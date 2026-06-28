extends AudioStreamPlayer2D

class_name VariableSound2D

export var pitch_variation = 0.1
export var one_shot = false
export var streams: Array = []

# overrides sfx with all the same params
export var override_same_sfx = false

# overrides sfx with the same *sound*, regardless of params
export var override_same_wav = false

var pitch_scale_ = 0.0

var rng = BetterRng.new()

var _override_sfx_key = ""
var _override_wav_key = ""

func _ready():
	rng.randomize()
	pitch_scale_ = pitch_scale
	if autoplay:
		play()
	if one_shot:
		connect("finished", self, "queue_free")
	if override_same_sfx or override_same_wav:
		refresh_override_keys()

func refresh_override_keys():
	if stream:
		_override_wav_key = stream.resource_path
		_override_sfx_key = _override_wav_key + "|" + str(volume_db) + "|" + str(pitch_variation)
	else:
		_override_wav_key = ""
		_override_sfx_key = ""

func _override_register_and_stop(key: String):
	var prev = Global.active_sfx_overrides.get(key)
	if prev != null and is_instance_valid(prev) and prev != self and prev.playing:
		prev.stop()
	Global.active_sfx_overrides[key] = self

# Called when the node enters the scene tree for the first time.
func play(p=0.0):
	var override_active = override_same_sfx or override_same_wav
	if len(streams) > 0:
		var picked = rng.choose(streams)
		if picked != stream:
			stream = picked
			if override_active:
				refresh_override_keys()
	if override_active and stream and _override_wav_key == "":
		refresh_override_keys()
	pitch_scale = pitch_scale_ + rng.randf_range(-pitch_variation, pitch_variation)
	if stream:
		if override_same_wav:
			_override_register_and_stop(_override_wav_key)
		if override_same_sfx:
			_override_register_and_stop(_override_sfx_key)
	.play(p)
