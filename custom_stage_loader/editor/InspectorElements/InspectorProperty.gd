extends BoxContainer

# Base inspector property class

var prop_data = null
var hint_data = []
var object = null
export var capitalize_prop_name = true

signal value_changed()

func set_object(obj):
	object = obj

func set_prop_data(_prop_data):
	prop_data = _prop_data

func _ready():
	if prop_data:
		$Label.text = prop_data.name.capitalize() if capitalize_prop_name else prop_data.name;
		hint_data = prop_data.hint_string.split(",");

# Should be overridden by the inspector
func set_value(value):
	pass
