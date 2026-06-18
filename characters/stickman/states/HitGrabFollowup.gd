extends ThrowState

func _frame_0():
	host.play_sound("Swish")
	# Skull Shaker's hit-grab opener has increment_combo = false, so it skips the
	# scale_combo proration latch where a parry punish would normally pick up its
	# +1 combo proration. Apply it here (once per combo) so Skull Shaker respects
	# parry proration like any other opener.
	if not host.combo_proration_set and (host.parry_combo or host.parried_burst_combo):
		host.combo_proration = Utils.int_min(host.combo_proration + 1, host.MAX_STALES)
		host.combo_proration_set = true
	pass

func _frame_6():
	host.play_sound("Swish")
	pass

func _on_hit_something(obj, hitbox):
	if obj == host.opponent:
		if host.combo_moves_used.has("HitGrab") and host.combo_moves_used["HitGrab"] <= 1:
			host.skull_shaker_bleed_ticks = host.SKULL_SHAKER_BLEED_TICKS
