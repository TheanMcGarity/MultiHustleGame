extends Reference

var materials = 0;
var data;
var API;

# Called when the node enters the scene tree for the first time.
func _init(params := {}):
	data = {
		"stage_name": "New Stage",
		"stage_icon": null,
		"stage_id": null,
		"materials": []
	};
	
	for key in params:
		data[key] = params[key]
	
	API = load("res://custom_stage_loader/CustomStageAPI.gd").new();

# Based off of https://github.com/litejs/natural-compare-lite/blob/main/index.js
# I needed a state, I don't wanna talk about it.
class NaturalSorter:
	var i:int
	
	func sort(a, b):
		i = -1
		var codeA:int
		var codeB = 1
		var posA = 0
		var posB = 0
		
		if a != b:
			while codeB:
				posA += 1
				posB += 1
				codeA = _get_code(a, posA)
				codeB = _get_code(b, posB)
				
				if codeA < 76 && codeB < 76 && codeA > 66 && codeB > 66:
					codeA = _get_code(a, posA, posA)
					posA = i
					codeB = _get_code(b, posB, posA)
					posB = i
				
				if codeA != codeB:
					return codeA < codeB
		return false

	func _get_code(string:String, pos:int, code = null):
		if code:
			i = pos
			for _i in range(pos, string.length()):
				code = _get_code(string, _i)
				i = _i
				if code < 76 and code > 65: break
			return string.substr(pos - 1, i).to_int()
		code = string.to_utf8()[pos] if pos < string.length() else 0
		if code < 45 or code > 127:
			return code
		if code < 46: # -
			return 65
		if code < 48:
			return code - 1
		if code < 58: # 0-9
			return code + 18
		if code < 65:
			return code - 11
		if code < 91: # A-Z
			return code + 11
		if code < 97:
			return code - 37
		if code < 123: # a-z
			return code + 5
		return code - 63

# Makes a StageBackground for our stage. Needs a name.
func make_background(background_name:String, params:Dictionary = {}):
	var object_data = make_metadata(background_name, params);
	object_data.type = "StageBackground";
	data.materials += [object_data];
	
	return object_data;

# Makes a StageLayer. Requires a StageBackground (found through id);
func make_layer(layer_name:String, background_id:int = -1, params:Dictionary = {}):
	var object_data = make_metadata(layer_name, params);
	object_data.type = "StageLayer";
	
	if background_id == -1:
		var backgrounds = get_materials_of_type("StageBackground");
		if len(backgrounds) < 1: return;
		
		background_id = backgrounds[0]._id;
	
	return add_child_material(background_id, object_data);

func make_element(element_name, layer_id:int = -1, params:Dictionary = {}):
	var object_data = make_metadata(element_name, params);
	
	object_data.type = "StageElement";
	
	if layer_id == -1:
		var layers = get_materials_of_type("StageLayer");
		if len(layers) < 1: return;
		
		layer_id = layers[0]._id;
	
	return add_child_material(layer_id, object_data);
	
func make_spriteframes_animation(path:String):
	var spriteFrames = SpriteFrames.new()
	var animFrames = ModLoader._get_all_files(path, "png")
	var sorter = NaturalSorter.new()
	animFrames.sort_custom(sorter, "sort")
	
	for frame in animFrames:
		var newTexFrame = ModLoader.textureGet(frame)
		spriteFrames.add_frame("default", newTexFrame, -1)
	return spriteFrames

func make_spriteframes_image(path:String):
	var spriteFrames = SpriteFrames.new()
	var texFrame = ModLoader.textureGet(path)
	spriteFrames.add_frame("default", texFrame)
		
	return spriteFrames

# Makes dict with essential keys for all materials.
# (currently only a select few keys)
func make_metadata(obj_name, params):
	var obj_data = {"type": null, "children": []};
	
	obj_data["material_name"] = obj_name;
	obj_data["_id"] = materials;
	
	for i in params.keys():
		obj_data[i] = params[i];
	
	materials += 1;
	return obj_data;

# Adds a custom asset to the stage data.
func add_asset(material_name, asset_path, parent_id = -1, params:Dictionary = {}):
	var object_data = make_metadata(material_name, params);
	
	object_data["asset_path"] = asset_path;
	object_data["type"] = "ASSET";
	
	if parent_id == -1:
		return add_material(object_data);
	
	return add_child_material(parent_id, object_data);

# Adds a piece of data as a child to another piece of data.
# id - Material ID of parent
# obj_data - Child to add
# root - list of materials to look for parent in
func add_child_material(parent_id, obj_data, root = -1):
	if root is int:
		root = data.materials;
	
	# Recursively looking through all children for the parent, then adding the data.
	for i in root:
		if i._id == parent_id:
			obj_data["parent_id"] = i._id;
			
			if "children" in i: 
				i.children += [obj_data];
		else:
			if "children" in i:
				add_child_material(parent_id, obj_data, i.children);
	
	return obj_data;

func add_material(obj_data, root = -1):
	if root is int:
		root = data.materials;
	
	root += [obj_data];
	
	return obj_data;

# Grabs a material's ID from its name.
func get_material_id(material_name:String, root = -1):
	var real_root = root;
	if root is int: real_root = data.materials;
	
	var res = -1;
	
	# Recursively finds a material with the name provided.
	for i in real_root:
		if i.material_name == material_name:
			return i._id;
		elif "children" in i:
			if len(i.children) > 0:
				var found = get_material_id(material_name, i.children);
				if found > -1: return found;
	return res;

func get_material_data_from_id(id:int, root = -1):
	if root is int:
		root = data.materials;
	
	var res;
	for i in root:
		if i._id == id:
			return i;
		elif "children" in i:
			res = get_material_data_from_id(id, i.children);
	
	return res;

# Grabs all materials of a specific type.
func get_materials_of_type(query:String, array = -1):
	if array is int:
		array = data.materials;
	
	var res = [];
	
	for i in array:
		if i.type == query:
			res += [i];
		if len(i.children) > 0:
			# side note: i fucking hate recursion -liz
			res += get_materials_of_type(query, i.children);
	return res;
