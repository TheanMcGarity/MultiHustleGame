extends GridContainer

onready var base_button = $"%SidePickerButton"

var players := {}

func init(data):
	if data and data.has("display_names"):
		var names = data.display_names
		for player in names:
			var name = names[player]
			var new_button = base_button.duplicate()
			new_button.text = name
			new_button.name = "SidePickerP%dButton" % player
			players[player] = new_button
			self.add_child(new_button)
			new_button.visible = true
