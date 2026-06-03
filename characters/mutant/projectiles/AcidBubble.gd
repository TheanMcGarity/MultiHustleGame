extends BaseProjectile

const KNOCKBACK_MULTIPLIER = "2.0"
const MAX_SPEED = "10.0"
var no_juke_pips = false
# Opt-in per scene: Acrid Bloom bubbles let the opponent free-cancel by
# popping them too (bubble still pops); Envenom bubbles leave it off, so only
# the creator gets a free cancel.
export var opponent_can_free_cancel = false

func hit_by(hitbox):
	.hit_by(hitbox)
	if hitbox.throw:
		return
	if objs_map.has(hitbox.host):
		var host = objs_map[hitbox.host]
		if host:
			if host.id == id:
				var f = fixed.normalized_vec_times(fixed.mul(hitbox.dir_x, str(host.get_facing_int())), hitbox.dir_y, fixed.mul(hitbox.knockback, KNOCKBACK_MULTIPLIER))
				apply_force(f.x, f.y)
				if host.is_in_group("Fighter"):
					host.projectile_free_cancel()
			else:
				# Opponent hit: bubble still pops, but Acrid Bloom bubbles also
				# grant the opponent a free cancel (Envenom bubbles don't).
				if opponent_can_free_cancel and host.is_in_group("Fighter"):
					host.projectile_free_cancel()
				change_state("Pop")

func tick():
	.tick()
	limit_speed(MAX_SPEED)

func on_got_blocked():
	.on_got_blocked()
	change_state("Pop")
