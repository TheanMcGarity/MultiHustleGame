extends BaseObj

class_name DistWallObj

var players = []

var player_particles = {}

export(int) var warning_distance = 80
export(int) var glitch_max_distance = 75
export(int) var damage_distance = 90

const PARTICLE_SCENE = preload("res://fx/DistanceWallHoverParticle.tscn")

func update_ui(player, glitch_percent):
	var p1 = get_tree().get_root().get_node("/root/Main/HudLayer/HudLayer/VBoxContainer/TopBar/P1Info_IMG")
	p1.per_player_glitch_val[player.id] = p1.glitch_max * glitch_percent
	var p2 = get_tree().get_root().get_node("/root/Main/HudLayer/HudLayer/VBoxContainer/TopBar/P2Info_IMG")
	p2.per_player_glitch_val[player.id] = p2.glitch_max * glitch_percent

func init(pos = null):
	.init(pos)
	
	var game = get_game()

	is_ghost = game.is_ghost
	for player in game.players.values():
		players.append(player)
		
		var particle = PARTICLE_SCENE.instance()
		player_particles[player.id] = particle
	
	for particle in player_particles.values():
		$Flip/Particles.add_child(particle)
		particle.modulate.a = 0
		particle.start()
		particle.show()

func tick_after():
	.tick_after()
	for player in players:
		tick_per(player)
		var effect_result = modify_player_effects(player)
		update_ui(player, effect_result.glitch)
		damage(player)
	pass

func calc_alpha(wall_x, player_x, dir):
	var dist_to_wall = ((wall_x + warning_distance) - player_x) if dir == 1 else (player_x - (wall_x - warning_distance))
	
	if dist_to_wall < 0:
		return 255 
	
	var percent = 1.0 - (float(dist_to_wall) / float(warning_distance))
	
	percent = 1 - clamp(percent, 0.0, 1.0)
	
	return int(percent * 255)

func tick_per(player):
	var particle:Node2D = player_particles[player.id]
	var facing = get_facing_int() * -1
	var pos = player.get_pos()
	var wall_x = get_pos().x
	
	if ((pos.x > wall_x - warning_distance and facing == 1) or (facing == -1 and pos.x < wall_x + warning_distance)):
		particle.modulate.a8 = calc_alpha(wall_x, pos.x, facing)
		pass
	else:
		particle.modulate.a8 = 0
	
	particle.global_position = Vector2(wall_x, pos.y)
	pass

func modify_player_effects(player):
	if is_ghost:
		 return
	# duplicate code
	var dir = get_facing_int()# * -1
	var player_x = player.get_pos().x
	var wall_x = get_pos().x
	
	#if ((player_x > wall_x + glitch_max_distance and dir == 1) or (dir == -1 and player_x < wall_x - glitch_max_distance)):
	#	return
	var dist_to_wall = ((wall_x - glitch_max_distance) - player_x) if dir == 1 else (player_x - (wall_x + glitch_max_distance))
	
	if dist_to_wall < 0:
		player.oob_glitch_effect = 0.0
		return {
			"glitch": 0
		}
	
	var percent = (float(dist_to_wall) / float(glitch_max_distance))
	
	percent = clamp(percent, 0.0, 1.0)
	var glitch_max = player.oob_glitch_max
	player.oob_glitch_effect = glitch_max * percent
	return {
		"glitch": percent
	}

func damage(player:Fighter):
	if (player.hitlag_ticks > 0):
		return
	
	var dir = get_facing_int()# * -1
	var player_x = player.get_pos().x
	var wall_x = get_pos().x
	
	if ((player_x > wall_x - damage_distance and dir == 1) or (dir == -1 and player_x < wall_x + damage_distance)):
		return

	player.take_damage(1)
