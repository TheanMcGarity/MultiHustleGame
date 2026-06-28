extends DefaultFireball

onready var hitbox = $Hitbox
onready var hitbox2 = $Hitbox2

func _frame_0():
	var fighter = host.get_fighter()
	if fighter and fighter.nade_explosion_in_combo:
		hitbox.grounded_hit_state = "HurtAerial"
		hitbox2.grounded_hit_state = "HurtAerial"
		

func _on_hit_something(obj, hitbox):
	if obj.is_in_group("Fighter"):
		var fighter = host.get_fighter()
		if fighter:
			fighter.nade_explosion_in_combo = true
