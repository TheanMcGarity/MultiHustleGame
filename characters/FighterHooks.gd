extends "res://obj/ObjHooks.gd"

class_name FighterHooks

# Modding hook surface for Fighter (BaseChar). Extends ObjHooks, so every
# object hook (ready, init, state_started, hit_something, on_got_parried, ...)
# is available here too, plus the fighter-specific events below. `host` is the
# Fighter. See ObjHooks.gd for how to register an extension.
#
# Fighter overrides tick() without calling super, so its pre_tick()/post_tick()
# (inherited from ObjHooks) are wired into the FIGHTER tick here — they fire
# once per fighter tick.


# Start of Fighter.tick_before (pre-tick bookkeeping, before tick()).
func tick_before():
	pass

# This fighter took a confirmed hit (any source).
func got_hit():
	pass

# This fighter took a confirmed hit from the opposing fighter.
func got_hit_by_fighter():
	pass

# This fighter took a confirmed hit from a projectile.
func got_hit_by_projectile():
	pass

# This fighter successfully parried an attack.
func parried():
	pass

# This fighter clashed.
func clashed():
	pass

# A super started on this fighter, freezing for `freeze_ticks`.
func super_started(freeze_ticks):
	pass

# An action was selected/queued for this fighter. `action` is the move name.
func action_selected(action, data, extra):
	pass
