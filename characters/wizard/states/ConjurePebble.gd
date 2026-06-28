extends SuperMove

const BOULDERS = [
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBoulder.tscn"),
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBoulder2.tscn"), 
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBoulder.tscn"),
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBoulder2.tscn"), 
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBoulder3.tscn"),
]

# Parallel arrays — same scenes and weights as the old dict, but order is
# guaranteed across ghost / replay / live sims. Dict-of-PackedScene-keys
# fed `.keys()` / `.values()` to `randi_weighted_choice` and the picked
# index resolved to the wrong scene whenever those two iterations didn't
# agree (showed up as replays/prediction spawning the wrong telekinesis
# variant once ice was added). Keep these two arrays in lockstep.
const SILLY_ITEMS = [
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisPebble.tscn"),
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBomb.tscn"),
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisTire.tscn"),
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisFruit.tscn"),
	preload("res://characters/wizard/projectiles/telekinesis/TelekinesisIce.tscn"),
]
const SILLY_ITEM_WEIGHTS = [3, 3, 5, 3, 3]

const NON_BOULDER_CHANCE = 15

func _frame_0():
	pass

func _frame_1():
	projectile_scene = host.randi_choice(BOULDERS)
	if host.randi_percent(NON_BOULDER_CHANCE):
#	if host.randi_percent(100):
		projectile_scene = host.randi_weighted_choice(SILLY_ITEMS, SILLY_ITEM_WEIGHTS)
	if host.should_hide_rng():
		projectile_scene = preload("res://characters/wizard/projectiles/telekinesis/TelekinesisBoulderGhost.tscn")

func _frame_4():
	host.play_sound("HitBass")

func process_projectile(obj):
	host.hover_left -= host.TK_HOVER_AMOUNT
	host.boulder_projectile = obj.obj_name

func is_usable():
	return .is_usable() and host.boulder_projectile == null and host.hover_left >= host.TK_HOVER_AMOUNT
