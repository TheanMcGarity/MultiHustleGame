extends VBoxContainer

signal data_changed()

onready var default = $Direction.value

export var centered = true

# [ Range Fix ] inspector category (export_categories plugin renders _c_* as a
# header) — flags the opt-in below so it's obvious why it exists.
export var _c_EnableThisToUseMinAndMaxValue = 0
# Honor the top-node min_value/max_value below. These were historically dead:
# $Direction just kept whatever range its scene set, and characters were authored
# against that. Making them apply unconditionally (1.10) silently re-ranged every
# existing slider and broke a bunch of characters, so it's opt-in. OFF = legacy
# behavior (range comes from $Direction); turn ON for sliders that actually want
# the top-node range. Existing content stays untouched.
export var apply_top_node_range = false
export var _c_DisabledByDefaultForBackwardCompatibility = 0

export var min_value = 0
export var max_value = 100

var buffer_value_changed = false

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_RIGHT and $Direction.get_rect().has_point(get_local_mouse_position()):
			$Direction.value = default

func _ready():
	if apply_top_node_range:
		$Direction.min_value = min_value
		$Direction.max_value = max_value
	if !centered:
		$Direction.min_value = 0
	$Label.text = name
	$Direction.connect("value_changed", self, "on_value_changed")

func on_value_changed(value):
	buffer_value_changed = true
	$ValueLabel.text = str(value)

func _process(_delta):
	if buffer_value_changed and !Input.is_mouse_button_pressed(BUTTON_LEFT):
		emit_signal("data_changed")
		buffer_value_changed = false

func get_value():
	return int($Direction.value)

func get_data():
	return {
		"x": get_value()
	}
