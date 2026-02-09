extends "res://custom_stage_loader/editor/InspectorElements/InspectorProperty.gd"

# This can use either LineEdit nodes or TextEdit edit nodes
onready var textedit = $TextEdit

func _ready():
	if object:
		set_value(object.get(prop_data.name));
		textedit.connect("text_changed", self, "_on_changed")

func set_value(value:String):
	textedit.text = value

func _on_changed():
	var value = textedit.text
	if object:
		object.set(prop_data.name, value)
		if object.get('data'):
			object.data[prop_data.name] = value
