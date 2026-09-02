extends Node

const ProceduralAudioClass := preload("res://scripts/services/procedural_audio.gd")
const AudioAssetSynthesizer := preload("res://tools/audio_asset_synthesizer.gd")

var passed := 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("AUDIO TEST FAILURE: " + message)

func _run() -> void:
	var synth := ProceduralAudioClass.new()
	add_child(synth)
	var runtime_source := FileAccess.get_file_as_string(ProceduralAudioClass.AUDIO_DEFINITIONS_PATH)
	_check(runtime_source.find("AudioStreamWAV.new()") < 0 and runtime_source.find("encode_s16(") < 0, "Production AudioManager must not contain PCM sample rendering")
	_check(runtime_source.find("call_deferred(\"_finish_startup_after_initial_frame\")") >= 0 and runtime_source.find("await get_tree().process_frame") >= 0, "Production audio startup must remain deferred until game frames can be presented")
	var export_presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(export_presets.count("tools/*") == 4, "Every production export preset must exclude offline audio tools")
	_check(String(ProceduralAudioClass.SFX_ALIASES.get("mutation_select", "")) == "mutation", "Legacy mutation-select event must resolve to the release mutation asset")
	var counts: Dictionary = synth.get_runtime_player_counts_for_tests()
	var caches: Dictionary = synth.get_runtime_cache_counts_for_tests()
	_check(int(counts.sfx) == 0 and int(counts.music) == 0 and int(caches.sfx) == 0 and int(caches.music) == 0, "Headless initialization must create no audio players or runtime sample caches")

	var contract_errors: PackedStringArray = synth.validate_audio_contract(true)
	_check(contract_errors.is_empty(), "Audio definition, manifest hashes, and generated asset contract must validate: %s" % "; ".join(contract_errors))
	var rendered_sfx: Array[String] = synth.get_rendered_sfx_ids_for_tests()
	for sfx_id in ProceduralAudioClass.REQUIRED_SFX_IDS:
		_check(rendered_sfx.has(String(sfx_id)), "Required SFX must render: %s" % sfx_id)
	var offline_renderer := AudioAssetSynthesizer.new()
	var reproduced_sfx: Dictionary = offline_renderer.synthesize_sfx_library()
	for sfx_id in ProceduralAudioClass.REQUIRED_SFX_IDS:
		var release_sfx := load("%s/sfx/%s.res" % [ProceduralAudioClass.GENERATED_AUDIO_ROOT, sfx_id]) as AudioStreamWAV
		var reproduced := reproduced_sfx.get(sfx_id) as AudioStreamWAV
		_check(release_sfx != null and reproduced != null and release_sfx.data == reproduced.data, "Offline renderer must reproduce release SFX byte-for-byte: %s" % sfx_id)

	var exterior_signatures: Dictionary = {}
	var interior_signatures: Dictionary = {}
	for boss_id in ProceduralAudioClass.BOSS_PROFILES:
		for state in ProceduralAudioClass.MUSIC_STATES:
			var streams: Array = synth.render_music_state_for_tests(String(boss_id), String(state), 0.6)
			var reproduced_layers: Array = offline_renderer.synthesize_music_layers(String(boss_id), String(state))
			_check(streams.size() == ProceduralAudioClass.MUSIC_LAYER_COUNT, "%s/%s must render three layers" % [boss_id, state])
			_check(reproduced_layers.size() == ProceduralAudioClass.MUSIC_LAYER_COUNT, "%s/%s offline reproduction must render three layers" % [boss_id, state])
			var signature := 17
			for layer_index in streams.size():
				var raw_stream: Variant = streams[layer_index]
				var stream := raw_stream as AudioStreamWAV
				_check(stream != null, "%s/%s layer must be AudioStreamWAV" % [boss_id, state])
				if stream == null:
					continue
				_check(stream.mix_rate == ProceduralAudioClass.MUSIC_SAMPLE_RATE, "%s/%s layer must use the bounded music sample rate" % [boss_id, state])
				_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s/%s layer must loop" % [boss_id, state])
				_check(stream.data.size() == ProceduralAudioClass.MUSIC_SAMPLE_RATE * 4 * 2, "%s/%s layer must have the fixed four-second footprint" % [boss_id, state])
				var reproduced_stream := reproduced_layers[layer_index] as AudioStreamWAV
				_check(reproduced_stream != null and stream.data == reproduced_stream.data, "%s/%s/%s must reproduce release PCM byte-for-byte" % [boss_id, state, ProceduralAudioClass.MUSIC_LAYER_IDS[layer_index]])
				signature = int((signature * 31 + hash(stream.data)) & 0x7fffffff)
			if state == "exterior":
				exterior_signatures[boss_id] = signature
			elif state == "interior":
				interior_signatures[boss_id] = signature

	_check(_unique_value_count(exterior_signatures) == 4, "All four bosses need distinct exterior tonal identities")
	_check(_unique_value_count(interior_signatures) == 4, "All four bosses need distinct interior tonal identities")

	var deterministic_a: Array = synth.render_music_state_for_tests("null_twin", "organ", 0.0)
	var deterministic_b: Array = synth.render_music_state_for_tests("null_twin", "organ", 1.0)
	_check((deterministic_a[0] as AudioStreamWAV).data == (deterministic_b[0] as AudioStreamWAV).data, "Intensity must never change the immutable boss/state waveform")
	var regenerated_a: Array = offline_renderer.synthesize_music_layers("null_twin", "organ")
	var regenerated_b: Array = offline_renderer.synthesize_music_layers("null_twin", "organ")
	for layer_index in ProceduralAudioClass.MUSIC_LAYER_COUNT:
		_check((regenerated_a[layer_index] as AudioStreamWAV).data == (regenerated_b[layer_index] as AudioStreamWAV).data, "Offline generation must be deterministic for null_twin/organ/%s" % ProceduralAudioClass.MUSIC_LAYER_IDS[layer_index])
		var quiet_db := synth.get_music_layer_target_db_for_tests("organ", layer_index, 0.0)
		var intense_db := synth.get_music_layer_target_db_for_tests("organ", layer_index, 1.0)
		_check(intense_db > quiet_db, "Runtime intensity must increase mixer gain for organ/%s" % ProceduralAudioClass.MUSIC_LAYER_IDS[layer_index])
	_check(int(synth.get_runtime_cache_counts_for_tests().music) <= ProceduralAudioClass.MUSIC_CACHE_LIMIT, "On-demand music cache must remain bounded")
	_check(synth.render_music_state_for_tests("unknown", "core").is_empty(), "Unknown boss render must fail closed")
	_check(synth.render_music_state_for_tests("gravemaw", "unknown").is_empty(), "Unknown music state render must fail closed")

	_check(synth.set_boss_identity("seraph_9"), "Known boss identity must be accepted")
	_check(synth.get_boss_identity() == "seraph_9", "Known boss identity must persist")
	synth.set_music_state("inside", 0.5)
	_check(synth.get_music_state() == "interior", "Legacy inside alias must resolve to interior")
	_check(not synth.set_boss_identity("malformed"), "Unknown boss identity must report rejection")
	_check(synth.get_boss_identity() == ProceduralAudioClass.DEFAULT_BOSS_ID, "Unknown boss identity must fail safely to default")
	synth.set_music_state("not_a_state", 0.5)
	_check(synth.get_music_state() == "interior", "Invalid state must not replace the active state")

	synth.shutdown_for_tests()
	synth.queue_free()
	offline_renderer = null
	print("INFINIDIVE AUDIO TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

func _unique_value_count(values: Dictionary) -> int:
	var unique: Dictionary = {}
	for value in values.values():
		unique[value] = true
	return unique.size()
