extends Control

class_name SettingsSlider

signal value_changed(value)

const ARROW_STEP = 0.01

onready var slider = $"%HSlider"
var value = 0.0
var mouse_entered = false

export var default_value = 0.0
export var min_value = 0.0
export var max_value = 100.0
export var step = 0.01
# When true the slider position [0,1] maps to [min_value, max_value] on a
# geometric (exponential) curve so the lower end has more resolution.
# Mapping: value = min * (max/min)^t, inverse: t = log(value/min)/log(max/min).
# Requires min_value > 0 for the pure form; falls back to a shifted curve if not.
export var exponential = false
# Optional override for the slider's left-side label. When empty, the slider's
# node name is used (matches the existing convention for most settings).
export var label_text = ""

func _ready():
	if exponential:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.001
	else:
		slider.min_value = min_value
		slider.max_value = max_value
		slider.step = step
	$"%Label".text = label_text if label_text else name
	set_value(default_value)

func _input(event):
	# Override the HSlider's built-in arrow stepping with a flat 0.01 in value
	# space (its native step is nonlinear in value space for exponential mode).
	# `_input` runs before `_gui_input`, so consuming the event here prevents
	# the HSlider from also processing the same arrow press.
	if !slider.has_focus():
		return
	if !(event is InputEventKey) or !event.pressed:
		return
	if event.scancode == KEY_LEFT:
		set_value(value - ARROW_STEP)
		get_tree().set_input_as_handled()
	elif event.scancode == KEY_RIGHT:
		set_value(value + ARROW_STEP)
		get_tree().set_input_as_handled()

func _on_HSlider_value_changed(slider_val):
	if exponential:
		value = _slider_to_value(slider_val)
	else:
		value = slider_val
	emit_signal("value_changed", value)
	$"%Value".text = _format_value(value)

func set_value(v):
	v = clamp(v, min_value, max_value)
	if exponential:
		# Drive the slider position from the value, but keep `value` exact
		# instead of round-tripping it through the slider's coarse 0.001 step
		# — otherwise styles round to a slightly-off number on load.
		slider.value = _value_to_slider(v)
		value = v
	else:
		slider.value = v
		value = slider.value
	emit_signal("value_changed", value)
	$"%Value".text = _format_value(value)

func get_data():
	return value

func _slider_to_value(t):
	if min_value <= 0.0:
		return pow(max_value - min_value + 1.0, t) - 1.0 + min_value
	return min_value * pow(max_value / min_value, t)

func _value_to_slider(v):
	v = clamp(v, min_value, max_value)
	if min_value <= 0.0:
		return log(v - min_value + 1.0) / log(max_value - min_value + 1.0)
	return log(v / min_value) / log(max_value / min_value)

func _format_value(v):
	if exponential:
		return "%.2f" % v
	return str(v)

func _on_ResetButton_pressed():
	set_value(default_value)
