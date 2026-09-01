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
	if source_fingerprint_end != source_fingerprint_start:
		_record_failure("source_changed_during_run", "Production source fingerprint changed while the soak process was active")
	_capture_metrics(elapsed)
	_validate_offline_queue_final()
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
	rng.seed = deterministic_seed

func _prepare_isolated_state() -> void:
	for path in [SaveManager.SAVE_PATH,SaveManager.BACKUP_PATH,SaveManager.TEMP_PATH,AnalyticsService.QUEUE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.save_profile()
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
		enemy_spawn_ok = projectile_pool.spawn_enemy(Vector2(x,180),Vector2(0,speed),8.0,{"life":3.0}) and enemy_spawn_ok
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
	projectile_pool.step(
		1.0/60.0,
		[{"id":"soak_target","position":Vector2(270,220),"radius":42.0}],
		Vector2(270,790),12.0
	)
	projectile_pool.clear_all()
	projectile_cycles += 1
	if not projectile_pool.player_active.is_empty() or not projectile_pool.enemy_active.is_empty():
		_record_failure("projectile_clear", "Active projectile survived clear_all at iteration %d" % iteration)
	if use_full_capacity and (projectile_pool._player_free.size() != ProjectilePoolClass.MAX_PLAYER or projectile_pool._enemy_free.size() != ProjectilePoolClass.MAX_ENEMY):
		_record_failure("projectile_reuse", "Full projectile capacity was not returned to reusable pools")

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
	var artifacts := DirAccess.open("res://")
	if artifacts and not artifacts.dir_exists("artifacts"):
		artifacts.make_dir("artifacts")
	var report := {
		"schema":1,
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
	var json_file := FileAccess.open("res://artifacts/%s.json" % report_stem,FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify(report,"\t"))
	var markdown_file := FileAccess.open("res://artifacts/%s.md" % report_stem,FileAccess.WRITE)
	if markdown_file:
		var memory_slope_mb := float(memory_analysis.get("slope_bytes_per_minute",0.0))/1048576.0
		var memory_delta_mb := float(memory_analysis.get("stable_delta_bytes",0.0))/1048576.0
		var memory_peak_mb := float(memory_analysis.get("peak_bytes",0.0))/1048576.0
		var body := "# INFINIDIVE Headless Soak Report\n\n"
		body += "- Result: **%s**\n" % ("PASS" if failures.is_empty() else "FAIL")
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
		markdown_file.store_string(body)

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
