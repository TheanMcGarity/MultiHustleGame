tool

extends CollisionBox

class_name SolidBox

var fixed = FixedMath.new()

func get_aabb():
	var local = .get_aabb()
	if (not get_parent().initialized):
		return local
	local.x1 = float(fixed.add(str(local.x1), str(get_parent().get_pos().x)))
	local.x2 = float(fixed.add(str(local.x2), str(get_parent().get_pos().x)))
	local.y1 = float(fixed.add(str(local.y1), str(get_parent().get_pos().y)))
	local.y2 = float(fixed.add(str(local.y2), str(get_parent().get_pos().y)))
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
	var left = int(fixed.sub(str(b.x2),str(a.x1)))
	var right = int(fixed.sub(str(a.x2),str(b.x1)))
	var top = int(fixed.sub(str(b.y2),str(a.y1)))
	var bottom = int(fixed.sub(str(a.y2),str(b.y1)))
	
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
	if (force_draw and Engine.editor_hint):
		return true
	return .can_draw_box()
