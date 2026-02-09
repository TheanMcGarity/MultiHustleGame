extends "res://custom_stage_loader/editor/InspectorElements/InspectorProperty.gd"

onready var checkbutton = $CheckButton

func _ready():
	if object:
		set_value(object.get(prop_data.name));
		checkbutton.connect("toggled", self, "_on_changed");

func set_value(value:bool):
	checkbutton.pressed = value

func _on_changed(value:bool):
	if object:
		object.set(prop_data.name, value)
		if object.get('data'):
			object.data[prop_data.name] = value
