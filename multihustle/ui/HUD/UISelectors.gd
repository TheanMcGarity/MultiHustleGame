extends Node

#class_name MultiHustle_UISelectors

onready var selects = { # {side, [self, opp]}
	1:[ # Left
		get_child(1).get_child(0),
		get_child(1).get_child(2)
	],
	2:[ # Right
		get_child(1).get_child(1),
		get_child(1).get_child(3)
	] 
}
onready var local_char_select = selects[1][0]
var main

onready var opp_target_label:Label = get_child(1).get_child(4)

func Init(main):
	opp_target_label = get_child(1).get_child(4)
	self.main = main
	var assigned_ids = []
	for id in selects.keys():

		var char_select = selects[id][0]
		var opp_select = selects[id][1]

		char_select.side = id
		opp_select.side = id

		char_select.parent = self
		opp_select.parent = char_select
		char_select.opponentSelect = opp_select
		if id == 1 && Network.multiplayer_active:
			# I don't like the number of things I'm doing here, a better way is probably most certainly possible.
			char_select.init(main, id)
			char_select.select_index(Network.player_id)
			opp_select.on_parent_changed()
			assigned_ids.append(Network.player_id)
			char_select.hide()
		else:
			var new_id = 1
			while assigned_ids.has(new_id):
				new_id += 1
			# This too. I hate this.
			char_select.init(main, id)
			char_select.select_index(new_id)
			opp_select.on_parent_changed()
			assigned_ids.append(new_id)
		
	if Network.multiplayer_active:
		selects[2][1].visible = false
		opp_target_label.visible = true

	# TODO - Make this more expandable
	Network.log_to_file("Network Player ID: " + str(Network.player_id) + " | Assigned IDs: " + str(assigned_ids))
	selects[1][0].deactivate_char(assigned_ids[1])
	selects[2][0].deactivate_char(assigned_ids[0])

	opp_target_label.text = "OPP TARGET: %s" % selects[2][0].get_char_name(selects[2][1].active_char_index)

func reinit(main):
	opp_target_label = get_child(1).get_child(4)
	self.main = main
	for id in selects.keys():
		var char_select = selects[id][0]
		var opp_select = selects[id][1]

		var old_char = char_select.active_char_index+1;
		var old_opp = opp_select.active_char_index+1;

		if Network.game.players[old_char-1].game_over:
			old_char = get_first_living_char(old_char)
			
		if Network.game.players.has(old_opp-1):
			if Network.game.players[old_opp-1].game_over:
				old_opp = get_first_living_char(old_opp)


		if id == 1 and Network.multiplayer_active:
			char_select.hide()

		char_select.parent = self
		opp_select.parent = char_select
		char_select.opponentSelect = opp_select
		
		# This too. I hate this.
		char_select.reinit(main, id)
		opp_select.reinit(main, id)

		char_select.select_index(old_char-1)
		opp_select.select_index(old_opp-1)
		
	
	# TODO - Make this more expandable
	Network.log_to_file("(ReInit) Network Player ID: " + str(Network.player_id))
	
	if Network.multiplayer_active:
		selects[2][1].visible = false
		opp_target_label.visible = true

func DeactivateOther(selfId:int, charId:int):
	match(selfId):
		1:
			selects[2][0].deactivate_char(charId)
		2:
			selects[1][0].deactivate_char(charId)

func _process(delta):
	if  main == null or main.game == null:
		self.visible = false
		return
	self.visible = true
	for pair in selects.values():
		for entry in pair:
			if Network.multiplayer_active && entry == local_char_select:
				continue
			if !entry.visible && main.game.game_paused:
				entry.clear_game_over()
			entry.visible = main.game.game_paused

func GetAllActiveChars():
	var active_chars = []
	for pair in selects.values():
		var entry = pair[0]
		active_chars.append(entry.get_active_char())
	return active_chars

func ResetGhosts():
	for index in main.game.players.keys():
		main.player_ghost_actions[index] = "Continue"
		main.player_ghost_datas[index] = null
		main.player_ghost_extras[index] = null

func get_first_living_char(ignore) -> int:
	for character in Network.game.players:
		if not Network.game.players[character].game_over and not character == ignore:
			return character
	return 1
