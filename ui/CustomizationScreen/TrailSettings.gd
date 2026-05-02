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
		$"%PositionOnly".set_pressed_no_signal(settings.get("attach_position_only", true))
	if has_node("%ConsistentSide"):
		$"%ConsistentSide".set_pressed_no_signal(settings.get("attach_consistent_side", true))
#			yield(get_tree(), "idle_frame")

func _ready():
	var shapes = CustomTrailParticle.get_shapes()
	for shape_name in shapes:
		$"%Shape".add_item(shape_name)
		shape_names.append(shape_name)
	for limb in ATTACH_LIMB_OPTIONS:
		$"%AttachLimb".add_item(limb)
	$"%AttachLimb".connect("item_selected", self, "_on_attach_limb_selected")
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
	_setting_value_changed()

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
	var position_only = $"%PositionOnly".pressed if has_node("%PositionOnly") else true
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
