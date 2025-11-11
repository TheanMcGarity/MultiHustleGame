extends CanvasLayer

onready var p1_action_buttons = $"%P1ActionButtons"
onready var p2_action_buttons = $"%P2ActionButtons"

signal singleplayer_started()
signal multiplayer_started()
signal loaded_replay(match_data)
signal received_synced_time()
#
#const dark_mode_color = Color("0b0c0f")
#const light_mode_color = Color("33394b")

var game
var turns_taken = {
	1: false,
	2: false
}

var turn_time = 30

var p1_turn_time = 30
var p2_turn_time = 30

var chess_timer = false

var draw_bg_circle = false

var lock_in_tick = -INF

const DISCORD_URL = "https://discord.gg/YourOnlyMoveIsHUSTLE"
const TWITTER_URL = "https://x.com/YourMoveHUSTLE"
const IVY_SLY_URL = "https://www.ivysly.com"
const TIKTOK_URL = "https://www.tiktok.com/@youronlymoveishustle"
const STEAM_URL = "https://store.steampowered.com/app/2212330"
const ITCH_URL = "https://ivysly.itch.io/your-only-move-is-hustle"
var MIN_TURN_TIME = 5.0

onready var lobby = $Lobby
onready var direct_connect_lobby = $DirectConnectLobby
onready var mh_support_window = $MHSupportWindow
onready var p1_turn_timer = $"%P1TurnTimer"
onready var p2_turn_timer = $"%P2TurnTimer"
onready var block_advantage_label = $"%BlockAdvantageLabel"
onready var neutral_label = $"%NeutralLabel"

var p1_synced_time = null
var p2_synced_time = null

var game_started = false
var timer_sync_tick = -1
var actionable = false

var forfeit_pressed = false

var actionable_time = 0

var received_synced_time = false

var quit_on_rematch = true

var p1_time_run_out = false
var p2_time_run_out = false

var p1_info_scene
var p2_info_scene

onready var global_option_check_buttons = {
	$"%EnableStyleColorsButton": "enable_custom_colors",
	$"%EnableAurasButton": "enable_custom_particles",
	$"%EnableHitsparksButton": "enable_custom_hit_sparks",
	$"%EnableEmotes": "enable_emotes",
	$"%LastMoveIndicatorButton": "show_last_move_indicators",
	$"%ProjectileOwnersButton": "show_projectile_owners",
	$"%SpeedLinesButton": "speed_lines_enabled",
	$"%AutoFCButton": "auto_fc",
	$"%ExtraInfoButton": "show_extra_info",
	$"%TimerSoundButton": "enable_timer_sound",
	$"%ExtraFreezeFrames": "replay_extra_freeze_frames",
#	$"%SingleplayerForfeitButton": "forfeit_buttons_enabled",
}

func _enter_tree():
	if Global.character_select_node == null:
		Global.character_select_node = $"%CharacterSelect"
	else:
		$"%CharacterSelect".free()
		var css: Node = Global.character_select_node
		add_child(css)
		move_child(css, 15)
		css.name = "CharacterSelect"
		css.owner = owner
		css.unique_name_in_owner = true
		css.reset()

func _ready():
	$"%SingleplayerButton".connect("pressed", self, "_on_singleplayer_pressed")
	$"%MultiplayerButton".connect("pressed", self, "_on_multiplayer_pressed")
	$"%SteamMultiplayerButton".connect("pressed", self, "_on_steam_multiplayer_pressed")
	$"%CustomizeButton".connect("pressed", self, "_on_customize_pressed")
	$"%DirectConnectButton".connect("pressed", self, "_on_direct_connect_button_pressed")
	$"%RematchButton".connect("pressed", self, "_on_rematch_button_pressed")
	$"%QuitButton".connect("pressed", self, "_on_quit_button_pressed")
	$"%SupportMHButton".connect("pressed", self, "_on_support_mh_button_pressed")
	$"%QuitToMainMenuButton".connect("pressed", self, "_on_quit_button_pressed")
	$"%ForfeitButton".connect("pressed", self, "_on_forfeit_button_pressed")
	$"%QuitProgramButton".connect("pressed", self, "_on_quit_program_button_pressed")
	$"%ResumeButton".connect("pressed", self, "pause")
	$"%ReplayButton".connect("pressed", self, "_on_view_replays_button_pressed")
	$"%ReplayCancelButton".connect("pressed", self, "_on_replay_cancel_pressed")
	$"%OpenReplayFolderButton".connect("pressed", self, "open_replay_folder")
	$"%P1ActionButtons".connect("turn_ended", self, "end_turn_for", [1])
	$"%P2ActionButtons".connect("turn_ended", self, "end_turn_for", [2])
	$"%ShowAutosavedReplays".connect("pressed", self, "_on_view_replays_button_pressed")
	$"%DiscordButton".connect("pressed", Steam, "activateGameOverlayToWebPage", [DISCORD_URL])
	$"%IvySlyLinkButton".connect("pressed", Steam, "activateGameOverlayToWebPage", [IVY_SLY_URL])
	$"%WishlistButton".connect("pressed", Steam, "activateGameOverlayToWebPage", [STEAM_URL])
	$"%TwitterButton".connect("pressed", Steam, "activateGameOverlayToWebPage", [TWITTER_URL])
	$"%TikTokButton".connect("pressed", Steam, "activateGameOverlayToWebPage", [TIKTOK_URL])
	$"%ItchButton".connect("pressed", Steam, "activateGameOverlayToWebPage", [ITCH_URL])
	$"%ResetZoomButton".connect("pressed", self, "_on_reset_zoom_pressed")
	Network.connect("player_turns_synced", self, "on_player_actionable")
	Network.connect("player_turn_ready", self, "_on_player_turn_ready")
	Network.connect("turn_ready", self, "_on_turn_ready")
	Network.connect("sync_timer_request", self, "_on_sync_timer_request")
	Network.connect("check_players_ready", self, "check_players_ready")
	Network.connect("force_open_action_buttons", self, "on_player_actionable")

	SteamLobby.connect("join_lobby_success", self, "_on_join_lobby_success")
	$"%OptionsContainer".hide()
	p1_turn_timer.connect("timeout", self, "_on_turn_timer_timeout", [1])
	p2_turn_timer.connect("timeout", self, "_on_turn_timer_timeout", [2])
	for lobby in [$"%Lobby", $"%DirectConnectLobby", SteamLobby]:
		lobby.connect("quit_on_rematch", $"%RematchButton", "hide")
		lobby.connect("quit_on_rematch", self, "set", ["quit_on_rematch", true])
	$"%HelpButton".connect("pressed", self, "toggle_help_screen")
	$"%OptionsBackButton".connect("pressed", $"%OptionsContainer", "hide")
	$"%OptionsButton".connect("pressed", $"%OptionsContainer", "show")
	$"%CreditsButton".connect("pressed", $"%Credits", "show")
	$"%CreditsButton".connect("pressed", $"%MainMenu", "hide")
	$"%PauseOptionsButton".connect("pressed", $"%OptionsContainer", "show")
	$"%MusicButton".set_pressed_no_signal(Global.music_enabled)
	$"%MusicButton".connect("toggled", self, "_on_music_button_toggled")
#	$"%LightModeButton".set_pressed_no_signal(Global.light_mode)
#	$"%LightModeButton".connect("toggled", self, "_on_light_mode_toggled")
	$"%FullscreenButton".set_pressed_no_signal(Global.fullscreen)
	$"%FullscreenButton".connect("toggled", self, "_on_fullscreen_button_toggled")
	$"%HitboxesButton".set_pressed_no_signal(Global.show_hitboxes)
	$"%HitboxesButton".connect("toggled", self, "_on_hitboxes_button_toggled")
	$"%PlaybackControls".set_pressed_no_signal(Global.show_playback_controls)
	$"%PlaybackControls".connect("toggled", self, "_on_playback_controls_button_toggled")
	$"%PredictionSettingsOpenButton".connect("pressed", self, "_on_open_prediction_settings_pressed")
	$"%PredictionSettingsCloseButton".connect("pressed", self, "_on_close_prediction_settings_pressed")
#	$"%BGColor".color = dark_mode_color
#	if Global.light_mode:
#		$"%BGColor".color = light_mode_color
	if !SteamHustle.STARTED:
		$"%SteamMultiplayerButton".hide()
		$"%WishlistButton".show()
		$"%RoadmapContainer".hide()
		$"%CustomizeButton".hide()
		$"%SteamBetaReplayTip".hide()
#		$"%CustomizeButton".hide()
#		$"%EnableStyleColorsButton".hide()
#		$"%EnableAurasButton".hide()
#		$"%EnableHitsparksButton".hide()
	else:
		$"%WishlistButton".hide()
		$"%RoadmapContainer".show()
		$"%MultiplayerButton".text = "Multiplayer (Legacy)"
	
	$NetworkSyncTimer.connect("timeout", self, "_on_network_timer_timeout")
	quit_on_rematch = false
	for node in global_option_check_buttons:
		node.set_pressed_no_signal(Global.get(global_option_check_buttons[node]))
		node.connect("toggled", self, "_on_global_option_toggled", [global_option_check_buttons[node]])
	
	$"%HelpScreen".hide()
	if SteamLobby.LOBBY_ID != 0:
		yield(get_tree(), "idle_frame") 
#		yield(get_tree(), "idle_frame")
		_on_join_lobby_success()
	$"%CharacterSelect".connect("opened", self, "reset_ui")
#	$"CharacterSelect".connect("opened", self, "reset_ui")
	yield(get_tree(), "idle_frame")
	
	p1_turn_timer.disconnect("timeout", self, "_on_turn_timer_timeout")
	p2_turn_timer.disconnect("timeout", self, "_on_turn_timer_timeout")
	Network.disconnect("player_turns_synced", self, "on_player_actionable")
	


func _on_global_option_toggled(toggled, param):
	Global.save_option(toggled, param)

#func _on_light_mode_toggled(on):
#	Global.set_light_mode(on)
#	if Global.light_mode:
#		$"%BGColor".color = light_mode_color
#	else:
#		$"%BGColor".color = dark_mode_color

func on_workshop_uploader_clicked():
	hide_main_menu()
	$"%WorkshopMenu".init()
	$"%WorkshopMenu".show()

	
func _on_music_button_toggled(on):
	Global.set_music_enabled(on)
	Global.save_options()

func _on_fullscreen_button_toggled(on):
	Global.set_fullscreen(on)

func _on_hitboxes_button_toggled(on):
	Global.set_hitboxes(on)

func _on_playback_controls_button_toggled(on):
	Global.set_playback_controls(on)

func _on_open_prediction_settings_pressed():
	$"%PredictionSettingsOpenButton".hide()
	$"%OptionsBar".show()

func _on_close_prediction_settings_pressed():
	$"%PredictionSettingsOpenButton".show()
	$"%OptionsBar".hide()

func toggle_help_screen():
	$"%HelpScreen".visible = !$"%HelpScreen".visible

func _on_join_lobby_success():
	if is_instance_valid(Global.current_game):
		return
	$"%HudLayer".hide()
	$"%SteamLobbyList".hide()
	$"%SteamLobby".show()
	$"%GameUI".hide()
	hide_main_menu(true)
#	$"%MainMenu".hide()

func hide_main_menu(all=false):
	if all:
		$"%MainMenu".hide()
	else:
		$"%ButtonContainer".hide()
		$"%Title".hide()
		$"%RoadmapContainer".hide()

func _on_view_replays_button_pressed():
	load_replays()
	hide_main_menu()

func _on_forfeit_button_pressed():
	if is_instance_valid(game) and !game.game_finished:
		var player_id = Network.player_id
		game.get_player(player_id).on_action_selected("Forfeit", null, null)
		Network.forfeit()
		forfeit_pressed = true
		actionable = false
	$"%PausePanel".hide()

func _on_opponent_disconnected():
	if is_instance_valid(game) and !game.game_finished:
		game.get_player((game.my_id % 2) + 1).on_action_selected("Forfeit", null, null)
		Network.forfeit(true)
		print("opponent disconnected")
		forfeit_pressed = true
		actionable = false
	$"%PausePanel".hide()

func _on_customize_pressed():
	$"%MainMenu".hide()
	$"%CustomizationScreen".init()
	$"%CustomizationScreen".show()
	pass

func load_replays():
	$"%ReplayWindow".show()
	for child in $"%ReplayContainer".get_children():
		child.free()
	var replay_map = ReplayManager.load_replays($"%ShowAutosavedReplays".pressed)
	var buttons = []
	for key in replay_map:
		var button = preload("res://ui/ReplayWindow/ReplayButton.tscn").instance()
		add_child(button)
		button.setup(replay_map, key)
		button.connect("pressed", self, "_on_replay_button_pressed", [button.path])
		buttons.append(button)
		remove_child(button)
	buttons.sort_custom(self, "sort_replays")
	for button in buttons:
		$"%ReplayContainer".add_child(button)
	for i in range(len(buttons)):
		if !is_instance_valid(self):
			break
		if !$"%ReplayWindow".visible:
			break
		if !is_instance_valid(buttons[i]):
			break
		var button = buttons[i]
		button.show_data()
		if i % 10 == 0:
			yield(button, "data_updated")

func _on_reset_zoom_pressed():
	if is_instance_valid(game):
		game.reset_zoom()

func set_turn_time(time, minutes=false):
#	print("setting turn time to " + str(time))
	p1_turn_time = time * (60 if minutes else 1)
	p2_turn_time = time * (60 if minutes else 1)
	turn_time = time * (60 if minutes else 1)
	p1_turn_timer.wait_time = p1_turn_time
	p2_turn_timer.wait_time = p2_turn_time
	for timer in turn_timers.values():
		timer.wait_time = time * (60 if minutes else 1)

func sort_replays(a, b):
	return a.modified > b.modified

func _on_replay_button_pressed(path):
	var match_data = ReplayManager.load_replay(path)
	emit_signal("loaded_replay", match_data)
	$"%ReplayWindow".hide()

func _on_replay_cancel_pressed():
	Global.reload()

#func _notification(what):
#	if (what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST):
#		pass
#		if will_forfeit():
#			_on_forfeit_button_pressed()
#			yield(get_tree().create_timer(2.0), "timeout")
#			get_tree().quit()
#		elif can_quit():
#			print ("You are quit!")
#			get_tree().quit() # default behavior

func will_forfeit():
	return !SteamLobby.SPECTATING and Network.multiplayer_active and is_instance_valid(game) and !game.game_finished and !game.forfeit and !ReplayManager.playback and !forfeit_pressed

func can_quit():
	return true
#	return !(is_instance_valid(game) and game.forfeit and !ReplayManager.playback and Network.forfeiter == Network.player_id)

func reset_ui():
	$"%HudLayer".hide()
	p1_turn_timer.stop()
	p2_turn_timer.stop()
	$"%P1TurnTimerBar".hide()
	$"%P1TurnTimerLabel".hide() 
	$"%P2TurnTimerBar".hide()
	$"%P2TurnTimerLabel".hide()
	$"%GameUI".hide()
	$"%ChatWindow".hide()
	$"%PostGameButtons".hide()
	$"%OpponentDisconnectedLabel".hide()
	forfeit_pressed = false
	actionable = false

func _on_quit_button_pressed():
	if will_forfeit():
		_on_forfeit_button_pressed()
	else:
		if can_quit():
			if !Network.steam:
				Network.stop_multiplayer()
				Global.reload()
			else:
				SteamLobby.exit_match_from_button()

func _on_quit_program_button_pressed():
	get_tree().quit()

func init(game):
	var m = Network.main # mh function uses m as its func param but vanilla uses game
	self.main = m
	game = m.game
	game.turns_taken = {}
	for index in game.players.keys():
		game.turns_taken[index] = false
		# TODO - Implement this
		player_time_run_out[index] = false
	forfeit_pressed = false
	if !ReplayManager.playback:
		$PostGameButtons.hide()
		$"%RematchButton".disabled = false
	self.game = game
	setup_action_buttons()
	if Network.multiplayer_active or SteamLobby.SPECTATING:
		game.connect("playback_requested", self, "_on_game_playback_requested")
		$"%P1TurnTimerLabel".show()
		$"%P2TurnTimerLabel".show()
		$"%ChatWindow".show()
	game_started = false
	chess_timer = game.match_data.has("chess_timer") and game.match_data.chess_timer
	timer_sync_tick = -1
	lock_in_tick = -INF
	p1_time_run_out = false
	p2_time_run_out = false
	
	turn_timers = {}
	for index in game.players.keys():
		turn_timers[index] = Timer.new()
		turn_timers[index].connect("timeout", self, "_on_turn_timer_timeout", [index])
		add_child(turn_timers[index], true)
	#if !is_instance_valid(spacebar_handler):
	#	spacebar_handler = preload("res://MultiHustle/SpacebarControl.gd").new()
	#	spacebar_handler.uilayer = self
	#	add_child(spacebar_handler)

func _on_rematch_button_pressed():
	Network.request_rematch()
	$"%RematchButton".disabled = true

func on_game_started():
	lobby.hide()
	$"%SteamLobby".hide()
	$MainMenu.hide()

func _on_singleplayer_pressed():
	Global.frame_advance = false
	SteamLobby.leave_Lobby()
	emit_signal("singleplayer_started")

func _on_direct_connect_button_pressed():
	direct_connect_lobby.show()
	hide_main_menu()
	
func _on_support_mh_button_pressed():
	mh_support_window.show()
	#hide_main_menu()

func _on_multiplayer_pressed():
	SteamLobby.leave_Lobby()
	lobby.show()
	hide_main_menu()
	
func _on_steam_multiplayer_pressed():
	$"%SteamLobbyList".show()
	hide_main_menu()
	

func _on_turn_ready():
	$"%P1TurnTimerBar".hide()
	$"%P2TurnTimerBar".hide()
	actionable = false
#	p1_turn_timer.stop()
#	p2_turn_timer.stop()
	
	var turns_taken = {
		1: false,
		2: false
	}


func open_replay_folder():
	var folder = ProjectSettings.globalize_path("user://replay")
	OS.shell_open(folder)

	
func check_players_ready():
	if is_instance_valid(game):
		if game.is_waiting_on_player():
			if lock_in_tick != game.current_tick:
				on_player_actionable()

func _on_network_timer_timeout():
	if Network.multiplayer_active:
		if !Network.turn_synced:
			if is_instance_valid(game):
				if game.player_actionable and lock_in_tick != game.current_tick and !actionable:
					Network.rpc_("check_players_ready")

func pause():
	$"%PausePanel".visible = !$"%PausePanel".visible
	if $"%PausePanel".visible:
		if will_forfeit():
			$"%QuitToMainMenuButton".hide()
			$"%ForfeitButton".show()
		else:
			$"%QuitToMainMenuButton".show()
			$"%ForfeitButton".hide()
		$"%SaveReplayButton".disabled = false
		$"%SaveReplayButton".text = "save replay"
		$"%SaveReplayLabel".text = ""

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ENTER:
				if is_instance_valid(game):
					$"%ChatWindow".show()
					$"%ChatWindow".line_edit_focus()
			if event.scancode == KEY_F1:
				visible = !visible
				$"../HudLayer/HudLayer".visible = ! $"../HudLayer/HudLayer".visible
#			if !Network.multiplayer_active:
#				if is_instance_valid(game) and $"%ReplayControls".visible:
#					if event.scancode == KEY_P:
#						Global.frame_advance = !Global.frame_advance
#					if event.scancode == KEY_F:
#						game.advance_frame_input = true
#			if event.scancode == KEY_SPACE:
#				p1_action_buttons.space_pressed()
#				p2_action_buttons.space_pressed()
	if event is InputEventMouseButton:
		if event.pressed:
			$"%ChatWindow".unfocus_line_edit()

func time_convert(time_in_sec):
	var seconds = time_in_sec%60
	var minutes = (time_in_sec/60)%60
	var hours = (time_in_sec/60)/60

	#returns a string with the format "HH:MM:SS"
	if hours >= 1:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]

func _process(delta):
	
	var p1_old_text = $"%P1TurnTimerLabel".text
	$"%P1TurnTimerLabel".text = time_convert(int(floor(p1_turn_timer.time_left)))
	var p1_different_text = p1_old_text != $"%P1TurnTimerLabel".text

	var p2_old_text = $"%P2TurnTimerLabel".text
	$"%P2TurnTimerLabel".text = time_convert(int(floor(p2_turn_timer.time_left)))
	var p2_different_text = p2_old_text != $"%P2TurnTimerLabel".text

	if $"%VersionLabel".visible:
		$"%VersionLabel".text = "version " + Global.VERSION

	var you_id = 1
	var opponent_id = 2
	if Network.multiplayer_active:
		you_id = Network.player_id
		opponent_id = (you_id % 2) + 1

	if is_instance_valid(game):
		if !p1_turn_timer.is_paused():
	#		if !turns_taken[1]:
				var bar = $"%P1TurnTimerBar"
				bar.value = p1_turn_timer.time_left / turn_time
				if p1_turn_timer.time_left < MIN_TURN_TIME:
					bar.visible = Utils.wave(-1, 1, 0.064) > 0
					if p1_different_text and you_id == 1 and p1_turn_timer.time_left:
						if Global.enable_timer_sound and (round(p1_turn_timer.time_left) == MIN_TURN_TIME):
							if !chess_timer or !p1_time_run_out:
								p1_time_run_out = true
								$"%P1OuttaTimeSound".play()
		if !p2_turn_timer.is_paused():
	#		if !turns_taken[2]:
				var bar = $"%P2TurnTimerBar"
				bar.value = p2_turn_timer.time_left / turn_time
				if p2_turn_timer.time_left < MIN_TURN_TIME:
					bar.visible = Utils.wave(-1, 1, 0.064) > 0
					if p2_different_text and you_id == 2:
						if Global.enable_timer_sound and (round(p2_turn_timer.time_left) == MIN_TURN_TIME):
							if !chess_timer or !p2_time_run_out:
								p2_time_run_out = true
								$"%P2OuttaTimeSound".play()
#	if !is_instance_valid(game):
#		reset_ui()
#	else:
#		$"%HudLayer".show()

	if Input.is_action_just_pressed("pause"):
		pause()

	var advantage_label = $"%AdvantageLabel"
#	advantage_label.text = ""
	var ghost_game = get_parent().ghost_game
	if is_instance_valid(game):
		if game.game_paused:
			if is_instance_valid(ghost_game):
				var you = ghost_game.get_player(you_id)
				var opponent = ghost_game.get_player(opponent_id)
				
				var advantage = 0
				var block_advantage = 0
				
				block_advantage = -you.blocked_hitbox_plus_frames + opponent.blocked_hitbox_plus_frames

				if you.ghost_ready_tick != null and opponent.ghost_ready_tick != null:
					advantage = opponent.ghost_ready_tick - you.ghost_ready_tick

				if advantage >= 0:
					advantage_label.set("custom_colors/font_color", Color("1d8df5"))
					advantage_label.text = "frame advantage: +" + str(advantage)
				else:
					advantage_label.set("custom_colors/font_color", Color("ff333d"))
					advantage_label.text = "frame advantage: " + str(advantage)
				if advantage == 0:
					advantage_label.text = ""

				if block_advantage > 0:
					block_advantage_label.set("custom_colors/font_color", Color("94e4ff"))
					block_advantage_label.text = "block advantage: +" + str(block_advantage)
					
				elif block_advantage < 0:
					block_advantage_label.set("custom_colors/font_color", Color("ff7a81"))
					block_advantage_label.text = "block advantage: " + str(block_advantage)
				else:
					block_advantage_label.text = ""
					pass

		else:
			advantage_label.text = ""
			block_advantage_label.text = ""
	
		if !ReplayManager.playback:
			var p1 = game.get_player(1)
			var p2 = game.get_player(2)
			var combo = p1.combo_count > 0 or p2.combo_count > 0
			var trade = p1.combo_count > 0 and p2.combo_count > 0
			var initiative = !combo and p1.state_interruptable and p2.state_interruptable and !p1.busy_interrupt and !p2.busy_interrupt
			neutral_label.text = (("<-COMBO" if game.get_player(1).combo_count > 0 else " COMBO->") if combo else ("BUSY" if !initiative else "NEUTRAL")) if !trade else "TRADE"
			neutral_label.rect_position.x = 0 if combo else 1
			neutral_label.set("custom_colors/font_color", ((Color("1d8df5") if p1.combo_count > 0 else Color("ff333d")) if combo else Color.darkgray) if !trade else Color("c735d4"))
			neutral_label.modulate.a = 1.0 if combo else 0.5 if !initiative else 1.0
		else:
			neutral_label.text = ""
	$"%P1SuperContainer".rect_min_size.y = 50 if !p1_action_buttons.visible else 0
	$"%P2SuperContainer".rect_min_size.y = 50 if !p2_action_buttons.visible else 0
	$"%TopInfo".visible = is_instance_valid(game) and !ReplayManager.playback and game.is_waiting_on_player() and !Network.multiplayer_active and !game.game_finished and !Network.rematch_menu
	$"%TopInfoMP".visible = is_instance_valid(game) and !ReplayManager.playback and game.is_waiting_on_player() and Network.multiplayer_active and !game.game_finished and !Network.rematch_menu
	$"%TopInfoReplay".visible = is_instance_valid(game) and ReplayManager.playback and !game.game_finished and !Network.rematch_menu
	$"%HelpButton".visible = is_instance_valid(game) and game.game_paused
	$"%ResetZoomButton".visible = is_instance_valid(game) and game.camera_zoom != 1.0 and game.game_paused
	if is_instance_valid(game) and !Network.multiplayer_active:
		$"%ReplayControls".show()
	else:
		$"%ReplayControls".hide()
#	if $"%TopInfoMP".visible and !actionable:
#		on_player_actionable()
	$"%SoftlockResetButton".visible = false
	if Network.multiplayer_active and is_instance_valid(game):
		var my_action_buttons = p1_action_buttons if Network.player_id == 1 else p2_action_buttons
		$"%SoftlockResetButton".visible = (!my_action_buttons.visible or my_action_buttons.get_node("%SelectButton").disabled) and actionable_time > 5 and !(game.game_finished or ReplayManager.playback) and !SteamLobby.SPECTATING
		if !$"%SoftlockResetButton".visible:
			$"%SoftlockResetButton".disabled = false

		if !my_action_buttons.visible or my_action_buttons.get_node("%SelectButton").disabled:
			actionable_time += delta
		else:
			actionable_time = 0

func set_lobby_settings(settings):
	$"%CharacterSelect".lobby_match_settings = settings
	pass

func start_timers():
	yield(get_tree().create_timer(0.25), "timeout")
	if actionable:
		p1_turn_timer.paused = false
		p2_turn_timer.paused = false
		for timer in turn_timers.values():
			timer.paused = false

func _on_ClearParticlesButton_pressed():
	if is_instance_valid(game):
		for particle in game.effects:
			particle.hide()
		if game.get_player(1).aura_particle:
			game.get_player(1).aura_particle.restart()
		if game.get_player(2).aura_particle:
			game.get_player(2).aura_particle.restart()
	pass # Replace with function body.


func _on_RoadmapButton_toggled(button_pressed):
	$"%RoadmapListContainer".visible = button_pressed
	pass # Replace with function body.


func _on_WorkshopUploader_pressed():
	on_workshop_uploader_clicked()
	pass # Replace with function body.

onready var multiHustle_UISelectors = $"%MHCharSelectors"
var spacebar_handler

var player_time_run_out:Dictionary = {}

var main

var turn_timers = {}

func _on_game_playback_requested():
	if Network.multiplayer_active and not ReplayManager.resimulating:
		$PostGameButtons.show()
		# Rematch button will probably cause issues, so it's disabled
		#if not quit_on_rematch and not SteamLobby.SPECTATING:
			#$"%RematchButton".show()
		Network.rematch_menu = true


func sync_timer(player_id):
	Network.log_to_file("Syncing time for player id " + str(player_id))
	if Network.multiplayer_active:
		if player_id == Network.player_id:
			Network.log_to_file("syncing timer")
			var timer = turn_timers[player_id]
			Network.sync_timer(player_id, timer.time_left)

func _on_sync_timer_request(id, time):
	if not chess_timer:
		return
	var timer = turn_timers[id]
	var paused = timer.paused
	timer.start(time)
	timer.paused = paused

func id_to_action_buttons(player_id):
	if multiHustle_UISelectors.selects[1][0].active_char_index == player_id:
		return $"%P1ActionButtons"
	if multiHustle_UISelectors.selects[2][0].active_char_index == player_id:
		return $"%P2ActionButtons"
	# Emergency Fallback
	if player_id == 1:
		return $"%P1ActionButtons"
	if player_id == 2:
		return $"%P2ActionButtons"
	return null

func _on_player_turn_ready(player_id):
	turn_timers[player_id].paused = true
	if not is_instance_valid(game):
		return 
	lock_in_tick = game.current_tick
	if player_id != Network.player_id or SteamLobby.SPECTATING:
		$"%TurnReadySound".play()

	game.turns_taken[player_id] = true

func setup_action_buttons():
	$"%P1ActionButtons".init(game, GetRealID(1))
	$"%P2ActionButtons".init(game, GetRealID(2))

func silent_end_turn_for(player_id):
	turn_timers[player_id].paused = true
	game.turns_taken[player_id] = true

func end_turn_for(player_id):
	player_id = GetRealID(player_id)
	turn_timers[player_id].paused = true
	$"%TurnReadySound".play()
	game.turns_taken[player_id] = true
	if player_id == Network.player_id:
		sync_timer(player_id)
func end_turn_for_real(player_id):
	turn_timers[player_id].paused = true
	$"%TurnReadySound".play()
	game.turns_taken[player_id] = true
	if player_id == Network.player_id:
		sync_timer(player_id)

func _on_turn_timer_timeout(player_id):
	Network.log_to_file("Player " + str(player_id) + " timed out")
	if player_id == Network.player_id:
		if GetRealID(1) == Network.player_id:
			$"%P1ActionButtons".timeout()
		elif GetRealID(2) == Network.player_id:
			$"%P2ActionButtons".timeout()
		else:
			#Simulate the user selecting themselves on the left side, just so that I can properly call the timeout function.
			multiHustle_UISelectors.selects[1][0].SelectIndex(Network.player_id)
			$"%P1ActionButtons".timeout()

	var timer = turn_timers[player_id]
	timer.wait_time = MIN_TURN_TIME
	timer.start()
	timer.paused = true

func GetRealID(player_id):
	var id =  multiHustle_UISelectors.selects[player_id][0].active_char_index
	if id == 0:
		return player_id
	return id

#Submits a blank action, used for locking all players in at once and locking in dead players
func submit_dummy_action(player_id, action = "Continue", data = null, extras = null):
	if Network.multiplayer_active and player_id == Network.player_id:
		var buttons = $"P1ActionButtons"
		
		if !buttons:
			return
		
		# This solution is questionable, but it should work? This is just to lock in automatically when the local player is dead
		buttons._on_submit_pressed()
	else:
		.end_turn_for(player_id)
		var fighter = game.get_player(player_id)
		fighter.on_action_selected(action, data, extras)
		game.turns_taken[player_id] = true
		Network.turns_ready[player_id] = true

func ContinueAll():
	if !Network.multiplayer_active:
		for index in game.players.keys():
			if game.turns_taken[index] == false:
				if self.main.player_ghost_actions.has(index):
					submit_dummy_action(index, self.main.player_ghost_actions[index], self.main.player_ghost_datas[index], self.main.player_ghost_extras[index])
				else:
					submit_dummy_action(index)

func on_player_actionable():
	Network.action_submitted = false
	multiHustle_UISelectors.ResetGhosts()
	for index in game.players.keys():
		var player = game.players[index]
		if player.game_over:
			submit_dummy_action(index, "ContinueAuto")
		else:
			game.turns_taken[index] = false
			Network.turns_ready[index] = false
	if actionable and (Network.multiplayer_active and not Network.undo and not Network.auto):
		return 
	while is_instance_valid(game) and not game.game_paused:
		yield (get_tree(), "idle_frame")
	Network.undo = false
	Network.auto = false
	actionable = true
	actionable_time = 0
	if Network.multiplayer_active or SteamLobby.SPECTATING:
		while not (Network.can_open_action_buttons):
			yield (get_tree(), "physics_frame")
		if not game_started:
			p1_turn_timer.start()
			p2_turn_timer.start()
			game_started = true
		else :
			if not chess_timer:
				p1_turn_timer.start(turn_time)
				p2_turn_timer.start(turn_time)
			else :
				if p1_turn_timer.time_left < MIN_TURN_TIME:
					p1_turn_timer.start(MIN_TURN_TIME)
				if p2_turn_timer.time_left < MIN_TURN_TIME:
					p2_turn_timer.start(MIN_TURN_TIME)
				if is_instance_valid(game):
					MIN_TURN_TIME = game.match_data.turn_min_length
		p1_turn_timer.paused = false
		p2_turn_timer.paused = false
		$"%P1TurnTimerBar".show()
		$"%P2TurnTimerBar".show()
	$"%P1ActionButtons".re_init(GetRealID(1))
	$"%P2ActionButtons".re_init(GetRealID(2))
	if is_instance_valid(game):
		game.is_in_replay = false
	$"%AdvantageLabel".text = ""
	if Network.multiplayer_active:
		if not chess_timer:
			for timer in turn_timers.values():
				timer.start(turn_time)
		else :
			for timer in turn_timers.values():
				if timer.time_left < MIN_TURN_TIME:
					timer.start(MIN_TURN_TIME)
		for timer in turn_timers.values():
			timer.paused = false
	


func _on_SoftlockResetButton_pressed():
	var team = Network.get_team(Network.player_id)
	var color = Network.get_color(team)
	if Network.game == null:
		return

	var text = ("[color=#%s]" % [color]) + Network.game.player_names[Network.player_id] + "[/color] wants to resync! Press the \"[color=#878787]sync[/color]\" button in chat to accept." 
	Network.rpc_("send_mh_chat_message_preformatted", [text])
	Network.request_softlock_fix()
	$"%SoftlockResetButton".disabled = true
