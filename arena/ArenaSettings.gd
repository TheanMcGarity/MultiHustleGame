extends HBoxContainer


signal value_changed
var current_arena_settings : Dictionary
var arena_name_input
var arena_container
var arena_buttons := {}
var game_settings
var default_format
var original_version
var steam_lobby_list
export var is_steam_lobby = true


class MyCustomSorter:
	static func sort_ascending(a, b):
		return a.name < b.name


func _ready():
	arena_name_input = $"%ArenaNameInput"
	arena_container = $"%ArenaContainer"
	
	call_deferred("get_default_format")


func get_default_format():
	var sorted_nodes = arena_container.get_children()
	sorted_nodes.sort_custom(MyCustomSorter, "sort_ascending")
	
	for node in arena_container.get_children():
		arena_container.remove_child(node)
	
	for node in sorted_nodes:
		arena_container.add_child(node)
	
	var format = game_settings.get_data()
	format.erase("select_arena")
	default_format = format
	
	if not Network.multiplayer_active:
		if " MH-" in Global.VERSION:
			var splits = Global.VERSION.split(" ", true, 2)
			Global.VERSION = splits[0] + " " + splits[1]
		else:
			Global.VERSION = Global.VERSION.split(" ", true, 1)[0]
	
	original_version = Global.VERSION


func _on_SelectArenaButton_pressed():
	arena_name_input.emit_signal("text_entered", arena_name_input.text)


func _on_ArenaNameInput_text_entered(arena_name: String):
	if arena_name in arena_buttons:
		arena_buttons[arena_name].pressed = not arena_buttons[arena_name].pressed
		arena_buttons[arena_name].emit_signal("pressed")


func _on_ArenaButton_pressed(arena_name: String, arena_settings: Dictionary, arena_version: String):
	for arena_button in arena_buttons:
		if arena_button == arena_name:
			
			if arena_buttons[arena_name].pressed:
				Global.VERSION = original_version + " " + arena_version if arena_version else original_version + arena_version
				arena_name_input.text = arena_name
				current_arena_settings = arena_settings
				
				if not is_steam_lobby:
					_on_create_lobby_button_pressed()
				else:
					steam_lobby_list.request_lobby_list()
			else:
				Global.VERSION = original_version
				arena_name_input.text = ""
				current_arena_settings = default_format
				
				if not is_steam_lobby:
					_on_create_lobby_button_pressed()
				else:
					steam_lobby_list.request_lobby_list()
			
		elif arena_buttons[arena_button].pressed:
			arena_buttons[arena_button].pressed = false


func _on_create_lobby_button_pressed():
	game_settings.load_settings(default_format)
	game_settings.load_settings(current_arena_settings)


func _on_exit_lobby_list_button_pressed():
	Global.VERSION = original_version
