extends Node

class_name ObjHooks

# Modding hook surface for BaseObj (every in-game object: fighters, projectiles,
# and plain objects). Each BaseObj instance creates one of these as a child in
# _ready (via ModLoader.attach_hooks + the virtual get_hooks_script),
# and calls hooks.<event>(...) at important moments. Every method here is an
# empty default — the base game does nothing extra.
#
# A mod reacts by extending this script and registering it once at init:
#
#     # ModMain.gd
#     func _init(modLoader):
#         modLoader.installScriptExtension("res://obj/ObjHooks.gd")
#
#     # MyObjHooks.gd
#     extends "res://obj/ObjHooks.gd"
#     func post_tick():
#         print(host.obj_name, " ticked")
#
# installScriptExtension take_over_path()s this script, so every object instance
# picks up the extended version automatically.
#
# `host` is the BaseObj these hooks belong to. Fighters and projectiles use
# the ObjHooks SUBCLASSES (FighterHooks / ProjectileHooks) which
# inherit every hook below and add their own — so overriding e.g. hit_by in a
# FighterHooks works too. Ghost/prediction copies create their own hooks
# node, so these fire during prediction as well — gate on host.is_ghost if a
# hook should only run on the real match.
#
# NOTE on tick: pre_tick/post_tick here wrap BaseObj.tick, which runs for plain
# objects and projectiles. Fighter overrides tick() without calling super, so on
# a Fighter the pre_tick/post_tick come from FighterHooks (its own tick),
# not this base path.

var host = null


# Object finished its base _ready setup (fires before subclass _ready completes).
func ready():
	pass

# Object was initialized (state machine set up, hitbox names assigned).
func init():
	pass

# Start of BaseObj.tick (before the object's state/physics advance).
func pre_tick():
	pass

# End of BaseObj.tick (after collision boxes and data are updated).
func post_tick():
	pass

# A state was entered on this object. Fired by the StateMachine (the single
# non-overridden driver), so it fires for every state regardless of how the
# state subclass overrides _enter — no per-state hooks node needed. `state`
# is the state node (state.host is this object).
func state_entered(state):
	pass

# A state was exited on this object.
func state_exited(state):
	pass

# A state ticked on this object.
func state_ticked(state):
	pass

# This object connected with something. `obj` is what was hit, `hitbox` the box
# that landed.
func hit_something(obj, hitbox):
	pass

# One of this object's hitboxes is about to land on `victim`, BEFORE the hit is
# applied (victim.hit_by). The hit is already validated (not invulnerable / not
# already-hit / OTG ok). Mutate `hitbox` here to change this specific hit
# (damage, knockback, ...). The victim's own pre-hit is its hit_by hook.
func hitbox_pre_hit(hitbox, victim):
	pass

# One of this object's hitboxes became active.
func hitbox_activated(hitbox):
	pass

# One of this object's hitboxes was deactivated.
func hitbox_deactivated(hitbox):
	pass

# This object is being hit by `hitbox` (fires at the top of hit_by, before the
# hit is resolved/parried/blocked).
func hit_by(hitbox):
	pass

# This object's hitboxes were refreshed (re-armed to hit again).
func refresh_hitboxes():
	pass

# A global hitlag/freeze of `amount` ticks was requested by this object.
func global_hitlag(amount):
	pass

# This object's attack was perfect-parried.
func on_got_parried():
	pass

# This object's attack was blocked.
func on_got_blocked():
	pass

# This object hit the ceiling.
func on_hit_ceiling():
	pass

# This object spawned a child object (e.g. a projectile). `obj` is the spawn.
func spawn_object(obj):
	pass

# This object spawned a particle effect. `fx` is the effect.
func spawn_particle(fx):
	pass

# This object's state is being changed to `state_name`.
func change_state(state_name, state_data):
	pass

# This object's state was copied onto `other` (ghost/prediction snapshot).
func copy_to(other):
	pass
