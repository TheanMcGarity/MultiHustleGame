extends CharacterState

func _tick():
	host.apply_grav()
	host.apply_forces()
	if (current_tick > 3 or _previous_state_name() == "Fall") and host.is_grounded():
		return "Landing"
