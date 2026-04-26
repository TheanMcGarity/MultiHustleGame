extends ThrowState

onready var anim_length_ = anim_length

func _frame_1():
	if host.is_neutral_juke():
		anim_length = 21
		minimum_grounded_frames = 3
	else:
		anim_length = anim_length_
		minimum_grounded_frames = -1
