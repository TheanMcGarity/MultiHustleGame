extends Window

func _ready():
	$"%Close".connect("pressed", self, "_on_close_pressed")
	pass

func _on_close_pressed():
	hide()
