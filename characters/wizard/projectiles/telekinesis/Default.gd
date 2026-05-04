extends ObjectState

const OFFSET_X = 0
const OFFSET_Y = -48
const LERP_VALUE = "0.18"
const Y_FORCE = "-12.0"
const DI_OFFSET_MAGNITUDE = "40"
const VERTICAL_SOFTCAP = "20"
const DOWN_SOFTCAP_MOD = "0.4"
const UP_SOFTCAP_MOD = "0.2"
var saved_di_x = 0
var saved_di_y = 0
#var start_x = 0
#var start_y = 0

func _enter():
	var pos = host.get_pos()
	host.set_facing(1)
#	start_x = pos.x
#	start_y = pos.y
#	host.apply_force("0", Y_FORCE)

func _tick():
	if host.creator:
		var pos = host.get_pos()
		var creator_pos = host.creator.get_pos()
		var target_pos = {
			x = creator_pos.x + OFFSET_X * host.creator.get_facing_int(),
			y = creator_pos.y + OFFSET_Y
		}

		var di = host.creator.current_di
		
		if host.creator.current_state().name == "Launch":
			di = {
				x = saved_di_x,
				y = saved_di_y,
			}
		
		saved_di_x = di.x
		saved_di_y = di.y

		var di_offset = xy_to_dir(di.x, di.y, DI_OFFSET_MAGNITUDE)

		
		if host.creator.is_grounded() and fixed.gt(di_offset.y, VERTICAL_SOFTCAP):
			di_offset.y = fixed.add(VERTICAL_SOFTCAP, fixed.mul(fixed.sub(di_offset.y, VERTICAL_SOFTCAP), DOWN_SOFTCAP_MOD))
		if fixed.lt(di_offset.y, "-" + VERTICAL_SOFTCAP):
			di_offset.y = fixed.add("-" + VERTICAL_SOFTCAP, fixed.mul(fixed.add(di_offset.y, VERTICAL_SOFTCAP), UP_SOFTCAP_MOD))
		di_offset.x = fixed.mul(di_offset.x, "1.2")
		
		if fixed.sign(di_offset.x) == host.creator.get_opponent_dir():
			di_offset.x = fixed.mul(di_offset.x, "0.75")
		
		target_pos = fixed.vec_add(str(target_pos.x), str(target_pos.y), di_offset.x, di_offset.y)

		var new_p_x = fixed.round(fixed.lerp_string(str(pos.x), target_pos.x, LERP_VALUE))
		var new_p_y = fixed.round(fixed.lerp_string(str(pos.y), target_pos.y, LERP_VALUE))
		host.set_pos(new_p_x, new_p_y)
	pass

func drop():
	queue_state_change("Drop")

func _frame_150():
	drop()
