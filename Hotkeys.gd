extends Node

signal binding_changed(action)

const LOCK_IN = "submit_action"
const WATCH_REPLAY = "playback"
const FRAME_ADVANCE = "frame_advance"
const TOGGLE_FRAME_ADVANCE = "toggle_frame_advance"
const EDIT_REPLAY = "edit_replay"
const PAUSE = "pause"
const FOCUS_NEXT = "ui_focus_next"
const ACCEPT = "ui_accept"
const OPEN_DEBUG_PANEL = "open_debug_panel"

const TOGGLE_HUD = "toggle_hud"
const OPEN_CHAT = "open_chat"
const SEND_CHAT = "send_chat"

const TOGGLE_FREE_CANCEL = "toggle_free_cancel"
const TOGGLE_PREDICTION = "toggle_prediction"
const TOGGLE_HITBOXES = "toggle_hitboxes"
const CLEAR_PARTICLES = "clear_particles"
const TOGGLE_PLAYBACK_CONTROLS = "toggle_playback_controls"
const TOGGLE_PROJECTILE_OWNERS = "toggle_projectile_owners"
const RESET_ZOOM = "reset_zoom"
const PREDICTION_SPEED_1 = "prediction_speed_1"
const PREDICTION_SPEED_2 = "prediction_speed_2"
const PREDICTION_SPEED_3 = "prediction_speed_3"

const RUNTIME_DEFAULTS = {
	TOGGLE_HUD: KEY_F1,
	OPEN_CHAT: KEY_ENTER,
	SEND_CHAT: KEY_ENTER,
	TOGGLE_FREE_CANCEL: 0,
	TOGGLE_PREDICTION: 0,
	TOGGLE_HITBOXES: 0,
	CLEAR_PARTICLES: 0,
	TOGGLE_PLAYBACK_CONTROLS: 0,
	TOGGLE_PROJECTILE_OWNERS: 0,
	RESET_ZOOM: 0,
	PREDICTION_SPEED_1: 0,
	PREDICTION_SPEED_2: 0,
	PREDICTION_SPEED_3: 0,
}

# Actions the user can rebind via the hotkeys settings UI.
# PAUSE/FOCUS_NEXT/ACCEPT/OPEN_DEBUG_PANEL are intentionally omitted - system keys.
const REBINDABLE = [
	{"action": LOCK_IN, "label": "Lock In"},
	{"action": WATCH_REPLAY, "label": "Watch Replay"},
	{"action": EDIT_REPLAY, "label": "Edit Replay"},
	{"action": FRAME_ADVANCE, "label": "Frame Advance"},
	{"action": TOGGLE_FRAME_ADVANCE, "label": "Toggle Frame Advance"},
	{"action": TOGGLE_HUD, "label": "Toggle HUD"},
	{"action": OPEN_CHAT, "label": "Open Chat"},
	{"action": TOGGLE_FREE_CANCEL, "label": "Toggle Free Cancel"},
	{"action": TOGGLE_PREDICTION, "label": "Toggle Prediction"},
	{"action": PREDICTION_SPEED_1, "label": "Prediction Speed x0.25"},
	{"action": PREDICTION_SPEED_2, "label": "Prediction Speed x1"},
	{"action": PREDICTION_SPEED_3, "label": "Prediction Speed x2"},
	{"action": TOGGLE_HITBOXES, "label": "Toggle Hitboxes"},
	{"action": CLEAR_PARTICLES, "label": "Clear Particles"},
	{"action": TOGGLE_PLAYBACK_CONTROLS, "label": "Toggle Playback Controls"},
	{"action": TOGGLE_PROJECTILE_OWNERS, "label": "Toggle Projectile Owners"},
	{"action": RESET_ZOOM, "label": "Reset Zoom"},

]

# ESC is reserved as the "clear binding" gesture during rebind, so it can't be assigned.
const PROTECTED_KEYS = [KEY_ESCAPE]

var defaults = {}
var hovered_xy_plot = null

func _ready():
	for action in RUNTIME_DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var code = RUNTIME_DEFAULTS[action]
			if code != 0:
				var ev = InputEventKey.new()
				ev.scancode = code
				InputMap.action_add_event(action, ev)
	for entry in REBINDABLE:
		defaults[entry.action] = get_bound_scancode(entry.action)
	load_overrides()

func get_display_name(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.get_action_list(action):
		if ev is InputEventKey:
			var code = ev.scancode if ev.scancode != 0 else ev.physical_scancode
			return OS.get_scancode_string(code)
	return ""

func get_bound_scancode(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.get_action_list(action):
		if ev is InputEventKey:
			return ev.scancode if ev.scancode != 0 else ev.physical_scancode
	return 0

func is_protected_key(scancode: int) -> bool:
	return scancode in PROTECTED_KEYS

func clear_binding(action: String):
	if not InputMap.has_action(action):
		return
	for ev in InputMap.get_action_list(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	emit_signal("binding_changed", action)
	save_overrides()

func rebind(action: String, scancode: int) -> bool:
	if is_protected_key(scancode):
		return false
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.get_action_list(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var new_ev = InputEventKey.new()
	new_ev.scancode = scancode
	InputMap.action_add_event(action, new_ev)
	emit_signal("binding_changed", action)
	save_overrides()
	return true

func reset_to_defaults():
	for entry in REBINDABLE:
		var action = entry.action
		var code = defaults.get(action, 0)
		for ev in InputMap.get_action_list(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		if code != 0:
			var new_ev = InputEventKey.new()
			new_ev.scancode = code
			InputMap.action_add_event(action, new_ev)
		emit_signal("binding_changed", action)
	save_overrides()

func save_overrides():
	var data = {}
	for entry in REBINDABLE:
		var action = entry.action
		data[action] = get_bound_scancode(action)
	Global.save_player_data({"hotkeys": data})

func load_overrides():
	var player_data = Global.get_player_data()
	if not (player_data is Dictionary):
		return
	if not ("hotkeys" in player_data):
		return
	var saved = player_data["hotkeys"]
	if not (saved is Dictionary):
		return
	for entry in REBINDABLE:
		var action = entry.action
		if not (action in saved):
			continue
		var code = int(saved[action])
		for ev in InputMap.get_action_list(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		if code != 0:
			var new_ev = InputEventKey.new()
			new_ev.scancode = code
			InputMap.action_add_event(action, new_ev)
