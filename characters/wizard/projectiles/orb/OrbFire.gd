extends BaseProjectile

# Spawned by Orb.start_fire and disabled by Orb when on_fire flips false.
# Snaps to the creator (the Orb) every tick so the hitbox tracks the orb
# wherever it gets pushed / locked / lightning'd to. Invisible by design —
# only the hitbox matters; the orb itself draws the fire VFX.
func tick():
	if creator and !creator.disabled:
		var pos = creator.get_pos()
		set_pos(pos.x, pos.y)
	.tick()

# Push-blocking the fire hitbox bounces the orb's fire trajectory back
# at the Wizard — same reversal that Orb does from its Sword state.
func on_got_push_blocked():
	if creator and !creator.disabled and creator.has_method("reverse_fire_direction"):
		creator.reverse_fire_direction()
