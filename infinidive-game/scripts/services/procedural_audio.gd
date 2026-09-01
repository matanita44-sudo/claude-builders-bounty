extends Node

const SAMPLE_RATE := 22050
const MUSIC_SAMPLE_RATE := 11025
const POOL_SIZE := 12
const MUSIC_LAYER_COUNT := 3
const MUSIC_CACHE_LIMIT := 8
const DEFAULT_BOSS_ID := "gravemaw"

const REQUIRED_SFX_IDS := [
	"ui_confirm", "ui_error", "player_fire", "scatter_fire", "rail_fire",
	"arc_fire", "orbital_hit", "enemy_fire", "armor_hit", "tissue_hit",
	"dash", "dash_ready", "shield_break", "breach", "dive", "heartbeat",
	"organ_damage", "organ_destroyed", "mutation", "player_damage",
	"player_death", "boss_phase", "boss_death", "pickup"
]

const MUSIC_STATES := [
	"nest", "exterior", "breach", "dive", "interior", "organ",
	"low_health", "core", "victory"
]

const MUSIC_STATE_ALIASES := {
	"inside": "interior",
	"organ_chamber": "organ",
	"low-health": "low_health"
}

# Distinct register, tempo, intervals and timbre for every launch colossus.
const BOSS_PROFILES := {
	"gravemaw": {
		"root": 41.0, "bpm": 70.0, "wave": "saw", "seed": 4101,
		"intervals": [1.0, 1.5, 2.0, 2.25], "detune": 0.004,
		"noise": 0.055, "sfx_pitch": 0.88
	},
	"seraph_9": {
		"root": 54.0, "bpm": 96.0, "wave": "triangle", "seed": 5909,
		"intervals": [1.0, 1.25, 1.5, 2.5], "detune": 0.0015,
		"noise": 0.012, "sfx_pitch": 1.12
	},
	"abyss_leviathan": {
		"root": 36.0, "bpm": 78.0, "wave": "sine", "seed": 7303,
		"intervals": [1.0, 1.333333, 1.777778, 2.0], "detune": 0.012,
		"noise": 0.035, "sfx_pitch": 0.76
	},
	"null_twin": {
		"root": 58.0, "bpm": 108.0, "wave": "square", "seed": 8807,
		"intervals": [1.0, 1.414214, 2.0, 2.02], "detune": 0.021,
		"noise": 0.025, "sfx_pitch": 1.04
	}
}

# Three gains correspond to bed, pulse and signal layers.
const STATE_PROFILES := {
	"nest": {"pitch":0.80,"tempo":0.55,"density":0.18,"tension":0.05,"layers":[0.64,0.06,0.12],"transition":0.80},
	"exterior": {"pitch":1.00,"tempo":1.00,"density":0.58,"tension":0.28,"layers":[0.50,0.28,0.16],"transition":0.45},
	"breach": {"pitch":1.08,"tempo":1.15,"density":0.82,"tension":0.62,"layers":[0.46,0.36,0.28],"transition":0.20},
	"dive": {"pitch":0.67,"tempo":1.35,"density":0.72,"tension":0.74,"layers":[0.58,0.24,0.30],"transition":0.12},
	"interior": {"pitch":0.76,"tempo":0.82,"density":0.42,"tension":0.44,"layers":[0.62,0.22,0.17],"transition":0.38},
	"organ": {"pitch":0.88,"tempo":1.08,"density":0.70,"tension":0.66,"layers":[0.55,0.34,0.23],"transition":0.25},
	"low_health": {"pitch":0.94,"tempo":1.25,"density":0.86,"tension":0.92,"layers":[0.40,0.34,0.38],"transition":0.18},
	"core": {"pitch":1.18,"tempo":1.22,"density":0.92,"tension":0.82,"layers":[0.56,0.40,0.34],"transition":0.30},
	"victory": {"pitch":1.46,"tempo":0.72,"density":0.34,"tension":0.04,"layers":[0.50,0.12,0.42],"transition":0.55}
}

const NEST_PROFILE := {
	"root":48.0,"bpm":62.0,"wave":"sine","seed":1701,
	"intervals":[1.0,1.25,1.5,2.0],"detune":0.002,"noise":0.010,"sfx_pitch":1.0
}

const BOSS_COLORED_SFX := {
	"enemy_fire":true,"breach":true,"dive":true,"heartbeat":true,
	"organ_damage":true,"organ_destroyed":true,"boss_phase":true,"boss_death":true
}

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_tween: Tween
var _music_state := ""
var _music_intensity := 0.5
var _music_intensity_bucket := -1
var _boss_id := DEFAULT_BOSS_ID
var _music_cache: Dictionary = {}
var _cache_order: Array[String] = []
var _audio_available := true

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_audio_available = false
		return
	_ensure_buses()
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFX%02d" % index
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	for layer_index in MUSIC_LAYER_COUNT:
		var music_player := AudioStreamPlayer.new()
		music_player.name = "AdaptiveMusicLayer%d" % layer_index
		music_player.bus = "Music"
		add_child(music_player)
		_music_players.append(music_player)
	_build_library()
	if not SettingsManager.setting_changed.is_connected(_on_setting_changed):
		SettingsManager.setting_changed.connect(_on_setting_changed)
	SettingsManager.apply_all()

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _build_library() -> void:
	_sfx = {
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

func play_sfx(id: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	if not _audio_available or not _sfx.has(id) or _players.is_empty() or not _sfx_output_enabled():
		return
	var player := _players[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _players.size()
	player.stop()
	player.stream = _sfx[id]
	var identity_pitch := 1.0
	if BOSS_COLORED_SFX.has(id):
		identity_pitch = float(BOSS_PROFILES[_boss_id].get("sfx_pitch", 1.0))
	player.pitch_scale = clampf(pitch * identity_pitch, 0.65, 1.5)
	player.volume_db = linear_to_db(maxf(volume, 0.001))
	player.play()

## Select the tonal identity after RunScene has resolved boss_definition.
## Invalid IDs fail safely to GRAVEMAW and report false to the caller.
func set_boss_identity(boss_id: String) -> bool:
	var accepted := BOSS_PROFILES.has(boss_id)
	var next_id := boss_id if accepted else DEFAULT_BOSS_ID
	if next_id == _boss_id:
		return accepted
	_boss_id = next_id
	if not _music_state.is_empty() and _music_state != "nest" and _audio_available:
		var active_state := _music_state
		var active_intensity := _music_intensity
		_music_state = ""
		_music_intensity_bucket = -1
		set_music_state(active_state, active_intensity)
	return accepted

func get_boss_identity() -> String:
	return _boss_id

func set_music_state(state: String, intensity: float = 0.5) -> void:
	var canonical := _canonical_music_state(state)
	if canonical.is_empty():
		return
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	var bucket := int(round(clamped_intensity * 10.0))
	var unchanged := canonical == _music_state and bucket == _music_intensity_bucket
	_music_state = canonical
	_music_intensity = clamped_intensity
	_music_intensity_bucket = bucket
	if not _audio_available or _music_players.is_empty() or not _music_output_enabled():
		return
	if unchanged and _music_is_playing():
		return
	_start_music_state(canonical, clamped_intensity, bucket)

func get_music_state() -> String:
	return _music_state

func _canonical_music_state(state: String) -> String:
	var normalized := state.strip_edges().to_lower()
	if MUSIC_STATE_ALIASES.has(normalized):
		normalized = String(MUSIC_STATE_ALIASES[normalized])
	return normalized if STATE_PROFILES.has(normalized) else ""

func _start_music_state(state: String, intensity: float, intensity_bucket: int) -> void:
	if is_instance_valid(_music_tween):
		_music_tween.kill()
	var streams := _get_or_build_music_layers(_boss_id, state, intensity_bucket)
	var layer_gains: Array = STATE_PROFILES[state].get("layers", [0.5, 0.2, 0.15])
	var transition := float(STATE_PROFILES[state].get("transition", 0.35))
	_music_tween = create_tween().set_parallel(true)
	for layer_index in MUSIC_LAYER_COUNT:
		var player := _music_players[layer_index]
		player.stop()
		player.stream = streams[layer_index]
		player.volume_db = -60.0
		player.play()
		var gain := float(layer_gains[layer_index]) * lerpf(0.48, 0.82, intensity)
		_music_tween.tween_property(player, "volume_db", linear_to_db(maxf(gain, 0.001)), transition)

func _get_or_build_music_layers(boss_id: String, state: String, intensity_bucket: int) -> Array:
	var cache_boss := "nest" if state == "nest" else boss_id
	var cache_key := "%s|%s|%02d" % [cache_boss, state, intensity_bucket]
	if _music_cache.has(cache_key):
		_cache_order.erase(cache_key)
		_cache_order.append(cache_key)
		return _music_cache[cache_key]
	var rendered := _make_music_layers(boss_id, state, float(intensity_bucket) / 10.0)
	_music_cache[cache_key] = rendered
	_cache_order.append(cache_key)
	while _cache_order.size() > MUSIC_CACHE_LIMIT:
		var oldest: String = _cache_order.pop_front()
		_music_cache.erase(oldest)
	return rendered

func stop_all() -> void:
	if is_instance_valid(_music_tween):
		_music_tween.kill()
	for music_player in _music_players:
		if is_instance_valid(music_player):
			music_player.stop()
			music_player.stream = null
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_music_state = ""
	_music_intensity_bucket = -1

func shutdown_for_tests() -> void:
	stop_all()
	for player in _players:
		if is_instance_valid(player):
			player.queue_free()
	_players.clear()
	for music_player in _music_players:
		if is_instance_valid(music_player):
			music_player.queue_free()
	_music_players.clear()
	_sfx.clear()
	_music_cache.clear()
	_cache_order.clear()

func _exit_tree() -> void:
	stop_all()

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
		var env := sin(PI * local) * (0.8 if segment < 2 else 1.0)
		var sample := sin(TAU * notes[segment] * t) * env * 0.72
		bytes.encode_s16(index * 2, int(sample * 32760.0))
	return _stream_from_bytes(bytes, false)

func _make_music_layers(boss_id: String, state: String, intensity: float) -> Array:
	var profile: Dictionary = NEST_PROFILE if state == "nest" else BOSS_PROFILES.get(boss_id, BOSS_PROFILES[DEFAULT_BOSS_ID])
	var state_profile: Dictionary = STATE_PROFILES.get(state, STATE_PROFILES["exterior"])
	var result: Array[AudioStreamWAV] = []
	for layer_index in MUSIC_LAYER_COUNT:
		result.append(_make_music_layer(profile, state_profile, state, layer_index, intensity))
	return result

func _make_music_layer(profile: Dictionary, state_profile: Dictionary, state: String, layer_index: int, intensity: float) -> AudioStreamWAV:
	var count := int(MUSIC_SAMPLE_RATE * 4.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	var state_index := maxi(0, MUSIC_STATES.find(state))
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
				var pulse_env := exp(-beat_position * lerpf(11.0, 6.0, density))
				var sub := sin(TAU * root * 0.5 * t)
				var tick := rng.randf_range(-1.0, 1.0) * noise_amount * 2.2
				sample = (sub * 0.38 + tick) * pulse_env * density
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
				var motif_env := pow(maxf(0.0, sin(PI * local_step)), 2.0)
				if state == "low_health":
					motif_env *= 1.0 if int(floor(t * 4.0)) % 4 < 2 else 0.18
				var identity_note := sin(TAU * note_frequency * (1.0 + detune) * t)
				var tense_note := sin(TAU * note_frequency * 1.414214 * t) * tension
				sample = (identity_note * 0.30 + tense_note * 0.11) * motif_env
		sample *= edge_fade * lerpf(0.62, 0.92, intensity)
		bytes.encode_s16(index * 2, int(clampf(sample, -0.88, 0.88) * 32760.0))
	var stream := _stream_from_bytes(bytes, true)
	stream.mix_rate = MUSIC_SAMPLE_RATE
	stream.loop_begin = 0
	stream.loop_end = count
	return stream

func _music_is_playing() -> bool:
	for player in _music_players:
		if is_instance_valid(player) and player.playing:
			return true
	return false

func _music_output_enabled() -> bool:
	return float(SettingsManager.get_value("master_volume", 1.0)) > 0.001 and float(SettingsManager.get_value("music_volume", 1.0)) > 0.001

func _sfx_output_enabled() -> bool:
	return float(SettingsManager.get_value("master_volume", 1.0)) > 0.001 and float(SettingsManager.get_value("sfx_volume", 1.0)) > 0.001

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key not in ["master_volume", "music_volume"]:
		return
	if not _music_output_enabled():
		for player in _music_players:
			player.stop()
	elif not _music_state.is_empty() and not _music_is_playing():
		_start_music_state(_music_state, _music_intensity, _music_intensity_bucket)

## Structural and rendered-sample checks used by the focused headless contract.
func validate_audio_contract(include_rendered_sfx: bool = false) -> PackedStringArray:
	var errors := PackedStringArray()
	if POOL_SIZE < 8 or POOL_SIZE > 24:
		errors.append("SFX pool size must remain bounded between 8 and 24")
	for boss_id in BOSS_PROFILES:
		var profile: Dictionary = BOSS_PROFILES[boss_id]
		for key in ["root", "bpm", "wave", "seed", "intervals", "detune", "noise", "sfx_pitch"]:
			if not profile.has(key):
				errors.append("Boss profile %s is missing %s" % [boss_id, key])
		if (profile.get("intervals", []) as Array).size() < 3:
			errors.append("Boss profile %s needs at least three tonal intervals" % boss_id)
	for state in MUSIC_STATES:
		if not STATE_PROFILES.has(state):
			errors.append("Missing music state %s" % state)
			continue
		var state_profile: Dictionary = STATE_PROFILES[state]
		for key in ["pitch", "tempo", "density", "tension", "layers", "transition"]:
			if not state_profile.has(key):
				errors.append("Music state %s is missing %s" % [state, key])
		if (state_profile.get("layers", []) as Array).size() != MUSIC_LAYER_COUNT:
			errors.append("Music state %s must define exactly %d layers" % [state, MUSIC_LAYER_COUNT])
	if include_rendered_sfx:
		if _sfx.is_empty():
			_build_library()
		for sfx_id in REQUIRED_SFX_IDS:
			if not _sfx.has(sfx_id):
				errors.append("Missing required SFX %s" % sfx_id)
				continue
			var rendered := _sfx[sfx_id] as AudioStreamWAV
			if rendered == null or rendered.data.is_empty():
				errors.append("Required SFX %s rendered no samples" % sfx_id)
	return errors

func render_music_state_for_tests(boss_id: String, state: String, intensity: float = 0.5) -> Array:
	var canonical := _canonical_music_state(state)
	if canonical.is_empty() or not BOSS_PROFILES.has(boss_id):
		return []
	return _make_music_layers(boss_id, canonical, clampf(intensity, 0.0, 1.0))

func get_rendered_sfx_ids_for_tests() -> Array[String]:
	if _sfx.is_empty():
		_build_library()
	var result: Array[String] = []
	for sfx_id in _sfx:
		result.append(String(sfx_id))
	result.sort()
	return result

func get_runtime_player_counts_for_tests() -> Dictionary:
	return {"sfx":_players.size(), "music":_music_players.size()}

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
