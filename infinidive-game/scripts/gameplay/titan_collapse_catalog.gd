class_name TitanCollapseCatalog
extends RefCounted

const DATA_PATH := "res://data/titan_collapses.json"
const EXPECTED_BOSS_IDS := ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]
const SUPPORTED_STYLE_TOKENS := [
	"harvest_shatter",
	"sunwheel_eclipse",
	"worldstream_release",
	"memory_unweave"
]
const SUPPORTED_AUDIO_TOKENS := [
	"boss_phase", "armor_hit", "tissue_hit", "organ_destroyed", "boss_death"
]
const SUPPORTED_VISUAL_TOKENS := [
	"cronus_crown_break", "cronus_sickle_shards", "cronus_golden_sunset", "cronus_final_seal",
	"hyperion_halo_stalls", "hyperion_ray_fall", "hyperion_eclipse", "hyperion_final_seal",
	"oceanus_trident_sinks", "oceanus_tide_unbinds", "oceanus_worldriver_returns", "oceanus_final_seal",
	"mnemosyne_echo_stills", "mnemosyne_muse_scatter", "mnemosyne_memory_unwritten", "mnemosyne_final_seal"
]


static func load_catalog(path: String = DATA_PATH) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []


static func profile_for(boss_id: String, path: String = DATA_PATH) -> Dictionary:
	var profiles := load_catalog(path)
	if not validate_catalog(profiles).is_empty():
		return {}
	for raw_profile in profiles:
		var profile := raw_profile as Dictionary
		if String(profile.get("boss_id", "")) == boss_id:
			return profile.duplicate(true)
	return {}


static func validate_catalog(raw_profiles: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(raw_profiles) != TYPE_ARRAY:
		errors.append("Collapse catalog must be an array")
		return errors
	var profiles := raw_profiles as Array
	if profiles.size() != EXPECTED_BOSS_IDS.size():
		errors.append("Collapse catalog must define exactly four launch Titans")
	var seen_bosses: Dictionary = {}
	var seen_styles: Dictionary = {}
	var seen_final_tokens: Dictionary = {}
	for raw_profile in profiles:
		if typeof(raw_profile) != TYPE_DICTIONARY:
			errors.append("Collapse profile must be a dictionary")
			continue
		var profile := raw_profile as Dictionary
		var boss_id := String(profile.get("boss_id", ""))
		var style_token := String(profile.get("style_token", ""))
		var final_token := String(profile.get("final_token", ""))
		if boss_id not in EXPECTED_BOSS_IDS or seen_bosses.has(boss_id):
			errors.append("Invalid or duplicate collapse boss_id: %s" % boss_id)
		seen_bosses[boss_id] = true
		if style_token not in SUPPORTED_STYLE_TOKENS or seen_styles.has(style_token):
			errors.append("Invalid or duplicate collapse style: %s" % style_token)
		seen_styles[style_token] = true
		if final_token.is_empty() or seen_final_tokens.has(final_token):
			errors.append("Missing or duplicate final collapse token: %s" % final_token)
		seen_final_tokens[final_token] = true
		var accent := String(profile.get("accent", ""))
		if not _is_rgb_hex(accent):
			errors.append("%s collapse accent must be #RRGGBB" % boss_id)
		var duration := float(profile.get("duration_seconds", 0.0))
		var reduced_duration := float(profile.get("reduced_motion_duration_seconds", 0.0))
		if duration < 1.0 or duration > 4.0:
			errors.append("%s collapse duration must stay between 1 and 4 seconds" % boss_id)
		if reduced_duration < 0.1 or reduced_duration > duration:
			errors.append("%s reduced-motion collapse duration must be positive and no longer than standard" % boss_id)
		_validate_cues(profile.get("cues", []), boss_id, style_token, errors)
	for expected_id in EXPECTED_BOSS_IDS:
		if not seen_bosses.has(expected_id):
			errors.append("Missing collapse profile for %s" % expected_id)
	return errors


static func _validate_cues(raw_cues: Variant, boss_id: String, style_token: String, errors: Array[String]) -> void:
	if typeof(raw_cues) != TYPE_ARRAY:
		errors.append("%s collapse cues must be an array" % boss_id)
		return
	var cues := raw_cues as Array
	if cues.size() < 4:
		errors.append("%s collapse needs at least four authored cues" % boss_id)
	var previous_at := -1.0
	var seen_visuals: Dictionary = {}
	var boss_death_count := 0
	var expected_prefix := _visual_prefix_for_style(style_token)
	for cue_index in cues.size():
		var raw_cue: Variant = cues[cue_index]
		if typeof(raw_cue) != TYPE_DICTIONARY:
			errors.append("%s collapse cue %d must be a dictionary" % [boss_id, cue_index])
			continue
		var cue := raw_cue as Dictionary
		var at := float(cue.get("at", -1.0))
		var visual_token := String(cue.get("visual_token", ""))
		var audio_token := String(cue.get("audio_token", ""))
		if at < 0.0 or at > 1.0 or at <= previous_at:
			errors.append("%s collapse cue %d timing must be strictly increasing in [0,1]" % [boss_id, cue_index])
		previous_at = at
		if visual_token not in SUPPORTED_VISUAL_TOKENS or seen_visuals.has(visual_token):
			errors.append("%s collapse cue %d has an invalid or duplicate visual token" % [boss_id, cue_index])
		if not expected_prefix.is_empty() and not visual_token.begins_with(expected_prefix):
			errors.append("%s collapse cue %d does not belong to style %s" % [boss_id, cue_index, style_token])
		seen_visuals[visual_token] = true
		if audio_token not in SUPPORTED_AUDIO_TOKENS:
			errors.append("%s collapse cue %d has an unsupported audio token" % [boss_id, cue_index])
		boss_death_count += 1 if audio_token == "boss_death" else 0
	if not cues.is_empty():
		var first_at := -1.0
		if typeof(cues[0]) == TYPE_DICTIONARY:
			first_at = float((cues[0] as Dictionary).get("at", -1.0))
		if not is_zero_approx(first_at):
			errors.append("%s collapse must begin with a time-zero cue" % boss_id)
	if boss_death_count != 1:
		errors.append("%s collapse must emit boss_death exactly once" % boss_id)


static func _visual_prefix_for_style(style_token: String) -> String:
	match style_token:
		"harvest_shatter": return "cronus_"
		"sunwheel_eclipse": return "hyperion_"
		"worldstream_release": return "oceanus_"
		"memory_unweave": return "mnemosyne_"
		_: return ""


static func _is_rgb_hex(value: String) -> bool:
	if value.length() != 7 or not value.begins_with("#"):
		return false
	for character_index in range(1, value.length()):
		var code := value.unicode_at(character_index)
		var numeric := code >= 48 and code <= 57
		var uppercase := code >= 65 and code <= 70
		var lowercase := code >= 97 and code <= 102
		if not numeric and not uppercase and not lowercase:
			return false
	return true
