extends Panel

signal spectate_requested(player)
signal team_change(id)
signal handicap_change(value)

onready var team:OptionButton = $"%ForcedTeam"
onready var handicap:SpinBox = $"%Handicap"

var p1
var p2

func init(member1):
	$"%Username".text = member1.steam_name
	p1 = member1
	handicap.connect("value_changed", self, "on_handicap_change")
	team.connect("item_selected", self, "on_team_change")


func _on_spectate_button_pressed():
	randomize()
	emit_signal("spectate_requested", p1 if randi() % 2 == 0 else p2)

func on_team_change(value):
	emit_signal("team_change", team.get_item_id(value))
func on_handicap_change(value):
	emit_signal("handicap_change", value)
