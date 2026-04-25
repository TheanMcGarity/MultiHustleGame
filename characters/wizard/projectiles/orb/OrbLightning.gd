extends BaseProjectile

func on_got_push_blocked():
	if creator and !creator.disabled:
		creator.on_got_push_blocked()
