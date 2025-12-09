extends AnimationPlayer

# Accidentally placed the stuff on RESET and not the trailer animation :sob:
func _ready():
	play("RESET")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_SPACE:
			play("RESET")
