extends Control

var path
var modified

onready var button = $"%Button"

signal pressed()
signal data_updated()


func setup(replay_map, key):
	button.text = key
	button.connect("pressed", self, "emit_signal", ["pressed"])
	var data = replay_map[key]
	path = data["path"]
	modified = data["modified"]
#	if data.has("version"):
#		$VersionLabel.text = str(data.version) if data.version else ("unknown")

func _pretty(full_name):
	if full_name == null:
		return "?"
	if full_name.find("__") != -1:
		return full_name.split("__")[1]
	return full_name

func show_data():
	var match_data = ReplayManager.load_replay(path)
	if !("version" in match_data):
		return
	$"%VersionLabel".show()
	var label_text = str(match_data["version"])
	if match_data.has("selected_characters"):
		var sc = match_data.selected_characters
		var p1_name = _pretty(sc[1].name) if sc.has(1) and sc[1].has("name") else "?"
		var p2_name = _pretty(sc[2].name) if sc.has(2) and sc[2].has("name") else "?"
		label_text += " — " + p1_name + " vs " + p2_name
	$"%VersionLabel".text = label_text
	yield(get_tree(), "idle_frame")
	emit_signal("data_updated")
