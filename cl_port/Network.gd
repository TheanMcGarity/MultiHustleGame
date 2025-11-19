extends "res://Network.gd"

var _Global = self

# these variables are only here bc Network is the only global script that modloader can extend
var default_chars = 0
var css_instance = null # instance of the charater select script that is currently running
var ogVersion = Global.VERSION
var isSteamGame = false
var steam_errorMsg = ""

var retro_P2P_doFix = false


# these var declarations are necessary to force ModHashCheck.gd to not run, otherwise all of this code gets replaced

#

var player1_hash_to_folder
var player2_hash_to_folder

var player1_chars = []
var player2_chars = []

var steam_oppChars = []

var normal_mods = []
var char_mods = []
#var generated_modlist = false

var hash_to_folder = {}

var diff = ""

var steam_isHost = false

remotesync func register_player(new_player_name, id, mods, isSteam = false):
	# failsafe in case you connect to a non-modded player, it'll show up as having no mods
	if (typeof(mods) != TYPE_DICTIONARY):
		mods = {"version" : mods, "active_mods":[]}

	if (mods.has("normal_mods")):
		if not second_register:
			player1_hashes = mods.normal_mods
			player1_chars = mods.char_mods
			player1_hash_to_folder = mods.hash_to_folder
			
			second_register = true
		elif second_register:
			player2_hashes = mods.normal_mods
			player2_chars = mods.char_mods
			player2_hash_to_folder = mods.hash_to_folder
			
			if not _compare_checksum():
				update_diffList()
				emit_signal("game_error", "Can't connect, you both need to share every server-side mod that isn't a character.\nDifferences: " + diff)
				return 
	else:
		second_register = true
	if mods.version != Global.VERSION:
		emit_signal("game_error", "Mismatched game versions.\nYou: %s, Opponent: %s." % [Global.VERSION, mods.version])
		return 
	
	if (get_tree().get_network_unique_id() == id):
		network_id = id
	
	_Global.isSteamGame = false

	print("registering player: " + str(id))
	players[id] = new_player_name
	emit_signal("player_list_changed")

func update_diffList():
	var diffList = []
	var namesList = []
	diff = ""
	var allHashes = player1_hashes + player2_hashes
	for h in allHashes:
		if (!(h in player1_hashes) or !(h in player2_hashes)):
			diffList.append(h)

			var modName
			if (player1_hash_to_folder.has(h)):
				modName = player1_hash_to_folder[h]
			else:
				modName = player2_hash_to_folder[h]
			if !(modName in namesList):
				namesList.append(modName)
			else:
				namesList[namesList.find(modName)] += " (diff. versions)"

	for i in len(namesList):
		var m = namesList[i]
		if i > 0:
			diff += ", "

		diff += m.replace("res://", "")
# steam shits
#func register_player_steam(steam_id, mods = {}):
#    if SteamLobby.SPECTATING:
#        return 
#    register_player(Steam.getFriendPersonaName(steam_id), steam_id, mods, true)
	

# these 3 function overwrites are for hash_to_folder, normal_mods and char_mods to get sent alongside active_mods
# hash_to_folder will tell what mod names the other player should display when they differ in server-sided non-character mods (the other player doesn't know the names of the mods they don't have)
remote func player_connected_relay():
	rpc_("register_player", [player_name, get_tree().get_network_unique_id(), {"active_mods": ModLoader.active_mods, "normal_mods":normal_mods, "hash_to_folder":hash_to_folder, "char_mods":char_mods, "version":Global.VERSION}])

func player_connected(id):
	if direct_connect:
		rpc_("register_player", [player_name, id, {"active_mods": ModLoader.active_mods, "normal_mods":normal_mods, "hash_to_folder":hash_to_folder, "char_mods":char_mods, "version":Global.VERSION}])

func host_game_direct(new_player_name, port):
	_reset()
	player_name = new_player_name
	peer = NetworkedMultiplayerENet.new()
	peer.create_server(int(port), MAX_PEERS)
	get_tree().set_network_peer(peer)
	multiplayer_active = true
	direct_connect = true
	multiplayer_host = true # this is the on
	rpc_("register_player", [new_player_name, get_tree().get_network_unique_id(), {"active_mods": ModLoader.active_mods, "normal_mods":normal_mods, "hash_to_folder":hash_to_folder, "char_mods":char_mods, "version":Global.VERSION}])

# had to overwrite this whole function just because ivy forgot to set multiplayer_host to false
func join_game_direct(ip, port, new_player_name):
	_reset()
	player_name = new_player_name
	peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, int(port))
	multiplayer_active = true
	direct_connect = true
	multiplayer_host = false
	get_tree().set_network_peer(peer)

# now player hashes only correspond to non-character mods
func _compare_checksum():
	player1_hashes.sort()
	player2_hashes.sort()

	return player1_hashes == player2_hashes

# when the client finishes loading the host's character, it will send a signal that will call this function, ensuring the Go button becomes available for the host
remotesync func go_button_activate():
	do_button_activate()

# when the host presses the Go button, a signal is emmitted that calls this function
remotesync func go_button_pressed():
	do_button_pressed()

# these get called separately, from different functions depending on if it's legacy (here with rpc) or steam (on SteamLobby with send_P2P_Packet)
func do_button_activate():
	if multiplayer_host:
		var goBtt = _Global.css_instance.get_node("GoButton")
		if !goBtt.visible:
			goBtt.show()
			_Global.css_instance.enable_online_go = true # this variable serves as a buffered check to enable the Go button in characterSelect's _process()
		else:
			goBtt.disabled = false

func do_button_pressed():
	if !multiplayer_host:
		_Global.css_instance.buffer_go = true # this variable serves as a buffered check to call the go() function in characterSelect's _process()

remotesync func character_list(chars):
	steam_oppChars = chars

var char_loaded = {}

var sync_unlocks = {}

var lock_sync_unlocks = true

#Oh my god I hate this so much but it somehow works in testing dpajwojiosdfnikvkvknovnkonkoiopsja
var mh_file_path = "user://logs/mhlogs" + Time.get_time_string_from_unix_time(int(Time.get_unix_time_from_system()-(Time.get_ticks_msec()/1000))).replace(":", ".") + ".log"
var net_file_path = "user://logs/netlogs" + Time.get_time_string_from_unix_time(int(Time.get_unix_time_from_system()-(Time.get_ticks_msec()/1000))).replace(":", ".") + ".log"

const DISABLE_LOGS = false

# Util Functions

"""
Quick note from CTAG: I use a lot of questionable logic to sorta ignore dead players while still sending them actions.
Dead players could get desynced and nobody would be the wiser besides the dead player.
If someone comes along who wants to fix this and make it properly ignore/remove/make them spectators, go ahead.
But I'm fairly confident that this xshould cover for now.
"""

# This function is just so that i dont have to rename a ton of usages before this function got renamed without the usages being renamed as well.
func log_to_file(msg, net = false):
	self.log(msg, net)

func log(msg, net = false):
	if DISABLE_LOGS:
		return
	
	print(msg)
	#if net:
	#	logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] " + msg, net_file_path)
	#else:
	#	logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] " + msg, mh_file_path)

func get_all_pairs(list):
	var idx = 0
	var listEnd = len(list)
	var listEndMinus = listEnd - 1
	var result = []
	for p1 in list:
		for p2 in list.slice(idx+1, listEnd):
			result.append([p1, p2])
		idx = idx + 1
		if (idx == listEndMinus):
			break
	return result

# Deprecated, base game always has it now.
func has_char_loader()->bool:
	return true

func ensure_script_override(object):
	#var property_list = object.get_property_list()
	#var properties = {}
	#for property in property_list:
	#	properties[property.name] = object.get(property.name)
	object.set_script(load(object.get_script().resource_path))
	#for property in properties.keys():
	#	object.set(property, properties[property])

func pid_to_usernamepid_to_username(player_id):
	if !is_instance_valid(game):
		return ""
	if SteamLobby.SPECTATING or !network_ids.has(player_id):
		return Global.current_game.match_data.user_data["p" + str(player_id)]
	if direct_connect:
		return players[network_ids[opponent_player_id(player_id)]]
	return players[network_ids[player_id]]

remotesync func end_turn_simulation(tick, player_id):
	Network.log("Ending turn simulation for player " + str(player_id) + " at tick " + str(tick))
	ticks[player_id] = tick
	turn_synced = true
	for v in ticks.values():
		if v != tick:
			turn_synced = false
	if turn_synced:
		send_ready = false
		emit_signal("player_turns_synced")

func submit_action(action, data, extra):
	if multiplayer_active:
		action_inputs[player_id]["action"] = action
		action_inputs[player_id]["data"] = data
		action_inputs[player_id]["extra"] = extra
		rpc_("multiplayer_turn_ready", player_id)
		Network.log("Action ready for player " + str(player_id))

func send_current_action():
	if last_action:
		rpc_("send_action", [last_action["action"], last_action["data"], last_action["extra"], player_id], "remote")

remotesync func multiplayer_turn_ready(id):
	turns_ready[id] = true
	Network.log("Turn ready for player " + str(id) + " | Turns ready: " + str(turns_ready))
	emit_signal("player_turn_ready", id)
	if steam:
		SteamLobby.spectator_turn_ready(id)
	for r in turns_ready.values():
		if !r:
			return
	action_submitted = true
	last_action = action_inputs[player_id]
	if is_instance_valid(game):
		last_action_sent_tick = game.current_tick
	send_current_action()
	possible_softlock = true
	emit_signal("turn_ready")
	turn_synced = false
	send_ready = true

func sync_tick():
	lock_sync_unlocks = false
	if not game.players[Network.player_id].game_over:
		Network.log("Telling opponent im ready")
		rpc_("mh_opponent_tick", player_id, "remote")

remote func mh_opponent_tick(id):
	Network.log("Opponent is ready")
	yield (get_tree(), "idle_frame")
	if is_instance_valid(game):
		game.network_simulate_readies[id] = true

func reset_action_inputs():
	turns_ready = {}
	action_inputs = {}
	for player in game.players.keys():
		if game.players[player].game_over:
			action_inputs[player] = {
				"action":"ContinueAuto", 
				"data":null, 
				"extra":null, 
			}
			turns_ready[player] = true
		else:
			action_inputs[player] = {
				"action":null, 
				"data":null, 
				"extra":null, 
			}
			turns_ready[player] = false

func sync_unlock_turn():
	Network.log("telling opponent we are actionable")
	
	rpc_("opponent_sync_check_unlock", null, "remote")

remote func opponent_sync_check_unlock():
	Network.log("Opponent is actionable")
	while is_instance_valid(game) and not game.game_paused:
		yield (get_tree(), "idle_frame")
	Network.log("So are we")
	sync_unlocks[player_id] = true
	rpc_("mh_opponent_sync_unlock", player_id, "remote")

remote func mh_opponent_sync_unlock(id):
	if !lock_sync_unlocks:
		Network.log("Opponent sync unlocked, ID: " + str(id))
		sync_unlocks[id] = true
		Network.log("Sync unlocks: " + str(sync_unlocks))
		var done = true
		for key in sync_unlocks:
			var value = sync_unlocks[key]

			if game.quitters.has(key):
				log_to_file("Ignoring sync unlock for quitter " + str(key))
				continue

			if not value:
				done = false
				break
		if done:
			for key in sync_unlocks.keys():
				if not game.players[key].game_over and not game.quitters.has(key):
					sync_unlocks[key] = false
			can_open_action_buttons = true
			Network.log("Unlocking action buttons")
			emit_signal("force_open_action_buttons")
			lock_sync_unlocks = true

remote func player_disconnected(id):
	pass

	

# Teams

# username just is for printing to log.
remotesync func on_team_change(team:int, username:String, player:int):
	var team_name
	var in_team = true
	match team:
		1:
			team_name = "Red"
		2:
			team_name = "Blue"
		3:
			team_name = "Yellow"
		4:
			team_name = "Green"
		_:
			team_name = "None"
			in_team = false
	
	print(username+"'s team changed to "+str(team_name))
	
	for team_key in teams:
		var team_dict = teams[team_key]
		if team_dict.has(player):
			team_living[team_key] -= 1
			team_dict.erase(player)

	team_living[team] += 1
	teams[team][player] = null
	 

# TODO: Move to game.gd
# Please do Dictionary<int, Dictionary<int, BaseChar>>
var teams: Dictionary = { 
	1: {},
	2: {},
	3: {},
	4: {},
	0: {}
}

func print_team_counts():
	pass
	#print("Team Player Counts")
	#print("Red team: " + str(teams[1].size()))
	#print("Blue team: " + str(teams[1].size()))
	#print("Yellow team: " + str(teams[1].size()))
	#print("Green team: " + str(teams[1].size()))
	
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Team Player Counts", mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Red team: " + str(teams[1].size()), mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Blue team: " + str(teams[2].size()), mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Yellow team: " + str(teams[3].size()), mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Green team: " + str(teams[4].size()), mh_file_path)

func is_on_team(character, id:int):
	return teams[id].values().contains(character)

func get_team(character_id:int):
	for team in teams:
		if teams[team].has(character_id):
			return team
	
	return 0 # if the character is not in a team (including FFA)

func get_color(id:int):
	#print("Getting color for team "+str(id)) laggy
	match id:
		1:
			return "ff333d" # Red
		2:
			return "1d8df5" # Blue
		3:
			return "fcc603" # Yellow
		4:
			return "2ac91e" # Green
	
	return "ffffff" # White / None

func create_team_button(text:String, name:String, team:int, container:Node):
	var team_button = load("res://multihustle/teams/TeamButton.tscn").instance()
	container.add_child(team_button)
	team_button.text = text
	team_button.name = name
	team_button.team_id = team
	return team_button

signal mh_chat_message_received(id, message, username)
remotesync func send_mh_chat_message(player_id, message, username):
	emit_signal("mh_chat_message_received", player_id, message, username)
	

signal mh_chat_message_received_preformatted(message)
remotesync func send_mh_chat_message_preformatted(message):
	emit_signal("mh_chat_message_received_preformatted", message)
	

# TODO: Make an actual system that isnt this
var temp_hitbox_teams = { }

func get_living_players_on_team(team:int):
	if (teams == null):
		print("null teams")
	if (teams[team] == null):
		print("null team")
	var living = teams[team].size()
	#print(str(team)+" "+living)
	for player in teams[team]:
		living -= int(player.game_over)
	return living


remotesync func set_display_name(name:String, char_id:int):

	var color = get_color(get_team(char_id));
	
	if name == null or name == "":
		name = "!!Invalid Persona Name!!"
		color = "630700"
	
	if not is_instance_valid(game):
		return

	game.player_names_rich[char_id] = "[center][color=#%s]%s[/color][/center]" % [color, name]
	game.player_names[char_id] = name
	
	name_init_count += 1
	if name_init_count > game.players.size():
		name_initialized = true
		
		main.uiselectors.reinit(main)
		main.hud_layer.reinit(main.hud_layer.p1index, main.hud_layer.p2index)
	else:
		name_initialized = false

remotesync func set_ghost_display_name(name:String, char_id:int):
	var label:RichTextLabel = game.ghost_game.players[char_id].display_name
	label.bbcode_text = "[center][color=#99"+get_color(get_team(char_id))+"]"+name+"[/color][/center]"
	
var team_living:Dictionary = {
	1:0,
	2:0,
	3:0,
	4:0,
	0:0
}


var name_init_count:int = 0
var name_initialized:bool = false

var main

func get_contains_string(option_button:OptionButton, string:String):
	for i in range(0, option_button.get_item_count()):
		if string in option_button.get_item_text(i):
			return true 
	return false

signal mh_resim_accepted(player)

signal mh_resim_requested(player)

remotesync func request_mh_resim(requester_id:int):
	resync_counter = 1
	resync_request_player_id = requester_id
	emit_signal("mh_resim_requested", requester_id)

var resync_request_player_id:int = 0



remotesync func accept_mh_resim(player_id:int):
	# todo: make better
	resync_counter += 1

	log_to_file("ACCEPT_MH_RESIM()->%d,%d)" % players.size, resync_counter)

	if (self.player_id == player_id):
		var team = Network.get_team(Network.player_id)
		var color = Network.get_color(team)
		var username = game.player_names[Network.player_id]
		var msg = ("[color=#%s]%s[/color] clicked RESYNC. %d/%d" % [color, username, resync_counter, players.size() - game.quitters.size()]) 

		rpc_("send_mh_chat_message_preformatted", [msg])

	
	emit_signal("mh_resim_accepted", player_id)

func request_softlock_fix():
	if multiplayer_active:
		rpc_("request_mh_resim", [Network.player_id])

var resync_counter = 0

func accept_softlock_fix():
	if multiplayer_active:
		rpc_("accept_mh_resim", [Network.player_id])

remotesync func mh_resim(frames):
	if player_id != resync_request_player_id:
		ReplayManager.frames = frames
	log_to_file("MH Resync from %s" % game.player_names[resync_request_player_id])
	undo = true
	auto = true

	if is_instance_valid(game):
		game.undo(false)

	log_to_file("MH_RESIM()")

	var ui = main.ui_layer
	for player in game.players:
		var real_id = ui.GetRealID(player)
		var timer = ui.turn_timers[real_id]
		if timer:
			timer.start(ui.turn_time)
			timer.paused = false

	resync_request_player_id = 0

remotesync func select_opp(my_id, opp_id):
	game.players[my_id].opponent = game.players[opp_id]
	#var opp_name = main.uiselectors.selects[2][0].get_char_name(opp_id)

	#if main.uiselectors.selects[2][0].active_char_index == my_id:
	#	main.uiselectors.opp_target_label.text = "OPP TARGET: %s" % opp_name


func select_opponent(self_id, opp_id):
	#("select_opponent->self_id=%d opp_id=%d" % [self_id, opp_id])
	if multiplayer_active:
		rpc_("select_opp", [self_id, opp_id])
	else: # Singleplayer port
		game.players[self_id].opponent = game.players[opp_id]
		sp_opp_dict[self_id] = opp_id


var player_character_names:Dictionary = {}
var player_character_uses:Dictionary = {}

func team_init(player:int):

	if get_team(player) != 0:
		return # Already on a team, no need to initialize.
	
	print("Teams Initialized for player %d!" % player)


	if not multiplayer_active:
		singleplayer_on_team_change(0, ("p%d" % player), player)
		return

	var steam_id = Steam.getSteamID()
	var username = Steam.getFriendPersonaName(steam_id)
	
	rpc_("on_team_change", [0, username, Network.player_id])

func singleplayer_on_team_change(team:int, username:String, player:int):
	var team_name
	var in_team = true
	match team:
		1:
			team_name = "Red"
		2:
			team_name = "Blue"
		3:
			team_name = "Yellow"
		4:
			team_name = "Green"
		_:
			team_name = "None"
			in_team = false
	
	print(username+"'s team changed to "+str(team_name))
	
	for team_key in teams:
		var team_dict = teams[team_key]
		if team_dict.has(player):
			team_living[team_key] -= 1
			team_dict.erase(player)
	
	team_living[team] += 1
	teams[team][player] = null

var sp_opp_dict = {}


remotesync func client_disconnected(id):
	log_to_file("CLIENT DISCONNECTED -> %d" % id)
	if not is_instance_valid(game):
		print("Game is invalid!")
		return
	var ui = main.ui_layer
	var player = game.players[id]
	if player:
		player.game_over = true
		player.hp = 0
		player.forfeit()
		sync_unlocks[id] = true
		turns_ready[id] = true
		game.quitters.append(id)
		ui.end_turn_for_real(id)
		player.on_action_selected("Forfeit", null, null)

		resync_counter += 1
		if resync_counter == game.players.size() and player_id == resync_request_player_id:
			rpc_("mh_resim", [ReplayManager.frames])
			log_to_file("Rsyncing from forfeit.")
		


		log_to_file("CLIENT FORFEIT -> %d" % id)
		

signal steam_lobby_sync_confirmed(steam_id, opps)

remotesync func net_sync_confirm(steam_id, opps):
	emit_signal("steam_lobby_sync_confirmed", steam_id, opps)
