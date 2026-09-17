extends TextureRect

export var side := 1

export var glitch_max := 0.033
var glitch_val := 0.0
var per_player_glitch_val := {}

func _ready():
	material = material.duplicate(true)

func _process(delta):
	upd_glitch_val()
	material.set_shader_param("mh_glitch_intensity", glitch_val)

func upd_glitch_val():
	if not per_player_glitch_val.has(get_player()):
		glitch_val = 0.0
		return
		
	glitch_val = per_player_glitch_val[get_player()]

func get_player():
	if Network.main == null:
		return
	return Network.main.ui_layer.GetRealID(side)
