extends Node2D

# Visual-only trail spawned alongside the GasBomb. Lives independently of the
# bomb so it can keep drawing (and fade out) after the bomb is disabled/freed.
# Ticked from Game.process_fx — pauses with the game, not with the renderer.

const TRAIL_LENGTH = 30
const COLOR = Color("64d26b")

var target = null
var positions = []  # game-space Vector2s, oldest at index 0

func tick():
	var alive = is_instance_valid(target) and not target.disabled
	if alive:
		positions.append(target.get_pos_visual())
		while positions.size() > TRAIL_LENGTH:
			positions.pop_front()
	else:
		# Bomb gone — shrink the trail one tick at a time so it tapers out
		# from the tail end, then free once nothing's left to draw.
		if positions.size() > 0:
			positions.pop_front()
		if positions.empty():
			queue_free()
			return
	update()

func _draw():
	if positions.size() < 2:
		return
	var n = positions.size()
	var origin = global_position
	for i in range(n - 1):
		# i=0 is the tail end; i=n-2 is the head end. (i+1)/n keeps the tail
		# at a faint glow instead of zero so the segment doesn't pop out.
		var c = COLOR
		c.a = float(i + 1) / float(n)
		draw_line(positions[i] - origin, positions[i + 1] - origin, c, 1.0)
