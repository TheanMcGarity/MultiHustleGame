extends ObjectState

const LOCK_DISTANCE = "8"
const CHARACTER_LOCK_DISTANCE = "16"
# Hooks zip toward each other at up to SPEED+SPEED = 30 px/frame combined,
# which is well above LOCK_DISTANCE — without this, a head-on hook clash
# tunnels past the lock zone in one frame and they fly to opposite walls
# instead of grappling each other.
const HOOK_VS_HOOK_LOCK_DISTANCE = "16"

func _frame_0():
	host.play_sound("HookSound")

func _tick():
	host.update_rotation()
	host.apply_grav_custom(host.gravity, "1000000000000")
	host.apply_forces_no_limit()
	if host.is_grounded():
		lock()
	if Utils.int_abs(Utils.int_abs(host.get_pos().x) - host.stage_width) < 2:
		lock()
	# Cache the opponent's hook name (if any) so we can use a wider lock
	# range against it — fast head-on closure tunnels the standard threshold.
	var opp_hook_name = ""
	if host.creator and host.creator.opponent and "grappling_hook_projectile" in host.creator.opponent:
		var opp_hook = host.creator.opponent.grappling_hook_projectile
		if opp_hook:
			opp_hook_name = opp_hook
	for obj_name in host.objs_map:
		var obj = host.objs_map[obj_name]
		if obj != null:
			if !obj.disabled and obj != host and obj != host.creator:
				var obj_pos = host.obj_local_center(obj)
				var dist = fixed.vec_len(str(obj_pos.x), str(obj_pos.y))
				var lock_dist = LOCK_DISTANCE
				if obj.is_in_group("Fighter"):
					lock_dist = CHARACTER_LOCK_DISTANCE
				elif opp_hook_name != "" and obj.obj_name == opp_hook_name:
					lock_dist = HOOK_VS_HOOK_LOCK_DISTANCE
				if fixed.lt(dist, lock_dist):
					lock(obj)
					break

func _on_hit_something(obj, hitbox):
	lock(obj)

func _ready():
	pass

func lock(obj=null):
	queue_state_change("Locked")
	host.attached_to = obj.obj_name if obj else null
	host.is_locked = true
