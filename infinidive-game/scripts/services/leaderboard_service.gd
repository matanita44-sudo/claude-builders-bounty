extends Node

## Deterministic offline leaderboard and submission outbox. No network calls or
## credentials live here. A future backend adapter should pull validated pending
## records from export_pending() and acknowledge them explicitly.

signal queue_changed(pending_count: int)

const RemoteConfigClass := preload("res://scripts/services/remote_config_service.gd")
const ChallengeCodeClass := preload("res://scripts/core/challenge_code.gd")
const QUEUE_SCHEMA := 1
const DEFAULT_QUEUE_PATH := "user://infinidive_leaderboard_queue.json"
const ALLOWED_MODES := ["story", "daily", "friend", "abyss"]
const ALLOWED_BOSSES := ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]
const ALLOWED_WEAPONS := ["pulse_needle", "scatter_maw", "rail_spine", "arc_swarm", "void_orbitals"]
const ALLOWED_DIFFICULTIES := ["diver", "deep", "abyss"]
const COMPETITIVE_MODES := ["daily", "friend"]
const MAX_MUTATIONS := 24

var queue_path := DEFAULT_QUEUE_PATH
var backup_path := DEFAULT_QUEUE_PATH + ".backup"
var temporary_path := DEFAULT_QUEUE_PATH + ".tmp"
var entries: Array = []
var recovered_from_backup := false
var last_storage_status := "not_loaded"
var _initialized := false
var _config_snapshot: Dictionary = RemoteConfigClass._safe_defaults()

func _ready() -> void:
	if not _initialized:
		initialize()

func configure_storage(primary_path: String) -> void:
	if _initialized:
		push_warning("LeaderboardService storage cannot change after initialization")
		return
	queue_path = primary_path
	backup_path = primary_path + ".backup"
	temporary_path = primary_path + ".tmp"

func initialize(config_snapshot: Dictionary = {}) -> void:
	if _initialized:
		return
	_initialized = true
	if not config_snapshot.is_empty():
		_config_snapshot = _sanitize_config_snapshot(config_snapshot)
	else:
		var config := RemoteConfigClass.new()
		config.load_local_config()
		_config_snapshot = config.export_snapshot()
		config.free()
	load_queue()

func validate_run(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var run_id := String(raw.get("run_id", ""))
	if not _is_safe_identifier(run_id, 8, 96):
		errors.append("invalid_run_id")
	var mode := String(raw.get("mode", ""))
	if not ALLOWED_MODES.has(mode):
		errors.append("invalid_mode")
	errors.append_array(_challenge_identity_errors(raw, mode))
	if not ALLOWED_BOSSES.has(String(raw.get("boss_id", ""))):
		errors.append("invalid_boss")
	if not ALLOWED_WEAPONS.has(String(raw.get("weapon_id", ""))):
		errors.append("invalid_weapon")
	if not ALLOWED_DIFFICULTIES.has(String(raw.get("difficulty", ""))):
		errors.append("invalid_difficulty")
	var seed := int(raw.get("seed", 0))
	if seed < 1 or seed > 2147483646:
		errors.append("invalid_seed")
	var maximum_score := int((_config_snapshot.limits as Dictionary).get("maximum_score", 50000000))
	var score := int(raw.get("score", -1))
	if score < 0 or score > maximum_score:
		errors.append("invalid_score")
	var maximum_duration := int((_config_snapshot.limits as Dictionary).get("maximum_run_duration_ms", 14400000))
	var duration_ms := int(raw.get("duration_ms", 0))
	if duration_ms < 1000 or duration_ms > maximum_duration:
		errors.append("invalid_duration")
	if score > 0 and duration_ms > 0 and score > (duration_ms * 500 + 1000000):
		errors.append("implausible_score_rate")
	var organs: Variant = raw.get("organs_destroyed", [])
	if typeof(organs) != TYPE_ARRAY:
		errors.append("invalid_organs")
	else:
		var seen_organs: Dictionary = {}
		if (organs as Array).size() > 3:
			errors.append("invalid_organs")
		for organ_value in organs:
			var organ := String(organ_value)
			if not _is_safe_identifier(organ, 2, 48) or seen_organs.has(organ):
				errors.append("invalid_organs")
				break
			seen_organs[organ] = true
		if bool(raw.get("won", false)) and (organs as Array).size() != 3:
			errors.append("won_without_all_organs")
	var mutations: Variant = raw.get("mutations", [])
	if typeof(mutations) != TYPE_ARRAY or (mutations as Array).size() > MAX_MUTATIONS:
		errors.append("invalid_mutations")
	else:
		for mutation_value in mutations:
			if not _is_safe_identifier(String(mutation_value), 2, 48):
				errors.append("invalid_mutations")
				break
	var events: Variant = raw.get("event_summary", {})
	if typeof(events) != TYPE_DICTIONARY or not _valid_event_summary(events as Dictionary, organs as Array if typeof(organs) == TYPE_ARRAY else []):
		errors.append("invalid_event_summary")
	return _deduplicate_strings(errors)

func submit_run(raw: Dictionary) -> Dictionary:
	if not _initialized:
		initialize()
	var errors := validate_run(raw)
	if not errors.is_empty():
		return {"accepted": false, "queued": false, "status": "validation_failed", "errors": errors}
	var normalized := _normalize_run(raw)
	if String(normalized.mode) not in COMPETITIVE_MODES:
		# Story and Abyss scores are retained by SaveManager. They never occupy the
		# bounded upload outbox, which is reserved for comparable fixed challenges.
		return {
			"accepted": true,
			"queued": false,
			"duplicate": false,
			"status": "local_only_noncompetitive",
			"submission_id": ""
		}
	var submission_id := _submission_id(normalized)
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if String(entry.get("submission_id", "")) == submission_id:
			return {
				"accepted": true,
				"queued": String(entry.get("status", "pending")) == "pending",
				"duplicate": true,
				"status": "already_queued",
				"submission_id": submission_id
			}
	var queue_limit := int((_config_snapshot.limits as Dictionary).get("offline_submission_queue", 256))
	if entries.size() >= queue_limit:
		return {"accepted": false, "queued": false, "status": "queue_full", "errors": ["queue_full"]}
	entries.append({
		"submission_id": submission_id,
		"status": "pending",
		"attempts": 0,
		"verification": "unverified_local",
		"run": normalized
	})
	if not _persist_queue_atomic():
		entries.pop_back()
		return {"accepted": false, "queued": false, "status": "storage_error", "errors": ["storage_error"]}
	queue_changed.emit(pending_count())
	return {
		"accepted": true,
		"queued": true,
		"duplicate": false,
		"status": "offline_queued",
		"submission_id": submission_id
	}

func pending_count() -> int:
	var count := 0
	for raw_entry in entries:
		if String((raw_entry as Dictionary).get("status", "pending")) == "pending":
			count += 1
	return count

func export_pending() -> Array:
	var pending: Array = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if String(entry.get("status", "pending")) == "pending":
			pending.append(entry.duplicate(true))
	return pending

func flush_pending() -> Dictionary:
	# Deterministic failure is intentional: no HTTPRequest or vendor SDK exists in
	# this service. Pending results remain intact for a future approved adapter.
	var requested := bool((_config_snapshot.features as Dictionary).get("leaderboard_remote_enabled", false))
	return {
		"status": "transport_unavailable" if requested else "transport_disabled",
		"attempted": 0,
		"sent": 0,
		"remaining": pending_count()
	}

func get_local_leaderboard(mode: String, boss_id: String, difficulty: String, challenge_id: String = "", limit: int = 20) -> Array[Dictionary]:
	# Competitive boards without an exact canonical challenge identity would mix
	# different Daily seeds or Friend codes, so fail closed instead.
	if mode in COMPETITIVE_MODES and challenge_id.is_empty():
		return []
	var matches: Array[Dictionary] = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		var run: Dictionary = entry.get("run", {})
		if String(run.get("mode", "")) == mode and String(run.get("boss_id", "")) == boss_id and String(run.get("difficulty", "")) == difficulty and String(run.get("challenge_id", "")) == challenge_id:
			matches.append({
				"submission_id": String(entry.get("submission_id", "")),
				"run_id": String(run.get("run_id", "")),
				"challenge_id": String(run.get("challenge_id", "")),
				"boss_id": String(run.get("boss_id", "")),
				"difficulty": String(run.get("difficulty", "")),
				"score": int(run.get("score", 0)),
				"duration_ms": int(run.get("duration_ms", 0)),
				"weapon_id": String(run.get("weapon_id", "")),
				"won": bool(run.get("won", false)),
				"verification": String(entry.get("verification", "unverified_local"))
			})
	matches.sort_custom(_rank_before)
	var page_size := mini(limit, int((_config_snapshot.limits as Dictionary).get("leaderboard_page_size", 50)))
	page_size = clampi(page_size, 0, 100)
	if matches.size() > page_size:
		matches.resize(page_size)
	for index in matches.size():
		matches[index]["rank"] = index + 1
	return matches

func load_queue() -> void:
	recovered_from_backup = false
	var loaded := _read_queue_envelope(queue_path)
	last_storage_status = "loaded_primary"
	if loaded.is_empty() and FileAccess.file_exists(queue_path):
		loaded = _read_queue_envelope(backup_path)
		if not loaded.is_empty():
			recovered_from_backup = true
			last_storage_status = "recovered_backup"
	if loaded.is_empty():
		entries = []
		if not FileAccess.file_exists(queue_path):
			last_storage_status = "empty"
		elif not recovered_from_backup:
			last_storage_status = "corrupt_empty"
	else:
		entries = loaded
	queue_changed.emit(pending_count())

## Permanently clears the local competitive-result outbox and every recovery
## generation. Sidecars are removed before the primary; memory is cleared only
## after every removal succeeds, leaving the canonical primary intact if a
## sidecar deletion fails.
func clear_local_data() -> bool:
	for path in [temporary_path, backup_path, queue_path]:
		if not FileAccess.file_exists(path):
			continue
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if remove_error != OK or FileAccess.file_exists(path):
			last_storage_status = "clear_failed"
			push_error("LeaderboardService: failed to clear local queue generation: " + path)
			return false
	entries.clear()
	recovered_from_backup = false
	last_storage_status = "cleared"
	queue_changed.emit(0)
	return true

func _persist_queue_atomic() -> bool:
	var payload_json := JSON.stringify(entries, "", true)
	var envelope := {"schema": QUEUE_SCHEMA, "payload_json": payload_json, "checksum": payload_json.sha256_text()}
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_storage_status = "temporary_open_failed"
		return false
	file.store_string(JSON.stringify(envelope, "", true))
	file.flush()
	file = null
	var temp_abs := ProjectSettings.globalize_path(temporary_path)
	var primary_abs := ProjectSettings.globalize_path(queue_path)
	var backup_abs := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_abs)
	if FileAccess.file_exists(queue_path):
		if DirAccess.rename_absolute(primary_abs, backup_abs) != OK:
			last_storage_status = "backup_rotation_failed"
			return false
	if DirAccess.rename_absolute(temp_abs, primary_abs) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_abs, primary_abs)
		last_storage_status = "promotion_failed"
		return false
	last_storage_status = "saved"
	return true

func _read_queue_envelope(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return []
	var decoded: Variant = parser.data
	if typeof(decoded) != TYPE_DICTIONARY:
		return []
	var envelope: Dictionary = decoded
	if int(envelope.get("schema", 0)) != QUEUE_SCHEMA:
		return []
	var payload_json := String(envelope.get("payload_json", ""))
	if payload_json.is_empty() or String(envelope.get("checksum", "")) != payload_json.sha256_text():
		return []
	var payload_parser := JSON.new()
	if payload_parser.parse(payload_json) != OK:
		return []
	var payload: Variant = payload_parser.data
	if typeof(payload) != TYPE_ARRAY:
		return []
	var safe_entries: Array = []
	for raw_entry in payload:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return []
		var entry: Dictionary = raw_entry
		if not _is_safe_identifier(String(entry.get("submission_id", "")), 16, 64):
			return []
		if String(entry.get("status", "")) not in ["pending", "submitted"]:
			return []
		var run: Variant = entry.get("run", {})
		if typeof(run) != TYPE_DICTIONARY or not validate_run(run as Dictionary).is_empty():
			return []
		if String((run as Dictionary).get("mode", "")) not in COMPETITIVE_MODES:
			return []
		var normalized_run := _normalize_run(run as Dictionary)
		if _submission_id(normalized_run) != String(entry.get("submission_id", "")):
			return []
		safe_entries.append({
			"submission_id": String(entry.get("submission_id", "")),
			"status": String(entry.get("status", "pending")),
			"attempts": clampi(int(entry.get("attempts", 0)), 0, 1000),
			"verification": "unverified_local" if String(entry.get("verification", "")) != "verified_remote" else "verified_remote",
			"run": normalized_run
		})
	return safe_entries

func _normalize_run(raw: Dictionary) -> Dictionary:
	var organs: Array[String] = []
	for value in raw.get("organs_destroyed", []):
		organs.append(String(value))
	var mutations: Array[String] = []
	for value in raw.get("mutations", []):
		mutations.append(String(value))
	var event_summary := _normalize_event_summary(raw.get("event_summary", {}))
	return {
		"run_id": String(raw.get("run_id", "")),
		"mode": String(raw.get("mode", "")),
		"challenge_id": String(raw.get("challenge_id", "")) if String(raw.get("mode", "")) in COMPETITIVE_MODES else "",
		"challenge_day_utc": String(raw.get("challenge_day_utc", "")) if String(raw.get("mode", "")) == "daily" else "",
		"boss_id": String(raw.get("boss_id", "")),
		"weapon_id": String(raw.get("weapon_id", "")),
		"difficulty": String(raw.get("difficulty", "")),
		"seed": int(raw.get("seed", 0)),
		"modifiers": ChallengeCodeClass.canonical_modifiers(raw.get("modifiers", [])),
		"target_score": maxi(0, int(raw.get("target_score", 0))),
		"target_time_ms": maxi(0, int(raw.get("target_time_ms", 0))),
		"score": int(raw.get("score", 0)),
		"duration_ms": int(raw.get("duration_ms", 0)),
		"won": bool(raw.get("won", false)),
		"organs_destroyed": organs,
		"mutations": mutations,
		"event_summary": event_summary,
		"event_digest": JSON.stringify(event_summary, "", true).sha256_text(),
		"client_version": String(raw.get("client_version", ProjectSettings.get_setting("application/config/version", "0"))).left(32)
	}

func _submission_id(normalized: Dictionary) -> String:
	return "sub_" + JSON.stringify(normalized, "", true).sha256_text().left(32)

func _challenge_identity_errors(raw: Dictionary, mode: String) -> Array[String]:
	var errors: Array[String] = []
	if mode not in COMPETITIVE_MODES:
		return errors
	var challenge_id := String(raw.get("challenge_id", ""))
	if not _is_safe_identifier(challenge_id, 16, 96):
		errors.append("invalid_challenge_id")
	var modifiers: Variant = raw.get("modifiers", [])
	if typeof(modifiers) != TYPE_ARRAY or (modifiers as Array).size() > 4:
		errors.append("invalid_challenge_modifiers")
	else:
		for modifier_value in modifiers as Array:
			if not _is_safe_identifier(String(modifier_value), 1, 48):
				errors.append("invalid_challenge_modifiers")
				break
	var maximum_score := int((_config_snapshot.limits as Dictionary).get("maximum_score", 50000000))
	var maximum_duration := int((_config_snapshot.limits as Dictionary).get("maximum_run_duration_ms", 14400000))
	if int(raw.get("target_score", 0)) < 0 or int(raw.get("target_score", 0)) > maximum_score:
		errors.append("invalid_target_score")
	if int(raw.get("target_time_ms", 0)) < 0 or int(raw.get("target_time_ms", 0)) > maximum_duration:
		errors.append("invalid_target_time")
	var utc_day := String(raw.get("challenge_day_utc", ""))
	if mode == "daily" and not ChallengeCodeClass.is_valid_utc_day(utc_day):
		errors.append("invalid_challenge_day")
	var expected := ChallengeCodeClass.canonical_challenge_id(mode, raw, utc_day)
	if expected.is_empty() or challenge_id != expected:
		errors.append("invalid_challenge_id")
	return _deduplicate_strings(errors)

func _valid_event_summary(summary: Dictionary, organs: Array) -> bool:
	var allowed := ["shots_fired", "hits", "damage_taken", "dashes", "organs_destroyed", "max_projectiles", "major_events"]
	for key_value in summary:
		var key := String(key_value)
		if not allowed.has(key):
			return false
		var value: Variant = summary[key_value]
		if key == "major_events":
			if typeof(value) != TYPE_ARRAY or (value as Array).size() > 64:
				return false
			for event_value in value:
				if not _is_safe_identifier(String(event_value), 2, 48):
					return false
		else:
			if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
				return false
			var numeric := float(value)
			if not is_finite(numeric) or numeric != floor(numeric) or int(value) < 0 or int(value) > 10000000:
				return false
	if int(summary.get("organs_destroyed", organs.size())) != organs.size():
		return false
	return true

func _normalize_event_summary(raw: Dictionary) -> Dictionary:
	var major_events: Array[String] = []
	for value in raw.get("major_events", []):
		major_events.append(String(value))
	return {
		"shots_fired": int(raw.get("shots_fired", 0)),
		"hits": int(raw.get("hits", 0)),
		"damage_taken": int(raw.get("damage_taken", 0)),
		"dashes": int(raw.get("dashes", 0)),
		"organs_destroyed": int(raw.get("organs_destroyed", 0)),
		"max_projectiles": int(raw.get("max_projectiles", 0)),
		"major_events": major_events
	}

func _sanitize_config_snapshot(raw: Dictionary) -> Dictionary:
	var safe: Dictionary = RemoteConfigClass._safe_defaults()
	var features: Variant = raw.get("features", {})
	if typeof(features) == TYPE_DICTIONARY:
		for key in safe.features:
			var value: Variant = (features as Dictionary).get(key, false)
			safe.features[key] = value if typeof(value) == TYPE_BOOL else false
	var limits: Variant = raw.get("limits", {})
	if typeof(limits) == TYPE_DICTIONARY:
		safe.limits.offline_submission_queue = clampi(int((limits as Dictionary).get("offline_submission_queue", 256)), 1, 2000)
		safe.limits.leaderboard_page_size = clampi(int((limits as Dictionary).get("leaderboard_page_size", 50)), 1, 100)
		safe.limits.maximum_score = clampi(int((limits as Dictionary).get("maximum_score", 50000000)), 1000, 100000000)
		safe.limits.maximum_run_duration_ms = clampi(int((limits as Dictionary).get("maximum_run_duration_ms", 14400000)), 1000, 86400000)
	return safe

func _rank_before(left: Dictionary, right: Dictionary) -> bool:
	if int(left.score) != int(right.score):
		return int(left.score) > int(right.score)
	if int(left.duration_ms) != int(right.duration_ms):
		return int(left.duration_ms) < int(right.duration_ms)
	return String(left.submission_id) < String(right.submission_id)

func _is_safe_identifier(value: String, minimum: int, maximum: int) -> bool:
	if value.length() < minimum or value.length() > maximum:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var accepted := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [45, 95]
		if not accepted:
			return false
	return true

func _deduplicate_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result
