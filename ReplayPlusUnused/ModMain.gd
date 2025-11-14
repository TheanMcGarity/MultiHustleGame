extends Node

var MOD_NAME = "Replay+"
onready var VERSION = ModLoader._readMetadata("res://ReplayPlus/_metadata")["version"]

func _init(modLoader = ModLoader):
	modLoader.installScriptExtension("res://ReplayPlus/MLMainHook.gd")
	var file = File.new()
	if file.file_exists("res://SoupModOptions/ModOptions.gd"):
		modLoader.installScriptExtension("res://ReplayPlus/ModOptionsAddon.gd")
	name = "ReplayPlus"
