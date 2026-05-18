extends BaseProjectile

# Source frames are 512x512. The bolt content sits in source-y
# BOLT_TOP_SOURCE_Y → BOLT_BOTTOM_SOURCE_Y (134 px tall), the rest of
# the canvas is transparent. Top of the bolt always renders at the
# orb's spawn y; bottom snaps to GROUND_ANCHOR_Y if the orb is low
# enough to reach, otherwise lands in the air at spawn_y + BOLT_HEIGHT.
const NATIVE_SPRITE_WIDTH = 512
const BOLT_TOP_SOURCE_Y = 256
const BOLT_BOTTOM_SOURCE_Y = 390
const BOLT_HEIGHT = BOLT_BOTTOM_SOURCE_Y - BOLT_TOP_SOURCE_Y
# World y the bolt's bottom anchors to when the orb is within reach of
# the ground. Tune if the visual floor isn't at world y=0.
const GROUND_ANCHOR_Y = 0

func init(pos=null):
	.init(pos)
	_fit_sprite_to_spawn_height()

func on_got_push_blocked():
	if creator and !creator.disabled:
		creator.on_got_push_blocked()

func _fit_sprite_to_spawn_height():
	if not sprite:
		return
	var spawn_y = get_pos().y
	# Visible bolt height — capped at BOLT_HEIGHT so an orb above the
	# bolt's natural reach gets the FULL bolt with its endpoint in the
	# air (rather than stretched to the ground or held at the old min).
	var vh = int(clamp(GROUND_ANCHOR_Y - spawn_y, 0, BOLT_HEIGHT))
	sprite.centered = false
	sprite.offset = Vector2(-NATIVE_SPRITE_WIDTH / 2.0, 0)
	sprite.scale = Vector2(1, 1)
	sprite.position = Vector2(0, 0)
	if vh <= 0:
		sprite.visible = false
		return
	# Keep the BOTTOM `vh` source rows of the bolt — bolt-bottom
	# (splash) is always preserved, top gets sliced when orb is low.
	var y_start = BOLT_BOTTOM_SOURCE_Y - vh
	var frames_copy: SpriteFrames = sprite.frames.duplicate()
	for anim in frames_copy.get_animation_names():
		for i in range(frames_copy.get_frame_count(anim)):
			var src = frames_copy.get_frame(anim, i)
			if src == null:
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = src
			atlas.region = Rect2(0, y_start, NATIVE_SPRITE_WIDTH, vh)
			frames_copy.set_frame(anim, i, atlas)
	sprite.frames = frames_copy
	# Particle rides the bolt's endpoint — at GROUND_ANCHOR_Y when low,
	# floating with the orb in the air when high.
	var particle = get_node_or_null("Flip/Particles/ParticleEffect")
	if particle:
		particle.position.y = vh
