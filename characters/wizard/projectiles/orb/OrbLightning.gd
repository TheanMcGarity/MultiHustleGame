extends BaseProjectile

# Source frames are 512x512. The actual visible bolt occupies source-y
# 256 (top) → BOLT_BOTTOM_SOURCE_Y (bottom), about 134 pixels of bolt
# content surrounded by transparent canvas. We anchor source-y
# BOLT_BOTTOM_SOURCE_Y to world y=0 (ground impact) and crop everything
# in the source above the orb's spawn y so the rendered bolt visually
# starts at the orb and ends at the ground.
const NATIVE_SPRITE_WIDTH = 512
const NATIVE_SPRITE_HEIGHT = 512
const BOLT_BOTTOM_SOURCE_Y = 390

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
	if spawn_y >= 0:
		return  # orb at/below ground — nothing meaningful to draw
	# Crop the top of the source so the bolt visually starts at orb.y:
	#   world y at source-y N = spawn_y + (sprite.position.y) + (N - y_start)
	# We want world y == 0 at source-y BOLT_BOTTOM_SOURCE_Y, so the
	# sprite position.y compensates for any source-y rows we kept above
	# the bolt (when orb is higher than the natural bolt top).
	var y_start = int(max(0, spawn_y + BOLT_BOTTOM_SOURCE_Y))
	var crop_height = BOLT_BOTTOM_SOURCE_Y - y_start
	sprite.centered = false
	sprite.offset = Vector2(-NATIVE_SPRITE_WIDTH / 2.0, 0)
	sprite.scale = Vector2(1, 1)
	sprite.position = Vector2(0, max(0, -spawn_y - BOLT_BOTTOM_SOURCE_Y))
	if crop_height > 0:
		var frames_copy: SpriteFrames = sprite.frames.duplicate()
		for anim in frames_copy.get_animation_names():
			for i in range(frames_copy.get_frame_count(anim)):
				var src = frames_copy.get_frame(anim, i)
				if src == null:
					continue
				var atlas := AtlasTexture.new()
				atlas.atlas = src
				atlas.region = Rect2(0, y_start, NATIVE_SPRITE_WIDTH, crop_height)
				frames_copy.set_frame(anim, i, atlas)
		sprite.frames = frames_copy
	# Particle effect anchored at the ground impact too — scene-relative
	# offset was tuned for a fixed spawn height, remap per-instance.
	var particle = get_node_or_null("Flip/Particles/ParticleEffect")
	if particle:
		particle.position.y = -spawn_y
