extends "res://modloader/MLMainHook.gd"

var download_request:HTTPRequest
const PCK_URL := "https://github.com/TheanMcGarity/MultiHustleGame/raw/refs/heads/v8/installer_builds/%s_build/YourOnlyMoveIsHUSTLE.pck"
const VERSION_URL := "https://raw.githubusercontent.com/TheanMcGarity/MultiHustleGame/refs/heads/v8/installer_builds/%s_build/version.txt"
const PREF_PATH := "%s/mh_install_pref.txt"
var popup_node:AcceptDialog
var manual_branch := "release"
func get_branch():
	if (Global.get("get_upd_branch_str") != null):
		return Global.get_upd_branch_str()
	if (Global.get("update_branch") != null):
		return Global.get_upd_branch()
	return manual_branch
func get_ver_url():
	return VERSION_URL % get_branch()
func get_pck_url():
	return PCK_URL % get_branch()
func _ready():
	add_bat_file()
	
	if (not "mh" in Global.VERSION):
		on_vanilla_detected()
		return
	elif (Global.get("update_branch") != null):
		load_pref()
		Global.update_branch = get_upd_branch_int(manual_branch)
		Global.save_options()
	download_request = HTTPRequest.new()
	add_child(download_request)

	download_request.connect("request_completed", self, "on_downloaded_ver")

	download_request.request(get_ver_url())
	pass

func on_vanilla_detected():
	popup_node = load("res://_Installer/VersionRequest.tscn").instance()
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
		popup_node = load("res://_Installer/Error.tscn").instance()
		get_tree().get_root().get_node("Main/%UILayer").add_child(popup_node)
		popup_node.text = popup_node.text % code
		popup_node.popup()
		return
	var user_dir = ProjectSettings.globalize_path("user://")
	var bat_dir = ProjectSettings.globalize_path("user://MH.bat")
	var game_dir = OS.get_executable_path().get_base_dir()
	var game_pck_dir = "%s/YourOnlyMoveIsHUSTLE.pck" % game_dir
	var game_exe_dir = "%s/YourOnlyMoveIsHUSTLE.exe" % game_dir
	var inner_cmd = "\"" + bat_dir + "\" \"" + game_pck_dir + "\" \"" + user_dir + "\" \"" + game_dir + "\""
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
func load_pref():
	var data_path = PREF_PATH % get_vanilla_yomi_data()
	var f = File.new()
	f.open(data_path, File.WRITE)
	manual_branch = f.get_buffer(f.get_len()).get_string_from_utf8()
	f.close()
	pass
func get_vanilla_yomi_data():
	return ProjectSettings.globalize_path("user://")+"../YourOnlyMoveIsHUSTLE"

func get_upd_branch_int(branch):
	match branch:
		"release":
			return 0
		"beta":
			return 1
		"prev":
			return 2
		"alpha":
			return 3
		_:
			return 0
