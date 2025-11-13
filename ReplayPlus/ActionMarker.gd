extends TextureRect

var tl
var id: int
var action
var frame: int
var frame_data
var action_title: String
var hovered = false

func init(tl, id, action, frame, frame_data):
	self.tl = tl
	self.id = id
	self.action = action
	self.frame = frame
	self.frame_data = frame_data
	action_title = action.title
	tl.connect("ui_zoom_updated", self, "_on_ui_zoom_update")
	connect("mouse_entered", self, "_mouse_entered")
	connect("mouse_exited", self, "_mouse_exited")
	connect("gui_input", self, "_on_gui_input")

func _ready():
	rect_position.x = (frame * tl.ui_zoom) - 8
	rect_position.y = 0 if id == 1 else -17
	texture = action.button_texture
	expand = true
	stretch_mode = STRETCH_KEEP_ASPECT
	rect_size = Vector2(16, 16)
	self_modulate.a = 0.75

func get_neighboring_actions():
	var result = []
	for child in get_parent().get_children():
		if rect_position.x - (rect_size.x * 2) < child.rect_position.x and rect_position.x + (rect_size.x * 2) > child.rect_position.x and not frame == child.frame:
			result.append(child)
	return result

func _on_ui_zoom_update():
	rect_position.x = (frame * tl.ui_zoom) - 8

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		tl.snap_to_frame(frame)

func _mouse_entered():
	tl.hovered_action = self
	hovered = true
	for action in get_neighboring_actions():
		action.self_modulate.a = 0.25
	self_modulate.a = 1

func _mouse_exited():
	tl.hovered_action = null
	hovered = false
	for action in get_neighboring_actions():
		action.self_modulate.a = 0.75
	self_modulate.a = 0.75
