extends "res://SoupModOptions/OptionTypes/ModOptionObject.gd"

# SoupModOptions 1.2 ships persistent values but no push-button option type.
# This adapter uses its normal option container while opting out of schemas
# and saving, so destructive maintenance commands are explicit one-click
# actions instead of fake booleans.
var target = null
var method_name = ""
var method_args = []
var btn = null


func configure(callback_target, callback_method, callback_args = []):
	target = callback_target
	method_name = callback_method
	method_args = callback_args


func _build():
	ignore = true
	btn = Button.new()
	btn.text = display_name
	btn.mouse_filter = MOUSE_FILTER_PASS
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(btn)
	btn.connect("pressed", self, "_pressed")


func _pressed():
	if target != null and is_instance_valid(target) and method_name != "" and target.has_method(method_name):
		target.callv(method_name, method_args)
