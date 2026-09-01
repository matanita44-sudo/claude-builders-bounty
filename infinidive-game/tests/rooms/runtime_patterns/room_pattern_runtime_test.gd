extends Node

const Mechanics := preload("res://scripts/core/room_mechanics.gd")
const Runtime := preload("res://scripts/core/room_pattern_runtime.gd")
const Space := preload("res://scripts/core/room_space.gd")

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("ROOM PATTERN RUNTIME TEST FAILURE: " + message)


func _run() -> void:
	await get_tree().process_frame
	var rooms := _read_rooms()
	_test_registry_and_catalog_coverage(rooms)
	_test_room_space()
	_test_every_room_plan(rooms)
	_test_transient_wave_lifecycle(rooms)
	_test_structural_safe_clearance(rooms)
	_test_determinism(rooms)
	_test_replay_integrity(rooms)
	_test_validation_hardening(rooms)
	_test_declared_values_change_behavior(rooms)
	_test_geometry_taxonomy(rooms)
	_test_caps_and_fail_closed(rooms)
	print("INFINIDIVE ROOM PATTERN RUNTIME TESTS: %d passed, %d failed" % [passed, failures.size()])
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)


func _read_rooms() -> Array:
	var file := FileAccess.open("res://data/rooms.json", FileAccess.READ)
	_check(file != null, "Room catalog must be readable")
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(typeof(parsed) == TYPE_ARRAY, "Room catalog must parse as an array")
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


func _test_registry_and_catalog_coverage(rooms: Array) -> void:
	_check(Runtime.validate_runtime_registry().is_empty(), "Runtime registries must be internally complete")
	_check(Runtime.validate_catalog(rooms).is_empty(), "Every catalog contract value must compile to a runtime behavior")
	_check(Runtime.supported_spawn_patterns().size() == 42, "All 42 authored spawn.pattern values must map exactly")
	_check(Runtime.supported_projectile_patterns().size() == 25, "All 25 authored projectile.pattern values must map exactly")
	_check(Runtime.supported_movement_models().size() == 6, "All six movement.model values must map exactly")
	_check(Runtime.supported_primitives().size() >= 8, "Runtime must expose at least eight reusable primitives")
	_check(Runtime.supported_defender_archetypes().size() >= 4, "Runtime must expose at least four defender archetypes")
	var declared_spawn: Dictionary = {}
	var declared_projectile: Dictionary = {}
	var declared_movement: Dictionary = {}
	for index in range(rooms.size()):
		var contract := Mechanics.build_contract(rooms[index] as Dictionary, 7001 + index)
		declared_spawn[String((contract.spawn as Dictionary).pattern)] = true
		declared_projectile[String((contract.projectile as Dictionary).pattern)] = true
		declared_movement[String((contract.movement as Dictionary).model)] = true
	_check(_same_keys(declared_spawn, Runtime.supported_spawn_patterns()), "Spawn registry must have neither missing nor orphan catalog aliases")
	_check(_same_keys(declared_projectile, Runtime.supported_projectile_patterns()), "Projectile registry must have neither missing nor orphan catalog aliases")
	_check(_same_keys(declared_movement, Runtime.supported_movement_models()), "Movement registry must have neither missing nor orphan catalog aliases")


func _test_room_space() -> void:
	for room_rect in [Rect2(0.0, 0.0, 540.0, 960.0), Rect2(24.0, 59.0, 393.0, 782.0), Rect2(10.0, 20.0, 720.0, 1280.0)]:
		for point in [[0.04, 0.04], [0.5, 0.5], [0.96, 0.96], [0.23, 0.81]]:
			var world := Space.normalized_to_world(point, room_rect)
			var round_trip := Space.world_to_normalized(world, room_rect)
			_check(_distance(point, round_trip) < 0.00001, "RoomSpace normalized/world transforms must round-trip across target aspect ratios")
		_check(is_equal_approx(Space.normalized_clearance_to_world(0.1, room_rect), minf(room_rect.size.x, room_rect.size.y) * 0.1), "RoomSpace clearance must scale from the safe-area short edge")
	_check(Space.clamp_normalized([-2.0, 4.0]) == [0.04, 0.96], "RoomSpace must clamp runtime geometry inside readable bounds")
	_check(Space.inside_normalized([0.5, 0.5]) and not Space.inside_normalized([1.2, 0.5]), "RoomSpace must validate normalized geometry")


func _test_every_room_plan(rooms: Array) -> void:
	var used_spawn_primitives: Dictionary = {}
	var used_projectile_primitives: Dictionary = {}
	var used_movement_primitives: Dictionary = {}
	var used_defenders: Dictionary = {}
	var visual_signatures: Dictionary = {}
	var structural_rooms := 0
	for index in range(rooms.size()):
		var room := rooms[index] as Dictionary
		var room_id := String(room.id)
		var contract := Mechanics.build_contract(room, 91001 + index * 977)
		var source_snapshot := contract.duplicate(true)
		var plan := Runtime.compile_contract(contract)
		_check(contract == source_snapshot, "%s compile must not mutate its RoomMechanics contract" % room_id)
		_check(bool(plan.get("valid", false)), "%s must compile: %s" % [room_id, plan.get("errors", [])])
		if not bool(plan.get("valid", false)):
			continue
		_check(Runtime.validate_plan(plan).is_empty(), "%s execution plan must independently validate" % room_id)
		_check(String(plan.coordinate_space) == Runtime.COORDINATE_SPACE, "%s must use unified room-normalized space" % room_id)
		_check(String(plan.hazard) == String(contract.hazard) and String(plan.family) == String(contract.family), "%s must retain hazard/family attribution" % room_id)
		_check(is_equal_approx(float(plan.duration), float(contract.duration)), "%s must retain authored duration" % room_id)
		var source := plan.source as Dictionary
		_check(String(source.spawn_pattern) == String((contract.spawn as Dictionary).pattern), "%s must consume its exact spawn.pattern" % room_id)
		_check(String(source.projectile_pattern) == String((contract.projectile as Dictionary).pattern), "%s must consume its exact projectile.pattern" % room_id)
		_check(String(source.movement_model) == String((contract.movement as Dictionary).model), "%s must consume its exact movement.model" % room_id)
		_check(String(plan.safe_path_signature) == Runtime.safe_path_signature(contract.safe_path as Array), "%s must expose its exact safe-path signature" % room_id)
		_check(not String(plan.plan_signature).is_empty() and not String(plan.visual_signature).is_empty() and not String(plan.geometry_signature).is_empty() and not String(plan.lifecycle_signature).is_empty(), "%s must expose deterministic replay/visual/geometry/lifecycle signatures" % room_id)
		_check(String(plan.geometry_signature) == Runtime.geometry_signature_for_plan(plan), "%s geometry signature must derive from executable topology rather than source labels" % room_id)
		_check(String(plan.lifecycle_signature) == Runtime.lifecycle_signature_for_plan(plan), "%s lifecycle signature must derive from executable operation order and ownership" % room_id)
		_check(not visual_signatures.has(String(plan.visual_signature)), "%s must retain a distinct authored visual identity" % room_id)
		visual_signatures[String(plan.visual_signature)] = room_id
		var plan_events := plan.events as Array
		_check(plan_events.size() == mini((contract.events as Array).size(), Runtime.MAX_EVENTS), "%s must compile every bounded schedule event" % room_id)
		for raw_event in plan_events:
			var event := raw_event as Dictionary
			var spawn := event.spawn as Dictionary
			var projectile := event.projectile as Dictionary
			var movement := event.movement as Dictionary
			used_spawn_primitives[String(spawn.primitive)] = true
			used_projectile_primitives[String(projectile.primitive)] = true
			used_movement_primitives[String(movement.primitive)] = true
			if String(spawn.defender_archetype) != "none":
				used_defenders[String(spawn.defender_archetype)] = true
			_check(String(spawn.source_pattern) == String(source.spawn_pattern), "%s event spawn primitive must retain its source alias" % room_id)
			_check(String(projectile.source_pattern) == String(source.projectile_pattern), "%s event projectile primitive must retain its source alias" % room_id)
			_check(String(movement.source_model) == String(source.movement_model), "%s event motion primitive must retain its source model" % room_id)
			_check(int(spawn.hazard_count) <= Runtime.MAX_HAZARDS_PER_EVENT and int(spawn.enemy_count) <= Runtime.MAX_ENEMIES_PER_EVENT, "%s spawn counts must be bounded" % room_id)
			_check(int(spawn.max_active_enemies) <= Runtime.MAX_ACTIVE_ENEMIES, "%s active defenders must be bounded" % room_id)
			_check(int(projectile.count) <= Runtime.MAX_PROJECTILES_PER_EVENT and int(projectile.max_active) <= Runtime.MAX_ACTIVE_PROJECTILES, "%s projectile counts must be bounded" % room_id)
			_check(String(event.owner_wave_id) == String(projectile.owner_wave_id) and String(event.owner_wave_id) == String(spawn.owner_wave_id), "%s defender/projectile work must inherit its parent wave" % room_id)
			for raw_operation in event.operations as Array:
				_check(String((raw_operation as Dictionary).owner_wave_id) == String(event.owner_wave_id), "%s every wave descendant must support atomic cleanup attribution" % room_id)
			_check(_operation_names(event.operations as Array) in [["telegraph", "apply_movement", "spawn", "emit_projectiles", "close_emitter", "clear_wave"], ["telegraph", "apply_movement", "spawn", "hold_structural_hazard", "close_emitter", "clear_wave"]], "%s must expose an ordered execution lifecycle" % room_id)
			_check(String((event.telegraph as Dictionary).signature) == String(event.visual_signature), "%s telegraph must expose the matching draw signature" % room_id)
			_check(String((event.telegraph as Dictionary).coordinate_space) == Runtime.COORDINATE_SPACE, "%s telegraph geometry must use unified room space" % room_id)
			_check(not (spawn.collision as Dictionary).is_empty(), "%s structural/defender positions must carry explicit collision geometry" % room_id)
			for raw_position in spawn.positions as Array:
				var position := (raw_position as Dictionary).position as Array
				_check(_inside(position), "%s spawn geometry must remain inside normalized room space" % room_id)
				if String(spawn.defender_archetype) != "none":
					_check(_distance(position, (event.safe as Dictionary).position as Array) >= float((event.safe as Dictionary).clearance) + 0.024, "%s defender spawn must preserve the published safe corridor" % room_id)
			if bool((contract.projectile as Dictionary).enabled):
				_check(int(projectile.count) > 0, "%s enabled projectile alias must emit a bounded nonzero pattern" % room_id)
				_check((projectile.directions_degrees as Array).size() == int(projectile.count), "%s projectile geometry count must match emission count" % room_id)
			else:
				structural_rooms += 1 if int(event.index) == 0 else 0
				_check(String(projectile.source_pattern) == "none_structural" and int(projectile.count) == 0, "%s none_structural must never fabricate generic bullets" % room_id)
				_check("emit_projectiles" not in _operation_names(event.operations as Array), "%s structural-only waves cannot execute projectile emission" % room_id)
	_check(used_spawn_primitives.size() >= 8, "Launch plans must exercise at least eight reusable spawn primitives")
	_check(used_projectile_primitives.size() >= 8, "Launch plans must exercise at least eight reusable projectile primitives")
	_check(used_movement_primitives.size() == 6, "Launch plans must exercise every movement behavior")
	_check(used_defenders.size() >= 4, "Launch plans must exercise at least four distinct defender archetypes")
	_check(structural_rooms == 18, "All 18 none_structural profiles must remain projectile-free")
	_check(visual_signatures.size() == rooms.size(), "All 42 room plans must expose distinct visual signatures")


func _test_transient_wave_lifecycle(rooms: Array) -> void:
	var projectile_events := 0
	var delayed_events := 0
	var defender_events := 0
	var armored_events := 0
	var projectile_sample: Dictionary = {}
	var defender_sample: Dictionary = {}
	for room_index in range(rooms.size()):
		var room := rooms[room_index] as Dictionary
		var room_id := String(room.get("id", "room-%d" % room_index))
		var contract := Mechanics.build_contract(room, 440011 + room_index * 499)
		var plan := Runtime.compile_contract(contract)
		_check(bool(plan.get("valid", false)), "%s transient lifecycle plan must compile" % room_id)
		if not bool(plan.get("valid", false)):
			continue
		for raw_event in plan.events as Array:
			var event := raw_event as Dictionary
			var operations := event.operations as Array
			var close_operation := operations[4] as Dictionary
			var clear_operation := operations[5] as Dictionary
			var spawn_operation := operations[2] as Dictionary
			var spawn := event.spawn as Dictionary
			var projectile := event.projectile as Dictionary
			var active_seconds := float(event.clear_at) - float(event.active_at)
			_check(is_equal_approx(float(close_operation.at), float(event.clear_at)), "%s emitter must close exactly at clear_at" % room_id)
			_check(is_equal_approx(float(clear_operation.at), float(event.clear_at)), "%s transient wave must clear exactly at clear_at" % room_id)
			_check(String(clear_operation.get("mode", "")) == "force" and String(clear_operation.get("reason", "")) == "transient_boundary", "%s clear_wave must declare its forced transient-boundary reason" % room_id)
			_check(not clear_operation.has("when") and not clear_operation.has("timeout_seconds"), "%s transient clear cannot wait beyond clear_at" % room_id)
			_check(not close_operation.has("actor_owner_id") and not clear_operation.has("actor_owner_id"), "%s transient cleanup cannot target the independent actor owner" % room_id)
			_check(String(event.lifecycle_signature) == Runtime.lifecycle_signature_for_event(event), "%s event lifecycle signature must cover its exact close/clear contract" % room_id)
			if int(projectile.count) > 0:
				projectile_events += 1
				if projectile_sample.is_empty():
					projectile_sample = plan.duplicate(true)
				var delay := float(projectile.get("max_delay_seconds", -1.0))
				var latest_threat := minf(Runtime.MAX_THREAT_TIME_SECONDS, maxf(Runtime.MIN_THREAT_TIME_SECONDS, active_seconds - Runtime.EMISSION_BOUNDARY_GUARD_SECONDS))
				var expected_threat := clampf(active_seconds * 0.58, Runtime.MIN_THREAT_TIME_SECONDS, latest_threat)
				_check(is_equal_approx(float(projectile.lifetime_seconds), active_seconds), "%s effective projectile life must end at clear_at" % room_id)
				_check(float(projectile.authored_lifetime_seconds) > 0.0, "%s projectile plan must retain its source lifetime as non-blocking metadata" % room_id)
				_check(delay >= 0.0 and delay <= Runtime.MAX_DELAYED_EMISSION_SECONDS and delay < active_seconds - Runtime.EMISSION_BOUNDARY_GUARD_SECONDS + 0.000001, "%s delayed emission must remain inside the active window" % room_id)
				_check(is_equal_approx(float(projectile.threat_time_seconds), expected_threat), "%s first frozen threat must use the bounded active-window TTI" % room_id)
				if String(projectile.travel_model) == "delayed_linear":
					delayed_events += 1
					_check(delay > 0.0, "%s delayed_linear must publish a real bounded emission delay" % room_id)
			else:
				_check(is_zero_approx(float(projectile.get("max_delay_seconds", 0.0))), "%s structural wave cannot fabricate a projectile tail" % room_id)
			var actor_owner_id := String(spawn.get("actor_owner_id", ""))
			var actor_seconds := float(spawn.get("actor_resolution_seconds", -1.0))
			if int(spawn.enemy_count) > 0:
				defender_events += 1
				if defender_sample.is_empty():
					defender_sample = plan.duplicate(true)
				var armored := String((spawn.defender_behavior as Dictionary).get("health_class", "")) == "armored"
				armored_events += 1 if armored else 0
				_check(actor_owner_id.begins_with("actor:") and actor_owner_id != String(event.owner_wave_id), "%s defender owner must be independent from its transient emitter" % room_id)
				_check(actor_seconds >= Runtime.MIN_ACTOR_RESOLUTION_SECONDS and actor_seconds <= Runtime.ARMORED_ACTOR_RESOLUTION_SECONDS, "%s defender resolution must remain bounded" % room_id)
				_check(is_equal_approx(actor_seconds, Runtime.ARMORED_ACTOR_RESOLUTION_SECONDS if armored else Runtime.ACTOR_RESOLUTION_SECONDS), "%s defender resolution must match its health class" % room_id)
				_check(String(spawn_operation.actor_owner_id) == actor_owner_id and is_equal_approx(float(spawn_operation.actor_resolution_seconds), actor_seconds), "%s spawn operation must retain actor ownership and lifetime" % room_id)
				_check(not bool(spawn_operation.blocks_next_event) and bool(spawn_operation.blocks_room_exit), "%s defenders may overlap the next telegraph but must resolve before exit" % room_id)
			else:
				_check(actor_owner_id.is_empty() and is_zero_approx(actor_seconds), "%s actor-free wave must retain zero actor metadata" % room_id)
				_check(String(spawn_operation.actor_owner_id).is_empty() and is_zero_approx(float(spawn_operation.actor_resolution_seconds)), "%s actor-free spawn operation must not fabricate ownership" % room_id)
				_check(not bool(spawn_operation.blocks_next_event) and not bool(spawn_operation.blocks_room_exit), "%s actor-free spawn cannot block event or exit progression" % room_id)
	_check(projectile_events > 0 and delayed_events > 0, "Catalog lifecycle tests must exercise regular and delayed transient projectile waves")
	_check(defender_events > 0 and armored_events > 0, "Catalog lifecycle tests must exercise regular and armored independent defender owners")

	var tampered_close := projectile_sample.duplicate(true)
	var tampered_close_event := (tampered_close.events as Array)[0] as Dictionary
	((tampered_close_event.operations as Array)[4] as Dictionary).at = float(tampered_close_event.clear_at) + 0.01
	_check(not Runtime.validate_plan(tampered_close).is_empty(), "Plan validation must reject an emitter close after the transient boundary")
	var tampered_clear := projectile_sample.duplicate(true)
	var tampered_clear_event := (tampered_clear.events as Array)[0] as Dictionary
	((tampered_clear_event.operations as Array)[5] as Dictionary).reason = "descendants_empty"
	_check(not Runtime.validate_plan(tampered_clear).is_empty(), "Plan validation must reject stale descendants-based transient cleanup")
	var tampered_lifetime := projectile_sample.duplicate(true)
	var tampered_lifetime_event := (tampered_lifetime.events as Array)[0] as Dictionary
	(tampered_lifetime_event.projectile as Dictionary).lifetime_seconds = float((tampered_lifetime_event.projectile as Dictionary).authored_lifetime_seconds)
	_check(not Runtime.validate_plan(tampered_lifetime).is_empty(), "Plan validation must reject projectiles that outlive clear_at")
	var tampered_actor := defender_sample.duplicate(true)
	var tampered_actor_event := (tampered_actor.events as Array)[0] as Dictionary
	(tampered_actor_event.spawn as Dictionary).actor_owner_id = String(tampered_actor_event.owner_wave_id)
	_check(not Runtime.validate_plan(tampered_actor).is_empty(), "Plan validation must reject defenders owned by the transient wave")

	var signature_contract := _contract_with_projectile(rooms, "falling_cells", 775501)
	var base_signature_plan := Runtime.compile_contract(signature_contract)
	var changed_boundary_contract := signature_contract.duplicate(true)
	changed_boundary_contract.timing.active_seconds = float(changed_boundary_contract.timing.active_seconds) + 0.03
	for raw_event in changed_boundary_contract.events as Array:
		(raw_event as Dictionary).clear_at = float((raw_event as Dictionary).clear_at) + 0.03
	var changed_boundary_plan := Runtime.compile_contract(changed_boundary_contract)
	_check(String(base_signature_plan.lifecycle_signature) != String(changed_boundary_plan.lifecycle_signature), "Changing the transient boundary must change lifecycle identity")
	_check(String(base_signature_plan.plan_signature) != String(changed_boundary_plan.plan_signature), "Changing lifecycle timing must invalidate the replay plan signature")


func _test_structural_safe_clearance(rooms: Array) -> void:
	var exercised_shapes: Dictionary = {}
	for room_index in range(rooms.size()):
		var room := rooms[room_index] as Dictionary
		var room_id := String(room.get("id", "room-%d" % room_index))
		var plan := Runtime.compile_room(room, 230011 + room_index * 313)
		_check(bool(plan.get("valid", false)), "%s safe-clearance plan must compile" % room_id)
		if not bool(plan.get("valid", false)):
			continue
		for raw_event in plan.events as Array:
			var event := raw_event as Dictionary
			var spawn := event.spawn as Dictionary
			var safe := event.safe as Dictionary
			var collision := spawn.collision as Dictionary
			var shape := String(collision.get("shape", ""))
			exercised_shapes[shape] = true
			var player_radius := float(safe.get("player_radius_normalized", 0.0))
			var required := float(safe.clearance) + player_radius + Runtime.SAFE_GEOMETRY_EPSILON
			var actual := Runtime.structural_geometry_clearance(spawn.positions as Array, collision, safe.position as Array)
			_check(player_radius >= Runtime.PLAYER_RADIUS_NORMALIZED, "%s event must publish the bounded player radius" % room_id)
			_check(actual + 0.000001 >= required, "%s %s geometry must clear the safe disk plus player radius (%.4f < %.4f)" % [room_id, shape, actual, required])
			_check(Runtime.structural_geometry_clears_safe_disk(spawn.positions as Array, collision, safe.position as Array, float(safe.clearance), player_radius), "%s %s geometry must pass the independent safe-disk predicate" % [room_id, shape])
	for required_shape in ["circle", "box", "cell", "arc", "segment_chain"]:
		_check(exercised_shapes.has(required_shape), "Launch plans must exercise geometry-aware clearance for %s" % required_shape)

	var safe_position := [0.5, 0.5]
	var safe_clearance := 0.10
	var shape_cases := [
		{
			"name":"circle",
			"collision":{"enabled":true,"shape":"circle","radius_normalized":0.035},
			"unsafe":[{"position":[0.5,0.5]}],
			"safe":[{"position":[0.80,0.5]}],
		},
		{
			"name":"box",
			"collision":{"enabled":true,"shape":"box","half_extents_normalized":[0.055,0.12]},
			"unsafe":[{"position":[0.5,0.5]}],
			"safe":[{"position":[0.84,0.5]}],
		},
		{
			"name":"cell",
			"collision":{"enabled":true,"shape":"cell","half_extents_normalized":[0.07,0.07]},
			"unsafe":[{"position":[0.5,0.5]}],
			"safe":[{"position":[0.82,0.5]}],
		},
		{
			"name":"arc",
			"collision":{"enabled":true,"shape":"arc","radius_normalized":0.24,"thickness_normalized":0.035},
			"unsafe":[{"position":[0.74,0.5]}],
			"safe":[{"position":[0.5,0.5]}],
		},
		{
			"name":"segment_chain",
			"collision":{"enabled":true,"shape":"segment_chain","thickness_normalized":0.025},
			"unsafe":[{"position":[0.2,0.5]},{"position":[0.8,0.5]}],
			"safe":[{"position":[0.2,0.8]},{"position":[0.8,0.8]}],
		},
	]
	for raw_case in shape_cases:
		var shape_case := raw_case as Dictionary
		_check(not Runtime.structural_geometry_clears_safe_disk(shape_case.unsafe as Array, shape_case.collision as Dictionary, safe_position, safe_clearance), "%s collision must detect an unsafe disk intersection" % String(shape_case.name))
		_check(Runtime.structural_geometry_clears_safe_disk(shape_case.safe as Array, shape_case.collision as Dictionary, safe_position, safe_clearance), "%s collision must accept separated geometry" % String(shape_case.name))

	var tampered := Runtime.compile_room(rooms[0] as Dictionary, 77219)
	var tampered_event := (tampered.events as Array)[0] as Dictionary
	var tampered_positions := (tampered_event.spawn as Dictionary).positions as Array
	(tampered_positions[0] as Dictionary).position = (tampered_event.safe as Dictionary).position
	_check(not Runtime.validate_plan(tampered).is_empty(), "Plan validation must reject structural geometry moved into the published safe disk")


func _test_determinism(rooms: Array) -> void:
	var varied := 0
	for index in range(rooms.size()):
		var room := rooms[index] as Dictionary
		var first := Runtime.compile_room(room, 884422)
		var repeat := Runtime.compile_room(room, 884422)
		var alternate := Runtime.compile_room(room, 884423)
		_check(first == repeat, "%s runtime plan must be byte-for-byte deterministic for its seed" % String(room.id))
		if String(first.get("plan_signature", "")) != String(alternate.get("plan_signature", "")):
			varied += 1
	_check(varied >= 36, "Challenge seed must materially alter nearly every execution-plan signature")


func _test_replay_integrity(rooms: Array) -> void:
	var projectile_contract := _contract_with_projectile(rooms, "falling_cells", 991337)
	var base := Runtime.compile_contract(projectile_contract)
	_check(bool(base.get("valid", false)), "Replay-integrity projectile fixture must compile")
	if not bool(base.get("valid", false)):
		return

	# Source-level executable changes must produce a new geometry and top-level
	# replay identity, even when aliases, counts, timing, and visuals are unchanged.
	var changed_damage_contract := projectile_contract.duplicate(true)
	changed_damage_contract.projectile.damage = float(changed_damage_contract.projectile.damage) + 0.125
	var changed_damage := Runtime.compile_contract(changed_damage_contract)
	_check(String(base.geometry_signature) != String(changed_damage.geometry_signature), "Projectile damage must participate in canonical geometry identity")
	_check(String(base.plan_signature) != String(changed_damage.plan_signature), "Canonical plan identity must include geometry identity")

	for field in ["emitters", "radius_pixels", "travel_model", "damage"]:
		var tampered := base.duplicate(true)
		var event := (tampered.events as Array)[0] as Dictionary
		var projectile := event.projectile as Dictionary
		match field:
			"emitters":
				var emitters := projectile.emitters as Array
				var emitter := (emitters[0] as Array).duplicate()
				emitter[0] = float(emitter[0]) + 0.001
				emitters[0] = emitter
				projectile.emitters = emitters
			"radius_pixels":
				projectile.radius_pixels = float(projectile.radius_pixels) + 0.125
			"travel_model":
				projectile.travel_model = "recorded_path"
			"damage":
				projectile.damage = float(projectile.damage) + 0.125
		event.projectile = projectile
		((event.operations as Array)[3] as Dictionary).plan = projectile.duplicate(true)
		_assert_geometry_tamper_rejected(tampered, "projectile.%s" % field)

	var arc_contract := _contract_with_spawn(rooms, "rib_arc", 991339)
	var arc_plan := Runtime.compile_contract(arc_contract)
	_check(bool(arc_plan.get("valid", false)), "Replay-integrity arc fixture must compile")
	if not bool(arc_plan.get("valid", false)):
		return
	var collision_tampered := arc_plan.duplicate(true)
	var collision_event := (collision_tampered.events as Array)[0] as Dictionary
	var collision_spawn := collision_event.spawn as Dictionary
	var collision := collision_spawn.collision as Dictionary
	collision.thickness_normalized = float(collision.thickness_normalized) + 0.0001
	collision.damage = float(collision.damage) + 0.125
	collision_spawn.collision = collision
	collision_event.spawn = collision_spawn
	((collision_event.operations as Array)[2] as Dictionary).plan = collision_spawn.duplicate(true)
	((collision_event.operations as Array)[3] as Dictionary).collision = collision.duplicate(true)
	_assert_geometry_tamper_rejected(collision_tampered, "collision thickness/damage")

	var movement_tampered := arc_plan.duplicate(true)
	var movement_event := (movement_tampered.events as Array)[0] as Dictionary
	var movement := movement_event.movement as Dictionary
	movement.angular_rate = float(movement.angular_rate) + 0.0001
	movement_event.movement = movement
	((movement_event.operations as Array)[1] as Dictionary).plan = movement.duplicate(true)
	_assert_geometry_tamper_rejected(movement_tampered, "movement controller")

	var telegraph_tampered := base.duplicate(true)
	var telegraph_event := (telegraph_tampered.events as Array)[0] as Dictionary
	var telegraph := telegraph_event.telegraph as Dictionary
	telegraph.color_role = "tampered_warning"
	telegraph_event.telegraph = telegraph
	((telegraph_event.operations as Array)[0] as Dictionary).plan = telegraph.duplicate(true)
	_assert_geometry_tamper_rejected(telegraph_tampered, "telegraph payload")

	# Once the canonical event/plan geometry digests are refreshed, the old plan
	# signature must still fail; this specifically proves it covers geometry.
	var rebased := base.duplicate(true)
	var rebased_event := (rebased.events as Array)[0] as Dictionary
	var rebased_projectile := rebased_event.projectile as Dictionary
	rebased_projectile.damage = float(rebased_projectile.damage) + 0.125
	rebased_event.projectile = rebased_projectile
	((rebased_event.operations as Array)[3] as Dictionary).plan = rebased_projectile.duplicate(true)
	rebased_event.geometry_signature = Runtime.geometry_signature_for_event(rebased_event)
	rebased.geometry_signature = Runtime.geometry_signature_for_plan(rebased)
	var rebased_errors := Runtime.validate_plan(rebased)
	_check("Plan signature does not match its compiled lifecycle" in rebased_errors, "A refreshed geometry digest must invalidate the prior top-level plan signature")


func _assert_geometry_tamper_rejected(plan: Dictionary, label: String) -> void:
	var event := (plan.events as Array)[0] as Dictionary
	_check(String(event.geometry_signature) != Runtime.geometry_signature_for_event(event), "%s must change canonical event geometry" % label)
	var errors := Runtime.validate_plan(plan)
	_check(not errors.is_empty(), "%s tamper must fail independent plan validation" % label)


func _test_validation_hardening(rooms: Array) -> void:
	var contract := _contract_with_projectile(rooms, "falling_cells", 991401)
	var base := Runtime.compile_contract(contract)
	_check(bool(base.get("valid", false)), "Validation-hardening fixture must compile")
	if not bool(base.get("valid", false)):
		return
	_check((base.get("timing", {}) as Dictionary) == (contract.get("timing", {}) as Dictionary), "Canonical plan must bind the exact live room timing payload")
	_check(int((contract.movement as Dictionary).lane_count) == 3, "Safe-lane topology fixture must expose exactly three movement lanes")

	var invalid_safe_lane := contract.duplicate(true)
	((invalid_safe_lane.events as Array)[0] as Dictionary).safe_lane = 8
	var invalid_lane_errors := Runtime.validate_source_contract(invalid_safe_lane)
	_check(_errors_have_fragment(invalid_lane_errors, "safe lane must be an integer within movement lane count"), "A source safe_lane outside lane_count must reject before compilation")
	_check(invalid_lane_errors == Runtime.validate_source_contract(invalid_safe_lane), "Invalid source safe-lane topology must return a deterministic error list")
	var rejected_safe_lane := Runtime.compile_contract(invalid_safe_lane)
	_check(not bool(rejected_safe_lane.get("valid", true)) and _has_error_fragment(rejected_safe_lane, "safe lane must be an integer within movement lane count"), "Compilation must fail closed instead of wrapping an invalid source safe_lane")

	var lower_boundary_contract := _safe_lane_contract(contract, 0)
	_check(Runtime.validate_source_contract(lower_boundary_contract).is_empty(), "safe_lane 0 must pass for lane_count 3")
	var lower_boundary_plan := Runtime.compile_contract(lower_boundary_contract)
	_check(bool(lower_boundary_plan.get("valid", false)), "safe_lane 0 must compile for lane_count 3")
	var upper_boundary_contract := _safe_lane_contract(contract, 2)
	_check(Runtime.validate_source_contract(upper_boundary_contract).is_empty(), "safe_lane 2 must pass for lane_count 3")
	_check(bool(Runtime.compile_contract(upper_boundary_contract).get("valid", false)), "safe_lane 2 must compile for lane_count 3")

	var compiled_lane_tamper := lower_boundary_plan.duplicate(true)
	var compiled_lane_event := (compiled_lane_tamper.events as Array)[0] as Dictionary
	(compiled_lane_event.safe as Dictionary).lane = 8
	_resign_plan(compiled_lane_tamper)
	_check(_errors_have_fragment(Runtime.validate_plan(compiled_lane_tamper), "safe lane must be an integer within compiled movement lane count"), "Independent plan validation must reject a re-signed safe_lane outside its compiled lane_count")

	var lane_movement_plan := Runtime.compile_contract(_contract_with_spawn(rooms, "membrane_gate", 991402))
	_check(bool(lane_movement_plan.get("valid", false)), "Compiled movement-lane tamper fixture must compile")
	if bool(lane_movement_plan.get("valid", false)):
		var movement_lane_tamper := lane_movement_plan.duplicate(true)
		var movement_lane_event := (movement_lane_tamper.events as Array)[0] as Dictionary
		(movement_lane_event.movement as Dictionary).lane = 8
		_synchronize_event_operation_plans(movement_lane_event)
		_resign_plan(movement_lane_tamper)
		_check(_errors_have_fragment(Runtime.validate_plan(movement_lane_tamper), "Lane movement lane must be an integer within movement lane count"), "Independent plan validation must reject a re-signed movement.lane outside movement.lane_count while safe.lane remains legal")

	for source_container in ["timing", "spawn", "projectile", "movement"]:
		var malformed_source := contract.duplicate(true)
		malformed_source[source_container] = []
		var malformed_source_errors := Runtime.validate_source_contract(malformed_source)
		_check(not malformed_source_errors.is_empty(), "Wrong-type source %s container must reject without a script error" % source_container)
		_check(not bool(Runtime.compile_contract(malformed_source).get("valid", true)), "Wrong-type source %s container must fail compilation closed" % source_container)
	var malformed_source_event := contract.duplicate(true)
	(malformed_source_event.events as Array)[0].safe_position = {}
	_check(not Runtime.validate_source_contract(malformed_source_event).is_empty(), "Wrong-type source event position must reject without a script error")
	var malformed_source_events := contract.duplicate(true)
	malformed_source_events.events = {}
	_check(not Runtime.validate_source_contract(malformed_source_events).is_empty(), "Wrong-type source events container must reject without a script error")
	var malformed_source_path := contract.duplicate(true)
	var untyped_source_path: Array = []
	for raw_waypoint in malformed_source_path.safe_path as Array:
		untyped_source_path.append(raw_waypoint)
	untyped_source_path[0] = []
	malformed_source_path.safe_path = untyped_source_path
	_check(not Runtime.validate_source_contract(malformed_source_path).is_empty(), "Wrong-type source safe-path waypoint must reject without a script error")

	var wrong_plan_source := base.duplicate(true)
	wrong_plan_source.source = []
	_check(not Runtime.validate_plan(wrong_plan_source).is_empty(), "Wrong-type plan source container must reject without a script error")
	var wrong_plan_timing := base.duplicate(true)
	wrong_plan_timing.timing = []
	_check(not Runtime.validate_plan(wrong_plan_timing).is_empty(), "Wrong-type plan timing container must reject without a script error")
	var wrong_plan_path := base.duplicate(true)
	var untyped_plan_path: Array = []
	for raw_waypoint in wrong_plan_path.safe_path as Array:
		untyped_plan_path.append(raw_waypoint)
	untyped_plan_path[0] = []
	wrong_plan_path.safe_path = untyped_plan_path
	_check(not Runtime.validate_plan(wrong_plan_path).is_empty(), "Wrong-type plan safe-path waypoint must reject without a script error")
	var wrong_plan_events := base.duplicate(true)
	wrong_plan_events.events = {}
	_check(not Runtime.validate_plan(wrong_plan_events).is_empty(), "Wrong-type plan events container must reject without a script error")
	var wrong_plan_event_entry := base.duplicate(true)
	var untyped_plan_events: Array = []
	for raw_event in wrong_plan_event_entry.events as Array:
		untyped_plan_events.append(raw_event)
	untyped_plan_events[0] = []
	wrong_plan_event_entry.events = untyped_plan_events
	_check(not Runtime.validate_plan(wrong_plan_event_entry).is_empty(), "Wrong-type plan event entry must reject without a script error")
	for event_container in ["spawn", "projectile", "movement", "safe", "telegraph"]:
		var malformed_plan := base.duplicate(true)
		((malformed_plan.events as Array)[0] as Dictionary)[event_container] = []
		_check(not Runtime.validate_plan(malformed_plan).is_empty(), "Wrong-type event %s container must reject without a script error" % event_container)
	var wrong_operations := base.duplicate(true)
	((wrong_operations.events as Array)[0] as Dictionary).operations = {}
	_check(not Runtime.validate_plan(wrong_operations).is_empty(), "Wrong-type operations container must reject without a script error")
	var wrong_operation_entry := base.duplicate(true)
	var untyped_operations: Array = []
	for raw_operation in ((wrong_operation_entry.events as Array)[0] as Dictionary).operations as Array:
		untyped_operations.append(raw_operation)
	untyped_operations[0] = []
	((wrong_operation_entry.events as Array)[0] as Dictionary).operations = untyped_operations
	_check(not Runtime.validate_plan(wrong_operation_entry).is_empty(), "Wrong-type operation entry must reject without a script error")
	var wrong_operation_plan := base.duplicate(true)
	((((wrong_operation_plan.events as Array)[0] as Dictionary).operations as Array)[0] as Dictionary).plan = []
	_check(not Runtime.validate_plan(wrong_operation_plan).is_empty(), "Wrong-type operation plan must reject without a script error")
	var wrong_positions := base.duplicate(true)
	(((wrong_positions.events as Array)[0] as Dictionary).spawn as Dictionary).positions = {}
	_check(not Runtime.validate_plan(wrong_positions).is_empty(), "Wrong-type spawn positions must reject without a script error")
	var wrong_position_entry := base.duplicate(true)
	var untyped_positions: Array = []
	for raw_position in (((wrong_position_entry.events as Array)[0] as Dictionary).spawn as Dictionary).positions as Array:
		untyped_positions.append(raw_position)
	untyped_positions[0] = []
	(((wrong_position_entry.events as Array)[0] as Dictionary).spawn as Dictionary).positions = untyped_positions
	_check(not Runtime.validate_plan(wrong_position_entry).is_empty(), "Wrong-type spawn position entry must reject without a script error")
	var wrong_collision := base.duplicate(true)
	(((wrong_collision.events as Array)[0] as Dictionary).spawn as Dictionary).collision = []
	_check(not Runtime.validate_plan(wrong_collision).is_empty(), "Wrong-type collision container must reject without a script error")
	var wrong_safe_position := base.duplicate(true)
	(((wrong_safe_position.events as Array)[0] as Dictionary).safe as Dictionary).position = {}
	_check(not Runtime.validate_plan(wrong_safe_position).is_empty(), "Wrong-type event safe position must reject without a script error")

	for profile_tamper in ["spawn", "projectile", "movement"]:
		var remapped := base.duplicate(true)
		var remapped_event := (remapped.events as Array)[0] as Dictionary
		match profile_tamper:
			"spawn": (remapped_event.spawn as Dictionary).primitive = "gravity_field"
			"projectile":
				(remapped_event.projectile as Dictionary).travel_model = "soft_homing"
				(remapped_event.projectile as Dictionary).tracking_strength = 1.0
			"movement": (remapped_event.movement as Dictionary).primitive = "orbit_arc"
		_synchronize_event_operation_plans(remapped_event)
		_resign_plan(remapped)
		_check(_errors_have_fragment(Runtime.validate_plan(remapped), "canonical registry profile"), "Re-signed %s profile remap must fail canonical validation" % profile_tamper)
	var defender_contract := _contract_with_spawn(rooms, "egg_hatch", 991402)
	var defender_plan := Runtime.compile_contract(defender_contract)
	_check(bool(defender_plan.get("valid", false)), "Canonical defender-profile fixture must compile")
	if bool(defender_plan.get("valid", false)):
		var defender_remap := defender_plan.duplicate(true)
		var defender_event := (defender_remap.events as Array)[0] as Dictionary
		(defender_event.spawn as Dictionary).defender_behavior = Runtime.DEFENDER_ARCHETYPES["armor_drone"].duplicate(true)
		_synchronize_event_operation_plans(defender_event)
		_resign_plan(defender_remap)
		_check(_errors_have_fragment(Runtime.validate_plan(defender_remap), "canonical registry profile"), "Re-signed defender behavior remap must fail canonical validation")

	var executor_floor_contract := contract.duplicate(true)
	executor_floor_contract.projectile.speed_pixels_per_second = Runtime.MIN_PROJECTILE_SPEED_PIXELS_PER_SECOND
	executor_floor_contract.projectile.radius_pixels = Runtime.MIN_PROJECTILE_RADIUS_PIXELS
	executor_floor_contract.projectile.damage = Runtime.MIN_PROJECTILE_DAMAGE
	_check(bool(Runtime.compile_contract(executor_floor_contract).get("valid", false)), "Exact RunScene projectile scalar floors must remain valid")
	for floor_field in ["speed_pixels_per_second", "radius_pixels", "damage"]:
		var below_floor_source := executor_floor_contract.duplicate(true)
		below_floor_source.projectile[floor_field] = float(below_floor_source.projectile[floor_field]) - 0.001
		_check(not bool(Runtime.compile_contract(below_floor_source).get("valid", true)), "Source projectile %s below the executor floor must fail closed" % floor_field)
		var below_floor_plan := base.duplicate(true)
		var below_floor_event := (below_floor_plan.events as Array)[0] as Dictionary
		(below_floor_event.projectile as Dictionary)[floor_field] = float(executor_floor_contract.projectile[floor_field]) - 0.001
		_synchronize_event_operation_plans(below_floor_event)
		_resign_plan(below_floor_plan)
		_check(not Runtime.validate_plan(below_floor_plan).is_empty(), "Re-signed projectile %s below the executor floor must fail" % floor_field)
	var projectile_cap_tamper := base.duplicate(true)
	var projectile_cap_event := (projectile_cap_tamper.events as Array)[0] as Dictionary
	(projectile_cap_event.projectile as Dictionary).max_active = maxi(0, int((projectile_cap_event.projectile as Dictionary).count) - 1)
	_synchronize_event_operation_plans(projectile_cap_event)
	_resign_plan(projectile_cap_tamper)
	_check(_errors_have_fragment(Runtime.validate_plan(projectile_cap_tamper), "active cap is below"), "Re-signed projectile cap below executable count must fail")
	var hazard_count_tamper := base.duplicate(true)
	var hazard_count_event := (hazard_count_tamper.events as Array)[0] as Dictionary
	(hazard_count_event.spawn as Dictionary).hazard_count = maxi(0, int((hazard_count_event.spawn as Dictionary).hazard_count) - 1)
	_synchronize_event_operation_plans(hazard_count_event)
	_resign_plan(hazard_count_tamper)
	_check(_errors_have_fragment(Runtime.validate_plan(hazard_count_tamper), "positions are missing or unbounded"), "Re-signed hazard count below executed positions must fail")
	if bool(defender_plan.get("valid", false)):
		var defender_cap_tamper := defender_plan.duplicate(true)
		var defender_cap_event := (defender_cap_tamper.events as Array)[0] as Dictionary
		(defender_cap_event.spawn as Dictionary).max_active_enemies = maxi(0, int((defender_cap_event.spawn as Dictionary).enemy_count) - 1)
		_synchronize_event_operation_plans(defender_cap_event)
		_resign_plan(defender_cap_tamper)
		_check(not Runtime.validate_plan(defender_cap_tamper).is_empty(), "Re-signed defender cap below executable count must fail")
	var structural_contract := _contract_with_projectile(rooms, "none_structural", 991403)
	var structural_plan := Runtime.compile_contract(structural_contract)
	_check(bool(structural_plan.get("valid", false)) and int((((structural_plan.events as Array)[0] as Dictionary).projectile as Dictionary).count) == 0 and int((((structural_plan.events as Array)[0] as Dictionary).projectile as Dictionary).max_active) == 0, "Structural-only projectile zero state must remain valid")

	var timing_source_tamper := contract.duplicate(true)
	timing_source_tamper.timing.telegraph_seconds = float(timing_source_tamper.timing.telegraph_seconds) + 0.01
	var rejected_timing_source := Runtime.compile_contract(timing_source_tamper)
	_check(not bool(rejected_timing_source.get("valid", true)) and _has_error_fragment(rejected_timing_source, "telegraph window diverges"), "Source timing used by RunScene must not diverge from signed event telegraphs")

	var timing_plan_tamper := base.duplicate(true)
	(timing_plan_tamper.timing as Dictionary).telegraph_seconds = float((timing_plan_tamper.timing as Dictionary).telegraph_seconds) + 0.01
	_check(String(base.plan_signature) != Runtime.plan_signature_for_plan(timing_plan_tamper), "Canonical plan signature must bind the live timing payload")
	_resign_plan(timing_plan_tamper)
	_check(_errors_have_fragment(Runtime.validate_plan(timing_plan_tamper), "canonical plan timing payload"), "Re-signed timing/event divergence must fail semantic plan validation")

	for malformed_case in ["nan_cadence", "infinite_speed", "huge_radius", "huge_damage", "infinite_rotation", "nan_clearance", "nan_projectile_count"]:
		var malformed := contract.duplicate(true)
		match malformed_case:
			"nan_cadence":
				malformed.timing.cadence = NAN
				malformed.spawn.cadence = NAN
			"infinite_speed": malformed.projectile.speed_pixels_per_second = INF
			"huge_radius": malformed.projectile.radius_pixels = Runtime.MAX_PROJECTILE_RADIUS_PIXELS + 1.0
			"huge_damage": malformed.projectile.damage = Runtime.MAX_PROJECTILE_DAMAGE + 1.0
			"infinite_rotation": malformed.movement.rotation_rate = INF
			"nan_clearance": malformed.safe_clearance_normalized = NAN
			"nan_projectile_count": malformed.projectile.count = NAN
		var rejected := Runtime.compile_contract(malformed)
		_check(not bool(rejected.get("valid", true)) and not (rejected.get("errors", []) as Array).is_empty(), "%s executable scalar must fail closed before signing" % malformed_case)

	var resigned_huge_damage := base.duplicate(true)
	var damage_event := (resigned_huge_damage.events as Array)[0] as Dictionary
	(damage_event.projectile as Dictionary).damage = Runtime.MAX_PROJECTILE_DAMAGE + 1.0
	((damage_event.operations as Array)[3] as Dictionary).plan = (damage_event.projectile as Dictionary).duplicate(true)
	_resign_plan(resigned_huge_damage)
	_check(_errors_have_fragment(Runtime.validate_plan(resigned_huge_damage), "damage must be finite and bounded"), "A re-signed huge projectile damage must fail semantic plan validation")

	var fractional_count := base.duplicate(true)
	var fractional_event := (fractional_count.events as Array)[0] as Dictionary
	(fractional_event.spawn as Dictionary).hazard_count = 1.5
	((fractional_event.operations as Array)[2] as Dictionary).plan = (fractional_event.spawn as Dictionary).duplicate(true)
	_resign_plan(fractional_count)
	_check(_errors_have_fragment(Runtime.validate_plan(fractional_count), "hazard count exceeds"), "A re-signed fractional actor count must fail semantic plan validation")

	var unbounded_positions := base.duplicate(true)
	var unbounded_positions_event := (unbounded_positions.events as Array)[0] as Dictionary
	var oversized_positions := (unbounded_positions_event.spawn as Dictionary).positions as Array
	while oversized_positions.size() <= Runtime.MAX_HAZARDS_PER_EVENT:
		oversized_positions.append((oversized_positions[0] as Dictionary).duplicate(true))
	(unbounded_positions_event.telegraph as Dictionary).positions = oversized_positions.duplicate(true)
	_synchronize_event_operation_plans(unbounded_positions_event)
	_resign_plan(unbounded_positions)
	_check(_errors_have_fragment(Runtime.validate_plan(unbounded_positions), "positions are missing or unbounded"), "A re-signed oversized spawn-position array must fail semantic plan validation")

	var missing_collision_radius := base.duplicate(true)
	var missing_radius_event := (missing_collision_radius.events as Array)[0] as Dictionary
	((missing_radius_event.spawn as Dictionary).collision as Dictionary).erase("radius_normalized")
	_synchronize_event_operation_plans(missing_radius_event)
	_resign_plan(missing_collision_radius)
	_check(_errors_have_fragment(Runtime.validate_plan(missing_collision_radius), "Collision radius"), "A re-signed collision missing its authored radius must fail semantic plan validation")

	var invalid_axis := base.duplicate(true)
	var invalid_axis_event := (invalid_axis.events as Array)[0] as Dictionary
	(invalid_axis_event.movement as Dictionary).axis = "diagonal"
	_synchronize_event_operation_plans(invalid_axis_event)
	_resign_plan(invalid_axis)
	_check(_errors_have_fragment(Runtime.validate_plan(invalid_axis), "axis is unsupported"), "A re-signed movement axis outside the executor vocabulary must fail semantic plan validation")

	var duplicate_index := contract.duplicate(true)
	duplicate_index.events[1].index = int(duplicate_index.events[0].index)
	duplicate_index.events[1].event_seed = int(duplicate_index.events[0].event_seed)
	var rejected_duplicate := Runtime.compile_contract(duplicate_index)
	_check(not bool(rejected_duplicate.get("valid", true)) and _has_error_fragment(rejected_duplicate, "duplicate event index"), "Duplicate source index/owner identity must fail closed")

	var duplicate_owner := base.duplicate(true)
	var first_owner_event := (duplicate_owner.events as Array)[0] as Dictionary
	var second_owner_event := (duplicate_owner.events as Array)[1] as Dictionary
	var duplicated_owner_id := String(first_owner_event.owner_wave_id)
	second_owner_event.wave_key = duplicated_owner_id
	second_owner_event.owner_wave_id = duplicated_owner_id
	(second_owner_event.spawn as Dictionary).wave_key = duplicated_owner_id
	(second_owner_event.spawn as Dictionary).owner_wave_id = duplicated_owner_id
	(second_owner_event.projectile as Dictionary).parent_wave_key = duplicated_owner_id
	(second_owner_event.projectile as Dictionary).owner_wave_id = duplicated_owner_id
	(second_owner_event.movement as Dictionary).owner_wave_id = duplicated_owner_id
	(second_owner_event.telegraph as Dictionary).owner_wave_id = duplicated_owner_id
	for raw_operation in second_owner_event.operations as Array:
		(raw_operation as Dictionary).owner_wave_id = duplicated_owner_id
	_synchronize_event_operation_plans(second_owner_event)
	_resign_plan(duplicate_owner)
	_check(not Runtime.validate_plan(duplicate_owner).is_empty(), "Re-signed duplicate wave ownership must fail semantic plan validation")

	var overlapping := contract.duplicate(true)
	var prior_event := (overlapping.events as Array)[0] as Dictionary
	var overlap_event := (overlapping.events as Array)[1] as Dictionary
	overlap_event.telegraph_at = float(prior_event.clear_at) + Runtime.MIN_EVENT_GAP_SECONDS * 0.5
	overlap_event.active_at = float(overlap_event.telegraph_at) + float((overlapping.timing as Dictionary).telegraph_seconds)
	overlap_event.clear_at = float(overlap_event.active_at) + float((overlapping.timing as Dictionary).active_seconds)
	var rejected_overlap := Runtime.compile_contract(overlapping)
	_check(not bool(rejected_overlap.get("valid", true)) and _has_error_fragment(rejected_overlap, "overlaps the prior event"), "Overlapping event schedule must fail closed")

	var out_of_duration := contract.duplicate(true)
	(out_of_duration.events as Array)[-1].clear_at = float(out_of_duration.duration) + 0.01
	var rejected_out_of_duration := Runtime.compile_contract(out_of_duration)
	_check(not bool(rejected_out_of_duration.get("valid", true)) and _has_error_fragment(rejected_out_of_duration, "within room duration"), "Event cleanup after room duration must fail closed")

	var too_short := contract.duplicate(true)
	too_short.timing.active_seconds = Runtime.MIN_ACTIVE_WINDOW_SECONDS - 0.01
	for raw_event in too_short.events as Array:
		(raw_event as Dictionary).clear_at = float((raw_event as Dictionary).active_at) + float(too_short.timing.active_seconds)
	var rejected_short := Runtime.compile_contract(too_short)
	_check(not bool(rejected_short.get("valid", true)) and _has_error_fragment(rejected_short, "active duration must be finite and bounded"), "Too-short active/threat window must fail closed")
	for raw_event in base.events as Array:
		var event := raw_event as Dictionary
		var projectile := event.projectile as Dictionary
		if int(projectile.count) > 0:
			_check(float(projectile.threat_time_seconds) <= float(event.clear_at) - float(event.active_at) - Runtime.EMISSION_BOUNDARY_GUARD_SECONDS + 0.000001, "Every compiled threat time must remain inside its active boundary")

	var actor_free_event := ((base.events as Array)[0] as Dictionary).duplicate(true)
	var original_lifecycle := Runtime.lifecycle_signature_for_event(actor_free_event)
	var actor_free_spawn_operation := (actor_free_event.operations as Array)[2] as Dictionary
	actor_free_spawn_operation.blocks_room_exit = true
	actor_free_spawn_operation.blocks_next_event = true
	_check(original_lifecycle != Runtime.lifecycle_signature_for_event(actor_free_event), "Lifecycle digest must encode room-exit and next-event booleans independently")
	var actor_free_tamper := base.duplicate(true)
	var actor_free_plan_event := (actor_free_tamper.events as Array)[0] as Dictionary
	var actor_free_plan_spawn_operation := (actor_free_plan_event.operations as Array)[2] as Dictionary
	actor_free_plan_spawn_operation.blocks_room_exit = true
	actor_free_plan_spawn_operation.blocks_next_event = true
	_resign_plan(actor_free_tamper)
	_check(_errors_have_fragment(Runtime.validate_plan(actor_free_tamper), "blocking flags"), "Re-signed actor-free blocking flags must fail semantic plan validation")


func _synchronize_event_operation_plans(event: Dictionary) -> void:
	var operations := event.operations as Array
	(operations[0] as Dictionary).plan = (event.telegraph as Dictionary).duplicate(true)
	(operations[1] as Dictionary).plan = (event.movement as Dictionary).duplicate(true)
	(operations[2] as Dictionary).plan = (event.spawn as Dictionary).duplicate(true)
	if String((operations[3] as Dictionary).op) == "emit_projectiles":
		(operations[3] as Dictionary).plan = (event.projectile as Dictionary).duplicate(true)
	else:
		(operations[3] as Dictionary).collision = (event.spawn as Dictionary).collision.duplicate(true)
		(operations[3] as Dictionary).positions = (event.spawn as Dictionary).positions.duplicate(true)


func _resign_plan(plan: Dictionary) -> void:
	for raw_event in plan.events as Array:
		var event := raw_event as Dictionary
		event.geometry_signature = Runtime.geometry_signature_for_event(event)
		event.lifecycle_signature = Runtime.lifecycle_signature_for_event(event)
	plan.geometry_signature = Runtime.geometry_signature_for_plan(plan)
	plan.lifecycle_signature = Runtime.lifecycle_signature_for_plan(plan)
	plan.plan_signature = Runtime.plan_signature_for_plan(plan)


func _has_error_fragment(result: Dictionary, fragment: String) -> bool:
	return _errors_have_fragment(result.get("errors", []), fragment)


func _errors_have_fragment(errors: Variant, fragment: String) -> bool:
	if typeof(errors) != TYPE_ARRAY and typeof(errors) != TYPE_PACKED_STRING_ARRAY:
		return false
	for error in errors:
		if fragment in String(error):
			return true
	return false


func _test_declared_values_change_behavior(rooms: Array) -> void:
	var lane_contract := Mechanics.build_contract(rooms[0] as Dictionary, 4477)
	var lane_plan := Runtime.compile_contract(lane_contract)
	var alternate_spawn := lane_contract.duplicate(true)
	alternate_spawn.spawn.pattern = "paired_vessels"
	var alternate_spawn_plan := Runtime.compile_contract(alternate_spawn)
	_check(String(lane_plan.visual_signature) != String(alternate_spawn_plan.visual_signature), "Changing spawn.pattern must change visual execution identity")
	_check(String(((lane_plan.events as Array)[0] as Dictionary).spawn.primitive) != String(((alternate_spawn_plan.events as Array)[0] as Dictionary).spawn.primitive), "Changing spawn.pattern must select a different spatial primitive")

	var projectile_contract := _contract_with_projectile(rooms, "falling_cells", 5599)
	var projectile_plan := Runtime.compile_contract(projectile_contract)
	var alternate_projectile := projectile_contract.duplicate(true)
	alternate_projectile.projectile.pattern = "node_arc"
	var alternate_projectile_plan := Runtime.compile_contract(alternate_projectile)
	_check(String(((projectile_plan.events as Array)[0] as Dictionary).projectile.primitive) != String(((alternate_projectile_plan.events as Array)[0] as Dictionary).projectile.primitive), "Changing projectile.pattern must change emitted geometry")
	_check(String(projectile_plan.visual_signature) != String(alternate_projectile_plan.visual_signature), "Changing projectile.pattern must change its draw signature")

	var alternate_movement := lane_contract.duplicate(true)
	alternate_movement.movement.model = "ring"
	var alternate_movement_plan := Runtime.compile_contract(alternate_movement)
	_check(String(((lane_plan.events as Array)[0] as Dictionary).movement.primitive) != String(((alternate_movement_plan.events as Array)[0] as Dictionary).movement.primitive), "Changing movement.model must change the motion controller")
	_check((alternate_movement_plan.events as Array)[0].movement.has("angular_rate"), "Ring movement must compile explicit orbit parameters")


func _test_geometry_taxonomy(rooms: Array) -> void:
	var base := Mechanics.build_contract(rooms[0] as Dictionary, 77331)
	var primitive_geometry: Dictionary = {}
	var geometry_values: Dictionary = {}
	for pattern in Runtime.supported_spawn_patterns():
		var behavior := Runtime.SPAWN_BEHAVIORS[String(pattern)] as Dictionary
		var primitive := String(behavior.primitive)
		if primitive_geometry.has(primitive):
			continue
		var synthetic := base.duplicate(true)
		synthetic.spawn.pattern = String(pattern)
		var plan := Runtime.compile_contract(synthetic)
		_check(bool(plan.get("valid", false)), "%s primitive representative must compile" % primitive)
		if not bool(plan.get("valid", false)):
			continue
		var signature := String(((plan.events as Array)[0] as Dictionary).geometry_signature)
		primitive_geometry[primitive] = signature
		geometry_values[signature] = true
	_check(primitive_geometry.size() >= 8, "Catalog must resolve to at least eight spawn primitives")
	_check(geometry_values.size() >= 8, "At least eight primitives must produce distinct label-free geometry/motion/topology signatures")


func _test_caps_and_fail_closed(rooms: Array) -> void:
	var defender_contract := _contract_with_spawn(rooms, "egg_hatch", 6633)
	var overloaded := defender_contract.duplicate(true)
	overloaded.spawn.burst_count = 999
	overloaded.spawn.max_active = 999
	overloaded.projectile.count = 999
	for event in overloaded.events as Array:
		(event as Dictionary).spawn_count = 999
	overloaded.duration = Runtime.MAX_ROOM_DURATION_SECONDS
	while (overloaded.events as Array).size() < Runtime.MAX_EVENTS:
		var duplicate := ((overloaded.events as Array)[-1] as Dictionary).duplicate(true)
		duplicate.index = (overloaded.events as Array).size()
		duplicate.active_at = float(((overloaded.events as Array)[-1] as Dictionary).active_at) + float((overloaded.timing as Dictionary).cadence)
		duplicate.telegraph_at = float(duplicate.active_at) - float((overloaded.timing as Dictionary).telegraph_seconds)
		duplicate.clear_at = float(duplicate.active_at) + float((overloaded.timing as Dictionary).active_seconds)
		(overloaded.events as Array).append(duplicate)
	var capped := Runtime.compile_contract(overloaded)
	_check(bool(capped.get("valid", false)), "Oversubscribed positive contracts must compile through hard caps")
	_check((capped.events as Array).size() == Runtime.MAX_EVENTS, "An event schedule at the runtime cap must compile in full")
	for raw_event in capped.events as Array:
		var event := raw_event as Dictionary
		_check(int((event.spawn as Dictionary).enemy_count) == Runtime.MAX_ENEMIES_PER_EVENT, "Enemy burst must clamp to the per-event cap")
		_check(int((event.spawn as Dictionary).max_active_enemies) == Runtime.MAX_ACTIVE_ENEMIES, "Active enemies must clamp to the global cap")
		_check(int((event.projectile as Dictionary).count) == Runtime.MAX_PROJECTILES_PER_EVENT, "Projectile burst must clamp to the per-event cap")
		_check(int((event.projectile as Dictionary).max_active) == Runtime.MAX_ACTIVE_PROJECTILES, "Active projectiles must clamp to the global cap")

	var source_overflow := overloaded.duplicate(true)
	var overflow_event := ((source_overflow.events as Array)[-1] as Dictionary).duplicate(true)
	overflow_event.index = Runtime.MAX_EVENTS
	overflow_event.active_at = float(overflow_event.active_at) + float((source_overflow.timing as Dictionary).cadence)
	overflow_event.telegraph_at = float(overflow_event.active_at) - float((source_overflow.timing as Dictionary).telegraph_seconds)
	overflow_event.clear_at = float(overflow_event.active_at) + float((source_overflow.timing as Dictionary).active_seconds)
	(source_overflow.events as Array).append(overflow_event)
	_check(_errors_have_fragment(Runtime.validate_source_contract(source_overflow), "event count exceeds"), "A 65-event source contract must fail validation instead of truncating")
	var rejected_source_overflow := Runtime.compile_contract(source_overflow)
	_check(not bool(rejected_source_overflow.get("valid", true)) and _has_error_fragment(rejected_source_overflow, "event count exceeds"), "Compilation must fail closed for a 65-event source contract")

	var resigned_plan_overflow := capped.duplicate(true)
	(resigned_plan_overflow.events as Array).append(((resigned_plan_overflow.events as Array)[-1] as Dictionary).duplicate(true))
	_resign_plan(resigned_plan_overflow)
	_check(_errors_have_fragment(Runtime.validate_plan(resigned_plan_overflow), "event count is empty or unbounded"), "A re-signed 65-event plan tamper must fail before iteration")

	for field in ["spawn", "projectile", "movement"]:
		var malformed := defender_contract.duplicate(true)
		match field:
			"spawn": malformed.spawn.pattern = "unknown_spawn"
			"projectile": malformed.projectile.pattern = "unknown_projectile"
			"movement": malformed.movement.model = "unknown_motion"
		var rejected := Runtime.compile_contract(malformed)
		_check(not bool(rejected.get("valid", true)) and "Unmapped" in String((rejected.errors as Array)[0]), "Unknown %s catalog value must fail closed" % field)
	var mismatch := defender_contract.duplicate(true)
	mismatch.projectile.enabled = false
	_check(not bool(Runtime.compile_contract(mismatch).get("valid", true)), "Disabled non-structural projectile aliases must fail closed")
	var bad_timing := defender_contract.duplicate(true)
	bad_timing.events[0].active_at = bad_timing.events[0].telegraph_at
	_check(not bool(Runtime.compile_contract(bad_timing).get("valid", true)), "Execution plans must reject compressed telegraph timing")


func _contract_with_projectile(rooms: Array, projectile_pattern: String, seed: int) -> Dictionary:
	for room in rooms:
		var contract := Mechanics.build_contract(room as Dictionary, seed)
		if String((contract.projectile as Dictionary).pattern) == projectile_pattern:
			return contract
	return {}


func _safe_lane_contract(contract: Dictionary, safe_lane: int) -> Dictionary:
	var result := contract.duplicate(true)
	var event := (result.events as Array)[0] as Dictionary
	event.safe_lane = safe_lane
	var hazard_lanes: Array[int] = []
	for lane in range(int((result.movement as Dictionary).lane_count)):
		if lane != safe_lane:
			hazard_lanes.append(lane)
	event.hazard_lanes = hazard_lanes
	var safe_position := (event.safe_position as Array).duplicate()
	safe_position[0] = 0.125 + (float(safe_lane) + 0.5) * (0.75 / float((result.movement as Dictionary).lane_count))
	event.safe_position = safe_position
	return result


func _contract_with_spawn(rooms: Array, spawn_pattern: String, seed: int) -> Dictionary:
	for room in rooms:
		var contract := Mechanics.build_contract(room as Dictionary, seed)
		if String((contract.spawn as Dictionary).pattern) == spawn_pattern:
			return contract
	return {}


func _same_keys(values: Dictionary, supported: PackedStringArray) -> bool:
	if values.size() != supported.size():
		return false
	for key in supported:
		if not values.has(key):
			return false
	return true


func _operation_names(operations: Array) -> Array[String]:
	var names: Array[String] = []
	for raw_operation in operations:
		names.append(String((raw_operation as Dictionary).get("op", "")))
	return names


func _inside(position: Array) -> bool:
	return position.size() == 2 and float(position[0]) >= 0.04 and float(position[0]) <= 0.96 and float(position[1]) >= 0.04 and float(position[1]) <= 0.96


func _distance(a: Array, b: Array) -> float:
	var dx := float(a[0]) - float(b[0])
	var dy := float(a[1]) - float(b[1])
	return sqrt(dx * dx + dy * dy)
