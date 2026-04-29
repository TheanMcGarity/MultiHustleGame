extends BaseProjectile

const IS_ROBOT_MISSILE = true
const EXPLOSION = preload("res://characters/robo/projectiles/MissileExplosion.tscn")

var detected_friends = []
var arc_index = 0
var is_up_missile = false
var initial_facing = 1

func hit_by(hitbox):
	if hitbox.id == id:
		return
	.hit_by(hitbox)
	if hitbox and hitbox.throw:
		return
	if objs_map.has(hitbox.host):
		var host = objs_map[hitbox.host]
		if host.is_in_group("Fighter"):
			disable()

func disable():
	if !disabled:
		var explosion = spawn_object(EXPLOSION, 0, 0)
		if creator:
			explosion.set_facing(creator.get_facing_int())
	.disable()
