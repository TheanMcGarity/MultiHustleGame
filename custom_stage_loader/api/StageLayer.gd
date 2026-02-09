extends ParallaxLayer

# - StageLayer
# - This class handles background / foreground elements that don't affect players.
#
# - Parameters: [?children, 
#                motion_scale = Vector2(1, 1), 
#                motion_offset = Vector2(0, 0), 
#                motion_mirroring = Vector2(0, 0)]

# Creates a new instance of the Stage API for use in loading API objects.
var API = load("res://custom_stage_loader/CustomStageAPI.gd").new();

# Class Variables
var _children = []

var ready:bool;
func _ready():
	ready = true;

func _init(data:Dictionary):
	# TODO: Find something new out for mirroring, last attempt didn't cut it
	pass;
