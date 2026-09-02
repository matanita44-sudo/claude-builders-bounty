extends Node

## Deterministic offline renderer for all release audio. Run from repository root:
## Godot --headless --path infinidive-game --scene res://tools/GenerateAudioAssets.tscn
##
## Production playback never invokes this script. The generated .res files are
## native Godot AudioStreamWAV resources and are loaded on demand at runtime.

const ProceduralAudioClass := preload("res://scripts/services/procedural_audio.gd")
const AudioAssetSynthesizer := preload("res://tools/audio_asset_synthesizer.gd")
const GENERATOR_PATH := ProceduralAudioClass.AUDIO_GENERATOR_PATH
const SYNTHESIS_PATH := ProceduralAudioClass.AUDIO_SYNTHESIS_PATH
const DEFINITIONS_PATH := ProceduralAudioClass.AUDIO_DEFINITIONS_PATH

var _failures: Array[String] = []
var _assets: Array[Dictionary] = []
var _total_bytes := 0

func _ready() -> void:
	var synth := AudioAssetSynthesizer.new()
	_prepare_directories()
	_render_sfx(synth)
	_render_music(synth)
	synth = null
	if _failures.is_empty():
		_write_manifest()
	if _failures.is_empty():
		print("INFINIDIVE AUDIO ASSETS: %d SFX + %d music layers = %d assets, %d bytes" % [
			ProceduralAudioClass.REQUIRED_SFX_IDS.size(),
			_assets.size() - ProceduralAudioClass.REQUIRED_SFX_IDS.size(),
			_assets.size(),
			_total_bytes
		])
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("AUDIO ASSET GENERATION FAILURE: " + failure)
		get_tree().quit(1)

func _prepare_directories() -> void:
	_make_directory(ProceduralAudioClass.GENERATED_AUDIO_ROOT)
	_make_directory(ProceduralAudioClass.GENERATED_AUDIO_ROOT + "/sfx")
	_make_directory(ProceduralAudioClass.GENERATED_AUDIO_ROOT + "/music/nest")
	for boss_id in _sorted_boss_ids():
		for state in ProceduralAudioClass.MUSIC_STATES:
			if state == "nest":
				continue
			_make_directory("%s/music/%s/%s" % [ProceduralAudioClass.GENERATED_AUDIO_ROOT, boss_id, state])

func _make_directory(path: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		_failures.append("Could not create %s: %s" % [path, error_string(error)])

func _render_sfx(synth: RefCounted) -> void:
	var library: Dictionary = synth.synthesize_sfx_library()
	for sfx_id in ProceduralAudioClass.REQUIRED_SFX_IDS:
		if not library.has(sfx_id):
			_failures.append("Synthesizer omitted required SFX %s" % sfx_id)
			continue
		var stream := library[sfx_id] as AudioStreamWAV
		var path := "%s/sfx/%s.res" % [ProceduralAudioClass.GENERATED_AUDIO_ROOT, sfx_id]
		_save_stream(stream, path, {
			"kind":"sfx",
			"id":String(sfx_id),
			"mix_rate":ProceduralAudioClass.SAMPLE_RATE,
			"loop":false
		})

func _render_music(synth: RefCounted) -> void:
	var nest_layers: Array = synth.synthesize_music_layers(ProceduralAudioClass.DEFAULT_BOSS_ID, "nest")
	_save_music_layers(nest_layers, "nest", "nest")
	for boss_id in _sorted_boss_ids():
		for state in ProceduralAudioClass.MUSIC_STATES:
			if state == "nest":
				continue
			var layers: Array = synth.synthesize_music_layers(boss_id, String(state))
			_save_music_layers(layers, boss_id, String(state))

func _save_music_layers(layers: Array, boss_id: String, state: String) -> void:
	if layers.size() != ProceduralAudioClass.MUSIC_LAYER_COUNT:
		_failures.append("%s/%s did not render exactly three music layers" % [boss_id, state])
		return
	for layer_index in ProceduralAudioClass.MUSIC_LAYER_COUNT:
		var layer_id := String(ProceduralAudioClass.MUSIC_LAYER_IDS[layer_index])
		var path := "%s/music/nest/%s.res" % [ProceduralAudioClass.GENERATED_AUDIO_ROOT, layer_id] if state == "nest" else "%s/music/%s/%s/%s.res" % [ProceduralAudioClass.GENERATED_AUDIO_ROOT, boss_id, state, layer_id]
		_save_stream(layers[layer_index] as AudioStreamWAV, path, {
			"kind":"music",
			"boss_id":boss_id,
			"state":state,
			"layer":layer_id,
			"mix_rate":ProceduralAudioClass.MUSIC_SAMPLE_RATE,
			"loop":true
		})

func _save_stream(stream: AudioStreamWAV, path: String, metadata: Dictionary) -> void:
	if stream == null or stream.data.is_empty():
		_failures.append("Renderer produced an empty stream for %s" % path)
		return
	var error := ResourceSaver.save(stream, path)
	if error != OK:
		_failures.append("Could not save %s: %s" % [path, error_string(error)])
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Could not reopen generated asset %s" % path)
		return
	var byte_count := file.get_length()
	file.close()
	if byte_count <= 0:
		_failures.append("Generated asset is empty %s" % path)
		return
	var entry := metadata.duplicate(true)
	entry["path"] = path
	entry["bytes"] = byte_count
	entry["pcm_bytes"] = stream.data.size()
	entry["sha256"] = FileAccess.get_sha256(path)
	_assets.append(entry)
	_total_bytes += byte_count

func _write_manifest() -> void:
	_assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.path) < String(b.path))
	var sfx_count := ProceduralAudioClass.REQUIRED_SFX_IDS.size()
	var music_count := _assets.size() - sfx_count
	var expected_music_count := ProceduralAudioClass.MUSIC_LAYER_COUNT + (ProceduralAudioClass.MUSIC_STATES.size() - 1) * ProceduralAudioClass.BOSS_PROFILES.size() * ProceduralAudioClass.MUSIC_LAYER_COUNT
	if sfx_count != 24 or music_count != expected_music_count or music_count != 99 or _assets.size() != 123:
		_failures.append("Asset count invariant failed: %d SFX, %d music, %d total" % [sfx_count, music_count, _assets.size()])
		return
	var manifest := {
		"schema_version":ProceduralAudioClass.AUDIO_MANIFEST_SCHEMA_VERSION,
		"asset_version":ProceduralAudioClass.AUDIO_ASSET_VERSION,
		"format":ProceduralAudioClass.AUDIO_RESOURCE_FORMAT,
		"runtime_policy":ProceduralAudioClass.AUDIO_RUNTIME_POLICY,
		"generator":{
			"path":GENERATOR_PATH,
			"sha256":FileAccess.get_sha256(GENERATOR_PATH),
			"synthesis_path":SYNTHESIS_PATH,
			"synthesis_sha256":FileAccess.get_sha256(SYNTHESIS_PATH),
			"definitions_path":DEFINITIONS_PATH,
			"definitions_sha256":FileAccess.get_sha256(DEFINITIONS_PATH)
		},
		"counts":{"sfx":sfx_count, "music":music_count, "total":_assets.size()},
		"total_resource_bytes":_total_bytes,
		"assets":_assets
	}
	var temp_path := ProceduralAudioClass.GENERATED_AUDIO_MANIFEST + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not open manifest temporary file")
		return
	file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	file.flush()
	file.close()
	var target_absolute := ProjectSettings.globalize_path(ProceduralAudioClass.GENERATED_AUDIO_MANIFEST)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(ProceduralAudioClass.GENERATED_AUDIO_MANIFEST):
		var remove_error := DirAccess.remove_absolute(target_absolute)
		if remove_error != OK:
			_failures.append("Could not replace prior manifest: %s" % error_string(remove_error))
			return
	var rename_error := DirAccess.rename_absolute(temp_absolute, target_absolute)
	if rename_error != OK:
		_failures.append("Could not atomically install manifest: %s" % error_string(rename_error))

func _sorted_boss_ids() -> Array[String]:
	var result: Array[String] = []
	for boss_id in ProceduralAudioClass.BOSS_PROFILES:
		result.append(String(boss_id))
	result.sort()
	return result
