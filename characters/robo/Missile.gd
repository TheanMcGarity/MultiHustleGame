extends RobotState

const MISSILES = 3
var missiles_left = MISSILES

export(PackedScene) var arc_projectile_scene = null

func _enter():
	missiles_left = MISSILES

func _is_arc():
	return data and data.has("y") and data.y < 0

func _is_up():
	return _is_arc() and data.has("x") and data.x == 0

func get_projectile_pos():
	if _is_up():
		return { "x": -5, "y": projectile_pos_y - 20 }
	return .get_projectile_pos()

func apply_timed_force():
	if _is_up():
		if force_speed != "0.0":
			var force = xy_to_dir("0", "1", force_speed, "1.0")
			host.apply_force_relative(force.x, force.y)
	else:
		.apply_timed_force()

func spawn_exported_projectile():
	var scene = arc_projectile_scene if (_is_arc() and arc_projectile_scene) else projectile_scene
	if scene:
		var pos = get_projectile_pos()
		var obj = host.spawn_object(scene, pos.x, pos.y, true, get_projectile_data(), projectile_local_pos)
		if projectile_match_facing:
			obj.set_facing(host.get_facing_int())
		process_projectile(obj)

func process_projectile(obj):
	.process_projectile(obj)
	var idx = MISSILES - missiles_left
	var particle_dir = Vector2.RIGHT
	if _is_arc():
		particle_dir = Vector2(1, -1.0 + 0.3 * idx)
	spawn_particle_relative(timed_particle_scene, timed_particle_position, particle_dir)
	obj.z_index = host.z_index + 1
	obj.arc_index = idx
	obj.is_up_missile = _is_up()
	missiles_left -= 1
	if missiles_left > 0:
		current_tick = 1

func is_usable():
	return .is_usable()
