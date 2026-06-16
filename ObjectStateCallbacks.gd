extends Node

class_name ObjectStateCallbacks

# Modding hook surface for ObjectState (every object/projectile state). Each
# state instance creates one of these as a child in StateInterface._ready (via
# the virtual get_callbacks_script), and the StateMachine calls the methods
# below as it drives the state. Firing from the StateMachine — the one
# non-overridden driver — means these fire for EVERY state regardless of how the
# state subclass overrides _enter/_tick/_exit, so no super calls are needed in
# the hundreds of state scripts.
#
# `state` is the state these callbacks belong to. The owning object is
# state.host. CharacterState states use the CharStateCallbacks subclass (which
# inherits every hook here). See ObjCallbacks.gd for how to register an
# extension; the script to extend here is res://ObjectStateCallbacks.gd.
#
# Note: unlike the per-instance object/particle callbacks (carried in their
# scene), states have no scene slot — there are hundreds of state nodes spread
# across every character/projectile scene — so this node is created in code with
# a one-time, cache-backed load() at scene-load (match start), not per frame.

var state = null


# The callbacks node was created (state.host is set).
func ready():
	pass

# This state was entered (after the state's _enter ran, and it isn't
# immediately transitioning away).
func enter():
	pass

# This state was exited.
func exit():
	pass

# This state ticked (after the state's _tick_before/_tick/_tick_after ran).
func tick():
	pass
