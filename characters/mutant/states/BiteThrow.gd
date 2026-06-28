extends ThrowState

func _frame_0():
	host.opponent.z_index = -2
	if host.combo_proration < 3:
		host.combo_proration = 3
	# Latch it, or the next combo hit's increment_opponent_combo overwrites this
	# with that hitbox's damage_proration.
	host.combo_proration_set = true

func process_projectile(obj):
	var existing = host.obj_from_name(host.poison_projectile)
	if existing and !existing.disabled:
		existing.current_tick = 1
		obj.disable()
		return
	host.poison_projectile = obj.obj_name

