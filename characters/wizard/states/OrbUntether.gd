extends WizardState

func _frame_0():
	host.tether_ticks = 0

func is_usable():
	return host.tether_ticks > 0 and .is_usable()
