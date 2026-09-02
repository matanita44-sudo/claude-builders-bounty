extends Node

## Runs in a separate Godot process. SaveManager's autoload has already loaded
## user:// before this scene starts, so a passing probe is real process-relaunch
## evidence rather than another in-memory Dictionary assertion.

func _ready() -> void:
	call_deferred("_verify_loaded_profile")

func _verify_loaded_profile() -> void:
	var expected_bio := -1
	var expected_runs := -1
	var expected_source := "primary"
	var expected_upgrade := ""
	var expected_upgrade_level := -1
	var expected_run_ids: Array[String] = []
	var expect_temp_absent := false
	var accept_run_id := ""
	var accept_bio := 0
	var accept_shards := 0
	var accept_won := false
	var accept_boss := "gravemaw"
	var reject_run_id := ""
	var reject_bio := 0
	var reject_shards := 0
	var reject_won := false
	var reject_boss := "gravemaw"
	for argument_value in OS.get_cmdline_user_args():
		var argument := String(argument_value)
		if argument.begins_with("--expected-bio="):
			expected_bio = int(argument.trim_prefix("--expected-bio="))
		elif argument.begins_with("--expected-runs="):
			expected_runs = int(argument.trim_prefix("--expected-runs="))
		elif argument.begins_with("--expected-source="):
			expected_source = argument.trim_prefix("--expected-source=")
		elif argument.begins_with("--expected-upgrade="):
			var parts := argument.trim_prefix("--expected-upgrade=").split(":",false,1)
			if parts.size() == 2:
				expected_upgrade = String(parts[0])
				expected_upgrade_level = int(parts[1])
		elif argument.begins_with("--expected-run-ids="):
			for run_id_value in argument.trim_prefix("--expected-run-ids=").split(",",false):
				expected_run_ids.append(String(run_id_value))
		elif argument == "--expect-temp-absent=true":
			expect_temp_absent = true
		elif argument.begins_with("--accept-run-id="):
			accept_run_id = argument.trim_prefix("--accept-run-id=")
		elif argument.begins_with("--accept-bio="):
			accept_bio = int(argument.trim_prefix("--accept-bio="))
		elif argument.begins_with("--accept-shards="):
			accept_shards = int(argument.trim_prefix("--accept-shards="))
		elif argument.begins_with("--accept-won="):
			accept_won = argument.trim_prefix("--accept-won=") == "true"
		elif argument.begins_with("--accept-boss="):
			accept_boss = argument.trim_prefix("--accept-boss=")
		elif argument.begins_with("--reject-run-id="):
			reject_run_id = argument.trim_prefix("--reject-run-id=")
		elif argument.begins_with("--reject-bio="):
			reject_bio = int(argument.trim_prefix("--reject-bio="))
		elif argument.begins_with("--reject-shards="):
			reject_shards = int(argument.trim_prefix("--reject-shards="))
		elif argument.begins_with("--reject-won="):
			reject_won = argument.trim_prefix("--reject-won=") == "true"
		elif argument.begins_with("--reject-boss="):
			reject_boss = argument.trim_prefix("--reject-boss=")

	var failures: Array[String] = []
	if SaveManager.last_load_source != expected_source:
		failures.append("expected %s save source, got %s" % [expected_source,SaveManager.last_load_source])
	if expected_bio < 0 or int(SaveManager.profile.get("bio_matter",-1)) != expected_bio:
		failures.append("Bio-Matter mismatch")
	if expected_runs < 0 or int(SaveManager.profile.get("total_runs",-1)) != expected_runs:
		failures.append("total_runs mismatch")
	var upgrades: Dictionary = SaveManager.profile.get("upgrades",{})
	if not expected_upgrade.is_empty() and int(upgrades.get(expected_upgrade,-1)) != expected_upgrade_level:
		failures.append("Forge upgrade mismatch")
	var processed: Array = SaveManager.profile.get("processed_run_ids",[])
	for expected_run_id in expected_run_ids:
		if not processed.has(expected_run_id):
			failures.append("missing run receipt %s" % expected_run_id)
	if expect_temp_absent and FileAccess.file_exists(SaveManager.TEMP_PATH):
		failures.append("stale temporary generation survived boot recovery")

	var bank_accepted := false
	if not accept_run_id.is_empty():
		var before_bio := int(SaveManager.profile.get("bio_matter",0))
		var before_shards := int(SaveManager.profile.get("core_shards",0))
		var before_runs := int(SaveManager.profile.get("total_runs",0))
		var candidate := {
			"run_id": accept_run_id,
			"banked_bio": accept_bio,
			"banked_shards": accept_shards,
			"won": accept_won,
			"boss_id": accept_boss,
			"mode": "story",
			"difficulty": "diver"
		}
		var accepted := SaveManager.bank_run(candidate)
		var once_snapshot := SaveManager.profile.duplicate(true)
		var replay_rejected := not SaveManager.bank_run(candidate) and SaveManager.profile == once_snapshot
		bank_accepted = (
			accepted
			and replay_rejected
			and int(SaveManager.profile.get("bio_matter",-1)) == before_bio + maxi(0,accept_bio)
			and int(SaveManager.profile.get("core_shards",-1)) == before_shards + maxi(0,accept_shards)
			and int(SaveManager.profile.get("total_runs",-1)) == before_runs + 1
			and (SaveManager.profile.get("processed_run_ids",[]) as Array).has(accept_run_id)
		)
		if not bank_accepted:
			failures.append("new run was not banked exactly once after recovery")

	var replay_rejected := false
	if not reject_run_id.is_empty():
		var profile_before_replay := SaveManager.profile.duplicate(true)
		var accepted := SaveManager.bank_run({
			"run_id": reject_run_id,
			"banked_bio": reject_bio,
			"banked_shards": reject_shards,
			"won": reject_won,
			"boss_id": reject_boss,
			"mode": "story",
			"difficulty": "diver"
		})
		replay_rejected = not accepted and SaveManager.profile == profile_before_replay
		if not replay_rejected:
			failures.append("duplicate run replay was accepted or mutated the profile")

	if failures.is_empty():
		print("INFINIDIVE RELAUNCH PROBE: PASS source=%s bio=%d runs=%d upgrade=%s:%d receipts=%d bank_accepted=%s replay_rejected=%s" % [expected_source,expected_bio,expected_runs,expected_upgrade,expected_upgrade_level,expected_run_ids.size(),str(bank_accepted),str(replay_rejected)])
		get_tree().quit(0)
	else:
		push_error("INFINIDIVE RELAUNCH PROBE: FAIL %s" % "; ".join(failures))
		get_tree().quit(1)
