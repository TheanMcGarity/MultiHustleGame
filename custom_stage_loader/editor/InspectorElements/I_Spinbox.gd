extends "res://custom_stage_loader/editor/InspectorElements/InspectorProperty.gd"

onready var spinbox = $SpinBox

# Called when the node enters the scene tree for the first time.
func _ready():
	if hint_data.empty():
		# Set default hint data
		hint_data = [-999999, 999999, 1]
	if prop_data:
		# Break down hint data and apply it to the spinbox's range
		if prop_data.hint == PROPERTY_HINT_RANGE:
			var hint_data_count = hint_data.size()
			spinbox.min_value = float(hint_data[0])
			spinbox.max_value = float(hint_data[1])
			if hint_data_count >= 3:
				# These can be out of order, so loop through them.
				for i in range(2, hint_data_count):
					if hint_data[i] == "or_greater":
						spinbox.allow_greater = true
					elif hint_data[i] == "or_lesser":
						spinbox.allow_greater = true
					else:
						var step = float(hint_data[i])
						if step:
							spinbox.step = step
	# This should always be true but for my sanity I check for it.
	if object:
		set_value(object.get(prop_data.name))
		spinbox.connect("value_changed", self, "_on_value_changed")
	

func set_value(value:float):
	spinbox.set_value(value)

func _on_value_changed(value):
	if object:
		object.set(prop_data.name, value)
		if object.get('data'):
			object.data[prop_data.name] = value
