extends "res://ui/SteamLobby/SteamLobbyList.gd"


func _ready():
	$"%LobbySize2".connect("value_changed", self, "_on_LobbySize2_value_changed")


func _on_LobbySize2_value_changed(value):
	$"%LobbySizeLabelCount2".text = str(value)
	pass # Replace with function body.
	
	
func _on_create_lobby_button_pressed():
	var availability
	if $"%PublicButton".pressed:
		availability = SteamLobby.LOBBY_AVAILABILITY.PUBLIC
	else:
		availability = SteamLobby.LOBBY_AVAILABILITY.FRIENDS
	SteamLobby.LOBBY_NAME = get_lobby_name()
	SteamLobby.LOBBY_CHARLOADER_ENABLED = charloader_button.pressed and ModLoader.active
	SteamLobby.create_lobby(availability, $"%LobbySize".value * $"%LobbySize2".value)
