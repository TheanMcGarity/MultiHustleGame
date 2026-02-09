extends BaseGround

const MIN_SPEED: float = 0.0001

onready var physics_col:PhysicsBoxBasic = $SolidBox

var vel = Vector2.ZERO setget _set_vel, get_vel
var gravity_modifier:float = 1
var accel:Vector2

onready var gravity_f:float = float(gravity)

var collision_centers := []

func copy_to(o):
	#.copy_to(o)
	o.vel = vel
	o.gravity_modifier = gravity_modifier
	o.accel = accel
	o.gravity_f = gravity_f

func tick():
	.tick()
	if not initialized:
		return
	is_touching_floor()
	apply_grav()
	apply_fric()
	apply_forces()
	apply_collisions()
	#snap_to_floor()

func snap_to_floor():
	var game = get_game()
	if not is_instance_valid(game):
		return
	var solids = game.solids
	for solid in solids:
		if not is_instance_valid(solid):
			continue
		var col:SolidBox = solid.get_node("SolidBox")
		
		if not is_instance_valid(col):
			continue
		var pos = position
		pos.x = pos.x - (physics_col.width / 2)
		pos.y = pos.y + .1
		print(pos)
		if (col.overlaps_on_point(pos)):
			position.y = col.get_aabb().y1
			print("snap")
		else:
			print("no ):")

func apply_collisions():
	var self_center = Vector2(
		physics_col.x + physics_col.width / 2,
		physics_col.y + physics_col.height / 2
	)
	self_center += position
	
	for collision_data in collision_centers:
		print("apply")
		var collision = collision_data.collider
		var half_w = physics_col.width / 2
		var half_h = physics_col.height  / 2
		var col_half_w = collision.width
		var col_half_h = collision.height / 2
		
		var diff = self_center - collision.position
		var overlap_x = (half_w + col_half_w) - abs(diff.x)
		var overlap_y = (half_h + col_half_h) - abs(diff.y)
		
		if overlap_x > 0 and overlap_y > 0:
			if overlap_x < overlap_y:
				position.x += overlap_x * sign(diff.x)
			else:
				position.y += overlap_y * sign(diff.y)
				vel.y = 0
				_is_grounded = diff.y < 0
func is_touching_floor():
	collision_centers = []
	var game = get_game()
	if not is_instance_valid(game):
		return
	var solids = game.solids
	for solid in solids:
		if not is_instance_valid(solid):
			continue
		var col:SolidBox = solid.get_node("SolidBox")
		
		if not is_instance_valid(col):
			continue
			
		if (col == self):
			continue
		
		var overlap = physics_col.overlaps(col)
		print(overlap)
		if (physics_col.overlaps(col)):
			collision_centers.append({
				"collider": col,
				"center": physics_col.get_overlap_center(col)
			})

func set_gravity_modifier(modifier: String):
	chara.set_gravity_modifier(modifier)
	
func _set_gravity_modifier(modifier):
	chara.set_gravity_modifier(modifier)
	gravity_modifier = modifier
	
func _set_vel(value):
	chara.set_vel(str(value.x), str(value.y))
	vel = value
func get_vel():
	return vel
func set_vel(x,y):
	vel = Vector2(x,y)

func apply_grav() -> void:
	if not _is_grounded and vel.y < float(max_fall_speed):
		apply_force_vec(Vector2(0.0, gravity_f * gravity_modifier))


func apply_grav_custom(gravity_val: String, fall_speed: String) -> void:
	if not _is_grounded and vel.y < float(fall_speed):
		apply_force_vec(Vector2(0.0, float(gravity_val) * gravity_modifier))


func apply_forces() -> void:
	vel += accel

	if _is_grounded:
		if abs(vel.x) > float(max_ground_speed):
			vel.x = float(max_ground_speed) * sign(vel.x)
	else:
		if abs(vel.x) > float(max_air_speed):
			vel.x = float(max_air_speed) * sign(vel.x)

		if vel.y > float(max_fall_speed):
			vel.y = float(max_fall_speed)

	move_directly(vel.x,vel.y)
	update_grounded()

	if _is_grounded and vel.y > 0.0:
		vel.y = 0.0

	if vel.length() < MIN_SPEED:
		vel = Vector2.ZERO

	accel = Vector2.ZERO
	
func apply_force(x, y) -> void:
	apply_force_vec(Vector2(x,y))
func apply_force_vec(vec):
	accel += vec
func move_directly(x, y):
	.move_directly(x, y)
	position += Vector2(float(x),float(y))
