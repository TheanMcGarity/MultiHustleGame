tool

extends Control
const NUM_LINES = 100
const LINE_MIN_SIZE = 20
const LINE_MAX_SIZE = 200
const TICK_DIV = 100.0
const SPEED = 1
const CAMERA_SPEED_DIVISOR = 16.0
const MIN_INTENSITY = 0.05
# Camera speed needed to start nudging intensity up at all. Below this, the
# clamp pins target at 0 so the lerp drives intensity to ~0 and the draw
# branch's intensity > 0.25 gate stays false. Without a deadzone, idle micro-
# motion from the camera-snap lerp in game._physics_process was enough to
# keep target above the threshold-crossing speed (~8.4 px/tick) often enough
# to register as "lines always on" on low-FPS PCs where the eye sees the
# tail rather than the brief equilibrium dips.
const CAMERA_SPEED_DEADZONE = 4.0

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export var dir = Vector2()
export var intensity = 100.0
export var noise: OpenSimplexNoise
export var noise2: OpenSimplexNoise
export var on = false
export(float, EASE) var intensity_easing = 0
var speed = 0.0
# Smoothing input — set_speed stores into this from main._process (called at
# render rate), and the lerp that turns it into `intensity` runs in
# _physics_process at the fixed engine physics rate. Keeping the smoothing
# step at a fixed cadence means the time-to-decay below the draw threshold
# is the same on 30-FPS and 144-FPS machines; before this split, the lerp
# ran in set_speed at render rate, so on low-FPS PCs intensity decayed many
# fewer iterations per real second and the lines hung on visibly while the
# camera was sitting still.
var target_speed = 0.0
var center = Vector2(320, 180)
var tick = 0

func set_direction(dir):
	self.dir = -dir

func set_speed(speed):
	target_speed = speed
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

func _physics_process(delta):
	# Drive the intensity lerp from a fixed-rate tick so the convergence
	# rate per real second is the same regardless of render FPS. Camera speed
	# below the deadzone clamps target to 0, so transient camera-snap jitter
	# (which is present even when the camera "isn't really moving") doesn't
	# keep nudging intensity above the draw threshold.
	var effective_speed = max(abs(target_speed) - CAMERA_SPEED_DEADZONE, 0.0)
	var target = clamp(effective_speed / CAMERA_SPEED_DIVISOR, 0.0, 1.0)
	intensity = pow(lerp(intensity, target, 0.95), 2)
	update()
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
