extends CharacterState

export var _c_Boost_Settings = 0
onready var hitbox = $TeamBoostHitbox
export var boost_strength:int = 1

export(String, MULTILINE) var hitstun_requirement := "disallow\nallow_only"

func is_usable():
	return .is_usable() and host.team != 0

func get_hitstun_mode()->int:
	var ret = 0
	if "disallow" in hitstun_requirement:
		ret += 1
	if "allow_only" in hitstun_requirement:
		ret += 2
	return ret

func is_char_hitstun_allowed(chara)->bool:
	var hitstun_mode := get_hitstun_mode()
	
	
	var hitstun_amount = 0
	if "hitstun_ticks" in chara.current_state():
		hitstun_amount = chara.current_state().hitstun_ticks
	
	match hitstun_mode:
		1:
			return hitstun_amount < 1
		2:
			return hitstun_amount > 1
		3:
			return true
		_:
			assert("Invalid hitstun_mode! mode="+str(hitstun_mode))
	return false

func _add_vec(vec1, vec2):
	return {
		"x": float(vec1.x) + float(vec2.x),
		"y": float(vec1.y) + float(vec2.y)
	}
func _multiply_vec(vec1, vec2:Dictionary):
	return {
		"x": float(vec1.x) * float(vec2.x),
		"y": float(vec1.y) * float(vec2.y)
	}
func _multiply_vec_f(vec1, m):
	return {
		"x": float(vec1.x) * m,
		"y": float(vec1.y) * m
	}

func _get_host_game():
	var node = host
	while node:
		if "Game" in node.name:
			return node
		node = node.get_parent()
	return Network.game


func _frame_0():
	
	var vec = xy_to_dir(data["x"], data["y"], "1")
	var game = _get_host_game()
	for team_member in Network.teams[host.team]:
		var chara = game.players[team_member]
		if chara.id != host.id:
			if (overlaps(hitbox, chara.collision_box) and is_char_hitstun_allowed(chara)):
				#print("overlap")
				var final_vec = _multiply_vec_f(vec, boost_strength)
				var vel = _add_vec(final_vec, chara.get_vel())
				chara.set_vel(vel.x, vel.y)
				#print(vel)
				
func overlaps(box, other):
	if box.width == 0 and box.height == 0:
		return false
	if other.width == 0 and other.height == 0:
		return false
	if get("IS_SWEPT") or box.get("IS_SWEPT"):
		return false

	var aabb1 = other.get_aabb()
	var aabb2 = box.get_aabb()
	return !(aabb1.x1 > aabb2.x2 or aabb1.x2 < aabb2.x1 or aabb1.y1 > aabb2.y2 or aabb1.y2 < aabb2.y1)

