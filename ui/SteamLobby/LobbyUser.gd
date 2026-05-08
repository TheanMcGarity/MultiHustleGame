extends Panel

signal challenge_pressed()
signal replay_challenge_pressed(member)
signal avatar_loaded()

#const MEMBER_MIN_SIZE = 30
#const OWNER_MIN_SIZE = 44
onready var owner_actions = $OwnerActions

var member

var _owner_popup: PopupMenu

func _ready():
	Steam.connect("avatar_loaded", self, "_loaded_Avatar")
	$"%ChallengeButton".connect("pressed", self, "on_challenge_pressed")
	$"%ReplayChallengeButton".connect("pressed", self, "on_replay_challenge_pressed")
	# Make the avatar clickable so the lobby owner can right- or left-click
	# another user's portrait to surface ownership transfer.
	$"%AvatarIcon".connect("gui_input", self, "_on_avatar_gui_input")
	$"%AvatarIcon".mouse_filter = Control.MOUSE_FILTER_STOP

func init(member):
#	if $"%AvatarIcon".texture == null:
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, member.steam_id)
	$"%Username".text = member.steam_name
	self.member = member
	$"%OwnerIcon".visible = false
	$"%ChallengeButton".hide()
	$"%ReplayChallengeButton".hide()
	if SteamHustle.STEAM_ID != member.steam_id:
		$"%ChallengeButton".show()
		if SteamLobby.LOBBY_REPLAY_CHALLENGE_ENABLED:
			$"%ReplayChallengeButton".show()
		else:
			$"%ChallengeButton".margin_right = 92
	if Steam.getLobbyOwner(SteamLobby.LOBBY_ID) == member.steam_id:
		$"%OwnerIcon".visible = true
	var status = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, member.steam_id, "status")
	if status != "idle":
		$"%ChallengeButton".disabled = true
		$"%ReplayChallengeButton".hide()
		$"%ChallengeButton".margin_right = 92
		$"%ChallengeButton".text = status
		if status == "fighting":
			$"%ChallengeButton".text = "fighting " + Steam.getFriendPersonaName(int(Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, member.steam_id, "opponent_id")))
		elif status == "spectating":
			var spectating_id = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, member.steam_id, "spectating_id")
			if spectating_id != "":
				$"%ChallengeButton".text = "spectating " + Steam.getFriendPersonaName(int(spectating_id))

#	var lobby_owner = SteamLobby.am_i_lobby_owner()
#	rect_min_size.y = MEMBER_MIN_SIZE if !lobby_owner else OWNER_MIN_SIZE
#	owner_actions.visible = lobby_owner

func update_avatar():
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, member.steam_id)

func on_challenge_pressed():
	if member:
		emit_signal("challenge_pressed")
		SteamLobby.challenge_user(member)

func on_replay_challenge_pressed():
	if member:
		emit_signal("replay_challenge_pressed", member)

func _loaded_Avatar(id: int, size: int, buffer: PoolByteArray) -> void:
	if id != member.steam_id:
		return
	print("Avatar for user: "+str(id))
	print("Size: "+str(size))
	# Create the image and texture for loading
	var AVATAR = Image.new()
	var AVATAR_TEXTURE: ImageTexture = ImageTexture.new()
	AVATAR.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)
	# Apply it to the texture
	AVATAR_TEXTURE.create_from_image(AVATAR)
	# Set it
	$"%AvatarIcon".set_texture(AVATAR_TEXTURE)
	emit_signal("avatar_loaded")

func _on_avatar_gui_input(event: InputEvent):
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != BUTTON_LEFT:
		return
	if member == null:
		return
	# Only the lobby owner can hand off ownership, and only to a *different*
	# user.
	if Steam.getLobbyOwner(SteamLobby.LOBBY_ID) != SteamHustle.STEAM_ID:
		return
	if member.steam_id == SteamHustle.STEAM_ID:
		return
	_show_owner_popup()

func _show_owner_popup():
	if _owner_popup == null:
		_owner_popup = PopupMenu.new()
		_owner_popup.add_item("Transfer Ownership", 0)
		_owner_popup.connect("id_pressed", self, "_on_owner_popup_id_pressed")
		add_child(_owner_popup)
	var avatar_rect = $"%AvatarIcon".get_global_rect()
	_owner_popup.popup(Rect2(avatar_rect.position + Vector2(0, avatar_rect.size.y), Vector2(0, 0)))

func _on_owner_popup_id_pressed(id: int):
	if id == 0 and member != null:
		Steam.setLobbyOwner(SteamLobby.LOBBY_ID, member.steam_id)
