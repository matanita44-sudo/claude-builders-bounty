extends Node

const MetaGoals := preload("res://scripts/services/meta_goal_service.gd")
const TEST_BAD_ACHIEVEMENTS := "user://infinidive_bad_achievements_test.json"
const TEST_BAD_CONTRACTS := "user://infinidive_bad_contracts_test.json"
const DATE_A := {"year": 2026, "month": 9, "day": 1}

var passed := 0
var failures: Array[String] = []
var event_sequence := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("META GOAL TEST FAILURE: " + message)


func _run() -> void:
	_cleanup()
	_test_catalogs_and_profile_contract()
	_test_utc_determinism_and_rotation()
	_test_persistence_signal_and_receipt_compaction()
	_test_receipt_capacity_fails_closed()
	_test_achievement_progress_and_idempotency()
	_test_contract_completion_rollover_and_persistence()
	_test_catalog_rejection_and_offline_boundary()
	_cleanup()
	print("INFINIDIVE META GOAL TESTS: %d passed, %d failed" % [passed, failures.size()])
	if not failures.is_empty():
		for failure in failures:
			print(" - " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_catalogs_and_profile_contract() -> void:
	var profile := {"bio_matter": -9, "core_shards": -2, "achievements": "corrupt", "contracts": []}
	var service := MetaGoals.new()
	_check(service.initialize(profile, DATE_A), "Shipped catalogs must initialize")
	_check(service.get_validation_errors().is_empty(), "Shipped catalogs must validate without errors")
	_check(service.achievements.size() == 14, "Catalog must expose fourteen meaningful achievements")
	_check(service.contracts.size() == 19, "Catalog must expose nineteen rotating contract templates")
	_check(not service.has_network_transport(), "Meta goals must be explicitly offline-only")
	_check(int(profile.bio_matter) == 0 and int(profile.core_shards) == 0, "Malformed negative currency must normalize safely")
	_check(typeof(profile.achievements) == TYPE_ARRAY, "Malformed achievement profile state must recover")
	_check(typeof(profile.contracts) == TYPE_DICTIONARY, "Malformed contract profile state must recover")
	_check(typeof(profile.meta_goal_state) == TYPE_DICTIONARY, "Caller profile must receive versioned meta state")
	_check(int(profile.meta_goal_state.schema_version) == 2, "Meta profile state must declare its receipt schema")
	_check(service.has_pending_profile_changes(), "Profile normalization and first UTC activation must request persistence")
	_check(service.receipt_count() == 0, "Initialization must not fabricate event receipts")
	service.mark_profile_persisted()
	_check(not service.has_pending_profile_changes(), "Successful caller persistence must clear the pending flag explicitly")
	var active := service.get_active_contracts()
	_check(active.size() == 3, "Exactly three daily contracts must be active")
	var slots: Array = active.map(func(goal: Dictionary) -> String: return String(goal.slot))
	slots.sort()
	_check(slots == ["build", "hunt", "skill"], "Daily selection must include one contract per design slot")
	for goal in active:
		_check(String(goal.day_key) == "2026-09-01", "Active contract must expose the UTC day key")
		_check(int(goal.progress) == 0 and not bool(goal.completed), "Fresh daily contract must start clean")
	service = null


func _test_utc_determinism_and_rotation() -> void:
	_check(MetaGoals.day_key_from_utc(DATE_A) == "2026-09-01", "UTC date must format canonically")
	_check(
		MetaGoals.day_key_from_utc({"year": 2024, "month": 2, "day": 31}) == "2024-02-29",
		"UTC day normalization must respect leap years"
	)
	_check(
		MetaGoals.day_key_from_utc({"year": 2025, "month": 2, "day": 31}) == "2025-02-28",
		"UTC day normalization must clamp non-leap February"
	)
	var first := MetaGoals.new()
	var second := MetaGoals.new()
	_check(first.initialize({}, DATE_A), "First deterministic service must initialize")
	_check(second.initialize({}, DATE_A), "Second deterministic service must initialize")
	var first_ids := first.select_contract_ids_for_date(DATE_A)
	var second_ids := second.select_contract_ids_for_date(DATE_A)
	_check(first_ids == second_ids, "Same UTC day must select the same contract IDs across instances")
	_check(first_ids == first.select_contract_ids_for_date(DATE_A), "Daily selection must be stable across repeated calls")

	var combinations: Dictionary = {}
	var ids_seen: Dictionary = {}
	for day in range(1, 29):
		var selected := first.select_contract_ids_for_date({"year": 2026, "month": 9, "day": day})
		combinations[JSON.stringify(selected)] = true
		for id_value in selected:
			ids_seen[String(id_value)] = true
	_check(combinations.size() >= 10, "A month must rotate through varied daily combinations")
	_check(ids_seen.size() >= 15, "A month must exercise broad contract catalog coverage")
	_check(first_ids != first.select_contract_ids_for_date({"year": 2026, "month": 9, "day": 2}), "Adjacent UTC days must rotate this shipped catalog")
	first = null
	second = null


func _test_persistence_signal_and_receipt_compaction() -> void:
	var profile := {"bio_matter": 0, "core_shards": 0, "achievements": [], "contracts": {}}
	var service := MetaGoals.new()
	_check(service.initialize(profile, DATE_A), "Persistence-contract service must initialize")
	service.mark_profile_persisted()

	var irrelevant := service.progress("untracked_event", {"event_id": "does-not-change-a-goal"})
	_check(bool(irrelevant.accepted) and not bool(irrelevant.changed), "Irrelevant event must be accepted as a no-op")
	_check(not bool(irrelevant.needs_persist), "No-op event must not request persistence")
	_check(service.receipt_count() == 0, "No-op event ID must not enter long-term storage")

	var missing_id := service.progress("organ_destroyed", {"organ_id": "hunter_eye"})
	_check(not bool(missing_id.accepted) and String(missing_id.status) == "missing_event_id", "Goal-changing event must require an idempotency ID")
	_check(int(profile.bio_matter) == 0 and service.receipt_count() == 0, "Rejected unreceipted event must not mutate goals or rewards")

	var changed := service.progress("organ_destroyed", {"event_id": "receipt-organ-1", "organ_id": "hunter_eye"})
	_check(bool(changed.accepted) and bool(changed.changed) and bool(changed.needs_persist), "Goal progress must report needs_persist")
	_check(service.has_pending_profile_changes(), "Goal progress must latch pending persistence until caller success")
	_check(service.receipt_count() == 1, "Changed event must create exactly one compact receipt")
	var compact_receipt := String((profile.meta_goal_state.processed_event_ids as Array)[0])
	_check(compact_receipt.begins_with(MetaGoals.RECEIPT_PREFIX) and compact_receipt.length() == 67, "Receipt must store a bounded SHA-256 fingerprint, not the raw event ID")
	_check(compact_receipt.find("receipt-organ-1") == -1, "Compact receipt must not retain the raw event identifier")
	service.mark_profile_persisted()
	var duplicate := service.progress("organ_destroyed", {"event_id": "receipt-organ-1", "organ_id": "hunter_eye"})
	_check(bool(duplicate.accepted) and bool(duplicate.duplicate), "Compact receipt must reject replay exactly once")
	_check(not bool(duplicate.needs_persist), "A persisted duplicate must not request another save")
	_check(service.receipt_count() == 1, "Duplicate event must not duplicate its receipt")

	service.activate_contracts_for_date({"year": 2026, "month": 9, "day": 2})
	_check(service.has_pending_profile_changes(), "UTC rollover must latch pending persistence even before gameplay progress")
	var after_rollover := service.progress("untracked_event", {"event_id": "rollover-no-op"})
	_check(bool(after_rollover.needs_persist), "Progress result after rollover must surface pending profile mutation")
	service.mark_profile_persisted()
	_check(not service.has_pending_profile_changes(), "Caller-confirmed rollover save must clear pending state")

	var legacy_profile := {
		"bio_matter": 0,
		"core_shards": 0,
		"achievements": [],
		"contracts": {},
		"meta_goal_state": {
			"schema_version": 1,
			"achievement_progress": {},
			"reward_ledger": [],
			"processed_event_ids": ["legacy-organ-event", "legacy-organ-event"]
		}
	}
	var migrated := MetaGoals.new()
	_check(migrated.initialize(legacy_profile, DATE_A), "Legacy raw receipt profile must migrate")
	_check(migrated.receipt_count() == 1, "Legacy raw and duplicate event IDs must compact to one fingerprint")
	_check(migrated.has_pending_profile_changes(), "Receipt migration must request caller persistence")
	var legacy_duplicate := migrated.progress("organ_destroyed", {"event_id": "legacy-organ-event", "organ_id": "hunter_eye"})
	_check(bool(legacy_duplicate.duplicate) and int(legacy_profile.bio_matter) == 0, "Migrated receipt must still block its replay reward")
	service = null
	migrated = null


func _test_receipt_capacity_fails_closed() -> void:
	var receipts: Array = []
	for index in MetaGoals.MAX_EVENT_RECEIPTS + 8:
		receipts.append(MetaGoals.RECEIPT_PREFIX + ("capacity-event-%d" % index).sha256_text())
	var profile := {
		"bio_matter": 0,
		"core_shards": 0,
		"achievements": [],
		"contracts": {},
		"meta_goal_state": {
			"schema_version": 2,
			"achievement_progress": {},
			"reward_ledger": [],
			"processed_event_ids": receipts
		}
	}
	var service := MetaGoals.new()
	_check(service.initialize(profile, DATE_A), "Saturated receipt profile must remain readable")
	service.mark_profile_persisted()
	_check(service.receipt_count() == MetaGoals.MAX_EVENT_RECEIPTS and service.receipt_capacity_remaining() == 0, "Oversized legacy receipt ledger must compact to its hard bound")
	var rejected := service.progress("organ_destroyed", {"event_id": "new-event-after-capacity", "organ_id": "hunter_eye"})
	_check(not bool(rejected.accepted) and String(rejected.status) == "receipt_capacity", "New goal-changing event must fail closed at receipt capacity")
	_check(int(profile.bio_matter) == 0 and not bool(rejected.needs_persist), "Capacity rejection must not mutate progress, reward, or persistence state")
	var known_duplicate := service.progress("organ_destroyed", {"event_id": "capacity-event-0", "organ_id": "hunter_eye"})
	_check(bool(known_duplicate.accepted) and bool(known_duplicate.duplicate), "Known replay must still be recognized after saturation")
	var compacted_replay := service.progress("organ_destroyed", {"event_id": "capacity-event-%d" % (MetaGoals.MAX_EVENT_RECEIPTS + 1), "organ_id": "hunter_eye"})
	_check(not bool(compacted_replay.accepted) and String(compacted_replay.status) == "receipt_capacity", "Compacted legacy receipt must fail closed rather than replay a reward")
	var harmless := service.progress("untracked_event", {"event_id": "harmless-after-capacity"})
	_check(bool(harmless.accepted) and not bool(harmless.changed), "Receipt saturation must not reject events that cannot affect goals")
	_check(service.receipt_count() == MetaGoals.MAX_EVENT_RECEIPTS, "Fail-closed capacity path must never evict an old receipt")
	service = null


func _test_achievement_progress_and_idempotency() -> void:
	var profile := {"bio_matter": 0, "core_shards": 0, "achievements": [], "contracts": {}}
	var service := MetaGoals.new()
	_check(service.initialize(profile, DATE_A), "Achievement test service must initialize")

	var first := service.progress("organ_destroyed", {"event_id": "organ-01", "organ_id": "hunter_eye"})
	_check(bool(first.accepted) and first.completions.size() >= 1, "First organ must complete First Incision")
	_check(profile.achievements.has("first_incision"), "First Incision completion must persist in caller profile")
	_check(int(profile.bio_matter) == 60, "First Incision must grant its exact reward")
	var duplicate := service.progress("organ_destroyed", {"event_id": "organ-01", "organ_id": "hunter_eye"})
	_check(bool(duplicate.duplicate) and not bool(duplicate.changed), "Repeated event ID must be idempotent")
	_check(int(profile.bio_matter) == 60, "Repeated event ID must not duplicate rewards")

	var organs := [
		"hunter_eye", "gravity_lung", "bone_forge",
		"prism_cortex", "wing_reactor", "halo_choir",
		"vortex_stomach", "shock_gland", "brood_sac",
		"memory_cortex", "echo_heart", "reflection_lattice"
	]
	for index in range(1, organs.size()):
		service.progress("organ_destroyed", {"event_id": "organ-%02d" % (index + 1), "organ_id": organs[index]})
	_check(profile.achievements.has("anatomy_student"), "Three unique organs must complete Anatomy Student")
	_check(profile.achievements.has("complete_anatomy"), "Twelve unique organs must complete Complete Anatomy")
	_check(int(profile.core_shards) == 2, "Complete Anatomy must grant two Core Shards")
	var bio_after_organs := int(profile.bio_matter)
	service.progress("organ_destroyed", {"organ_id": "hunter_eye"})
	_check(int(profile.bio_matter) == bio_after_organs, "Completed organ goals must never pay twice without an event ID")

	var bosses := ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]
	for index in bosses.size():
		service.progress("run_complete", {
			"event_id": "boss-win-%d" % index,
			"won": true,
			"boss_id": bosses[index],
			"weapon_id": "pulse_needle",
			"difficulty": "diver",
			"damage_taken": 30,
			"duration_ms": 420000
		})
	_check(profile.achievements.has("gravebreaker"), "Gravemaw victory achievement must complete")
	_check(profile.achievements.has("silence_the_choir"), "Seraph-9 victory achievement must complete")
	_check(profile.achievements.has("harpoon_the_abyss"), "Leviathan victory achievement must complete")
	_check(profile.achievements.has("break_the_mirror"), "Null Twin victory achievement must complete")
	_check(profile.achievements.has("colossus_archive"), "Four unique boss victories must complete the archive")

	var weapons := ["pulse_needle", "scatter_maw", "rail_spine", "arc_swarm", "void_orbitals"]
	for index in range(1, weapons.size()):
		service.progress("run_complete", {
			"event_id": "weapon-win-%d" % index,
			"won": true,
			"boss_id": "gravemaw",
			"weapon_id": weapons[index],
			"difficulty": "diver",
			"damage_taken": 30,
			"duration_ms": 420000
		})
	_check(profile.achievements.has("arsenal_master"), "Wins with five unique weapons must complete Arsenal Master")

	for index in 50:
		service.progress("dash_used", {"event_id": "dash-%d" % index})
	_check(profile.achievements.has("phase_practice"), "Fifty dash events must complete Phase Practice")
	for index in 10:
		service.progress("perfect_dash", {"event_id": "perfect-%d" % index})
	_check(profile.achievements.has("between_the_bullets"), "Ten perfect dashes must complete their achievement")
	service.progress("run_complete", {
		"event_id": "deep-win",
		"won": true,
		"boss_id": "gravemaw",
		"weapon_id": "pulse_needle",
		"difficulty": "deep"
	})
	_check(profile.achievements.has("deeper_water"), "Deep difficulty must satisfy the allowed-difficulty match")
	service.progress("abyss_depth_reached", {"event_id": "depth-9", "depth": 9})
	service.progress("abyss_depth_reached", {"event_id": "depth-8", "depth": 8})
	_check(not profile.achievements.has("abyss_depth_ten"), "Max metric must not accumulate lower depth reports")
	service.progress("abyss_depth_reached", {"event_id": "depth-10", "depth": 10})
	_check(profile.achievements.has("abyss_depth_ten"), "Depth ten must complete the Abyss achievement")

	var run_index := 0
	while not profile.achievements.has("seasoned_diver") and run_index < 30:
		service.progress("run_complete", {
			"event_id": "seasoned-%d" % run_index,
			"won": false,
			"boss_id": "gravemaw",
			"weapon_id": "pulse_needle",
			"difficulty": "diver"
		})
		run_index += 1
	_check(profile.achievements.has("seasoned_diver"), "Run completion must count losses toward Seasoned Diver")
	var achievement_ledger_count := 0
	for ledger_key in profile.meta_goal_state.reward_ledger:
		if String(ledger_key).begins_with("achievement:"):
			achievement_ledger_count += 1
	_check(achievement_ledger_count == profile.achievements.size(), "Each completed achievement must have exactly one reward-ledger entry")
	service = null


func _test_contract_completion_rollover_and_persistence() -> void:
	var profile := {"bio_matter": 0, "core_shards": 0, "achievements": [], "contracts": {}}
	var service := MetaGoals.new()
	_check(service.initialize(profile, DATE_A), "Contract test service must initialize")
	# Pre-complete achievements so this test can isolate daily contract currency.
	profile.achievements = service.achievements.map(func(goal: Dictionary) -> String: return String(goal.id))
	var active := service.get_active_contracts()
	var expected_bio := 0
	var original_ids: Array = []
	for goal in active:
		expected_bio += int(goal.reward.get("bio_matter", 0))
		original_ids.append(String(goal.id))
	for goal in active:
		_satisfy_contract(service, String(goal.id))
	var completed: Array = profile.contracts.completed
	for id in original_ids:
		_check(completed.has(id), "Selected contract must be completable from its data rule: %s" % id)
	_check(int(profile.bio_matter) == expected_bio, "Daily contract rewards must equal the selected catalog rewards exactly")
	var reward_after_completion := int(profile.bio_matter)
	for goal in active:
		_satisfy_contract(service, String(goal.id))
	_check(int(profile.bio_matter) == reward_after_completion, "Completed contracts must never grant a duplicate reward")

	var serialized := JSON.stringify(profile)
	var restored_profile: Dictionary = JSON.parse_string(serialized)
	var restored := MetaGoals.new()
	_check(restored.initialize(restored_profile, DATE_A), "Serialized caller profile must restore into a fresh service")
	_check((restored_profile.contracts.completed as Array).size() == 3, "Daily completion state must survive profile serialization")
	_check(int(restored_profile.bio_matter) == reward_after_completion, "Restore must not award currency implicitly")
	for goal in restored.get_active_contracts():
		_satisfy_contract(restored, String(goal.id))
	_check(int(restored_profile.bio_matter) == reward_after_completion, "Restored completed contracts must remain reward-idempotent")

	var next_date := {"year": 2026, "month": 9, "day": 2}
	var next_ids := restored.select_contract_ids_for_date(next_date)
	_check(next_ids != original_ids, "Rollover test requires a genuinely different shipped daily set")
	restored.activate_contracts_for_date(next_date)
	_check(String(restored_profile.contracts.day_key) == "2026-09-02", "UTC rollover must update the stored day")
	_check((restored_profile.contracts.completed as Array).is_empty(), "UTC rollover must clear current completion state")
	_check((restored_profile.contracts.progress as Dictionary).is_empty(), "UTC rollover must clear current progress")
	_check((restored_profile.meta_goal_state.reward_ledger as Array).size() >= 3, "Rollover must retain the durable reward ledger")

	# Returning to a prior device date resets display state, but its day-scoped
	# ledger keys stop the same offline day from paying again.
	restored.activate_contracts_for_date(DATE_A)
	for goal in restored.get_active_contracts():
		_satisfy_contract(restored, String(goal.id))
	_check(int(restored_profile.bio_matter) == reward_after_completion, "Clock rollback must not repay an already rewarded UTC day")
	_check((restored_profile.contracts.completed as Array).size() == 3, "Clock rollback goals may complete without duplicate currency")
	service = null
	restored = null


func _test_catalog_rejection_and_offline_boundary() -> void:
	var bad_achievements := {
		"schema_version": 1,
		"achievements": [
			{
				"id": "bad-id!",
				"title": {"en": "Broken", "he": "שבור"},
				"description": {"en": "Broken", "he": "שבור"},
				"event": "",
				"metric": "mystery",
				"threshold": 0,
				"match": [],
				"reward": {"bio_matter": -1, "network_token": 1}
			},
			{
				"id": "operator_fault",
				"title": {"en": "Operator", "he": "אופרטור"},
				"description": {"en": "Operator", "he": "אופרטור"},
				"event": "run_complete",
				"metric": "count",
				"threshold": 1,
				"match": {"damage_taken": {"unsupported": 1}},
				"reward": {"bio_matter": 1}
			},
			{
				"id": "operator_fault",
				"title": {"en": "Duplicate", "he": "כפול"},
				"description": {"en": "Duplicate", "he": "כפול"},
				"event": "run_complete",
				"metric": "count",
				"threshold": 1,
				"match": {},
				"reward": {"bio_matter": 1}
			}
		]
	}
	_write_json(TEST_BAD_ACHIEVEMENTS, bad_achievements)
	var invalid := MetaGoals.new()
	_check(not invalid.initialize({}, DATE_A, TEST_BAD_ACHIEVEMENTS, MetaGoals.CONTRACTS_PATH), "Invalid achievement catalog must fail closed")
	_check(invalid.get_validation_errors().size() >= 8, "Catalog validator must report multiple independent faults")
	var rejected := invalid.progress("run_complete", {"event_id": "rejected"})
	_check(not bool(rejected.accepted), "Uninitialized invalid service must reject progress")

	_write_json(TEST_BAD_CONTRACTS, {"schema_version": 9, "contracts": []})
	var bad_contracts := MetaGoals.new()
	_check(not bad_contracts.initialize({}, DATE_A, MetaGoals.ACHIEVEMENTS_PATH, TEST_BAD_CONTRACTS), "Unsupported contract schema must fail closed")
	_check(not bad_contracts.initialize({}, DATE_A, "res://data/missing_achievement_catalog.json", MetaGoals.CONTRACTS_PATH), "Missing catalog must fail closed")

	var source_file := FileAccess.open("res://scripts/services/meta_goal_service.gd", FileAccess.READ)
	_check(source_file != null, "Focused test must inspect the service boundary")
	if source_file != null:
		var source := source_file.get_as_text()
		_check(source.find("SaveManager") == -1, "Meta goal service must not depend on SaveManager")
		_check(source.find("HTTPRequest") == -1 and source.find("HTTPClient") == -1, "Meta goal service must not contain network clients")
		_check(source.find("FileAccess.WRITE") == -1, "Meta goal service must not persist outside the caller profile")
	invalid = null
	bad_contracts = null


func _satisfy_contract(service: RefCounted, contract_id: String) -> void:
	var safety := 0
	while safety < 32:
		var goal := _active_goal(service, contract_id)
		if goal.is_empty() or bool(goal.completed):
			return
		var payload := _payload_for_goal(goal, safety)
		event_sequence += 1
		payload.event_id = "contract-test-%d" % event_sequence
		service.progress(String(goal.event), payload)
		safety += 1
	_check(false, "Contract helper exceeded bounded attempts: %s" % contract_id)


func _active_goal(service: RefCounted, contract_id: String) -> Dictionary:
	for goal in service.get_active_contracts():
		if String(goal.id) == contract_id:
			return goal
	return {}


func _payload_for_goal(goal: Dictionary, sequence: int) -> Dictionary:
	var payload: Dictionary = {}
	var match_rules: Dictionary = goal.get("match", {})
	for key_value in match_rules:
		var key := String(key_value)
		var rule: Variant = match_rules[key]
		if typeof(rule) == TYPE_ARRAY:
			payload[key] = (rule as Array)[0]
		elif typeof(rule) == TYPE_DICTIONARY:
			var rule_dictionary: Dictionary = rule
			if rule_dictionary.has("eq"):
				payload[key] = rule_dictionary.eq
			elif rule_dictionary.has("in"):
				payload[key] = (rule_dictionary.get("in") as Array)[0]
			elif rule_dictionary.has("lte"):
				payload[key] = rule_dictionary.lte
			elif rule_dictionary.has("gte"):
				payload[key] = rule_dictionary.gte
		else:
			payload[key] = rule
	var value_key := String(goal.get("value_key", ""))
	match String(goal.get("metric", "count")):
		"max", "sum":
			payload[value_key] = int(goal.get("threshold", 1))
		"unique":
			if value_key == "weapon_id":
				var weapons := ["pulse_needle", "scatter_maw", "rail_spine", "arc_swarm", "void_orbitals"]
				payload[value_key] = weapons[sequence % weapons.size()]
			else:
				payload[value_key] = "test_unique_%d" % sequence
	return payload


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Focused test must create scoped invalid catalog")
	if file != null:
		file.store_string(JSON.stringify(value))
		file.flush()


func _cleanup() -> void:
	for path in [TEST_BAD_ACHIEVEMENTS, TEST_BAD_CONTRACTS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
