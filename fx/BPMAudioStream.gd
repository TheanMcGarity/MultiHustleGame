extends AudioStreamPlayer
class_name BPMCalculatorAudioStream

const BAND_EDGES = [100.0, 200.0, 400.0, 800.0, 1600.0, 3200.0, 6400.0, 12000.0]
const MIN_FLUX = 0.0008
const MIN_BEAT_INTERVAL = 0.1

var spectrum: AudioEffectSpectrumAnalyzerInstance
var threshold_multiplier := 1.5
var flux_average := 0.0
var average_speed := 2.0

var _prev_band_energy := []
var _was_playing := false
var _prev_raw_flux := 0.0
var _prev_smoothed_flux := 0.0
var _rising := false

var _last_beat_detected_time := 0.0
var last_beat_detected_energy := 0.0
var last_beat_detected_seconds := 0.0

func _ready():
	var index = AudioServer.get_bus_index("GhostBPM")
	spectrum = AudioServer.get_bus_effect_instance(index, 1)
	for i in BAND_EDGES.size() - 1:
		_prev_band_energy.append(0.0)

func _process(delta: float) -> void:
	if not (is_instance_valid(spectrum) and playing):
		_was_playing = false
		return

	if not _was_playing:
		for i in BAND_EDGES.size() - 1:
			var mag = spectrum.get_magnitude_for_frequency_range(
				BAND_EDGES[i], BAND_EDGES[i + 1], AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
			)
			_prev_band_energy[i] = mag.length()
		_was_playing = true
		_prev_raw_flux = 0.0
		_prev_smoothed_flux = 0.0
		_rising = false
		return

	var flux := 0.0
	for i in BAND_EDGES.size() - 1:
		var mag = spectrum.get_magnitude_for_frequency_range(
			BAND_EDGES[i], BAND_EDGES[i + 1], AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
		)
		var energy = mag.length()
		var diff = energy - _prev_band_energy[i]
		if diff > 0.0:
			flux += diff
		_prev_band_energy[i] = energy

	# Light 2-frame smoothing so single-frame analyzer jitter doesn't
	# register as its own little peak.
	var smoothed_flux = (flux + _prev_raw_flux) * 0.5
	_prev_raw_flux = flux

	var dynamic_threshold = flux_average * threshold_multiplier
	var is_rising = smoothed_flux > _prev_smoothed_flux

	if _rising and not is_rising:
		var peak_value = _prev_smoothed_flux
		if peak_value > dynamic_threshold and peak_value >= MIN_FLUX:
			_on_beat_detected(peak_value)

	_rising = is_rising
	_prev_smoothed_flux = smoothed_flux
	flux_average = lerp(flux_average, smoothed_flux, delta * average_speed)

func _on_beat_detected(energy):
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_beat_detected_time < MIN_BEAT_INTERVAL:
		return
	print("Onset detected at: %f with %f energy" % [get_playback_position(), energy])
	last_beat_detected_seconds = now - _last_beat_detected_time
	_last_beat_detected_time = now
	last_beat_detected_energy = energy
