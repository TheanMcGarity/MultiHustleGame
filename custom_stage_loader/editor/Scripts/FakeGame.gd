extends Node2D

var stage_width = 1100
var drag_position = null
var camera_zoom = 1.0
var tick_pause = false

onready var camera = $Camera2D

signal zoom_changed()
signal game_tick(tick);

func _ready():
	camera.limit_left = - stage_width - 20
	camera.limit_right = stage_width + 20
	pass

func reset():
	sym_tick = 0;
	current_tick = 0;
	pass;

func _physics_process(delta):
	camera.tick();
	if not tick_pause: tick();

var tick_rate = 1;
var sym_tick = 0;
var current_tick = 0;
func tick():
	sym_tick += 1;
	
	var modulo = int(1 / tick_rate if tick_rate < 0 else 1)
	if sym_tick % modulo == 0:
		current_tick += max(1, int(tick_rate));
		
		emit_signal("game_tick", current_tick);
	
	pass;

func _process(delta):
	update();
	
	if camera.global_position.y > camera.limit_bottom - get_viewport_rect().size.y / 2:
		camera.global_position.y = camera.limit_bottom - get_viewport_rect().size.y / 2
	camera.global_position.x = clamp(camera.global_position.x, camera.limit_left + get_viewport_rect().size.x / 2, camera.limit_right - get_viewport_rect().size.x / 2);
	
	camera.zoom = Vector2(camera_zoom, camera_zoom)

# this is passed from the Viewport Container
func _passed_input(event:InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			drag_position = camera.get_local_mouse_position()
			raise()
		else :
			drag_position = null
	if (event is InputEventMouseMotion and drag_position):
		camera.global_position -= event.relative
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_WHEEL_UP:
				zoom_in()
			if event.button_index == BUTTON_WHEEL_DOWN:
				zoom_out()

func zoom_in():
	emit_signal("zoom_changed")
	camera_zoom -= 0.1
	if camera_zoom < 0.2:
		camera_zoom = 0.2

func zoom_out():
	emit_signal("zoom_changed")
	camera_zoom += 0.1
	if camera_zoom > 3.0:
		camera_zoom = 3.0

func reset_zoom():
	camera_zoom = 1.0
	emit_signal("zoom_changed")

func _draw():
	if drag_position:
		draw_circle(camera.position, 3, Color.white * 0.5)
	var line_color = Color.white
	draw_line(Vector2( - stage_width, 0), Vector2(stage_width, 0), line_color, 2.0)
	draw_line(Vector2( - stage_width, 0), Vector2( - stage_width, - 10000), line_color, 2.0)
	draw_line(Vector2(stage_width, 0), Vector2(stage_width, - 10000), line_color, 2.0)
	var line_dist = 50
	var num_lines = stage_width * 2 / line_dist
	for i in range(num_lines):
		var x = i * (((stage_width * 2)) / float(num_lines)) - stage_width
		draw_line(Vector2(x, 0), Vector2(x, 10), line_color, 2.0)
	draw_line(Vector2(stage_width, 0), Vector2(stage_width, 10), line_color, 2.0)
