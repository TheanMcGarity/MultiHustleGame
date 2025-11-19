extends Node2D

class_name Game

const GHOST_FRAMES = 90
const SUPER_FREEZE_TICKS = 20
const GHOST_ACTIONABLE_FREEZE_TICKS = 10
const CAMERA_MAX_Y_DIST = 210
const QUITTER_FOCUS_TICKS = 60
const CLASH_DAMAGE_DIFF = 25
const CAMERA_PADDING = 20
const DEBUG_THROW_ROUTING := false

export(int) var char_distance = 200
export(int) var stage_width = 1100
export(int) var max_char_distance = 600
export(int) var time = 3000

signal player_actionable()
signal player_actionable_network()
signal simulation_continue()
signal playback_requested()
signal game_ended()
signal game_won(winner)
signal team_game_won(winner)
signal ghost_finished()
signal make_afterimage()
signal ghost_my_turn()
signal forfeit_started(id)
signal actions_submitted()
signal turn_started()
signal zoom_changed()

var p1_data
var p2_data

var p1_turn = false
var p2_turn = false

onready var camera: GoodCamera = $Camera2D
onready var objects_node = $Objects
onready var fx_node = $Fx

var mouse_pressed = false

var current_tick = -1
var max_replay_tick = 0
var game_started = false
var undoing = false
var singleplayer = false
var parry_freeze = false
var clashing_enabled = false

var game_paused = false

var buffer_playback = false
var buffer_edit = false

var game_end_tick = 0

var frame_passed = false

var game_finished = false

var ghost_cleaned = true

var asymmetrical_clashing = false

var forfeit = false

var quitter_focus = false
var quitter_focus_ticks = 0

var advance_frame_input = false

var frame_by_frame = false

var network_simulate_ready = true

var gravity_enabled = true

var is_ghost = false
var is_afterimage = false
var ghost_hidden = false
var ghost_game
var ghost_speed = 3
var ghost_tick = 0
var forfeit_player = null

var match_data = null
var simulated_once = false
var started_multiplayer = false
var prediction_enabled = true

var p1 = null
var p2 = null

var p1_username = null
var p2_username = null
var my_id = 1

var draw_stage = true

var snapping_camera = false 
var waiting_for_player_prev = false
var spectate_tick = -1
var global_gravity_modifier = "1.0"

var camera_snap_position = Vector2()

var objects: Array = []
var objs_map = {
	
}
var effects: Array = []

var drag_position = null

var real_tick = 0
var super_freeze_ticks = 0
var super_active = false
var prediction_effect = false
var p1_super = false
var p2_super = false
var hit_freeze = false
var ghost_freeze = false
var player_actionable = true
var network_sync_tick = -100
var ceiling_height = 400
var has_ceiling = true
var mouse_position = Vector2()

var ghost_simulated_ticks = 0

var is_in_replay = false

var ghost_actionable_freeze_ticks = 0
var ghost_p1_actionable = false
var ghost_p2_actionable = false
var made_afterimage = false

var p1_ghost_ready_tick
var p2_ghost_ready_tick

var spectating = false

var ghost_time = 0.0

var camera_zoom = 1.0

var player_datas:Dictionary = {}
var player_turns:Dictionary = {}
var players:Dictionary = {}
var player_usernames:Dictionary = {}
var player_supers:Dictionary = {}
var ghost_player_actionables:Dictionary = {}
var player_ghost_ready_tick:Dictionary = {}
var game_started_real:bool = false
var multiHustle_CharManager
var turns_taken:Dictionary = {}
var needs_refresh:bool = true
var current_opponent_indicies:Dictionary = {}
var player_colors:Dictionary = {}
var color_rng:BetterRng = BetterRng.new()
var throws_consumed:Dictionary = {}
var players_hittable_dic:Dictionary = {}
var network_simulate_readies:Dictionary = {}
var player_names:Dictionary = {}
var player_names_rich:Dictionary = {}
var players_getting_throwed:Dictionary = {}
var quitters:Array = []
var is_team_win := false

#var has_ghost_frozen_yet = false

func get_ticks_left():
	return time - Utils.int_min(current_tick, time)

func _ready():
	
	if is_ghost:
		hide()
		for object in objects_node.get_children():
			object.free()
		for fx in fx_node.get_children():
			fx.free()
		$GhostStartTimer.start()
		ghost_time = Time.get_unix_time_from_system()
	else:
		emit_signal("simulation_continue")

func _spawn_particle_effect(particle_effect: PackedScene, pos: Vector2, dir= Vector2.RIGHT):
	var obj = particle_effect.instance()
	add_child(obj)
	obj.tick()
	var facing = -1 if dir.x < 0 else 1
	obj.position = pos
	if facing < 0:
		obj.rotation = (dir * Vector2(-1, -1)).angle()
	else:
		obj.rotation = dir.angle()
	obj.scale.x = facing
	remove_child(obj)
	on_particle_effect_spawned(obj)

func connect_signals(object):
	object.connect("object_spawned", self, "on_object_spawned")
	object.connect("particle_effect_spawned", self, "on_particle_effect_spawned")

func copy_to(game):
	set_vanilla_game_started(true)

	if not self.game_started:
		return
	game.player_colors = player_colors.duplicate(true)
	game.current_opponent_indicies = current_opponent_indicies.duplicate(true)
	for index in players.keys():
		var player_old = players[index]
		player_old.chara.copy_to(game.players[index].chara)
		game.players[index].update_data()
		player_old.copy_to(game.players[index])
		var player_new = game.players[index]
		match(index):
			1:
				game.p1 = player_new
			2:
				game.p2 = player_new
		player_new.hp = player_old.hp
	# Delayed opponent initialization just to be sure
	for index in players.keys():
		if is_instance_valid(players[index].opponent):
			game.players[index].opponent = game.players[players[index].opponent.id]
	clean_objects()
	for object in game.objects:
		if is_instance_valid(object):
			object.free()
	for fx in game.effects:
		if is_instance_valid(fx):
			fx.free()
	for object in self.objects:
		if is_instance_valid(object):
			if not object.disabled:
				var new_obj = load(object.filename).instance()
				game.on_object_spawned(new_obj)
				# Refuses to override, so done manually here. Thanks to Degritone for part of the code
				new_obj.init()
				var old_state_machine = object.get("state_machine") # Just making sure the object has a state machine
				if old_state_machine != null:
					var old_map = old_state_machine.states_map
					var old_hitboxes = object.hitboxes
					var new_state_machine = new_obj.state_machine
					var new_map = new_state_machine.states_map
					var new_hitboxes = new_obj.hitboxes
					if new_hitboxes.size() < old_hitboxes.size():
						new_hitboxes.resize(old_hitboxes.size())
					for key in new_map:
						var state = new_map[key]
						for old_hit in old_map[key].get_children():
							if (old_hit is Hitbox and !state.has_node(old_hit.name)):
								var new_hit = old_hit.duplicate()
								new_hit.name = old_hit.name
								state.add_child(new_hit)
								# REVIEW - Possibly try to eliminate pointless rechecking
								for index in old_hitboxes.size():
									if old_hit == old_hitboxes[index]:
										new_hitboxes[index] = new_hit

				object.copy_to(new_obj)
			else :
				game.objs_map[str(game.objs_map.size() + 1)] = null
	game.camera.limit_left = self.camera.limit_left
	game.camera.limit_right = self.camera.limit_right

func _on_super_started(ticks, player):
	set_vanilla_game_started(true)

	if self.is_ghost:
		return
	if ticks == null:
		ticks = 0
		var state = player.current_state()
		if state.get("super_freeze_ticks") != null:
			if state.super_freeze_ticks > ticks:
				ticks = state.super_freeze_ticks
	self.super_freeze_ticks = ticks

	self.super_active = true
	for index in players.keys():
		if player == players[index]:
			player_supers[index] = true
			match(index):
				1:
					p1_super = true
				2:
					p2_super = true

func get_screen_position(player_id):
	var screen_center = camera.get_camera_screen_center()
	var player_position = get_player(player_id).get_center_position_float()
	var result = player_position - screen_center
	return result / camera.zoom.x

func get_player(id):
	set_vanilla_game_started(true)

	if players.has(id):
		return players[id]
	return players[1] # im scared to return null, so ill just do this ig

func on_particle_effect_spawned(fx: ParticleEffect):
	if ReplayManager.resimulating:
		fx.queue_free()
		return
	effects.append(fx)
	fx_node.add_child(fx)
	fx.connect("tree_exited", self, "_on_fx_exit_tree", [fx])
	
func on_object_spawned(obj: BaseObj):
	objects.append(obj)
	objects_node.add_child(obj)
	obj.has_ceiling = has_ceiling
	obj.ceiling_height = ceiling_height
	obj.obj_name = str(objs_map.size() + 1)
	obj.logic_rng = BetterRng.new()
	obj.logic_rng_static = BetterRng.new()
	var seed_ = hash(match_data.seed + (objs_map.size() + 1))
	obj.logic_rng.seed = seed_
	obj.logic_rng_seed = seed_
	obj.logic_rng_static.seed = match_data.seed
	obj.logic_rng_static_seed = match_data.seed
	objs_map[obj.obj_name if obj.obj_name else obj.name] = obj
	obj.objs_map = objs_map
	obj.connect("tree_exited", self, "_on_obj_exit_tree", [obj])
	obj.connect("hitbox_refreshed", self, "on_hitbox_refreshed")
	obj.connect("global_hitlag", self, "on_global_hitlag")
	obj.gravity_enabled = gravity_enabled
	obj.set_gravity_modifier(global_gravity_modifier)
	obj.fighter_owner = get_player(obj.id)
	obj.update_data()
	for particle in obj.particles.get_children():
		effects.append(particle)
	connect_signals(obj)

func _on_fx_exit_tree(fx):
	effects.erase(fx)

func _on_obj_exit_tree(obj):
	objects.erase(obj)

func on_hitbox_refreshed(hitbox_name):
	set_vanilla_game_started(true)

	for index in players.keys():
		players[index].parried_hitboxes.erase(hitbox_name)
	pass

func on_clash():
	super_freeze_ticks = 5
	parry_freeze = true
	pass

func on_parry():
	super_freeze_ticks = 10 
	parry_freeze = true

func on_block():
	super_freeze_ticks = 7 
	parry_freeze = true

var is_global_hitlag_activated_now = false

func on_global_hitlag(amount):
	if is_ghost:
		return
	is_global_hitlag_activated_now = true
	super_freeze_ticks = amount
	parry_freeze = true
	hit_freeze = true

func forfeit(id):
	set_vanilla_game_started(true)
	players[id].forfeit()

func start_game(singleplayer:bool, match_data:Dictionary):
	set_vanilla_game_started(true)

	#print(match_data)
	
	if match_data.has("teams"):
		var team_dict = match_data["teams"]
		var replay_teams = {1:{},2:{},3:{},4:{},0:{}}
		var replay_teams_living = {1:0,2:0,3:0,4:0,0:0}
		for team_player in team_dict:
			replay_teams[team_dict[team_player]][team_player] = null
			replay_teams_living[team_dict[team_player]] += 1
			pass
		Network.teams = replay_teams
		Network.team_living = replay_teams_living
	# Only for compatibility with old replays
	if match_data.has("display_names"):
		player_names_rich = match_data["display_names"]
	if match_data.has("rich_display_names"):
		player_names_rich = match_data["rich_display_names"]

	if match_data.has("selector_char_names"):
		Network.player_character_names = match_data["selector_char_names"]

	self.match_data = match_data
	color_rng.seed = match_data.seed

	if match_data.has("spectating"):
		self.spectating = match_data.spectating
		if self.is_ghost:
			self.spectating = false
	# Implement variable key loader
	for index in match_data.selected_characters.keys():
		if multiHustle_CharManager.InitCharacter(self, index, match_data.selected_characters[index]) == false:
			Network.log("Failed to load character")
			return false

	for player in players.values():
		player.connect("parried", self, "on_parry")
		player.connect("clashed", self, "on_clash")
		player.connect("predicted", self, "on_prediction", [player])
	
	if not Network.multiplayer_active and not match_data.has("replay"):
		var team0_last = Network.teams[0][Network.teams[0].keys()[-1]]
		if not players.has(team0_last):
			var team_dict = Network.teams[0]
			if team_dict.has(team0_last):
				Network.team_living[0] -= 1
				team_dict.erase(team0_last)
		
	self.stage_width = Utils.int_clamp(match_data.stage_width, 100, 50000)
	if match_data.has("game_length"):
		self.time = match_data["game_length"]
	if match_data.has("frame_by_frame"):
		self.frame_by_frame = match_data.frame_by_frame
	if match_data.has("char_distance"):
		self.char_distance = match_data["char_distance"]
	if match_data.has("clashing_enabled"):
		self.clashing_enabled = match_data["clashing_enabled"]
	if match_data.has("asymmetrical_clashing"):
		self.asymmetrical_clashing = match_data["asymmetrical_clashing"]
	if match_data.has("global_gravity_modifier"):
		self.global_gravity_modifier = match_data["global_gravity_modifier"]
	if match_data.has("has_ceiling"):
		self.has_ceiling = match_data["has_ceiling"]
	if match_data.has("ceiling_height"):
		self.ceiling_height = match_data["ceiling_height"]
	if match_data.has("prediction_enabled"):
		self.prediction_enabled = match_data["prediction_enabled"]
	for index in players.keys():
		var player = players[index]
		player.has_ceiling = has_ceiling
		player.name = str("P", index)
		player.logic_rng = BetterRng.new()
		player.logic_rng_static = BetterRng.new()
		var rng_seed = hash(match_data.seed + index - 1)
		player.logic_rng.seed = rng_seed
		player.logic_rng_seed = rng_seed
		player.logic_rng_static.seed = rng_seed
		player.logic_rng_static_seed = rng_seed
		player.id = index
		player.is_ghost = self.is_ghost
		player.set_gravity_modifier(self.global_gravity_modifier)
	if not self.is_ghost:
		Global.current_game = self
	for value in match_data:
		for player in players.values():
			if player.get(value) != null:
				player.set(value, match_data[value])

	for index in players.keys():
		var player = players[index]
		$Players.add_child(player)
		player.set_color(MultiHustle_get_color_by_index(index))
		player.init()
	
	if match_data.has("selected_styles"):
		for index in players.keys():
			if match_data.selected_styles.has(index):
				var style = match_data.selected_styles[index]
				if self.is_ghost or Custom.can_use_style(index, style):
					players[index].apply_style(style)

	if match_data.has("gravity_enabled"):
		self.gravity_enabled = match_data.gravity_enabled
		for player in players.values():
			player.gravity_enabled = match_data.gravity_enabled



			player.connect("undo", self, "set", ["undoing", true])
			player.connect("super_started", self, "_on_super_started", [player])
			connect_signals(player)
	self.objs_map = {}
	for index in players.keys():
		self.objs_map[str("P", index)] = players[index]
	for player in players.values():
		player.objs_map = self.objs_map
	self.snapping_camera = true
	self.singleplayer = singleplayer
	if singleplayer:
		# Dummy mode is not currently supported
		#if match_data["p2_dummy"]:
		#	players[2].dummy = true
		pass
	elif not self.is_ghost:
		Network.game = self
	if not singleplayer:
		self.started_multiplayer = true
		if Network.multiplayer_active:
			for index in players.keys():
				var username = Network.pid_to_username(index)
				player_usernames[index] = username
				match(index):
					1:
						p1_username = username
					2:
						p2_username = username

			self.my_id = Network.player_id
	self.current_tick = - 1
	if not self.is_ghost:
		if ReplayManager.playback:
			get_max_replay_tick()
		elif not match_data.has("replay"):
			ReplayManager.init()
		else :
			get_max_replay_tick()
			for id in ReplayManager.frame_ids():
				if ReplayManager.frames[id].size() > 0:
					ReplayManager.playback = true

	# Set player positions
	process_player_positions()

	if self.stage_width >= 320:
		self.camera.limit_left = - self.stage_width - 20
		self.camera.limit_right = self.stage_width + 20

	

	#Here is where we have a problem, leaving it be for now
	for index in players.keys():
		var player = players[index]
		var evenModulo = index % 2
		current_opponent_indicies[index] = evenModulo + 1
		player.opponent = players[evenModulo + 1]
		if evenModulo == 0:
			player.set_facing(-1)
	for index in players.keys():
		var player = players[index]
		player.update_data()
		player_datas[index] = player.data
		match(index):
			1:
				p1_data = player.data
			2:
				p2_data = player.data
	#print("PLR DICT: "+str(players))
	apply_hitboxes(players.values())
	if not ReplayManager.resimulating:
		show_state()
	if ReplayManager.playback and not ReplayManager.resimulating and not self.is_ghost:
		yield (get_tree().create_timer(0.5 if not ReplayManager.replaying_ingame else 0.25), "timeout")
	self.game_started = true
	if not self.is_ghost:
		if SteamLobby.is_fighting():
			SteamLobby.on_match_started()

	if match_data.has("starting_meter"):
		var meter_amount = p1.fixed.round(p1.fixed.mul(str(Fighter.MAX_SUPER_METER), match_data.starting_meter))
		for index in players.keys():
			var player = players[index]
			player.gain_super_meter(meter_amount)

func on_prediction(ticks=7, player=null):
	_on_super_started(ticks, player)
	prediction_effect = true
	pass

func update_data():
	set_vanilla_game_started(true)

	for index in players.keys():
		var player = players[index]
		player.update_data()
		player_datas[index] = player.data
		match(index):
			1:
				p1_data = player.data
			2:
				p2_data = player.data

func get_max_replay_tick():
	max_replay_tick = 0
	for id in ReplayManager.frame_ids():
		for tick in ReplayManager.frames[id].keys():
			if tick > max_replay_tick:
				max_replay_tick = tick
	return max_replay_tick

func clean_objects():
	var invalid_objects = []
	for object in objects:
		if !is_instance_valid(object):
			invalid_objects.append(object)
	for object in invalid_objects:
		objects.erase(object)

func initialize_objects():
	for object in objects:
		if !object.initialized:
			object.init()

func process_fx():
	for fx in effects:
		if is_instance_valid(fx):
			fx.tick()

func tick():
	set_vanilla_game_started(true)

	if self.is_ghost and not self.prediction_enabled:
		return
	if self.quitter_focus and self.quitter_focus_ticks > 0:
		if (60 - self.quitter_focus_ticks) % 10 == 0:
			if self.forfeit_player:
				self.forfeit_player.toggle_quit_graphic()
		self.quitter_focus_ticks -= 1
		return
	else :
		if self.forfeit_player:
			self.forfeit_player.toggle_quit_graphic(false)
		self.quitter_focus = false
	self.frame_passed = true
	if not singleplayer:
		if not self.is_ghost:
			Network.reset_action_inputs()

	process_opponents()

	clean_objects()
	for object in self.objects:
		if object.disabled:
			continue
		if not object.initialized:
			object.init()

		object.tick()
		var pos = object.get_pos()
		if pos.x < - self.stage_width:
			object.set_pos( - self.stage_width, pos.y)
		elif pos.x > self.stage_width:
			object.set_pos(self.stage_width, pos.y)
		if self.has_ceiling and pos.y <= - self.ceiling_height:
			object.set_y( - self.ceiling_height)
			object.on_hit_ceiling()

	for fx in self.effects:
		if is_instance_valid(fx):
			fx.tick()
	self.current_tick += 1

	for player_key in range(1, players.size() + 1):
		var player:Fighter = players[player_key]

		player.current_tick = self.current_tick
		
		player.lowest_tick = - 1

	
	var playerPorts = resolve_port_priority()

		
	for player in playerPorts:
		player.tick_before()

	for player in playerPorts:
		player.update_advantage()
	
	for player in playerPorts:
		player.tick()

	resolve_same_x_coordinate()
	initialize_objects()
	for index in players.keys():
		var data = players[index].data
		player_datas[index] = data
		match(index):
			1:
				p1_data = data
			2:
				p2_data = data
	resolve_collisions_all()
	apply_hitboxes(playerPorts)
	for index in players.keys():
		var data = players[index].data
		player_datas[index] = data
		match(index):
			1:
				p1_data = data
			2:
				p2_data = data

	# This needs to be reviewed, not sure how to handle it anyways
	for player in players.values():
		var opponent = player.opponent
		if (opponent.state_interruptable or opponent.dummy_interruptable) and not opponent.busy_interrupt:
			player.reset_combo()


	if self.is_ghost:
		if not self.ghost_hidden:
			if not self.visible and self.current_tick >= 0:
				show()
		return

	if not self.game_finished:
		if ReplayManager.playback:
			if not ReplayManager.resimulating:
				self.is_in_replay = true
				if self.current_tick > self.max_replay_tick and not (ReplayManager.frames.has("finished") and ReplayManager.frames.finished):
					ReplayManager.set_deferred("playback", false)
			else :
				if self.current_tick > (ReplayManager.resim_tick if ReplayManager.resim_tick >= 0 else self.max_replay_tick - 2):
					if not Network.multiplayer_active:
						ReplayManager.playback = false
					ReplayManager.resimulating = false
					self.camera.reset_shake()
	else :
		ReplayManager.frames.finished = true
	if should_game_end():
		if self.started_multiplayer:
			if not ReplayManager.playback:
				Network.autosave_match_replay(match_data, player_usernames[1], player_usernames[2])
		end_game()
	for player in players.values():
		if player.hp <= 0:
			if not(player.game_over):
				Network.team_living[player.team] -= 1
				print("player death:" + str(player.team)+", team_living[]: "+str(Network.team_living))
			
			player.game_over = true
		else:
			player.game_over = false
	
	if not is_ghost:
		var opp = Network.main.uiselectors.selects[2][0].active_char_index
		var opp_target = Network.main.uiselectors.selects[2][0].get_char_name(opp)

		Network.main.uiselectors.opp_target_label.text = "OPP TARGET: %s" % opp_target
var priorities = [
	funcref(self,"state_priority"),
	funcref(self,"comboing"),
	funcref(self,"attacks"),
	funcref(self,"lower_sadness"),
	funcref(self,"forward_movement"),
	funcref(self,"lower_health")
]
func resolve_port_priority(id = false):
	set_vanilla_game_started(true)

	# TODO: Figure out how to implement id properly
	var order = []
	var playerAdded = {}
	for index in players.keys():
		playerAdded[index] = false
	var pairs = get_all_pairs(players.keys())
	for p in self.priorities:
		for pair in pairs:
			var index1 = pair[0]
			var index2 = pair[1]
			var p1 = players[index1]
			var p2 = players[index2]
			var p1_state = p1.current_state()
			var p2_state = p2.current_state()
			var priority = p.call_func(p1_state, p2_state)
			match priority:
				1:
					if !playerAdded[index1]:
						order.append(p1)
						playerAdded[index1] = true
				2:
					if !playerAdded[index2]:
						order.append(p2)
						playerAdded[index2] = true
	for index in players.keys():
		if playerAdded[index] == false:
			order.append(players[index])
	return order

func state_priority(p1_state, p2_state):
	if p1_state.tick_priority < p2_state.tick_priority:
		return 1
	if p2_state.tick_priority < p1_state.tick_priority:
		return 2
	return 0

func comboing(p1_state,p2_state):
	if(p1_state.is_hurt_state):
		return 2
	if(p2_state.is_hurt_state):
		return 1
	return 0

func attacks(p1_state,p2_state):
	var p1_hitboxes = []
	var p2_hitboxes = []
	for c in p1_state.get_children():
		if(c is Hitbox):
			p1_hitboxes.append(c)
	for c in p2_state.get_children():
		if(c is Hitbox):
			p2_hitboxes.append(c)
	if(p1_hitboxes.size()==0 and p2_hitboxes.size()==0):
		return 0
	if(p1_hitboxes.size()==0):
		return 2
	if(p2_hitboxes.size()==0):
		return 1
	var p1_start_tick = 999
	var p2_start_tick = 999
	var p1_damage = 0
	var p2_damage = 0
	for h in p1_hitboxes:
		if(h.start_tick<p1_start_tick):
			p1_start_tick = h.start_tick
			p1_damage = h.damage
	for h in p2_hitboxes:
		if(h.start_tick<p2_start_tick):
			p2_start_tick = h.start_tick
			p2_damage = h.damage
	if(p1_start_tick!=p2_start_tick):
		return 1 if p1_start_tick>p2_start_tick else 2
	if(p1_damage!=p2_damage):
		return 1 if p1_damage>p2_damage else 2
	return 0

func lower_sadness(_1, _2):
	set_vanilla_game_started(true)

	# What even are these parameters!?
	var p1 = players[1]
	var p2 = players[2]
	if (abs(p1.penalty - p2.penalty) < 10):
		return 0
	return 1 if p1.penalty < p2.penalty else 2

func forward_movement(p1_state,p2_state):
	if(p1_state.beats_backdash and !p2_state.beats_backdash):
		return 1
	elif(p1_state.beats_backdash):
		pass
	elif(p2_state.beats_backdash):
		return 2
	return 0

func lower_health(_1, _2):
	set_vanilla_game_started(true)

	# What even are these parameters!?
	var p1 = players[1]
	var p2 = players[2]
	var p1_hp = p1.hp / p1.MAX_HEALTH
	var p2_hp = p2.hp / p2.MAX_HEALTH
	if (p1_hp == p2_hp):
		return 0
	return 1 if p1_hp < p2_hp else 2

func int_abs(n: int):
	if n < 0:
		n *= -1
	return n

func int_clamp(n: int, min_: int, max_: int):
	if n > min_ and n < max_:
		return n
	if n <= min_:
		return min_
	if n >= max_:
		return max_

func should_game_end():
	set_vanilla_game_started(true)
	
	var alive_teams := 4
	alive_teams -= int(calc_team_is_living(1))
	alive_teams -= int(calc_team_is_living(2))
	alive_teams -= int(calc_team_is_living(3))
	alive_teams -= int(calc_team_is_living(4))
	
	
	is_team_win = alive_teams <= 1
	var ffa_living = calc_team_living_count(0)
	var ffa_alive := calc_team_living_count(0) > 0

	#print("alive teams: %d, ffa alive: %s, ffa living count: %d, is team win: %s." % [alive_teams, ffa_alive, ffa_living, is_team_win])

	if (ffa_alive):
		is_team_win = false

		var liveCount = len(players)
		for player in players.values():
			liveCount -= int(player.game_over)
			
		return (self.current_tick > self.time or liveCount <= 1)
	

	return alive_teams <= 1

func resolve_same_x_coordinate():
	set_vanilla_game_started(true)

	for pair in get_all_pairs(players.values()):
		resolve_same_x_coordinate_internal(pair[0], pair[1])

func resolve_collisions(p1, p2, step = 0):
	if step > 0:
		return true
	else:
		var result = resolve_collisions_vanilla(p1, p2, step)
		if result is bool:
			return result
		else:
			return false
func resolve_collisions_vanilla(p1, p2, step=0):
	p1.update_collision_boxes()
	p2.update_collision_boxes()
	var x_pos = p1.data.object_data.position_x
	var opp_x_pos = p2.data.object_data.position_x
	var p1_right_edge = (x_pos + p1.collision_box.width + p1.collision_box.x)
	var p1_left_edge = (x_pos - p1.collision_box.width + p1.collision_box.x)
	var p2_right_edge = (opp_x_pos + p2.collision_box.width + p2.collision_box.x)
	var p2_left_edge = (opp_x_pos - p2.collision_box.width + p2.collision_box.x)
	var edge_distance
	if x_pos < opp_x_pos:
		edge_distance = int_abs(p2_right_edge - p1_left_edge)
	else:
		edge_distance = int_abs(p1_right_edge - p2_left_edge)

	if p1.is_colliding_with_opponent() and p2.is_colliding_with_opponent() and p1.collision_box.overlaps(p2.collision_box):
		var push_p1_left = (p1.get_facing_int() == 1)
		if p1.reverse_state:
			push_p1_left = !push_p1_left
		var push_p2_left = (p1.get_facing_int() == -1)
		if p2.reverse_state:
			push_p2_left = !push_p2_left
		if push_p1_left:
			var edge = p1_right_edge
			var opp_edge = p2_left_edge
			if opp_edge < edge:
				var overlap = int_abs(opp_edge - edge)
				p1.set_x(x_pos - overlap / 2)
				p2.set_x(opp_x_pos + (overlap / 2))
			
		elif push_p2_left:
			var edge = p1_left_edge
			var opp_edge = p2_right_edge
			if opp_edge > edge:
				var overlap = int_abs(opp_edge - edge)
				p1.set_x(x_pos + overlap / 2)
				p2.set_x(opp_x_pos - (overlap / 2))

	if edge_distance > max_char_distance:
		var midpoint = (x_pos + opp_x_pos) / 2
		var left = int_clamp(midpoint - max_char_distance / 2, -stage_width, stage_width)
		var right = int_clamp(midpoint + max_char_distance / 2, -stage_width, stage_width)
		p1.set_x(int_clamp(x_pos, left + (p1.collision_box.width + p1.collision_box.x), right + (-p1.collision_box.width + p1.collision_box.x)))
		p2.set_x(int_clamp(opp_x_pos, left + (p2.collision_box.width + p2.collision_box.x), right + (-p2.collision_box.width + p2.collision_box.x)))
		$Camera2D.reset_smoothing()

	var p1_y_pos = p1.data.object_data.position_y
	var p2_y_pos = p2.data.object_data.position_y
	
	if has_ceiling:
		if p1_y_pos - p1.collision_box.height * 2 < -ceiling_height:
			p1.set_y(-ceiling_height + p1.collision_box.height * 2)
			var vel = p1.get_vel()
			p1.set_vel(vel.x, "0")
		
		if p2_y_pos - p2.collision_box.height * 2 < -ceiling_height:
			p2.set_y(-ceiling_height + p2.collision_box.height * 2)
			var vel = p2.get_vel()
			p2.set_vel(vel.x, "0")
			
	if step < 5:
		if !p1.clipping_wall and x_pos - p1.collision_box.width < -stage_width:
			p1.set_x(-stage_width + p1.collision_box.width)
			p1.update_data()
			p2.update_data()
			return resolve_collisions(p1, p2, step+1)
			
		elif !p1.clipping_wall and x_pos + p1.collision_box.width > stage_width:
			p1.set_x(stage_width - p1.collision_box.width)
			p1.update_data()
			p2.update_data()
			return resolve_collisions(p1, p2, step+1)
			
		if !p2.clipping_wall and opp_x_pos - p2.collision_box.width < -stage_width:
			p2.set_x(-stage_width + p2.collision_box.width)
			p1.update_data()
			p2.update_data()
			return resolve_collisions(p1, p2, step+1)
			
		elif !p2.clipping_wall and opp_x_pos + p2.collision_box.width > stage_width:
			p2.set_x(stage_width - p2.collision_box.width)
			p1.update_data()
			p2.update_data()
			return resolve_collisions(p1, p2, step+1)
		
		if p1.is_colliding_with_opponent() and p2.is_colliding_with_opponent() and p1.collision_box.overlaps(p2.collision_box):
			p1.update_data()
			p2.update_data()
			return resolve_collisions(p1, p2, step+1)
func apply_hitboxes(players):
	set_vanilla_game_started(true)

	var players_w_hitboxes = []
	players_w_hitboxes.resize(len(players))
	for index in len(players):
		var player = players[index]
		players_w_hitboxes[index] = [player, player.get_active_hitboxes()]

	for player in players:
		throws_consumed[player] = null
		players_hittable_dic[player] = true

	# TODO - Prioritize overlaps to selected opponent
	# TODO - Prioritize throw techs in consumption
	for hitboxpair in get_all_pairs(players_w_hitboxes):
		apply_hitboxes_internal(hitboxpair)
	apply_hitboxes_objects(players)

	"""
	for obj in throws_consumed:
		if throws_consumed[obj] != null:
			for hitbox in obj.get_active_hitboxes():
				if hitbox.throw:
					hitbox.deactivate()
					pass
	"""
	# This is to clear out any objects that got added to it
	throws_consumed.clear()
	

# Currently if someone gets caught in a tech crossfire, they just get teched too
# Only use players for throwee, otherwise set throws_consumed directly
func get_colliding_hitbox(hitboxes, hurtbox) -> Hitbox:
	var hit_by = null
	for hitbox in hitboxes:
		if hitbox is Hitbox:
			var host = hurtbox.get_parent()
			if host is ObjectState:
				host = host.host
			var attacker = hitbox.host
			var grounded = (host.is_grounded() if !(hurtbox is Hitbox) else true)
			var otg = (host.is_otg() if !(hurtbox is Hitbox) else false)
			if !hitbox.overlaps(hurtbox):
				var any_collisions = false
				if host and host.current_state():
					for hurtbox_ in host.current_state().get_active_hurtboxes():
						if hitbox.overlaps(hurtbox_):
							any_collisions = true
							break
				if !any_collisions:
					continue
			
			if hitbox is ThrowBox:
				if !host.can_be_thrown():
					if host.is_in_group("Fighter") and host.blockstun_ticks > 0:
						hitbox.save_hit_object(host)
					continue
				if host.is_in_group("Fighter"):
					if host.wakeup_throw_immunity_ticks > 0:
						continue
			if (!hitbox.hits_vs_aerial and !grounded) or (!hitbox.hits_vs_grounded and grounded):
				continue
			if !otg and !hitbox.hits_vs_standing:
				continue
			if otg and not hitbox.hits_otg:
				continue
			if !host.is_in_group("Fighter") and !hitbox.hits_projectiles:
				continue
			if hitbox.already_hit_object(host):
				continue
			if attacker:
				if !attacker.is_grounded():
					if host.aerial_attack_immune:
						continue
				else:
					if host.grounded_attack_immune:
						continue
				if attacker.id == host.id and !hitbox.allowed_to_hit_own_team:
					continue
			hit_by = hitbox

	return hit_by

func is_waiting_on_player():
	set_vanilla_game_started(true)

	if self.forfeit_player != null:
		return false
	if not self.game_started:
		return false
	for player in players.values():
		if not player.game_over:
			if player.state_interruptable:
				return true
	return false


func simulate_until_ready():
	while !is_waiting_on_player():
		tick()
	show_state()

func simulate_one_tick():
	tick()

	show_state()

func resimulate():
	while ReplayManager.resimulating:
		tick()
		show_state()
	show_state()
	if Network.multiplayer_active:
		Network.undo_finished()
#		yield(get_tree().create_timer(1.0), "timeout")

func undo(cut=true):
	ReplayManager.undo(cut)
	game_started = false
	start_playback()

func start_playback():
	ReplayManager.replaying_ingame = true
#	ReplayManager.resimulating = true
	emit_signal("playback_requested")

func end_game():
	set_vanilla_game_started(true)

	if self.game_finished:
		return
	self.game_end_tick = self.current_tick
	self.game_finished = true
	for player in players.values():
		player.game_over = true

	if not self.is_ghost:
		if not ReplayManager.playback and not ReplayManager.replaying_ingame and not self.is_in_replay:
			if not Network.multiplayer_active and not SteamLobby.SPECTATING:
				SteamHustle.unlock_achievement("ACH_CHESS")
		ReplayManager.play_full = true
	var winner = 0
	var losers = []
	var highestHealth = 0
	var lowestHealth = 9223372036854775807
	
	# TODO - Figure out better logic for losers
	if not is_team_win:
		for index in players.keys():
			var player = players[index]
			if player.hp > highestHealth:
				winner = index
				highestHealth = player.hp
			if player.hp < lowestHealth:
				losers.append(index)
				if (player.hp < lowestHealth):
					lowestHealth = player.hp
				
		for loser in losers:
			if get_player(loser).had_sadness:
				if Network.multiplayer_active and winner == Network.player_id:
					SteamHustle.unlock_achievement("ACH_WIN_VS_SADNESS")
		emit_signal("game_ended")

		emit_signal("game_won", winner)

	else:
		for index in Network.teams.keys():
			var count = calc_team_living_count(index)
			if count > 0:
				winner = index
				break
		emit_signal("game_ended")

		emit_signal("team_game_won", winner)

	


func negative_on_hit(player):
	return player.current_state().started_during_combo and !player.opponent.current_state().started_during_combo

func process_tick():
	set_vanilla_game_started(true)

	if self.super_freeze_ticks > 0:
		return

	self.network_simulate_ready = true
	for value in self.network_simulate_readies.values():
		if !value:
			self.network_simulate_ready = value

	var can_tick = not Global.frame_advance or (self.advance_frame_input)
	if can_tick:
		self.advance_frame_input = false
	if not Global.frame_advance:
		if Global.playback_speed_mod > 0:
			can_tick = self.real_tick % Global.playback_speed_mod == 0
	if (Network.multiplayer_active) and not self.ghost_tick and not self.spectating:
		can_tick = self.network_simulate_ready
	if ReplayManager.resimulating:
		ReplayManager.playback = true
		can_tick = true

	if not ReplayManager.playback:
		if not is_waiting_on_player():
				if can_tick:

					if not Global.frame_advance:
						self.snapping_camera = true
					call_deferred("simulate_one_tick")


					for index in players.keys():
						player_turns[index] = false
						match(index):
							1:
								p1_turn = false
							2:
								p2_turn = false
					if self.game_paused:
						if Network.multiplayer_active:
							Network.can_open_action_buttons = false
					self.game_paused = false
		else :
			ReplayManager.frames.finished = false
			self.game_paused = true
			var someones_turn = false
			var turn_trigger = false
			for index in players.keys():
				var player = players[index]
				if player.state_interruptable && !player_turns[index]:
					turn_trigger = true
					break
			if turn_trigger:
				for index in players.keys():
					var player = players[index]
					player.busy_interrupt = ( not player.state_interruptable and not (player.current_state().interruptible_on_opponent_turn or player.feinting or negative_on_hit(player)))
					if not player.busy_interrupt:
						player.current_state().on_interrupt()
					player.state_interruptable = true;
					player.show_you_label()
					player_turns[index] = true
					match index:
						1:
							self.p1_turn = true
						2:
							self.p2_turn = true

				if singleplayer:
					emit_signal("player_actionable")
				elif not is_ghost:
					someones_turn = true
				player_actionable = true

			if someones_turn:
				ReplayManager.replaying_ingame = false
				if Network.multiplayer_active:
					if self.network_sync_tick != self.current_tick:
						Network.rpc_("end_turn_simulation", [self.current_tick, Network.player_id])
						self.network_sync_tick = self.current_tick
						for key in self.network_simulate_readies.keys():
							if not self.players[key].game_over:
								self.network_simulate_readies[key] = false
						self.network_simulate_ready = false
						Network.sync_unlock_turn()
						Network.on_turn_started()

	else:
		if ReplayManager.resimulating:
			self.snapping_camera = true
			call_deferred("resimulate")
			yield (get_tree(), "idle_frame")
			self.game_paused = false
		else:
			if self.buffer_edit:
				ReplayManager.playback = false
				ReplayManager.cut_replay(self.current_tick)
				self.buffer_edit = false
			if can_tick:
				call_deferred("simulate_one_tick")

func _process(delta):

	for quitter in quitters:
		Network.main.ui_layer.silent_end_turn_for(quitter)
		Network.sync_unlocks[quitter] = true
		Network.turns_ready[quitter] = true
		network_simulate_readies[quitter] = true

	set_vanilla_game_started(true)

	update()
	super_dim()
	if self.camera.global_position.y > self.camera.limit_bottom - .get_viewport_rect().size.y / 2:
		self.camera.global_position.y = self.camera.limit_bottom - .get_viewport_rect().size.y / 2
	if self.camera.global_position.x > self.camera.limit_right - .get_viewport_rect().size.x / 2:
		self.camera.global_position.x = self.camera.limit_right - .get_viewport_rect().size.x / 2
	if self.camera.global_position.x < self.camera.limit_left + .get_viewport_rect().size.x / 2:
		self.camera.global_position.x = self.camera.limit_left + .get_viewport_rect().size.x / 2

	if is_instance_valid(ghost_game):
		ghost_game.camera_zoom = self.camera_zoom
		ghost_game.update_camera_limits()

	if self.game_started and not self.is_ghost:
		self.camera.zoom = Vector2.ONE
		var hurtboxCenterYs = []
		for player in players.values():
			hurtboxCenterYs.append(player.get_hurtbox_center().y)
		var lowy = hurtboxCenterYs[0]
		var highy = hurtboxCenterYs[0]
		for y in hurtboxCenterYs:
			if y < lowy:
				lowy = y
			if y > highy:
				highy = y
		var dist = highy - lowy
		if dist > 210:
			var dist_ratio = dist / float(210)
			self.camera.zoom = Vector2.ONE * dist_ratio
		self.camera.zoom *= self.camera_zoom
	if is_instance_valid(ghost_game):
		ghost_game.camera.zoom = self.camera.zoom
		ghost_game.camera.position = self.camera.position
		ghost_game.camera.position = self.camera.position

	self.camera_snap_position = self.camera.position

	if is_ghost and Global.ghost_speed > 2:
		var current_time = Time.get_unix_time_from_system()
		var ghost_delta = current_time - ghost_time
		var fps = 60
		var fixed_delta = 1.0 / fps
		var min_delta = fixed_delta * (1.0 / Global.get_ghost_speed_modifier())
		if ghost_delta >= min_delta:
			ghost_time = current_time
			if ghost_actionable_freeze_ticks > 0:
				pass
			else :
				for i in range(floor(ghost_delta / min_delta)):
					call_deferred("ghost_tick")

	set_vanilla_game_started(false)

func _physics_process(_delta):
	set_vanilla_game_started(true)

	if self.forfeit:
		self.game_paused = false
		self.game_finished = true
	self.camera.tick()
	self.real_tick += 1
	if not $GhostStartTimer.is_stopped():
		set_vanilla_game_started(false)
		return
	if self.undoing:
		#.undo() # Allow vanilla handler to manage this one
		set_vanilla_game_started(false)
		return
	if not self.game_started:
		set_vanilla_game_started(false)
		return

	if not self.is_ghost:
		if not self.game_finished:
			if ReplayManager.playback:
				for i in range(1):
					process_tick()
			else :
				process_tick()
		else :
			call_deferred("simulate_one_tick")
			if self.current_tick >= self.game_end_tick + 120:
				start_playback()
	else :
		if self.ghost_actionable_freeze_ticks > 0:
			self.ghost_actionable_freeze_ticks -= 1
			if self.ghost_actionable_freeze_ticks == 0:
				emit_signal("make_afterimage")
		elif Global.ghost_speed <= 2:
			call_deferred("ghost_tick")

	self.super_active = self.super_freeze_ticks > 0
	if self.super_freeze_ticks > 0:
		self.super_freeze_ticks -= 1
		if self.super_freeze_ticks == 0:
			self.super_active = false
			for index in players.keys():
				player_supers[index] = false
				match(index):
					1:
						p1_super = false
					2:
						p2_super = false
			self.parry_freeze = false
			prediction_effect = false

	if not is_waiting_on_player():
		emit_signal("simulation_continue")
		if self.player_actionable and not self.is_ghost and Network.multiplayer_active:
			Network.sync_tick()
		self.player_actionable = false

	if not self.is_ghost:
		if self.snapping_camera:
			var target = Vector2(0, 0)
			if self.camera.focused_object:
				target = self.camera.focused_object.get_center_position_float()
			elif self.forfeit_player:
				target = self.forfeit_player.global_position
			else:
				for player in players.values():
					if player.game_over:
						continue
					
					target += player.global_position
				target /= len(players)
			if self.camera.global_position.distance_squared_to(target) > 10:
				self.camera.global_position = lerp(self.camera.global_position, target, 0.28)
	if is_instance_valid(ghost_game):
		ghost_game.camera.global_position = self.camera.global_position

	self.waiting_for_player_prev = is_waiting_on_player()

	if not self.is_ghost and self.buffer_playback:
		ReplayManager.resimulating = false
		self.game_finished = false
		emit_signal("simulation_continue")
		start_playback()

	if self.spectating and not self.is_ghost and not ReplayManager.play_full:
		for id in ReplayManager.frame_ids():
			for input_tick in ReplayManager.frames[id].keys():
				if self.current_tick == input_tick - 1:


					var input = ReplayManager.frames[id][input_tick]
					get_player(id).on_action_selected(input.action, input.data, input.extra)

	set_vanilla_game_started(false)

func ghost_tick():
	set_vanilla_game_started(true)



	var simulate_frames = 1
	if self.ghost_speed == 1:
		simulate_frames = 1 if self.ghost_tick % 4 == 0 else 0
	self.ghost_tick += 1






	p1.grounded_indicator.hide()
	p2.grounded_indicator.hide()
	for i in range(simulate_frames):
		if self.ghost_actionable_freeze_ticks == 0:
			ghost_simulated_ticks += 1
			simulate_one_tick()
		if self.current_tick > GHOST_FRAMES:
			emit_signal("ghost_finished")

		# REVIEW - This could probably be optimized
		for index in players.keys():
			var p1 = players[index]
			if p1.ghost_blocked_melee_attack > 0 and not p1.block_frame_label.visible:
				p1.block_frame_label.show()
				p1.block_frame_label.text = "Parry %s @ %sf" % [p1.ghost_wrong_block, p1.ghost_blocked_melee_attack]

			var p1_tick = ghost_simulated_ticks + (p1.hitlag_ticks if not is_other_ghost_actionable(index) else 0)
			if (p1.state_interruptable or p1.dummy_interruptable or p1.state_hit_cancellable) and not ghost_player_actionables[index]:
				player_ghost_ready_tick[index] = p1_tick
			else :
				player_ghost_ready_tick[index] = null
			if p1.ghost_got_hit and not p1.hit_frame_label.visible:
				p1.hit_frame_label.show()
				p1.hit_frame_label.text = "Hit @ %sf" % p1.turn_frames
			if (ghost_simulated_ticks == player_ghost_ready_tick[index]):
				p1.ghost_ready_tick = player_ghost_ready_tick[index]
				player_ghost_ready_tick[index] = null
				ghost_player_actionables[index] = true
				match(index):
					1:
						ghost_p1_actionable = true
					2:
						ghost_p2_actionable = true
				p1.set_ghost_colors()
				if self.ghost_freeze:
					self.ghost_actionable_freeze_ticks = GHOST_ACTIONABLE_FREEZE_TICKS
				else :
					self.ghost_actionable_freeze_ticks = 1
				if not p1.actionable_label.visible:
					p1.actionable_label.show()
					p1.actionable_label.text = "Ready\nin %sf" % p1.turn_frames
					p1.grounded_indicator.visible = p1.is_grounded() and p1.ghost_was_in_air

				emit_signal("ghost_my_turn")
				for index2 in players.keys():
					var p2 = players[index2]
					if p2.current_state().interruptible_on_opponent_turn or p2.feinting or negative_on_hit(p2):
						if not p2.actionable_label.visible:
							p2.actionable_label.show()
							if p2.current_state().anim_length == p2.current_state().current_tick + 1 or p2.current_state().iasa_at == p2.current_state().current_tick:
								p2.actionable_label.text = "Ready\nin %sf" % p2.turn_frames
							else :
								p2.actionable_label.text = "Interrupt\nin %sf" % p2.turn_frames

							p2.grounded_indicator.visible = p2.is_grounded() and p2.ghost_was_in_air
						ghost_player_actionables[index2] = true
						match(index2):
							1:
								ghost_p1_actionable = true
							2:
								ghost_p2_actionable = true

func super_dim():
	pass

func update_mouse_world_position():
	Global.mouse_world_position = Global.screen_to_world(get_local_mouse_position())
	pass

func _unhandled_input(event: InputEvent):
	if is_afterimage:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			drag_position = camera.get_local_mouse_position()
			mouse_pressed = true
			raise()
		else:
			mouse_pressed = false
			drag_position = null
	if event is InputEventMouseMotion:
		if drag_position and ((is_waiting_on_player() and !ReplayManager.playback) or Global.frame_advance):
			camera.global_position -= event.relative
			snapping_camera = false
		
	if !is_ghost and singleplayer:
			if event.is_action_pressed("playback"):
				if !game_finished and !ReplayManager.playback:
					if is_waiting_on_player() and current_tick > 0:
						buffer_playback = true
			if event.is_action_pressed("edit_replay"):
				if ReplayManager.playback:
					buffer_edit = true
					ReplayManager.play_full = false
	if !is_ghost:
		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == BUTTON_WHEEL_UP:
					zoom_in()
				if event.button_index == BUTTON_WHEEL_DOWN:
					zoom_out()
	update_mouse_world_position()

func update_camera_limits():
	if camera_zoom == 1.0 and stage_width > 320:
		camera.limit_left = -stage_width - CAMERA_PADDING
		camera.limit_right = stage_width + CAMERA_PADDING
	else:
		camera.limit_left = -10000000
		camera.limit_right = 10000000
	if is_instance_valid(ghost_game):
		ghost_game.update_camera_limits()
		

func zoom_in():
	emit_signal("zoom_changed")
	camera_zoom -= 0.1
	if camera_zoom < 0.2:
		camera_zoom = 0.2
	update_camera_limits()


func zoom_out():
	emit_signal("zoom_changed")
	camera_zoom += 0.1
	if camera_zoom > 3.0:
		camera_zoom = 3.0
	update_camera_limits()

func reset_zoom():
	camera_zoom = 1.0
	emit_signal("zoom_changed")
	update_camera_limits()

func _draw():
	if is_ghost:
		return
	if !snapping_camera and mouse_pressed:
		draw_circle(camera.position, 3, Color.white * 0.5)
	if draw_stage:
		var line_color = Color.white
		var ceiling_draw_height = -100000 if !has_ceiling else -ceiling_height 
		draw_line(Vector2(-stage_width, 0), Vector2(stage_width, 0), line_color, 2.0)
	#	if stage_width < 320 or camera_zoom != 1.0:
		draw_line(Vector2(-stage_width, 0), Vector2(-stage_width, ceiling_draw_height), line_color, 2.0)
		draw_line(Vector2(stage_width, 0), Vector2(stage_width, ceiling_draw_height), line_color, 2.0)
		if has_ceiling:
			draw_line(Vector2(-stage_width, ceiling_draw_height), Vector2(stage_width, ceiling_draw_height), line_color, 2.0)
		var line_dist = 50
		var small_line_dist = 10
		var num_lines = stage_width * 2 / line_dist
		for i in range(num_lines):
			var x = i * (((stage_width * 2)) / float(num_lines)) - stage_width
			draw_line(Vector2(x, 0), Vector2(x, 10), line_color, 2.0)
		num_lines = stage_width * 2 / small_line_dist
#		for i in range(num_lines):
#			var c = line_color
#			c.a = 0.25
#			var x = i * (((stage_width * 2)) / float(num_lines)) - stage_width
#			draw_line(Vector2(x, 0), Vector2(x, 5), c, 2.0)
		draw_line(Vector2(stage_width, 0), Vector2(stage_width, 10), line_color, 2.0)
	
#	draw_circle(to_local(Global.mouse_world_position), 5, Color.white)
#	draw_circle(get_local_mouse_position(), 5, Color.blue)
	custom_draw_func()

func custom_draw_func():
	pass

func show_state():
	set_vanilla_game_started(true)

	for player in players.values():
		player.position = player.get_pos_visual()
		player.update()
	for object in self.objects:
		object.position = object.get_pos_visual()
		object.update()



func _debug_throw(event: String, payload := {}):
	if not DEBUG_THROW_ROUTING:
		return
	var tag = "[Ghost]" if self.is_ghost else "[Main]"
	print("%s %s %s" % [tag, event, payload])




func MultiHustle_get_color_by_index(index):
	# TODO - Add more auto-colors
	if !player_colors.has(index):
		match index:
			1:
				player_colors[index] = Color("aca2ff")
			2:
				player_colors[index] = Color("ff7a81")
			3:
				player_colors[index] = Color("8effe9")
			4:
				player_colors[index] = Color("ddff8e")
			_: # This SHOULD be deterministic, but I could see something going wrong.
				player_colors[index] = Color(color_rng.randf(), color_rng.randf(), color_rng.randf())
	return player_colors[index]



func process_player_positions():
	var height = 0
	if match_data.has("char_height"):
		height = - match_data.char_height

	var tempDistance = self.char_distance
	var alternation: bool = false

	var team_pos_data = calc_player_order()

	if not is_ghost:
		print("team_pos_data: "+str(team_pos_data))

	match team_pos_data.size():
		1:
			for player in players.values():
				if alternation == false:
					player.set_pos(-tempDistance, height)
					alternation = true
				else:
					player.set_pos(tempDistance, height)
					tempDistance = (self.char_distance * 2) + tempDistance
					alternation = false

				player.stage_width = self.stage_width
		2:
			for idx in team_pos_data[0]:
				var player = players[idx]
				
				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width

			tempDistance = self.char_distance

			for idx in team_pos_data[1]:
				var player = players[idx]
				
				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
		4:
			for idx in team_pos_data[0]:
				var player = players[idx]
				
				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width

			tempDistance = self.char_distance + tempDistance

			for idx in team_pos_data[1]:
				var player = players[idx]
				
				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width

			tempDistance = self.char_distance

			for idx in team_pos_data[2]:
				var player = players[idx]
				
				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
			
			tempDistance = self.char_distance + tempDistance
			
			for idx in team_pos_data[3]:
				var player = players[idx]
				
				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
		3:
			for idx in team_pos_data[0]:
				var player = players[idx]
				
				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width


			tempDistance = self.char_distance + tempDistance
			for idx in team_pos_data[1]:
				var player = players[idx]

				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width	
				tempDistance = self.char_distance

			tempDistance = self.char_distance

			for idx in team_pos_data[2]:
				var player = players[idx]
				
				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
		5:
			for idx in team_pos_data[0]:
				var player = players[idx]
				
				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
			
			tempDistance = self.char_distance + tempDistance

			for idx in team_pos_data[1]:
				var player = players[idx]
				
				player.set_pos(tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width

			tempDistance = self.char_distance

			for idx in team_pos_data[2]:
				var player = players[idx]

				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

			tempDistance = self.char_distance + tempDistance
			for idx in team_pos_data[3]:
				var player = players[idx]
				
				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
				
			tempDistance = self.char_distance + tempDistance

			for idx in team_pos_data[4]:
				var player = players[idx]
				
				player.set_pos(-tempDistance, height)
				tempDistance = self.char_distance + tempDistance

				player.stage_width = self.stage_width
	



func calc_team_is_living(var team:int) -> bool:
	var team_alive = Network.team_living[team]
	
	return team_alive < 1



func calc_team_living_count(var team:int) -> int:
	var team_alive = Network.team_living[team]
	
	return team_alive

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



func resolve_same_x_coordinate_internal(p1, p2):
	# Consider temporary variable assignment and base calling instead
	var p1_pos = p1.get_pos()
	var p2_pos = p2.get_pos()
	if p1_pos.x == p2_pos.x:
		var player_to_move = p1 if self.current_tick % 2 == 0 else p2
		var direction_to_move = 1 if self.current_tick % 2 == 0 else - 1
		var x = p1_pos.x
		if x < 0:
			direction_to_move = 1
			if p1.get_facing_int() == - 1:
				player_to_move = p1
			elif p2.get_facing_int() == - 1:
				player_to_move = p2
		elif x > 0:
			direction_to_move = - 1
			if p1.get_facing_int() == 1:
				player_to_move = p1
			elif p2.get_facing_int() == 1:
				player_to_move = p2
		player_to_move.set_x(player_to_move.get_pos().x + direction_to_move)
		player_to_move.update_data()



func resolve_collisions_all(step = 0):
	var repeat = false
	for pair in get_all_pairs(players.values()):
		repeat = repeat or resolve_collisions(pair[0], pair[1], 0)
	if repeat and step < 5:
		return resolve_collisions_all(step + 1)



# Currently if someone gets caught in a tech crossfire, they just get teched too
# Only use players for throwee, otherwise set throws_consumed directly
func consume_throw_by(thrower, throwee, is_tech):
	if !throws_consumed.has(thrower):
		throws_consumed[thrower] = null
	consume_throw_propagate(throwee)
	if !is_tech:
		var current = throws_consumed[thrower]
		if current == null:
			current = []
		if current is Array:
			if not current.has(throwee):
				current.append(throwee)
				_register_players_getting_throwed(thrower, throwee)
		throws_consumed[thrower] = current
	else:
		thrower.state_machine.queue_state("ThrowTech")
		throws_consumed[thrower] = true
		_unregister_players_getting_throwed(thrower)
func consume_throw_propagate(throwee):
	if !throws_consumed.has(throwee):
		return
	var throwee_targets = throws_consumed[throwee]
	if throwee_targets == null or throwee_targets == true:
		return
	if throwee_targets is Array:
		throws_consumed[throwee] = true
		#_unregister_players_getting_throwed(throwee)
		for target in throwee_targets:
			if is_instance_valid(target):
				target.state_machine.queue_state("ThrowTech")
				consume_throw_propagate(target)

func _register_players_getting_throwed(thrower, throwee):
	if thrower == null or throwee == null:
		return
	if not thrower.is_in_group("Fighter") or not throwee.is_in_group("Fighter"):
		return
	var thrower_id = thrower.id
	var throwee_id = throwee.id
	if thrower_id == null or throwee_id == null:
		return
	if not players_getting_throwed.has(thrower_id):
		players_getting_throwed[thrower_id] = []
	if not players_getting_throwed[thrower_id].has(throwee_id):
		players_getting_throwed[thrower_id].append(throwee_id)

func _unregister_players_getting_throwed(thrower, throwee = null):
	if thrower == null:
		return
	if not thrower.is_in_group("Fighter"):
		return
	var thrower_id = thrower.id
	if thrower_id == null:
		return
	if not players_getting_throwed.has(thrower_id):
		return
	if throwee == null:
		players_getting_throwed.erase(thrower_id)
		return
	if not throwee.is_in_group("Fighter"):
		return
	var throwee_id = throwee.id
	if throwee_id == null:
		return
	players_getting_throwed[thrower_id].erase(throwee_id)
	if players_getting_throwed[thrower_id].empty():
		players_getting_throwed.erase(thrower_id)

func _thrower_locked_out(thrower):
	if thrower == null:
		return false
	if !throws_consumed.has(thrower):
		return false
	if throws_consumed[thrower] is Array:
		return true
	return throws_consumed[thrower] == true

func _thrower_has_target(thrower, target):
	if thrower == null or target == null:
		return false
	if !throws_consumed.has(thrower):
		return false
	var value = throws_consumed[thrower]
	return value is Array and value.has(target)

# throws_consumed is handled by instance, but may be passed by reference in the future


func apply_hitboxes_internal(playerhitboxpair:Array):
	var pair1 = playerhitboxpair[0]
	var pair2 = playerhitboxpair[1]
	var px1 = pair1[0]
	var px2 = pair2[0]

	var p1_hitboxes = pair1[1]
	var p2_hitboxes = pair2[1]

	var p1_pos = px1.get_pos()
	var p2_pos = px2.get_pos()

	for hitbox in p1_hitboxes:
		hitbox.update_position(p1_pos.x, p1_pos.y)
	for hitbox in p2_hitboxes:
		hitbox.update_position(p2_pos.x, p2_pos.y)

	var p2_hit_by = get_colliding_hitbox(p1_hitboxes, px2.hurtbox) if not px2.invulnerable else null
	var p1_hit_by = get_colliding_hitbox(p2_hitboxes, px1.hurtbox) if not px1.invulnerable else null
	var p1_hit = false
	var p2_hit = false
	var p1_throwing = false
	var p2_throwing = false

	if p1_hit_by:
		if not (p1_hit_by is ThrowBox):
			p1_hit = true
		else :
			p2_throwing = true
			if DEBUG_THROW_ROUTING:
				_debug_throw("throw_contact", {
					"attacker": px2.name,
					"defender": px1.name,
					"hitbox": p1_hit_by.name
				})

	if p2_hit_by:
		if not (p2_hit_by is ThrowBox):
			p2_hit = true
		else :
			p1_throwing = true
			if DEBUG_THROW_ROUTING:
				_debug_throw("throw_contact", {
					"attacker": px1.name,
					"defender": px2.name,
					"hitbox": p2_hit_by.name
				})

	var clash_position = Vector2()
	var clashed = false
	if clashing_enabled:
		for p1_hitbox in p1_hitboxes:
			if p1_hitbox is ThrowBox:
				continue
			if not p1_hitbox.can_clash:
				continue
			var p2_hitbox = get_colliding_hitbox(p2_hitboxes, p1_hitbox)
			if p2_hitbox:
				if p2_hitbox is ThrowBox:
					continue
				if not p2_hitbox.can_clash:
					continue
				var valid_clash = false



				if self.asymmetrical_clashing:
					if p1_hit and not p2_hit:
						if p1_hitbox.damage - p2_hitbox.damage < 40:
							valid_clash = true

					if p2_hit and not p1_hit:
						if p2_hitbox.damage - p1_hitbox.damage < 40:
							valid_clash = true

				if ( not p1_hit and not p2_hit) or (p1_hit and p2_hit):
					if Utils.int_abs(p2_hitbox.damage - p1_hitbox.damage) < 40:
						valid_clash = true
					elif p1_hitbox.damage > p2_hitbox.damage:
						p1_hit = false
						clash_position = p2_hitbox.get_center_float()
						_spawn_particle_effect(preload("res://fx/ClashEffect.tscn"), clash_position)
					elif p1_hitbox.damage < p2_hitbox.damage:
						clash_position = p1_hitbox.get_center_float()
						_spawn_particle_effect(preload("res://fx/ClashEffect.tscn"), clash_position)
						p2_hit = false

				if valid_clash:
					clashed = true
					clash_position = p2_hitbox.get_overlap_center_float(p1_hitbox)

					break

	if clashed:
		px1.clash()
		px2.clash()
		px1.add_penalty( - 25)
		px2.add_penalty( - 25)
		_spawn_particle_effect(preload("res://fx/ClashEffect.tscn"), clash_position)
	else :
		if p1_hit:
				if not (p1_throwing and not p1_hit_by.beats_grab):
					MH_wrapped_hit(p1_hit_by, px1)
				else :
					p1_hit = false
		if p2_hit:
				if not (p2_throwing and not p2_hit_by.beats_grab):
					MH_wrapped_hit(p2_hit_by, px2)
				else :
					p2_hit = false

	# REVIEW: Make sure this new system isn't gonna merc anything.
	#var players_hittable = true
	var players_hittable = true
	if DEBUG_THROW_ROUTING:
		_debug_throw("pair_evaluated", {
			"p1": px1.name,
			"p2": px2.name,
			"p1_throwing": p1_throwing,
			"p2_throwing": p2_throwing,
			"p1_hit": p1_hit_by != null,
			"p2_hit": p2_hit_by != null
		})

	if not p2_hit and not p1_hit:
		if p2_throwing and p1_throwing and px1.current_state().throw_techable and px2.current_state().throw_techable:
				#px1.state_machine.queue_state("ThrowTech")
				#px2.state_machine.queue_state("ThrowTech")
				consume_throw_by(px1, px2, true)
				consume_throw_by(px2, px1, true)
				#players_hittable = false
				players_hittable_dic[px1] = false
				players_hittable_dic[px2] = false

		elif p2_throwing and p1_throwing and not px1.current_state().throw_techable and not px2.current_state().throw_techable:
			#players_hittable = false
			players_hittable_dic[px1] = false
			players_hittable_dic[px2] = false

		elif p1_throwing:
			if px1.current_state().throw_techable and px2.current_state().throw_techable:
				#px1.state_machine.queue_state("ThrowTech")
				#px2.state_machine.queue_state("ThrowTech")
				consume_throw_by(px1, px2, true)
				consume_throw_by(px2, px1, true)
				#players_hittable = false
				players_hittable_dic[px1] = false
				players_hittable_dic[px2] = false

			var can_hit = true
			var fail_reasons = []
			var victim_state = px2.current_state()
			var victim_grabbed = victim_state and victim_state.state_name == "Grabbed"
			var debug_payload = null
			if DEBUG_THROW_ROUTING:
				debug_payload = {
					"thrower": px1.name,
					"target": px2.name,
					"victim_state": victim_state.state_name if victim_state else "",
					"grounded": px2.is_grounded(),
					"hits_vs_grounded": p2_hit_by.hits_vs_grounded,
					"hits_vs_aerial": p2_hit_by.hits_vs_aerial,
					"players_hittable": MH_players_hittable(px1, px2)
				}
			if px2.is_grounded() and not p2_hit_by.hits_vs_grounded:
				can_hit = false
				fail_reasons.append("grounded_block")
			if not px2.is_grounded() and not p2_hit_by.hits_vs_aerial:
				can_hit = false
				fail_reasons.append("aerial_block")
			if not MH_players_hittable(px1, px2):
				can_hit = false
				fail_reasons.append("players_hittable")

			if not can_hit and p2_hit_by.throw and victim_grabbed:
				fail_reasons.append("override_grabbed")
				can_hit = true
				if DEBUG_THROW_ROUTING and debug_payload:
					debug_payload["reasons"] = fail_reasons.duplicate()
					_debug_throw("throw_override", debug_payload)

			if can_hit:
				var locked_out = _thrower_locked_out(px1)
				var has_target = _thrower_has_target(px1, px2)
				if locked_out or has_target:
					if DEBUG_THROW_ROUTING and debug_payload:
						debug_payload["locked_out"] = locked_out
						debug_payload["has_target"] = has_target
						_debug_throw("throw_blocked", debug_payload)
					return
				MH_wrapped_hit(p2_hit_by, px2)
				if p2_hit_by.throw_state:
					if DEBUG_THROW_ROUTING and debug_payload:
						debug_payload["throw_state"] = p2_hit_by.throw_state
						_debug_throw("queue_throw_state", debug_payload)
					px1.state_machine.queue_state(p2_hit_by.throw_state)
					# NOTE - This allows for a character to have special MultiHustle grab handling
					if p2_hit_by.throw_state.begins_with("MH_"):
						return [px1, "MH_Grab"]
				consume_throw_by(px1, px2, false)
				#players_hittable = false
				_mark_players_unhittable(px1, px2, p2_hit_by)
			elif DEBUG_THROW_ROUTING and debug_payload:
				debug_payload["reasons"] = fail_reasons
				_debug_throw("throw_gated", debug_payload)


		elif p2_throwing:
			if px1.current_state().throw_techable and px2.current_state().throw_techable:
				#px1.state_machine.queue_state("ThrowTech")
				#px2.state_machine.queue_state("ThrowTech")
				consume_throw_by(px1, px2, true)
				consume_throw_by(px2, px1, true)
				#players_hittable = false
				players_hittable_dic[px1] = false
				players_hittable_dic[px2] = false
			var can_hit = true
			var fail_reasons = []
			var victim_state = px1.current_state()
			var victim_grabbed = victim_state and victim_state.state_name == "Grabbed"
			var debug_payload = null
			if DEBUG_THROW_ROUTING:
				debug_payload = {
					"thrower": px2.name,
					"target": px1.name,
					"victim_state": victim_state.state_name if victim_state else "",
					"grounded": px1.is_grounded(),
					"hits_vs_grounded": p1_hit_by.hits_vs_grounded,
					"hits_vs_aerial": p1_hit_by.hits_vs_aerial,
					"players_hittable": MH_players_hittable(px1, px2)
				}
			if px1.is_grounded() and not p1_hit_by.hits_vs_grounded:
				can_hit = false
				fail_reasons.append("grounded_block")
			if not px1.is_grounded() and not p1_hit_by.hits_vs_aerial:
				can_hit = false
				fail_reasons.append("aerial_block")
			if not MH_players_hittable(px1, px2):
				can_hit = false
				fail_reasons.append("players_hittable")

			if not can_hit and p1_hit_by.throw and victim_grabbed:
				fail_reasons.append("override_grabbed")
				can_hit = true
				if DEBUG_THROW_ROUTING and debug_payload:
					debug_payload["reasons"] = fail_reasons.duplicate()
					_debug_throw("throw_override", debug_payload)

			if can_hit:
				var locked_out = _thrower_locked_out(px2)
				var has_target = _thrower_has_target(px2, px1)
				if locked_out or has_target:
					if DEBUG_THROW_ROUTING and debug_payload:
						debug_payload["locked_out"] = locked_out
						debug_payload["has_target"] = has_target
						_debug_throw("throw_blocked", debug_payload)
					return
				MH_wrapped_hit(p1_hit_by, px1)
				if p1_hit_by.throw_state:
					if DEBUG_THROW_ROUTING and debug_payload:
						debug_payload["throw_state"] = p1_hit_by.throw_state
						_debug_throw("queue_throw_state", debug_payload)
					px2.state_machine.queue_state(p1_hit_by.throw_state)
					# NOTE - This allows for a character to have special MultiHustle grab handling
					if p1_hit_by.throw_state.begins_with("MH_"):
						return [px2, "MH_Grab"]
				consume_throw_by(px2, px1, false)
				#players_hittable = false
				_mark_players_unhittable(px2, px1, p1_hit_by)
			elif DEBUG_THROW_ROUTING and debug_payload:
				debug_payload["reasons"] = fail_reasons
				_debug_throw("throw_gated", debug_payload)




func apply_hitboxes_objects(players:Array):
	# REVIEW - Literally everything here
	var objects_to_hit = []
	var objects_hit_each_other = false
	var player_hit_object = false
	var players_to_hit = []
	var objects_hit_player = false

	for object in self.objects:
		if object.disabled:
			continue


		var o_hitboxes = object.get_active_hitboxes()

		var o_pos = object.get_pos()

		for hitbox in o_hitboxes:
			hitbox.update_position(o_pos.x, o_pos.y)

		for p in players:
			if !players_hittable_dic[p]:
				continue
			# This should always be the same as the player index
			var index = p.id
			var p_hit_by
			if object.id == index and not object.damages_own_team:
				continue

			var can_be_hit_by_melee = object.get("can_be_hit_by_melee")

			if p:
				var obj_hit_by = get_colliding_hitbox(p.get_active_hitboxes(), object.hurtbox)
				if obj_hit_by and (can_be_hit_by_melee or obj_hit_by.hitbox_type == Hitbox.HitboxType.Detect):
					player_hit_object = true
					objects_to_hit.append([obj_hit_by, object])

				if p.projectile_invulnerable and object.get("immunity_susceptible"):
					continue

				var hitboxes = object.get_active_hitboxes()
				p_hit_by = get_colliding_hitbox(hitboxes, p.hurtbox)
				if p_hit_by:
					players_to_hit.append([p_hit_by, p])
					objects_hit_player = true

		# REVIEW: Make sure this works properly
		var opp_objects = []

		for opp_object in self.objects:
			if opp_object.disabled:
				continue
			if opp_object.id != object.id:
				opp_objects.append(opp_object)

		if not object.projectile_immune:
			for opp_object in opp_objects:
				var obj_hit_by
				var obj_hitboxes = opp_object.get_active_hitboxes()
				obj_hit_by = get_colliding_hitbox(obj_hitboxes, object.hurtbox)
				if obj_hit_by:
					objects_hit_each_other = true
					objects_to_hit.append([obj_hit_by, object])

	if objects_hit_each_other or player_hit_object:
		for pair in objects_to_hit:
			var hitbox = pair[0]
			var target = pair[1]
			var host = hitbox.host
			if hitbox.throw || hitbox is ThrowBox:
				if not _thrower_locked_out(host) and not _thrower_has_target(host, target):
					MH_wrapped_hit(hitbox, target)
					# I'm genuinely not even sure what or how to handle this
			else:
				MH_wrapped_hit(hitbox, target)
	if objects_hit_player:
		for pair in players_to_hit:
			var hitbox = pair[0]
			var target = pair[1]
			var host = hitbox.host
			if hitbox.throw || hitbox is ThrowBox:
				if not _thrower_locked_out(host) and not _thrower_has_target(host, target):
					MH_wrapped_hit(hitbox, target)
					consume_throw_by(host, target, false)
			else:
				MH_wrapped_hit(hitbox, target)



func MH_wrapped_hit(hitbox, target):
	var host = hitbox.host
	var result
	var restore_opponent = !(hitbox.throw or hitbox is ThrowBox)
	if not target.get("opponent") == null:
		var opponentTemp = target.opponent
		if host.is_in_group("Fighter"):
			target.opponent = host
		elif host.fighter_owner:
			target.opponent = host.fighter_owner
		result = hitbox.hit(target)
		if restore_opponent:
			target.opponent = opponentTemp
	else:
		Network.log("Couldn't set opponent for hitbox")
		result = hitbox.hit(target)
	return result



func MH_players_hittable(px1, px2):
	return players_hittable_dic[px1] && players_hittable_dic[px2]

func _mark_players_unhittable(attacker, defender, hitbox):
	var lock_attacker = true
	if hitbox and (hitbox.throw or hitbox is ThrowBox):
		lock_attacker = false
	if lock_attacker and attacker in players_hittable_dic:
		players_hittable_dic[attacker] = false
	if defender in players_hittable_dic:
		players_hittable_dic[defender] = false



func set_vanilla_game_started(toggle:bool):
	# Godot doesn't allow lifecycle functions to be properly overridden
	match(toggle):
		true:
			if game_started_real:
				self.game_started = true
				game_started_real = false
		false:
			if self.game_started:
				game_started_real = true
				self.game_started = false



func is_other_ghost_actionable(selfIndex):
	set_vanilla_game_started(true)

	for index in players.keys():
		if index == selfIndex:
			continue
		if ghost_player_actionables[index]:
			return true
	return false




func get_player_from_name(id:String):
	for player in players.values():
		if player.name == id:
			return player



func process_opponents():
	for index in players:
		var player = players[index]
		if !ReplayManager.playback:
			if player.queued_extra:
				var queued_extra = player.queued_extra
				if queued_extra:
					if "opponent" in queued_extra:
						player.opponent = players[queued_extra["opponent"]]
		else:
			# Apparently current tick doesn't update until after objects... so I'm forced check one ahead locally.
			var current_tick = self.current_tick+1
			var ticks = ReplayManager.frames[index]
			if ticks.has(current_tick):
				var input = ticks[current_tick]
				if input:
					var queued_extra = input["extra"]
					if queued_extra:
						if "opponent" in queued_extra:
							players[index].opponent = players[queued_extra["opponent"]]

		# I probably don't need to do this every frame, but it doesn't really hurt.
		if not Network.multiplayer_active:
			if Network.sp_opp_dict.has(index):
				player.opponent = players[Network.sp_opp_dict[index]]
		# TODO - Add some sort of a way to force update current target selection
		#if !is_ghost:



func calc_player_order():
	var buckets := {}
	for id in players.keys():
		var team = Network.get_team(id)
		if not buckets.has(team):
			buckets[team] = []
		buckets[team].append(id)
	var order := []
	var keys := buckets.keys()
	keys.sort()
	for k in keys:
		order.append(buckets[k])
	return order
