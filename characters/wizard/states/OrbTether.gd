extends WizardState

const TETHER_LINE_SCENE = preload("res://characters/wizard/states/OrbTetherLine.gd")

func is_usable():
	return .is_usable() and host.orb_projectile and (host.is_grounded() or host.air_movements_left > 0) and host.tether_ticks == 0

func _frame_0():
	if !host.is_grounded() and !host.infinite_resources:
		host.air_movements_left -= 1
#	interruptible_on_opponent_turn = false
#	host.move_directly(0, -1)
#	host.set_grounded(false)
	host.tether_ticks = host.TETHER_TICKS
	_spawn_tether_line()

func _spawn_tether_line():
	# Don't double-spawn during resim — the existing line node is recreated
	# along with the rest of the fx layer when the prediction reseats.
	if ReplayManager.resimulating:
		return
	var orb = host.objs_map.get(host.orb_projectile) if host.orb_projectile else null
	if orb == null:
		return
	# Walk up from host to find the owning game (real or ghost) — same trick
	# GasBomb uses to register its trail with whichever game it's in, so
	# prediction lines tick from the ghost game's process_fx.
	var game = host.get_parent()
	while game and not game.has_method("process_fx"):
		game = game.get_parent()
	if game == null:
		return
	var line = TETHER_LINE_SCENE.new()
	line.wizard = host
	line.orb = orb
	game.fx_node.add_child(line)
	game.effects.append(line)
	line.connect("tree_exited", game, "_on_fx_exit_tree", [line])

func _tick():
	if current_tick > 8 and started_in_air:
		if host.is_grounded():
			return "Landing"

