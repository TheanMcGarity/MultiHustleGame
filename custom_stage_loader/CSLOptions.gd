extends "res://SoupModOptions/ModOptions.gd"

var _csl_stage_select;
var _csl_rstages;
var _csl_menu;

class CSLTitle:
	extends HBoxContainer
	const ignore = true
	const DISCORD_URL = "https://discord.gg/keTcqpUQVG"
	const DOCS_URL = "https://hazelpy.github.io/Custom-Stage-Loader-Documentation/#/"
	func _ready():
		name = "CSLTitle"
		
		var btn = Button.new()
		btn.mouse_filter = MOUSE_FILTER_PASS
		btn.text = "CSL Discord"
		btn.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		btn.connect("pressed", OS, "shell_open", [DISCORD_URL])
		add_child(btn)
		
		var btn2 = Button.new()
		btn2.mouse_filter = MOUSE_FILTER_PASS
		btn2.text = "CSL Documentation"
		btn2.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		btn2.connect("pressed", OS, "shell_open", [DOCS_URL])
		add_child(btn2)

class CSLRandomStageSelection:
	extends "res://SoupModOptions/OptionTypes/ModOptionObject.gd"
	var options: PoolStringArray
	var option_icon_map: Dictionary
	var list_panel: PanelContainer
	var option_list: VBoxContainer
	var label: Label
	var btn_theme = load("res://theme.tres")
	var select_btn: CheckBox
	
	func _build():
		var vbox = VBoxContainer.new()
		vbox.name = "RSSContainer"
		add_child(vbox)
		
		var titlebar = PanelContainer.new()
		vbox.add_child(titlebar)
		titlebar.set_theme_type_variation("CategoryTitlebar")
		
		var button = CheckButton.new()
		titlebar.add_child(button)
		button.set_theme_type_variation("CategoryButton")
		button.text = display_name
		button.pressed = true
		
		list_panel = PanelContainer.new()
		vbox.add_child(list_panel)
		list_panel.name = "OptionsContainer"
		list_panel.set_theme_type_variation("CategoryOptions")
		option_list = VBoxContainer.new()
		list_panel.add_child(option_list)
		option_list.name = "OptionList"
		
		var hbox = HBoxContainer.new()
		option_list.add_child(hbox)
		
		select_btn = CheckBox.new()
		select_btn.mouse_filter = MOUSE_FILTER_PASS
		select_btn.theme = btn_theme
		select_btn.hint_tooltip = "Select All"
		select_btn.connect("toggled", self, "select_btn_checked")
		hbox.add_child(select_btn)
		
		label = Label.new()
		hbox.add_child(label)
		label.align = Label.ALIGN_CENTER
		label.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		
		button.connect("toggled", self, "category_toggled")
		
		_add_options()
	
	func category_toggled(value):
		list_panel.visible = value
	
	func _add_options(value: PoolStringArray = current_value):
		for child in option_list.get_children():
			if child.is_class("CheckBox"):
				child.disabled = true
				child.queue_free()
		for opt in options:
			var btn = CheckBox.new()
			btn.text = opt
			if value and opt in value: btn.pressed = true
			btn.mouse_filter = MOUSE_FILTER_PASS
			btn.theme = btn_theme
			if option_icon_map.has(opt):
				btn.icon = option_icon_map[opt]
			option_list.add_child(btn)
			btn.connect("toggled", self, "option_checked", [opt])
		update_label(value)
		update_select_btn(value)
	
	func update_label(value: PoolStringArray = current_value):
		var opts_checked = 0
		for opt in options:
			if value and opt in value:
				opts_checked += 1
		label.text = "%d stage%s selected.%s" % [opts_checked, "" if opts_checked == 1 else "s", "" if opts_checked != 0 else " All stages will be used."]
	
	func update_select_btn(value: PoolStringArray = current_value):
		var all_checked = value.size() != 0
		for opt in options:
			if value and not opt in value:
				all_checked = false
				break
		
		if all_checked:
			select_btn.set_pressed_no_signal(true)
			select_btn.hint_tooltip = "Unselect All"
		else:
			select_btn.set_pressed_no_signal(false)
			select_btn.hint_tooltip = "Select All"
	
	func select_btn_checked(check_all: bool):
		var new_value = PoolStringArray() if not check_all else PoolStringArray(options)
		current_value = new_value
		_add_options(new_value)
		emit_signal("option_changed", fullpath, new_value)
	
	func option_checked(value: bool, opt: String):
		var new_value = PoolStringArray(current_value)
		if value and not opt in new_value: new_value.append(opt)
		elif not value and opt in new_value:
			var idx = new_value.find(opt)
			if idx != -1: new_value.remove(idx)
		current_value = new_value
		update_label(new_value)
		update_select_btn(new_value)
		emit_signal("option_changed", fullpath, new_value)
	
	func set_value(value: PoolStringArray):
		current_value = value
		_add_options(value)
	
	func add_item(_name, _icon = null):
		options.append(_name)
		if _icon != null:
			option_icon_map[_name] = _icon
		_add_options()
		return self

class CSLClearCache:
	extends VBoxContainer
	const ignore = true
	var btn: Button
	var seconds_left: float = 0
	var pressed_once = false
	func _ready():
		name = "CSLClearCacheButton"
		
		btn = Button.new()
		btn.mouse_filter = MOUSE_FILTER_PASS
		btn.text = "Clear Stage Cache (Restart)"
		btn.hint_tooltip = "This will clear stage cache and will restart the game afterwards."
		btn.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		btn.connect("pressed", self, "_on_pressed")
		btn.add_color_override("font_color_focus", Color.red)
		btn.add_color_override("font_color", Color.red)
		btn.add_color_override("font_color_hover", Color("#ff3c3c"))
		btn.add_color_override("font_color_pressed", Color("#ff6e6e"))
		add_child(btn)
		
		var btn2 = Button.new()
		btn2.mouse_filter = MOUSE_FILTER_PASS
		btn2.text = "Open Stage Cache Folder"
		btn2.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		btn2.connect("pressed", OS, "shell_open", [ProjectSettings.globalize_path("user://csl")])
		add_child(btn2)
	
	func _on_pressed():
		if not pressed_once:
			pressed_once = true
			btn.text = "Are you sure?"
			seconds_left = 5.0
		else:
			pressed_once = false
			seconds_left = 0.0
			btn.text = "Restarting..."
			var dir = Directory.new()
			for file in ModLoader._get_all_files("user://csl", "pck") + ModLoader._get_all_files("user://csl", "md5"):
				dir.remove(file)
			if SteamHustle.STARTED: OS.shell_open("steam://run/2212330")
			get_tree().quit(0)
	
	func _process(delta):
		if pressed_once:
			seconds_left -= delta
			if seconds_left <= 0:
				pressed_once = false
				btn.text = "Clear Stage Cache (Restart)"

class CSLColorOption:
	extends "res://SoupModOptions/OptionTypes/ModOptionObject.gd"

	var label:Label
	var lineedit:LineEdit
	var colorrect:ColorRect

	func _build():
		var vsep = VBoxContainer.new()
		label = Label.new()
		lineedit = LineEdit.new()
		
		label.text = display_name
		lineedit.text = current_value
		
		vsep.add_child(label)
		add_child(vsep)
		
		var hsep = HBoxContainer.new()
		hsep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colorrect = ColorRect.new()
		colorrect.rect_min_size.x = 50
		lineedit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hsep.add_child(colorrect)
		hsep.add_child(lineedit)
		vsep.add_child(hsep)
		
		
		lineedit.connect("text_changed", self, "option_changed")
		
	func option_changed(value):
		current_value = value
		colorrect.color = Color(value)
		emit_signal("option_changed", fullpath, value)
		
	func set_value(value:String):
		current_value = value
		colorrect.color = Color(value)
		lineedit.text = value
		
	func get_value_for_save():
		return current_value

func _ready():
	_csl_menu = generate_menu("CustomStageLoader", "Custom Stage Loader")
	_csl_menu.add_label("---title", "Custom Stage Loader", Label.ALIGN_CENTER, Color.slategray)
	var csltitle = CSLTitle.new()
	_csl_menu._resolve_slash_path("CustomStageLoader").add_child(csltitle)
	_csl_menu.add_label("---separator", " ")
	
	_csl_menu.add_label("---opts", "Stage Config", Label.ALIGN_CENTER, Color.slategray)
	var lines = _csl_menu.add_bool("drawLines", "Draw Stage Lines", true)
	
	var pips = _csl_menu.add_bool("drawPips", "Draw Stage Pips", true)
	
	var _csl_colorline = _csl_menu._create_generic(CSLColorOption, "lines_hex_string", "Lines Color (HEX)", "#ffffff")
	_csl_menu._add_to_list("lines_hex_string", _csl_colorline)
	_csl_colorline.connect("option_changed", _csl_menu, "option_changed")

	_csl_menu.add_label("---separator2", " ")
	_csl_stage_select = _csl_menu.add_dropdown_menu("stageSelect", "Select Stage")
	_csl_menu.add_bool("randomStage", "Select Random Stage", false)
	
	_csl_rstages = _csl_menu._create_generic(CSLRandomStageSelection, "randomStageSelect", "Random Stage Selection", [])
	_csl_menu._add_to_list("randomStageSelect", _csl_rstages)
	_csl_rstages.connect("option_changed", _csl_menu, "option_changed")
	
	_csl_menu.add_label("---separator3", " ")
	var cc = CSLClearCache.new()
	_csl_menu._resolve_slash_path("CustomStageLoader").add_child(cc)
	
	add_menu(_csl_menu);

func _CustomStageLoader_late_init(menu):
	var Loader = get_tree().get_root().get_node("CSL")
	Loader.import_stage_icons()
	
	for stage in Loader.stages:
		var icon = null
		if stage.has("stage_icon") and stage.stage_icon != null:
			icon = load(stage.stage_icon)
			_csl_stage_select.add_icon_item(icon, stage.stage_name)
		else:
			_csl_stage_select.add_item(stage.stage_name)
		_csl_rstages.add_item(stage.stage_name, icon)
	_csl_stage_select.emit_signal("item_added")
