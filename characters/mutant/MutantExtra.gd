extends PlayerExtra

onready var spike_button = $"%DisableSpikeButton"
onready var bloom_button = $"%BloomButton"
onready var juke_button = $"%JukeButton"
onready var juke_dir = $"%JukeDir"

const BLOOM_AVAILABLE_TICK = 7

func _ready():
	spike_button.connect("toggled", self, "_on_data_changed")
	bloom_button.connect("toggled", self, "_on_data_changed")
	juke_button.connect("toggled", self, "_on_data_changed")
	juke_dir.connect("data_changed", self, "_on_data_changed", [null])

func _on_data_changed(_on):
	emit_signal("data_changed")

func show_options():
	spike_button.hide()
	spike_button.set_pressed_no_signal(true)
	bloom_button.hide()
	bloom_button.set_pressed_no_signal(false)
	juke_button.show()
	if fighter.current_state().state_name == "Knockdown" or fighter.current_state().state_name == "HardKnockdown":
		juke_button.hide()
		juke_dir.hide()
		return

	if fighter.current_state().get("disable_aerial_movement"):
		juke_button.hide()
		juke_dir.hide()

	var spike = fighter.obj_from_name(fighter.spike_projectile)
	if spike:
		if spike.get("can_cancel"):
			spike_button.show()

	# Bloom is offered once the gas bomb has been out long enough — reading
	# the projectile's current state tick (it lives in GasBombDefault). Toggle
	# is unpressed by default so the bomb only detonates early on explicit opt-in.
	var bomb = fighter.obj_from_name(fighter.gas_bomb_projectile)
	if bomb and bomb.current_state().current_tick > BLOOM_AVAILABLE_TICK:
		bloom_button.show()

func is_invalid_state(state):
	return state.type == CharacterState.ActionType.Defense or state.state_name == "DashBackward"

func update_selected_move(move_state):
	.update_selected_move(move_state)
	if fighter.current_state().state_name == "Knockdown" or fighter.current_state().state_name == "HardKnockdown":
		juke_button.set_pressed_no_signal(false)
		juke_button.disabled = true
		juke_button.hide()
		juke_dir.hide()
		return
	juke_button.disabled = fighter.juke_pips < 1
	if move_state is CharacterState:
		if is_invalid_state(move_state):
			juke_button.set_pressed_no_signal(false)
			juke_button.disabled = true
	elif is_invalid_state(fighter.current_state()):
		juke_button.set_pressed_no_signal(false)
		juke_button.disabled = true
	
	var air_juke = move_state and move_state.get("force_air_juke")
	var allow_down = move_state and move_state.get("force_air_juke_allow_down")
	var different = ((juke_dir.S or juke_dir.N) != air_juke)
	juke_dir.set_S(!fighter.is_grounded() or allow_down)
	juke_dir.set_SW(!fighter.is_grounded() or allow_down)
	juke_dir.set_SE(!fighter.is_grounded() or allow_down)
#	juke_dir.set_Neutral(!fighter.is_grounded())
	juke_dir.set_N((!fighter.is_grounded() and fighter.air_movements_left > 0) or air_juke)
	juke_dir.set_NE((!fighter.is_grounded() and fighter.air_movements_left > 0) or air_juke)
	juke_dir.set_NW((!fighter.is_grounded() and fighter.air_movements_left > 0) or air_juke)
	juke_dir.call_deferred("try_hide_sections")
	
	juke_button.visible = fighter.juke_pips >= 1 and fighter.opponent.combo_count <= 0
	juke_dir.visible = fighter.juke_pips >= 1 and fighter.opponent.combo_count <= 0

	var can_afford_side = fighter.juke_pips >= 2
	var back_cost = 2 if fighter.combo_count > 0 else 3
	var can_afford_back = fighter.juke_pips >= back_cost
	var opponent_right = fighter.get_opponent_dir() > 0
	if opponent_right:
		juke_dir.set_E(can_afford_side)
		juke_dir.set_W(can_afford_back)
	else:
		juke_dir.set_W(can_afford_side)
		juke_dir.set_E(can_afford_back)
	if !can_afford_side:
		juke_dir.set_N(false)
		juke_dir.set_S(false)
		if opponent_right:
			juke_dir.set_NE(false)
			juke_dir.set_SE(false)
		else:
			juke_dir.set_NW(false)
			juke_dir.set_SW(false)
	if !can_afford_back:
		if opponent_right:
			juke_dir.set_NW(false)
			juke_dir.set_SW(false)
		else:
			juke_dir.set_NE(false)
			juke_dir.set_SE(false)

	if juke_dir.pressed_button and juke_dir.pressed_button.disabled:
		juke_dir.set_sensible_default(juke_dir.pressed_button.name, false)

	if fighter.current_state().get("disable_aerial_movement"):
		juke_button.hide()
		juke_dir.hide()
	
	var current = juke_dir.pressed_button.name

	if different and fighter.is_grounded():
		if !(current == "E" or current == "W"): 
			juke_dir.set_sensible_default(juke_dir.pressed_button.name, false)
		pass

	if $"%JukeButton".disabled:
		$"%JukeButton".set_pressed_no_signal(false)

func get_extra():
	var juke_data = juke_dir.get_data() if juke_button.pressed and juke_button.is_visible_in_tree() else null
	var is_back_juke = false
	if juke_data and juke_dir.pressed_button:
		var btn = juke_dir.pressed_button.name
		if fighter.get_opponent_dir() > 0:
			is_back_juke = "W" in btn
		else:
			is_back_juke = "E" in btn
	var extra = {
		"spike_enabled": spike_button.pressed,
		"bloom": bloom_button.pressed and bloom_button.is_visible_in_tree(),
		"juke_dir": juke_data,
		"back_juke": is_back_juke
	}
	return extra

func reset():
	spike_button.set_pressed_no_signal(true)
	bloom_button.set_pressed_no_signal(false)
	juke_button.set_pressed_no_signal(false)
#	juke_dir.hide()

func _on_JukeButton_toggled(button_pressed):
#	if !button_pressed:
#		juke_dir.set_sensible_default("Neutral")
	pass
	
func _on_JukeDir_data_changed():
	$"%JukeButton".set_pressed_no_signal($"%JukeButton".visible)
	if $"%JukeButton".disabled:
		$"%JukeButton".set_pressed_no_signal(false)
