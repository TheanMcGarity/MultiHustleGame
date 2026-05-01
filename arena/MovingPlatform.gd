extends "res://arena_new/BaseGround.gd"

export var time_to_move:float

onready var move_ticks = int(time_to_move * 60)
onready var col = get_node("SolidBox")

func solid_tick_before():
	current_tick += 1
	
	position.y -= 1
	for obj in colliding:
		if (not is_instance_valid(obj)):
			continue
		var obj_pos = obj.get_pos()
		obj.set_pos(str(obj_pos.x), str(col.get_aabb().y1))
		#obj.set_grounded(true)
		if (obj is Fighter):
			var chara:Fighter = obj
			chara.grounded_last_frame = true

func solid_tick():
	for obj in colliding:
		if (not is_instance_valid(obj)):
			continue
		#obj.set_grounded(true)
		if (obj is Fighter):
			var chara:Fighter = obj
			chara.grounded_last_frame = true
