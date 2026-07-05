tool
extends RichTextEffect
class_name ShakierTextEffect

# (TickShake)
var bbcode = "tshake"

func _process_custom_fx(char_fx):
	var scale = char_fx.env.get("scale", 0.01)
	var rate = char_fx.env.get("rate", 10)
	var start = char_fx.env.get("start", 0)
	
	var time_factor = Global.current_game.current_tick - start
	
	var seed_x = char_fx.absolute_index * 13.0 + time_factor * rate
	var seed_y = char_fx.absolute_index * 37.0 + time_factor * rate
	
	var shake_x = sin(seed_x) * sin(seed_x * 0.5)
	var shake_y = cos(seed_y) * cos(seed_y * 0.7)
	
	char_fx.offset.x += shake_x * scale * time_factor
	char_fx.offset.y += shake_y * scale * time_factor
	
	return true
