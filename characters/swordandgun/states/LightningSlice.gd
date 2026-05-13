extends CharacterState

const TRACKING_DISTANCE = "86.0"
const DEADZONE_RADIUS = "70.0"

const DEFAULT_HITBOX_X = 128
const DEFAULT_HITBOX_Y = -16

export var cancel = false
export var followup = false
export var neutral = false

var stall = false

onready var hitbox = $Hitbox

func is_usable():
	return .is_usable() and (neutral and host.combo_count == 0) or (!neutral and host.combo_count > 0)

func _frame_0():
	stall = false
	# Gate the hitbox's ground-bounce on a per-combo flag held by the
	# attacker — first LightningSlice in a combo gets the bounce, subsequent
	# hits don't. Re-armed by SwordGuy.reset_combo when the combo ends.
	# Property set on the hitbox NODE so HitboxData snapshots it at hit time.
	hitbox.air_ground_bounce = !host.lightning_slice_ground_bounced

func _on_hit_something(obj, hitbox):
	._on_hit_something(obj, hitbox)
	if obj.is_in_group("Fighter"):
		host.lightning_slice_ground_bounced = true

func _frame_1():
	var vel = host.get_vel()
	if !host.used_aerial_l_slice:
		host.set_vel(vel.x, "0")
		host.used_aerial_l_slice = true
		stall = true
	else:
		stall = false

func _frame_8():
	spawn_particle_relative(particle_scene)

func _tick():
#	var tracking_pos = {
#		"x": DEFAULT_HITBOX_X,
#		"y": DEFAULT_HITBOX_Y,
#	}
	hitbox.x = DEFAULT_HITBOX_X
	hitbox.y = DEFAULT_HITBOX_Y
	if followup:
		 hitbox.x = host.lightning_slice_x
		 hitbox.y = host.lightning_slice_y
	else:
		var hitbox_pos
		if neutral:
			hitbox_pos = xy_to_dir(50 * host.get_facing_int(), 0, TRACKING_DISTANCE)
		else:
			hitbox_pos = xy_to_dir(data.x, data.y, TRACKING_DISTANCE)
			
		hitbox.x = DEFAULT_HITBOX_X + (fixed.round(hitbox_pos.x) * host.get_facing_int())
		hitbox.y = DEFAULT_HITBOX_Y + fixed.round(hitbox_pos.y)
		host.lightning_slice_x = hitbox.x
		host.lightning_slice_y = hitbox.y

func _tick_after():
	._tick_after()
	if cancel and current_tick == 1:
		current_tick = 3
	if current_tick > 16 or !stall:
		host.apply_grav()
