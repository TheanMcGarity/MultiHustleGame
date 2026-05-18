extends ObjectState

export var LIFETIME = 30000

func _tick():
	anim_name = "OrbFire" if host.on_fire() else "Orb"
	if host.frozen:
		return
	if !host.locked:
		host.travel_towards_creator()
	host.attempt_triggered_attack()
	if current_tick > LIFETIME:
		host.disable()
	if host.push_ticks > 0:
		host.push_ticks -= 1
