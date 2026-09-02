extends Node

signal profile_changed(profile: Dictionary)
signal recovery_performed(source: String)

const TutorialFlowClass := preload("res://scripts/core/tutorial_flow.gd")
const SAVE_SCHEMA := 6
const SAVE_PATH := "user://infinidive.save.json"
const BACKUP_PATH := "user://infinidive.save.backup.json"
const TEMP_PATH := "user://infinidive.save.tmp.json"

var profile: Dictionary = {}
var last_load_source := "default"
var _test_save_failures_remaining := 0

func _ready() -> void:
	load_profile()

func default_profile() -> Dictionary:
	return {
		"bio_matter": 0,
		"core_shards": 0,
		"unlocked_weapons": ["pulse_needle"],
		"selected_weapon": "pulse_needle",
		"upgrades": {},
		"nest_stage": 0,
		"unlocked_bosses": ["gravemaw"],
		"boss_clears": {},
		"difficulty_progress": {"diver": 0, "deep": 0, "abyss": 0},
		"achievements": [],
		"discovered_mutations": [],
		"high_scores": {},
		"tutorial_complete": false,
		"tutorial_step": 0,
		"tutorial_state": {"version": 1, "understood_mask": 0},
		"tutorial_presentation": {"version": 1, "replay_active": false, "replay_mask": 0},
		"tutorial_replay_requested": false,
		"cosmetic": "diver_default",
		"contracts": {},
		"meta_goal_state": {"schema_version": 1, "achievement_progress": {}, "reward_ledger": [], "processed_event_ids": []},
		"total_runs": 0,
		"total_wins": 0,
		"abyss_unlocked": false,
		"processed_run_ids": [],
		"settings": {
			"master_volume": 0.85,
			"music_volume": 0.72,
			"sfx_volume": 0.9,
			"haptics": true,
			"screen_shake": 0.7,
			"reduced_motion": false,
			"projectile_contrast": false,
			"damage_flash": 0.7,
			"control_sensitivity": 0.72,
			"dash_method": "button",
			"handedness": "right",
			"language": "en",
			"assist_projectile_speed": 1.0,
			"assist_telegraph": 1.0,
			"assist_dash_window": 1.0,
			"aim_assist": true,
			"analytics_opt_in": false
		}
	}

func load_profile() -> Dictionary:
	var loaded := _read_envelope(SAVE_PATH)
	last_load_source = "primary"
	if loaded.is_empty():
		loaded = _read_envelope(BACKUP_PATH)
		last_load_source = "backup"
		if not loaded.is_empty():
			recovery_performed.emit("backup")
	if loaded.is_empty():
		profile = default_profile()
		last_load_source = "default"
	else:
		profile = _migrate_and_merge(loaded)
	profile_changed.emit(profile.duplicate(true))
	return profile

func _read_envelope(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var decoded: Variant = parser.data
	if typeof(decoded) != TYPE_DICTIONARY:
		return {}
	var envelope: Dictionary = decoded
	var payload_value: Variant = {}
	if envelope.has("payload_json"):
		var payload_json := String(envelope.get("payload_json", ""))
		if payload_json.is_empty() or String(envelope.get("checksum", "")) != payload_json.sha256_text():
			return {}
		payload_value = JSON.parse_string(payload_json)
	else:
		payload_value = envelope.get("payload", {})
	if typeof(payload_value) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = payload_value
	if not envelope.has("payload_json"):
		var checksum := String(envelope.get("checksum", ""))
		if checksum != JSON.stringify(payload).sha256_text():
			return {}
	payload["_schema"] = int(envelope.get("schema", 1))
	return payload

func _migrate_and_merge(loaded: Dictionary) -> Dictionary:
	var schema := int(loaded.get("_schema", 1))
	loaded.erase("_schema")
	if schema <= 1:
		if loaded.has("bank") and not loaded.has("bio_matter"):
			loaded["bio_matter"] = int(loaded.get("bank", 0))
		loaded.erase("bank")
		schema = 2
	if schema <= 2:
		if not loaded.has("contracts"):
			loaded["contracts"] = {}
		if not loaded.has("abyss_unlocked"):
			loaded["abyss_unlocked"] = int(loaded.get("total_wins", 0)) > 0
		schema = 3
	if schema <= 3:
		schema = 4
	if schema <= 4:
		if not loaded.has("tutorial_state"):
			var legacy_mask := 0
			if bool(loaded.get("tutorial_complete", false)):
				# A legacy completion flag means every semantic tutorial step was
				# understood. Marking only the final step would reopen steps 1-9.
				legacy_mask = TutorialFlowClass.FULL_MASK
			loaded["tutorial_state"] = {"version": 1, "understood_mask": legacy_mask}
		if not loaded.has("tutorial_replay_requested"):
			loaded["tutorial_replay_requested"] = false
		schema = 5
	if schema <= 5:
		if not loaded.has("tutorial_presentation"):
			loaded["tutorial_presentation"] = {"version": 1, "replay_active": false, "replay_mask": 0}
		schema = 6
	var merged := _deep_defaults(loaded, default_profile())
	return merged

func _deep_defaults(value: Dictionary, defaults: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in defaults:
		if not result.has(key):
			result[key] = _value_matching_default(value.get(key, null), defaults[key], value.has(key))
	# Preserve future fields so a newer save is not silently stripped when opened
	# by this build. Known fields are always normalized to their expected shape.
	for key in value:
		if not result.has(key):
			result[key] = value[key]
	return result

func _value_matching_default(raw_value: Variant, default_value: Variant, was_present: bool) -> Variant:
	if not was_present:
		return default_value.duplicate(true) if default_value is Dictionary or default_value is Array else default_value
	match typeof(default_value):
		TYPE_DICTIONARY:
			if typeof(raw_value) != TYPE_DICTIONARY:
				return (default_value as Dictionary).duplicate(true)
			return _deep_defaults(raw_value as Dictionary, default_value as Dictionary)
		TYPE_ARRAY:
			return (raw_value as Array).duplicate(true) if typeof(raw_value) == TYPE_ARRAY else (default_value as Array).duplicate(true)
		TYPE_INT:
			if typeof(raw_value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(raw_value)):
				return int(raw_value)
		TYPE_FLOAT:
			if typeof(raw_value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(raw_value)):
				return float(raw_value)
		TYPE_BOOL:
			if typeof(raw_value) == TYPE_BOOL:
				return raw_value
		TYPE_STRING:
			if typeof(raw_value) == TYPE_STRING:
				return raw_value
		_:
			if typeof(raw_value) == typeof(default_value):
				return raw_value
	return default_value

func save_profile() -> bool:
	if _test_save_failures_remaining > 0:
		_test_save_failures_remaining -= 1
		push_warning("SaveManager: injected isolated-test save failure")
		return false
	var payload := profile.duplicate(true)
	var payload_json := JSON.stringify(payload)
	var envelope := {
		"schema": SAVE_SCHEMA,
		"payload_json": payload_json,
		"checksum": payload_json.sha256_text()
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: unable to open temporary save")
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	file = null
	var temp_abs := ProjectSettings.globalize_path(TEMP_PATH)
	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_abs := ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(backup_abs)
	if FileAccess.file_exists(SAVE_PATH):
		if DirAccess.rename_absolute(save_abs, backup_abs) != OK:
			push_error("SaveManager: failed to rotate backup")
			return false
	if DirAccess.rename_absolute(temp_abs, save_abs) != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(backup_abs, save_abs)
		push_error("SaveManager: failed atomic save promotion")
		return false
	profile_changed.emit(profile.duplicate(true))
	return true

func inject_isolated_test_save_failures(count: int) -> bool:
	if OS.get_environment("INFINIDIVE_TEST_ISOLATED") != "1":
		return false
	_test_save_failures_remaining = maxi(0,count)
	return true

func update_value(key: String, value: Variant, persist_now := true) -> void:
	profile[key] = value
	if persist_now:
		save_profile()

func add_currency(bio_matter: int, core_shards: int = 0) -> void:
	profile.bio_matter = max(0, int(profile.get("bio_matter", 0)) + bio_matter)
	profile.core_shards = max(0, int(profile.get("core_shards", 0)) + core_shards)
	save_profile()

static func high_score_key_for_run_result(run_result: Dictionary) -> String:
	var mode := String(run_result.get("mode", "story"))
	if mode in ["daily", "friend"]:
		var challenge_id := String(run_result.get("challenge_id", ""))
		# Never collapse unidentified competitive results into one mixed board.
		return "%s:%s" % [mode, challenge_id] if not challenge_id.is_empty() else ""
	return "%s:%s:%s" % [mode, String(run_result.get("boss_id", "gravemaw")), String(run_result.get("difficulty", "diver"))]

func bank_run(run_result: Dictionary) -> bool:
	var run_id := String(run_result.get("run_id", ""))
	if run_id.is_empty():
		push_error("SaveManager rejected a run without an id")
		return false
	var processed: Array = profile.get("processed_run_ids", [])
	if processed.has(run_id):
		return false
	var profile_before := profile.duplicate(true)
	processed.append(run_id)
	# This ledger is intentionally not truncated. Dropping old run IDs would let an
	# interrupted/replayed result be banked again after enough later runs.
	profile.processed_run_ids = processed
	profile.bio_matter = int(profile.get("bio_matter", 0)) + maxi(0, int(run_result.get("banked_bio", 0)))
	profile.core_shards = int(profile.get("core_shards", 0)) + maxi(0, int(run_result.get("banked_shards", 0)))
	profile.total_runs = int(profile.get("total_runs", 0)) + 1
	var high_scores: Dictionary = profile.get("high_scores", {})
	var score_key := high_score_key_for_run_result(run_result)
	if not score_key.is_empty():
		var prior: Dictionary = high_scores.get(score_key, {})
		var candidate_score := maxi(0, int(run_result.get("score", 0)))
		var candidate_time := maxf(0.0, float(run_result.get("elapsed", 0.0)))
		if prior.is_empty() or candidate_score > int(prior.get("score", -1)) or (candidate_score == int(prior.get("score", -1)) and candidate_time < float(prior.get("elapsed", INF))):
			high_scores[score_key] = {"score": candidate_score, "elapsed": candidate_time, "won": bool(run_result.get("won", false)), "challenge_id":String(run_result.get("challenge_id", ""))}
	profile.high_scores = high_scores
	if bool(run_result.get("won", false)):
		profile.total_wins = int(profile.get("total_wins", 0)) + 1
		var boss_id := String(run_result.get("boss_id", "gravemaw"))
		var clears: Dictionary = profile.get("boss_clears", {})
		clears[boss_id] = int(clears.get(boss_id, 0)) + 1
		profile.boss_clears = clears
		var boss_order := ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]
		var next_index := boss_order.find(boss_id) + 1
		if next_index > 0 and next_index < boss_order.size() and not profile.unlocked_bosses.has(boss_order[next_index]):
			profile.unlocked_bosses.append(boss_order[next_index])
		var weapon_unlocks := {"gravemaw":"rail_spine","seraph_9":"arc_swarm","abyss_leviathan":"void_orbitals"}
		if weapon_unlocks.has(boss_id) and not profile.unlocked_weapons.has(weapon_unlocks[boss_id]):
			profile.unlocked_weapons.append(weapon_unlocks[boss_id])
		if boss_id == "null_twin":
			profile.abyss_unlocked = true
		if String(run_result.get("mode", "story")) == "story":
			var difficulty := String(run_result.get("difficulty", "diver"))
			var difficulty_progress: Dictionary = profile.get("difficulty_progress", {})
			difficulty_progress[difficulty] = maxi(int(difficulty_progress.get(difficulty, 0)), boss_order.find(boss_id) + 1)
			profile.difficulty_progress = difficulty_progress
	profile.nest_stage = clampi(maxi(int(profile.get("nest_stage", 0)), int(profile.total_wins)), 0, 4)
	if not save_profile():
		profile = profile_before
		profile_changed.emit(profile.duplicate(true))
		return false
	return true

func reset_progress() -> bool:
	var profile_before := profile.duplicate(true)
	profile = default_profile()
	if not save_profile():
		profile = profile_before
		profile_changed.emit(profile.duplicate(true))
		return false
	# Reset is intentional deletion. Replace the rotated pre-reset generation
	# with a backup of the new blank profile so corruption cannot resurrect it.
	var backup_abs := ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(backup_abs)
	var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), backup_abs)
	if copy_error != OK:
		push_warning("SaveManager: reset completed without a recovery backup")
	return true
