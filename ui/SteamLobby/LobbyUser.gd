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
	# Apply any user's published Personalization name color (broadcast via
	# Steam lobby member data) so every row tints with its owner's color.
	var custom = Global.get_remote_name_color(member.steam_id)
	if custom != null:
		$"%Username".add_color_override("font_color", custom)
	else:
		$"%Username".remove_color_override("font_color")
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
	_show_owner_popup()

const _ACTION_PROFILE = 0
const _ACTION_MUTE = 1
const _ACTION_BLOCK = 2
const _ACTION_TRANSFER = 3
const _ACTION_SET_BUSY = 4

func _show_owner_popup():
	if _owner_popup == null:
		_owner_popup = PopupMenu.new()
		_owner_popup.connect("id_pressed", self, "_on_owner_popup_id_pressed")
		add_child(_owner_popup)
	# Rebuild items each open — labels flip on mute/block/busy state, and
	# the Transfer Ownership entry is only available to the lobby owner.
	_owner_popup.clear()
	if member.steam_id == SteamHustle.STEAM_ID:
		# Self-row: only the busy-mode toggle. Profile/mute/block/transfer
		# don't make sense pointed at yourself.
		_owner_popup.add_item(
			"Set Status: Idle" if Global.lobby_busy_mode else "Set Status: Busy",
			_ACTION_SET_BUSY
		)
	else:
		_owner_popup.add_item("Open Steam Profile", _ACTION_PROFILE)
		_owner_popup.add_item("Unmute" if SteamLobby.is_muted(member.steam_id) else "Mute", _ACTION_MUTE)
		_owner_popup.add_item("Unblock" if SteamLobby.is_blocked(member.steam_id) else "Block", _ACTION_BLOCK)
		if Steam.getLobbyOwner(SteamLobby.LOBBY_ID) == SteamHustle.STEAM_ID:
			_owner_popup.add_separator()
			_owner_popup.add_item("Transfer Ownership", _ACTION_TRANSFER)
	# Set position via rect_global_position and call popup() with no args —
	# Popup.popup(Rect2) in 3.5 forces set_size(bounds.size), so passing a 0×0
	# rect collapses the menu instead of letting it auto-size to its items.
	var avatar_rect = $"%AvatarIcon".get_global_rect()
	_owner_popup.rect_global_position = avatar_rect.position + Vector2(0, avatar_rect.size.y)
	_owner_popup.popup()

func _on_owner_popup_id_pressed(id: int):
	if member == null:
		return
	match id:
		_ACTION_PROFILE:
			Steam.activateGameOverlayToUser("steamid", member.steam_id)
		_ACTION_MUTE:
			SteamLobby.set_muted(member.steam_id, not SteamLobby.is_muted(member.steam_id))
		_ACTION_BLOCK:
			SteamLobby.set_blocked(member.steam_id, not SteamLobby.is_blocked(member.steam_id))
		_ACTION_TRANSFER:
			Steam.setLobbyOwner(SteamLobby.LOBBY_ID, member.steam_id)
		_ACTION_SET_BUSY:
			Global.lobby_busy_mode = not Global.lobby_busy_mode
			Global.save_options()
			SteamLobby.apply_busy_mode()
