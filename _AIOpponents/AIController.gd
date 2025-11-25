extends Node2D

var target_player = null
var id = 0

var queued_action = null
var queued_data = null
var queued_extra = null

var ghost_game = null
var main = null
var ghost_viewport = null
var game = null

# To check UIElements against to see if they have the same script as the 3 default ones
var checkable_menu = preload("res://_AIOpponents/AICheckableUIData.tscn").instance()
var difficulty = 1

# MH
var mh_ai_count = 1

# For a variable hurt sprite
var hurtno = 1


export  var _c_AI_variables = 0
# Frames simulated when evaluating a move
export var FRAMES_TO_SIMULATE = 35 
# States to not simulate
export var states_to_ignore = ["Taunt", "DefensiveBurst"] 
# Stop eval immediately if a move causes hp to drop below 0
export var prevent_self_destruction = true 
# Amount to multiply the super level of a move by at evaluation. 
export var SUPER_MODIFIER = -0.5
# Amount to multiply the distance a move closes by at evaluation
export var DISTANCE_MODIFIER = 0.1
# Amount to multiply the damage a move does by at evaluation
export var DAMAGE_MODIFIER = 1
# Amount by which to multiply the frame advantage a move causes at evaluation
export var FRAME_ADVANTAGE_MODIFIER = 20

# Modifiers for the eval of specific moves. 
# Key is the name of a state, value is a dictionary of operation and amount.
# Use either + or * operators with the given amount. 
# This modifier is the last applied thing to a move eval.
# Place the operation inside a key of "positive" or "negative" to have it only
# fire when the eval is already positive or negative.
var state_specific_modifiers = {
										"WhiffInstantCancel": {"operation": "*", "amount":0},
										"InstantCancel": {"operation": "*", "amount":0},
										"Roll": {"operation": "*", "amount":0.5},
										"Burst": {
											"positive":{"operation":"*", "amount":0}, 
											"negative":{"operation":"+", "amount":-999999} 
											},
										"DefensiveBurst": {
											"positive":{"operation":"*", "amount":0}, 
											"negative":{"operation":"+", "amount":-999999} 
											},
										"OffensiveBurst": {
											"positive":{"operation":"*", "amount":0}, 
											"negative":{"operation":"+", "amount":-999999} 
											},
										}
										
var quick_data_lookup = {
	"SuperJump":["homing"],
	"Grab":{"Dash":[true, false], "Direction":[{"x":1, "y":0}, {"x":-1, "y":0}], "Jump":[false]},
	#"DashForward":{"AutoCorrect":[true], "Distance":[{"x":0}, {"x":100}, {"x":50}]},
	"ParryHigh":["Parry"],
	"Jump":[{"x":0, "y":-100}, {"x":-87, "y":-50}, {"x":87, "y":-50}, #Largest jump in directions
		{"x":45, "y":-89}, {"x":-54, "y":-84}, #Diagonal
		{"x":0, "y":-69}, {"x":-60, "y":-35}, {"x":60, "y":-35}], #Short hops
}


var multihustle = false

func _ready():
	
	game = get_parent()

	if game.is_ghost:
		#game.disconnect("player_actionable", self, "_start_decision_thread")
		self.queue_free()
	else:
		if main == null:
			main = find_parent("Main")
		if !multihustle and main.has_method("MultiHustle_AddData"):
			print("AI: Multihustle detected!")
			multihustle = true
			
		# Set difficulty and MH AI Count
		var ModOptions = main.get_node("ModOptions")
		if Network.multiplayer_active:
			id = 0
			difficulty = 1
		elif ModOptions != null:
			var difficulty_int = ModOptions.get_setting("_AIOptions", "difficulty")
			difficulty = difficulty_int + 1 if not Network.multiplayer_active else 1
			
			mh_ai_count = ModOptions.get_setting("_AIOptions", "ai_count")
			
			id = ModOptions.get_setting("_AIOptions", "target_player")
		else:
			id = 2
		
		game.connect("player_actionable", self, "_start_decision_thread")



func debug_print(message):
	# Uncomment this for a "thought process" breakbown
	#print(message)
	pass

		
func _start_decision_thread():
	print("_start_decision_thread")
	if multihustle:
		for player in range(id, id + mh_ai_count + 1):	
			_start_decision_thread_internal(player)
	else:
		_start_decision_thread_internal(id)
	

func _start_decision_thread_internal(pid):
	if !target_player:
		target_player = get_parent().get_player(pid)
		if target_player:
			target_player.connect("action_selected", self, "_edit_queue")
			print("AI: Controller ready!")
			make_move()
		else:
			pass
#			print("AI: Disabled")
#			get_parent().disconnect("player_actionable", self, "_start_decision_thread")
#			self.queue_free()
	else:
		make_move()

func _edit_queue(_action, _data, _extra):
	target_player.queued_action = queued_action
	target_player.queued_data = queued_data
	target_player.queued_extra = queued_extra
	
# Decicion making code. Calls ActionSelected
func make_move():
	
	ReplayManager.resimulating = true # Not strictly necessary but stops Godot errors
	debug_print("============================================================")
	
	# Prepare variables for prediction setup
	if game == null:
		game = get_parent()
	if ghost_viewport == null:
		ghost_viewport = main.find_node("GhostViewport")
	
	var previous_actionbutton_ids = []
	if multihustle:
		var closest_dist = 999999
		var closest_opponent = target_player.opponent
		for player in game.players.values():
			if player != self:
				var opponent_dist = sqrt(pow(player.get_pos().x - target_player.get_pos().x, 2) + pow(player.get_pos().y - target_player.get_pos().y, 2))
				if opponent_dist < closest_dist:
					closest_opponent = player
					closest_dist = opponent_dist
		target_player.opponent = closest_opponent
		debug_print("AI of ID " + str(id) + " chooses to target player ID " + str(target_player.opponent.id))
		previous_actionbutton_ids.append(main.ui_layer.GetRealID(1))
		previous_actionbutton_ids.append(main.ui_layer.GetRealID(2))
	
	# Do DI
	var ai_pos = target_player.get_pos()
	var opponent_pos = target_player.opponent.get_pos()
	var di = di_as_percentage_int_vec(Vector2(ai_pos.x - opponent_pos.x, ai_pos.y - opponent_pos.y).normalized())
	var temp_extra = {"DI":di, "feint":false, "prediction":-1, "reverse":false}
	
	
	var choice = {"action":"Continue", "data":null}
	var opponent_action = choice.action
	var opponent_data = choice.data

	if target_player.bursts_available > 0 or target_player.opponent.combo_count <= 0:
		choice = get_best_move(temp_extra, target_player.opponent.id, 0.2, difficulty>=2, true, false)
		opponent_action = choice.action
		opponent_data = choice.data

	
	debug_print("Choosing " +opponent_action+" with data " + str(opponent_data))
	debug_print("++++++++++++++++++++++++++++++++++++++++++++++++++++")
	
	# Next, pick your own move
	
	choice = get_best_move(temp_extra, id, 0.01, true, difficulty == 3, true, opponent_action, opponent_data)
	target_player.queued_action = choice.action
	target_player.queued_data = choice.data
	
	if difficulty == 3 and target_player.opponent.combo_count <= 0: # Hard mode goes one step deeper
		debug_print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
		choice = get_best_move(temp_extra, target_player.opponent.id, 0.1, difficulty>=2, true, true, target_player.queued_action, target_player.queued_data)
		opponent_action = choice.action
		opponent_data = choice.data
		debug_print("Choosing " +opponent_action+" with data " + str(opponent_data))
		debug_print("++++++++++++++++++++++++++++++++++++++++++++++++++++")
		choice = get_best_move(temp_extra, id, 0.01, true, false, true, opponent_action, opponent_data)
		#target_player.queued_action = choice.action
		#target_player.queued_data = choice.data
	
	ReplayManager.resimulating = false
	
	#if multihustle:
	#	Network.multihustle_action_button_manager.set_active_buttons(previous_actionbutton_ids[0], 2-id%2==2)
	#	Network.multihustle_action_button_manager.set_active_buttons(previous_actionbutton_ids[1], 2-(1+id)%2==2)
	
	queued_action = choice.action
	queued_data = choice.data
	queued_extra = {"DI":di, "feint":choice.feint if target_player.feints > 0 else false, "prediction":-1, "reverse":false}
	debug_print("Extra is " + str(queued_extra))
	


	main.call_deferred("_start_ghost")



# Function that evaluates a move made by character of an id.
# Returns an array of 2 values - the evaluation number and a bool of whether the move should be free cancelled.
func eval_move(action, data, extra, id, opponent_action="Continue", opponent_data=null):
	setup_ghost_game()
	
	var evaluee = ghost_game.get_player(id)
	
	var opponent = ghost_game.get_player(evaluee.opponent.id) 
	
	# Setup specifics
	opponent.is_ghost = true
	opponent.queued_action = opponent_action
	opponent.queued_data = opponent_data
	
	evaluee.is_ghost = true
	evaluee.queued_action = action
	evaluee.queued_data = data
	evaluee.queued_extra = extra
	
	var opponent_start_hp = opponent.hp
	var evaluee_start_hp = evaluee.hp
	
	var evaluee_ready_tick = null
	var opponent_ready_tick = null
	
	var evaluee_is_hit = opponent.combo_count > 0
	var opponent_is_hit = evaluee.combo_count > 0
	
	var evaluee_opponent_dist_start = sqrt(pow(opponent.get_pos().x - evaluee.get_pos().x, 2) + pow(opponent.get_pos().y - evaluee.get_pos().y, 2))
	var evaluee_opponent_dist_end = 0
	
	
	if multihustle: # Makes sure that the evalation plays out as expected in MultiHustle
		evaluee.opponent = opponent
		evaluee.opponent.opponent = evaluee
	
	for current_frame in range(1, FRAMES_TO_SIMULATE+1):
		ghost_game.simulate_one_tick()
		
		if evaluee.hp <= 0 and prevent_self_destruction and evaluee_ready_tick == null:
			return {"eval":-999999, "feint":false}
		
		var evaluee_tick = current_frame + (evaluee.hitlag_ticks if not opponent_ready_tick else 0)
		if (evaluee.state_interruptable or evaluee.dummy_interruptable or evaluee.state_hit_cancellable) and evaluee_ready_tick == null:
			evaluee_ready_tick = evaluee_tick
			# ghost_p1_actionable is evaluee_actionable != null
			# Ready if true, inturrupt if false:
			# opponent.current_state().anim_length == opponent.current_state().current_tick + 1 or opponent.current_state().iasa_at == opponent.current_state().current_tick
			if (opponent.current_state().interruptible_on_opponent_turn or opponent.feinting or ghost_game.negative_on_hit(opponent)) and opponent_ready_tick == null:
				opponent_ready_tick = current_frame
				break
		
		var opponent_tick = current_frame + (opponent.hitlag_ticks if not evaluee_ready_tick else 0)
		if (opponent.state_interruptable or opponent.dummy_interruptable or opponent.state_hit_cancellable) and opponent_ready_tick == null:
			opponent_ready_tick = opponent_tick
			
			# Ready if true, inturrupt if false:
			# evaluee.current_state().anim_length == evaluee.current_state().current_tick + 1 or evaluee.current_state().iasa_at == evaluee.current_state().current_tick
			if (evaluee.current_state().interruptible_on_opponent_turn or evaluee.feinting or ghost_game.negative_on_hit(evaluee)) and evaluee_ready_tick == null:
				evaluee_ready_tick = current_frame
		
		if !evaluee_opponent_dist_end and (opponent_ready_tick != null or evaluee_ready_tick != null):
			evaluee_opponent_dist_end = sqrt(pow(opponent.get_pos().x - evaluee.get_pos().x, 2) + pow(opponent.get_pos().y - evaluee.get_pos().y, 2))
		if opponent_ready_tick != null and evaluee_ready_tick != null:
			break

	if !evaluee_opponent_dist_end:
		evaluee_opponent_dist_end = sqrt(pow(opponent.get_pos().x - evaluee.get_pos().x, 2) + pow(opponent.get_pos().y - evaluee.get_pos().y, 2))
	if evaluee_ready_tick == null:
		evaluee_ready_tick = FRAMES_TO_SIMULATE
	if opponent_ready_tick == null:
		opponent_ready_tick = FRAMES_TO_SIMULATE
	
	var frame_advantage = opponent_ready_tick - evaluee_ready_tick
	var damage = (opponent_start_hp - opponent.hp) - (evaluee_start_hp - evaluee.hp)
	var distance_closed = evaluee_opponent_dist_start - evaluee_opponent_dist_end 
	
	
	var evaluee_state = evaluee.state_machine.get_state(action)
	var earliest_hitbox = null
	var supers = null
	var feint = false
	if evaluee_state:
		
		if target_player.feints > 0 and evaluee_state.can_feint() and frame_advantage < 0:
			feint = true
			if damage > 0:
				frame_advantage = 0
			
		
		earliest_hitbox = evaluee_state.get("earliest_hitbox")
		supers = evaluee_state.get("super_level_")
		
	if earliest_hitbox == null:
		earliest_hitbox = 0
	if supers == null:
		supers = 0
	
	#debug_print("Frame Advantage: "+str(frame_advantage) + ", Damage: " + str(damage) + ", Distance closed: "+str(distance_closed) + ", Earliest Hitbox: " +str(earliest_hitbox) + ", Distance end: " + str(evaluee_opponent_dist_end))
	
	
	var frame_advantage_modifier = FRAME_ADVANTAGE_MODIFIER
	if distance_closed < 50:
		frame_advantage_modifier /= 10
	
	var distance_modifier = DISTANCE_MODIFIER
	if damage == 0:
		distance_modifier *= 10
	if damage < 0 or evaluee_is_hit:
		distance_modifier *= -1
	
	var eval = (
		(frame_advantage * FRAME_ADVANTAGE_MODIFIER) + 
		(damage * DAMAGE_MODIFIER) + 
		(distance_closed * distance_modifier) + 
		(supers * SUPER_MODIFIER)
		)
	
	var modifier = state_specific_modifiers.get(action)
	if modifier:
		if modifier.has("positive") and eval >= 0:
			modifier = modifier.positive
		elif modifier.has("negative") and eval < 0:
			modifier = modifier.negative
		
		if modifier.has("operation") and modifier.has("amount"):
			if modifier.operation == "*":
				eval *= modifier.amount
			elif modifier.operation == "+":
				eval += modifier.amount
			else:
				debug_print("WARNING: operator for eval modifier of " + action + "(" + modifier.operation + ") is invalid. Only '*' and '+' are supported.")
		else:
			debug_print("WARNING: state modifier " + str(modifier) + " is missing an operation or amount.")
	
	# Trying to avoid weird Whiffs where the opponent is far away
	if action == "WhiffInstantCancel" and evaluee_opponent_dist_end > 150:
		eval = -200
		

	

	return {"eval":eval, "feint":feint}
	

# Returns the frame at which you should block to parry a given move.
# ID is of the blocking player.
func get_block_data(opponent_action, opponent_data, id):
	
	setup_ghost_game()
	
	var evaluee = ghost_game.get_player(id)
	var opponent = evaluee.opponent

	opponent.is_ghost = true
	opponent.queued_action = opponent_action
	opponent.queued_data = opponent_data
	
	evaluee.queued_action = "ParryHigh"
	evaluee.queued_data = {"Block Height":{"y":0}, "Melee Parry Timing":{"count":19}}
	evaluee.queued_extra = null
	evaluee.is_ghost = true
	
	var tick = 0
	# If the move doesn't hit, only go for 20 frames then return a default of 4
	while evaluee.ghost_blocked_melee_attack == -1 and tick < 20: 
		ghost_game.simulate_one_tick()
		tick += 1
	
	return {"Block Height":{"y":1 if evaluee.ghost_wrong_block == "Low" else 0}, "Melee Parry Timing":{"count":evaluee.ghost_blocked_melee_attack if evaluee.ghost_blocked_melee_attack != -1 else 4}}


# Takes a potential data node as input (ActionUIData or XYPlot/Slider etc.)
# Recursively generates a dictionary of arrays of possible inputs to an ActionUIData.
func get_data_structure(control_node, fighter=null):
	# Account for unused code, halves time to process Grab
	if !control_node.visible and control_node.get_name() == "Jump" and get_children_names(control_node.get_parent()) == ["Direction", "Dash", "Jump"]:
		return {control_node.get_name():[false]}
	
	var script = control_node.get_script()
	if script != null:
		for UIElement in checkable_menu.get_children():
			if script == UIElement.get_script():
				# If it's a custom UIElement, we do nothing. Will be fixed eventally
				match UIElement.get_name():
					"XYPlot":
						return {control_node.get_name():get_possible_xyplot_outputs(control_node)}
					"8Way":
						var possible_dirs = []
						for dir in control_node.DIRS:
							if control_node.get(dir):
								possible_dirs.append(control_node.get_value(dir))
						return {control_node.get_name():possible_dirs}
					"Slider":
						return {control_node.get_name():make_unique([{"x":control_node.min_value}, {"x":control_node.max_value}, {"x":(control_node.min_value+control_node.max_value)/2}])}
					"CountOption":
						return {control_node.get_name():{"count":make_unique([control_node.min_value, control_node.max_value, (control_node.min_value+control_node.max_value)/2])}}
					"OptionButton":
						return {control_node.get_name():get_enabled_options(control_node)}
					"CheckButton":
						return {control_node.get_name():[true, false]}

	if control_node is Container:
		activate_action_ui_data(control_node, fighter)
		var test_data = {}
		var datum = null
		for child in control_node.get_children():
			datum = get_data_structure(child, fighter)
			if datum is int:
				return null
			elif datum != null and not datum is Array:
				test_data[datum.keys()[0]] = datum.values()[0]
		
		
		if test_data.keys().size() > 1:
			return verify_data_structure(control_node, test_data)
		elif datum is Array:
			return verify_data_structure(control_node, datum)
		elif datum != null:
			return verify_data_structure(control_node, datum.values()[0] )
		else:
			return [null]

# Turns the pile of spaghetti made in the above function into an an array of data
func split_potential_data(data):
	debug_print(data)
	var result = [{}]
	
	for key in data.keys():
		var new_result = []
		var value = data[key]
		
		if value is Array:
			for item in value:
				for existing_dict in result:
					var new_dict = existing_dict.duplicate()
					new_dict[key] = item
					new_result.append(new_dict)
		elif value is Dictionary:
			var sub_permutations = split_potential_data(value)
			for sub_perm in sub_permutations:
				for existing_dict in result:
					var new_dict = existing_dict.duplicate()
					new_dict[key] = sub_perm
					new_result.append(new_dict)
		else:
			for existing_dict in result:
				existing_dict[key] = value
			new_result = result
		
		result = new_result
	
	return result
	
	
func get_enabled_options(option_button: OptionButton) -> Array:
	var enabled_options = []
	var items = option_button.get_item_count()
	for option in range(items):
		if not option_button.is_item_disabled(option):
			enabled_options.append({
				id = option, 
				name = option_button.items[option]
			})

	return enabled_options
	
# An AI generated bit to get possible XYPlot values (that I've manually fixed)
# It gets up, down, left and right if applicable, then the extremities of the limited area if it is limited
func create_output(x: float, y: float, xy_plot, panel_radius) -> Dictionary:
	return xy_plot.as_percentage_int_vec(Vector2(x, y) * panel_radius)

func get_possible_xyplot_outputs(xy_plot: XYPlot) -> Array:
	var outputs = []
	var panel_radius = xy_plot.panel_radius
	var facing = xy_plot.facing * target_player.get_facing_int()
	var limit_angle = xy_plot.limit_angle
	var limit_center = xy_plot.get_limit_center()
	var limit_range = xy_plot.get_limit_range()

	# Add (1, 0) and (-1, 0) if within allowed angle
	if not limit_angle or abs(Utils.angle_diff(0, limit_center)) <= limit_range / 2:
		outputs.append(create_output(facing, 0, xy_plot, panel_radius))
	if not limit_angle or abs(Utils.angle_diff(PI, limit_center)) <= limit_range / 2:
		outputs.append(create_output(-facing, 0, xy_plot, panel_radius))

	# Add (0, 1) and (0, -1) if within allowed angle
	if not limit_angle or abs(Utils.angle_diff(-PI/2, limit_center)) <= limit_range / 2:
		outputs.append(create_output(0, -1, xy_plot, panel_radius))
	if not limit_angle or abs(Utils.angle_diff(PI/2, limit_center)) <= limit_range / 2:
		outputs.append(create_output(0, 1, xy_plot, panel_radius))

	# If angle is limited, add extremities
	if limit_angle:
		var left_extremity = Utils.ang2vec(limit_center - limit_range / 2)
		var right_extremity = Utils.ang2vec(limit_center + limit_range / 2)
		outputs.append(create_output(left_extremity.x * facing, left_extremity.y, xy_plot, panel_radius))
		outputs.append(create_output(right_extremity.x * facing, right_extremity.y, xy_plot, panel_radius))

	return outputs

# From the actual DI code
func di_as_percentage_int_vec(vec2:Vector2):
	return {
		"x":int(round(vec2.x * 100)), 
		"y":int(round(vec2.y * 100)), 
	}

#Stole this from Reddit u/Dizzy_Caterpillar777
func make_unique(arr: Array) -> Array:
	var dict := {}
	for a in arr:
		dict[a] = 1
	return dict.keys()
	
func get_children_names(node):
	var children_names = []
	for child in node.get_children():
		children_names.append(child.get_name())
	return children_names

func get_option_data(option: String, extra: Dictionary, data_ui_scene, fighter) -> Array:
	var temp_data = [null]
	debug_print("--------------")
	debug_print("checking " + option)
	if data_ui_scene != null:
		var possible_data = []
		if option in quick_data_lookup:
			possible_data = quick_data_lookup[option]
		else:
			var data_scene_instance = data_ui_scene.instance()
			possible_data = get_data_structure(data_scene_instance, fighter) 
			data_scene_instance.free()
		temp_data = split_potential_data(possible_data) if possible_data is Dictionary else possible_data
		debug_print(temp_data)
	return temp_data

func setup_ghost_game():
	
	#setup prediction engine
	if ghost_game and is_instance_valid(ghost_game):
		ghost_game.free()

	var gg_scene = load("res://Game.tscn")
	ghost_game = gg_scene.instance()
	

	if multihustle:
		ghost_game.set_script(Global.current_game.get_script())
		ghost_game.multiHustle_CharManager = Global.current_game.multiHustle_CharManager
		
	ghost_game.is_ghost = true
	ghost_game.visible = false
	ghost_viewport.add_child(ghost_game)
	ghost_game.start_game(true, main.match_data)

	ghost_game.ghost_speed = 100
	ghost_game.ghost_freeze = false
	game.copy_to(ghost_game)



	#game.ghost_game = ghost_game


	
func get_best_move(extra:Dictionary, id:int, leeway_percentage:float, allow_leeway:bool, limit_by_difficulty:bool, randomise_burst:bool, opponent_action="Continue", opponent_data=null) -> Dictionary:

	var moves = []
	var best_score = -999999
	
	#if multihustle:
	#	Network.multihustle_action_button_manager.set_active_buttons(id, 2-id%2==2)
	var action_buttons = main.find_node("P"+str(2-id%2)+"ActionButtons")
	
	var evaluee = game.get_player(id)
	var opponent = game.get_player(evaluee.opponent.id) 
	
	var dist = sqrt(pow(opponent.get_pos().x - evaluee.get_pos().x, 2) + pow(opponent.get_pos().y - evaluee.get_pos().y, 2))
	
	for button in action_buttons.buttons:
		# Check if the button is a move we're bothering to check.
		if (button.is_visible() and ((button.state == null or (button.state.type != 0 and button.state.type <= difficulty)) or !limit_by_difficulty)) and !(button.action_name in states_to_ignore or "StrikeAPose" in button.action_name or "StrikeA_Pose" in button.action_name) and !(dist > 200 and button.state and button.state.type == 1):

			var evaluation = evaluate_button(button, extra, id, opponent_action, opponent_data)
			if best_score < evaluation.eval:
				if !allow_leeway or abs(best_score - evaluation.eval) >= best_score*leeway_percentage:
					moves = [evaluation]
				best_score = evaluation.eval
				
			elif allow_leeway and abs(best_score - evaluation.eval) <= best_score*leeway_percentage:
				moves.append(evaluation)

	# Choose a move that's one of the "best" options to pick
	debug_print("Options were: " + str(make_options_readable(moves)))
	
	# Burst randomisation and failsafe if no moves are returned
	if moves.empty() or randomise_burst and moves[0].action == "Burst": 
		moves.append({"action":"Continue", "eval":0, "data":null, "feint":false})
	
	var chosen_move = moves[target_player.randi_range(0, moves.size()-1)].duplicate() if !moves.empty() else {"action":"Continue", "eval":-999999, "data":null, "feint":false}
	debug_print("Picking " + chosen_move.action + " with eval of " + str(chosen_move.eval) + " and data " + str(chosen_move.data))
	debug_print("Assuming opponent chooses " + opponent_action + " with data " + str(opponent_data))
	if ghost_game and is_instance_valid(ghost_game):
		ghost_game.free()
	return chosen_move

func evaluate_button(button, extra, id, opponent_action, opponent_data):
	var temp_data = get_option_data(button.action_name, extra, button.state.data_ui_scene if button.state != null else null, game.get_player(id))
	var best_score = -999999
	var best_data = null
	var feint = false
	
	for example_data in temp_data:
		if example_data is String and example_data == "Parry":
			example_data = get_block_data(opponent_action, opponent_data, id)
			if example_data["Melee Parry Timing"].count == 0:
				example_data["Melee Parry Timing"].count = 1 #Not possible to block @f0
		debug_print(example_data)
		var prediction = eval_move(button.action_name, example_data, extra, id, opponent_action, opponent_data)
		debug_print(prediction.eval)
		if prediction.eval > best_score:# If the move has the best score, we'll assume they'll pick it
			best_score = prediction.eval
			best_data = example_data
			feint = prediction.feint
	return {"action":button.action_name, "eval":best_score, "data":best_data, "feint":feint}

func activate_action_ui_data(control_node, fighter):
			
	if control_node is ActionUIData:
		control_node.fighter = fighter
		self.add_child(control_node)
		control_node.fighter_update()

func verify_data_structure(control_node, unverified_data):
	if control_node is ActionUIData:
		var default_data = control_node.get_data()
		var test_data
		if unverified_data is Array:
			test_data = unverified_data[0]
		else:
			test_data = unverified_data
		if default_data is Dictionary and test_data is Dictionary and default_data.keys() != test_data.keys():
			debug_print("Mismatch: " + str(test_data.keys()) + " vs " + str(default_data.keys()))
			return [default_data]
		if test_data is Dictionary and not default_data is Dictionary or not test_data is Dictionary and default_data is Dictionary:
			debug_print("Mismatch: " + str(test_data) + " vs " + str(default_data))
			return [default_data]
	return unverified_data
	
func make_options_readable(options):
	var output = ""
	for option in options:
		output += option.action + ", "
	return output.left(output.length() - 2)
	
