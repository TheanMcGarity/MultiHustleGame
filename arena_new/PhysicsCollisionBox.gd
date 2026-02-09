tool

extends SolidBox

class_name PhysicsBoxBasic

func get_overlap_normal(box:CollisionBox) -> Vector2:
	return _overlap_normal(self, box) 
func _overlap_normal(a, b) -> Vector2:
	var dx = (a.x + a.width / 2) - (b.x + b.width / 2);
	var dy = (a.y + a.height / 2) - (b.y + b.height / 2);
	var combined_half_widths = a.width / 2 + b.width / 2;
	var combined_half_heights = a.height / 2 + b.height / 2;
	var overlap_x = combined_half_widths - abs(dx);
	var overlap_y = combined_half_heights - abs(dy);
	if (overlap_x < overlap_y):
		return Vector2(sign(dx), 0); 
	else:
		return Vector2(0, sign(dy)); 
