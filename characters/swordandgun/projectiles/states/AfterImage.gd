extends BaseProjectile

class_name ForesightAfterImage

var detonating = false

func disable():
	.disable()
	if (creator == null):
		return
	creator.after_image_object = null

func _ready():
	connect("got_hit", self, "on_got_hit")

func on_got_hit():
	disable()
