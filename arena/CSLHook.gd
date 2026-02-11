extends "res://main.gd"

var arena_button_path = preload("res://arena/ArenaButton.tscn")
onready var arena_settings := preload("res://arena/SingleArenaSettings.tscn").instance()
onready var steam_arena_settings := preload("res://arena/SteamArenaSettings.tscn").instance()
onready var character_select = $"%CharacterSelect"

var arenas = {}

func _ready():
	var steam_lobby_list = ui_layer.get_node("SteamLobbyList")
	steam_lobby_list.add_child(steam_arena_settings)
	steam_lobby_list.move_child(steam_arena_settings, 0)
	steam_lobby_list.rect_position.x = 106
#	steam_lobby_list.get_node("NetworkSetupScreen/Panel/MarginContainer/HBoxContainer2/Version").text = "Arena Name"
	
	var create_lobby_button = steam_lobby_list.get_node("%CreateLobbyButton")
	create_lobby_button.connect("pressed", steam_arena_settings, "_on_create_lobby_button_pressed")
	
	steam_arena_settings.rect_position.x = -103
	steam_arena_settings.rect_position.y = -17
	steam_arena_settings.steam_lobby_list = steam_lobby_list
	arena_settings.steam_lobby_list = steam_lobby_list
	
	var steam_back_button = steam_lobby_list.get_node("%BackButton")
	steam_back_button.connect("pressed", steam_arena_settings, "_on_exit_lobby_list_button_pressed")
	
	var steam_lobby = ui_layer.get_node("%SteamLobby")
	var steam_lobby_back_button = steam_lobby.get_node("%BackButton")
	steam_lobby_back_button.connect("pressed", steam_arena_settings, "_on_exit_lobby_list_button_pressed")
	
	var single_back_button = $"%CharacterSelect".get_node("%QuitButton")
	single_back_button.connect("pressed", steam_arena_settings, "_on_exit_lobby_list_button_pressed")
	
	var steam_game_settings = steam_lobby.get_node("%GameSettingsPanelContainer")
	steam_arena_settings.game_settings = steam_game_settings
	
	var game_settings = ui_layer.get_node("%CharacterSelect").get_node("%GameSettingsPanelContainer").get_node("%GameSettings")
	game_settings.settings_nodes["select_arena"] = arena_settings
	game_settings.rect_position.x = 300
	
	arena_settings.connect("value_changed", game_settings, "_setting_value_changed", ["select_arena"])
	arena_settings.game_settings = game_settings
	
	var game_formats_container = game_settings.get_node("%GameFormats")
	game_formats_container.add_child(arena_settings)
	game_formats_container.move_child(arena_settings, 0)
	arena_settings.rect_position.x = -110
	arena_settings.rect_position.y = -120
	
	$"%ButtonContainer".alignment = 0
	$"%MultiplayerButton".visible = false
	$"%DirectConnectButton".visible = false
	
#	# fix everything later
#	$"UILayer/MainMenu/ButtonContainer/RankedButton".visible = false
#
#	var arena_info = {
#		"name": "Ranked",
#		"stage_name": "",
#		"manager_scene": "res://_base_arena/ArenaManager.tscn",
#		"button_image": "res://_base_arena/base_arena_banner.png",
#		"button_text": "[wave amp=18.0 freq=6.0 connected=1]Ranked[/wave]",
#		"settings": {},
#		"custom_button": "res://arena/RankedArenaButton.tscn"
#	}
#
#	add_custom_arena(arena_info)


func _createImportFiles(folder, _charName, _charPath):
	var dir = Directory.new()

	
	var md = ModLoader._readMetadata(folder + "/_metadata")
	var modName = md.name
	if (modName in character_select.charPackages.keys()):
		character_select.loadingText = "Loading Cached Package"
		ProjectSettings.load_resource_pack(character_select.charPackages[modName])
		return []
	
	character_select._import_start()

	var assets = ModLoader._get_all_files(folder, "png") + ModLoader._get_all_files(folder, "wav") + ModLoader._get_all_files(folder, "ogg")
	var delList = []
	
	var missingFiles = []

	for i in len(assets):
		if ( not dir.file_exists(assets[i] + ".import")):
			missingFiles.append(assets[i] + ".import")
		else :
			character_select.loadingText = "Loading " + character_select.getCharName(_charName) + " - " + str(int((float(i) / len(assets)) * 100)) + "%"
			
			
			var c = ConfigFile.new()
			c.load(assets[i] + ".import")
			var dest = c.get_value("remap", "path")

			if ( not dir.file_exists(dest)):
				
				var tmpFile = "user://mod_temp/" + dest.split("://.import/")[1]
				if (dest.ends_with(".stex")):
					var img = Image.new()
					img.load(assets[i])
					character_select.save_stex(img, tmpFile)
				elif (dest.ends_with(".oggstr")):
					character_select.save_oggstr(assets[i], tmpFile)
				else :
					character_select.save_sample(assets[i], tmpFile)
				
				
				character_select.p.add_file(dest, tmpFile)
				delList.append(tmpFile)
	
	
	if (dir.dir_exists(folder + "/.import")):
		var imports = ModLoader._get_all_files(folder)
		for f in imports:
			character_select.p.add_file("res://.import/" + f.split(".import/")[1], f)
	
	character_select._import_end()

	
	var imports = ModLoader._get_all_files(folder, "import")
	for f in imports:
		if (dir.file_exists(f.replace(".import", ""))):
			var im = ConfigFile.new()
			im.load(f)
			var expected = im.get_value("remap", "path")
			if not dir.file_exists(expected):
				missingFiles.append(expected)
	
	for f in delList:
		dir.remove(f)
	dir.remove("user://mod_temp")

	if (missingFiles == []):
		character_select._import_copy("user://char_cache/" + modName.validate_node_name() + "-" + md.author.validate_node_name() + "-" + str(character_select.folder_to_hash(folder)) + "-" + character_select.clVersion.validate_node_name() + ".pck")

	return missingFiles


func add_custom_arena(arena):
	var folder_name = arena.manager_scene.split("/")[2]
	print(folder_name)
	
	var arena_button = arena_button_path.instance() if not "custom_button" in arena or not arena.custom_button else load(arena.custom_button).instance()
	arena_button.name = arena.name
	
	_createImportFiles("res://" + folder_name, arena.name, arena.manager_scene)
	
	arena_button.icon = ModLoader.textureGet(arena.button_image)
	arena_button.get_node("ArenaName").bbcode_text = arena.button_text
	
	var steam_arena_button = arena_button.duplicate()
	var arena_version_name = arena.version_name if "version_name" in arena else arena.name
	
	arena_button.connect("pressed", arena_settings, "_on_ArenaButton_pressed", [arena.name, arena.settings, arena_version_name])
	arena_settings.arena_buttons[arena.name] = arena_button
	arena_settings.arena_container.add_child(arena_button)
	
	arenas[arena_version_name] = arena
	
	steam_arena_button.connect("pressed", steam_arena_settings, "_on_ArenaButton_pressed", [arena.name, arena.settings, arena_version_name])
	steam_arena_settings.arena_buttons[arena.name] = steam_arena_button
	steam_arena_settings.arena_container.add_child(steam_arena_button)


func _on_match_ready(data):
	._on_match_ready(data)
	
	var selected_arena = null
	
	if "version" in data:
		Global.VERSION = data.version
	
	if Global.VERSION.split(" ", true, 1).size() > 1:
		if " MH-" in Global.VERSION:
			selected_arena = Global.VERSION.split(" ", true, 2)[2]
		else:
			selected_arena = Global.VERSION.split(" ", true, 1)[1]
	
	if selected_arena:
		var arena_index = 0 
		
		for index in Loader.stages.size():
			var stage_data = Loader.stages[index]
			if "stage_name" in stage_data and arenas[selected_arena].stage_name == stage_data.stage_name:
				arena_index = index
				break
		
		if arena_index:
			Loader.select_stage(arena_index)
			if Loader.stage_data.has("stage_name"):
				curStage = Loader.stage_data.stage_name


func setup_game_deferred(singleplayer, data):
	.setup_game_deferred(singleplayer, data)
	
	var selected_arena = null
	
	if Global.VERSION.split(" ", true, 1).size() > 1:
		if " MH-" in Global.VERSION:
			selected_arena = Global.VERSION.split(" ", true, 2)[2]
		else:
			selected_arena = Global.VERSION.split(" ", true, 1)[1]
	
	if selected_arena:
		var arena_manager = load(arenas[selected_arena].manager_scene)
		var arena_manager_obj = game.get_player(1).spawn_object(arena_manager, 0, -64, false, null, false)
		arena_manager_obj.id = 0
