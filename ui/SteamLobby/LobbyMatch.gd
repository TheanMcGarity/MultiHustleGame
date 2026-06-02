extends Panel

signal spectate_requested(player)

onready var team:OptionButton = $"%ForcedTeam"
onready var handicap:SpinBox = $"%HandicapMultiplier"

func init(id):
	$"%P1Username".text = Steam.getFriendPersonaName(id)
	if SteamHustle.STEAM_ID != SteamLobby.LOBBY_OWNER:
		team.disabled = true
		handicap.disabled = true
