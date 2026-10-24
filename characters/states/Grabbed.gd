extends CharacterState

# Safety net: let go if nothing has been holding us for this long. A throw that
# loses track of its victim otherwise leaves them Grabbed and invulnerable forever.
const UNHELD_RELEASE_TICKS = 45
var unheld_ticks = 0

func _ready():
	is_hurt_state = true

func _enter():
	unheld_ticks = 0
	host.set_snap_to_ground(false)
	host.colliding_with_opponent = false
	host.opponent.colliding_with_opponent = false
	host.on_grabbed()
	host.start_invulnerability()
	var opponent = host.opponent
	if opponent \
		and opponent.current_state().state_name == "Grabbed" \
		and opponent.opponent == host:
		queue_state_change("Wait")
		opponent.current_state().queue_state_change("Wait")

func _exit():
	host.set_snap_to_ground(true)

func _tick():
	if _is_held():
		unheld_ticks = 0
		return
	unheld_ticks += 1
	if unheld_ticks >= UNHELD_RELEASE_TICKS:
		if !host.is_ghost:
			print("Grabbed: nobody holding player %d for %d ticks, releasing" % [host.id, unheld_ticks])
		host.end_invulnerability()
		return "Wait" if host.is_grounded() else "Fall"

func _is_held():
	if host.hitlag_ticks > 0:
		return true
	for p in host.get_game().players.values():
		if p == host or p.game_over:
			continue
		var st = p.current_state()
		if st == null:
			continue
		if st is ThrowState and st.get_targets().has(host.id):
			return true
		# Cowboy's lasso combo (reel/pull, teleport out of it) holds via lasso_targets.
		if "lasso_targets" in p and p.lasso_targets.has(host) and (st.state_name.begins_with("Lasso") or st.state_name == "Teleport" or st.state_name == "IzunaDrop"):
			return true
		# A grab that connected but hasn't switched to its throw state yet.
		if !p.state_interruptable and (st.state_name.find("Grab") != -1 or st.state_name.find("Throw") != -1):
			return true
	return false
