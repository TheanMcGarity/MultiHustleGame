extends ActionUIData
onready var direction = $"%Direction"


func fighter_update():
	direction.limit_angle = fighter.combo_count <= 0
	direction.update_value(direction.get_default_value())
