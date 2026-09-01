extends Node

const Mechanics := preload("res://scripts/core/room_mechanics.gd")
const Runtime := preload("res://scripts/core/room_pattern_runtime.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")

const FRAME_RATES := [30, 60]
const PROBE_SEED_SALTS := [0, 0x2A91]
const EXPECTED_CATEGORIES := ["echo", "field", "gate", "node", "radial", "rain", "spawn", "sweep"]
const PROJECTILE_TRAVEL_MODELS := ["linear","delayed_linear","soft_homing","expanding","node_link","lunge","recorded_path"]

const CATEGORY_BY_HAZARD := {
	"closing_membranes": "gate",
	"vein_walls": "gate",
	"rotating_ribs": "radial",
	"light_gates": "gate",
	"lateral_current": "field",
	"false_lane": "gate",
	"falling_cells": "rain",
	"pulse_gate": "sweep",
	"orbiting_defenders": "spawn",
	"pincer_spawn": "spawn",
	"bone_drones": "spawn",
	"tracking_mites": "echo",
	"refracting_defenders": "spawn",
	"sound_cones": "sweep",
	"chain_defenders": "node",
	"brood_wave": "spawn",
	"delayed_clone_fire": "echo",
	"decoy_bursts": "spawn",
	"pressure_burst": "gate",
	"falling_acid": "rain",
	"closing_bone_press": "gate",
	"inhale_exhale": "field",
	"beam_grid": "gate",
	"turbine_sweep": "radial",
	"rotating_wells": "field",
	"node_arcs": "node",
	"path_replay": "echo",
	"mirrored_walls": "gate",
	"cell_bloom": "radial",
	"artery_sweep": "sweep",
	"tracking_gaze": "sweep",
	"suction_cycle": "field",
	"bone_press": "gate",
	"refracted_grid": "gate",
	"turbine_lanes": "radial",
	"resonance_pulses": "radial",
	"suction_wells": "field",
	"chain_arcs": "node",
	"egg_hatches": "spawn",
	"attack_replay": "echo",
	"delayed_path": "echo",
	"mirrored_quadrants": "gate",
}

const CATEGORY_REPRESENTATIVE := {
	"gate": "closing_membranes",
	"rain": "falling_cells",
	"radial": "rotating_ribs",
	"sweep": "pulse_gate",
	"field": "lateral_current",
	"node": "node_arcs",
	"spawn": "orbiting_defenders",
	"echo": "path_replay",
}

const MOVEMENT_REPRESENTATIVE := {
	"lane": "closing_membranes",
	"ring": "rotating_ribs",
	"sweep": "pulse_gate",
	"anchor": "lateral_current",
	"pocket": "falling_cells",
	"replay": "path_replay",
}

class MalformedPreviewPool extends ProjectilePool:
	func preview_enemy_travel(_origin: Vector2, _velocity: Vector2, _options: Dictionary = {}) -> Array[Dictionary]:
		return [{"age":0.0,"position":Vector2(NAN,0.0),"radius":7.0}]

var passed := 0
var failures: Array[String] = []
var damage_causes: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("ROOM RUNTIME INTEGRATION FAILURE: " + message)


func _run() -> void:
	var rooms := _read_rooms()
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run := RunSceneClass.new()
	run.initialize({
		"boss": "gravemaw",
		"weapon": "pulse_needle",
		"difficulty": "deep",
		"seed": 84191,
		"mode": "story",
		"competitive": false,
	})
	add_child(run)
	run.set_process(false)
	run.set_physics_process(false)
	run._player.set_physics_process(false)
	run._player.set_process_unhandled_input(false)
	run._player.damaged.connect(_record_damage)

	_test_live_trace_coverage(run, rooms)
	_test_safe_and_unsafe_probes(run, rooms)
	_test_defender_lifecycle(run, rooms)
	_test_chamber_last_defender_duration_boundary(run, rooms)
	_test_movement_outputs(run, rooms)
	_test_movement_zero_origin_and_first_tick(run, rooms)
	_test_hitch_delta_swept_clearance(run)
	_test_impossible_structural_geometry_fails_closed(run, rooms)
	_test_execution_context_integrity(run, rooms)
	_test_projectile_preview_runtime_parity(run)
	_test_projectile_preview_rejection(run, rooms)
	_test_post_activation_preview_effect_monotonicity(run)
	_test_pending_emission_integrity(run, rooms)
	_test_runtime_owner_identity(run, rooms)
	_test_rejection_latch(run, rooms)
	_test_replay_input_dependency(run, rooms)
	_test_atomic_cleanup(run, rooms)

	run.projectiles_clear_and_enemies()
	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	print("INFINIDIVE ROOM RUNTIME INTEGRATION TESTS: %d passed, %d failed" % [passed, failures.size()])
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
	var rooms := parsed as Array if typeof(parsed) == TYPE_ARRAY else []
	_check(rooms.size() == 42, "Runtime integration suite requires all 42 launch rooms")
	return rooms


func _test_live_trace_coverage(run: Node, rooms: Array) -> void:
	var traced_rooms: Dictionary = {}
	var categories: Dictionary = {}
	var representative_signatures: Dictionary = {}
	var structural_rooms := 0
	var stroked_structural_rooms := 0
	for room_index in range(rooms.size()):
		var room := rooms[room_index] as Dictionary
		var room_id := String(room.get("id", "room-%d" % room_index))
		var hazard := String(room.get("hazard", ""))
		var capture := _capture_first_activation(run, room, 710003 + room_index * 977, 1.0 / 60.0)
		_check(bool(capture.get("activated", false)), "%s must activate a live runtime event" % room_id)
		if not bool(capture.get("activated", false)):
			continue
		var activation := capture.get("activation", {}) as Dictionary
		var category := String(activation.get("category", ""))
		var expected_category := String(CATEGORY_BY_HAZARD.get(hazard, "__unmapped__"))
		_check(category == expected_category, "%s live category must be %s, got %s" % [room_id, expected_category, category])
		traced_rooms[room_id] = true
		categories[category] = true
		var operations := _trace_operations(run._room_runtime_trace)
		_check("plan_built" in operations, "%s live trace must include plan_built" % room_id)
		_check("telegraph" in operations, "%s live trace must include telegraph" % room_id)
		_check("activated" in operations, "%s live trace must include activated" % room_id)
		var projectile_enabled := bool((run._room_contract.get("projectile", {}) as Dictionary).get("enabled", false))
		if projectile_enabled:
			_check("emit_projectiles" in operations, "%s enabled pattern must execute live projectile emission" % room_id)
		else:
			structural_rooms += 1
			_check("hold_structural_hazard" in operations, "%s none_structural pattern must execute a live structural collider" % room_id)
			_check(int(capture.get("projectiles", -1)) == 0, "%s none_structural pattern must create zero bullets" % room_id)
			var motif := capture.get("motif", {}) as Dictionary
			var collision := motif.get("collision", {}) as Dictionary
			_check(bool(collision.get("enabled", false)) and not (motif.get("positions", []) as Array).is_empty(), "%s none_structural pattern must create at least one enabled live collider" % room_id)
			_check(_motif_safe_disk_clearance(motif) >= -0.25, "%s initial structural collision footprint must preserve the expanded safe disk (%.2fpx)" % [room_id, _motif_safe_disk_clearance(motif)])
			var shape := String(collision.get("shape", "circle"))
			if shape in ["arc", "segment_chain"]:
				stroked_structural_rooms += 1
				var unit := minf(RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x, RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y)
				var collision_diameter := maxf(8.0, float(collision.get("thickness_normalized", 0.025)) * unit) * 2.0
				var render_width := RunSceneClass.room_collision_render_width(collision, unit)
				_check(is_equal_approx(render_width, collision_diameter), "%s %s render width must equal its authored collision diameter (render %.2f, collision %.2f)" % [room_id, shape, render_width, collision_diameter])
		_check(bool(capture.get("caps_ok", false)), "%s must remain inside live enemy/projectile/wave caps: %s" % [room_id, String(capture.get("cap_error", "unknown"))])
		var cause := String((capture.get("motif", {}) as Dictionary).get("cause", ""))
		_check("room:%s|" % String(run._room_contract.get("room_id", "")) in cause and "|category:%s|" % category in cause, "%s live damage attribution must include room and category" % room_id)
		var activation_base := _vector_positions(((capture.get("motif", {}) as Dictionary).get("base_positions", []) as Array))
		var frozen_telegraph := _vector_positions(capture.get("telegraph_positions", []) as Array)
		_check(not frozen_telegraph.is_empty() and _positions_within(frozen_telegraph, activation_base, 0.001), "%s frozen telegraph runtime positions must equal the activation base with no first-active teleport" % room_id)
		if String(CATEGORY_REPRESENTATIVE.get(category, "")) == hazard:
			var signature := _label_free_live_signature(run, capture)
			representative_signatures[category] = signature
			_check(not signature.is_empty(), "%s representative must expose a live behavior signature" % category)
		var clear_result := _advance_until_wave_clear(run, String(capture.get("wave_id", "")), Vector2(capture.get("safe_position", Vector2.ZERO)), 1.0 / 60.0)
		_check(bool(clear_result.get("cleared", false)), "%s first live wave must reach clear_wave" % room_id)
		_check(bool(clear_result.get("caps_ok", false)), "%s must preserve caps through cleanup: %s" % [room_id, String(clear_result.get("cap_error", "unknown"))])
		_check(_owner_entities(run, String(capture.get("wave_id", ""))) == 0, "%s clear_wave must remove every owned runtime entity" % room_id)
	_check(traced_rooms.size() == 42, "All 42 launch rooms must produce a live trace")
	_check(structural_rooms == 18, "Exactly 18 none_structural profiles must run with zero bullets and real colliders")
	_check(stroked_structural_rooms > 0, "Launch structural profiles must exercise collision/render-width parity for a stroked shape")
	_check(_sorted_keys(categories) == EXPECTED_CATEGORIES, "Live runtime must exercise exactly the eight authored categories")
	_check(representative_signatures.size() == 8, "Each runtime category must expose one live representative signature")
	var signature_set: Dictionary = {}
	for signature in representative_signatures.values():
		signature_set[String(signature)] = true
	_check(signature_set.size() == 8, "The eight live categories must have pairwise-distinct label-free behavior signatures")


func _test_safe_and_unsafe_probes(run: Node, rooms: Array) -> void:
	var safe_cases := 0
	var unsafe_cases := 0
	for hz in FRAME_RATES:
		var delta := 1.0 / float(hz)
		for room_index in range(rooms.size()):
			var room := rooms[room_index] as Dictionary
			var room_id := String(room.get("id", "room-%d" % room_index))
			for seed_salt in PROBE_SEED_SALTS:
				var seed := 920011 + room_index * 4099 + int(seed_salt)
				var safe_result := _run_safe_path_agent(run, room, seed, delta)
				_check(bool(safe_result.get("prepared", false)), "%s safe-path agent must prepare at %d Hz seed %d" % [room_id, hz, seed])
				_check(int(safe_result.get("activated_events", -1)) == int(safe_result.get("expected_events", -2)), "%s safe-path agent must cover every live event at %d Hz seed %d (%d/%d)" % [room_id, hz, seed, int(safe_result.get("activated_events", 0)), int(safe_result.get("expected_events", 0))])
				_check(int(safe_result.get("approached_events", -1)) == int(safe_result.get("expected_events", -2)), "%s safe-path agent must enter every safe disk before activation at %d Hz seed %d (%d/%d)" % [room_id, hz, seed, int(safe_result.get("approached_events", 0)), int(safe_result.get("expected_events", 0))])
				_check(int(safe_result.get("edge_events", -1)) == int(safe_result.get("expected_events", -2)), "%s safe-path agent must reach every safe-disk edge at %d Hz seed %d (%d/%d)" % [room_id, hz, seed, int(safe_result.get("edge_events", 0)), int(safe_result.get("expected_events", 0))])
				_check(int(safe_result.get("waypoints_reached", -1)) == int(safe_result.get("expected_waypoints", -2)), "%s bounded agent must traverse every contract.safe_path waypoint at %d Hz seed %d (%d/%d)" % [room_id, hz, seed, int(safe_result.get("waypoints_reached", 0)), int(safe_result.get("expected_waypoints", 0))])
				_check(bool(safe_result.get("exit_reached", false)), "%s safe path must reach the forward exit without a dead end at %d Hz seed %d (distance %.2f)" % [room_id, hz, seed, float(safe_result.get("exit_distance", INF))])
				_check(bool(safe_result.get("health_unchanged", false)), "%s bounded safe-path agent must take zero damage at %d Hz seed %d; causes=%s" % [room_id, hz, seed, str(safe_result.get("damage_causes", []))])
				_check(bool(safe_result.get("bounded_motion", false)), "%s touch-driven safe-path motion must remain speed-bounded at %d Hz seed %d (max %.2f px/s)" % [room_id, hz, seed, float(safe_result.get("max_control_speed", INF))])
				_check(bool(safe_result.get("inside_bounds", false)), "%s safe-path agent must remain inside combat bounds at %d Hz seed %d" % [room_id, hz, seed])
				_check(bool(safe_result.get("swept_clearance_ok", false)), "%s live swept motif collision must remain outside the expanded safe disk at %d Hz seed %d: %s" % [room_id, hz, seed, str(safe_result.get("swept_clearance_failures", []))])
				_check(String(safe_result.get("cap_error", "")).is_empty(), "%s safe-path agent must respect authored/runtime caps at %d Hz seed %d: %s" % [room_id, hz, seed, String(safe_result.get("cap_error", "unknown"))])
				safe_cases += 1

				var unsafe_capture := _capture_first_activation(run, room, seed, delta)
				_check(bool(unsafe_capture.get("activated", false)), "%s unsafe probe must activate at %d Hz seed %d" % [room_id, hz, seed])
				if not bool(unsafe_capture.get("activated", false)):
					continue
				var unsafe_result := _execute_unsafe_probe(run, unsafe_capture, delta)
				_check(bool(unsafe_result.get("valid_trajectory", false)), "%s unsafe probe must use a live collider or moved owned-projectile trajectory at %d Hz seed %d: %s" % [room_id, hz, seed, String(unsafe_result.get("error", "unknown"))])
				_check(bool(unsafe_result.get("damaged", false)), "%s live unsafe trajectory must damage the player at %d Hz seed %d" % [room_id, hz, seed])
				_check(bool(unsafe_result.get("cause_matches", false)), "%s unsafe damage signal must carry the exact room/hazard/event/wave cause at %d Hz seed %d; got %s" % [room_id, hz, seed, String(unsafe_result.get("actual_cause", "none"))])
				_check(bool(unsafe_result.get("before_cleanup", false)), "%s impact must occur strictly before wave cleanup at %d Hz seed %d" % [room_id, hz, seed])
				_check(String(unsafe_result.get("cap_error", "")).is_empty(), "%s unsafe probe must respect authored/runtime caps at %d Hz seed %d: %s" % [room_id, hz, seed, String(unsafe_result.get("cap_error", "unknown"))])
				run._clear_contract_waves()
				unsafe_cases += 1
	_check(safe_cases == rooms.size() * FRAME_RATES.size() * PROBE_SEED_SALTS.size(), "Every room/seed/rate safe-probe case must execute")
	_check(unsafe_cases == rooms.size() * FRAME_RATES.size() * PROBE_SEED_SALTS.size(), "Every room/seed/rate unsafe-probe case must execute")


func _run_safe_path_agent(run: Node, room: Dictionary, seed: int, delta: float) -> Dictionary:
	if not _prepare_room(run, room, seed):
		return {"prepared": false}
	# A chamber repeats its schedule in production. This probe exercises one
	# authored path from entry to exit without allowing the next cycle to reset it.
	run.state = RunSceneClass.RunState.INTERNAL_ROOMS
	var events := run._room_pattern_plan.get("events", []) as Array
	var safe_path := run._room_contract.get("safe_path", []) as Array
	var duration := float(run._room_contract.get("duration", 0.0))
	var waypoint_min_distances: Array[float] = []
	for _waypoint in safe_path:
		waypoint_min_distances.append(INF)
	var activation_seen: Dictionary = {}
	var activation_approached: Dictionary = {}
	var edge_min_distances: Dictionary = {}
	var start_health := float(run._player.health)
	var cause_start := damage_causes.size()
	var cap_error := ""
	var bounded_motion := true
	var inside_bounds := true
	var max_control_speed := 0.0
	var swept_clearances: Dictionary = {}
	run._player.set_controls_active(true)
	_send_agent_touch(run, run._player.position, true)
	var max_frames := maxi(1, ceili((duration + 0.35) / delta))
	for _frame in range(max_frames):
		var target_record := _safe_agent_target(run, float(run._room_elapsed), 0.16)
		var target := Vector2(target_record.get("position", run._player.position))
		var edge_event := int(target_record.get("event_index", -1))
		_send_agent_touch(run, target, false)
		var before_control: Vector2 = run._player.position
		run._player._physics_process(delta)
		var control_speed: float = before_control.distance_to(run._player.position) / maxf(delta, 0.0001)
		max_control_speed = maxf(max_control_speed, control_speed)
		if control_speed > float(run._player.max_speed) + 1.0:
			bounded_motion = false
		_step_live_room(run, delta)
		_record_swept_clearances(run, swept_clearances)
		if not RunSceneClass.INTERNAL_COMBAT_BOUNDS.grow(0.5).has_point(run._player.position):
			inside_bounds = false
		if edge_event >= 0:
			var edge_distance: float = run._player.position.distance_to(target)
			edge_min_distances[edge_event] = minf(float(edge_min_distances.get(edge_event, INF)), edge_distance)
		for waypoint_index in range(safe_path.size()):
			var waypoint := safe_path[waypoint_index] as Dictionary
			var waypoint_world := RunSceneClass.room_space_position(waypoint.get("position", Mechanics.ENTRY_POINT) as Array)
			waypoint_min_distances[waypoint_index] = minf(waypoint_min_distances[waypoint_index], run._player.position.distance_to(waypoint_world))
		# The runtime trace is a bounded rolling buffer. Reading it with a monotonically
		# growing array cursor loses new entries after the first pop_front(); one event
		# can activate per frame, so dedupe the latest activation by signed event index.
		var trace_entry := _last_trace(run._room_runtime_trace, "activated")
		if not trace_entry.is_empty():
			var event_index := int(trace_entry.get("event_index", -1))
			if event_index >= 0 and not activation_seen.has(event_index):
				activation_seen[event_index] = true
				var wave_id := String(trace_entry.get("wave_id", ""))
				var motif := run._active_room_motifs.get(wave_id, {}) as Dictionary
				var safe_center := Vector2(motif.get("safe_position", Vector2.ZERO))
				var safe_radius := float(motif.get("safe_clearance_pixels", 0.0))
				activation_approached[event_index] = run._player.position.distance_to(safe_center) <= safe_radius + 0.5
		cap_error = _first_cap_error(run)
		if not cap_error.is_empty():
			break
		if float(run._room_elapsed) >= duration and run._active_room_waves.is_empty() and run._telegraph.is_empty():
			break
	_send_agent_touch(run, run._player.position, false, true)
	run._player.set_controls_active(false)
	var waypoints_reached := 0
	var unit := minf(RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x, RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y)
	for waypoint_index in range(safe_path.size()):
		var waypoint := safe_path[waypoint_index] as Dictionary
		var clearance := maxf(18.0, float(waypoint.get("clearance", Mechanics.MIN_SAFE_CLEARANCE)) * unit)
		if waypoint_min_distances[waypoint_index] <= clearance:
			waypoints_reached += 1
	var approached_events := 0
	var edge_events := 0
	for event_index in range(events.size()):
		if bool(activation_approached.get(event_index, false)):
			approached_events += 1
		if float(edge_min_distances.get(event_index, INF)) <= 18.0:
			edge_events += 1
	var exit_data := (run._room_contract.get("exit", {}) as Dictionary).get("normalized_position", Mechanics.EXIT_POINT) as Array
	var exit_position := RunSceneClass.room_space_position(exit_data)
	var exit_distance: float = run._player.position.distance_to(exit_position)
	var case_causes: Array[String] = []
	for cause_index in range(cause_start, damage_causes.size()):
		case_causes.append(damage_causes[cause_index])
	var swept_clearance_failures: Array[String] = []
	for raw_key in swept_clearances.keys():
		var record := swept_clearances[raw_key] as Dictionary
		var minimum_clearance := float(record.get("minimum_clearance", INF))
		if minimum_clearance >= -0.25:
			continue
		swept_clearance_failures.append(
			"event=%d model=%s shape=%s min_clearance=%.2fpx" % [
				int(record.get("event_index", -1)),
				String(record.get("movement_model", "unknown")),
				String(record.get("shape", "unknown")),
				minimum_clearance,
			]
		)
	swept_clearance_failures.sort()
	return {
		"prepared": true,
		"expected_events": events.size(),
		"activated_events": activation_seen.size(),
		"approached_events": approached_events,
		"edge_events": edge_events,
		"expected_waypoints": safe_path.size(),
		"waypoints_reached": waypoints_reached,
		"exit_reached": exit_distance <= 24.0,
		"exit_distance": exit_distance,
		"health_unchanged": is_equal_approx(float(run._player.health), start_health) and case_causes.is_empty(),
		"damage_causes": case_causes,
		"bounded_motion": bounded_motion,
		"inside_bounds": inside_bounds,
		"max_control_speed": max_control_speed,
		"swept_clearance_ok": swept_clearance_failures.is_empty(),
		"swept_clearance_failures": swept_clearance_failures,
		"cap_error": cap_error,
	}


func _safe_agent_target(run: Node, elapsed_time: float, lookahead: float) -> Dictionary:
	var sample_time := elapsed_time + lookahead
	var target := _safe_path_position(run._room_contract.get("safe_path", []) as Array, sample_time)
	var events := run._room_pattern_plan.get("events", []) as Array
	for raw_event in events:
		var event := raw_event as Dictionary
		if elapsed_time + 0.0001 < float(event.get("telegraph_at", 0.0)) or elapsed_time > float(event.get("clear_at", 0.0)) + 0.0001:
			continue
		return {
			"position": _safe_edge_position(event),
			"event_index": int(event.get("index", -1)),
		}
	return {"position": target, "event_index": -1}


func _record_swept_clearances(run: Node, records: Dictionary) -> void:
	for raw_wave_id in run._active_room_motifs.keys():
		var motif := run._active_room_motifs[raw_wave_id] as Dictionary
		var collision := motif.get("collision", {}) as Dictionary
		if not bool(motif.get("emitter_active", true)) or not bool(collision.get("enabled", false)):
			continue
		var event_index := int(motif.get("event_index", -1))
		var movement := motif.get("movement", {}) as Dictionary
		var movement_model := String(movement.get("source_model", "unknown"))
		var shape := String(collision.get("shape", "circle"))
		var key := "%d|%s|%s" % [event_index, movement_model, shape]
		var clearance := _motif_safe_disk_clearance(motif)
		var prior := records.get(key, {}) as Dictionary
		if prior.is_empty() or clearance < float(prior.get("minimum_clearance", INF)):
			records[key] = {
				"event_index": event_index,
				"movement_model": movement_model,
				"shape": shape,
				"minimum_clearance": clearance,
			}


func _motif_safe_disk_clearance(motif: Dictionary) -> float:
	var positions := motif.get("positions", []) as Array
	if positions.is_empty():
		return INF
	var collision := motif.get("collision", {}) as Dictionary
	var shape := String(collision.get("shape", "circle"))
	var safe_center := Vector2(motif.get("safe_position", RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()))
	# The safe disk describes the player's center. Expand it by the same 12 px
	# player radius used by RunScene collision instead of relying on safe immunity.
	var expanded_safe_radius := float(motif.get("safe_clearance_pixels", 34.0)) + 12.0
	var unit := minf(RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x, RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y)
	var minimum_clearance := INF
	if shape == "segment_chain" and positions.size() >= 2:
		var chain_radius := maxf(8.0, float(collision.get("thickness_normalized", 0.025)) * unit)
		for index in range(positions.size() - 1):
			var first := Vector2(positions[index])
			var second := Vector2(positions[index + 1])
			minimum_clearance = minf(minimum_clearance, _point_segment_distance(safe_center, first, second) - chain_radius - expanded_safe_radius)
		return minimum_clearance
	var visual_token := String((motif.get("spawn", {}) as Dictionary).get("visual_token", ""))
	for position_index in range(positions.size()):
		var center := Vector2(positions[position_index])
		var clearance := INF
		match shape:
			"box", "cell":
				var half_data := collision.get("half_extents_normalized", [0.055, 0.055]) as Array
				var half_extents := Vector2(
					float(half_data[0]) * RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x,
					float(half_data[1]) * RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y
				)
				clearance = _point_rect_distance(safe_center, Rect2(center - half_extents, half_extents * 2.0)) - expanded_safe_radius
			"arc":
				var arc_radius := maxf(20.0, float(collision.get("radius_normalized", 0.24)) * unit)
				var arc_thickness := maxf(8.0, float(collision.get("thickness_normalized", 0.035)) * unit)
				var phase_offset := float(abs(visual_token.hash()) % 17) * 0.07 + float(position_index) * 0.5
				clearance = _point_arc_distance(safe_center, center, arc_radius, -1.05 + phase_offset, 1.05 + phase_offset) - arc_thickness - expanded_safe_radius
			_:
				var radius := maxf(10.0, float(collision.get("radius_normalized", 0.035)) * unit)
				clearance = safe_center.distance_to(center) - radius - expanded_safe_radius
		minimum_clearance = minf(minimum_clearance, clearance)
	return minimum_clearance


func _motif_clearance_at_positions(motif: Dictionary, positions: Array[Vector2]) -> float:
	var sample := motif.duplicate(true)
	sample["positions"] = positions.duplicate()
	return _motif_safe_disk_clearance(sample)


func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var delta_x := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var delta_y := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(delta_x, delta_y).length()


func _point_arc_distance(point: Vector2, center: Vector2, radius: float, start_angle: float, end_angle: float) -> float:
	var offset := point - center
	if offset.length_squared() <= 0.0001:
		return radius
	var relative_angle := wrapf(offset.angle() - start_angle, 0.0, TAU)
	var span := wrapf(end_angle - start_angle, 0.0, TAU)
	if relative_angle <= span:
		return absf(offset.length() - radius)
	var start_point := center + Vector2.from_angle(start_angle) * radius
	var end_point := center + Vector2.from_angle(end_angle) * radius
	return minf(point.distance_to(start_point), point.distance_to(end_point))


func _safe_path_position(safe_path: Array, sample_time: float) -> Vector2:
	if safe_path.is_empty():
		return RunSceneClass.room_space_position(Mechanics.ENTRY_POINT)
	var first := safe_path[0] as Dictionary
	if sample_time <= float(first.get("time", 0.0)):
		return RunSceneClass.room_space_position(first.get("position", Mechanics.ENTRY_POINT) as Array)
	for index in range(1, safe_path.size()):
		var prior := safe_path[index - 1] as Dictionary
		var current := safe_path[index] as Dictionary
		var current_time := float(current.get("time", 0.0))
		if sample_time > current_time:
			continue
		var prior_time := float(prior.get("time", 0.0))
		var ratio := clampf((sample_time - prior_time) / maxf(0.001, current_time - prior_time), 0.0, 1.0)
		var prior_position := RunSceneClass.room_space_position(prior.get("position", Mechanics.ENTRY_POINT) as Array)
		var current_position := RunSceneClass.room_space_position(current.get("position", Mechanics.EXIT_POINT) as Array)
		return prior_position.lerp(current_position, ratio)
	var last := safe_path[-1] as Dictionary
	return RunSceneClass.room_space_position(last.get("position", Mechanics.EXIT_POINT) as Array)


func _safe_edge_position(event: Dictionary) -> Vector2:
	var safe := event.get("safe", {}) as Dictionary
	var center := RunSceneClass.room_space_position(safe.get("position", [0.5, 0.5]) as Array)
	var unit := minf(RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x, RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y)
	var radius := maxf(34.0, float(safe.get("clearance", Mechanics.MIN_SAFE_CLEARANCE)) * unit)
	var inward := RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center() - center
	if inward.length_squared() < 0.001:
		inward = Vector2.RIGHT
	return center + inward.normalized() * maxf(0.0, radius - 14.0)


func _send_agent_touch(run: Node, world_target: Vector2, pressed: bool, release: bool = false) -> void:
	var canvas_transform := run.get_viewport().get_canvas_transform()
	var screen_target := canvas_transform * (world_target - Vector2(0.0, -82.0))
	if pressed or release:
		var touch := InputEventScreenTouch.new()
		touch.index = 77
		touch.position = screen_target
		touch.pressed = not release
		run._player._unhandled_input(touch)
		return
	var drag := InputEventScreenDrag.new()
	drag.index = 77
	drag.position = screen_target
	run._player._unhandled_input(drag)


func _execute_unsafe_probe(run: Node, capture: Dictionary, delta: float) -> Dictionary:
	var wave_id := String(capture.get("wave_id", ""))
	var motif := run._active_room_motifs.get(wave_id, {}) as Dictionary
	var collision := motif.get("collision", {}) as Dictionary
	var expected_cause := String(motif.get("cause", ""))
	var cause_start := damage_causes.size()
	var start_health := float(run._player.health)
	var deadline := float(run._active_room_waves.get(wave_id, -INF))
	var valid_trajectory := false
	var error := ""
	run._player.set_controls_active(false)
	run._player.invulnerability = 0.0
	if bool(collision.get("enabled", false)):
		var crossing := _structural_crossing(motif)
		valid_trajectory = bool(crossing.get("valid", false))
		if valid_trajectory:
			run._player.place_at(Vector2(crossing.get("finish", Vector2.ZERO)))
			run._room_previous_player_position = Vector2(crossing.get("start", run._player.position))
			# A zero delta makes RunScene's swept endpoint fraction zero and only
			# probes the start point. Advance one real frame so this is a genuine
			# bounded crossing through the live, moving collision geometry.
			run._update_active_room_motifs(delta)
		else:
			error = String(crossing.get("error", "no structural crossing"))
	else:
		var initial_positions: Array[Vector2] = []
		for bullet in run._projectiles.enemy_active:
			if String((bullet as Dictionary).get("parent_group", "")) == wave_id:
				initial_positions.append(Vector2((bullet as Dictionary).get("position", Vector2.ZERO)))
		var safe_position := Vector2(capture.get("safe_position", RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()))
		run._player.place_at(safe_position)
		run._room_previous_player_position = safe_position
		_step_live_room(run, delta)
		var intercept_bullet: Dictionary = {}
		for bullet in run._projectiles.enemy_active:
			var candidate := bullet as Dictionary
			if String(candidate.get("parent_group", "")) != wave_id:
				continue
			var candidate_position := Vector2(candidate.get("position", Vector2.ZERO))
			var moved := true
			for initial_position in initial_positions:
				if candidate_position.distance_to(initial_position) <= 0.1:
					moved = false
					break
			if moved and RunSceneClass.INTERNAL_COMBAT_BOUNDS.has_point(candidate_position) and float(candidate.get("life", 0.0)) > delta:
				intercept_bullet = candidate
				break
		if not intercept_bullet.is_empty():
			valid_trajectory = true
			expected_cause = String(intercept_bullet.get("cause", expected_cause))
			var intercept := Vector2(intercept_bullet.get("position", Vector2.ZERO))
			run._player.place_at(intercept)
			run._room_previous_player_position = intercept
			run._player.invulnerability = 0.0
			_step_live_room(run, delta)
		else:
			error = "no moved, in-bounds, live owned projectile before deadline"
	var damaged := float(run._player.health) < start_health - 0.001 and damage_causes.size() > cause_start
	var actual_cause := damage_causes[-1] if damage_causes.size() > cause_start else ""
	var before_cleanup: bool = damaged and float(run._room_elapsed) < deadline + 0.0001 and run._active_room_waves.has(wave_id) and not _trace_has_wave_operation(run._room_runtime_trace, "clear_wave", wave_id)
	return {
		"valid_trajectory": valid_trajectory,
		"damaged": damaged,
		"cause_matches": damaged and actual_cause == expected_cause and "|wave:%s" % wave_id in actual_cause,
		"actual_cause": actual_cause,
		"before_cleanup": before_cleanup,
		"cap_error": _first_cap_error(run),
		"error": error,
	}


func _structural_crossing(motif: Dictionary) -> Dictionary:
	var positions := motif.get("positions", []) as Array
	if positions.is_empty():
		return {"valid": false, "error": "structural motif has no positions"}
	var collision := motif.get("collision", {}) as Dictionary
	var shape := String(collision.get("shape", "circle"))
	var safe_position := Vector2(motif.get("safe_position", RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()))
	var safe_radius := float(motif.get("safe_clearance_pixels", 34.0))
	var unit := minf(RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x, RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y)
	var probe := Vector2.ZERO
	var crossing_axis := Vector2.RIGHT
	var found := false
	if shape == "segment_chain" and positions.size() >= 2:
		for index in range(positions.size() - 1):
			var start := Vector2(positions[index])
			var finish := Vector2(positions[index + 1])
			for sample_index in range(1, 10):
				var candidate := start.lerp(finish, float(sample_index) / 10.0)
				if candidate.distance_to(safe_position) <= safe_radius + 2.0 or not RunSceneClass.INTERNAL_COMBAT_BOUNDS.has_point(candidate):
					continue
				probe = candidate
				crossing_axis = (finish - start).normalized().orthogonal()
				found = true
				break
			if found:
				break
	elif shape == "arc":
		var arc_radius := maxf(20.0, float(collision.get("radius_normalized", 0.24)) * unit)
		var visual_token := String((motif.get("spawn", {}) as Dictionary).get("visual_token", ""))
		for position_index in range(positions.size()):
			var center := Vector2(positions[position_index])
			var phase_offset := float(abs(visual_token.hash()) % 17) * 0.07 + float(position_index) * 0.5
			for sample_index in range(1, 10):
				var angle := lerpf(-1.05 + phase_offset, 1.05 + phase_offset, float(sample_index) / 10.0)
				var candidate := center + Vector2.from_angle(angle) * arc_radius
				if candidate.distance_to(safe_position) <= safe_radius + 2.0 or not RunSceneClass.INTERNAL_COMBAT_BOUNDS.has_point(candidate):
					continue
				probe = candidate
				crossing_axis = (candidate - center).normalized()
				found = true
				break
			if found:
				break
	else:
		for raw_position in positions:
			var candidate := Vector2(raw_position)
			if candidate.distance_to(safe_position) <= safe_radius + 2.0 or not RunSceneClass.INTERNAL_COMBAT_BOUNDS.has_point(candidate):
				continue
			probe = candidate
			found = true
			break
	if not found:
		return {"valid": false, "error": "no in-bounds collision point outside safe disk for shape %s" % shape}
	var half_crossing := 6.0
	var crossing_start := probe - crossing_axis * half_crossing
	var crossing_finish := probe + crossing_axis * half_crossing
	if not RunSceneClass.INTERNAL_COMBAT_BOUNDS.has_point(crossing_start) or not RunSceneClass.INTERNAL_COMBAT_BOUNDS.has_point(crossing_finish):
		crossing_start = probe
		crossing_finish = probe
	if crossing_finish.distance_to(safe_position) <= safe_radius and crossing_start.distance_to(safe_position) > safe_radius:
		var swap: Vector2 = crossing_start
		crossing_start = crossing_finish
		crossing_finish = swap
	if crossing_finish.distance_to(safe_position) <= safe_radius:
		return {"valid": false, "error": "computed structural finish is inside the protected safe disk"}
	return {"valid": true, "start": crossing_start, "finish": crossing_finish}


func _test_defender_lifecycle(run: Node, rooms: Array) -> void:
	var defender_profiles := 0
	var persisted_profiles := 0
	var killable_profiles := 0
	for room_index in range(rooms.size()):
		var room := rooms[room_index] as Dictionary
		var room_id := String(room.get("id", "room-%d" % room_index))
		var capture := _capture_first_activation(run, room, 440071 + room_index * 271, 1.0 / 60.0)
		if not bool(capture.get("activated", false)):
			continue
		var event := capture.get("event", {}) as Dictionary
		var spawn := event.get("spawn", {}) as Dictionary
		if String(spawn.get("defender_archetype", "none")) == "none":
			run._clear_contract_waves()
			continue
		defender_profiles += 1
		var wave_id := String(capture.get("wave_id", ""))
		var actor_group := String(capture.get("actor_group", ""))
		var original_defenders: Dictionary = {}
		for enemy in run._enemies:
			var defender := enemy as Dictionary
			if String(defender.get("actor_owner_id", "")) != actor_group:
				continue
			original_defenders[String(defender.get("id", ""))] = {
				"health": float(defender.get("health", 0.0)),
				"archetype": String(defender.get("archetype", "")),
			}
		_check(not original_defenders.is_empty(), "%s defender plan must instantiate at least one live defender" % room_id)
		var deadline := float(run._active_room_actor_groups.get(actor_group, float(run._room_elapsed)))
		var safe_position := Vector2(capture.get("safe_position", RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()))
		while float(run._room_elapsed) + 1.0 / 60.0 < deadline - 0.0001 and run._active_room_actor_groups.has(actor_group):
			run._player.place_at(safe_position)
			run._room_previous_player_position = safe_position
			_step_live_room(run, 1.0 / 60.0)
		var persistent: bool = run._active_room_actor_groups.has(actor_group)
		for defender_id in original_defenders:
			var defender := _enemy_by_id(run._enemies, String(defender_id))
			var original := original_defenders[defender_id] as Dictionary
			persistent = persistent \
				and not defender.is_empty() \
				and String(defender.get("source_wave", "")) == wave_id \
				and String(defender.get("parent_wave", "")) == wave_id \
				and String(defender.get("actor_owner_id", "")) == actor_group \
				and String(defender.get("contract_group", "")) == actor_group \
				and String(defender.get("archetype", "")) == String(original.get("archetype", "")) \
				and is_equal_approx(float(defender.get("health", -1.0)), float(original.get("health", 0.0)))
		_check(persistent, "%s defenders must persist, retain health/archetype/ownership, and remain targetable until the active deadline" % room_id)
		if persistent:
			persisted_profiles += 1
		var target_id := String(original_defenders.keys()[0]) if not original_defenders.is_empty() else ""
		var target := _enemy_by_id(run._enemies, target_id)
		var killed := false
		if not target.is_empty() and run._active_room_actor_groups.has(actor_group):
			var spawned: bool = run._projectiles.spawn_player(
				Vector2(target.get("position", Vector2.ZERO)),
				Vector2.ZERO,
				float(target.get("health", 0.0)) + 1.0,
				{"radius": 4.0, "life": 0.1, "behavior": "runtime_killability_probe"}
			)
			_check(spawned, "%s killability probe must enter the real player-projectile pool" % room_id)
			var hit_result: Dictionary = run._projectiles.step(1.0 / 600.0, run._target_infos(false), safe_position, 12.0)
			for hit in hit_result.get("target_hits", []) as Array:
				run._damage_target(hit as Dictionary)
			killed = _enemy_by_id(run._enemies, target_id).is_empty() and run._active_room_actor_groups.has(actor_group) and float(run._room_elapsed) < deadline
		_check(killed, "%s live defender must be killable through player projectile collision before owner-wave cleanup" % room_id)
		if killed:
			killable_profiles += 1
		run._bio_pickups.clear()
		run._clear_contract_waves()
	_check(defender_profiles > 0, "Launch catalog must exercise defender lifecycle integration")
	_check(persisted_profiles == defender_profiles, "Every defender profile must persist until its live wave deadline")
	_check(killable_profiles == defender_profiles, "Every defender profile must be killable through the live projectile/damage path")


func _test_chamber_last_defender_duration_boundary(run: Node, rooms: Array) -> void:
	var tested_profiles := 0
	for room_index in range(rooms.size()):
		var room := rooms[room_index] as Dictionary
		if String(room.get("type", "")) != "chamber":
			continue
		var room_id := String(room.get("id", "room-%d" % room_index))
		if not _prepare_room(run, room, 660013 + room_index * 337):
			_check(false, "%s last-defender boundary probe must prepare" % room_id)
			continue
		var events := run._room_pattern_plan.get("events", []) as Array
		if events.is_empty():
			_check(false, "%s chamber plan must expose a last event" % room_id)
			continue
		var last_event := events[-1] as Dictionary
		var spawn := last_event.get("spawn", {}) as Dictionary
		if String(spawn.get("defender_archetype", "none")) == "none" or int(spawn.get("enemy_count", 0)) <= 0:
			continue
		tested_profiles += 1
		var last_event_index := int(last_event.get("index", events.size() - 1))
		var delta := 1.0 / 60.0
		var telegraph_seconds := float((run._room_contract.get("timing", {}) as Dictionary).get("telegraph_seconds", 0.45))
		run._room_event_index = events.size() - 1
		run._room_elapsed = maxf(0.0, float(last_event.get("active_at", 0.0)) - telegraph_seconds - delta)
		var fallback_safe := RunSceneClass.room_space_position((last_event.get("safe", {}) as Dictionary).get("position", [0.5, 0.5]) as Array)
		var activation: Dictionary = {}
		for _frame in range(240):
			var safe_position := _current_live_safe_position(run, fallback_safe)
			run._player.place_at(safe_position)
			run._room_previous_player_position = safe_position
			_step_live_room(run, delta)
			var candidate := _last_trace(run._room_runtime_trace, "activated")
			if not candidate.is_empty() and int(candidate.get("event_index", -1)) == last_event_index:
				activation = candidate
				break
		_check(not activation.is_empty(), "%s final chamber event must activate for the actor-deadline probe" % room_id)
		if activation.is_empty():
			run._clear_contract_waves()
			continue
		var actor_group := String(activation.get("actor_group", ""))
		var actor_count := _enemy_actor_owner_count(run._enemies, actor_group)
		_check(not actor_group.is_empty() and actor_count > 0, "%s final chamber event must instantiate a live defender actor group" % room_id)
		if actor_group.is_empty() or actor_count <= 0:
			run._clear_contract_waves()
			continue
		var duration := float(run._room_contract.get("duration", 0.0))
		var actor_deadline := float(run._active_room_actor_groups.get(actor_group, -INF))
		_check(actor_deadline > duration + delta, "%s final defender deadline must extend beyond contract.duration (deadline %.3f, duration %.3f)" % [room_id, actor_deadline, duration])
		var initial_cycle := int(run._room_cycle_index)
		var saw_after_duration := false
		var persisted_until_deadline := true
		while float(run._room_elapsed) + delta < actor_deadline - 0.0001:
			var safe_position := _current_live_safe_position(run, fallback_safe)
			run._player.place_at(safe_position)
			run._room_previous_player_position = safe_position
			_step_live_room(run, delta)
			if float(run._room_elapsed) > duration + 0.0001:
				saw_after_duration = true
			if int(run._room_cycle_index) != initial_cycle or not run._active_room_actor_groups.has(actor_group) or _enemy_actor_owner_count(run._enemies, actor_group) != actor_count:
				persisted_until_deadline = false
				break
		_check(saw_after_duration, "%s actor-deadline probe must cross contract.duration before defender expiry" % room_id)
		_check(persisted_until_deadline, "%s cycle_reset must not remove the final defender before its actor deadline" % room_id)
		if persisted_until_deadline:
			while run._active_room_actor_groups.has(actor_group) and float(run._room_elapsed) < actor_deadline + delta * 2.0:
				var safe_position := _current_live_safe_position(run, fallback_safe)
				run._player.place_at(safe_position)
				run._room_previous_player_position = safe_position
				_step_live_room(run, delta)
			_check(not run._active_room_actor_groups.has(actor_group) and _enemy_actor_owner_count(run._enemies, actor_group) == 0, "%s final defender must resolve atomically at its actor deadline" % room_id)
			_check(_trace_has_actor_clear_reason(run._room_runtime_trace, actor_group, "deadline"), "%s final defender cleanup must retain the deadline reason across chamber reset" % room_id)
		run._clear_contract_waves()
	_check(tested_profiles > 0, "Launch chambers must include a final-event defender actor-deadline case")


func _current_live_safe_position(run: Node, fallback: Vector2) -> Vector2:
	if not run._telegraph.is_empty():
		return Vector2(run._telegraph.get("safe_position", fallback))
	for raw_wave_id in run._active_room_motifs.keys():
		var motif := run._active_room_motifs[raw_wave_id] as Dictionary
		if bool(motif.get("emitter_active", true)):
			return Vector2(motif.get("safe_position", fallback))
	return fallback


func _test_movement_outputs(run: Node, rooms: Array) -> void:
	var outputs: Dictionary = {}
	for model in MOVEMENT_REPRESENTATIVE:
		var hazard := String(MOVEMENT_REPRESENTATIVE[model])
		var room := _room_for_hazard(rooms, hazard)
		var capture := _capture_first_activation(run, room, 113033 + String(model).hash(), 1.0 / 60.0)
		_check(bool(capture.get("activated", false)), "%s movement representative must activate" % String(model))
		if not bool(capture.get("activated", false)):
			continue
		var wave_id := String(capture.get("wave_id", ""))
		var motif := run._active_room_motifs.get(wave_id, {}) as Dictionary
		var initial := _vector_positions(motif.get("positions", []) as Array)
		var active_seconds := float(capture.get("active_seconds", 0.5))
		if String(model) == "anchor":
			var safe := Vector2(capture.get("safe_position", RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()))
			var before := Vector2(RunSceneClass.INTERNAL_COMBAT_BOUNDS.end.x - 8.0, safe.y)
			run._player.place_at(before)
			run._room_previous_player_position = before
			run._update_active_room_motifs(1.0 / 30.0)
			var displacement: Vector2 = run._player.position - before
			_check(displacement.length() > 1.0, "anchor movement must apply a live field force outside its safe anchor")
			outputs[model] = _measured_motion_signature([], [], RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center(), displacement)
		else:
			var safe_position := Vector2(capture.get("safe_position", Vector2.ZERO))
			var target_time: float = float(run._room_elapsed) + active_seconds * 0.48
			while run._room_elapsed < target_time and run._active_room_motifs.has(wave_id):
				run._player.place_at(safe_position)
				run._room_previous_player_position = safe_position
				_step_live_room(run, 1.0 / 60.0)
			motif = run._active_room_motifs.get(wave_id, {}) as Dictionary
			var moved := _vector_positions(motif.get("positions", []) as Array)
			var delta_vector := _first_position_delta(initial, moved)
			_check(delta_vector.length() > 0.5, "%s movement model must change live runtime geometry" % String(model))
			var movement := (capture.get("event", {}) as Dictionary).get("movement", {}) as Dictionary
			var signature_center := RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()
			match String(model):
				"lane":
					_check(absf(delta_vector.y) > absf(delta_vector.x), "lane movement must advance primarily along the room axis")
				"ring":
					signature_center = RunSceneClass.room_space_position(movement.get("center", [0.5, 0.5]) as Array)
					_check(not initial.is_empty() and not moved.is_empty() and absf(initial[0].distance_to(signature_center) - moved[0].distance_to(signature_center)) < 2.0, "ring movement must rotate while preserving radius")
				"sweep":
					var axis := String(movement.get("axis", "vertical"))
					_check((axis == "horizontal" and absf(delta_vector.x) > absf(delta_vector.y)) or (axis != "horizontal" and absf(delta_vector.y) > absf(delta_vector.x)), "sweep movement must consume its authored axis")
				"pocket":
					_check(not initial.is_empty() and not moved.is_empty() and absf(initial[0].distance_to(signature_center) - moved[0].distance_to(signature_center)) > 0.5, "pocket movement must pulse live geometry radially")
				"replay":
					_check(String((capture.get("activation", {}) as Dictionary).get("replay_digest", "")) != "history:none", "replay movement output must be backed by consumed input history")
			outputs[model] = _measured_motion_signature(initial, moved, signature_center)
		run._clear_contract_waves()
	_check(outputs.size() == 6, "All six movement models must produce a live output")
	var unique_outputs: Dictionary = {}
	for output in outputs.values():
		unique_outputs[String(output)] = true
	_check(unique_outputs.size() == 6, "All six movement models must have pairwise-distinct measured runtime outputs")


func _test_movement_zero_origin_and_first_tick(run: Node, rooms: Array) -> void:
	var exercised_models: Dictionary = {}
	for raw_model in MOVEMENT_REPRESENTATIVE.keys():
		var model := String(raw_model)
		var room := _room_for_hazard(rooms, String(MOVEMENT_REPRESENTATIVE[raw_model]))
		for hz in FRAME_RATES:
			var delta := 1.0 / float(hz)
			var capture := _capture_first_activation(run, room, 330017 + model.hash(), delta)
			_check(bool(capture.get("activated", false)), "%s zero-origin/first-tick representative must activate at %d Hz" % [model, hz])
			if not bool(capture.get("activated", false)):
				continue
			var wave_id := String(capture.get("wave_id", ""))
			var motif := run._active_room_motifs.get(wave_id, {}) as Dictionary
			var base_positions := _vector_positions(motif.get("base_positions", []) as Array)
			var starts_at := float(motif.get("starts_at", run._room_elapsed))
			var ends_at := float(motif.get("ends_at", starts_at + 0.5))
			var zero_positions := _vector_positions(run._moved_room_positions(motif, 0.0, starts_at) as Array)
			_check(_positions_within(zero_positions, base_positions, 0.001), "%s moved(p=0) must equal base geometry at %d Hz" % [model, hz])
			var safe_position := Vector2(capture.get("safe_position", RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()))
			run._player.place_at(safe_position)
			run._room_previous_player_position = safe_position
			run._update_active_room_motifs(delta)
			var advanced := run._active_room_motifs.get(wave_id, {}) as Dictionary
			var first_tick_positions := _vector_positions(advanced.get("positions", []) as Array)
			var measured_displacement := _maximum_position_displacement(base_positions, first_tick_positions)
			var authored_bound := _authored_first_tick_bound(motif, delta, starts_at, ends_at)
			_check(measured_displacement <= authored_bound + 0.1, "%s first live tick must remain bounded by authored motion at %d Hz (measured %.3f, bound %.3f)" % [model, hz, measured_displacement, authored_bound])
			exercised_models[model] = true
			run._clear_contract_waves()
	_check(exercised_models.size() == 6, "Zero-origin and first-tick checks must exercise all six live movement models")


func _authored_first_tick_bound(motif: Dictionary, delta: float, starts_at: float, ends_at: float) -> float:
	var movement := motif.get("movement", {}) as Dictionary
	var model := String(movement.get("source_model", "lane"))
	var duration := maxf(0.01, ends_at - starts_at)
	match model:
		"lane":
			return 42.0 * delta / duration
		"ring":
			var center := RunSceneClass.room_space_position(movement.get("center", [0.5, 0.5]) as Array)
			var maximum_radius := 0.0
			for raw_position in motif.get("base_positions", []) as Array:
				maximum_radius = maxf(maximum_radius, Vector2(raw_position).distance_to(center))
			return maximum_radius * absf(float(movement.get("angular_rate", 0.0))) * delta
		"sweep":
			return 84.0 * delta / duration
		"pocket":
			return 12.0 * PI * delta / duration
		"replay":
			return 28.0 * delta / duration
		_:
			return 0.0


func _test_hitch_delta_swept_clearance(run: Node) -> void:
	var ring_center := RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()
	var duration := 0.5
	var motif: Dictionary = {
		"collision": {
			"enabled": true,
			"shape": "arc",
			"radius_normalized": 0.08,
			"thickness_normalized": 0.02,
		},
		"spawn": {"visual_token": "hitch_sweep_regression"},
		"movement": {
			"source_model": "ring",
			"center": [0.5, 0.5],
			"angular_rate": TAU / duration,
		},
		"base_positions": [ring_center + Vector2(100.0, 0.0)],
		"positions": [ring_center + Vector2(100.0, 0.0)],
		"safe_position": ring_center - Vector2(100.0, 0.0),
		"safe_clearance_pixels": 34.0,
		"starts_at": 0.0,
		"ends_at": duration,
		"motion_sample_time": 0.0,
		"emitter_active": true,
	}
	var end_positions := _vector_positions(run._moved_room_positions(motif, 1.0, duration) as Array)
	var midpoint_positions := _vector_positions(run._moved_room_positions(motif, 0.5, duration * 0.5) as Array)
	var start_clearance := _motif_safe_disk_clearance(motif)
	var end_clearance := _motif_clearance_at_positions(motif, end_positions)
	var midpoint_clearance := _motif_clearance_at_positions(motif, midpoint_positions)
	_check(start_clearance >= 0.5 and end_clearance >= 0.5 and midpoint_clearance < -0.25, "Hitch regression fixture must be safe at both endpoints and unsafe mid-sweep (%.2f/%.2f/%.2f)" % [start_clearance, midpoint_clearance, end_clearance])
	var advanced: Dictionary = run._advance_room_motif_geometry(motif.duplicate(true), duration, 0.0, duration)
	var advanced_time := float(advanced.get("motion_sample_time", 0.0))
	var minimum_swept_clearance := INF
	for sample_index in range(97):
		var sample_time := lerpf(0.0, advanced_time, float(sample_index) / 96.0)
		var progress := clampf(sample_time / duration, 0.0, 1.0)
		var sample_positions := _vector_positions(run._moved_room_positions(motif, progress, sample_time) as Array)
		minimum_swept_clearance = minf(minimum_swept_clearance, _motif_clearance_at_positions(motif, sample_positions))
	_check(minimum_swept_clearance >= -0.25, "A hitch-sized ring/arc update must not skip across an unsafe intermediate sweep (advanced %.3fs, minimum %.2fpx)" % [advanced_time, minimum_swept_clearance])
	_check(_motif_safe_disk_clearance(advanced) >= -0.25, "Hitch-sized motif advancement must finish on shape-aware safe geometry (%.2fpx)" % _motif_safe_disk_clearance(advanced))
	var extreme := motif.duplicate(true)
	var extreme_movement := extreme.get("movement", {}) as Dictionary
	extreme_movement["angular_rate"] = TAU * 10.0 / duration
	extreme["movement"] = extreme_movement
	var extreme_before_positions := _vector_positions(extreme.get("positions", []) as Array)
	var extreme_before_time := float(extreme.get("motion_sample_time", 0.0))
	var required_substeps := ceili(100.0 * absf(float(extreme_movement.get("angular_rate", 0.0))) * duration / 0.5)
	_check(required_substeps > 8192 and int(run._room_motif_sweep_substeps(extreme, 0.0, duration, 0.0, duration)) == 0, "Extreme ring fixture must exceed the hard 8192 swept-substep CPU cap")
	var frozen_extreme: Dictionary = run._advance_room_motif_geometry(extreme, duration, 0.0, duration)
	_check(is_equal_approx(float(frozen_extreme.get("motion_sample_time", -1.0)), extreme_before_time) and _positions_within(_vector_positions(frozen_extreme.get("positions", []) as Array), extreme_before_positions, 0.001), "A ring motion exceeding the swept-substep CPU cap must fail closed with unchanged positions and time")


func _test_impossible_structural_geometry_fails_closed(run: Node, rooms: Array) -> void:
	var reference_room := _room_for_hazard(rooms, "closing_membranes")
	_check(_prepare_room(run, reference_room, 0x5AFE11), "Impossible structural-geometry fixture must prepare a live room")
	var safe_center := RunSceneClass.INTERNAL_COMBAT_BOUNDS.get_center()
	var safe_radius := 34.0
	var wave_id := "room:qa_impossible_structural:0:991"
	var impossible_event: Dictionary = {
		"index": 991,
		"active_at": 0.1,
		"clear_at": 0.6,
		"runtime_active_seconds": 0.5,
		"runtime_wave_id": wave_id,
		"visual_signature": "qa_impossible_structural",
		"safe": {
			"position": [0.5, 0.5],
			"clearance": safe_radius / minf(RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.x, RunSceneClass.INTERNAL_COMBAT_BOUNDS.size.y),
		},
		"movement": {
			"source_model": "lane",
			"primitive": "lane_step",
		},
		"spawn": {
			"primitive": "paired_barrier",
			"visual_token": "qa_impossible_wall",
			"positions": [{"position": [0.5, 0.5]}],
			"hazard_count": 1,
			"enemy_count": 0,
			"max_active_enemies": 0,
			"defender_archetype": "none",
			"collision": {
				"enabled": true,
				"shape": "box",
				"half_extents_normalized": [2.0, 2.0],
				"damage": 999.0,
			},
		},
		"projectile": {
			"enabled": false,
			"count": 0,
			"max_active": 0,
		},
		"operations": [{"op": "hold_structural_hazard"}],
	}
	var initial_positions: Array[Vector2] = [safe_center]
	var rejected_positions: Array[Vector2] = run._room_structural_safe_start_positions(impossible_event, initial_positions, safe_center, safe_radius)
	_check(rejected_positions.is_empty(), "An enabled structural collider with no in-bounds safe placement must return an empty geometry set")
	var start_health := float(run._player.health)
	var cause_start := damage_causes.size()
	run._spawn_contract_pattern(impossible_event)
	run._update_active_room_motifs(0.5)
	var rejected_trace := _last_trace(run._room_runtime_trace, "structural_geometry_rejected")
	_check(String(rejected_trace.get("wave_id", "")) == wave_id and String(rejected_trace.get("reason", "")) == "no_safe_placement", "Impossible structural activation must trace structural_geometry_rejected/no_safe_placement")
	_check(not run._active_room_waves.has(wave_id) and not run._active_room_motifs.has(wave_id), "Rejected structural activation must create no wave or motif")
	_check(run._projectiles.enemy_group_size(wave_id) == 0 and _enemy_source_wave_count(run._enemies, wave_id) == 0 and _pending_owner_count(run._pending_room_emissions, wave_id) == 0, "Rejected structural activation must create no projectile, defender, or delayed descendant")
	_check(is_equal_approx(float(run._player.health), start_health) and damage_causes.size() == cause_start, "Rejected structural activation must never damage the player")
	_check(not _trace_has_wave_operation(run._room_runtime_trace, "activated", wave_id), "Rejected structural geometry must never emit an activated trace")
	run._clear_contract_waves()


func _test_execution_context_integrity(run: Node, rooms: Array) -> void:
	var room := _room_for_hazard(rooms, "falling_cells")
	var original_difficulty := String(run.config.get("difficulty", "deep"))
	run.config.difficulty = "deep"
	var first := _capture_first_telegraph(run, room, 0x71A11, 1.0 / 60.0)
	var repeated := _capture_first_telegraph(run, room, 0x71A11, 1.0 / 60.0)
	var thirty_hz := _capture_first_telegraph(run, room, 0x71A11, 1.0 / 30.0)
	_check(bool(first.get("armed", false)) and bool(repeated.get("armed", false)) and bool(thirty_hz.get("armed", false)), "Execution-context determinism probes must arm a telegraph")
	_check(String(first.get("digest", "")) == String(repeated.get("digest", "")), "Identical room context must reproduce the exact execution digest")
	_check(String(first.get("digest", "")) == String(thirty_hz.get("digest", "")), "Execution-context digest must be deterministic at 30/60 Hz for identical input")
	var first_payload := first.get("payload", {}) as Dictionary
	var first_event := first.get("event", {}) as Dictionary
	var executable_blocks := first_payload.get("event", {}) as Dictionary
	_check(executable_blocks.get("spawn", {}) == first_event.get("spawn", {}) and executable_blocks.get("projectile", {}) == first_event.get("projectile", {}), "Frozen execution context must contain exact spawn and projectile blocks")
	_check(executable_blocks.get("movement", {}) == first_event.get("movement", {}) and executable_blocks.get("safe", {}) == first_event.get("safe", {}), "Frozen execution context must contain exact movement and safe blocks")
	_check(executable_blocks.get("operations", []) == first_event.get("operations", []), "Frozen execution context must contain the exact executable operations list")
	var first_specs := first_event.get("runtime_projectile_specs",[]) as Array
	var first_previews := first_event.get("runtime_projectile_previews",[]) as Array
	_check(not first_specs.is_empty() and first_previews.size()==first_specs.size(),"Projectile telegraph must freeze exactly one preview per runtime spec")
	_check(first_payload.get("runtime_projectile_previews",[])==first_previews,"Execution envelope must sign the exact bounded projectile preview data")
	_check(RunSceneClass._room_projectile_previews_valid(first_specs,first_previews),"Signed runtime projectile previews must pass the production finite/order/cap validator")
	var snapshot_data := first_event.get("runtime_player_snapshot",[]) as Array
	var snapshot := Vector2(float(snapshot_data[0]),float(snapshot_data[1])) if snapshot_data.size()==2 else Vector2(NAN,NAN)
	var every_target_frozen := is_finite(snapshot.x) and is_finite(snapshot.y)
	for raw_spec in first_specs:
		every_target_frozen=every_target_frozen and Vector2(((raw_spec as Dictionary).get("options",{}) as Dictionary).get("frozen_target",Vector2(NAN,NAN))).is_equal_approx(snapshot)
	_check(every_target_frozen,"Every signed projectile spec must freeze the exact telegraph-time player snapshot")
	run.config.difficulty = "abyss"
	var changed_difficulty := _capture_first_telegraph(run, room, 0x71A11, 1.0 / 60.0)
	_check(String(first.get("digest", "")) != String(changed_difficulty.get("digest", "")), "A consumed difficulty/speed context change must change the execution digest")
	run.config.difficulty = original_difficulty

	var runtime_spec_case := _capture_first_telegraph(run, room, 0x71A12, 1.0 / 60.0)
	_check(bool(runtime_spec_case.get("armed", false)), "Runtime projectile-spec tamper case must arm")
	var runtime_spec_event := run._telegraph.get("event", {}) as Dictionary
	var runtime_specs := runtime_spec_event.get("runtime_projectile_specs", []) as Array
	_check(not runtime_specs.is_empty(), "Runtime projectile-spec tamper case requires frozen projectile specs")
	if not runtime_specs.is_empty():
		var runtime_spec := (runtime_specs[0] as Dictionary).duplicate(true)
		runtime_spec.velocity = Vector2(runtime_spec.get("velocity", Vector2.ZERO)) + Vector2(37.0, -19.0)
		runtime_specs[0] = runtime_spec
		runtime_spec_event.runtime_projectile_specs = runtime_specs
		run._telegraph.event = runtime_spec_event
		_finish_current_telegraph(run, Vector2(runtime_spec_case.get("safe_position", Vector2.ZERO)), 1.0 / 60.0)
		_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected") == 1, "Mutating a frozen runtime projectile spec must reject activation exactly once")
		_check(_room_activation_side_effects(run) == 0, "Rejected runtime projectile-spec tamper must create no wave, motif, actor, bullet, or pending emission")

	var preview_case := _capture_first_telegraph(run, room, 0x71A17, 1.0 / 60.0)
	_check(bool(preview_case.get("armed",false)),"Runtime projectile-preview tamper case must arm")
	var preview_event := run._telegraph.get("event",{}) as Dictionary
	var previews := preview_event.get("runtime_projectile_previews",[]) as Array
	_check(not previews.is_empty() and not ((previews[0] as Dictionary).get("samples",[]) as Array).is_empty(),"Runtime projectile-preview tamper case requires frozen render samples")
	if not previews.is_empty() and not ((previews[0] as Dictionary).get("samples",[]) as Array).is_empty():
		var preview := (previews[0] as Dictionary).duplicate(true)
		var samples := preview.get("samples",[]) as Array
		var sample_index := mini(1,samples.size()-1)
		var sample := (samples[sample_index] as Dictionary).duplicate(true)
		sample.position=Vector2(sample.position)+Vector2(19.0,-7.0)
		samples[sample_index]=sample
		preview.samples=samples
		previews[0]=preview
		preview_event.runtime_projectile_previews=previews
		run._telegraph.event=preview_event
		_finish_current_telegraph(run,Vector2(preview_case.get("safe_position",Vector2.ZERO)),1.0/60.0)
		_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected")==1,"Mutating a signed projectile-preview point must reject activation exactly once")
		_check(_room_activation_side_effects(run)==0,"Rejected projectile-preview tamper must create zero activation side effects")

	var frozen_target_case := _capture_first_telegraph(run,room,0x71A18,1.0/60.0)
	_check(bool(frozen_target_case.get("armed",false)),"Frozen-target tamper case must arm")
	var frozen_target_event := run._telegraph.get("event",{}) as Dictionary
	var frozen_target_specs := frozen_target_event.get("runtime_projectile_specs",[]) as Array
	if not frozen_target_specs.is_empty():
		var frozen_target_spec := (frozen_target_specs[0] as Dictionary).duplicate(true)
		var frozen_options := (frozen_target_spec.get("options",{}) as Dictionary).duplicate(true)
		frozen_options.frozen_target=Vector2(frozen_options.get("frozen_target",Vector2.ZERO))+Vector2(23.0,11.0)
		frozen_target_spec.options=frozen_options
		frozen_target_specs[0]=frozen_target_spec
		frozen_target_event.runtime_projectile_specs=frozen_target_specs
		run._telegraph.event=frozen_target_event
		_finish_current_telegraph(run,Vector2(frozen_target_case.get("safe_position",Vector2.ZERO)),1.0/60.0)
		_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected")==1 and _room_activation_side_effects(run)==0,"Mutating a frozen preview target must fail its signed execution envelope before activation")

	var stable_case := _capture_first_telegraph(run,room,0x71A19,1.0/60.0)
	_check(bool(stable_case.get("armed",false)),"Per-frame preview immutability case must arm")
	var stable_event := run._telegraph.get("event",{}) as Dictionary
	var stable_preview_digest := RunSceneClass.room_runtime_canonical_digest("preview-frame-stability",stable_event.get("runtime_projectile_previews",[]))
	var active_before: int = run._projectiles.enemy_active.size()
	var free_before: int = run._projectiles._enemy_free.size()
	for _frame in 3:
		run._player.place_at(Vector2(stable_case.get("safe_position",Vector2.ZERO)))
		run._room_previous_player_position=run._player.position
		_step_live_room(run,1.0/60.0)
	var stable_after := run._telegraph.get("event",{}) as Dictionary
	_check(not run._telegraph.is_empty() and RunSceneClass.room_runtime_canonical_digest("preview-frame-stability",stable_after.get("runtime_projectile_previews",[]))==stable_preview_digest,"Telegraph frames must reuse the once-frozen preview without recomputation or mutation")
	_check(run._projectiles.enemy_active.size()==active_before and run._projectiles._enemy_free.size()==free_before,"Rendering-time preview reuse must not consume, release or add projectile-pool entries per frame")

	var spawn_case := _capture_first_telegraph(run, room, 0x71A13, 1.0 / 60.0)
	_check(bool(spawn_case.get("armed", false)), "Spawn collision tamper case must arm")
	var spawn_event := run._telegraph.get("event", {}) as Dictionary
	var spawn_block := spawn_event.get("spawn", {}) as Dictionary
	var collision := spawn_block.get("collision", {}) as Dictionary
	collision.damage = float(collision.get("damage", 1.0)) + 0.25
	spawn_block.collision = collision
	spawn_event.spawn = spawn_block
	spawn_event.geometry_signature = Runtime.geometry_signature_for_event(spawn_event)
	run._telegraph.event = spawn_event
	_finish_current_telegraph(run, Vector2(spawn_case.get("safe_position", Vector2.ZERO)), 1.0 / 60.0)
	_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected") == 1 and _room_activation_side_effects(run) == 0, "A re-signed spawn.collision.damage mutation must fail closed before activation")

	var movement_case := _capture_first_telegraph(run, room, 0x71A14, 1.0 / 60.0)
	_check(bool(movement_case.get("armed", false)), "Movement tamper case must arm")
	var movement_event := run._telegraph.get("event", {}) as Dictionary
	var movement_block := movement_event.get("movement", {}) as Dictionary
	movement_block.primitive = "%s_tampered" % String(movement_block.get("primitive", "movement"))
	movement_event.movement = movement_block
	movement_event.geometry_signature = Runtime.geometry_signature_for_event(movement_event)
	run._telegraph.event = movement_event
	_finish_current_telegraph(run, Vector2(movement_case.get("safe_position", Vector2.ZERO)), 1.0 / 60.0)
	_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected") == 1 and _room_activation_side_effects(run) == 0, "A re-signed movement.primitive mutation must fail closed before activation")

	var operations_case := _capture_first_telegraph(run, room, 0x71A16, 1.0 / 60.0)
	_check(bool(operations_case.get("armed", false)), "Executable operations tamper case must arm")
	var operations_event := run._telegraph.get("event", {}) as Dictionary
	var operations := operations_event.get("operations", []) as Array
	_check(not operations.is_empty(), "Executable operations tamper case requires a compiled operation")
	if not operations.is_empty():
		var operation := (operations[0] as Dictionary).duplicate(true)
		operation.op = "hold_structural_hazard"
		operations[0] = operation
		operations_event.operations = operations
		operations_event.geometry_signature = Runtime.geometry_signature_for_event(operations_event)
		run._telegraph.event = operations_event
		_finish_current_telegraph(run, Vector2(operations_case.get("safe_position", Vector2.ZERO)), 1.0 / 60.0)
		_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected") == 1 and _room_activation_side_effects(run) == 0, "A re-signed emit-to-structural operation mutation must fail closed before collision or safe-placement side effects")

	var plan_case := _capture_first_telegraph(run, room, 0x71A15, 1.0 / 60.0)
	_check(bool(plan_case.get("armed", false)), "Re-signed plan tamper case must arm")
	var mutated_plan := run._room_pattern_plan.duplicate(true) as Dictionary
	var plan_events := mutated_plan.get("events", []) as Array
	var plan_event := plan_events[0] as Dictionary
	var plan_projectile := plan_event.get("projectile", {}) as Dictionary
	plan_projectile.damage = float(plan_projectile.get("damage", 1.0)) + 0.125
	plan_event.projectile = plan_projectile
	plan_event.geometry_signature = Runtime.geometry_signature_for_event(plan_event)
	plan_event.lifecycle_signature = Runtime.lifecycle_signature_for_event(plan_event)
	plan_events[0] = plan_event
	mutated_plan.events = plan_events
	mutated_plan.geometry_signature = Runtime.geometry_signature_for_plan(mutated_plan)
	mutated_plan.lifecycle_signature = Runtime.lifecycle_signature_for_plan(mutated_plan)
	mutated_plan.plan_signature = Runtime.plan_signature_for_plan(mutated_plan)
	run._room_pattern_plan = mutated_plan
	_finish_current_telegraph(run, Vector2(plan_case.get("safe_position", Vector2.ZERO)), 1.0 / 60.0)
	_check(_trace_operations(run._room_runtime_trace).count("execution_context_rejected") == 1 and _room_activation_side_effects(run) == 0, "A fully re-signed live plan mutation must still fail its frozen execution envelope")


func _test_projectile_preview_runtime_parity(run: Node) -> void:
	run.projectiles_clear_and_enemies()
	run._reset_room_defender_effects()
	var no_world_positions: Array[Vector2] = []
	for model in PROJECTILE_TRAVEL_MODELS:
		var event := _preview_fixture_event(run,model)
		var safe_data := (event.get("safe",{}) as Dictionary).get("position",[0.5,0.5]) as Array
		var safe_position := RunSceneClass.room_space_position(safe_data)
		var built: Dictionary = run._build_room_projectile_specs(event,no_world_positions,safe_position,1.1)
		var specs := built.get("specs",[]) as Array
		var previews := run._build_room_projectile_previews(specs) as Array
		_check(not specs.is_empty() and previews.size()==specs.size(),"%s integration fixture must build one bounded preview per runtime projectile spec" % model)
		_check(RunSceneClass._room_projectile_previews_valid(specs,previews),"%s integration previews must be finite, ordered and within render-data caps" % model)
		event.runtime_projectile_specs=specs.duplicate(true)
		event.runtime_projectile_previews=previews.duplicate(true)
		event.runtime_projectile_seconds=float(built.get("follow_through_seconds",1.1))
		event.runtime_projectile_threat_seconds=float(built.get("threat_seconds",0.0))
		event.runtime_threat_position=built.get("threat_position",[])
		var digest: String = run._freeze_room_execution_context(event)
		var validation := run._validate_room_execution_context(event) as Dictionary
		_check(not digest.is_empty() and bool(validation.get("valid",false)),"%s runtime preview and frozen target must be covered by a valid execution signature" % model)
		var payload := event.get("runtime_execution_context",{}) as Dictionary
		_check(payload.get("runtime_projectile_previews",[])==previews,"%s execution payload must freeze the exact render preview" % model)
		var snapshot_data := event.get("runtime_player_snapshot",[]) as Array
		var snapshot := Vector2(float(snapshot_data[0]),float(snapshot_data[1]))
		var targets_match := true
		for raw_spec in specs:
			targets_match=targets_match and Vector2(((raw_spec as Dictionary).get("options",{}) as Dictionary).get("frozen_target",Vector2(NAN,NAN))).is_equal_approx(snapshot)
		_check(targets_match,"%s every runtime spec must target the signed telegraph-time player snapshot" % model)
		if model=="delayed_linear":
			var has_delayed_offset := false
			for preview_index in range(previews.size()):
				var preview := previews[preview_index] as Dictionary
				var spec := specs[preview_index] as Dictionary
				var delay := float(preview.get("delay_seconds",0.0))
				has_delayed_offset=has_delayed_offset or delay>0.0
				_check(is_equal_approx(delay,float(spec.get("delay_seconds",0.0))),"Delayed-linear render metadata must preserve each authored emission offset")
			_check(has_delayed_offset,"Delayed-linear preview fixture must exercise a positive visual emission offset")
		var parity_index := 1 if model=="delayed_linear" and specs.size()>1 else 0
		for fps in [30,60]:
			var parity := _runtime_projectile_preview_parity(run,specs[parity_index] as Dictionary,previews[parity_index] as Dictionary,fps,0.8)
			_check(bool(parity.get("live",false)),"%s preview parity projectile must remain live through 0.8 seconds at %d Hz" % [model,fps])
			_check(float(parity.get("position_delta",INF))<0.05,"%s signed preview endpoint must match the live projectile at %d Hz (delta %.5f)" % [model,fps,float(parity.get("position_delta",INF))])
			_check(float(parity.get("radius_delta",INF))<0.001,"%s signed preview radius must match the live projectile at %d Hz" % [model,fps])
			_check(bool(parity.get("target_frozen",false)),"%s live projectile must retain the signed frozen target at %d Hz" % [model,fps])
	run.projectiles_clear_and_enemies()
	run._reset_room_defender_effects()


func _test_projectile_preview_rejection(run: Node, rooms: Array) -> void:
	run.projectiles_clear_and_enemies()
	var real_pool: ProjectilePool = run._projectiles
	var pool_parent := real_pool.get_parent()
	pool_parent.remove_child(real_pool)
	var malformed_pool := MalformedPreviewPool.new()
	pool_parent.add_child(malformed_pool)
	run._projectiles=malformed_pool
	var room := _room_for_hazard(rooms,"falling_cells")
	var prepared := _prepare_room(run,room,0xBADC0DE)
	var health_before := float(run._player.health)
	if prepared:
		var events := run._room_pattern_plan.get("events",[]) as Array
		var event := events[0] as Dictionary
		var safe_position := RunSceneClass.room_space_position((event.get("safe",{}) as Dictionary).get("position",[0.5,0.5]) as Array)
		for _frame in 720:
			run._player.place_at(safe_position)
			run._room_previous_player_position=safe_position
			_step_live_room(run,1.0/60.0)
			if _trace_operations(run._room_runtime_trace).count("projectile_preview_rejected")>0:
				break
	_check(prepared,"Malformed-preview fail-closed fixture must prepare a compiled projectile room")
	_check(_trace_operations(run._room_runtime_trace).count("projectile_preview_rejected")==1,"Malformed or incomplete preview data must trace exactly one projectile_preview_rejected event")
	_check(run._telegraph.is_empty(),"A projectile event without a complete finite preview must never arm a telegraph")
	_check(_room_activation_side_effects(run)==0 and is_equal_approx(float(run._player.health),health_before),"Rejected preview generation must create zero spawn, projectile, wave, pending-emission or damage side effects")
	run.projectiles_clear_and_enemies()
	pool_parent.remove_child(malformed_pool)
	malformed_pool.free()
	pool_parent.add_child(real_pool)
	run._projectiles=real_pool
	run._clear_contract_waves()


func _test_post_activation_preview_effect_monotonicity(run: Node) -> void:
	run.projectiles_clear_and_enemies()
	run._reset_room_defender_effects()
	var no_world_positions: Array[Vector2] = []
	var scope_id := "room-effect:preview-monotonic"
	var wave_id := "room:preview-monotonic:cycle:0"
	var foreign_wave_id := "room:preview-foreign:cycle:0"
	var soft_event := _preview_fixture_event(run,"soft_homing")
	var safe_position := RunSceneClass.room_space_position((soft_event.get("safe",{}) as Dictionary).get("position",[0.5,0.5]) as Array)
	var soft_specs := (run._build_room_projectile_specs(soft_event,no_world_positions,safe_position,1.1).get("specs",[]) as Array)
	var soft_spec := (soft_specs[0] as Dictionary).duplicate(true)
	var soft_options := (soft_spec.get("options",{}) as Dictionary).duplicate(true)
	soft_options.group=wave_id
	soft_options.parent_group=wave_id
	soft_options.effect_scope_id=scope_id
	soft_options.source_archetype="tracking_mite"
	soft_options.cause="preview-monotonic-soft"
	soft_spec.options=soft_options
	soft_spec.delay_seconds=0.1
	var emission_event := {
		"index":91,
		"runtime_canonical_wave_id":"preview-monotonic",
		"runtime_execution_context_digest":"room-execution-v2:preview-monotonic",
		"runtime_effect_scope_id":scope_id,
		"spawn":{"defender_archetype":"tracking_mite"},
	}
	var soft_emission := run._freeze_room_emission(soft_spec,emission_event,wave_id,0,run._room_elapsed+0.1) as Dictionary
	_check(run._projectiles.spawn_enemy(Vector2(110.0,250.0),Vector2.RIGHT*210.0,7.0,soft_options),"Tracking suppression fixture must spawn its owned warned homing projectile")
	var linear_options := soft_options.duplicate(true)
	linear_options.travel_model="linear"
	linear_options.homing=0.0
	_check(run._projectiles.spawn_enemy(Vector2(110.0,280.0),Vector2.RIGHT*210.0,7.0,linear_options),"Tracking suppression fixture must spawn an owned non-homing control projectile")
	var foreign_options := soft_options.duplicate(true)
	foreign_options.group=foreign_wave_id
	foreign_options.parent_group=foreign_wave_id
	_check(run._projectiles.spawn_enemy(Vector2(110.0,310.0),Vector2.RIGHT*210.0,7.0,foreign_options),"Tracking suppression fixture must spawn a foreign homing control projectile")
	run._room_defender_effect_state={"scopes":{scope_id:{"owner_wave_id":wave_id,"flags":{"tracking_disabled":1.0},"timers":{},"tags":{},"values":{}}},"kill_effects_applied":1}
	run._room_runtime_trace.clear()
	var cleared := int((run._execute_room_defender_operation({"op":"disable_tracking","owner_wave_id":wave_id}) as Dictionary).get("affected",-1))
	_check(cleared==1,"Post-activation tracking break must remove exactly the warned wave's active soft-homing path")
	_check(run._projectiles.enemy_group_size(wave_id)==1,"Tracking break must retain the owned linear control instead of rewriting or clearing unrelated travel models")
	_check(run._projectiles.enemy_group_size(foreign_wave_id)==1,"Tracking break must never clear a foreign wave's homing path")
	var soft_spawned: bool = run._spawn_room_projectile_spec(soft_emission)
	_check(not soft_spawned,"A pending soft-homing emission under tracking_disabled must be suppressed, never straightened into a new path")
	_check(run._projectiles.enemy_group_size(wave_id)==1,"Suppressed pending homing must not add a replacement projectile")
	_check(_trace_operations(run._room_runtime_trace).count("tracking_projectiles_suppressed")==1 and _trace_operations(run._room_runtime_trace).count("emission_suppressed")==1,"Active and pending tracking suppression must both remain auditable")
	run._projectiles.clear_enemy()
	run._reset_room_defender_effects()
	var node_event := _preview_fixture_event(run,"node_link")
	var node_specs := (run._build_room_projectile_specs(node_event,no_world_positions,safe_position,1.1).get("specs",[]) as Array)
	var node_spec := (node_specs[0] as Dictionary).duplicate(true)
	var node_options := (node_spec.get("options",{}) as Dictionary).duplicate(true)
	node_options.group=wave_id
	node_options.parent_group=wave_id
	node_options.effect_scope_id=scope_id
	node_options.source_archetype="arc_linker"
	node_spec.options=node_options
	var node_emission := run._freeze_room_emission(node_spec,emission_event,wave_id,1,run._room_elapsed+0.1) as Dictionary
	run._room_defender_effect_state={"scopes":{scope_id:{"flags":{"link_broken":1.0},"timers":{},"tags":{},"values":{}}},"kill_effects_applied":1}
	run._room_runtime_trace.clear()
	var node_spawned: bool = run._spawn_room_projectile_spec(node_emission)
	_check(not node_spawned and run._projectiles.enemy_active.is_empty(),"A post-activation link break may suppress the warned node-link projectile but must never replace it with a new path")
	_check(_trace_operations(run._room_runtime_trace).count("emission_suppressed")==1,"Suppressed safer post-activation emission must remain auditable")
	run._reset_room_defender_effects()


func _test_pending_emission_integrity(run: Node, rooms: Array) -> void:
	var room := _room_for_hazard(rooms, "delayed_clone_fire")
	var capture := _capture_first_activation(run, room, 0xD31A7, 1.0 / 60.0)
	_check(bool(capture.get("activated", false)) and not run._pending_room_emissions.is_empty(), "Delayed-emission integrity case must activate with queued emissions")
	if run._pending_room_emissions.is_empty():
		return
	var emission_trace := _last_trace(run._room_runtime_trace, "emit_projectiles")
	_check(not (emission_trace.get("emission_digests", []) as Array).is_empty() and not (emission_trace.get("effect_state_digests", []) as Array).is_empty(), "Projectile trace must expose deterministic emission and defender-effect digests")
	var pending_index := 0
	var earliest_spawn := INF
	for index in range(run._pending_room_emissions.size()):
		var candidate := run._pending_room_emissions[index] as Dictionary
		var spawn_time := float(candidate.get("spawn_at_room_time", INF))
		if spawn_time < earliest_spawn:
			earliest_spawn = spawn_time
			pending_index = index
	var pending := run._pending_room_emissions[pending_index] as Dictionary
	var emission_index := int(pending.get("emission_index", -1))
	var queued_digest := String(pending.get("emission_digest", ""))
	var pending_spec := pending.get("spec", {}) as Dictionary
	pending_spec.origin = Vector2(pending_spec.get("origin", Vector2.ZERO)) + Vector2(91.0, 0.0)
	pending.spec = pending_spec
	run._pending_room_emissions[pending_index] = pending
	var rejected_before := _trace_operations(run._room_runtime_trace).count("emission_rejected")
	run._room_elapsed = earliest_spawn
	run._update_pending_room_emissions(0.0)
	_check(_trace_operations(run._room_runtime_trace).count("emission_rejected") == rejected_before + 1, "A delayed pending-spec mutation must be authenticated and rejected by the live spawn path")
	_check(not _trace_has_emission_spawn(run._room_runtime_trace, emission_index, queued_digest), "A rejected delayed emission must never create the tampered trajectory")
	_check(_first_cap_error(run).is_empty(), "Pending-emission rejection must preserve runtime caps and ownership")


func _test_runtime_owner_identity(run: Node, rooms: Array) -> void:
	var room := _room_for_hazard(rooms, "falling_cells")
	var first := _capture_first_activation(run, room, 0x0A11CE, 1.0 / 60.0, 0)
	var repeated := _capture_first_activation(run, room, 0x0A11CE, 1.0 / 60.0, 0)
	var later_cycle := _capture_first_activation(run, room, 0x0A11CE, 1.0 / 60.0, 3)
	var changed_seed := _capture_first_activation(run, room, 0x0A11CF, 1.0 / 60.0, 0)
	_check(bool(first.get("activated", false)) and bool(repeated.get("activated", false)) and bool(later_cycle.get("activated", false)) and bool(changed_seed.get("activated", false)), "Owner identity probes must all activate")
	var first_activation := first.get("activation", {}) as Dictionary
	var repeated_activation := repeated.get("activation", {}) as Dictionary
	var cycle_activation := later_cycle.get("activation", {}) as Dictionary
	var seed_activation := changed_seed.get("activation", {}) as Dictionary
	var canonical_owner := String(first_activation.get("canonical_wave_id", ""))
	_check(not canonical_owner.is_empty() and String(first_activation.get("live_wave_id", "")) == "room:%s:cycle:0" % canonical_owner, "Live owner must derive from the compiler-signed owner plus cycle suffix")
	_check(first_activation.get("canonical_wave_id", "") == repeated_activation.get("canonical_wave_id", "") and first_activation.get("live_wave_id", "") == repeated_activation.get("live_wave_id", ""), "Same seed and cycle must reproduce canonical and live owners")
	_check(String(cycle_activation.get("canonical_wave_id", "")) == canonical_owner and String(cycle_activation.get("live_wave_id", "")) == "room:%s:cycle:3" % canonical_owner, "Cycle identity must change only the live-owner suffix")
	_check(String(seed_activation.get("canonical_wave_id", "")) != canonical_owner and String(seed_activation.get("live_wave_id", "")) != String(first_activation.get("live_wave_id", "")), "Changing the event seed must change signed canonical and live owner identity")
	var active_wave := String(changed_seed.get("wave_id", ""))
	var foreign_wave := "room:qa_foreign_signed_owner:cycle:77"
	_check(run._projectiles.spawn_enemy(Vector2(40.0, 40.0), Vector2.RIGHT * 10.0, 1.0, {"group":foreign_wave, "parent_group":foreign_wave, "life":5.0}), "Cleanup-isolation fixture must spawn a foreign projectile")
	run._finalize_room_wave(active_wave, "owner_identity_probe")
	_check(run._projectiles.enemy_group_size(active_wave) == 0 and run._projectiles.enemy_group_size(foreign_wave) == 1, "Finalizing a signed live owner must not clear a foreign owner")
	run._projectiles.clear_enemy_group(foreign_wave)


func _test_rejection_latch(run: Node, rooms: Array) -> void:
	var room := _room_for_hazard(rooms, "falling_cells")
	_check(_prepare_room(run, room, 0x1A7C4), "Compiler rejection-latch case must begin from a valid contract")
	var original_projectile := (run._room_contract.get("projectile", {}) as Dictionary).duplicate(true)
	var original_seed := int(run._room_contract.get("runtime_seed", 0))
	var invalid_projectile := original_projectile.duplicate(true)
	invalid_projectile.damage = Runtime.MAX_PROJECTILE_DAMAGE + 1.0
	run._room_contract.projectile = invalid_projectile
	run._room_pattern_plan.clear()
	run._room_pattern_rejection_key = ""
	run._room_runtime_trace.clear()
	_check(not run._compile_room_pattern_plan(false) and not run._compile_room_pattern_plan(false), "The same invalid runtime contract must remain rejected")
	_check(_trace_operations(run._room_runtime_trace).count("plan_rejected") == 1, "The same invalid contract must compile and trace rejection only once")
	run._room_contract.runtime_seed = original_seed + 1
	_check(not run._compile_room_pattern_plan(false), "Changing an invalid contract seed must retry compilation")
	_check(_trace_operations(run._room_runtime_trace).count("plan_rejected") == 2, "A changed invalid contract key must produce exactly one new rejection trace")
	run._room_contract.projectile = original_projectile
	run._room_contract.runtime_seed = original_seed
	_check(run._compile_room_pattern_plan() and run._room_pattern_rejection_key.is_empty(), "Repairing the contract must clear the rejection latch and recover compilation")
	_check(_trace_operations(run._room_runtime_trace).count("plan_built") == 1, "Recovered contract compilation must emit one successful plan trace")


func _test_replay_input_dependency(run: Node, rooms: Array) -> void:
	var room := _room_for_hazard(rooms, "path_replay")
	var first := _capture_replay(run, room, 551903, 1.0 / 60.0, 0)
	var repeated := _capture_replay(run, room, 551903, 1.0 / 60.0, 0)
	var alternate := _capture_replay(run, room, 551903, 1.0 / 60.0, 1)
	var thirty_hz := _capture_replay(run, room, 551903, 1.0 / 30.0, 0)
	_check(bool(first.get("activated", false)) and bool(repeated.get("activated", false)) and bool(alternate.get("activated", false)) and bool(thirty_hz.get("activated", false)), "Replay dependency probes must all activate")
	_check(String(first.get("digest", "")) != "history:none", "Replay runtime must consume a non-empty player-history digest")
	_check(String(first.get("digest", "")) == String(repeated.get("digest", "")), "Same seed and input history must produce the same live replay digest")
	_check(first.get("positions", []) == repeated.get("positions", []), "Same seed and input history must reproduce identical live echo geometry")
	_check(String(first.get("digest", "")) != String(alternate.get("digest", "")), "Different player input must change the live replay digest")
	_check(first.get("positions", []) != alternate.get("positions", []), "Different player input must change live echo positions")
	_check(String(first.get("digest", "")) == String(thirty_hz.get("digest", "")), "The same continuous replay input must have a frame-rate-independent digest at 30/60 Hz")
	_check(first.get("positions", []) == thirty_hz.get("positions", []), "The same continuous replay input must reproduce identical echo geometry at 30/60 Hz")


func _test_atomic_cleanup(run: Node, rooms: Array) -> void:
	var cleaned := 0
	for room_index in range(rooms.size()):
		var room := rooms[room_index] as Dictionary
		var room_id := String(room.get("id", "room-%d" % room_index))
		var capture := _capture_first_activation(run, room, 772031 + room_index * 313, 1.0 / 60.0)
		_check(bool(capture.get("activated", false)), "%s atomic-cleanup case must activate" % room_id)
		if not bool(capture.get("activated", false)):
			continue
		var wave_id := String(capture.get("wave_id", ""))
		_check(_owner_entities(run, wave_id) > 0, "%s must own at least one motif/enemy/projectile/pending operation before cleanup" % room_id)
		_check(_all_descendants_owned_by(run, wave_id), "%s every live descendant must inherit the active wave owner" % room_id)
		run._clear_contract_waves()
		_check(not run._active_room_waves.has(wave_id), "%s atomic cleanup must remove the wave registry entry" % room_id)
		_check(run._active_room_actor_groups.is_empty(), "%s boundary cleanup must atomically remove independent defender actor owners" % room_id)
		_check(not run._active_room_motifs.has(wave_id), "%s atomic cleanup must remove its structural motif" % room_id)
		_check(run._projectiles.enemy_group_size(wave_id) == 0, "%s atomic cleanup must return every owned projectile" % room_id)
		_check(not _has_enemy_owner(run._enemies, wave_id), "%s atomic cleanup must remove every owned defender" % room_id)
		_check(not _has_pending_owner(run._pending_room_emissions, wave_id), "%s atomic cleanup must cancel every delayed emission" % room_id)
		cleaned += 1
	_check(cleaned == 42, "Atomic cleanup must execute for all 42 live profiles")

	var delayed_room := _room_for_hazard(rooms, "delayed_clone_fire")
	var delayed := _capture_first_activation(run, delayed_room, 900733, 1.0 / 60.0)
	_check(bool(delayed.get("activated", false)), "Delayed replay cleanup probe must activate")
	var delayed_wave := String(delayed.get("wave_id", ""))
	_check(_has_pending_owner(run._pending_room_emissions, delayed_wave), "Delayed replay must expose pending emissions before atomic cleanup")
	run.projectiles_clear_and_enemies()
	_check(run._active_room_waves.is_empty() and run._active_room_actor_groups.is_empty() and run._active_room_motifs.is_empty() and run._pending_room_emissions.is_empty(), "Whole-room cleanup must clear waves, actor owners, motifs, and delayed emissions")
	_check(run._projectiles.enemy_active.is_empty() and run._enemies.is_empty(), "Whole-room cleanup must clear projectiles and defenders")
	_check(run._room_pattern_plan.is_empty() and run._room_player_history.is_empty() and run._telegraph.is_empty(), "Whole-room cleanup must clear plan, history, and telegraph state")
	run._update_pending_room_emissions(1.0)
	_check(run._projectiles.enemy_active.is_empty(), "Cancelled delayed emissions must not resurrect after whole-room cleanup")

	var telegraph_room := _room_for_hazard(rooms, "closing_membranes")
	_check(_prepare_room(run, telegraph_room, 810221), "Mid-telegraph cleanup probe must prepare")
	for _frame in range(240):
		_step_live_room(run, 1.0 / 60.0)
		if not run._telegraph.is_empty():
			break
	_check(not run._telegraph.is_empty() and run._active_room_waves.is_empty(), "Mid-telegraph cleanup probe must stop before activation")
	run.projectiles_clear_and_enemies()
	_check(run._telegraph.is_empty() and run._room_pattern_plan.is_empty() and run._active_room_waves.is_empty() and run._projectiles.enemy_active.is_empty(), "Mid-telegraph whole-room cleanup must be atomic")

	var pool_room := _room_for_hazard(rooms, "mirrored_quadrants")
	var pool_before: int = run._projectiles._enemy_free.size() + run._projectiles.enemy_active.size()
	var first_pool_capture := _capture_first_activation(run, pool_room, 810991, 1.0 / 60.0)
	_check(bool(first_pool_capture.get("activated", false)), "Projectile-pool plateau probe must activate on first pass")
	run.projectiles_clear_and_enemies()
	var pool_after_first: int = run._projectiles._enemy_free.size() + run._projectiles.enemy_active.size()
	var second_pool_capture := _capture_first_activation(run, pool_room, 810991, 1.0 / 60.0)
	_check(bool(second_pool_capture.get("activated", false)), "Projectile-pool plateau probe must activate on repeated pass")
	run.projectiles_clear_and_enemies()
	var pool_after_second: int = run._projectiles._enemy_free.size() + run._projectiles.enemy_active.size()
	_check(pool_after_first >= pool_before and pool_after_second == pool_after_first, "Repeated identical room waves must reuse the projectile pool without allocation growth")


func _preview_fixture_event(run: Node, model: String) -> Dictionary:
	var count := 3 if model=="delayed_linear" else 1
	var owner_wave_id := "preview:%s" % model
	var model_index := PROJECTILE_TRAVEL_MODELS.find(model)
	var player_snapshot := Vector2(430.0,690.0)
	var event := {
		"index":70+model_index,
		"event_seed":0x510000+model_index,
		"owner_wave_id":owner_wave_id,
		"geometry_signature":"preview-geometry:%s" % model,
		"lifecycle_signature":"preview-lifecycle:%s" % model,
		"visual_signature":"preview-visual:%s" % model,
		"spawn":{
			"defender_archetype":"none",
			"collision":{"enabled":false},
			"positions":[],
		},
		"projectile":{
			"enabled":true,
			"primitive":"preview_probe",
			"count":count,
			"max_active":count,
			"emitters":[[0.12,0.28],[0.50,0.18],[0.88,0.28]],
			"directions_degrees":[0.0,90.0,180.0],
			"speed_pixels_per_second":180.0,
			"radius_pixels":7.0,
			"damage":8.0,
			"travel_model":model,
			"tracking_strength":0.9 if model=="soft_homing" else 0.0,
			"visual_token":"preview_%s" % model,
		},
		"movement":{},
		"safe":{"position":[0.5,0.5],"clearance":0.12},
		"operations":[{"op":"emit_projectiles"}],
		"runtime_active_seconds":1.1,
		"runtime_telegraph_seconds":0.45,
		"runtime_cycle_index":int(run._room_cycle_index),
		"runtime_canonical_wave_id":owner_wave_id,
		"runtime_difficulty_context":{
			"difficulty":"deep",
			"mode":"story",
			"abyss_depth":0,
			"competitive":false,
			"assist_telegraph":1.0,
			"assist_projectile_speed":1.0,
			"projectile_speed_multiplier":1.0,
		},
		"runtime_gap_x":270.0,
		"runtime_origin":[270.0,500.0],
		"runtime_player_snapshot":[player_snapshot.x,player_snapshot.y],
		"runtime_player_history_snapshot":[],
		"runtime_world_positions":[],
		"runtime_effect_scope_id":"room-effect:preview:%s" % model,
		"runtime_actor_seconds":0.0,
		"runtime_wave_seconds":1.1,
		"runtime_replay_digest":"history:none",
	}
	event.runtime_wave_id=run._room_live_wave_id(event,int(run._room_cycle_index))
	return event


func _runtime_projectile_preview_parity(run: Node, spec: Dictionary, preview: Dictionary, fps: int, sample_age: float) -> Dictionary:
	run._projectiles.clear_enemy()
	var samples := preview.get("samples",[]) as Array
	var expected := _projectile_preview_sample_at(samples,sample_age)
	var options := (spec.get("options",{}) as Dictionary).duplicate(true)
	var spawned: bool = run._projectiles.spawn_enemy(
		Vector2(spec.get("origin",Vector2.ZERO)),
		Vector2(spec.get("velocity",Vector2.ZERO)),
		float(spec.get("damage",1.0)),
		options
	)
	var unexpected_hit := false
	if spawned:
		for _frame in int(round(sample_age*float(fps))):
			var result: Dictionary = run._projectiles.step(1.0/float(fps),[],Vector2(-1000.0,-1000.0),0.0)
			unexpected_hit=unexpected_hit or not (result.player_hits as Array).is_empty()
			if run._projectiles.enemy_active.is_empty():
				break
	var live: bool = spawned and not unexpected_hit and not expected.is_empty() and not run._projectiles.enemy_active.is_empty()
	var position_delta := INF
	var radius_delta := INF
	var target_frozen := false
	if live:
		var bullet := run._projectiles.enemy_active[0] as Dictionary
		position_delta=Vector2(bullet.position).distance_to(Vector2(expected.position))
		radius_delta=absf(float(bullet.radius)-float(expected.radius))
		target_frozen=bool(bullet.get("frozen_target_enabled",false)) and Vector2(bullet.frozen_target).is_equal_approx(Vector2(options.frozen_target))
	run._projectiles.clear_enemy()
	return {
		"live":live,
		"position_delta":position_delta,
		"radius_delta":radius_delta,
		"target_frozen":target_frozen,
	}


func _projectile_preview_sample_at(samples: Array, age: float) -> Dictionary:
	for raw_sample in samples:
		var sample := raw_sample as Dictionary
		if absf(float(sample.get("age",-1.0))-age)<0.00001:
			return sample
	return {}


func _prepare_room(run: Node, room: Dictionary, seed: int) -> bool:
	run.projectiles_clear_and_enemies()
	run._room_runtime_trace.clear()
	run.current_room = room.duplicate(true)
	run._room_contract = Mechanics.contract_for(room, seed)
	run._room_pattern_plan.clear()
	run._room_elapsed = 0.0
	run._room_event_index = 0
	run._room_cycle_index = 0
	run._room_history_next_sample = 0.0
	run._room_player_history.clear()
	run._room_previous_player_position = Vector2.ZERO
	run._enemy_serial = 0
	run._damage_taken_total = 0.0
	run.state = RunSceneClass.RunState.ORGAN_CHAMBER if String(room.get("type", "")) == "chamber" else RunSceneClass.RunState.INTERNAL_ROOMS
	run._player.combat_bounds = RunSceneClass.INTERNAL_COMBAT_BOUNDS
	run._place_player_at_room_entry()
	run._player.max_health = 10000.0
	run._player.health = 10000.0
	run._player.shield_hits = 0
	run._player.invulnerability = 0.0
	run._player.dash_time = 0.0
	run._player.set_controls_active(false)
	return bool(run._room_contract.get("valid", false)) and run._compile_room_pattern_plan()


func _capture_first_telegraph(run: Node, room: Dictionary, seed: int, delta: float, cycle_index: int = 0) -> Dictionary:
	if not _prepare_room(run, room, seed):
		return {"armed": false}
	run._room_cycle_index = cycle_index
	var events := run._room_pattern_plan.get("events", []) as Array
	if events.is_empty():
		return {"armed": false}
	var event := events[0] as Dictionary
	var safe_position := RunSceneClass.room_space_position((event.get("safe", {}) as Dictionary).get("position", [0.5, 0.5]) as Array)
	for _frame in range(720):
		run._player.place_at(safe_position)
		run._room_previous_player_position = safe_position
		_step_live_room(run, delta)
		if not run._telegraph.is_empty():
			var runtime_event := run._telegraph.get("event", {}) as Dictionary
			return {
				"armed": true,
				"digest": String(runtime_event.get("runtime_execution_context_digest", "")),
				"payload": (runtime_event.get("runtime_execution_context", {}) as Dictionary).duplicate(true),
				"event": runtime_event.duplicate(true),
				"safe_position": safe_position,
			}
	return {"armed": false}


func _finish_current_telegraph(run: Node, safe_position: Vector2, delta: float) -> void:
	for _frame in range(720):
		if run._telegraph.is_empty():
			return
		run._player.place_at(safe_position)
		run._room_previous_player_position = safe_position
		_step_live_room(run, delta)


func _room_activation_side_effects(run: Node) -> int:
	return (
		run._active_room_waves.size()
		+ run._active_room_motifs.size()
		+ run._active_room_actor_groups.size()
		+ run._enemies.size()
		+ run._projectiles.enemy_active.size()
		+ run._pending_room_emissions.size()
	)


func _capture_first_activation(run: Node, room: Dictionary, seed: int, delta: float, cycle_index: int = 0) -> Dictionary:
	if not _prepare_room(run, room, seed):
		return {"activated": false, "cap_error": "room failed to prepare"}
	run._room_cycle_index = cycle_index
	var events := run._room_pattern_plan.get("events", []) as Array
	if events.is_empty():
		return {"activated": false, "cap_error": "compiled plan has no events"}
	var event := events[0] as Dictionary
	var safe_position := RunSceneClass.room_space_position((event.get("safe", {}) as Dictionary).get("position", [0.5, 0.5]) as Array)
	var cap_error := ""
	var frozen_telegraph_positions: Array[Vector2] = []
	for _frame in range(720):
		run._player.place_at(safe_position)
		run._room_previous_player_position = safe_position
		_step_live_room(run, delta)
		if not run._telegraph.is_empty():
			var runtime_event := run._telegraph.get("event", {}) as Dictionary
			var serialized_positions := runtime_event.get("runtime_world_positions", []) as Array
			if not serialized_positions.is_empty():
				frozen_telegraph_positions.clear()
				for raw_position in serialized_positions:
					var position_data := raw_position as Array
					if position_data.size() == 2:
						frozen_telegraph_positions.append(Vector2(float(position_data[0]), float(position_data[1])))
		cap_error = _first_cap_error(run)
		if not cap_error.is_empty():
			break
		var activation := _last_trace(run._room_runtime_trace, "activated")
		if not activation.is_empty():
			var wave_id := String(activation.get("wave_id", ""))
			var actor_group := String(activation.get("actor_group", ""))
			var motif := (run._active_room_motifs.get(wave_id, {}) as Dictionary).duplicate(true)
			return {
				"activated": true,
				"activation": activation.duplicate(true),
				"wave_id": wave_id,
				"actor_group": actor_group,
				"motif": motif,
				"event": event.duplicate(true),
				"telegraph_positions": frozen_telegraph_positions.duplicate(),
				"safe_position": safe_position,
				"active_seconds": maxf(0.08, float(event.get("clear_at", 0.0)) - float(event.get("active_at", 0.0))),
				"projectiles": run._projectiles.enemy_group_size(wave_id),
				"enemies": _enemy_actor_owner_count(run._enemies, actor_group),
				"pending": _pending_owner_count(run._pending_room_emissions, wave_id),
				"health_at_activation": run._player.health,
				"caps_ok": cap_error.is_empty(),
				"cap_error": cap_error,
			}
	return {"activated": false, "cap_error": cap_error if not cap_error.is_empty() else "activation timeout"}


func _capture_replay(run: Node, room: Dictionary, seed: int, delta: float, variant: int) -> Dictionary:
	if not _prepare_room(run, room, seed):
		return {"activated": false}
	var event := ((run._room_pattern_plan.get("events", []) as Array)[0] as Dictionary)
	var safe_position := RunSceneClass.room_space_position((event.get("safe", {}) as Dictionary).get("position", [0.5, 0.5]) as Array)
	for _frame in range(720):
		# Express the path in room time so 30/60 Hz probes supply the same
		# continuous input rather than the same number of frames.
		var progress := clampf(float(run._room_elapsed) / 0.68, 0.0, 1.0)
		var normalized := [
			lerpf(0.14, 0.86, progress) if variant == 0 else lerpf(0.86, 0.14, progress),
			lerpf(0.82, 0.48, progress) if variant == 0 else lerpf(0.46, 0.78, progress),
		]
		var input_position := RunSceneClass.room_space_position(normalized)
		if not run._telegraph.is_empty():
			input_position = safe_position
		run._player.place_at(input_position)
		run._room_previous_player_position = input_position
		_step_live_room(run, delta)
		var activation := _last_trace(run._room_runtime_trace, "activated")
		if not activation.is_empty():
			var wave_id := String(activation.get("wave_id", ""))
			var motif := run._active_room_motifs.get(wave_id, {}) as Dictionary
			var positions: Array = []
			for position in motif.get("base_positions", []) as Array:
				var point := Vector2(position)
				positions.append([roundi(point.x * 1000.0), roundi(point.y * 1000.0)])
			var result := {
				"activated": true,
				"digest": String(activation.get("replay_digest", "")),
				"positions": positions,
			}
			run._clear_contract_waves()
			return result
	return {"activated": false}


func _advance_until_wave_clear(run: Node, wave_id: String, safe_position: Vector2, delta: float) -> Dictionary:
	var cap_error := ""
	for _frame in range(720):
		run._player.place_at(safe_position)
		run._room_previous_player_position = safe_position
		_step_live_room(run, delta)
		cap_error = _first_cap_error(run)
		if not cap_error.is_empty():
			break
		if _trace_has_wave_operation(run._room_runtime_trace, "clear_wave", wave_id):
			return {"cleared": true, "caps_ok": true, "cap_error": ""}
	return {"cleared": false, "caps_ok": cap_error.is_empty(), "cap_error": cap_error if not cap_error.is_empty() else "clear timeout"}


func _step_live_room(run: Node, delta: float) -> void:
	run._update_enemies(delta)
	var hit_result: Dictionary = run._projectiles.step(delta, [], run._player.position, 12.0)
	run._apply_player_hits(hit_result.get("player_hits", []) as Array)
	run._update_internal_hazards(delta)


func _first_cap_error(run: Node) -> String:
	if run._enemies.size() > Runtime.MAX_ACTIVE_ENEMIES:
		return "enemies %d > %d" % [run._enemies.size(), Runtime.MAX_ACTIVE_ENEMIES]
	if run._projectiles.enemy_active.size() > Runtime.MAX_ACTIVE_PROJECTILES:
		return "projectiles %d > %d" % [run._projectiles.enemy_active.size(), Runtime.MAX_ACTIVE_PROJECTILES]
	if run._active_room_waves.size() > 1:
		return "active waves %d > 1" % run._active_room_waves.size()
	if run._active_room_motifs.size() > 1:
		return "active motifs %d > 1" % run._active_room_motifs.size()
	if run._pending_room_emissions.size() > Runtime.MAX_PROJECTILES_PER_EVENT:
		return "pending emissions %d > %d" % [run._pending_room_emissions.size(), Runtime.MAX_PROJECTILES_PER_EVENT]
	for raw_wave_id in run._active_room_waves.keys():
		var wave_id := String(raw_wave_id)
		var motif := run._active_room_motifs.get(raw_wave_id, {}) as Dictionary
		if motif.is_empty():
			return "active wave %s has no motif owner" % wave_id
		var projectile := motif.get("projectile", {}) as Dictionary
		var spawn := motif.get("spawn", {}) as Dictionary
		var owned_projectiles: int = run._projectiles.enemy_group_size(wave_id)
		var owned_pending: int = _pending_owner_count(run._pending_room_emissions, wave_id)
		var projectile_cap: int = int(projectile.get("max_active", 0))
		var projectile_budget: int = int(projectile.get("count", 0))
		if owned_projectiles > projectile_cap:
			return "%s projectiles %d > authored active cap %d" % [wave_id, owned_projectiles, projectile_cap]
		if owned_projectiles + owned_pending > projectile_budget:
			return "%s live+pending projectiles %d > event budget %d" % [wave_id, owned_projectiles + owned_pending, projectile_budget]
		var owned_enemies: int = _enemy_source_wave_count(run._enemies, wave_id)
		var enemy_cap: int = int(spawn.get("max_active_enemies", 0))
		var enemy_budget: int = int(spawn.get("enemy_count", 0))
		if owned_enemies > enemy_cap or owned_enemies > enemy_budget:
			return "%s defenders %d > authored cap/budget %d/%d" % [wave_id, owned_enemies, enemy_cap, enemy_budget]
	for bullet in run._projectiles.enemy_active:
		var owner := String((bullet as Dictionary).get("parent_group", ""))
		if owner.begins_with("room:") and not run._active_room_waves.has(owner):
			return "orphan projectile owner %s" % owner
	for enemy in run._enemies:
		var actor_owner := String((enemy as Dictionary).get("actor_owner_id", ""))
		var source_wave := String((enemy as Dictionary).get("source_wave", ""))
		if actor_owner.begins_with("room_actor:") and not run._active_room_actor_groups.has(actor_owner):
			return "orphan defender actor owner %s" % actor_owner
		if actor_owner.begins_with("room_actor:") and not source_wave.begins_with("room:"):
			return "defender %s lost transient source-wave attribution" % actor_owner
	return ""


func _label_free_live_signature(run: Node, capture: Dictionary) -> String:
	var motif := capture.get("motif", {}) as Dictionary
	var collision := motif.get("collision", {}) as Dictionary
	var positions := _vector_positions(motif.get("positions", []) as Array)
	var bounds := Rect2()
	if not positions.is_empty():
		bounds = Rect2(positions[0], Vector2.ZERO)
		for position in positions:
			bounds = bounds.expand(position)
	var wave_id := String(capture.get("wave_id", ""))
	var bullet_count := 0
	var bullet_speed_sum := 0.0
	var direction_sum := Vector2.ZERO
	for bullet in run._projectiles.enemy_active:
		var projectile := bullet as Dictionary
		if String(projectile.get("parent_group", "")) != wave_id:
			continue
		bullet_count += 1
		var velocity := Vector2(projectile.get("velocity", Vector2.ZERO))
		bullet_speed_sum += velocity.length()
		direction_sum += velocity.normalized()
	var mean_speed := bullet_speed_sum / float(maxi(1, bullet_count))
	var direction_coherence := direction_sum.length() / float(maxi(1, bullet_count))
	return "%d:%s:%d:%d:%d:%d:%d:%d:%d" % [
		1 if bool(collision.get("enabled", false)) else 0,
		String(collision.get("shape", "none")),
		positions.size(),
		roundi(bounds.size.x / 8.0),
		roundi(bounds.size.y / 8.0),
		bullet_count,
		roundi(mean_speed / 10.0),
		roundi(direction_coherence * 100.0),
		int(capture.get("enemies", 0)),
	]


func _trace_operations(trace: Array) -> Array[String]:
	var operations: Array[String] = []
	for entry in trace:
		operations.append(String((entry as Dictionary).get("operation", "")))
	return operations


func _last_trace(trace: Array, operation: String) -> Dictionary:
	for index in range(trace.size() - 1, -1, -1):
		var entry := trace[index] as Dictionary
		if String(entry.get("operation", "")) == operation:
			return entry
	return {}


func _integer_sign(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0


func _trace_has_wave_operation(trace: Array, operation: String, wave_id: String) -> bool:
	for raw_entry in trace:
		var entry := raw_entry as Dictionary
		if String(entry.get("operation", "")) == operation and String(entry.get("wave_id", "")) == wave_id:
			return true
	return false


func _trace_has_emission_spawn(trace: Array, emission_index: int, queued_digest: String) -> bool:
	for raw_entry in trace:
		var entry := raw_entry as Dictionary
		if String(entry.get("operation", "")) == "projectile_emission_spawned" \
				and int(entry.get("emission_index", -1)) == emission_index \
				and String(entry.get("queued_emission_digest", "")) == queued_digest:
			return true
	return false


func _trace_has_actor_clear_reason(trace: Array, actor_group: String, reason: String) -> bool:
	for raw_entry in trace:
		var entry := raw_entry as Dictionary
		if String(entry.get("operation", "")) == "clear_actor_group" \
				and String(entry.get("actor_group", "")) == actor_group \
				and String(entry.get("reason", "")) == reason:
			return true
	return false


func _owner_entities(run: Node, wave_id: String) -> int:
	return (
		(1 if run._active_room_motifs.has(wave_id) else 0)
		+ run._projectiles.enemy_group_size(wave_id)
		+ _pending_owner_count(run._pending_room_emissions, wave_id)
	)


func _all_descendants_owned_by(run: Node, wave_id: String) -> bool:
	for bullet in run._projectiles.enemy_active:
		var item := bullet as Dictionary
		if String(item.get("group", "")) == wave_id and String(item.get("parent_group", "")) != wave_id:
			return false
	for enemy in run._enemies:
		var item := enemy as Dictionary
		if String(item.get("source_wave", "")) != wave_id:
			continue
		var actor_owner := String(item.get("actor_owner_id", ""))
		if actor_owner.is_empty() or actor_owner == wave_id or String(item.get("contract_group", "")) != actor_owner or not run._active_room_actor_groups.has(actor_owner):
			return false
	for pending in run._pending_room_emissions:
		if String((pending as Dictionary).get("wave_id", "")) != wave_id:
			return false
	return true


func _enemy_owner_count(enemies: Array, wave_id: String) -> int:
	return _enemy_source_wave_count(enemies, wave_id)


func _enemy_source_wave_count(enemies: Array, wave_id: String) -> int:
	var count := 0
	for enemy in enemies:
		if String((enemy as Dictionary).get("source_wave", "")) == wave_id:
			count += 1
	return count


func _enemy_actor_owner_count(enemies: Array, actor_owner_id: String) -> int:
	if actor_owner_id.is_empty():
		return 0
	var count := 0
	for enemy in enemies:
		if String((enemy as Dictionary).get("actor_owner_id", "")) == actor_owner_id:
			count += 1
	return count


func _pending_owner_count(pending_emissions: Array, wave_id: String) -> int:
	var count := 0
	for pending in pending_emissions:
		if String((pending as Dictionary).get("wave_id", "")) == wave_id:
			count += 1
	return count


func _has_enemy_owner(enemies: Array, wave_id: String) -> bool:
	return _enemy_owner_count(enemies, wave_id) > 0


func _has_pending_owner(pending_emissions: Array, wave_id: String) -> bool:
	return _pending_owner_count(pending_emissions, wave_id) > 0


func _enemy_by_id(enemies: Array, enemy_id: String) -> Dictionary:
	for enemy in enemies:
		var candidate := enemy as Dictionary
		if String(candidate.get("id", "")) == enemy_id:
			return candidate
	return {}


func _record_damage(_amount: float, cause: String) -> void:
	damage_causes.append(cause)


func _room_for_hazard(rooms: Array, hazard: String) -> Dictionary:
	for raw_room in rooms:
		var room := raw_room as Dictionary
		if String(room.get("hazard", "")) == hazard:
			return room
	return {}


func _vector_positions(values: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for value in values:
		result.append(Vector2(value))
	return result


func _positions_within(first: Array[Vector2], second: Array[Vector2], tolerance: float) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if first[index].distance_to(second[index]) > tolerance:
			return false
	return true


func _maximum_position_displacement(first: Array[Vector2], second: Array[Vector2]) -> float:
	if first.size() != second.size() or first.is_empty():
		return INF
	var maximum := 0.0
	for index in range(first.size()):
		maximum = maxf(maximum, first[index].distance_to(second[index]))
	return maximum


func _first_position_delta(before: Array[Vector2], after: Array[Vector2]) -> Vector2:
	if before.is_empty() or after.is_empty():
		return Vector2.ZERO
	return after[0] - before[0]


func _measured_motion_signature(before: Array[Vector2], after: Array[Vector2], center: Vector2, force: Vector2 = Vector2.ZERO) -> String:
	if not force.is_zero_approx():
		return "%d:%d:%d:%d" % [roundi(force.x * 100.0), roundi(force.y * 100.0), 0, 0]
	var count := mini(before.size(), after.size())
	if count <= 0:
		return "empty"
	var mean_delta := Vector2.ZERO
	var mean_radial_delta := 0.0
	var mean_angle_delta := 0.0
	for index in range(count):
		mean_delta += after[index] - before[index]
		mean_radial_delta += after[index].distance_to(center) - before[index].distance_to(center)
		mean_angle_delta += angle_difference((before[index] - center).angle(), (after[index] - center).angle())
	mean_delta /= float(count)
	mean_radial_delta /= float(count)
	mean_angle_delta /= float(count)
	return "%d:%d:%d:%d" % [
		roundi(mean_delta.x * 10.0),
		roundi(mean_delta.y * 10.0),
		roundi(mean_radial_delta * 10.0),
		roundi(mean_angle_delta * 1000.0),
	]


func _sorted_keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in values:
		result.append(String(key))
	result.sort()
	return result
