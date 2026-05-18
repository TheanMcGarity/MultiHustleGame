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

# Orb spawns this projectile at the orb's current y. Reposition + scale
# the sprite so its top-left lands at the projectile's node position
# (i.e., the orb's y) and its bottom lands at world y=0 — visually a
# vertical bolt that grows/shrinks with how high the orb was when the
# strike fired. centered=false anchors the sprite at top-left; offset.x
# pulls it back by half-width so it stays horizontally centered.
func _fit_sprite_to_spawn_height():
	if not sprite:
		return
	var spawn_y = get_pos().y
	var height = -spawn_y if spawn_y < 0 else 0
	sprite.centered = false
	sprite.offset = Vector2(-NATIVE_SPRITE_WIDTH / 2.0, 0)
	sprite.scale = Vector2(1, float(height) / float(NATIVE_SPRITE_HEIGHT))
