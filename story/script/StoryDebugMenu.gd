tool
extends Control

var editor_plugin = null
var efs
const TRES_LOCATION = "res://story/resource%s"
const JSON_LOCATION = "res://story/data%s"

func load_json():
	var json_path = get_node("VBoxContainer/Contents/VBoxContainer/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit")
	var tres_path = get_node("VBoxContainer/Contents/VBoxContainer/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit2")
	var json_fs_path = ProjectSettings.globalize_path(JSON_LOCATION % json_path.text)
	var f = File.new()
	f.open(json_fs_path, File.READ)
	var json = f.get_as_text()
	ResourceSaver.save(TRES_LOCATION % tres_path.text, from_json_str_new(json))
	
	if (editor_plugin != null):
		if (efs == null):
			var ei = editor_plugin.get_editor_interface() 
			efs = ei.get_resource_filesystem()
	else:
		return
	
	if (efs.is_scanning()):
		print(efs.get_scanning_progress())
		return
		
	efs.update_file(json_fs_path)
	efs.scan()
	pass
func save_json():
	var json_path = get_node("VBoxContainer/Contents/VBoxContainer/TabContainer/GodotEditor/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit")
	var tres_path = get_node("VBoxContainer/Contents/VBoxContainer/TabContainer/GodotEditor/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit2")
	var json = to_json_str(load(TRES_LOCATION % tres_path.text))
	var json_fs_path = ProjectSettings.globalize_path(JSON_LOCATION % json_path.text)
	var f = File.new()
	f.open(json_fs_path, File.WRITE)
	f.store_string(json)
	f.close()


static func to_json_str(obj:Object) -> String:
	return JSON.print(to_dict(obj),"   ")
static func from_json_str(string:String, to:Object):
	from_dict(JSON.parse(string).result, to)
static func from_json_str_new(string:String) -> Object:
	var dict = JSON.parse(string).result
	var obj = load(dict.script_path).new()
	from_dict(dict, obj)
	return obj
	
static func to_dict(obj: Object) -> Dictionary:
	var root_dict = {}
	if not obj:
		return {"this is a":"invalid object"}
	
	root_dict["__is_resource__"]=obj is Resource
	root_dict["script_path"]=obj.get_script().get_path() if obj.get_script() else ""
	
	var dict = {}
	
	for prop in obj.get_property_list():
		if (prop.usage & PROPERTY_USAGE_STORAGE) and not prop.name in ["script", "resource_path", "resource_name", "resource_local_to_scene"]:
			var val = obj.get(prop.name)
			dict[prop.name] = _serialize_value(val)
	root_dict["data"]=dict
	return root_dict
	
static func from_dict(dict: Dictionary, target_obj: Object) -> Object:
	var dict2 = dict.data if dict.has("data") else dict
	if not target_obj or dict.empty():
		return target_obj
	
	var STORAGE = 1
	var SCRIPT_VAR = 128
	
	var dbg = target_obj.get_property_list()
	
	for prop in target_obj.get_property_list():
		var is_storage = (prop.usage & STORAGE) > 0
		var is_script_var = (prop.usage & SCRIPT_VAR) > 0
		
		if (is_storage or is_script_var) and not prop.name in ["script", "resource_path", "resource_name", "resource_local_to_scene"]:
			if dict2.has(prop.name):
				var raw_val = dict2[prop.name]
				var parsed_val = _deserialize_value(raw_val, prop.type)
				target_obj.set(prop.name, parsed_val)
				
	return target_obj

static func _serialize_value(val):
	if typeof(val) == TYPE_OBJECT:
		if val is Resource:
			return {
				"__is_resource__": true,
				"script_path": val.get_script().get_path() if val.get_script() else "",
				"data": to_dict(val)
			}
		return null
	elif typeof(val) == TYPE_VECTOR2:
		return {"__type__": "Vector2", "x": val.x, "y": val.y}
	elif typeof(val) == TYPE_COLOR:
		return {"__type__": "Color", "r": val.r8, "g": val.g8, "b": val.b8, "a": val.a8}
	elif typeof(val) == TYPE_ARRAY:
		var list = []
		for element in val:
			list.append(_serialize_value(element))
		return list
	elif typeof(val) == TYPE_DICTIONARY:
		var inner_dict = {}
		for key in val:
			inner_dict[key] = _serialize_value(val[key])
		return inner_dict
	return val

static func _deserialize_value(val, expected_type):
	if typeof(val) == TYPE_DICTIONARY:
		if val.has("__is_resource__") and val["__is_resource__"]:
			var path = val["script_path"]
			if path != "":
				var res_script = load(path)
				if res_script:
					return from_dict(val["data"], res_script.new())
			return null
		elif val.has("__type__"):
			match val["__type__"]:
				"Vector2": return Vector2(val["x"], val["y"])
				"Color": return Color8(val["r"], val["g"], val["b"], val["a"])
		else:
			var inner_dict = {}
			for key in val:
				inner_dict[key] = _deserialize_value(val[key], null)
			return inner_dict
	elif typeof(val) == TYPE_ARRAY:
		var list = []
		for element in val:
			list.append(_deserialize_value(element, null))
		return list
	
	if expected_type == TYPE_INT and typeof(val) == TYPE_REAL:
		return int(val)
	return val
