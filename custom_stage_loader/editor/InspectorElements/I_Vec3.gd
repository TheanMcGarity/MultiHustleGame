extends "res://custom_stage_loader/editor/InspectorElements/InspectorProperty.gd"

func _ready():
	if object:
		set_value(object.get(prop_data.name));
		$"%X".connect("value_changed", self, "_on_prop_changed", ["x"]);
		$"%Y".connect("value_changed", self, "_on_prop_changed", ["y"]);
		$"%Z".connect("value_changed", self, "_on_prop_changed", ["z"]);

func set_value(value:Vector3):
	$"%X".set_value(value.x);
	$"%Y".set_value(value.y);
	$"%Z".set_value(value.z);

func _on_prop_changed(value:float, prop:String):
	if object:
		object.set_indexed(prop_data.name + ":" + prop, value);
	update_data();

func update_data():
	var val = Vector3($"%X".value, $"%Y".value, $"%Z".value);
	if object:
		object.data[prop_data.name] = val;
