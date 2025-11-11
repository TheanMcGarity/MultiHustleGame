extends CanvasLayer

var game: Game

onready var p1_healthbar = $"%P1HealthBar"
onready var p2_healthbar = $"%P2HealthBar"

onready var p1_health_bar_trail = $"%P1HealthBarTrail"
onready var p2_health_bar_trail = $"%P2HealthBarTrail"

onready var p1_burst_meter = $"%P1BurstMeter"
onready var p2_burst_meter = $"%P2BurstMeter"

onready var p1_super_meter = $"%P1SuperMeter"
onready var p2_super_meter = $"%P2SuperMeter"

onready var active_p1_super_meter = $"%ActiveP1SuperMeter"
onready var active_p2_super_meter = $"%ActiveP2SuperMeter"

onready var p1_num_supers = $"%P1NumSupers"
onready var p2_num_supers = $"%P2NumSupers"

onready var p1_combo_counter = $"%P1ComboCounter"
onready var p2_combo_counter = $"%P2ComboCounter"

onready var p1_air_option_display = $"%P1AirMovementDisplay"
onready var p2_air_option_display = $"%P2AirMovementDisplay"

onready var p1_super_effects_node = $"%P1SuperEffectsNode"
onready var p2_super_effects_node = $"%P2SuperEffectsNode"

onready var p1_ghost_health_bar = $"%P1GhostHealthBar"
onready var p1_ghost_health_bar_trail = $"%P1GhostHealthBarTrail"

onready var p2_ghost_health_bar = $"%P2GhostHealthBar"
onready var p2_ghost_health_bar_trail = $"%P2GhostHealthBarTrail"

onready var p1_sadness_label = $"%P1SadnessLabel"
onready var p2_sadness_label = $"%P2SadnessLabel"

onready var p1_brace_label = $"%P1BraceLabel"
onready var p2_brace_label = $"%P2BraceLabel"

onready var extra_info_container = $"%ExtraInfoContainer"
onready var extra_info_label_1 = $"%ExtraInfoLabel1"
onready var extra_info_label_2 = $"%ExtraInfoLabel2"
onready var active_p1_initiative = $"%ActiveP1Initiative"
onready var active_p2_initiative = $"%ActiveP2Initiative"

onready var action_buttons = $"%ActionButtons"
onready var p1_action_buttons = $"%P1ActionButtons"
onready var p2_action_buttons = $"%P2ActionButtons"

onready var p1_air_movement_label = $"%P1AirMovementLabel"
onready var p2_air_movement_label = $"%P2AirMovementLabel"


const TRAIL_DRAIN_RATE = 25

var p1: Fighter
var p2: Fighter

var super_started = false

var p1_effects = []
var p2_effects = []

var p1_prev_super = 0
var p2_prev_super = 0


func init(game):
	show()
	self.game = game
	$"%GameUI".show()
	$"%WinLabel".hide()
	p1 = game.get_player(1)
	p2 = game.get_player(2)
	extra_info_label_1.fighter = p1
	extra_info_label_2.fighter = p2
	p1_air_option_display.fighter = p1
	p2_air_option_display.fighter = p2
	$"%P1Portrait".texture = p1.character_portrait
	$"%P2Portrait".texture = p2.character_portrait
	p1_healthbar.max_value = p1.MAX_HEALTH
	p2_healthbar.max_value = p2.MAX_HEALTH
	p2_health_bar_trail.max_value = p2.MAX_HEALTH
	p1_health_bar_trail.max_value = p1.MAX_HEALTH
	p1_health_bar_trail.value = p1.MAX_HEALTH
	p2_health_bar_trail.value = p2.MAX_HEALTH
	$"%P1FeintDisplay".fighter = p1
	$"%P2FeintDisplay".fighter = p2
	p1_ghost_health_bar_trail.max_value = p1.MAX_HEALTH
	p2_ghost_health_bar_trail.max_value = p2.MAX_HEALTH
	p1_ghost_health_bar_trail.value = p1.MAX_HEALTH
	p2_ghost_health_bar_trail.value = p2.MAX_HEALTH
	
	p1_ghost_health_bar.max_value = p1.MAX_HEALTH
	p2_ghost_health_bar.max_value = p2.MAX_HEALTH
	
	p1_super_meter.max_value = p1.MAX_SUPER_METER
	p2_super_meter.max_value = p2.MAX_SUPER_METER
	
	active_p1_super_meter.max_value = p1.MAX_SUPER_METER
	active_p2_super_meter.max_value = p2.MAX_SUPER_METER
	
	p1_burst_meter.fighter = p1
	p2_burst_meter.fighter = p2
	
	p1_air_movement_label.text = p1.air_option_bar_name
	p2_air_movement_label.text = p2.air_option_bar_name
	
	

	if Network.multiplayer_active and !SteamLobby.SPECTATING:
		$"%P1Username".text = Network.pid_to_username(1)
		$"%P2Username".text = Network.pid_to_username(2)
	elif game.match_data.has("user_data"):
		if game.match_data.user_data.has("p1"):
			$"%P1Username".text = game.match_data.user_data.p1
		if game.match_data.user_data.has("p2"):
			$"%P2Username".text = game.match_data.user_data.p2
	
	$"%P1ShowStyle".set_pressed_no_signal(true)
	$"%P2ShowStyle".set_pressed_no_signal(true)
	
	
	game.connect("game_won", self, "on_game_won")
	
	
	# Reset the portrait colors so that replaying doesnt show the incorrect thing
	$"%P1Portrait".modulate = game.MultiHustle_get_color_by_index(1)
	$"%P2Portrait".self_modulate = game.MultiHustle_get_color_by_index(2)

	game.connect("team_game_won", self, "on_team_won")

func healthbar_armor_effect(player, healthbar: TextureProgress, no_armor_image, armor_image, projectile_armor_image):
	if player.has_armor():
		if healthbar.texture_progress != armor_image:
			healthbar.texture_progress = armor_image
	elif player.has_projectile_armor():
		if healthbar.texture_progress != projectile_armor_image:
			healthbar.texture_progress = projectile_armor_image
	else:
		if healthbar.texture_progress != no_armor_image:
			healthbar.texture_progress = no_armor_image


func super_speed_scale(ticks):
	return 15 * (15 / float(ticks))

func drain_health_trail(trail, drain_value):
	if drain_value < trail.value:
		trail.value -= TRAIL_DRAIN_RATE
		if trail.value < drain_value:
			trail.value = drain_value
	else:
		trail.value = drain_value

var p1index:int = 1
var p2index:int = 2

var mh_p1_healthbar: TextureProgress;
var mh_p2_healthbar: TextureProgress;
var mh_p1_health_bar_trail: TextureProgress;
var mh_p2_health_bar_trail: TextureProgress;
var mh_p1_ghost_health_bar: TextureProgress;
var mh_p2_ghost_health_bar: TextureProgress;
var mh_p1_ghost_health_bar_trail: TextureProgress;
var mh_p2_ghost_health_bar_trail: TextureProgress;

var health_labels
var p1_health_label
var p2_health_label

func _ready():
	$"%P1ShowStyle".connect("toggled", self, "_on_show_style_toggled", [1])
	$"%P2ShowStyle".connect("toggled", self, "_on_show_style_toggled", [2])
	
	mh_p1_healthbar = p1_healthbar.duplicate()
	mh_p1_healthbar.name = "MH_P1HealthBar"
	mh_p1_healthbar.rect_position.x = 0
	$"%P1HealthBar".add_child(mh_p1_healthbar)
	p1_healthbar.self_modulate.a = 0
	p1_health_bar_trail.modulate.a = 0
	p1_ghost_health_bar.modulate.a = 0
	mh_p1_health_bar_trail = mh_p1_healthbar.get_node("P1HealthBarTrail")
	mh_p1_ghost_health_bar = mh_p1_healthbar.get_node("P1GhostHealthBar")
	mh_p1_ghost_health_bar_trail = mh_p1_healthbar.get_node("P1GhostHealthBar/P1GhostHealthBarTrail")
	
	mh_p2_healthbar = p2_healthbar.duplicate()
	mh_p2_healthbar.name = "MH_P2HealthBar"
	mh_p2_healthbar.rect_position.x = 0
	$"%P2HealthBar".add_child(mh_p2_healthbar)
	p2_healthbar.self_modulate.a = 0
	p2_health_bar_trail.modulate.a = 0
	p2_ghost_health_bar.modulate.a = 0
	mh_p2_health_bar_trail = mh_p2_healthbar.get_node("P2HealthBarTrail")
	mh_p2_ghost_health_bar = mh_p2_healthbar.get_node("P2GhostHealthBar")
	mh_p2_ghost_health_bar_trail = mh_p2_healthbar.get_node("P2GhostHealthBar/P2GhostHealthBarTrail")

	health_labels = load("res://MultiHustle/ui/HUD/HPNumbers.tscn").instance()
	p1_health_label = health_labels.get_node("P1HealthLabel")
	p2_health_label = health_labels.get_node("P2HealthLabel")
	self.add_child(health_labels)


	hide()
	$"%WinLabel".hide()

func on_game_won(winner):
	$"HudAnimationPlayer".play("game_won")
	if winner == 0:
		$"%WinLabel".text = "DRAW"
	else:
		if not Network.multiplayer_active or SteamLobby.SPECTATING:
			$"%WinLabel".text = "P%d {%s) WON!" % [winner, Network.player_character_names[winner]] 
		else:
			$"%WinLabel".text = "%s WON!" % Network.game.player_names[winner]
	SteamHustle.record_winner(winner)

func on_team_won(winner):
	$"HudAnimationPlayer".play("game_won")
	var string:String
	match winner:
		1:
			string = "RED"
		2:
			string = "BLUE"
		3:
			string = "YELLOW"
		4:
			string = "GREEN"
		_:
			string = "#"+str(winner)

	print("TEAM WON! - " + string)
	$"%WinLabel".text = "TEAM " + string + " WIN"

func _on_show_style_toggled(on, pidx):
	var player_id = self["p%dindex" % pidx]
	if is_instance_valid(game):
		var player = game.get_player(player_id)
		if on:
			player.reapply_style()
		else :
			player.reset_style()
			player.sprite.get_material().set_shader_param("color", game.MultiHustle_get_color_by_index(player_id))

func initp1(p1index):
	self.p1index = p1index
	p1 = game.players[p1index]
	p1_air_option_display.fighter = p1
	$"%P1Portrait".texture = p1.character_portrait
	if is_instance_valid(game):
		$"%P1Portrait".modulate = game.MultiHustle_get_color_by_index(p1index)
	$"%P1FeintDisplay".fighter = p1
	yield(get_tree(), "idle_frame")
	p1_healthbar.max_value = 1500
	p1_health_bar_trail.max_value = 1500
	p1_health_bar_trail.value = 1500
	p1_ghost_health_bar_trail.max_value = 1500
	p1_ghost_health_bar_trail.value = 1500
	p1_ghost_health_bar.max_value = 1500
	
	mh_p1_healthbar.max_value = 1500
	mh_p1_health_bar_trail.max_value = 1500
	mh_p1_health_bar_trail.value = 1500
	mh_p1_ghost_health_bar_trail.max_value = 1500
	mh_p1_ghost_health_bar_trail.value = 1500
	mh_p1_ghost_health_bar.max_value = 1500
	
	p1_super_meter.max_value = p1.MAX_SUPER_METER
	p1_burst_meter.fighter = p1

	if Network.multiplayer_active and not SteamLobby.SPECTATING:
		if (Network.game.player_names.has(p1index)):
			$"%P1Username".text = Network.game.player_names[p1index]
	elif not Network.multiplayer_active:
		Network.player_character_names[p1index]
	elif game.match_data.has("user_data"):
		if game.match_data.user_data.has("p"+str(p1index)):
			$"%P1Username".text = Network.game.player_names[p1index]
	
	$"%P1ShowStyle".set_pressed_no_signal(p1.is_style_active == true)

	p1_health_label.text = "%d/%d" % [p1.hp, p1.MAX_HEALTH]

	print("initp1->MAX_HEALTH=%d" % p1.MAX_HEALTH)


func initp2(p2index):
	self.p2index = p2index
	p2 = game.players[p2index]
	p2_air_option_display.fighter = p2
	$"%P2Portrait".texture = p2.character_portrait
	if is_instance_valid(game):
		$"%P2Portrait".self_modulate = game.MultiHustle_get_color_by_index(p2index)
	
	yield(get_tree(), "idle_frame")
	
	p2_healthbar.max_value = 1500
	p2_health_bar_trail.max_value = 1500
	p2_health_bar_trail.value = 1500
	$"%P2FeintDisplay".fighter = p2
	p2_ghost_health_bar_trail.max_value = 1500
	p2_ghost_health_bar_trail.value = 1500
	mh_p2_ghost_health_bar_trail.max_value = 1500
	mh_p2_ghost_health_bar_trail.value = 1500
	
	p2_ghost_health_bar.max_value = 1500
	mh_p2_ghost_health_bar.max_value = 1500
	

	
	p2_super_meter.max_value = p2.MAX_SUPER_METER
	p2_burst_meter.fighter = p2

	if Network.multiplayer_active and not SteamLobby.SPECTATING:
		if (Network.game.player_names.has(p2index)):
			$"%P2Username".text = Network.game.player_names[p2index]
	elif not Network.multiplayer_active:
		$"%P2Username".text = Network.player_character_names[p2index]
	elif game.match_data.has("user_data"):
		if game.match_data.user_data.has("p"+str(p2index)):
			$"%P2Username".text = Network.game.player_names[p2index]
	
	$"%P2ShowStyle".set_pressed_no_signal(p2.is_style_active == true)


	p2_health_label.text = "%d/%d" % [p2.hp, p2.MAX_HEALTH]

	print("initp2->MAX_HEALTH=%d" % p2.MAX_HEALTH)

func reinit(p1index:int, p2index:int):
	initp1(p1index)
	initp2(p2index)

# Need to store HP trails here since values from UI are unreliable
var ghost_hp_trails = {}
var hp_trails = {}

func _physics_process(_delta):
	if is_instance_valid(game):
		# Process all HP trails here first
		for index in game.players.keys():
			var plr = game.players[index]
			var trail = 0 if not index in hp_trails else hp_trails[index]
			if plr.trail_hp < trail:
				hp_trails[index] -= TRAIL_DRAIN_RATE
				if hp_trails[index] < plr.trail_hp:
					hp_trails[index] = plr.trail_hp
			else:
				hp_trails[index] = plr.trail_hp
		
		mh_p1_healthbar.value = max(p1.hp, 0)
		mh_p2_healthbar.value = max(p2.hp, 0)
		mh_p1_health_bar_trail.value = hp_trails[p1index]
		mh_p2_health_bar_trail.value = hp_trails[p2index]
		
		p1_health_label.text = "%d/%d" % [p1.hp, p1.MAX_HEALTH]
		p2_health_label.text = "%d/%d" % [p2.hp, p2.MAX_HEALTH]
		if is_instance_valid(game.ghost_game):
			# Process all ghost HP trails here first
			for index in game.players.keys():
				var plr = game.ghost_game.players[index]
				if plr.trail_hp < ghost_hp_trails[index]:
					ghost_hp_trails[index] -= TRAIL_DRAIN_RATE
					if ghost_hp_trails[index] < plr.trail_hp:
						ghost_hp_trails[index] = plr.trail_hp
				else:
					ghost_hp_trails[index] = plr.trail_hp
			
			# Now update ghost HP hud accordingly
			var p1_ghost = game.ghost_game.players[p1index]
			var p2_ghost = game.ghost_game.players[p2index]
			mh_p1_ghost_health_bar.value = max(p1_ghost.hp, 0)
			mh_p2_ghost_health_bar.value = max(p2_ghost.hp, 0)
			mh_p1_ghost_health_bar_trail.value = ghost_hp_trails[p1index]
			mh_p2_ghost_health_bar_trail.value = ghost_hp_trails[p2index]
		else:
			for index in game.players.keys():
				ghost_hp_trails[index] = 0
			mh_p1_ghost_health_bar.value = 0
			mh_p2_ghost_health_bar.value = 0
			mh_p1_ghost_health_bar_trail.value = 0
			mh_p2_ghost_health_bar_trail.value = 0
		
		$"%P1SuperTexture".visible = game.player_supers[p1index]
		$"%P2SuperTexture".visible = game.player_supers[p2index]
