extends Control

var has_edits = false

onready var scene_tree = $"%SceneTree"
onready var l_sidebar_tabs = $"%LeftSidebarTabs"
onready var inspector = $"%Inspector"
onready var viewport = $"%Viewport"
onready var game = viewport.get_node("FakeGame")

var stage_api = preload("../CustomStageAPI.gd").new()
var stage_data = preload("../CustomStageBuilder.gd").new()
var stage_loader = preload("../CustomStageLoader.gd").new()

func _ready():
	scene_tree.tree.connect("item_selected", self, "item_selected")
	l_sidebar_tabs.set_tab_title(0, "Scene Tree")
	
	# Temp Stage Data
	stage_data.make_background("Static");
	
	#Saloon
	stage_data.make_layer("SaloonLayer", stage_data.get_material_id("Static"));
#	stage_data.make_element("Horse", stage_data.get_material_id("SaloonLayer"), {
#		"active": true,
#		"frames": "res://saloon_standalone/saloon/horse/horseframes.tres", 
#		"position": Vector2(0, -250),
#		"ticks_per_frame": 3
#	});
	
	load_builder_data()

func _process(delta):
	var display = $"%DebugDataDisplay"
	display.text = String(stage_data.data)

func load_builder_data():
	stage_loader.stages = [stage_data.data];
	stage_loader.load_stage(viewport);
	stage_loader.stage_holder._set_game(game);
	
	game.reset();
	
	# Reload scene tree
	scene_tree.call_deferred("set_scene_path","%Viewport/STAGE_ROOT")
	

# set inspector data
# things related to the inspector are kinda hacky rn ngl
func item_selected():
	var item = scene_tree.tree.get_selected()
	inspector.set_target_object(item.get_metadata(0))

func show_unsaved_dialog():
	pass

func show_save_dialog():
	pass

func _on_save(path:String):
	pass




func _on_reload_pressed():
	# Free the stage holder explicitly, so that the stage root name doesn't change
	stage_loader.unload_stage()
	load_builder_data()
