tool
extends Control

var pos_data = Vector2()

onready var parent = get_parent()

func update_pos(pos):
	pos_data = pos
	update()

func _draw():
	var midpoint = parent.midpoint() # + Vector2(0, 1)
	if parent.last_di_pos != null and Global.show_last_di_state:
		var ghost_color = Color(1, 1, 0, 0.35)
		draw_line(midpoint, parent.last_di_pos, ghost_color, 1.0)
		draw_circle(parent.last_di_pos, 3, ghost_color)
	draw_line(midpoint, pos_data, Color.white, 1.0)
	draw_circle(pos_data, 3, Color.white)
