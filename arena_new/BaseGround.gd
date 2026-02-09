extends BaseObj

class_name BaseGround

export var bounciness := 1

var colliding := []

var movement_velocity = Vector2(0,0)
var prev_pos = Vector2(0,0)

func init(pos = null):
	.init()
	
func _ready():
	add_to_group("Solids")

func calc_vel():
	movement_velocity = position - prev_pos
	prev_pos = position
	
func solid_tick():
	pass

func solid_tick_before():
	pass
