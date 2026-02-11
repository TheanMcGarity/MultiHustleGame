extends BaseObj

class_name BaseGround


export var _c_SolidObjectData = 0
export var bounciness := 1.0

export var interact_once_per_hit := true

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
func _solid_tick_internal():
	if not initialized:
		init()
		initialized = true
	set_pos(str(position.x),str(position.y))
# Overridable Functions
func solid_tick():
	pass
func solid_tick_before():
	pass

func interact(player):
	pass
func finish_interacting(player):
	pass
