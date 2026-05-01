extends CharacterState

var exploded := false

func _frame_0():
	if (exploded):
		return
	spawn_enter_particle()
	host.flip.hide()
	host.screen_bump(Vector2(), 20, 10 / 60.0)
	host.hp = 0
	host.play_sound("HitBass")
	exploded = true

func is_usable():
	return .is_usable() and Global.current_game.gamemode == 4
