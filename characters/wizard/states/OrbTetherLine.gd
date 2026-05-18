extends Node2D

# Visual-only 1px line drawn between the wizard and the orb while OrbTether
# is active. Lives in the game's fx_node and is ticked from Game.process_fx,
# matching the GasBombTrail pattern so it pauses with the sim and dies
# automatically when tether_ticks runs out.

const COLOR = Color("04579a")

var wizard = null
var orb = null

func _ready():
	# Force the line to draw behind everything in the scene. fx_node is a
	# later sibling of Players + Objects, so a default-z child would render
	# on TOP of the wizard and orb sprites. Absolute z=-100 sinks it below
	# both regardless of their own (sometimes 100+) z_index values.
	z_as_relative = false
	z_index = -100

func tick():
	var alive = is_instance_valid(wizard) \
		and is_instance_valid(orb) \
		and not orb.disabled \
		and wizard.tether_ticks > 0
	if not alive:
		queue_free()
		return
	update()

func _draw():
	if not is_instance_valid(wizard) or not is_instance_valid(orb):
		return
	var origin = global_position
	# Hurtbox center, not get_pos_visual — for the wizard, pos is the feet
	# anchor, so the tether would otherwise stick out of the ground. The orb
	# uses its hurtbox center too for symmetry; both render mid-body.
	draw_line(wizard.get_hurtbox_center_float() - origin, orb.get_hurtbox_center_float() - origin, COLOR, 1.0)
