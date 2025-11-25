extends "res://SoupModOptions/ModOptions.gd"

func _ready():
	var my_menu = generate_menu("_AIOptions", "AI Opponent Options")
	my_menu.add_label("lbl1", "AI Opponent Options Menu")
	
	var player_dropdown = my_menu.add_dropdown_menu("target_player", "AI Player")
	player_dropdown.add_item("Off")
	player_dropdown.add_item("Player 1")
	player_dropdown.add_item("Player 2")
	
	var mh_player_count = my_menu.add_number_slider("ai_count", "AI Player Count", 1, {min_value=1,max_value=3})

	var dropdown = my_menu.add_dropdown_menu("difficulty", "Difficulty")
	dropdown.add_item("Easy")
	dropdown.add_item("Medium")
	dropdown.add_item("Hard")
	
	my_menu.add_label("lbl3", "The harder the setting, the longer an AI will take to think, but the more possibilities it will consider. Hard mode takes especially long sometimes!")
	
	#var experimental_button = my_menu.add_bool("experimental", "Experimental Performance Increase")
	#my_menu.add_label("lbl4", "By deleting a line of YOMI's code, you can double decision speed! I hope it wasn't important!")
	
	
	add_menu(my_menu)
	
export var min_value = 0
export var max_value = 100
