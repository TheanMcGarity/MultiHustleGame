extends BaseProjectile

const LIFETIME = 900
const ACTIVATE_TIME = 30
const EXPLOSION = preload("res://characters/robo/projectiles/NadeExplosion.tscn")
const DI_INFLUENCE = "5"
const DI_HORIZONTAL_MODIFIER = "0.85"
const DI_DEGRADATION_PER_HIT = "0.0"
const NUDGE_DISTANCE = 10
const ARM_TIME_REDUCTION_ON_HIT = 5
const ARM_TIME_ON_OPPONENT_HIT = 4
# Knockback multiplier applied on top of `hitbox.knockback` when the bomb
# is hit. Default for any attacker; CREATOR variant kicks in when the
# Robot who threw the bomb attacks it themselves so they can chase it
# across the stage with their own attacks. Opponent hits stay on the
# baseline.
const KNOCKBACK_MULTIPLIER = "1.5"
const CREATOR_KNOCKBACK_MULTIPLIER = "1.9"
# DI influence amount when the attacker steers the bomb via their DI.
# Creator gets a boosted value so their own DI has more pull on the bomb
# than an opponent's DI does.
const CREATOR_DI_INFLUENCE = "12"
# Boosted air- and fall-speed caps applied while the creator's hit is still
# propelling the bomb through the air. Stay in effect until the bomb lands
# or the opponent hits it — opponent hits revert to the scene defaults.
# Tunable independently so the boost's horizontal vs vertical feel can be
# tweaked separately.
const CREATOR_BOOSTED_AIR_SPEED = "19"
const CREATOR_BOOSTED_FALL_SPEED = "16"

# Tracked in extra_state_variables so rollback / replay restore preserves
# whether the bomb is currently riding the creator's air-speed boost.
var creator_air_speed_boosted = false

onready var my_hitbox = $StateMachine/Active/Hitbox
onready var active_indicator = $Flip/ActiveIndicator

var last_vel_x
var last_vel_y
var hits_chained = 0
var last_hit_by = -1

var active = false
var hitbox_out = false

var ticks_left = LIFETIME

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(pos=null):
	.init(pos)

func tick():
	.tick()
	if hitlag_ticks <= 0:
		ticks_left -= 1
		if ticks_left == ACTIVATE_TIME - 3:
			has_projectile_parry_window = false
		if ticks_left <= 0 and !creator.opponent.current_state().state_name == "Grabbed":
			explode()
		elif ticks_left <= ACTIVATE_TIME:
			activate()
	# Creator's air-speed boost ends the moment the bomb lands. Idempotent —
	# safe to call every tick while grounded, only re-pushes chara state on
	# the actual transition out of the boost.
	if creator_air_speed_boosted and is_grounded():
		_clear_creator_air_speed_boost()
	# Cap upward velocity to the horizontal air-speed limit. The chara backend
	# only enforces a fall-speed (downward) cap natively, so without this an
	# uppercut could shoot the bomb straight up at speeds well above the
	# horizontal cap. Mirrors max_air_speed (= boosted while creator hits).
	var up_cap = CREATOR_BOOSTED_AIR_SPEED if creator_air_speed_boosted else max_air_speed
	var neg_cap = fixed.mul(up_cap, "-1")
	var vel = get_vel()
	if fixed.lt(vel.y, neg_cap):
		set_vel(vel.x, neg_cap)

func activate():
	if active:
		return
	ticks_left = Utils.int_min(ticks_left, ACTIVATE_TIME)
	play_sound("Beep")
	active = true
	current_state().hitbox.sdi_modifier = "0.0"
	my_hitbox.increment_combo = false


func _process(delta):
	if active and !disabled:
		active_indicator.visible = Utils.pulse(0.064, 0.5)

func explode():
	disable()
	spawn_object(EXPLOSION, 0, -8)

func can_hit_cancel(fighter):
	if active:
		return hit_cancel_on_hit and fighter.id == id
	return hit_cancel_on_hit

func hit_by(hitbox):
	.hit_by(hitbox)
	if hitbox:
		if hitbox.hitbox_type == Hitbox.HitboxType.Flip:
			var vel = get_vel()
			set_vel(fixed.mul(vel.x, "-1"), vel.y)
		else:
			reset_momentum()
			# Resolve the attacker up-front so we can pick the creator-vs-
			# opponent knockback multiplier. Creator's own attacks get
			# amplified knockback (and DI further down) so Robot can pilot
			# his own bomb around — opponents still see baseline values.
			var host = hitbox.host
			var host_object = obj_from_name(host) if host != null else null
			var attacker_is_creator = is_instance_valid(host_object) and host_object.id == id
			var knockback_mul = CREATOR_KNOCKBACK_MULTIPLIER if attacker_is_creator else KNOCKBACK_MULTIPLIER
			var dir = fixed.normalized_vec_times(get_hitbox_x_dir(hitbox), hitbox.dir_y, fixed.mul(hitbox.knockback, knockback_mul))
			if is_grounded() and fixed.gt(dir.y, "0"):
				dir.y = fixed.mul(dir.y, "-1")
			change_state("Active")
			apply_force(dir.x, dir.y)
			var nudge = fixed.normalized_vec_times(get_hitbox_x_dir(hitbox), hitbox.dir_y, str(NUDGE_DISTANCE))
			move_directly(nudge.x, nudge.y)
			if host:
				my_hitbox.hit_objects.append(host)
			# Creator hit → arm the air-speed boost until landing or an
			# opponent hits the bomb. Opponent hit while boosted clears it.
			if attacker_is_creator:
				_apply_creator_air_speed_boost()
			elif creator_air_speed_boosted:
				_clear_creator_air_speed_boost()
			if host_object:
				var player_object = host_object.get_owner()
				var player = player_object.obj_name
				hit_cancel_on_hit = true
				if last_hit_by != host_object.id or player_object.combo_count > 0 or player_object.opponent.combo_count > 0:
					last_hit_by = host_object.id
					hits_chained = 0
				else:
					hits_chained += 1
#				if hits_chained > 0:
#					hit_cancel_on_hit = false

#				if player_object.combo_count > 0:
#					hit_cancel_on_hit = true
#
				# new
				hit_cancel_on_hit = player_object.combo_count > 0 and hits_chained == 0

				if host != player:
					my_hitbox.hit_objects.append(player)
				else:
					# DI pull on the bomb. Creator gets the boosted influence
					# so their own DI moves the bomb more than an opponent's.
					var di_influence = CREATOR_DI_INFLUENCE if attacker_is_creator else DI_INFLUENCE
					var di_amount = fixed.mul(fixed.sub("1.0", fixed.mul(DI_DEGRADATION_PER_HIT, str(hits_chained))), di_influence)
					if fixed.lt(di_amount, "0"):
						di_amount = "0"
#					print(di_amount)
					var di_force = xy_to_dir(host_object.current_di.x, host_object.current_di.y, di_amount)
					apply_force(fixed.mul(di_force.x, DI_HORIZONTAL_MODIFIER), di_force.y)

				if active:
					if host_object.id != id:
						ticks_left = Utils.int_min(ticks_left, ARM_TIME_ON_OPPONENT_HIT)
					else:
						ticks_left -= ARM_TIME_REDUCTION_ON_HIT
					if ticks_left < 0:
						ticks_left = 0

func refresh():
	hitbox_out = false
	change_state(current_state().state_name)
	
func on_got_blocked():
	.on_got_blocked()
	var vel = get_vel()
	if active:
		ticks_left = Utils.int_min(ticks_left, ARM_TIME_ON_OPPONENT_HIT)
	else:
		set_vel(fixed.mul(vel.x, "-0.9"), vel.y)
	if creator.magnet_ticks_left > 0:
		creator.magnetize_opponent = true
		creator.magnetize_opponent_blocked = true

func _on_hit_something(obj, hitbox):
	._on_hit_something(obj, hitbox)
	if obj.is_in_group("Fighter"):
		if creator.magnet_ticks_left > 0:
			creator.magnetize_opponent = true
			creator.magnetize_opponent_blocked = false

func disable():
	.disable()
	active_indicator.hide()
	creator.grenade_object = null
	creator.magnetize_opponent = false
	creator.magnetize_opponent_blocked = false

# Push the boosted air- and fall-speed caps to the chara backend (the
# GD-side `max_air_speed` / `max_fall_speed` fields stay at scene defaults,
# so reverting just means re-pushing them). Mirrors the pattern Wizard.tick
# uses for spark-explosion speed bumps.
func _apply_creator_air_speed_boost():
	creator_air_speed_boosted = true
	chara.set_max_air_speed(CREATOR_BOOSTED_AIR_SPEED)
	chara.set_max_fall_speed(CREATOR_BOOSTED_FALL_SPEED)

func _clear_creator_air_speed_boost():
	creator_air_speed_boosted = false
	chara.set_max_air_speed(max_air_speed)
	chara.set_max_fall_speed(max_fall_speed)
