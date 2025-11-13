extends "res://SoupModOptions/ModOptions.gd"

func _ready():
	var replayplus = get_tree().get_root().get_node("ModLoader/ReplayPlus")
	var my_menu = generate_menu("ReplayPlus", replayplus.MOD_NAME)
	my_menu.add_bool("compat_icons", "Show Replay Compatibility Icons", true)
	my_menu.add_label("lbl1", "If you have a large amount of replays and experience issues when opening the replay list, you can disable this to stop reading replays.", Label.ALIGN_CENTER, Color.gray)
	add_menu(my_menu)

func _ReplayPlus_late_init(menu):
	pass
