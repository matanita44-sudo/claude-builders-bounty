extends Node

## Deterministic offline music-bed renderer for the browser gameplay trailer.
##
## The source streams are the same generated AudioStreamWAV resources loaded by
## ProceduralAudio at runtime. No microphone, network, stock, or third-party
## samples are used. This is intentionally a score added after browser capture;
## it is not represented as live-captured or event-synchronous gameplay audio.

const AUDIO_SCRIPT := preload("res://scripts/services/procedural_audio.gd")
const OUTPUT_SAMPLE_RATE := 48000
const OUTPUT_CHANNELS := 2
const OUTPUT_DURATION_SECONDS := 30.0
const BOSS_ID := "gravemaw"
const MASTER_GAIN := 4.0

# The early transitions broadly follow the contracted outside/inside arc. The
# final exterior bed begins at 16 seconds so every expected 17–22 second edit
# closes on the same runtime state without requiring capture-time synthesis.
const MUSIC_SEGMENTS := [
	{"start": 0.0, "end": 7.0, "state": "exterior", "intensity": 0.54},
	{"start": 7.0, "end": 9.0, "state": "breach", "intensity": 0.76},
	{"start": 9.0, "end": 11.0, "state": "dive", "intensity": 0.72},
	{"start": 11.0, "end": 13.4, "state": "interior", "intensity": 0.58},
	{"start": 13.4, "end": 15.2, "state": "organ", "intensity": 0.72},
	{"start": 15.2, "end": 16.0, "state": "dive", "intensity": 0.66},
	{"start": 16.0, "end": 30.0, "state": "exterior", "intensity": 0.64},
]

var _left := PackedFloat32Array()
var _right := PackedFloat32Array()


func _ready() -> void:
	var output_path := _output_path_from_args()
	if output_path.is_empty():
		printerr("Usage: godot --headless --path <project> --scene res://tools/bright_trailer_audio_renderer.tscn -- <output.wav>")
		get_tree().quit(2)
		return
	var renderer = AUDIO_SCRIPT.new()
	var errors: PackedStringArray = renderer.validate_audio_contract(true)
	if not errors.is_empty():
		printerr("ProceduralAudio generated-asset contract failed: %s" % "; ".join(errors))
		renderer.free()
		get_tree().quit(3)
		return
	var frame_count := int(round(OUTPUT_DURATION_SECONDS * OUTPUT_SAMPLE_RATE))
	_left.resize(frame_count)
	_right.resize(frame_count)
	for segment: Dictionary in MUSIC_SEGMENTS:
		var mix_error := _mix_music_segment(renderer, segment)
		if not mix_error.is_empty():
			printerr(mix_error)
			renderer.shutdown_for_tests()
			renderer.free()
			get_tree().quit(4)
			return
	renderer.shutdown_for_tests()
	renderer.free()
	_apply_master_envelope_and_limiter()
	var write_error := _write_wave(output_path, _interleaved_pcm16())
	if write_error != OK:
		printerr("Could not write WAV %s: error %d" % [output_path, write_error])
		get_tree().quit(5)
		return
	print("BRIGHT_TRAILER_AUDIO_OK path=%s frames=%d rate=%d channels=%d duration=%.3f sha256=%s" % [
		output_path,
		frame_count,
		OUTPUT_SAMPLE_RATE,
		OUTPUT_CHANNELS,
		OUTPUT_DURATION_SECONDS,
		FileAccess.get_sha256(output_path),
	])
	get_tree().quit(0)


func _output_path_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return ""
	return ProjectSettings.globalize_path(String(args[0]))


func _mix_music_segment(renderer: Node, segment: Dictionary) -> String:
	var state := String(segment["state"])
	var intensity := float(segment["intensity"])
	var streams: Array = renderer.render_music_state_for_tests(BOSS_ID, state, intensity)
	if streams.size() != AUDIO_SCRIPT.MUSIC_LAYER_COUNT:
		return "Expected three generated runtime music layers for %s/%s" % [BOSS_ID, state]
	var profile: Dictionary = AUDIO_SCRIPT.STATE_PROFILES[state]
	var gains: Array = profile["layers"]
	var start_frame := int(round(float(segment["start"]) * OUTPUT_SAMPLE_RATE))
	var end_frame := mini(_left.size(), int(round(float(segment["end"]) * OUTPUT_SAMPLE_RATE)))
	var duration_frames := maxi(1, end_frame - start_frame)
	for layer_index in streams.size():
		var stream := streams[layer_index] as AudioStreamWAV
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.stereo:
			return "Generated runtime music layer %d for %s has an unexpected PCM format" % [layer_index, state]
		var source_frames := stream.data.size() / 2
		if source_frames < 2 or stream.mix_rate < 1:
			return "Generated runtime music layer %d for %s is empty" % [layer_index, state]
		var layer_gain := float(gains[layer_index]) * lerpf(0.48, 0.82, intensity) * 0.56
		var pan: float = float([-0.16, 0.0, 0.16][layer_index])
		var pan_left := sqrt((1.0 - pan) * 0.5)
		var pan_right := sqrt((1.0 + pan) * 0.5)
		for output_frame in range(start_frame, end_frame):
			var local_frame := output_frame - start_frame
			var source_position := float(local_frame) * float(stream.mix_rate) / float(OUTPUT_SAMPLE_RATE)
			var wrapped_position := fmod(source_position, float(source_frames))
			var sample := _sample_mono_linear(stream.data, wrapped_position, source_frames)
			var edge_seconds := minf(float(local_frame), float(duration_frames - 1 - local_frame)) / float(OUTPUT_SAMPLE_RATE)
			var edge_gain := clampf(edge_seconds / 0.075, 0.0, 1.0)
			_left[output_frame] += sample * layer_gain * pan_left * edge_gain
			_right[output_frame] += sample * layer_gain * pan_right * edge_gain
	return ""


func _sample_mono_linear(data: PackedByteArray, position: float, frame_count: int) -> float:
	var first := clampi(int(floor(position)), 0, frame_count - 1)
	var second := mini(frame_count - 1, first + 1)
	var fraction: float = position - floor(position)
	var first_sample := float(data.decode_s16(first * 2)) / 32768.0
	var second_sample := float(data.decode_s16(second * 2)) / 32768.0
	return lerpf(first_sample, second_sample, fraction)


func _apply_master_envelope_and_limiter() -> void:
	var fade_frames := int(0.12 * OUTPUT_SAMPLE_RATE)
	for index in _left.size():
		var fade_in := clampf(float(index) / float(fade_frames), 0.0, 1.0)
		var fade_out := clampf(float(_left.size() - 1 - index) / float(fade_frames), 0.0, 1.0)
		var envelope := minf(fade_in, fade_out)
		_left[index] = clampf(_left[index] * envelope * MASTER_GAIN, -0.94, 0.94)
		_right[index] = clampf(_right[index] * envelope * MASTER_GAIN, -0.94, 0.94)


func _interleaved_pcm16() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(_left.size() * OUTPUT_CHANNELS * 2)
	for frame in _left.size():
		bytes.encode_s16(frame * 4, int(round(_left[frame] * 32767.0)))
		bytes.encode_s16(frame * 4 + 2, int(round(_right[frame] * 32767.0)))
	return bytes


func _write_wave(output_path: String, pcm: PackedByteArray) -> Error:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.big_endian = false
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + pcm.size())
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(OUTPUT_CHANNELS)
	file.store_32(OUTPUT_SAMPLE_RATE)
	file.store_32(OUTPUT_SAMPLE_RATE * OUTPUT_CHANNELS * 2)
	file.store_16(OUTPUT_CHANNELS * 2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(pcm.size())
	file.store_buffer(pcm)
	file.close()
	return OK
