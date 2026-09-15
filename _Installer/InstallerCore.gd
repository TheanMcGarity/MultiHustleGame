extends Node

class_name MHInstaller

var download_request:HTTPRequest
const PCK_URL := "https://github.com/TheanMcGarity/MultiHustleGame/raw/refs/heads/v8/installer_builds/%s_build/YourOnlyMoveIsHUSTLE.pck"
const VERSION_URL := "https://raw.githubusercontent.com/TheanMcGarity/MultiHustleGame/refs/heads/v8/installer_builds/%s_build/version.txt"
const DATA_URL := "https://raw.githubusercontent.com/TheanMcGarity/MultiHustleGame/refs/heads/v8/installer_builds/build_collection.json"

const PREF_PATH := "%s/mh_install_pref.txt"

onready var data = init_data()

var branches := { 
	"release": 0,
	0: "release"
}

var wait := false
signal end_wait

var popup_node:AcceptDialog
var manual_branch := "release"

func get_branch():
	if (Global.has_method("get_upd_branch_str")):
		return Global.get_upd_branch_str()
	if (Global.get("update_branch") != null):
		return Global.get_upd_branch()
	return manual_branch
func get_ver_url():
	return VERSION_URL % get_branch()
func get_pck_url():
	return PCK_URL % get_branch()
func init_data():
	var req = HTTPRequest.new()
	req.pause_mode = Node.PAUSE_MODE_PROCESS 
	add_child(req)

	req.request(DATA_URL)
	wait = true
	var result = yield(req, "request_completed")
	wait = false
	
	data = JSON.parse(result[3].get_string_from_utf8()).result
	
	emit_signal("end_wait")
	pass

func _ready():
	if wait:
		yield(self, "end_wait")
		
	add_bat_file()
	
	if (not "mh" in Global.VERSION):
		on_vanilla_detected()
		return
	elif (Global.get("update_branch") != null):
		var data_path = PREF_PATH % get_vanilla_yomi_data()
		if (Directory.new().file_exists(data_path)):
			load_pref(true)
			Global.update_branch = get_upd_branch_int(manual_branch)
			Global.save_options()
	else:
		load_pref(false)
	download_request = HTTPRequest.new()
	add_child(download_request)

	download_request.connect("request_completed", self, "on_downloaded_ver")

	download_request.request(get_ver_url())
	pass

func on_vanilla_detected():
	if (OS.get_name() != "Windows"):
		inform_error(data.installer_messages["err.os"])
		return
	
	popup_node = load("res://_Installer/VersionRequest.tscn").instance()
	
	var selector = popup_node.get_node("UpdateBranch")
	update_branches(selector)
	get_tree().get_root().get_node("Main/%UILayer").add_child(popup_node)
	popup_node.connect("confirmed", self, "on_select_branch")
	popup_node.popup()

func on_select_branch():
	var selector = popup_node.get_node("UpdateBranch")
	manual_branch = selector.get_item_text(selector.selected)
	
	download_request = HTTPRequest.new()
	add_child(download_request)

	download_request.connect("request_completed", self, "on_downloaded_ver")

	download_request.request(get_ver_url())
	
func on_downloaded_ver(result, code, header, body):
	var ver = body.get_string_from_utf8()
	print("Detected latest multihustle %s build's version as %s" % [get_branch(), ver])
	if (ver != Global.VERSION):
		popup_node = load("res://_Installer/Popup.tscn").instance()
		get_tree().get_root().get_node("Main/%UILayer").add_child(popup_node)
		popup_node.connect("confirmed", self, "download_mh")
		popup_node.popup()
		print("Asking for user to download %s" % ver)
	else:
		print("%s is installed! (%s)" % [ver, Global.VERSION])
		download_request.queue_free()

func on_downloaded_mh(result, code, header, body):
	if (code != 200):
		if (data.installer_messages.has("err.download_failed.code%d" % code)):
			inform_error(data.installer_messages["err.download_failed.code%d"%code])
		else:
			inform_error(data.installer_messages["err.download_failed.generic"] % code)
		return
	var user_dir = ProjectSettings.globalize_path("user://")
	var bat_dir = ProjectSettings.globalize_path("user://MH.bat")
	var game_dir = OS.get_executable_path().get_base_dir()
	var game_pck_dir = "%s/YourOnlyMoveIsHUSTLE.pck" % game_dir
	var game_exe_dir = "%s/YourOnlyMoveIsHUSTLE.exe" % game_dir
	var inner_cmd = "\"" + bat_dir + "\" \"" + game_pck_dir + "\" \"" + user_dir + "\\MH.pck\" \"" + game_dir + "\""
	var arguments:PoolStringArray = ["/c", inner_cmd]

	save_pref()
	
	var exit_code = OS.execute("cmd.exe", arguments, false, [], false,  true)
	download_request.queue_free()
	get_tree().quit()

func download_mh():
	download_request.disconnect("request_completed", self, "on_downloaded_ver")
	download_request.connect("request_completed", self, "on_downloaded_mh")
	
	download_request.set_download_file("user://MH.pck")
	
	download_request.request(get_pck_url())

func add_bat_file():
	var dir := Directory.new()
	dir.copy("res://_Installer/intall.bat", "user://MH.bat")

#func compare_mh_version(new):
#	var current = Global.get("MH_VERSION_DATA")
#	if (current == null):
#		return Global.VERSION == new

func save_pref():
	var data_path = PREF_PATH % get_vanilla_yomi_data()
	var f = File.new()
	f.open(data_path, File.WRITE)
	f.store_string(manual_branch)
	f.close()
	pass
func load_pref(erase):
	var data_path = PREF_PATH % get_vanilla_yomi_data()
	var f = File.new()
	f.open(data_path, File.WRITE)
	manual_branch = f.get_buffer(f.get_len()).get_string_from_utf8()
	f.close()
	if erase:
		Directory.new().remove(data_path)
	pass
func get_vanilla_yomi_data():
	return ProjectSettings.globalize_path("user://")+"../YourOnlyMoveIsHUSTLE"

# replaced with new system, used to be hardcoded `match`
func get_upd_branch_int(branch):
	return branches[branch]

func update_branches(selector:OptionButton):
	if wait:
		yield(self, "end_wait")
	selector.connect("item_selected", self, "on_update_branch", [selector])
	selector.clear()
	
	for branch_id in data.branches:
		var branch = data.branches[branch_id]
		branches[int(branch_id)] = branch.name
		branches[branch.name] = int(branch_id)
		
		if (not branch.active):
			continue
		
		selector.add_item(branch.name, int(branch_id))
		
		pass
func on_update_branch(idx, selector):
	if wait:
		yield(self, "end_wait")
	var branch_name = selector.get_item_text(idx)
	var id = branches[branch_name]
	var branch = data.branches[str(id)]
	
	match int(branch.unstable_level):
		0:
			pass
		_:
			var err = inform_error(data.installer_messages["w.unstable.lvl_%d" % branch.unstable_level])
			yield(err, "confirmed")
	
	match int(branch.stable_version_relative):
		-1:
			var err = inform_error(data.installer_messages["w.older_version"])
			yield(err, "confirmed")
		1:
			var err = inform_error(data.installer_messages["w.newer_version"])
			yield(err, "confirmed")
		_:
			continue
	
	if (is_ver_older(Global.VERSION, branch.yomi_ver)):
			var err = inform_error(data.installer_messages["w.old_steam_ver"] % [branch_name, branch.yomi_ver, branch.mh_ver])
			yield(err, "confirmed")
	pass
	
func is_ver_older(curr, upd):
	var curr_array = calc_yomi_ver_array(curr)
	var upd_array = calc_yomi_ver_array(upd)
	
	if (upd_array[0] < curr_array[0]):
		return true
	if (upd_array[1] < curr_array[1]):
		return true
	if (upd_array[2] < curr_array[2]):
		return true
	return false
func calc_yomi_ver_array(ver):
	var step1 = ver.split(".")
	var step2 = [int(step1[0]), int(step1[1]), int(step1[2].split('-')[0])]
	return step2
func inform_error(err):
	popup_node = load("res://_Installer/Error.tscn").instance()
	get_tree().get_root().get_node("Main/%UILayer").add_child(popup_node)
	popup_node.dialog_text = err
	popup_node.popup()
	return popup_node
