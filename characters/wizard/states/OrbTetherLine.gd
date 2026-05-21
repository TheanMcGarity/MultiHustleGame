extends Node2D

# Visual-only dotted tether drawn between the wizard and the orb while
# OrbTether is active. Lives in the game's fx_node and is ticked from
# Game.process_fx, matching the GasBombTrail pattern so it pauses with the
# sim and dies automatically when tether_ticks runs out. Spawned for both
# the real and ghost wizards so prediction renders the tether too.

const DOT_SPRITE = preload("res://fx/particle_round_hollow_4x4.png")
const COLOR = Color("1d8df5")
const DOT_SPACING = 8.0
# Hard cap on visible dots. Past the length where MAX_DOTS at DOT_SPACING
# would span the tether, the dots stretch evenly across the full length
# instead of multiplying — keeps the visual consistent on long tethers.
const MAX_DOTS = 11
# Mirror of Wizard.gd's TETHER_SPEED / TETHER_FALLOFF / "0.05" cutoff —
# duplicated here so the alpha fade can be derived without poking through
# fixed-point helpers from the fx layer.
const TETHER_SPEED_MAX = 1.5
const TETHER_FALLOFF = 0.96
const TETHER_SPEED_MIN = 0.05

var wizard = null
var orb = null

func _ready():
	# Force the dots to draw behind everything in the scene. fx_node is a
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
	var start = wizard.get_hurtbox_center_float() - origin
	var end = orb.get_hurtbox_center_float() - origin
	var color = COLOR
	color.a = _alpha_from_tether_speed()
	var diff = end - start
	var dist = diff.length()
	if dist < 0.001:
		_draw_dot(start, color)
		return
	var dir = diff / dist
	var max_span_at_default = DOT_SPACING * (MAX_DOTS - 1)
	if dist > max_span_at_default:
		# Stretch: MAX_DOTS dots evenly spaced from start to end (inclusive).
		# Spacing widens with the tether so the count never exceeds MAX_DOTS.
		var spacing = dist / float(MAX_DOTS - 1)
		for i in range(MAX_DOTS):
			_draw_dot(start + dir * (i * spacing), color)
	else:
		# Short tether — keep the 8px rhythm, then anchor an extra dot at the
		# end so the orb side always reads as connected even when dist isn't
		# an exact multiple of DOT_SPACING.
		var t = 0.0
		while t < dist:
			_draw_dot(start + dir * t, color)
			t += DOT_SPACING
		_draw_dot(end, color)

func _draw_dot(pos: Vector2, color: Color):
	var size = DOT_SPRITE.get_size()
	draw_texture(DOT_SPRITE, pos - size * 0.5, color)

# Map current tether_speed (which decays from MAX → MIN over the tether's
# lifetime) onto alpha 1.0 → 0.5. Matches the falloff Wizard.gd applies in
# its tick() before pushing force at the wizard.
func _alpha_from_tether_speed() -> float:
	var elapsed = wizard.TETHER_TICKS - wizard.tether_ticks
	var falloff_power = elapsed / 3.0
	var speed = TETHER_SPEED_MAX * pow(TETHER_FALLOFF, falloff_power)
	var span = TETHER_SPEED_MAX - TETHER_SPEED_MIN
	var t = clamp((speed - TETHER_SPEED_MIN) / span, 0.0, 1.0)
	return lerp(0.25, 1.0, t)
