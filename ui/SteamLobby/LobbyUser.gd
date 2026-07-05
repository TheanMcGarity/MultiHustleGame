extends Panel

signal challenge_pressed()
signal replay_challenge_pressed(member)
signal avatar_loaded()

#const MEMBER_MIN_SIZE = 30
#const OWNER_MIN_SIZE = 44
onready var owner_actions = $OwnerActions

var main_ui

var member

func _ready():
	Steam.connect("avatar_loaded", self, "_loaded_Avatar")
	$"%ChallengeButton".connect("pressed", self, "on_challenge_pressed")
	$"%ReplayButton".connect("pressed", self, "on_replay_challenge_pressed")

func init(member):
#	if $"%AvatarIcon".texture == null:
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, member.steam_id)
	$"%Username".text = member.steam_name
	self.member = member
	$"%OwnerIcon".visible = false
	if Steam.getLobbyOwner(SteamLobby.LOBBY_ID) == member.steam_id:
		$"%OwnerIcon".visible = true
	var status = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, member.steam_id, "status")
	if status != "idle":
		$"%ChallengeButton".disabled = true
		$"%ChallengeButton".text = status
		if status == "fighting":
			$"%ChallengeButton".text = "game in-progress"

	show_if_lobby_owner($"%ChallengeButton")
	show_if_lobby_owner($"%ReplayButton")

	
#	var lobby_owner = SteamLobby.am_i_lobby_owner()
#	rect_min_size.y = MEMBER_MIN_SIZE if !lobby_owner else OWNER_MIN_SIZE
#	owner_actions.visible = lobby_owner
func show_if_lobby_owner(button):
	button.disabled = true
	button.hide()
	if Steam.getLobbyOwner(SteamLobby.LOBBY_ID) == member.steam_id:
		button.show()
	if Steam.getLobbyOwner(SteamLobby.LOBBY_ID) == SteamHustle.STEAM_ID:
		button.disabled = false

func update_avatar():
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, member.steam_id)

signal start_game_pressed()

func on_challenge_pressed():
	emit_signal("start_game_pressed")
	SteamLobby.host_game_vs_all(main_ui.get_matches_list_children())

func on_replay_challenge_pressed():
	emit_signal("replay_challenge_pressed", member)

func _loaded_Avatar(id:int, size:int, buffer:PoolByteArray)->void :
	if id != member.steam_id:
		return 
		
	var AVATAR = Image.new()
	var AVATAR_TEXTURE:ImageTexture = ImageTexture.new()
	AVATAR.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)
		
	AVATAR_TEXTURE.create_from_image(AVATAR)
		
	$"%AvatarIcon".set_texture(AVATAR_TEXTURE)
	emit_signal("avatar_loaded")
