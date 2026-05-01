extends BaseProjectile

var attached_players := []
var current_zoom

var offset = Vector2.ZERO
var zoom_multiplier = 1.0
var calculate_zoom = true

const MIN_ZOOM = 0.54

func init(pos = null):
	.init(pos)
	#disabled = true

func tick():
	if is_ghost:
		return
		
	if (len(attached_players) != 0):
		calc_midpoint(attached_players)
		#grab_camera_focus()
		set_camera_zoom(max(current_zoom * (1 / zoom_multiplier), MIN_ZOOM))
	else:
		release_camera_focus()

func grab_camera_focus(): # to get around the no tick rule on grab_camera_focus
	var camera = get_camera()
	if camera:
		camera.focused_object = self

func calc_midpoint(objects):
	var total_position = Vector2.ZERO
	
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)

	for obj in objects:
		var pos = obj.get_pos()
		var pos_vec = Vector2(float(pos.x),float(pos.y))
		total_position += (pos_vec + Vector2(0, -15))
		
		min_pos.x = min(min_pos.x, pos_vec.x)
		min_pos.y = min(min_pos.y, pos_vec.y)
		max_pos.x = max(max_pos.x, pos_vec.x)
		max_pos.y = max(max_pos.y, pos_vec.y)
		
	position = (total_position / objects.size()) + offset
	set_pos(str(position.x), str(position.y))
	var bounds = max_pos - min_pos

	if not calculate_zoom or len(objects) == 1:
		current_zoom = 1
		return
	var zoom_x = (bounds.x * 2.5) / 640
	var zoom_y = (bounds.y * 2.5) / 360

	current_zoom = max(zoom_x, zoom_y)

func get_center_position_float():
	if (attached_players.size() != 0):
		calc_midpoint(attached_players)
		
	return position
var tween
func set_camera_zoom(value):
	if is_ghost or ReplayManager.resimulating:
		return 
	if tween:
		tween.kill()
	var game = Global.current_game
	game.camera_zoom = value
	emit_signal("zoom_changed")
	game.update_camera_limits()
