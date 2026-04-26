extends ObjectState
onready var hitbox = $Hitbox

func _on_hit_something(obj, hitbox):
	queue_state_change("Pop")
	# don't call parent — prevents granting juke pips to mutant
