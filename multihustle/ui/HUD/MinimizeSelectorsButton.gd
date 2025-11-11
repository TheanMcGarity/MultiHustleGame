extends Button

export (NodePath) var node_to_hide

func on_press():
	var node = get_node(node_to_hide)
	if (node.visible):
		node.hide()
	else:
		node.show()

func _ready():
	connect("pressed", self, "on_press")
