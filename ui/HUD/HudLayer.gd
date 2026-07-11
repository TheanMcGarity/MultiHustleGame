extends CanvasLayer

# Same color-replacement shader the character sprite uses, so the HUD
# portrait can be recolored with a player's style palette.
const CHAR_SHADER = preload("res://characters/BaseChar.gdshader")

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
onready var p1_num_supers_active = $"%ActiveP1NumSupers"
onready var p2_num_supers_active = $"%ActiveP2NumSupers"

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

onready var reload_ui_button = $"%UISoftlockButton"


const TRAIL_DRAIN_RATE = 25

var p1: Fighter
var p2: Fighter

var super_started = false

var p1_effects = []
var p2_effects = []

var p1_prev_super = 0
var p2_prev_super = 0

# Last hp_pct we wrote to Steam lobby member data for the local fighter,
# and the os-msec timestamp it was written at. Together they cap writes
# to "when the integer percent changes AND at least HP_PUBLISH_MIN_INTERVAL_MS
# has elapsed" so a heavy combo that flips several percents per frame
# doesn't spam lobby_data_update on every client.
var _last_published_hp_pct := -1
var _last_hp_publish_msec := 0
const HP_PUBLISH_MIN_INTERVAL_MS = 3000

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
	
	p1_super_meter.value = p1.super_meter
	p2_super_meter.value = p2.super_meter
	active_p1_super_meter.value = p1.super_meter
	active_p2_super_meter.value = p2.super_meter
	
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
	# Personalization name-color: in Steam matches, each side's color comes
	# from that side's published lobby member data so both fighters render
	# in their own picked color (including for spectators). In legacy MP /
	# SP / replay there's no broadcast channel, so just color the local
	# user's side from Global.
	$"%P1Username".remove_color_override("font_color")
	$"%P2Username".remove_color_override("font_color")
	# Saved replays bring their own color snapshot in user_data — that's the
	# source of truth for replay playback (live lobby data may not exist
	# anymore). Prefer it over the live lookup, fall back to live for matches
	# where it wasn't recorded (older replays).
	var ud = game.match_data.get("user_data", {}) if game.match_data else {}
	var p1_color = null
	var p2_color = null
	if ud.get("p1_color") is String and ud.p1_color != "":
		p1_color = Color("#" + ud.p1_color)
	if ud.get("p2_color") is String and ud.p2_color != "":
		p2_color = Color("#" + ud.p2_color)
	if p1_color == null or p2_color == null:
		if Network.steam:
			var p1_steam = SteamLobby.OPPONENT_IDS[1]
			var p2_steam = SteamLobby.OPPONENT_IDS[2]
			if p1_color == null and p1_steam != 0:
				p1_color = Global.get_remote_name_color(p1_steam)
			if p2_color == null and p2_steam != 0:
				p2_color = Global.get_remote_name_color(p2_steam)
		elif !SteamLobby.SPECTATING and Global.has_name_color():
			# Network.player_id defaults to 2 and is only set in actual MP
			# setup paths. Treat non-multiplayer as "you are P1" so vs-CPU
			# shows the user's color on their character.
			var my_side = Network.player_id if Network.multiplayer_active else 1
			if my_side == 1 and p1_color == null:
				p1_color = Global.get_name_color()
			elif my_side == 2 and p2_color == null:
				p2_color = Global.get_name_color()
	if p1_color != null:
		$"%P1Username".add_color_override("font_color", p1_color)
	if p2_color != null:
		$"%P2Username".add_color_override("font_color", p2_color)
	
	$"%P1ShowStyle".set_pressed_no_signal(true)
	$"%P2ShowStyle".set_pressed_no_signal(true)
	refresh_portrait_style(1)
	refresh_portrait_style(2)


	game.connect("game_won", self, "on_game_won")
	
	
	# Reset the portrait colors so that replaying doesnt show the incorrect thing
	$"%P1Portrait".modulate = game.MultiHustle_get_color_by_index(1)
	$"%P2Portrait".self_modulate = game.MultiHustle_get_color_by_index(2)

	game.connect("team_game_won", self, "on_team_won")

# Recolor a player's HUD portrait with their style's palette (colors only —
# no auras / outline effects beyond what the palette defines). Mirrors the
# CSS CharacterDisplay path: the source replacement colors come from the
# character itself, the target colors from the applied style. The portrait
# always runs through the color-replacement shader (no modulate tint) — when
# the style is off / null / disabled it falls back to the engine's default
# per-player body color (P1_COLOR / P2_COLOR) at the shader level.
func refresh_portrait_style(player_id):
	if not is_instance_valid(game):
		return
	var portrait = $"%P1Portrait" if player_id == 1 else $"%P2Portrait"
	var show_btn = $"%P1ShowStyle" if player_id == 1 else $"%P2ShowStyle"
	var player = game.get_player(Network.main.ui_layer.GetRealID(player_id))
	if player == null:
		return
	# All coloring happens in the shader now — clear any modulate tint baked
	# into the scene so it doesn't double up on the shader color.
	portrait.modulate = Color.white
	portrait.self_modulate = Color.white
	var mat = portrait.material
	if not (mat is ShaderMaterial):
		mat = ShaderMaterial.new()
		mat.shader = CHAR_SHADER
		portrait.material = mat
	# Source magenta keys to replace come from the character; reset the base
	# params before applying either the style or the default color.
	mat.set_shader_param("extra_replace_color_1", player.extra_color_1)
	mat.set_shader_param("extra_replace_color_2", player.extra_color_2)
	mat.set_shader_param("use_outline", false)
	mat.set_shader_param("use_extra_color_1", false)
	mat.set_shader_param("use_extra_color_2", false)
	var style = player.applied_style
	if show_btn.pressed and style != null and Global.enable_custom_colors:
		mat.set_shader_param("color", Color.white)
		Custom.apply_style_to_material(style, mat, true)
	else:
		# Default per-player body color (same constants the character sprite
		# uses in reset_color), applied at the shader level instead of via a
		# modulate tint.
		
		mat.set_shader_param("color", Global.current_game.MultiHustle_get_color_by_index(player_id))

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

# Copy the ghost's "Ready in Xf" / "Interrupt in Xf" / "Hit @ Xf" floating
# labels into fixed HUD spots, and (independently) hide the same text on the
# characters themselves via modulate so it doesn't obscure the prediction.
# Both are user-toggleable; default is HUD on, character labels on.
func _sync_next_turn_info(p1_ghost, p2_ghost):
	if Global.show_next_turn_info_hud:
		_mirror_next_turn_label($"%P1NextTurnReadyLabel", p1_ghost.actionable_label)
		_mirror_next_turn_label($"%P1NextTurnHitLabel", p1_ghost.hit_frame_label)
		_mirror_next_turn_label($"%P2NextTurnReadyLabel", p2_ghost.actionable_label)
		_mirror_next_turn_label($"%P2NextTurnHitLabel", p2_ghost.hit_frame_label)
	else:
		$"%P1NextTurnReadyLabel".text = ""
		$"%P1NextTurnHitLabel".text = ""
		$"%P2NextTurnReadyLabel".text = ""
		$"%P2NextTurnHitLabel".text = ""
	# Hide on characters via modulate (not .visible) so ghost_tick's visibility
	# gating in game.gd stays untouched — the label still counts as "shown",
	# just renders at alpha 0.
	var char_alpha = 1.0 if Global.show_next_turn_info_on_chars else 0.0
	p1_ghost.actionable_label.modulate.a = char_alpha
	p1_ghost.hit_frame_label.modulate.a = char_alpha
	p2_ghost.actionable_label.modulate.a = char_alpha
	p2_ghost.hit_frame_label.modulate.a = char_alpha

func _mirror_next_turn_label(hud_label, char_label):
	if not is_instance_valid(char_label) or not char_label.visible:
		hud_label.text = ""
		return
	# Char labels use "Ready\nin Xf" multi-line; flatten for the narrow HUD spot.
	hud_label.text = char_label.text.replace("\n", " ")

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
	
	reload_ui_button.connect("pressed", self, "_on_UISoftlockButton_pressed")
	
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

	health_labels = load("res://multihustle/ui/HUD/HPNumbers.tscn").instance()
	p1_health_label = health_labels.get_node("P1HealthLabel")
	p2_health_label = health_labels.get_node("P2HealthLabel")
	if not Global.show_health_numbers:
		p1_health_label.hide()
		p2_health_label.hide()
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
	if (Network.multiplayer_active):
		var color
		var steam_id = SteamLobby.OPPONENT_IDS[p2index]
		color = Global.get_remote_name_color(steam_id)
		if color != null:
			$"%P1Username".add_color_override("font_color", color)


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
	if (Network.multiplayer_active):
		var color
		var steam_id = SteamLobby.OPPONENT_IDS[p2index]
		color = Global.get_remote_name_color(steam_id)
		if color != null:
			$"%P2Username".add_color_override("font_color", color)

func reinit(p1index:int, p2index:int):
	initp1(p1index)
	initp2(p2index)

# Need to store HP trails here since values from UI are unreliable
var ghost_hp_trails = {}
var hp_trails = {}

func _physics_process(_delta):
	if is_instance_valid(game):
		$"%Timer".text = str(game.get_ticks_left())
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
		
		p1_super_meter.value = p1.super_meter
		p2_super_meter.value = p2.super_meter
		active_p1_super_meter.value = p1.super_meter
		active_p2_super_meter.value = p2.super_meter
		mh_p1_healthbar.value = max(p1.hp, 0)
		mh_p2_healthbar.value = max(p2.hp, 0)
		mh_p1_health_bar_trail.value = hp_trails[p1index]
		mh_p2_health_bar_trail.value = hp_trails[p2index]
		
		p1_healthbar.max_value = p1.MAX_HEALTH
		p2_healthbar.max_value = p2.MAX_HEALTH
		
		mh_p1_healthbar.max_value = p1.MAX_HEALTH
		mh_p2_healthbar.max_value = p2.MAX_HEALTH
		
		
		
		p1_num_supers.texture.current_frame = clamp(p1.supers_available, 0, 9)
		p2_num_supers.texture.current_frame = clamp(p2.supers_available, 0, 9)
		p1_num_supers_active.texture.current_frame = clamp(p1.supers_available, 0, 9)
		p2_num_supers_active.texture.current_frame = clamp(p2.supers_available, 0, 9)
		
		p1_health_label.text = "%d/%d" % [p1.hp, p1.MAX_HEALTH]
		p2_health_label.text = "%d/%d" % [p2.hp, p2.MAX_HEALTH]
		
		reload_ui_button.visible = game.reload_ui_allowed and game.game_paused
		
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
			_sync_next_turn_info(p1_ghost, p2_ghost)
		else:
			for index in game.players.keys():
				ghost_hp_trails[index] = 0
			mh_p1_ghost_health_bar.value = 0
			mh_p2_ghost_health_bar.value = 0
			mh_p1_ghost_health_bar_trail.value = 0
			mh_p2_ghost_health_bar_trail.value = 0
		
		#$"%P1SuperTexture".visible = game.player_supers[p1index]
		#$"%P2SuperTexture".visible = game.player_supers[p2index]
		
func _on_UISoftlockButton_pressed():
	Network.main.ui_layer.p1_action_buttons.re_init(Network.main.ui_layer.GetRealID(1))
	Network.main.ui_layer.p2_action_buttons.re_init(Network.main.ui_layer.GetRealID(2))
	initp1(Network.main.ui_layer.GetRealID(1))
	initp2(Network.main.ui_layer.GetRealID(2))
