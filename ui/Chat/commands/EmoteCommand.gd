extends Command

export var online := false

func execute(args: Array):
	var player_id 
	var emote 
	
	if is_instance_valid(Global.current_game):
		var player = Global.current_game.get_player(player_id)
		if player:
			player.emote(emote)
			return true
