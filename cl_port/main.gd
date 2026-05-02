extends "res://main.gd"

# delete character cache button
func _ready():
	var mod_toggle = $"%ModToggle" if has_node("%ModToggle") else null
	var container = mod_toggle.get_parent() if mod_toggle else null

	if container and container.get_node_or_null("ModToggleRow") == null:
		var btt = Button.new()
		btt.name = "DeleteCache"
		btt.text = "delete character cache"
		btt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btt.connect("pressed", self, "_delete_char_cache", [btt])

		var hbox = HBoxContainer.new()
		hbox.name = "ModToggleRow"
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_constant_override("separation", 10)
		var idx = mod_toggle.get_index()
		container.remove_child(mod_toggle)
		container.add_child(hbox)
		container.move_child(hbox, idx)
		hbox.add_child(btt)
		hbox.add_child(mod_toggle)
		mod_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _delete_char_cache(btt):
	var dir = Directory.new()
	_Global.css_instance.charPackages = {}
	for f in ModLoader._get_all_files("user://char_cache", "pck"):
		dir.remove(f)
	get_tree().quit()

# these just load the necessary custom characters through characterSelect.gd
func _on_loaded_replay(match_data):
	_Global.css_instance.net_loadReplayChars([match_data.selected_characters[1]["name"], match_data.selected_characters[2]["name"], match_data])
	match_data["replay"] = true
	_on_match_ready(match_data)

func _on_received_spectator_match_data(data):
	get_node("/root/SteamLobby/LoadingSpectator/Label").text = "Spectating...\n(Loading Characters, this may take a while)"
	_Global.css_instance.net_loadReplayChars([data.selected_characters[1]["name"], data.selected_characters[2]["name"], data])
	data["spectating"] = true
	_on_match_ready(data)
