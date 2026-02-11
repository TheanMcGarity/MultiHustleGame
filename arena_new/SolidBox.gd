tool

extends CollisionBox

class_name SolidBox

func get_aabb():
	var local = .get_aabb()
	local.x1 += get_parent().position.x
	local.x2 += get_parent().position.x
	local.y1 += get_parent().position.y
	local.y2 += get_parent().position.y
	return local

func overlaps_on_point(pos) -> bool:
	var aabb = get_aabb()
	if (aabb.x1 <= pos.x and aabb.x2 >= pos.x) and (aabb.y1 <= pos.y and aabb.y2 >= pos.y):
		#print(str(pos) + " true " + str(aabb))
		return true
	
	#print(str(pos) + " false " + str(aabb))
	return false
func point_and_top_overlap(pos) -> bool:
	var aabb = get_aabb()
	if (aabb.x1 <= pos.x and aabb.x2 >= pos.x) and (aabb.y1 <= pos.y and aabb.y1 - 2 >= pos.y):
		#print(str(pos) + " true " + str(aabb))
		return true
	
	#print(str(pos) + " false " + str(aabb))
	return false
	
func pos_to_x_side(max_dist, pos) -> int:
	var aabb = get_aabb()
	if (aabb.x1 <= pos.x and aabb.x1 + max_dist >= pos.x):
		return 1
	if (aabb.x2 >= pos.x and aabb.x2 - max_dist <= pos.x):
		return 2
	
	return 0


func get_overlap_normal(box:CollisionBox) -> Vector2:
	return _overlap_normal(self.get_aabb(), box.get_aabb()) 
func _overlap_normal(a, b) -> Vector2:
	var left = b.x2 - a.x1
	var right = a.x2 - b.x1
	var top = b.y2 - a.y1
	var bottom = a.y2 - b.y1
	
	#print([left, right, top, bottom])
	var minimum = _min_array([left, right, top, bottom])
	#print(minimum)
	if (minimum == left):
		return Vector2(-1,0)
	if (minimum == right):
		return Vector2(1,0)
	if (minimum == top):
		return Vector2(0,-1)
	else:
		return Vector2(0,1)

func _min_array(numbers:Array):
	var smallest = 9223372036854775807
	for number in numbers:
		if (number < smallest):
			smallest = number
	return smallest
export var force_draw := false
func can_draw_box():
	
	return force_draw and Engine.editor_hint
