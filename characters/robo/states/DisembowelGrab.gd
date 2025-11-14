extends RobotState

onready var hitbox = $Hitbox
onready var hitbox_2 = $Hitbox2
onready var hitbox_3 = $Hitbox3
onready var hitbox_4 = $Hitbox4

var queued_trycatch_targets:Array = []
var trycatch_state:Dictionary = {}
var trycatch_connected = false

var grabbed_ids # idk why it just threw an error on a line where it had just been assigning this value 2 lines before that this var isnt there

func _frame_0():
	var target_state = "DisembowelGrabFollowup" if !data else "TryCatchGroundSlam"
	#._frame_0()
	for h in [hitbox, hitbox_2, hitbox_3, hitbox_4]:
		if h == null:
			continue
		if not h.throw:
			h.throw = true
		#h.throw_state = target_state
		#h.followup_state = target_state

func _enter():
	queued_trycatch_targets.clear()
	_connect_trycatch_state()
	return ._enter()

func _on_hit_something(obj, hitbox):
	var next = "DisembowelGrabFollowup" if !data else "TryCatchGroundSlam"
	host.state_machine._change_state(next, data)
	trycatch_state[next]._on_hit_something(obj, hitbox)
	if _should_track_trycatch_target(obj, hitbox):
		_queue_trycatch_target(obj)
	._on_hit_something(obj, hitbox)


func _connect_trycatch_state():
	if trycatch_connected:
		return
	trycatch_state.clear()
	trycatch_state["TryCatchGroundSlam"] = _get_trycatch_slam_state()
	trycatch_state["DisembowelGrabFollowup"] = _get_trycatch_follow_state()
	if trycatch_state["TryCatchGroundSlam"] == null or trycatch_state["DisembowelGrabFollowup"] == null:
		return
	trycatch_state["TryCatchGroundSlam"].connect("state_started", self, "_on_trycatch_slam_started")
	trycatch_state["DisembowelGrabFollowup"].connect("state_started", self, "_on_trycatch_follow_started")
	trycatch_connected = true

func _disconnect_trycatch_state():
	if not trycatch_connected:
		return
	for state_key in trycatch_state.keys():
		var state = trycatch_state[state_key]
		if not is_instance_valid(state):
			continue
		var method = "_on_trycatch_slam_started" if state_key == "TryCatchGroundSlam" else "_on_trycatch_follow_started"
		if state.is_connected("state_started", self, method):
			state.disconnect("state_started", self, method)
	trycatch_connected = false
	trycatch_state.clear()

func _get_trycatch_slam_state():
	if host == null or host.state_machine == null:
		return null
	return host.state_machine.states_map.get("TryCatchGroundSlam", null)
func _get_trycatch_follow_state():
	if host == null or host.state_machine == null:
		return null
	return host.state_machine.states_map.get("DisembowelGrabFollowup", null)

func _on_trycatch_slam_started():
	var state = trycatch_state.get("TryCatchGroundSlam")
	if state == null:
		state = _get_trycatch_slam_state()
	if state:
		trycatch_state["TryCatchGroundSlam"] = state
	_apply_all_trycatch_overrides(state)

func _on_trycatch_follow_started():
	var state = trycatch_state.get("DisembowelGrabFollowup")
	if state == null:
		state = _get_trycatch_follow_state()
	if state:
		trycatch_state["DisembowelGrabFollowup"] = state
	_apply_all_trycatch_overrides(state)

func _apply_all_trycatch_overrides(state):
	if queued_trycatch_targets.empty():
		return
	if state == null:
		return
	for target in queued_trycatch_targets:
		_apply_trycatch_overrides(state, target)
	queued_trycatch_targets.clear()
	_disconnect_trycatch_state()

func _queue_trycatch_target(target):
	if target == null or not target.is_in_group("Fighter"):
		return
	if _apply_trycatch_to_active_state(target):
		return
	if queued_trycatch_targets.has(target):
		return
	queued_trycatch_targets.append(target)

func _apply_trycatch_to_active_state(target) -> bool:
	if host == null:
		return false
	var current_state = host.current_state()
	if current_state == null:
		return false
	var state_name = current_state.state_name
	if state_name != "DisembowelGrabFollowup" and state_name != "TryCatchGroundSlam":
		return false
	var state = trycatch_state.get(state_name)
	if state == null:
		state = _get_trycatch_follow_state() if state_name == "DisembowelGrabFollowup" else _get_trycatch_slam_state()
		if state == null:
			return false
		trycatch_state[state_name] = state
	_apply_trycatch_overrides(state, target)
	return true

func _apply_trycatch_overrides(trycatch_state_ref, target):
	if target == null or not target.is_in_group("Fighter"):
		return
	trycatch_state_ref._add_grabbed_target(target, false, true)
	if target.get("id") != null and not trycatch_state_ref.grabbed_ids.has(target.id):
		trycatch_state_ref.grabbed_ids.append(target.id)
		if trycatch_state_ref.data == null:
			trycatch_state_ref.data = {}
		trycatch_state_ref.data["grabbed_ids"] = trycatch_state_ref.grabbed_ids.duplicate()
	var primary_set = trycatch_state_ref.primary_target != null
	if not primary_set:
		trycatch_state_ref.primary_target = target
		if trycatch_state_ref.previous_opponent == null:
			trycatch_state_ref.previous_opponent = trycatch_state_ref.host.opponent
		trycatch_state_ref.host.opponent = target

func _should_track_trycatch_target(obj, hitbox):
	if obj == null or hitbox == null:
		return false
	if not obj.is_in_group("Fighter"):
		return false
	return true#hitbox.followup_state in ["TryCatchGroundSlam", "DisembowelGrabFollowup"]
