extends Button


export var colors := []
export var transition_time := 1.25

onready var max_index = colors.size()

var current_index := 0
var tween:SceneTreeTween

func _ready():
	start()
	pass
	
func start():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate", colors[current_index], transition_time)
	tween.connect("finished", self, "restart")
	
func restart():
	current_index += 1
	if current_index >= max_index:
		current_index = 0
	start()
