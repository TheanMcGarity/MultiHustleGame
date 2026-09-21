extends BaseStoryTrigger
class_name DeathStoryTrigger

export(int, 0.0, 1.0) var hp_percentage := 1.0

func should_trigger():
	return get_player().game_over
