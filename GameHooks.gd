extends Node

# Modding hook surface for the Game node.
#
# Game.tscn carries one of these as the `Hooks` child, and game.gd calls
# the methods below at every important moment of the match loop. Each method is
# an empty default ("virtual") here, so the base game does nothing extra.
#
# To react to these events, a mod ships a script that extends this one and
# overrides the hooks it cares about, then registers it during init:
#
#     # ModMain.gd
#     func _init(modLoader):
#         modLoader.installScriptExtension("res://my_mod/MyHooks.gd")
#
#     # MyHooks.gd
#     extends "res://GameHooks.gd"
#     func post_tick():
#         print("tick ", game.current_tick)
#
# installScriptExtension take_over_path()s this script, so every Game instance
# (including ghost/prediction games) picks up the extended version automatically.
#
# `game` is the owning Game node, set by game.gd before any hook fires. Use
# it to read match state (game.p1, game.p2, game.current_tick, game.is_ghost,
# game.objects, ...). Ghost/prediction games fire these too — gate on
# game.is_ghost if a hook should only run on the real match.

var game = null


# --- lifecycle ---

# Game node entered the tree and finished its own _ready.
func ready():
	pass

# A match finished setting up (characters loaded, state initialized). Fires once
# per match, at the end of game.start_game.
func game_started(match_data):
	pass

# The match ended. `winner` is 1, 2, or 0 (draw).
func game_ended(winner):
	pass

# An undo was requested (rewinds into playback).
func undo():
	pass

# In-game playback/replay started.
func playback_started():
	pass


# --- per-tick loop ---

# Start of a simulation tick, before any object/player is ticked.
func pre_tick():
	pass

# End of a simulation tick, after hitboxes resolved and combo state updated.
func post_tick():
	pass

# Top of process_tick (the per-real-frame driver that advances simulation,
# handles freeze frames and turn flow).
func process_tick():
	pass

# Each engine physics frame. `delta` is the frame time.
func physics_process(delta):
	pass

# A player became actionable — `player` is the fighter whose turn started.
func player_actionable(player):
	pass

# A player committed an action to the sim — their locked-in move for the turn.
# `player` is the fighter. (Sim-side; the UI-side pick is MainHooks.action_clicked,
# and FighterHooks.action_selected is the same event on the fighter itself.)
func player_acted(player, action, data, extra):
	pass


# --- spawning ---

# A gameplay object (projectile, etc.) was spawned and added to the match.
func object_spawned(obj):
	pass

# A particle/visual effect was spawned.
func particle_effect_spawned(fx):
	pass


# --- combat ---

# Right before hitbox/hurtbox overlaps are resolved for the tick. `players` is
# the port-priority-ordered [attacker_first, ...] array.
func pre_apply_hitboxes(players):
	pass

# Right after hitbox/hurtbox resolution for the tick.
func post_apply_hitboxes(players):
	pass

# A hitbox was refreshed (re-armed so it can hit again).
func hitbox_refreshed(hitbox_name):
	pass

# Two hitboxes clashed. `a` and `b` are the two clashing fighters.
func clashed(a, b):
	pass

# `parrier` parried an attack from `attacker`. The parried move is
# attacker.current_state() (attacker is the opposing fighter; for a parried
# projectile it's the fighter that owns it).
func parried(parrier, attacker):
	pass

# `blocker` blocked a melee attack from `attacker`.
func blocked(blocker, attacker):
	pass

# A global hitlag/freeze was triggered for `amount` ticks.
func global_hitlag(amount):
	pass

# A super freeze started for `player` lasting `ticks`.
func super_started(ticks, player):
	pass

# Player `id` forfeited the match.
func forfeit(id):
	pass
