extends Window

const MAX_LINES = 300

export var force_mute_on_hide = false

var showing = false

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
	if Network.multiplayer_active or SteamLobby.SPECTATING:
		if len(message) < 1000:
			$"%LineEdit".clear()
			send_message(message)
		else:
			$"%TooLongLabel".show()
			$"%TooLongLabel".text = "message too long (" + str(len(message)) + "/1000)"
	else:
		send_message(message)
		$"%LineEdit".clear()

func process_command_vanilla(message: String):
	if Network.multiplayer_active and !SteamLobby.SPECTATING:
		if message.begins_with("/em "):
			Network.rpc_("player_emote", [Network.player_id, message])
			return true
	else:
		if message.begins_with("/em "):
			if is_instance_valid(Global.current_game):
				var player = Global.current_game.get_player(1)
				if player:
					player.emote(message.split("/em ")[-1])
			return true
		if message.begins_with("/em1 "):
			if is_instance_valid(Global.current_game):
				var player = Global.current_game.get_player(1)
				if player:
					player.emote(message.split("/em1 ")[-1])
			return true
		if message.begins_with("/em2 "):
			if is_instance_valid(Global.current_game):
				var player = Global.current_game.get_player(2)
				if player:
					player.emote(message.split("/em2 ")[-1])
			return true
	
	return false

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


onready var resync_button = $"%ResyncButton"

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

func process_command(message:String):
	var a = process_command_vanilla(message)
	if a: return a
	if not(Network.multiplayer_active and not SteamLobby.SPECTATING):
		if is_instance_valid(Global.current_game):
			# Technically checks player 1 and 2 twice, but I'll leave it just in case
			for v in Global.current_game.players.keys():
				if message.begins_with("/em" + str(v) + " "):
					var player = Global.current_game.get_player(v)
					if player:
						player.emote(message.split("/em" + str(v) + " ")[ - 1])
						return true
	return a

# Same as vanilla but with custom player name colors
func on_mh_chat_message_received(player_id: int, message: String, username: String):
	var team = Network.get_team(player_id)
	var color = Network.get_color(team)
	if Network.game == null:
		color = "d931e8"
	print(color)


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

