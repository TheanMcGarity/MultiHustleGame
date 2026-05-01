tool
extends "res://ui/HorizSlider/HorizSlider.gd"

export var initial_value:int

func on_value_changed(value):
	buffer_value_changed = true
	$ValueLabel.text = "x%.2f" % (value / 100.0)

func _ready():
	._ready()
	$Direction.min_value = min_value
	$Direction.max_value = max_value
	$Direction.value = initial_value

func get_value():
	return .get_value() / 100.0
