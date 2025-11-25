extends "res://game.gd"


func _ready():
	add_child(preload("res://_AIOpponents/AIController.tscn").instance())
	._ready()

