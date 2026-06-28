extends BaseProjectile

class_name TemporalPath

# Reworked Temporal Round projectile. Spawned by Cowboy's Shoot (temporal)
# state. Unlike the old time bullet (NewTimeBullet, kept for revert), this is
# a STATIC projectile: on spawn it computes its entire ricochet path up front
# (direction from the shot, ricochet reflections bent by DI), draws it as a
# dark-grey line, then after a delay (fast/normal, matching the old temporal
# round timing) activates one swept hitbox per path segment all at once and
# turns the line purple. Destroyed if Cowboy is hit, like the old round.
#
# All the per-spawn data (direction, computed path, activation state) lives in
# extra_state_variables so it survives rollback / replay. SwordGuy keeps its
# super-meter penalty active via `temporal_round` name tracking (set in
# Shoot.gd), so no separate active-bullet counter is needed here.

const LINE_GREY = Color("404040")
const LINE_PURPLE = Color("4b2bd9")
# Thin preview line before activation; thicker once the hitboxes are live.
const LINE_WIDTH_GREY = 1.0
const LINE_WIDTH_PURPLE = 3.0

# Both parameterized so the move can be tuned without touching code.
export var ricochet_count = 3
export var active_frames = 30
# After the active window the line fades its thickness to 0 over this many
# frames, then the projectile is freed.
export var fade_frames = 10
# Pre-activation delay, in frames. Mirrors the old TemporalRoundDefault timing
# (the frame at which it used to spawn the flying bullet).
export var delay_fast = 18
export var delay_normal = 51
# Per-segment length cap (px) for degenerate rays (e.g. parallel to a wall, or
# pointing up with no ceiling) so a segment never shoots off to infinity.
export var segment_cap = 10000

# Set by Shoot.gd at spawn.
var fast = false
var dir_x = "0"
var dir_y = "0"
# DI sampled once at spawn (TemporalPathDefault), drives the ricochet angles.
var di_x = "0"
var di_y = "0"

# Computed path in world coords (fixed-point ints). Drawn as a polyline and
# used to place the swept hitboxes. point count == segment count + 1.
var path_x = []
var path_y = []
# Flipped true once the hitboxes go live — drives the grey→purple line color.
var activated = false
# Current line thickness, driven by the state (1px grey preview, 3px active,
# ramping to 0 during the fade-out).
var line_width = LINE_WIDTH_GREY

func init(pos=null):
	.init(pos)

func _draw():
	if disabled:
		return
	if path_x.size() < 2:
		return
	if line_width <= 0.0:
		return
	var col = LINE_PURPLE if activated else LINE_GREY
	for i in range(path_x.size() - 1):
		var a = to_local(Vector2(path_x[i], path_y[i]))
		var b = to_local(Vector2(path_x[i + 1], path_y[i + 1]))
		draw_line(a, b, col, line_width)
