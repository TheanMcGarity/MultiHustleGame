extends Node

# + CSL v1 Backwards Compatibility Script
# - Authors: Snazzah
#
# - Turns V1 stages to V2 stages

signal stage_added();

onready var CustomStageBuilder = load("res://custom_stage_loader/CustomStageBuilder.gd");
onready var Loader = get_tree().get_root().get_node("CSL");

class StageData:
	var id = 0
	var displayName = "New Layer"
	var layers = []
	var bg_color:Array = [11, 12, 15] setget set_stage_color;
	func _init(id: int = 0, display_name: String = "New Layer"):
		self.id = id;
		displayName = display_name;
	
	func set_stage_color(rgb: Array):
		bg_color = rgb;
	
	func addLayer(layer: LayerData):
		layers.append(layer);

class LayerData:
	var layer_name:String = "Unnamed Layer";
	var sprite_path:String = "";
	var motion:Vector2 = Vector2(1, 1);
	var mirrorX:bool = false;
	var mirrorY:bool = false;
	var ground:bool = false;
	
	func _init(path:String = "", motion:Vector2 = Vector2(1, 1), mirrorX:bool = false, mirrorY:bool = false, ground:bool = false):
		self.sprite_path = path;
		self.motion = motion;
		self.mirrorX = mirrorX;
		self.mirrorY = mirrorY;
		self.ground = ground;
	
	func _set_name(_name: String):
		layer_name = _name;


func _ready():
	name = "V1Importer"


func addStage(stage: StageData):
	print("CSL: Converting V1 Stage " + str(stage.displayName));
	emit_signal("stage_added", stage);
	
	var Builder = CustomStageBuilder.new({ stage_name = stage.displayName });
	var bg = Builder.make_background("BaseBackground", {
		"bg_color": Color8(stage.bg_color[0], stage.bg_color[1], stage.bg_color[2], stage.bg_color[3] if stage.bg_color.size() > 3 else 255)
	});
	var stage_error = false
	
	for i in stage.layers.size():
		var layer = stage.layers[i]
		var v2layer = Builder.make_layer("Layer%d" % i, bg._id, { "motion_scale": layer.motion });
		
		var tex = ModLoader.textureGet(layer.sprite_path);
		if tex is int and tex == 0:
			print("CSL: !!!   V1 Stage is missing an asset: ", layer.sprite_path, "   !!!")
			stage_error = true
			continue
		var frames = SpriteFrames.new()
		frames.add_frame("default", tex)
		
		Builder.make_element("Element%d" % i, v2layer._id, {
			"frames": frames,
			"position": Vector2(0, (tex.get_height() / 2) * (1 if layer.ground else -1)),
			"h_tile": layer.mirrorX,
			"v_tile": layer.mirrorY,
			"mirror": layer.mirrorX or layer.mirrorY
		});
	
	if stage_error:
		print("CSL: !!! Failed to load V1 stage: ", str(stage.displayName))
		return
	Loader.add_stage(Builder.data);

