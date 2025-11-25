extends Node

func _init(modLoader = ModLoader):
	  modLoader.installScriptExtension("res://_AIOpponents/ModOptions.gd")
	  modLoader.installScriptExtension("res://_AIOpponents/AILoader.gd")
	  #modLoader.installScriptExtension("res://_AIOpponents/ExperimentalChange.gd")
	 

func _ready():
	  pass
