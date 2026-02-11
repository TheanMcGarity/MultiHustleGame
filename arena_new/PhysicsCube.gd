extends BaseGround

const MIN_SPEED: float = 0.0001

onready var physics_col:PhysicsBoxBasic = $SolidBox
onready var gravity_f:float = float(gravity)

export var _c_PhysicsData = 0

export(Vector2) var starting_velocity = Vector2.ZERO

var vel = Vector2.ZERO setget _set_vel, _get_vel
var gravity_modifier:float = 1
var accel = {"x":"0","y":"0"}

var collision_centers := []
var object_collisions := []
var set_init_vel := false
func copy_to(o):
	.copy_to(o)
	o.gravity_modifier = gravity_modifier
	#o.set_init_vel = set_init_vel
	#var pos = get_pos()
	#o.set_pos(str(pos.x), str(pos.y))
	#var vel = get_vel()
	#o.set_vel(str(vel.x), str(vel.y))
	#assert(false, str({
	#	"copy_vel": o.get_vel(),
	#	"vel": vel,
	#	"pos": pos,
	#	"copy_pos": o.get_pos()
	#}))
	o.accel = accel
	#o.gravity_f = gravity_f

func init(pos = null):
	if not is_ghost:
		set_pos(str(position.x), str(position.y))
	.init(pos)
	#if (not set_init_vel):
	#	set_vel(str(starting_velocity.x), str(starting_velocity.y))
	#	set_init_vel = true

func tick():
	.tick()
	if not initialized:
		return
	#is_touching_floor()
	detect_collisions()
	#snap_to_floor()
	handle_collisions()
	apply_grav()
	apply_fric()
	apply_forces()

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

func detect_collisions():
	var self_center = Vector2(
		fixed.add(str(physics_col.x), fixed.div(str(physics_col.width), "2")),
		fixed.add(str(physics_col.y), fixed.div(str(physics_col.height), "2"))
	)
	self_center = fixed.vec_add(str(self_center.x),str(self_center.y), str(position.x),str(position.y))
	
	for collision_data in collision_centers:
		var collision = collision_data.collider
		var half_w = fixed.div(physics_col.width, 2)
		var half_h = fixed.div(physics_col.height, 2)
		var col_half_w = fixed.div(collision.width, 2)
		var col_half_h = fixed.div(collision.height, 2)
		
		var diff = self_center - collision.position
		var overlap_x = fixed.sub(fixed.add(half_w, col_half_w), fixed.abs(diff.x))
		var overlap_y = fixed.sub(fixed.add(half_h, col_half_h), fixed.abs(diff.y))
		
		if overlap_x > 0 and overlap_y > 0:
			if overlap_x < overlap_y:
				position.x = fixed.add(position.x, fixed.mul(overlap_x, fixed.sign(diff.x)))
			else:
				position.y = fixed.add(position.y, fixed.mul(overlap_y, fixed.sign(diff.y)))
				set_vel(vel.x, str(0))
				_is_grounded = diff.y < 0
	
	object_collisions = []
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
			
		if (col == physics_col):
			continue
		var overlap = physics_col.overlaps(col)
		if (overlap):
			object_collisions.append([col, _get_side_from_normal(physics_col.get_overlap_normal(col))])

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
func _get_vel():
	return get_vel()

func apply_grav() -> void:
	if not _is_grounded and float(vel.y) < float(max_fall_speed):
		apply_force("0.0", mul(gravity, str(gravity_modifier)))


func apply_grav_custom(gravity_val: String, fall_speed: String) -> void:
	if not _is_grounded and vel.y < float(fall_speed):
		apply_force("0.0", mul(gravity_val, gravity_modifier))


func apply_forces() -> void:
	var vel = get_vel()
	
	if _is_grounded:
		if float(vel.y) >= 0:
			#set_vel(mul(max_ground_speed, sign_f(vel.x)), vel.y)
			vel.y = "0"
	
	vel = vec_add2(vel, accel)
	
	if _is_grounded:
		if float(abs_f(vel.x)) > float(max_ground_speed):
			#set_vel(mul(max_ground_speed, sign_f(vel.x)), vel.y)
			vel.x = mul(max_ground_speed, sign_f(vel.x))
	else:
		if float(abs_f(vel.x)) > float(max_air_speed):
			vel.x = mul(max_air_speed, sign_f(vel.x))
			#set_vel(mul(max_air_speed, sign_f(vel.x)), vel.y)

		if float(vel.y) > float(max_fall_speed):
			vel.y = max_fall_speed
			#set_vel(str(vel.x), max_fall_speed)

	move_directly(vel.x,vel.y)
	update_grounded()

	#if _is_grounded and float(vel.y) > 0.0:
	#	vel.y = "0.0"

	#if float(fixed.vec_len(vel.x, vel.y)) < MIN_SPEED:
	#	vel = {"x":"0","y":"0"}
	
	if float(abs_f(vel.x)) < MIN_SPEED:
		vel.x = "0"
	if float(abs_f(vel.y)) < MIN_SPEED:
		vel.y = "0"
	set_vel(vel.x,vel.y)
	accel = {"x":"0","y":"0"}
	
func apply_force(x, y) -> void:
	accel = vec_add(accel.x, accel.y, x, y)
func apply_force_vec(vec):
	accel = vec_add2(accel, vec)
func move_directly(x, y):
	.move_directly(x, y)
	#position += Vector2(float(x),float(y))
	var pos = get_pos()
	position = Vector2(float(pos.x), float(pos.y))

func handle_collisions():
	var grounded_to_origin = float(get_pos().y) >= 0
	_is_grounded = grounded_to_origin
	for col in object_collisions:
		if col[1] == 4:
			_is_grounded = true
		move_away_from_collision(col[0], col[1])
	if (_is_grounded):
		var y_vel = div(get_vel().y, 5)
		y_vel = mul(y_vel, mul(bounciness, 1.5))
		if (grounded_to_origin):
			set_pos(str(get_pos().x), "0")
		set_vel(str(get_vel().x), mul(-1, abs_f(y_vel)))


func move_away_from_wall(wall_col, dir):
	return

func move_away_from_collision(wall_col, dir):
	if (not is_instance_valid(wall_col)):
		return
	var wall = wall_col.get_parent()
	match dir:
		2:
			# probably overusing str() but dont want errors so ill keep it until this needs to be changed again
			var x_vel = fixed.div(str(get_vel().x), "2.5")
			x_vel = fixed.add(str(x_vel), str(movement_velocity.x))
			x_vel = fixed.mul(str(x_vel), str(wall.bounciness))
			x_vel = fixed.mul(str(x_vel), str(bounciness))
			set_pos(str(wall_col.get_aabb().x1 - physics_col.width), str(get_pos().y))
			set_vel(str(fixed.mul(fixed.abs(str(x_vel)), "-1")), str(get_vel().y))
		1:
			var x_vel = fixed.div(str(get_vel().x), "2.5")
			x_vel = fixed.add(str(x_vel), str(movement_velocity.x))
			x_vel = fixed.mul(str(x_vel), str(wall.bounciness))
			x_vel = fixed.mul(str(x_vel), str(bounciness))
			set_pos(str(wall_col.get_aabb().x2 + physics_col.width), str(get_pos().y))
			set_vel(str(fixed.abs(x_vel)), str(get_vel().y))
		3:
			var y_vel = fixed.div(str(get_vel().y), "2.5")
			y_vel = fixed.add(str(y_vel), str(movement_velocity.y))
			y_vel = fixed.mul(str(y_vel), str(wall.bounciness))
			y_vel = fixed.mul(str(y_vel), str(bounciness))
			set_pos(str(get_pos().x), fixed.sub(str(wall_col.get_aabb().y2), fixed.mul(str(physics_col.height), "2")))
			set_vel(str(get_vel().x), str(fixed.abs(str(y_vel))))
		#4:
		#	#if (not is_ghost):
		#	#	print("on top of smth idk (%s on %s)" % [name, wall.name])
		#	var y_vel = fixed.div(str(get_vel().y), "6")
		#	y_vel = fixed.add(str(y_vel), str(movement_velocity.y))
		#	y_vel = fixed.mul(str(y_vel), str(wall.bounciness))
		#	y_vel = fixed.mul(str(y_vel), str(bounciness))
			set_pos(str(get_pos().x), fixed.add(str(wall_col.get_aabb().y1), fixed.mul(str(physics_col.height), "2")))
		#	set_vel(str(get_vel().x), str(fixed.mul(fixed.abs(str(y_vel)), "-1")))
