extends DefaultFireball

const ASCENT_ANGLE_BASE = "-1.4"
const ASCENT_ANGLE_PER_INDEX = "0.0"
const DESCENT_ANGLE_BASE = "1.6"
const DESCENT_ANGLE_PER_INDEX = "-0.17"
const ASCENT_TICKS_BASE = 8
const ASCENT_TICKS_PER_INDEX = 0
const ARC_TICKS_BASE = 2
const ARC_TICKS_PER_INDEX = 0
const SPEED_BASE = "12.0"
const SPEED_PER_INDEX = "0.0"
const STEER_FACTOR = "0.35"
const DESCENT_FORCE_BASE = "0.05"
const DESCENT_FORCE_INCREASE = "0.05"

const UP_ASCENT_ANGLE_BASE = "-1.371"
const UP_ASCENT_ANGLE_PER_INDEX = "-0.2"
const UP_DESCENT_ANGLE_BASE = "1.5"
const UP_DESCENT_ANGLE_PER_INDEX = "0.0"
const UP_ASCENT_TICKS_BASE = 7
const UP_ASCENT_TICKS_PER_INDEX = 0
const UP_ARC_TICKS_BASE = 10
const UP_ARC_TICKS_PER_INDEX = 0
const UP_SPEED_BASE = "10.0"
const UP_SPEED_PER_INDEX = "0.0"
const UP_STEER_FACTOR = "0.35"
const UP_DESCENT_FORCE_BASE = "0.05"
const UP_DESCENT_FORCE_INCREASE = "0.05"

export var flying = false

var hitbox_start_offsets = {}
var ascent_target_angle = "0"
var descent_target_angle = "0"
var ascent_ticks_total = 0
var arc_ticks_total = 0
var target_speed = "0"
var phase = 0
var descent_force = "0"
var steer_factor = STEER_FACTOR
var descent_force_increase = DESCENT_FORCE_INCREASE
var descent_force_base = DESCENT_FORCE_BASE

onready var front_hitbox = get_node_or_null("FrontHitbox")
onready var back_hitbox = get_node_or_null("BackHitbox")

func _ready():
	for hb in [front_hitbox, back_hitbox]:
		if hb:
			hitbox_start_offsets[hb] = {x = hb.x, y = hb.y}


func _facing_int():
	return host.initial_facing

func _frame_0():
	var idx = host.arc_index
	var up = host.is_up_missile
	ascent_target_angle = fixed.add(UP_ASCENT_ANGLE_BASE if up else ASCENT_ANGLE_BASE, fixed.mul(UP_ASCENT_ANGLE_PER_INDEX if up else ASCENT_ANGLE_PER_INDEX, str(idx)))
	descent_target_angle = fixed.add(UP_DESCENT_ANGLE_BASE if up else DESCENT_ANGLE_BASE, fixed.mul(UP_DESCENT_ANGLE_PER_INDEX if up else DESCENT_ANGLE_PER_INDEX, str(idx)))
	ascent_ticks_total = (UP_ASCENT_TICKS_BASE if up else ASCENT_TICKS_BASE) + (UP_ASCENT_TICKS_PER_INDEX if up else ASCENT_TICKS_PER_INDEX) * idx
	arc_ticks_total = (UP_ARC_TICKS_BASE if up else ARC_TICKS_BASE) + (UP_ARC_TICKS_PER_INDEX if up else ARC_TICKS_PER_INDEX) * idx
	target_speed = fixed.add(UP_SPEED_BASE if up else SPEED_BASE, fixed.mul(UP_SPEED_PER_INDEX if up else SPEED_PER_INDEX, str(idx)))
	steer_factor = UP_STEER_FACTOR if up else STEER_FACTOR
	descent_force_base = UP_DESCENT_FORCE_BASE if up else DESCENT_FORCE_BASE
	descent_force_increase = UP_DESCENT_FORCE_INCREASE if up else DESCENT_FORCE_INCREASE
	_set_visual_angle(ascent_target_angle)
	if !flying:
		host.set_grounded(false)
#	else:
#		var dir_vec = fixed.rotate_vec("1", "0", ascent_target_angle)
#		var vx = fixed.mul(fixed.mul(dir_vec.x, target_speed), str(_facing_int()))
#		var vy = fixed.mul(dir_vec.y, target_speed)
#		host.set_vel(vx, vy)

func _tick_before():
	._tick_before()
	if flying and phase == 1:
		host.apply_grav()

func _tick():
	if current_tick < 1:
		host.sprite.hide()
	else:
		host.sprite.show()
	
	._tick()
	if flying:
		if phase == 0 and current_tick >= ascent_ticks_total:
			phase = 1
		elif phase == 1 and current_tick >= ascent_ticks_total + arc_ticks_total:
			phase = 2
			descent_force = descent_force_base
		if phase == 0:
			_steer_toward(ascent_target_angle, target_speed)
		elif phase == 1:
			_update_rotation_from_velocity()
		elif phase == 2:
			var dir_vec = fixed.rotate_vec("1", "0", descent_target_angle)
			host.apply_force_relative(fixed.mul(dir_vec.x, descent_force), fixed.mul(dir_vec.y, descent_force))
			descent_force = fixed.add(descent_force, descent_force_increase)
			_update_rotation_from_velocity()
		if current_tick % 5 == 0:
			host.play_sound("FlySound")
	if host.get_pos().y >= 0 and current_tick > 1 and flying:
		host.disable()

func _steer_toward(angle, speed):
	host.update_data()
	var dir_vec = fixed.rotate_vec("1", "0", angle)
	var target_vx = fixed.mul(fixed.mul(dir_vec.x, speed), str(_facing_int()))
	var target_vy = fixed.mul(dir_vec.y, speed)
	var vel = host.get_vel()
	var new_vx = fixed.lerp_string(vel.x, target_vx, steer_factor)
	var new_vy = fixed.lerp_string(vel.y, target_vy, steer_factor)
	host.set_vel(new_vx, new_vy)

func _set_visual_angle(angle):
	host.sprite.rotation = (Utils.ang2vec(float(angle))).angle()
	for hb in [front_hitbox, back_hitbox]:
		if !hb or !hitbox_start_offsets.has(hb):
			continue
		var start = hitbox_start_offsets[hb]
		var rotated = fixed.rotate_vec(str(start.x), str(start.y), angle)
		hb.x = fixed.round(rotated.x)
		hb.y = fixed.round(rotated.y)

func _update_rotation_from_velocity():
	host.update_data()
	var vel = host.get_vel()
	if fixed.eq(vel.x, "0") and fixed.eq(vel.y, "0"):
		return
	var local_x = fixed.mul(vel.x, str(_facing_int()))
	var angle = fixed.vec_to_angle(local_x, vel.y)
	_set_visual_angle(angle)

func _on_hit_something(obj, hitbox):
	._on_hit_something(obj, hitbox)
	if obj and obj.is_in_group("Fighter"):
		host.disable()

func on_got_blocked():
	.on_got_blocked()
	host.disable()
