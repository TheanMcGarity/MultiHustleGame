extends "res://custom_stage_loader/editor/InspectorElements/InspectorProperty.gd"

func _ready():
	if object:
		set_value(object.get(prop_data.name));
		$"%X".connect("value_changed", self, "_on_prop_changed", ["x"]);
		$"%Y".connect("value_changed", self, "_on_prop_changed", ["y"]);
		$"%Z".connect("value_changed", self, "_on_prop_changed", ["z"]);
		$"%D".connect("value_changed", self, "_on_prop_changed", ["d"]);

func set_value(value:Plane):
	$"%X".set_value(value.x);
	$"%Y".set_value(value.y);
	$"%Z".set_value(value.z);
	$"%D".set_value(value.d);

func _on_prop_changed(value:float, prop:String):
	if object:
		object.set_indexed(prop_data.name + ":" + prop, value);
	update_data();

func update_data():
	var val = Plane($"%X".value, $"%Y".value, $"%Z".value, $"%D".value);
	if object:
		object.data[prop_data.name] = val;
