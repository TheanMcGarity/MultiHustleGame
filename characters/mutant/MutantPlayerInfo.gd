extends PlayerInfo

onready var h_box_container = $HBoxContainer
onready var separator_1 = $HBoxContainer/Separator1
onready var separator_2 = $HBoxContainer/Separator2

func set_fighter(fighter):
	.set_fighter(fighter)
	if player_id == 1:
		$HBoxContainer.alignment = BoxContainer.ALIGN_BEGIN
	else:
		$HBoxContainer.alignment = BoxContainer.ALIGN_END
		call_deferred("update_p2_children")


func update_p2_children():
		var children = []
		separator_1.flip_h = true
		separator_2.flip_h = true
		for i in range($HBoxContainer.get_child_count()):
			$HBoxContainer.get_child(i).visible = fighter.juke_pips > i
			$HBoxContainer.get_child(i).flip_h = true
			children.push_front($HBoxContainer.get_child(i))
		
		for child in children:
			$HBoxContainer.remove_child(child)

		for child in children:
			$HBoxContainer.call_deferred("add_child", child)
	
func _process(delta):
	if !is_instance_valid(fighter):
		return
	for i in range(6):
		var child = h_box_container.get_node("TextureRect" + str(i + 1))
		if i >= fighter.JUKE_PIPS:
			child.visible = false
			continue
		var idx = i if player_id == 1 else fighter.JUKE_PIPS - i - 1
		child.visible = fighter.juke_pips > idx
		child.texture = preload("res://characters/mutant/ActivePip.tres") if (fighter.juke_pips / 2) > idx / 2 else preload("res://characters/mutant/pip3.png")
	if player_id == 1:
		separator_1.visible = fighter.juke_pips > 2
		separator_2.visible = fighter.juke_pips > 4
	else:
		# p2 reverses the child order, so Sep2 ends up after the first
		# two pips and Sep1 after the first four — swap the thresholds.
		separator_2.visible = fighter.juke_pips > 2
		separator_1.visible = fighter.juke_pips > 4

