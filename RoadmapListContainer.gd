extends HBoxContainer

export var slide_time = 0.0
export var off_x = -230
export var on_x = 0

export var off_object_positions = {}
export var on_object_positions = {}

var state:bool = false

onready var y_pos = rect_position.y

func _ready():
	rect_position.x = off_x

func toggle(val):
	var tween := create_tween()
	match state:
		true:
			tween.parallel().tween_property(self, "rect_position", Vector2(off_x, y_pos), slide_time).set_trans(Tween.EASE_IN_OUT)
			
			for pos in off_object_positions.keys():
				tween.parallel().tween_property(get_node(pos), "rect_position", Vector2(off_object_positions[pos], get_node(pos).rect_position.y), slide_time).set_trans(Tween.EASE_IN_OUT)
			
			state = false
		false:
			tween.parallel().tween_property(self, "rect_position", Vector2(on_x, y_pos), slide_time).set_trans(Tween.EASE_IN_OUT)
			
			for pos in on_object_positions.keys():
				tween.parallel().tween_property(get_node(pos), "rect_position", Vector2(on_object_positions[pos], get_node(pos).rect_position.y), slide_time).set_trans(Tween.EASE_IN_OUT)
			
			state = true
