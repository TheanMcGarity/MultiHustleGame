extends "res://arena_new/BaseGround.gd"

var spring_tick = 0
var spring_state = -2

func solid_tick():
	match spring_state:
		1:
			spring_tick += 1
			position.x -= 12.65
			if (spring_tick == 15):
				spring_state = 0
				spring_tick = 0
		0:
			spring_tick += 1
			if (spring_tick == 75):
				spring_state = -1
				spring_tick = 0
		-2:
			spring_tick += 1
			if (spring_tick == 60):
				spring_state = 1
				spring_tick = 0
		-1:
			spring_tick += 1
			position.x += 2.2
			if (spring_tick == 40):
				spring_state = -2
				spring_tick = 0

	
