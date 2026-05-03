extends CanvasLayer

onready var p1_action_buttons = $"%P1ActionButtons"
onready var p2_action_buttons = $"%P2ActionButtons"

signal singleplayer_started()
signal multiplayer_started()
signal loaded_replay(match_data)
signal replay_picked_for_challenge(match_data, path)
signal received_synced_time()

var replay_picker_for_challenge = false
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
	$"%EnableReplayBackups": "enable_replay_backups",
	$"%XYPlotInvertSnapButton": "xyplot_invert_snap",
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
	if Global.winws_detected:
#		$"%MultiplayerButton".disabled = true
		$"%SteamMultiplayerButton".disabled = true
		$"%WinwsLabel".show()
	
	$"%SingleplayerButton".connect("pressed", self, "_on_singleplayer_pressed")
	$"%MultiplayerButton".connect("pressed", self, "_on_multiplayer_pressed")
	$"%SteamMultiplayerButton".connect("pressed", self, "_on_steam_multiplayer_pressed")
	$"%CustomizeButton".connect("pressed", self, "_on_customize_pressed")
	$"%DirectConnectButton".connect("pressed", self, "_on_direct_connect_button_pressed")
	$"%RematchButton".connect("pressed", self, "_on_rematch_button_pressed")
	$"%QuitButton".connect("pressed", self, "_on_quit_button_pressed")
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
	$"%ShowBackupReplays".connect("pressed", self, "_on_view_replays_button_pressed")
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
	update_help_text()
	Hotkeys.connect("binding_changed", self, "_on_hotkey_changed")
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
	$"%MasterSlider".set_value(Global.master_value)
	AudioServer.set_bus_volume_db(0, linear2db(Global.master_value))
	$"%MasterSlider".connect("value_changed", self, "_on_master_slider_changed")
	$"%FXSlider".set_value(Global.fx_value)
	AudioServer.set_bus_volume_db(1, linear2db(Global.fx_value))
	$"%FXSlider".connect("value_changed", self, "_on_fx_slider_changed")
	$"%UISlider".set_value(Global.ui_value)
	AudioServer.set_bus_volume_db(2, linear2db(Global.ui_value))
	$"%UISlider".connect("value_changed", self, "_on_ui_slider_changed")
	$"%MusicSlider".set_value(Global.music_value)
	AudioServer.set_bus_volume_db(3, linear2db(Global.music_value))
	$"%MusicSlider".connect("value_changed", self, "_on_music_slider_changed")
#	$"%LightModeButton".set_pressed_no_signal(Global.light_mode)
#	$"%LightModeButton".connect("toggled", self, "_on_light_mode_toggled")
	$"%FullscreenButton".set_pressed_no_signal(Global.fullscreen)
	$"%FullscreenButton".connect("toggled", self, "_on_fullscreen_button_toggled")
	$"%HitboxesButton".set_pressed_no_signal(Global.show_hitboxes)
	$"%HitboxesButton".connect("toggled", self, "_on_hitboxes_button_toggled")
	$"%CapFramerateButton".set_pressed_no_signal(Global.cap_framerate)
	$"%CapFramerateButton".connect("toggled", self, "_on_cap_framerate_button_toggled")
	$"%PlaybackControls".set_pressed_no_signal(Global.show_playback_controls)
	$"%PlaybackControls".connect("toggled", self, "_on_playback_controls_button_toggled")
	$"%PredictionSettingsOpenButton".connect("pressed", self, "_on_open_prediction_settings_pressed")
	$"%PredictionSettingsCloseButton".connect("pressed", self, "_on_close_prediction_settings_pressed")
#	$"%BGColor".color = dark_mode_color
#	if Global.light_mode:
#		$"%BGColor".color = light_mode_color
	if !SteamHustle.STARTED:
		pass
#		$"%SteamMultiplayerButton".hide()
#		$"%WishlistButton".show()
#		$"%RoadmapContainer".hide()
#		$"%CustomizeButton".hide()
#		$"%SteamBetaReplayTip".hide()
#		$"%CustomizeButton".hide()
#		$"%EnableStyleColorsButton".hide()
#		$"%EnableAurasButton".hide()
#		$"%EnableHitsparksButton".hide()
	else:
		$"%WishlistButton".hide()
		$"%RoadmapContainer".show()
#		$"%MultiplayerButton".text = "Multiplayer (Legacy)"
	
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

func _on_master_slider_changed(value):
	AudioServer.set_bus_volume_db(0, linear2db(value))
	$"%OptionsSoundPlayer".bus = "Master"
	$"%OptionsSoundPlayer".pitch_variation = 0
	$"%OptionsSoundPlayer".streams = [load("res://sound/ui/button_hover3.wav")]
	$"%OptionsSoundPlayer".play()
	Global.master_value = value
	Global.save_options()

func _on_fx_slider_changed(value):
	AudioServer.set_bus_volume_db(1, linear2db(value))
	$"%OptionsSoundPlayer".bus = "Fx"
	$"%OptionsSoundPlayer".pitch_variation = 0.1
	$"%OptionsSoundPlayer".streams = [load("res://sound/common/explosion2.wav")]
	$"%OptionsSoundPlayer".play()
	Global.fx_value = value
	Global.save_options()

func _on_ui_slider_changed(value):
	AudioServer.set_bus_volume_db(2, linear2db(value))
	$"%OptionsSoundPlayer".bus = "UI"
	$"%OptionsSoundPlayer".pitch_variation = 0
	$"%OptionsSoundPlayer".streams = [load("res://sound/ui/button_hover3.wav")]
	$"%OptionsSoundPlayer".play()
	Global.ui_value = value
	Global.save_options()

func _on_music_slider_changed(value):
	AudioServer.set_bus_volume_db(3, linear2db(value))
	$"%OptionsSoundPlayer".bus = "UI"
	$"%OptionsSoundPlayer".pitch_variation = 0
	$"%OptionsSoundPlayer".streams = [load("res://sound/ui/button_hover3.wav")]
	$"%OptionsSoundPlayer".play()
	Global.music_value = value
	Global.save_options()

func _on_fullscreen_button_toggled(on):
	Global.set_fullscreen(on)

func _on_hitboxes_button_toggled(on):
	Global.set_hitboxes(on)

func _on_cap_framerate_button_toggled(on):
	Global.set_cap_framerate(on)

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
	var replay_map = ReplayManager.load_replays($"%ShowAutosavedReplays".pressed, $"%ShowBackupReplays".pressed)
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

func _set_prediction_speed(speed: int):
	var btn = get_node_or_null("%%%dSpeed" % speed)
	if btn:
		btn.emit_signal("pressed")

func set_turn_time(time, minutes=false):
#	print("setting turn time to " + str(time))
	p1_turn_time = time * (60 if minutes else 1)
	p2_turn_time = time * (60 if minutes else 1)
	turn_time = time * (60 if minutes else 1)
	p1_turn_timer.wait_time = p1_turn_time
	p2_turn_timer.wait_time = p2_turn_time

func sort_replays(a, b):
	return a.modified > b.modified

func _on_replay_button_pressed(path):
	var match_data = ReplayManager.load_replay(path)
	$"%ReplayWindow".hide()
	if replay_picker_for_challenge:
		replay_picker_for_challenge = false
		$"%ReplayChallengeTitle".hide()
		$"%SteamLobby".show()
		emit_signal("replay_picked_for_challenge", match_data, path)
		return
	emit_signal("loaded_replay", match_data)

func _on_replay_cancel_pressed():
	if replay_picker_for_challenge:
		replay_picker_for_challenge = false
		$"%ReplayWindow".hide()
		$"%ReplayChallengeTitle".hide()
		$"%SteamLobby".show()
		return
	Global.reload()

func open_replay_picker_for_challenge(opponent_name=""):
	replay_picker_for_challenge = true
	if opponent_name == "":
		$"%ReplayChallengeTitle".text = "Select a replay to resume with"
	else:
		$"%ReplayChallengeTitle".text = "Select a replay to resume with " + opponent_name
	$"%ReplayChallengeTitle".show()
	$"%SteamLobby".hide()
	load_replays()

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

func _on_sync_timer_request(id, time):
	if !chess_timer:
		return
	if id == 1:
		var paused = p1_turn_timer.paused
		p1_turn_timer.start(time)
		p1_turn_timer.paused = paused
		received_synced_time = true
		emit_signal("received_synced_time")
	elif id == 2:
		var paused = p2_turn_timer.paused
		p2_turn_timer.start(time)
		p2_turn_timer.paused = paused
		received_synced_time = true
		emit_signal("received_synced_time")

func get_chess_timer_state():
	if !chess_timer:
		return null
	return {
		"p1_time_left": p1_turn_timer.time_left,
		"p2_time_left": p2_turn_timer.time_left,
		"turn_time": turn_time,
	}

func restore_chess_timer_state(state):
	if !state or !chess_timer:
		return
	if state.has("p1_time_left"):
		var paused = p1_turn_timer.paused
		p1_turn_timer.start(state.p1_time_left)
		p1_turn_timer.paused = paused
	if state.has("p2_time_left"):
		var paused = p2_turn_timer.paused
		p2_turn_timer.start(state.p2_time_left)
		p2_turn_timer.paused = paused

func sync_timer(player_id):
	if Network.multiplayer_active:
		if player_id == Network.player_id:
			print("syncing timer")
			var timer = p1_turn_timer
			if player_id == 2:
				timer = p2_turn_timer
			Network.sync_timer(player_id, timer.time_left)

func id_to_action_buttons(player_id):
	if player_id == 1:
		return $"%P1ActionButtons"
	else:
		return $"%P2ActionButtons"

func init(game):
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

func _on_player_turn_ready(player_id):
	if !is_instance_valid(game):
		return
	lock_in_tick = game.current_tick
	if player_id != Network.player_id or SteamLobby.SPECTATING:
		$"%TurnReadySound".play()

	turns_taken[player_id] = true
	if player_id == 1:
		$"%P1TurnTimerBar".hide()
#		p1_turn_timer.stop()
		p1_turn_timer.paused = true

	elif player_id == 2:
		$"%P2TurnTimerBar".hide()
#		p2_turn_timer.stop()
		p2_turn_timer.paused = true
	
func _on_rematch_button_pressed():
	Network.request_rematch()
	$"%RematchButton".disabled = true

func _on_game_playback_requested():
	if Network.multiplayer_active and !ReplayManager.resimulating:
		$PostGameButtons.show()
		if !quit_on_rematch and !SteamLobby.SPECTATING:
			$"%RematchButton".show()
		Network.rematch_menu = true

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

func end_turn_for(player_id):
	$"%TurnReadySound".play()
	turns_taken[player_id] = true
	if player_id == Network.player_id:
		sync_timer(player_id)
	if player_id == 1:
		$"%P1TurnTimerBar".hide()
#		p1_turn_timer.stop()
		p1_turn_timer.paused = true

	elif player_id == 2:
		$"%P2TurnTimerBar".hide()
#		p2_turn_timer.stop()
		p2_turn_timer.paused = true
	if Network.rematch_menu:
		hide_rematch_menu()

func setup_action_buttons():
	$"%P1ActionButtons".init(game, 1)
	$"%P2ActionButtons".init(game, 2)
	
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

func on_player_actionable():
	if actionable and (Network.multiplayer_active and !Network.undo and !Network.auto):
		return
	while is_instance_valid(game) and !game.game_paused:
		yield(get_tree(), "idle_frame")
	Network.undo = false
	Network.auto = false
	actionable = true
	actionable_time = 0
#	yield(Network, "both_players_actionable")
#	if p1_turn_timer.wait_time == 0:
#		p1_turn_timer.wait_time = MIN_TURN_TIME
#	if p2_turn_timer.wait_time == 0:
#		 p2_turn_timer.wait_time = MIN_TURN_TIME
	if Network.multiplayer_active or SteamLobby.SPECTATING:
#		Network.rpc_("my_turn_started")
		var wait_start = OS.get_ticks_msec()
		while !(Network.can_open_action_buttons):
			if OS.get_ticks_msec() - wait_start > 3000 and !SteamLobby.SPECTATING:
				print("button-open watchdog: stuck waiting >3s, resending end_turn_simulation")
				if is_instance_valid(game):
					Network.rpc_("end_turn_simulation", [game.current_tick, Network.player_id])
				wait_start = OS.get_ticks_msec()
			yield(get_tree(), "physics_frame")

		print("starting turn timer")
#		if $"%P1ActionButtons".any_available_actions and $"%P2ActionButtons".any_available_actions:
		if !game_started:
#		if p1_turn_timer.is_stopped():
			if chess_timer:
				if is_instance_valid(game):
					MIN_TURN_TIME = game.match_data.turn_min_length
			p1_turn_timer.start()
			p2_turn_timer.start()
			game_started = true
		else:
			if !chess_timer:
				p1_turn_timer.start(turn_time)
				p2_turn_timer.start(turn_time)
			else:
				if p1_turn_timer.time_left < MIN_TURN_TIME:
					p1_turn_timer.start(MIN_TURN_TIME)
				if p2_turn_timer.time_left < MIN_TURN_TIME:
					p2_turn_timer.start(MIN_TURN_TIME)


		p1_turn_timer.paused = false
		p2_turn_timer.paused = false
#		if game.current_tick != timer_sync_tick:
#			timer_sync_tick = game.current_tick
#			sync_timer(Network.player_id)
#			if !received_synced_time:
#				yield(self, "received_synced_time")
#				received_synced_time = false
		$"%P1TurnTimerBar".show()
		$"%P2TurnTimerBar".show()

#	$"%P1SuperContainer".rect_min_size.y = 40
#	$"%P2SuperContainer".rect_min_size.y = 40
	$"%P1ActionButtons".activate()
	$"%P2ActionButtons".activate()
	if is_instance_valid(game):
		game.is_in_replay = false
	$"%AdvantageLabel".text = ""

#		else:
#			turn_timer.start(turn_time)

func _on_turn_timer_timeout(player_id):
		if player_id == 1:
			if Network.player_id == player_id:
				$"%P1ActionButtons".timeout()
				p1_turn_timer.wait_time = MIN_TURN_TIME
				p1_turn_timer.start()
				p1_turn_timer.paused = true
		else:
			if Network.player_id == player_id:
				$"%P2ActionButtons".timeout()
				p1_turn_timer.wait_time = MIN_TURN_TIME
				p1_turn_timer.start()
				p1_turn_timer.paused = true
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

func _on_hotkey_changed(_action):
	update_help_text()

func update_help_text():
	$"%TopInfo".text = _format_help([
		[Hotkeys.LOCK_IN, "Lock in"],
		[Hotkeys.WATCH_REPLAY, "Watch replay"],
		[Hotkeys.PAUSE, "Open menu"],
		[Hotkeys.TOGGLE_HUD, "Toggle HUD"],
	])
	$"%TopInfoMP".text = _format_help([
		[Hotkeys.LOCK_IN, "Lock in"],
		[Hotkeys.PAUSE, "Open menu"],
		[Hotkeys.OPEN_CHAT, "Chat"],
		[Hotkeys.TOGGLE_HUD, "Toggle HUD"],
	])
	$"%TopInfoReplay".text = _format_help([
		[Hotkeys.WATCH_REPLAY, "Watch replay"],
		[Hotkeys.EDIT_REPLAY, "Edit replay"],
		[Hotkeys.PAUSE, "Open menu"],
		[Hotkeys.TOGGLE_HUD, "Toggle HUD"],
	])

func _format_help(entries: Array) -> String:
	var parts = []
	for entry in entries:
		var key_name = Hotkeys.get_display_name(entry[0])
		if key_name == "":
			continue
		parts.append("%s: %s" % [key_name, entry[1]])
	return PoolStringArray(parts).join(" - ")

func _unhandled_input(event):
	if event.is_action_pressed(Hotkeys.OPEN_CHAT):
		if is_instance_valid(game):
			$"%ChatWindow".show()
			$"%ChatWindow".line_edit_focus()
	if event.is_action_pressed(Hotkeys.TOGGLE_HUD):
		visible = !visible
		$"../HudLayer/HudLayer".visible = ! $"../HudLayer/HudLayer".visible
		$"../GhostLayer".visible = visible
		Global.ui_hidden = !visible
	if event.is_action_pressed(Hotkeys.TOGGLE_FREE_CANCEL):
		_toggle_free_cancel()
	if event.is_action_pressed(Hotkeys.TOGGLE_PREDICTION):
		_toggle_prediction()
	if event.is_action_pressed(Hotkeys.TOGGLE_HITBOXES):
		_toggle_hitboxes()
	if event.is_action_pressed(Hotkeys.CLEAR_PARTICLES):
		_on_ClearParticlesButton_pressed()
	if event.is_action_pressed(Hotkeys.TOGGLE_PLAYBACK_CONTROLS):
		_toggle_playback_controls()
	if event.is_action_pressed(Hotkeys.TOGGLE_PROJECTILE_OWNERS):
		_toggle_projectile_owners()
	if event.is_action_pressed(Hotkeys.RESET_ZOOM):
		_on_reset_zoom_pressed()
	if event.is_action_pressed(Hotkeys.PREDICTION_SPEED_1):
		_set_prediction_speed(1)
	if event.is_action_pressed(Hotkeys.PREDICTION_SPEED_2):
		_set_prediction_speed(2)
	if event.is_action_pressed(Hotkeys.PREDICTION_SPEED_3):
		_set_prediction_speed(3)
	_handle_xy_nudge(event)
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

func hide_rematch_menu():
	Network.rematch_menu = false
	var post_game_buttons = get_node_or_null("%PostGameButtons")
	var disconnected_label = get_node_or_null("%OpponentDisconnectedLabel")
	if post_game_buttons:
		post_game_buttons.hide()
	if disconnected_label:
		disconnected_label.hide()

func _process(delta):

	if chess_timer and is_instance_valid(game) and game.match_data:
		game.match_data["chess_timer_state"] = {
			"p1_time_left": p1_turn_timer.time_left,
			"p2_time_left": p2_turn_timer.time_left,
			"turn_time": turn_time,
		}

	var p1_old_text = $"%P1TurnTimerLabel".text
	$"%P1TurnTimerLabel".text = time_convert(int(floor(p1_turn_timer.time_left)))
	var p1_different_text = p1_old_text != $"%P1TurnTimerLabel".text

	var p2_old_text = $"%P2TurnTimerLabel".text
	$"%P2TurnTimerLabel".text = time_convert(int(floor(p2_turn_timer.time_left)))
	var p2_different_text = p2_old_text != $"%P2TurnTimerLabel".text

	if $"%VersionLabel".visible:
		$"%VersionLabel".text = "version " + Global.VERSION

	if Network.undo and Network.rematch_menu:
		hide_rematch_menu()

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

func _on_SoftlockResetButton_pressed():
	Network.rpc_("send_chat_message", [Network.player_id, "-- wants to resync."])
	Network.request_softlock_fix()
	$"%SoftlockResetButton".disabled = true
	pass # Replace with function body.



func _on_ClearParticlesButton_pressed():
	if is_instance_valid(game):
		for particle in game.effects:
			particle.hide()
		for p in game.get_player(1).aura_particles:
			if is_instance_valid(p):
				p.restart()
		for p in game.get_player(2).aura_particles:
			if is_instance_valid(p):
				p.restart()
	pass # Replace with function body.


func _on_RoadmapButton_toggled(button_pressed):
	$"%RoadmapListContainer".visible = button_pressed
	pass # Replace with function body.


# --- More Hotkeys handlers --------------------------------------------------

func _toggle_free_cancel():
	if not is_instance_valid(game):
		return
	var targets = []
	if Network.multiplayer_active:
		targets.append(p1_action_buttons if Network.player_id == 1 else p2_action_buttons)
	else:
		targets = [p1_action_buttons, p2_action_buttons]
	for ab in targets:
		var feint_btn = ab.get_node("%FeintButton")
		if not feint_btn.disabled:
			feint_btn.pressed = !feint_btn.pressed
			ab.send_ui_action()

func _toggle_prediction():
	var btn = get_node_or_null("%GhostButton")
	if btn:
		btn.set_pressed(!btn.pressed)

func _toggle_hitboxes():
	Global.show_hitboxes = !Global.show_hitboxes
	$"%HitboxesButton".set_pressed_no_signal(Global.show_hitboxes)
	Global.save_options()

func _toggle_playback_controls():
	Global.show_playback_controls = !Global.show_playback_controls
	$"%PlaybackControls".set_pressed_no_signal(Global.show_playback_controls)
	Global.save_options()
	if is_instance_valid(game) and not Network.multiplayer_active:
		$"%ReplayControls".visible = Global.show_playback_controls

func _toggle_projectile_owners():
	Global.show_projectile_owners = !Global.show_projectile_owners
	$"%ProjectileOwnersButton".set_pressed_no_signal(Global.show_projectile_owners)
	Global.save_options()


# --- XY plot arrow-key nudging (not rebindable) -----------------------------

func _handle_xy_nudge(event):
	if not is_instance_valid(Hotkeys.hovered_xy_plot):
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var nudge = null
	match event.scancode:
		KEY_LEFT: nudge = Vector2(-0.01, 0)
		KEY_RIGHT: nudge = Vector2(0.01, 0)
		KEY_UP: nudge = Vector2(0, -0.01)
		KEY_DOWN: nudge = Vector2(0, 0.01)
	if nudge == null:
		return
	var plot = Hotkeys.hovered_xy_plot
	var new_value = plot.value_float + nudge * plot.panel_radius
	new_value = new_value.limit_length(plot.panel_radius)
	plot.update_value(new_value, true, true)
	plot.emit_signal("data_changed")


func _on_WorkshopUploader_pressed():
	on_workshop_uploader_clicked()
	pass # Replace with function body.
