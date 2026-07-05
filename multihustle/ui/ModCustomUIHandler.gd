extends Node

class_name MHCharacterUI

var all = { }

func get_all_nodes(self_node):
	var result = []
	for node in self_node.get_children():
		result.append_array(get_all_nodes(node))
		if (not node in result):
			result.append(node)
	return result
	
func _get_nodes_with(nodes, property:String):
	var result = []
	for node in nodes:
		if (node.get(property) != null):
			return node
	return result

func _get_player_from_node(node):
	var current = node
	while true:
		if (current == null):
			return null
		if (current.get("players") != null):
			return null

		if (current.get("id") != null):
			break
		
		current = current.get_parent()
	
	return current

# nvm i wont use this because the ui runs in _enter_tree
# so it wouldnt work.
func get_all_ui_nodes(root):
	all = { }
	var nodes = get_all_nodes(root)
	var nodes_with = _get_nodes_with(nodes, "nodepaths")
	for node in nodes_with:
		var player = _get_player_from_node(node)
		if (player == null):
			continue
		all[player.id] = {
			"ui": node,
			"path_var": node.nodepaths
		}
func get_ui_node_from_player(player):
	var nodes = get_all_nodes(player)
	var nodes_with = _get_nodes_with(nodes, "nodepaths")
	for node in nodes_with:
		all[player.id] = {
			"ui": node,
			"path_var": node.nodepaths
		}
