extends SpinBox

func _process(delta):
	if is_visible_in_tree():
		max_value = Global.current_game.players.size()
