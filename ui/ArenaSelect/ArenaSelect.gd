extends Control

onready var quit_button = $"%QuitButton"
onready var button_container = $"%ArenaButtonContainer"
onready var go_button = $"%GoButton"

var singleplayer := true

export(NodePath) var character_select
onready var css = get_node(character_select)

func init(singleplayer=true):
	self.singleplayer = singleplayer
	
func go():
	if !singleplayer:
		css.network_match_data["selected_characters"] = css.selected_characters
		css.emit_signal("match_ready", css.network_match_data)
	else:
		css.emit_signal("match_ready", css.get_match_data())
	hide()
	
func _ready():
	go_button.connect("pressed", self, "go")
