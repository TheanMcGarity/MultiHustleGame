extends "res://main.gd";

onready var CustomStageLoader = load("res://custom_stage_loader/CustomStageLoader.gd");
var Loader;

onready var CustomStageBuilder = load("res://custom_stage_loader/CustomStageBuilder.gd");

# V1 Compatibility Property
var curStage:String = "";

func _ready():
	call_deferred("get_loader");

func get_loader():
	if get_tree().get_root().has_node("CSL"):
		Loader = get_tree().get_root().get_node("CSL");
	else:
		Loader = CustomStageLoader.new();
		Loader.name = "CSL";
		
		get_tree().get_root().add_child(Loader);
	pass;

func _on_match_ready(data):
	._on_match_ready(data);
	
	# For being more V1 compatible, we select the stage we want here and set "curStage" from here
	# On "setup_game_deferred" the stage will be loaded
	if Loader.stage_loaded and is_instance_valid(Loader.stage_holder): return
	var ModOptions = get_tree().get_root().get_node("Main/ModOptions");
	if ModOptions:
		var selected_stage = ModOptions.get_setting("CustomStageLoader", "stageSelect")
		if ModOptions.get_setting("CustomStageLoader", "randomStage"):
			var rng = RandomNumberGenerator.new()
			rng.seed = OS.get_unix_time()
			
			var random_stages = ModOptions.get_setting("CustomStageLoader", "randomStageSelect")
			var random_stage_ids = []
			for i in Loader.stages.size():
				if Loader.stages[i].stage_name in random_stages:
					random_stage_ids.append(i)
			if random_stage_ids.size() == 0:
				random_stage_ids = range(Loader.stages.size())
			selected_stage = random_stage_ids[rng.randi_range(0, random_stage_ids.size() - 1)]
		if selected_stage >= Loader.stages.size():
			selected_stage = 0
		
		Loader.select_stage(selected_stage)
		if Loader.stage_data.has("stage_name"):
			curStage = Loader.stage_data.stage_name

func setup_game_deferred(singleplayer, data):
	.setup_game_deferred(singleplayer, data);
	
	# Stage gets loaded here, along with stage lines being updated
	var ModOptions = get_tree().get_root().get_node("Main/ModOptions");
	if ModOptions:
		if ModOptions.get_setting("CustomStageLoader", "drawLines") == true:
			game.draw_stage = false
			var draw_holder = Node2D.new()
			draw_holder.set_script(load("res://custom_stage_loader/CustomStageDraw.gd"))
			game.add_child(draw_holder)
			game.move_child(draw_holder, 0)
			draw_holder.draw_pips = ModOptions.get_setting("CustomStageLoader", "drawPips")
		elif ModOptions.get_setting("CustomStageLoader", "drawLines") == false:
			game.draw_stage = false
	
	if Loader.stage_loaded and is_instance_valid(Loader.stage_holder): return
	Loader.load_stage(self);
