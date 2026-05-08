extends Window

const MAX_LINES = 300
const PROMPT_GREEN := Color("#33dd55")
const PROMPT_RED := Color("#dd3333")

export var force_mute_on_hide = false

var showing = false

# True while a permission prompt is on screen waiting for a yes/no click.
# Reset on match boundary so a stale prompt doesn't block next match's request.
var pending_style_request := false

# Called when the node enters the scene tree for the first time.
func _ready():
	$"%ShowButton".connect("pressed", self, "toggle")
	$"%LineEdit".connect("message_ready", self, "on_message_ready")
	Network.connect("chat_message_received", self, "on_chat_message_received")
	Network.connect("style_save_request_received", self, "_on_style_save_request_received")
	Network.connect("style_save_response_received", self, "_on_style_save_response_received")
	Network.connect("match_ready", self, "_on_match_ready")
	SteamLobby.connect("chat_message_received", self, "on_steam_chat_message_received")
	if static_:
		$"%ShowButton".hide()
	SteamLobby.connect("user_joined", self, "_on_user_joined")
	SteamLobby.connect("user_left", self, "_on_user_left")
#	toggle()

func _on_match_ready(_data):
	pending_style_request = false

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
	var color = "ff333d" if (Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "player_id") == "2") else "1d8df5"
	var sender_status = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "status")
	if sender_status == "spectating":
		color = "999999"
		if steam_id == SteamHustle.STEAM_ID:
			color = "DDDDDD"
	# When we're in/watching a match and someone outside (still in the main
	# lobby) chats, dim their name so it reads as background chatter rather
	# than a teammate / spectator of our match.
	var my_status = SteamLobby.get_status()
	if (my_status == "fighting" or my_status == "spectating") \
			and sender_status != "fighting" and sender_status != "spectating":
		color = "888888"

	var steam_name = Steam.getFriendPersonaName(steam_id)
	
	var text = ProfanityFilter.filter(("<[color=#%s]" % [color]) + steam_name + "[/color]>: " + message)
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

func process_command(message: String):
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

func send_message(message):
	if process_command(message):
		return

	if "[img" in message and "ui/unknown2.png" in message:
		SteamHustle.unlock_achievement("ACH_JUMPSCARE")
	if !Network.multiplayer_active and !SteamLobby.SPECTATING:
		on_chat_message_received(1, message)
		return
	if !Network.steam:
		Network.rpc_("send_chat_message", [Network.player_id, message])
	else:
		SteamLobby.send_chat_message(message)

func _on_style_save_request_received(target_player_id, requester_id, requester_name, style_name):
	# Only the targeted *fighter* gets prompted. Spectators may share a
	# Network.player_id with a fighter (default 1), so explicitly exclude
	# them. pending_style_request also blocks a duplicate prompt if the
	# network double-delivers.
	if SteamLobby.SPECTATING:
		return
	if Network.player_id != target_player_id:
		return
	if pending_style_request:
		return
	pending_style_request = true
	if !visible:
		show()
	_show_style_save_prompt(target_player_id, requester_id, requester_name, style_name)

func _show_style_save_prompt(target_player_id, requester_id, requester_name, style_name):
	var wrapper = VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content_height = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var display_name = style_name if style_name != "" else "your style"
	var safe_requester = ProfanityFilter.filter(requester_name)
	var safe_style = ProfanityFilter.filter(display_name)
	label.append_bbcode(":: " + safe_requester + " wants to save your style, \"" + safe_style + "\"")
	wrapper.add_child(label)
	var button_row = HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes_btn = Button.new()
	yes_btn.text = "yes"
	yes_btn.modulate = PROMPT_GREEN
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.rect_min_size = Vector2(0, 18)
	yes_btn.connect("pressed", self, "_on_style_prompt_response", [button_row, target_player_id, requester_id, requester_name, true])
	button_row.add_child(yes_btn)
	var no_btn = Button.new()
	no_btn.text = "no"
	no_btn.modulate = PROMPT_RED
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_btn.rect_min_size = Vector2(0, 18)
	no_btn.connect("pressed", self, "_on_style_prompt_response", [button_row, target_player_id, requester_id, requester_name, false])
	button_row.add_child(no_btn)
	wrapper.add_child(button_row)
	$"%MessageContainer".call_deferred("add_child", wrapper)
	play_chat_sound()
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func _on_style_prompt_response(prompt_node, target_player_id, requester_id, requester_name, allowed):
	pending_style_request = false
	Network.broadcast_rpc("receive_style_save_response", [target_player_id, requester_id, requester_name, allowed])
	if is_instance_valid(prompt_node):
		prompt_node.queue_free()
	god_message(("granted save permission to " if allowed else "denied save permission to ") + requester_name + ".")

func _on_style_save_response_received(target_player_id, requester_id, requester_name, allowed):
	# Only surface to the actual requester. On steam, match by verified
	# steam_id (spoof-resistant). On relay, fall back to username.
	if !_response_matches_me(requester_id, requester_name):
		return
	if allowed:
		god_message("p%d granted save permission." % target_player_id)
	else:
		god_message("p%d denied save permission." % target_player_id)

func _response_matches_me(requester_id, requester_name) -> bool:
	if Network.steam:
		return requester_id != 0 and requester_id == SteamHustle.STEAM_ID
	return requester_name == Global.get_player_data().username

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
