extends "res://multihustle/ui/HUD/CharacterSelect.gd"

#class_name OpponentCharacterSelect

var self_char_index = 1

const PAIR_SELECT_ID = 0

func get_paired_selector(p := 0):
	.get_paired_selector(PAIR_SELECT_ID)


func PreConnect():
	.PreConnect()
	on_parent_changed()


func _item_selected(index):
	._item_selected(index)
	self_char_index = parent.active_char_index
	var paired_selector = get_paired_selector()

	#var pid = paired_selector.active_char_index

	if Network.multiplayer_active and not parent.visible:
		self_char_index = Network.player_id

	Network.select_opponent(self_char_index, active_char_index)
	
	parent.GetActionButtons().extra_updated()

func on_parent_changed():
	reactivate_all_alive()
	select_index(get_game().current_opponent_indicies[parent.active_char_index])
	deactivate_char(parent.active_char_index)
