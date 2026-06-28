extends "res://obj/ObjHooks.gd"

# Modding hook surface for BaseProjectile. Extends ObjHooks, so every object
# hook is available here too, plus the projectile-specific events below. `host`
# is the BaseProjectile. See ObjHooks.gd for how to register an extension.


# This projectile was disabled (fizzled/spent — hidden, hitboxes off).
func on_disable():
	pass

# This projectile was parried (it emits got_parried).
func on_got_parried():
	pass
