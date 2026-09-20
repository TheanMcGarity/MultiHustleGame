extends Resource

class_name MHStoryFighter

const NINJA = "Ninja"
const SWORD = "Cowboy"
const MAGIC = "Wizard"
const ROBOT = "Robot"
const BEAST = "Mutant"
# add alien when bro drops

export var name = "default name"
export var character_type = NINJA
export var max_hp = 1500
export var team = 1

func is_char_valid() -> bool:
	if (character_type == NINJA):
		return true
	if (character_type == SWORD):
		return true
	if (character_type == MAGIC):
		return true
	if (character_type == ROBOT):
		return true
	if (character_type == BEAST):
		return true
	return false

func is_team_valid() -> bool:
	return team > -1 and team < 5

export var difficulty = 0
export var behavior = MHCombatAI.BEHAVIOR_CLASSIC
export var search_mode = MHCombatAI.SEARCH_ADAPTIVE
export var awareness = MHCombatAI.AWARENESS_STANDARD
export var move_selection = MHCombatAI.SELECTION_SKILL_WEIGHTED
export var learning_enabled = true
export var LearningAlgorithm = MHCombatAI.LEARNING_ADAPTIVE
export var preferred_winner = MHCombatAI.DIRECTOR_NATURAL
export var director_strength = 0
export var battle_pacing = MHCombatAI.PACING_NATURAL
export var move_visibility = MHCombatAI.VISIBILITY_FAIR
export var exhaustive_limit = 0
export var tactical_depth = 0
export var simulation_cache_enabled = true
export var ignored_moves = ""
export var ignored_move_cache = {}
export var di_policy = MHCombatAI.DI_POLICY_STRATEGIST
export var resource_strategy = MHCombatAI.RESOURCE_ADAPTIVE
