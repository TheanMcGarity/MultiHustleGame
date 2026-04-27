extends Fighter

class_name Mutant

const INSTALL_TICKS = 120
const JUKE_PIPS = 6
const JUKE_PIPS_PER_USE = 2
const JUKE_TICKS = 3
const UP_JUKE_TICKS = 10
const NEUTRAL_JUKE_TICKS = 6
const SIDE_JUKE_TICKS = 4
const UP_JUKE_DOWN_FORCE = "2"
const UP_JUKE_GRAVITY = "-0.95"
const GROUNDED_UP_JUKE_GRAVITY = "-0.55"
const JUKE_SPEED = "12"
const JUKE_COMBO_MODIFIER = "1.25"
const DOWN_JUKE_SPEED = "14"
const BACK_JUKE_SPEED = "2"
const MAX_BACK_SPEED_FOR_JUKE = "6"
const JUKE_STARTUP_TICKS_NO_INITIATIVE = 2

onready var twist_attack_sprite = $"%TwistAttackSprite"
onready var rebirth_particle_effect = $"%RebirthParticleEffect"

var install_ticks = 0
var shockwave_projectile = null
var spike_projectile = null
var bc_charge = false

var juke_startup_ticks = 0
var juke_pips = 2
var juke_dir_x = "0"
var juke_dir_y = "0"
var juke_ticks = 0
var up_juke_ticks = 0
#var juke_dir_type = ""
var juked_this_turn = false
var started_up_juke_from_ground = false
var can_air_dash = false
var thorn_set = []
var gas_bomb_projectile = null

func apply_grav():
	if up_juke_ticks > 0:
		pass
	else:
		.apply_grav()

func apply_grav_custom(grav, fall_speed):
	if juke_ticks > 0:
		pass
	else:
		.apply_grav_custom(grav, fall_speed)

func start_rebirth_fx():
	rebirth_particle_effect.start()
	rebirth_particle_effect.show()

func stop_rebirth_fx():
	rebirth_particle_effect.stop_emitting()
	rebirth_particle_effect.hide()

func process_action(action):
	.process_action(action)
	if state_machine.states_map.has(action) and state_machine.states_map[action].has_hitboxes and previous_input and previous_input.action == "AirDash":
		can_air_dash = true

func process_extra(extra):
	bc_charge = false
	juke_startup_ticks = 0
	juked_this_turn = false
	.process_extra(extra)
	if extra.has("spike_enabled"):
		var obj = obj_from_name(spike_projectile)
		if obj:
			if !extra.spike_enabled:
				obj.disable()
	var juke_dir = extra.get("juke_dir")
#	juke_ticks = 0
	if juke_dir != null:
		juke_dir = fixed.normalized_vec(str(juke_dir.x), str(juke_dir.y))
	var invalid_juke_states = ["DashBackward"]
	if !(queued_action in invalid_juke_states):
		if juke_dir != null:
			juke_dir_x = juke_dir.x
			juke_dir_y = juke_dir.y
#			move_directly(juke_dir_x, juke_dir_y)
			juke_ticks = JUKE_TICKS
			create_speed_after_image_from_style()

			if fixed.gt(juke_dir_y, "0"):
#					juke_dir_type = "Down"
				pass
			if fixed.lt(juke_dir_y, "0"):
#					juke_dir_type = "Up"
				set_vel(fixed.mul(get_vel().x, "0.75"), fixed.mul(get_vel().y, "0.5"))
				up_juke_ticks = UP_JUKE_TICKS
				var next_state = get_state(queued_action)
				if !(next_state and next_state.get("uses_air_movement")):
					use_air_movement()
				apply_force("0", UP_JUKE_DOWN_FORCE)
				started_up_juke_from_ground = is_grounded()
			if fixed.eq(juke_dir_y, "0") and fixed.eq(juke_dir_x, "0"):
				juke_ticks = NEUTRAL_JUKE_TICKS
				add_juke_pips(-1)
			elif fixed.gt(juke_dir_x, "0"):
					juke_ticks = SIDE_JUKE_TICKS
					add_juke_pips(-2)
			elif fixed.lt(juke_dir_x, "0"):
					juke_ticks = SIDE_JUKE_TICKS
					add_juke_pips(-2)
			else:
				add_juke_pips(-2)
			if extra.get("back_juke") and combo_count <= 0:
				add_juke_pips(-1)
#			create_speed_after_image_from_style()
			juked_this_turn = true
			play_sound("Juke")
			play_sound("Juke2")

func is_neutral_juke():
	return juke_ticks > 0 and fixed.eq(juke_dir_x, "0") and fixed.eq(juke_dir_y, "0")

func init(pos=null):
	.init(pos)
	twist_attack_sprite.material = sprite.get_material()

func _on_hit_something(obj, hitbox):
	._on_hit_something(obj, hitbox)
#	if !juked_this_turn:
	if obj.is_in_group("Fighter"):
		start_projectile_invulnerability()
	if obj.id != id or (obj.id == id and !obj.get("no_juke_pips")):
		add_juke_pips(1)
		bc_charge = true


func on_parried():
	add_juke_pips(JUKE_PIPS_PER_USE)

func on_got_blocked():
	var state = current_state()
	var type = state.type
	var max_blocks = 0
	if state.get("juke_pip_max_blocks"):
		max_blocks = state.get("juke_pip_max_blocks")
	if state.number_of_hits_blocked <= max_blocks:
		if type == CharacterState.ActionType.Special:
			add_juke_pips(1)
	.on_got_blocked()

func on_blocked_melee_attack():
	.on_blocked_melee_attack()
	var obj = obj_from_name(spike_projectile)
	if obj:
		obj.disable()

func launched_by(hitbox):
	.launched_by(hitbox)
	var obj = obj_from_name(spike_projectile)
	if obj:
		obj.disable()
		
	if juked_this_turn and opponent.current_state().state_name == "Burst":
		add_juke_pips(JUKE_PIPS_PER_USE / 2)

func on_blocked_something():
	pass

func add_juke_pips(amount: int):
	juke_pips += amount
	juke_pips = Utils.int_clamp(juke_pips, 0, JUKE_PIPS)

func add_juke_pip():
	add_juke_pips(1)

func copy_to(f):
	.copy_to(f)
#	f.juke_dir_type = juke_dir_type
	f.juke_ticks = juke_ticks
	f.up_juke_ticks = up_juke_ticks

func tick():
	if !initiative and turn_frames == 0:
		juke_startup_ticks = JUKE_STARTUP_TICKS_NO_INITIATIVE

	if twist_attack_sprite.visible: 
		twist_attack_sprite.frame = (twist_attack_sprite.frame + 1) % twist_attack_sprite.frames.get_frame_count("default")
	if (juke_ticks > 0 or up_juke_ticks > 0) and hitlag_ticks <= 0 and blockstun_ticks <= 0 and juke_startup_ticks <= 0:
		spawn_particle_effect_relative(preload("res://characters/mutant/JukeEffect.tscn"), Vector2(0, -16))
		var juke_speed = JUKE_SPEED
		
		if fixed.gt(juke_dir_y, "0"):
			juke_speed = DOWN_JUKE_SPEED
		
		if current_state().get("IS_FAST_SWIPE") or current_state().get("IS_GRAB"):
			juke_speed = fixed.mul(juke_speed, "0.25")
		
		if combo_count > 0:
			juke_speed = fixed.mul(juke_speed, JUKE_COMBO_MODIFIER)
		else:
			juke_speed = fixed.mul(juke_speed, "0.7")
			if current_state().state_name == "DashForward":
				juke_speed = fixed.mul(juke_speed, "1.4")
			if !fixed.eq(juke_dir_x, "0"):
				var facing = get_facing_int()
				if (fixed.lt(juke_dir_x, "0") and facing == -1) or (fixed.gt(juke_dir_x, "0") and facing == 1):
					juke_speed = fixed.mul(juke_speed, "1.4")
		
		if current_state().state_name == "AirDash":
			juke_speed = fixed.mul(juke_speed, "1.8")

		if up_juke_ticks > 0:
			up_juke_ticks -= 1
			if fixed.lt(juke_dir_y, "0") and current_state().get("IS_JUMP") == null and !(current_state() is ThrowState):
#			if "Landing" in current_state().state_name:
#				juke_ticks = 0
#				set_vel(get_vel().x, "0")
#				if get_pos().y > -2:
#					set_pos(get_pos().x, 0)
#			else:
				apply_force("0", UP_JUKE_GRAVITY if !started_up_juke_from_ground else GROUNDED_UP_JUKE_GRAVITY)
		
		if juke_ticks > 0:
			juke_ticks -= 1
			if juke_ticks == JUKE_TICKS + 1 or up_juke_ticks == UP_JUKE_TICKS + 1:
				create_speed_after_image_from_style()
			if !fixed.eq(juke_dir_x, "0"):
				if juke_ticks <= JUKE_TICKS:
					move_directly(fixed.mul(juke_dir_x, juke_speed), "0")
			if fixed.gt(juke_dir_y, "0"):
				move_directly("0", fixed.mul(juke_dir_y, juke_speed))
			if juke_dir_x == "0" and juke_dir_y == "0":
				reset_momentum()
	elif juke_startup_ticks > 0:
		juke_startup_ticks -= 1

	if penalty_ticks > 0:
		juke_pips = 0

	if is_in_hurt_state(false) or "Knockdown" in current_state().state_name:
		juke_ticks = 0
		up_juke_ticks = 0

	if infinite_resources:
		juke_pips = JUKE_PIPS
	.tick()



func on_got_parried():
	if juked_this_turn:
		juke_ticks = 0
		up_juke_ticks = 0
		hitlag_ticks += 5

#func passive_sadness_gain():
#	.passive_sadness_gain()
#	var dir = fixed.sign(last_vel.x)
#	var opp_dir = get_opponent_dir()
#	if dir != 0 and dir != opp_dir and current_tick % 6 == 0:
#		add_penalty(1)

func on_got_push_blocked():
	if is_neutral_juke():
		juke_ticks = 0
