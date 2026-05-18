extends BaseProjectile

const ACCEL_SPEED = "0.30"
const FRIC = "0.04"
const DIRECT_MOVE_SPEED = "3.0"
const PUSH_SPEED_LIMIT = "8"
const LIGHTNING_Y = 132
const LIGHTNING_PUSH_FORCE = "-5"
const ATTACK_SUPER_DRAIN = 0
const LIGHTNING_DRAIN = 0
const HIT_FORCE_MODIFIER = "2.0"
const PUSH_BACK_FORCE = "10"
const PUSH_BLOCK_LOCK_COOLDOWN = 20
const FIRE_TICKS = 20
const FIRE_MOVE_SPEED = "11"

const ORB_DART_SCENE = preload("res://characters/wizard/projectiles/OrbDart.tscn")
const LOCKED_DART_SCENE = preload("res://characters/wizard/projectiles/OrbDartLocked.tscn")
const LIGHTNING_SCENE = preload("res://characters/wizard/projectiles/orb/OrbLightning.tscn")
const FIRE_SCENE = preload("res://characters/wizard/projectiles/orb/OrbFire.tscn")
const LOCK_PARTICLE = preload("res://characters/wizard/projectiles/orb/OrbSpawnParticle.tscn")
const DISABLE_PARTICLE = preload("res://characters/wizard/projectiles/orb/OrbSpawnParticle.tscn")
const PUSH_PARTICLE = preload("res://characters/wizard/projectiles/orb/OrbSpawnParticle.tscn")
const PUSH_TICKS = 30

onready var fire_particle = $"%FireParticle"

var triggered_attacks = {}

var frozen = false
var locked = false

var lock_cooldown = 0

var push_ticks = 0

var strikes_left = 0
var strike_ticks_left = 0

var fire_ticks_left = 0
# obj_name of the active OrbFire follower (spawned by start_fire, disabled
# by tick when on_fire flips false or by Orb.disable). Tracked in
# extra_state_variables so rollback/replay carry the reference.
var fire_obj = null

var push_dir = null

var last_push_x = "0"
var last_push_y = "0"

var fire_direction_x = "0"
var fire_direction_y = "0"

func _ready():
	pass

func get_target_pos():
	var local_pos = obj_local_center(creator)
	return {
		"x": local_pos.x - creator.get_facing_int() * 30,
		"y": local_pos.y - 12
	}

func lock():
	reset_momentum()
	locked = true
	push_ticks = 0
	spawn_particle_effect_relative(LOCK_PARTICLE)
	play_sound("Lock")

func on_fire():
	return fire_ticks_left > 0

func unlock():
	locked = false
	spawn_particle_effect_relative(LOCK_PARTICLE)
	play_sound("Unlock")

func get_travel_dir():
	if creator:
		var local_pos = get_target_pos()
		return fixed.normalized_vec(str(local_pos.x), str(local_pos.y))

func on_got_push_blocked():
	unlock()
	reset_momentum()
	lock_cooldown = PUSH_BLOCK_LOCK_COOLDOWN
	var dir_sign = get_fighter().opponent.get_opponent_dir()
	apply_force(fixed.mul(str(dir_sign), PUSH_BACK_FORCE), "0")

func travel_towards_creator():
	if on_fire():
		var force = fixed.normalized_vec_times(fire_direction_x, fire_direction_y, FIRE_MOVE_SPEED)
		if (fixed.eq(last_push_x, "0") and fixed.eq(last_push_y, "0")):
			force.x = "0"
			force.y = "0"
		move_directly(force.x, force.y)
		set_vel(force.x, force.y)
		update_data()
		return
		
	var travel_dir = get_travel_dir()
	if travel_dir:
		var force = fixed.vec_mul(travel_dir.x, travel_dir.y, ACCEL_SPEED)
		if get_pos().y == 0:
			var vel = get_vel()
			set_vel(vel.x, fixed.mul(vel.y, "-1"))
			if push_dir:
				push_dir.y = "0"
		apply_x_fric(FRIC)
		apply_y_fric(FRIC)
		apply_force(force.x, force.y)
		if push_ticks > 0:
			if push_dir != null:
				apply_force(fixed.div(push_dir.x, "10"), fixed.div(push_dir.y, "10"))
			limit_speed(PUSH_SPEED_LIMIT)
			apply_forces_no_limit()
		else:
			apply_forces()
		if get_pos().y > -5:
			apply_force("0", "-" + ACCEL_SPEED)
		var direct_movement = fixed.vec_mul(travel_dir.x, travel_dir.y, DIRECT_MOVE_SPEED)
		var local_pos = get_target_pos()
		if fixed.lt(fixed.vec_len(str(local_pos.x), str(local_pos.y)), "1.5"):
			move_directly(local_pos.x, local_pos.y)
		set_facing(get_object_dir(creator.opponent))
#		print(current_tick, get_vel())

func attempt_triggered_attack():
	if triggered_attacks.has(current_tick):
		attack(triggered_attacks[current_tick])
		triggered_attacks.erase(current_tick)

func trigger_attack(attack_type, attack_delay):
	if attack_type == "Lightning":
		if strikes_left > 0 or strike_ticks_left > 0:
			return
		for attack in triggered_attacks.values():
			if attack == "Lightning":
				return
	elif attack_type == "Sword":
		if current_state().state_name == "Sword":
			return
	elif attack_type == "OrbFire":
		if on_fire():
			return
	triggered_attacks[current_tick + attack_delay] = attack_type

func start_fire():
	fire_particle.start_emitting()
	fire_ticks_left = FIRE_TICKS
	# Spawn the follower hitbox if one isn't already alive — keeps a single
	# OrbFire across overlapping/back-to-back triggers instead of stacking.
	# Orb.tick is responsible for tearing it down when on_fire goes false.
	if obj_from_name(fire_obj) == null:
		var fire = spawn_object(FIRE_SCENE, 0, 0, false, null, false)
		if fire:
			fire_obj = fire.obj_name
			fire_direction_x = last_push_x
			fire_direction_y = last_push_y

func drain_super():
	if creator:
		creator.use_super_meter(ATTACK_SUPER_DRAIN)

func attack(attack_type):
	match attack_type:
		"OrbDart":
			spawn_orb_dart()
			drain_super()
		"Sword":
			state_machine.queue_state("Sword")
			drain_super()
		"Lightning":
			strikes_left += 2
			spawn_lightning()
		"OrbFire":
			start_fire()

func tick():
	.tick()
	if strike_ticks_left > 0:
		strike_ticks_left -= 1
		if strike_ticks_left == 0:
			spawn_lightning()
	if lock_cooldown > 0:
		lock_cooldown -= 1
	if fire_ticks_left > 0:
		if fire_ticks_left >= FIRE_TICKS - 2:
			fire_direction_x = last_push_x
			fire_direction_y = last_push_y
		fire_ticks_left -= 1
		if fire_ticks_left <= 0:
			fire_particle.stop_emitting()
	
	var _on_fire = on_fire()

	# Tear down the follower OrbFire when on_fire flips false. start_fire
	# is the only place it's spawned, so this is the corresponding free.
	if !_on_fire and fire_obj != null:
		var fire = obj_from_name(fire_obj)
		if fire and !fire.disabled:
			fire.disable()
		fire_obj = null

func push(fx, fy):
	if fixed.eq(fx,"0") and fixed.eq(fy,"0"):
		return

	last_push_x = fx
	last_push_y = fy
	play_sound("Push")
#	reset_momentum()
	push_ticks = PUSH_TICKS
	push_dir = {
		"x": fx,
		"y": fy,
	}
#	apply_force(fx, fy)
	spawn_particle_effect_relative(PUSH_PARTICLE)

func disable():
	# Pair-disable the fire follower so it doesn't outlive the orb.
	if fire_obj != null:
		var fire = obj_from_name(fire_obj)
		if fire and !fire.disabled:
			fire.disable()
		fire_obj = null
	.disable()
	creator.orb_projectile = null
	spawn_particle_effect_relative(DISABLE_PARTICLE)

func spawn_lightning():
	var pos = get_pos()
	# Lightning sprite's top clips to the orb's y — it always spawns at
	# the orb's current position and extends downward, instead of
	# teleporting the orb up to LIGHTNING_Y like the old logic did.
	var lightning_y = pos.y
	if pos.y > -LIGHTNING_Y:
		# Orb is below the canonical lightning ceiling — give it a small
		# upward push per strike instead of snapping it to LIGHTNING_Y.
		# apply_force accumulates so back-to-back strikes nudge it higher
		# while gravity still pulls it back down between them.
		apply_force("0", LIGHTNING_PUSH_FORCE)
		spawn_particle_effect_relative(PUSH_PARTICLE)
	spawn_object(LIGHTNING_SCENE, pos.x, lightning_y, false, null, false)
	play_sound("Lightning")
	if strikes_left > 0:
		strikes_left -= 1
		strike_ticks_left = 15
	if creator:
		creator.use_super_meter(LIGHTNING_DRAIN)

func spawn_orb_dart():
	var local_pos = obj_local_center(creator.opponent)
	var dir = fixed.normalized_vec(str(local_pos.x), str(local_pos.y))
	spawn_object(ORB_DART_SCENE if !locked else LOCKED_DART_SCENE, 0, 0, true, {"dir": dir})
	play_sound("Shoot")

func hit_by(hitbox):
	if hitbox:
		if hitbox.throw:
			return
		locked = false
		var force = get_knockback_force(hitbox)
		force = fixed.vec_mul(force.x, force.y, HIT_FORCE_MODIFIER)
		apply_force(force.x, force.y)
