extends Button

class_name KofiButton, "res://ui/MHDonate/KofiLogo.png"

const KOFI_URL:String = "https://ko-fi.com/"
#
export var page_exists:bool = true
export var page:String = ""

func _ready():
	connect("pressed", self, "_on_pressed")

func _on_pressed():
	if page_exists:
		OS.shell_open(KOFI_URL + page)
