extends ParticleEffect

class_name CustomTrailParticle

var shape = preload("res://fx/particle_round_4x4.png")
var shape_name = "circle"
var flip_shape = false
var random_flip = false
# User-facing total particle count. When random_flip is on, this is split
# between `particles` (normal) and `particles_flipped` (mirrored).
var total_amount = 16
var start_color = Color.white
var end_color = Color.white
var start_alpha = 1.0
var end_alpha = 1.0
var start_scale = 1.0
var end_scale = 1.0
# Position of the "halfway" point for each interpolation curve. 0.5 is the
# linear default (no skew); lower values pack the transition into the start,
# higher values stretch it toward the end. Color and alpha share one Gradient
# in CPUParticles2D but can have independent midpoints — we sample at both
# breakpoints when they differ.
var color_midpoint = 0.5
var alpha_midpoint = 0.5
var scale_midpoint = 0.5
# Per-axis scale applied to this Node2D (the whole emitter rig — both the
# normal and flipped particles + any attached sprite). Distinct from
# start_scale / end_scale which control the per-particle scale curve.
var transform_scale_x = 1.0
var transform_scale_y = 1.0
# Extra rotation added on top of whatever tick() computes (limb rotation /
# facing-flip / zero). Stored in degrees for UI sanity; converted to radians
# at apply time since Node2D.rotation is radians.
var transform_rotation = 0.0

var default_gravity_x = 0
var facing = 1
var default_angle = 0
# When true, set_lifetime won't mirror lifetime into preprocess. Used by
# the hitspark particle path so a fresh burst actually starts from zero
# instead of pretending it's been emitting for a full lifetime already.
var no_preprocess := false
# Marker that this CustomTrailParticle is being driven by a hitspark (rather
# than a character aura). Suppresses the in-game _physics_process auto-disable
# that would otherwise kill the burst frame after start_emitting. Set by
# CustomHitEffect.gd in its _apply_config.
var auto_start_on_ready := false

onready var particles = $CPUParticles2D
# Mirror emitter — duplicated from `particles` in _ready. Holds the flipped
# texture and emits its half of the count when random_flip is on. Sits idle
# (emitting=false, hidden) otherwise.
var particles_flipped: CPUParticles2D = null

var custom_set = {
	"shape": "set_shape",
	"flip_shape": "set_flip_shape",
	"random_flip": "set_random_flip",
	"emission_shape": "set_emission_shape",
	"emission_circle_radius": "set_emission_circle_radius",
	"start_color": "set_start_color",
	"end_color": "set_end_color",
	"start_scale": "set_start_scale",
	"end_scale": "set_end_scale",
	"in_front": "set_in_front",
	"rect_size_x": "set_rect_size_x",
	"rect_size_y": "set_rect_size_y",
	"gravity_x": "set_gravity_x",
	"gravity_y": "set_gravity_y",
	"start_alpha": "set_start_alpha",
	"end_alpha": "set_end_alpha",
	"color_midpoint": "set_color_midpoint",
	"alpha_midpoint": "set_alpha_midpoint",
	"scale_midpoint": "set_scale_midpoint",
	"transform_scale_x": "set_transform_scale_x",
	"transform_scale_y": "set_transform_scale_y",
	"transform_rotation": "set_transform_rotation",
	"x_offset": "set_x_offset",
	"y_offset": "set_y_offset",
	"lifetime": "set_lifetime",
	"angle": "set_angle",
	"flip_with_character": "set_flip_with_character",
	"framerate": "set_framerate",
	"cap_framerate": "set_cap_framerate",
}

static func get_shapes():
	return {
		"circle": preload("res://fx/particle_round_4x4.png"),
		"square": preload("res://fx/particle_square_4x4.png"),
		"triangle": preload("res://fx/TriUp.png"),
		"star": preload("res://fx/star.png"),
		"heart": preload("res://fx/heart.png"),
		"arrow": preload("res://fx/arrow.png"),
		"cross": preload("res://fx/cross.png"),
		"line": preload("res://fx/line.png"),
		"diamond": preload("res://fx/diamond.png"),
		"shine": preload("res://fx/four_point_star.png"),
		"elec": preload("res://fx/elec.png"),
		"hollow circle": preload("res://fx/particle_round_hollow_4x4.png"),
		"hollow square": preload("res://fx/particle_square_hollow_4x4.png"),
		"checkerboard 1": preload("res://fx/checkerboard_1.png"),
		"checkerboard 2": preload("res://fx/checkerboard_2.png"),
	}

static func get_default():
	return {
		"in_front": false,
		"shape": "circle",
		"flip_shape": false,
		"random_flip": false,
		"emission_shape": "rectangle",
		"emission_circle_radius": 8.0,
		"amount": 16,
		"alpha": 1.0,
		"local_coords": false,
		"speed_scale": 2.0,
		"explosiveness": 0.0,
		"lifetime_randomness": 0.5,
		"gravity_x": 0.0,
		"gravity_y": 0.0,
		"rect_size_x": 4.0,
		"rect_size_y": 4.0,
		"direction": Vector2(0, -1),
		"spread": 0.0,
		"initial_velocity": 16.0,
		"initial_velocity_random": 16.0,
		"linear_accel": 0.0,
		"linear_accel_random": 0.0,
		"radial_accel": 0.0,
		"radial_accel_random": 0.0,
		"tangential_accel": 0.0,
		"tangential_accel_random": 0.0,
		"orbit_velocity": 0.0,
		"orbit_velocity_random": 0.0,
		"start_color": Color.white,
		"end_color": Color.white,
		"start_scale": 1.0,
		"end_scale": 1.0,
		"color_midpoint": 0.5,
		"alpha_midpoint": 0.5,
		"scale_midpoint": 0.5,
		"transform_scale_x": 1.0,
		"transform_scale_y": 1.0,
		"transform_rotation": 0.0,
		"x_offset": 0.0,
		"y_offset": 0.0,
		"scale_amount_random": 0.0,
		"angle": 0.0,
		"angle_random": 0.0,
		"angular_velocity": 0.0,
		"angular_velocity_random": 0.0,
		"damping": 0.0,
		"damping_random": 0.0,
		"cap_framerate": false,
		"framerate": 60,
		"disable_on_ko": true,
		"dynamic_triggers": false,
		"dynamic_one_shot": false,
		"triggers_inverted": false,
		"trigger_during_combo": false,
		"trigger_during_combo_linger": 0,
		"trigger_during_melee_attacks": false,
		"trigger_during_melee_attacks_linger": 0,
		"trigger_while_being_comboed": false,
		"trigger_while_being_comboed_linger": 0,
		"trigger_low_health": false,
		"trigger_low_health_threshold": 30,
		"trigger_low_health_linger": 0,
		"trigger_high_health": false,
		"trigger_high_health_threshold": 70,
		"trigger_high_health_linger": 0,
		"trigger_super_level": false,
		"trigger_super_level_min": 1,
		"trigger_super_level_linger": 0,
		"trigger_after_spawn_projectile": false,
		"trigger_after_spawn_projectile_duration": 30,
		"trigger_projectiles_active": false,
		"trigger_projectiles_active_linger": 0,
		"trigger_after_take_damage": false,
		"trigger_after_take_damage_duration": 30,
		"trigger_after_opponent_take_damage": false,
		"trigger_after_opponent_take_damage_duration": 30,
		"trigger_after_perfect_parry": false,
		"trigger_after_perfect_parry_duration": 30,
		"trigger_after_burst": false,
		"trigger_after_burst_duration": 30,
		"trigger_action_type": false,
		"trigger_action_type_value": "Attack",
		"trigger_action_type_linger": 0,
		"trigger_during_install": false,
		"trigger_during_install_linger": 0,
		"trigger_during_taunt": false,
		"trigger_during_taunt_linger": 0,
		"trigger_during_parry_combo": false,
		"trigger_during_parry_combo_linger": 0,
	}

static func get_setting_min(setting):
	var minimums = {
		"amount": 1,
		"lifetime": 0.064,
		"speed_scale": 0.0,
		"explosiveness": 0.0,
		"lifetime_randomness": 0.0,
		"gravity_x": -100.0,
		"gravity_y": -100.0,
		"rect_size_x": 0.0,
		"rect_size_y": 0.0,
		"emission_circle_radius": 0.0,
		"spread": 0.0,
		"initial_velocity": -100.0,
		"initial_velocity_random": 0.0,
		"linear_accel": -100.0,
		"linear_accel_random": 0.0,
		"radial_accel": -100.0,
		"radial_accel_random": 0.0,
		"tangential_accel": -100.0,
		"tangential_accel_random": 0.0,
		"orbit_velocity": -100.0,
		"orbit_velocity_random": 0.0,
		"start_scale": 0.0,
		"end_scale": 0.0,
		"scale_amount_random": 0.0,
		"x_offset": -32.0,
		"y_offset": -32.0,
		"angle": -360.0,
		"angle_random": 0.0,
		"angular_velocity": -1500.0,
		"angular_velocity_random": 0.0,
		"damping": 0.0,
		"damping_random": 0.0,
		"framerate": 1,
		"trigger_during_combo_linger": 0,
		"trigger_during_melee_attacks_linger": 0,
		"trigger_while_being_comboed_linger": 0,
		"trigger_low_health_threshold": 1,
		"trigger_low_health_linger": 0,
		"trigger_high_health_threshold": 1,
		"trigger_high_health_linger": 0,
		"trigger_super_level_min": 1,
		"trigger_super_level_linger": 0,
		"trigger_action_type_linger": 0,
		"trigger_during_install_linger": 0,
		"trigger_after_spawn_projectile_duration": 1,
		"trigger_projectiles_active_linger": 0,
		"trigger_after_take_damage_duration": 1,
		"trigger_after_opponent_take_damage_duration": 1,
		"trigger_after_perfect_parry_duration": 1,
		"trigger_after_burst_duration": 1,
	}
	# cap_framerate and the dynamic_triggers booleans aren't in the numeric clamp set
	return minimums[setting] if minimums.has(setting) else null

static func get_setting_max(setting):
	var maximums = {
		"amount": 32,
		"lifetime": 2.0,
		"speed_scale": 30.0,
		"explosiveness": 1.0,
		"lifetime_randomness": 1.0,
		"gravity_x": 100.0,
		"gravity_y": 100.0,
		"rect_size_x": 32.0,
		"rect_size_y": 32.0,
		"emission_circle_radius": 32.0,
		"spread": 180.0,
		"initial_velocity": 100.0,
		"initial_velocity_random": 1.0,
		"linear_accel": 100.0,
		"linear_accel_random": 1.0,
		"radial_accel": 100.0,
		"radial_accel_random": 1.0,
		"tangential_accel": 100.0,
		"tangential_accel_random": 1.0,
		"orbit_velocity": 100.0,
		"orbit_velocity_random": 1.0,
		"start_scale": 5.0,
		"end_scale": 5.0,
		"x_offset": 32.0,
		"y_offset": 32.0,
		"scale_amount_random": 1.0,
		"angle": 360.0,
		"angle_random": 1.0,
		"angular_velocity": 1500.0,
		"angular_velocity_random": 1.0,
		"damping": 200.0,
		"damping_random": 1.0,
		"framerate": 60,
		"trigger_during_combo_linger": 120,
		"trigger_during_melee_attacks_linger": 120,
		"trigger_while_being_comboed_linger": 120,
		"trigger_low_health_threshold": 100,
		"trigger_low_health_linger": 120,
		"trigger_high_health_threshold": 100,
		"trigger_high_health_linger": 120,
		"trigger_super_level_min": 9,
		"trigger_super_level_linger": 120,
		"trigger_action_type_linger": 120,
		"trigger_during_install_linger": 120,
		"trigger_after_spawn_projectile_duration": 120,
		"trigger_projectiles_active_linger": 120,
		"trigger_after_take_damage_duration": 120,
		"trigger_after_opponent_take_damage_duration": 120,
		"trigger_after_perfect_parry_duration": 120,
		"trigger_after_burst_duration": 120,
	}
	return maximums[setting] if maximums.has(setting) else null

func restart():
	$CPUParticles2D.restart()
	if particles_flipped:
		particles_flipped.restart()
	set_enabled(false)
	# Re-roll the random tilt every restart so successive emissions on a
	# total_amount=1 setup actually alternate between normal and flipped.
	_apply_amount()

func start_emitting():
	# Parent's start_emitting blanket-sets emitting=true on every CPUParticles2D
	# child. We need to then re-apply the random tilt so a 0-count emitter
	# doesn't sneak in a stray particle.
	.start_emitting()
	_apply_amount()

func _ready():
	set_enabled(false)
	# particles_flipped is created lazily by set_random_flip(true). When
	# random_flip is off (the default), we don't allocate the second emitter.

# Spawn a mirror CPUParticles2D as a sibling of the main one, duplicating
# its current state (which includes both .tscn-set config and any live
# edits that have already been applied). Idempotent — no-op if it already
# exists.
func _ensure_flip_emitter():
	if particles == null or particles_flipped != null:
		return
	particles_flipped = particles.duplicate()
	particles_flipped.name = "CPUParticles2DFlipped"
	particles.get_parent().add_child(particles_flipped)
	particles_flipped.amount = 1
	particles_flipped.emitting = false
	particles_flipped.hide()

func _destroy_flip_emitter():
	if particles_flipped == null:
		return
	particles_flipped.queue_free()
	particles_flipped = null

# Sanity retrigger cooldown — refuse a fresh burst if the last one happened
# within this many frames. Stops a single-frame jitter (e.g. trigger flickering
# false→true→false) from spamming bursts.
const BURST_COOLDOWN_FRAMES = 5
# Cap on simultaneous burst clones per source CustomTrailParticle. When at
# cap, the oldest clone is freed before spawning the new one — favors showing
# the latest action over preserving stale bursts.
const MAX_BURST_CLONES = 20
# Active burst clones spawned by this source, in spawn order. Stale entries
# (queue_freed externally) are filtered each emit_burst.
var active_burst_clones: Array = []
# Frame counter incremented in tick(); reset to 0 each emit_burst() and
# initialized so the first burst is unblocked.
var frames_since_last_burst = BURST_COOLDOWN_FRAMES
# How many game-ticks the current burst (on a clone) should keep emitting for.
# Decremented in tick(); when it hits 0 we flip emitting off ourselves. We
# don't use CPUParticles2D's `one_shot=true` because in this game's "many game
# ticks per render frame" pattern, a long resume delta overshoots the cycle
# and Godot stops emission ~5 frames in regardless of `lifetime`.
var burst_emit_ticks_remaining = 0
# When > 0, this CustomTrailParticle is an ephemeral burst clone; once
# emit_ticks_remaining hits 0 AND another lifetime has passed (so particles
# have died), the clone queue_frees itself.
var burst_clone_free_in_ticks = 0

# Spawn an ephemeral clone that emits its own burst and frees itself. Multiple
# rapid events stack as overlapping clones; the source emitter is left alone
# so its in-flight particles aren't reset. The clone re-uses CustomTrailParticle's
# tick() (for limb-following / facing) and its own `burst_emit_ticks_remaining`
# countdown (since Godot's one_shot is unreliable in our process_internal-
# toggling setup).
func emit_burst():
	if particles == null:
		return
	if frames_since_last_burst < BURST_COOLDOWN_FRAMES:
		return
	frames_since_last_burst = 0
	# Drop stale refs and enforce the cap. If we're at MAX_BURST_CLONES, free
	# the oldest live clone before spawning the new one.
	var live_clones := []
	for c in active_burst_clones:
		if is_instance_valid(c):
			live_clones.append(c)
	active_burst_clones = live_clones
	if active_burst_clones.size() >= MAX_BURST_CLONES:
		var oldest = active_burst_clones.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var clone = duplicate()
	# duplicate() doesn't copy non-export script-vars, so explicitly carry
	# over the runtime state we care about (random_flip, flip_shape,
	# attach state, offsets, _last_*_active gates).
	clone.random_flip = random_flip
	clone.flip_shape = flip_shape
	clone._last_primary_active = _last_primary_active
	clone._last_mirror_active = _last_mirror_active
	clone.particles_flipped = null
	if clone.has_node("CPUParticles2DFlipped"):
		clone.particles_flipped = clone.get_node("CPUParticles2DFlipped")
	clone.attached_to_limb = attached_to_limb
	clone.attached_rotation = attached_rotation
	clone.attached_limb_flipped = attached_limb_flipped
	clone.flip_with_character = flip_with_character
	clone.facing = facing
	clone.default_x_offset = default_x_offset
	clone.default_y_offset = default_y_offset
	clone.default_gravity_x = default_gravity_x
	clone.default_angle = default_angle
	clone.total_amount = total_amount
	get_parent().add_child(clone)
	# Position the clone where the source is right now — auras attach to a
	# moving character so each burst should freeze at the moment-of-trigger
	# global position (default `local_coords=false` keeps the spawned particles
	# in world space afterward).
	clone.global_position = global_position
	clone.rotation = rotation
	clone.scale = scale
	# Clone-specific: mark as burst clone, kick off emission, schedule free.
	clone.frames_since_last_burst = 0
	clone._start_burst_clone(int(total_amount))
	active_burst_clones.append(clone)

# Called on a freshly-instanced clone to begin its single emission cycle.
# Picks the same odd-tilt split for random_flip totals so total=1 plays only
# one side. Caller has already set our `particles` / `particles_flipped`
# references.
func _start_burst_clone(amount_total: int):
	# Live for ~2 cycles in real-time (one cycle to emit, one for the last
	# particles to die), accounting for speed_scale which compresses cycle
	# duration in real time.
	var speed = particles.speed_scale if particles.speed_scale > 0 else 1.0
	burst_clone_free_in_ticks = max(int(particles.lifetime * 60.0 / speed), 1) * 2
	if particles_flipped == null:
		_clone_burst_one(particles, max(amount_total, 1))
		return
	var amt = max(amount_total, 1)
	var half = amt / 2
	var extra = amt - 2 * half
	var primary_count = half
	var mirror_count = half
	if extra > 0:
		if randi() % 2 == 0:
			primary_count += extra
		else:
			mirror_count += extra
	if primary_count > 0:
		_clone_burst_one(particles, primary_count)
	else:
		particles.emitting = false
	if mirror_count > 0:
		_clone_burst_one(particles_flipped, mirror_count)
	else:
		particles_flipped.emitting = false

func _clone_burst_one(emitter: CPUParticles2D, burst_amount: int):
	# Burst clones leave process_internal on (see _physics_process) so Godot's
	# `one_shot=true` auto-stop is reliable: emitter stops emitting after
	# exactly one cycle (= one `lifetime`).
	emitter.one_shot = true
	emitter.amount = max(burst_amount, 1)
	# `preprocess` is set to lifetime by set_lifetime() so a continuously-
	# emitting source looks "already running" on screen-load. For a one-shot
	# burst we want particles to spawn fresh from T=0, not pre-aged. Zero it
	# only on the clone — source preprocess stays unchanged.
	emitter.preprocess = 0.0
	emitter.restart()
	# Manual countdown is kept as a hard backstop in case Godot's auto-stop
	# misbehaves for any reason — sized generously here (two real-time
	# cycles) since we're not relying on it.
	var speed = emitter.speed_scale if emitter.speed_scale > 0 else 1.0
	burst_emit_ticks_remaining = max(int(emitter.lifetime * 60.0 / speed) * 2, 1)

func get_data():
	pass

func set_shape(shape_name):
	var shapes = get_shapes()
	if shape_name in shapes:
		self.shape_name = shape_name
		_apply_shape_texture()

func set_flip_shape(on):
	flip_shape = on
	_apply_shape_texture()

func set_random_flip(on):
	random_flip = on
	if on:
		_ensure_flip_emitter()
	else:
		_destroy_flip_emitter()
	_apply_shape_texture()
	_apply_amount()

# Resolve the current shape -> texture, honoring flip_shape and random_flip.
# Most shapes are symmetric so flipping is a visual no-op, but a few (arrow,
# triangle, heart, cross, line) actually mirror differently. When random_flip
# is on, the main emitter always uses the normal texture and the mirror
# emitter uses the flipped one — flip_shape becomes a no-op.
func _apply_shape_texture():
	var shapes = get_shapes()
	var tex = shapes.get(shape_name)
	if tex == null:
		return
	var flipped_tex = _flip_texture(tex)
	if random_flip:
		particles.texture = tex
		if particles_flipped:
			particles_flipped.texture = flipped_tex
	else:
		particles.texture = flipped_tex if flip_shape else tex
		if particles_flipped:
			particles_flipped.texture = flipped_tex if flip_shape else tex

func _flip_texture(tex):
	var img = tex.get_data()
	if img == null:
		return tex
	img.flip_x()
	var flipped = ImageTexture.new()
	flipped.create_from_image(img, tex.flags)
	return flipped

# Split `total_amount` between the two emitters (or hand it all to the main
# emitter). For odd totals we randomly tilt the extra particle to one or the
# other — so total=1 plays the normal OR flipped texture (not both), and
# total=3 plays 2+1 or 1+2 randomly. CPUParticles2D rejects amount=0, so
# zero-count emitters need `amount=1` set anyway, with `emitting=false` for
# the silent half. The main emitter's `emitting` is owned by
# BaseChar._apply_aura_state — we don't touch it here.
var _last_primary_active = true
var _last_mirror_active = true
func _apply_amount():
	var amt = max(int(total_amount), 1)
	if random_flip and particles_flipped:
		var half = amt / 2
		var extra = amt - 2 * half
		var primary_count = half
		var mirror_count = half
		if extra > 0:
			if randi() % 2 == 0:
				primary_count += extra
			else:
				mirror_count += extra
		particles.amount = max(primary_count, 1)
		particles_flipped.amount = max(mirror_count, 1)
		# Track which side has zero count so _sync_flipped_emit() can mute it
		# while letting BaseChar own particles.emitting on the primary.
		_last_primary_active = primary_count > 0
		_last_mirror_active = mirror_count > 0
		if not _last_primary_active:
			particles.emitting = false
		if not _last_mirror_active:
			particles_flipped.emitting = false
		particles_flipped.show()
	else:
		particles.amount = amt
		_last_primary_active = true
		_last_mirror_active = false
		if particles_flipped:
			particles_flipped.hide()
			particles_flipped.emitting = false

func set_in_front(on):
	if on:
		show_behind_parent = false
#		particles.z_index = 1
	else:
		show_behind_parent = true
#		particles.z_index = -1

func set_start_color(color):
	start_color = color
	update_color()
	
func set_end_color(color):
	end_color = color
	update_color()

func _physics_process(_delta):
	if !is_instance_valid(Global.current_game):
		if !enabled:
			start_emitting()
			set_enabled(true)
		tick()
	elif Global.current_game:
		# Burst clones run process_internal continuously so Godot's particle
		# time advances steadily — toggling process_internal off-and-on feeds
		# inconsistent deltas into _particles_process and Godot's one_shot
		# auto-stop fires after the wrong amount of "particle time".
		# Hitspark particles (auto_start_on_ready=true) likewise need to keep
		# processing for their lifetime — they aren't gated by triggers, so
		# the usual "freeze self" path would kill emission immediately.
		if enabled and burst_clone_free_in_ticks <= 0 and !auto_start_on_ready:
			set_enabled(false)

var flip_with_character = true

# Set by BaseChar / CustomizationScreen / CharacterDisplay when this aura is
# attached to a specific limb. Rotation comes directly from the limb dir
# (assuming natural forward = (1, 0)); scale.x handles the user's "flipped"
# toggle from the Limb Finder. When facing left, the x_offset is mirrored
# across the y axis so an offset aura stays on the same side of the body.
var attached_to_limb = false
var attached_rotation = 0.0
var attached_limb_flipped = false
var default_x_offset = 0.0
var default_y_offset = 0.0

func tick():
	.tick()
	# tick() rewrites scale.x every frame to apply facing/flip — fold the
	# user's transform_scale_x in here so it doesn't get stomped (and apply
	# transform_scale_y too while we have the node in hand).
	var extra_rotation = deg2rad(transform_rotation)
	if attached_to_limb:
		rotation = attached_rotation + extra_rotation
		# scale.x mirrors first (before rotation in T*R*S), so facing left
		# flips the aura horizontally without introducing a 180° rotation.
		var flipped = attached_limb_flipped
		if facing == -1:
			flipped = !flipped
		scale.x = (-1 if flipped else 1) * transform_scale_x
		scale.y = transform_scale_y
		particles.gravity.x = default_gravity_x
		particles.angle = default_angle
		# Apply the offset in aura-local space — parent rotation/scale will
		# rotate and mirror it naturally, so e.g. a sword aura with x_offset
		# extends along the limb dir.
		particles.position.x = -default_x_offset if facing == -1 else default_x_offset
		particles.position.y = default_y_offset
	elif flip_with_character:
		rotation = extra_rotation
		scale.x = transform_scale_x
		scale.y = transform_scale_y
		particles.gravity.x = default_gravity_x * facing
		particles.angle = 360 - default_angle if facing == -1 else default_angle
		particles.position.x = default_x_offset
	else:
		rotation = extra_rotation
		particles.gravity.x = default_gravity_x
		particles.angle = default_angle
		scale.x = facing * transform_scale_x
		scale.y = transform_scale_y
		particles.position.x = default_x_offset
	_sync_flipped_transient()
	if frames_since_last_burst < BURST_COOLDOWN_FRAMES:
		frames_since_last_burst += 1
	# Manual one-shot timeout for burst clones: count down from the burst
	# start and flip emitting=false ourselves when the cycle is up.
	# CPUParticles2D's own one_shot logic doesn't track us reliably
	# (process_internal is toggled every render frame by the parent
	# ParticleEffect, and a long resume delta can prematurely end the cycle).
	if burst_emit_ticks_remaining > 0:
		burst_emit_ticks_remaining -= 1
		if burst_emit_ticks_remaining == 0:
			if particles:
				particles.emitting = false
			if particles_flipped:
				particles_flipped.emitting = false
	# Clone teardown — once we've emitted for one lifetime AND another
	# lifetime has passed (so existing particles have had time to die),
	# free ourselves.
	if burst_clone_free_in_ticks > 0:
		burst_clone_free_in_ticks -= 1
		if burst_clone_free_in_ticks == 0:
			queue_free()

# Mirror tick()'s per-frame state from the main emitter to the flipped one
# so they stay co-located and orient identically. Also mirrors the primary's
# emit state (gated by _last_mirror_active so a 0-count flipped side stays
# silent) — BaseChar only writes to particles.emitting; the flipped sibling
# follows.
func _sync_flipped_transient():
	if particles_flipped == null:
		return
	particles_flipped.gravity = particles.gravity
	particles_flipped.angle = particles.angle
	particles_flipped.position = particles.position
	var desired = particles.emitting and _last_mirror_active
	if particles_flipped.emitting != desired:
		particles_flipped.emitting = desired

func set_start_alpha(a):
#	particles.self_modulate.a = a
	start_color.a = a
	update_color()

func set_end_alpha(a):
	end_color.a = a
	update_color()

func update_color():
	# Build a Gradient that interpolates color + alpha from start to end with
	# possibly-separate midpoint skews. Adjacent gradient points interpolate
	# linearly, so when alpha_midpoint != color_midpoint we sample at both
	# breakpoints — that's enough to exactly reconstruct the piecewise-linear
	# skewed curve (which has corners only at 0, alpha_m, color_m, and 1).
	var gradient = Gradient.new()
	var alpha_m = clamp(alpha_midpoint, 0.001, 0.999)
	var color_m = clamp(color_midpoint, 0.001, 0.999)
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, _skewed_color_alpha(0.0, color_m, alpha_m))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, _skewed_color_alpha(1.0, color_m, alpha_m))
	if abs(color_m - 0.5) > 0.0001 or abs(alpha_m - 0.5) > 0.0001:
		# Insert a breakpoint at each midpoint. When they're equal, only one
		# point gets added (the second add_point on the same offset would be
		# redundant but harmless).
		var inner_positions = [color_m] if abs(color_m - alpha_m) < 0.0001 else _sorted_distinct([color_m, alpha_m])
		for t in inner_positions:
			gradient.add_point(t, _skewed_color_alpha(t, color_m, alpha_m))
	particles.color_ramp = gradient
	if particles_flipped:
		particles_flipped.color_ramp = gradient

func _skewed_color_alpha(t: float, color_m: float, alpha_m: float) -> Color:
	var c = start_color.linear_interpolate(end_color, _skew(t, color_m))
	c.a = lerp(start_color.a, end_color.a, _skew(t, alpha_m))
	return c

# Piecewise-linear skew: maps t in [0,1] to a position in [0,1] such that t=m
# lands at 0.5. Drives both color/alpha gradients and the scale curve so the
# user-facing midpoint slider has the same meaning across all three.
func _skew(t: float, m: float) -> float:
	if t <= m:
		return (t / m) * 0.5
	return 0.5 + ((t - m) / (1.0 - m)) * 0.5

func _sorted_distinct(arr: Array) -> Array:
	arr.sort()
	var out := []
	for v in arr:
		if out.size() == 0 or abs(out[-1] - v) > 0.0001:
			out.append(v)
	return out

func set_color_midpoint(m):
	color_midpoint = m
	update_color()

func set_alpha_midpoint(m):
	alpha_midpoint = m
	update_color()

func set_scale_midpoint(m):
	scale_midpoint = m
	update_scale()

func set_transform_scale_x(s):
	transform_scale_x = s
	scale = Vector2(transform_scale_x, transform_scale_y)

func set_transform_scale_y(s):
	transform_scale_y = s
	scale = Vector2(transform_scale_x, transform_scale_y)

func set_transform_rotation(r):
	transform_rotation = r
	# tick() reapplies rotation every frame; this immediate assignment only
	# matters for stationary previews / customization screens where tick()
	# might not be running.
	rotation = deg2rad(r)

func set_start_scale(sc):
	start_scale = sc
	update_scale()

func set_end_scale(sc):
	end_scale = sc
	update_scale()

func update_scale():
	var curve = Curve.new()
	var max_ = max(start_scale, end_scale)
	var start = start_scale
	var end = end_scale
	if max_ > 0:
		start = start_scale / max_
		end = end_scale / max_
	particles.scale_amount = max_
	curve.add_point(Vector2(0, start))
	var sm = clamp(scale_midpoint, 0.001, 0.999)
	if abs(sm - 0.5) > 0.0001:
		# Non-default midpoint — insert a knee at (m, midpoint_value) so the
		# curve bends. Default (0.5) stays as a 2-point curve, matching
		# pre-midpoint behavior exactly.
		curve.add_point(Vector2(sm, (start + end) * 0.5))
	curve.add_point(Vector2(1, end))
	# Force linear tangents on every point so segments are straight lines —
	# Godot's Curve defaults to cubic Hermite, which would bow the segments
	# and visually contradict the piecewise-linear meaning of the midpoint.
	for i in range(curve.get_point_count()):
		curve.set_point_left_mode(i, Curve.TANGENT_LINEAR)
		curve.set_point_right_mode(i, Curve.TANGENT_LINEAR)
	particles.scale_amount_curve = curve
	if particles_flipped:
		particles_flipped.scale_amount = max_
		particles_flipped.scale_amount_curve = curve

const EMISSION_SHAPE_NAMES = {
	"rectangle": 2, # CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	"circle": 1,    # CPUParticles2D.EMISSION_SHAPE_SPHERE
}

func set_emission_shape(shape_name):
	if not (shape_name in EMISSION_SHAPE_NAMES):
		return
	var enum_val = EMISSION_SHAPE_NAMES[shape_name]
	particles.emission_shape = enum_val
	if particles_flipped:
		particles_flipped.emission_shape = enum_val

func set_emission_circle_radius(r):
	particles.emission_sphere_radius = r
	if particles_flipped:
		particles_flipped.emission_sphere_radius = r

func set_rect_size_x(x):
#	print("rect_x: " + str(x))
	var ext = Vector2(x, particles.get_emission_rect_extents().y)
	particles.set_emission_rect_extents(ext)
	if particles_flipped:
		particles_flipped.set_emission_rect_extents(ext)

func set_rect_size_y(y):
	var ext = Vector2(particles.get_emission_rect_extents().x, y)
	particles.set_emission_rect_extents(ext)
	if particles_flipped:
		particles_flipped.set_emission_rect_extents(ext)

func set_gravity_x(x):
	default_gravity_x = x
	particles.gravity.x = x
	if particles_flipped:
		particles_flipped.gravity.x = x

func set_gravity_y(y):
	particles.gravity.y = y
	if particles_flipped:
		particles_flipped.gravity.y = y

func set_x_offset(x):
	default_x_offset = x
	particles.position.x = x
	if particles_flipped:
		particles_flipped.position.x = x

func set_y_offset(y):
	default_y_offset = y
	particles.position.y = y
	if particles_flipped:
		particles_flipped.position.y = y

func set_lifetime(lifetime):
	particles.lifetime = lifetime
	particles.preprocess = 0.0 if no_preprocess else lifetime
	if particles_flipped:
		particles_flipped.lifetime = lifetime
		particles_flipped.preprocess = 0.0 if no_preprocess else lifetime

func set_angle(angle):
	default_angle = angle
	particles.angle = angle
	if particles_flipped:
		particles_flipped.angle = angle

func set_flip_with_character(on):
	flip_with_character = on

var cap_framerate_enabled = false
var framerate_value = 60

func set_cap_framerate(on):
	cap_framerate_enabled = on
	_apply_framerate()

func set_framerate(value):
	framerate_value = int(value)
	_apply_framerate()

func _apply_framerate():
	var fps = framerate_value if cap_framerate_enabled else 0
	particles.fixed_fps = fps
	if particles_flipped:
		particles_flipped.fixed_fps = fps

const TRIGGER_META_PARAMS = [
	"disable_on_ko",
	"dynamic_triggers",
	"dynamic_one_shot",
	"triggers_inverted",
	"trigger_during_combo", "trigger_during_combo_linger",
	"trigger_during_melee_attacks", "trigger_during_melee_attacks_linger",
	"trigger_while_being_comboed", "trigger_while_being_comboed_linger",
	"trigger_low_health", "trigger_low_health_threshold", "trigger_low_health_linger",
	"trigger_high_health", "trigger_high_health_threshold", "trigger_high_health_linger",
	"trigger_super_level", "trigger_super_level_min", "trigger_super_level_linger",
	"trigger_after_spawn_projectile", "trigger_after_spawn_projectile_duration",
	"trigger_projectiles_active", "trigger_projectiles_active_linger",
	"trigger_after_take_damage", "trigger_after_take_damage_duration",
	"trigger_after_opponent_take_damage", "trigger_after_opponent_take_damage_duration",
	"trigger_after_perfect_parry", "trigger_after_perfect_parry_duration",
	"trigger_after_burst", "trigger_after_burst_duration",
	"trigger_action_type", "trigger_action_type_value", "trigger_action_type_linger",
	"trigger_during_install", "trigger_during_install_linger",
]

# Per-aura tick trackers for threshold-based continuous triggers — stored on
# the particle (rather than the host) because the threshold is per-aura.
var style_aura_low_health_tick = -100000
var style_aura_high_health_tick = -100000
var style_aura_super_level_tick = -100000
var style_aura_action_type_tick = -100000
# Rising-edge ticks (per aura) for one-shot mode.
var style_aura_low_health_started_tick = -100000
var style_aura_high_health_started_tick = -100000
var style_aura_super_level_started_tick = -100000
var was_low_health_active = false
var was_high_health_active = false
var was_super_level_active = false
# Same idea as BaseChar._aura_rising_edge_initialized: skip the first per-aura
# threshold check so a full-HP round start doesn't spuriously fire the
# high-health rising edge on tick 0.
var _threshold_rising_edge_initialized = false
# Per-trigger "last consumed" started_tick. Stops a continuous trigger
# (projectiles_active, low_health, etc.) from firing more than one burst per
# rising edge — see BaseChar._aura_trigger_event_fired.
var _consumed_event_ticks = {}

func set_parameter(param, value):
	var max_value = get_setting_max(param)
	var min_value = get_setting_min(param)
	if max_value and value > max_value:
		value = max_value
	if min_value and value < min_value:
		value = min_value
	# Trigger meta-settings live on the entry dict and are evaluated per-tick by
	# the host character, not pushed to the particles node.
	if param in TRIGGER_META_PARAMS:
		return
	# `amount` is split between the two emitters when random_flip is on, so
	# track the user-facing total and route through _apply_amount.
	if param == "amount":
		total_amount = value
		_apply_amount()
		return
	if !(param in custom_set):
		particles.set(param, value)
		if particles_flipped:
			particles_flipped.set(param, value)
	else:
		call(custom_set[param], value)

func load_defaults():
	load_settings(get_default())

func load_settings(settings):
	if settings:
		for setting in settings:
			set_parameter(setting, settings[setting])
