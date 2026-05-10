extends TelekinesisProjectile

func hit_action(obj):
	.hit_action(obj)
	var vel = get_vel()
	var force = fixed.vec_mul(vel.x, vel.y, "0.35")
	obj.apply_force(force.x, force.y)
	pass
