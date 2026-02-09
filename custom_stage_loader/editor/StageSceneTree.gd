extends MarginContainer

var scene_path:NodePath setget set_scene_path,get_scene_path
var scene_root:Node setget set_scene_root,get_scene_root
var tree:Tree = null
var is_ready = false

signal item_selected(ind)
signal item_double_clicked(item)
signal item_added(parent, item)
signal item_removed(parent, item)
signal item_dragged(item)

# [Class, Icon]
var icon_defs = [
	[preload("res://custom_stage_loader/api/StageLayer.gd"), preload("res://custom_stage_loader/editor/Sprites/layer.png")],
	[preload("res://custom_stage_loader/api/StageElement.gd"), preload("res://custom_stage_loader/editor/Sprites/element.png")],
];
var default_icon = preload("res://custom_stage_loader/editor/Sprites/node.png");

func _ready():
	tree = $Tree
	_connect_signals()
	is_ready = true

func _connect_signals():
	tree.connect("item_double_clicked", self, "_on_item_double_click")

func _on_item_double_click(item):
	pass

# setter and getter for scene path- also sets the root variable
func set_scene_path(path):
	# use self to trigger setter so it rebuilds the tree
	self.scene_root = get_node(path)
	scene_path = path
func get_scene_path():
	return scene_path
	
# setter and getter for scene root
func set_scene_root(node):
	scene_path = get_path_to(node)
	scene_root = node
	rebuild_tree()
func get_scene_root():
	return scene_root

## Rebuilds the scene tree from the scene root.
func rebuild_tree() -> void:
	if !is_ready:
		yield(self, "ready")
	# empty tree, make the root and then recurse through the root's children to build the tree
	tree.clear()
	_make_root()
	_children_to_treeitems(tree.get_root())
	pass

# recursive function once again lol
func _children_to_treeitems(treeitem:TreeItem):
	var node = treeitem.get_metadata(0)
	for child in node.get_children():
		var item = tree.create_item(treeitem)
		# metadata column 0 is the node itself
		item.set_metadata(0, child)
		item.set_text(0, child.name)
		# check for an icon definition for the item
		for icon in icon_defs:
			if child is icon[0]:
				item.set_icon(0, icon[1])
				break
			item.set_icon(0, default_icon)
		# force the icon max width of 14 for column 0
		item.set_icon_max_width(0, 14)
		# recursion
		if child.get_child_count() > 0:
			_children_to_treeitems(item)

# not really implemented yet.
func add_bg(parent) -> void:
	var item = tree.create_item(parent)
	#item.set_icon(0, preload("res://custom_stage_loader/editor/Sprites/element.png"))
	var type = preload("res://custom_stage_loader/api/StageBackground.gd")
func add_layer(parent) -> void:
	var item = tree.create_item(parent)
	item.set_icon(0, preload("res://custom_stage_loader/editor/Sprites/layer.png"))
	var type = preload("res://custom_stage_loader/api/StageLayer.gd")
	pass
func add_element(parent) -> void:
	var item = tree.create_item(parent)
	item.set_icon(0, preload("res://custom_stage_loader/editor/Sprites/element.png"))
	var type = preload("res://custom_stage_loader/api/StageElement.gd")
	# var node = preload("res://custom_stage_loader/api/StageElement.gd").instance()
	
	pass
	
# Makes the root node. This will always be the stage canvas layer.
func _make_root() -> void:
	var item = tree.create_item(null, 0)
	item.set_metadata(0, scene_root)
	item.set_text(0, scene_root.name)
	item.set_icon(0, preload("res://custom_stage_loader/editor/Sprites/icon2.png"))
	item.set_icon_max_width(0, 14)
	pass
