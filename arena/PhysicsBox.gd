tool

extends CollisionBox

class_name PhysicsBox

export var box_rotation_parent:NodePath

onready var box_rotation_node = get_node(box_rotation_parent)

func get_axes(rotation):
	return [
		Vector2(cos(rotation), sin(rotation)), 
		Vector2(-sin(rotation), cos(rotation))  
	]
func get_box_rotation(col):
	if col.get("box_rotation_node") != null:
		return col.box_rotation_node.rotation
	else:
		return 0
func get_half_size(col):
	return Vector2(col.width / 2, col.height / 2)
	
func get_box_center(col):
	return col.global_position + Vector2(col.x,col.y)
	#var pos = col.global_position + Vector2(col.x,col.y)
	#return Vector2(pos.x + (col.width / 2), pos.y + (col.height / 2))

func get_corners(center, half, rotation):
	var axes = get_axes(rotation)
	return [
		center + axes[0] * half.x + axes[1] * half.y,
		center + axes[0] * half.x - axes[1] * half.y,
		center - axes[0] * half.x - axes[1] * half.y,
		center - axes[0] * half.x + axes[1] * half.y
	]

func obb_overlap(a, b) -> bool:
	var a_axes = get_axes(get_box_rotation(a))
	var b_axes = get_axes(get_box_rotation(b))

	var axes = [
		a_axes[0], a_axes[1],
		b_axes[0], b_axes[1]
	]

	var a_pts = get_corners(get_box_center(a), get_half_size(a), get_box_rotation(a))
	var b_pts = get_corners(get_box_center(b), get_half_size(b), get_box_rotation(b))
	
	for axis in axes:
		axis = axis.normalized()
		var p1 = project(a_pts, axis)
		var p2 = project(b_pts, axis)
		if p1.y < p2.x or p2.y < p1.x:
			return false

	return true
func obb_overlap_center(a, b):
	var a_axes = get_axes(get_box_rotation(a))
	var b_axes = get_axes(get_box_rotation(b))

	var axes = [
		a_axes[0], a_axes[1],
		b_axes[0], b_axes[1]
	]
	
	var a_pts = get_corners(get_box_center(a), get_half_size(a), get_box_rotation(a))
	var b_pts = get_corners(get_box_center(b), get_half_size(b), get_box_rotation(b))

	var min_overlap = INF
	var best_axis = Vector2.ZERO

	for axis in axes:
		axis = axis.normalized()
		var p1 = project(a_pts, axis)
		var p2 = project(b_pts, axis)
		var overlap = min(p1.y, p2.y) - max(p1.x, p2.x)
		if overlap <= 0:
			return null
		if overlap < min_overlap:
			min_overlap = overlap
			best_axis = axis

	var dir = get_box_center(b) - get_box_center(a)
	if dir.dot(best_axis) < 0:
		best_axis = -best_axis

	return {
		"normal": best_axis,
		"depth": min_overlap,
		"center": get_box_center(a) + best_axis * (min_overlap * 0.5)
	}

func project(points, axis):
	var min_p = points[0].dot(axis)
	var max_p = min_p
	for p in points:
		var d = p.dot(axis)
		min_p = min(min_p, d)
		max_p = max(max_p, d)
	return Vector2(min_p, max_p)

func overlaps(box:CollisionBox):
	return obb_overlap(box, self)

func get_aabb():
	var old = .get_aabb()
	old["rotation"] = get_box_rotation(self)
	return null

func get_overlap_center(box:CollisionBox):
	return obb_overlap_center(box, self).center

func can_draw_box():
	if !can_draw:
		return false
	if Engine.editor_hint:
		return true
	return Global.show_hitboxes
