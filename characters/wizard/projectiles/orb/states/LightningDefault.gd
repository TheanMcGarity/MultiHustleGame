extends ObjectState

const UNLOCKED_DAMAGE = 100
const LOCKED_DAMAGE = 110

onready var hitbox = $Hitbox

func _enter():
	var locked = host.creator and !host.creator.disabled and host.creator.locked
	hitbox.damage = LOCKED_DAMAGE if locked else UNLOCKED_DAMAGE
	hitbox.damage_in_combo = LOCKED_DAMAGE if locked else UNLOCKED_DAMAGE

func _exit():
	host.disable()
	host.hide()
