extends Window

const TRES_LOCATION = "res://story/resource%s"
const JSON_LOCATION = "res://story/data%s"

func load_json():
	var json_path = get_node("VBoxContainer/Contents/VBoxContainer/TabContainer/GodotEditor/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit")
	var tres_path = get_node("VBoxContainer/Contents/VBoxContainer/TabContainer/GodotEditor/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit2")
	var json_fs_path = ProjectSettings.globalize_path(JSON_LOCATION % json_path.text)
	var f = File.new()
	f.open(json_fs_path, File.READ)
	var json = f.get_as_text()
	ResourceSaver.save(ProjectSettings.globalize_path(TRES_LOCATION % tres_path.text), JSONManager.from_json_str_new(json))
	pass
func save_json():
	var json_path = get_node("VBoxContainer/Contents/VBoxContainer/TabContainer/GodotEditor/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit")
	var tres_path = get_node("VBoxContainer/Contents/VBoxContainer/TabContainer/GodotEditor/ScrollContainer/VBoxContainer/HBoxContainer/LineEdit2")
	var json = JSONManager.to_json_str(load(TRES_LOCATION % tres_path.text))
	var json_fs_path = ProjectSettings.globalize_path(JSON_LOCATION % json_path.text)
	var f = File.new()
	f.open(json_fs_path, File.WRITE)
	f.store_string(json)
	f.close()
