extends "res://characters/states/Landing.gd"

onready var hitbox = $Hitbox

func _frame_0():
	hitbox.scale_combo = true
	if host.combo_count > 0:
		if _previous_state_name() == "GroundToAirSpin":
			hitbox.scale_combo = false
