extends Window



const MAX_LINES = 450

onready var resync_button = $"%ResyncButton"

export var force_mute_on_hide = false

var showing = false

var commands := {
	"em[p]": "em_command",
	"emc[p]": "clear_em_command",
	"emt[p]": "timed_em_command",
	"help": "list_command",
	"kick[p]": "kick_command"
}

const ARG_PLAYER = "[p]"


func _on_user_joined(user):
	god_message(user + " joined.")

func _on_user_left(user):
	god_message(user + " left.")

func line_edit_focus():
	$"%LineEdit".grab_focus()

func is_muted():
	return $"%MuteButton".pressed or (!is_visible_in_tree() and force_mute_on_hide)
	

func on_chat_message_received(player_id: int, message: String):
	var color = "ff333d" if player_id == 2 else "1d8df5"
#	print("here")
	var text = ProfanityFilter.filter(("<[color=#%s]" % [color]) + Network.pid_to_username(player_id) + "[/color]>: " + message)
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.append_bbcode(text)
	node.fit_content_height = true
	if !(player_id == Network.player_id):
		play_chat_sound()
	$"%MessageContainer".call_deferred("add_child", node)
	if $"%MessageContainer".get_child_count() + 1 > MAX_LINES:
		$"%MessageContainer".call_deferred("remove_child", $"%MessageContainer".get_child(0))
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func god_message(message: String):
	$"ChatSound".play()
	var node = RichTextLabel.new()
	var text = ProfanityFilter.filter(":: " + message)
	node.bbcode_enabled = true
	node.append_bbcode(text)
	node.fit_content_height = true
	$"%MessageContainer".call_deferred("add_child", node)
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func play_chat_sound():
	if !is_muted():
		$"ChatSound".play()

func on_steam_chat_message_received(steam_id: int, message: String):
	if !SteamLobby.can_get_messages_from_user(steam_id):
		return
	var color = "d931e8"
	var steam_name = Steam.getFriendPersonaName(steam_id)
	
	var text = ProfanityFilter.filter(("<[color=#%s]%s[/color]>: %s" % [color, steam_name, message]))
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.append_bbcode(text)
	node.fit_content_height = true
	if !(steam_id == SteamHustle.STEAM_ID):
		play_chat_sound()
	
	$"%MessageContainer".call_deferred("add_child", node)
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func unfocus_line_edit():
	$"%LineEdit".release_focus()

func on_message_ready(message):
	$"%TooLongLabel".hide()
	$"%LineEdit".clear()
	send_message(message)


func toggle():
	visible = !visible
#	if showing:
#		$"%Contents".hide()
#		showing = false
#		yield(get_tree(), "idle_frame")
#		rect_size.y = 0
#	else:
#		$"%Contents".show()
#		showing = true



func _ready():
	Network._whitelist_rpc_method("send_mh_chat_message")
	Network.connect("mh_chat_message_received", self, "on_mh_chat_message_received")

	Network._whitelist_rpc_method("send_mh_chat_message_preformatted")
	Network.connect("mh_chat_message_received_preformatted", self, "on_mh_chat_message_received_preformatted")

	Network._whitelist_rpc_method("request_mh_resim")
	Network._whitelist_rpc_method("accept_mh_resim")
	Network.connect("mh_resim_requested", self, "show_resync")

	resync_button.hide()
	resync_button.connect("pressed", self, "on_resync_press")
	print("MH Modded Chat ready!")
	
	$"%ShowButton".connect("pressed", self, "toggle")
	$"%LineEdit".connect("message_ready", self, "on_message_ready")
	Network.connect("chat_message_received", self, "on_chat_message_received")
	SteamLobby.connect("chat_message_received", self, "on_steam_chat_message_received")
	if static_:
		$"%ShowButton".hide()
	SteamLobby.connect("user_joined", self, "_on_user_joined")
	SteamLobby.connect("user_left", self, "_on_user_left")


func on_resync_press():
	Network.accept_softlock_fix()
	resync_button.hide()

func show_resync(player_id:int):
	if Network.resync_request_player_id == Network.player_id:
		return
	
	resync_button.show()
	pass

func process_data(msg:String, cmd_base:String) -> Dictionary:
	var data = {}
	
	data["args_with_cmd"] = msg.split(" ", false)
	var args = msg.split(" ", false)
	args.remove(0)
	if (ARG_PLAYER in cmd_base):
		data["players"] = []
		var regex_p = RegEx.new()
		regex_p.compile("(\\d+|\\[p\\])")
		for result in regex_p.search_all(data.args_with_cmd[0]):
			data.players.append(int(result.get_string()))
	
	data["args"] = args
	
	return data

func process_command_online(message:String):
	for cmd in commands:
		var cmd_no_args = cmd.replace(ARG_PLAYER, "").replace(" ", "")#.replace(...).replace(...)...
		if ("/"+cmd_no_args in message):
			call(commands[cmd]+"_online", process_data(message, cmd))
			return true
	return false
		
func process_command(message:String):
	if Network.multiplayer_active and !SteamLobby.SPECTATING:
		return process_command_online(message)
	else:
		for cmd in commands:
			var msg_start:String = message.split(" ", false)[0]
			msg_start = remove_digits(msg_start)
			var cmd_no_args = cmd.replace(ARG_PLAYER, "").replace(" ", "")#.replace(...).replace(...)...
			if ("/"+cmd_no_args == msg_start):
				call(commands[cmd], process_data(message, cmd))
				return true
	return false

# Same as vanilla but with custom player name colors
func on_mh_chat_message_received(player_id: int, message: String, username: String):
	var team = Network.get_team(player_id)
	var color = Network.get_color(team)
	if Network.game == null:
		color = "d931e8"

	var text = ProfanityFilter.filter(("<[color=#%s]" % [color]) + username + "[/color]>: " + message)
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.bbcode_text = text
	node.fit_content_height = true
	#if not (player_id == Network.player_id): doesnt work? its causing errors
	#	play_cha_sound()
	$"%MessageContainer".call_deferred("add_child", node)
	if $"%MessageContainer".get_child_count() + 1 > MAX_LINES:
		$"%MessageContainer".call_deferred("remove_child", $"%MessageContainer".get_child(0))
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func send_message(message):
	if process_command(message):
		return
		
	if Network.game == null:
		SteamLobby.send_chat_message(message)
		
		if "[img" in message and "ui/unknown2.png" in message:
			SteamHustle.unlock_achievement("ACH_JUMPSCARE")
		return
	
	var steam_name = Steam.getFriendPersonaName(Steam.getSteamID())
	
	if "[img" in message and "ui/unknown2.png" in message:
		SteamHustle.unlock_achievement("ACH_JUMPSCARE")
	if not Network.multiplayer_active and not SteamLobby.SPECTATING:
		on_mh_chat_message_received(1, message, steam_name)
		return
	Network.rpc_("send_mh_chat_message", [Network.player_id, message, steam_name])

# For system messages (resync for example)
func on_mh_chat_message_received_preformatted(message: String):
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.bbcode_text = message
	node.fit_content_height = true
	play_chat_sound()
	$"%MessageContainer".call_deferred("add_child", node)
	if $"%MessageContainer".get_child_count() + 1 > MAX_LINES:
		$"%MessageContainer".call_deferred("remove_child", $"%MessageContainer".get_child(0))
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func em_command_online(data):
	Network.rpc_("player_emote", [Network.player_id, " ".join(data.args)])
func em_command(data):
	if is_instance_valid(Global.current_game):
		var v = 1 if len(data.players) == 0 else data.players[0]
		var player = Global.current_game.get_player(v)
		if player:
			player.emote(" ".join(data.args))
			
func timed_em_command_online(data):
	#on_mh_chat_message_received_preformatted("Timed EM text is currently not supported in online multiplayer!")
	var time = data.args[0]
	data.args[0] = ""
	Network.rpc_("timed_player_emote", [Network.player_id, " ".join(data.args), time])

func timed_em_command(data):
	if is_instance_valid(Global.current_game):
		var v = 1 if len(data.players) == 0 else data.players[0]
		var player = Global.current_game.get_player(v)
		var time = data.args[0]
		data.args[0] = ""
		if player:
			player.emote(" ".join(data.args), int(time))

func clear_em_command_online(data):
	Network.rpc_("player_emote", [Network.player_id, ""])
func clear_em_command(data):
	if is_instance_valid(Global.current_game):
		var v = 1 if len(data.players) == 0 else data.players[0]
		var player = Global.current_game.get_player(v)
		if player:
			player.emote("", 0)

func remove_digits(string:String) -> String:
	var regex = RegEx.new()
	regex.compile("\\d+")
	return regex.sub(string, "", true)


func clear_em_command_help():
	return "Clears emote"
	
func em_command_help():
	return "Spawns emote text for 3 seconds (180 frames)"
	
func timed_em_command_help():
	return "Spawns emote text for a custom amout of time in frames. Just put the time between the /emt[p] and the emote text. (60 frames = 1 second)"
	
func list_command_help():
	return "Lists all commands."

func kick_command_help():
	return "Kicks a player and forfeits them."
	
func list_command(data):
	var text = "[rainbow]Commands:[/rainbow]\n"
	for cmd in commands:
		var cmd_help = call(commands[cmd]+"_help")
		text += "/%s: %s\n" % [cmd, cmd_help]
	on_mh_chat_message_received_preformatted(text)
func list_command_online(data):
	list_command(data)

# just here for no reason
func kick_command(data):
	if (len(data.players) == 0):
		return
	
	if is_instance_valid(Global.current_game):
		var v = data.players[0]
		var player = Global.current_game.get_player(v)
		if player:
			player.forfeit()
			
func kick_command_online(data):
	if (len(data.players) == 0):
		return
	
	if is_instance_valid(Global.current_game):
		if (Network.player_id != 1):
			Network.send_mh_chat_message_preformatted("%s tried to kick %s but they aren't the owner! (exposed)" % [Global.current_game.player_names_rich[Network.player_id], Global.current_game.player_names_rich[data.players[0]]])
			return
		
		var v = data.players[0]
		var player = Global.current_game.get_player(v)
		if player:
			Steam.closeP2PSessionWithUser(Network.network_ids[data.players[0]])
