extends Panel

signal spectate_requested(player)

const SOME_PEOPLE_SPRITE = preload("res://ui/SteamLobby/spectator_people.png")
const MANY_PEOPLE_SPRITE = preload("res://ui/SteamLobby/spectator_people_multiple.png")

var p1
var p2

func init(member1, member2):
	$"%P1Username".text = member1.steam_name
	$"%P2Username".text = member2.steam_name
	_apply_name_color($"%P1Username", member1.steam_id)
	_apply_name_color($"%P2Username", member2.steam_id)

	$"%P1Character".text = member1.character
	$"%P2Character".text = member2.character
	p1 = member1
	p2 = member2
	
#	var rng = BetterRng.new()
#	rng.randomize()
#	$"%HealthP1".value = rng.randi_range(0, 100)
#	$"%HealthP2".value = rng.randi_range(0, 100)
	print($"%HealthP1".value)
	
	_refresh_spectator_count()
	_refresh_health()
# Pull live hp percents from each fighter's lobby member data and apply to
# HealthP1 / HealthP2. min_value is -1 on both bars (so 0% still shows ~1
# pixel) — keep it that way. If either side isn't publishing hp data,
# treat the match as having no health info and hide both bars together
# so they don't go visually asymmetric.
func _refresh_health():
	if p1 == null or p2 == null or SteamLobby.LOBBY_ID == 0:
#		$"%HealthP1".hide()
#		$"%HealthP2".hide()
		return
	var p1_str = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, p1.steam_id, "hp_pct")
	var p2_str = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, p2.steam_id, "hp_pct")
	if p1_str == "" or p2_str == "":
#		$"%HealthP1".hide()
#		$"%HealthP2".hide()
		return
	$"%HealthP1".show()
	$"%HealthP2".show()
	$"%HealthP1".value = int(p1_str)
	$"%HealthP2".value = int(p2_str)

func _apply_name_color(label, steam_id):
	var custom = Global.get_remote_name_color(steam_id)
	if custom != null:
		label.add_color_override("font_color", custom)
	else:
		label.remove_color_override("font_color")

func _ready():
	$"%SpectateButton".connect("pressed", self, "_on_spectate_button_pressed")
	SteamLobby.connect("lobby_data_update", self, "_on_lobby_data_update")

func _on_lobby_data_update(_a=null, _b=null, _c=null):
	_refresh_spectator_count()
	_refresh_health()

func _refresh_spectator_count():
	if p1 == null or p2 == null or SteamLobby.LOBBY_ID == 0:
		return
	# Read live from Steam — LobbyMember snapshots status/spectating_id once at
	# _init, so it'd go stale as people start/stop spectating without a full
	# member list rebuild.
	var count = 0
	var num_members = Steam.getNumLobbyMembers(SteamLobby.LOBBY_ID)
	for i in range(num_members):
		var steam_id = Steam.getLobbyMemberByIndex(SteamLobby.LOBBY_ID, i)
		if Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "status") != "spectating":
			continue
		var spec_str = Steam.getLobbyMemberData(SteamLobby.LOBBY_ID, steam_id, "spectating_id")
		if spec_str == "":
			continue
		var spec_id = int(spec_str)
		if spec_id == p1.steam_id or spec_id == p2.steam_id:
			count += 1
	
	var many = count >= 4
	$"%SpectatorCount".modulate = Color("ffd519" if many else "94e4ff") if count > 0 else Color("6e707f")
#	$"%SpectatorCount".modulate.a = 1.0 if count > 0 else 0.5
	$"%SpectatorCount".text = str(count)
#	$"%SpectateButton".text = "spectate" if count == 0 else " spectate"
#	$"%SpectateButton".rect_size.x = 54
#	$"%SpectateButton".rect_position.x = 16 if count == 0 else 9
#	$"%SpectateButton".align = Button.ALIGN_CENTER if count == 0 else Button.ALIGN_LEFT
	$"%SpectatorSprite".texture = MANY_PEOPLE_SPRITE if many else SOME_PEOPLE_SPRITE
	

func _on_spectate_button_pressed():
	randomize()
	emit_signal("spectate_requested", p1 if randi() % 2 == 0 else p2)
