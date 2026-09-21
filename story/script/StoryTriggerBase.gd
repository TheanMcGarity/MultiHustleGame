extends Resource

class_name BaseStoryTrigger

export var target_fighter = 1
export var trigger_once := true

var triggered := false

signal trigger()

# extend this
func should_trigger() -> bool:
	return false

func game():
	return Global.current_game

func get_player():
	return game().get_player(target_fighter)

func attempt_trigger() -> bool:
	if (trigger_once and triggered):
		return false
	if (should_trigger()):
		triggered = true
		emit_signal("trigger")
		return true
	return false
