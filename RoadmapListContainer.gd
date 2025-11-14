extends VBoxContainer

export var slide_time = 0.0
export var off_x = -230
export var on_x = 0

var state:bool = false

onready var y_pos = rect_position.y

func _ready():
	rect_position.x = off_x

func toggle(val):
	var tween := create_tween()
	match state:
		true:
			tween.tween_property(self, "rect_position", Vector2(off_x, y_pos), slide_time).set_trans(Tween.EASE_IN_OUT)
			state = false
		false:
			tween.tween_property(self, "rect_position", Vector2(on_x, y_pos), slide_time).set_trans(Tween.EASE_IN_OUT)
			state = true
