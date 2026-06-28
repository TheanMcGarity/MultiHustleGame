extends BeastState

const JUMP_FORCE = -10
const JUMP_HORIZ_SPEED = "7.0"
const FIGHTER_JUMP_FORCE = -5
const BASE_JUMP_FORCE = -5

var jumped = false

func _enter():
	jumped = false

func _frame_0():
	if host.is_grounded():
		host.apply_force_relative("5", "0")

func _frame_5():
	host.start_projectile_invulnerability()

func _frame_14():
	if host.is_grounded() and !started_in_air:
		queue_state_change("Landing")

func _frame_16():
	host.end_projectile_invulnerability()

func detect(obj):
	if jumped:
		return
	jumped = true
	host.set_vel(0, 0)

	var mod = "1"
	if host.combo_count > 0:
		host.air_vaults = 0
	else:
		if obj.id == host.id:
			for i in range(host.air_vaults):
				mod = fixed.mul("0.85", mod)
	
	var dir = xy_to_dir(data.x, data.y)
	var dir_x = fixed.mul(dir.x, JUMP_HORIZ_SPEED)
	var dir_y = fixed.mul(dir.y, str(JUMP_FORCE if !obj.is_in_group("Fighter") else FIGHTER_JUMP_FORCE))
	dir_y = fixed.mul(dir_y, "-1")
	
	host.apply_force(fixed.mul(dir_x, mod), fixed.mul(dir_y, mod))
	
	host.apply_force("0", fixed.mul(str(BASE_JUMP_FORCE), mod))
	queue_state_change("ProjectileGrabJump")
	if !obj.is_in_group("Fighter"):
		obj.apply_force("0", fixed.mul(str(-JUMP_FORCE), mod))
		pass
		
	if !obj.is_in_group("Fighter") and host.combo_count <= 0:
		host.air_vaults += 1
