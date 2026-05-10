extends CharacterState

class_name FrozenState

const PARTICLE = preload("res://characters/wizard/projectiles/telekinesis/IceCrash2.tscn")

# Hurt-style "do nothing" lockdown — distinct from HurtAerial / HurtGrounded:
# no DI, no knockback math, no air recovery. Just stops the player from
# acting for the hitbox's hitstun and tints them with a frozen palette.
#
# Driven by the incoming hitbox passed via `data["hitbox"]`:
#   duration       = hitbox.hitstun_ticks
#   freeze forces  = "FreezeForces" in hitbox.misc_data — when set, velocity
#                    is zeroed and gravity skipped (frozen mid-air); when
#                    not set, existing momentum keeps applying (e.g. they
#                    keep falling while frozen).
#
# Exits on either: hitstun elapsed (returns to fallback_state), or being hit
# (the hit pipeline transitions to HurtAerial/HurtGrounded which fires _exit
# here and restores the original material).

const FROZEN_INNER_COLOR = Color("94e4ff")
const FROZEN_OUTLINE_COLOR = Color("ffffff")
const DEFAULT_DURATION = 60

var duration = DEFAULT_DURATION
var freeze_forces = false
var hitbox = null
var can_act = false

# Snapshotted shader params — restoring these (rather than calling
# host.reset_color()) preserves any active custom-style palette the
# character had before being frozen. Extras are snapshotted too because
# pre-rework styles often left use_extra_color_1/2 = true; the shader
# runs the extra-color replacements AFTER the main color swap, so if we
# don't disable them while frozen they override the ice tint with the
# style's accent colors.
var saved_color = null
var saved_use_outline = false
var saved_outline_color = null
var saved_use_extra_color_1 = false
var saved_use_extra_color_2 = false
var did_snapshot = false

func _enter_tree():
	# Counts as a hurt state for the whiff-meter gate in CharState — even
	# without a hitbox of its own, the player isn't choosing to be here.
	is_hurt_state = true

func _enter():
	duration = DEFAULT_DURATION
	freeze_forces = false
	hitbox = null
	can_act = false
	if data is Dictionary and data.has("hitbox"):
		hitbox = data["hitbox"]
		if hitbox != null:
			duration = hitbox.hitstun_ticks
			freeze_forces = "FreezeForces" in hitbox.misc_data
	if freeze_forces:
		host.set_vel("0", "0")
	else:
		var vel = host.get_vel()
		vel = fixed.vec_mul(vel.x, vel.y, "0.5")
		host.set_vel(vel.x, vel.y)
	var mat = host.sprite.get_material()
	# Ghost prediction copies don't have a style applied (apply_style is
	# gated on !is_ghost in BaseChar), so there's nothing meaningful to
	# snapshot for them — on exit we just kick them back to default colors.
	# The real character snapshots so we can preserve any active style.
	if !host.is_ghost:
		saved_color = mat.get_shader_param("color")
		saved_use_outline = mat.get_shader_param("use_outline")
		saved_outline_color = mat.get_shader_param("outline_color")
		saved_use_extra_color_1 = mat.get_shader_param("use_extra_color_1")
		saved_use_extra_color_2 = mat.get_shader_param("use_extra_color_2")
		did_snapshot = true
	mat.set_shader_param("color", FROZEN_INNER_COLOR)
	mat.set_shader_param("use_outline", true)
	mat.set_shader_param("outline_color", FROZEN_OUTLINE_COLOR)
	# Disable extras while frozen — old styles in particular often replace
	# white/highlight pixels via the extras with a fixed style color, which
	# would paint right over the ice tint. Restored from the snapshot on
	# exit so the style stays intact.
	mat.set_shader_param("use_extra_color_1", false)
	mat.set_shader_param("use_extra_color_2", false)

func _frame_0():
	host.release_opponent()
	host.spawn_particle_effect(PARTICLE, host.get_center_position_float())

func _tick():
	if freeze_forces:
		# Pin velocity to zero each tick so any forces that snuck in
		# (gravity, friction-rebounds, etc.) can't drift the body.
		host.set_vel("0", "0")
	else:
		host.apply_grav()
		host.apply_fric()
		host.apply_forces()
	# Force a grounded re-check each tick — without this, a target frozen
	# mid-air who falls to the floor (when freeze_forces is off) keeps
	# `is_grounded()` reading false until the next state-machine cycle
	# runs update_grounded, which is too late for friction.
	host.update_grounded()
	# Mirror HurtGrounded's recovery handshake: on the first tick past the
	# freeze duration, signal interruptable so the player's buffered or
	# next-turn action can kick in immediately. We don't queue a state
	# change ourselves — leaving the transition to the player's input avoids
	# routing through Fall → Landing's recovery lag.
	if current_tick >= duration:
		if can_act:
			return fallback_state
		else:
			enable_interrupt()
			can_act = true

func _exit():

	host.spawn_particle_effect(PARTICLE, host.get_center_position_float())
	if host.is_ghost:
		# Ghost path: reset back to the default character palette (no style,
		# no outline). Avoids restoring a stale snapshot from when the ghost
		# was spawned mid-Frozen.
		host.reset_color()
	elif did_snapshot:
		var mat = host.sprite.get_material()
		mat.set_shader_param("color", saved_color)
		mat.set_shader_param("use_outline", saved_use_outline)
		mat.set_shader_param("outline_color", saved_outline_color)
		mat.set_shader_param("use_extra_color_1", saved_use_extra_color_1)
		mat.set_shader_param("use_extra_color_2", saved_use_extra_color_2)
		did_snapshot = false
