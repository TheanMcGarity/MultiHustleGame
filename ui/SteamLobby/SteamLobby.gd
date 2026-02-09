extends "res://ui/SteamLobby/UiSteamLobbyOld.gd"

onready var loading_mods_rect = $"%LoadingModsRect"
onready var loading_lobby_rect = $"%LoadingLobbyRect"
onready var match_list = $"%MatchList"

var _Global = Network
var errorMsg = Label.new()

func _ready():
	add_child(errorMsg)
	errorMsg.set_position(Vector2(0, 345))
	errorMsg.text = ""
	_Global.steam_errorMsg = ""

func _process(delta):
	if !is_visible_in_tree():
		return

	errorMsg.text = _Global.steam_errorMsg
		

	var css = _Global.css_instance
func init():
	if SteamLobby.REMATCHING_ID != 0:
		Network.log_to_file("MultiHustle doesn't support rematch button yet")
		SteamLobby.REMATCHING_ID = 0
	.init()
	
	for child in $"%MatchList".get_children():
		child.free()

func _on_retrieved_lobby_members(members):
	._on_retrieved_lobby_members(members)
	var script = load("res://ui/SteamLobby/LobbyUser.gd")
	for child in $"%UserList".get_children():
		var member = child.member
		child.disconnect("challenge_pressed", self, "_on_user_challenge_pressed")
		#child.set_script(script)
		child.init(member)
