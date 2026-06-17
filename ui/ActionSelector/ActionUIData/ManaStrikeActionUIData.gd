extends ActionUIData

# Mana Strike: a Distance slider plus a "close" toggle. When close is on the
# strike is fixed to a set point (handled in ManaStrike.gd), so the distance
# slider is disabled. get_data stays flat ({x, close}) so the state keeps
# reading data["x"] as before.

onready var distance = $Distance
onready var close = $Close

func _ready():
	._ready()
	_update_slider_enabled()

func on_data_changed():
	_update_slider_enabled()
	.on_data_changed()

func _update_slider_enabled():
	if distance.has_method("set_disabled"):
		distance.set_disabled(close.pressed)

func get_data():
	return {
		"x": distance.get_data().x,
		"close": close.pressed,
	}
