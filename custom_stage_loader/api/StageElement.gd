extends "res://custom_stage_loader/scripts/TilingSprite.gd";

onready var game
var stage_root;

var current_tick = -1
var active:bool = false # <3
var finished = false
var data;

export var ticks_per_frame:int = 1;
export var looping:bool = true

# TODO: figuring out things with this
func _init(data:Dictionary):
	._init()
	
	self.data = data;

func _ready():
	if "frames" in data:
		if data.frames is String:
			if data.frames.get_extension() == "png":
				var frames = SpriteFrames.new();
				frames.add_frame("default", load(data.frames));
				set_sprite_frames(frames);
			else:
				set_sprite_frames(load(data.frames));
		else:
			set_sprite_frames(data.frames);
		set_frame(0);
	
	if "stage_root" in data:
		stage_root = data.stage_root;

func _process(_d):
	if is_instance_valid(game):
		if not is_instance_valid(game.camera):
			camera = null;
		elif camera != game.camera:
			camera = game.camera;
	else:
		game = null;
		camera = null;

func _on_tick_changed(new_tick = 0):
	current_tick = new_tick;
	
	_tick();

func _on_game_changed():
	if not is_instance_valid(stage_root): return;
	
	game = stage_root.game
	current_tick = game.current_tick
	
	if "camera" in game:
		if camera != game.camera: camera = game.camera;

func _tick():
	if active and (looping or not finished): _next_frame()

func _next_frame():
	finished = false
	ticks_per_frame = max(ticks_per_frame, 1)
	
	var frame_count = frames.get_frame_count(animation)
	var fake_frame = wrapi(current_tick, 0, ticks_per_frame * frame_count)
	var new_frame = floor(fake_frame / ticks_per_frame)
	
	if not looping and frame_count - 1 == frame and new_frame == 0:
		finished = true
	elif new_frame != frame:
		set_frame(new_frame);
		update();

func play(anim:String = "Default"):
	set_animation(anim);
	
	finished = false
	active = true

func _pause():
	active = false
