extends VBoxContainer

const ATTACH_LIMB_NONE := "(none)"
const ATTACH_LIMB_OPTIONS := [
	ATTACH_LIMB_NONE,
	"Head",
	"LeftHand", "RightHand", "Hands",
	"LeftFoot", "RightFoot", "Feet",
	"Eyes",
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

# Set false for non-aura uses (e.g. hitspark particle editor) where the
# dynamic-triggers section is irrelevant. The TriggersSection node still
# exists in the tree so $"%TriggerX" lookups in the script don't NPE — it's
# just hidden so the user can't reach it.
export var enable_triggers := true
# Hides the Attach-to-limb selector and its related toggles (mirror pair,
# rotate-with-limb, consistent-side). Limb attachment only makes sense for
# auras that follow a character — irrelevant for hitspark particles, which
# spawn at a hit location and don't track an emitter.
export var enable_limb_attach := true

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
	$"%HideWhenInactive": "hide_when_inactive",
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
	$"%Color Midpoint": "color_midpoint",
	$"%Alpha Midpoint": "alpha_midpoint",
	$"%Scale Midpoint": "scale_midpoint",
	$"%Transform Scale X": "transform_scale_x",
	$"%Transform Scale Y": "transform_scale_y",
	$"%Transform Rotation": "transform_rotation",
	$"%X Offset": "x_offset",
	$"%Y Offset": "y_offset",
	$"%Angle": "angle",
	$"%Angle Randomness": "angle_random",
	$"%AngularVelocity": "angular_velocity",
	$"%AngularVelocityRandom": "angular_velocity_random",
	$"%Damping": "damping",
	$"%DampingRandom": "damping_random",
	$"%FlipWithCharacter": "flip_with_character",
}

var nodes_map = {}

var shape_names = []

var flip_option: OptionButton
const FLIP_OPTION_NONE := 0
const FLIP_OPTION_ALL := 1
const FLIP_OPTION_RANDOM := 2
var emission_shape_button: OptionButton
var circle_radius_slider
var dynamic_one_shot_button: CheckButton
var action_type_button: CheckButton
var action_type_option: OptionButton
var action_type_linger
var during_install_button: CheckButton
var during_install_linger
var during_taunt_button: CheckButton
var during_taunt_linger
var during_parry_combo_button: CheckButton
var during_parry_combo_linger
var eye_spacing_slider
var eye_left_y_slider
var eye_right_y_slider
var custom_preprocess_button: CheckButton
var custom_preprocess_slider
var preprocess_on_retrigger_button: CheckButton

const ACTION_TYPE_OPTIONS := ["Movement", "Defense", "Attack", "Special", "Super"]

func _build_flip_shape_button():
	# Shape lives inside an HBoxContainer (label + OptionButton). Add the
	# Flip mode picker as its own row below, in the surrounding VBox. The
	# data still saves as `flip_shape` / `random_flip` booleans (handled in
	# load_settings / get_settings) — the OptionButton is just a tidier UI
	# than two checkboxes.
	var shape_node = $"%Shape"
	var row = shape_node.get_parent() if shape_node else null
	var parent = row.get_parent() if row else self
	var flip_row = HBoxContainer.new()
	flip_row.name = "FlipRow"
	var label = Label.new()
	label.text = "Flip: "
	flip_row.add_child(label)
	flip_option = OptionButton.new()
	flip_option.name = "FlipShape"
	flip_option.add_item("none", FLIP_OPTION_NONE)
	flip_option.add_item("all", FLIP_OPTION_ALL)
	flip_option.add_item("random", FLIP_OPTION_RANDOM)
	flip_option.hint_tooltip = "How asymmetric particle shapes are mirrored."
	flip_row.add_child(flip_option)
	parent.add_child(flip_row)
	if row:
		var idx = row.get_position_in_parent() + 1
		parent.move_child(flip_row, idx)
	flip_option.connect("item_selected", self, "_setting_value_changed")

# Emission shape selector (rectangle vs circle) and the matching circle radius
# slider — built in code so the editor can't strip them. The associated
# rect_size sliders are existing scene nodes; we toggle their visibility based
# on which shape is active.
func _build_emission_shape_widgets():
	var row = HBoxContainer.new()
	row.name = "EmissionShapeRow"
	var label = Label.new()
	label.text = "Emission: "
	row.add_child(label)
	emission_shape_button = OptionButton.new()
	emission_shape_button.name = "EmissionShape"
	emission_shape_button.add_item("rectangle", 0)
	emission_shape_button.add_item("circle", 1)
	row.add_child(emission_shape_button)

	circle_radius_slider = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	circle_radius_slider.name = "CircleRadius"
	circle_radius_slider.label_text = "Circle Radius"
	circle_radius_slider.default_value = 12.0
	circle_radius_slider.min_value = 0.0
	circle_radius_slider.max_value = 32.0
	circle_radius_slider.step = 0.1

	# Slot the row + slider in just before the existing Rect Size sliders so
	# they read as a coherent "emission area" group. Rect Size X may now live
	# inside a CollapsibleSection wrapper, so add to the same parent rather
	# than to TrailSettings root.
	if has_node("%Rect Size X"):
		var anchor = $"%Rect Size X"
		var anchor_parent = anchor.get_parent()
		anchor_parent.add_child(row)
		anchor_parent.add_child(circle_radius_slider)
		var idx = anchor.get_position_in_parent()
		anchor_parent.move_child(row, idx)
		anchor_parent.move_child(circle_radius_slider, idx + 1)
	else:
		add_child(row)
		add_child(circle_radius_slider)

	settings_map[emission_shape_button] = "emission_shape"
	settings_map[circle_radius_slider] = "emission_circle_radius"

# One-shot toggle for dynamic triggers — placed right under DynamicTriggers
# in the expanded menu so users see it when they enable triggers.
func _build_dynamic_one_shot_button():
	if not has_node("%DynamicTriggers"):
		return
	var dt = $"%DynamicTriggers"
	var parent = dt.get_parent() if dt else self
	dynamic_one_shot_button = CheckButton.new()
	dynamic_one_shot_button.name = "DynamicOneShot"
	dynamic_one_shot_button.text = "enable one-shot mode"
	dynamic_one_shot_button.hint_tooltip = "creates a new particle on every trigger which disappears after it's finished."
	parent.add_child(dynamic_one_shot_button)
	parent.move_child(dynamic_one_shot_button, dt.get_position_in_parent() + 1)
	settings_map[dynamic_one_shot_button] = "dynamic_one_shot"

# Action-type trigger: one CheckButton + dropdown of action categories + linger
# slider. Built in code (instead of in the .tscn) for the same reason as the
# other dynamic-trigger widgets — the editor strips them on save.
func _build_action_type_trigger():
	if not has_node("%DynamicTriggers"):
		return
	var dt = $"%DynamicTriggers"
	var parent = dt.get_parent() if dt else self
	action_type_button = CheckButton.new()
	action_type_button.name = "TriggerActionType"
	action_type_button.unique_name_in_owner = true
	action_type_button.text = "  during action type"
	parent.add_child(action_type_button)
	action_type_option = OptionButton.new()
	action_type_option.name = "TriggerActionTypeOption"
	action_type_option.unique_name_in_owner = true
	for t in ACTION_TYPE_OPTIONS:
		action_type_option.add_item(t)
	action_type_option.selected = ACTION_TYPE_OPTIONS.find("Attack")
	parent.add_child(action_type_option)
	action_type_linger = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	action_type_linger.name = "TriggerActionTypeLinger"
	action_type_linger.unique_name_in_owner = true
	action_type_linger.label_text = "Linger Duration"
	action_type_linger.default_value = 0.0
	action_type_linger.min_value = 0.0
	action_type_linger.max_value = 120.0
	action_type_linger.step = 1.0
	parent.add_child(action_type_linger)
	settings_map[action_type_button] = "trigger_action_type"
	settings_map[action_type_option] = "trigger_action_type_value"
	settings_map[action_type_linger] = "trigger_action_type_linger"

# "during install" trigger — character-specific install supers (Wizard's Orb,
# Mutant's Beast install, SwordGuy's 1000 Cuts buff, etc.). Active state is
# resolved in BaseChar.is_in_install_super(), which characters override.
func _build_during_install_trigger():
	if not has_node("%DynamicTriggers"):
		return
	var dt = $"%DynamicTriggers"
	var parent = dt.get_parent() if dt else self
	during_install_button = CheckButton.new()
	during_install_button.name = "TriggerDuringInstall"
	during_install_button.unique_name_in_owner = true
	during_install_button.text = "  during install"
	parent.add_child(during_install_button)
	during_install_linger = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	during_install_linger.name = "TriggerDuringInstallLinger"
	during_install_linger.unique_name_in_owner = true
	during_install_linger.label_text = "Linger Duration"
	during_install_linger.default_value = 0.0
	during_install_linger.min_value = 0.0
	during_install_linger.max_value = 120.0
	during_install_linger.step = 1.0
	parent.add_child(during_install_linger)
	settings_map[during_install_button] = "trigger_during_install"
	settings_map[during_install_linger] = "trigger_during_install_linger"

# "during Hustle (taunt)" trigger — active for the duration of the Taunt
# state. Same shape as the install trigger.
func _build_during_taunt_trigger():
	if not has_node("%DynamicTriggers"):
		return
	var dt = $"%DynamicTriggers"
	var parent = dt.get_parent() if dt else self
	during_taunt_button = CheckButton.new()
	during_taunt_button.name = "TriggerDuringTaunt"
	during_taunt_button.unique_name_in_owner = true
	during_taunt_button.text = "  during hustle"
	parent.add_child(during_taunt_button)
	during_taunt_linger = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	during_taunt_linger.name = "TriggerDuringTauntLinger"
	during_taunt_linger.unique_name_in_owner = true
	during_taunt_linger.label_text = "Linger Duration"
	during_taunt_linger.default_value = 0.0
	during_taunt_linger.min_value = 0.0
	during_taunt_linger.max_value = 120.0
	during_taunt_linger.step = 1.0
	parent.add_child(during_taunt_linger)
	settings_map[during_taunt_button] = "trigger_during_taunt"
	settings_map[during_taunt_linger] = "trigger_during_taunt_linger"

# "during parry combo" trigger — active while parry_combo or
# parried_burst_combo is > 0 (i.e. the parry-combo damage scaling is
# applied). Built at runtime + reparented to live right after the
# After-Perfect-Parry duration slider so the UI grouping makes sense.
func _build_during_parry_combo_trigger():
	if not has_node("%DynamicTriggers"):
		return
	var dt = $"%DynamicTriggers"
	var parent = dt.get_parent() if dt else self
	during_parry_combo_button = CheckButton.new()
	during_parry_combo_button.name = "TriggerDuringParryCombo"
	during_parry_combo_button.unique_name_in_owner = true
	during_parry_combo_button.text = "  during parry combo"
	parent.add_child(during_parry_combo_button)
	during_parry_combo_linger = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	during_parry_combo_linger.name = "TriggerDuringParryComboLinger"
	during_parry_combo_linger.unique_name_in_owner = true
	during_parry_combo_linger.label_text = "Linger Duration"
	during_parry_combo_linger.default_value = 0.0
	during_parry_combo_linger.min_value = 0.0
	during_parry_combo_linger.max_value = 120.0
	during_parry_combo_linger.step = 1.0
	parent.add_child(during_parry_combo_linger)
	settings_map[during_parry_combo_button] = "trigger_during_parry_combo"
	settings_map[during_parry_combo_linger] = "trigger_during_parry_combo_linger"
	# Reposition under the After-Perfect-Parry pair so the grouping reads
	# as "everything parry-related, together". Falls through to the natural
	# append order if the anchor node isn't in the tree (e.g. enable_triggers
	# was flipped off and the section is gone).
	var anchor = get_node_or_null("%TriggerAfterPerfectParryDuration")
	if anchor and anchor.get_parent() == parent:
		var insert_at = anchor.get_position_in_parent() + 1
		parent.move_child(during_parry_combo_button, insert_at)
		parent.move_child(during_parry_combo_linger, insert_at + 1)

# Eye-attachment sub-controls — spacing between the two eyes and per-eye
# vertical offset. Visible only when AttachLimb == "Eyes" (toggled in
# _update_attach_visibility). Slotted right below the AttachLimb row so
# the eye-specific settings group with the attach picker.
func _build_eye_attach_widgets():
	if not has_node("%AttachLimb"):
		return
	var anchor = $"%AttachLimb"
	var anchor_row = anchor.get_parent()
	if anchor_row == null:
		return
	var parent = anchor_row.get_parent()
	if parent == null:
		return
	eye_spacing_slider = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	eye_spacing_slider.name = "EyeSpacing"
	eye_spacing_slider.unique_name_in_owner = true
	eye_spacing_slider.label_text = "Eye Spacing"
	eye_spacing_slider.default_value = 6.0
	eye_spacing_slider.min_value = 0.0
	eye_spacing_slider.max_value = 40.0
	eye_spacing_slider.step = 0.1
	parent.add_child(eye_spacing_slider)
	eye_left_y_slider = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	eye_left_y_slider.name = "EyeLeftYOffset"
	eye_left_y_slider.unique_name_in_owner = true
	eye_left_y_slider.label_text = "Left Eye Y Offset"
	eye_left_y_slider.default_value = 0.0
	eye_left_y_slider.min_value = -20.0
	eye_left_y_slider.max_value = 20.0
	eye_left_y_slider.step = 0.1
	parent.add_child(eye_left_y_slider)
	eye_right_y_slider = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	eye_right_y_slider.name = "EyeRightYOffset"
	eye_right_y_slider.unique_name_in_owner = true
	eye_right_y_slider.label_text = "Right Eye Y Offset"
	eye_right_y_slider.default_value = 0.0
	eye_right_y_slider.min_value = -20.0
	eye_right_y_slider.max_value = 20.0
	eye_right_y_slider.step = 0.1
	parent.add_child(eye_right_y_slider)
	settings_map[eye_spacing_slider] = "attach_eye_spacing"
	settings_map[eye_left_y_slider] = "attach_eye_left_y_offset"
	settings_map[eye_right_y_slider] = "attach_eye_right_y_offset"
	var insert_at = anchor_row.get_position_in_parent() + 1
	parent.move_child(eye_spacing_slider, insert_at)
	parent.move_child(eye_left_y_slider, insert_at + 1)
	parent.move_child(eye_right_y_slider, insert_at + 2)

# Custom-preprocess toggle + value slider — under "Particle Lifetime" in
# the Lifetime section. When the toggle is off, preprocess defaults to
# lifetime (continuous auras look already-running on load). When on, the
# user-specified value is used instead.
func _build_custom_preprocess_widgets():
	if not has_node("%Particle Lifetime"):
		return
	var lifetime_node = $"%Particle Lifetime"
	var parent = lifetime_node.get_parent()
	if parent == null:
		return
	custom_preprocess_button = CheckButton.new()
	custom_preprocess_button.name = "CustomPreprocess"
	custom_preprocess_button.unique_name_in_owner = true
	custom_preprocess_button.text = "custom preprocess"
	custom_preprocess_button.hint_tooltip = "Override the auto-preprocess (which defaults to the particle lifetime, so continuous auras look already-running on load)."
	parent.add_child(custom_preprocess_button)
	custom_preprocess_slider = preload("res://ui/CustomizationScreen/SettingsSlider.tscn").instance()
	custom_preprocess_slider.name = "CustomPreprocessValue"
	custom_preprocess_slider.unique_name_in_owner = true
	custom_preprocess_slider.label_text = "Preprocess Time"
	custom_preprocess_slider.default_value = 0.0
	custom_preprocess_slider.min_value = 0.0
	custom_preprocess_slider.max_value = 10.0
	custom_preprocess_slider.step = 0.01
	parent.add_child(custom_preprocess_slider)
	settings_map[custom_preprocess_button] = "custom_preprocess"
	settings_map[custom_preprocess_slider] = "custom_preprocess_value"
	var insert_at = lifetime_node.get_position_in_parent() + 1
	parent.move_child(custom_preprocess_button, insert_at)
	parent.move_child(custom_preprocess_slider, insert_at + 1)

# "preprocess on retrigger" — lives in the Triggers section since it only
# affects dynamic-trigger re-fires. Off (default): a re-triggered aura
# builds up gradually from time=0. On: it re-applies preprocess so it snaps
# back to its full / all-at-once look on each trigger.
func _build_preprocess_on_retrigger_button():
	if not has_node("%DynamicTriggers"):
		return
	var dt = $"%DynamicTriggers"
	var parent = dt.get_parent() if dt else self
	preprocess_on_retrigger_button = CheckButton.new()
	preprocess_on_retrigger_button.name = "PreprocessOnRetrigger"
	preprocess_on_retrigger_button.unique_name_in_owner = true
	preprocess_on_retrigger_button.text = "preprocess on retrigger"
	preprocess_on_retrigger_button.hint_tooltip = "Re-apply preprocess each time a dynamic trigger re-fires, so the aura snaps to its full look instead of building up gradually."
	parent.add_child(preprocess_on_retrigger_button)
	settings_map[preprocess_on_retrigger_button] = "preprocess_on_retrigger"

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
			if value is String and node is OptionButton:
				for id in node.get_item_count():
					if value == node.get_item_text(id):
						node.selected = id
						break
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
	_update_custom_preprocess_visibility()
	if has_node("%AttachLimb"):
		_update_attach_visibility()
	if has_node("%DynamicTriggers"):
		_update_trigger_visibility()
	# Explicit default for old styles that don't have emission_shape saved.
	if emission_shape_button:
		var em_shape = settings.get("emission_shape", "rectangle")
		for id in emission_shape_button.get_item_count():
			if em_shape == emission_shape_button.get_item_text(id):
				emission_shape_button.selected = id
				break
	_update_emission_visibility()
	# Flip mode is derived from the two booleans the data still stores. Random
	# wins when both are true, "all" otherwise if flip_shape is true, else "none".
	if flip_option:
		if settings.get("random_flip", false):
			flip_option.selected = FLIP_OPTION_RANDOM
		elif settings.get("flip_shape", false):
			flip_option.selected = FLIP_OPTION_ALL
		else:
			flip_option.selected = FLIP_OPTION_NONE
#			yield(get_tree(), "idle_frame")

const TRIGGER_LABELS = {
	"TriggerDuringComboLinger": "Linger Duration",
	"TriggerDuringMeleeLinger": "Linger Duration",
	"TriggerWhileBeingComboedLinger": "Linger Duration",
	"TriggerLowHealthThreshold": "Health %",
	"TriggerLowHealthLinger": "Linger Duration",
	"TriggerHighHealthThreshold": "Health %",
	"TriggerHighHealthLinger": "Linger Duration",
	"TriggerSuperLevelMin": "Min Level",
	"TriggerSuperLevelLinger": "Linger Duration",
	"TriggerAfterSpawnProjDuration": "Duration",
	"TriggerAfterTakeDmgDuration": "Duration",
	"TriggerAfterOppTakeDmgDuration": "Duration",
	"TriggerAfterPerfectParryDuration": "Duration",
	"TriggerAfterBurstDuration": "Duration",
	"TriggerProjectilesActiveLinger": "Linger Duration",
	"TriggerDuringInstallLinger": "Linger Duration",
	"TriggerDuringTauntLinger": "Linger Duration",
	"TriggerDuringParryComboLinger": "Linger Duration",
	"AngularVelocity": "Angular Velocity",
	"AngularVelocityRandom": "Angular Vel. Randomness",
	"Damping": "Damping",
	"DampingRandom": "Damping Randomness",
}

func _ready():
	# Godot's editor strips export-property overrides on scene instances when
	# the property isn't statically visible at edit time (the same issue that
	# bit `label_text` overrides on SettingsSlider). Fall back to detecting
	# our role from the node's name so the hitspark instance still loses its
	# triggers + limb-attach controls even after a linter pass.
	if name == "HitsparkParticles":
		enable_triggers = false
		enable_limb_attach = false
		# Hitsparks aren't tied to a character's facing or coordinate space —
		# they spawn at a hit location and play out independently. Hide the
		# toggles that only make sense for character-attached auras. Using
		# the unique-name shortcut because PositionSection (a CollapsibleSection)
		# re-parents its children under a Content node at _ready, so the
		# direct PositionSection/HFlowContainer path doesn't resolve here.
		if has_node("%Local"):
			$"%Local".visible = false
		if has_node("%FlipWithCharacter"):
			$"%FlipWithCharacter".visible = false
		# With limb attachment removed, the section's just "Position".
		if has_node("PositionSection"):
			$PositionSection.section_title = "Position"
	# Strip the entire triggers section for non-aura uses (e.g. hitsparks).
	# Done as a free() rather than visible=false because the user wants the
	# triggers feature simply not present in those contexts. Trigger-related
	# wiring below is gated on enable_triggers so it doesn't try to talk to
	# nodes that no longer exist.
	if not enable_triggers and has_node("TriggersSection"):
		$TriggersSection.free()
	# Hide limb-attach controls for non-aura uses. AttachLimb stays at its
	# default "(none)" so save/load don't need special handling. Direct
	# child paths don't work because PositionSection (a CollapsibleSection)
	# re-parents its children under a Content node at _ready, so we go
	# through the unique-name shortcut + walk to the AttachLimbRow parent.
	if not enable_limb_attach:
		if has_node("%AttachLimb"):
			var row = $"%AttachLimb".get_parent()
			if row:
				row.visible = false
		if has_node("%MirrorPair"):
			$"%MirrorPair".visible = false
		if has_node("%PositionOnly"):
			$"%PositionOnly".visible = false
		if has_node("%ConsistentSide"):
			$"%ConsistentSide".visible = false
	# Build the FlipShape checkbox in code — it has to live next to the Shape
	# OptionButton, but adding it via the .tscn is fragile because Godot's
	# editor strips unknown nodes from TrailSettings.tscn on save (same issue
	# that bit the slider label_text overrides). Wire it directly here.
	_build_flip_shape_button()
	_build_emission_shape_widgets()
	_build_custom_preprocess_widgets()
	if enable_limb_attach:
		_build_eye_attach_widgets()
	if enable_triggers:
		_build_dynamic_one_shot_button()
		_build_preprocess_on_retrigger_button()
		_build_action_type_trigger()
		_build_during_install_trigger()
		_build_during_taunt_trigger()
		_build_during_parry_combo_trigger()
		# TriggersInverted (label "hide on trigger") lives in the .tscn so its
		# state survives editor re-saves, but the programmatically-built triggers
		# above are appended after it. Bump it to the end so it stays at the
		# bottom of the dynamic-triggers list visually.
		if has_node("%TriggersInverted"):
			var inv = $"%TriggersInverted"
			inv.get_parent().move_child(inv, inv.get_parent().get_child_count() - 1)
	if emission_shape_button:
		emission_shape_button.connect("item_selected", self, "_on_emission_shape_changed")
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
	if enable_triggers:
		for trigger_button_name in [
			"DynamicTriggers",
			"TriggerDuringCombo", "TriggerDuringMelee", "TriggerWhileBeingComboed",
			"TriggerLowHealth", "TriggerHighHealth", "TriggerSuperLevel",
			"TriggerAfterSpawnProj", "TriggerProjectilesActive",
			"TriggerAfterTakeDmg", "TriggerAfterOppTakeDmg",
			"TriggerAfterPerfectParry", "TriggerAfterBurst"
		]:
			get_node("%" + trigger_button_name).connect("toggled", self, "_on_trigger_toggled")
		# DynamicOneShot also needs to flip linger-slider visibility — it's not
		# in the loop above because that list pre-existed before one_shot mode.
		if dynamic_one_shot_button:
			dynamic_one_shot_button.connect("toggled", self, "_on_trigger_toggled")
		# Same wiring for the runtime-built action-type and install triggers.
		if action_type_button:
			action_type_button.connect("toggled", self, "_on_trigger_toggled")
		if action_type_option:
			# OptionButton emits item_selected, not value_changed/toggled, so the
			# generic settings_map signal-wiring loop misses it. Hook it manually
			# so dropdown changes get saved alongside the rest.
			action_type_option.connect("item_selected", self, "_on_trigger_toggled")
		if during_install_button:
			during_install_button.connect("toggled", self, "_on_trigger_toggled")
		if during_taunt_button:
			during_taunt_button.connect("toggled", self, "_on_trigger_toggled")
		if during_parry_combo_button:
			during_parry_combo_button.connect("toggled", self, "_on_trigger_toggled")
	_update_framerate_visibility()
	if custom_preprocess_button:
		custom_preprocess_button.connect("toggled", self, "_on_custom_preprocess_toggled")
	_update_custom_preprocess_visibility()
	_update_attach_visibility()
	if enable_triggers:
		_update_trigger_visibility()
	if has_node("%MirrorPair"):
		$"%MirrorPair".connect("toggled", self, "_setting_value_changed")
	if has_node("%PositionOnly"):
		$"%PositionOnly".connect("toggled", self, "_setting_value_changed")
	if has_node("%ConsistentSide"):
		$"%ConsistentSide".connect("toggled", self, "_setting_value_changed")
	for node in settings_map:
		# Guard against nodes the godot editor may have stripped from the
		# scene — settings_map is built via $"%Foo" at onready time, so a
		# missing node lands as null here and would crash has_signal. Also
		# skip freed objects (e.g. trigger nodes after free()) — those refs
		# aren't null but are no longer valid.
		if node == null or not is_instance_valid(node):
			continue
		if node.has_signal("value_changed"):
			node.connect("value_changed", self, "_setting_value_changed")
		if node.has_signal("toggled"):
			node.connect("toggled", self, "_setting_value_changed")
		if node.has_signal("data_changed"):
			node.connect("data_changed", self, "_setting_value_changed")
		if node.has_signal("color_changed"):
			node.connect("color_changed", self, "_setting_value_changed")
		if node.has_signal("item_selected"):
			node.connect("item_selected", self, "_setting_value_changed")
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

func _on_custom_preprocess_toggled(_pressed):
	_update_custom_preprocess_visibility()

func _update_custom_preprocess_visibility():
	if custom_preprocess_slider and custom_preprocess_button:
		custom_preprocess_slider.visible = custom_preprocess_button.pressed

func _on_emission_shape_changed(_idx):
	_update_emission_visibility()
	_setting_value_changed()

func _current_emission_shape() -> String:
	if emission_shape_button and emission_shape_button.selected >= 0:
		return emission_shape_button.get_item_text(emission_shape_button.selected)
	return "rectangle"

func _update_emission_visibility():
	var is_circle = _current_emission_shape() == "circle"
	if has_node("%Rect Size X"):
		$"%Rect Size X".visible = not is_circle
	if has_node("%Rect Size Y"):
		$"%Rect Size Y".visible = not is_circle
	if circle_radius_slider:
		circle_radius_slider.visible = is_circle

func _update_attach_visibility():
	var attached = $"%AttachLimb".selected > 0
	var attach_text = ""
	if $"%AttachLimb".selected >= 0:
		attach_text = $"%AttachLimb".get_item_text($"%AttachLimb".selected)
	var is_eyes = attach_text == "Eyes"
	if has_node("%MirrorPair"):
		$"%MirrorPair".visible = attached
	if has_node("%PositionOnly"):
		$"%PositionOnly".visible = attached
	if has_node("%ConsistentSide"):
		$"%ConsistentSide".visible = attached
	if eye_spacing_slider:
		eye_spacing_slider.visible = is_eyes
	if eye_left_y_slider:
		eye_left_y_slider.visible = is_eyes
	if eye_right_y_slider:
		eye_right_y_slider.visible = is_eyes

func _on_trigger_toggled(_pressed):
	_update_trigger_visibility()
	_setting_value_changed()

func _update_trigger_visibility():
	var dt = $"%DynamicTriggers".pressed
	# In one-shot mode each event spawns a fresh ephemeral burst that lives
	# its own lifetime — linger/duration values don't apply, and inversion is
	# intentionally ignored (the rising edges are used directly), so hide
	# both classes of widget while it's on.
	var os = dt and dynamic_one_shot_button and dynamic_one_shot_button.pressed
	var show_linger = dt and not os
	if dynamic_one_shot_button:
		dynamic_one_shot_button.visible = dt
	$"%TriggerDuringCombo".visible = dt
	$"%TriggerDuringMelee".visible = dt
	$"%TriggerWhileBeingComboed".visible = dt
	$"%TriggerAfterSpawnProj".visible = dt
	$"%TriggerAfterTakeDmg".visible = dt
	$"%TriggerAfterOppTakeDmg".visible = dt
	$"%TriggerDuringComboLinger".visible = show_linger and $"%TriggerDuringCombo".pressed
	$"%TriggerDuringMeleeLinger".visible = show_linger and $"%TriggerDuringMelee".pressed
	$"%TriggerWhileBeingComboedLinger".visible = show_linger and $"%TriggerWhileBeingComboed".pressed
	$"%TriggerLowHealth".visible = dt
	$"%TriggerLowHealthThreshold".visible = dt and $"%TriggerLowHealth".pressed
	$"%TriggerLowHealthLinger".visible = show_linger and $"%TriggerLowHealth".pressed
	$"%TriggerHighHealth".visible = dt
	$"%TriggerHighHealthThreshold".visible = dt and $"%TriggerHighHealth".pressed
	$"%TriggerHighHealthLinger".visible = show_linger and $"%TriggerHighHealth".pressed
	$"%TriggerSuperLevel".visible = dt
	$"%TriggerSuperLevelMin".visible = dt and $"%TriggerSuperLevel".pressed
	$"%TriggerSuperLevelLinger".visible = show_linger and $"%TriggerSuperLevel".pressed
	$"%TriggerAfterSpawnProjDuration".visible = show_linger and $"%TriggerAfterSpawnProj".pressed
	$"%TriggerProjectilesActive".visible = dt
	$"%TriggerProjectilesActiveLinger".visible = show_linger and $"%TriggerProjectilesActive".pressed
	$"%TriggerAfterTakeDmgDuration".visible = show_linger and $"%TriggerAfterTakeDmg".pressed
	$"%TriggerAfterOppTakeDmgDuration".visible = show_linger and $"%TriggerAfterOppTakeDmg".pressed
	$"%TriggerAfterPerfectParry".visible = dt
	$"%TriggerAfterPerfectParryDuration".visible = show_linger and $"%TriggerAfterPerfectParry".pressed
	$"%TriggerAfterBurst".visible = dt
	$"%TriggerAfterBurstDuration".visible = show_linger and $"%TriggerAfterBurst".pressed
	$"%TriggersInverted".visible = dt and not os
	# Runtime-built triggers (action_type, during_install).
	if action_type_button:
		action_type_button.visible = dt
		action_type_option.visible = dt and action_type_button.pressed
	if action_type_linger:
		action_type_linger.visible = show_linger and action_type_button and action_type_button.pressed
	if during_install_button:
		during_install_button.visible = dt
	if during_install_linger:
		during_install_linger.visible = show_linger and during_install_button and during_install_button.pressed
	if during_taunt_button:
		during_taunt_button.visible = dt
	if during_taunt_linger:
		during_taunt_linger.visible = show_linger and during_taunt_button and during_taunt_button.pressed
	if during_parry_combo_button:
		during_parry_combo_button.visible = dt
	if during_parry_combo_linger:
		during_parry_combo_linger.visible = show_linger and during_parry_combo_button and during_parry_combo_button.pressed
	# Re-applies preprocess on re-fire — only meaningful for continuous
	# (non-one-shot) dynamic triggers; one-shot bursts always start fresh.
	if preprocess_on_retrigger_button:
		preprocess_on_retrigger_button.visible = dt and not os

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
		if settings_node == null or not is_instance_valid(settings_node):
			continue
		var value
		if settings_map[settings_node] in map:
			continue
		if settings_node is SettingsSlider:
			value = settings_node.get_data()
		elif settings_node is XYPlot:
			value = settings_node.get_value_float()
		elif settings_node is OptionButton:
			# OptionButton inherits BaseButton (which has `pressed`), so this
			# branch must come before the generic `get("pressed")` check or
			# the OptionButton's always-false `pressed` would be saved instead
			# of the selected item text.
			if settings_node.selected >= 0:
				value = settings_node.get_item_text(settings_node.selected)
		elif settings_node.get("pressed") != null:
			value = settings_node.pressed
		elif settings_node is SpinBox:
			value = settings_node.value
		if value != null:
			map[settings_map[settings_node]] = value
	# Derive flip_shape / random_flip from the OptionButton. The dropdown
	# isn't in settings_map (it's a UI proxy for two saved booleans), so we
	# write them out here.
	var flip_idx = flip_option.selected if flip_option else FLIP_OPTION_NONE
	map["flip_shape"] = (flip_idx == FLIP_OPTION_ALL)
	map["random_flip"] = (flip_idx == FLIP_OPTION_RANDOM)
	return map
