extends BeastState

const FORCE = "19"

func process_projectile(obj):
	obj.set_grounded(false)
	var dir = xy_to_dir(data.x, data.y, FORCE)
	obj.apply_force(dir.x, dir.y)
	host.gas_bomb_projectile = obj.obj_name

func is_usable():
	var proj = host.obj_from_name(host.gas_bomb_projectile)
	if proj:
		return false
	# Lock out for one turn after the bloom toggle is used — prevents an
	# immediate fresh bomb on the turn right after detonating the last one.
	if host.bloomed_last_turn:
		return false
	return .is_usable()
