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
