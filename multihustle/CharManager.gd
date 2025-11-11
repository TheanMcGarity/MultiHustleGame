extends Node

#class_name MultiHustle_CharManager

var main

var afterImageParent
var afterImages

func _init(main, game, afterImageParent):
	self.main = main
	self.afterImageParent = afterImageParent
	afterImages = {1:afterImageParent.find_node("AfterImage1", false, false), 2:afterImageParent.find_node("AfterImage2", false, false)}
	name = "MultiHustle_CharManager"
	game.add_child(self)
	game.multiHustle_CharManager = self
	unique_name_in_owner = true

func InitCharacter(game:Game, index:int, selectedChar:Dictionary):
		if Global.name_paths.has(selectedChar["name"]):
			InitCharacter_Internal(game, index, selectedChar)
			return true
		else :
			return false

func InitCharacter_Internal(game:Game, index:int, selectedChar:Dictionary):
	var player = load(Global.name_paths[selectedChar["name"]]).instance()
	game.players[index] = player
	game.player_turns[index] = false
	game.player_usernames[index] = null
	game.player_supers[index] = false
	game.ghost_player_actionables[index] = false
	match(index):
		1:
			game.p1 = player
		2:
			game.p2 = player
		#_: # Debug
			#player.dummy = true

func Create_GhostActions():
	for index in Global.current_game.players.keys():
		CreateGhost(index)

func CreateGhost(index:int):
	var curNode:Node = afterImages.get(index, null)
	if not is_instance_valid(curNode):
		curNode = afterImageParent.get_node_or_null(("AfterImage"+str(index)))
	if not is_instance_valid(curNode):
		curNode = afterImages[1].duplicate(7)
		curNode.set_name("AfterImage"+str(index))
		curNode.set_unique_name_in_owner(true)
		afterImageParent.add_child(curNode)
		afterImages[index] = curNode
