extends ParallaxBackground

# - StageBackground
# - This class handles actual *layering* of StageLayers, since it's the actual
# - background itself.
#
# - Parameters: [?children, layer = -100]

# Special API classes have to have a "loaded_by" property.
# This property makes sure this object is placed under the correct parent.
# (ignored if the instance is a child of another API-class instance)
var loaded_by = "stage_holder"; # Refer to the loader script for options

# The API also responds to objects that have a "csl_data" property.
var csl_data;

# Creates a new instance of the Stage API for use in loading API objects.
var API = load("res://custom_stage_loader/CustomStageAPI.gd").new();

# Class Variables
var _children = [];

var bg_colorrect = ColorRect.new()

func _init(data:Dictionary):
	._init();
	
	if not data.has("layer"): layer = 1;
	if data.has("bg_color"):
		bg_colorrect.color = data.bg_color
		bg_colorrect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_colorrect.anchor_right = 1
		bg_colorrect.anchor_bottom = 1
		add_child(bg_colorrect)
