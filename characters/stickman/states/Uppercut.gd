extends CharacterState

onready var hitbox_2 = $Hitbox2

export var air = false

# Captured on the first frame: was the opponent free (not in hitstun) when
# Ninja started this Uppercut? Used to gate the grounded-Uppercut
# neutral-hit bonus that ends the opponent's hitstun a couple frames after
# Ninja becomes actionable.
var was_neutral_hit = false

func _frame_0():
#	if current_tick == 0:
	was_neutral_hit = !air and host.opponent != null and !host.opponent.is_in_hurt_state(false)
	if host.initiative and host.is_grounded():
#		host.start_invulnerability()
		host.start_invulnerability()
#	host.start_throw_invulnerability()
#	if !host.is_grounded():
#		host.start_projectile_invulnerability()
	var vel = host.get_vel()
	if air_type != AirType.Aerial:
		if fixed.sign(vel.x) != host.get_facing_int():
			host.reset_momentum()
		else:
			host.reset_momentum()
			host.set_vel(fixed.div(vel.x, "3"), vel.y)
#	host.start_invulnerability()
	hitbox_2.block_punishable = false

func on_got_blocked():
	hitbox_2.block_punishable = true

func _on_hit_something(obj, hitbox):
#	if !air and (host.combo_moves_used.size() <= 0):
	if !air:
		host.apply_force("0", "6")
		if was_neutral_hit:
			host.cancel_opponent_hitstun_pending = true
			host.cancel_opponent_hitstun_countdown = -1

func _tick():
	host.apply_grav()
	host.apply_forces()
	if host.is_grounded() and current_tick > force_tick:
		return "UppercutLanding"

func _frame_4():
	host.end_invulnerability()
#	host.end_projectile_invulnerability()

func _frame_8():
	host.end_throw_invulnerability()

func _frame_9():
	host.end_invulnerability()
