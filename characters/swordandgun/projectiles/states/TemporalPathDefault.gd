extends ObjectState

# Static Temporal Round path projectile.
#
# Direction comes from the shot; each ricochet's angle is full DI control
# (the sampled DI direction), except that if DI would drive the bullet back
# into the surface it just bounced off, the normal component is flipped away.
# Bounces off the stage walls/floor/ceiling AND the creator's AfterImage if
# one exists — so the path is recomputed every tick and changes live when the
# AfterImage is destroyed or moves, even after the hitboxes are active.
#
# DI is sampled once (at spawn) into host.di_x/di_y so the path only reacts to
# the AfterImage afterward, not to continued stick wiggling.

# When the post-bounce normal component lands on exactly zero we leave it —
# sliding along a surface is fine and not degenerate.

var _swept_hitboxes = []

# Half-extent restored on active segments (segments beyond the path are zeroed
# so leftover hitbox nodes can't hit). Matches the scene's hitbox size.
const HITBOX_HALF = 4

func _enter():
	# Force Right facing so hitbox x/to_x offsets are absolute world deltas
	# (x_facing()/to_x_facing() become identity), matching the world-space path.
	host.set_facing(1)
	_swept_hitboxes = []
	for child in get_children():
		if child is SweptHitbox:
			_swept_hitboxes.append(child)

func _tick():
	# Destroyed if Cowboy is hit at any point, like the old temporal round.
	var fighter = host.get_fighter()
	if fighter and fighter.is_in_hurt_state(false):
		host.disable()
		return
	if current_tick == 0:
		# Lock in DI once. Re-sampled identically on a resim of this frame.
		var di = fighter.current_di if fighter else null
		if di != null:
			host.di_x = str(di.x)
			host.di_y = str(di.y)
	var delay = host.delay_fast if host.fast else host.delay_normal
	var active_end = delay + host.active_frames
	var fade_end = active_end + host.fade_frames
	# Done fading — free it.
	if current_tick >= fade_end:
		host.disable()
		return
	# Phases: grey preview → active (purple, hitboxes live) → fade thickness
	# to 0 (hitboxes off). activated drives the line color; line_width the
	# thickness; live the hitbox activation.
	var live = current_tick >= delay and current_tick < active_end
	host.activated = current_tick >= delay
	if current_tick < delay:
		host.line_width = host.LINE_WIDTH_GREY
	elif current_tick < active_end:
		host.line_width = host.LINE_WIDTH_PURPLE
	else:
		var f = float(current_tick - active_end) / float(host.fade_frames)
		host.line_width = host.LINE_WIDTH_PURPLE * (1.0 - f)
	# Recompute the path every tick so it tracks the AfterImage live.
	_compute_path()
	_configure_hitboxes(live)
	host.update()

# --- path -----------------------------------------------------------------

func _compute_path():
	var di_dir = fixed.normalized_vec(host.di_x, host.di_y)
	var has_di = !fixed.eq(fixed.vec_len(di_dir.x, di_dir.y), "0")

	# The AfterImage only matters as a redirect waypoint when there's DI to
	# steer with — otherwise the bullet just flies straight through it.
	var box = _after_image_box() if has_di else null

	# Clamp the origin just inside the play area (1px margin). A bullet spawned
	# exactly on a boundary (e.g. y=0 floor) would otherwise raycast straight
	# through it — the floor/wall hit is at t=0, which we reject as "behind".
	var start = host.get_pos()
	var sx = start.x
	var sy = start.y
	if sx > host.stage_width - 1:
		sx = host.stage_width - 1
	elif sx < 1 - host.stage_width:
		sx = 1 - host.stage_width
	if sy > -1:
		sy = -1
	if host.has_ceiling and sy < 1 - host.ceiling_height:
		sy = 1 - host.ceiling_height
	var px = str(sx)
	var py = str(sy)
	var dx = host.dir_x
	var dy = host.dir_y

	host.path_x = [sx]
	host.path_y = [sy]

	# One segment per ricochet plus the initial segment, capped at how many
	# swept hitbox nodes we have to represent them.
	var num_segments = int(max(1, host.ricochet_count + 1))
	num_segments = int(min(num_segments, _swept_hitboxes.size()))

	# Surface the previous bounce came off — excluded from the next raycast so
	# a bounce can't immediately re-hit the same wall / AfterImage.
	var last_surface = ""

	for i in range(num_segments):
		var hit = _raycast(px, py, dx, dy, box, last_surface)
		host.path_x.append(fixed.round(hit.x))
		host.path_y.append(fixed.round(hit.y))
		# Last segment, or the ray escaped (capped) — no more ricochets.
		if hit.capped or i == num_segments - 1:
			break
		last_surface = hit.surface
		var in_dx = dx
		var in_dy = dy
		if hit.surface == "afterimage":
			# Not a bounce — passing through the AfterImage lets the bullet
			# freely re-aim in the DI direction (no reflection / clamps). With
			# no DI it just continues straight through.
			if has_di:
				dx = di_dir.x
				dy = di_dir.y
		else:
			# Surface bounce: full DI control of the angle...
			if has_di:
				dx = di_dir.x
				dy = di_dir.y
			else:
				# No DI — plain reflection off the hit axis.
				if hit.axis == "x":
					dx = fixed.mul(in_dx, "-1")
				else:
					dy = fixed.mul(in_dy, "-1")
			# Normal axis (perpendicular to the surface): if the chosen
			# direction still drives into the surface, flip it back out.
			# Tangential axis (along the surface): if the bullet would head
			# back the way it came, flip it to keep going forward. Walls have
			# normal x / tangent y; ground+ceiling the reverse.
			if hit.axis == "x":
				if _same_sign(dx, in_dx):
					dx = fixed.mul(dx, "-1")
				if _opposite_sign(dy, in_dy):
					dy = fixed.mul(dy, "-1")
			else:
				if _same_sign(dy, in_dy):
					dy = fixed.mul(dy, "-1")
				if _opposite_sign(dx, in_dx):
					dx = fixed.mul(dx, "-1")
		var n = fixed.normalized_vec(dx, dy)
		dx = n.x
		dy = n.y
		px = hit.x
		py = hit.y

func _same_sign(a, b):
	return (fixed.gt(a, "0") and fixed.gt(b, "0")) or (fixed.lt(a, "0") and fixed.lt(b, "0"))

func _opposite_sign(a, b):
	return (fixed.gt(a, "0") and fixed.lt(b, "0")) or (fixed.lt(a, "0") and fixed.gt(b, "0"))

# Nearest stage boundary OR AfterImage box along the ray from (px,py) in
# (dx,dy), skipping `exclude` (the surface the previous bounce came off, so
# we can't immediately re-hit it). Returns impact point (fixed strings), the
# hit axis, a surface id, and whether it was distance-capped (escaped).
func _raycast(px, py, dx, dy, box, exclude):
	var best_t = null
	var best_axis = ""
	var best_surface = ""
	if !fixed.eq(dx, "0"):
		var going_right = fixed.gt(dx, "0")
		var surface = "wall+" if going_right else "wall-"
		if surface != exclude:
			var wall = host.stage_width if going_right else -host.stage_width
			var t = fixed.div(fixed.sub(str(wall), px), dx)
			if fixed.gt(t, "0"):
				best_t = t
				best_axis = "x"
				best_surface = surface
	if fixed.gt(dy, "0") and exclude != "floor":
		var t = fixed.div(fixed.sub("0", py), dy)  # floor at y = 0
		if fixed.gt(t, "0") and (best_t == null or fixed.lt(t, best_t)):
			best_t = t
			best_axis = "y"
			best_surface = "floor"
	if fixed.lt(dy, "0") and host.has_ceiling and exclude != "ceiling":
		var t = fixed.div(fixed.sub(str(-host.ceiling_height), py), dy)  # ceiling
		if fixed.gt(t, "0") and (best_t == null or fixed.lt(t, best_t)):
			best_t = t
			best_axis = "y"
			best_surface = "ceiling"
	# AfterImage box (only when the ray isn't axis-parallel — keeps the slab
	# test simple, and a perfectly axis-aligned ray grazing the box is a
	# negligible edge case).
	if box != null and exclude != "afterimage" and !fixed.eq(dx, "0") and !fixed.eq(dy, "0"):
		var b = _ray_box(px, py, dx, dy, box)
		if b != null and (best_t == null or fixed.lt(b.t, best_t)):
			best_t = b.t
			best_axis = b.axis
			best_surface = "afterimage"
	var capped = false
	if best_t == null or fixed.gt(best_t, str(host.segment_cap)):
		best_t = str(host.segment_cap)
		capped = true
	return {
		"x": fixed.add(px, fixed.mul(dx, best_t)),
		"y": fixed.add(py, fixed.mul(dy, best_t)),
		"axis": best_axis,
		"surface": best_surface,
		"capped": capped,
	}

# Slab-method ray vs the AfterImage AABB. Returns {t, axis} of the entry face,
# or null if the ray misses or the box is behind the start.
func _ray_box(px, py, dx, dy, box):
	var tx1 = fixed.div(fixed.sub(str(box.x1), px), dx)
	var tx2 = fixed.div(fixed.sub(str(box.x2), px), dx)
	var tminx = _fmin(tx1, tx2)
	var tmaxx = _fmax(tx1, tx2)
	var ty1 = fixed.div(fixed.sub(str(box.y1), py), dy)
	var ty2 = fixed.div(fixed.sub(str(box.y2), py), dy)
	var tminy = _fmin(ty1, ty2)
	var tmaxy = _fmax(ty1, ty2)
	var tenter = _fmax(tminx, tminy)
	var texit = _fmin(tmaxx, tmaxy)
	if fixed.gt(tenter, texit) or fixed.le(tenter, "0"):
		return null
	return {"t": tenter, "axis": "x" if fixed.gt(tminx, tminy) else "y"}

func _fmin(a, b):
	return a if fixed.lt(a, b) else b

func _fmax(a, b):
	return a if fixed.gt(a, b) else b

# AfterImage AABB in world coords, or null if Cowboy has none alive.
func _after_image_box():
	var fighter = host.get_fighter()
	if fighter == null:
		return null
	var ai_name = fighter.get("after_image_object")
	if not ai_name:
		return null
	var ai = fighter.obj_from_name(ai_name)
	if ai == null or ai.disabled:
		return null
	var c = ai.get_hurtbox_center()
	var hw = ai.hurtbox.width
	var hh = ai.hurtbox.height
	return {
		"x1": c.x - hw, "x2": c.x + hw,
		"y1": c.y - hh, "y2": c.y + hh,
	}

# --- hitboxes -------------------------------------------------------------

func _configure_hitboxes(live):
	# Offsets are relative to the projectile's actual position (process_hitboxes
	# sets pos_x/pos_y to host.get_pos() each tick), NOT path_x[0] — which may
	# be the clamped origin and differ by the 1px margin.
	var hp = host.get_pos()
	var num_segments = host.path_x.size() - 1
	# Track whether any live segment moved this tick (path changed, e.g. the
	# AfterImage was destroyed) so we can refresh the group afterward.
	var path_changed = false
	for i in range(_swept_hitboxes.size()):
		var h = _swept_hitboxes[i]
		if i < num_segments:
			var nx = host.path_x[i] - hp.x
			var ny = host.path_y[i] - hp.y
			var ntx = host.path_x[i + 1] - host.path_x[i]
			var nty = host.path_y[i + 1] - host.path_y[i]
			if h.active and (h.x != nx or h.y != ny or h.to_x != ntx or h.to_y != nty):
				path_changed = true
			# Offset to this segment's start; sweep covers it.
			h.width = HITBOX_HALF
			h.height = HITBOX_HALF
			h.x = nx
			h.y = ny
			h.to_x = ntx
			h.to_y = nty
			# Earlier segments win when overlapping a target (higher priority),
			# so a target in two segments takes the earlier segment's knockback.
			h.priority = _swept_hitboxes.size() - i
			var seg = fixed.normalized_vec(str(h.to_x), str(h.to_y))
			h.dir_x = seg.x
			h.dir_y = seg.y
			# Live only during the active window; segments can come and go as
			# the AfterImage changes, so (de)activate to match.
			if live and !h.active:
				h.activate()
			elif !live and h.active:
				h.deactivate()
		else:
			# Beyond the current path — make leftover nodes inert.
			if h.active:
				h.deactivate()
			h.width = 0
			h.height = 0
	# Path moved under active hitboxes — clear the group's hit list so targets
	# already struck can be hit again on the new path. reset_hit_objects()
	# clears the whole group, so one call covers them all.
	if path_changed:
		for h in _swept_hitboxes:
			if h.active:
				h.reset_hit_objects()
				break
