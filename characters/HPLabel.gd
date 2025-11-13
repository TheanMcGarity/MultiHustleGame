extends RichTextLabel

export(String, MULTILINE) var text_format = "[center][color=#%s]%d[/color]/%d[/center]"
export(Dictionary) var text_variables = {
	"hp_color": "ffffff",
	"hp": "1500",
	"max_hp": "1500"
}
var is_ghost := false

func _process(delta):
	bbcode_enabled = true
	bbcode_text = text_format % [text_variables.hp_color,text_variables.hp,text_variables.max_hp]
	
	visible = Global.player_hp_label
	
	modulate = "c8ffffff" if not is_ghost else "5affffff"
