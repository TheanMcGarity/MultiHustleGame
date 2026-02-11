extends CanvasLayer

signal tick_changed(new_tick);
signal game_changed();

var game setget _set_game;
var data:Dictionary = {};
var current_tick:int = 0;

func _init(data:Dictionary):
	._init()
	
	self.data = data;

func _ready():
	game_check();

func _set_game(_game):
	game = _game;
	emit_signal("game_changed");
	
	return game;

# TODO: check if this is used anywhere & remove
func _on_material_loaded(material = null):
	pass;

func _process(_d):
	game_check();

func game_check():
	if is_instance_valid(Global.current_game) and game != Global.current_game:
		_set_game(Global.current_game);
	
	if is_instance_valid(game):
		tick_check();

func tick_check():
	if game.current_tick != current_tick:
		current_tick = game.current_tick;
		emit_signal("tick_changed", current_tick);
