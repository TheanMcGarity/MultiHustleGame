extends Node

# + Custom Stage API
# - Authors: Hazelpy, Fleig, Sulayre, and Supersonic
#
# - Every object in this API takes in an object data dictionary,
# - so that we don't have to hardcode everything in this class specifically. 
# - See API classes for more info.

# TODO: Add preloads for every api piece so they get picked up by load_object()
var StageBackground = load("res://custom_stage_loader/api/StageBackground.gd");
var StageLayer = load("res://custom_stage_loader/api/StageLayer.gd");
var StageElement = load("res://custom_stage_loader/api/StageElement.gd");
var StageCanvas = load("res://custom_stage_loader/api/StageCanvas.gd");

var root_binds = [
	{"signal": "game_changed", "function": "_on_game_changed"},
	{"signal": "tick_changed", "function": "_on_tick_changed"}
];

# [ load_object function ]
# This function takes in object data and returns an instance.
func load_object(obj_data:Dictionary, stage_root = null):
	var type = get(obj_data.type); # Object type string
	var instance; # Object instance
	
	if type != null:
		instance = type.new(obj_data); # ?
	else:
		if obj_data.type == "ASSET":
			var asset = load(obj_data.asset_path);
			
			instance = asset.instance(); 
		else:
			return null;
	
	if stage_root:
		for bind in root_binds:
			if instance.has_method(bind.function):
				if not stage_root.is_connected(bind.signal, instance, bind.function):
					stage_root.connect(bind.signal, instance, bind.function);
		
		obj_data["stage_root"] = stage_root;
	
	if obj_data.has("children"):
		obj_data["_children"] = [];
		
		for child in obj_data.children:
			var child_instance = load_object(child, stage_root);
			
			obj_data["_children"].append(child_instance);
			instance.add_child(child_instance);
		
	instance.set("csl_data", obj_data);
	
	for i in obj_data:
		instance.set(i, obj_data[i]);
	
	if "material_name" in obj_data: 
		instance.name = obj_data["material_name"];
	
	#print("Loaded object of type '" + obj_data.type + "'!");
	#print("Object data:", obj_data);
	return instance
