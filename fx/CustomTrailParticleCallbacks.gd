extends "res://fx/ParticleCallbacks.gd"

class_name CustomTrailParticleCallbacks

# Modding hook surface for CustomTrailParticle (the configurable trail/aura
# particle). Extends ParticleCallbacks, so the base particle hooks (ready, tick,
# start, ...) are available too, plus the trail-specific events below. `host` is
# the CustomTrailParticle. The base tick() hook fires once per tick (via the
# super .tick() call inside CustomTrailParticle.tick).


# A burst of particles was emitted.
func emit_burst():
	pass

# The particle system restarted.
func restart():
	pass
