extends SuperMove

func _frame_0():
	interruptible_on_opponent_turn = false

func process_projectile(projectile):
	host.add_spark_bomb(projectile.obj_name)
	interruptible_on_opponent_turn = true
	pass


export var trigger_orb_attack = true
export var trigger_orb_type = ""
export var trigger_orb_delay = 20
var triggered_orb_attack = false

func _enter_shared():
	._enter_shared()
	triggered_orb_attack = false
	pass

func _tick_shared():
	if !triggered_orb_attack and current_tick == 0:
		if trigger_orb_attack:
			if host.orb_projectile:
				host.objs_map[host.orb_projectile].trigger_attack(trigger_orb_type, trigger_orb_delay)
				triggered_orb_attack = true
	return ._tick_shared()
