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
# Frame delta cached from _process so set_speed (called externally from
# main._process) can scale its lerp factor without depending on
# get_process_delta_time, which returns 0 the very first time it's read.
var _last_dt = 1.0 / 60.0
var center = Vector2(320, 180)
var tick = 0

func set_direction(dir):
	self.dir = -dir

func set_speed(speed):
	# Delta-scaled smoothing factor. At dt = 1/60 this evaluates to
	# INTENSITY_LERP_AT_60HZ (the constant the original formula used);
	# above/below 60Hz it rescales so the time-to-decay is the same in
	# real seconds. Without the rescale, on low-FPS PCs the per-call
	# factor stayed at 0.95 but call rate dropped, so decay per real
	# second dropped too — the "lines hang on" symptom.
	var t = 1.0 - pow(1.0 - INTENSITY_LERP_AT_60HZ, _last_dt * 60.0)
	var target = clamp(abs(speed) / CAMERA_SPEED_DIVISOR, MIN_INTENSITY, 1.0)
	_smoothed_target = lerp(_smoothed_target, target, t)
	intensity = _smoothed_target * _smoothed_target
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
	if on and intensity > 0.25 and Global.speed_lines_enabled:
		dir = dir.normalized()
		
		for i in range(NUM_LINES):
			var variation = get_variation(NUM_LINES - i)

			var x = get_line_x(i)
			var y = get_line_y(i)
		
			var pos = Vector2(x, y) + (tick * dir * (speed * abs(intensity)))
			pos.x = fposmod(pos.x, 640)
			pos.y = fposmod(pos.y, 360)
			var distance_to_center = Vector2(abs(pos.x - center.x) / 400, abs(pos.y - center.y) / 200)
#			print(distance_to_center.length())
#			print(ease(distance_to_center.length(), intensity_easing))
			var line_intensity = intensity * variation * ease(distance_to_center.length(), intensity_easing)
			var line_size = lerp(LINE_MIN_SIZE, LINE_MAX_SIZE, line_intensity)
			var start = pos - dir * line_size / 2.0
			var end = pos + dir * line_size / 2.0
	#		print(pos)
			var color = Color.white
			color.a = max(line_intensity, 0)
			draw_line(start, end, color, 1.5 + line_intensity)
