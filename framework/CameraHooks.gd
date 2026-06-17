extends Node

# Modding hook surface for GoodCamera (the match camera). Game.tscn carries one
# of these as the camera's `Hooks` child; the camera grabs it in _ready and
# calls the methods below. `host` is the GoodCamera. NOTE: no class_name — these
# hook scripts are take_over_path'd by mods (installScriptExtension), which
# breaks if the script registers a global class. Extend by path:
#
#     extends "res://framework/CameraHooks.gd"
#
# See res://obj/ObjHooks.gd for the full modding pattern.

var host = null


# The hooks node was created (host is set).
func ready():
	pass

# A screenshake was triggered. `dir` is the shake direction, `amount` the
# (clamped) intensity, `time` the duration. Fires for every bump (bump_at_location
# routes through bump too).
func screenshake(dir, amount, time):
	pass
