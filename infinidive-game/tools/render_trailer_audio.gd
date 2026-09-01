extends Node

## Offline renderer for store-media audio.
##
## Every oscillator and noise source comes from the shipped ProceduralAudio
## implementation. This tool only arranges its rendered layers and SFX against
## the existing truthful runtime edit; it does not introduce external audio.

const AUDIO_SCRIPT := preload("res://scripts/services/procedural_audio.gd")
const OUTPUT_SAMPLE_RATE := 44100
const OUTPUT_CHANNELS := 2
const OUTPUT_DURATION_SECONDS := 17.2

const MUSIC_SEGMENTS := [
	{"start": 0.0, "end": 1.0, "state": "nest", "intensity": 0.24},
	{"start": 1.0, "end": 8.0, "state": "exterior", "intensity": 0.58},
	{"start": 8.0, "end": 10.4, "state": "breach", "intensity": 0.82},
	{"start": 10.4, "end": 11.6, "state": "organ", "intensity": 0.60},
	{"start": 11.6, "end": 13.2, "state": "dive", "intensity": 0.78},
	{"start": 13.2, "end": 17.2, "state": "interior", "intensity": 0.64}
]

const SFX_CUES := [
	{"time": 0.12, "id": "ui_confirm", "gain": 0.34, "pan": 0.0},
	{"time": 1.30, "id": "player_fire", "gain": 0.30, "pan": -0.24},
	{"time": 2.05, "id": "armor_hit", "gain": 0.38, "pan": 0.18},
	{"time": 2.85, "id": "player_fire", "gain": 0.28, "pan": -0.12},
	{"time": 3.60, "id": "enemy_fire", "gain": 0.25, "pan": 0.28},
	{"time": 4.55, "id": "dash", "gain": 0.42, "pan": -0.30},
	{"time": 5.35, "id": "armor_hit", "gain": 0.40, "pan": 0.14},
	{"time": 6.18, "id": "player_fire", "gain": 0.28, "pan": -0.08},
	{"time": 7.18, "id": "boss_phase", "gain": 0.40, "pan": 0.0},
	{"time": 8.02, "id": "breach", "gain": 0.62, "pan": 0.0},
	{"time": 10.46, "id": "ui_confirm", "gain": 0.40, "pan": 0.0},
	{"time": 11.62, "id": "dive", "gain": 0.56, "pan": 0.0},
	{"time": 13.28, "id": "heartbeat", "gain": 0.46, "pan": -0.08},
	{"time": 14.30, "id": "enemy_fire", "gain": 0.27, "pan": 0.22},
	{"time": 15.20, "id": "heartbeat", "gain": 0.40, "pan": 0.08},
	{"time": 16.18, "id": "organ_damage", "gain": 0.50, "pan": 0.0}
]

var _left := PackedFloat32Array()
var _right := PackedFloat32Array()

func _ready() -> void:
	var output_path := _output_path_from_args()
	if output_path.is_empty():
		printerr("Usage: godot --headless --path <project> --script res://tools/render_trailer_audio.gd -- <output.wav>")
		get_tree().quit(2)
		return
	var renderer = AUDIO_SCRIPT.new()
	var errors: PackedStringArray = renderer.validate_audio_contract(true)
	if not errors.is_empty():
		printerr("ProceduralAudio contract failed: %s" % "; ".join(errors))
		get_tree().quit(3)
		return
	var frame_count := int(round(OUTPUT_DURATION_SECONDS * OUTPUT_SAMPLE_RATE))
	_left.resize(frame_count)
	_right.resize(frame_count)
	for segment: Dictionary in MUSIC_SEGMENTS:
		_mix_music_segment(renderer, segment)
	var rendered_sfx: Dictionary = renderer.get("_sfx")
	for cue: Dictionary in SFX_CUES:
		_mix_sfx(rendered_sfx, cue)
	renderer.shutdown_for_tests()
	renderer.free()
	_apply_master_envelope_and_limiter()
	var pcm := _interleaved_pcm16()
	var write_error := _write_wave(output_path, pcm)
	if write_error != OK:
		printerr("Could not write WAV %s: error %d" % [output_path, write_error])
		get_tree().quit(4)
		return
	print("TRAILER_AUDIO_OK path=%s frames=%d rate=%d channels=%d duration=%.3f" % [
		output_path, frame_count, OUTPUT_SAMPLE_RATE, OUTPUT_CHANNELS, OUTPUT_DURATION_SECONDS
	])
	get_tree().quit(0)

func _output_path_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return ""
	return ProjectSettings.globalize_path(String(args[0]))

func _mix_music_segment(renderer: Node, segment: Dictionary) -> void:
	var state := String(segment["state"])
	var intensity := float(segment["intensity"])
	var streams: Array = renderer.render_music_state_for_tests("gravemaw", state, intensity)
	if streams.size() != 3:
		printerr("No three-layer music render for state %s" % state)
		return
	var profile: Dictionary = AUDIO_SCRIPT.STATE_PROFILES[state]
	var gains: Array = profile["layers"]
	var start_frame := int(round(float(segment["start"]) * OUTPUT_SAMPLE_RATE))
	var end_frame := mini(_left.size(), int(round(float(segment["end"]) * OUTPUT_SAMPLE_RATE)))
	var duration_frames := maxi(1, end_frame - start_frame)
	for layer_index in streams.size():
		var stream := streams[layer_index] as AudioStreamWAV
		var layer_gain := float(gains[layer_index]) * lerpf(0.48, 0.82, intensity) * 0.56
		var pan: float = float([-0.16, 0.0, 0.16][layer_index])
		var pan_left := sqrt((1.0 - pan) * 0.5)
		var pan_right := sqrt((1.0 + pan) * 0.5)
		var source_frames := stream.data.size() / 2
		for output_frame in range(start_frame, end_frame):
			var local_frame := output_frame - start_frame
			var source_position := float(local_frame) * float(stream.mix_rate) / float(OUTPUT_SAMPLE_RATE)
			var wrapped_position := fmod(source_position, float(source_frames))
			var sample := _sample_mono_linear(stream.data, wrapped_position, source_frames)
			var edge_seconds := minf(float(local_frame), float(duration_frames - 1 - local_frame)) / float(OUTPUT_SAMPLE_RATE)
			var edge_gain := clampf(edge_seconds / 0.075, 0.0, 1.0)
			_left[output_frame] += sample * layer_gain * pan_left * edge_gain
			_right[output_frame] += sample * layer_gain * pan_right * edge_gain

func _mix_sfx(rendered_sfx: Dictionary, cue: Dictionary) -> void:
	var id := String(cue["id"])
	if not rendered_sfx.has(id):
		printerr("Missing rendered SFX cue: %s" % id)
		return
	var stream := rendered_sfx[id] as AudioStreamWAV
	var start_frame := int(round(float(cue["time"]) * OUTPUT_SAMPLE_RATE))
	var source_frames := stream.data.size() / 2
	var output_length := int(ceil(float(source_frames) * OUTPUT_SAMPLE_RATE / float(stream.mix_rate)))
	var gain := float(cue["gain"])
	var pan := clampf(float(cue["pan"]), -1.0, 1.0)
	var pan_left := sqrt((1.0 - pan) * 0.5)
	var pan_right := sqrt((1.0 + pan) * 0.5)
	for local_frame in output_length:
		var output_frame := start_frame + local_frame
		if output_frame >= _left.size():
			break
		var source_position := float(local_frame) * float(stream.mix_rate) / float(OUTPUT_SAMPLE_RATE)
		var sample := _sample_mono_linear(stream.data, source_position, source_frames)
		_left[output_frame] += sample * gain * pan_left
		_right[output_frame] += sample * gain * pan_right

func _sample_mono_linear(data: PackedByteArray, position: float, frame_count: int) -> float:
	var first := clampi(int(floor(position)), 0, frame_count - 1)
	var second := mini(frame_count - 1, first + 1)
	var fraction: float = position - floor(position)
	var first_sample := float(data.decode_s16(first * 2)) / 32768.0
	var second_sample := float(data.decode_s16(second * 2)) / 32768.0
	return lerpf(first_sample, second_sample, fraction)

func _apply_master_envelope_and_limiter() -> void:
	var fade_frames := int(0.10 * OUTPUT_SAMPLE_RATE)
	for index in _left.size():
		var fade_in := clampf(float(index) / float(fade_frames), 0.0, 1.0)
		var fade_out := clampf(float(_left.size() - 1 - index) / float(fade_frames), 0.0, 1.0)
		var envelope := minf(fade_in, fade_out)
		_left[index] = clampf(_left[index] * envelope, -0.94, 0.94)
		_right[index] = clampf(_right[index] * envelope, -0.94, 0.94)

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
