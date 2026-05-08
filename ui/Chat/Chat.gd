extends Window

const MAX_LINES = 300
const PROMPT_GREEN := Color("#33dd55")
const PROMPT_RED := Color("#dd3333")

const TAB_MATCH = 0
const TAB_LOBBY = 1
const TAB_TITLES = ["match", "lobby"]

export var force_mute_on_hide = false

var showing = false

# True while a permission prompt is on screen waiting for a yes/no click.
# Reset on match boundary so a stale prompt doesn't block next match's request.
var pending_style_request := false

# Built at runtime alongside the scene's %ScrollContainer. Each tab gets its
# own ScrollContainer + VBoxContainer pair — sharing one ScrollContainer
# leaks the bigger child's scroll bounds onto the smaller one (Godot 3.5
# fits each child to its own minsize, but the scrollbar max ends up tracking
# the larger child) so the small tab gets a phantom scroll range to nowhere.
var match_scroll: ScrollContainer
var match_container: VBoxContainer
var unread_match := false
var unread_lobby := false

# Called when the node enters the scene tree for the first time.
func _ready():

	$"%ShowButton".connect("pressed", self, "toggle")
	$"%LineEdit".connect("message_ready", self, "on_message_ready")
	Network.connect("chat_message_received", self, "on_chat_message_received")
	Network.connect("style_save_request_received", self, "_on_style_save_request_received")
	Network.connect("style_save_response_received", self, "_on_style_save_response_received")
	Network.connect("match_ready", self, "_on_match_ready")
	SteamLobby.connect("chat_message_received", self, "on_steam_chat_message_received")
	SteamLobby.connect("lobby_data_update", self, "_on_lobby_data_update")
	if static_:
		$"%ShowButton".hide()
	SteamLobby.connect("user_joined", self, "_on_user_joined")
	SteamLobby.connect("user_left", self, "_on_user_left")
	_setup_tabs()
#	toggle()

func _setup_tabs():
	var lobby_scroll = $"%ScrollContainer"
	var parent = lobby_scroll.get_parent()
	# Mirror the lobby ScrollContainer's sizing so the match tab feels
	# identical when active.
	match_scroll = ScrollContainer.new()
	match_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_scroll.rect_min_size = lobby_scroll.rect_min_size
	parent.add_child(match_scroll)
	parent.move_child(match_scroll, lobby_scroll.get_index() + 1)
	match_container = VBoxContainer.new()
	match_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_scroll.add_child(match_container)
	match_scroll.hide()
	$"%Tabs".add_tab(TAB_TITLES[TAB_MATCH])
	$"%Tabs".add_tab(TAB_TITLES[TAB_LOBBY])
	# Inactive tab text needs to read clearly as backgrounded vs the active
	# one — Tabs ships with a fairly light bg color by default that doesn't
	# contrast much against the active tab.
	$"%Tabs".add_color_override("font_color_bg", Color(0.35, 0.35, 0.35))
	$"%Tabs".connect("tab_changed", self, "_on_tab_changed")
	$"%TabButton".connect("toggled", self, "_on_tab_button_toggled")
	_update_tabs_visibility()

func _on_tab_button_toggled(_pressed):
	_update_tabs_visibility()

func _on_match_ready(_data):
	pending_style_request = false
	# Don't clear match_container — chat history survives the new match start.
	_update_tabs_visibility()
	if $"%Tabs".visible:
		# Default to the match tab so match chat is visible the moment the
		# match begins; preserves any existing history that's already there.
		$"%Tabs".current_tab = TAB_MATCH
		_on_tab_changed(TAB_MATCH)

func _on_lobby_data_update(_success=null, _lobby_id=null, _member_id=null):
	# Status flips (back to idle when a match ends, etc.) come through here —
	# refresh tab visibility so the strip hides itself when we return to the
	# main lobby.
	_update_tabs_visibility()

func _update_tabs_visibility():
	var status = SteamLobby.get_status()
	var in_match = status == "fighting" or status == "spectating"
	# TabButton is the user's manual override — pressed hides the strip, but
	# the active container still shows whatever tab was last on. Only
	# relevant when there's actually a strip to toggle, so hide entirely
	# outside of fighting/spectating (singleplayer and main lobby idle).
	$"%TabButton".visible = in_match
	$"%Tabs".visible = in_match and not $"%TabButton".pressed
	if not in_match:
		# No match context — only the lobby scroll is on screen. Match-tab
		# unread state would be invisible anyway, but clear it so a stale *
		# doesn't reappear when the next match starts.
		match_scroll.hide()
		$"%ScrollContainer".show()
		unread_match = false
	else:
		_apply_active_tab()
	_refresh_tab_titles()

func _on_tab_changed(idx):
	if idx == TAB_MATCH:
		unread_match = false
	else:
		unread_lobby = false
	_apply_active_tab()
	_refresh_tab_titles()
	# Snap to bottom of the newly-revealed scroll so the latest message is
	# in view. Defer one frame so layout has settled before clamping.
	yield(get_tree(), 'idle_frame')
	_active_scroll().scroll_vertical = 10000000000000000

func _apply_active_tab():
	var active = _active_category()
	match_scroll.visible = active == "match"
	$"%ScrollContainer".visible = active == "lobby"

func _active_scroll() -> ScrollContainer:
	return match_scroll if _active_category() == "match" else $"%ScrollContainer" as ScrollContainer

func _active_category() -> String:
	# Idle/SP has no match context — everything routes to lobby. Otherwise
	# go off current_tab regardless of whether the strip is currently shown,
	# so TabButton can hide the strip without yanking the active container.
	var status = SteamLobby.get_status()
	var in_match = status == "fighting" or status == "spectating"
	if not in_match:
		return "lobby"
	return "match" if $"%Tabs".current_tab == TAB_MATCH else "lobby"

func _container_for(category):
	return match_container if category == "match" else $"%MessageContainer"

func _refresh_tab_titles():
	$"%Tabs".set_tab_title(TAB_MATCH, ("*" if unread_match else "") + TAB_TITLES[TAB_MATCH])
	$"%Tabs".set_tab_title(TAB_LOBBY, ("*" if unread_lobby else "") + TAB_TITLES[TAB_LOBBY])

# Decide which tab a message belongs to. Returns "" for messages that aren't
# for us at all (e.g. a different match's chatter when we're in our own).
func _categorize_message(steam_id) -> String:
	if steam_id == SteamHustle.STEAM_ID:
		# Our own echo — show it in whichever tab we're typing in so what we
		# just sent is visible regardless of which audience actually receives
		# it (Steam broadcasts; recipient-side filtering decides who sees).
		return _active_category()
	var sender_status = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "status")
	if sender_status == "idle" or sender_status == "busy":
		return "lobby"
	# Sender is fighting or spectating. Reuse the match-membership filter to
	# decide whether they're in *our* match — anyone in a different match is
	# dropped.
	if SteamLobby.can_get_messages_from_user(steam_id):
		return "match"
	return ""

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
	_container_for(_active_category()).call_deferred("add_child", node)
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	_active_scroll().scroll_vertical = 10000000000000000

func play_chat_sound():
	if !is_muted():
		$"ChatSound".play()

func on_steam_chat_message_received(steam_id: int, message: String):
	var category = _categorize_message(steam_id)
	if category == "":
		return
	var color = "ff333d" if (Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "player_id") == "2") else "1d8df5"
	var sender_status = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "status")
	if sender_status == "spectating":
		color = "999999"
		if steam_id == SteamHustle.STEAM_ID:
			color = "DDDDDD"

	var steam_name = Steam.getFriendPersonaName(steam_id)

	var text = ProfanityFilter.filter(("<[color=#%s]" % [color]) + steam_name + "[/color]>: " + message)
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.append_bbcode(text)
	node.fit_content_height = true

	var container = _container_for(category)
	container.call_deferred("add_child", node)

	# Sound only plays when the message lands in the tab that's currently on
	# screen — chatter in the other tab is signaled by the * marker instead.
	# Self-echoes never play sound (matches existing behavior).
	var is_active = category == _active_category()
	if is_active and steam_id != SteamHustle.STEAM_ID:
		play_chat_sound()
	if not is_active:
		if category == "match":
			unread_match = true
		else:
			unread_lobby = true
		_refresh_tab_titles()

	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	if is_active:
		_active_scroll().scroll_vertical = 10000000000000000

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
	_container_for(_active_category()).call_deferred("add_child", wrapper)
	play_chat_sound()
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	_active_scroll().scroll_vertical = 10000000000000000

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
