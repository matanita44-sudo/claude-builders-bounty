extends Node

const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const ProjectilePoolClass := preload("res://scripts/gameplay/projectile_pool.gd")

const DEFAULT_DURATION_SECONDS := 1800.0
const TICK_SECONDS := 0.05
const SAMPLE_INTERVAL_SECONDS := 5.0
const PROGRESS_INTERVAL_SECONDS := 60.0
const MEMORY_SLOPE_LIMIT_BYTES_PER_MINUTE := 2.0 * 1024.0 * 1024.0
const MEMORY_DELTA_LIMIT_BYTES := 16.0 * 1024.0 * 1024.0
const MAX_FAILURE_RECORDS := 200

var requested_duration_seconds := DEFAULT_DURATION_SECONDS
var deterministic_seed := 0x1F1D1E
var report_stem := "soak-30m"
var report_self_test := ""
var cleanup_failure_injected := false
var started_ms := 0
var started_at_utc := ""
var finished_at_utc := ""
var source_fingerprint_start := ""
var source_fingerprint_end := ""
var iterations := 0
var boss_restarts := 0
var dive_transitions := 0
var projectile_cycles := 0
var player_projectiles_spawned := 0
var enemy_projectiles_spawned := 0
var projectile_models_requested: Dictionary = {}
var projectile_models_executed: Dictionary = {}
var save_writes := 0
var save_reloads := 0
var offline_events_queued := 0
var offline_queue_reloads := 0
var peak_player_projectiles := 0
var peak_enemy_projectiles := 0
var peak_total_projectiles := 0
var peak_object_count := 0
var peak_node_count := 0
var peak_orphan_node_count := 0
var baseline_object_count := 0
var baseline_node_count := 0
var final_object_count := 0
var final_node_count := 0
var next_sample_seconds := 0.0
var next_progress_seconds := PROGRESS_INTERVAL_SECONDS
var failures: Array[Dictionary] = []
var memory_samples: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var projectile_pool: ProjectilePool

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_arguments()
	if OS.get_environment("INFINIDIVE_SOAK_ISOLATED") != "1":
		_record_failure("isolation_required", "Set INFINIDIVE_SOAK_ISOLATED=1 and use a temporary XDG_DATA_HOME")
		_write_reports(0.0,{})
		get_tree().quit(2)
		return
	_prepare_isolated_state()
	started_at_utc = Time.get_datetime_string_from_system(true)
	source_fingerprint_start = _source_fingerprint()
	projectile_pool = ProjectilePoolClass.new()
	projectile_pool.name = "SoakProjectilePool"
	add_child(projectile_pool)
	await get_tree().process_frame
	baseline_object_count = _object_count()
	baseline_node_count = _node_count()
	_capture_metrics(0.0)
	started_ms = Time.get_ticks_msec()
	print("SOAK START duration=%.1fs seed=%d tick=%.3fs" % [requested_duration_seconds,deterministic_seed,TICK_SECONDS])

	while _elapsed_seconds() < requested_duration_seconds and failures.size() < MAX_FAILURE_RECORDS:
		_stress_projectile_pool(iterations)
		if iterations % 10 == 0:
			await _stress_boss_restart_and_dive(iterations)
		if iterations % 20 == 3:
			_stress_save_write(iterations)
		if iterations % 10 == 5:
			_stress_offline_queue(iterations)
		iterations += 1
		var elapsed := _elapsed_seconds()
		_capture_peaks()
		if elapsed >= next_sample_seconds:
			_capture_metrics(elapsed)
			next_sample_seconds += SAMPLE_INTERVAL_SECONDS
		if elapsed >= next_progress_seconds:
			print(
				"SOAK PROGRESS elapsed=%.1fs iterations=%d restarts=%d dives=%d projectiles=%d saves=%d queue=%d failures=%d memory_mb=%.2f objects=%d nodes=%d"
				% [elapsed,iterations,boss_restarts,dive_transitions,projectile_cycles,save_writes,AnalyticsService.queue.size(),failures.size(),_memory_bytes()/1048576.0,_object_count(),_node_count()]
			)
			next_progress_seconds += PROGRESS_INTERVAL_SECONDS
		await get_tree().create_timer(TICK_SECONDS).timeout

	var elapsed := _elapsed_seconds()
	finished_at_utc = Time.get_datetime_string_from_system(true)
	source_fingerprint_end = _source_fingerprint()
	if report_self_test=="source_change":
		source_fingerprint_end=("injected-source-change|%s" % source_fingerprint_start).sha256_text()
	if source_fingerprint_end != source_fingerprint_start:
		_record_failure("source_changed_during_run", "Production source fingerprint changed while the soak process was active")
	_capture_metrics(elapsed)
	_validate_offline_queue_final()
	_validate_projectile_model_coverage()
	var memory_analysis := _analyze_memory(elapsed)
	if elapsed >= 600.0 and float(memory_analysis.slope_bytes_per_minute) > MEMORY_SLOPE_LIMIT_BYTES_PER_MINUTE and float(memory_analysis.stable_delta_bytes) > MEMORY_DELTA_LIMIT_BYTES:
		_record_failure(
			"memory_trend",
			"Post-warm-up memory grew %.2f MB at %.2f MB/min" % [float(memory_analysis.stable_delta_bytes)/1048576.0,float(memory_analysis.slope_bytes_per_minute)/1048576.0]
		)
	projectile_pool.clear_all()
	projectile_pool.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	final_object_count = _object_count()
	final_node_count = _node_count()
	if final_node_count > baseline_node_count + 3:
		_record_failure("node_residue", "Final node count %d exceeded baseline %d" % [final_node_count,baseline_node_count])
	_write_reports(elapsed,memory_analysis)
	print(
		"SOAK RESULT passed=%s elapsed=%.2fs iterations=%d restarts=%d dives=%d projectile_cycles=%d saves=%d queue_events=%d peak_projectiles=%d failures=%d report=artifacts/%s.json"
		% [str(failures.is_empty()),elapsed,iterations,boss_restarts,dive_transitions,projectile_cycles,save_writes,offline_events_queued,peak_total_projectiles,failures.size(),report_stem]
	)
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--duration-seconds="):
			requested_duration_seconds = maxf(1.0,float(argument.trim_prefix("--duration-seconds=")))
		elif argument.begins_with("--seed="):
			deterministic_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--report-stem="):
			report_stem = argument.trim_prefix("--report-stem=").validate_filename()
	if report_stem.is_empty():
		report_stem = "soak-report"
	if OS.get_environment("INFINIDIVE_SOAK_SELF_TEST")=="1":
		report_self_test=OS.get_environment("INFINIDIVE_SOAK_REPORT_SELF_TEST")
	rng.seed = deterministic_seed

func _prepare_isolated_state() -> void:
	for path in [SaveManager.SAVE_PATH,SaveManager.BACKUP_PATH,SaveManager.TEMP_PATH,AnalyticsService.QUEUE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveManager.profile = SaveManager.default_profile()
	if SaveManager.save_profile():
		save_writes += 1
	else:
		_record_failure("save_initial_write", "Initial isolated save could not be written")
	SettingsManager.values = SaveManager.profile.settings.duplicate(true)
	SettingsManager.values.analytics_opt_in = true
	SaveManager.profile.settings = SettingsManager.values.duplicate(true)
	AnalyticsService.queue.clear()
	for queue_index in 520:
		AnalyticsService.track("settings_changed",{"soak_prefill":queue_index})
		offline_events_queued += 1
	if AnalyticsService.queue.size() != AnalyticsService.MAX_QUEUE:
		_record_failure("offline_queue_prefill", "Queue cap expected %d, got %d" % [AnalyticsService.MAX_QUEUE,AnalyticsService.queue.size()])
	var expected_last := int(AnalyticsService.queue[-1].properties.soak_prefill) if not AnalyticsService.queue.is_empty() else -1
	AnalyticsService.queue.clear()
	AnalyticsService._load_queue()
	offline_queue_reloads += 1
	if AnalyticsService.queue.size() != AnalyticsService.MAX_QUEUE or int(AnalyticsService.queue[-1].properties.soak_prefill) != expected_last:
		_record_failure("offline_queue_initial_reload", "Persisted capped queue did not reload exactly")

func _stress_projectile_pool(iteration: int) -> void:
	var use_full_capacity := iteration % 25 == 0
	var player_count := ProjectilePoolClass.MAX_PLAYER if use_full_capacity else 48 + iteration % 17
	var enemy_count := ProjectilePoolClass.MAX_ENEMY if use_full_capacity else 96 + iteration % 31
	var player_spawn_ok := true
	for projectile_index in player_count:
		var angle := float((projectile_index * 37 + iteration * 11) % 360) * PI / 180.0
		player_spawn_ok = projectile_pool.spawn_player(
			Vector2(270,700),Vector2.from_angle(angle)*640.0,12.0,
			{"life":2.0,"pierce":projectile_index%3,"behavior":"pulse"}
		) and player_spawn_ok
	var enemy_spawn_ok := true
	for projectile_index in enemy_count:
		var x := 30.0 + float((projectile_index * 29 + iteration * 7) % 480)
		var speed := 150.0 + float(projectile_index % 7) * 25.0
		var origin := Vector2(x,180)
		var travel_model := String(ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS[(projectile_index+iteration)%ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size()])
		var options := _soak_enemy_projectile_options(travel_model,origin)
		projectile_models_requested[travel_model]=int(projectile_models_requested.get(travel_model,0))+1
		var spawned := projectile_pool.spawn_enemy(origin,Vector2(0,speed),8.0,options)
		enemy_spawn_ok = spawned and enemy_spawn_ok
		if spawned:
			var spawned_bullet: Dictionary = projectile_pool.enemy_active[-1]
			var executed_model := String(spawned_bullet.get("travel_model",""))
			projectile_models_executed[executed_model]=int(projectile_models_executed.get(executed_model,0))+1
			if executed_model!=travel_model:
				_record_failure(
					"projectile_model_fallback",
					"Requested travel model %s but spawned canonical model %s at iteration %d projectile %d"
					% [travel_model,executed_model,iteration,projectile_index]
				)
	if not player_spawn_ok or not enemy_spawn_ok:
		_record_failure("projectile_capacity", "Expected projectile allocation failed at iteration %d" % iteration)
	player_projectiles_spawned += player_count
	enemy_projectiles_spawned += enemy_count
	peak_player_projectiles = maxi(peak_player_projectiles,projectile_pool.player_active.size())
	peak_enemy_projectiles = maxi(peak_enemy_projectiles,projectile_pool.enemy_active.size())
	peak_total_projectiles = maxi(peak_total_projectiles,projectile_pool.player_active.size()+projectile_pool.enemy_active.size())
	if use_full_capacity:
		if projectile_pool.spawn_player(Vector2.ZERO,Vector2.ZERO,1.0) or projectile_pool.spawn_enemy(Vector2.ZERO,Vector2.ZERO,1.0):
			_record_failure("projectile_overflow", "Projectile hard cap accepted an overflow allocation")
	for update_index in 4:
		projectile_pool.step(
			1.0/60.0,
			[{"id":"soak_target","position":Vector2(270,220),"radius":42.0}],
			Vector2(270+sin(float(iteration*4+update_index)*0.11)*72.0,790),12.0
		)
	projectile_pool.clear_all()
	projectile_cycles += 1
	if not projectile_pool.player_active.is_empty() or not projectile_pool.enemy_active.is_empty():
		_record_failure("projectile_clear", "Active projectile survived clear_all at iteration %d" % iteration)
	if use_full_capacity and (projectile_pool._player_free.size() != ProjectilePoolClass.MAX_PLAYER or projectile_pool._enemy_free.size() != ProjectilePoolClass.MAX_ENEMY):
		_record_failure("projectile_reuse", "Full projectile capacity was not returned to reusable pools")


func _soak_enemy_projectile_options(travel_model: String, origin: Vector2) -> Dictionary:
	var options := {"life":3.0,"travel_model":travel_model}
	match travel_model:
		ProjectilePoolClass.TRAVEL_SOFT_HOMING:
			# This production-faithful pairing exercises homing and protected-disk
			# avoidance together instead of treating them as separate code paths.
			options.homing=1.55
			options.safe_position=Vector2(270,210)
			options.safe_radius=54.0
		ProjectilePoolClass.TRAVEL_EXPANDING:
			options.travel_parameters={"expansion_rate":24.0,"expansion_max_scale":3.0}
		ProjectilePoolClass.TRAVEL_NODE_LINK:
			options.travel_parameters={"link_amplitude":12.0,"link_frequency_hz":2.1}
		ProjectilePoolClass.TRAVEL_LUNGE:
			options.travel_parameters={"windup_seconds":0.12,"burst_seconds":0.24,"burst_multiplier":2.5}
		ProjectilePoolClass.TRAVEL_RECORDED_PATH:
			options.travel_parameters={
				"path_duration":0.7,
				"path_points":[origin,origin+Vector2(-18,30),origin+Vector2(22,68),origin+Vector2(0,112)],
				"path_exit_velocity":Vector2(0,190),
			}
	return options


func _validate_projectile_model_coverage() -> void:
	for travel_model in ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS:
		var canonical_model := String(travel_model)
		if int(projectile_models_executed.get(canonical_model,0))<=0:
			_record_failure("projectile_model_coverage", "Travel model %s was not exercised" % String(travel_model))
		if int(projectile_models_requested.get(canonical_model,0))!=int(projectile_models_executed.get(canonical_model,0)):
			_record_failure(
				"projectile_model_count_mismatch",
				"Travel model %s requested %d spawns but executed %d"
				% [canonical_model,int(projectile_models_requested.get(canonical_model,0)),int(projectile_models_executed.get(canonical_model,0))]
			)


func _stress_boss_restart_and_dive(iteration: int) -> void:
	var boss_index := boss_restarts % GameData.bosses.size()
	var boss: Dictionary = GameData.bosses[boss_index]
	var organ_index := (boss_restarts / GameData.bosses.size()) % 3
	var organ: Dictionary = boss.organs[organ_index]
	var run := RunSceneClass.new()
	run.initialize({
		"boss":String(boss.id),
		"weapon":"pulse_needle",
		"difficulty":"diver",
		"seed":deterministic_seed+boss_restarts*104729,
		"mode":"story",
		"competitive":true
	})
	add_child(run)
	_capture_peaks()
	run.transition_timer = 0.0
	run._physics_process(0.016)
	if run.state != RunScene.RunState.EXTERIOR:
		_record_failure("restart_boot", "%s restart did not reach exterior" % boss.id)
		await _dispose_run(run)
		return
	run._damage_target({"id":"boss","damage":run.armor_max+1.0,"behavior":"pulse"})
	if run.state != RunScene.RunState.BREACH_OPEN:
		_record_failure("restart_breach", "%s restart did not open breach" % boss.id)
		await _dispose_run(run)
		return
	run._request_dive()
	run._select_organ(String(organ.id))
	run.transition_timer = 0.0
	run.hit_stop_timer = 0.0
	run._physics_process(0.016)
	var room_guard := 0
	while run.state == RunScene.RunState.INTERNAL_ROOMS and room_guard < 12:
		run._start_next_room()
		room_guard += 1
	if run.state != RunScene.RunState.ORGAN_CHAMBER:
		_record_failure("restart_internal", "%s/%s did not reach organ chamber" % [boss.id,organ.id])
		await _dispose_run(run)
		return
	run._damage_target({"id":"organ","damage":run.organ_max+1.0,"behavior":"pulse"})
	if run.state != RunScene.RunState.MUTATION_CHOICE or run._offered_mutation_ids.is_empty():
		_record_failure("restart_mutation", "%s/%s did not produce an offered mutation" % [boss.id,organ.id])
		await _dispose_run(run)
		return
	run._select_mutation(run._offered_mutation_ids[0])
	run.transition_timer = 0.0
	run.hit_stop_timer = 0.0
	run._physics_process(0.016)
	if run.state != RunScene.RunState.EXTERIOR or not run._organ_map.destroyed_organs().has(String(organ.id)):
		_record_failure("restart_return", "%s/%s did not return to changed exterior" % [boss.id,organ.id])
	else:
		dive_transitions += 1
	boss_restarts += 1
	await _dispose_run(run)
	var residual_nodes := _node_count()
	if residual_nodes > baseline_node_count + 5:
		_record_failure("restart_node_growth", "Node count %d exceeded baseline %d after restart %d" % [residual_nodes,baseline_node_count,boss_restarts])

func _dispose_run(run: Node) -> void:
	if is_instance_valid(run):
		run.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _stress_save_write(iteration: int) -> void:
	var expected_bio := iteration % 100000
	SaveManager.profile.bio_matter = expected_bio
	SaveManager.profile.contracts.soak = {"iteration":iteration,"seed":deterministic_seed}
	if SaveManager.save_profile():
		save_writes += 1
	else:
		_record_failure("save_write", "Atomic save failed at iteration %d" % iteration)
	if save_writes > 0 and save_writes % 60 == 0:
		var loaded := SaveManager.load_profile()
		save_reloads += 1
		if int(loaded.bio_matter) != expected_bio or int(loaded.contracts.soak.iteration) != iteration:
			_record_failure("save_reload", "Reloaded save did not match write %d" % save_writes)
		if SaveManager._read_envelope(SaveManager.BACKUP_PATH).is_empty():
			_record_failure("save_backup", "Backup envelope invalid after write %d" % save_writes)

func _stress_offline_queue(iteration: int) -> void:
	AnalyticsService.track("settings_changed",{"soak_iteration":iteration,"seed":deterministic_seed})
	offline_events_queued += 1
	if AnalyticsService.queue.size() > AnalyticsService.MAX_QUEUE:
		_record_failure("offline_queue_cap", "Offline queue exceeded cap at iteration %d" % iteration)
	if offline_events_queued % 120 == 0:
		var expected_iteration := int(AnalyticsService.queue[-1].properties.soak_iteration)
		AnalyticsService.queue.clear()
		AnalyticsService._load_queue()
		offline_queue_reloads += 1
		if AnalyticsService.queue.is_empty() or int(AnalyticsService.queue[-1].properties.soak_iteration) != expected_iteration:
			_record_failure("offline_queue_reload", "Offline queue lost its newest event at iteration %d" % iteration)

func _validate_offline_queue_final() -> void:
	if AnalyticsService.queue.size() != AnalyticsService.MAX_QUEUE:
		_record_failure("offline_queue_final_size", "Expected capped offline queue size %d, got %d" % [AnalyticsService.MAX_QUEUE,AnalyticsService.queue.size()])
	var expected_last: Dictionary = AnalyticsService.queue[-1].duplicate(true) if not AnalyticsService.queue.is_empty() else {}
	AnalyticsService.queue.clear()
	AnalyticsService._load_queue()
	offline_queue_reloads += 1
	var actual_last: Dictionary = AnalyticsService.queue[-1] if not AnalyticsService.queue.is_empty() else {}
	if AnalyticsService.queue.is_empty() or not _offline_events_equal(expected_last,actual_last):
		_record_failure("offline_queue_final_reload", "Final offline queue reload changed newest event: expected=%s actual=%s" % [JSON.stringify(expected_last),JSON.stringify(actual_last)])

func _offline_events_equal(expected: Dictionary, actual: Dictionary) -> bool:
	for key in ["event","session_id","timestamp"]:
		if String(expected.get(key,"")) != String(actual.get(key,"")):
			return false
	var expected_properties: Dictionary = expected.get("properties",{})
	var actual_properties: Dictionary = actual.get("properties",{})
	if expected_properties.size() != actual_properties.size():
		return false
	for key_value in expected_properties:
		var key := String(key_value)
		if not actual_properties.has(key):
			return false
		var expected_value: Variant = expected_properties[key]
		var actual_value: Variant = actual_properties[key]
		if typeof(expected_value) in [TYPE_INT,TYPE_FLOAT] and typeof(actual_value) in [TYPE_INT,TYPE_FLOAT]:
			if not is_equal_approx(float(expected_value),float(actual_value)):
				return false
		elif expected_value != actual_value:
			return false
	return true

func _capture_metrics(elapsed: float) -> void:
	_capture_peaks()
	memory_samples.append({
		"elapsed_seconds":elapsed,
		"memory_bytes":_memory_bytes(),
		"object_count":_object_count(),
		"node_count":_node_count(),
		"orphan_node_count":_orphan_node_count()
	})

func _capture_peaks() -> void:
	peak_object_count = maxi(peak_object_count,_object_count())
	peak_node_count = maxi(peak_node_count,_node_count())
	peak_orphan_node_count = maxi(peak_orphan_node_count,_orphan_node_count())

func _analyze_memory(elapsed: float) -> Dictionary:
	var warmup_seconds := minf(300.0,elapsed*0.2)
	var stable_samples: Array[Dictionary] = []
	for raw_sample in memory_samples:
		var sample: Dictionary = raw_sample
		if float(sample.elapsed_seconds) >= warmup_seconds:
			stable_samples.append(sample)
	var slope := 0.0
	if stable_samples.size() >= 2:
		var sum_x := 0.0
		var sum_y := 0.0
		var sum_xy := 0.0
		var sum_xx := 0.0
		for sample in stable_samples:
			var x := float(sample.elapsed_seconds)/60.0
			var y := float(sample.memory_bytes)
			sum_x += x
			sum_y += y
			sum_xy += x*y
			sum_xx += x*x
		var count := float(stable_samples.size())
		var denominator := count*sum_xx-sum_x*sum_x
		if absf(denominator) > 0.000001:
			slope = (count*sum_xy-sum_x*sum_y)/denominator
	var first_memory := int(stable_samples[0].memory_bytes) if not stable_samples.is_empty() else _memory_bytes()
	var last_memory := int(stable_samples[-1].memory_bytes) if not stable_samples.is_empty() else _memory_bytes()
	var peak_memory := 0
	for sample in memory_samples:
		peak_memory = maxi(peak_memory,int(sample.memory_bytes))
	return {
		"sample_count":memory_samples.size(),
		"stable_sample_count":stable_samples.size(),
		"warmup_seconds":warmup_seconds,
		"start_bytes":int(memory_samples[0].memory_bytes) if not memory_samples.is_empty() else 0,
		"stable_start_bytes":first_memory,
		"end_bytes":int(memory_samples[-1].memory_bytes) if not memory_samples.is_empty() else 0,
		"peak_bytes":peak_memory,
		"stable_delta_bytes":last_memory-first_memory,
		"slope_bytes_per_minute":slope
	}

func _write_reports(elapsed: float, memory_analysis: Dictionary) -> void:
	var artifacts_path := ProjectSettings.globalize_path("res://artifacts")
	if not DirAccess.dir_exists_absolute(artifacts_path):
		var directory_error := DirAccess.make_dir_absolute(artifacts_path)
		if directory_error!=OK:
			_record_failure("report_directory", "Could not create report directory: error %d" % directory_error)
			return
	var json_path := "res://artifacts/%s.json" % report_stem
	var markdown_path := "res://artifacts/%s.md" % report_stem
	var json_temporary_path := "%s.next" % json_path
	var markdown_temporary_path := "%s.next" % markdown_path
	var json_backup_path := "%s.previous" % json_path
	var markdown_backup_path := "%s.previous" % markdown_path
	_recover_interrupted_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path)
	_remove_report_file(json_temporary_path)
	_remove_report_file(markdown_temporary_path)
	var transaction_id := (
		"%s|%d|%d|%s" % [started_at_utc,deterministic_seed,Time.get_ticks_usec(),report_stem]
	).sha256_text().left(24)

	# Open both destinations before writing either report so an unavailable peer
	# cannot disturb an already-valid final pair.
	var json_file: FileAccess = null
	if report_self_test=="json_open":
		_record_failure("report_json_open", "Self-test simulated unavailable JSON report")
	else:
		json_file=FileAccess.open(json_temporary_path,FileAccess.WRITE)
	if json_file==null and report_self_test!="json_open":
		_record_failure("report_json_open", "Could not open JSON report: error %d" % FileAccess.get_open_error())
	var markdown_file: FileAccess = null
	if report_self_test=="markdown_open":
		_record_failure("report_markdown_open", "Self-test simulated unavailable Markdown report")
	else:
		markdown_file=FileAccess.open(markdown_temporary_path,FileAccess.WRITE)
	if markdown_file==null and report_self_test!="markdown_open":
		_record_failure("report_markdown_open", "Could not open Markdown report: error %d" % FileAccess.get_open_error())

	if json_file==null or markdown_file==null:
		if json_file!=null:
			json_file.close()
		if markdown_file!=null:
			markdown_file.close()
		_remove_report_file(json_temporary_path)
		_remove_report_file(markdown_temporary_path)
		return
	if report_self_test in ["json_write","markdown_write"]:
		_record_failure("report_%s" % report_self_test, "Self-test simulated report write/flush failure")
		json_file.close()
		markdown_file.close()
		_remove_report_file(json_temporary_path)
		_remove_report_file(markdown_temporary_path)
		return

	var markdown_body := _build_markdown_report(elapsed,memory_analysis,transaction_id)
	var markdown_sha256 := markdown_body.sha256_text()
	var report := _build_json_report(elapsed,memory_analysis,transaction_id,markdown_sha256,false)
	json_file.store_string(JSON.stringify(report,"\t"))
	json_file.flush()
	var json_error := json_file.get_error()
	var json_length := json_file.get_length()
	json_file.close()
	markdown_file.store_string(markdown_body)
	markdown_file.flush()
	var markdown_error := markdown_file.get_error()
	var markdown_length := markdown_file.get_length()
	markdown_file.close()
	if json_error!=OK or json_length<=0:
		_record_failure("report_json_write", "JSON report write/flush failed: error %d bytes %d" % [json_error,json_length])
		_remove_report_file(json_temporary_path)
		_remove_report_file(markdown_temporary_path)
		return
	if markdown_error!=OK or markdown_length<=0:
		_record_failure("report_markdown_write", "Markdown report write/flush failed: error %d bytes %d" % [markdown_error,markdown_length])
		_remove_report_file(json_temporary_path)
		_remove_report_file(markdown_temporary_path)
		return
	if report_self_test=="pair_verify" or not _report_pair_is_valid(
		json_temporary_path,markdown_temporary_path,transaction_id,failures.is_empty(),false
	):
		_record_failure("report_pair_verify", "Self-test or validation rejected the staged report pair")
		_remove_report_file(json_temporary_path)
		_remove_report_file(markdown_temporary_path)
		return
	_commit_report_pair(
		json_temporary_path,markdown_temporary_path,
		json_path,markdown_path,json_backup_path,markdown_backup_path,
		transaction_id,elapsed,memory_analysis
	)


func _build_json_report(elapsed: float, memory_analysis: Dictionary, transaction_id: String, markdown_sha256: String, transaction_complete: bool) -> Dictionary:
	return {
		"schema":1,
		"report_transaction_id":transaction_id,
		"report_markdown_sha256":markdown_sha256,
		"report_transaction_complete":transaction_complete,
		"passed":failures.is_empty(),
		"requested_duration_seconds":requested_duration_seconds,
		"elapsed_wall_seconds":elapsed,
		"seed":deterministic_seed,
		"started_at_utc":started_at_utc,
		"finished_at_utc":finished_at_utc,
		"source_fingerprint_start":source_fingerprint_start,
		"source_fingerprint_end":source_fingerprint_end,
		"source_changed_during_run":source_fingerprint_start != source_fingerprint_end,
		"engine":Engine.get_version_info(),
		"display_server":DisplayServer.get_name(),
		"scope":"Linux Godot headless structural soak; not device FPS, thermal, battery, GPU, or touch performance",
		"counts":{
			"iterations":iterations,
			"boss_restarts":boss_restarts,
			"dive_transitions":dive_transitions,
			"projectile_cycles":projectile_cycles,
			"projectile_model_steps":projectile_models_executed.duplicate(true),
			"projectile_models_requested":projectile_models_requested.duplicate(true),
			"projectile_models_executed":projectile_models_executed.duplicate(true),
			"player_projectiles_spawned":player_projectiles_spawned,
			"enemy_projectiles_spawned":enemy_projectiles_spawned,
			"save_writes":save_writes,
			"save_reloads":save_reloads,
			"offline_events_queued":offline_events_queued,
			"offline_queue_reloads":offline_queue_reloads,
			"offline_queue_final_size":AnalyticsService.queue.size()
		},
		"peaks":{
			"player_projectiles":peak_player_projectiles,
			"enemy_projectiles":peak_enemy_projectiles,
			"total_projectiles":peak_total_projectiles,
			"object_count":peak_object_count,
			"node_count":peak_node_count,
			"orphan_node_count":peak_orphan_node_count
		},
		"object_counts":{
			"baseline_objects":baseline_object_count,
			"baseline_nodes":baseline_node_count,
			"final_objects":final_object_count,
			"final_nodes":final_node_count
		},
		"memory":memory_analysis,
		"failures":failures,
		"memory_samples":memory_samples
	}


func _build_markdown_report(elapsed: float, memory_analysis: Dictionary, transaction_id: String) -> String:
	var memory_slope_mb := float(memory_analysis.get("slope_bytes_per_minute",0.0))/1048576.0
	var memory_delta_mb := float(memory_analysis.get("stable_delta_bytes",0.0))/1048576.0
	var memory_peak_mb := float(memory_analysis.get("peak_bytes",0.0))/1048576.0
	var body := "# INFINIDIVE Headless Soak Report\n\n"
	body += "- Result: **%s**\n" % ("PASS" if failures.is_empty() else "FAIL")
	body += "- Report transaction: `%s`\n" % transaction_id
	body += "- Requested wall time: `%.2f seconds`\n" % requested_duration_seconds
	body += "- Actual wall time: `%.2f seconds`\n" % elapsed
	body += "- Seed: `%d`\n" % deterministic_seed
	body += "- Source fingerprint: `%s`\n" % source_fingerprint_start
	body += "- Source changed during run: `%s`\n" % str(source_fingerprint_start != source_fingerprint_end)
	body += "- Environment: Godot `%s`, display server `%s`\n" % [String(Engine.get_version_info().string),DisplayServer.get_name()]
	body += "- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.\n\n"
	body += "| Metric | Value |\n|---|---:|\n"
	body += "| Iterations | %d |\n" % iterations
	body += "| Boss restarts | %d |\n" % boss_restarts
	body += "| Dive transitions | %d |\n" % dive_transitions
	body += "| Projectile pressure cycles | %d |\n" % projectile_cycles
	body += "| Projectile travel models exercised | %d / %d |\n" % [_executed_projectile_model_coverage(),ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size()]
	body += "| Player projectiles spawned | %d |\n" % player_projectiles_spawned
	body += "| Enemy projectiles spawned | %d |\n" % enemy_projectiles_spawned
	body += "| Peak simultaneous projectiles | %d |\n" % peak_total_projectiles
	body += "| Save writes / reloads | %d / %d |\n" % [save_writes,save_reloads]
	body += "| Offline events / reloads | %d / %d |\n" % [offline_events_queued,offline_queue_reloads]
	body += "| Peak objects / nodes / orphan nodes | %d / %d / %d |\n" % [peak_object_count,peak_node_count,peak_orphan_node_count]
	body += "| Peak static memory | %.2f MB |\n" % memory_peak_mb
	body += "| Post-warm-up memory delta | %.2f MB |\n" % memory_delta_mb
	body += "| Post-warm-up memory slope | %.3f MB/min |\n" % memory_slope_mb
	body += "| Failures | %d |\n" % failures.size()
	if not failures.is_empty():
		body += "\n## Failures\n\n"
		for failure in failures:
			body += "- `%s`: %s\n" % [String(failure.code),String(failure.detail)]
	return body


func _executed_projectile_model_coverage() -> int:
	var coverage := 0
	for travel_model in ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS:
		if int(projectile_models_executed.get(String(travel_model),0))>0:
			coverage += 1
	return coverage


func _remove_report_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	if report_self_test=="cleanup_failure" and not cleanup_failure_injected and path.ends_with(".md.previous"):
		cleanup_failure_injected=true
		_record_failure("report_cleanup_failure", "Self-test simulated failure removing %s" % path)
		return false
	var removal_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if removal_error!=OK:
		_record_failure("report_cleanup_failure", "Could not remove report transaction file %s: error %d" % [path,removal_error])
		return false
	return true


func _report_pair_is_valid(
	json_path: String, markdown_path: String,
	expected_transaction_id: String = "", expected_passed: Variant = null,
	expected_transaction_complete: bool = true
) -> bool:
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(markdown_path):
		return false
	if FileAccess.get_file_as_bytes(json_path).is_empty() or FileAccess.get_file_as_bytes(markdown_path).is_empty():
		return false
	var json_text := FileAccess.get_file_as_string(json_path)
	var parsed_report: Variant = JSON.parse_string(json_text)
	if not parsed_report is Dictionary:
		return false
	var report := parsed_report as Dictionary
	if not _dictionary_has_exact_keys(report,[
		"schema","report_transaction_id","report_markdown_sha256","report_transaction_complete","passed",
		"requested_duration_seconds","elapsed_wall_seconds","seed","started_at_utc","finished_at_utc",
		"source_fingerprint_start","source_fingerprint_end","source_changed_during_run",
		"engine","display_server","scope","counts","peaks","object_counts","memory","failures","memory_samples",
	]):
		return false
	if not _is_whole_number(report.get("schema",null)) or int(report.schema)!=1:
		return false
	if not report.has("passed") or typeof(report.passed)!=TYPE_BOOL:
		return false
	if not report.has("report_transaction_complete") or typeof(report.report_transaction_complete)!=TYPE_BOOL:
		return false
	if bool(report.report_transaction_complete)!=expected_transaction_complete:
		return false
	if not report.get("failures",null) is Array:
		return false
	var report_failures := report.failures as Array
	if bool(report.passed)!=report_failures.is_empty():
		return false
	var report_passed := bool(report.passed)
	if not _json_integer_tokens_are_canonical(json_text,not report_failures.is_empty()):
		return false
	var transaction_id := String(report.get("report_transaction_id",""))
	if not _is_lower_hex(transaction_id,24):
		return false
	var markdown_sha256 := String(report.get("report_markdown_sha256",""))
	if not _is_lower_hex(markdown_sha256,64) or FileAccess.get_sha256(markdown_path)!=markdown_sha256:
		return false
	if not expected_transaction_id.is_empty() and transaction_id!=expected_transaction_id:
		return false
	if expected_passed!=null and bool(report.get("passed",false))!=bool(expected_passed):
		return false
	var source_fingerprint_start := String(report.get("source_fingerprint_start",""))
	var source_fingerprint_end := String(report.get("source_fingerprint_end",""))
	if not _is_lower_hex(source_fingerprint_start,64) or not _is_lower_hex(source_fingerprint_end,64):
		return false
	if not report.has("source_changed_during_run") or typeof(report.source_changed_during_run)!=TYPE_BOOL:
		return false
	var source_changed := bool(report.source_changed_during_run)
	if source_changed!=(source_fingerprint_start!=source_fingerprint_end):
		return false
	if report_passed and source_changed:
		return false
	if not _is_positive_number(report.get("requested_duration_seconds",null)) or not _is_positive_number(report.get("elapsed_wall_seconds",null)):
		return false
	if report_passed and float(report.elapsed_wall_seconds)<float(report.requested_duration_seconds):
		return false
	for string_key in ["started_at_utc","finished_at_utc","display_server","scope"]:
		if not report.get(String(string_key),null) is String or String(report[String(string_key)]).strip_edges().is_empty():
			return false
	if not _is_whole_number(report.get("seed",null)):
		return false
	if not report.get("engine",null) is Dictionary or (report.engine as Dictionary).is_empty():
		return false
	if not report.get("counts",null) is Dictionary:
		return false
	var counts := report.counts as Dictionary
	var count_fields := [
		"iterations","boss_restarts","dive_transitions","projectile_cycles",
		"projectile_model_steps","projectile_models_requested","projectile_models_executed",
		"player_projectiles_spawned","enemy_projectiles_spawned","save_writes","save_reloads",
		"offline_events_queued","offline_queue_reloads","offline_queue_final_size",
	]
	if not _dictionary_has_exact_keys(counts,count_fields):
		return false
	for count_key in count_fields:
		if String(count_key).begins_with("projectile_model"):
			continue
		if not _is_nonnegative_whole_number(counts.get(String(count_key),null)):
			return false
	for map_key in ["projectile_model_steps","projectile_models_requested","projectile_models_executed"]:
		if not counts.get(String(map_key),null) is Dictionary:
			return false
		var model_counts := counts[String(map_key)] as Dictionary
		if model_counts.size()!=ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size():
			return false
		for travel_model in ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS:
			var model_count: Variant = model_counts.get(String(travel_model),null)
			if report_passed and not _is_positive_whole_number(model_count):
				return false
			if not report_passed and not _is_nonnegative_whole_number(model_count):
				return false
	var requested_models := counts.projectile_models_requested as Dictionary
	var executed_models := counts.projectile_models_executed as Dictionary
	var legacy_models := counts.projectile_model_steps as Dictionary
	var requested_total := 0
	for requested_count in requested_models.values():
		requested_total += int(requested_count)
	if report_passed:
		if int(counts.iterations)<=0 or int(counts.projectile_cycles)!=int(counts.iterations):
			return false
		if int(counts.boss_restarts)<=0 or int(counts.dive_transitions)!=int(counts.boss_restarts):
			return false
		if int(counts.player_projectiles_spawned)<=0 or int(counts.enemy_projectiles_spawned)<=0:
			return false
		if int(counts.save_writes)<=0 or int(counts.offline_events_queued)<=0 or int(counts.offline_queue_reloads)<=0:
			return false
		for travel_model in ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS:
			var model := String(travel_model)
			if int(requested_models[model])!=int(executed_models[model]) or int(legacy_models[model])!=int(executed_models[model]):
				return false
		if requested_total!=int(counts.enemy_projectiles_spawned):
			return false
	if not _validate_nonnegative_integer_object(report.get("peaks",null),[
		"player_projectiles","enemy_projectiles","total_projectiles","object_count","node_count","orphan_node_count",
	]):
		return false
	if not _validate_nonnegative_integer_object(report.get("object_counts",null),[
		"baseline_objects","baseline_nodes","final_objects","final_nodes",
	]):
		return false
	if not report.get("memory",null) is Dictionary:
		return false
	var memory := report.memory as Dictionary
	if not _dictionary_has_exact_keys(memory,[
		"sample_count","stable_sample_count","warmup_seconds","start_bytes","stable_start_bytes",
		"end_bytes","peak_bytes","stable_delta_bytes","slope_bytes_per_minute",
	]):
		return false
	for memory_integer_key in ["sample_count","stable_sample_count","start_bytes","stable_start_bytes","end_bytes","peak_bytes"]:
		if not _is_nonnegative_whole_number(memory.get(String(memory_integer_key),null)):
			return false
	for memory_number_key in ["warmup_seconds","stable_delta_bytes","slope_bytes_per_minute"]:
		if not _is_finite_number(memory.get(String(memory_number_key),null)):
			return false
	if not report.get("memory_samples",null) is Array:
		return false
	var samples := report.memory_samples as Array
	if samples.is_empty() or samples.size()!=int(memory.sample_count):
		return false
	for raw_sample in samples:
		if not raw_sample is Dictionary:
			return false
		var sample := raw_sample as Dictionary
		if not _dictionary_has_exact_keys(sample,["elapsed_seconds","memory_bytes","object_count","node_count","orphan_node_count"]):
			return false
		if not _is_finite_number(sample.get("elapsed_seconds",null)):
			return false
		for sample_integer_key in ["memory_bytes","object_count","node_count","orphan_node_count"]:
			if not _is_nonnegative_whole_number(sample.get(String(sample_integer_key),null)):
				return false
	var source_change_failure_found := false
	for raw_failure in report_failures:
		if not raw_failure is Dictionary:
			return false
		var failure := raw_failure as Dictionary
		if not _dictionary_has_exact_keys(failure,["elapsed_seconds","iteration","code","detail"]):
			return false
		if not _is_finite_number(failure.get("elapsed_seconds",null)) or not _is_nonnegative_whole_number(failure.get("iteration",null)):
			return false
		var failure_code := String(failure.get("code",""))
		var failure_detail := String(failure.get("detail",""))
		if failure_code.is_empty() or failure_detail.is_empty():
			return false
		if failure_code=="source_changed_during_run":
			source_change_failure_found=true
	if source_changed and not source_change_failure_found:
		return false
	var markdown := FileAccess.get_file_as_string(markdown_path)
	if not markdown.begins_with("# INFINIDIVE Headless Soak Report\n\n"):
		return false
	if not markdown.contains("- Report transaction: `%s`" % transaction_id):
		return false
	var expected_result := "PASS" if report_passed else "FAIL"
	if not markdown.contains("- Result: **%s**" % expected_result):
		return false
	if not markdown.contains("- Requested wall time: `%.2f seconds`" % float(report.requested_duration_seconds)):
		return false
	if not markdown.contains("- Actual wall time: `%.2f seconds`" % float(report.elapsed_wall_seconds)):
		return false
	if not markdown.contains("- Source fingerprint: `%s`" % source_fingerprint_start):
		return false
	if not markdown.contains("- Source changed during run: `%s`" % str(source_changed)):
		return false
	var executed_coverage := 0
	for travel_model in ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS:
		if int(executed_models[String(travel_model)])>0:
			executed_coverage += 1
	if not markdown.contains(
		"| Projectile travel models exercised | %d / %d |"
		% [executed_coverage,ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size()]
	):
		return false
	if not markdown.contains("| Failures | %d |" % report_failures.size()):
		return false
	for raw_failure in report_failures:
		var failure := raw_failure as Dictionary
		var failure_code := String(failure.get("code",""))
		var failure_detail := String(failure.get("detail",""))
		if not markdown.contains("- `%s`: %s" % [failure_code,failure_detail]):
			return false
	return true


func _dictionary_has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size()!=expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(String(key)):
			return false
	return true


func _validate_nonnegative_integer_object(value: Variant, expected_keys: Array) -> bool:
	if not value is Dictionary:
		return false
	var dictionary := value as Dictionary
	if not _dictionary_has_exact_keys(dictionary,expected_keys):
		return false
	for key in expected_keys:
		if not _is_nonnegative_whole_number(dictionary.get(String(key),null)):
			return false
	return true


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	return is_finite(float(value))


func _is_positive_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value)>0.0


func _is_whole_number(value: Variant) -> bool:
	if not _is_finite_number(value):
		return false
	var numeric_value := float(value)
	return is_equal_approx(numeric_value,floorf(numeric_value))


func _is_nonnegative_whole_number(value: Variant) -> bool:
	return _is_whole_number(value) and float(value)>=0.0


func _is_positive_whole_number(value: Variant) -> bool:
	return _is_whole_number(value) and float(value)>0.0


func _json_integer_tokens_are_canonical(json_text: String, require_failure_iteration: bool) -> bool:
	var integer_keys := [
		"schema","seed","iterations","boss_restarts","dive_transitions","projectile_cycles",
		"linear","delayed_linear","soft_homing","expanding","node_link","lunge","recorded_path",
		"player_projectiles_spawned","enemy_projectiles_spawned","save_writes","save_reloads",
		"offline_events_queued","offline_queue_reloads","offline_queue_final_size",
		"player_projectiles","enemy_projectiles","total_projectiles","object_count","node_count","orphan_node_count",
		"baseline_objects","baseline_nodes","final_objects","final_nodes","sample_count","stable_sample_count",
		"start_bytes","stable_start_bytes","end_bytes","peak_bytes","memory_bytes",
	]
	if require_failure_iteration:
		integer_keys.append("iteration")
	var integer_pattern := RegEx.new()
	if integer_pattern.compile("^-?(0|[1-9][0-9]*)$")!=OK:
		return false
	for key in integer_keys:
		var field_pattern := RegEx.new()
		if field_pattern.compile('"%s"[[:space:]]*:[[:space:]]*([^,}\\]\\r\\n]+)' % String(key))!=OK:
			return false
		var matches := field_pattern.search_all(json_text)
		if matches.is_empty():
			return false
		for raw_match in matches:
			var report_match := raw_match as RegExMatch
			if integer_pattern.search(report_match.get_string(1).strip_edges())==null:
				return false
	return true


func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length()!=expected_length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _recover_interrupted_report_pair(json_path: String, markdown_path: String, json_backup_path: String, markdown_backup_path: String) -> void:
	if _report_pair_is_valid(json_path,markdown_path):
		_remove_report_file(json_backup_path)
		_remove_report_file(markdown_backup_path)
		return
	if _report_pair_is_valid(json_backup_path,markdown_backup_path):
		_remove_report_file(json_path)
		_remove_report_file(markdown_path)
		var json_restore_error := _rename_report_file(json_backup_path,json_path)
		var markdown_restore_error := _rename_report_file(markdown_backup_path,markdown_path)
		if json_restore_error!=OK or markdown_restore_error!=OK or not _report_pair_is_valid(json_path,markdown_path):
			_record_failure("report_recovery", "Could not restore the previous complete report pair")
		return
	if _report_pair_is_valid(json_backup_path,markdown_path):
		_remove_report_file(json_path)
		if _rename_report_file(json_backup_path,json_path)!=OK or not _report_pair_is_valid(json_path,markdown_path):
			_record_failure("report_recovery", "Could not restore the interrupted JSON backup")
			return
		_remove_report_file(markdown_backup_path)
		return
	if _report_pair_is_valid(json_path,markdown_backup_path):
		_remove_report_file(markdown_path)
		if _rename_report_file(markdown_backup_path,markdown_path)!=OK or not _report_pair_is_valid(json_path,markdown_path):
			_record_failure("report_recovery", "Could not restore the interrupted Markdown backup")
			return
		_remove_report_file(json_backup_path)
		return
	_remove_report_file(json_backup_path)
	_remove_report_file(markdown_backup_path)


func _commit_report_pair(
	json_temporary_path: String, markdown_temporary_path: String,
	json_path: String, markdown_path: String,
	json_backup_path: String, markdown_backup_path: String,
	transaction_id: String, elapsed: float, memory_analysis: Dictionary
) -> void:
	var had_previous_pair := _report_pair_is_valid(json_path,markdown_path)
	var previous_json_hash := FileAccess.get_sha256(json_path) if had_previous_pair else ""
	var previous_markdown_hash := FileAccess.get_sha256(markdown_path) if had_previous_pair else ""
	var stale_json_cleanup_ok := _remove_report_file(json_backup_path)
	var stale_markdown_cleanup_ok := _remove_report_file(markdown_backup_path)
	if not stale_json_cleanup_ok or not stale_markdown_cleanup_ok:
		_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
		return
	if had_previous_pair:
		if _rename_report_file(json_path,json_backup_path)!=OK:
			_record_failure("report_backup", "Could not protect the previous JSON report")
			_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
			return
		if _rename_report_file(markdown_path,markdown_backup_path)!=OK:
			_rename_report_file(json_backup_path,json_path)
			_record_failure("report_backup", "Could not protect the previous Markdown report")
			_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
			return
		if not _report_pair_is_valid(json_backup_path,markdown_backup_path):
			_record_failure("report_backup_verify", "Protected report pair did not validate")
			_rollback_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path,had_previous_pair)
			_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
			return
	else:
		var invalid_json_cleanup_ok := _remove_report_file(json_path)
		var invalid_markdown_cleanup_ok := _remove_report_file(markdown_path)
		if not invalid_json_cleanup_ok or not invalid_markdown_cleanup_ok:
			_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
			return
	if report_self_test=="first_commit":
		_record_failure("report_first_commit", "Self-test simulated first report commit failure")
		_rollback_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path,had_previous_pair)
		_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
		_assert_previous_report_hashes(json_path,markdown_path,had_previous_pair,previous_json_hash,previous_markdown_hash)
		return
	if _rename_report_file(json_temporary_path,json_path)!=OK:
		_record_failure("report_first_commit", "Could not commit staged JSON report")
		_rollback_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path,had_previous_pair)
		_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
		_assert_previous_report_hashes(json_path,markdown_path,had_previous_pair,previous_json_hash,previous_markdown_hash)
		return
	if report_self_test=="second_commit":
		_record_failure("report_second_commit", "Self-test simulated second report commit failure")
		_rollback_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path,had_previous_pair)
		_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
		_assert_previous_report_hashes(json_path,markdown_path,had_previous_pair,previous_json_hash,previous_markdown_hash)
		return
	if _rename_report_file(markdown_temporary_path,markdown_path)!=OK:
		_record_failure("report_second_commit", "Could not commit staged Markdown report")
		_rollback_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path,had_previous_pair)
		_cleanup_staged_report_pair(json_temporary_path,markdown_temporary_path)
		_assert_previous_report_hashes(json_path,markdown_path,had_previous_pair,previous_json_hash,previous_markdown_hash)
		return
	if not _report_pair_is_valid(json_path,markdown_path,transaction_id,failures.is_empty(),false):
		_record_failure("report_final_verify", "Committed report pair did not cross-validate")
		_rollback_report_pair(json_path,markdown_path,json_backup_path,markdown_backup_path,had_previous_pair)
		_assert_previous_report_hashes(json_path,markdown_path,had_previous_pair,previous_json_hash,previous_markdown_hash)
		return
	var json_cleanup_ok := _remove_report_file(json_backup_path)
	var markdown_cleanup_ok := _remove_report_file(markdown_backup_path)
	if not json_cleanup_ok or not markdown_cleanup_ok:
		return
	_finalize_report_transaction(json_path,markdown_path,transaction_id,failures.is_empty(),elapsed,memory_analysis)


func _finalize_report_transaction(
	json_path: String, markdown_path: String, transaction_id: String,
	expected_passed: bool, elapsed: float, memory_analysis: Dictionary
) -> void:
	if not _report_pair_is_valid(json_path,markdown_path,transaction_id,expected_passed,false):
		_record_failure("report_finalize_read", "Pending report pair no longer cross-validates")
		return
	# Rebuild from typed runtime values rather than parsing and re-stringifying
	# JSON, because Godot parses JSON integer tokens as floats.
	var report := _build_json_report(
		elapsed,memory_analysis,transaction_id,FileAccess.get_sha256(markdown_path),true
	)
	var finalize_path := "%s.finalize.next" % json_path
	if not _remove_report_file(finalize_path):
		return
	var finalize_file := FileAccess.open(finalize_path,FileAccess.WRITE)
	if finalize_file==null:
		_record_failure("report_finalize_open", "Could not open the finalized JSON report: error %d" % FileAccess.get_open_error())
		return
	finalize_file.store_string(JSON.stringify(report,"\t"))
	finalize_file.flush()
	var finalize_error := finalize_file.get_error()
	var finalize_length := finalize_file.get_length()
	finalize_file.close()
	if finalize_error!=OK or finalize_length<=0:
		_record_failure("report_finalize_write", "Finalized JSON report write/flush failed: error %d bytes %d" % [finalize_error,finalize_length])
		_remove_report_file(finalize_path)
		return
	if not _report_pair_is_valid(finalize_path,markdown_path,transaction_id,expected_passed,true):
		_record_failure("report_finalize_verify", "Finalized JSON report did not cross-validate")
		_remove_report_file(finalize_path)
		return
	if not _remove_report_file(json_path):
		_remove_report_file(finalize_path)
		return
	if _rename_report_file(finalize_path,json_path)!=OK:
		_record_failure("report_finalize_commit", "Could not commit the finalized JSON report")
		return
	if not _report_pair_is_valid(json_path,markdown_path,transaction_id,expected_passed,true):
		_record_failure("report_finalize_verify", "Committed finalized report pair did not cross-validate")


func _rollback_report_pair(json_path: String, markdown_path: String, json_backup_path: String, markdown_backup_path: String, had_previous_pair: bool) -> void:
	_remove_report_file(json_path)
	_remove_report_file(markdown_path)
	if had_previous_pair:
		var json_restore_error := _rename_report_file(json_backup_path,json_path)
		var markdown_restore_error := _rename_report_file(markdown_backup_path,markdown_path)
		if json_restore_error!=OK or markdown_restore_error!=OK or not _report_pair_is_valid(json_path,markdown_path):
			_record_failure("report_rollback", "Could not restore the previous complete report pair")
	else:
		_remove_report_file(json_backup_path)
		_remove_report_file(markdown_backup_path)


func _assert_previous_report_hashes(json_path: String, markdown_path: String, had_previous_pair: bool, expected_json_hash: String, expected_markdown_hash: String) -> void:
	if had_previous_pair:
		if FileAccess.get_sha256(json_path)!=expected_json_hash or FileAccess.get_sha256(markdown_path)!=expected_markdown_hash:
			_record_failure("report_rollback_hash", "Rollback did not preserve the previous report pair byte-for-byte")
	elif FileAccess.file_exists(json_path) or FileAccess.file_exists(markdown_path):
		_record_failure("report_rollback_residue", "Failed transaction left a partial report pair without a previous pair")


func _cleanup_staged_report_pair(json_temporary_path: String, markdown_temporary_path: String) -> void:
	_remove_report_file(json_temporary_path)
	_remove_report_file(markdown_temporary_path)


func _rename_report_file(source_path: String, destination_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)

func _record_failure(code: String, detail: String) -> void:
	if failures.size() >= MAX_FAILURE_RECORDS:
		return
	failures.append({"elapsed_seconds":_elapsed_seconds(),"iteration":iterations,"code":code,"detail":detail})
	if failures.size() <= 20:
		printerr("SOAK FAILURE %s: %s" % [code,detail])

func _source_fingerprint() -> String:
	var records: Array[String] = []
	for source_path in ["res://project.godot","res://export_presets.cfg","res://scripts","res://data","res://scenes","res://assets","res://web"]:
		_collect_source_records(String(source_path),records)
	records.sort()
	return "\n".join(records).sha256_text()

func _collect_source_records(path: String, records: Array[String]) -> void:
	if path == "res://assets/store/gameplay/raw" or path.begins_with("res://assets/store/gameplay/raw/"):
		return
	var directory := DirAccess.open(path)
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if entry != "." and entry != "..":
				var child_path := path.path_join(entry)
				if directory.current_is_dir():
					_collect_source_records(child_path,records)
				elif not entry.ends_with(".uid"):
					records.append("%s:%s" % [child_path,FileAccess.get_sha256(child_path)])
			entry = directory.get_next()
		directory.list_dir_end()
	elif FileAccess.file_exists(path):
		records.append("%s:%s" % [path,FileAccess.get_sha256(path)])

func _elapsed_seconds() -> float:
	if started_ms <= 0:
		return 0.0
	return float(Time.get_ticks_msec()-started_ms)/1000.0

func _memory_bytes() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))

func _object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))

func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

func _orphan_node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
