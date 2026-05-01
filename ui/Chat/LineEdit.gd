extends LineEdit

signal message_ready(message)

const MAX_MSG_LENGTH = 1500

func _ready():
	$"%SendButton".connect("pressed", self, "send_message")

func _gui_input(event):
	if len(text) < MAX_MSG_LENGTH:
			$"%TooLongLabel".hide()
	else:
			$"%TooLongLabel".show()
			$"%TooLongLabel".text = "message too long\n(%d/%d)" % [len(text), MAX_MSG_LENGTH]
	
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ENTER:
				send_message()
		$KeyboardSound.play()

func send_message():
	if text.strip_edges() == "":
		return
	if len(text) < MAX_MSG_LENGTH:
		emit_signal("message_ready", text.strip_edges())
