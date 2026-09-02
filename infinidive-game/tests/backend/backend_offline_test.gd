extends Node

const RemoteConfigClass := preload("res://scripts/services/remote_config_service.gd")
const LeaderboardClass := preload("res://scripts/services/leaderboard_service.gd")
const ChallengeCodeClass := preload("res://scripts/core/challenge_code.gd")
const SaveManagerClass := preload("res://scripts/services/save_manager.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const AnalyticsClass := preload("res://scripts/services/analytics_service.gd")
const TEST_PATH := "user://infinidive_backend_offline_focused_test.json"
const SATURATION_PATH := "user://infinidive_backend_saturation_focused_test.json"
const ANALYTICS_PATH := "user://infinidive_backend_analytics_privacy_test.json"

var passed := 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("BACKEND TEST FAILURE: " + message)

func _run() -> void:
	_cleanup()
	_test_remote_config()
	_test_fail_closed_config()
	_test_analytics_privacy_contract()
	_test_submission_validation_queue_and_ranking()
	_test_canonical_identity_and_story_queue_isolation()
	_test_atomic_recovery()
	_test_complete_local_data_deletion()
	_cleanup()
	print("INFINIDIVE BACKEND TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

func _test_remote_config() -> void:
	var config := RemoteConfigClass.new()
	_check(config.load_local_config(), "Shipped local config must load")
	for feature in RemoteConfigClass.FEATURE_DEFAULTS:
		_check(not config.is_enabled(feature), "Shipped risky feature must default off: %s" % feature)
	_check(not config.has_network_transport(), "Local config service must not expose a network transport")
	_check(String(config.export_snapshot().transport.provider) == "none", "Shipped provider must be none")
	config.free()

func _test_analytics_privacy_contract() -> void:
	var original_values := SettingsManager.values.duplicate(true)
	var service := AnalyticsClass.new()
	service.queue_path = ANALYTICS_PATH
	_check(not service.has_network_transport(), "Analytics abstraction must not expose a network transport")

	SettingsManager.values["analytics_opt_in"] = true
	service.track("first_dive", {"seed": 7719})
	_check(service.queue.size() == 1 and FileAccess.file_exists(ANALYTICS_PATH), "Literal Boolean true must enable the bounded local diagnostics queue")

	var malformed_truthy_values: Array = [1, 1.0, "true", "1", [true], {"enabled": true}]
	for malformed: Variant in malformed_truthy_values:
		SettingsManager.values["analytics_opt_in"] = malformed
		service.track("first_dash")
		_check(service.queue.is_empty(), "Malformed truthy analytics consent must fail closed: %s" % JSON.stringify(malformed))
		_check(not FileAccess.file_exists(ANALYTICS_PATH), "Fail-closed consent must delete the local queue: %s" % JSON.stringify(malformed))

	# Stage legacy data through the low-level persistence hook, then prove an
	# opted-out boot removes it without ever deserializing it into memory.
	service.queue = [{"event":"first_dive","properties":{},"session_id":"legacy","timestamp":"2026-09-01T00:00:00Z"}]
	_check(service._persist_queue(), "Analytics privacy test must stage a legacy local queue")
	service.queue.clear()
	SettingsManager.values["analytics_opt_in"] = false
	service._ready()
	_check(not service.disk_load_attempted, "Opted-out boot must not load pending diagnostics into memory")
	_check(service.queue.is_empty() and not FileAccess.file_exists(ANALYTICS_PATH), "Opted-out boot must retry and complete pending local deletion")

	SettingsManager.values = original_values
	service.free()

func _test_fail_closed_config() -> void:
	var config := RemoteConfigClass.new()
	_check(not config.load_local_config("res://data/does_not_exist.json"), "Missing config must report fallback")
	for feature in RemoteConfigClass.FEATURE_DEFAULTS:
		_check(not config.is_enabled(feature), "Missing config must fail closed: %s" % feature)
	config.free()

func _test_submission_validation_queue_and_ranking() -> void:
	var service := LeaderboardClass.new()
	service.configure_storage(TEST_PATH)
	service.initialize()
	var invalid := _valid_run("invalid-score", 1000, 120000)
	invalid.score = -1
	var rejected: Dictionary = service.submit_run(invalid)
	_check(not bool(rejected.accepted) and rejected.errors.has("invalid_score"), "Negative score must be rejected")
	_check(service.pending_count() == 0, "Rejected runs must not enter the queue")

	var first := _valid_run("run-alpha-0001", 9000, 90000)
	var first_result: Dictionary = service.submit_run(first)
	_check(bool(first_result.accepted) and bool(first_result.queued), "Valid run must be queued offline")
	_check(String(first_result.status) == "offline_queued", "Offline submission status must be explicit")
	var duplicate: Dictionary = service.submit_run(first)
	_check(bool(duplicate.accepted) and bool(duplicate.duplicate), "Identical run must be idempotent")
	_check(service.pending_count() == 1, "Duplicate run must not duplicate the outbox")

	var faster := _valid_run("run-bravo-0002", 12000, 80000)
	var tied_slow := _valid_run("run-charlie-003", 12000, 85000)
	_check(bool(service.submit_run(faster).accepted), "Second valid run must queue")
	_check(bool(service.submit_run(tied_slow).accepted), "Third valid run must queue")
	var challenge_id := String(first.challenge_id)
	var other_daily := _valid_run("run-delta-0004", 40000, 70000)
	other_daily.seed = int(other_daily.seed) + 1
	other_daily.challenge_id = ChallengeCodeClass.daily_challenge_id(other_daily, String(other_daily.challenge_day_utc))
	_check(bool(service.submit_run(other_daily).accepted), "A second Daily seed must queue under its own identity")
	var friend_a := _friend_run("run-friend-0005", 18000, 78000, 18000, 78000)
	var friend_b := _friend_run("run-friend-0006", 19000, 77000, 19000, 77000)
	_check(bool(service.submit_run(friend_a).accepted) and bool(service.submit_run(friend_b).accepted), "Distinct Friend challenge targets must queue separately")
	var board := service.get_local_leaderboard("daily", "gravemaw", "diver", challenge_id, 20)
	_check(board.size() == 3, "Local leaderboard must include accepted matching runs")
	_check(String(board[0].run_id) == "run-bravo-0002", "Ranking must prefer higher score then shorter time")
	_check(String(board[1].run_id) == "run-charlie-003", "Ranking tie-break must be deterministic")
	_check(int(board[0].rank) == 1 and int(board[2].rank) == 3, "Local ranks must be contiguous")
	_check(String(board[0].verification) == "unverified_local", "Offline scores must not pretend to be verified")
	_check(service.get_local_leaderboard("daily", "gravemaw", "diver", String(other_daily.challenge_id), 20).size() == 1, "Daily boards must not mix different seeds")
	_check(service.get_local_leaderboard("daily", "gravemaw", "diver").is_empty(), "A competitive leaderboard query without challenge identity must fail closed")
	_check(service.get_local_leaderboard("friend", "gravemaw", "diver", String(friend_a.challenge_id), 20).size() == 1, "Friend boards must not mix different challenge codes")
	var flush_a := service.flush_pending()
	var flush_b := service.flush_pending()
	_check(flush_a == flush_b and String(flush_a.status) == "transport_disabled", "Disabled transport failure must be deterministic")
	_check(service.pending_count() == 6, "Failed flush must retain every pending result")

	var fresh := LeaderboardClass.new()
	fresh.configure_storage(TEST_PATH)
	fresh.initialize()
	_check(fresh.pending_count() == 6, "Atomic queue must survive service restart")
	var fresh_json := JSON.stringify(fresh.export_pending(), "", true)
	var service_json := JSON.stringify(service.export_pending(), "", true)
	_check(
		fresh_json == service_json,
		"Persisted pending order and values must be stable"
	)
	service.free()
	fresh.free()

func _test_canonical_identity_and_story_queue_isolation() -> void:
	var semantic_a := {"boss":"null_twin","seed":88123,"weapon":"rail_spine","difficulty":"abyss","modifiers":["swift","dense"],"target_score":9000,"target_time_ms":80000}
	var semantic_b := semantic_a.duplicate(true)
	semantic_b.modifiers = ["dense", "swift"]
	var friend_id := ChallengeCodeClass.friend_challenge_id(semantic_a)
	_check(friend_id == ChallengeCodeClass.friend_challenge_id(semantic_b), "Friend identity must sort modifiers before hashing")
	semantic_b.target_score = 9001
	_check(friend_id != ChallengeCodeClass.friend_challenge_id(semantic_b), "Friend identity must include score and time targets")
	var day_a := "2026-09-01"
	var day_b := "2026-09-02"
	var daily := _valid_run("identity-daily-01", 1000, 30000)
	_check(ChallengeCodeClass.is_valid_utc_day("2028-02-29") and not ChallengeCodeClass.is_valid_utc_day("2026-02-29"), "Daily UTC day validation must handle leap years")
	var sampled_seeds_in_range := true
	for month in range(1, 13):
		for day in range(1, 29):
			var sampled_seed := ChallengeCodeClass.daily_seed({"year": 2026, "month": month, "day": day})
			if sampled_seed < 1 or sampled_seed > 2147483646:
				sampled_seeds_in_range = false
	_check(sampled_seeds_in_range, "Daily seeds must remain inside the validated deterministic range")
	_check(ChallengeCodeClass.daily_challenge_id(daily, day_a) != ChallengeCodeClass.daily_challenge_id(daily, day_b), "Daily identity must include its UTC day")
	var run_scene := RunSceneClass.new()
	run_scene.initialize({"mode":"daily","boss":"gravemaw","weapon":"pulse_needle","difficulty":"diver","seed":int(daily.seed),"modifiers":["daily_standard"],"challenge_day_utc":day_a})
	run_scene._apply_config_defaults()
	_check(String(run_scene.config.challenge_id) == ChallengeCodeClass.daily_challenge_id(run_scene.config, day_a), "RunScene must preserve the canonical Daily identity in its run config")
	run_scene.initialize(semantic_a.merged({"mode":"friend"}, true))
	run_scene._apply_config_defaults()
	_check(String(run_scene.config.challenge_id) == friend_id, "RunScene must preserve the canonical Friend identity in its run config")
	run_scene.free()
	_check(SaveManagerClass.high_score_key_for_run_result({"mode":"daily","challenge_id":String(daily.challenge_id)}) == "daily:%s" % String(daily.challenge_id), "Daily high-score storage must include challenge identity")
	_check(SaveManagerClass.high_score_key_for_run_result({"mode":"friend","challenge_id":friend_id}) == "friend:%s" % friend_id, "Friend high-score storage must include challenge identity")
	_check(SaveManagerClass.high_score_key_for_run_result({"mode":"story","boss_id":"gravemaw","difficulty":"diver"}) == "story:gravemaw:diver", "Story high scores must retain their separate local key")

	var tiny_config := RemoteConfigClass._safe_defaults()
	tiny_config.limits.offline_submission_queue = 1
	var service := LeaderboardClass.new()
	service.configure_storage(SATURATION_PATH)
	service.initialize(tiny_config)
	for index in 5:
		var story := _valid_run("story-fill-%04d" % index, 500 + index, 30000)
		story.mode = "story"
		story.challenge_id = ""
		story.challenge_day_utc = ""
		var local_result: Dictionary = service.submit_run(story)
		_check(bool(local_result.accepted) and not bool(local_result.queued) and String(local_result.status) == "local_only_noncompetitive", "Story run %d must remain local-only" % index)
	_check(service.pending_count() == 0, "Story runs must not consume competitive outbox quota")
	var daily_after_story := _valid_run("daily-after-story", 7000, 40000)
	var queued: Dictionary = service.submit_run(daily_after_story)
	_check(bool(queued.accepted) and bool(queued.queued) and service.pending_count() == 1, "Daily result must queue after Story saturation attempt")
	var full: Dictionary = service.submit_run(_valid_run("daily-queue-full", 8000, 40000))
	_check(not bool(full.accepted) and String(full.status) == "queue_full", "Competitive queue limit must still be enforced")
	service.free()

func _test_atomic_recovery() -> void:
	# The latest primary contains six entries and its backup contains five. A
	# corrupted primary must recover that last known-good backup rather than trust
	# malformed content or erase the whole outbox.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	_check(file != null, "Focused test must be able to corrupt its scoped primary")
	if file != null:
		file.store_string("{corrupt")
		file.flush()
		file = null
	var recovered := LeaderboardClass.new()
	recovered.configure_storage(TEST_PATH)
	recovered.initialize()
	_check(recovered.recovered_from_backup, "Corrupt primary must recover from atomic backup")
	_check(recovered.pending_count() == 5, "Recovery must expose the previous complete queue")
	_check(String(recovered.last_storage_status) == "recovered_backup", "Recovery source must be inspectable")
	recovered.free()

func _test_complete_local_data_deletion() -> void:
	var service := LeaderboardClass.new()
	service.configure_storage(TEST_PATH)
	service.initialize()
	_check(service.pending_count() == 5, "Deletion test must load the last recoverable leaderboard generation")
	var stale_temp := FileAccess.open(service.temporary_path, FileAccess.WRITE)
	_check(stale_temp != null, "Deletion test must create a stale temporary generation")
	if stale_temp != null:
		stale_temp.store_string("stale-temp")
		stale_temp.flush()
		stale_temp = null
	_check(FileAccess.file_exists(service.queue_path) and FileAccess.file_exists(service.backup_path) and FileAccess.file_exists(service.temporary_path), "Deletion test must cover primary, backup, and temporary leaderboard files")
	_check(service.clear_local_data(), "Leaderboard local-data deletion must report success")
	_check(service.entries.is_empty() and service.pending_count() == 0, "Leaderboard local-data deletion must clear in-memory entries")
	_check(String(service.last_storage_status) == "cleared" and not service.recovered_from_backup, "Leaderboard deletion state must be inspectable and clear recovery flags")
	for path in [service.queue_path, service.backup_path, service.temporary_path]:
		_check(not FileAccess.file_exists(path), "Leaderboard local-data deletion must remove storage generation: %s" % path)
	_check(service.clear_local_data(), "Leaderboard local-data deletion must be idempotent")
	service.free()

func _valid_run(run_id: String, score: int, duration_ms: int) -> Dictionary:
	var run := {
		"run_id": run_id,
		"mode": "daily",
		"challenge_day_utc": "2026-09-01",
		"boss_id": "gravemaw",
		"weapon_id": "pulse_needle",
		"difficulty": "diver",
		"seed": 20260901,
		"modifiers": ["daily_standard"],
		"target_score": 0,
		"target_time_ms": 0,
		"score": score,
		"duration_ms": duration_ms,
		"won": true,
		"organs_destroyed": ["hunter_eye", "gravity_lung", "bone_forge"],
		"mutations": ["split_chamber"],
		"event_summary": {
			"shots_fired": 420,
			"hits": 260,
			"damage_taken": 24,
			"dashes": 8,
			"organs_destroyed": 3,
			"max_projectiles": 72,
			"major_events": ["breach_opened", "boss_victory"]
		},
		"client_version": "0.1.0"
	}
	run.challenge_id = ChallengeCodeClass.daily_challenge_id(run, String(run.challenge_day_utc))
	return run

func _friend_run(run_id: String, score: int, duration_ms: int, target_score: int, target_time_ms: int) -> Dictionary:
	var run := _valid_run(run_id, score, duration_ms)
	run.mode = "friend"
	run.challenge_day_utc = ""
	run.modifiers = ["swift", "dense"]
	run.target_score = target_score
	run.target_time_ms = target_time_ms
	run.challenge_id = ChallengeCodeClass.friend_challenge_id(run)
	return run

func _cleanup() -> void:
	for path in [TEST_PATH, TEST_PATH + ".backup", TEST_PATH + ".tmp", SATURATION_PATH, SATURATION_PATH + ".backup", SATURATION_PATH + ".tmp", ANALYTICS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
