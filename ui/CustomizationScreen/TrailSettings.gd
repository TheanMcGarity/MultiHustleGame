extends VBoxContainer

const ATTACH_LIMB_NONE := "(none)"
const ATTACH_LIMB_OPTIONS := [
	ATTACH_LIMB_NONE,
	"Head",
	"LeftHand", "RightHand", "Hands",
	"LeftFoot", "RightFoot", "Feet",
]
# Old attach_limb values that map to the simplified set above. Body / Upper /
# Lower fall through to "(none)" since there's no anatomical body limb anymore.
const ATTACH_LIMB_MIGRATIONS := {
	"UpperBody": "",
	"LowerBody": "",
	"Body": "",
	"LeftArm": "LeftHand",
	"RightArm": "RightHand",
	"LeftLeg": "LeftFoot",
	"RightLeg": "RightFoot",
}

signal settings_changed(settings)

var start_color := Color.white
var end_color := Color.white

onready var settings_map = {
	$"%Particle Amount": "amount",
	$"%Particle Lifetime": "lifetime",
	$"%InFront": "in_front",
	$"%Local": "local_coords",
	$"%Shape": "shape",
	$"%Speed Scale": "speed_scale",
	$"%DisableOnKO": "disable_on_ko",
	$"%CapFramerate": "cap_framerate",
	$"%Framerate": "framerate",
	$"%DynamicTriggers": "dynamic_triggers",
	$"%TriggerDuringCombo": "trigger_during_combo",
	$"%TriggerDuringComboLinger": "trigger_during_combo_linger",
	$"%TriggerDuringMelee": "trigger_during_melee_attacks",
	$"%TriggerDuringMeleeLinger": "trigger_during_melee_attacks_linger",
	$"%TriggerWhileBeingComboed": "trigger_while_being_comboed",
	$"%TriggerWhileBeingComboedLinger": "trigger_while_being_comboed_linger",
	$"%TriggerLowHealth": "trigger_low_health",
	$"%TriggerLowHealthThreshold": "trigger_low_health_threshold",
	$"%TriggerLowHealthLinger": "trigger_low_health_linger",
	$"%TriggerHighHealth": "trigger_high_health",
	$"%TriggerHighHealthThreshold": "trigger_high_health_threshold",
	$"%TriggerHighHealthLinger": "trigger_high_health_linger",
	$"%TriggerSuperLevel": "trigger_super_level",
	$"%TriggerSuperLevelMin": "trigger_super_level_min",
	$"%TriggerSuperLevelLinger": "trigger_super_level_linger",
	$"%TriggerAfterSpawnProj": "trigger_after_spawn_projectile",
	$"%TriggerAfterSpawnProjDuration": "trigger_after_spawn_projectile_duration",
	$"%TriggerProjectilesActive": "trigger_projectiles_active",
	$"%TriggerProjectilesActiveLinger": "trigger_projectiles_active_linger",
	$"%TriggerAfterTakeDmg": "trigger_after_take_damage",
	$"%TriggerAfterTakeDmgDuration": "trigger_after_take_damage_duration",
	$"%TriggerAfterOppTakeDmg": "trigger_after_opponent_take_damage",
	$"%TriggerAfterOppTakeDmgDuration": "trigger_after_opponent_take_damage_duration",
	$"%TriggerAfterPerfectParry": "trigger_after_perfect_parry",
	$"%TriggerAfterPerfectParryDuration": "trigger_after_perfect_parry_duration",
	$"%TriggerAfterBurst": "trigger_after_burst",
	$"%TriggerAfterBurstDuration": "trigger_after_burst_duration",
	$"%TriggersInverted": "triggers_inverted",
	$"%Explosiveness": "explosiveness",
	$"%Lifetime Randomness": "lifetime_randomness",
	$"%Direction": "direction",
	$"%Direction Spread": "spread",
	$"%Gravity X": "gravity_x",
	$"%Gravity Y": "gravity_y",
	$"%Rect Size X": "rect_size_x",
	$"%Rect Size Y": "rect_size_y",
	$"%Initial Velocity": "initial_velocity",
	$"%Initial Velocity Randomness": "initial_velocity_random", 
	$"%Linear Accel": "linear_accel",
	$"%Linear Accel Randomness": "linear_accel_random",
	$"%Radial Accel": "radial_accel",
	$"%Radial Accel Randomness": "radial_accel_random",
	$"%Tangential Accel": "tangential_accel",
	$"%Tangential Accel Randomness": "tangential_accel_random",
	$"%Orbit Velocity": "orbit_velocity",
	$"%Orbit Velocity Randomness": "orbit_velocity_random",
	$"%Explosiveness": "explosiveness",
	$"%Start Scale": "start_scale",
	$"%End Scale": "end_scale",
	$"%Scale Randomness": "scale_amount_random",
	$"%StartColor": "start_color",
	$"%EndColor": "end_color",
	$"%Start Alpha": "start_alpha",
	$"%End Alpha": "end_alpha",
	$"%X Offset": "x_offset",
	$"%Y Offset": "y_offset",
	$"%Angle": "angle",
	$"%Angle Randomness": "angle_random",
	$"%FlipWithCharacter": "flip_with_character",
}

var nodes_map = {}

var shape_names = []

func load_settings(settings):
	for setting in settings:
		if setting in nodes_map:
			var node = nodes_map[setting]
			var value = settings[setting]
			if value is float and node is SettingsSlider:
				node.set_value(value)
			if value is bool and node is BaseButton:
				node.set_pressed(value)
			if value is Color and node is YomiColorPicker:
				node.set_color(value)
			if (value is int or value is float) and node is SpinBox:
				node.set_value(value)
			if value is Vector2 and node is XYPlot:
				node.set_value_float(value)
	if "shape" in settings:
		var shape = settings["shape"]
		for id in $"%Shape".get_item_count():
			if shape == $"%Shape".get_item_text(id):
				$"%Shape".selected = id
				break
	var attach_limb = settings.get("attach_limb", "")
	if ATTACH_LIMB_MIGRATIONS.has(attach_limb):
		attach_limb = ATTACH_LIMB_MIGRATIONS[attach_limb]
	if attach_limb == "":
		attach_limb = ATTACH_LIMB_NONE
	for id in $"%AttachLimb".get_item_count():
		if attach_limb == $"%AttachLimb".get_item_text(id):
			$"%AttachLimb".selected = id
			break
	if has_node("%MirrorPair"):
		$"%MirrorPair".set_pressed_no_signal(settings.get("attach_pair_mirror", true))
	if has_node("%PositionOnly"):
		# UI says "enable limb rotation" — the inverse of the saved
		# attach_position_only key (kept for backward compat with existing styles).
		$"%PositionOnly".set_pressed_no_signal(not settings.get("attach_position_only", true))
	if has_node("%ConsistentSide"):
		$"%ConsistentSide".set_pressed_no_signal(settings.get("attach_consistent_side", true))
	if has_node("%CapFramerate"):
		_update_framerate_visibility()
	if has_node("%AttachLimb"):
		_update_attach_visibility()
	if has_node("%DynamicTriggers"):
		_update_trigger_visibility()
#			yield(get_tree(), "idle_frame")

const TRIGGER_LABELS = {
	"TriggerDuringComboLinger": "linger duration",
	"TriggerDuringMeleeLinger": "linger duration",
	"TriggerWhileBeingComboedLinger": "linger duration",
	"TriggerLowHealthThreshold": "health %",
	"TriggerLowHealthLinger": "linger duration",
	"TriggerHighHealthThreshold": "health %",
	"TriggerHighHealthLinger": "linger duration",
	"TriggerSuperLevelMin": "min level",
	"TriggerSuperLevelLinger": "linger duration",
	"TriggerAfterSpawnProjDuration": "duration",
	"TriggerAfterTakeDmgDuration": "duration",
	"TriggerAfterOppTakeDmgDuration": "duration",
	"TriggerAfterPerfectParryDuration": "duration",
	"TriggerAfterBurstDuration": "duration",
	"TriggerProjectilesActiveLinger": "linger duration",
}

func _ready():
	var shapes = CustomTrailParticle.get_shapes()
	for shape_name in shapes:
		$"%Shape".add_item(shape_name)
		shape_names.append(shape_name)
	for limb in ATTACH_LIMB_OPTIONS:
		$"%AttachLimb".add_item(limb)
	$"%AttachLimb".connect("item_selected", self, "_on_attach_limb_selected")
	$"%CapFramerate".connect("toggled", self, "_on_cap_framerate_toggled")
	# Driving these labels from code instead of as scene-instance overrides:
	# Godot's editor has dropped `label_text` overrides on TrailSettings.tscn
	# multiple times when the parent SettingsSlider scene is re-saved. Keeping
	# them here makes them invulnerable to that.
	for slider_name in TRIGGER_LABELS:
		var n = get_node_or_null("%" + slider_name)
		if n and n.has_method("set_label_text"):
			n.set_label_text(TRIGGER_LABELS[slider_name])
	for trigger_button_name in [
		"DynamicTriggers",
		"TriggerDuringCombo", "TriggerDuringMelee", "TriggerWhileBeingComboed",
		"TriggerLowHealth", "TriggerHighHealth", "TriggerSuperLevel",
		"TriggerAfterSpawnProj", "TriggerProjectilesActive",
		"TriggerAfterTakeDmg", "TriggerAfterOppTakeDmg",
		"TriggerAfterPerfectParry", "TriggerAfterBurst"
	]:
		get_node("%" + trigger_button_name).connect("toggled", self, "_on_trigger_toggled")
	_update_framerate_visibility()
	_update_attach_visibility()
	_update_trigger_visibility()
	if has_node("%MirrorPair"):
		$"%MirrorPair".connect("toggled", self, "_setting_value_changed")
	if has_node("%PositionOnly"):
		$"%PositionOnly".connect("toggled", self, "_setting_value_changed")
	if has_node("%ConsistentSide"):
		$"%ConsistentSide".connect("toggled", self, "_setting_value_changed")
	for node in settings_map:
		if node.has_signal("value_changed"):
			node.connect("value_changed", self, "_setting_value_changed")
		if node.has_signal("toggled"):
			node.connect("toggled", self, "_setting_value_changed")
		if node.has_signal("data_changed"):
			node.connect("data_changed", self, "_setting_value_changed")
		if node.has_signal("color_changed"):
			node.connect("color_changed", self, "_setting_value_changed")
		var setting = settings_map[node]
		nodes_map[setting] = node
	pass # Replace with function body.

func _on_attach_limb_selected(_index):
	_update_attach_visibility()
	_setting_value_changed()

func _on_cap_framerate_toggled(_pressed):
	_update_framerate_visibility()

func _update_framerate_visibility():
	$"%Framerate".visible = $"%CapFramerate".pressed

func _update_attach_visibility():
	var attached = $"%AttachLimb".selected > 0
	if has_node("%MirrorPair"):
		$"%MirrorPair".visible = attached
	if has_node("%PositionOnly"):
		$"%PositionOnly".visible = attached
	if has_node("%ConsistentSide"):
		$"%ConsistentSide".visible = attached

func _on_trigger_toggled(_pressed):
	_update_trigger_visibility()
	_setting_value_changed()

func _update_trigger_visibility():
	var dt = $"%DynamicTriggers".pressed
	$"%TriggerDuringCombo".visible = dt
	$"%TriggerDuringMelee".visible = dt
	$"%TriggerWhileBeingComboed".visible = dt
	$"%TriggerAfterSpawnProj".visible = dt
	$"%TriggerAfterTakeDmg".visible = dt
	$"%TriggerAfterOppTakeDmg".visible = dt
	$"%TriggerDuringComboLinger".visible = dt and $"%TriggerDuringCombo".pressed
	$"%TriggerDuringMeleeLinger".visible = dt and $"%TriggerDuringMelee".pressed
	$"%TriggerWhileBeingComboedLinger".visible = dt and $"%TriggerWhileBeingComboed".pressed
	$"%TriggerLowHealth".visible = dt
	$"%TriggerLowHealthThreshold".visible = dt and $"%TriggerLowHealth".pressed
	$"%TriggerLowHealthLinger".visible = dt and $"%TriggerLowHealth".pressed
	$"%TriggerHighHealth".visible = dt
	$"%TriggerHighHealthThreshold".visible = dt and $"%TriggerHighHealth".pressed
	$"%TriggerHighHealthLinger".visible = dt and $"%TriggerHighHealth".pressed
	$"%TriggerSuperLevel".visible = dt
	$"%TriggerSuperLevelMin".visible = dt and $"%TriggerSuperLevel".pressed
	$"%TriggerSuperLevelLinger".visible = dt and $"%TriggerSuperLevel".pressed
	$"%TriggerAfterSpawnProjDuration".visible = dt and $"%TriggerAfterSpawnProj".pressed
	$"%TriggerProjectilesActive".visible = dt
	$"%TriggerProjectilesActiveLinger".visible = dt and $"%TriggerProjectilesActive".pressed
	$"%TriggerAfterTakeDmgDuration".visible = dt and $"%TriggerAfterTakeDmg".pressed
	$"%TriggerAfterOppTakeDmgDuration".visible = dt and $"%TriggerAfterOppTakeDmg".pressed
	$"%TriggerAfterPerfectParry".visible = dt
	$"%TriggerAfterPerfectParryDuration".visible = dt and $"%TriggerAfterPerfectParry".pressed
	$"%TriggerAfterBurst".visible = dt
	$"%TriggerAfterBurstDuration".visible = dt and $"%TriggerAfterBurst".pressed
	$"%TriggersInverted".visible = dt

func _setting_value_changed(_value=null):
	emit_signal("settings_changed", get_settings())

func set_start_color(start_color):
	self.start_color = start_color
	_setting_value_changed()

func set_end_color(end_color):
	self.end_color = end_color
	_setting_value_changed()

func get_settings():
	var attach_limb_text = $"%AttachLimb".get_item_text($"%AttachLimb".selected) if $"%AttachLimb".selected >= 0 else ATTACH_LIMB_NONE
	var mirror_pair = $"%MirrorPair".pressed if has_node("%MirrorPair") else true
	# UI checkbox is "enable limb rotation"; saved key is the inverse
	# (`attach_position_only`) — kept that way so old styles still load correctly.
	var position_only = (not $"%PositionOnly".pressed) if has_node("%PositionOnly") else true
	var consistent_side = $"%ConsistentSide".pressed if has_node("%ConsistentSide") else true
	var map = {
		"start_color": $"%StartColor".current_color,
		"end_color": $"%EndColor".current_color,
		"shape": shape_names[$"%Shape".selected],
		"attach_limb": "" if attach_limb_text == ATTACH_LIMB_NONE else attach_limb_text,
		"attach_pair_mirror": mirror_pair,
		"attach_position_only": position_only,
		"attach_consistent_side": consistent_side,
	}
#	print("getting all aura settings")
	for settings_node in settings_map:
		var value
		if settings_map[settings_node] in map:
			continue
		if settings_node is SettingsSlider:
			value = settings_node.get_data()
		elif settings_node is XYPlot:
			value = settings_node.get_value_float()
		elif settings_node.get("pressed") != null:
			value = settings_node.pressed
		elif settings_node is SpinBox:
			value = settings_node.value
		if value != null:
			map[settings_map[settings_node]] = value
	return map
