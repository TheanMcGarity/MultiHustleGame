extends BaseProjectile

# Source frames are 512x512 squares — used to compute the scale factor
# that makes the lightning span exactly from the orb's spawn y down to
# world y=0 (the ground). Re-compute if the sprite art ever changes size.
const NATIVE_SPRITE_WIDTH = 512
const NATIVE_SPRITE_HEIGHT = 512

func init(pos=null):
	.init(pos)
	_fit_sprite_to_spawn_height()

func on_got_push_blocked():
	if creator and !creator.disabled:
		creator.on_got_push_blocked()

# Orb spawns this projectile at the orb's current y. We slice the top
# off each animation frame by wrapping its texture in an AtlasTexture
# pinned to the bottom `height` pixels — no vertical scaling, so the
# bolt keeps its native proportions; the part of the sprite that would
# have rendered above the orb's spawn y just isn't drawn. SpriteFrames
# is duplicated per-instance so other lightnings (and any sprite
# sharing the source SpriteFrames) aren't affected.
func _fit_sprite_to_spawn_height():
	if not sprite:
		return
	var spawn_y = get_pos().y
	var height = -spawn_y if spawn_y < 0 else 0
	sprite.centered = false
	sprite.offset = Vector2(-NATIVE_SPRITE_WIDTH / 2.0, 0)
	sprite.scale = Vector2(1, 1)
	if height <= 0 or height >= NATIVE_SPRITE_HEIGHT:
		return
	var frames_copy: SpriteFrames = sprite.frames.duplicate()
	for anim in frames_copy.get_animation_names():
		for i in range(frames_copy.get_frame_count(anim)):
			var src = frames_copy.get_frame(anim, i)
			if src == null:
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = src
			atlas.region = Rect2(0, NATIVE_SPRITE_HEIGHT - height, NATIVE_SPRITE_WIDTH, height)
			frames_copy.set_frame(anim, i, atlas)
	sprite.frames = frames_copy
