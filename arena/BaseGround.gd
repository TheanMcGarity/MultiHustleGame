tool

extends BaseObj

class_name BaseGround

# Anything extending this is very recommened to be a tool class, so that the size variables will work

export var _c_COLLIDER_SETTINGS = 0
export(Vector2) var size = Vector2(48,8) setget set_size
export var bounciness := 1
export var solid := true

var colliding := []

var movement_velocity = Vector2(0,0)
var prev_pos = Vector2(0,0)

func init(pos = null):
	.init()
	
func _ready():
	add_to_group("Solids")
	$"%Color".rect_size = size * 2
	var col = $"%SolidBox"
	if (solid):
		col.width = size.x
		col.x = size.x
		col.height = size.y
		col.y = size.y
		return
	col.width = 0
	col.x = 0
	col.height = 0
	col.y = 0
func calc_vel():
	movement_velocity = position - prev_pos
	prev_pos = position
	
func solid_tick():
	pass

func solid_tick_before():
	pass

func _editor_draw():
	$"%Color".rect_size = size * 2
	var col = $"%SolidBox"
	if (solid):
		col.width = size.x
		col.x = size.x
		col.height = size.y
		col.y = size.y
		return
	col.width = 0
	col.x = 0
	col.height = 0
	col.y = 0
func set_size(value):
	size = value
	if (Engine.editor_hint):
		_editor_draw()
