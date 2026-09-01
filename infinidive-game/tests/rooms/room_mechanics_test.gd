extends Node

const Mechanics := preload("res://scripts/core/room_mechanics.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("ROOM MECHANICS TEST FAILURE: " + message)


func _run() -> void:
	var rooms := _read_rooms()
	_test_launch_catalog(rooms)
	_test_every_room_contract(rooms)
	_test_determinism(rooms)
	_test_fail_closed(rooms)
	_test_contract_guardrails(rooms)
	await _test_runtime_playback(rooms)
	print("INFINIDIVE ROOM MECHANICS TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _read_rooms() -> Array:
	var file := FileAccess.open("res://data/rooms.json", FileAccess.READ)
	_check(file != null, "Room catalog must be readable")
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(typeof(parsed) == TYPE_ARRAY, "Room catalog must parse as an array")
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


func _test_launch_catalog(rooms: Array) -> void:
	var non_chambers := 0
	var chambers := 0
	var hazards: Dictionary = {}
	for raw_room in rooms:
		var room := raw_room as Dictionary
		if String(room.type) == "chamber":
			chambers += 1
		else:
			non_chambers += 1
		hazards[String(room.hazard)] = true
	_check(non_chambers == 30, "Launch data must contain 30 authored non-chamber rooms")
	_check(chambers == 12, "Launch data must contain 12 authored organ chambers")
	_check(rooms.size() == 42, "Launch room total must be 42")
	_check(hazards.size() == 42, "Every authored room must have a distinct explicit hazard contract")
	_check(Mechanics.supported_hazards().size() == 42, "Mechanics registry must cover every shipped hazard")
	var errors := Mechanics.validate_catalog(rooms, true)
	_check(errors.is_empty(), "Launch room catalog must satisfy mechanics contracts: %s" % "; ".join(errors))


func _test_every_room_contract(rooms: Array) -> void:
	var families: Dictionary = {}
	var models: Dictionary = {}
	for index in range(rooms.size()):
		var room := rooms[index] as Dictionary
		var room_id := String(room.id)
		var contract := Mechanics.build_contract(room, 73013 + index)
		_check(bool(contract.get("valid", false)), "%s must build a valid contract: %s" % [room_id, contract.get("errors", [])])
		if not bool(contract.get("valid", false)):
			continue
		families[String(contract.family)] = true
		var movement := contract.movement as Dictionary
		models[String(movement.model)] = true
		_check(String(contract.safe_rule) == String(room.safe_rule), "%s must bind its exact authored safe rule" % room_id)
		_check(float(contract.safe_clearance_normalized) >= Mechanics.MIN_SAFE_CLEARANCE, "%s must keep non-zero player clearance" % room_id)
		_check(int(movement.lane_count) >= 2, "%s must expose at least two movement options" % room_id)
		_check(float(movement.max_required_speed_normalized) > 0.0, "%s must bound required movement speed" % room_id)
		var timing := contract.timing as Dictionary
		_check(float(timing.cadence) > float(timing.telegraph_seconds), "%s telegraph must precede its next cadence" % room_id)
		_check(float(timing.telegraph_seconds) >= 0.35, "%s must provide a readable telegraph" % room_id)
		var spawn := contract.spawn as Dictionary
		_check(not String(spawn.pattern).is_empty() and float(spawn.cadence) > 0.0, "%s must expose a real spawn cadence" % room_id)
		_check(int(spawn.max_active) > 0 and int(spawn.max_active) <= 14, "%s must bound simultaneous hazards/enemies" % room_id)
		var projectile := contract.projectile as Dictionary
		_check(not String(projectile.pattern).is_empty(), "%s must expose a projectile/structural specification" % room_id)
		if bool(projectile.enabled):
			_check(float(projectile.speed_pixels_per_second) > 0.0, "%s projectile must move" % room_id)
			_check(float(projectile.lifetime_seconds) > 0.0 and float(projectile.lifetime_seconds) <= 4.0, "%s projectile lifetime must be bounded" % room_id)
			_check(int(projectile.count) > 0, "%s projectile pattern must emit a non-zero count" % room_id)
		var events := contract.events as Array
		_check(not events.is_empty() and events.size() <= 64, "%s must have a bounded non-empty event schedule" % room_id)
		for raw_event in events:
			var event := raw_event as Dictionary
			_check(float(event.telegraph_at) < float(event.active_at), "%s event must telegraph before activation" % room_id)
			_check((event.safe_position as Array).size() == 2, "%s event must publish a safe position" % room_id)
			_check(int(event.safe_lane) not in (event.hazard_lanes as Array), "%s safe lane must never be marked hazardous" % room_id)
		var safe_path := contract.safe_path as Array
		_check(safe_path.size() >= 3, "%s must publish a non-empty safe path" % room_id)
		_check(_path_has_positive_clearance(safe_path), "%s safe path must retain positive clearance at every waypoint" % room_id)
		var last := safe_path[-1] as Dictionary
		_check(absf(float(last.time) - float(room.duration)) < 0.001, "%s safe path must reach the room end" % room_id)
		_check(_near_point(last.position as Array, Mechanics.EXIT_POINT), "%s safe path must reach the forward exit" % room_id)
		var exit := contract.exit as Dictionary
		_check(String(exit.kind) == "forward" and float(exit.width_normalized) >= Mechanics.MIN_EXIT_WIDTH, "%s cannot generate a procedural dead end" % room_id)
		_check(Mechanics.validate_contract(contract).is_empty(), "%s generated contract must pass independent validation" % room_id)
	_check(families.size() == 4, "Launch rooms must exercise lane, ring, sweep, and spawn families")
	for required_model in Mechanics.ALLOWED_MOVEMENT_MODELS:
		_check(models.has(required_model), "Launch rooms must exercise movement model: %s" % required_model)


func _test_determinism(rooms: Array) -> void:
	var seed_changes_schedule := 0
	for index in range(rooms.size()):
		var room := rooms[index] as Dictionary
		var first := Mechanics.build_contract(room, 998877)
		var repeat := Mechanics.build_contract(room, 998877)
		var alternate := Mechanics.build_contract(room, 998878)
		_check(first == repeat, "%s contract must be deterministic for the same seed" % String(room.id))
		if first.events != alternate.events:
			seed_changes_schedule += 1
	_check(seed_changes_schedule >= 36, "Challenge seed must materially vary nearly every room schedule")


func _test_fail_closed(rooms: Array) -> void:
	var unknown := (rooms[0] as Dictionary).duplicate(true)
	unknown.hazard = "unmapped_hazard"
	var unknown_contract := Mechanics.build_contract(unknown, 7)
	_check(not bool(unknown_contract.valid), "Unknown hazards must be rejected")
	_check("Unknown room hazard" in String(unknown_contract.errors[0]), "Unknown-hazard rejection must be inspectable")
	var changed_rule := (rooms[0] as Dictionary).duplicate(true)
	changed_rule.safe_rule = "Guess."
	_check(not bool(Mechanics.build_contract(changed_rule, 7).valid), "Hazards with mismatched safe rules must be rejected")
	var no_rule := (rooms[1] as Dictionary).duplicate(true)
	no_rule.erase("safe_rule")
	_check(not Mechanics.validate_room(no_rule).is_empty(), "Missing safe rules must fail validation")
	var invalid_density := (rooms[2] as Dictionary).duplicate(true)
	invalid_density.density = 0
	_check(not bool(Mechanics.build_contract(invalid_density, 7).valid), "Zero-density rooms must be rejected")
	var invalid_chamber := (rooms[-1] as Dictionary).duplicate(true)
	invalid_chamber.organ = ""
	_check(not Mechanics.validate_room(invalid_chamber).is_empty(), "Chambers without organ targets must be rejected")
	var duplicate_catalog := rooms.duplicate(true)
	duplicate_catalog.append((rooms[0] as Dictionary).duplicate(true))
	_check(not Mechanics.validate_catalog(duplicate_catalog, true).is_empty(), "Duplicate or over-count launch catalogs must be rejected")
	var safe_fallback := Mechanics.safe_fallback_contract(unknown, 7)
	_check(bool(safe_fallback.get("valid", false)), "Unknown hazards must resolve to a validated non-damaging-safe fallback contract")
	_check(String(safe_fallback.get("hazard", "")) == "closing_membranes", "Non-chamber fallback must use the known bright-opening contract")
	var unknown_chamber := (rooms[-1] as Dictionary).duplicate(true)
	unknown_chamber.hazard = "unmapped_chamber_hazard"
	var chamber_fallback := Mechanics.safe_fallback_contract(unknown_chamber, 8)
	_check(bool(chamber_fallback.get("valid", false)) and String(chamber_fallback.get("room_type", "")) == "chamber", "Chamber fallback must remain a valid organ chamber")


func _test_contract_guardrails(rooms: Array) -> void:
	var base := Mechanics.build_contract(rooms[0] as Dictionary, 314159)
	var no_path := base.duplicate(true)
	no_path.safe_path = []
	_check(not Mechanics.validate_contract(no_path).is_empty(), "Validator must reject zero safe paths")
	var no_clearance := base.duplicate(true)
	no_clearance.safe_clearance_normalized = 0.0
	_check(not Mechanics.validate_contract(no_clearance).is_empty(), "Validator must reject zero safe clearance")
	var dead_end := base.duplicate(true)
	dead_end.exit.width_normalized = 0.0
	_check(not Mechanics.validate_contract(dead_end).is_empty(), "Validator must reject procedural dead ends")
	var no_telegraph := base.duplicate(true)
	no_telegraph.events[0].telegraph_at = no_telegraph.events[0].active_at
	_check(not Mechanics.validate_contract(no_telegraph).is_empty(), "Validator must reject untelegraphed events")
	var impossible := base.duplicate(true)
	impossible.safe_path[1].time = 0.001
	impossible.safe_path[1].position = [0.95, 0.05]
	_check(not Mechanics.validate_contract(impossible).is_empty(), "Validator must reject impossible safe-path movement")
	var unbounded_projectile := Mechanics.build_contract(rooms[6] as Dictionary, 2718)
	unbounded_projectile.projectile.lifetime_seconds = 0.0
	_check(not Mechanics.validate_contract(unbounded_projectile).is_empty(), "Validator must reject unbounded/invalid projectile lifetime")


func _test_runtime_playback(rooms: Array) -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run := RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"deep","seed":84621,"mode":"story","competitive":false})
	add_child(run)
	run.set_physics_process(false)
	run.set_process(false)
	for room_index in rooms.size():
		var room := rooms[room_index] as Dictionary
		var seed := 600001 + room_index * 977
		var normal := _play_first_runtime_event(run,room,seed,1.0/30.0)
		var repeated := _play_first_runtime_event(run,room,seed,1.0/30.0)
		var hitch := _play_first_runtime_event(run,room,seed,0.25)
		var room_id := String(room.id)
		_check(bool(normal.get("telegraphed",false)), "%s runtime must visibly telegraph before activation" % room_id)
		_check(bool(normal.get("spawned",false)), "%s runtime must activate its first authored event" % room_id)
		_check(normal.get("signature",[]) == repeated.get("signature",[]), "%s event-local runtime output must be deterministic" % room_id)
		_check(normal.get("signature",[]) == hitch.get("signature",[]), "%s hitch playback must preserve deterministic event geometry" % room_id)
		_check(float(normal.get("initial_warning",0.0)) >= float(normal.get("required_warning",0.0))-0.001, "%s must never compress its warning window" % room_id)
		_check(not bool(normal.get("spawned_on_warning_frame",true)), "%s must not deal contract damage on the frame its warning begins" % room_id)
		_check(bool(normal.get("wave_cleaned",false)), "%s wave must clear at its advertised active-window boundary" % room_id)
		_check(int(normal.get("peak_enemies",0)) <= int(normal.get("max_active",0)), "%s must enforce spawn.max_active" % room_id)
	_test_wall_gap_runtime(run,rooms)
	_test_defender_runtime(run)
	_test_chamber_runtime_bounds(run,rooms)
	run.projectiles_clear_and_enemies()
	_check(run._projectiles.enemy_active.is_empty() and run._enemies.is_empty() and run._active_room_waves.is_empty() and run._telegraph.is_empty(), "Dive cleanup must clear projectiles, enemies, waves, and telegraphs")
	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile


func _play_first_runtime_event(run: Node, room: Dictionary, seed: int, delta: float) -> Dictionary:
	run.projectiles_clear_and_enemies()
	run._enemy_serial = 0
	run._room_contract = Mechanics.contract_for(room,seed)
	run.current_room = room.duplicate(true)
	run.state = RunSceneClass.RunState.ORGAN_CHAMBER if String(room.type)=="chamber" else RunSceneClass.RunState.INTERNAL_ROOMS
	run._room_elapsed = 0.0
	run._room_event_index = 0
	run._room_cycle_index = 0
	run._player.position = Vector2(270,790)
	var telegraphed := false
	var spawned := false
	var spawned_on_warning_frame := false
	var initial_warning := 0.0
	var required_warning := float((run._room_contract.timing as Dictionary).telegraph_seconds)
	var peak_enemies := 0
	var signature: Array = []
	var wave_id := ""
	for _step in 240:
		var warning_before: bool = not run._telegraph.is_empty()
		var event_before: int = int(run._room_event_index)
		run._update_contract_hazards(delta)
		peak_enemies = maxi(peak_enemies,run._enemies.size())
		if not warning_before and not run._telegraph.is_empty():
			telegraphed = true
			initial_warning = float(run._telegraph.timer)
			spawned_on_warning_frame = run._room_event_index != event_before or not run._projectiles.enemy_active.is_empty() or not run._enemies.is_empty()
		if run._room_event_index > 0:
			spawned = true
			var event := (run._room_contract.events as Array)[0] as Dictionary
			wave_id = "room:%s:0:%d" % [String(run._room_contract.room_id),int(event.index)]
			signature = _runtime_signature(run,wave_id)
			break
	var wave_cleaned := false
	if spawned and run._active_room_waves.has(wave_id):
		run._room_elapsed = float(run._active_room_waves[wave_id])+0.001
		run._expire_contract_waves()
		wave_cleaned = run._projectiles.enemy_group_size(wave_id)==0 and not _has_enemy_group(run._enemies,wave_id) and not run._active_room_waves.has(wave_id)
	var max_active := int((run._room_contract.spawn as Dictionary).max_active)
	return {"telegraphed":telegraphed,"spawned":spawned,"spawned_on_warning_frame":spawned_on_warning_frame,"initial_warning":initial_warning,"required_warning":required_warning,"signature":signature,"wave_cleaned":wave_cleaned,"peak_enemies":peak_enemies,"max_active":max_active}


func _runtime_signature(run: Node, wave_id: String) -> Array:
	var signature: Array = []
	for bullet in run._projectiles.enemy_active:
		if String(bullet.get("group","")) != wave_id:
			continue
		var position := Vector2(bullet.position)
		var velocity := Vector2(bullet.velocity)
		signature.append("p:%.3f:%.3f:%.3f:%.3f:%.3f" % [position.x,position.y,velocity.x,velocity.y,float(bullet.life)])
	for enemy in run._enemies:
		if String(enemy.get("contract_group","")) != wave_id:
			continue
		var position := Vector2(enemy.position)
		var velocity := Vector2(enemy.velocity)
		signature.append("e:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f" % [position.x,position.y,velocity.x,velocity.y,float(enemy.shoot_timer),float(enemy.phase)])
	return signature


func _test_wall_gap_runtime(run: Node, rooms: Array) -> void:
	var lane_room: Dictionary = {}
	for raw_room in rooms:
		var candidate := raw_room as Dictionary
		if String(Mechanics.contract_for(candidate,91).family) == "lane":
			lane_room = candidate
			break
	var seed := 44119
	run.projectiles_clear_and_enemies()
	run._room_contract = Mechanics.contract_for(lane_room,seed)
	run.current_room = lane_room
	run.state = RunSceneClass.RunState.INTERNAL_ROOMS
	run._room_elapsed = 0.0
	run._room_event_index = 0
	run._room_cycle_index = 0
	var gap_x := -1.0
	for _step in 180:
		run._update_contract_hazards(1.0/30.0)
		if not run._telegraph.is_empty():
			gap_x = float(run._telegraph.gap_x)
		if run._room_event_index > 0:
			break
	_check(gap_x >= 80.0 and gap_x <= 460.0, "Runtime wall warning must publish the authored safe gap")
	var gap_is_clear := true
	for bullet in run._projectiles.enemy_active:
		if absf(Vector2(bullet.position).x-gap_x) < 62.0:
			gap_is_clear = false
	_check(gap_is_clear, "Actual wall projectiles and rendered warning must use the same safe gap")


func _test_defender_runtime(run: Node) -> void:
	run.projectiles_clear_and_enemies()
	run._enemy_serial = 0
	_check(run._spawn_enemy(Vector2(150,430),775533,"",1), "Deterministic defender must spawn")
	var first := (run._enemies[0] as Dictionary).duplicate(true)
	run._enemies.clear()
	run._enemy_serial = 0
	_check(run._spawn_enemy(Vector2(150,430),775533,"",1), "Repeated deterministic defender must spawn")
	var repeated := run._enemies[0] as Dictionary
	_check(Vector2(first.velocity).is_equal_approx(Vector2(repeated.velocity)) and absf(float(first.shoot_timer)-float(repeated.shoot_timer))<0.0001 and absf(float(first.phase)-float(repeated.phase))<0.0001, "Event-local defender parameters must not depend on shared RNG state")
	run._enemies[0].shoot_timer = 0.0
	var bullets_before: int = int(run._projectiles.enemy_active.size())
	run._update_enemies(0.5)
	_check(float(run._enemies[0].shot_telegraph_timer)>0.0 and run._projectiles.enemy_active.size()==bullets_before, "Defender must enter a visible warning state before firing")
	var warning := float(run._enemies[0].shot_telegraph_total)
	run._update_enemies(warning*0.5)
	_check(run._projectiles.enemy_active.size()==bullets_before, "Defender cannot fire before its warning duration elapses")
	run._update_enemies(warning*0.6)
	_check(run._projectiles.enemy_active.size()==bullets_before+1, "Defender may fire only after its warning completes")
	run.projectiles_clear_and_enemies()
	for index in 5:
		run._spawn_enemy(Vector2(80+index*70,420),9000+index,"",2)
	_check(run._enemies.size()==2, "Enemy creation must enforce the supplied max-active bound")


func _test_chamber_runtime_bounds(run: Node, rooms: Array) -> void:
	for raw_room in rooms:
		var room := raw_room as Dictionary
		if String(room.get("hazard","")) not in ["egg_hatches","attack_replay"]:
			continue
		run.projectiles_clear_and_enemies()
		run._room_contract = Mechanics.contract_for(room,778899)
		run.current_room = room
		run.state = RunSceneClass.RunState.ORGAN_CHAMBER
		run._room_elapsed = 0.0
		run._room_event_index = 0
		run._room_cycle_index = 0
		var max_active := int((run._room_contract.spawn as Dictionary).max_active)
		var runtime_seed := int(run._room_contract.runtime_seed)
		run._spawn_enemy(Vector2(130,460),run._mix_room_seed(runtime_seed,0),"",max_active)
		run._spawn_enemy(Vector2(410,500),run._mix_room_seed(runtime_seed,1),"",max_active)
		var peak := 0
		var overlapping_wave := false
		for _step in int(float(room.duration)*2.2*30.0):
			run._update_contract_hazards(1.0/30.0)
			peak = maxi(peak,run._enemies.size())
			overlapping_wave = overlapping_wave or run._active_room_waves.size()>1
			if run._enemies.size()>max_active:
				break
		_check(peak<=max_active, "%s repeated chamber cycles must respect max-active" % String(room.id))
		_check(not overlapping_wave, "%s cannot overlap active waves with conflicting safe corridors" % String(room.id))
		_check(run._projectiles.enemy_active.size()<=run._projectiles.MAX_ENEMY, "%s repeated chamber cycles must remain within projectile pool bounds" % String(room.id))


func _has_enemy_group(enemies: Array, group_id: String) -> bool:
	for enemy in enemies:
		if String((enemy as Dictionary).get("contract_group","")) == group_id:
			return true
	return false


func _path_has_positive_clearance(path: Array) -> bool:
	for raw_waypoint in path:
		if float((raw_waypoint as Dictionary).get("clearance", 0.0)) < Mechanics.MIN_SAFE_CLEARANCE:
			return false
	return true


func _near_point(actual: Array, expected: Array, epsilon: float = 0.001) -> bool:
	return actual.size() == 2 and absf(float(actual[0]) - float(expected[0])) <= epsilon and absf(float(actual[1]) - float(expected[1])) <= epsilon
