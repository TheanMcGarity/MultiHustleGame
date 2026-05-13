extends ParticleEffect

# Config dict applied in _ready. Schema matches what the customization screen
# stores: {sprite, show_particles, particles, show_particles_2, particles_2,
# flip_when_facing_left}. The two particle slots map onto the two
# CustomTrailParticle children — slot 0 to CustomTrailParticle, slot 1 to
# CustomTrailParticle2. Either can be disabled independently.
# Set by the spawner BEFORE add_child so _ready sees it.
var custom_config = null

func _ready():
	._ready()
	if custom_config is Dictionary:
		_apply_config(custom_config)

func _apply_config(config):
	var sprite_name = str(config.get("sprite", ""))
	var animated = get_node_or_null("AnimatedSprite")
	if animated:
		if sprite_name == "":
			var empty := SpriteFrames.new()
			animated.frames = empty
			animated.visible = false
		else:
			var frames = load("res://fx/hitsparks/frames/%s_frames.tres" % sprite_name)
			if frames:
				animated.frames = frames
			animated.scale = Custom.HITSPARK_SPRITE_SCALES.get(sprite_name, Vector2(1, 1))
	_apply_particle_slot(
		get_node_or_null("CustomTrailParticle"),
		bool(config.get("show_particles", false)),
		config.get("particles", null))
	_apply_particle_slot(
		get_node_or_null("CustomTrailParticle2"),
		bool(config.get("show_particles_2", false)),
		config.get("particles_2", null))

func _apply_particle_slot(particle, show, settings):
	if particle == null:
		return
	if show and settings is Dictionary:
		# auto_start_on_ready doubles as the "hitspark, keep processing" flag —
		# without it, CustomTrailParticle's _physics_process auto-disables
		# non-burst-clone particles every frame in-game.
		particle.no_preprocess = true
		particle.auto_start_on_ready = true
		particle.load_settings(settings)
		particle.start_emitting()
	else:
		particle.queue_free()
