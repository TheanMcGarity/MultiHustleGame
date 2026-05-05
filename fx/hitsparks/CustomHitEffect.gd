extends ParticleEffect

# Config dict applied in _ready. Schema matches what the customization screen
# stores: {sprite: <name or "">, show_particles: bool, particles: <dict>}.
# Set by the spawner BEFORE add_child so _ready sees it.
var custom_config = null

func _ready():
	# ParticleEffect's _ready is what initializes the AnimatedSprite tick
	# state and the lifetime timer — call it explicitly since GDScript doesn't
	# auto-chain when you override _ready.
	._ready()
	if custom_config is Dictionary:
		_apply_config(custom_config)

func _apply_config(config):
	var sprite_name = str(config.get("sprite", ""))
	var animated = get_node_or_null("AnimatedSprite")
	if animated:
		if sprite_name == "":
			# (none) — empty SpriteFrames so ParticleEffect.tick's
			# get_frame_count() doesn't NPE, hidden so nothing flashes.
			var empty := SpriteFrames.new()
			animated.frames = empty
			animated.visible = false
		else:
			var frames = load("res://fx/hitsparks/frames/%s_frames.tres" % sprite_name)
			if frames:
				animated.frames = frames
			animated.scale = Custom.HITSPARK_SPRITE_SCALES.get(sprite_name, Vector2(1, 1))
	var particle = get_node_or_null("CustomTrailParticle")
	if particle:
		var show_particles = bool(config.get("show_particles", false))
		var particle_settings = config.get("particles", null)
		if show_particles and particle_settings is Dictionary:
			# Now that we're in the tree, particle.particles (onready) is set
			# and load_settings runs without NPE-ing on color_ramp etc.
			# auto_start_on_ready also doubles as the "hitspark, keep
			# processing" flag — without it, CustomTrailParticle's
			# _physics_process auto-disables non-burst-clone particles every
			# frame in-game and our burst gets killed before it's visible.
			particle.no_preprocess = true
			particle.auto_start_on_ready = true
			particle.load_settings(particle_settings)
			particle.start_emitting()
		else:
			particle.queue_free()
