extends SuperMove

export var end = false

const PROJECTILE_SCENE = preload("res://characters/swordandgun/projectiles/1000cuts/1000Cuts.tscn")

func _frame_0():
	if end:
		var obj = host.obj_from_name(host.cut_projectile)
		if obj:
			obj.disable()
		host.prediction_effect()

func _frame_6():
	if end:
		return
	var obj = host.spawn_object(PROJECTILE_SCENE, 0, 0)
	host.cut_projectile = obj.obj_name
	host.start_1k_cuts_buff()


func _frame_0_shared():
	if !end:
		if scale_combo_meter:
			host.combo_supers += 1
		host.super_effect(super_freeze_ticks)
	else:
		._frame_0_shared()

func is_usable():
	if end:
		return host.cut_projectile != null and host.supers_available >= super_level
	return host.supers_available >= super_level and host.cut_projectile == null
