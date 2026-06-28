extends BaseProjectile

const ACID_BUBBLE_SCENE = preload("res://characters/mutant/projectiles/PoisonAcidBubble.tscn")
const NUM_ACID_BUBBLES = 1
const ACID_BUBBLE_SPEED = "17"
const STARTUP = 16

onready var poison_particle = $Flip/Particles/PoisonParticle
onready var poison_particle_2 = $Flip/Particles/PoisonParticle2

var spawn_acid_bubble_startup = STARTUP

func init(pos=null):
	.init(pos)
#	get_fighter().opponent.connect("got_hit_by_fighter", self, "on_opponent_hit")
#	get_fighter().opponent.connect("blocked_melee_attack", self, "on_opponent_hit")

func spawn_bubbles():
	for i in range((NUM_ACID_BUBBLES)):
		var projectile = spawn_object(ACID_BUBBLE_SCENE, 0, 0)
		var randangle = fixed_deg_to_rad(randi_static() % 360)
		var randdir = fixed.angle_to_vec(randangle)

		var force = fixed.normalized_vec_times(randdir.x, randdir.y, ACID_BUBBLE_SPEED)
		var opp_vel = get_fighter().opponent.get_vel()
		projectile.set_vel(opp_vel.x, opp_vel.y)
		projectile.apply_force(force.x, force.y)

func tick():
	if current_tick == 1:
		spawn_acid_bubble_startup = 36
		
	.tick()
	if get_fighter().opponent.combo_count > 0 and !get_opponent().current_state().get("IS_BURST"):
		disable()
		return

	if current_tick >= 360:
		disable()
		return

	if spawn_acid_bubble_startup > 0:
		spawn_acid_bubble_startup -= 1
		if spawn_acid_bubble_startup <= 0:
			spawn_acid_bubble_startup = 0
			spawn_bubbles()
			spawn_acid_bubble_startup = STARTUP
