extends ObjectState

const ACID_BUBBLE_SCENE = preload("res://characters/mutant/projectiles/GasBombBubble.tscn")
const NUM_BUBBLES = 7
const BUBBLE_SPREAD = "3"
const STRAIGHT_FRAMES = 20
const HOMING_FORCE = "0.9"
const HOMING_DECEL = "0.85"
const MAX_HOMING_SPEED = "12"

var homing = false
var bounces = 2
var last_y_vel = "0"
var last_x_vel = "0"

func _enter():
	host.start_invulnerability()

func _tick():
	apply_grav = false
	apply_fric = homing
	if host.disabled:
		return
	host.update_grounded()
	var vel = host.get_vel()
	if !fixed.eq(vel.y, "0"):
		last_y_vel = vel.y
	if !fixed.eq(vel.x, "0"):
		last_x_vel = vel.x

	if host.get_fighter().is_in_hurt_state() and !host.get_opponent().current_state().get("IS_BURST"):
		host.disable()
		return

	if host.is_grounded():
		if !try_bounce():
			return
		host.set_grounded(false)
		host.move_directly("0", "-1")
		var v = host.get_vel()
		host.set_vel(v.x, fixed.mul(fixed.abs(last_y_vel), "-0.75"))

	var pos = host.get_pos()
	if pos.x <= -host.stage_width:
		if !try_bounce():
			return
		host.set_pos(-host.stage_width + 1, pos.y)
		var v = host.get_vel()
		host.set_vel(fixed.mul(fixed.abs(last_x_vel), "0.75"), v.y)
	elif pos.x >= host.stage_width:
		if !try_bounce():
			return
		host.set_pos(host.stage_width - 1, pos.y)
		var v = host.get_vel()
		host.set_vel(fixed.mul(fixed.abs(last_x_vel), "-0.75"), v.y)

	if host.has_ceiling and pos.y <= -host.ceiling_height:
		if !try_bounce():
			return
		host.set_pos(pos.x, -host.ceiling_height + 1)
		var v = host.get_vel()
		host.set_vel(v.x, fixed.mul(fixed.abs(last_y_vel), "0.75"))

	vel = host.get_vel()

	if current_tick >= 180:
		spawn_acid_bubbles(vel)
		host.disable()
		return
	if current_tick > STRAIGHT_FRAMES and !homing:
		var opponent = host.get_opponent()
		if opponent:
			var target = host.obj_local_center(opponent)
			var dist = fixed.vec_len(str(target.x), str(target.y))
			if fixed.ge(dist, "115"):
				homing = true
	if homing:
		var opponent = host.get_opponent()
		if opponent == null:
			return
		var target = host.obj_local_center(opponent)
		var dist = fixed.vec_len(str(target.x), str(target.y))
		var vel_n = fixed.normalized_vec(vel.x, vel.y)
		var target_n = fixed.normalized_vec(str(target.x), str(target.y))
		var dot = fixed.add(fixed.mul(vel_n.x, target_n.x), fixed.mul(vel_n.y, target_n.y))
		var in_range = fixed.lt(dist, "115") and fixed.gt(dot, "0.707")
		if in_range:
			spawn_acid_bubbles(vel)
			host.disable()
			return
		if !in_range:
			host.set_vel(fixed.mul(vel.x, HOMING_DECEL), fixed.mul(vel.y, HOMING_DECEL))
			var force = fixed.normalized_vec_times(str(target.x), str(target.y), HOMING_FORCE)
			host.apply_force(force.x, force.y)
		host.apply_forces()
		var new_vel = host.get_vel()
		if fixed.gt(fixed.vec_len(new_vel.x, new_vel.y), MAX_HOMING_SPEED):
			var clamped = fixed.normalized_vec_times(new_vel.x, new_vel.y, MAX_HOMING_SPEED)
			host.set_vel(clamped.x, clamped.y)

func try_bounce():
	if bounces <= 0:
		host.disable()
		return false
	bounces -= 1
	return true

func spawn_acid_bubbles(vel):
	var vel_n = fixed.normalized_vec_times(vel.x, vel.y, "2.0")
	for i in range(NUM_BUBBLES):
		var bubble = host.spawn_object(ACID_BUBBLE_SCENE, 0, 0)
		bubble.no_juke_pips = true
		bubble.get_node("StateMachine/Default").anim_length = 60 + i
		var rand_x = str(host.randi_static() % 61 - 30)
		var rand_y = str(host.randi_static() % 61 - 30)
		var nudge_strength = fixed.powu(fixed.div(str(host.randi_static() % 101), "100"), 2)
		var nudge = fixed.normalized_vec_times(rand_x, rand_y, fixed.mul(nudge_strength, "1.15"))
		bubble.set_vel(fixed.add(vel_n.x, nudge.x), fixed.add(vel_n.y, nudge.y))
