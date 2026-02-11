extends ViewportContainer

onready var game = $Viewport/FakeGame

func _gui_input(event):
	game._passed_input(event)

var Loader;
var Builder;
func _ready():
	pass

var debug:bool = true;
func _process(_d):
	if debug:
		$DebugStats.text = "Current tick: " + str(game.current_tick);
		pass;
