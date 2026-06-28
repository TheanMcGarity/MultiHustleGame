tool 

extends Hitbox

class_name SweptHitbox

const IS_SWEPT = true

export  var _c_Raycast = 0
export  var to_x = 0
export  var to_y = 0

func _fixed_clamp(
	n: String,
	start: String, end: String
):
	if host.fixed.lt(n, start):
		return start
	elif host.fixed.gt(n, end):
		return end
	else:
		return n

func _fixed_max(
	a: String,
	b: String
):
	return a if host.fixed.gt(a, b) else b

func _fixed_min(
	a: String,
	b: String
):
	return a if host.fixed.lt(a, b) else b
	
func _aabb_intersect(aabb: Dictionary):
	var fixed: FixedMath = host.fixed
	var x1 = x_facing() + pos_x - width
	var x2 = x_facing() + pos_x + width
	var y1 = y + pos_y - height
	var y2 = y + pos_y + height
	if x1 > aabb.x2 or x2 < aabb.x1 or y1 > aabb.y2 or y2 < aabb.y1:
		return null
	else:
		return "0"

func _seg_seg_intersect(start: int, delta: int, padding: int, n1: int, n2: int):
	var fixed: FixedMath = host.fixed

	var near: int
	var far: int
	if delta > 0:
		near = n1 - padding
		far = n2 + padding
	else:
		near = n2 + padding
		far = n1 - padding

	var recip: String = fixed.div("1.0", str(delta))

	var near_time: String = fixed.mul(str(near - start), recip)
	if fixed.ge(near_time, "1"):
		return null
	
	var far_time: String = fixed.mul(str(far - start), recip)
	if fixed.le(far_time, "0"):
		return null
		
	return near_time

func _seg_rect_intersect(box: CollisionBox):
	return _swept_aabb_intersect(x_facing() + pos_x, y + pos_y, to_x_facing(), to_y, box.get_aabb())

# Continuous-collision core: segment starts at (start_x, start_y), moves
# by (delta_x, delta_y) over t ∈ [0, 1], swept by self's (width, height)
# half-extents. Tests against an `aabb` dict (x1, x2, y1, y2). Returns
# the near_time of impact as a fixed-point string, or null if the swept
# rect never enters the aabb. Used by:
#   - _seg_rect_intersect (static aabb, self's own motion) for swept-
#     hitbox vs static hurtbox/hitbox.
#   - _seg_swept_intersect (relative motion, other's start aabb) for
#     swept-vs-swept clash detection.
func _swept_aabb_intersect(start_x: int, start_y: int, delta_x: int, delta_y: int, aabb: Dictionary):
	var fixed: FixedMath = host.fixed

	# segment starts inside rect
	if start_x > aabb.x1 and start_x < aabb.x2 and start_y > aabb.y1 and start_y < aabb.y2:
		return "0"

	var zero_y = delta_y == 0
	var zero_x = delta_x == 0
	# less strenuous tests if segment is straight
	if zero_x != zero_y:
		if zero_y:
			if start_y > aabb.y1 - height and start_y < aabb.y2 + height:
				return _seg_seg_intersect(start_x, delta_x, width, aabb.x1, aabb.x2)
			else:
				return null
		if zero_x:
			if start_x > aabb.x1 - width and start_x < aabb.x2 + width:
				return _seg_seg_intersect(start_y, delta_y, height, aabb.y1, aabb.y2)
			else:
				return null
	# aabb intersection if segment is (0, 0)
	elif zero_x and zero_y:
		return _aabb_intersect_at(start_x, start_y, aabb)

	var near_x: int
	var far_x: int
	if delta_x > 0:
		near_x = aabb.x1 - width
		far_x = aabb.x2 + width
	else:
		near_x = aabb.x2 + width
		far_x = aabb.x1 - width

	var near_y: int
	var far_y: int
	if delta_y > 0:
		near_y = aabb.y1 - height
		far_y = aabb.y2 + height
	else:
		near_y = aabb.y2 + height
		far_y = aabb.y1 - height

	var recip_x: String = fixed.div("1.0", str(delta_x))
	var recip_y: String = fixed.div("1.0", str(delta_y))

	var near_time_x: String = fixed.mul(str(near_x - start_x), recip_x)
	var far_time_y:  String = fixed.mul(str(far_y - start_y),  recip_y)

	if fixed.gt(near_time_x, far_time_y):
		return null

	var near_time_y: String = fixed.mul(str(near_y - start_y), recip_y)
	var far_time_x:  String = fixed.mul(str(far_x - start_x),  recip_x)

	if fixed.gt(near_time_y, far_time_x):
		return null

	var near_time: String = _fixed_max(near_time_x, near_time_y)
	var far_time:  String = _fixed_min(far_time_x, far_time_y)

	if fixed.ge(near_time, "1") or fixed.le(far_time, "0"):
		return null

	return near_time

# Static aabb-overlap test centered at (start_x, start_y) with self's
# (width, height) half-extents — used by the zero-delta branch of the
# swept-vs-swept variant, where the relative motion happens to cancel
# out and both rects move in lockstep.
func _aabb_intersect_at(start_x: int, start_y: int, aabb: Dictionary):
	var x1 = start_x - width
	var x2 = start_x + width
	var y1 = start_y - height
	var y2 = start_y + height
	if x1 > aabb.x2 or x2 < aabb.x1 or y1 > aabb.y2 or y2 < aabb.y1:
		return null
	return "0"

# Swept-vs-swept variant. Treat `other` as static at its start position
# and have self move with the relative delta (self.delta - other.delta).
# The Minkowski sum (self.width + other.width, etc.) falls out for free
# because _swept_aabb_intersect inflates the aabb by self's size, and
# we pass other's actual size as the aabb extent.
func _seg_swept_intersect(other):
	var other_start_x = other.x_facing() + other.pos_x
	var other_start_y = other.y + other.pos_y
	var aabb = {
		"x1": other_start_x - other.width,
		"x2": other_start_x + other.width,
		"y1": other_start_y - other.height,
		"y2": other_start_y + other.height,
	}
	var delta_x = to_x_facing() - other.to_x_facing()
	var delta_y = to_y - other.to_y
	return _swept_aabb_intersect(x_facing() + pos_x, y + pos_y, delta_x, delta_y, aabb)
	
func _seg_rect_test(box: CollisionBox):
	return _seg_rect_intersect(box) != null

func _seg_rect_delta(box: CollisionBox):
	var near_time = _seg_rect_intersect(box)
	if near_time == null:
		return null

	var fixed: FixedMath = host.fixed

	var hit_time = _fixed_clamp(near_time, "0", "1")

	var delta_x = str(to_x_facing())
	var delta_y = str(to_y)
	
	return {
		"x": fixed.mul(delta_x, hit_time),
		"y": fixed.mul(delta_y, hit_time)
	}


func get_sweep_center():
	var fixed: FixedMath = host.fixed

	var start = get_center()	
	
	var delta_x = to_x_facing()
	var delta_y = to_y
	
	var delta_half = fixed.vec_mul(str(delta_x), str(delta_y), "0.5")
	
	return {
		"x": start.x + fixed.round(delta_half.x),
		"y": start.y + fixed.round(delta_half.y)
	}

func get_sweep_center_float():
	var delta = Vector2(to_x_facing(), to_y)
	
	return get_center_float() + (delta / 2.0)

func to_x_facing():
	return to_x if facing == "Right" else - to_x

func get_aabb():
	# given how everything is implemented, this will only happen when trying to
	#  test for CollisionBox.overlaps(SweptHitbox), which only occurs when
	#  a SweptHitbox is used as a hurtbox
#	assert(false, "calling get_aabb() on a SweptHitbox")
	
	pass

func overlaps(box: CollisionBox):
	if box.width == 0 and box.height == 0:
		return false
	if box.get("IS_SWEPT"):
		return _seg_swept_intersect(box) != null
	return _seg_rect_test(box)

func box_draw():
	var parent = get_parent()
	if parent.is_in_group("BaseObj"):
		if parent.disabled:
			return 
	var color = Color.red
	if throw:
		color = Color.purple
		
	var to_x_facing = to_x_facing()
	
	var top_origin_is_flat = (to_y >= 0)
	var right_origin_is_flat = (to_x_facing < 0)

	var size = Vector2(width, height)
	var size_neg = Vector2(-width, height)

	var offset = Vector2(x_facing(), y)
	var to_offset = offset + Vector2(to_x_facing, to_y)

	var offset1
	var offset2

	if right_origin_is_flat:
		offset1 = to_offset
		offset2 = offset
	else:
		offset1 = offset
		offset2 = to_offset

	var p1
	var p2

	if top_origin_is_flat == right_origin_is_flat:
		p1 = size
		p2 = size_neg
	else:
		p1 = size_neg
		p2 = -size
	
	var points = [
		offset1 + p1,
		offset1 + p2,
		offset1 - p1,

		offset2 - p1,
		offset2 - p2,
		offset2 + p1
	]

	var fill = color
	var stroke = color
	fill.a = 0.25
	stroke.a = 0.5
	draw_colored_polygon(points, fill)

	# draw_polyline needs a closing point
	points.push_back(points[0])
	draw_polyline(points, stroke)

func spawn_whiff_particle():
	if whiff_particle:
		host.spawn_particle_effect(whiff_particle, Vector2(x + pos_x, y + pos_y), Vector2(x_facing(), 0))
	
func get_center():
	return {
		"x": x_facing() + pos_x,
		"y": y + pos_y
	}
	
func get_center_float():
	return Vector2(x_facing() + pos_x, y + pos_y)

func get_overlap_center_float(box: CollisionBox):
	# Reconstruct both rects at the moment of first contact (or t=0 if
	# already overlapping at start) and return the center of their AABB
	# intersection. Works symmetrically for swept-vs-static and
	# swept-vs-swept; the visual lands at the actual point of contact
	# rather than a path-projection approximation.
	var near_time
	if box.get("IS_SWEPT"):
		near_time = _seg_swept_intersect(box)
	else:
		near_time = _seg_rect_intersect(box)
	if near_time == null:
		# Caller asked redundantly (no actual collision). Fall back to
		# self's start center; degenerate but safe.
		return get_center_float()
	var t = float(near_time)
	var self_cx = float(x_facing() + pos_x) + float(to_x_facing()) * t
	var self_cy = float(y + pos_y) + float(to_y) * t
	var box_cx: float
	var box_cy: float
	if box.get("IS_SWEPT"):
		box_cx = float(box.x_facing() + box.pos_x) + float(box.to_x_facing()) * t
		box_cy = float(box.y + box.pos_y) + float(box.to_y) * t
	else:
		var bc = box.get_center_float()
		box_cx = bc.x
		box_cy = bc.y
	var ox1 = max(self_cx - width, box_cx - box.width)
	var oy1 = max(self_cy - height, box_cy - box.height)
	var ox2 = min(self_cx + width, box_cx + box.width)
	var oy2 = min(self_cy + height, box_cy + box.height)
	return Vector2((ox1 + ox2) / 2.0, (oy1 + oy2) / 2.0)
