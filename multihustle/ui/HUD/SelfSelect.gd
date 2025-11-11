extends "res://multihustle/ui/HUD/CharacterSelect.gd"

#class_name SelfCharacterSelect

onready var opponentSelect

# TODO: fix the naming style to fit with rest of code

const PAIR_SELECT_ID = 1

func get_paired_selector(p := 0):
	.get_paired_selector(PAIR_SELECT_ID)

func pre_connect():
	.pre_connect()
	select_index(id)
	opponentSelect.init(main, id)

func deactivate_char(index:int):
	reactivate_all_alive()
	.deactivate_char(index)

func _item_selected(index):
	._item_selected(index)
	var realIndex = index+1
	GetActionButtons().re_init(realIndex)
	InitUI(realIndex)
	parent.DeactivateOther(id, realIndex)
	opponentSelect.on_parent_changed()
	parent.opp_target_label.text = "OPP TARGET: %s" % get_char_name(opponentSelect.active_char_index)

func InitUI(index:int):
	InitHUD(index)

func GetActionButtons():
	match(id):
		1:
			return main.ui_layer.p1_action_buttons
		2:
			return main.ui_layer.p2_action_buttons

func InitHUD(index:int):
	match(id):
		1:
			main.hud_layer.initp1(index)
		2:
			main.hud_layer.initp2(index)

func clear_game_over():
	var game = get_game()
	for player in game.players.values():
		if get_active_char().game_over:
			var active_chars = parent.GetAllActiveChars()
			if !active_chars.has(player):
				select_char(player)
				break
	.clear_game_over()
