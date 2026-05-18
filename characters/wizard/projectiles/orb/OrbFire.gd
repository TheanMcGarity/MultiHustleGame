extends BaseProjectile

# Spawned by Orb.start_fire and disabled by Orb when on_fire flips false.
# Snaps to the creator (the Orb) every tick so the hitbox tracks the orb
# wherever it gets pushed / locked / lightning'd to. Invisible by design —
# only the hitbox matters; the orb itself draws the fire VFX.
func tick():
	.tick()
	if creator and !creator.disabled:
		var pos = creator.get_pos()
		set_pos(pos.x, pos.y)
