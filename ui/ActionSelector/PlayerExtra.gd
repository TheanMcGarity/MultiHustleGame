extends HBoxContainer

signal data_changed()

class_name PlayerExtra

var fighter: Fighter
var player_id
var selected_move
# Set by ActionButtons before update_selected_move: true when the selected move
# isn't locked in yet and will re-enter from tick 0 (so a re-selected current
# move counts as a fresh cast, not a held continuation). Passed via a field
# rather than a method arg so mod PlayerExtra overrides keep the 1-arg signature.
var selected_move_will_restart = false
var can_feint = true

func _ready():
	connect("data_changed", self, "on_data_changed")

func on_data_changed():
	pass

func set_fighter(fighter: Fighter):
	self.fighter = fighter
	player_id = fighter.id

func get_extra():
	return {}

func show_options():
	return

func reset():
	selected_move = null
	pass

func update_selected_move(move_state):
	can_feint = true
	selected_move = move_state
	pass
