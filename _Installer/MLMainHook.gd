extends "res://modloader/MLMainHook.gd"

var download_request:HTTPRequest
const PCK_URL := "https://github.com/TheanMcGarity/MultiHustleGame/raw/refs/heads/v8/release_build/YourOnlyMoveIsHUSTLE.pck"
const VERSION_URL := "https://raw.githubusercontent.com/TheanMcGarity/MultiHustleGame/refs/heads/v8/release_build/version.txt"

var download_popup:AcceptDialog

func _ready():
	add_bat_file()
	
	download_request = HTTPRequest.new()
	add_child(download_request)

	download_request.connect("request_completed", self, "on_downloaded_ver")

	download_request.request(VERSION_URL)
	pass

func on_downloaded_ver(result, code, header, body):
	var ver = body.get_string_from_utf8()
	print("Detected latest multihustle release build's version as %s" % ver)
	if (ver != Global.VERSION):
		download_popup = load("res://_Installer/Popup.tscn").instance()
		get_tree().get_root().get_node("Main/%UILayer").add_child(download_popup)
		download_popup.connect("confirmed", self, "download_mh")
		download_popup.popup()
		print("Asking for user to download %s" % ver)
	else:
		print("%s is installed! (%s)" % [ver, Global.VERSION])
		download_request.queue_free()

func on_downloaded_mh(result, code, header, body):
	var user_dir = ProjectSettings.globalize_path("user://")
	var bat_dir = ProjectSettings.globalize_path("user://MH.bat")
	var game_dir = OS.get_executable_path().get_base_dir()
	var game_pck_dir = "%s/YourOnlyMoveIsHUSTLE.pck" % game_dir
	var game_exe_dir = "%s/YourOnlyMoveIsHUSTLE.exe" % game_dir
	var inner_cmd = "\"" + bat_dir + "\" \"" + game_pck_dir + "\" \"" + user_dir + "\" \"" + game_dir + "\""
	var arguments:PoolStringArray = ["/c", inner_cmd]
	
	var exit_code = OS.execute("cmd.exe", arguments, false, [], false,  true)
	get_tree().quit()
	download_request.queue_free()

func download_mh():
	download_request.disconnect("request_completed", self, "on_downloaded_ver")
	download_request.connect("request_completed", self, "on_downloaded_mh")
	
	download_request.set_download_file("user://MH.pck")
	
	download_request.request(PCK_URL)

func add_bat_file():
	var dir := Directory.new()
	dir.copy("res://_Installer/intall.bat", "user://MH.bat")
