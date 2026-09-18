# CombatAI.gd - Combat AI Strategist, forked from SirWise's Combat AI.
#
# Design notes:
# - Chess-engine shaped: enumerate legal moves, score each one by simulating
#   it in a private sandbox game, then pick by skill temperature (softmax).
#   Every difficulty sees every move; lower difficulties simply blunder more.
# - The sandbox uses the game's OWN copy_to, never a forked copy of it, so
#   game patches to the copy chain can't silently break predictions.
# - Thinking is spread across frames (frame budget) so the game never freezes.
#   If the player advances the turn early, we hold the turn open and submit
#   once the decision is ready.

extends Node2D

const MENU_ID = "_CombatAIStrategist"
const PERFORMANCE_FAST = 0
const PERFORMANCE_BALANCED = 1
const PERFORMANCE_EPIC = 2
const SIM_FRAMES = 40
const FAST_SIM_FRAMES = 24
const EPIC_SIM_FRAMES = 52
# Adaptive frame budget: how many ms of thinking to spend per rendered frame.
# _tune_budget shrinks it when the device drops frames and grows it when
# there's headroom, so slow PCs stay smooth and fast ones think sooner.
const BUDGET_MIN_MS = 6.0
const BUDGET_MAX_MS = 22.0
const FAST_BUDGET_MS = 10.0
const FAST_BOTH_AI_BUDGET_MS = 18.0
const EPIC_BUDGET_MS = 55.0
# AI-vs-AI: no human to keep the game smooth for, so think near-continuously.
const BOTH_AI_BUDGET_MS = 40.0
# Patience Mode scales only the CPU time spent per rendered frame. It never
# removes moves, variants, simulation frames, or search passes. Patient is
# exactly the legacy allowance, so existing installs keep their pacing until
# the player deliberately chooses a gentler or more aggressive setting.
const PATIENCE_GOD_LEVEL = 0
const PATIENCE_GREAT = 1
const PATIENCE_VERY = 2
const PATIENCE_PATIENT = 3
const PATIENCE_NOT = 4
const PATIENCE_ADHD = 5
const PATIENCE_FERAL = 6
const PATIENCE_MULTIPLIERS = [0.25, 0.4, 0.65, 1.0, 1.5, 2.25, 4.0]
# 2-ply beam: the deep passes only re-examine this many top candidates.
# Full width still happens at ply 1, so nothing is ever unseen - depth is
# just spent where it can change the answer.
const PLY2_BEAM = 8
# Blend of pass 1 (vs their predicted plan) and pass 2 (vs their perfect
# counter to our pick). Higher = more aggressive. Mid-combo we lean harder
# into pass 1: the foe is in hitstun, paranoia about counters is wasted.
const PLY2_BLEND = 0.6
const PLY2_BLEND_COMBO = 0.75
# Cap on input permutations per move (default + aimed/retreat plots, slider
# min/max, flipped toggles) so candidate count stays bounded.
const MAX_DATA_VARIANTS = 5
# Auto performance tier. What a player actually notices is the GAME
# stuttering while we think - not how long any one simulation takes. We yield
# between sims and THINK_DEADLINE_MS caps the wall clock, so an expensive sim
# on a healthy machine costs patience, not smoothness. So the tier watches
# the framerate.
#
# It used to watch sim milliseconds (7ms / 24ms), which punished good
# character mods instead of slow hardware: heavy modded fighters sim at
# 35-45ms normally, so overload tripped on the first turn of EVERY match and
# switched the AI off at the knees for the whole match. Sim cost survives
# only as a backstop for the pathological case.
const STRAIN_FPS = 50.0
const OVERLOAD_FPS = 34.0
# Sustained health earns depth back - one heavy opening turn must not
# lobotomise the remaining five minutes.
const RECOVER_FPS = 57.0
const RECOVER_SAMPLES = 45
const STRAIN_SIM_MS = 120.0
const OVERLOAD_SIM_MS = 300.0
# Hard wall-clock cap on one thinking session: past this, finalize with
# whatever is scored so far - a partial sweep beats a stalled game. Mostly
# bites on turn 1 (no tier measured yet, full prediction sweep) and in
# AI-vs-AI where two brains think per turn.
const THINK_DEADLINE_MS = 8000.0
const FAST_THINK_DEADLINE_MS = 3000.0
const EPIC_THINK_DEADLINE_MS = 20000.0
# Deep combo search: mid-combo, the top candidates get simmed one exchange
# further to see whether a follow-up actually exists from where they leave
# us. Champion+ only, skipped entirely when overloaded (tier 2), so weak
# machines never pay for it. The follow-up guesses are this sweep's best
# moves plus the combo book's suggestion.
const COMBO_SEARCH_TOP = 3
const COMBO_SEARCH_FOLLOWUPS = 2
const COMBO_SEARCH_FRAMES = 24
const CONTINUATION_WEIGHT = 0.6
# The same probe run in NEUTRAL is worth less: exchange 2 assumes the foe
# stands still, which is fair inside a combo (they are in hitstun) but
# optimistic in neutral, where they get a free turn. Fold it in at a lower
# weight so setup moves become considerable without becoming irresistible.
const NEUTRAL_CONTINUATION_WEIGHT = 0.35
# Parry timing is measured, not guessed: a ghost fighter that blocks a
# parriable hit records the frame it needed in ghost_blocked_melee_attack and
# the hit's height in ghost_wrong_block. One short probe per sweep beats
# sampling a 20-frame slider two values at a time.
const PARRY_PROBE_FRAMES = 20
# Combo book: move sequences that actually sustained combos in real matches
# (either side - the human is usually the better teacher), persisted across
# sessions. Book moves get a nudge while mid-combo; sims still veto whiffs,
# the book just breaks ties toward proven routes.
const BOOK_PATH = "user://combatai_strategist_combos.json"
const LEARNING_PATH = "user://combatai_strategist_learning.json"
const LEARNING_ADAPTIVE = 0
const LEARNING_REINFORCEMENT = 1
const LEARNING_IMITATION = 2
const LEARNING_COMBO = 3
const LEARNING_CONTEXT_CAP = 160
const LEARNING_ENTRY_CAP = 160
const LEARNING_SCORE_CAP = 220.0
const LEARNING_EXPLORATION = 30.0
const BOOK_BONUS = 25.0
const BOOK_SEEN_BONUS = 5.0
const BOOK_SEEN_CAP = 4
const BOOK_MIN_HITS = 2
const BOOK_MAX_ROUTES = 40
const BOOK_MAX_SEQ = 8
# Burst book: learns WHEN a character panic-bursts - the combo depth (hits
# eaten) at which they hit the button - keyed by character, persisted across
# matches. Two uses: predict the foe's burst so we can defend/bait it, and
# mimic that timing for our own escapes. Until a character has been seen
# bursting a couple of times, fall back to a sensible "you're in a real
# combo now" depth.
const BURST_BOOK_PATH = "user://combatai_strategist_bursts.json"
const FAULT_LOG_PATH = "user://combatai_strategist_faults.log"
const DIALOGUE_PATH = "user://CombatAIStrategist/custom_dialogues.json"
const BURST_LEARN_MIN_DEPTH = 3
const BURST_MIN_SAMPLES = 2
# Bonus on our own burst candidate once a combo reaches the learned escape
# depth and the burst is usable - enough to make it the pick when it truly
# breaks the string, not so much it fires on every stray hit.
const BURST_ESCAPE_BONUS = 120.0
# Opponent habit model: after this many observed turns, the human's actual
# move frequencies tilt their predicted-option scores by up to HABIT_WEIGHT.
const HABIT_WEIGHT = 60.0
const HABIT_MIN_TURNS = 2
# Overloaded matchups can't afford to simulate the foe's whole kit, so the
# mini-sweep predicts against only their most-played moves. Ten keeps a real
# read on a heavy machine without the full ~30-option cost.
const HABIT_PREDICT_TOP = 10
# Each hit added to our ongoing combo is worth this much beyond its damage:
# a locked-down opponent loses their next turn too. Symmetric for being hit.
const COMBO_EXTEND_WEIGHT = 16.0
# Flat bonus for candidates whose sim actually connects: every tier leans
# toward moves that DO something over equal-scoring passive spacing. Mild
# tilt at blunder temperatures, tie-breaker at Master.
const AGGRESSION_BONUS = 25.0
# Rule of relentlessness: while we are comboing, any candidate that fails
# to keep the combo going eats this penalty if ANY candidate can keep it
# going - dropping a live combo to play safe is how Masters feel easy.
const COMBO_DROP_PENALTY = 150.0
# A grab that whiffs against the foe's predicted plan in neutral is a
# wasted turn: grabs are for starting combos and beating defense, not
# fishing. (A grab that is genuinely the only damage-free option still
# wins - its raw score advantage exceeds this tax.)
const GRAB_WHIFF_PENALTY = 40.0
# A clean grab usually reaches the next decision before dealing damage. Treat
# that captured state as real contact or the evaluator calls every successful
# throw starter a whiff and subtracts the penalty above.
const THROW_CAPTURE_BONUS = 55.0
# High-skill symmetric AI can deterministically agree on one safe answer
# forever (Lightning Slice dittos exposed it). Only after several AI-vs-AI
# turns with no damage, meaningful movement, meter, combo, or object progress
# do we tax repeated non-contact actions; tactical hits and forced moves stay
# untouched.
const LOOP_HISTORY_LIMIT = 6
const LOOP_STAGNATION_START = 2
const LOOP_BASE_PENALTY = 45.0
const LOOP_GROWTH_PENALTY = 25.0
const LOOP_MAX_PENALTY = 300.0
const LOOP_POSITION_EPSILON = 8.0
const LoopStagnationEscape = 4
const RepeatActionPenalty = 35.0
const ComboContinuationMargins = [0.0, 0.0, 50.0, 100.0, 180.0]
# Real players are not perfect: when the predicted "best counter" is a
# move this player has never actually used this match, the paranoid
# 2-ply rescore blends this far toward the aggressive pass instead.
const PLY2_BLEND_UNSEEN = 0.85
# Lethal outcomes get a flat bonus so closing a round outbids playing safe.
const KILL_BONUS = 1000.0
# Bursts are too precious to spend dodging stray hits: any action with
# "Burst" in its name is taxed this much unless its owner is caught in a
# real combo (2+ hits) - which is what burst is actually for.
const BURST_RESERVE_PENALTY = 90.0
# ...and being caught in a combo is only permission to consider it. A burst
# that does not actually catch them is a free combo extension for the
# opponent, and one that merely ties our best ordinary answer is a resource
# thrown away on a coin flip. Both were reported from real matches.
const BURST_WHIFF_PENALTY = 120.0
const BURST_MARGIN = 40.0
# Feints: commit to a move and cancel it, so the answer it drew whiffs. Only
# probed on candidates that come out MINUS - that is what a feint is for.
# They are a limited resource (two per match; past that consume_feint() eats
# super bar), so a feint has to be clearly better, not marginally.
const FEINT_COST = 35.0
const FEINT_MARGIN = 20.0
const FEINT_PROBE_TOP = 3
const SKIP_ACTIONS = ["Taunt", "Forfeit", "Undo"]
# Shared action-discipline weights. These do not ban tactical tools; they make
# a resource-spending cancel, burst, or repeated throw prove its value in the
# sandbox instead of winning because it is the only non-idle button.
const CANCEL_WASTE_PENALTY = 140.0
const THROW_REPEAT_PENALTY = 85.0
const PASSIVE_IDLE_PENALTY = 45.0
const SUPER_CONTACT_BONUS = 30.0
const DI_POLICY_STRATEGIST = 0
const DI_POLICY_RESPECT_UI = 1
const DI_POLICY_UNPREDICTABLE = 2
const RESOURCE_ADAPTIVE = 0
const RESOURCE_SPEND = 1
const RESOURCE_SAVE = 2
const SPEECH_PRESETS = [
	{
		"opening": ["Let's make this interesting.", "Show me your plan."],
		"attack": ["I found the opening.", "That option loses here."],
		"combo": ["The route continues.", "I planned the follow-up."],
		"defense": ["I have another answer.", "That pressure has a gap."],
		"winning": ["Stay focused. The round is not over.", "I will convert this lead."],
		"losing": ["This position is still playable.", "I only need one clean answer."],
		"finisher": ["Checkmate.", "That was the line."]
	},
	{
		"opening": ["Try to keep up.", "I'm taking the first opening."],
		"attack": ["There you are!", "No room to breathe."],
		"combo": ["I'm not dropping this.", "The pressure keeps going!"],
		"defense": ["Not enough.", "My turn again."],
		"winning": ["Now the pace is mine.", "Keep fighting!"],
		"losing": ["Good. Now I get serious.", "One opening is enough."],
		"finisher": ["Finished!", "That's the round!"]
	},
	{
		"opening": ["Take your time.", "Let's have a clean match."],
		"attack": ["A small opening.", "That should connect."],
		"combo": ["Steady.", "One step at a time."],
		"defense": ["I can wait.", "No need to force it."],
		"winning": ["Keep it controlled.", "No careless finish."],
		"losing": ["Breathe and reset.", "There is still time."],
		"finisher": ["Good match.", "That settles it."]
	}
]
# Softmax temperature per skill: how many eval points of "worse" a move can
# be and still get picked. Novice blunders happily, Master plays the top move.
# Order matches the Skill dropdown: Novice, Adept, Brawler, Champion, Master.
const DIFFICULTY_TEMPS = [150.0, 75.0, 35.0, 12.0, 0.5]
# Side behavior profiles. Classic is exactly the original score path.
const BEHAVIOR_CLASSIC = 0
const BEHAVIOR_AGGRESSIVE = 1
const BEHAVIOR_DYNAMIC = 2
const BEHAVIOR_DEFENSIVE = 3
# Simulation coverage and awareness modes match the option dropdown order.
const SEARCH_ADAPTIVE = 0
const SEARCH_FULL_ACTIONS = 1
const SEARCH_EXHAUSTIVE = 2
const AWARENESS_STANDARD = 0
const AWARENESS_ENHANCED = 1
const AWARENESS_STRATEGIC = 2
const SELECTION_SKILL_WEIGHTED = 0
const SELECTION_EQUAL_BEST = 1
const SELECTION_NEAR_BEST = 2
const SELECTION_TOP_MOVES = 3
const VISIBILITY_FAIR = 0
const VISIBILITY_P1_READS = 1
const VISIBILITY_P2_READS = 2
const VISIBILITY_BOTH = 3
const DIRECTOR_NATURAL = 0
const DIRECTOR_P1 = 1
const DIRECTOR_P2 = 2
const PACING_NATURAL = 0
const PACING_COMPETITIVE = 1
const PACING_CINEMATIC = 2
# Integer counters larger than this are continuous-like for search purposes:
# sample their endpoints instead of creating thousands of nearly identical
# choices. Dropdowns and eight-way controls are always finite and complete.
const FULL_COUNTER_SAMPLE_LIMIT = 32
# Strategic awareness blends the primary expected line, the mean of other
# plausible replies, and the worst reply. It never reads the locked move.
const AWARENESS_PRIMARY_WEIGHT = 0.55
const AWARENESS_MEAN_WEIGHT = 0.25
const AWARENESS_WORST_WEIGHT = 0.20
# Fight-director strengths are indexed Subtle, Strong, Determined. They alter
# move evaluation only; no live fighter property is ever written.
const DIRECTOR_BASE_BONUS = [35.0, 90.0, 190.0]
const DIRECTOR_FINISH_BONUS = [1800.0, 6500.0, 100000.0]
const DIRECTOR_UPSET_PENALTY = [300.0, 6000.0, 100000.0]
const DIRECTOR_EFFORT_BONUS = [12.0, 26.0, 45.0]
# Worth of one usable move option after the exchange. Values resources
# (MP, ammo, cooldowns, meter) generically on any character: spending them
# usually locks options, gaining them unlocks options.
const RESOURCE_WEIGHT = 3.0
# Worth of one allied object (summon, minion, trap, projectile) still on the
# field after the exchange. 8: most of a solid hit - the one-exchange sim
# can't see a summon's future turns, so its lasting presence must carry
# that value or setup specials never outbid immediate damage. (Was 4;
# lower it if the AI starts over-summoning.)
const PRESENCE_WEIGHT = 8.0

var game = null
var main_node = null
var fighter = null

# Options
var ai_player = 0
var difficulty = 0
var p1_difficulty = 0
var p2_difficulty = 0
var p1_behavior = BEHAVIOR_CLASSIC
var p2_behavior = BEHAVIOR_CLASSIC
var behavior_profile = BEHAVIOR_CLASSIC
var search_mode = SEARCH_ADAPTIVE
var awareness = AWARENESS_STANDARD
var move_selection = SELECTION_SKILL_WEIGHTED
var learning_enabled = true
var LearningAlgorithm = LEARNING_ADAPTIVE
var preferred_winner = DIRECTOR_NATURAL
var director_strength = 0
var battle_pacing = PACING_NATURAL
var move_visibility = VISIBILITY_FAIR
var exhaustive_limit = 0
var tactical_depth = 0
var simulation_cache_enabled = true
var p1_ignored_moves = ""
var p2_ignored_moves = ""
var ignored_move_cache = {}
var di_policy = DI_POLICY_STRATEGIST
var resource_strategy = RESOURCE_ADAPTIVE
var ai_speech = false
var speech_frequency = 1
var p1_speech_enabled = true
var p2_speech_enabled = true
var p1_speech_profile = 0
var p2_speech_profile = 0
var custom_speech = {1: {}, 2: {}}
var show_error_popups = true
var auto_lock_in = true
var debug_logging = false
# Which side this brain instance is FOR (game.gd spawns one per side); the
# AI Controls setting decides whether this instance lives. In AI-vs-AI
# both live and each locks independently as soon as it has decided.
var forced_player = 0
var both_ai = false
var random_skill_aivai = false
# Look one exchange past the current turn in neutral, not just mid-combo.
var plan_ahead = true
# AI-vs-AI resim coordination: true while this brain holds a shared resim token.
var resim_held = false
# Fast is a strict workload cap. Balanced preserves the v1.1 adaptive
# behavior. Epic raises the simulation horizon and per-frame CPU allowance.
var performance_profile = PERFORMANCE_BALANCED
var performance_mode = false
# CPU pacing, independent from Thinking Load/search quality.
var patience_mode = PATIENCE_PATIENT

# Deferred-thinking mode: wait for the player's lock before spending any
# cycles - for machines where background thinking lags the player's own
# decision phase. The foe's locked CHOICE is still never read.
var think_after_lock = false
var foe_lock_tick = -1
var revealed_foe_action = null
var revealed_foe_data = null
var revealed_foe_extra = null
var revealed_foe_tick = -1

var think_budget_ms = 14.0
var adaptive_budget_ms = 14.0
# Always on since v0.7.1; kept as a variable so the frame-budget yield points
# in the think pipeline read naturally.
var background_thinking = true

# Measured sim cost for this match (0 until the first sim lands) and the
# performance tier it has forced so far.
var avg_sim_ms = 0.0
# How much of a sim is spent rebuilding the sandbox (copy_to) rather than
# ticking it. Reported so a future optimisation pass knows where to aim.
var avg_prepare_ms = 0.0
var avg_fps = 0.0
var healthy_samples = 0
var strain_tier = 0

# Sandbox
var sim_viewport = null
var sim_game = null
var sim_start_states = ["Start", "Start"]
# Outcome of the most recent sim, read by _score_options right after each
# entry lands (sequential within a session, so never stale at read time).
var last_sim_hit = false
var last_sim_extended = false
# Match study state. `last_predicted` is the scored table of the OPPONENT's
# options from this turn's prediction sweep - built BEFORE they lock, so
# looking their real choice up in it afterwards is pure observation and can
# never influence a decision. That lookup is the whole point of the study:
# it says where a human's pick ranked on the AI's own scale.
var study = false
var last_sim_terms = {}
var last_predicted = []
var last_plan_src = "none"
var study_turn = 0
# Why the parry solver and the feint pass did or didn't fire this turn, for
# the study log. Both ran their whole match returning nothing and the single
# success/failure print couldn't say why.
var last_parry_bail = "not-run"
var last_feint_diag = "not-run"
# Prep cost split: rebuilding the sandbox is 80% of every sim, but the single
# timer couldn't say whether that is _reset_sim (our residue clearing) or the
# game's own copy_to. Timed separately so the optimisation aims true.
var avg_reset_ms = 0.0
var avg_copy_ms = 0.0
# Frame advantage the last sim ended on: positive means we act first.
var last_sim_advantage = 0

# Decision state
var decided_action = null
var decided_data = null
var decided_extra = null
var decided_category = "Utility"
var decided_terms = {}

# Session bookkeeping (async safety)
var session = 0
var session_active = false
var slice_started = 0
var session_deadline = 0
var sims_done = 0
var sim_cache_hits = 0
var held_turn = false
var last_turn_tick = -1
var status_label = null

# Cached default move data, per fighter id and action, for this match
var move_data_cache = {}
var action_names_cache = {}
var action_buttons_cache = {}
var sim_cache = {}
var starting_hp = {}

# Opponent habit model: what the human actually picked this match
var foe_history = {}
var foe_turns = 0

# Character hint packs (hints.json): per-character values for mechanics the
# generic score can't judge, plus quest-style preferred-move nudges.
var hints_data = null
var hints_cache = {}

# Combo book state: learned routes per character key, each side's live combo
# sequence this match, and the last move each side locked (a combo's first
# recorded move is the launcher, which was selected before the combo showed).
var combo_book = {}
var combo_live = {}
var last_action_by = {}
var LearningBook = {}
var LearningDirty = {}
var LearningPending = {}
var LearningRecent = {}
var LearningSaveCounter = 0
var last_ai_choice = ""
var last_ai_choice_streak = 0
var speech_turns = 0
var speech_started = false
var recent_ai_actions = []
var stagnation_turns = 0
var progress_snapshot = null
# Burst book: char key -> {bursts, sum_depth, min_depth}. avg = sum_depth /
# bursts is the depth this character tends to burst at.
var burst_book = {}

var rng = RandomNumberGenerator.new()


func _ready():
	game = get_parent()
	if game.is_ghost:
		queue_free()
		return
	if Network.multiplayer_active:
		queue_free()
		return
	rng.randomize()
	main_node = find_parent("Main")

	var options = main_node.get_node_or_null("ModOptions")
	if options != null:
		# Master switch: turn the whole mod off without uninstalling.
		var en = options.get_setting(MENU_ID, "enabled")
		if en != null and not en:
			queue_free()
			return
		# Settings come back JSON-parsed, so numbers are floats; coerce to int
		# or they silently miss int-keyed dictionaries (selected_characters,
		# caches: float 2.0 and int 2 are different keys in Godot 3).
		var v = options.get_setting(MENU_ID, "ai_player")
		if v != null:
			ai_player = int(v)
		v = options.get_setting(MENU_ID, "difficulty")
		if v != null:
			difficulty = int(v)
		v = options.get_setting(MENU_ID, "p1_difficulty")
		if v != null:
			p1_difficulty = int(v)
		v = options.get_setting(MENU_ID, "p2_difficulty")
		if v != null:
			p2_difficulty = int(v)
		v = options.get_setting(MENU_ID, "p1_behavior")
		if v != null:
			p1_behavior = int(v)
		v = options.get_setting(MENU_ID, "p2_behavior")
		if v != null:
			p2_behavior = int(v)
		v = options.get_setting(MENU_ID, "search_mode")
		if v != null:
			search_mode = int(v)
		v = options.get_setting(MENU_ID, "performance_profile")
		if v != null:
			performance_profile = int(v)
		v = options.get_setting(MENU_ID, "patience_mode")
		if v != null:
			patience_mode = int(v)
		v = options.get_setting(MENU_ID, "awareness")
		if v != null:
			awareness = int(v)
		v = options.get_setting(MENU_ID, "move_selection")
		if v != null:
			move_selection = int(v)
		v = options.get_setting(MENU_ID, "learning_enabled")
		if v != null:
			learning_enabled = bool(v)
		v = options.get_setting(MENU_ID, "LearningAlgorithm")
		if v != null:
			LearningAlgorithm = int(v)
		v = options.get_setting(MENU_ID, "preferred_winner")
		if v != null:
			preferred_winner = int(v)
		v = options.get_setting(MENU_ID, "director_strength")
		if v != null:
			director_strength = int(v)
		v = options.get_setting(MENU_ID, "battle_pacing")
		if v != null:
			battle_pacing = int(v)
		v = options.get_setting(MENU_ID, "move_visibility")
		if v != null:
			move_visibility = int(v)
		v = options.get_setting(MENU_ID, "exhaustive_limit")
		if v != null:
			exhaustive_limit = int(v)
		v = options.get_setting(MENU_ID, "tactical_depth")
		if v != null:
			tactical_depth = int(v)
		v = options.get_setting(MENU_ID, "simulation_cache")
		if v != null:
			simulation_cache_enabled = bool(v)
		v = options.get_setting(MENU_ID, "p1_ignored_moves")
		if v != null:
			p1_ignored_moves = str(v)
		v = options.get_setting(MENU_ID, "p2_ignored_moves")
		if v != null:
			p2_ignored_moves = str(v)
		v = options.get_setting(MENU_ID, "di_policy")
		if v != null:
			di_policy = int(v)
		v = options.get_setting(MENU_ID, "resource_strategy")
		if v != null:
			resource_strategy = int(v)
		v = options.get_setting(MENU_ID, "ai_speech")
		if v != null:
			ai_speech = bool(v)
		v = options.get_setting(MENU_ID, "speech_frequency")
		if v != null:
			speech_frequency = int(v)
		v = options.get_setting(MENU_ID, "p1_speech_enabled")
		if v != null:
			p1_speech_enabled = bool(v)
		v = options.get_setting(MENU_ID, "p2_speech_enabled")
		if v != null:
			p2_speech_enabled = bool(v)
		v = options.get_setting(MENU_ID, "p1_speech_profile")
		if v != null:
			p1_speech_profile = int(v)
		v = options.get_setting(MENU_ID, "p2_speech_profile")
		if v != null:
			p2_speech_profile = int(v)
		v = options.get_setting(MENU_ID, "show_error_popups")
		if v != null:
			show_error_popups = bool(v)
		v = options.get_setting(MENU_ID, "auto_lock_in")
		if v != null:
			auto_lock_in = v
		v = options.get_setting(MENU_ID, "debug_logging")
		if v != null:
			debug_logging = v
		v = options.get_setting(MENU_ID, "think_after_lock")
		if v != null:
			think_after_lock = v
		v = options.get_setting(MENU_ID, "random_skill_aivai")
		if v != null:
			random_skill_aivai = v
		v = options.get_setting(MENU_ID, "plan_ahead")
		if v != null:
			plan_ahead = v
		v = options.get_setting(MENU_ID, "study")
		if v != null:
			study = v
		if study:
			debug_logging = true
	performance_profile = int(clamp(performance_profile, PERFORMANCE_FAST, PERFORMANCE_EPIC))
	performance_mode = performance_profile == PERFORMANCE_FAST
	LearningAlgorithm = int(clamp(LearningAlgorithm, LEARNING_ADAPTIVE, LEARNING_COMBO))
	patience_mode = int(clamp(patience_mode, PATIENCE_GOD_LEVEL, PATIENCE_FERAL))
	di_policy = int(clamp(di_policy, DI_POLICY_STRATEGIST, DI_POLICY_UNPREDICTABLE))
	resource_strategy = int(clamp(resource_strategy, RESOURCE_ADAPTIVE, RESOURCE_SAVE))
	speech_frequency = int(clamp(speech_frequency, 0, 2))
	p1_speech_profile = int(clamp(p1_speech_profile, 0, 3))
	p2_speech_profile = int(clamp(p2_speech_profile, 0, 3))
	ReloadCustomDialogues()
	_refresh_think_budget()
	if ai_player == 0:
		queue_free()
		return
	if ai_player == 3:
		both_ai = true
		ai_player = forced_player
	elif forced_player != 0 and ai_player != forced_player:
		# This side belongs to a human.
		queue_free()
		return
	# AI-vs-AI has a different legacy base allowance, so refresh after its
	# side ownership has been resolved.
	_refresh_think_budget()
	# A side-specific value of zero means "Use Shared Skill". Nonzero menu
	# indices map back to the original 0..4 difficulty scale.
	var side_skill = p1_difficulty if ai_player == 1 else p2_difficulty
	if side_skill > 0:
		difficulty = int(clamp(side_skill - 1, 0, DIFFICULTY_TEMPS.size() - 1))
	behavior_profile = p1_behavior if ai_player == 1 else p2_behavior
	behavior_profile = int(clamp(behavior_profile, BEHAVIOR_CLASSIC, BEHAVIOR_DEFENSIVE))
	if both_ai and random_skill_aivai:
		# Each side rolls independently after side settings resolve.
		difficulty = rng.randi() % DIFFICULTY_TEMPS.size()
		if debug_logging:
			print("CombatAI Strategist P%d random skill -> %d" % [ai_player, difficulty])
	add_to_group("combat_ai_strategist_memory")
	if learning_enabled:
		_load_book()
		_load_bursts()
	game.connect("player_actionable", self, "_on_turn_started")


func _exit_tree():
	# Don't leak a resim token if freed mid-think - it would strand the real
	# game in resimulation for the other brain.
	if resim_held and _resim_end():
		ReplayManager.resimulating = false
	if learning_enabled and is_instance_valid(game) and !LearningPending.empty():
		for PendingId in LearningPending.keys():
			var Pending = LearningPending[PendingId]
			var OutcomeActor = game.get_player(int(PendingId))
			if OutcomeActor == null or !is_instance_valid(OutcomeActor) or OutcomeActor.opponent == null:
				continue
			var DamageDealt = max(0.0, float(Pending.get("foe_hp", OutcomeActor.opponent.hp)) - float(OutcomeActor.opponent.hp))
			var DamageTaken = max(0.0, float(Pending.get("self_hp", OutcomeActor.hp)) - float(OutcomeActor.hp))
			var ComboGrowth = max(0, int(OutcomeActor.combo_count) - int(Pending.get("combo", 0)))
			var DefensiveEscape = int(Pending.get("foe_combo", 0)) > 0 and int(OutcomeActor.opponent.combo_count) <= 0 and DamageTaken <= 0.0
			var ConvertedOpportunity = DamageDealt > 0.0 or ComboGrowth > 0 or DefensiveEscape
			var OutcomeReward = DamageDealt * 2.0 - DamageTaken * 2.25
			if DamageDealt > 0.0:
				OutcomeReward += 30.0
			if ComboGrowth > 0:
				OutcomeReward += float(ComboGrowth) * 20.0
			if DefensiveEscape:
				OutcomeReward += 45.0
			if int(Pending.get("combo", 0)) > 0 and int(OutcomeActor.combo_count) <= 0 and DamageDealt <= 0.0:
				OutcomeReward -= 60.0
			if str(Pending.get("action", "")) != "Continue" and DamageDealt <= 0.0 and ComboGrowth <= 0 and !DefensiveEscape:
				OutcomeReward -= 20.0
			if float(OutcomeActor.opponent.hp) <= 0.0:
				OutcomeReward += 500.0
			if float(OutcomeActor.hp) <= 0.0:
				OutcomeReward -= 500.0
			var SourceAllowed = LearningAlgorithm == LEARNING_ADAPTIVE or (LearningAlgorithm == LEARNING_REINFORCEMENT and bool(Pending.get("is_ai", false))) or (LearningAlgorithm == LEARNING_IMITATION and !bool(Pending.get("is_ai", false))) or (LearningAlgorithm == LEARNING_COMBO and (int(Pending.get("combo", 0)) > 0 or DamageDealt > 0.0 or ComboGrowth > 0))
			if !SourceAllowed:
				continue
			var CharacterKey = str(Pending.get("character", ""))
			if CharacterKey == "":
				continue
			if !LearningBook.has(CharacterKey) or !(LearningBook[CharacterKey] is Dictionary):
				LearningBook[CharacterKey] = {}
			if !LearningDirty.has(CharacterKey) or !(LearningDirty[CharacterKey] is Dictionary):
				LearningDirty[CharacterKey] = {}
			for ContextKey in [str(Pending.get("context", "*")), "*"]:
				if !LearningBook[CharacterKey].has(ContextKey) or !(LearningBook[CharacterKey][ContextKey] is Dictionary):
					LearningBook[CharacterKey][ContextKey] = {}
				if !LearningDirty[CharacterKey].has(ContextKey) or !(LearningDirty[CharacterKey][ContextKey] is Dictionary):
					LearningDirty[CharacterKey][ContextKey] = {}
				for CandidateKey in ["A:" + str(Pending.get("action", "Continue")), "V:" + str(Pending.get("variant", ""))]:
					var BookRecord = LearningBook[CharacterKey][ContextKey].get(CandidateKey, {})
					if !(BookRecord is Dictionary):
						BookRecord = {}
					BookRecord["uses"] = float(BookRecord.get("uses", 0.0)) + 1.0
					BookRecord["reward"] = float(BookRecord.get("reward", 0.0)) + OutcomeReward
					BookRecord["positive"] = float(BookRecord.get("positive", 0.0)) + (1.0 if OutcomeReward > 0.0 else 0.0)
					BookRecord["negative"] = float(BookRecord.get("negative", 0.0)) + (1.0 if OutcomeReward < 0.0 else 0.0)
					BookRecord["damage_dealt"] = float(BookRecord.get("damage_dealt", 0.0)) + DamageDealt
					BookRecord["damage_taken"] = float(BookRecord.get("damage_taken", 0.0)) + DamageTaken
					BookRecord["opportunities"] = float(BookRecord.get("opportunities", 0.0)) + 1.0
					BookRecord["conversions"] = float(BookRecord.get("conversions", 0.0)) + (1.0 if ConvertedOpportunity else 0.0)
					LearningBook[CharacterKey][ContextKey][CandidateKey] = BookRecord
					var DirtyRecord = LearningDirty[CharacterKey][ContextKey].get(CandidateKey, {})
					if !(DirtyRecord is Dictionary):
						DirtyRecord = {}
					DirtyRecord["uses"] = float(DirtyRecord.get("uses", 0.0)) + 1.0
					DirtyRecord["reward"] = float(DirtyRecord.get("reward", 0.0)) + OutcomeReward
					DirtyRecord["positive"] = float(DirtyRecord.get("positive", 0.0)) + (1.0 if OutcomeReward > 0.0 else 0.0)
					DirtyRecord["negative"] = float(DirtyRecord.get("negative", 0.0)) + (1.0 if OutcomeReward < 0.0 else 0.0)
					DirtyRecord["damage_dealt"] = float(DirtyRecord.get("damage_dealt", 0.0)) + DamageDealt
					DirtyRecord["damage_taken"] = float(DirtyRecord.get("damage_taken", 0.0)) + DamageTaken
					DirtyRecord["opportunities"] = float(DirtyRecord.get("opportunities", 0.0)) + 1.0
					DirtyRecord["conversions"] = float(DirtyRecord.get("conversions", 0.0)) + (1.0 if ConvertedOpportunity else 0.0)
					LearningDirty[CharacterKey][ContextKey][CandidateKey] = DirtyRecord
		LearningPending.clear()
	if study and is_instance_valid(fighter):
		var them = fighter.opponent
		print("CAISTUDY match end p=%d turns=%d hp=%s foehp=%s result=%s foe_moves_seen=%d" % [
			ai_player, study_turn, _study_num(fighter.hp),
			_study_num(them.hp) if is_instance_valid(them) else "?",
			("won" if (is_instance_valid(them) and them.hp <= 0) else ("lost" if fighter.hp <= 0 else "unfinished")),
			foe_turns])
	# Commit any combo still running when the match ends.
	if learning_enabled:
		for pid in combo_live.keys():
			_book_commit(pid, combo_live[pid])
		if !LearningDirty.empty():
			_save_book()
	combo_live.clear()


# Mod Options one-shot memory controls call these methods through a group so
# both AI brains drop their loaded copies before either can save stale data
# back over a file that the user just cleared.
func clear_saved_combo_memory():
	combo_book.clear()
	combo_live.clear()
	last_action_by.clear()
	LearningBook.clear()
	LearningDirty.clear()
	LearningPending.clear()
	LearningRecent.clear()
	LearningSaveCounter = 0


func clear_saved_burst_memory():
	burst_book.clear()


func clear_study_and_match_memory():
	foe_history.clear()
	foe_turns = 0
	LearningPending.clear()
	LearningRecent.clear()
	last_predicted.clear()
	last_plan_src = "none"
	study_turn = 0
	last_ai_choice = ""
	last_ai_choice_streak = 0
	speech_turns = 0
	speech_started = false
	recent_ai_actions.clear()
	stagnation_turns = 0
	progress_snapshot = null
	last_parry_bail = "not-run"
	last_feint_diag = "not-run"


func ReloadCustomDialogues():
	custom_speech = {1: {}, 2: {}}
	var DialogueDirectory = Directory.new()
	if !DialogueDirectory.dir_exists("user://CombatAIStrategist"):
		var DirectoryError = DialogueDirectory.make_dir_recursive("user://CombatAIStrategist")
		if DirectoryError != OK:
			push_error("CombatAI Strategist: could not create the custom dialogue folder (error %d)" % DirectoryError)
			return false
	var DialogueFile = File.new()
	if !DialogueFile.file_exists(DIALOGUE_PATH):
		var ExampleFile = File.new()
		if ExampleFile.open("res://_CombatAIStrategist/dialogues.example.json", File.READ) != OK:
			push_error("CombatAI Strategist: could not load the custom dialogue template")
			return false
		var ExampleText = ExampleFile.get_as_text()
		ExampleFile.close()
		if DialogueFile.open(DIALOGUE_PATH, File.WRITE) != OK:
			push_error("CombatAI Strategist: could not create custom_dialogues.json")
			return false
		DialogueFile.store_string(ExampleText)
		DialogueFile.close()
	var OpenError = DialogueFile.open(DIALOGUE_PATH, File.READ)
	if OpenError != OK:
		push_error("CombatAI Strategist: could not open custom dialogues (error %d)" % OpenError)
		return false
	var ParsedDialogues = JSON.parse(DialogueFile.get_as_text())
	DialogueFile.close()
	if ParsedDialogues.error != OK or !(ParsedDialogues.result is Dictionary):
		if main_node != null and !main_node.has_meta("cas_dialogue_error"):
			main_node.set_meta("cas_dialogue_error", true)
			_report_fault("E106", "Custom dialogue JSON is invalid at line %d. The file was preserved." % ParsedDialogues.error_line)
		return false
	for Side in [1, 2]:
		var SideData = ParsedDialogues.result.get("player%d" % Side, {})
		if !(SideData is Dictionary):
			continue
		for Situation in ["opening", "attack", "combo", "defense", "winning", "losing", "finisher"]:
			var StoredLines = SideData.get(Situation, [])
			var CleanLines = []
			if StoredLines is Array:
				for StoredLine in StoredLines:
					var CleanLine = str(StoredLine).strip_edges()
					if CleanLine != "":
						CleanLines.append(CleanLine)
			elif StoredLines is String:
				for StoredLine in StoredLines.split("|", false):
					var CleanLine = str(StoredLine).strip_edges()
					if CleanLine != "":
						CleanLines.append(CleanLine)
			custom_speech[Side][Situation] = CleanLines
	return true

func _turn_started_player(player):
	if player != null:
		player.connect("action_selected", self, "_on_foe_action", [player])
		starting_hp[ai_player] = max(1.0, float(fighter.hp))
		starting_hp[int(player.id)] = max(1.0, float(player.hp))
func _on_turn_started():
	if fighter == null:
		fighter = game.get_player(ai_player)
		if fighter == null:
			_report_fault("E101", "No fighter exists for AI player %d. This Strategist brain was disabled for the match." % ai_player)
			queue_free()
			return
		fighter.connect("action_selected", self, "_on_lock_in")
		for player in game.players.values():
			_turn_started_player(player)
		
		if debug_logging:
			print("CombatAI: controlling player %d" % ai_player)
		if study:
			var them = fighter.opponent
			print("CAISTUDY match start p=%d me=%s foe=%s skill=%d behavior=%d coverage=%d awareness=%d depth=%d selection=%d winner=%d influence=%d pacing=%d visibility=%d hp=%s foehp=%s planahead=%d" % [
				ai_player, _book_char_key(ai_player), _book_char_key(them.id if them != null else 0),
				difficulty, behavior_profile, search_mode, awareness, tactical_depth, move_selection,
				preferred_winner, director_strength, battle_pacing, move_visibility,
				_study_num(fighter.hp), _study_num(them.hp) if them != null else "?",
				1 if plan_ahead else 0])
	if learning_enabled and !LearningPending.empty():
		for PendingId in LearningPending.keys():
			var Pending = LearningPending[PendingId]
			if int(Pending.get("tick", game.current_tick)) == int(game.current_tick):
				continue
			var OutcomeActor = game.get_player(int(PendingId))
			if OutcomeActor == null or !is_instance_valid(OutcomeActor) or OutcomeActor.opponent == null:
				LearningPending.erase(PendingId)
				continue
			var DamageDealt = max(0.0, float(Pending.get("foe_hp", OutcomeActor.opponent.hp)) - float(OutcomeActor.opponent.hp))
			var DamageTaken = max(0.0, float(Pending.get("self_hp", OutcomeActor.hp)) - float(OutcomeActor.hp))
			var ComboGrowth = max(0, int(OutcomeActor.combo_count) - int(Pending.get("combo", 0)))
			var DefensiveEscape = int(Pending.get("foe_combo", 0)) > 0 and int(OutcomeActor.opponent.combo_count) <= 0 and DamageTaken <= 0.0
			var ConvertedOpportunity = DamageDealt > 0.0 or ComboGrowth > 0 or DefensiveEscape
			var OutcomeReward = DamageDealt * 2.0 - DamageTaken * 2.25
			if DamageDealt > 0.0:
				OutcomeReward += 30.0
			if ComboGrowth > 0:
				OutcomeReward += float(ComboGrowth) * 20.0
			if DefensiveEscape:
				OutcomeReward += 45.0
			if int(Pending.get("combo", 0)) > 0 and int(OutcomeActor.combo_count) <= 0 and DamageDealt <= 0.0:
				OutcomeReward -= 60.0
			if str(Pending.get("action", "")) != "Continue" and DamageDealt <= 0.0 and ComboGrowth <= 0 and !DefensiveEscape:
				OutcomeReward -= 20.0
			if float(OutcomeActor.opponent.hp) <= 0.0:
				OutcomeReward += 500.0
			if float(OutcomeActor.hp) <= 0.0:
				OutcomeReward -= 500.0
			var SourceAllowed = LearningAlgorithm == LEARNING_ADAPTIVE or (LearningAlgorithm == LEARNING_REINFORCEMENT and bool(Pending.get("is_ai", false))) or (LearningAlgorithm == LEARNING_IMITATION and !bool(Pending.get("is_ai", false))) or (LearningAlgorithm == LEARNING_COMBO and (int(Pending.get("combo", 0)) > 0 or DamageDealt > 0.0 or ComboGrowth > 0))
			if SourceAllowed:
				var CreditTargets = [{"entry": Pending, "weight": 1.0, "current": true}]
				var RecentEntries = LearningRecent.get(int(PendingId), [])
				var PreviousCount = 0
				for RecentIndex in range(RecentEntries.size() - 1, -1, -1):
					if PreviousCount >= 2:
						break
					PreviousCount += 1
					CreditTargets.append({"entry": RecentEntries[RecentIndex], "weight": pow(0.5, PreviousCount), "current": false})
				for CreditTarget in CreditTargets:
					var CreditEntry = CreditTarget.entry
					var CreditWeight = float(CreditTarget.weight)
					var CharacterKey = str(CreditEntry.get("character", ""))
					if CharacterKey == "":
						continue
					if !LearningBook.has(CharacterKey) or !(LearningBook[CharacterKey] is Dictionary):
						LearningBook[CharacterKey] = {}
					if !LearningDirty.has(CharacterKey) or !(LearningDirty[CharacterKey] is Dictionary):
						LearningDirty[CharacterKey] = {}
					for ContextKey in [str(CreditEntry.get("context", "*")), "*"]:
						if !LearningBook[CharacterKey].has(ContextKey) or !(LearningBook[CharacterKey][ContextKey] is Dictionary):
							LearningBook[CharacterKey][ContextKey] = {}
						if !LearningDirty[CharacterKey].has(ContextKey) or !(LearningDirty[CharacterKey][ContextKey] is Dictionary):
							LearningDirty[CharacterKey][ContextKey] = {}
						for CandidateKey in ["A:" + str(CreditEntry.get("action", "Continue")), "V:" + str(CreditEntry.get("variant", ""))]:
							var UsesDelta = 1.0 if bool(CreditTarget.current) else 0.0
							var ConversionDelta = 1.0 if bool(CreditTarget.current) and ConvertedOpportunity else 0.0
							var PositiveDelta = 1.0 if bool(CreditTarget.current) and OutcomeReward > 0.0 else 0.0
							var NegativeDelta = 1.0 if bool(CreditTarget.current) and OutcomeReward < 0.0 else 0.0
							var BookRecord = LearningBook[CharacterKey][ContextKey].get(CandidateKey, {})
							if !(BookRecord is Dictionary):
								BookRecord = {}
							BookRecord["uses"] = float(BookRecord.get("uses", 0.0)) + UsesDelta
							BookRecord["reward"] = float(BookRecord.get("reward", 0.0)) + OutcomeReward * CreditWeight
							BookRecord["positive"] = float(BookRecord.get("positive", 0.0)) + PositiveDelta
							BookRecord["negative"] = float(BookRecord.get("negative", 0.0)) + NegativeDelta
							BookRecord["damage_dealt"] = float(BookRecord.get("damage_dealt", 0.0)) + DamageDealt * CreditWeight
							BookRecord["damage_taken"] = float(BookRecord.get("damage_taken", 0.0)) + DamageTaken * CreditWeight
							BookRecord["opportunities"] = float(BookRecord.get("opportunities", 0.0)) + UsesDelta
							BookRecord["conversions"] = float(BookRecord.get("conversions", 0.0)) + ConversionDelta
							LearningBook[CharacterKey][ContextKey][CandidateKey] = BookRecord
							var DirtyRecord = LearningDirty[CharacterKey][ContextKey].get(CandidateKey, {})
							if !(DirtyRecord is Dictionary):
								DirtyRecord = {}
							DirtyRecord["uses"] = float(DirtyRecord.get("uses", 0.0)) + UsesDelta
							DirtyRecord["reward"] = float(DirtyRecord.get("reward", 0.0)) + OutcomeReward * CreditWeight
							DirtyRecord["positive"] = float(DirtyRecord.get("positive", 0.0)) + PositiveDelta
							DirtyRecord["negative"] = float(DirtyRecord.get("negative", 0.0)) + NegativeDelta
							DirtyRecord["damage_dealt"] = float(DirtyRecord.get("damage_dealt", 0.0)) + DamageDealt * CreditWeight
							DirtyRecord["damage_taken"] = float(DirtyRecord.get("damage_taken", 0.0)) + DamageTaken * CreditWeight
							DirtyRecord["opportunities"] = float(DirtyRecord.get("opportunities", 0.0)) + UsesDelta
							DirtyRecord["conversions"] = float(DirtyRecord.get("conversions", 0.0)) + ConversionDelta
							LearningDirty[CharacterKey][ContextKey][CandidateKey] = DirtyRecord
				RecentEntries.append(Pending)
				while RecentEntries.size() > 3:
					RecentEntries.pop_front()
				LearningRecent[int(PendingId)] = RecentEntries
				LearningSaveCounter += 1
				if LearningSaveCounter >= 4:
					_save_book()
			LearningPending.erase(PendingId)
	# (A busy_interrupt skip lived here for one build - WRONG: the game's
	# is_waiting_on_player() is just `p1.state_interruptable or p2.state_
	# interruptable`, and the turn scan sets that flag on BOTH fighters
	# unconditionally. The game waits for a busy fighter's input too - they
	# submit Continue - so skipping stalled the match until a human locked
	# for us. Every turn is our turn.)
	# The game emits player_actionable once per actionable player; one
	# thinking session per turn boundary is enough. That includes re-fires
	# AFTER a completed think (seen as duplicate decisions in telemetry):
	# the state at the same tick is the same, the decision stands.
	if last_turn_tick == game.current_tick and (session_active or decided_action != null):
		return
	last_turn_tick = game.current_tick
	# Deferred-thinking mode: wait for the player's lock before burning any
	# cycles. (Not in AI-vs-AI - there's no human to wait for.) If they
	# somehow locked before we got here, think right away. Void last
	# turn's decision NOW - the deferred trigger uses "no decision yet"
	# to know this turn still needs thinking.
	var waits_for_lock = think_after_lock or _side_has_locked_move_visibility(ai_player)
	if waits_for_lock and !both_ai and foe_lock_tick != game.current_tick:
		decided_action = null
		decided_data = null
		decided_extra = null
		return
	# AI-vs-AI is strictly turn-taking: one brain thinks at the boundary and
	# locks, THEN the other thinks (triggered by the first lock arriving in
	# _on_foe_action) with the whole frame budget to itself. Two brains
	# interleaving on one thread never ran in parallel anyway - they just
	# halved each other's budget slices, stomped the shared resim flag, and
	# raced sessions. Fairness is intact: every sim freshly copies the game
	# and overwrites BOTH fighters' queued actions with its own hypothesis,
	# so the second thinker never reads the first's locked move.
	if both_ai and ai_player != _aivai_first_player() and foe_lock_tick != game.current_tick:
		decided_action = null
		decided_data = null
		decided_extra = null
		return
	var t = _think()
	if t is GDScriptFunctionState:
		pass # thinking continues across frames


# The player locked the turn in. If we already decided, apply our move over
# whatever the UI had selected for us. If we're still thinking, hold the turn
# open (the game waits while state_interruptable is true) and _finish submits.
func _on_foe_action(action, data, extra):
	var ObservedPreviousAction = str(last_action_by.get(int(fighter.opponent.id), "")) if is_instance_valid(fighter) and fighter.opponent != null else ""
	if action is String and action != "":
		revealed_foe_action = action
		revealed_foe_data = _duplicate_input(data)
		revealed_foe_extra = _duplicate_input(extra)
		revealed_foe_tick = game.current_tick
	if learning_enabled and action is String and action != "":
		foe_history[action] = foe_history.get(action, 0) + 1
		foe_turns += 1
		if study:
			_study_foe_move(action)
	if learning_enabled and !both_ai and action is String and action != "" and is_instance_valid(fighter) and fighter.opponent != null:
		var ObservedActor = fighter.opponent
		var ObservedFoe = fighter
		var ObservedGap = Vector2(ObservedFoe.get_pos().x - ObservedActor.get_pos().x, ObservedFoe.get_pos().y - ObservedActor.get_pos().y).length()
		var ObservedRange = "close" if ObservedGap < 140.0 else ("mid" if ObservedGap < 420.0 else "far")
		var ObservedPhase = "combo" if int(ObservedActor.combo_count) > 0 else ("defense" if int(ObservedFoe.combo_count) > 0 else "neutral")
		var ObservedHeight = ("ground" if ObservedActor.has_method("is_grounded") and ObservedActor.is_grounded() else "air") + ":" + ("ground" if ObservedFoe.has_method("is_grounded") and ObservedFoe.is_grounded() else "air")
		var ObservedHealth = "ahead" if float(ObservedActor.hp) > float(ObservedFoe.hp) * 1.1 else ("behind" if float(ObservedFoe.hp) > float(ObservedActor.hp) * 1.1 else "even")
		var ObservedContext = ObservedRange + "|" + ObservedPhase + "|" + ObservedHeight + "|" + ObservedHealth + "|prev:" + _norm_name(ObservedPreviousAction)
		var ObservedLearningExtra = extra.duplicate(true) if extra is Dictionary else extra
		if ObservedLearningExtra is Dictionary:
			ObservedLearningExtra.erase("DI")
			ObservedLearningExtra.erase("prediction")
		var ObservedVariant = _fingerprint([str(action), data, ObservedLearningExtra], 0)
		if ObservedVariant == null:
			ObservedVariant = str(action)
		LearningPending[int(ObservedActor.id)] = {
			"tick": int(game.current_tick),
			"character": _book_char_key(int(ObservedActor.id)),
			"context": ObservedContext,
			"action": str(action),
			"variant": str(ObservedVariant),
			"self_hp": float(ObservedActor.hp),
			"foe_hp": float(ObservedFoe.hp),
			"combo": int(ObservedActor.combo_count),
			"foe_combo": int(ObservedFoe.combo_count),
			"is_ai": false,
		}
	# In AI-vs-AI each brain records only its own side - the other brain
	# covers the foe, so routes aren't committed twice.
	if learning_enabled and !both_ai and is_instance_valid(fighter) and fighter.opponent != null:
		_book_track(int(fighter.opponent.id), action)
		_burst_track(int(fighter.opponent.id), action)
	# Fair mode ignores the cached lock. Visibility modes opt into using it;
	# the permission check happens inside _think, never implicitly here.
	foe_lock_tick = game.current_tick
	# Deferred-thinking mode (human matches) and the second brain's turn in
	# sequential AI-vs-AI both start here: the other side has committed -
	# think NOW. A visibility-permitted side scores against the cached lock;
	# otherwise this remains the original prediction-only path.
	var my_turn_now = ((think_after_lock or _side_has_locked_move_visibility(ai_player)) and !both_ai) or (both_ai and ai_player == _aivai_second_player())
	if my_turn_now and game.current_tick == last_turn_tick and !session_active and decided_action == null:
		_show_status()
		var t = _think()
		if t is GDScriptFunctionState:
			pass # thinking continues across frames


func _side_has_locked_move_visibility(player_id):
	return move_visibility == VISIBILITY_BOTH or (move_visibility == VISIBILITY_P1_READS and int(player_id) == 1) or (move_visibility == VISIBILITY_P2_READS and int(player_id) == 2)


func _aivai_first_player():
	if move_visibility == VISIBILITY_P1_READS:
		return 2
	if move_visibility == VISIBILITY_P2_READS:
		return 1
	if move_visibility == VISIBILITY_BOTH:
		# Same-turn mutual perfect response has no finite solution. Alternate
		# which permitted side commits first. Store the choice on Main so both
		# brains observe the same value and variable-length actions cannot skew
		# alternation through current-tick parity.
		var tick = int(game.current_tick)
		var stored_tick = int(main_node.get_meta("cas_reveal_order_tick")) if main_node.has_meta("cas_reveal_order_tick") else -1
		if stored_tick != tick:
			var previous = int(main_node.get_meta("cas_reveal_first")) if main_node.has_meta("cas_reveal_first") else 2
			main_node.set_meta("cas_reveal_first", 2 if previous == 1 else 1)
			main_node.set_meta("cas_reveal_order_tick", tick)
		return int(main_node.get_meta("cas_reveal_first"))
	return 1


func _aivai_second_player():
	return 2 if _aivai_first_player() == 1 else 1


func _has_current_reveal():
	return _side_has_locked_move_visibility(ai_player) and revealed_foe_tick == game.current_tick and revealed_foe_action is String and revealed_foe_action != ""


func _duplicate_input(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _on_lock_in(action, Data, Extra):
	var PreviousAction = str(last_action_by.get(ai_player, ""))
	if action is String:
		if action == last_ai_choice:
			last_ai_choice_streak += 1
		else:
			last_ai_choice_streak = 1
		last_ai_choice = action
		if both_ai:
			recent_ai_actions.append(action)
			while recent_ai_actions.size() > LOOP_HISTORY_LIMIT:
				recent_ai_actions.pop_front()
			progress_snapshot = _combat_progress_snapshot()
	if learning_enabled:
		_book_track(ai_player, action)
		_burst_track(ai_player, action)
		if action is String and action != "" and is_instance_valid(fighter) and fighter.opponent != null:
			var LearningFoe = fighter.opponent
			var LearningGap = Vector2(LearningFoe.get_pos().x - fighter.get_pos().x, LearningFoe.get_pos().y - fighter.get_pos().y).length()
			var LearningRange = "close" if LearningGap < 140.0 else ("mid" if LearningGap < 420.0 else "far")
			var LearningPhase = "combo" if int(fighter.combo_count) > 0 else ("defense" if int(LearningFoe.combo_count) > 0 else "neutral")
			var LearningHeight = ("ground" if fighter.has_method("is_grounded") and fighter.is_grounded() else "air") + ":" + ("ground" if LearningFoe.has_method("is_grounded") and LearningFoe.is_grounded() else "air")
			var LearningHealth = "ahead" if float(fighter.hp) > float(LearningFoe.hp) * 1.1 else ("behind" if float(LearningFoe.hp) > float(fighter.hp) * 1.1 else "even")
			var LearningContext = LearningRange + "|" + LearningPhase + "|" + LearningHeight + "|" + LearningHealth + "|prev:" + _norm_name(PreviousAction)
			var LearningExtra = Extra.duplicate(true) if Extra is Dictionary else Extra
			if LearningExtra is Dictionary:
				LearningExtra.erase("DI")
				LearningExtra.erase("prediction")
			var LearningVariant = _fingerprint([str(action), Data, LearningExtra], 0)
			if LearningVariant == null:
				LearningVariant = str(action)
			LearningPending[ai_player] = {
				"tick": int(game.current_tick),
				"character": _book_char_key(ai_player),
				"context": LearningContext,
				"action": str(action),
				"variant": str(LearningVariant),
				"self_hp": float(fighter.hp),
				"foe_hp": float(LearningFoe.hp),
				"combo": int(fighter.combo_count),
				"foe_combo": int(LearningFoe.combo_count),
				"is_ai": true,
			}
	if session_active and background_thinking:
		held_turn = true
		fighter.state_interruptable = true
		# Only now is anyone actually waiting on the AI, so only now show it.
		_show_status()
	else:
		fighter.queued_action = decided_action
		fighter.queued_data = decided_data
		fighter.queued_extra = decided_extra


func _think():
	_update_stagnation()
	session += 1
	var my_session = session
	session_active = true
	sims_done = 0
	sim_cache_hits = 0
	sim_cache.clear()
	# Character transformations and resource-dependent data UIs can change
	# legal actions/default inputs mid-match. Refresh these lightweight caches
	# once per decision; never carry stale character data across turns.
	move_data_cache.clear()
	action_names_cache.clear()
	action_buttons_cache.clear()
	slice_started = OS.get_ticks_msec()
	session_deadline = OS.get_ticks_msec() + _think_deadline_ms()
	# Safe placeholder in case anything slips through mid-thought.
	decided_action = null
	decided_data = null
	decided_extra = null
	decided_category = "Utility"
	decided_terms = {}
	fighter.queued_action = null
	fighter.queued_data = null
	fighter.queued_extra = null
	_resim_begin()
	if background_thinking:
		_show_status()
	if debug_logging:
		print("CombatAI P%d think @%s (session %d)" % [ai_player, str(game.current_tick), my_session])

	var foe = fighter.opponent
	var extra = _make_extra(_default_di())

	# Pick DI by simulation while we're being comboed. Respect-UI mode leaves
	# ownership with the DI widget (including Automatic DI) and never replaces
	# the value it selected.
	if foe.combo_count > 0 and di_policy != DI_POLICY_RESPECT_UI:
		var di_pick = _pick_di(my_session)
		if di_pick is GDScriptFunctionState:
			di_pick = yield(di_pick, "completed")
		if di_pick == null:
			_abort(my_session)
			return
		extra = _make_extra(di_pick)

	# Predict the opponent by simulating their options against us idling and
	# taking their best. Blunder tiers (Novice/Adept) skip it - prediction
	# quality is wasted on them and it halves their think time.
	#
	# On a healthy machine we score their WHOLE kit. Overloaded (tier 2) we
	# can't afford ~30 sims, but the fix for that is NOT to go blind: we score
	# only their most-played moves (a mini-sweep). Simulating your top ten
	# habits is a handful of sims, cheap even on the heaviest matchup, and it
	# gives a real read - which of the things you actually do beats me right
	# now - instead of the old single "most frequent move" guess that let the
	# AI walk into every combo.
	var foe_plan = ["Continue", null, null]
	var foe_plan_key = "Continue|0|0"
	var predicted = []
	last_predicted = []
	last_plan_src = "idle"
	var has_reveal = _has_current_reveal()
	# Enhanced awareness and comprehensive coverage always build the complete
	# legal opponent table. Skill still controls depth and final selection.
	# Fast mode spends its limited time on our own legal-action table. It uses
	# a learned habit/burst fallback for the foe instead of a second full table.
	var full_sweep = !has_reveal and !performance_mode and (search_mode >= SEARCH_FULL_ACTIONS or awareness >= AWARENESS_ENHANCED or tactical_depth >= 2 or (difficulty >= 2 and strain_tier < 2))
	var mini_sweep = !has_reveal and !full_sweep and difficulty >= 2 and strain_tier >= 2 and foe_turns >= HABIT_MIN_TURNS
	if full_sweep or mini_sweep:
		var beam = null
		if mini_sweep:
			beam = _habit_beam(foe, HABIT_PREDICT_TOP)
		if !mini_sweep or (beam != null and beam.size() > 0):
			predicted = _best_for(foe.id, "Continue", null, my_session, beam)
			if predicted is GDScriptFunctionState:
				predicted = yield(predicted, "completed")
			if predicted == null:
				_abort(my_session)
				return
			if predicted.size() > 0:
				var top = _argmax(predicted)
				foe_plan = [top.action, top.data, top.get("extra")]
				foe_plan_key = top.key
				last_predicted = predicted
				last_plan_src = "mini" if mini_sweep else "sweep"

	# Nothing simulated at all (blunder tier, or too few turns for a habit
	# beam)? Then do NOT score everything against an opponent who politely
	# stands still - that mannequin was the single biggest hole in overloaded
	# play. Fall back to their single most-played move. Zero sims.
	if !has_reveal and predicted.size() == 0 and learning_enabled and foe_turns >= HABIT_MIN_TURNS:
		var habit = _most_played(foe)
		if habit != "":
			foe_plan = [habit, null, null]
			foe_plan_key = habit + "|0|0"
			last_plan_src = "habit"

	# Burst read: once we have comboed them as deep as this character tends to
	# burst at, plan for the burst - whatever the sweep otherwise predicted.
	# Scoring our options against an incoming burst makes the AI defend it
	# (space it out, block or parry via the solver) instead of extending into
	# it. Fires at every difficulty>=2 and every tier, since it costs no sims.
	if !has_reveal and difficulty >= 2 and fighter.combo_count > 0 and _burst_read_confident(foe.id):
		var foe_burst = _usable_burst(foe)
		if foe_burst != "" and fighter.combo_count >= _burst_depth_for(foe.id):
			foe_plan = [foe_burst, null, null]
			foe_plan_key = foe_burst + "|0|0"
			last_plan_src = "burst"

	# Explicit perfect-information mode: use the actual committed action and
	# its exact data/extra inputs. Prediction work above was skipped entirely.
	if has_reveal:
		foe_plan = [revealed_foe_action, _duplicate_input(revealed_foe_data), _duplicate_input(revealed_foe_extra)]
		foe_plan_key = "revealed|" + str(revealed_foe_action)
		last_plan_src = "revealed"

	# Score all our options against their predicted plan.
	var scored = _score_options(ai_player, foe_plan[0], foe_plan[1], extra, my_session, null, foe_plan[2])
	if scored is GDScriptFunctionState:
		scored = yield(scored, "completed")
	if scored == null:
		_abort(my_session)
		return
	if scored.empty():
		_report_fault("E103", "No legal decision results were produced for Player %d. Falling back to Continue." % ai_player)
		scored = [{"action": "Continue", "data": null, "extra": extra, "score": 0.0, "category": "Utility", "terms": {}}]

	if session != my_session:
		return

	# Strategic awareness evaluates our table against several distinct,
	# already-predicted opponent plans. This is chess-like robust choice, not a
	# read: every plan was produced before the opponent's lock is observed.
	if !performance_mode and !has_reveal and awareness >= AWARENESS_STRATEGIC and predicted.size() > 1 and _search_time_available():
		var aware_ok = _blend_strategic_awareness(scored, predicted, extra, my_session)
		if aware_ok is GDScriptFunctionState:
			aware_ok = yield(aware_ok, "completed")
		if aware_ok == null:
			_abort(my_session)
			return
		if session != my_session:
			return

	# Deep search: verify that the top candidates LEAD somewhere by simming
	# one exchange further. A launcher that looks great but strands us must
	# score below a slightly weaker hit that keeps the juggle going. Brawler
	# and up - blunder tiers wouldn't keep the routes anyway.
	#
	# Mid-combo this always runs. In NEUTRAL it runs only with Plan Ahead on
	# and at Champion+, because that is where set-up characters live: without
	# it nothing values a move whose whole point is the turn after it, and the
	# AI walks into its own bad positions.
	var deep_search = fighter.combo_count > 0 or (plan_ahead and difficulty >= 3) or tactical_depth >= 1
	var deep_allowed = difficulty >= 2 or tactical_depth >= 1
	if !performance_mode and deep_allowed and (strain_tier < 2 or search_mode >= SEARCH_FULL_ACTIONS or tactical_depth >= 2) and deep_search and _search_time_available():
		var ok = _deepen(scored, COMBO_SEARCH_TOP, foe_plan[0], foe_plan[1], foe_plan[2], extra, my_session)
		if ok is GDScriptFunctionState:
			ok = yield(ok, "completed")
		if ok == null:
			_abort(my_session)
			return
		if session != my_session:
			return

	var pick = _pick_decision(_break_stagnant_loop(_relentless(scored, foe_plan[0])))

	# Champion and Master think one move deeper: what is their best answer to
	# our pick, and what should we play given that answer? Not on overloaded
	# matchups - a shallow answer now beats a deep one after a minute of lag.
	var response_allowed = difficulty >= 3 or tactical_depth >= 2
	if !performance_mode and !has_reveal and response_allowed and (strain_tier < 2 or search_mode >= SEARCH_FULL_ACTIONS or tactical_depth >= 2) and _search_time_available():
		var foe_beam = _top_actions(predicted, _beam_width())
		# Rule 3, mid-combo: a comboed player's realistic outs are burst
		# (or whatever we already predicted) - not a perfectly chosen
		# exotic counter. Searching only those stops the AI from dropping
		# combos out of fear of answers nobody actually plays.
		if fighter.combo_count > 0:
			foe_beam = {foe_plan[0]: true}
			for aname in _action_names(fighter.opponent.id):
				if aname.find("Burst") != -1:
					foe_beam[aname] = true
		var responses = _best_for(foe.id, pick.action, pick.data, my_session, foe_beam, pick.get("extra"))
		if responses is GDScriptFunctionState:
			responses = yield(responses, "completed")
		if responses == null:
			_abort(my_session)
			return
		# If their best counter IS the plan we already scored everything
		# against, the rescore would reproduce identical numbers - skip it.
		if responses is Array and responses.size() > 0 and _argmax(responses).key != foe_plan_key:
			var counter = _argmax(responses)
			var my_beam = _top_actions(scored, _beam_width())
			my_beam[pick.action] = true
			var rescored = _score_options(ai_player, counter.action, counter.data, extra, my_session, my_beam, counter.get("extra"))
			if rescored is GDScriptFunctionState:
				rescored = yield(rescored, "completed")
			if rescored == null:
				_abort(my_session)
				return
			if session != my_session:
				return
			# Blend the passes: pure vs-counter scoring assumes the foe reads
			# our exact move, which made Champion/Master shy away from combo
			# follow-ups. Lean into pass 1 harder while mid-combo.
			var w = PLY2_BLEND_COMBO if fighter.combo_count > 0 else PLY2_BLEND
			# Rule 3, neutral: an unseen "perfect counter" is a weak reason
			# to abandon a plan - if this player has never used the move we
			# fear, mostly ignore the fear.
			if foe_turns >= HABIT_MIN_TURNS and !foe_history.has(counter.action):
				w = max(w, PLY2_BLEND_UNSEEN)
			var first_pass = {}
			for e in scored:
				first_pass[e.key] = e
			for e in rescored:
				if first_pass.has(e.key):
					e.score = first_pass[e.key].score * w + e.score * (1.0 - w)
					# Deep-search exonerations (movement links) must survive
					# into the rescored pass or rule 1 re-penalizes them.
					if first_pass[e.key].get("extended"):
						e.extended = true
			scored = rescored
			pick = _pick_decision(_break_stagnant_loop(_relentless(rescored, counter.action)))

	decided_action = pick.action
	decided_data = pick.data
	decided_extra = pick.get("extra", extra)
	decided_category = str(pick.get("category", "Utility"))
	decided_terms = pick.get("terms", {}).duplicate(true)
	fighter.queued_action = decided_action
	fighter.queued_data = decided_data
	fighter.queued_extra = decided_extra
	if debug_logging:
		print("CombatAI Strategist P%d @%s: %s [%s] (score %d, %d options, best %s, %d sims + %d cache hits avg %.1fms [prep %.1fms] %.0ffps tier %d)" % [ai_player, str(game.current_tick), str(decided_action), str(pick.get("category", "Utility")), int(pick.score), scored.size(), str(_argmax(scored).action), sims_done, sim_cache_hits, avg_sim_ms, avg_prepare_ms, avg_fps, strain_tier])
	if study:
		_study_decision(pick, scored, foe_plan)
	_finish(my_session)


# In AI-vs-AI two brains think at once; they must not stomp the shared
# resimulation flag or fire the ghost preview before BOTH have decided. Each
# brain holds one token while it has a live decision; only the last to finish
# clears resimulating and starts the ghost. Solo AI: these no-op back to the
# original single-brain behavior.
func _resim_begin():
	ReplayManager.resimulating = true
	if both_ai and main_node != null and not resim_held:
		resim_held = true
		var n = main_node.get_meta("combatai_resim") if main_node.has_meta("combatai_resim") else 0
		main_node.set_meta("combatai_resim", n + 1)


func _resim_end():
	if both_ai and main_node != null and resim_held:
		resim_held = false
		var n = main_node.get_meta("combatai_resim") if main_node.has_meta("combatai_resim") else 1
		n = max(0, n - 1)
		main_node.set_meta("combatai_resim", n)
		return n == 0
	return true


func _finish(my_session):
	if session != my_session:
		return
	session_active = false
	var LastThinker = _resim_end()
	# Keep the resimulation guard until the completed AI-vs-AI decision is sent.
	# Never pause SceneTree here: the player must retain pause/menu control while
	# the frame-sliced search runs. Any early Wait is intercepted by _on_lock_in
	# and replaced synchronously below once the calculated action is ready.
	var GuardDeferredSubmit = both_ai and !held_turn and decided_action != null and auto_lock_in
	if LastThinker and !GuardDeferredSubmit:
		ReplayManager.resimulating = false
	if status_label:
		status_label.visible = false
	# A turn backup can land while a long search is yielding. Never speak,
	# submit, or restart the preview with a decision made for the abandoned
	# timeline; the restored turn's actionable signal will start a fresh
	# session. This also prevents deferred lock-ins from replaying stale move
	# data after an undo.
	if !is_instance_valid(game) or game.current_tick != last_turn_tick or bool(game.get("undoing")):
		if GuardDeferredSubmit:
			ReplayManager.resimulating = false
		held_turn = false
		decided_action = null
		decided_data = null
		decided_extra = null
		return
	if decided_action != null:
		_maybe_speak()
	var MustSubmit = held_turn
	held_turn = false
	if MustSubmit and is_instance_valid(fighter):
		# The game is holding the turn open waiting on us: submit right now.
		var action = decided_action if decided_action != null else "Continue"
		# on_action_selected converts unusable actions into Forfeit; if
		# usability shifted since we decided, back off to Continue.
		var st = fighter.state_machine.get_state(action)
		if _is_rejected_action(ai_player, action) or (st != null and st.has_method("is_usable") and !st.is_usable()):
			action = "Continue"
		fighter.on_action_selected(action, decided_data, decided_extra)
	elif decided_action != null and auto_lock_in:
		# AI-vs-AI submits synchronously so no idle frame can accept a queued Wait.
		# Solo AI stays deferred to avoid re-entering player_actionable.
		if both_ai:
			_auto_submit(my_session)
		else:
			call_deferred("_auto_submit", my_session)
	# In sequential AI-vs-AI, the first lock immediately starts the second
	# brain. Wait for that second decision before starting a preview so the
	# ghost cannot race the live search in a half-ready state.
	if LastThinker and (!both_ai or (auto_lock_in and ai_player == _aivai_second_player())):
		main_node.call_deferred("_start_ghost")


func _auto_submit(my_session):
	if session != my_session:
		if both_ai and !session_active and main_node != null and int(main_node.get_meta("combatai_resim") if main_node.has_meta("combatai_resim") else 0) == 0:
			ReplayManager.resimulating = false
		return
	if session_active:
		return
	if !is_instance_valid(game) or game.current_tick != last_turn_tick or bool(game.get("undoing")):
		if both_ai and main_node != null and int(main_node.get_meta("combatai_resim") if main_node.has_meta("combatai_resim") else 0) == 0:
			ReplayManager.resimulating = false
		decided_action = null
		decided_data = null
		decided_extra = null
		return
	if !is_instance_valid(fighter) or decided_action == null:
		if both_ai and main_node != null and int(main_node.get_meta("combatai_resim") if main_node.has_meta("combatai_resim") else 0) == 0:
			ReplayManager.resimulating = false
		return
	var action = decided_action
	var st = fighter.state_machine.get_state(action)
	if _is_rejected_action(ai_player, action) or (st != null and st.has_method("is_usable") and !st.is_usable()):
		action = "Continue"
	# Release immediately before the real lock signal. The second brain starts
	# synchronously from that signal and acquires the guard for its own search.
	if both_ai:
		ReplayManager.resimulating = false
	fighter.on_action_selected(action, decided_data, decided_extra)


func _abort(my_session):
	if session != my_session:
		return
	_finish(my_session)


func _maybe_speak():
	if !ai_speech or !is_instance_valid(fighter) or !fighter.has_method("emote") or !_speech_enabled_for_side(ai_player):
		return
	var situation = _speech_situation()
	if !speech_started:
		speech_started = true
		situation = "opening"
	else:
		speech_turns += 1
	var interval = [12, 7, 4][speech_frequency]
	if situation != "opening" and situation != "finisher" and speech_turns < interval:
		return
	speech_turns = 0
	var lines = _speech_lines(ai_player, situation)
	if lines.empty():
		return
	fighter.emote(lines[rng.randi() % lines.size()])


func _speech_enabled_for_side(side):
	return p1_speech_enabled if int(side) == 1 else p2_speech_enabled


func _speech_situation():
	if fighter.opponent != null and fighter.opponent.hp <= 0:
		return "finisher"
	var my_start = max(1.0, float(starting_hp.get(ai_player, fighter.hp)))
	var foe_start = max(1.0, float(starting_hp.get(int(fighter.opponent.id), fighter.opponent.hp))) if fighter.opponent != null else 1.0
	var my_ratio = float(fighter.hp) / my_start
	var foe_ratio = float(fighter.opponent.hp) / foe_start if fighter.opponent != null else 1.0
	if my_ratio <= 0.35 and my_ratio < foe_ratio:
		return "losing"
	if foe_ratio <= 0.35 and my_ratio > foe_ratio:
		return "winning"
	if decided_category == "Combo":
		return "combo"
	if decided_category == "Defense":
		return "defense"
	return "attack"


func _speech_lines(side, situation):
	var profile = p1_speech_profile if int(side) == 1 else p2_speech_profile
	if profile >= 0 and profile < SPEECH_PRESETS.size():
		return SPEECH_PRESETS[profile].get(situation, [])
	var CustomLines = custom_speech.get(int(side), {}).get(situation, [])
	return CustomLines if CustomLines is Array else []


# Returns [{action, data, score, key}, ...] for every option `player_id` has,
# scored against the given opposing plan. Null on session abort. When `beam`
# (a Dictionary of action names) is given, only those actions are scored.
func _score_options(player_id, versus_action, versus_data, extra, my_session, beam = null, versus_extra = null):
	var results = []
	var actor = game.get_player(player_id)
	var buttons = _action_buttons(player_id)
	if buttons == null:
		_report_fault("E102", "The Player %d action-button container could not be found. Check character and UI-mod compatibility." % int(player_id))
		return results
	if debug_logging:
		print("CombatAI sim P%s Continue vs %s" % [str(player_id), str(versus_action)])
	results.append(_scored_entry("Continue", null, extra, player_id, versus_action, versus_data, my_session, versus_extra))
	if results[0] is GDScriptFunctionState:
		results[0] = yield(results[0], "completed")
	if results[0] == null:
		return null
	results[0].key = "Continue|0|0"
	results[0].hit = last_sim_hit
	results[0].extended = last_sim_extended
	results[0].advantage = last_sim_advantage
	results[0].terms = last_sim_terms
	# Measure the parry once for the whole sweep - the answer depends only on
	# what is coming at us, not on which of our candidates we are scoring.
	# Never for the prediction sweep: that one runs against "Continue", where
	# there is nothing to block. Runs at EVERY tier: one probe of at most 20
	# ticks against a sweep of dozens of full-length sims is nothing, and
	# guessing parry timing blind is how the AI got called out for it.
	var parry_read = null
	if int(player_id) == ai_player and versus_action != "Continue":
		parry_read = _solve_parry(player_id, versus_action, versus_data, extra, my_session, versus_extra)
		if parry_read is GDScriptFunctionState:
			parry_read = yield(parry_read, "completed")
	elif int(player_id) == ai_player:
		# Foe plan is Continue (no prediction, or they idle) - nothing to
		# block, so the solver is not even called.
		last_parry_bail = "foe-idle"
	# Behavior extras are identical for every legal action in this sweep.
	# Build them once instead of allocating the same array and Dictionaries for
	# every button (especially expensive during exhaustive reverse searches).
	var action_extras = _behavior_extras(extra)
	var LearningCharacter = _book_char_key(int(player_id))
	var LearningGap = Vector2(actor.opponent.get_pos().x - actor.get_pos().x, actor.opponent.get_pos().y - actor.get_pos().y).length()
	var LearningRange = "close" if LearningGap < 140.0 else ("mid" if LearningGap < 420.0 else "far")
	var LearningPhase = "combo" if int(actor.combo_count) > 0 else ("defense" if int(actor.opponent.combo_count) > 0 else "neutral")
	var LearningHeight = ("ground" if actor.has_method("is_grounded") and actor.is_grounded() else "air") + ":" + ("ground" if actor.opponent.has_method("is_grounded") and actor.opponent.is_grounded() else "air")
	var LearningHealth = "ahead" if float(actor.hp) > float(actor.opponent.hp) * 1.1 else ("behind" if float(actor.opponent.hp) > float(actor.hp) * 1.1 else "even")
	var LearningContext = LearningRange + "|" + LearningPhase + "|" + LearningHeight + "|" + LearningHealth + "|prev:" + _norm_name(str(last_action_by.get(int(player_id), "")))
	var ProvenButtons = []
	var ExplorationButtons = []
	var PunishedButtons = []
	var OrderedButtons = []
	for PoolButton in buttons.buttons:
		var PoolUses = 0.0
		var PoolReward = 0.0
		if learning_enabled and LearningBook.has(LearningCharacter) and LearningBook[LearningCharacter] is Dictionary:
			for PoolContext in [LearningContext, "*"]:
				var PoolContextData = LearningBook[LearningCharacter].get(PoolContext, {})
				var PoolRecord = PoolContextData.get("A:" + str(PoolButton.action_name), {}) if PoolContextData is Dictionary else {}
				if PoolRecord is Dictionary:
					PoolUses += float(PoolRecord.get("uses", 0.0))
					PoolReward += float(PoolRecord.get("reward", 0.0))
		if PoolUses <= 0.0:
			ExplorationButtons.append(PoolButton)
		elif PoolReward / PoolUses >= 0.0:
			ProvenButtons.append(PoolButton)
		else:
			PunishedButtons.append(PoolButton)
	var ProvenIndex = 0
	var ExplorationIndex = 0
	while ProvenIndex < ProvenButtons.size() or ExplorationIndex < ExplorationButtons.size():
		for ProvenStep in range(3):
			if ProvenIndex >= ProvenButtons.size():
				break
			OrderedButtons.append(ProvenButtons[ProvenIndex])
			ProvenIndex += 1
		if ExplorationIndex < ExplorationButtons.size():
			OrderedButtons.append(ExplorationButtons[ExplorationIndex])
			ExplorationIndex += 1
	for PunishedButton in PunishedButtons:
		OrderedButtons.append(PunishedButton)
	for button in OrderedButtons:
		# Session deadline: keep what's scored, skip the rest. Partial
		# knowledge submitted on time beats a stalled table.
		if background_thinking and OS.get_ticks_msec() > session_deadline and (performance_mode or (search_mode == SEARCH_ADAPTIVE and awareness < AWARENESS_STRATEGIC and tactical_depth < 2)):
			break
		if !_button_reachable(button) or _is_rejected_action(player_id, button.action_name, button):
			continue
		if beam != null and !beam.has(button.action_name):
			continue
		# Resource-gated moves (MP, charges, cooldowns on modded characters):
		# submitting an unusable action makes the game Forfeit, so never
		# consider one.
		if button.state != null and button.state.has_method("is_usable") and !button.state.is_usable():
			continue
		var variants = _data_variants(player_id, button, actor, parry_read)
		for vi in range(variants.size()):
			for xi in range(action_extras.size()):
				if debug_logging:
					print("CombatAI Strategist sim P%s %s|%s|%s vs %s" % [str(player_id), button.action_name, str(vi), str(xi), str(versus_action)])
				var entry = _scored_entry(button.action_name, variants[vi], action_extras[xi], player_id, versus_action, versus_data, my_session, versus_extra)
				if entry is GDScriptFunctionState:
					entry = yield(entry, "completed")
				if entry == null:
					return null
				entry.key = button.action_name + "|" + str(vi) + "|" + str(xi)
				entry.hit = last_sim_hit
				entry.extended = last_sim_extended
				entry.advantage = last_sim_advantage
				entry.terms = last_sim_terms
				results.append(entry)
	# Character-specific turn controls live in custom PlayerExtra scenes rather
	# than a move's ActionUIData. The game's standard PlayerExtra is shared by
	# every fighter and contains ordinary turn/DI controls; sweeping it again
	# multiplied every deep search and could stall even vanilla mirror matches.
	# Only custom character scenes are sampled, and their work receives a hard
	# local time boundary so one unusual UI can never hold the entire turn.
	var PlayerExtraScene = actor.get("player_extra_params_scene")
	var PlayerExtraPath = str(PlayerExtraScene.resource_path) if PlayerExtraScene is PackedScene else ""
	var BuiltInPlayerExtra = PlayerExtraPath.begins_with("res://ui/") or PlayerExtraPath.begins_with("res://characters/swordandgun/") or PlayerExtraPath.begins_with("res://characters/wizard/") or PlayerExtraPath.begins_with("res://characters/stickman/") or PlayerExtraPath.begins_with("res://characters/robo/") or PlayerExtraPath.begins_with("res://characters/mutant/")
	var CustomPlayerExtra = PlayerExtraScene is PackedScene and !BuiltInPlayerExtra
	var IsMikoExtra = PlayerExtraPath.find("/_LamMiko/characters/Miko/States/Miko_Extra.tscn") != -1
	if int(player_id) == ai_player and CustomPlayerExtra and results.size() > 0 and (IsMikoExtra or OS.get_ticks_msec() <= session_deadline):
		var ExtraReady = _prepare_sim()
		if ExtraReady:
			var ExtraActor = sim_game.get_player(int(player_id))
			var ExtraUI = PlayerExtraScene.instance()
			ExtraUI.set_process(false)
			ExtraUI.set_physics_process(false)
			add_child(ExtraUI)
			if ExtraUI.has_method("set_fighter"):
				ExtraUI.set_fighter(ExtraActor)
			if ExtraUI.has_method("show_options"):
				ExtraUI.show_options()
			var DefaultCharacterExtra = ExtraUI.get_extra() if ExtraUI.has_method("get_extra") else null
			var CharacterExtras = []
			var ExtraDeadline = OS.get_ticks_msec() + 3000 if IsMikoExtra else min(session_deadline, OS.get_ticks_msec() + 3000)
			if DefaultCharacterExtra is Dictionary:
				# Miko's sword and spell trees are held PlayerExtra inputs, not
				# actions. Explicit legal payloads guarantee both charge paths are
				# considered even after her unusually large move list consumes the
				# ordinary search deadline. Once a path has charge, keep holding it
				# until it is spent; switching inputs would reset that progress.
				if IsMikoExtra:
					var SwordExtra = DefaultCharacterExtra.duplicate(true)
					SwordExtra["SP"] = true
					SwordExtra["SP2"] = false
					SwordExtra["MP"] = false
					SwordExtra["MP2"] = false
					_append_unique_data(CharacterExtras, SwordExtra)
					var MagicExtra = DefaultCharacterExtra.duplicate(true)
					MagicExtra["SP"] = false
					MagicExtra["SP2"] = false
					MagicExtra["MP"] = true
					MagicExtra["MP2"] = false
					_append_unique_data(CharacterExtras, MagicExtra)
				var ExtraSampleCap = 4 if performance_mode else (12 if search_mode >= SEARCH_EXHAUSTIVE else 8)
				for ExtraControl in _data_buttons(ExtraUI):
					if CharacterExtras.size() >= ExtraSampleCap or OS.get_ticks_msec() > ExtraDeadline:
						break
					var ExtraText = str(ExtraControl.text) if ExtraControl is Button else ""
					var ExtraLabels = [str(ExtraControl.get_name()), ExtraText, str(ExtraControl.get("hint_tooltip"))]
					var UnsafeExtra = false
					for ExtraLabel in ExtraLabels:
						var ExtraLower = ExtraLabel.to_lower()
						if ExtraLower.find("forfeit") != -1 or ExtraLower.find("debug") != -1 or ExtraLower.find("developer only") != -1 or ExtraLower.find("dev only") != -1:
							UnsafeExtra = true
							break
					if UnsafeExtra or !_player_reachable(ExtraControl, ExtraUI) or ExtraControl.disabled:
						continue
					var ExtraPresses = 4 if !ExtraControl.toggle_mode else 2
					for ExtraPress in range(ExtraPresses):
						if CharacterExtras.size() >= ExtraSampleCap or OS.get_ticks_msec() > ExtraDeadline or ExtraControl.disabled or !_player_reachable(ExtraControl, ExtraUI):
							break
						if ExtraControl.toggle_mode:
							ExtraControl.pressed = !ExtraControl.pressed
						if ExtraControl.has_method("_pressed"):
							ExtraControl.call("_pressed")
						else:
							ExtraControl.emit_signal("pressed")
						var CharacterExtra = ExtraUI.get_extra()
						if CharacterExtra is Dictionary and (_value_differs(CharacterExtra, DefaultCharacterExtra) or _value_differs(DefaultCharacterExtra, CharacterExtra)):
							_append_unique_data(CharacterExtras, CharacterExtra)
			var ExtraTargets = results.duplicate()
			ExtraTargets.sort_custom(self, "_by_score_desc")
			var ExtraTargetCap = 1 if performance_mode else (4 if search_mode >= SEARCH_EXHAUSTIVE else 2)
			var ExtraTargetCount = 0
			for ExtraTarget in ExtraTargets:
				if ExtraTargetCount >= ExtraTargetCap or OS.get_ticks_msec() > ExtraDeadline:
					break
				ExtraTargetCount += 1
				for ExtraIndex in range(CharacterExtras.size()):
					if OS.get_ticks_msec() > ExtraDeadline:
						break
					if IsMikoExtra:
						var LiveSwordCharge = actor.get("SPlv")
						var LiveMagicCharge = actor.get("MPlv")
						if LiveSwordCharge is int and LiveSwordCharge > 0 and !bool(CharacterExtras[ExtraIndex].get("SP", false)):
							continue
						if LiveMagicCharge is int and LiveMagicCharge > 0 and !bool(CharacterExtras[ExtraIndex].get("MP", false)):
							continue
					var CombinedExtra = ExtraTarget.get("extra", extra)
					CombinedExtra = CombinedExtra.duplicate(true) if CombinedExtra is Dictionary else _normalized_extra(CombinedExtra, player_id)
					for ExtraKey in CharacterExtras[ExtraIndex].keys():
						if ExtraKey != "DI" and ExtraKey != "feint" and ExtraKey != "prediction" and ExtraKey != "reverse":
							CombinedExtra[ExtraKey] = _duplicate_input(CharacterExtras[ExtraIndex][ExtraKey])
					var ExtraEntry = _scored_entry(ExtraTarget.action, ExtraTarget.data, CombinedExtra, player_id, versus_action, versus_data, my_session, versus_extra)
					if ExtraEntry is GDScriptFunctionState:
						ExtraEntry = yield(ExtraEntry, "completed")
					if ExtraEntry == null:
						ExtraUI.free()
						return null
					ExtraEntry.key = str(ExtraTarget.get("key", ExtraTarget.action)) + "|E" + str(ExtraIndex)
					ExtraEntry.hit = last_sim_hit
					ExtraEntry.extended = last_sim_extended
					ExtraEntry.advantage = last_sim_advantage
					ExtraEntry.terms = last_sim_terms
					results.append(ExtraEntry)
			ExtraUI.free()
	# Feints. A feint is only ever the answer to being MINUS: you commit to
	# something, cancel it, and the answer they threw whiffs into your free
	# turn. So we re-sim just the best few candidates that come out negative
	# and whose state can actually be feinted, and keep the cancel if it is
	# clearly better. Brawler and up - blunder tiers have no business running
	# mindgames. Three extra sims runs at every tier; what gets cut when the
	# machine struggles is BREADTH (sim length, variants, the prediction
	# sweep), not the handful of sims that decide whether we eat a punish.
	var scans_mindgames = (int(player_id) == ai_player and difficulty >= 2) or search_mode >= SEARCH_EXHAUSTIVE
	if int(player_id) == ai_player and !scans_mindgames:
		last_feint_diag = "blunder-tier"
	elif int(player_id) == ai_player and actor.feints <= 0:
		last_feint_diag = "no-feints-left"
	if scans_mindgames and actor.feints > 0:
		var ranked = results.duplicate()
		ranked.sort_custom(self, "_by_score_desc")
		var probed = 0
		# Study counters: how many candidates were even eligible, so a zero
		# feint count reads as "nothing was minus" vs "nothing was feintable"
		# vs "the feint just wasn't worth it".
		var minus_cnt = 0
		var feintable_cnt = 0
		var kept = 0
		var feint_probe_limit = 1 if performance_mode else (results.size() if search_mode >= SEARCH_EXHAUSTIVE else FEINT_PROBE_TOP)
		for entry in ranked:
			if probed >= feint_probe_limit or ((performance_mode or (search_mode == SEARCH_ADAPTIVE and awareness < AWARENESS_STRATEGIC and tactical_depth < 2)) and OS.get_ticks_msec() > session_deadline):
				break
			# A free cancel also matters when an attack whiffs: it lets the AI
			# recover instead of donating a punish. Probe minus outcomes and
			# non-connecting attacks, while still ignoring safe connecting moves.
			if entry.action == "Continue" or (entry.get("advantage") >= 0 and entry.get("hit")):
				continue
			minus_cnt += 1
			var fst = actor.state_machine.get_state(entry.action)
			if fst == null or !fst.has_method("can_feint") or !fst.can_feint():
				continue
			feintable_cnt += 1
			probed += 1
			var feinted = _scored_entry(entry.action, entry.data, _with_feint(entry.get("extra", extra)), player_id, versus_action, versus_data, my_session, versus_extra)
			if feinted is GDScriptFunctionState:
				feinted = yield(feinted, "completed")
			if feinted == null:
				return null
			var net = feinted.score - FEINT_COST
			var gain = net - entry.score
			var was_minus = int(entry.get("advantage"))
			if gain > FEINT_MARGIN:
				kept += 1
				entry.score = net
				entry.feint = true
				entry.hit = last_sim_hit
				entry.extended = last_sim_extended
				entry.advantage = last_sim_advantage
				entry.extra = feinted.extra
				entry.terms = last_sim_terms
				if debug_logging:
					print("CombatAI P%d feint: %s %+d (was %d frames minus)" % [ai_player, entry.action, int(gain), -was_minus])
		last_feint_diag = "minus=%d feintable=%d kept=%d" % [minus_cnt, feintable_cnt, kept]
	# Burst discipline applies ONLY in neutral. A burst is a panic button:
	# wasting it on a stray projectile loses the match, so in neutral it is
	# taxed hard and must clearly out-score an ordinary answer. But the moment
	# we are actually caught in a combo (opponent.combo_count >= 2) NONE of
	# this fires - escaping a combo is the entire reason burst exists, and a
	# defensive burst that breaks the string without dealing damage is a great
	# outcome, not a "whiff". Penalising it here is why the AI sat in 7-hit
	# combos holding Roll instead of bursting out.
	if actor.opponent.combo_count <= 1:
		for entry in results:
			if entry.action.find("Burst") != -1:
				entry.score -= BURST_RESERVE_PENALTY
		# Our own candidates only: the foe-prediction sweep must stay
		# burst-happy or mid-combo baiting stops forecasting the burst we are
		# deliberately trying to draw out of them.
		if int(player_id) == ai_player:
			var best_other = null
			for entry in results:
				if entry.action.find("Burst") == -1 and (best_other == null or entry.score > best_other):
					best_other = entry.score
			for entry in results:
				if entry.action.find("Burst") == -1:
					continue
				# Bursting at someone who is not there hands them the turn.
				if !entry.get("hit"):
					entry.score -= BURST_WHIFF_PENALTY
				# And it has to clearly beat our best ordinary answer, not a
				# near-tie the skill temperature can flip into a blunder.
				if best_other != null and entry.score - best_other < BURST_MARGIN:
					entry.score -= BURST_RESERVE_PENALTY
	# Mimic the opponent's escape timing: once WE are comboed as deep as this
	# character tends to burst at, and our burst is actually usable, nudge it
	# so we break out at the moment a real player would - the fix for "it does
	# not burst out of combos often enough". The raw simulation must still be
	# competitive with an ordinary defense: this prevents the timing bonus
	# from promoting a burst that plainly misses or leaves the AI worse off.
	if int(player_id) == ai_player and actor.opponent.combo_count >= 2 and actor.opponent.combo_count >= _burst_depth_for(actor.opponent.id):
		var ComboBestOther = null
		for ComboEntry in results:
			if ComboEntry.action.find("Burst") == -1 and (ComboBestOther == null or ComboEntry.score > ComboBestOther):
				ComboBestOther = ComboEntry.score
		for entry in results:
			if entry.action.find("Burst") != -1:
				if ComboBestOther == null or entry.score >= ComboBestOther - BURST_MARGIN:
					entry.score += BURST_ESCAPE_BONUS
				elif !entry.get("hit"):
					entry.score -= BURST_WHIFF_PENALTY
	# Opponent habit model: when scoring the human's options, tilt toward the
	# moves they demonstrably favor. The prediction stops assuming a textbook
	# maximizer and starts respecting how this player actually plays.
	if learning_enabled and int(player_id) != ai_player and foe_turns >= HABIT_MIN_TURNS:
		for entry in results:
			if foe_history.has(entry.action):
				entry.score += HABIT_WEIGHT * float(foe_history[entry.action]) / foe_turns
	# (Rule 1 - relentlessness - is applied at pick time via _relentless(),
	# AFTER the deep search has had a chance to exonerate movement links
	# whose follow-up exchange keeps the combo alive.)
	# Rule 2 - grabs are combo starters or defense, never fishing: tax
	# grabs that whiff against the foe's predicted plan in neutral.
	if int(player_id) == ai_player and actor.combo_count == 0:
		for entry in results:
			if _is_throw_action(entry.action, actor) and !entry.get("hit"):
				entry.score -= GRAB_WHIFF_PENALTY
	# Aggression tilt, every difficulty: connecting beats posturing.
	if int(player_id) == ai_player:
		for entry in results:
			if entry.get("hit"):
				entry.score += AGGRESSION_BONUS
	# Combo book: while mid-combo, moves that continue a route this character
	# has actually landed before get a nudge. Sims still veto whiffs - the
	# book only breaks near-ties toward proven follow-ups.
	if int(player_id) == ai_player and actor.combo_count > 0:
		var nexts = _book_next_moves(ai_player)
		for entry in results:
			if nexts.has(entry.action):
				entry.score += nexts[entry.action]
	if learning_enabled and LearningCharacter != "" and LearningBook.has(LearningCharacter) and LearningBook[LearningCharacter] is Dictionary:
		for entry in results:
			var LearnedExtra = entry.get("extra", extra)
			LearnedExtra = LearnedExtra.duplicate(true) if LearnedExtra is Dictionary else LearnedExtra
			if LearnedExtra is Dictionary:
				LearnedExtra.erase("DI")
				LearnedExtra.erase("prediction")
			var LearnedVariant = _fingerprint([str(entry.action), entry.get("data"), LearnedExtra], 0)
			if LearnedVariant == null:
				LearnedVariant = str(entry.action)
			var LearningBonus = 0.0
			var LearningUses = 0.0
			for WeightedContext in [[LearningContext, 0.75], ["*", 0.25]]:
				var ContextData = LearningBook[LearningCharacter].get(str(WeightedContext[0]), {})
				if !(ContextData is Dictionary):
					continue
				for WeightedCandidate in [["A:" + str(entry.action), 0.65], ["V:" + str(LearnedVariant), 0.35]]:
					var LearnedRecord = ContextData.get(str(WeightedCandidate[0]), {})
					if !(LearnedRecord is Dictionary):
						continue
					var LearnedUses = float(LearnedRecord.get("uses", 0.0))
					var LearnedAverage = float(LearnedRecord.get("reward", 0.0)) / max(1.0, LearnedUses)
					var LearnedConfidence = min(1.0, sqrt(LearnedUses) / 3.0)
					var LearnedOpportunities = float(LearnedRecord.get("opportunities", 0.0))
					var LearnedConversion = float(LearnedRecord.get("conversions", 0.0)) / max(1.0, LearnedOpportunities)
					LearningBonus += (LearnedAverage * LearnedConfidence + (LearnedConversion - 0.5) * 40.0 * LearnedConfidence) * float(WeightedContext[1]) * float(WeightedCandidate[1])
					LearningUses += LearnedUses * float(WeightedContext[1]) * float(WeightedCandidate[1])
			LearningBonus += LEARNING_EXPLORATION / sqrt(LearningUses + 1.0)
			if LearningAlgorithm == LEARNING_COMBO:
				LearningBonus *= 1.25 if int(actor.combo_count) > 0 else 0.25
			LearningBonus = clamp(LearningBonus, -LEARNING_SCORE_CAP, LEARNING_SCORE_CAP)
			entry.score += LearningBonus
			entry.learning_bonus = LearningBonus
	# Quest-style nudge: if this character has a variable naming a move it
	# wants used (e.g. SoloHunter's QuestMove), bonus that candidate.
	var hints = _hints_for(player_id)
	if hints.has("preferred_move_var"):
		var wanted = game.get_player(player_id).get(hints.preferred_move_var)
		if wanted is String and wanted != "":
			# Quest vars hold display names ("Kashmir Chase") while candidates
			# use state node names ("KashmirChase"), so compare normalized and
			# accept prefix matches ("Dagger Throw" covers DaggerThrowAerial).
			var want_n = _norm_name(wanted)
			if want_n != "":
				for entry in results:
					var act_n = _norm_name(entry.action)
					if act_n.begins_with(want_n) or want_n.begins_with(act_n):
						entry.score += hints.preferred_move_bonus
	# Chess-like classification is attached to every candidate, even in Classic
	# mode, so pool selection and study output can explain the move table.
	for entry in results:
		entry.category = _categorize_entry(entry, actor, versus_action)
		entry.style_bonus = 0.0
		entry.director_bonus = 0.0
	if int(player_id) == ai_player:
		_apply_action_discipline(results, actor, versus_action)
		_apply_behavior_profile(results, actor, versus_action)
		_apply_fight_director(results, actor)
	return results


func _scored_entry(action, data, extra, player_id, versus_action, versus_data, my_session, versus_extra = null):
	var score = _run_sim(player_id, action, data, extra, versus_action, versus_data, my_session, versus_extra)
	if score is GDScriptFunctionState:
		score = yield(score, "completed")
	if score == null:
		return null
	return {"action": action, "data": data, "extra": extra, "score": score, "feint": bool(extra.get("feint", false)) if extra is Dictionary else false}


func _best_for(player_id, versus_action, versus_data, my_session, beam = null, versus_extra = null):
	var scored = _score_options(player_id, versus_action, versus_data, _make_extra(_foe_di(player_id)), my_session, beam, versus_extra)
	if scored is GDScriptFunctionState:
		scored = yield(scored, "completed")
	return scored


# Score the current candidate table against the next two distinct opponent
# plans. Primary expectation matters most; mean and worst reply add awareness
# without turning one hypothetical perfect counter into the whole decision.
func _blend_strategic_awareness(scored, predicted, extra, my_session):
	var plans = predicted.duplicate()
	plans.sort_custom(self, "_by_score_desc")
	var distinct = []
	var seen_actions = {}
	for plan in plans:
		if seen_actions.has(plan.action):
			continue
		seen_actions[plan.action] = true
		distinct.append(plan)
		if distinct.size() >= 3:
			break
	if distinct.size() <= 1:
		return true
	var samples = {}
	for entry in scored:
		samples[entry.key] = []
	for i in range(1, distinct.size()):
		var plan = distinct[i]
		var alt = _score_options(ai_player, plan.action, plan.data, extra, my_session, null, plan.get("extra"))
		if alt is GDScriptFunctionState:
			alt = yield(alt, "completed")
		if alt == null:
			return null
		for candidate in alt:
			if samples.has(candidate.key):
				samples[candidate.key].append(float(candidate.score))
	for entry in scored:
		var values = samples.get(entry.key, [])
		if values.empty():
			continue
		var total = 0.0
		var worst = values[0]
		for value in values:
			total += value
			worst = min(worst, value)
		var mean = total / values.size()
		entry.score = float(entry.score) * AWARENESS_PRIMARY_WEIGHT + mean * AWARENESS_MEAN_WEIGHT + worst * AWARENESS_WORST_WEIGHT
	last_plan_src += "+strategic"
	return true


func _behavior_extras(base):
	var out = [base]
	if !performance_mode and search_mode >= SEARCH_EXHAUSTIVE and base is Dictionary:
		var reversed = base.duplicate()
		reversed["reverse"] = !bool(base.get("reverse", false))
		out.append(reversed)
	return out


func _categorize_entry(entry, actor, versus_action):
	var terms = entry.get("terms", {})
	if float(terms.get("kill", 0.0)) > 0.0:
		return "Finisher"
	var action = str(entry.action)
	var lower = action.to_lower()
	var state = actor.state_machine.get_state(action)
	if action.find("Burst") != -1 or (state != null and bool(state.get("can_parry"))):
		return "Defense"
	for word in ["block", "parry", "guard", "dodge", "roll", "escape", "counter"]:
		if lower.find(word) != -1:
			return "Defense"
	if entry.get("extended"):
		return "Combo"
	if entry.get("hit"):
		return "Attack"
	if float(terms.get("pres", 0.0)) > 0.0 or float(terms.get("res", 0.0)) > 3.0 or float(terms.get("hint", 0.0)) > 8.0:
		return "Setup"
	for word in ["dash", "jump", "step", "teleport", "walk", "fly", "hop", "drift"]:
		if lower.find(word) != -1:
			return "Positioning"
	if abs(float(terms.get("gap", 0.0))) >= 20.0:
		return "Positioning"
	if str(versus_action) != "Continue" and float(terms.get("taken", 0.0)) <= 0.0 and float(terms.get("ready", 0.0)) > 0.0:
		return "Defense"
	return "Utility"


func _apply_behavior_profile(results, actor, _versus_action):
	if behavior_profile == BEHAVIOR_CLASSIC:
		return
	var resolved = behavior_profile
	if behavior_profile == BEHAVIOR_DYNAMIC:
		if actor.opponent.combo_count > 0 or actor.hp < actor.opponent.hp * 0.7:
			resolved = BEHAVIOR_DEFENSIVE
		elif actor.combo_count > 0 or actor.opponent.hp < actor.hp * 0.55:
			resolved = BEHAVIOR_AGGRESSIVE
	for entry in results:
		var terms = entry.get("terms", {})
		var bonus = 0.0
		if resolved == BEHAVIOR_AGGRESSIVE:
			bonus += float(terms.get("dmg", 0.0)) * 0.25
			bonus -= float(terms.get("taken", 0.0)) * 0.05
			if entry.category == "Attack":
				bonus += 22.0
			elif entry.category == "Combo":
				bonus += 35.0
			elif entry.category == "Positioning" and float(terms.get("gap", 0.0)) > 0.0:
				bonus += 12.0
		elif resolved == BEHAVIOR_DEFENSIVE:
			bonus -= float(terms.get("taken", 0.0)) * 0.45
			bonus += max(0.0, float(terms.get("ready", 0.0))) * 0.08
			if entry.category == "Defense":
				bonus += 35.0
			elif entry.category == "Positioning":
				bonus += 14.0
			elif entry.category == "Setup":
				bonus += 8.0
		else:
			# Dynamic neutral posture: keep good tactical choices but push away
			# from repeating the exact action, creating less scripted patterns.
			if entry.category in ["Attack", "Defense", "Positioning", "Setup"]:
				bonus += 8.0
			if last_ai_choice != "" and entry.action == last_ai_choice:
				bonus -= 18.0
		entry.style_bonus = bonus
		entry.score += bonus


# Tactical resource discipline shared by every character. Simulation evidence
# can always overcome these weights; the goal is to stop empty cancels,
# repeated throws, idle defense, and flashy supers that do not connect from
# being selected merely because their raw frame score looks attractive.
func _apply_action_discipline(results, actor, versus_action):
	var foe_idle = str(versus_action) == "Continue"
	var proactive_exists = false
	for entry in results:
		var terms = entry.get("terms", {})
		if entry.get("hit") or entry.get("extended") or float(terms.get("gap", 0.0)) > 18.0 or float(terms.get("pres", 0.0)) > 0.0 or float(terms.get("hint", 0.0)) > 8.0:
			proactive_exists = true
			break
	for entry in results:
		var lower = str(entry.action).to_lower().replace(" ", "").replace("_", "")
		var terms = entry.get("terms", {})
		var made_contact = bool(entry.get("hit", false)) or bool(entry.get("extended", false))
		var IsIdleAction = lower in ["continue", "continueauto", "wait", "fall"]
		if (lower.find("whiffcancel") != -1 or lower.find("instantcancel") != -1) and !made_contact:
			entry.score -= CANCEL_WASTE_PENALTY
		if _is_throw_action(entry.action, actor) and entry.action == last_ai_choice:
			entry.score -= THROW_REPEAT_PENALTY * max(1, last_ai_choice_streak)
		if entry.action == last_ai_choice and last_ai_choice_streak >= 2 and !made_contact:
			entry.score -= min(RepeatActionPenalty * last_ai_choice_streak, LOOP_MAX_PENALTY)
		if foe_idle and proactive_exists:
			if IsIdleAction:
				entry.score -= PASSIVE_IDLE_PENALTY
			elif entry.category == "Defense" and float(terms.get("dmg", 0.0)) <= 0.0:
				entry.score -= PASSIVE_IDLE_PENALTY * 0.6
		var state = actor.state_machine.get_state(entry.action)
		var super_level = state.get("super_level_") if state != null else null
		if made_contact and (super_level is int or super_level is float) and float(super_level) > 0.0:
			entry.score += SUPER_CONTACT_BONUS + float(super_level) * 8.0


func _is_throw_action(action, actor = null):
	var labels = [str(action)]
	if actor != null and actor.state_machine != null:
		var state = actor.state_machine.get_state(action)
		if state != null:
			labels.append(str(state.get("title")))
	for label in labels:
		var lower = label.to_lower().replace(" ", "").replace("_", "")
		for token in ["grab", "throw", "commandgrab", "handshake"]:
			if lower.find(token) != -1:
				return true
	return false


# Narrative outcome steering through move choice only. The preferred fighter
# gets a late-round tactical push; the other fighter keeps earning damage and
# pressure bonuses so the battle remains active, but upset-finishing moves are
# increasingly rejected at Strong/Determined influence.
func _apply_fight_director(results, actor):
	if preferred_winner == DIRECTOR_NATURAL or actor == null or actor.opponent == null:
		return
	var strength = int(clamp(director_strength, 0, DIRECTOR_BASE_BONUS.size() - 1))
	var actor_id = int(actor.id)
	var foe_id = int(actor.opponent.id)
	var actor_start = float(starting_hp.get(actor_id, max(1.0, float(actor.hp))))
	var foe_start = float(starting_hp.get(foe_id, max(1.0, float(actor.opponent.hp))))
	var actor_ratio = clamp(float(actor.hp) / max(1.0, actor_start), 0.0, 1.0)
	var foe_ratio = clamp(float(actor.opponent.hp) / max(1.0, foe_start), 0.0, 1.0)
	var fight_phase = clamp(1.0 - min(actor_ratio, foe_ratio), 0.0, 1.0)
	var influence = 0.30 + fight_phase * 0.70
	if battle_pacing == PACING_COMPETITIVE:
		influence *= 0.75 + abs(actor_ratio - foe_ratio) * 0.5
	elif battle_pacing == PACING_CINEMATIC:
		influence *= 0.55 + fight_phase * 0.65
	var actor_is_preferred = actor_id == preferred_winner
	for entry in results:
		var terms = entry.get("terms", {})
		var bonus = 0.0
		if actor_is_preferred:
			if entry.category in ["Attack", "Combo", "Defense", "Finisher"]:
				bonus += DIRECTOR_BASE_BONUS[strength] * influence
			bonus += float(terms.get("dmg", 0.0)) * (0.08 + 0.05 * strength) * influence
			bonus -= float(terms.get("taken", 0.0)) * (0.10 + 0.06 * strength) * influence
			if bool(terms.get("foe_dead", false)):
				bonus += DIRECTOR_FINISH_BONUS[strength]
			if actor_ratio < foe_ratio and entry.category in ["Defense", "Combo"]:
				bonus += DIRECTOR_BASE_BONUS[strength] * 0.5
		else:
			# Visible effort: keep the underdog attacking and extending pressure.
			if entry.category in ["Attack", "Combo", "Defense"]:
				bonus += DIRECTOR_EFFORT_BONUS[strength]
			if entry.get("hit"):
				bonus += DIRECTOR_EFFORT_BONUS[strength] * 0.5
			# The only hard narrative edge: reject a simulated upset finish. If
			# every legal option loses anyway, normal engine state still decides.
			if bool(terms.get("foe_dead", false)):
				bonus -= DIRECTOR_UPSET_PENALTY[strength]
			if battle_pacing == PACING_CINEMATIC and foe_ratio < 0.3:
				if entry.category in ["Positioning", "Setup", "Defense"]:
					bonus += DIRECTOR_EFFORT_BONUS[strength]
				elif entry.category == "Finisher":
					bonus -= DIRECTOR_UPSET_PENALTY[strength] * 0.5
		entry.director_bonus = bonus
		entry.score += bonus


# Determined outcome control closes the last randomized-selection loophole.
# Score bonuses still create the battle's visible pressure and effort; this
# final gate only removes outcomes the current simulation explicitly proves
# would kill the selected winner. If every line loses, normal play remains.
func _director_decision_pool(scored):
	if preferred_winner == DIRECTOR_NATURAL or director_strength < 2 or scored.empty():
		return scored
	var safe = []
	var actor_is_preferred = ai_player == preferred_winner
	for entry in scored:
		var terms = entry.get("terms", {})
		var loses_selected_fighter = bool(terms.get("self_dead", false)) if actor_is_preferred else bool(terms.get("foe_dead", false))
		if !loses_selected_fighter:
			safe.append(entry)
	return safe if !safe.empty() else scored


# The distinct action names of the `count` best entries, as a Dictionary set.
func _top_actions(entries, count):
	var pool = entries.duplicate()
	pool.sort_custom(self, "_by_score_desc")
	var out = {}
	for e in pool:
		if out.size() >= count:
			break
		out[e.action] = true
	return out


func _by_score_desc(a, b):
	return a.score > b.score


# Refresh the legacy/profile CPU allowance, then apply Patience Mode without
# changing the actual search. Lower modes yield between simulations sooner;
# higher modes run more simulations before returning a rendered frame.
func _tune_budget():
	var fps = Engine.get_frames_per_second()
	if fps > 0:
		avg_fps = float(fps) if avg_fps == 0.0 else avg_fps * 0.8 + float(fps) * 0.2
		_track_health()
	if !performance_mode and performance_profile != PERFORMANCE_EPIC and !both_ai:
		if fps > 0 and fps < 45:
			adaptive_budget_ms = max(BUDGET_MIN_MS, adaptive_budget_ms - 2.0)
		elif fps > 55:
			adaptive_budget_ms = min(BUDGET_MAX_MS, adaptive_budget_ms + 1.0)
	_refresh_think_budget()


func _base_think_budget_ms():
	if performance_mode:
		return FAST_BOTH_AI_BUDGET_MS if both_ai else FAST_BUDGET_MS
	if performance_profile == PERFORMANCE_EPIC:
		return EPIC_BUDGET_MS
	if both_ai:
		return BOTH_AI_BUDGET_MS
	return adaptive_budget_ms


func _patience_multiplier():
	var mode = int(clamp(patience_mode, PATIENCE_GOD_LEVEL, PATIENCE_FERAL))
	return PATIENCE_MULTIPLIERS[mode]


func _refresh_think_budget():
	think_budget_ms = _base_think_budget_ms() * _patience_multiplier()


# Set the performance tier from how the GAME is actually running. Sampled on
# every mid-think yield, which is exactly when we are loading the machine.
func _track_health():
	var before = strain_tier
	if avg_fps < OVERLOAD_FPS:
		strain_tier = 2
		healthy_samples = 0
	elif avg_fps < STRAIN_FPS:
		strain_tier = int(max(strain_tier, 1))
		healthy_samples = 0
	elif avg_fps > RECOVER_FPS:
		healthy_samples += 1
		if healthy_samples >= RECOVER_SAMPLES and strain_tier > 0:
			strain_tier -= 1
			healthy_samples = 0
	else:
		healthy_samples = 0
	if strain_tier != before and debug_logging:
		print("CombatAI P%d: %.0f fps, performance tier %d" % [ai_player, avg_fps, strain_tier])


func _sim_frames():
	if performance_mode:
		return FAST_SIM_FRAMES
	if performance_profile == PERFORMANCE_EPIC:
		return EPIC_SIM_FRAMES
	if search_mode >= SEARCH_FULL_ACTIONS:
		return SIM_FRAMES
	return 26 if strain_tier >= 1 else SIM_FRAMES


func _beam_width():
	if performance_mode:
		return 3
	if performance_profile == PERFORMANCE_EPIC:
		return 12
	if search_mode >= SEARCH_FULL_ACTIONS:
		return PLY2_BEAM
	return 5 if strain_tier >= 1 else PLY2_BEAM


func _max_variants():
	if performance_mode:
		return 1
	if search_mode >= SEARCH_EXHAUSTIVE:
		return 0 # zero means no cap on the finite generated set
	if performance_profile == PERFORMANCE_EPIC:
		return 8
	if search_mode >= SEARCH_FULL_ACTIONS:
		return MAX_DATA_VARIANTS
	return 2 if strain_tier >= 1 else MAX_DATA_VARIANTS


func _think_deadline_ms():
	var deadline = THINK_DEADLINE_MS
	if performance_mode:
		deadline = FAST_THINK_DEADLINE_MS
	elif performance_profile == PERFORMANCE_EPIC:
		deadline = EPIC_THINK_DEADLINE_MS
	# Patient and faster modes retain the profile's old deadline. Gentler
	# modes get extra wall-clock time in inverse proportion to their smaller
	# CPU slice, so choosing smooth rendering does not silently truncate the
	# search merely because it yielded more often.
	return deadline / min(1.0, _patience_multiplier())


func _search_time_available():
	if performance_mode:
		return OS.get_ticks_msec() < session_deadline
	if performance_profile == PERFORMANCE_EPIC:
		return true
	return search_mode >= SEARCH_FULL_ACTIONS or awareness >= AWARENESS_STRATEGIC or tactical_depth >= 2 or OS.get_ticks_msec() < session_deadline


# Fold one sim's measured cost into the rolling average. The framerate drives
# the tier now (see _track_health); these thresholds are a backstop for sims
# so expensive that no frame budget can hide them, however healthy the
# framerate looked a moment ago.
func _track_sim_cost(elapsed):
	avg_sim_ms = float(elapsed) if avg_sim_ms == 0.0 else avg_sim_ms * 0.8 + float(elapsed) * 0.2
	var before = strain_tier
	if avg_sim_ms > STRAIN_SIM_MS:
		strain_tier = int(max(strain_tier, 1))
	if avg_sim_ms > OVERLOAD_SIM_MS:
		strain_tier = 2
	if strain_tier != before and debug_logging:
		print("CombatAI P%d: sims averaging %.1fms, performance tier %d" % [ai_player, avg_sim_ms, strain_tier])


# Yield to the engine for one frame mid-think. Returns false if the thinking
# session died while we were away.
func _breathe(my_session):
	ReplayManager.resimulating = false
	_tune_budget()
	yield(get_tree(), "idle_frame")
	if session != my_session or !is_instance_valid(game) or !is_instance_valid(fighter) or !is_instance_valid(sim_game):
		return false
	ReplayManager.resimulating = true
	slice_started = OS.get_ticks_msec()
	return true


func _run_sim(player_id, action, data, extra, versus_action, versus_data, my_session, versus_extra = null):
	var real_actor = game.get_player(player_id)
	var real_foe_id = int(real_actor.opponent.id) if real_actor != null and real_actor.opponent != null else (2 if int(player_id) == 1 else 1)
	extra = _normalized_extra(extra, player_id)
	versus_extra = _normalized_extra(versus_extra, real_foe_id)
	var cache_key = null
	if simulation_cache_enabled:
		cache_key = _simulation_cache_key(player_id, action, data, extra, versus_action, versus_data, versus_extra)
		if cache_key != null and sim_cache.has(cache_key):
			var cached_result = sim_cache[cache_key]
			last_sim_hit = cached_result.hit
			last_sim_extended = cached_result.extended
			last_sim_advantage = cached_result.advantage
			last_sim_terms = cached_result.terms.duplicate(true)
			sim_cache_hits += 1
			return cached_result.score
	# Frame budget: hand control back to the engine between simulations.
	if background_thinking and OS.get_ticks_msec() - slice_started > think_budget_ms:
		if status_label and status_label.visible:
			status_label.text = "Combat AI is thinking... (%d simulations, %d cached)" % [sims_done, sim_cache_hits]
		var alive = _breathe(my_session)
		if alive is GDScriptFunctionState:
			alive = yield(alive, "completed")
		if !alive:
			return null
	sims_done += 1
	var sim_started = OS.get_ticks_msec()

	if !_prepare_sim():
		return null
	# Rebuilding the sandbox (reset + the game's own copy_to) is charged to
	# every single sim, so if it dominates, that is where a speed-up lives.
	var prep = float(OS.get_ticks_msec() - sim_started)
	avg_prepare_ms = prep if avg_prepare_ms == 0.0 else avg_prepare_ms * 0.8 + prep * 0.2
	var me = sim_game.get_player(player_id)
	var foe = me.opponent
	me.is_ghost = true
	foe.is_ghost = true
	me.queued_action = action
	me.queued_data = data
	me.queued_extra = extra
	foe.queued_action = versus_action
	foe.queued_data = versus_data
	foe.queued_extra = versus_extra

	var my_hp = me.hp
	var foe_hp = foe.hp
	var my_combo = me.combo_count
	var foe_combo = foe.combo_count
	var ComboUnbroken = true
	# True 2D distance: an airborne juggled opponent is only "close" if we
	# match their height too - X-only gap made the AI walk under juggles.
	# get_pos() returns an {x, y} Dictionary, NOT a Vector2 - subtract per
	# component; dict-minus-dict is invalid and hard-crashes release builds.
	var start_gap = Vector2(foe.get_pos().x - me.get_pos().x, foe.get_pos().y - me.get_pos().y).length()
	var me_ready = -1
	var foe_ready = -1
	var frame_cap = _sim_frames()
	for frame in range(1, frame_cap + 1):
		sim_game.simulate_one_tick()
		if my_combo > 0 and me.combo_count < my_combo:
			ComboUnbroken = false
		if me_ready < 0 and (me.state_interruptable or me.state_hit_cancellable or me.dummy_interruptable):
			me_ready = frame + (me.hitlag_ticks if foe_ready < 0 else 0)
		if foe_ready < 0 and (foe.state_interruptable or foe.state_hit_cancellable or foe.dummy_interruptable):
			foe_ready = frame + (foe.hitlag_ticks if me_ready < 0 else 0)
		if me_ready >= 0 and foe_ready >= 0:
			break
	if me_ready < 0:
		me_ready = frame_cap
	if foe_ready < 0:
		foe_ready = frame_cap
	_track_sim_cost(OS.get_ticks_msec() - sim_started)

	var damage_dealt = foe_hp - foe.hp
	var damage_taken = my_hp - me.hp
	var throw_capture = _is_throw_capture(foe)
	last_sim_hit = damage_dealt > 0 or throw_capture
	last_sim_extended = ComboUnbroken and me.combo_count > my_combo
	last_sim_advantage = foe_ready - me_ready
	var end_gap = Vector2(foe.get_pos().x - me.get_pos().x, foe.get_pos().y - me.get_pos().y).length()
	var gap_closed = start_gap - end_gap

	# Taken-damage weight 1.1: slightly brave trades. (1.2 was the old
	# cautious value - the revert knob if aggression overshoots.)
	var throw_term = THROW_CAPTURE_BONUS if throw_capture and damage_dealt <= 0 else 0.0
	var score = damage_dealt * 1.0 - damage_taken * 1.1 + throw_term
	# Recovery frames count fully in the two situations that decide rounds:
	# the exchange made CONTACT (the punish, the pressure, "am I minus now"),
	# or the move COMMITTED to travel (whiffing a lunge is how you die).
	# Only a stationary non-event is damped, because there every option would
	# otherwise lose to standing still.
	#
	# Both halves are load-bearing and were learned the hard way. Keying on
	# movement alone damped the fast in-place pokes you want in a punish, so
	# the AI took the slow heavy option and sat in obvious minus. Keying on
	# contact alone then cut the whiffed-lunge penalty by 10x and the AI
	# stopped fearing commitals - visibly worse in play. It is the union.
	var readiness_weight = 15.0
	if damage_dealt == 0 and damage_taken == 0 and abs(gap_closed) < 50:
		readiness_weight = 1.5
	score += (foe_ready - me_ready) * readiness_weight
	# On an empty exchange, closing in is the whole point of the turn.
	var gap_weight = 0.02
	if damage_dealt == 0 and damage_taken == 0:
		gap_weight = 1.0
	score += gap_closed * gap_weight
	# Generic resource valuation: how many of each side's moves remain usable
	# after the exchange. Works for any modded mechanic that gates moves.
	var resource_term = (_usable_count(me, player_id) - _usable_count(foe, foe.id)) * _resource_weight()
	score += resource_term
	# Board presence: summons, minions, traps and projectiles still alive
	# after the exchange are an advantage for whoever owns them.
	var presence = 0
	for object in sim_game.objects:
		if is_instance_valid(object) and !object.disabled and object.has_method("get_fighter"):
			var owner = object.get_fighter()
			if owner == me:
				presence += 1
			elif owner == foe:
				presence -= 1
	score += presence * PRESENCE_WEIGHT
	# Character hint packs: valued deltas of character-specific mechanics
	# (mana, fatigue, bleed...) that the generic terms can't judge.
	var hint_term = _hint_score(me, player_id) - _hint_score(foe, foe.id)
	score += hint_term
	# A growing combo denies the opponent their next turn on top of its
	# damage; being caught in one costs ours.
	var combo_term = 0.0
	if ComboUnbroken and me.combo_count > my_combo:
		combo_term += (me.combo_count - my_combo) * COMBO_EXTEND_WEIGHT
	if foe.combo_count > foe_combo:
		combo_term -= (foe.combo_count - foe_combo) * COMBO_EXTEND_WEIGHT
	score += combo_term
	var kill_term = 0.0
	if foe.hp <= 0:
		kill_term = KILL_BONUS
	if me.hp <= 0:
		kill_term = -100000.0
	score += kill_term
	# Keep the components on every candidate: style profiles and categories
	# need the same evidence that Match Study prints. This is bookkeeping only.
	last_sim_terms = {
		"dmg": damage_dealt,
		"taken": damage_taken,
		"adv": foe_ready - me_ready,
		"advw": readiness_weight,
		"ready": (foe_ready - me_ready) * readiness_weight,
		"gap": gap_closed * gap_weight,
		"res": resource_term,
		"pres": presence * PRESENCE_WEIGHT,
		"hint": hint_term,
		"combo": combo_term,
		"throw": throw_term,
		"kill": kill_term,
		"self_dead": me.hp <= 0,
		"foe_dead": foe.hp <= 0,
	}
	if cache_key != null:
		sim_cache[cache_key] = {
			"score": score,
			"hit": last_sim_hit,
			"extended": last_sim_extended,
			"advantage": last_sim_advantage,
			"terms": last_sim_terms.duplicate(true),
		}
	return score


func _resource_weight():
	if resource_strategy == RESOURCE_SPEND:
		return RESOURCE_WEIGHT * 0.55
	if resource_strategy == RESOURCE_SAVE:
		return RESOURCE_WEIGHT * 1.75
	# Adaptive saves more at high skill and spends more freely while a live
	# combo or a threatened round makes immediate conversion valuable.
	if is_instance_valid(fighter) and fighter.opponent != null:
		if fighter.combo_count > 0 or fighter.hp < fighter.opponent.hp * 0.4:
			return RESOURCE_WEIGHT * 0.75
	return RESOURCE_WEIGHT * (1.0 + 0.1 * max(0, difficulty - 2))


func _is_throw_capture(sim_foe):
	if sim_foe == null or !is_instance_valid(sim_foe) or !sim_foe.has_method("current_state"):
		return false
	var state = sim_foe.current_state()
	return state != null and _is_grabbed_state_name(str(state.name))


func _is_grabbed_state_name(state_name):
	var normalized = str(state_name).to_lower().replace(" ", "").replace("_", "")
	return normalized.find("grabbed") != -1


func _simulation_cache_key(player_id, action, data, extra, versus_action, versus_data, versus_extra):
	return _fingerprint([int(player_id), str(action), data, extra, str(versus_action), versus_data, versus_extra, _sim_frames()], 0)


# Stable, bounded serialization for primitive move inputs. Complex mod objects,
# resources, or very deep/self-referential data return null and bypass caching
# instead of risking a collision or recursive str() crash.
func _fingerprint(value, depth):
	if depth > 6:
		return null
	var kind = typeof(value)
	if kind == TYPE_NIL:
		return "n"
	if kind == TYPE_BOOL:
		return "b1" if value else "b0"
	if kind == TYPE_INT:
		return "i" + str(value)
	if kind == TYPE_REAL:
		return "f" + str(value)
	if kind == TYPE_STRING:
		return "s" + str(value.length()) + ":" + value
	if kind == TYPE_VECTOR2:
		return "v2:" + str(value.x) + "," + str(value.y)
	if kind == TYPE_ARRAY:
		var array_parts = []
		for item in value:
			var encoded_item = _fingerprint(item, depth + 1)
			if encoded_item == null:
				return null
			array_parts.append(encoded_item)
		return "a[" + PoolStringArray(array_parts).join("|") + "]"
	if kind == TYPE_DICTIONARY:
		var keys = []
		for key in value.keys():
			if !(key is String):
				return null
			keys.append(key)
		keys.sort()
		var dict_parts = []
		for key in keys:
			var encoded_value = _fingerprint(value[key], depth + 1)
			if encoded_value == null:
				return null
			dict_parts.append(str(key.length()) + ":" + key + "=" + encoded_value)
		return "d{" + PoolStringArray(dict_parts).join("|") + "}"
	return null


# --- Match study ------------------------------------------------------------
#
# Every line is tagged CAISTUDY and written as key=value so a whole match can
# be pulled out of the log and analysed. Observation only: nothing here feeds
# back into a decision, and the opponent lookup in _study_foe_move reads a
# table that was already finished before they locked.


func _study_num(v):
	return "%.0f" % float(v)


func _study_decision(pick, scored, foe_plan):
	study_turn += 1
	var foe = fighter.opponent
	var gap = Vector2(foe.get_pos().x - fighter.get_pos().x, foe.get_pos().y - fighter.get_pos().y).length()
	print("CAISTUDY turn n=%d tick=%s p=%d hp=%s foehp=%s combo=%d foecombo=%d gap=%d meter=%s burst=%s feints=%s tier=%d fps=%.0f sims=%d cached=%d simms=%.1f prepms=%.1f" % [
		study_turn, str(game.current_tick), ai_player,
		_study_num(fighter.hp), _study_num(foe.hp),
		fighter.combo_count, foe.combo_count, int(gap),
		_study_num(fighter.get("super_meter")), _study_num(fighter.get("burst_meter")), _study_num(fighter.get("feints")),
		strain_tier, avg_fps, sims_done, sim_cache_hits, avg_sim_ms, avg_prepare_ms])
	# Prep split + why the defensive tools did or didn't fire this turn.
	print("CAISTUDY diag n=%d sim=%.1fms prep=%.1fms (reset=%.1f copy=%.1f) parry=%s feint=[%s]" % [
		study_turn, avg_sim_ms, avg_prepare_ms, avg_reset_ms, avg_copy_ms, last_parry_bail, last_feint_diag])
	print("CAISTUDY expect n=%d src=%s action=%s pool=%d" % [study_turn, last_plan_src, str(foe_plan[0]), last_predicted.size()])
	# What we picked, and what it beat. Rank order makes near-misses visible:
	# a blunder the temperature caused looks different from a scoring error.
	var ranked = scored.duplicate()
	ranked.sort_custom(self, "_by_score_desc")
	for i in range(min(6, ranked.size())):
		var e = ranked[i]
		print("CAISTUDY opt n=%d rank=%d action=%s category=%s var=%s score=%d style=%d director=%d hit=%d adv=%d ext=%d feint=%d reverse=%d%s" % [
			study_turn, i + 1, str(e.action), str(e.get("category", "Utility")),
			str(e.get("key")), int(e.score), int(e.get("style_bonus", 0.0)), int(e.get("director_bonus", 0.0)),
			1 if e.get("hit") else 0, int(e.get("advantage")),
			1 if e.get("extended") else 0, 1 if e.get("feint") else 0, 1 if (e.get("extra") is Dictionary and e.get("extra").get("reverse", false)) else 0,
			"  <== PICKED" if e.get("key") == pick.get("key") else ""])
	# Why the pick scored what it did.
	if pick.get("terms") is Dictionary:
		var t = pick.terms
		print("CAISTUDY terms n=%d action=%s dmg=%d taken=%d adv=%d x%.1f=%d gap=%d res=%d pres=%d hint=%d combo=%d kill=%d" % [
			study_turn, str(pick.action), int(t.dmg), int(t.taken), int(t.adv), t.advw, int(t.ready),
			int(t.gap), int(t.res), int(t.pres), int(t.hint), int(t.combo), int(t.kill)])


# Called once the opponent's real choice is known. Where did it rank on our
# scale? If a strong human's moves keep outranking the AI's own picks, the
# scoring function is sound and selection is broken. If they rank LOW and the
# human still wins, the scoring function is what's wrong.
func _study_foe_move(action):
	var rank = 0
	var found = null
	var ranked = last_predicted.duplicate()
	ranked.sort_custom(self, "_by_score_desc")
	for i in range(ranked.size()):
		if str(ranked[i].action) == str(action):
			rank = i + 1
			found = ranked[i]
			break
	if found == null:
		print("CAISTUDY foeplay n=%d played=%s rank=unscored pool=%d expected=%s" % [
			study_turn, str(action), ranked.size(), str(last_predicted.size() > 0)])
		return
	var top = ranked[0]
	print("CAISTUDY foeplay n=%d played=%s rank=%d/%d score=%d hit=%d adv=%d | our_top=%s score=%d | gap_to_top=%d" % [
		study_turn, str(action), rank, ranked.size(), int(found.score),
		1 if found.get("hit") else 0, int(found.get("advantage")),
		str(top.action), int(top.score), int(top.score - found.score)])


# The foe's up-to-n most-played moves that they could actually pick right
# now, as a beam (Dictionary set of action names) for the mini-sweep. Unusable
# or vanished moves are dropped here; _score_options filters again anyway.
func _habit_beam(foe, n):
	var ranked = foe_history.keys()
	ranked.sort_custom(self, "_by_habit_count")
	var beam = {}
	for action in ranked:
		if beam.size() >= n:
			break
		if _is_rejected_action(foe.id, action):
			continue
		var st = foe.state_machine.get_state(action)
		if st == null:
			continue
		if st.has_method("is_usable") and !st.is_usable():
			continue
		beam[action] = true
	return beam


func _by_habit_count(a, b):
	return int(foe_history.get(a, 0)) > int(foe_history.get(b, 0))


# The action this opponent has picked most often this match and could pick
# right now. A free, sim-less read for when we cannot afford the real sweep.
func _most_played(foe):
	var best = ""
	var best_n = 0
	for action in foe_history:
		if foe_history[action] <= best_n or _is_rejected_action(foe.id, action):
			continue
		var st = foe.state_machine.get_state(action)
		if st == null:
			continue
		if st.has_method("is_usable") and !st.is_usable():
			continue
		best = action
		best_n = foe_history[action]
	return best


# Reject engine controls and modded surrender/debug actions by every label a
# player can see, then apply the optional exact per-side move list. Hope, for
# example, names its state "No Escape" but titles the button
# "No Escape (FORFEIT)"; checking only action_name misses it.
func _is_rejected_action(player_id, action, button = null):
	if action in SKIP_ACTIONS:
		return true
	var labels = [str(action)]
	if button != null and is_instance_valid(button):
		labels.append(str(button.get("text")))
		labels.append(str(button.get("hint_tooltip")))
		if button.get("state") != null:
			labels.append(str(button.state.get("title")))
	for label in labels:
		var lower = label.to_lower()
		if lower.find("forfeit") != -1 or lower.find("debug") != -1 or lower.find("developer only") != -1 or lower.find("dev only") != -1:
			return true
	return _is_user_ignored_move(player_id, labels)


func _is_user_ignored_move(player_id, labels):
	# In a human-vs-AI match, a list for the human side must never censor the
	# opponent model. In AI-vs-AI both side lists are active.
	if !both_ai and int(player_id) != ai_player:
		return false
	var id = int(player_id)
	if !ignored_move_cache.has(id):
		var raw = p1_ignored_moves if id == 1 else p2_ignored_moves
		raw = raw.replace(";", ",").replace("\n", ",")
		var blocked = {}
		for item in raw.split(","):
			var key = _norm_name(str(item).strip_edges())
			if key != "":
				blocked[key] = true
		ignored_move_cache[id] = blocked
	for label in labels:
		if ignored_move_cache[id].has(_norm_name(str(label))):
			return true
	return false


func _usable_count(sim_fighter, player_id):
	var count = 0
	for action_name in _action_names(player_id):
		var st = sim_fighter.state_machine.get_state(action_name)
		if st == null or !st.has_method("is_usable") or st.is_usable():
			count += 1
	return count


func _action_names(player_id):
	var id = int(player_id)
	if !action_names_cache.has(id):
		var names = []
		var buttons = _action_buttons(id)
		if buttons != null:
			for button in buttons.buttons:
				# Resource valuation and burst discovery must use the same legal,
				# player-reachable set as the real decision sweep. Scanning every
				# hidden state made very large characters pay hundreds of needless
				# is_usable() calls after every simulation.
				if _button_reachable(button) and !_is_rejected_action(id, button.action_name, button):
					names.append(button.action_name)
		action_names_cache[id] = names
	return action_names_cache[id]


# Action-button containers are stable during one decision but finding them by
# recursive name scan is not free. The cache is cleared at the next _think so
# transformations and character-mod UI replacements remain compatible.
func _action_buttons(player_id):
	var id = int(player_id)
	if !action_buttons_cache.has(id):
		action_buttons_cache[id] = main_node.find_node("P%dActionButtons" % id)
	return action_buttons_cache[id]


func _load_hints():
	if hints_data != null:
		return
	hints_data = {}
	var file = File.new()
	var open_error = file.open("res://_CombatAIStrategist/hints.json", File.READ)
	if open_error != OK:
		_report_fault("E106", "Character hint packs could not be opened (error %d). Generic scoring will continue." % open_error)
		return
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error == OK and parsed.result is Dictionary:
		hints_data = parsed.result
	else:
		_report_fault("E107", "Character hint packs contain invalid JSON at line %d. Generic scoring will continue." % parsed.error_line)


# Resolve the hint pack for a player's character: generic "*" hints merged
# with any pack whose key appears in the selected character's name.
func _hints_for(player_id):
	player_id = int(player_id)
	if hints_cache.has(player_id):
		return hints_cache[player_id]
	_load_hints()
	var resolved = {"vars": {}}
	var generic = hints_data.get("*")
	if generic is Dictionary and generic.has("vars"):
		for k in generic.vars:
			resolved.vars[k] = generic.vars[k]
	var char_name = ""
	var selected = main_node.match_data.get("selected_characters", {})
	if selected.has(player_id):
		char_name = str(selected[player_id].get("name", "")).to_lower()
	for key in hints_data:
		if key != "*" and char_name.find(str(key).to_lower()) != -1:
			var pack = hints_data[key]
			if pack is Dictionary:
				if pack.has("vars"):
					for k in pack.vars:
						resolved.vars[k] = pack.vars[k]
				if pack.has("preferred_move_var"):
					resolved["preferred_move_var"] = pack.preferred_move_var
					resolved["preferred_move_bonus"] = pack.get("preferred_move_bonus", 20.0)
	if debug_logging:
		print("CombatAI hints for P%d ('%s'): %s" % [player_id, char_name, str(resolved)])
	hints_cache[player_id] = resolved
	return resolved


func _hint_score(sim_fighter, player_id):
	var hints = _hints_for(player_id)
	if hints.vars.empty():
		return 0.0
	var real = game.get_player(player_id)
	var total = 0.0
	for var_name in hints.vars:
		var now = sim_fighter.get(var_name)
		var before = real.get(var_name)
		if (now is int or now is float) and (before is int or before is float):
			total += _var_reward(float(now), float(before), hints.vars[var_name], real)
	return total


# Reward for a single hint var. `spec` is either a plain weight (the original
# linear model: reward = delta * weight) or a Dictionary describing a richer
# shape. Recognized dict fields:
#   weight        base linear slope
#   cap           saturate the value here (gains past the resource max are
#                 worthless - stops the AI hoarding)
#   curve         with cap: "diminish" (concave, early units worth more) or
#                 "accelerate" (convex, late units worth more, e.g. a fatigue
#                 bar nearing a KO)
#   threshold /   flat swing the moment the var crosses a usable breakpoint
#     threshold_bonus   this sim (e.g. reaching the meter a key move costs)
#   target        reward moving the var TOWARD a value instead of maximizing
#   when /        situational weighting: use `weight` only while the live
#     else_weight       board matches `when`, otherwise `else_weight` (0)
func _var_reward(now, before, spec, real):
	if spec is int or spec is float:
		return (now - before) * float(spec)
	if not (spec is Dictionary):
		return 0.0
	var weight = float(spec.get("weight", 0.0))
	if spec.has("when") and not _cond_pass(spec["when"], real):
		weight = float(spec.get("else_weight", 0.0))
	var contrib = 0.0
	if spec.has("target"):
		var t = float(spec["target"])
		contrib += weight * (abs(before - t) - abs(now - t))
	else:
		var fn = now
		var fb = before
		if spec.has("cap"):
			var cap = float(spec["cap"])
			fn = min(fn, cap)
			fb = min(fb, cap)
			if spec.has("curve"):
				fn = _curve(fn, cap, str(spec["curve"]))
				fb = _curve(fb, cap, str(spec["curve"]))
		contrib += (fn - fb) * weight
	if spec.has("threshold"):
		var th = float(spec["threshold"])
		var tb = float(spec.get("threshold_bonus", 0.0))
		if now >= th and before < th:
			contrib += tb
		elif now < th and before >= th:
			contrib -= tb
	return contrib


# Reshape a capped value so equal deltas are not valued equally. `cap`
# normalizes the value into 0..1 before the curve and scales it back, so a
# curved var stays in the same rough score range as its linear form.
func _curve(v, cap, kind):
	if cap <= 0.0:
		return v
	var x = clamp(v, 0.0, cap) / cap
	if kind == "diminish":
		return sqrt(x) * cap
	elif kind == "accelerate":
		return x * x * cap
	return v


# Every condition in `when` must hold against the real fighter's live state
# for the situational weight to apply. Missing / non-numeric vars fail closed.
func _cond_pass(when_dict, real):
	if not (when_dict is Dictionary):
		return true
	for cvar in when_dict:
		var cur = real.get(cvar)
		if not (cur is int or cur is float):
			return false
		if not _cmp(float(cur), str(when_dict[cvar])):
			return false
	return true


# Compare a number against an expression string: ">0", ">=30", "<=10",
# "<5", "==0", "!=2". A bare number is treated as equality.
func _cmp(value, expr):
	var s = expr.strip_edges()
	var op = "=="
	var num_str = s
	if s.begins_with(">="):
		op = ">="
		num_str = s.substr(2)
	elif s.begins_with("<="):
		op = "<="
		num_str = s.substr(2)
	elif s.begins_with("=="):
		op = "=="
		num_str = s.substr(2)
	elif s.begins_with("!="):
		op = "!="
		num_str = s.substr(2)
	elif s.begins_with(">"):
		op = ">"
		num_str = s.substr(1)
	elif s.begins_with("<"):
		op = "<"
		num_str = s.substr(1)
	var n = float(num_str.strip_edges())
	if op == ">=":
		return value >= n
	if op == "<=":
		return value <= n
	if op == ">":
		return value > n
	if op == "<":
		return value < n
	if op == "!=":
		return value != n
	return value == n


# --- Combo book -------------------------------------------------------------
# Routes are learned from real matches: whenever either side's combo ends,
# the move sequence that sustained it is stored under that character's key.
# The human's own combos are the best training data the AI can get.


func _load_book():
	combo_book = {}
	var file = File.new()
	if file.open(BOOK_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			combo_book = parsed.result
	LearningBook = {}
	LearningDirty = {}
	var LearningFile = File.new()
	if LearningFile.open(LEARNING_PATH, File.READ) == OK:
		var ParsedLearning = JSON.parse(LearningFile.get_as_text())
		LearningFile.close()
		if ParsedLearning.error == OK and ParsedLearning.result is Dictionary:
			LearningBook = ParsedLearning.result


func _save_book():
	# Merge with what's on disk before writing: in AI-vs-AI two brains
	# save independently, and a plain overwrite would clobber whichever
	# routes the other brain learned since our load.
	var file = File.new()
	if file.open(BOOK_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			var on_disk = parsed.result
			for ckey in combo_book:
				if !on_disk.has(ckey):
					on_disk[ckey] = combo_book[ckey]
					continue
				for rkey in combo_book[ckey]:
					var mine = combo_book[ckey][rkey]
					var theirs = on_disk[ckey].get(rkey)
					if theirs == null:
						on_disk[ckey][rkey] = mine
					else:
						theirs.seen = int(max(int(theirs.seen), int(mine.seen)))
						theirs.hits = int(max(int(theirs.hits), int(mine.hits)))
			combo_book = on_disk
	if file.open(BOOK_PATH, File.WRITE) == OK:
		file.store_string(JSON.print(combo_book))
		file.close()
	if LearningDirty.empty():
		return
	var LearningFile = File.new()
	var OnDiskLearning = {}
	if LearningFile.open(LEARNING_PATH, File.READ) == OK:
		var ParsedLearning = JSON.parse(LearningFile.get_as_text())
		LearningFile.close()
		if ParsedLearning.error == OK and ParsedLearning.result is Dictionary:
			OnDiskLearning = ParsedLearning.result
	for CharacterKey in LearningDirty:
		if !OnDiskLearning.has(CharacterKey) or !(OnDiskLearning[CharacterKey] is Dictionary):
			OnDiskLearning[CharacterKey] = {}
		for ContextKey in LearningDirty[CharacterKey]:
			if !OnDiskLearning[CharacterKey].has(ContextKey) or !(OnDiskLearning[CharacterKey][ContextKey] is Dictionary):
				OnDiskLearning[CharacterKey][ContextKey] = {}
			for CandidateKey in LearningDirty[CharacterKey][ContextKey]:
				var DeltaRecord = LearningDirty[CharacterKey][ContextKey][CandidateKey]
				var StoredRecord = OnDiskLearning[CharacterKey][ContextKey].get(CandidateKey, {})
				if !(StoredRecord is Dictionary):
					StoredRecord = {}
				for Metric in ["uses", "reward", "positive", "negative", "damage_dealt", "damage_taken", "opportunities", "conversions"]:
					StoredRecord[Metric] = float(StoredRecord.get(Metric, 0.0)) + float(DeltaRecord.get(Metric, 0.0))
				OnDiskLearning[CharacterKey][ContextKey][CandidateKey] = StoredRecord
			while OnDiskLearning[CharacterKey][ContextKey].size() > LEARNING_ENTRY_CAP:
				var WeakestCandidate = null
				var WeakestSamples = INF
				for StoredCandidate in OnDiskLearning[CharacterKey][ContextKey]:
					var StoredSamples = float(OnDiskLearning[CharacterKey][ContextKey][StoredCandidate].get("uses", 0.0))
					if StoredSamples < WeakestSamples:
						WeakestSamples = StoredSamples
						WeakestCandidate = StoredCandidate
				if WeakestCandidate == null:
					break
				OnDiskLearning[CharacterKey][ContextKey].erase(WeakestCandidate)
		while OnDiskLearning[CharacterKey].size() > LEARNING_CONTEXT_CAP:
			var WeakestContext = null
			var WeakestContextSamples = INF
			for StoredContext in OnDiskLearning[CharacterKey]:
				if StoredContext == "*":
					continue
				var ContextSamples = 0.0
				for StoredCandidate in OnDiskLearning[CharacterKey][StoredContext]:
					ContextSamples += float(OnDiskLearning[CharacterKey][StoredContext][StoredCandidate].get("uses", 0.0))
				if ContextSamples < WeakestContextSamples:
					WeakestContextSamples = ContextSamples
					WeakestContext = StoredContext
			if WeakestContext == null:
				break
			OnDiskLearning[CharacterKey].erase(WeakestContext)
	if LearningFile.open(LEARNING_PATH, File.WRITE) == OK:
		LearningFile.store_string(JSON.print(OnDiskLearning))
		LearningFile.close()
	LearningBook = OnDiskLearning
	LearningDirty.clear()
	LearningSaveCounter = 0


# Follow one player's locked actions and combo counter. A combo's recorded
# sequence starts at the move locked BEFORE the counter first showed (the
# launcher) and ends with the last move locked while it was still running.
func _book_track(player_id, action):
	if !(action is String) or action == "":
		return
	var p = game.get_player(player_id)
	if p == null or !is_instance_valid(p) or p.opponent == null:
		return
	var live = combo_live.get(player_id)
	if p.combo_count > 0:
		if live == null:
			live = {"seq": [], "hits": 0}
			if last_action_by.has(player_id):
				live.seq.append(last_action_by[player_id])
			combo_live[player_id] = live
		live.hits = int(max(live.hits, p.combo_count))
		if live.seq.size() < BOOK_MAX_SEQ:
			live.seq.append(action)
	elif live != null:
		_book_commit(player_id, live)
		combo_live.erase(player_id)
	last_action_by[player_id] = action


func _book_commit(player_id, live):
	if live.seq.size() < 2 or live.hits < BOOK_MIN_HITS:
		return
	var ckey = _book_char_key(player_id)
	if ckey == "":
		return
	if !combo_book.has(ckey):
		combo_book[ckey] = {}
	var routes = combo_book[ckey]
	var rkey = PoolStringArray(live.seq).join(">")
	if routes.has(rkey):
		routes[rkey].seen = int(routes[rkey].seen) + 1
		routes[rkey].hits = int(max(int(routes[rkey].hits), live.hits))
	else:
		routes[rkey] = {"seq": live.seq, "hits": live.hits, "seen": 1}
		while routes.size() > BOOK_MAX_ROUTES:
			var worst = null
			for k in routes:
				if worst == null or int(routes[k].seen) * int(routes[k].hits) < int(routes[worst].seen) * int(routes[worst].hits):
					worst = k
			routes.erase(worst)
	_save_book()


# Character key for the book: the selected character's name with any
# char_loader hash prefix ("f-<hex>__Name") stripped, normalized - so routes
# survive reinstalls and different mod load orders.
func _book_char_key(player_id):
	if main_node == null or !is_instance_valid(main_node):
		return ""
	var selected = main_node.match_data.get("selected_characters", {})
	player_id = int(player_id)
	if !selected.has(player_id):
		return ""
	var cname = str(selected[player_id].get("name", ""))
	var idx = cname.find_last("__")
	if idx != -1:
		cname = cname.substr(idx + 2, cname.length())
	return _norm_name(cname)


# --- Burst book -------------------------------------------------------------
# Learn the combo depth at which a character panic-bursts, so we can both
# predict their burst (to defend it) and mimic that timing for our own escapes.


func _load_bursts():
	burst_book = {}
	var file = File.new()
	if file.open(BURST_BOOK_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			burst_book = parsed.result


# A burst locked while being comboed is one data point: how many hits this
# character had eaten when they hit the button. Commit + persist immediately -
# bursts are single events, not sequences like combo routes.
func _burst_track(player_id, action):
	if !(action is String) or action.find("Burst") == -1:
		return
	var p = game.get_player(player_id)
	if p == null or !is_instance_valid(p) or p.opponent == null:
		return
	# Only DEFENSIVE bursts teach escape timing - a burst thrown in neutral
	# says nothing about when this player panics out of pressure.
	var depth = int(p.opponent.combo_count)
	if depth <= 0:
		return
	var ckey = _book_char_key(player_id)
	if ckey == "":
		return
	var rec = burst_book.get(ckey)
	if rec == null:
		rec = {"bursts": 0, "sum_depth": 0, "min_depth": depth}
		burst_book[ckey] = rec
	rec.bursts = int(rec.bursts) + 1
	rec.sum_depth = int(rec.sum_depth) + depth
	rec.min_depth = int(min(int(rec.min_depth), depth))
	if debug_logging:
		print("CombatAI: %s bursted at combo depth %d (avg now %.1f over %d)" % [ckey, depth, float(rec.sum_depth) / rec.bursts, rec.bursts])
	_save_bursts()


func _save_bursts():
	var file = File.new()
	# Merge with disk first (AI-vs-AI: two brains write independently).
	if file.open(BURST_BOOK_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			var on_disk = parsed.result
			for ckey in burst_book:
				var mine = burst_book[ckey]
				var theirs = on_disk.get(ckey)
				if theirs == null:
					on_disk[ckey] = mine
				elif int(mine.bursts) > int(theirs.get("bursts", 0)):
					on_disk[ckey] = mine
			burst_book = on_disk
	if file.open(BURST_BOOK_PATH, File.WRITE) == OK:
		file.store_string(JSON.print(burst_book))
		file.close()


# The combo depth at which this character tends to burst. Below the sample
# floor we don't trust the average yet and use the generic "real combo" depth.
func _burst_depth_for(player_id):
	var rec = burst_book.get(_book_char_key(player_id))
	if rec == null or int(rec.bursts) < BURST_MIN_SAMPLES:
		return BURST_LEARN_MIN_DEPTH
	# Bias toward the EARLIEST they've bursted, not the mean - reading a burst
	# a hit early costs nothing; a hit late means we already ate it.
	var avg = float(rec.sum_depth) / int(rec.bursts)
	return int(max(int(rec.min_depth), int(round(avg)) - 1))


func _burst_read_confident(player_id):
	var rec = burst_book.get(_book_char_key(player_id))
	return rec != null and int(rec.get("bursts", 0)) >= BURST_MIN_SAMPLES


# Does this character have a burst they could use RIGHT NOW?
func _usable_burst(f):
	if !is_instance_valid(f):
		return ""
	for aname in _action_names(f.id):
		if aname.find("Burst") != -1:
			var st = f.state_machine.get_state(aname)
			if st != null and (!st.has_method("is_usable") or st.is_usable()):
				return aname
	return ""


# Moves that would continue a known route from the AI's current combo
# sequence, as {action_name: bonus}. A match on the last TWO moves is worth
# full weight; a single-move match is a weaker hint.
func _book_next_moves(player_id):
	var out = {}
	var live = combo_live.get(int(player_id))
	if live == null or live.seq.size() == 0:
		return out
	var ckey = _book_char_key(player_id)
	if !combo_book.has(ckey):
		return out
	var last = live.seq[live.seq.size() - 1]
	var prev = live.seq[live.seq.size() - 2] if live.seq.size() >= 2 else null
	for rkey in combo_book[ckey]:
		var route = combo_book[ckey][rkey]
		var quality = BOOK_BONUS + BOOK_SEEN_BONUS * min(int(route.seen), BOOK_SEEN_CAP)
		var seq = route.seq
		for i in range(seq.size() - 1):
			if seq[i] != last:
				continue
			var w = quality
			if !(prev != null and i > 0 and seq[i - 1] == prev):
				w *= 0.6
			var nxt = seq[i + 1]
			out[nxt] = max(out.get(nxt, 0.0), w)
	return out


# Book guess for what should follow a candidate we haven't played yet -
# used to aim the deep search's follow-up exchange.
func _book_followup(action):
	var live = combo_live.get(ai_player)
	var prev = null
	if live != null and live.seq.size() > 0:
		prev = live.seq[live.seq.size() - 1]
	var ckey = _book_char_key(ai_player)
	if !combo_book.has(ckey):
		return null
	var best = null
	var best_w = 0.0
	for rkey in combo_book[ckey]:
		var route = combo_book[ckey][rkey]
		var seq = route.seq
		for i in range(seq.size() - 1):
			if seq[i] != action:
				continue
			var w = 1.0 + float(int(route.seen))
			if prev != null and i > 0 and seq[i - 1] == prev:
				w *= 3.0
			if w > best_w:
				best_w = w
				best = seq[i + 1]
	if best == null:
		return null
	return {"action": best, "data": null}


# Combo memory intentionally stores action names only, because move-data
# payloads belong to one particular turn, facing, and character state. Before
# a remembered action enters the second prediction exchange, bind it to the
# best currently legal candidate that the first sweep already simulated. This
# keeps learned routes useful without replaying aim/distance/jump moves with a
# fabricated null payload. A stale or currently unavailable move is skipped.
func _current_followup_candidate(booked, ranked_pool):
	if !(booked is Dictionary) or !(booked.get("action") is String):
		return null
	var action = booked.action
	for candidate in ranked_pool:
		if candidate is Dictionary and candidate.get("action") == action:
			return {
				"action": action,
				"data": candidate.get("data"),
			}
	return null


# --- Deep combo search ------------------------------------------------------


# Sim the top mid-combo candidates one exchange deeper and fold the best
# follow-up's value back into their scores. Mutates `scored`; returns true,
# or null if the session died.
func _deepen(scored, top_n, versus_action, versus_data, versus_extra, extra, my_session):
	# Exchange 2 lets the foe idle, which is true in a combo and generous in
	# neutral - discount the neutral case accordingly.
	var fold = CONTINUATION_WEIGHT if fighter.combo_count > 0 else NEUTRAL_CONTINUATION_WEIGHT
	var pool = scored.duplicate()
	pool.sort_custom(self, "_by_score_desc")
	# This sweep's best moves double as generic follow-up guesses.
	var general = []
	for e in pool:
		if e.action == "Continue" or general.size() >= COMBO_SEARCH_FOLLOWUPS:
			continue
		var dup = false
		for g in general:
			if g.action == e.action:
				dup = true
		if !dup:
			general.append(e)
	var deepened = 0
	for entry in pool:
		if deepened >= top_n:
			break
		if entry.action == "Continue":
			continue
		deepened += 1
		var followups = []
		var booked = _current_followup_candidate(_book_followup(entry.action), pool)
		if booked != null:
			followups.append(booked)
		for g in general:
			var dup2 = false
			for f in followups:
				if f.action == g.action:
					dup2 = true
			if !dup2 and followups.size() < COMBO_SEARCH_FOLLOWUPS + (1 if booked != null else 0):
				followups.append({"action": g.action, "data": g.data})
		var best = null
		var keeps_combo = false
		for f in followups:
			var probe = _run_combo_probe(entry.action, entry.data, f.action, f.get("data"), entry.get("extra", extra), versus_action, versus_data, my_session, versus_extra)
			if probe is GDScriptFunctionState:
				probe = yield(probe, "completed")
			if probe == null:
				return null
			if probe.extended or probe.e2_extended:
				keeps_combo = true
			if best == null or probe.value > best:
				best = probe.value
		if best != null:
			entry.score += fold * best
			# Exonerate movement links from rule 1: a candidate that doesn't
			# hit THIS exchange but provably reconnects next exchange keeps
			# the combo alive in the way that matters.
			if keeps_combo:
				entry.extended = true
			if debug_logging:
				print("CombatAI deepen: %s %+d%s" % [entry.action, int(fold * best), " (link)" if (keeps_combo and !entry.get("hit")) else ""])
	return true


# Run our candidate exchange in the sandbox, then - without resetting - queue
# a follow-up on top of the result and keep ticking. Returns
# {extended, value}, or null if the session died. The follow-up runs with
# default inputs; if it is unusable from where exchange 1 left us, it
# degrades to Continue (which scores the dead end honestly).
func _run_combo_probe(action, data, followup, fdata, extra, versus_action, versus_data, my_session, versus_extra = null):
	extra = _normalized_extra(extra, ai_player)
	var real_foe_id = int(fighter.opponent.id) if is_instance_valid(fighter) and fighter.opponent != null else (2 if ai_player == 1 else 1)
	versus_extra = _normalized_extra(versus_extra, real_foe_id)
	if background_thinking and OS.get_ticks_msec() - slice_started > think_budget_ms:
		var alive = _breathe(my_session)
		if alive is GDScriptFunctionState:
			alive = yield(alive, "completed")
		if !alive:
			return null
	sims_done += 1
	var sim_started = OS.get_ticks_msec()

	if !_prepare_sim():
		return null
	var me = sim_game.get_player(ai_player)
	var foe = me.opponent
	me.is_ghost = true
	foe.is_ghost = true
	me.queued_action = action
	me.queued_data = data
	me.queued_extra = extra
	foe.queued_action = versus_action
	foe.queued_data = versus_data
	foe.queued_extra = versus_extra

	var start_combo = me.combo_count
	var ComboUnbroken = true
	for frame in range(1, _sim_frames() + 1):
		sim_game.simulate_one_tick()
		if start_combo > 0 and me.combo_count < start_combo:
			ComboUnbroken = false
		# Once we're actionable again the follow-up decision point is here;
		# a few frames minimum so startup invulnerability can't fake it.
		if frame >= 8 and (me.state_interruptable or me.state_hit_cancellable or me.dummy_interruptable):
			break
	if me.hp <= 0:
		_track_sim_cost(OS.get_ticks_msec() - sim_started)
		return {"extended": false, "e2_extended": false, "value": 0.0}
	# Even when exchange 1 didn't extend, play the follow-up anyway: real
	# routes often need a movement LINK (dash/jump, no hit) before the next
	# hit - this is where those links get discovered.
	var e1_extended = ComboUnbroken and me.combo_count > start_combo

	var foe_hp1 = foe.hp
	var my_hp1 = me.hp
	var combo1 = me.combo_count
	var st = me.state_machine.get_state(followup)
	if st == null or (st.has_method("is_usable") and !st.is_usable()):
		followup = "Continue"
		fdata = null
	me.queued_action = followup
	me.queued_data = fdata
	me.queued_extra = extra
	foe.queued_action = "Continue"
	foe.queued_data = null
	for frame in range(1, COMBO_SEARCH_FRAMES + 1):
		sim_game.simulate_one_tick()
		if start_combo > 0 and me.combo_count < start_combo:
			ComboUnbroken = false
	_track_sim_cost(OS.get_ticks_msec() - sim_started)

	var value = (foe_hp1 - foe.hp) - 1.2 * (my_hp1 - me.hp)
	value += COMBO_EXTEND_WEIGHT * max(0, me.combo_count - combo1)
	if foe.hp <= 0:
		value += KILL_BONUS
	if me.hp <= 0:
		value -= 100000.0
	# A fresh hit after the opponent escaped is not a movement link in the
	# original combo, even when it beats the reset counter of zero.
	return {"extended": e1_extended, "e2_extended": ComboUnbroken and me.combo_count > combo1 and me.combo_count > 0, "value": value}


# --- Parry solver -----------------------------------------------------------
#
# Ask the engine when the incoming move actually lands instead of sampling a
# timing slider and hoping. We block once with a deliberately late input - so
# the block is NOT a perfect parry and the game keeps looking - and read the
# frame it recorded back off the ghost fighter.
#
# Returns {"timing": frame, "low": bool}, or null when nothing was recorded
# (the move does not hit us, is unparriable, or this character has no parry).
# A dead session also returns null: the per-entry guards in the sweep that
# follows will abort it a moment later, so this never needs its own signal.
func _solve_parry(player_id, versus_action, versus_data, extra, my_session, versus_extra = null):
	last_parry_bail = ""
	extra = _normalized_extra(extra, player_id)
	var real_actor = game.get_player(player_id)
	var real_foe_id = int(real_actor.opponent.id) if real_actor != null and real_actor.opponent != null else (2 if int(player_id) == 1 else 1)
	versus_extra = _normalized_extra(versus_extra, real_foe_id)
	var buttons = _action_buttons(player_id)
	if buttons == null:
		last_parry_bail = "no-buttons"
		return null
	var actor = game.get_player(player_id)
	# can_parry is the game's own flag on the state, so modded parries are
	# covered without a name list.
	var parry_button = null
	for button in buttons.buttons:
		if _is_rejected_action(player_id, button.action_name, button) or !_button_reachable(button):
			continue
		if button.state == null or !button.state.get("can_parry"):
			continue
		if button.state.has_method("is_usable") and !button.state.is_usable():
			continue
		parry_button = button
		break
	if parry_button == null:
		# The common, benign case: this character simply has no parry.
		last_parry_bail = "no-parry-move"
		return null
	# Warm the move cache so the probe can reuse the discovered widgets.
	_data_variants(player_id, parry_button, actor)
	var cached = move_data_cache.get(str(player_id) + "|" + str(actor.get_facing_int()) + "|" + parry_button.action_name)
	if cached == null:
		last_parry_bail = "cache-miss"
		return null
	if !(cached.data is Dictionary):
		last_parry_bail = "no-data"
		return null
	var timing_range = null
	for r in cached.ranges:
		if r.wrap == "count":
			timing_range = r
			break
	if timing_range == null:
		last_parry_bail = "no-timing-widget"
		return null
	var probe = cached.data.duplicate()
	probe[timing_range.key] = _range_sample(timing_range, timing_range.max_value, cached.data.get(timing_range.key))
	if cached.get("RootKey", "") != "":
		probe = probe[cached.RootKey]

	if background_thinking and OS.get_ticks_msec() - slice_started > think_budget_ms:
		var alive = _breathe(my_session)
		if alive is GDScriptFunctionState:
			alive = yield(alive, "completed")
		if !alive:
			last_parry_bail = "session-died"
			return null
	sims_done += 1
	var sim_started = OS.get_ticks_msec()

	if !_prepare_sim():
		last_parry_bail = "sandbox-failed"
		return null
	var me = sim_game.get_player(player_id)
	var foe = me.opponent
	me.is_ghost = true
	foe.is_ghost = true
	me.queued_action = parry_button.action_name
	me.queued_data = probe
	me.queued_extra = extra
	foe.queued_action = versus_action
	foe.queued_data = versus_data
	foe.queued_extra = versus_extra
	for frame in range(1, PARRY_PROBE_FRAMES + 1):
		sim_game.simulate_one_tick()
		if me.ghost_blocked_melee_attack != -1:
			break
	_track_sim_cost(OS.get_ticks_msec() - sim_started)
	if session != my_session:
		last_parry_bail = "session-died"
		return null
	if me.ghost_blocked_melee_attack == -1:
		# We CAN parry, but the incoming move never registered as a parriable
		# hit on us this probe - a projectile, a throw, a whiff, or simply out
		# of range. Nothing to solve.
		last_parry_bail = "not-parriable"
		return null
	var read = {"timing": int(me.ghost_blocked_melee_attack), "low": me.ghost_wrong_block == "Low"}
	last_parry_bail = "solved"
	if debug_logging:
		print("CombatAI P%d parry read: %s lands f%d %s" % [ai_player, str(versus_action), read.timing, "low" if read.low else "high"])
	return read


# Rebuild a parry's data around a measured read: the timing widget takes the
# recorded frame, and the block-height widget (the one y-without-x value in
# vanilla parry data) takes the recorded height. Null when the move's inputs
# already say exactly this.
func _solved_parry_data(cached, parry_read):
	if !(cached.data is Dictionary):
		return null
	var out = cached.data.duplicate()
	var changed = false
	for r in cached.ranges:
		if r.wrap != "count":
			continue
		# Frame 0 is not blockable, and a read past the widget's reach is
		# what its maximum already means.
		var timing = int(clamp(parry_read.timing, max(1.0, r.min_value), r.max_value))
		var was = cached.data.get(r.key)
		if !(was is Dictionary) or int(was.get("count", -1)) != timing:
			out[r.key] = _range_sample(r, timing, was)
			changed = true
		break
	var height = 1 if parry_read.low else 0
	for HeightRange in cached.ranges:
		if HeightRange.get("IsHeight", false):
			var HeightValue = out.get(HeightRange.key)
			if !(HeightValue is Dictionary) or int(HeightValue.get("y", -1)) != height:
				out[HeightRange.key] = _range_sample(HeightRange, height, HeightValue)
				changed = true
	for k in out.keys():
		var v = out[k]
		if v is Dictionary and v.has("y") and !v.has("x"):
			if int(v.get("y")) != height:
				var swapped = v.duplicate()
				swapped["y"] = height
				out[k] = swapped
				changed = true
	if !changed:
		return null
	return out


# Lowercase and strip non-alphanumerics: "Arise [Lower Class]" -> "ariselowerclass".
func _norm_name(s):
	var out = ""
	for i in range(s.length()):
		var c = s.substr(i, 1).to_lower()
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


# Move data: the move's default input plus meaningful permutations - plot
# inputs get aimed-at-foe and away-from-foe samples, slider inputs get their
# min and max, toggle inputs get flipped. Capped at MAX_DATA_VARIANTS.
func _data_variants(player_id, button, actor, parry_read = null):
	# ActionUIData returns world-space directions after facing is applied. Keep
	# the two orientations separate so crossing sides cannot reuse a stale cone,
	# enabled 8-way set, or default direction from the opposite facing.
	var key = str(player_id) + "|" + str(actor.get_facing_int()) + "|" + button.action_name
	if !move_data_cache.has(key):
		var entry = {"data": null, "plots": [], "direct_variants": [], "ranges": [], "toggles": [], "eightways": [], "RootKey": ""}
		if button.state != null and button.state.data_ui_scene != null:
			var ui = button.state.data_ui_scene.instance()
			ui.fighter = actor
			# Custom ActionUIData frequently branches on the selected state
			# (Valued's shared Chant/Imbue scene is one example). The real action
			# selector supplies this field; prediction must do the same.
			ui.state = button.state
			add_child(ui)
			_prepare_data_ui_facing(ui, actor.get_facing_int())
			if ui.has_method("fighter_update"):
				ui.fighter_update()
			# The stock parry panel reveals timing when selected. Scratch panels
			# never receive that UI event; reveal only its legitimate timing field
			# without reading the human's currently selected opposing move.
			var TimingControl = ui.get("melee_parry_timing")
			if TimingControl is Control and button.state.get("can_parry") and !button.state.get("reblock"):
				TimingControl.show()
			if ui.has_method("get_data"):
				entry.data = ui.get_data()
			var RawData = entry.data
			# ActionUIData unwraps a single control's payload. Temporarily name
			# that root value for discovery, then restore its original shape before
			# simulation/submission. Named multi-control dictionaries stay intact.
			var RootFingerprint = _fingerprint(RawData, 0)
			var RootMatches = []
			if RootFingerprint != null:
				for RootControl in ui.get_children():
					if RootControl.has_method("get_data"):
						var ControlData = RootControl.get_data()
						var MatchesRoot = _fingerprint(ControlData, 0) == RootFingerprint
						# Some aimed moves flatten x/y beside extra flags such as
						# holster. Bind that control without losing the extra fields.
						if !MatchesRoot and RawData is Dictionary and ControlData is Dictionary and !ControlData.empty() and !RawData.has(str(RootControl.name)):
							MatchesRoot = (ControlData.has("count") or (ControlData.has("x") and ControlData.has("y")) or _single_numeric_field(ControlData) != "") and !_value_differs(ControlData, RawData)
						if MatchesRoot:
							RootMatches.append(str(RootControl.name))
			if RootMatches.size() == 1:
				entry.RootKey = RootMatches[0]
				entry.data = {entry.RootKey: RawData}
			if entry.data is Dictionary:
				for plot in _find_plots(ui):
					if entry.data.has(plot.get_name()) and _player_reachable(plot, ui):
						entry.plots.append({"key": plot.get_name(), "cone": _plot_cone(plot)})
				_find_inputs(ui, entry.data, entry, ui)
				if RawData is Dictionary:
					for DirectSample in _clickable_data_variants(ui, RawData):
						entry.direct_variants.append({entry.RootKey: DirectSample} if entry.RootKey != "" else DirectSample)
			ui.free()
		move_data_cache[key] = entry
	var cached = move_data_cache[key]
	var variants = [cached.data]
	for direct in cached.direct_variants:
		_append_unique_data(variants, direct)
	if !(cached.data is Dictionary):
		return variants
	# Adaptive prediction keeps the original default+aim cap. Comprehensive
	# coverage uses the same full generated set for either player.
	var cap = _max_variants() if (performance_mode or int(player_id) == ai_player or search_mode >= SEARCH_FULL_ACTIONS) else 2
	if search_mode < SEARCH_EXHAUSTIVE and variants.size() > cap:
		variants = _stratified_variant_trim(variants, cap)
	# A measured parry is not a guess like the min/max samples below, so it
	# takes its slot before them and the cap can never cut it.
	if parry_read != null and button.state != null and button.state.get("can_parry"):
		var solved = _solved_parry_data(cached, parry_read)
		if solved != null:
			variants.append(solved)
	# Collect one "primary" sample per input widget first, then second
	# samples - so a move with many inputs sees each widget at least once
	# before the cap cuts off. Each pair is [data key, sample value]; a null
	# value means "flip the toggle".
	var primary = []
	var secondary = []
	for plot_entry in cached.plots:
		var foe_p = actor.opponent
		var toward = _led_world_direction(actor, foe_p)
		if toward.length() > 1:
			toward = toward.normalized()
			# Straight at them folded into the plot's legal arc, then the
			# arc's own edges. Unconstrained plots yield exactly one sample,
			# as before - the extra sims land only on the moves that need
			# them.
			var aims = _aim_samples(plot_entry.cone, toward)
			primary.append([plot_entry.key, aims[0]])
			for i in range(1, aims.size()):
				secondary.append([plot_entry.key, aims[i]])
			# Retreat aim is for escaping pressure; offered in neutral it
			# just makes aimed moves fire at nothing and look random.
			if foe_p.combo_count > 0:
				secondary.append([plot_entry.key, _as_plot_data(_clamp_to_cone(-toward, plot_entry.cone))])
	# 8Way direction pickers: offer the enabled direction closest to the foe
	# (in the world-space data returned by a facing-initialized widget) plus the
	# next-closest alternative.
	for e8 in cached.eightways:
		var foe8 = actor.opponent
		_aim_dir = Vector2(foe8.get_pos().x - actor.get_pos().x, foe8.get_pos().y - actor.get_pos().y).normalized()
		var dirs = e8.dirs.duplicate()
		dirs.sort_custom(self, "_by_aim")
		if dirs.size() > 0:
			primary.append([e8.key, {"x": dirs[0][0], "y": dirs[0][1]}])
		if dirs.size() > 1:
			secondary.append([e8.key, {"x": dirs[1][0], "y": dirs[1][1]}])
		if search_mode >= SEARCH_EXHAUSTIVE:
			for i in range(2, dirs.size()):
				secondary.append([e8.key, {"x": dirs[i][0], "y": dirs[i][1]}])
	for r in cached.ranges:
		if search_mode >= SEARCH_EXHAUSTIVE and r.has("samples"):
			for sample in r.samples:
				secondary.append([r.key, _range_sample(r, sample, cached.data.get(r.key))])
		else:
			primary.append([r.key, _range_sample(r, r.max_value, cached.data.get(r.key))])
			secondary.append([r.key, _range_sample(r, r.min_value, cached.data.get(r.key))])
	for t in cached.toggles:
		primary.append([t, null])
	var resolved_samples = []
	for pair in primary + secondary:
		var sample_key = pair[0]
		var sample_value = pair[1]
		var sample_base = cached.data.get(sample_key)
		if sample_value == null:
			sample_value = !sample_base
		elif sample_base is int and sample_value is float:
			sample_value = int(round(sample_value))
		if sample_value is Dictionary and sample_base is Dictionary:
			var CompleteSample = sample_base.duplicate(true)
			for SampleField in sample_value:
				CompleteSample[SampleField] = sample_value[SampleField]
			sample_value = CompleteSample
		if _value_differs(sample_value, sample_base):
			resolved_samples.append([sample_key, sample_value])
	if search_mode >= SEARCH_EXHAUSTIVE:
		variants = _combine_input_variants(variants, resolved_samples)
	else:
		for pair in resolved_samples:
			if variants.size() >= cap:
				break
			var k = pair[0]
			var v = pair[1]
			_append_unique_data(variants, _with_value(cached.data, k, v))
	if cached.get("RootKey", "") != "":
		for VariantIndex in range(variants.size()):
			variants[VariantIndex] = _duplicate_input(variants[VariantIndex][cached.RootKey])
	return variants


# Cartesian product of the finite samples discovered from player-reachable
# widgets. Defaults remain one branch for every input, so single-input and
# combined-input choices are both represented.
func _combine_input_variants(bases, samples):
	var grouped = {}
	var key_order = []
	for pair in samples:
		var key = pair[0]
		var value = pair[1]
		if !grouped.has(key):
			grouped[key] = []
			key_order.append(key)
		var duplicate = false
		for existing in grouped[key]:
			if !_value_differs(value, existing):
				duplicate = true
				break
		if !duplicate:
			grouped[key].append(value)
	var out = bases.duplicate()
	for key in key_order:
		var expanded = out.duplicate()
		var ExpandedKeys = {}
		for ExistingVariant in expanded:
			var ExistingKey = _fingerprint(ExistingVariant, 0)
			if ExistingKey != null:
				ExpandedKeys[ExistingKey] = true
		for variant in out:
			for value in grouped[key]:
				if _value_differs(value, variant.get(key)):
					var CombinedVariant = _with_value(variant, key, value)
					var CombinedKey = _fingerprint(CombinedVariant, 0)
					if CombinedKey == null or !ExpandedKeys.has(CombinedKey):
						expanded.append(CombinedVariant)
						if CombinedKey != null:
							ExpandedKeys[CombinedKey] = true
		out = _stratified_variant_trim(expanded, _exhaustive_variant_cap(), bases.size())
	return out


func _exhaustive_variant_cap():
	if exhaustive_limit == 1:
		return 256
	if exhaustive_limit == 2:
		return 128
	if exhaustive_limit == 3:
		return 64
	return 0


# Evenly sample the expansion rather than taking a prefix, which would favor
# early-discovered widgets and silently exclude later character mechanics.
func _stratified_variant_trim(variants, cap, preserve_count = 1):
	if cap <= 0 or variants.size() <= cap:
		return variants
	var trimmed = []
	var mandatory = int(min(preserve_count, cap))
	for i in range(mandatory):
		trimmed.append(variants[i])
	var slots = cap - mandatory
	for i in range(slots):
		var index = mandatory
		if slots > 1:
			index += int(round(float(i) * float(variants.size() - mandatory - 1) / float(slots - 1)))
		trimmed.append(variants[index])
	return trimmed


var _aim_dir = Vector2()


func _by_aim(a, b):
	return Vector2(a[0], a[1]).normalized().dot(_aim_dir) > Vector2(b[0], b[1]).normalized().dot(_aim_dir)


# str() on arbitrary mod data can recurse into huge or self-referencing
# structures; compare only what we ourselves sample.
func _value_differs(a, b):
	if a is Dictionary or b is Dictionary:
		if a is Dictionary and b is Dictionary:
			# Every key OUR sample carries, not just the plot's x/y - a
			# count dict compared on x/y alone reads null != null, i.e.
			# "identical", and the whole sample gets thrown away. Extra
			# keys on the default are deliberately ignored: they are mod
			# data we never touched, and may be arbitrarily deep.
			for k in a.keys():
				var LeftFingerprint = _fingerprint(a[k], 0)
				var RightFingerprint = _fingerprint(b.get(k), 0)
				if LeftFingerprint != null and RightFingerprint != null:
					if LeftFingerprint != RightFingerprint:
						return true
				elif a[k] != b.get(k):
					return true
			return false
		return true
	return str(a) != str(b)


# Widgets whose data value is a wrapper Dictionary need the sample put back
# in that shape before it can replace the default - and the default's other
# keys carried along, since we only ever mean to move the one we sampled.
func _range_sample(r, value, base_value):
	if r.wrap == "count":
		var out = base_value.duplicate() if base_value is Dictionary else {}
		out["count"] = int(round(value))
		return out
	if r.wrap == "field":
		var out = base_value.duplicate() if base_value is Dictionary else {}
		out[r.field] = int(round(value)) if out.get(r.field) is int else value
		return out
	return value


func _with_value(data, key, value):
	var out = data.duplicate(true)
	out[key] = value
	return out


func _append_unique_data(out, value):
	for existing in out:
		if !_value_differs(value, existing) and !_value_differs(existing, value):
			return
	out.append(_duplicate_input(value))


# Some modded ActionUIData scenes expose choices only through custom buttons.
# Valued's Chant, for example, returns `color = Blue` only after the player
# clicks a Blue button. Exercise each reachable enabled data button on the
# temporary UI and capture the complete player-obtainable result.
func _clickable_data_variants(ui, default_data):
	var Out = []
	var HiddenUnlocked = false
	# Multi-page move menus reveal controls only after another button is
	# pressed. Re-scan a few times so those newly reachable controls are also
	# exercised. Four passes covers tab -> submenu -> choice while remaining a
	# tiny UI-only cost compared with even one combat simulation.
	for Pass in range(4):
		for Candidate in _data_buttons(ui):
			var Reachable = _player_reachable(Candidate, ui)
			if default_data.has(Candidate.get_name()) or (!Reachable and !HiddenUnlocked) or Candidate.disabled:
				continue
			var Text = str(Candidate.text) if Candidate is Button else ""
			var Labels = [str(Candidate.get_name()), Text, str(Candidate.get("hint_tooltip"))]
			var Unsafe = false
			for Label in Labels:
				var Lower = Label.to_lower()
				if Lower.find("forfeit") != -1 or Lower.find("debug") != -1 or Lower.find("developer only") != -1 or Lower.find("dev only") != -1:
					Unsafe = true
					break
			if Unsafe:
				continue
			# emit_signal("pressed") alone bypasses scripts that implement the
			# BaseButton _pressed callback. Reproduce the click's toggle first,
			# then invoke whichever contract this custom control uses.
			if Candidate.toggle_mode:
				Candidate.pressed = !Candidate.pressed
			if Candidate.has_method("_pressed"):
				Candidate.call("_pressed")
			else:
				Candidate.emit_signal("pressed")
			# Some menus defer page visibility until their next process callback.
			# A changed root payload proves that the reachable tab button switched
			# modes, so later passes may exercise that page's child choices even
			# before the temporary UI receives an engine frame.
			if ui.has_method("get_data"):
				var Sample = ui.get_data()
				if Reachable and (_value_differs(Sample, default_data) or _value_differs(default_data, Sample)):
					HiddenUnlocked = true
				if _value_differs(Sample, default_data) or _value_differs(default_data, Sample):
					_append_unique_data(Out, Sample)
	return Out


func _data_buttons(node):
	var out = []
	for child in node.get_children():
		if child is BaseButton and !(child is OptionButton):
			out.append(child)
		for nested in _data_buttons(child):
			out.append(nested)
	return out


# Initialize temporary input scenes through the same facing contract used by
# the real action selector. Most roots propagate set_facing() themselves; the
# recursive fallback covers small custom scenes that expose only child widgets.
func _prepare_data_ui_facing(node, facing):
	if node.has_method("set_facing"):
		node.set_facing(facing)
		return
	if node.get("facing") != null:
		node.set("facing", facing)
		if node.has_method("init"):
			node.init()
		return
	for child in node.get_children():
		_prepare_data_ui_facing(child, facing)


# Aim at where the opponent is moving, not only where they stood at the start
# of the decision. ActionUIData values are world-space once the widget's facing
# is initialized, so no second facing multiplication belongs here.
func _led_world_direction(actor, foe):
	var target = Vector2(foe.get_pos().x, foe.get_pos().y)
	var velocity = foe.get_vel() if foe.has_method("get_vel") else null
	if velocity is Vector2:
		target += velocity * 6.0
	elif velocity is Dictionary and velocity.get("x") != null and velocity.get("y") != null:
		target += Vector2(float(velocity.x), float(velocity.y)) * 6.0
	return Vector2(target.x - actor.get_pos().x, target.y - actor.get_pos().y)


# Discover input widgets whose node name is a key in the move's data
# dictionary, so variants can sample them: plain Range sliders, the game's
# HorizSlider scene (a container with its Range inside), CountOption counters,
# OptionButton dropdowns, toggle buttons, and the 8Way direction picker.
func _find_inputs(node, data, entry, root):
	for child in node.get_children():
		var cname = child.get_name()
		if data.has(cname):
			if !_player_reachable(child, root):
				if debug_logging:
					print("CombatAI: input '%s' unreachable by a player, not sampling it" % cname)
			else:
				var value = data[cname]
				# OptionButton first: it IS a toggle-mode BaseButton internally,
				# but its value is a dropdown index, not an on/off state.
				if child is OptionButton:
					if !child.disabled and child.get_item_count() > 1 and (value is int or value is float):
						var option_samples = []
						for option_index in range(child.get_item_count()):
							option_samples.append(option_index)
						entry.ranges.append({"key": cname, "min_value": 0, "max_value": child.get_item_count() - 1, "wrap": "", "samples": option_samples})
				elif child is BaseButton and child.toggle_mode and value is bool:
					# Disabled toggles are decoration to a human - and often
					# exactly the dev-only switches we must never flip.
					if !child.disabled:
						entry.toggles.append(cname)
				elif value is int or value is float:
					# Only real input sliders/spinboxes: a stray ScrollBar inside
					# a matching container would feed garbage bounds into moves.
					var range_node = child if (child is Slider or child is SpinBox) else _find_range_in(child)
					if range_node != null and range_node.editable and abs(range_node.max_value - range_node.min_value) <= 10000:
						entry.ranges.append({"key": cname, "min_value": range_node.min_value, "max_value": range_node.max_value, "wrap": ""})
				elif value is Dictionary and value.has("count"):
					# CountOption (parry timing, charge counts, modded counters):
					# its data value is {"count": N}, so the numeric branch above
					# never saw it and we shipped the UI default forever. The
					# scene exports its own bounds; the inner slider is the
					# fallback for anything mod-made that mimics the shape.
					var lo = child.get("min_value")
					var hi = child.get("max_value")
					if !(lo is int or lo is float) or !(hi is int or hi is float):
						var count_node = _find_range_in(child)
						if count_node != null and count_node.editable:
							lo = count_node.min_value
							hi = count_node.max_value
						else:
							lo = null
							hi = null
					if lo != null and hi != null and abs(hi - lo) <= 10000:
						var count_range = {"key": cname, "min_value": lo, "max_value": hi, "wrap": "count"}
						if int(floor(hi)) - int(ceil(lo)) <= FULL_COUNTER_SAMPLE_LIMIT:
							var count_samples = []
							for count_value in range(int(ceil(lo)), int(floor(hi)) + 1):
								count_samples.append(count_value)
							count_range["samples"] = count_samples
						entry.ranges.append(count_range)
				elif value is Dictionary:
					# Some custom controls return a one-field wrapper such as
					# {"x": distance} around an ordinary Slider. Preserve that
					# shape while sampling the same player-visible range.
					var field_range = _find_range_in(child)
					var numeric_field = _single_numeric_field(value)
					if field_range != null and field_range.editable and numeric_field != "" and abs(field_range.max_value - field_range.min_value) <= 10000:
						entry.ranges.append({"key": cname, "min_value": field_range.min_value, "max_value": field_range.max_value, "wrap": "field", "field": numeric_field})
					elif value.has("y") and child.has_method("set_height"):
						# BlockHeight is high/low, not an unrestricted 8-way wheel.
						entry.ranges.append({"key": cname, "min_value": 0, "max_value": 1, "wrap": "field", "field": "y", "IsHeight": true})
					elif value.has("x") and value.has("y") and !(child is XYPlot):
						entry.eightways.append({"key": cname, "dirs": _eightway_dirs(child)})
		elif _player_reachable(child, root):
			# Custom roots sometimes rename the visible control while storing it
			# under a different move-data key (for example a VertSlider returned
			# as JumpH). Infer only a single unambiguous numeric match.
			var inferred_range = _infer_unique_range(child, data, entry, root)
			if inferred_range != null:
				entry.ranges.append(inferred_range)
		_find_inputs(child, data, entry, root)


func _single_numeric_field(value):
	var found = ""
	for key in value.keys():
		if value[key] is int or value[key] is float:
			if found != "":
				return ""
			found = str(key)
	return found


func _infer_unique_range(child, data, entry, root):
	if !child.has_method("get_data"):
		return null
	var range_node = child if (child is Slider or child is SpinBox) else _find_range_in(child)
	if range_node == null or !range_node.editable or abs(range_node.max_value - range_node.min_value) > 10000:
		return null
	var child_value = child.get_data()
	var child_field = _single_numeric_field(child_value) if child_value is Dictionary else ""
	if !(child_value is int or child_value is float) and child_field == "":
		return null
	var matched_key = ""
	var matched_wrap = ""
	var matched_field = ""
	for data_key in data.keys():
		# An exact-name control will be handled by the normal path, even when
		# it appears later in the scene tree.
		if root.find_node(str(data_key), true, false) != null or _range_key_claimed(entry, str(data_key)):
			continue
		var data_value = data[data_key]
		var matches = false
		var wrap = ""
		var field = ""
		if (child_value is int or child_value is float) and (data_value is int or data_value is float):
			matches = str(child_value) == str(data_value)
		elif child_value is Dictionary and data_value is Dictionary:
			var data_field = _single_numeric_field(data_value)
			matches = child_field != "" and child_field == data_field and str(child_value.get(child_field)) == str(data_value.get(data_field))
			wrap = "field"
			field = data_field
		if !matches:
			continue
		if matched_key != "":
			return null
		matched_key = str(data_key)
		matched_wrap = wrap
		matched_field = field
	if matched_key == "":
		return null
	var out = {"key": matched_key, "min_value": range_node.min_value, "max_value": range_node.max_value, "wrap": matched_wrap}
	if matched_wrap == "field":
		out["field"] = matched_field
	return out


func _range_key_claimed(entry, key):
	for candidate in entry.ranges:
		if str(candidate.key) == key:
			return true
	return false


# A move button a human could actually CLICK: shown by the game's own legality
# pass and enabled. A button inside a ScrollContainer remains reachable even
# while scrolled out of the viewport; rejecting those cut most of the legal
# kit from characters with very large menus such as Disgraced Chef. Truly
# off-screen non-scroll buttons remain excluded as dev/test actions.
func _button_reachable(button):
	if !button.is_visible():
		return false
	if button.has_method("get_disabled") and button.get_disabled():
		return false
	var ancestor = button.get_parent()
	while ancestor != null and ancestor != main_node:
		if ancestor is ScrollContainer:
			return true
		ancestor = ancestor.get_parent()
	var r = button.get_global_rect()
	var vp = button.get_viewport_rect().size
	return r.position.x + r.size.x > 0 and r.position.y + r.size.y > 0 and r.position.x < vp.x and r.position.y < vp.y


# The real data panel's size - the area a player can actually see and
# click widgets in. The authored UI scenes often have no root size at all
# (containers size themselves at runtime), so this is the honest yardstick.
var data_panel_size = Vector2()
const INPUT_LAYOUT_SLOP = 64.0


func _data_panel_size():
	if data_panel_size == Vector2() and main_node != null and is_instance_valid(main_node):
		var panel = main_node.find_node("DataContainer", true, false)
		if panel != null and panel is Control:
			data_panel_size = panel.rect_size
	return data_panel_size


# Only sample inputs a player could actually operate: skip widgets that are
# hidden or parked outside the panel's reachable area. The game (and some
# mods) leave dev-test widgets off-screen where only code can reach them -
# sampling those gave the AI moves no human can perform ("Grab Hop" et al).
func _player_reachable(widget, root):
	var pos = Vector2()
	var scrollable = false
	var node = widget
	while node != null and node != root:
		if node is CanvasItem and !node.visible:
			return false
		if node is ScrollContainer:
			scrollable = true
		if node is Control:
			pos += node.rect_position
		node = node.get_parent()
	if node != root or scrollable or !(widget is Control):
		return true
	# Bounds: authored root size when it exists, else (and at least) twice
	# the real panel - generous to layout slop, hopeless for widgets parked
	# hundreds of pixels away.
	var bounds = Vector2()
	if root is Control:
		bounds = root.rect_size
	var panel = _data_panel_size()
	if panel.x > 0:
		bounds.x = max(bounds.x, panel.x * 2.0)
		bounds.y = max(bounds.y, panel.y * 2.0)
	if bounds.x <= 0 or bounds.y <= 0:
		return true
	# Custom ActionUIData commonly draws compact controls just outside its tiny
	# authored root (Michael's dash slider is 12 px above it). Allow ordinary
	# layout overflow while still rejecting controls parked far off-screen.
	return pos.x + max(widget.rect_size.x, 1) > -INPUT_LAYOUT_SLOP and pos.y + max(widget.rect_size.y, 1) > -INPUT_LAYOUT_SLOP and pos.x < bounds.x + INPUT_LAYOUT_SLOP and pos.y < bounds.y + INPUT_LAYOUT_SLOP


func _find_range_in(node):
	for child in node.get_children():
		if child is Slider or child is SpinBox:
			return child
		var found = _find_range_in(child)
		if found != null:
			return found
	return null


const EIGHTWAY_DIRS = {"NW": [-1, -1], "N": [0, -1], "NE": [1, -1], "W": [-1, 0], "E": [1, 0], "SW": [-1, 1], "S": [0, 1], "SE": [1, 1]}


# Only offer directions the widget actually enables: the stock 8Way scene
# has a button per direction whose disabled/visible state is the truth.
# Unknown widgets (no such buttons) allow the full ring.
func _eightway_dirs(node):
	var dirs = []
	for dname in EIGHTWAY_DIRS:
		var btn = node.find_node(dname, true, false)
		if btn == null or !(btn is BaseButton) or (!btn.disabled and btn.visible):
			dirs.append(EIGHTWAY_DIRS[dname])
	return dirs


# Read an XYPlot's own declared aim restriction. Over half the aimed moves
# on this roster (155 of 278 scenes across the installed workshop) set
# limit_angle, confining the input to a cone - most often 90 degrees around
# forward, or 90 degrees around straight up. The clamp lives in the widget's
# update_value(), which we bypass by writing queued_data directly, so an
# unclamped "straight at them" vector is an input no human could ever pick
# AND usually points nowhere useful.
func _plot_cone(plot):
	if !plot.get("limit_angle"):
		return null
	var deg = plot.get("limit_center_degrees")
	var span = plot.get("limit_range_degrees")
	if !(deg is int or deg is float) or !(span is int or span is float):
		return null
	# get_limit_vec(): ang2vec(deg2rad(limit_center_degrees)) * Vector2(facing, 1)
	var f = plot.get("facing")
	if !(f is int or f is float) or f == 0:
		f = 1
	var c = deg2rad(float(deg))
	var center = Vector2(cos(c) * f, sin(c)).angle()
	return {"center": center, "half": deg2rad(float(span)) * 0.5, "symmetrical": bool(plot.get("limit_symmetrical"))}


# Shortest signed difference between two angles, in -PI..PI.
func _angle_delta(from_angle, to_angle):
	return wrapf(from_angle - to_angle, -PI, PI)


# Fold an aim direction to the NEAREST direction the widget would accept.
# (Not a reproduction of update_value()'s own clamp - we are choosing an
# input, not replaying a mouse drag, and nearest-edge is the better aim. Any
# result here is inside the arc, so a re-clamp anywhere would be a no-op.)
func _clamp_to_cone(dir, cone):
	if cone == null:
		return dir
	var delta = _angle_delta(dir.angle(), cone.center)
	var center = cone.center
	# Symmetrical plots accept the opposite lobe too; take whichever is
	# nearer, then clamp within that lobe. Only a handful of moves use it.
	if cone.symmetrical:
		var flipped = _angle_delta(dir.angle(), cone.center + PI)
		if abs(flipped) < abs(delta):
			delta = flipped
			center = cone.center + PI
	if abs(delta) <= cone.half:
		return dir
	return Vector2(cos(center + cone.half * sign(delta)), sin(center + cone.half * sign(delta)))


# The aim vectors worth simulating, as plot data dicts in -100..100. Always
# legal by construction. The first is our best guess (straight at them,
# folded into the cone); the rest are the cone's own edges, which are
# frequently the real answer when the foe sits outside the allowed arc.
func _aim_samples(cone, toward_dir):
	var out = [_as_plot_data(_clamp_to_cone(toward_dir, cone))]
	if cone != null:
		for edge in [cone.center - cone.half, cone.center + cone.half]:
			var sample = _as_plot_data(Vector2(cos(edge), sin(edge)))
			var dup = false
			for existing in out:
				if existing.x == sample.x and existing.y == sample.y:
					dup = true
			if !dup:
				out.append(sample)
	return out


func _as_plot_data(dir):
	var n = dir.normalized()
	return {"x": int(round(n.x * 100)), "y": int(round(n.y * 100))}


func _find_plots(node):
	var out = []
	if node is XYPlot:
		out.append(node)
	for child in node.get_children():
		for found in _find_plots(child):
			out.append(found)
	return out


func _pick_di(my_session):
	var base = _default_di()
	var candidates = [base]
	var ring = [
		{"x": 100, "y": 0}, {"x": 71, "y": 71}, {"x": 0, "y": 100}, {"x": -71, "y": 71},
		{"x": -100, "y": 0}, {"x": -71, "y": -71}, {"x": 0, "y": -100}, {"x": 71, "y": -71},
		{"x": 0, "y": 0}
	]
	# Fast keeps a varied half-width sample. Balanced/Epic examine the complete
	# DI ring, including toward, vertical, and neutral choices; the old search
	# only checked the away-facing half-plane and became trivially readable.
	if performance_mode:
		var offset = rng.randi() % 4
		for index in [offset, offset + 2, offset + 4, offset + 6]:
			_append_unique_di(candidates, ring[index % 8])
	else:
		for candidate in ring:
			_append_unique_di(candidates, candidate)
	var scored = []
	for candidate in candidates:
		var score = _run_sim(ai_player, "Continue", null, _make_extra(candidate), "Continue", null, my_session)
		if score is GDScriptFunctionState:
			score = yield(score, "completed")
		if score == null:
			return null
		scored.append({"di": candidate, "score": float(score)})
	scored.sort_custom(self, "_by_score_desc")
	var margin = [55.0, 35.0, 22.0, 12.0, 8.0][int(clamp(difficulty, 0, 4))]
	if di_policy == DI_POLICY_UNPREDICTABLE:
		margin *= 2.0
	var pool = []
	for entry in scored:
		if scored[0].score - entry.score <= margin:
			pool.append(entry.di)
	return pool[rng.randi() % pool.size()] if !pool.empty() else scored[0].di


func _append_unique_di(out, candidate):
	for existing in out:
		if int(existing.x) == int(candidate.x) and int(existing.y) == int(candidate.y):
			return
	out.append(candidate)


func _default_di():
	if di_policy == DI_POLICY_RESPECT_UI:
		return _selected_ui_di(ai_player)
	var foe = fighter.opponent
	var away = Vector2(fighter.get_pos().x - foe.get_pos().x, fighter.get_pos().y - foe.get_pos().y).normalized()
	return _sanitize_di({"x": int(round(away.x * 100)), "y": int(round(away.y * 100))})


func _make_extra(di):
	return {"DI": _sanitize_di(di), "feint": false, "prediction": -1, "reverse": false}


# Safe current DI for prediction sweeps. Character scripts commonly read
# current_di.x/y directly, so a null queued DI is never a valid hypothesis.
func _foe_di(player_id):
	var actor = game.get_player(int(player_id)) if game != null else null
	if actor != null and is_instance_valid(actor):
		return _sanitize_di(actor.get("current_di"))
	return {"x": 0, "y": 0}


func _selected_ui_di(player_id):
	var buttons = _action_buttons(player_id)
	if buttons != null:
		var widget = buttons.find_node("DI", true, false)
		if widget != null and widget.has_method("get_data"):
			return _sanitize_di(widget.get_data(), _foe_di(player_id))
	return _foe_di(player_id)


func _sanitize_di(value, fallback = null):
	var source = value
	if source is Vector2:
		source = {"x": source.x, "y": source.y}
	if !(source is Dictionary) or source.get("x") == null or source.get("y") == null:
		source = fallback
	if source is Vector2:
		source = {"x": source.x, "y": source.y}
	if !(source is Dictionary) or source.get("x") == null or source.get("y") == null:
		return {"x": 0, "y": 0}
	var x = source.get("x")
	var y = source.get("y")
	if !(x is int or x is float or x is String) or !(y is int or y is float or y is String):
		return {"x": 0, "y": 0}
	return {"x": int(clamp(float(x), -100.0, 100.0)), "y": int(clamp(float(y), -100.0, 100.0))}


func _normalized_extra(value, player_id):
	var out = value.duplicate(true) if value is Dictionary else {}
	out["DI"] = _sanitize_di(out.get("DI"), _foe_di(player_id))
	if !out.has("feint"):
		out["feint"] = false
	if !out.has("prediction"):
		out["prediction"] = -1
	if !out.has("reverse"):
		out["reverse"] = false
	return out


# The same turn's inputs, but cancelling the move. process_extra() reads
# "feint" straight off this dict, so the sandbox and the real game see the
# identical decision.
func _with_feint(extra):
	var out = extra.duplicate()
	out["feint"] = true
	return out


# Snapshot only generic, deterministic combat progress. This deliberately
# avoids character names and special-case resources, so the same safeguard
# works for base and modded dittos without prescribing their move lists.
func _combat_progress_snapshot():
	if !is_instance_valid(fighter) or fighter.opponent == null:
		return null
	var foe = fighter.opponent
	return {
		"my_hp": float(fighter.hp),
		"foe_hp": float(foe.hp),
		"my_pos": Vector2(fighter.get_pos().x, fighter.get_pos().y),
		"foe_pos": Vector2(foe.get_pos().x, foe.get_pos().y),
		"my_combo": int(fighter.combo_count),
		"foe_combo": int(foe.combo_count),
		"my_super": float(fighter.super_meter),
		"foe_super": float(foe.super_meter),
		"my_burst": float(fighter.burst_meter),
		"foe_burst": float(foe.burst_meter),
		"objects": game.objects.size(),
	}


func _update_stagnation():
	if !both_ai:
		return
	var now = _combat_progress_snapshot()
	if now == null or progress_snapshot == null:
		return
	var changed = now.my_hp != progress_snapshot.my_hp or now.foe_hp != progress_snapshot.foe_hp
	changed = changed or now.my_combo != progress_snapshot.my_combo or now.foe_combo != progress_snapshot.foe_combo
	changed = changed or now.my_super != progress_snapshot.my_super or now.foe_super != progress_snapshot.foe_super
	changed = changed or now.my_burst != progress_snapshot.my_burst or now.foe_burst != progress_snapshot.foe_burst
	changed = changed or now.objects != progress_snapshot.objects
	changed = changed or now.my_pos.distance_to(progress_snapshot.my_pos) > LOOP_POSITION_EPSILON
	changed = changed or now.foe_pos.distance_to(progress_snapshot.foe_pos) > LOOP_POSITION_EPSILON
	if changed:
		stagnation_turns = 0
		recent_ai_actions.clear()
	else:
		stagnation_turns += 1


# Apply the loop breaker to decision copies only. Search tables, awareness
# blending, beams, and study diagnostics retain their honest simulation score.
func _break_stagnant_loop(scored):
	if !both_ai or stagnation_turns < LOOP_STAGNATION_START or recent_ai_actions.empty():
		return scored
	var repeats = {}
	for action in recent_ai_actions:
		repeats[action] = int(repeats.get(action, 0)) + 1
	var out = []
	for entry in scored:
		var candidate = entry.duplicate()
		var repeated = int(repeats.get(candidate.action, 0))
		var terms = candidate.get("terms", {})
		var made_contact = bool(candidate.get("hit", false)) or bool(candidate.get("extended", false)) or float(terms.get("kill", 0.0)) > 0.0
		if repeated > 0 and !made_contact:
			var penalty = LOOP_BASE_PENALTY * repeated + LOOP_GROWTH_PENALTY * max(0, stagnation_turns - LOOP_STAGNATION_START)
			candidate.score -= min(LOOP_MAX_PENALTY, penalty)
		out.append(candidate)
	if stagnation_turns >= LoopStagnationEscape:
		var EscapeCandidates = []
		for Candidate in out:
			var ActionName = str(Candidate.get("action", "")).to_lower().replace(" ", "").replace("_", "")
			var IsIdleAction = ActionName in ["continue", "continueauto", "wait", "fall"]
			var IsWasteCancel = ActionName.find("whiffcancel") != -1 or ActionName.find("instantcancel") != -1
			if !IsIdleAction and !IsWasteCancel and str(Candidate.get("category", "Utility")) in ["Attack", "Combo", "Positioning", "Setup", "Finisher"]:
				EscapeCandidates.append(Candidate)
		if !EscapeCandidates.empty():
			return EscapeCandidates
	return out


# Rule 1 - relentlessness, applied at pick time on a copy so stored scores
# stay honest for beam reuse and blending: mid-combo, if ANY candidate can
# keep the combo alive (directly, or via a deep-search-verified follow-up),
# candidates that can't are picked as if COMBO_DROP_PENALTY worse.
func _relentless(scored, versus_action = ""):
	if !is_instance_valid(fighter) or fighter.combo_count <= 0:
		return scored
	# When their predicted play IS the burst, the combo is about to be
	# broken anyway - blocking or parrying the burst is the right greed
	# (a parried burst can be the whole round), so no candidate gets
	# punished for declining to swing into it.
	if str(versus_action).find("Burst") != -1:
		return scored
	var can_extend = false
	var BestExtendingScore = -INF
	var BestDroppingScore = -INF
	for e in scored:
		if e.get("extended"):
			can_extend = true
			BestExtendingScore = max(BestExtendingScore, float(e.score))
		else:
			BestDroppingScore = max(BestDroppingScore, float(e.score))
	if !can_extend:
		return scored
	var DropPenalty = COMBO_DROP_PENALTY
	var ProtectContinuation = preferred_winner == DIRECTOR_NATURAL or ai_player == preferred_winner
	if ProtectContinuation and difficulty >= 2 and BestDroppingScore > -INF:
		var RequiredMargin = ComboContinuationMargins[difficulty]
		DropPenalty = max(DropPenalty, BestDroppingScore - BestExtendingScore + RequiredMargin)
	var out = []
	for e in scored:
		var c = e.duplicate()
		if !c.get("extended"):
			c.score -= DropPenalty
		out.append(c)
	return out


func _argmax(scored):
	var best = scored[0]
	for entry in scored:
		if entry.score > best.score:
			best = entry
	return best


func _pick_decision(scored):
	scored = _director_decision_pool(scored)
	# Determined means the best surviving director-safe line is selected
	# without skill-temperature or shortlist randomness undoing the outcome.
	if preferred_winner != DIRECTOR_NATURAL and director_strength >= 2 and !scored.empty():
		return _argmax(scored)
	if move_selection == SELECTION_SKILL_WEIGHTED:
		return _pick_by_temperature(scored)
	return _pick_from_best_pool(scored)


# Build a shortlist from the best VARIANT of each action first. This prevents
# one move with dozens of aim combinations from buying dozens of lottery
# tickets, while a second roll still varies that action's strong inputs.
func _pick_from_best_pool(scored):
	if scored.empty():
		return {"action": "Continue", "data": null, "extra": _make_extra(null), "score": 0, "category": "Utility"}
	var ranked = scored.duplicate()
	ranked.sort_custom(self, "_by_score_desc")
	var action_best = []
	var seen = {}
	for entry in ranked:
		if !seen.has(entry.action):
			seen[entry.action] = true
			action_best.append(entry)
	var skill = int(clamp(difficulty, 0, DIFFICULTY_TEMPS.size() - 1))
	var margin = 1.0
	var max_actions = action_best.size()
	if move_selection == SELECTION_NEAR_BEST:
		margin = [70.0, 55.0, 40.0, 28.0, 18.0][skill]
	elif move_selection == SELECTION_TOP_MOVES:
		margin = [160.0, 120.0, 90.0, 65.0, 45.0][skill]
		max_actions = [8, 7, 6, 5, 4][skill]
	var best_score = float(action_best[0].score)
	var eligible = []
	for action_entry in action_best:
		if eligible.size() >= max_actions or best_score - float(action_entry.score) > margin:
			break
		eligible.append(action_entry)
	if eligible.empty():
		return action_best[0]
	var chosen_action = eligible[rng.randi() % eligible.size()]
	var variant_margin = max(1.0, margin * 0.5)
	var variants = []
	for entry in ranked:
		if entry.action == chosen_action.action and float(chosen_action.score) - float(entry.score) <= variant_margin:
			variants.append(entry)
	if variants.empty():
		return chosen_action
	return variants[rng.randi() % variants.size()]


# Skill temperature: softmax over scores. Sage is effectively argmax, Rookie
# genuinely blunders.
func _pick_by_temperature(scored):
	if scored.empty():
		return {"action": "Continue", "data": null, "score": 0}
	var temp = DIFFICULTY_TEMPS[int(clamp(difficulty, 0, DIFFICULTY_TEMPS.size() - 1))]
	var best = _argmax(scored)
	var weights = []
	var total = 0.0
	var ActionWeights = {}
	for entry in scored:
		var w = exp(clamp((entry.score - best.score) / max(temp, 0.001), -30.0, 0.0))
		weights.append(w)
		ActionWeights[entry.action] = max(float(ActionWeights.get(entry.action, 0.0)), w)
	# Apply skill temperature to each action's best input first. Duplicate
	# aim/slider samples must not multiply that action's selection odds.
	for Action in ActionWeights:
		total += float(ActionWeights[Action])
	var ActionRoll = rng.randf() * total
	var ChosenAction = best.action
	for Action in ActionWeights:
		ActionRoll -= float(ActionWeights[Action])
		if ActionRoll <= 0.0:
			ChosenAction = Action
			break
	total = 0.0
	for Index in range(scored.size()):
		if scored[Index].action == ChosenAction:
			total += weights[Index]
	var roll = rng.randf() * total
	for i in range(scored.size()):
		if scored[i].action != ChosenAction:
			continue
		roll -= weights[i]
		if roll <= 0.0:
			return scored[i]
	return best


func _prepare_sim():
	if sim_viewport == null or !is_instance_valid(sim_viewport):
		sim_viewport = Viewport.new()
		sim_viewport.usage = Viewport.USAGE_2D
		sim_viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
		sim_viewport.size = Vector2(400, 300)
		add_child(sim_viewport)
	if sim_game == null or !is_instance_valid(sim_game) or !sim_game.game_started:
		if sim_game != null and is_instance_valid(sim_game):
			sim_game.free()
		var game_scene = load("res://Game.tscn")
		if game_scene == null:
			_report_fault("E104", "The prediction sandbox could not load Game.tscn. This decision was cancelled safely.")
			return false
		sim_game = game_scene.instance()
		if sim_game == null:
			_report_fault("E105", "The prediction sandbox could not be created. This decision was cancelled safely.")
			return false
		sim_game.is_ghost = true
		sim_game.visible = false
		sim_viewport.add_child(sim_game)
		sim_game.set_physics_process(false)
		sim_game.set_process(false)
		sim_game.start_game(true, main_node.match_data)
		sim_game.ghost_speed = 100
		sim_game.ghost_freeze = false
		sim_game.set_physics_process(false)
		sim_game.set_process(false)
		# The ghost auto-play timer would tick the sandbox outside our
		# control (running modded intro states unsupervised) - never allow it.
		var gst = sim_game.get_node_or_null("GhostStartTimer")
		if gst != null:
			gst.stop()
		sim_start_states = [sim_game.p1.state_machine.state.name, sim_game.p2.state_machine.state.name]
	else:
		var reset_started = OS.get_ticks_msec()
		_reset_sim()
		var rst = float(OS.get_ticks_msec() - reset_started)
		avg_reset_ms = rst if avg_reset_ms == 0.0 else avg_reset_ms * 0.8 + rst * 0.2
	var copy_started = OS.get_ticks_msec()
	game.copy_to(sim_game)
	_disable_automatic_sim_processing(sim_game)
	var cpy = float(OS.get_ticks_msec() - copy_started)
	avg_copy_ms = cpy if avg_copy_ms == 0.0 else avg_copy_ms * 0.8 + cpy * 0.2
	return true


# GDScript 3 cannot intercept native engine panics or arbitrary errors emitted
# inside another mod. These guards report faults Strategist can detect before
# they become an invalid submission, with a stable code users can paste into
# the Workshop comments alongside their log excerpt.
func _report_fault(code, message):
	var report = "Combat AI Strategist [CAS-%s] %s" % [str(code), str(message)]
	push_error(report)
	var file = File.new()
	var mode = File.READ_WRITE if file.file_exists(FAULT_LOG_PATH) else File.WRITE
	if file.open(FAULT_LOG_PATH, mode) == OK:
		if mode == File.READ_WRITE:
			file.seek_end()
		file.store_line("%s | %s" % [OS.get_datetime().get("year", 0), report])
		file.close()
	if !show_error_popups or main_node == null or !is_instance_valid(main_node):
		return
	var shown = main_node.get_meta("cas_fault_popup_codes") if main_node.has_meta("cas_fault_popup_codes") else {}
	if shown.has(str(code)):
		return
	shown[str(code)] = true
	main_node.set_meta("cas_fault_popup_codes", shown)
	var dialog = AcceptDialog.new()
	dialog.window_title = "Combat AI Strategist Issue"
	dialog.dialog_text = "%s\n\nPlease report CAS-%s and the error message in this mod's Steam Workshop comments. Include the matching lines from godot.log when possible.\n\nSaved to: user://combatai_strategist_faults.log" % [str(message), str(code)]
	main_node.add_child(dialog)
	dialog.connect("popup_hide", dialog, "queue_free")
	dialog.call_deferred("popup_centered", Vector2(760, 300))


# YOMI's prediction is advanced exclusively by simulate_one_tick(). Modded
# fighters may also implement _process for cameras, music, UI, or visuals;
# leaving those callbacks alive lets the hidden sandbox mutate real-scene
# presentation between simulations and burns CPU while the AI is yielded.
func _disable_automatic_sim_processing(node):
	if node == null or !is_instance_valid(node):
		return
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_automatic_sim_processing(child)


# Clear everything a previous simulation left behind that copy_to won't
# overwrite, so the sandbox is indistinguishable from a freshly started one.
func _reset_sim():
	for object in sim_game.objects:
		if is_instance_valid(object):
			object.free()
	sim_game.objects.clear()
	for fx in sim_game.effects:
		if is_instance_valid(fx):
			fx.free()
	sim_game.effects.clear()
	for key in sim_game.objs_map.keys():
		if key != "P1" and key != "P2":
			sim_game.objs_map.erase(key)
	var idx = 0
	for player in [sim_game.p1, sim_game.p2]:
		player.state_machine.states_stack.clear()
		player.state_machine.queued_states.clear()
		player.state_machine.queued_data.clear()
		for hitbox in player.hitboxes:
			if hitbox.active or hitbox.enabled:
				hitbox.deactivate()
		# Silent return to the pristine starting state: no _exit/_enter side
		# effects from whatever state the last simulation ended in.
		player.state_machine._change_state(sim_start_states[idx], null, false, false)
		# The parry probe reads these off the fighter, and they only ever
		# latch once - we reuse one sandbox all match, so without clearing
		# them the first block of the match answers every later probe.
		player.ghost_blocked_melee_attack = -1
		player.ghost_wrong_block = ""
		player.queued_action = null
		player.queued_data = null
		player.queued_extra = null
		idx += 1
	# hp is assigned at the END of copy_to; sync it now so state transition
	# callbacks during the copy never see a stale corpse.
	sim_game.p1.hp = game.p1.hp
	sim_game.p2.hp = game.p2.hp
	sim_game.super_freeze_ticks = 0
	sim_game.super_active = false
	sim_game.parry_freeze = false
	sim_game.hit_freeze = false
	sim_game.p1_super = false
	sim_game.p2_super = false
	sim_game.prediction_effect = false
	sim_game.undoing = false


func _show_status():
	if status_label == null:
		var layer = CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		status_label = Label.new()
		status_label.anchor_left = 0
		status_label.anchor_right = 1
		# Below the arena's midline: the top of the screen is covered by
		# HP/meter bars, which hid this label entirely.
		status_label.anchor_top = 0.62
		status_label.anchor_bottom = 0.62
		status_label.margin_top = 0
		status_label.margin_bottom = 24
		status_label.align = Label.ALIGN_CENTER
		layer.add_child(status_label)
	status_label.text = "Combat AI is thinking..."
	status_label.visible = true
