extends "res://characters/states/Landing.gd"

onready var hitbox = $Hitbox

func _frame_0():
	# Run the parent Landing.gd's lag setup — otherwise anim_length and
	# iasa_at stay at their defaults (1 / 0) and the state becomes instantly
	# interruptible, which lets Shred land actionable after a parry.
	set_lag(null)
	hitbox.scale_combo = true
	if host.combo_count > 0:
		if _previous_state_name() == "GroundToAirSpin":
			hitbox.scale_combo = false
