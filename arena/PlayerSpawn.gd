tool

extends Node2D

class_name PlayerSpawnPoint

export(int) var player_id = 1 setget set_id

func _draw():
	if not is_instance_valid($EditorDisplay):
		return
	$EditorDisplay.visible = Engine.editor_hint
	$EditorDisplay/PlayerIDLabel.text = "P%d" % player_id

func set_id(value):
	player_id = value
	_draw()
