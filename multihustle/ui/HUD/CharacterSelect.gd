extends OptionButton

class_name CharacterSelect

var main
var id:int
var active_char_index:int
var parent
var connected:bool

var side:int


func get_paired_selector(select_id) -> CharacterSelect:
	return Network.main.uiselectors.selects[side][select_id]

# For some reason properties are broken
#var activeChar:Fighter setget , get_active_char
func get_active_char():
	return get_game().players[active_char_index]

#var game:Game setget , get_game
func get_game():
	return Global.current_game

#var ghost_game:Game setget , get_ghost_game
func get_ghost_game():
	return get_game().ghost_game

func init(main, id:int):
	self.main = main
	self.id = id
	var game = get_game()
	for index in game.players.keys():
		var player = game.players[index]
		add_item(get_char_name(index))
	if connected:
		return
	pre_connect()
	self.connect("item_selected", self, "_item_selected")
	connected = true

func reinit(main, id:int):
	self.main = main
	self.id = id
	var game = get_game()
	for index in game.players.keys():
		set_item_text(index-1,  get_char_name(index))

func pre_connect():
	pass

func get_char_name(index:int):
	var name:String
	# if multiplayer is active then check if
	# the player name exists, then return that. If it
	# doesnt, return placeholder text with the player id
	# or, just return the player id if it's singleplayer.
	if Network.multiplayer_active:
		if not Network.game.player_names.has(index):
			name = "{P%d NAME NOT FOUND}" % index
		else:
			name = Network.game.player_names[index]
	else:
		var chara = Network.player_character_names[index]
		name = "p%d - %s" % [index, chara]#, Network.player_character_uses[chara]]
	return name

func deactivate_char(index:int):
	set_item_disabled(index-1, true)

func reactivate_all_alive():
	var game = get_game()
	for index in game.players.keys():
		if !game.players[index].game_over:
			set_item_disabled(index-1, false)
		else:
			set_item_disabled(index-1, true)

func clear_game_over():
	var game = get_game()
	for index in game.players.keys():
		if game.players[index].game_over:
			set_item_disabled(index-1, true)

func _item_selected(index):
	active_char_index = index+1

func select_index(index:int):
	active_char_index = index
	select(index-1)

func select_char(character:Fighter):
	active_char_index = character.id
	select(character.id-1)
