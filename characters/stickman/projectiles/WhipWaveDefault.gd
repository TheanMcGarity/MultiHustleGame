extends DefaultFireball

func _enter():
	if host.whip_parriable:
		host.has_projectile_parry_window = true

func _frame_4():
	host.has_projectile_parry_window = true
