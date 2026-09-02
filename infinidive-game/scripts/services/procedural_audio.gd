extends Node

const SAMPLE_RATE := 22050
const MUSIC_SAMPLE_RATE := 11025
const POOL_SIZE := 12
const MUSIC_LAYER_COUNT := 3
const MUSIC_CACHE_LIMIT := 8
const DEFAULT_BOSS_ID := "gravemaw"
const GENERATED_AUDIO_ROOT := "res://assets/audio/generated"
const GENERATED_AUDIO_MANIFEST := GENERATED_AUDIO_ROOT + "/manifest.json"
const AUDIO_ASSET_VERSION := "infinidive-audio-v1"
const AUDIO_MANIFEST_SCHEMA_VERSION := 1
const AUDIO_RESOURCE_FORMAT := "AudioStreamWAV .res / PCM signed 16-bit mono"
const AUDIO_RUNTIME_POLICY := "pre-rendered assets loaded on demand; intensity uses mixer gain only"
const AUDIO_GENERATOR_PATH := "res://tools/generate_audio_assets.gd"
const AUDIO_SYNTHESIS_PATH := "res://tools/audio_asset_synthesizer.gd"
const AUDIO_DEFINITIONS_PATH := "res://scripts/services/procedural_audio.gd"
const MUSIC_LAYER_IDS := ["bed", "pulse", "signal"]

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

const SFX_ALIASES := {
	"mutation_select": "mutation"
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
var _boss_id := DEFAULT_BOSS_ID
var _music_cache: Dictionary = {}
var _cache_order: Array[String] = []
var _audio_available := true
var _startup_frame_presented := false

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
	if not SettingsManager.setting_changed.is_connected(_on_setting_changed):
		SettingsManager.setting_changed.connect(_on_setting_changed)
	SettingsManager.apply_all()
	# Never hold UIKit's launch storyboard while audio resources are loaded. Two
	# process-frame boundaries let Godot present responsive game content first;
	# playback then starts without changing deterministic challenge timing.
	call_deferred("_finish_startup_after_initial_frame")

func _finish_startup_after_initial_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _audio_available:
		return
	_startup_frame_presented = true
	if not _music_state.is_empty() and _music_output_enabled():
		_start_music_state(_music_state, _music_intensity)

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func play_sfx(id: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	if not _startup_frame_presented:
		return
	var canonical_id := String(SFX_ALIASES.get(id, id))
	if not _audio_available or not REQUIRED_SFX_IDS.has(canonical_id) or _players.is_empty() or not _sfx_output_enabled():
		return
	if not _sfx.has(canonical_id):
		var stream := _load_generated_stream(_sfx_asset_path(canonical_id))
		if stream == null:
			push_error("Missing generated SFX asset: %s" % canonical_id)
			return
		_sfx[canonical_id] = stream
	var player := _players[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _players.size()
	player.stop()
	player.stream = _sfx[canonical_id]
	var identity_pitch := 1.0
	if BOSS_COLORED_SFX.has(canonical_id):
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
		set_music_state(active_state, active_intensity)
	return accepted

func get_boss_identity() -> String:
	return _boss_id

func set_music_state(state: String, intensity: float = 0.5) -> void:
	var canonical := _canonical_music_state(state)
	if canonical.is_empty():
		return
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	var same_state := canonical == _music_state
	var same_intensity := is_equal_approx(clamped_intensity, _music_intensity)
	_music_state = canonical
	_music_intensity = clamped_intensity
	if not _audio_available or _music_players.is_empty() or not _music_output_enabled():
		return
	if not _startup_frame_presented:
		return
	if same_state and _music_is_playing():
		if not same_intensity:
			_tween_music_gains(canonical, clamped_intensity, 0.12)
		return
	_start_music_state(canonical, clamped_intensity)

func get_music_state() -> String:
	return _music_state

func _canonical_music_state(state: String) -> String:
	var normalized := state.strip_edges().to_lower()
	if MUSIC_STATE_ALIASES.has(normalized):
		normalized = String(MUSIC_STATE_ALIASES[normalized])
	return normalized if STATE_PROFILES.has(normalized) else ""

func _start_music_state(state: String, intensity: float) -> void:
	if is_instance_valid(_music_tween):
		_music_tween.kill()
	var streams := _load_music_layers(_boss_id, state)
	if streams.size() != MUSIC_LAYER_COUNT:
		push_error("Missing generated music assets for %s/%s" % [_boss_id, state])
		return
	var transition := float(STATE_PROFILES[state].get("transition", 0.35))
	for layer_index in MUSIC_LAYER_COUNT:
		var player := _music_players[layer_index]
		player.stop()
		player.stream = streams[layer_index]
		player.volume_db = -60.0
		player.play()
	_tween_music_gains(state, intensity, transition)

func _tween_music_gains(state: String, intensity: float, duration: float) -> void:
	if is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	for layer_index in MUSIC_LAYER_COUNT:
		var player := _music_players[layer_index]
		if not is_instance_valid(player):
			continue
		_music_tween.tween_property(player, "volume_db", _music_layer_target_db(state, layer_index, intensity), duration)

func _music_layer_target_db(state: String, layer_index: int, intensity: float) -> float:
	var layer_gains: Array = STATE_PROFILES[state].get("layers", [0.5, 0.2, 0.15])
	var gain := float(layer_gains[layer_index]) * lerpf(0.48, 0.82, clampf(intensity, 0.0, 1.0))
	return linear_to_db(maxf(gain, 0.001))

func _load_music_layers(boss_id: String, state: String) -> Array:
	var cache_boss := "nest" if state == "nest" else boss_id
	var cache_key := "%s|%s" % [cache_boss, state]
	if _music_cache.has(cache_key):
		_cache_order.erase(cache_key)
		_cache_order.append(cache_key)
		return _music_cache[cache_key]
	var loaded: Array[AudioStreamWAV] = []
	for layer_id in MUSIC_LAYER_IDS:
		var stream := _load_generated_stream(_music_asset_path(boss_id, state, String(layer_id)))
		if stream == null:
			return []
		loaded.append(stream)
	_music_cache[cache_key] = loaded
	_cache_order.append(cache_key)
	while _cache_order.size() > MUSIC_CACHE_LIMIT:
		var oldest: String = _cache_order.pop_front()
		_music_cache.erase(oldest)
	return loaded

func _sfx_asset_path(sfx_id: String) -> String:
	return "%s/sfx/%s.res" % [GENERATED_AUDIO_ROOT, sfx_id]

func _music_asset_path(boss_id: String, state: String, layer_id: String) -> String:
	if state == "nest":
		return "%s/music/nest/%s.res" % [GENERATED_AUDIO_ROOT, layer_id]
	return "%s/music/%s/%s/%s.res" % [GENERATED_AUDIO_ROOT, boss_id, state, layer_id]

func _load_generated_stream(path: String) -> AudioStreamWAV:
	if not ResourceLoader.exists(path, "AudioStreamWAV"):
		return null
	return load(path) as AudioStreamWAV

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
	elif _startup_frame_presented and not _music_state.is_empty() and not _music_is_playing():
		_start_music_state(_music_state, _music_intensity)

## Structural and generated-asset checks used by the focused headless contract.
func validate_audio_contract(include_generated_assets: bool = false) -> PackedStringArray:
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
	if include_generated_assets:
		_validate_generated_assets(errors)
	return errors

func _validate_generated_assets(errors: PackedStringArray) -> void:
	if not FileAccess.file_exists(GENERATED_AUDIO_MANIFEST):
		errors.append("Generated audio manifest is missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GENERATED_AUDIO_MANIFEST))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Generated audio manifest is not valid JSON object data")
		return
	var manifest: Dictionary = parsed
	if int(manifest.get("schema_version", -1)) != AUDIO_MANIFEST_SCHEMA_VERSION:
		errors.append("Generated audio manifest schema version is invalid")
	if String(manifest.get("asset_version", "")) != AUDIO_ASSET_VERSION:
		errors.append("Generated audio manifest version does not match %s" % AUDIO_ASSET_VERSION)
	if String(manifest.get("format", "")) != AUDIO_RESOURCE_FORMAT:
		errors.append("Generated audio manifest format is invalid")
	if String(manifest.get("runtime_policy", "")) != AUDIO_RUNTIME_POLICY:
		errors.append("Generated audio manifest runtime policy is invalid")
	var raw_generator: Variant = manifest.get("generator", {})
	if typeof(raw_generator) != TYPE_DICTIONARY:
		errors.append("Generated audio manifest generator metadata is invalid")
	else:
		var generator: Dictionary = raw_generator
		_validate_source_hash(generator, "path", "sha256", AUDIO_GENERATOR_PATH, errors)
		_validate_source_hash(generator, "synthesis_path", "synthesis_sha256", AUDIO_SYNTHESIS_PATH, errors)
		_validate_source_hash(generator, "definitions_path", "definitions_sha256", AUDIO_DEFINITIONS_PATH, errors)
	var raw_assets: Variant = manifest.get("assets", [])
	if typeof(raw_assets) != TYPE_ARRAY:
		errors.append("Generated audio manifest assets must be an array")
		return
	var by_path: Dictionary = {}
	for raw_entry in raw_assets as Array:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			errors.append("Generated audio manifest contains a non-object entry")
			continue
		var entry: Dictionary = raw_entry
		var path := String(entry.get("path", ""))
		if path.is_empty() or by_path.has(path):
			errors.append("Generated audio manifest has an empty or duplicate path: %s" % path)
			continue
		by_path[path] = entry

	var expected: Dictionary = {}
	for sfx_id in REQUIRED_SFX_IDS:
		expected[_sfx_asset_path(String(sfx_id))] = {"kind":"sfx", "id":String(sfx_id), "mix_rate":SAMPLE_RATE, "loop":false}
	for layer_id in MUSIC_LAYER_IDS:
		expected[_music_asset_path(DEFAULT_BOSS_ID, "nest", String(layer_id))] = {"kind":"music", "boss_id":"nest", "state":"nest", "layer":String(layer_id), "mix_rate":MUSIC_SAMPLE_RATE, "loop":true}
	for boss_id in BOSS_PROFILES:
		for state in MUSIC_STATES:
			if state == "nest":
				continue
			for layer_id in MUSIC_LAYER_IDS:
				expected[_music_asset_path(String(boss_id), String(state), String(layer_id))] = {"kind":"music", "boss_id":String(boss_id), "state":String(state), "layer":String(layer_id), "mix_rate":MUSIC_SAMPLE_RATE, "loop":true}

	if by_path.size() != expected.size():
		errors.append("Generated audio manifest must contain exactly %d assets, found %d" % [expected.size(), by_path.size()])
	var raw_counts: Variant = manifest.get("counts", {})
	if typeof(raw_counts) != TYPE_DICTIONARY:
		errors.append("Generated audio manifest counts are invalid")
		return
	var counts: Dictionary = raw_counts
	if int(counts.get("sfx", -1)) != REQUIRED_SFX_IDS.size():
		errors.append("Generated audio manifest SFX count is invalid")
	if int(counts.get("music", -1)) != expected.size() - REQUIRED_SFX_IDS.size():
		errors.append("Generated audio manifest music count is invalid")
	if int(counts.get("total", -1)) != expected.size():
		errors.append("Generated audio manifest total count is invalid")

	var total_resource_bytes := 0
	var prior_path := ""
	for raw_entry in raw_assets as Array:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var ordered_path := String((raw_entry as Dictionary).get("path", ""))
		if not prior_path.is_empty() and ordered_path <= prior_path:
			errors.append("Generated audio manifest assets are not strictly path-sorted")
			break
		prior_path = ordered_path
	for path in expected:
		if not by_path.has(path):
			errors.append("Generated audio manifest is missing %s" % path)
			continue
		if not FileAccess.file_exists(path):
			errors.append("Generated audio asset is missing %s" % path)
			continue
		var metadata: Dictionary = expected[path]
		var entry: Dictionary = by_path[path]
		if String(entry.get("kind", "")) != String(metadata.kind):
			errors.append("Generated audio kind mismatch for %s" % path)
		if String(metadata.kind) == "sfx":
			if String(entry.get("id", "")) != String(metadata.id):
				errors.append("Generated SFX id mismatch for %s" % path)
		else:
			for metadata_key in ["boss_id", "state", "layer"]:
				if String(entry.get(metadata_key, "")) != String(metadata[metadata_key]):
					errors.append("Generated music %s mismatch for %s" % [metadata_key, path])
		if int(entry.get("mix_rate", -1)) != int(metadata.mix_rate):
			errors.append("Generated audio manifest sample rate metadata mismatch for %s" % path)
		if bool(entry.get("loop", not bool(metadata.loop))) != bool(metadata.loop):
			errors.append("Generated audio manifest loop metadata mismatch for %s" % path)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() <= 0:
			errors.append("Generated audio asset is empty %s" % path)
			continue
		var byte_count := file.get_length()
		file.close()
		total_resource_bytes += byte_count
		if int(entry.get("bytes", -1)) != byte_count:
			errors.append("Generated audio byte count mismatch for %s" % path)
		if String(entry.get("sha256", "")) != FileAccess.get_sha256(path):
			errors.append("Generated audio hash mismatch for %s" % path)
		var stream := _load_generated_stream(path)
		if stream == null or stream.data.is_empty():
			errors.append("Generated audio asset has no PCM samples %s" % path)
			continue
		if stream.mix_rate != int(metadata.mix_rate):
			errors.append("Generated audio sample rate mismatch for %s" % path)
		if stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.stereo:
			errors.append("Generated audio PCM format mismatch for %s" % path)
		if int(entry.get("pcm_bytes", -1)) != stream.data.size():
			errors.append("Generated audio PCM byte count mismatch for %s" % path)
		var should_loop := bool(metadata.loop)
		if (stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) != should_loop:
			errors.append("Generated audio loop mode mismatch for %s" % path)
		if should_loop and stream.data.size() != MUSIC_SAMPLE_RATE * 4 * 2:
			errors.append("Generated music asset has an unexpected footprint %s" % path)
	if int(manifest.get("total_resource_bytes", -1)) != total_resource_bytes:
		errors.append("Generated audio manifest total byte count is invalid")

func _validate_source_hash(metadata: Dictionary, path_key: String, hash_key: String, expected_path: String, errors: PackedStringArray) -> void:
	if String(metadata.get(path_key, "")) != expected_path:
		errors.append("Generated audio manifest source path mismatch for %s" % path_key)
		return
	if not FileAccess.file_exists(expected_path):
		errors.append("Generated audio source is missing: %s" % expected_path)
		return
	var expected_hash := FileAccess.get_sha256(expected_path)
	if String(metadata.get(hash_key, "")) != expected_hash:
		errors.append("Generated audio source hash mismatch for %s" % expected_path)

func render_music_state_for_tests(boss_id: String, state: String, _intensity: float = 0.5) -> Array:
	var canonical := _canonical_music_state(state)
	if canonical.is_empty() or (canonical != "nest" and not BOSS_PROFILES.has(boss_id)):
		return []
	return _load_music_layers(boss_id, canonical)

func get_rendered_sfx_ids_for_tests() -> Array[String]:
	var result: Array[String] = []
	for sfx_id in REQUIRED_SFX_IDS:
		if _load_generated_stream(_sfx_asset_path(String(sfx_id))) != null:
			result.append(String(sfx_id))
	result.sort()
	return result

func get_runtime_player_counts_for_tests() -> Dictionary:
	return {"sfx":_players.size(), "music":_music_players.size()}

func get_runtime_cache_counts_for_tests() -> Dictionary:
	return {"sfx":_sfx.size(), "music":_music_cache.size()}

func get_music_layer_target_db_for_tests(state: String, layer_index: int, intensity: float) -> float:
	var canonical := _canonical_music_state(state)
	if canonical.is_empty() or layer_index < 0 or layer_index >= MUSIC_LAYER_COUNT:
		return -80.0
	return _music_layer_target_db(canonical, layer_index, intensity)
