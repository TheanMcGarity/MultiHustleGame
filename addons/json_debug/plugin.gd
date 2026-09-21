tool
extends EditorPlugin

var window_instance

func _enter_tree():
	var window_script = preload("res://addons/json_debug/Menu.tscn")
	window_instance = window_script.instance()
	
	window_instance.editor_plugin = self
	
	add_control_to_bottom_panel(window_instance, "Story Dev")

func _exit_tree():
	if window_instance:
		remove_control_from_bottom_panel(window_instance)
		window_instance.queue_free()
