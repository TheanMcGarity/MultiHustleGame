extends Window

onready var timer = $Timer
onready var ok_button = $"%OkButton"

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	set_process(false)
	pass # Replace with function body.

func start():
	show()
	set_process(true)
	timer.start()

func _process(delta):
	$"%TimerLabel".text = str(ceil(timer.time_left))
	pass

func _on_OkButton_pressed():
	self.queue_free()
	pass # Replace with function body.


func _on_Timer_timeout():
	ok_button.disabled = false
	pass # Replace with function body.
