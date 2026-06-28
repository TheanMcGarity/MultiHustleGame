extends Node

# Modding hook surface for main.gd (the app/match controller). Main.tscn carries
# one of these as the `Hooks` child; main.gd grabs it in _ready and calls the
# methods below at app/match lifecycle points. `host` is the Main node — read
# host.game, host.match_data, host.singleplayer, host.ui_layer, etc. See
# ObjHooks.gd for how to register an extension (extend res://MainHooks.gd).

var host = null


# Main finished _ready (app initialized).
func ready():
	pass

# A new game flow started (post character-select reset). `singleplayer` is the
# mode. Fires from _on_game_started.
func game_started(singleplayer):
	pass

# Match data is ready for a match (local, multiplayer, replay, or spectate).
# `data` is the match_data dict. Fires from _on_match_ready.
func match_ready(data):
	pass

# A game is being set up (Game instance about to be (re)built). `data` is the
# match data. Fires from setup_game.
func game_setup(singleplayer, data):
	pass

# The opponent disconnected.
func player_disconnected():
	pass

# A replay was saved to `filename`.
func replay_saved(filename):
	pass

# UI/meta turn info ---

# The action UI opened for the active player — their turn, from the UI side
# (action buttons are now available).
func turn_ui_opened():
	pass

# A player clicked an action button in the UI (their intended move for the turn).
# `player_id` is 1 or 2. This is the UI-side pick; the sim-side commit is
# GameHooks.player_acted / FighterHooks.action_selected.
func action_clicked(player_id, action, data, extra):
	pass
