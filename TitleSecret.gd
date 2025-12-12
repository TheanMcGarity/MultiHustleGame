extends TextureRect


func _ready():
	if randf() <= 0.01:
		flip_h = true
