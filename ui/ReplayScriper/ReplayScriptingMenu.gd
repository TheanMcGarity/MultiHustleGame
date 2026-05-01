tool
extends Control

enum Page {
	CameraPage = 0, # camera stuff
	PosVelPage = 1, # position, velocity, force
	PlayerEffectsPage = 2, # ex: hitstun
	# todo: more stuff
}

onready var close_button = $"%Close"

func _process(delta):
	get_parent().move_child(self, len(get_parent().get_children()))

# Pages
onready var camera_page = $"%CameraPage"
onready var pos_vel_page = $"%PosVelPage"
onready var page_node:Control = get_page_from_enum(current_page)
export(Page) var current_page := Page.CameraPage setget set__page

# Page Switching
onready var camera_button = $"%CameraButton"
onready var pos_vel_button = $"%PosVelButton"

# Camera Page
onready var single_focus_button = $"%SingleFocusButton"
onready var single_focus_player = $"%SingleFocusPlayer"

onready var double_focus_button = $"%DoubleFocusButton"
onready var double_focus_player_1 = $"%DoubleFocusPlayer1"
onready var double_focus_player_2 = $"%DoubleFocusPlayer2"


onready var camera_zoom_button = $"%CamZoomButton"
onready var camera_zoom_slider = $"%CameraZoom"
onready var camera_zoom_ease = $"%ZoomEase"
onready var camera_zoom_ease_time = $"%ZoomEaseSeconds"

onready var camera_offset_button = $"%CamOffsetButton"
onready var camera_offset = $"%CamOffset"
onready var camera_offset_scale = $"%CamOffsetMagnitude"
onready var camera_offset_ease = $"%CamOffsetEase"

# Camera Controller
var camera_focus_center:BaseProjectile 
var camera_focus_scene = preload("res://ui/ReplayScriper/CameraFocusProjectile.tscn")

# Pos-Vel Page
onready var move_player = $"%MovePlayer"
onready var move_button = $"%MoveButton"
onready var move_wheel = $"%Move"
onready var move_scale = $"%MoveMagnitude"
func _ready():
	single_focus_button.connect("pressed",self,"on_single_focus_pressed")
	double_focus_button.connect("pressed",self,"on_double_focus_pressed")
	camera_offset_button.connect("pressed",self,"offset_camera")
	camera_zoom_button.connect("pressed",self,"on_zoom_change")
	
	move_button.connect("pressed",self,"offset_player")
	
	close_button.connect("pressed",self,"hide")
	
	camera_button.connect("pressed",self,"on_cam_button")
	pos_vel_button.connect("pressed",self,"on_pos_vel_button")
	pass

func set__page(val):
	current_page = val
	match val:
		Page.CameraPage:
			page_node.visible = false
			page_node = camera_page
			page_node.visible = true
		Page.PosVelPage:
			page_node.visible = false
			page_node = pos_vel_page
			page_node.visible = true
		_: # fallback
			page_node.visible = false
			page_node = camera_page
			page_node.visible = true

func get_page_from_enum(val):
	match val:
		Page.CameraPage:
			return camera_page
		Page.PosVelPage:
			return pos_vel_page
		_:
			return camera_page

func on_single_focus_pressed():
	print(Global.current_game.players)
	focus_camera_on_player(Global.current_game.players[int(single_focus_player.value)])

func on_double_focus_pressed():
	print(Global.current_game.players)
	focus_camera_on_players([
		Global.current_game.players[int(double_focus_player_1.value)],
		Global.current_game.players[int(double_focus_player_2.value)]
	])

func focus_camera_on_player(player):
	spawn_focus_proj(0, 0)
	camera_focus_center.attached_players = [player]
	camera_focus_center.init()
	camera_focus_center.tick()
	camera_focus_center.grab_camera_focus()
	
	add_script_to_replay({
		"type": "single_focus",
		"player": player.id
	})

func offset_camera():
	var already_exists = false
	if (is_instance_valid(camera_focus_center)):
		already_exists = true
	spawn_focus_proj(0, 0)
	if (not already_exists):
		camera_focus_center.attached_players = Global.current_game.players.values()
	camera_focus_center.init()
	camera_focus_center.tick()
	camera_focus_center.grab_camera_focus()
	
	var offset = camera_offset.value_float * camera_offset_scale.value
	camera_focus_center.offset = offset
	
	add_script_to_replay({
		"type": "cam_offset",
		"offset": offset
	})
func offset_player():
	var offset = move_wheel.value_float * move_scale.value * 10
	var player:Fighter = Global.current_game.players[int(move_player.value)]
	
	var pos = player.get_pos()
	var combined_pos = {
		"x": str(float(pos.x) + offset.x),
		"y": str(float(pos.y) + offset.y)
	}

	player.set_pos(combined_pos.x, combined_pos.y)
	player.last_pos = player.get_pos()
	player.update_data()
	print(player.data)
	add_script_to_replay({
		"type": "player_move",
		"new_pos": combined_pos,
		"player": player.id
	})
func offset_player_replay(pos, id):
	var player = Global.current_game.players[id]
	player.last_pos = player.get_pos()
	player.set_pos(pos.x, pos.y)
	player.update_data()

func offset_camera_replay(offset):
	var already_exists = false
	if (is_instance_valid(camera_focus_center)):
		already_exists = true
	spawn_focus_proj(0, 0)
	if (not already_exists):
		camera_focus_center.attached_players = Global.current_game.players.values()
	camera_focus_center.init()
	camera_focus_center.tick()
	camera_focus_center.grab_camera_focus()
	camera_focus_center.offset = offset


func on_zoom_change():
	change_camera_zoom(camera_zoom_slider.get_value())

var zoom_tween
func change_camera_zoom(val, ease_ = null, ease_time = null):
	var already_exists = false
	if (is_instance_valid(camera_focus_center)):
		already_exists = true
	spawn_focus_proj(0, 0)
	if (not already_exists):
		camera_focus_center.attached_players = Global.current_game.players.values()
	
	if ease_ == null:
		ease_ = camera_zoom_ease.pressed
	if ease_time == null:
		ease_time = camera_zoom_ease_time.value
	
	camera_focus_center.init()
	camera_focus_center.tick()
	camera_focus_center.grab_camera_focus()
	if ease_:
		if zoom_tween and zoom_tween.is_running():
			zoom_tween.kill()
		zoom_tween = create_tween()
		zoom_tween.tween_property(camera_focus_center, "zoom_multiplier", val, ease_time)
	else:
		camera_focus_center.zoom_multiplier = val
	
	
	add_script_to_replay({
		"type": "cam_zoom",
		"zoom": val,
		"ease": ease_,
		"ease_time": ease_time
	})
func focus_camera_on_players(players):
	spawn_focus_proj(0, 0)
	camera_focus_center.attached_players = players
	camera_focus_center.init()
	camera_focus_center.tick()
	camera_focus_center.grab_camera_focus()
	
	add_script_to_replay({
		"type": "double_focus",
		"player_one": players[0].id,
		"player_two": players[1].id
	})

func spawn_focus_proj(x, y):
	if is_instance_valid(camera_focus_center):
		return
	camera_focus_center = Global.current_game.players[1].spawn_object(camera_focus_scene, x, y)
	Global.current_game.on_object_spawned(camera_focus_center)


func replay_tick(scripts):
	for script in scripts:
		match script.type:
			"single_focus":
				focus_camera_on_player(Global.current_game.players[script.player])
			"cam_offset":
				offset_camera_replay(script.offset)
			"cam_zoom":
				change_camera_zoom(script.zoom, script.ease, script.ease_time)
			"player_move":
				offset_player_replay(script.new_pos, script.player)
			"double_focus":
				focus_camera_on_players([
					Global.current_game.players[script.player_one],
					Global.current_game.players[script.player_two]
				])
			_:
				print("Unknown script in replay! (%s)" % script)
#var existing_by_frame := []
func add_script_to_replay(script):
	if (ReplayManager.playback):
		return
	var tick = Global.current_game.current_tick
	#if (existing_by_frame.has("%s_%d" % [script.type, tick])):
	#		return
	if ReplayManager.frames.script.has(Global.current_game.current_tick):
		
		ReplayManager.frames.script[Global.current_game.current_tick].append(script)
	else:
		ReplayManager.frames.script[Global.current_game.current_tick] = [script]
	#existing_by_frame.append("%s_%d" % [script.type, tick])

func on_cam_button():
	self.current_page = Page.CameraPage
func on_pos_vel_button():
	self.current_page = Page.PosVelPage


func _unhandled_input(event):	
	if event is InputEventMouseButton:
		if event.button_index == 1:
			if event.pressed:
				modulate.a8 = 90
			else:
				modulate.a8 = 255
