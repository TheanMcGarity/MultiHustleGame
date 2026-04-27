extends ObjectState
onready var hitbox = $Hitbox

export var poison = false

func _on_hit_something(obj, hitbox):
	queue_state_change("Pop")

func _tick():
	if poison:
		var opponent = host.get_opponent()
		if opponent and current_tick <= 14 and current_tick > 10:
			var target = host.obj_local_center(opponent)
			var dist = fixed.vec_len(str(target.x), str(target.y))
			if fixed.lt(dist, "30"):
				current_tick = 10


	if host.get_pos().y > -5:
		host.set_pos(host.get_pos().x, -5)
		var vel = host.get_vel()
		host.set_vel(vel.x, fixed.mul(fixed.abs(vel.y), "-0.25"))


	if host.get_fighter().is_in_hurt_state(false) and !host.get_opponent().current_state().get("IS_BURST"):
		queue_state_change("Pop")
