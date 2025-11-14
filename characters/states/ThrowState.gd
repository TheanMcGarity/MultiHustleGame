extends CharacterState

class_name ThrowState

var released = false

export var _c_Throw_Data = 0
export var release = false
export var release_frame = -1
export var use_start_throw_pos = true
export var start_throw_pos_x = 0
export var start_throw_pos_y = 0
export var use_release_throw_pos = true
export var release_throw_pos_x = 0
export var release_throw_pos_y = 0

export var _c_Release_Data = 0
export var hitstun_ticks: int = 0
export var knockback: String = "1.0"
export var dir_x: String = "1.0"
export var dir_y: String = "0.0"
export var knockdown: bool = true
export var knockdown_extends_hitstun: bool = true
export var aerial_hit_state = "HurtAerial"
export var grounded_hit_state = "HurtGrounded"
export var damage = 10
export var damage_in_combo = -1
export var reverse = false
export var disable_collision = true
export var ground_bounce = true
export var screenshake_amount = 0
export var screenshake_frames = 0
export var hits_otg = false
export var increment_combo = true
export var hard_knockdown = false
export var force_grounded = false
export var air_ground_bounce = false
export var wall_slam = false
export var di_modifier = "1.0"
export var minimum_grounded_frames = -1
export var damage_proration = 0

export(Hitbox.HitHeight) var hit_height = Hitbox.HitHeight.Mid
export var _c_Release_Sound = 0
export(AudioStream) var release_sfx = null
export var release_sfx_volume = -10.0
export var play_release_sfx_bass = true

export(String, MULTILINE) var misc_data = ""

var hitlag_ticks = 0
var victim_hitlag = 0
var throw = true
var release_sfx_player = null

var team: int = 0
var hit_opponents := []
var grabbed_targets: Array = []
var primary_target = null
var previous_opponent = null
var grabbed_ids: Array = []

func _enter():
	released = false

func setup_audio():
	.setup_audio()
	if release_sfx:
		release_sfx_player = VariableSound2D.new()
		add_child(release_sfx_player)
		release_sfx_player.bus = "Fx"
		release_sfx_player.stream = release_sfx
		release_sfx_player.volume_db = release_sfx_volume

func update_throw_position():
	var frame = host.get_current_sprite_frame()
	if frame in throw_positions:
		var pos = throw_positions[frame]
		host.throw_pos_x = pos.x
		host.throw_pos_y = pos.y
	elif frame in host.throw_positions:
		var pos = host.throw_positions[frame]
		host.throw_pos_x = pos.x
		host.throw_pos_y = pos.y

func _get_host_game():
	var node = host
	while node:
		if "Game" in node.name:
			return node
		node = node.get_parent()
	return Network.game

func _update_primary_target(target):
	if not _is_valid_target(target):
		return
	if host.opponent != target:
		if previous_opponent == null:
			previous_opponent = host.opponent
		host.opponent = target
	primary_target = target

func _enter_shared():
	#var label = "[ThrowState %s]" % ("Ghost" if host.is_ghost else "Main")
	#print("%s entering %s" % [label, name])
	var next_state = ._enter_shared()
	#_gather_initial_targets()
	#_ensure_throw_target()
	#_force_targets_grabbed()
	return next_state

func _frame_0_shared():
	_ensure_throw_target()
	#host.opponent.change_state("Grabbed")
	if use_start_throw_pos:
		host.throw_pos_x = start_throw_pos_x
		host.throw_pos_y = start_throw_pos_y
	else:
		update_throw_position()
	var throw_pos = host.get_global_throw_pos()
	#host.opponent.set_pos(throw_pos.x, throw_pos.y)
	_force_targets_grabbed()
	_align_secondary_targets()

func _tick_shared():
	_ensure_throw_target()
	if current_tick == 0:
		throw = true
		if reverse and !force_same_direction_as_previous_state:
			host.reverse_state = false
			host.set_facing(-host.get_facing_int())
		host.start_invulnerability()
		released = false
	._tick_shared()
	if !released and release and current_tick + 1 == release_frame:
		if (!host.is_ghost):
			print("release")
		_release()
		released = true
	if !released:
		host.opponent.colliding_with_opponent = false
		host.colliding_with_opponent = false
	update_throw_position()
	_update_secondary_collisions()

func _tick_after():
	_ensure_throw_target()
	._tick_after()
	if !released:
		host.update_data()
		var throw_pos = host.get_global_throw_pos()
		host.opponent.set_pos(throw_pos.x, throw_pos.y)
	_align_secondary_targets()

func _exit_shared():
	._exit_shared()
	#_restore_original_opponent()

func _on_hit_something(obj, hitbox):
	if obj and obj.is_in_group("Fighter"):
		_add_grabbed_target(obj)
		_update_primary_target(obj)
	._on_hit_something(obj, hitbox)

func _release():
	throw = false
	var pos = _prepare_release_position()
	if not _apply_release_to_targets(pos):
		_apply_release_to_target(host.opponent, pos)
	if screenshake_amount > 0 and screenshake_frames > 0 and !host.is_ghost:
		var camera = get_tree().get_nodes_in_group("Camera")[0]
		camera.bump(Vector2(), screenshake_amount, screenshake_frames / 60.0)
	if release_sfx and !ReplayManager.resimulating:
		release_sfx_player.play()
	if play_release_sfx_bass:
		host.play_sound("HitBass")

func _prepare_release_position():
	if use_release_throw_pos:
		host.throw_pos_x = release_throw_pos_x
		host.throw_pos_y = release_throw_pos_y
	else:
		update_throw_position()
	var throw_pos = host.get_global_throw_pos()
	if throw_pos is Vector2:
		return throw_pos
	if throw_pos:
		return Vector2(throw_pos.x, throw_pos.y)
	var host_pos = host.get_pos()
	return Vector2(host_pos.x, host_pos.y)

func _apply_release_to_targets(pos: Vector2) -> bool:
	var applied = false
	for target in _gather_release_targets():
		if _apply_release_to_target(target, pos):
			applied = true
			_log_grabbed_targets("apply_release", target, false)
	return applied

func _gather_release_targets() -> Array:
	var targets := []
	for target in grabbed_targets:
		if _is_valid_target(target):
			targets.append(target)
	return targets

func _apply_release_to_target(target, pos: Vector2) -> bool:
	if not _is_valid_target(target):
		return false
	var original_opponent = target.opponent
	target.set_pos(int(pos.x), int(pos.y))
	target.update_facing()
	var throw_data = HitboxData.new(self)
	target.hit_by(throw_data, true)
	if target.current_state().state_name == "Grabbed":
		_force_post_release_state(target, throw_data)
	if target.opponent != original_opponent:
		target.opponent = original_opponent
	return true

func _force_post_release_state(target, hitbox):
	var next_state = grounded_hit_state if target.is_grounded() else aerial_hit_state
	target.colliding_with_opponent = false
	target.state_machine._change_state(next_state, {"hitbox": hitbox})

func _gather_initial_targets():
	#grabbed_targets.clear()
	_load_targets_from_data()
	_merge_targets_from_game()
	#if grabbed_targets.empty() and _is_valid_target(host.opponent) and host.opponent.current_state().state_name == "Grabbed":
	#	_add_grabbed_target(host.opponent, false, false)

func _merge_targets_from_game():
	for target in _lookup_targets_from_game():
		_add_grabbed_target(target)
	for target in _lookup_targets_from_world():
		_add_grabbed_target(target)

func _ensure_throw_target():
	#_merge_targets_from_game()
	_prune_invalid_targets()
	#var target = _pick_throw_target()
	#if target:
	#	_update_primary_target(target)
	#	_add_grabbed_target(target)
	return# target

func _pick_throw_target():
	var from_list = _first_valid_from(grabbed_targets)
	if from_list:
		return from_list
	var last_hit_target = _resolve_last_hit_target()
	if last_hit_target:
		return last_hit_target
	var cached_target = _resolve_cached_target()
	if cached_target:
		return cached_target
	if _is_valid_target(host.opponent) and host.opponent.current_state().state_name == "Grabbed":
		return host.opponent
	return null

func _resolve_last_hit_target():
	var obj_name = host.last_object_hit
	if obj_name is String and obj_name != "":
		var obj = host.obj_from_name(obj_name)
		if _is_valid_target(obj):
			_add_grabbed_target(obj)
			return obj
	return null

func _resolve_cached_target():
	for i in range(hit_opponents.size() - 1, -1, -1):
		var candidate = hit_opponents[i]
		if _is_valid_target(candidate):
			return candidate
		hit_opponents.remove(i)
	return null

func _add_grabbed_target(target, prioritize := true, persist := true, force_align := true):
	if not _is_valid_target(target):
		return
	var already = grabbed_targets.has(target)
	if prioritize:
		if already:
			grabbed_targets.erase(target)
		grabbed_targets.insert(0, target)
	elif not already:
		grabbed_targets.append(target)
	_sync_grabbed_target(target, not already, persist, force_align)
	_log_grabbed_targets("add_grabbed_target", target, not already)

func _sync_grabbed_target(target, newly_added: bool, persist: bool, force_align: bool):
	if not _is_valid_target(target):
		return
	if newly_added:
		_cache_hit_target(target)
		if persist:
			_remember_target_id(target)
		_register_target_with_game(target)
	if force_align and not released:
		if target.opponent != host:
			target.opponent = host
		_force_single_target_grabbed(target)
		if target != host.opponent:
			_position_secondary_target(target)

func _cache_hit_target(target):
	if target and not hit_opponents.has(target):
		hit_opponents.append(target)

func _lookup_targets_from_game():
	var results = []
	var game = _get_host_game()
	if game == null:
		return results
	if not game.players_getting_throwed.has(host.id):
		return results
	for target_id in game.players_getting_throwed[host.id]:
		if game.players.has(target_id):
			var player = game.players[target_id]
			if _is_valid_target(player):
				results.append(player)
	return results

func _lookup_targets_from_world():
	var results = []
	var game = _get_host_game()
	if game == null:
		return results
	var allowed_ids = []
	if game.players_getting_throwed.has(host.id):
		allowed_ids = game.players_getting_throwed[host.id].duplicate()
	if grabbed_ids:
		for target_id in grabbed_ids:
			if not allowed_ids.has(target_id):
				allowed_ids.append(target_id)
	if allowed_ids.empty():
		return results
	for target_id in allowed_ids:
		if not game.players.has(target_id):
			continue
		var player = game.players[target_id]
		if not _is_valid_target(player):
			continue
		if player.current_state().state_name != "Grabbed":
			continue
		if player.opponent != host:
			continue
		results.append(player)
	if not results.empty():
		return results
	for player in game.players.values():
		if not _is_valid_target(player):
			continue
		if player.current_state().state_name != "Grabbed":
			continue
		if player.opponent != host:
			continue
		if grabbed_ids and player.get("id") != null and not grabbed_ids.has(player.id):
			grabbed_ids.append(player.id)
		results.append(player)
	return results

func _force_targets_grabbed():
	if released:
		return
	for target in grabbed_targets:
		_force_single_target_grabbed(target)

func _force_single_target_grabbed(target):
	if not _is_valid_target(target):
		return
	if target.current_state().state_name != "Grabbed":
		target.change_state("Grabbed")
	target.colliding_with_opponent = false

func _align_secondary_targets():
	if released or grabbed_targets.empty():
		return
	for target in grabbed_targets:
		if target == host.opponent:
			continue
		_force_single_target_grabbed(target)
		_position_secondary_target(target)
		_log_grabbed_targets("align_secondary_targets", target, false)

func _update_secondary_collisions():
	if released:
		return
	for target in grabbed_targets:
		if _is_valid_target(target):
			target.colliding_with_opponent = false

func _prune_invalid_targets():
	for i in range(grabbed_targets.size() - 1, -1, -1):
		if not _is_valid_target(grabbed_targets[i]):
			grabbed_targets.remove(i)

func _first_valid_from(list):
	for entry in list:
		if _is_valid_target(entry):
			return entry
	return null

func _is_valid_target(target):
	return target \
		and is_instance_valid(target) \
		and not target.disabled \
		and target != host \
		and target.is_in_group("Fighter")

func _load_targets_from_data():
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return
	if not data.has("grabbed_ids"):
		return
	var stored = data["grabbed_ids"]
	if typeof(stored) != TYPE_ARRAY:
		return
	grabbed_ids = stored.duplicate()
	var game = _get_host_game()
	if game == null:
		return
	for id in grabbed_ids:
		if not game.players.has(id):
			continue
		var player = game.players[id]
		if _is_valid_target(player):
			_add_grabbed_target(player, false, false)

func _remember_target_id(target):
	if target == null or target.get("id") == null:
		return
	var id = target.id
	if grabbed_ids.has(id):
		return
	grabbed_ids.append(id)
	_store_grabbed_ids()

func _store_grabbed_ids():
	if data == null:
		data = {}
	if typeof(data) != TYPE_DICTIONARY:
		return
	data["grabbed_ids"] = grabbed_ids.duplicate()

func _restore_original_opponent():
	if not released:
		_release_unfinished_targets()
	if previous_opponent and host.opponent == primary_target:
		host.opponent = previous_opponent
	var game = _get_host_game()
	if game and game.players_getting_throwed.has(host.id):
		game.players_getting_throwed.erase(host.id)
	previous_opponent = null
	primary_target = null
	#grabbed_targets.clear()
	hit_opponents.clear()
	grabbed_ids.clear()

func _copy_to(state):
	._copy_to(state)
	state.grabbed_ids = grabbed_ids.duplicate()
	if grabbed_ids.size() > 0:
		if state.data == null:
			state.data = {}
		state.data["grabbed_ids"] = grabbed_ids.duplicate()

func _release_unfinished_targets():
	var release_pos = host.get_global_throw_pos()
	var pos_vec = Vector2()
	if release_pos is Vector2:
		pos_vec = release_pos
	elif release_pos:
		pos_vec = Vector2(release_pos.x, release_pos.y)
	else:
		var host_pos = host.get_pos()
		pos_vec = Vector2(host_pos.x, host_pos.y)
	for target in grabbed_targets:
		if not _is_valid_target(target):
			continue
		if target.current_state().state_name == "Grabbed":
			target.set_pos(pos_vec.x, pos_vec.y)
			target.update_facing()
			target.change_state("Wait" if target.is_grounded() else "Fall")
		target.colliding_with_opponent = true

func _position_secondary_target(target):
	if not _is_valid_target(target):
		return
	var pos = host.get_global_throw_pos()
	if pos is Vector2:
		target.set_pos(pos.x, pos.y)
	elif pos:
		target.set_pos(pos.x, pos.y)
	else:
		var host_pos = host.get_pos()
		target.set_pos(host_pos.x, host_pos.y)
	target.update_facing()

func _register_target_with_game(target):
	var game = _get_host_game()
	if game == null or target == null or target.get("id") == null:
		return
	if game.has_method("_thrower_has_target") and game._thrower_has_target(host, target):
		return
	if game.has_method("consume_throw_by"):
		game.consume_throw_by(host, target, false)
	elif game.has_method("_register_players_getting_throwed"):
		game._register_players_getting_throwed(host, target)
	_log_grabbed_targets("register_target_game", target, true)
	_log_registered_targets(game, "register_target_game_post")

func _log_grabbed_targets(context: String, focus_target, newly_added: bool):
	#return
	var target_name = focus_target.name if focus_target and focus_target.get("name") else "[unknown]"
	var names = []
	for entry in grabbed_targets:
		if entry and entry.get("name"):
			names.append(entry.name)
		else:
			names.append("[unknown]")
	push_warning("[ThrowState %s] context=%s target=%s new=%s targets=%s state=%s" % [
		"Ghost" if host and host.is_ghost else "Main",
		context,
		target_name,
		str(newly_added),
		names,
		name,
	])

func _log_target_source(context: String, targets: Array):
	return
	var names = []
	for entry in targets:
		if entry and entry.get("name"):
			names.append(entry.name)
		else:
			names.append("[unknown]")
	print("[ThrowState %s] context=%s game_targets=%s" % [
		"Ghost" if host and host.is_ghost else "Main",
		context,
		names
	])

func _log_registered_targets(game, context: String):
	return
	if host == null or game == null:
		return
	var thrower_id = host.id
	var target_ids = game.players_getting_throwed.get(thrower_id, [])
	print("[ThrowState %s] context=%s thrower=%s registered_ids=%s" % [
		"Ghost" if host and host.is_ghost else "Main",
		context,
		str(thrower_id),
		str(target_ids)
	])

func _log_debug(context: String, detail: String, target):
	return
	var tag = "Ghost" if host and host.is_ghost else "Main"
	var target_name = target.name if target and target.get("name") else "[none]"
	print("[ThrowState %s] context=%s detail=%s host=%s grabbed=%s hit=%s target=%s" % [
		tag,
		context,
		detail,
		host.name if host and host.get("name") else "[unknown]",
		str(grabbed_targets.size()),
		str(hit_opponents.size()),
		target_name
	])

func _log_pick_source(source: String, target):
	_log_debug("pick_target", source, target)
