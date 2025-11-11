extends Node

onready var action_buttons_scene = preload("res://ui/ActionSelector/ActionButtons.tscn")
var main
var bottombar

var vbox_container_left
var vbox_container_right
var custom_data_left
var custom_data_right
var action_buttons_left = {}
var action_buttons_right = {}
var active_buttons_left
var active_buttons_left_index
var active_buttons_right
var active_buttons_right_index

var last_active = {}

func init_actionbuttons():
	if !is_instance_valid(active_buttons_left):
		active_buttons_left = action_buttons_left[1]
	if !is_instance_valid(active_buttons_right):
		active_buttons_right = action_buttons_right[2]
	set_active_buttons(1, false)
	set_active_buttons(2, true)
	# This is just to make sure
	action_buttons_left[1].reset()
	action_buttons_right[2].reset()
	custom_data_left = get_custom_data(action_buttons_left[1])
	custom_data_right = get_custom_data(action_buttons_right[2])
	
	var game = Global.current_game
	var has_exclusions = Network.multiplayer_active
	reset_buttons(false, has_exclusions)
	reset_buttons(true, has_exclusions)
	for id in game.players.keys():
		if !has_exclusions:
			setup_buttons(id, false)
		setup_buttons(id, true)
		if !last_active.has(id) or !is_instance_valid(last_active[id]):
			last_active[id] = action_buttons_right[id]

func setup_buttons(id:int, is_right:bool):
	var action_buttons
	var group
	if !is_right:
		group = action_buttons_left
	else:
		group = action_buttons_right
	
	if !group.has(id):
		action_buttons = action_buttons_scene.instance()
		if !is_right:
			var new_owner = set_custom_data(action_buttons, custom_data_left)
			vbox_container_left.add_child(action_buttons)
			action_buttons.owner = new_owner
			action_buttons.opposite_buttons = action_buttons_left[1]
		else:
			var new_owner = set_custom_data(action_buttons, custom_data_right)
			vbox_container_right.add_child(action_buttons)
			action_buttons.owner = new_owner
			action_buttons.opposite_buttons = action_buttons_right[2]
		action_buttons.init(Global.current_game, id)
		action_buttons.connect("visibility_changed", bottombar, "_on_action_buttons_visibility_changed")
		action_buttons.connect("action_clicked", main, "on_action_clicked", [id])
		group[id] = action_buttons
		
	else:
		action_buttons = group[id]
	
	action_buttons.init(Global.current_game, id)

func reset_buttons(is_right:bool, has_exclusions:bool):
	var group
	if !is_right:
		group = action_buttons_left
	else:
		group = action_buttons_right
	
	for index in group.keys():
		if !is_instance_valid(group[index]):
			group.erase(index)
	for index in group.keys():
		var action_buttons = group[index]
		if has_exclusions:
			if check_index_match(index, 1, is_right):
				action_buttons.reset()
			else:
				action_buttons.queue_free()
				group.erase(index)
		else:
			action_buttons.reset()

func check_index_match(index:int, check:int, is_exclude:bool):
	if !is_exclude:
		return index == check
	else:
		return index != check

func set_active_buttons(id:int, is_right:bool):
	var old_buttons
	var active_buttons
	if !is_right:
		old_buttons = active_buttons_left
		active_buttons = action_buttons_left[id]
		if active_buttons == old_buttons:
			return
		
		old_buttons.name = "P1ActionButtons"+str(active_buttons_left_index)
		
		active_buttons = action_buttons_left[id]
		active_buttons_left_index = id
		main.ui_layer.p1_action_buttons = active_buttons
		active_buttons.name = "P1ActionButtons"
		active_buttons.unique_name_in_owner = true
		active_buttons.connect("action_clicked", main, "on_action_clicked", [1])
		active_buttons_left = active_buttons
		active_buttons.show()
		
		old_buttons.hide()
	else:
		old_buttons = active_buttons_right
		active_buttons = action_buttons_right[id]
		if active_buttons == old_buttons:
			return
		
		old_buttons.name = "P2ActionButtons"+str(active_buttons_right_index)
		
		active_buttons = action_buttons_right[id]
		active_buttons_right_index = id
		main.ui_layer.p2_action_buttons = active_buttons
		active_buttons.name = "P2ActionButtons"
		active_buttons.unique_name_in_owner = true
		active_buttons.connect("action_clicked", main, "on_action_clicked", [2])
		active_buttons_right = active_buttons
		active_buttons.show()
		
		old_buttons.hide()
	last_active[id] = active_buttons

func get_custom_data(obj):
	return {
		"owner":obj.owner,
		"player_id":obj.player_id,
		"anchor_right":obj.anchor_right,
		"anchor_bottom":obj.anchor_bottom,
		"margin_top":obj.margin_top,
		"margin_right":obj.margin_right,
		"margin_bottom":obj.margin_bottom,
		"rect_position":obj.rect_position,
		"rect_size":obj.rect_size,
		"rect_min_size":obj.rect_min_size,
		"size_flags_horizontal":obj.size_flags_horizontal
	}

func set_custom_data(obj, dic:Dictionary):
	obj.owner = dic["owner"]
	obj.player_id = dic["player_id"]
	obj.anchor_right = dic["anchor_right"]
	obj.anchor_bottom = dic["anchor_bottom"]
	obj.margin_top = dic["margin_top"]
	obj.margin_right = dic["margin_right"]
	obj.margin_bottom = dic["margin_bottom"]
	obj.rect_position = dic["rect_position"]
	obj.rect_size = dic["rect_size"]
	obj.rect_min_size = dic["rect_min_size"]
	obj.size_flags_horizontal = dic["size_flags_horizontal"]
	return dic["owner"]
