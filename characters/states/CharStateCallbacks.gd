extends "res://ObjectStateCallbacks.gd"

class_name CharStateCallbacks

# Modding hook surface for CharacterState (CharState) — fighter states. Extends
# ObjectStateCallbacks, so the state lifecycle hooks (ready, enter, exit, tick)
# are available here too. `state` is the CharacterState; the owning fighter is
# state.host. See ObjectStateCallbacks.gd for details and how to register an
# extension (the script to extend is res://characters/states/CharStateCallbacks.gd).
