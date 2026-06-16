extends Node

class_name ParticleCallbacks

# Modding hook surface for ParticleEffect (every particle effect). Each instance
# creates one of these as a child in _ready (via ModLoader.attach_callbacks +
# the virtual get_callbacks_script) and calls callbacks.<event>(...). `host` is
# the ParticleEffect. See ObjCallbacks.gd for how to register an extension; the
# script to extend here is res://fx/ParticleCallbacks.gd.

var host = null


# Particle finished its base _ready setup.
func ready():
	pass

# Particle advanced one tick.
func tick():
	pass

# Particle started (start()).
func start():
	pass

# Particle started emitting.
func start_emitting():
	pass

# Particle stopped emitting.
func stop_emitting():
	pass
