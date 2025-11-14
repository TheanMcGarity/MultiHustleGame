extends CharacterState

func _ready():
	is_hurt_state = true

func _enter():
	host.set_snap_to_ground(false)
	host.has_hyper_armor = false
	host.has_projectile_armor = false
	host.colliding_with_opponent = false
	host.opponent.colliding_with_opponent = false
	host.on_grabbed()
	host.start_invulnerability()
	var opponent = host.opponent
	if opponent \
		and opponent.current_state().state_name == "Grabbed" \
		and opponent.opponent == host:
		queue_state_change("Wait")
		opponent.current_state().queue_state_change("Wait")

func _exit():
	host.set_snap_to_ground(true)
