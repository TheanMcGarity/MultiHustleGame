extends VBoxContainer

onready var debug_1 = $"%P1ActionButtonsContainer"
onready var debug_2 = $"%ActionButtons"
onready var ui_layer = $"%UILayer"
onready var active_player_info_container = $"%ActivePlayerInfoContainer"
onready var main = $"../../.."

var debug_1_y := 0
var debug_2_y := 0

func _process(delta):
	var dbg_1_y = $"%P1ActionButtonsContainer".rect_position.y
	var dbg_2_y = $"%ActionButtons".rect_position.y
	if (debug_1_y != dbg_1_y):
		print("DEBUG1 - %d - %d" % [dbg_1_y, debug_1_y])
	if (debug_2_y != dbg_2_y):
		print("DEBUG2 - %d - %d" % [dbg_2_y, debug_2_y])
	debug_1_y = dbg_1_y
	debug_2_y = dbg_2_y

func _ready():
	$"%P1ActionButtons".connect("visibility_changed", self, "_on_action_buttons_visibility_changed", [], CONNECT_DEFERRED)
	$"%P2ActionButtons".connect("visibility_changed", self, "_on_action_buttons_visibility_changed", [], CONNECT_DEFERRED)
	$"%P1ActionButtons".opposite_buttons = $"%P2ActionButtons"
	$"%P2ActionButtons".opposite_buttons = $"%P1ActionButtons"
	$"%ActivePlayerSuperContainer".hide()
	main.connect("game_setup", self, "_on_action_buttons_visibility_changed")

func _on_action_buttons_visibility_changed():
	var p1_info_scene = ui_layer.p1_info_scene
	var p2_info_scene = ui_layer.p2_info_scene

	if !$"%P1ActionButtons".visible and !$"%P2ActionButtons".visible:
		$"%OptionsBarContainer".hide()
		$"%PredictionSettingsOpenButton".hide()

	else:
		$"%OptionsBar".show()
		if !$"%OptionsBarContainer".visible:
			$"%PredictionSettingsOpenButton".show()
		else:
			$"%PredictionSettingsOpenButton".hide()
#		$"%ActivePlayerSuperContainer".show()
	
	if is_instance_valid(p1_info_scene):
		p1_info_scene.get_parent().remove_child(p1_info_scene)
		p2_info_scene.get_parent().remove_child(p2_info_scene)

	if ReplayManager.playback or ReplayManager.play_full:
		$"%P1InfoContainer".add_child(p1_info_scene)
		$"%P1InfoContainer".move_child(p1_info_scene, 0)
		$"%P2InfoContainer".add_child(p2_info_scene)
		$"%P2InfoContainer".move_child(p2_info_scene, 0)
		$"%ActivePlayerSuperContainer".hide()
		$"%P1SuperContainer".show()
		$"%P2SuperContainer".show()
		$"%ActivePlayer".hide()
		if is_instance_valid(p1_info_scene):
			p1_info_scene.on_position_changed(false)
			p2_info_scene.on_position_changed(false)
	else:
		$"%P1SuperContainer".hide()
		$"%P2SuperContainer".hide()
		$"%ActivePlayer".show()
		$"%ActivePlayerSuperContainer".show()
		if is_instance_valid(p1_info_scene):
			active_player_info_container.add_child(p1_info_scene)
			active_player_info_container.add_child(p2_info_scene)
			p1_info_scene.on_position_changed(true)
			p2_info_scene.on_position_changed(true)
