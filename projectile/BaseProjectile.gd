extends BaseObj

signal got_parried()

class_name BaseProjectile

export var immunity_susceptible = true
export var deletes_other_projectiles = true
export var fizzle_on_ceiling = false
export var movable = true
export var can_be_hit_by_melee = false
export var hit_by_self_projectiles = false
export var hit_cancel_on_hit = false
export var free_cancel_on_hit = false
export var apply_hitlag_when_hit_by_melee = true
#export var can_be_hit_by_projectiles = false
export var projectile_immune = false
export var hitlag_modifier = "1.0"

var got_parried = false

var stopped = false

func _ready():
	state_variables.append_array(
		["got_parried", "immunity_susceptible", "hit_by_self_projectiles", "deletes_other_projectiles", "fizzle_on_ceiling", "movable", "can_be_hit_by_melee", "hit_cancel_on_hit", "projectile_immune", "hitlag_modifier", "stopped"]
	)

func get_opponent():
	if creator:
		if (creator.auto_set_opponent):
			var smallest_dist := INF
			var closest_player
			for player in get_game().players.values():
				if player.id == creator.id:
					continue
				if not player.game_over:
					var pos = get_pos()
					var other_pos = player.get_pos()
					var dist = fixed.vec_dist(str(pos.x), str(pos.y), str(other_pos.x), str(other_pos.y))
					if float(dist) < smallest_dist:
						smallest_dist = float(dist)
						closest_player = player
				
			return closest_player
						
		return creator.get_opponent()
	else:
		return obj_from_name("P%d" % id)

func get_fighter():
	if creator:
		if (creator.auto_set_opponent):
			var smallest_dist := INF
			var closest_player
			for player in get_game().players.values():
				if player.id == creator.id:
					continue
				if not player.game_over:
					var pos = get_pos()
					var other_pos = player.get_pos()
					var dist = fixed.vec_dist(str(pos.x), str(pos.y), str(other_pos.x), str(other_pos.y))
					if float(dist) < smallest_dist:
						smallest_dist = float(dist)
						closest_player = player
			creator.opponent = closest_player
		return creator.get_fighter()
	else:
		return obj_from_name("P%d" % id)

func disable():
	sprite.hide()
	state_machine.hide()
	collision_box.hide()

	hurtbox.hide()
	disabled = true
	for hitbox in get_active_hitboxes():
		hitbox.deactivate()
	stop_particles()


func on_got_parried():
	emit_signal("got_parried")

func _process(delta):
	if !disabled:
		update()

func on_hit_ceiling():
	if fizzle_on_ceiling:
		disable()

func can_hit_cancel(_fighter):
	return hit_cancel_on_hit

func hit_by(hitbox):
	if hitbox:
		if hitbox.throw:
			return
		hitlag_ticks = fixed.round(fixed.mul(hitlag_modifier, str(hitbox.victim_hitlag)))
		if objs_map.has(hitbox.host):
			var host = objs_map[hitbox.host]
			var host_hitlag_ticks = fixed.round(fixed.mul(hitlag_modifier, str(hitbox.hitlag_ticks)))
			if apply_hitlag_when_hit_by_melee:
				if host.hitlag_ticks < host_hitlag_ticks:
					host.hitlag_ticks = host_hitlag_ticks
			if free_cancel_on_hit and host.is_in_group("Fighter"):
				host.projectile_free_cancel()
		if hitbox.rumble:
			rumble(hitbox.screenshake_amount, hitbox.victim_hitlag if hitbox.screenshake_frames < 0 else hitbox.screenshake_frames)
	.hit_by(hitbox)
