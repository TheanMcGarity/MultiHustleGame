extends BaseProjectile

const ACID_BUBBLE_SCENE = preload("res://characters/mutant/projectiles/GasBombBubble.tscn")
const NUM_BUBBLES = 7
const BUBBLE_SPREAD = "3"
const STRAIGHT_FRAMES = 20
const HOMING_FORCE = "0.9"
const HOMING_DECEL = "0.85"
const MAX_HOMING_SPEED = "12"

var homing = false

func tick():
	var state = current_state()
	state.apply_grav = false
	state.apply_fric = homing
	.tick()
	if disabled:
		return
	if is_grounded():
		disable()
		return
	var vel = get_vel()
	var speed = fixed.vec_len(vel.x, vel.y)
#	if fixed.lt(speed, "0.06"):
#		disable()
#		return
	if current_tick >= 180:
		spawn_acid_bubbles(vel)
		disable()
		return
	if current_tick > STRAIGHT_FRAMES and !homing:
		var opponent = get_opponent()
		if opponent:
			var target = obj_local_center(opponent)
			var dist = fixed.vec_len(str(target.x), str(target.y))
			if fixed.ge(dist, "115"):
				homing = true
	if homing:
		var opponent = get_opponent()
		if opponent == null:
			return
		var target = obj_local_center(opponent)
		var dist = fixed.vec_len(str(target.x), str(target.y))
		var vel_n = fixed.normalized_vec(vel.x, vel.y)
		var target_n = fixed.normalized_vec(str(target.x), str(target.y))
		var dot = fixed.add(fixed.mul(vel_n.x, target_n.x), fixed.mul(vel_n.y, target_n.y))
		var in_range = fixed.lt(dist, "115") and fixed.gt(dot, "0.707")
		if in_range:
			spawn_acid_bubbles(vel)
			disable()
			return
		if !in_range:
			set_vel(fixed.mul(vel.x, HOMING_DECEL), fixed.mul(vel.y, HOMING_DECEL))
			var force = fixed.normalized_vec_times(str(target.x), str(target.y), HOMING_FORCE)
			apply_force(force.x, force.y)
		apply_forces()
		var new_vel = get_vel()
		if fixed.gt(fixed.vec_len(new_vel.x, new_vel.y), MAX_HOMING_SPEED):
			var clamped = fixed.normalized_vec_times(new_vel.x, new_vel.y, MAX_HOMING_SPEED)
			set_vel(clamped.x, clamped.y)

func spawn_acid_bubbles(vel):
	var vel_n = fixed.normalized_vec_times(vel.x, vel.y, "2.0")
	for i in range(NUM_BUBBLES):
		var bubble = spawn_object(ACID_BUBBLE_SCENE, 0, 0)
		bubble.no_juke_pips = true
		bubble.get_node("StateMachine/Default").anim_length = 60 + i
		var rand_x = str(randi_static() % 61 - 30)
		var rand_y = str(randi_static() % 61 - 30)
		var nudge_strength = fixed.powu(fixed.div(str(randi_static() % 101), "100"), 2)
		var nudge = fixed.normalized_vec_times(rand_x, rand_y, nudge_strength)
		bubble.set_vel(fixed.add(vel_n.x, nudge.x), fixed.add(vel_n.y, nudge.y))
