extends BaseGround

var cube_scene = preload("res://arena_new/PhysicsCube.tscn")

func interact(player):
	spawn_physical(cube_scene, -80, -425)
	print("spawned cube?")
