extends RobotState

var reversing_command_grab = false

func _enter():
	reversing_command_grab = data

func _frame_1():
	host.move_directly_relative(5, 0)

func _frame_2():
	host.start_throw_invulnerability()

func _frame_7():
	host.end_throw_invulnerability()

func _on_hit_something(obj, hitbox):
	if host.combo_count <= 0:
		host.combo_proration = 12
		# Latch it, or the next combo hit's increment_opponent_combo overwrites
		# this with that hitbox's (much lower) damage_proration.
		host.combo_proration_set = true
	._on_hit_something(obj, hitbox)
