extends Node

func _init(modLoader = ModLoader):
	print("instaler for multihusle")
	modLoader.add_child(load("res://_Installer/InstallerModCore.tscn").instance())
