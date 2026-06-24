extends PlayerExtra

var can_shoot = false
var aerial = false
var grounded = false

onready var sight_button = $"%SightButton"


func _ready():
	Utils.pass_signal_along($"%ShootButton", self, "pressed", "data_changed")
	Utils.pass_signal_along($"%DetonateButton", self, "pressed", "data_changed")
	Utils.pass_signal_along($"%TpButton", self, "pressed", "data_changed")
	Utils.pass_signal_along($"%MilkButton", self, "pressed", "data_changed")
	Utils.pass_signal_along(sight_button, self, "pressed", "data_changed")


func get_extra():
	return {
		"gun_cancel": $"%ShootButton".pressed and $"%ShootButton".visible,
		"detonate": $"%DetonateButton".pressed and $"%DetonateButton".visible,
		"shift": $"%TpButton".pressed and $"%TpButton".visible,
		"drift": $"%MilkButton".pressed and $"%MilkButton".visible,
		"hindsight": sight_button.pressed and sight_button.visible,
		"input_aerial": aerial,
		"input_grounded": grounded,
	}

func show_options():
	$"%ShootButton".hide()
	$"%ShootButton".pressed = false
	$"%DetonateButton".hide()
	$"%DetonateButton".pressed = false
	$"%TpButton".hide()
	$"%TpButton".pressed = false
	sight_button.pressed = false

func reset():
	selected_move = null
	sight_button.pressed = false
	sight_button.disabled = true
	sight_button.hide()
	$"%ShootButton".hide()
	$"%ShootButton".pressed = false
	$"%DetonateButton".hide()
	$"%DetonateButton".pressed = false
	$"%MilkButton".pressed = false
	$"%TpButton".hide()
	$"%MilkButton".hide()
	$"%TpButton".pressed = false
	if fighter.after_image_object != null:
		$"%DetonateButton".show()
		update_tp_button()
	else:
		sight_button.show()
		update_sight_button()
	if "Knockdown" in fighter.current_state().state_name:
		sight_button.hide()

	# Reveal the Draw toggle whenever a draw-cancelable move is in reach, so the
	# player can arm the cancel via the hold button without selecting it first.
	# Hold is the default selection here, so the draw is conditional.
	$"%ShootButton".visible = draw_cancel_available()
	$"%ShootButton".text = "Draw on Block" if fighter.draw_cancel_on_block_only(fighter.current_state(), true) else "Draw"

	block_disable()

func update_tp_button():
		var move = fighter.current_state()
		$"%TpButton".disabled = false
		$"%TpButton".show()
		if fighter.is_grounded() or fighter.air_movements_left > 0:
			$"%TpButton".show()
		else:
			$"%TpButton".hide()
		if (selected_move and selected_move.type == CharacterState.ActionType.Defense):
			$"%TpButton".disabled = true
			$"%TpButton".set_pressed_no_signal(false)
		var obj = fighter.obj_from_name(fighter.after_image_object)
#		if obj:
		if obj:
			$"%MilkButton".visible = obj.is_grounded() != fighter.is_grounded()
			$"%MilkButton".disabled =  fighter.supers_available < fighter.DRIFT_SUPERS
			
		if fighter.after_image_object != null:
			$"%DetonateButton".show()
			$"%DetonateButton".disabled = false
		block_disable()

func block_disable():
	if fighter.current_state().get("disable_aerial_movement"):
		$"%TpButton".set_pressed_no_signal(false)
		$"%TpButton".disabled = true
		$"%DetonateButton".set_pressed_no_signal(false)
		$"%DetonateButton".disabled = true
		$"%MilkButton".set_pressed_no_signal(false)
		$"%MilkButton".disabled = true
		$"%SightButton".set_pressed_no_signal(false)
		$"%SightButton".disabled = true

func update_sight_button():
	sight_button.disabled = !(fighter.supers_available > 0)
	if "Knockdown" in fighter.current_state().state_name:
		sight_button.hide()

# Hold case: holding continues the current move, so a draw is reachable only if
# that move can still produce one from its current tick (an unfired try_shoot, or
# a hitbox that can still land on block). Menu moves aren't relevant here — they
# get the toggle when actually selected.
#
# Once bullet_cancelling has latched true the draw is already committed for this
# move: it fires on block no matter what, and the latch isn't cleared by
# un-toggling (only by firing or the move ending). So the toggle is dead weight
# from here on — hide it instead of letting the player flip a switch that does
# nothing.
func draw_cancel_available():
	if fighter.bullet_cancelling:
		return false
	return fighter.draw_cancel_possible(fighter.current_state(), true)

func update_selected_move(move_state):
	.update_selected_move(move_state)
	# Hold (no specific move): available if any reachable move can still draw.
	# A specific move: only if that move itself can draw (checked fresh).
	var show_draw
	if move_state == null:
		show_draw = draw_cancel_available()
	else:
		show_draw = fighter.draw_cancel_possible(move_state, false)
	$"%ShootButton".visible = show_draw
	# "Draw on Block" only for moves whose sole draw route is the on-block one;
	# a try_shoot move draws on hit/whiff too, so it stays "Draw".
	var label_state = fighter.current_state() if move_state == null else move_state
	$"%ShootButton".text = "Draw on Block" if fighter.draw_cancel_on_block_only(label_state, move_state == null) else "Draw"
	if fighter.after_image_object != null:
		$"%DetonateButton".show()
		update_tp_button()
	sight_button.visible = (!move_state or (move_state.state_name != "Foresight" and move_state.state_name != "ForesightNeutral")) and fighter.after_image_object == null
	update_sight_button()

	var obj = fighter.obj_from_name(fighter.after_image_object)
	aerial = false
	grounded = false
	if obj:
		if $"%TpButton".pressed: 
			aerial = obj.get_pos().y < 0
			grounded = obj.get_pos().y == 0
		elif $"%MilkButton".pressed:
			aerial = fighter.is_grounded()
			grounded = !fighter.is_grounded()

	block_disable()

func _on_DetonateButton_toggled(button_pressed):
	$"%TpButton".set_pressed_no_signal(false)
	$"%MilkButton".set_pressed_no_signal(false)
	block_disable()

func _on_TpButton_toggled(button_pressed):
	$"%DetonateButton".set_pressed_no_signal(false)
	$"%MilkButton".set_pressed_no_signal(false)
	block_disable()

func _on_MilkButton_toggled(button_pressed):
	$"%DetonateButton".set_pressed_no_signal(false)
	$"%TpButton".set_pressed_no_signal(false)
	block_disable()
