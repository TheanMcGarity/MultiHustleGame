extends Node

onready var CustomStageLoader = load("res://custom_stage_loader/CustomStageLoader.gd");
var Loader;

func _init(modLoader = ModLoader):
	modLoader.installScriptExtension("res://custom_stage_loader/CSLHook.gd")
	modLoader.installScriptExtension("res://custom_stage_loader/CSLOptions.gd")
	
	call_deferred("get_loader");

func get_loader():
	if get_tree().get_root().has_node("CSL"):
		Loader = get_tree().get_root().get_node("CSL");
	else:
		Loader = CustomStageLoader.new();
		Loader.name = "CSL";
		
		get_tree().get_root().add_child(Loader);
