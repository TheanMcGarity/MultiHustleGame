extends BaseProjectile

class_name TelekinesisProjectile

var launched = false

export(PackedScene) var disable_obj
export(PackedScene) var disable_particle
export var rumble = true
export var no_hitlag = true

func disable():
	disable_action()

	if disable_obj:
		var obj = disable_obj
		var pos = get_pos()
		spawn_object(obj, 0, 0)
	
	if disable_particle:
		spawn_particle_effect_relative(disable_particle)

	.disable()
	if creator:
		if creator.boulder_projectile == obj_name:
			creator.boulder_projectile = null

func disable_action():
	if rumble:
		var camera: GoodCamera = get_camera()
		if camera:
			camera.bump(Vector2(), 10, 0.25)

func hit_action(obj):
	pass

func tick():
	.tick()
	if no_hitlag:
		hitlag_ticks = 0

func drop():
	if current_state().name == "Default":
		current_state().drop()

func launch(data):
#	if current_state().name == "Default":
	state_machine.queue_state("Launch", data)

func launch_redirect(data):
	# Identical to launch() except the boulder's hitbox comes out 2 frames
	# later — defined as its own state rather than gated in BoulderFling so
	# the timing is encoded in the .tscn instead of mixed into the script.
	state_machine.queue_state("LaunchRedirect", data)
