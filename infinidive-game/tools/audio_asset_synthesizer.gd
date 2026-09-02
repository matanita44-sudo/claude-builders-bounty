extends RefCounted

## Offline-only deterministic PCM renderer.
##
## This script lives under res://tools, which every production export preset
## excludes. The AudioManager runtime therefore contains no sample-generation
## loop and can only load immutable release assets.

const AudioDefinitions := preload("res://scripts/services/procedural_audio.gd")

const SAMPLE_RATE := AudioDefinitions.SAMPLE_RATE
const MUSIC_SAMPLE_RATE := AudioDefinitions.MUSIC_SAMPLE_RATE

func synthesize_sfx_library() -> Dictionary:
	return {
		"ui_confirm": _make_one_shot(520.0, 0.07, "sine", 240.0, 0.03, 11),
		"ui_error": _make_one_shot(180.0, 0.12, "square", -70.0, 0.04, 12),
		"player_fire": _make_one_shot(920.0, 0.045, "triangle", -520.0, 0.02, 13),
		"scatter_fire": _make_one_shot(310.0, 0.09, "noise", -120.0, 0.06, 14),
		"rail_fire": _make_one_shot(140.0, 0.2, "saw", 780.0, 0.04, 15),
		"arc_fire": _make_one_shot(680.0, 0.08, "square", 240.0, 0.025, 16),
		"orbital_hit": _make_one_shot(230.0, 0.065, "triangle", -100.0, 0.03, 17),
		"enemy_fire": _make_one_shot(150.0, 0.08, "square", 90.0, 0.025, 18),
		"armor_hit": _make_one_shot(190.0, 0.055, "noise", -90.0, 0.035, 19),
		"tissue_hit": _make_one_shot(105.0, 0.075, "sine", -45.0, 0.04, 20),
		"dash": _make_one_shot(220.0, 0.16, "noise", 740.0, 0.045, 21),
		"dash_ready": _make_motif(1.0),
		"shield_break": _make_one_shot(790.0, 0.18, "noise", -610.0, 0.06, 22),
		"breach": _make_motif(0.62),
		"dive": _make_one_shot(85.0, 0.5, "saw", 640.0, 0.065, 23),
		"heartbeat": _make_one_shot(54.0, 0.22, "sine", -8.0, 0.075, 24),
		"organ_damage": _make_one_shot(86.0, 0.12, "triangle", -28.0, 0.055, 29),
		"organ_destroyed": _make_motif(0.42),
		"mutation": _make_motif(1.35),
		"player_damage": _make_one_shot(118.0, 0.16, "square", -65.0, 0.06, 25),
		"player_death": _make_one_shot(180.0, 0.7, "saw", -145.0, 0.07, 26),
		"boss_phase": _make_motif(0.78),
		"boss_death": _make_one_shot(95.0, 1.0, "noise", -50.0, 0.08, 27),
		"pickup": _make_one_shot(660.0, 0.07, "sine", 300.0, 0.025, 28)
	}

func synthesize_music_layers(boss_id: String, state: String) -> Array:
	var canonical := _canonical_music_state(state)
	if canonical.is_empty() or (canonical != "nest" and not AudioDefinitions.BOSS_PROFILES.has(boss_id)):
		return []
	var profile: Dictionary = AudioDefinitions.NEST_PROFILE if canonical == "nest" else AudioDefinitions.BOSS_PROFILES[boss_id]
	var state_profile: Dictionary = AudioDefinitions.STATE_PROFILES[canonical]
	var result: Array[AudioStreamWAV] = []
	for layer_index in AudioDefinitions.MUSIC_LAYER_COUNT:
		result.append(_make_music_layer(profile, state_profile, canonical, layer_index))
	return result

func _canonical_music_state(state: String) -> String:
	var normalized := state.strip_edges().to_lower()
	if AudioDefinitions.MUSIC_STATE_ALIASES.has(normalized):
		normalized = String(AudioDefinitions.MUSIC_STATE_ALIASES[normalized])
	return normalized if AudioDefinitions.STATE_PROFILES.has(normalized) else ""

func _make_one_shot(frequency: float, duration: float, shape: String, slide: float, noise_mix: float, seed: int) -> AudioStreamWAV:
	var count := maxi(1, int(SAMPLE_RATE * duration))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var phase := 0.0
	for index in count:
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / maxf(duration, 0.001)
		var current_frequency := maxf(25.0, frequency + slide * progress)
		phase += TAU * current_frequency / float(SAMPLE_RATE)
		var oscillator := _wave(shape, phase, rng)
		var envelope := sin(PI * clampf(progress, 0.0, 1.0))
		envelope *= 1.0 - progress * 0.72
		var sample := oscillator * (1.0 - noise_mix) + rng.randf_range(-1.0, 1.0) * noise_mix
		bytes.encode_s16(index * 2, int(clampf(sample * envelope, -1.0, 1.0) * 32760.0))
	return _stream_from_bytes(bytes, false)

func _make_motif(speed: float) -> AudioStreamWAV:
	var duration := 0.42 / speed
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var notes := [330.0, 349.23, 233.08]
	for index in count:
		var t := float(index) / SAMPLE_RATE
		var segment := mini(2, int(t / duration * 3.0))
		var local := fmod(t, duration / 3.0) / (duration / 3.0)
		var envelope := sin(PI * local) * (0.8 if segment < 2 else 1.0)
		var sample := sin(TAU * notes[segment] * t) * envelope * 0.72
		bytes.encode_s16(index * 2, int(sample * 32760.0))
	return _stream_from_bytes(bytes, false)

func _make_music_layer(profile: Dictionary, state_profile: Dictionary, state: String, layer_index: int) -> AudioStreamWAV:
	var count := int(MUSIC_SAMPLE_RATE * 4.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	var state_index := maxi(0, AudioDefinitions.MUSIC_STATES.find(state))
	rng.seed = int(profile.get("seed", 1)) + state_index * 1009 + layer_index * 313
	var root := float(profile.get("root", 48.0)) * float(state_profile.get("pitch", 1.0))
	var bpm := float(profile.get("bpm", 80.0)) * float(state_profile.get("tempo", 1.0))
	var density := float(state_profile.get("density", 0.5))
	var tension := float(state_profile.get("tension", 0.2))
	var detune := float(profile.get("detune", 0.0))
	var noise_amount := float(profile.get("noise", 0.0))
	var intervals: Array = profile.get("intervals", [1.0, 1.5, 2.0])
	var phase_a := 0.0
	var phase_b := 0.0
	for index in count:
		var t := float(index) / float(MUSIC_SAMPLE_RATE)
		var beat_position := fmod(t * bpm / 60.0, 1.0)
		var edge_fade := minf(1.0, minf(t * 36.0, (4.0 - t) * 36.0))
		var sample := 0.0
		match layer_index:
			0:
				var wobble := 1.0 + sin(TAU * 0.25 * t) * detune
				phase_a += TAU * root * wobble / float(MUSIC_SAMPLE_RATE)
				phase_b += TAU * root * (1.5 + detune) / float(MUSIC_SAMPLE_RATE)
				var primary := _wave(String(profile.get("wave", "sine")), phase_a, rng)
				sample = primary * 0.31 + sin(phase_b) * (0.12 + tension * 0.05)
				sample += rng.randf_range(-1.0, 1.0) * noise_amount * (0.35 + tension)
			1:
				var pulse_envelope := exp(-beat_position * lerpf(11.0, 6.0, density))
				var sub := sin(TAU * root * 0.5 * t)
				var tick := rng.randf_range(-1.0, 1.0) * noise_amount * 2.2
				sample = (sub * 0.38 + tick) * pulse_envelope * density
				if state in ["interior", "organ"]:
					var second_beat := exp(-fmod(beat_position + 0.42, 1.0) * 14.0)
					sample += sin(TAU * root * 0.75 * t) * second_beat * 0.13
			2:
				var step_rate := lerpf(1.0, 3.5, density)
				var step := int(floor(t * step_rate))
				var note_index := step % intervals.size()
				if state == "victory":
					note_index = mini(intervals.size() - 1, step)
				var note_frequency := root * float(intervals[note_index])
				var local_step := fmod(t * step_rate, 1.0)
				var motif_envelope := pow(maxf(0.0, sin(PI * local_step)), 2.0)
				if state == "low_health":
					motif_envelope *= 1.0 if int(floor(t * 4.0)) % 4 < 2 else 0.18
				var identity_note := sin(TAU * note_frequency * (1.0 + detune) * t)
				var tense_note := sin(TAU * note_frequency * 1.414214 * t) * tension
				sample = (identity_note * 0.30 + tense_note * 0.11) * motif_envelope
		sample *= edge_fade * 0.78
		bytes.encode_s16(index * 2, int(clampf(sample, -0.88, 0.88) * 32760.0))
	var stream := _stream_from_bytes(bytes, true)
	stream.mix_rate = MUSIC_SAMPLE_RATE
	stream.loop_begin = 0
	stream.loop_end = count
	return stream

func _wave(shape: String, phase: float, rng: RandomNumberGenerator) -> float:
	match shape:
		"square": return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle": return asin(sin(phase)) * 2.0 / PI
		"saw": return 2.0 * (phase / TAU - floor(phase / TAU + 0.5))
		"noise": return rng.randf_range(-1.0, 1.0)
		_: return sin(phase)

func _stream_from_bytes(bytes: PackedByteArray, should_loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	return stream
