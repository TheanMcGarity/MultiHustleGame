extends Node2D

var line_color
var game
var modOptions
var rainbow_effect_t = 0.0

var draw_pips = true

func _ready():
	game = Global.current_game
	modOptions = get_tree().get_root().get_node("Main/ModOptions");

func _process(delta):
	update()
	rainbow_effect_t += delta
	rainbow_effect_t = fmod(rainbow_effect_t, 1.0)

func _draw():
	if game.is_ghost:
		return 
	if not game.snapping_camera and game.mouse_pressed:
		draw_circle(game.camera.position, 3, Color.white * 0.5)

	if modOptions.get_setting("CustomStageLoader", "lines_hex_string") != "rainbow":
		line_color = Color(modOptions.get_setting("CustomStageLoader", "lines_hex_string"))
	else:
		line_color = Color.from_hsv(rainbow_effect_t, 0.8, 1)

	var ceiling_draw_height = - 100000 if not game.has_ceiling else - game.ceiling_height
	draw_line(Vector2( - game.stage_width, 0), Vector2(game.stage_width, 0), line_color, 2.0)

	draw_line(Vector2( - game.stage_width, 0), Vector2( - game.stage_width, ceiling_draw_height), line_color, 2.0)
	draw_line(Vector2(game.stage_width, 0), Vector2(game.stage_width, ceiling_draw_height), line_color, 2.0)
	if game.has_ceiling:
		draw_line(Vector2( - game.stage_width, ceiling_draw_height), Vector2(game.stage_width, ceiling_draw_height), line_color, 2.0)
	var line_dist = 50
	var small_line_dist = 10
	var num_lines = game.stage_width * 2 / line_dist
	if draw_pips:
		for i in range(num_lines):
			var x = i * (((game.stage_width * 2)) / float(num_lines)) - game.stage_width
			draw_line(Vector2(x, 0), Vector2(x, 10), line_color, 2.0)
	num_lines = game.stage_width * 2 / small_line_dist

	draw_line(Vector2(game.stage_width, 0), Vector2(game.stage_width, 10), line_color, 2.0)
