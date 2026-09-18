extends "res://SoupModOptions/ModOptions.gd"

const MENU_ID = "_CombatAIStrategist"
const MEMORY_GROUP = "combat_ai_strategist_memory"
const COMBO_SAVE_PATH = "user://combatai_strategist_combos.json"
const LEARNING_SAVE_PATH = "user://combatai_strategist_learning.json"
const BURST_SAVE_PATH = "user://combatai_strategist_bursts.json"
const DATA_DIR = "user://CombatAIStrategist"
const DIALOGUE_PATH = "user://CombatAIStrategist/custom_dialogues.json"

var memory_status_option = null
var speech_status_option = null


func _ready():
	var menu = generate_menu(MENU_ID, "Combat AI Strategist")
	menu.add_label("cas_title", "Combat AI Strategist")

	menu.add_bool("enabled", "Mod Enabled", true)
	menu.add_label("cas_enable_note", "Enables or disables Combat AI Strategist.")

	var player_dropdown = menu.add_dropdown_menu("ai_player", "AI Controls")
	player_dropdown.add_item("Off")
	player_dropdown.add_item("Player 1")
	player_dropdown.add_item("Player 2")
	player_dropdown.add_item("AI vs AI (Both)")

	var shared_skill = menu.add_dropdown_menu("difficulty", "Shared Skill (Fallback)")
	_add_skills(shared_skill, false)
	menu.add_label("cas_shared_note", "Used by AI sides set to Use Shared Skill.")

	var p1_skill = menu.add_dropdown_menu("p1_difficulty", "Player 1 Skill")
	_add_skills(p1_skill, true)
	var p2_skill = menu.add_dropdown_menu("p2_difficulty", "Player 2 Skill")
	_add_skills(p2_skill, true)
	menu.add_label("cas_skill_note", "Sets the decision quality and mistake rate for each AI side.")

	var p1_behavior = menu.add_dropdown_menu("p1_behavior", "Player 1 Behavior")
	_add_behaviors(p1_behavior)
	var p2_behavior = menu.add_dropdown_menu("p2_behavior", "Player 2 Behavior")
	_add_behaviors(p2_behavior)
	menu.add_label("cas_behavior_note", "Classic is balanced. Aggressive favors pressure and combos. Dynamic adapts during the match. Defensive favors safety and spacing.")

	menu.add_string_single("p1_ignored_moves", "Player 1 Never Uses Moves", "")
	menu.add_string_single("p2_ignored_moves", "Player 2 Never Uses Moves", "")
	menu.add_label("cas_ignored_note", "Comma-separated action or button names that the selected AI side will not use.")

	menu.add_bool("random_skill_aivai", "Random Skill (AI vs AI)", false)
	menu.add_label("cas_random_note", "Assigns each AI side a random Skill at the start of an AI-vs-AI match.")

	menu.add_label("cas_director", "--- Fight Director ---")
	var winner = menu.add_dropdown_menu("preferred_winner", "Preferred Winner")
	winner.add_item("Natural Outcome")
	winner.add_item("Player 1")
	winner.add_item("Player 2")
	var influence = menu.add_dropdown_menu("director_strength", "Winner Influence")
	influence.add_item("Subtle")
	influence.add_item("Strong")
	influence.add_item("Determined")
	var pacing = menu.add_dropdown_menu("battle_pacing", "Battle Pacing")
	pacing.add_item("Natural")
	pacing.add_item("Competitive")
	pacing.add_item("Cinematic Comeback")
	menu.add_label("cas_director_note", "Preferred Winner steers move selection toward one side. Subtle allows frequent upsets, Strong reduces upsets, and Determined rejects simulated losing lines when a safe choice exists.")

	var visibility = menu.add_dropdown_menu("move_visibility", "Locked-Move Visibility")
	visibility.add_item("Fair - Neither Side")
	visibility.add_item("Player 1 Reads Player 2")
	visibility.add_item("Player 2 Reads Player 1")
	visibility.add_item("Both - Alternating Reveal")
	menu.add_label("cas_visibility_note", "Controls which AI may evaluate the opponent's locked move. Both alternates first-reader priority each turn.")

	menu.add_label("cas_performance_guide", "--- PERFORMANCE / LAG GUIDE ---")
	menu.add_label("cas_lag_low", "LOW LAG: Fast + Adaptive Coverage + Standard Awareness + Skill Based Depth")
	menu.add_label("cas_lag_recommended", "BALANCED: Balanced + Adaptive Coverage + Enhanced Awareness + Patient")
	menu.add_label("cas_lag_extreme", "EXTREME LAG: Epic + Exhaustive Unlimited + Strategic Awareness + Maximum Depth + Feral")
	menu.add_label("cas_lag_formula", "Coverage, generated inputs, awareness, and depth multiply total thinking work. Patience controls how much of that work runs per frame.")

	menu.add_label("cas_advanced", "--- Advanced Search Settings ---")
	var performance = menu.add_dropdown_menu("performance_profile", "Thinking Load", 1)
	performance.add_item("Fast [LOW LAG] - Short Search")
	performance.add_item("Balanced [RECOMMENDED] - Adaptive")
	performance.add_item("Epic [HIGH LAG] - Full Fidelity")
	menu.add_label("cas_performance_note", "Controls search size and simulation length. Fast is lightest, Balanced adapts to performance, and Epic uses the largest search.")

	var patience = menu.add_dropdown_menu("patience_mode", "Patience Mode", 3)
	patience.add_item("God-level Waiting")
	patience.add_item("Great Patience")
	patience.add_item("Very Patient")
	patience.add_item("Patient")
	patience.add_item("Not Patient")
	patience.add_item("ADHD")
	patience.add_item("Feral")
	menu.add_label("cas_patience_note", "Controls CPU use per frame without changing search quality. God-level Waiting is smoothest and slowest. Feral finishes fastest and causes the most stutter.")

	var coverage = menu.add_dropdown_menu("search_mode", "Simulation Coverage")
	coverage.add_item("Adaptive [LOWEST LAG]")
	coverage.add_item("Full Legal-Action Sweep [MEDIUM-HIGH]")
	coverage.add_item("Exhaustive Generated Inputs [EXTREME]")
	menu.add_label("cas_coverage_note", "Adaptive reduces work under strain. Full Sweep evaluates every legal action. Exhaustive also evaluates generated aim, slider, reverse, feint, and adjustable-input variants.")

	var exhaustive_limit = menu.add_dropdown_menu("exhaustive_limit", "Exhaustive Variant Limit")
	exhaustive_limit.add_item("Unlimited [EXTREME / MAY FREEZE]")
	exhaustive_limit.add_item("Smart 256 [VERY HIGH]")
	exhaustive_limit.add_item("Smart 128 [HIGH]")
	exhaustive_limit.add_item("Smart 64 [SAFER]")
	menu.add_label("cas_exhaustive_limit_note", "Limits generated input combinations while preserving a varied sample of each adjustable input.")

	var awareness = menu.add_dropdown_menu("awareness", "Opponent Awareness")
	awareness.add_item("Standard [LOW LAG]")
	awareness.add_item("Enhanced Prediction [MEDIUM-HIGH]")
	awareness.add_item("Strategic Multi-Plan [VERY HIGH]")
	menu.add_label("cas_awareness_note", "Standard uses a primary prediction. Enhanced scans the opponent's legal actions. Strategic compares several likely replies.")

	var depth = menu.add_dropdown_menu("tactical_depth", "Tactical Search Depth")
	depth.add_item("Skill Based [LOWEST LAG]")
	depth.add_item("Extra Exchange [HIGH]")
	depth.add_item("Maximum [EXTREME]")
	menu.add_label("cas_depth_note", "Skill Based scales depth with AI Skill. Extra Exchange searches follow-ups. Maximum also searches replies and counters.")

	var selection = menu.add_dropdown_menu("move_selection", "Best-Move Variety")
	selection.add_item("Skill Weighted")
	selection.add_item("Equal-Best Pool")
	selection.add_item("Near-Best Pool")
	selection.add_item("Top-Move Pool")
	menu.add_label("cas_selection_note", "Controls variety among highly scored moves. Larger pools produce more varied attacks and patterns with little performance impact.")

	var di_policy = menu.add_dropdown_menu("di_policy", "DI Control")
	di_policy.add_item("Strategist - Simulated Best DI")
	di_policy.add_item("Respect Current / Automatic DI")
	di_policy.add_item("Unpredictable Strategic DI")
	menu.add_label("cas_di_note", "Simulated Best searches for strong DI. Respect Current keeps the selected DI value. Unpredictable varies among strong simulated DI choices.")

	var resources = menu.add_dropdown_menu("resource_strategy", "Long-Term Resource Goal")
	resources.add_item("Adaptive - Spend or Save by Position")
	resources.add_item("Spend Freely - Immediate Pressure")
	resources.add_item("Save for Power - Long-Term Plan")
	menu.add_label("cas_resource_note", "Controls whether the AI spends resources immediately or saves them for stronger future options.")

	menu.add_bool("learning_enabled", "Opponent and Combo Learning", true)
	var LearningAlgorithm = menu.add_dropdown_menu("LearningAlgorithm", "Learning Algorithm")
	LearningAlgorithm.add_item("Adaptive")
	LearningAlgorithm.add_item("Reinforcement")
	LearningAlgorithm.add_item("Imitation")
	LearningAlgorithm.add_item("Combo Training")
	menu.add_label("cas_learning_note", "Controls how the AI learns from match outcomes, observed play, opportunities, and combo routes.")

	menu.add_bool("simulation_cache", "Per-Turn Simulation Cache", true)
	menu.add_label("cas_cache_note", "Reuses duplicate simulations during a decision. Enabled is faster; disable for characters with intentionally random simulations.")

	menu.add_bool("plan_ahead", "Plan Ahead", true)
	menu.add_label("cas_plan_note", "Evaluates follow-up opportunities during neutral decisions.")

	menu.add_label("cas_speech", "--- Situational AI Speech ---")
	menu.add_bool("ai_speech", "AI Battle Speech Master Switch", false)
	menu.add_bool("p1_speech_enabled", "Player 1 AI Can Speak", true)
	menu.add_bool("p2_speech_enabled", "Player 2 AI Can Speak", true)
	var speech_frequency = menu.add_dropdown_menu("speech_frequency", "AI Speech Frequency", 1)
	speech_frequency.add_item("Rare")
	speech_frequency.add_item("Occasional")
	speech_frequency.add_item("Frequent")
	var p1_speech_profile = menu.add_dropdown_menu("p1_speech_profile", "Player 1 Speech Personality")
	_add_speech_profiles(p1_speech_profile)
	var p2_speech_profile = menu.add_dropdown_menu("p2_speech_profile", "Player 2 Speech Personality")
	_add_speech_profiles(p2_speech_profile)
	menu.add_label("cas_speech_note", "Custom dialogue situations: Opening, Attack, Combo, Defense, Winning, Losing, and Finisher.")
	_add_action_button(menu, "open_dialogue_folder_action", "Open Custom Dialogue Folder", "OpenDialogueFolderPressed")
	_add_action_button(menu, "open_dialogue_file_action", "Open Custom Dialogue File", "OpenDialogueFilePressed")
	_add_action_button(menu, "reload_dialogues_action", "Reload Custom Dialogues", "ReloadDialoguesPressed")
	speech_status_option = menu.add_label("cas_speech_status", "Custom dialogues are stored in custom_dialogues.json.")

	menu.add_bool("auto_lock_in", "Auto Lock In", true)
	menu.add_bool("think_after_lock", "Think After Lock In", false)
	menu.add_label("cas_defer_note", "Starts AI thinking after the opponent locks in. This reduces background load but increases post-lock waiting time.")

	menu.add_label("cas_diagnostics", "--- Compatibility and Error Reporting ---")
	menu.add_bool("show_error_popups", "Show Recoverable Error Popups", true)
	menu.add_label("cas_error_note", "Shows detected compatibility faults with a CAS error code and saves details to combatai_strategist_faults.log.")
	menu.add_bool("debug_logging", "Debug Logging", false)
	menu.add_bool("study", "Match Study", false)
	menu.add_label("cas_study_note", "Logs ranked choices, categories, predicted replies, scores, and search diagnostics. Produces large log files.")

	menu.add_label("cas_memory_tools", "--- Learned Data Controls ---")
	# New internal names deliberately avoid the retired v1.3 boolean keys.
	# Soup loads old JSON by node name; reusing those names for ignored button
	# nodes would make it try to restore a bool into a non-persistent action.
	_add_action_button(menu, "clear_saved_combos_action", "Clear Saved Learning and Combos", "_clear_saved_combos_pressed")
	_add_action_button(menu, "clear_saved_bursts_action", "Clear Saved Burst Timing", "_clear_saved_bursts_pressed")
	_add_action_button(menu, "clear_match_memory_action", "Clear Current Study / Opponent Memory", "_clear_match_memory_pressed")
	_add_action_button(menu, "print_hint_packs_action", "Print Installed Hint Pack List", "_print_hint_packs_pressed")
	menu.add_label("cas_memory_note", "One-click controls for saved learning, combo routes, burst timing, current opponent memory, and the installed hint-pack list.")
	memory_status_option = menu.add_label("cas_memory_status", "No learned data cleared this session.")

	add_menu(menu)


func _add_skills(dropdown, include_shared):
	if include_shared:
		dropdown.add_item("Use Shared Skill")
	dropdown.add_item("Novice")
	dropdown.add_item("Adept")
	dropdown.add_item("Brawler")
	dropdown.add_item("Champion")
	dropdown.add_item("Master")


func _add_behaviors(dropdown):
	dropdown.add_item("Classic")
	dropdown.add_item("Aggressive")
	dropdown.add_item("Dynamic")
	dropdown.add_item("Defensive")


func _add_speech_profiles(dropdown):
	dropdown.add_item("Strategist - Analytical")
	dropdown.add_item("Aggressive - Intense")
	dropdown.add_item("Calm - Respectful")
	dropdown.add_item("Custom - Use Dialogue File")


func _add_action_button(menu, internal_name, label, callback_method):
	var option = load("res://_CombatAIStrategist/ActionButtonOption.gd").new()
	option.internal_name = internal_name
	option.name = internal_name
	option.fullpath = internal_name
	option.display_name = label
	option.default_value = null
	option.configure(self, callback_method)
	menu._add_to_list(internal_name, option)
	return option


# SoupModOptions auto-connects each menu's signals to these methods.
func __CombatAIStrategist_late_init(_menu):
	pass


func __CombatAIStrategist_opened(_menu):
	pass


func __CombatAIStrategist_closed(_menu_node):
	pass


func _clear_saved_combos_pressed():
	var ClearedCombos = _delete_save_file(COMBO_SAVE_PATH, "saved combo routes")
	var ClearedLearning = _delete_save_file(LEARNING_SAVE_PATH, "saved learning")
	get_tree().call_group(MEMORY_GROUP, "clear_saved_combo_memory")
	_set_memory_status("Saved learning and combo routes cleared." if ClearedCombos and ClearedLearning else "Could not clear all saved learning; check the game log.")


func _clear_saved_bursts_pressed():
	var cleared = _delete_save_file(BURST_SAVE_PATH, "saved burst timing")
	get_tree().call_group(MEMORY_GROUP, "clear_saved_burst_memory")
	_set_memory_status("Saved burst timing cleared." if cleared else "Could not clear saved burst timing; check the game log.")


func _clear_match_memory_pressed():
	get_tree().call_group(MEMORY_GROUP, "clear_study_and_match_memory")
	print("CombatAI Strategist: cleared current study and opponent memory")
	_set_memory_status("Current study and opponent memory cleared.")


func _print_hint_packs_pressed():
	var file = File.new()
	if file.open("res://_CombatAIStrategist/hints.json", File.READ) != OK:
		_set_memory_status("Could not read hint packs; check the game log.")
		return
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or !(parsed.result is Dictionary):
		_set_memory_status("Hint pack JSON is invalid; check the game log.")
		return
	var packs = []
	for key in parsed.result.keys():
		if key != "*":
			packs.append(str(key))
	packs.sort()
	print("CombatAI Strategist hint packs (%d): %s" % [packs.size(), PoolStringArray(packs).join(", ")])
	_set_memory_status("Printed %d hint-pack names to the game log." % packs.size())


func OpenDialogueFolderPressed():
	var DialogueDirectory = Directory.new()
	if !DialogueDirectory.dir_exists(DATA_DIR):
		var DirectoryError = DialogueDirectory.make_dir_recursive(DATA_DIR)
		if DirectoryError != OK:
			_set_speech_status("Could not create the custom dialogue folder.")
			return
	var DialogueFolder = ProjectSettings.globalize_path(DATA_DIR)
	var OpenError = OS.shell_open(DialogueFolder)
	_set_speech_status("Opened the custom dialogue folder." if OpenError == OK else "Could not open the custom dialogue folder.")


func OpenDialogueFilePressed():
	var DialogueDirectory = Directory.new()
	if !DialogueDirectory.dir_exists(DATA_DIR):
		var DirectoryError = DialogueDirectory.make_dir_recursive(DATA_DIR)
		if DirectoryError != OK:
			_set_speech_status("Could not create the custom dialogue folder.")
			return
	var DialogueCheck = File.new()
	if !DialogueCheck.file_exists(DIALOGUE_PATH):
		var ExampleFile = File.new()
		if ExampleFile.open("res://_CombatAIStrategist/dialogues.example.json", File.READ) != OK:
			_set_speech_status("Could not load the dialogue template.")
			return
		var ExampleText = ExampleFile.get_as_text()
		ExampleFile.close()
		if DialogueCheck.open(DIALOGUE_PATH, File.WRITE) != OK:
			_set_speech_status("Could not create custom_dialogues.json.")
			return
		DialogueCheck.store_string(ExampleText)
		DialogueCheck.close()
	var DialogueFile = ProjectSettings.globalize_path(DIALOGUE_PATH)
	var OpenError = OS.shell_open(DialogueFile)
	_set_speech_status("Opened custom_dialogues.json." if OpenError == OK else "Could not open custom_dialogues.json.")


func ReloadDialoguesPressed():
	var DialogueDirectory = Directory.new()
	if !DialogueDirectory.dir_exists(DATA_DIR):
		var DirectoryError = DialogueDirectory.make_dir_recursive(DATA_DIR)
		if DirectoryError != OK:
			_set_speech_status("Could not create the custom dialogue folder.")
			return
	var DialogueFile = File.new()
	if !DialogueFile.file_exists(DIALOGUE_PATH):
		var ExampleFile = File.new()
		if ExampleFile.open("res://_CombatAIStrategist/dialogues.example.json", File.READ) != OK:
			_set_speech_status("Could not load the dialogue template.")
			return
		var ExampleText = ExampleFile.get_as_text()
		ExampleFile.close()
		if DialogueFile.open(DIALOGUE_PATH, File.WRITE) != OK:
			_set_speech_status("Could not create custom_dialogues.json.")
			return
		DialogueFile.store_string(ExampleText)
		DialogueFile.close()
	if DialogueFile.open(DIALOGUE_PATH, File.READ) != OK:
		_set_speech_status("Could not open custom_dialogues.json.")
		return
	var ParsedDialogues = JSON.parse(DialogueFile.get_as_text())
	DialogueFile.close()
	if ParsedDialogues.error != OK or !(ParsedDialogues.result is Dictionary):
		_set_speech_status("Invalid JSON at line %d." % ParsedDialogues.error_line)
		return
	get_tree().call_group(MEMORY_GROUP, "ReloadCustomDialogues")
	_set_speech_status("Custom dialogues reloaded.")

func _set_memory_status(message):
	if memory_status_option != null and is_instance_valid(memory_status_option) and memory_status_option.label != null:
		memory_status_option.label.text = message


func _set_speech_status(message):
	if speech_status_option != null and is_instance_valid(speech_status_option) and speech_status_option.label != null:
		speech_status_option.label.text = message


func _delete_save_file(path, label):
	var file = File.new()
	if !file.file_exists(path):
		print("CombatAI Strategist: no %s file to clear" % label)
		return true
	var dir = Directory.new()
	var error = dir.remove(path)
	if error == OK:
		print("CombatAI Strategist: cleared %s" % label)
		return true
	else:
		push_error("CombatAI Strategist: failed to clear %s (error %d)" % [label, error])
		return false
