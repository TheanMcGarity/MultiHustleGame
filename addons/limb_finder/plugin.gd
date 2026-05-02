tool
extends EditorPlugin

const MainPanel = preload("res://addons/limb_finder/LimbFinder.tscn")

var main_panel_instance
var selection

func _enter_tree():
	main_panel_instance = MainPanel.instance()
	main_panel_instance.editor_plugin = self
	add_control_to_bottom_panel(main_panel_instance, "Limb Tagger")
	selection = get_editor_interface().get_selection()
	selection.connect("selection_changed", self, "_on_editor_selection_changed")

func _on_editor_selection_changed():
	var selected_nodes = selection.get_selected_nodes()
	for node in selected_nodes:
		if node is BaseObj:
			main_panel_instance.load_node(node)
			break

func _exit_tree():
	if main_panel_instance:
		remove_control_from_bottom_panel(main_panel_instance)
		main_panel_instance.queue_free()

func get_plugin_name():
	return "Limb Tagger"
