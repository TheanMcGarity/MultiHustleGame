extends BaseStoryTrigger
class_name HPStoryTrigger

export(float, 0.0, 1.0, 0.01) var hp_percentage := 0.5

func should_trigger():
	var max_hp = get_player().MAX_HP
	var hp = get_player().hp
	return (max_hp * hp_percentage) < hp
