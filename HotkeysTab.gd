extends Control

var rebinding_action = ""
var rebind_buttons = {}
var confirm_dialog: ConfirmationDialog

func _ready():
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "reset all hotkeys to defaults?"
	confirm_dialog.window_title = "reset hotkeys"
	confirm_dialog.connect("confirmed", Hotkeys, "reset_to_defaults")
	add_child(confirm_dialog)
	build_list()
	Hotkeys.connect("binding_changed", self, "_on_binding_changed")

func build_list():
	var list = $"%HotkeysList"
	for child in list.get_children():
		child.queue_free()
	rebind_buttons.clear()
	for entry in Hotkeys.REBINDABLE:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label = Label.new()
		label.text = entry.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var btn = Button.new()
		btn.rect_min_size = Vector2(80, 0)
		btn.text = _button_text_for(entry.action)
		btn.connect("pressed", self, "_start_rebind", [entry.action])
		row.add_child(btn)
		rebind_buttons[entry.action] = btn
		list.add_child(row)
	var reset_btn = Button.new()
	reset_btn.text = "reset to defaults"
	reset_btn.connect("pressed", confirm_dialog, "popup_centered")
	list.add_child(reset_btn)

func _button_text_for(action: String) -> String:
	if rebinding_action == action:
		return "press a key..."
	var key_name = Hotkeys.get_display_name(action)
	return key_name if key_name != "" else "(unbound)"

func _start_rebind(action: String):
	var previous = rebinding_action
	rebinding_action = "" if previous == action else action
	if previous != "":
		_refresh_button(previous)
	if rebinding_action != "":
		_refresh_button(rebinding_action)

func _refresh_button(action: String):
	if action in rebind_buttons:
		rebind_buttons[action].text = _button_text_for(action)

func _input(event):
	if rebinding_action == "":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_tree().set_input_as_handled()
	var code = event.scancode if event.scancode != 0 else event.physical_scancode
	var action = rebinding_action
	rebinding_action = ""
	if code == KEY_ESCAPE:
		Hotkeys.clear_binding(action)
	else:
		var ok = Hotkeys.rebind(action, code)
		if not ok:
			# protected key - just refresh, leave binding as-is
			_refresh_button(action)

func _on_binding_changed(action):
	_refresh_button(action)
