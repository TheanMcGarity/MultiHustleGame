extends VBoxContainer


var recorded_ticks = []
var ui_active = false
var ui_zoom = 2
var ActionMarker = preload("res://ReplayPlus/ActionMarker.tscn")

var hovered_action = null
var timeline_hover = false
var follow_timemark = true
var max_replay_tick = 0

signal ui_zoom_updated()


func _ready():
	$"%PauseButton".connect("pressed", self, "_on_pause_toggle")
	$"%NextFrameButton".connect("pressed", self, "_on_1f_press")
	$"%CamLockButton".connect("pressed", self, "_on_camlock_press")
	$"%ResetPlaybackButton".connect("pressed", self, "reset_playback")
	$"%FollowTimemarkButton".connect("pressed", self, "_on_follow_timemark_press")
	$"%Timeline".connect("mouse_entered", self, "_tl_hover")
	$"%Timeline".connect("mouse_exited", self, "_tl_hover_exit")
	$"%Timeline".connect("gui_input", self, "_tl_gui_input")
	$"%ScrollContainer".get_h_scrollbar().connect("scrolling", self, "_on_hscroll")
	$"%ScrollContainer".connect("gui_input", self, "_on_scrollcontainer_gui_input")
	
	var speed_icon = preload("res://ReplayPlus/speed.png")
	$"%SpeedControl".connect("item_selected", self, "_on_speed_change")
	$"%SpeedControl".add_icon_item(speed_icon, "x1")
	$"%SpeedControl".add_icon_item(speed_icon, "x0.5")
	$"%SpeedControl".add_icon_item(speed_icon, "x0.25")
	$"%SpeedControl".selected = {
		1:0, 
		2:1, 
		4:2, 
	}[Global.playback_speed_mod]
	
	var zoom_icon = preload("res://ReplayPlus/zoom.png")
	$"%ZoomControl".connect("item_selected", self, "_on_zoom_change")
	$"%ZoomControl".add_icon_item(zoom_icon, ".5x")
	$"%ZoomControl".add_icon_item(zoom_icon, "1x")
	$"%ZoomControl".add_icon_item(zoom_icon, "2x")
	$"%ZoomControl".add_icon_item(zoom_icon, "3x")
	$"%ZoomControl".selected = ui_zoom - 1
	
	$"%PauseButton".icon = preload("res://ui/PlaybackWindow/pause_play1.png") if Global.frame_advance else preload("res://ui/PlaybackWindow/pause_play2.png")
	$"%HoverMark".hide()
	$"%HoveredTimeLabel".hide()
	_update_ft_button()
	
	get_parent().get_node("BottomBar/ActionButtons/VBoxContainer/P1ActionButtons").connect("action_clicked", self, "_on_action_clicked")
	get_parent().get_node("BottomBar/ActionButtons/VBoxContainer2/P2ActionButtons").connect("action_clicked", self, "_on_action_clicked")

func update_ui():
	update_max_tick()
	for player in $"%TimelineContainer".get_children():
		if "P0" in player.name:
			continue
		print("freed timeline object %s" % player.name)
		player.free()

	for id in ReplayManager.frame_ids():
		if not id is int:
				continue
		var timeline_actions_node = $"%P0Actions".duplicate()
		var timeline_actions_list = $"%P0Actions".get_parent()
		
		timeline_actions_list.add_child(timeline_actions_node)
		timeline_actions_node.name = "P%dActions" % id
		
		timeline_actions_node.get_child(1).text = "P%d" % id
		
		var actions_line:Line2D = timeline_actions_node.get_child(0)
		actions_line.points[1].x = $"%Timeline".rect_size.x
		
		timeline_actions_node.visible = true
		
		for frame in ReplayManager.frames[id].keys():
			
			var frame_data = ReplayManager.frames[id][frame]
			var action = Global.current_game.players[id].state_machine.get_state(frame_data.action)
			if action:
				var action_marker = ActionMarker.instance()
				action_marker.init(self, id, action, frame, frame_data)
				timeline_actions_node.add_child(action_marker)
	ui_active = true
	hovered_action = null

func reset_playback():
	if not ReplayManager.resimulating:
		Global.current_game.game_started = false
		Global.current_game.start_playback()

func update_ui_zoom(zoom: int):
	ui_zoom = zoom
	$"%Timeline".rect_min_size.x = max_replay_tick * ui_zoom
	emit_signal("ui_zoom_updated")

func snap_to_frame(frame: int):
	if is_instance_valid(Global.current_game) and not ReplayManager.resimulating:
		if Global.current_game.current_tick == frame: return
		$"%SnapSound".play()
		if Global.current_game.current_tick > frame:
			Global.current_game.game_started = false
			Global.current_game.start_playback()
			yield(get_tree(), "idle_frame")
		if frame == 0: return
		var prev_playback = ReplayManager.playback
		ReplayManager.resimulating = true
		ReplayManager.playback = true
		ReplayManager.resim_tick = frame - 1
		while ReplayManager.resimulating:
			Global.current_game.tick()
			Global.current_game.show_state()
		Global.current_game.show_state()
		ReplayManager.playback = prev_playback

func get_max_replay_tick():
	max_replay_tick = 0
	for tick in ReplayManager.frames[1].keys():
		if tick > max_replay_tick:
			max_replay_tick = tick
	for tick in ReplayManager.frames[2].keys():
		if tick > max_replay_tick:
			max_replay_tick = tick
	return max_replay_tick

func update_max_tick():
	get_max_replay_tick()
	$"%Timeline".max_value = max_replay_tick
	$"%Timeline".rect_min_size.x = max_replay_tick * ui_zoom

func _on_action_clicked(_action, _data, _extra):
	if visible:
		update_ui()

func _tl_hover():
	timeline_hover = true
	$"%HoverMark".show()
	$"%HoveredTimeLabel".show()

func _tl_hover_exit():
	timeline_hover = false
	$"%HoverMark".hide()
	$"%HoveredTimeLabel".hide()

func _on_speed_change(id: int):
	Global.playback_speed_mod = {
		0:1, 
		1:2, 
		2:4, 
	}[id]

func _on_zoom_change(id: int):
	update_ui_zoom(id + 1)

func _tl_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed and timeline_hover and not hovered_action:
		var mouse_x = get_global_mouse_position().x - $"%Timeline".rect_global_position.x
		var frame = int(ceil(mouse_x / ui_zoom))
		snap_to_frame(frame)

func _on_hscroll():
	follow_timemark = false
	_update_ft_button()

func _on_pause_toggle():
	var playback_controls = get_tree().get_root().get_node("Main/UILayer/ReplayControls")
	var pause_btn = playback_controls.get_node("VBoxContainer/Contents/VBoxContainer/HBoxContainer/PauseButton")
	var icon = preload("res://ui/PlaybackWindow/pause_play2.png") if Global.frame_advance else preload("res://ui/PlaybackWindow/pause_play1.png")
	if not Global.frame_advance:
		Global.frame_advance = true
		$"%PauseButton".icon = icon
		pause_btn.icon = icon
	else :
		Global.frame_advance = false
		$"%PauseButton".icon = icon
		pause_btn.icon = icon
	pause_btn.set_pressed_no_signal(Global.frame_advance)

func _on_1f_press():
	if is_instance_valid(Global.current_game):
		Global.current_game.advance_frame_input = true

func _on_camlock_press():
	if is_instance_valid(Global.current_game):
		Global.current_game.snapping_camera = !Global.current_game.snapping_camera

func _on_follow_timemark_press():
	follow_timemark = !follow_timemark
	_update_ft_button()

func _update_ft_button():
	if follow_timemark:
		$"%FollowTimemarkButton".add_color_override("font_color", Color("#2ecc71"))
		$"%FollowTimemarkButton".add_color_override("font_color_focus", Color("#2ecc71"))
		$"%FollowTimemarkButton".add_color_override("font_color_hover", Color("#27ae60"))
		$"%FollowTimemarkButton".add_color_override("font_color_pressed", Color("#27ae60"))
	else:
		$"%FollowTimemarkButton".add_color_override("font_color", Color(1, 1, 1))
		$"%FollowTimemarkButton".add_color_override("font_color_focus", Color(1, 1, 1))
		$"%FollowTimemarkButton".add_color_override("font_color_hover", Color(1, 1, 1))
		$"%FollowTimemarkButton".add_color_override("font_color_pressed", Color(1, 1, 1))

func _on_scrollcontainer_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index in [4, 5]:
		follow_timemark = false
		_update_ft_button()

func _process(delta):
	if ui_active and is_instance_valid(Global.current_game):
		var tick = Global.current_game.current_tick
		var half_zoom = float(ui_zoom) / 2.0
		
		# Update timeline, timemark and time label
		$"%Timeline".value = tick
		$"%TimeMark".rect_size.x = ui_zoom
		$"%TimeMark".rect_pivot_offset.x = half_zoom
		$"%TimeMark".rect_position.x = min(max_replay_tick, max(0, tick)) * ui_zoom - int(round(half_zoom))
		$"%TimeLabel".text = "Frame %s/%d" % [str(min(max_replay_tick, max(0, tick))).pad_zeros(str(max_replay_tick).length()), max_replay_tick]
		
		# Hovered action tooltip
		if hovered_action:
			$"%TooltipTopLabel".bbcode_text = "[center][color=#%s]P%d[/color] - [color=#f1c40f]F%d[/color][/center]" % ["b1a7ff" if hovered_action.id == 1 else "ff7a81", hovered_action.id, hovered_action.frame]
			$"%TooltipMiddleLabel".text = hovered_action.action_title
			var tooltip_size = $"%Tooltip".rect_size
			$"%Tooltip".rect_position.x = max(0, min(640 - tooltip_size.x, get_global_mouse_position().x - (tooltip_size.x / 2)))
			$"%Tooltip".rect_position.y = -tooltip_size.y - 16
			if not $"%Tooltip".visible:
				$"%Tooltip".show()
		elif $"%Tooltip".visible:
			$"%Tooltip".hide()
		
		# Follow cam button
		if Global.current_game.snapping_camera:
			$"%CamLockButton".add_color_override("font_color", Color("#2ecc71"))
			$"%CamLockButton".add_color_override("font_color_focus", Color("#2ecc71"))
			$"%CamLockButton".add_color_override("font_color_hover", Color("#27ae60"))
			$"%CamLockButton".add_color_override("font_color_pressed", Color("#27ae60"))
		else:
			$"%CamLockButton".add_color_override("font_color", Color(1, 1, 1))
			$"%CamLockButton".add_color_override("font_color_focus", Color(1, 1, 1))
			$"%CamLockButton".add_color_override("font_color_hover", Color(1, 1, 1))
			$"%CamLockButton".add_color_override("font_color_pressed", Color(1, 1, 1))
		
		# Update hover timemark
		if timeline_hover and not hovered_action:
			var mouse_x = get_global_mouse_position().x - $"%Timeline".rect_global_position.x
			var hovered_tick = int(ceil(mouse_x / ui_zoom))
			$"%HoverMark".rect_size.x = ui_zoom
			$"%HoverMark".rect_pivot_offset.x = half_zoom
			$"%HoverMark".rect_position.x = min(max_replay_tick, max(0, hovered_tick)) * ui_zoom - int(round(half_zoom))
			$"%HoveredTimeLabel".text = "@ " + str(hovered_tick)
		
		# Follow timemark
		if follow_timemark:
			$"%ScrollContainer".scroll_horizontal = ($"%TimeMark".rect_position.x + $"%Timeline".rect_position.x) - 320

func _unhandled_input(event:InputEvent):
	if event is InputEventKey and event.physical_scancode == 84 and event.pressed and not event.echo and is_instance_valid(Global.current_game) and not Network.multiplayer_active and Global.current_game.singleplayer:
		if visible:
			hide()
			$"%HideSound".play()
		else:
			show()
			update_ui()
			$"%ShowSound".play()
