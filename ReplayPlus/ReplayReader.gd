extends Node

onready var replay_ok_texture = preload("res://ReplayPlus/replay_ok.png")
onready var replay_bad_texture = preload("res://ReplayPlus/replay_bad.png")
onready var replay_warn_texture = preload("res://ReplayPlus/replay_warn.png")

onready var mod_options = get_parent().get_node("ModOptions")
onready var replay_container = get_parent().get_node("UILayer/ReplayWindow/VBoxContainer/Panel/ScrollContainer/ReplayContainer")
var search_bar: LineEdit
var char_dropdown: OptionButton
var char_options = {} # map names to indexes

func _ready():
	var replay_window = get_parent().get_node("UILayer/ReplayWindow")
	
	get_parent().get_node("UILayer/MainMenu/ButtonContainer/ReplayButton").connect("pressed", self, "_on_view_replays", [], CONNECT_DEFERRED)
	replay_window.get_node("VBoxContainer/HBoxContainer/ShowAutosavedReplays").connect("pressed", self, "_on_view_replays", [], CONNECT_DEFERRED)
	
	search_bar = LineEdit.new()
	search_bar.name = "ReplayPlusSearchBar"
	search_bar.placeholder_text = "Search replays..."
	search_bar.caret_blink = true
	search_bar.caret_blink_speed = 0.5
	search_bar.clear_button_enabled = true
	search_bar.connect("text_changed", self, "_on_search_update")
	
	char_dropdown = OptionButton.new()
	char_dropdown.name = "ReplayPlusCharacterFilter"
	char_dropdown.align = Button.ALIGN_CENTER
	char_dropdown.size_flags_horizontal = Button.SIZE_EXPAND_FILL
	char_dropdown.add_item("All Characters")
	char_dropdown.connect("item_selected", self, "_on_item_selected")
	
	replay_window.get_node("VBoxContainer").add_child(search_bar)
	replay_window.get_node("VBoxContainer/HBoxContainer").add_child_below_node(replay_window.get_node("VBoxContainer/HBoxContainer/ShowAutosavedReplays"), char_dropdown, true)
	
	name = "ReplayPlusReader"

func _format_character_name(char_name: String, with_hash = true):
	# Fix modded character names
	if char_name.find("F-") == 0 and char_name.find("__") != -1:
		var name_split: PoolStringArray = char_name.split("__")
		if name_split[0].length() == 34 and name_split[1]:
			if with_hash:
				return "%s (%s)" % [name_split[1], name_split[0].substr(2, 6)]
			else:
				return name_split[1]
	
	return char_name

func _on_item_selected(item: int):
	_on_search_update(search_bar.text)

func _on_search_update(query: String):
	if query == "":
		for replay in replay_container.get_children():
			replay.show()
			if char_dropdown.selected == 0:
				continue
			var match_data = ReplayManager.load_replay(replay.path)
			if _format_character_name(match_data["selected_characters"][1].name, false) != char_options[char_dropdown.selected] and _format_character_name(match_data["selected_characters"][2].name, false) != char_options[char_dropdown.selected]:
				replay.visible = false
	else:
		var lower_query = query.to_lower()
		for replay in replay_container.get_children():
			var replay_name = replay.path.to_lower().get_basename().get_file()
			replay.visible = replay_name.find(lower_query) != -1
			if char_dropdown.selected == 0 or !replay.visible:
				continue
			var match_data = ReplayManager.load_replay(replay.path)
			if _format_character_name(match_data["selected_characters"][1].name, false) != char_options[char_dropdown.selected] and _format_character_name(match_data["selected_characters"][2].name, false) != char_options[char_dropdown.selected]:
				replay.visible = false

func compat_icons_enabled():
	return !is_instance_valid(mod_options) or mod_options.get_setting("ReplayPlus", "compat_icons")

func _on_view_replays():
	var available_characters = Global.name_paths.keys()
	if Network.get("css_instance"):
		available_characters.append_array(Network.css_instance.name_to_index.keys())
	char_dropdown.clear()
	char_dropdown.add_item("All Characters")
	char_dropdown.add_separator()
	var index = 2
	for character in available_characters:
		var clean_char_name = _format_character_name(character, false)
		if !char_options.keys().has(clean_char_name):
			char_dropdown.add_item(clean_char_name)
			char_options[index] = clean_char_name
			index += 1
	if compat_icons_enabled():
		for replay in replay_container.get_children():
			var match_data = ReplayManager.load_replay(replay.path)
			if not ("version" in match_data): continue
			var version_match = match_data["version"].split(" ")[0].begins_with(Global.VERSION.split(" ")[0])
			var invalid_characters = PoolStringArray()
			for _i in 2:
				var i = _i + 1
				if not match_data["selected_characters"][i].name in available_characters and not invalid_characters.has(match_data["selected_characters"][i].name):
					invalid_characters.append(match_data["selected_characters"][i].name)
			
			var texture_rect = TextureRect.new()
			texture_rect.rect_min_size.x = 12
			texture_rect.texture = replay_ok_texture
			replay.get_node("HBoxContainer").add_child(texture_rect)
			replay.get_node("HBoxContainer/VersionLabel").rect_min_size.x -= 13
			replay.get_node("HBoxContainer/VersionLabel").rect_size.x -= 13
			if invalid_characters.size() != 0:
				texture_rect.texture = replay_bad_texture
				texture_rect.hint_tooltip = "This replay requires the following characters:\n"
				var formatted_char_names = PoolStringArray()
				for invalid_char in invalid_characters:
					formatted_char_names.append(_format_character_name(invalid_char))
				texture_rect.hint_tooltip += formatted_char_names.join(", ")
				replay.button.disabled = true
				continue
			if version_match:
				texture_rect.texture = replay_ok_texture
				texture_rect.hint_tooltip = "This replay should be good to play."
			else:
				texture_rect.texture = replay_warn_texture
				texture_rect.hint_tooltip = "This replay is using a different version than the current one.\nYou may have desyncronization issues when playing this replay."
	
	if search_bar.text != "":
		_on_search_update(search_bar.text)
