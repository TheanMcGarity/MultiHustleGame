extends BaseProjectile

const TRAIL_SCENE = preload("res://characters/mutant/projectiles/GasBombTrail.tscn")
var trail_spawned = false

func init(pos=null):
	.init(pos)
	# Spawn the trailing line once per bomb. Both real and ghost bombs get
	# one so the line shows up in prediction too — each lives in its own
	# game's fx_node and gets ticked by that game's process_fx, so pauses
	# freeze the trail along with the rest of the sim.
	if trail_spawned or ReplayManager.resimulating:
		return
	trail_spawned = true
	var trail = TRAIL_SCENE.instance()
	trail.target = self
	# Seed with the bomb's spawn position so the first segment doesn't start
	# at (0, 0) before the trail's first tick has run.
	trail.positions.append(get_pos_visual())
	# Walk up to the owning Game (real or ghost) — its fx_node is the right
	# parent and its `effects` array is what process_fx iterates each tick.
	var bomb_game = get_parent().get_parent() if get_parent() else null
	if bomb_game and bomb_game.has_method("process_fx"):
		bomb_game.fx_node.add_child(trail)
		bomb_game.effects.append(trail)
		trail.connect("tree_exited", bomb_game, "_on_fx_exit_tree", [trail])
	else:
		get_parent().add_child(trail)
