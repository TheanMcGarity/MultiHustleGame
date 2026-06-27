extends Panel

signal spectate_requested(player)

onready var timescale:SpinBox = $"%Timescale"
onready var team:OptionButton = $"%ForcedTeam"
onready var handicap:SpinBox = $"%HandicapMultiplier"

var id

func init(id):
	self.id = id
	$"%P1Username".text = Steam.getFriendPersonaName(id)
	if SteamHustle.STEAM_ID != SteamLobby.LOBBY_OWNER:
		team.disabled = true
		handicap.editable = false
		timescale.editable = false
