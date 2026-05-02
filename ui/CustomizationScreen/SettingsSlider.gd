extends Control

class_name SettingsSlider

signal value_changed(value)

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

func _ready():
	if exponential:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.001
	else:
		slider.min_value = min_value
		slider.max_value = max_value
		slider.step = step
	$"%Label".text = name
	set_value(default_value)

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
		slider.value = _value_to_slider(v)
		value = _slider_to_value(slider.value)
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
