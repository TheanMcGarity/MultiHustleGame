tool

extends Control
const NUM_LINES = 100
const LINE_MIN_SIZE = 20
const LINE_MAX_SIZE = 200
const TICK_DIV = 100.0
const SPEED = 1
const CAMERA_SPEED_DIVISOR = 16.0
const MIN_INTENSITY = 0.05
# The hardcoded 0.95 the lerp originally used was calibrated for a 60Hz
# cadence. set_speed runs at render rate (called from main._process), so we
# rescale this per frame's actual dt — that's what keeps the per-real-second
# decay rate the same on 30-FPS and 144-FPS PCs without forcing the lerp
# (and the direction it depends on) onto a fixed-rate tick, which made the
# angle look out of sync with everything else updating at render rate.
const INTENSITY_LERP_AT_60HZ = 0.95
# Raw camera-derived target must exceed this for the sustained timer below to
# accrue. 0.5 matches the visual "lines on" threshold (intensity > 0.25 with
# intensity = target², so target = sqrt(0.25) = 0.5).
const SUSTAINED_TARGET_THRESHOLD = 0.5
# Real-time the target must STAY above SUSTAINED_TARGET_THRESHOLD before lines
# actually draw, regardless of how high intensity has climbed. Filters out
# single-tick speed spikes (screenshake / camera-snap nudges / brief impulses)
# that would otherwise flash the lines on for a frame. ~50ms = 3 frames at
# 60Hz, "more than a couple."
const SUSTAINED_TIME_THRESHOLD = 0.05
# Multiplier added to the speed input scaled by how vertical the motion is.
# The camera tracks the midpoint of the two players, so a single character
# jumping only moves the camera at half their speed; the camera-zoom division
# in main.gd nerfs it further when players are vertically spread. Without
# this, vertical motion barely reaches the line-on threshold even when
# horizontal motion of comparable character speed easily clears it. Applied
# only to the target calculation — self.speed (used for line ANIMATION rate)
# stays raw so the lines don't visibly speed up just because the camera is
# moving vertically. 1.0 = pure-vertical motion gets 2× the input speed.
const VERTICAL_SPEED_BOOST = 0.0
# Screen-space distance at which a line is fully unfaded relative to whichever
# character it's farther from. Lines inside this radius around either player
# fade out (via ease() with intensity_easing), lines outside it draw at full
# brightness. Replaces the previous center-of-screen anchor with a per-player
# anchor — same idea the super-effect overlay uses (it anchors per character).
const CHARACTER_FADE_RADIUS = 200.0

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export var dir = Vector2()
export var intensity = 0.0
export var noise: OpenSimplexNoise
export var noise2: OpenSimplexNoise
export var on = false
export(float, EASE) var intensity_easing = 0
var speed = 0.0
# Internal smoothed input in [0, 1] — set_speed lerps this toward the clamped
# speed/divisor each render frame, and `intensity` is its square. Smoothing
# a bounded value (rather than intensity directly) keeps the lerp's
# arithmetic bounded so the delta-scaled factor can't blow up at high FPS:
# the original formula did pow(lerp(intensity, target, 0.95), 2), which is
# fine when t≈1 because the lerp collapses to target, but rescaling t down
# for higher FPS made lerp(intensity, …) keep the OLD intensity term, and
# pow squared the leftover into the millions on the next pass.
var _smoothed_target = 0.0
# Counts real seconds the raw target has been above SUSTAINED_TARGET_THRESHOLD.
# Lines draw only when this exceeds SUSTAINED_TIME_THRESHOLD, so a single-tick
# speed spike can't flash them on. Decays back down when target drops so a
# follow-up motion has to earn the threshold again.
var _sustained_above = 0.0
# Frame delta cached from _process so set_speed (called externally from
# main._process) can scale its lerp factor without depending on
# get_process_delta_time, which returns 0 the very first time it's read.
var _last_dt = 1.0 / 60.0
var center = Vector2(320, 180)
# Per-player screen-space anchors used for the per-character fade in _draw.
# main._process recomputes these each render frame via set_player_anchors,
# using camera.global_position (the un-shaken base camera position) so the
# anchors don't pick up screen-shake offset — the lines stay where the
# characters'd be without any rumble.
var p1_anchor = Vector2(320, 180)
var p2_anchor = Vector2(320, 180)
var tick = 0

func set_direction(dir):
	self.dir = -dir

func set_player_anchors(p1: Vector2, p2: Vector2):
	p1_anchor = p1
	p2_anchor = p2

func set_speed(speed):
	# Delta-scaled smoothing factor. At dt = 1/60 this evaluates to
	# INTENSITY_LERP_AT_60HZ (the constant the original formula used);
	# above/below 60Hz it rescales so the time-to-decay is the same in
	# real seconds. Without the rescale, on low-FPS PCs the per-call
	# factor stayed at 0.95 but call rate dropped, so decay per real
	# second dropped too — the "lines hang on" symptom.
	var t = 1.0 - pow(1.0 - INTENSITY_LERP_AT_60HZ, _last_dt * 60.0)
	# Asymmetric boost for vertical-leaning motion (see VERTICAL_SPEED_BOOST).
	# dir was already set by set_direction this frame, so abs(dir.y) reflects
	# the current motion's verticality. Pure horizontal → multiplier of 1.0
	# (no change vs original sensitivity); pure vertical → 1 + boost.
	var verticality = abs(dir.y) if dir.length_squared() > 0.0 else 0.0
	var boosted_speed = abs(speed) * (1.0 + VERTICAL_SPEED_BOOST * verticality)
	var target = clamp(boosted_speed / CAMERA_SPEED_DIVISOR, MIN_INTENSITY, 1.0)
	_smoothed_target = lerp(_smoothed_target, target, t)
	intensity = _smoothed_target * _smoothed_target
	# Accumulate / decay the sustained-motion timer. Capped at 2× the
	# threshold so a long run of fast motion doesn't take forever to fall
	# back below the threshold after the motion ends.
	if target >= SUSTAINED_TARGET_THRESHOLD:
		_sustained_above = min(_sustained_above + _last_dt, SUSTAINED_TIME_THRESHOLD * 2.0)
	else:
		_sustained_above = max(_sustained_above - _last_dt, 0.0)
	self.speed = speed
#	on = intensity > 0.1

func get_line_x(num):
	var t = tick / TICK_DIV * speed
	return noise.get_noise_2d(num, t) * 640

func get_line_y(num):
	var t = tick / TICK_DIV * speed
	return noise2.get_noise_2d(num, t) * 360

func get_variation(num):
	return noise2.get_noise_1d(num)

func _process(delta):
	# Cache delta for set_speed to use, then schedule a redraw at the render
	# cadence so the visible draw rate matches the monitor refresh rate
	# (was _physics_process before, capped at 60Hz even on high-FPS displays).
	_last_dt = delta
	update()

func _physics_process(delta):
	tick += 1

func _draw():
#	draw_line(center, center + dir * 100, Color.purple, 10)
	if on and intensity > 0.25 and _sustained_above > SUSTAINED_TIME_THRESHOLD and Global.speed_lines_enabled:
		dir = dir.normalized()
		
		for i in range(NUM_LINES):
			var variation = get_variation(NUM_LINES - i)

			var x = get_line_x(i)
			var y = get_line_y(i)
		
			var pos = Vector2(x, y) + (tick * dir * (speed * abs(intensity)))
			pos.x = fposmod(pos.x, 640)
			pos.y = fposmod(pos.y, 360)
			# Per-character fade: lines bright far from BOTH players, faded
			# near whichever is closer. Same easing shape the center-of-screen
			# fade used, just anchored on the closer character's screen pos
			# (set by main._process via set_player_anchors, computed off the
			# un-shaken camera position so the anchor doesn't pick up rumble).
			var min_dist = min(pos.distance_to(p1_anchor), pos.distance_to(p2_anchor))
			var s = clamp(min_dist / CHARACTER_FADE_RADIUS, 0.0, 1.0)
			var line_intensity = intensity * variation * ease(s, intensity_easing)
			var line_size = lerp(LINE_MIN_SIZE, LINE_MAX_SIZE, line_intensity)
			var start = pos - dir * line_size / 2.0
			var end = pos + dir * line_size / 2.0
	#		print(pos)
			var color = Color.white
			color.a = max(line_intensity, 0)
			draw_line(start, end, color, 1.5 + line_intensity)
