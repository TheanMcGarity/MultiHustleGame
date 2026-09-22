extends "res://characters/states/ForfeitExplosion.gd"

func is_usable():
	return .is_usable() and Global.current_game.triggered_allow_test_move
