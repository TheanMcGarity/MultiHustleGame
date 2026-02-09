extends Node2D

onready var CustomStageBuilder = load("res://custom_stage_loader/CustomStageBuilder.gd");
# TODO: setup loader
var API;

var stage_data:Dictionary;
var stage_loaded:bool = false;
var stage_icons_imported:bool = false
onready var stage_holder;

var cur_stage:int = 0;
var stages = [];

func _ready():
	add_stage(CustomStageBuilder.new({ stage_name = "Default" }).data)
	
	# Add V1 importer
	add_child(load("res://stage_loader/StageCatalog.gd").new())

func select_stage(stage_idx:int = 0):
	cur_stage = stage_idx;
	
	update_stage_selection();

func add_stage(new_stage:Dictionary):
	stages.append(new_stage);
	print("CSL: Added Stage " + str(new_stage.stage_name));
	
	return stages;

func update_stage_selection():
	if no_stages_present(): return true;
	
	cur_stage = min(cur_stage, len(stages) - 1);
	stage_data = stages[cur_stage];
	
	return false;

func no_stages_present():
	return len(stages) == 0;

func load_stage(root):
	if update_stage_selection(): return;
	
	unload_stage();
	if not stage_data.has("disable_cache") or stage_data.disable_cache != true:
		import_stage_assets();
	
	API = load("res://custom_stage_loader/CustomStageAPI.gd").new();
	# stage_holder = load("res://custom_stage_loader/api/StageCanvas.gd").new();
	stage_holder = API.load_object({"type": "StageCanvas", "material_name": "STAGE_ROOT", "_id": "@STAGE_ROOT"});
	
	# I'm sorry God, for I have sinned.
	# This is a "main" checker. The worst possible kind.
	var root_workaround = false;
	if root.has_node("SpeedLinesLayer"):
		root_workaround = root.get_node("SpeedLinesLayer");
	
	if root_workaround:
		root.add_child_below_node(root_workaround, stage_holder);
	else:
		root.add_child(stage_holder);
	
	for material in stage_data.materials:
		var loaded_data = API.load_object(material, stage_holder);
		
		if "loaded_by" in loaded_data:
			get(loaded_data.loaded_by).add_child(loaded_data);
			# print("Adding new data of type '" + material.type + "' to instance named '" + loaded_data.loaded_by + "'!");
		else:
			stage_holder.add_child(loaded_data);
	
	### Layering Management
	# This stuff keeps UI in front and BG in the back.
	if root_workaround:
		var keep_on_top = ["SpeedLinesLayer", "GhostLayer", "HudLayer", "UILayer"];
		var keep_below = ["BGLayer"];
		
		var z_minmax = Vector2(1, 1);
		for i in stage_holder.get_children():
			if "csl_data" in i:
				var _data = i.csl_data;
				if _data.type == "StageBackground" and ("layer" in _data):
					# We're handling backgrounds.
					# TODO: Find a better way to handles this.
					z_minmax.x = min(_data.layer, z_minmax.x);
					z_minmax.y = max(_data.layer, z_minmax.y);
		
		for i in keep_on_top:
			var _layer = root.get_node(i);
			if _layer: _layer.layer = z_minmax.y;
			
		for i in keep_below:
			var _layer = root.get_node(i);
			if _layer: _layer.layer = z_minmax.x;
	
	# Makes sure all elements load the game in their scripts (if they want to)
	if is_instance_valid(stage_holder.game):
		stage_holder.emit_signal("game_changed");
	
	stage_loaded = true;

func unload_stage():
	if is_instance_valid(stage_holder):
		stage_holder.free();

func import_stage_assets(stage = stage_data):
	var stage_id = Utils.filter_filename(stage_data.stage_name if not stage_data.stage_id else stage_data.stage_id)
	var file_name = "user://csl/stages/%s" % stage_id
	var pck_path = "%s.pck" % file_name
	var md5_path = "%s.md5" % file_name
	var importer = load("res://custom_stage_loader/importer/Importer.gd").new(pck_path)
	var resources: PoolStringArray = find_all_resources(stage.materials)
	var dir = Directory.new()
	var missed_assets = PoolStringArray()
	
	# Exclude stage icons (they are already loaded on game start)
	if stage.stage_icon and stage.stage_icon in resources:
		for i in resources.size():
			if resources[i] == stage.stage_icon:
				resources.remove(i)
				break
	
	# Get all the assets required for this stage
	var assets = PoolStringArray()
	for resource in resources:
		if not dir.file_exists(resource):
			missed_assets.append(resource)
		elif resource.get_extension() in importer.file_types.keys():
			assets.append(resource)
		elif resource.get_extension() == "tscn" or resource.get_extension() == "tres":
			var resource_assets = find_all_assets(resource)
			for resource_asset in resource_assets:
				if not dir.file_exists(resource_asset):
					missed_assets.append(resource_asset)
				elif resource_asset.get_extension() in importer.file_types.keys() and not resource_asset in assets:
					assets.append(resource_asset)
	
	# Go through each asset and check if we even need to use a .pck file
	var pck_required = false
	for asset in assets:
		if dir.file_exists(asset + ".import"):
			var import_file = ConfigFile.new()
			import_file.load(asset + ".import")
			var dest = import_file.get_value("remap", "path", null)
			if dest and dir.file_exists(dest):
				continue
		pck_required = true
		break
	if not pck_required: return missed_assets
	
	# Hash-check any existing .pck we have already to check if we need to re-create the .pck
	var file = File.new()
	var hashes = ConfigFile.new()
	var recreate_pck = !dir.file_exists(pck_path) or !dir.file_exists(md5_path)
	if not recreate_pck:
		hashes.load(md5_path)
		for asset in assets:
			if file.get_md5(asset) != hashes.get_value("file_md5", asset, null):
				recreate_pck = true
				break
			# Also check for .import file changes (this is an empty string if it doesn't exist)
			if file.get_md5(asset + ".import") != hashes.get_value("import_md5", asset, null):
				recreate_pck = true
				break
	
	# Now we finally load the .pck, and write hashes
	if recreate_pck:
		print("CSL: caching assets ", assets)
		for asset in assets:
			hashes.set_value("file_md5", asset, file.get_md5(asset))
			hashes.set_value("import_md5", asset, file.get_md5(asset + ".import"))
			importer.import_file(asset)
		if importer.opened:
			importer.close()
			hashes.save(md5_path)
	else:
		print("CSL: loading cached assets from ", pck_path, ": ", assets)
		ProjectSettings.load_resource_pack(pck_path)
	
	# Return missing assets
	return missed_assets

func import_stage_icons():
	if stage_icons_imported: return
	var pck_path = "user://csl/icons.pck"
	var md5_path = "user://csl/icons.md5"
	var icons = PoolStringArray()
	for stage in stages:
		if stage.stage_icon != null:
			icons.append(stage.stage_icon)
	if icons.size() > 0:
		# check over each icon and make sure no changes were made
		var importer = load("res://custom_stage_loader/importer/Importer.gd").new(pck_path)
		var dir = Directory.new()
		var file = File.new()
		var hashes = ConfigFile.new()
		var recreate_icon_pck = !dir.file_exists(pck_path) or !dir.file_exists(md5_path)
		if not recreate_icon_pck:
			hashes.load(md5_path)
			for icon in icons:
				if file.get_md5(icon) != hashes.get_value("file_md5", icon, null):
					recreate_icon_pck = true
					break
				# Also check for .import file changes (this is an empty string if it doesn't exist)
				if file.get_md5(icon + ".import") != hashes.get_value("import_md5", icon, null):
					recreate_icon_pck = true
					break
		# And NOW we load them
		if recreate_icon_pck:
			for icon in icons:
				hashes.set_value("file_md5", icon, file.get_md5(icon))
				hashes.set_value("import_md5", icon, file.get_md5(icon + ".import"))
				importer.import_file(icon)
			if importer.opened:
				importer.close()
				hashes.save(md5_path)
		else:
			ProjectSettings.load_resource_pack(pck_path)
	stage_icons_imported = true

func find_all_assets(resource_path):
	var f = File.new()
	f.open(resource_path, File.READ)
	var assets = []
	var line = "]"
	var other_resources = []
	while line.find("]") != -1:
		line = f.get_line().replace("\n", "").replace("\r", "")
		if line == "":
			break
		if line.begins_with("[gd_scene") or line.begins_with("[gd_resource"):
			f.get_line() # skip the next line, that should be empty
			continue
		if not line.begins_with("[ext_resource"): continue
		var res_path = line.split("path=\"")[1].split("\" type=")[0]
		if res_path.ends_with(".tscn") or res_path.ends_with(".tres"):
			other_resources.append(res_path)
		else:
			assets.append(res_path)
	f.close()
	
	for res_path in other_resources:
		var more_assets = find_all_assets(res_path)
		for extra_asset in more_assets:
			if not extra_asset in assets:
				assets.append(extra_asset)
	
	return assets

func find_all_resources(data):
	return PoolStringArray(_find_all_resources(data).keys())

func _find_all_resources(data):
	var results = {}
	match typeof(data):
		TYPE_ARRAY:
			for child in data:
				var resources = _find_all_resources(child)
				for key in resources.keys():
					if not results.has(key):
						results[key] = 1
		TYPE_DICTIONARY:
			for value in data.values():
				var resources = _find_all_resources(value)
				for key in resources.keys():
					if not results.has(key):
						results[key] = 1
		TYPE_STRING_ARRAY:
			for string in data:
				if string.begins_with("res://") and not results.has(string):
					results[string] = 1
		TYPE_STRING:
			if data.begins_with("res://") and not results.has(data):
				results[data] = 1
	return results
