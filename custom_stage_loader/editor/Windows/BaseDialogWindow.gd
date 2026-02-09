extends Window

onready var close_button = $"%CloseButton"
onready var text_label = $"%DialogText"
onready var base_text = text_label.text
onready var window_title = $VBoxContainer/TitleBar/Title
onready var options = $VBoxContainer/Contents/VBoxContainer/Options/HBoxContainer

signal dialog_closed()
signal option_selected(ind)

func _ready():
	close_button.connect("pressed", self, "_on_close_pressed")
	
	for node in options.get_children():
		if node is Button:
			node.connect("pressed", self, "_on_option_selected", [node.get_position_in_parent()])

func change_title(text):
	window_title.text = text

func show_dialog(text):
	text_label.text = base_text%text
	show()

func _on_close_pressed():
	hide()
	emit_signal("dialog_closed")

func _on_option_selected(ind):
	emit_signal("option_selected", ind)
