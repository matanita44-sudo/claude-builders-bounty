class_name RoomMechanics
extends RefCounted

## Deterministic, data-driven contracts for every authored internal-room hazard.
## Coordinates are normalized so gameplay can scale them to any safe-area rectangle.

const LAUNCH_NON_CHAMBER_COUNT := 30
const LAUNCH_CHAMBER_COUNT := 12
const ENTRY_POINT := [0.5, 0.90]
const EXIT_POINT := [0.5, 0.08]
const MIN_SAFE_CLEARANCE := 0.085
const MIN_EXIT_WIDTH := 0.14
const ALLOWED_TYPES := ["traversal", "combat", "hazard", "chamber"]
const ALLOWED_FAMILIES := ["lane", "ring", "sweep", "spawn"]
const ALLOWED_MOVEMENT_MODELS := ["lane", "ring", "sweep", "anchor", "pocket", "replay"]

static var _cached_profiles: Dictionary = {}


static func contract_for(room: Dictionary, challenge_seed: int) -> Dictionary:
	return build_contract(room, challenge_seed)


static func build_contract(room: Dictionary, challenge_seed: int) -> Dictionary:
	var hazard := String(room.get("hazard", ""))
	var profiles := _profiles()
	if not profiles.has(hazard):
		return _rejected_contract(room, "Unknown room hazard: %s" % hazard)
	var profile: Dictionary = (profiles[hazard] as Dictionary).duplicate(true)
	var errors := _validate_room_metadata(room, profile)
	if not errors.is_empty():
		return {
			"valid": false,
			"room_id": String(room.get("id", "")),
			"hazard": hazard,
			"errors": errors,
		}

	var duration := float(room.get("duration", 0.0))
	var density := int(room.get("density", 0))
	var density_cadence := maxf(float(profile.cadence) * (1.0 - 0.055 * float(density - 1)), 0.58)
	var telegraph := minf(float(profile.telegraph), density_cadence * 0.72)
	var active_seconds := maxf(0.18, float(profile.active_seconds))
	# A published safe pocket remains authoritative until its damaging window
	# closes. The next telegraph starts only after that boundary, leaving a
	# visible reaction window before the next pocket becomes mandatory.
	var cadence := maxf(density_cadence, telegraph + active_seconds + 0.08)
	var exit_transition := clampf(maxf(cadence, 0.72), 0.72, minf(1.35, duration * 0.18))
	var runtime_seed := _combined_seed(challenge_seed, "%s|%s" % [String(room.id), hazard])
	var rng := RandomNumberGenerator.new()
	rng.seed = runtime_seed
	var schedule_result := _build_schedule(profile, duration, density, cadence, telegraph, active_seconds, exit_transition, rng)
	var contract := {
		"valid": true,
		"version": 1,
		"room_id": String(room.id),
		"room_type": String(room.type),
		"boss": String(room.get("boss", "any")),
		"organ": String(room.get("organ", "")),
		"hazard": hazard,
		"safe_rule": String(room.safe_rule),
		"seed": challenge_seed,
		"runtime_seed": runtime_seed,
		"duration": duration,
		"density": density,
		"family": String(profile.family),
		"timing": {
			"cadence": cadence,
			"telegraph_seconds": telegraph,
			"active_seconds": active_seconds,
			"initial_delay": float(profile.initial_delay),
			"exit_transition_seconds": exit_transition,
		},
		"movement": {
			"model": String(profile.movement_model),
			"axis": String(profile.axis),
			"lane_count": int(profile.lane_count),
			"ring_radius": float(profile.ring_radius),
			"rotation_rate": float(profile.rotation_rate),
			"max_required_speed_normalized": float(profile.max_required_speed),
		},
		"spawn": {
			"pattern": String(profile.spawn_pattern),
			"cadence": cadence,
			"burst_count": int(profile.burst_count) + maxi(0, density - 2),
			"max_active": int(profile.max_active) + density,
			"origin": String(profile.spawn_origin),
		},
		"projectile": {
			"enabled": int(profile.projectile_count) > 0,
			"pattern": String(profile.projectile_pattern),
			"speed_pixels_per_second": float(profile.projectile_speed) * (1.0 + 0.04 * float(density - 1)),
			"radius_pixels": float(profile.projectile_radius),
			"lifetime_seconds": float(profile.projectile_lifetime),
			"count": int(profile.projectile_count) + (1 if int(profile.projectile_count) > 0 and density >= 4 else 0),
			"spread_degrees": float(profile.projectile_spread),
			"tracking_strength": float(profile.tracking_strength),
			"damage": float(profile.damage),
		},
		"safe_path": schedule_result.safe_path,
		"events": schedule_result.events,
		"safe_clearance_normalized": float(profile.safe_clearance),
		"exit": {
			"kind": "forward",
			"opens_at": maxf(0.0, duration - exit_transition),
			"normalized_position": EXIT_POINT.duplicate(),
			"width_normalized": maxf(float(profile.safe_clearance) * 1.5, MIN_EXIT_WIDTH),
		},
	}
	var contract_errors := validate_contract(contract)
	if not contract_errors.is_empty():
		contract.valid = false
		contract.errors = contract_errors
	return contract


static func validate_room(room: Dictionary, challenge_seed: int = 1) -> PackedStringArray:
	var hazard := String(room.get("hazard", ""))
	var profiles := _profiles()
	if not profiles.has(hazard):
		return PackedStringArray(["Unknown room hazard: %s" % hazard])
	var profile: Dictionary = profiles[hazard]
	var errors := _validate_room_metadata(room, profile)
	if not errors.is_empty():
		return errors
	var contract := build_contract(room, challenge_seed)
	if not bool(contract.get("valid", false)):
		for error in contract.get("errors", []):
			errors.append(String(error))
	return errors


static func validate_catalog(rooms: Array, require_launch_coverage: bool = true) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	var used_hazards: Dictionary = {}
	var non_chambers := 0
	var chambers := 0
	var chamber_keys: Dictionary = {}
	for raw_room in rooms:
		if typeof(raw_room) != TYPE_DICTIONARY:
			errors.append("Room catalog entries must be dictionaries")
			continue
		var room := raw_room as Dictionary
		var room_id := String(room.get("id", ""))
		if ids.has(room_id):
			errors.append("Duplicate room id: %s" % room_id)
		ids[room_id] = true
		var room_errors := validate_room(room, 0x1F1D1E)
		for error in room_errors:
			errors.append("%s: %s" % [room_id, error])
		var room_type := String(room.get("type", ""))
		if room_type == "chamber":
			chambers += 1
			var chamber_key := "%s:%s" % [String(room.get("boss", "")), String(room.get("organ", ""))]
			if chamber_keys.has(chamber_key):
				errors.append("Duplicate chamber target: %s" % chamber_key)
			chamber_keys[chamber_key] = true
		else:
			non_chambers += 1
		used_hazards[String(room.get("hazard", ""))] = true
	if require_launch_coverage:
		if non_chambers != LAUNCH_NON_CHAMBER_COUNT:
			errors.append("Launch catalog requires %d non-chambers, found %d" % [LAUNCH_NON_CHAMBER_COUNT, non_chambers])
		if chambers != LAUNCH_CHAMBER_COUNT:
			errors.append("Launch catalog requires %d chambers, found %d" % [LAUNCH_CHAMBER_COUNT, chambers])
		if used_hazards.size() != _profiles().size():
			errors.append("Launch catalog/profile coverage mismatch: %d hazards used, %d supported" % [used_hazards.size(), _profiles().size()])
		for hazard in _profiles().keys():
			if not used_hazards.has(hazard):
				errors.append("Unused mechanics profile: %s" % hazard)
	return errors


static func validate_contract(contract: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not bool(contract.get("valid", false)):
		errors.append("Contract is marked invalid")
		return errors
	if String(contract.get("family", "")) not in ALLOWED_FAMILIES:
		errors.append("Unsupported mechanics family")
	var duration := float(contract.get("duration", 0.0))
	if duration <= 0.0:
		errors.append("Contract duration must be positive")
	var timing := contract.get("timing", {}) as Dictionary
	if float(timing.get("cadence", 0.0)) <= 0.0:
		errors.append("Spawn/hazard cadence must be positive")
	if float(timing.get("telegraph_seconds", 0.0)) <= 0.0:
		errors.append("Every hazard must telegraph")
	if float(timing.get("active_seconds", 0.0)) <= 0.0:
		errors.append("Every hazard must have an active window")
	var movement := contract.get("movement", {}) as Dictionary
	if String(movement.get("model", "")) not in ALLOWED_MOVEMENT_MODELS:
		errors.append("Unsupported movement model")
	if int(movement.get("lane_count", 0)) < 2:
		errors.append("Movement contract must expose at least two viable lanes/pockets")
	if float(movement.get("max_required_speed_normalized", 0.0)) <= 0.0:
		errors.append("Movement speed contract must be positive")
	var spawn := contract.get("spawn", {}) as Dictionary
	if String(spawn.get("pattern", "")).is_empty() or float(spawn.get("cadence", 0.0)) <= 0.0:
		errors.append("Spawn contract is incomplete")
	if int(spawn.get("burst_count", 0)) <= 0 or int(spawn.get("max_active", 0)) <= 0:
		errors.append("Spawn limits must be bounded and positive")
	var projectile := contract.get("projectile", {}) as Dictionary
	if String(projectile.get("pattern", "")).is_empty():
		errors.append("Projectile specification is missing")
	if bool(projectile.get("enabled", false)):
		if float(projectile.get("speed_pixels_per_second", 0.0)) <= 0.0 or int(projectile.get("count", 0)) <= 0:
			errors.append("Enabled projectile specification must have speed and count")
		if float(projectile.get("radius_pixels", 0.0)) <= 0.0 or float(projectile.get("lifetime_seconds", 0.0)) <= 0.0:
			errors.append("Enabled projectiles must have bounded geometry and lifetime")
	var clearance := float(contract.get("safe_clearance_normalized", 0.0))
	if clearance < MIN_SAFE_CLEARANCE:
		errors.append("Safe path clearance is below the launch minimum")
	var events := contract.get("events", []) as Array
	if events.is_empty():
		errors.append("Hazard schedule must contain at least one event")
	var prior_clear_at := -1.0
	for raw_event in events:
		var event := raw_event as Dictionary
		var telegraph_at := float(event.get("telegraph_at", -1.0))
		var active_at := float(event.get("active_at", -1.0))
		var clear_at := float(event.get("clear_at", -1.0))
		if telegraph_at < 0.0 or active_at <= telegraph_at or clear_at <= active_at or clear_at > duration + 0.001:
			errors.append("Hazard event has no usable telegraph window")
			break
		if prior_clear_at >= 0.0 and telegraph_at < prior_clear_at + 0.039:
			errors.append("Hazard telegraphs overlap the prior damaging window")
			break
		if (event.get("safe_position", []) as Array).size() != 2:
			errors.append("Hazard event has no safe position")
			break
		prior_clear_at = clear_at
	var exit := contract.get("exit", {}) as Dictionary
	if String(exit.get("kind", "")) != "forward" or float(exit.get("width_normalized", 0.0)) < MIN_EXIT_WIDTH:
		errors.append("Room exit is missing or can form a dead end")
	if prior_clear_at > float(exit.get("opens_at", -1.0)) + 0.001:
		errors.append("Room exit opens before the final damaging window clears")
	var exit_position := exit.get("normalized_position", []) as Array
	if exit_position.size() != 2 or not _inside_arena(exit_position):
		errors.append("Room exit position is invalid")
	var safe_path := contract.get("safe_path", []) as Array
	if safe_path.size() < 3:
		errors.append("Safe path must contain entry, avoidance, and exit waypoints")
	else:
		var prior_time := -1.0
		var prior_position: Array = []
		var max_speed := float(movement.get("max_required_speed_normalized", 0.0))
		for raw_waypoint in safe_path:
			var waypoint := raw_waypoint as Dictionary
			var time := float(waypoint.get("time", -1.0))
			var position := waypoint.get("position", []) as Array
			if time <= prior_time or position.size() != 2 or not _inside_arena(position):
				errors.append("Safe path contains invalid or non-monotonic waypoints")
				break
			if not prior_position.is_empty():
				var delta_time := time - prior_time
				var distance := _distance(prior_position, position)
				if delta_time <= 0.0 or distance / delta_time > max_speed + 0.001:
					errors.append("Safe path requires impossible movement speed")
					break
			prior_time = time
			prior_position = position
		if prior_time < duration - 0.001 or _distance(prior_position, EXIT_POINT) > 0.001:
			errors.append("Safe path does not reach the forward exit")
	return errors


static func supported_hazards() -> PackedStringArray:
	var hazards := PackedStringArray()
	for hazard in _profiles().keys():
		hazards.append(String(hazard))
	hazards.sort()
	return hazards


static func safe_fallback_contract(rejected_room: Dictionary, challenge_seed: int) -> Dictionary:
	var is_chamber := String(rejected_room.get("type", "")) == "chamber"
	var fallback_room := {
		"id": "safe_fallback_%s" % String(rejected_room.get("id", "room")),
		"type": "chamber" if is_chamber else "traversal",
		"boss": String(rejected_room.get("boss", "fallback_boss")) if is_chamber else "any",
		"organ": String(rejected_room.get("organ", "fallback_organ")) if is_chamber else "",
		"duration": maxf(2.0, float(rejected_room.get("duration", 3.0))),
		"hazard": "cell_bloom" if is_chamber else "closing_membranes",
		"safe_rule": "Pass behind the bloom as it opens." if is_chamber else "Follow the bright opening.",
		"density": 1,
	}
	if is_chamber:
		if String(fallback_room.boss).is_empty() or String(fallback_room.boss) == "any":
			fallback_room.boss = "fallback_boss"
		if String(fallback_room.organ).is_empty():
			fallback_room.organ = "fallback_organ"
	return build_contract(fallback_room, challenge_seed ^ 0x5AFE)


static func _validate_room_metadata(room: Dictionary, profile: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var room_id := String(room.get("id", ""))
	if room_id.is_empty():
		errors.append("Room id is required")
	var room_type := String(room.get("type", ""))
	if room_type not in ALLOWED_TYPES:
		errors.append("Unsupported room type: %s" % room_type)
	if float(room.get("duration", 0.0)) <= 0.0:
		errors.append("Room duration must be positive")
	var density := int(room.get("density", 0))
	if density < 1 or density > 4:
		errors.append("Room density must be between 1 and 4")
	var safe_rule := String(room.get("safe_rule", ""))
	if safe_rule != String(profile.safe_rule):
		errors.append("Safe rule does not match hazard contract")
	if room_type == "chamber":
		if String(room.get("boss", "")).is_empty() or String(room.get("boss", "")) == "any":
			errors.append("Chamber must target a specific boss")
		if String(room.get("organ", "")).is_empty():
			errors.append("Chamber must target a specific organ")
	return errors


static func _build_schedule(profile: Dictionary, duration: float, density: int, cadence: float, telegraph: float, active_seconds: float, exit_transition: float, rng: RandomNumberGenerator) -> Dictionary:
	var events: Array[Dictionary] = []
	var safe_path: Array[Dictionary] = [{"time": 0.0, "position": ENTRY_POINT.duplicate(), "clearance": float(profile.safe_clearance)}]
	var lane_count := int(profile.lane_count)
	var safe_lane := lane_count / 2
	# Preserve a real, reachable pre-telegraph approach from the common entrance.
	# A half-second preparation window keeps even side pockets and rings within
	# the published normalized movement-speed ceiling.
	var event_time := maxf(float(profile.initial_delay), telegraph + 0.50)
	var last_activation_at := maxf(event_time, duration - exit_transition - active_seconds)
	var event_index := 0
	var held_safe_position: Array = ENTRY_POINT.duplicate()
	while event_time <= last_activation_at + 0.001:
		safe_lane = _next_safe_lane(safe_lane, lane_count, rng, event_index)
		var safe_position := _safe_position(profile, safe_lane, event_index, event_time, duration, rng)
		var hazard_lanes: Array[int] = []
		for lane in range(lane_count):
			if lane != safe_lane:
				hazard_lanes.append(lane)
		var telegraph_at := maxf(0.0, event_time - telegraph)
		var event := {
			"index": event_index,
			"telegraph_at": telegraph_at,
			"active_at": event_time,
			"clear_at": event_time + active_seconds,
			"safe_lane": safe_lane,
			"safe_position": safe_position,
			"hazard_lanes": hazard_lanes,
			"spawn_count": int(profile.burst_count) + maxi(0, density - 2),
			"phase": rng.randf(),
			"event_seed": int(rng.randi()) & 0x7FFFFFFF,
		}
		events.append(event)
		# Hold the previously published pocket until the next warning appears,
		# traverse during that warning, then remain in the new pocket until the
		# exact damage boundary. This is both player-readable and bot-reachable.
		_append_waypoint(safe_path, maxf(0.05, telegraph_at), held_safe_position, float(profile.safe_clearance))
		_append_waypoint(safe_path, event_time, safe_position, float(profile.safe_clearance))
		_append_waypoint(safe_path, event_time + active_seconds, safe_position, float(profile.safe_clearance))
		held_safe_position = safe_position.duplicate()
		event_time += cadence
		event_index += 1
	var exit_opens := maxf(0.0, duration - exit_transition)
	var last_position: Array = (safe_path[-1] as Dictionary).position
	var staging_position := [clampf(float(last_position[0]), 0.35, 0.65), 0.18]
	_append_waypoint(safe_path, maxf(float((safe_path[-1] as Dictionary).time) + 0.05, exit_opens), last_position, float(profile.safe_clearance))
	_append_waypoint(safe_path, maxf(float((safe_path[-1] as Dictionary).time) + 0.05, duration - 0.24), staging_position, float(profile.safe_clearance))
	_append_waypoint(safe_path, duration, EXIT_POINT.duplicate(), float(profile.safe_clearance))
	return {"events": events, "safe_path": safe_path}


static func _next_safe_lane(current: int, lane_count: int, rng: RandomNumberGenerator, event_index: int) -> int:
	var options: Array[int] = [current]
	if current > 0:
		options.append(current - 1)
	if current + 1 < lane_count:
		options.append(current + 1)
	var chosen := options[rng.randi_range(0, options.size() - 1)]
	if event_index > 0 and options.size() > 1 and chosen == current and rng.randf() < 0.55:
		chosen = options[(options.find(current) + 1) % options.size()]
	return chosen


static func _safe_position(profile: Dictionary, safe_lane: int, event_index: int, event_time: float, duration: float, rng: RandomNumberGenerator) -> Array:
	var model := String(profile.movement_model)
	var lane_count := int(profile.lane_count)
	var progress := clampf(event_time / maxf(duration, 0.001), 0.0, 1.0)
	var lane_x := 0.125 + (float(safe_lane) + 0.5) * (0.75 / float(lane_count))
	match model:
		"ring":
			var direction := -1.0 if int(rng.seed) % 2 == 0 else 1.0
			var angle := float(profile.rotation_rate) * event_time * direction + float(event_index % 3) * 0.17
			return [0.5 + cos(angle) * float(profile.ring_radius), 0.51 + sin(angle) * float(profile.ring_radius)]
		"sweep":
			var side_x := 0.20 if safe_lane < lane_count / 2 else 0.80
			return [side_x, lerpf(0.84, 0.18, progress)]
		"anchor":
			return [lane_x, 0.64 if event_index % 2 == 0 else 0.40]
		"pocket":
			return [lane_x, lerpf(0.80, 0.22, progress)]
		"replay":
			return [lane_x, lerpf(0.84, 0.18, progress)]
		_:
			return [lane_x, lerpf(0.84, 0.18, progress)]


static func _append_waypoint(path: Array[Dictionary], time: float, position: Array, clearance: float) -> void:
	var last_time := float((path[-1] as Dictionary).time)
	if time <= last_time + 0.001:
		return
	path.append({"time": time, "position": position.duplicate(), "clearance": clearance})


static func _inside_arena(position: Array) -> bool:
	return position.size() == 2 and float(position[0]) >= 0.04 and float(position[0]) <= 0.96 and float(position[1]) >= 0.04 and float(position[1]) <= 0.96


static func _distance(a: Array, b: Array) -> float:
	var dx := float(a[0]) - float(b[0])
	var dy := float(a[1]) - float(b[1])
	return sqrt(dx * dx + dy * dy)


static func _combined_seed(challenge_seed: int, text: String) -> int:
	var stable_hash := 2166136261
	for byte in text.to_utf8_buffer():
		stable_hash = int((stable_hash ^ int(byte)) * 16777619) & 0x7FFFFFFF
	return (challenge_seed & 0x7FFFFFFF) ^ stable_hash ^ 0x49D1CE


static func _rejected_contract(room: Dictionary, message: String) -> Dictionary:
	return {
		"valid": false,
		"room_id": String(room.get("id", "")),
		"hazard": String(room.get("hazard", "")),
		"errors": PackedStringArray([message]),
	}


static func _p(safe_rule: String, family: String, movement_model: String, overrides: Dictionary = {}) -> Dictionary:
	var profile := {
		"safe_rule": safe_rule,
		"family": family,
		"movement_model": movement_model,
		"axis": "vertical",
		"lane_count": 3,
		"ring_radius": 0.25,
		"rotation_rate": 0.78,
		"max_required_speed": 1.55,
		"safe_clearance": 0.12,
		"cadence": 1.15,
		"telegraph": 0.42,
		"active_seconds": 0.48,
		"initial_delay": 0.78,
		"spawn_pattern": "structural_cycle",
		"spawn_origin": "ahead",
		"burst_count": 1,
		"max_active": 4,
		"projectile_pattern": "none_structural",
		"projectile_speed": 0.0,
		"projectile_radius": 8.0,
		"projectile_lifetime": 2.5,
		"projectile_count": 0,
		"projectile_spread": 0.0,
		"tracking_strength": 0.0,
		"damage": 10.0,
	}
	for key in overrides:
		profile[key] = overrides[key]
	return profile


static func _profiles() -> Dictionary:
	if not _cached_profiles.is_empty():
		return _cached_profiles
	_cached_profiles = {
		# Traversal rooms
		"closing_membranes": _p("Follow the bright opening.", "lane", "lane", {"spawn_pattern":"membrane_gate", "lane_count":3, "cadence":1.05, "telegraph":0.46}),
		"vein_walls": _p("Stay between paired vessels.", "lane", "lane", {"spawn_pattern":"paired_vessels", "lane_count":4, "safe_clearance":0.105, "cadence":1.18}),
		"rotating_ribs": _p("Move with the widest rib gap.", "ring", "ring", {"spawn_pattern":"rib_arc", "lane_count":3, "ring_radius":0.27, "rotation_rate":0.68, "cadence":0.98}),
		"light_gates": _p("Cross only through unlit gates.", "lane", "lane", {"spawn_pattern":"light_gate", "lane_count":4, "cadence":0.90, "telegraph":0.50}),
		"lateral_current": _p("Use the calm central eddy.", "sweep", "anchor", {"spawn_pattern":"current_pulse", "lane_count":3, "axis":"horizontal", "cadence":1.30, "telegraph":0.55, "safe_clearance":0.14}),
		"false_lane": _p("Follow the asymmetrical tissue mark.", "lane", "lane", {"spawn_pattern":"decoy_lane", "lane_count":4, "cadence":1.10, "telegraph":0.48}),
		"falling_cells": _p("Alternate left and right pockets.", "lane", "pocket", {"spawn_pattern":"cell_drop", "spawn_origin":"top", "lane_count":3, "cadence":0.82, "telegraph":0.38, "projectile_pattern":"falling_cells", "projectile_speed":180.0, "projectile_count":2, "projectile_radius":13.0, "projectile_lifetime":3.2}),
		"pulse_gate": _p("Cross between two heartbeat flashes.", "sweep", "sweep", {"spawn_pattern":"heartbeat_wall", "axis":"horizontal", "lane_count":2, "cadence":1.32, "telegraph":0.62, "active_seconds":0.32, "safe_clearance":0.15}),

		# Combat rooms
		"orbiting_defenders": _p("Keep one open escape lane.", "spawn", "ring", {"spawn_pattern":"orbital_defender", "spawn_origin":"ring", "lane_count":3, "cadence":1.05, "burst_count":2, "max_active":6, "projectile_pattern":"radial_single", "projectile_speed":205.0, "projectile_count":1, "projectile_radius":7.0, "projectile_lifetime":2.8}),
		"pincer_spawn": _p("Break the marked side first.", "spawn", "lane", {"spawn_pattern":"pincer_pair", "spawn_origin":"sides", "lane_count":3, "cadence":1.24, "telegraph":0.55, "burst_count":2, "max_active":6, "projectile_pattern":"inward_fan", "projectile_speed":190.0, "projectile_count":3, "projectile_spread":24.0}),
		"bone_drones": _p("Use destroyed drones as cover.", "spawn", "pocket", {"spawn_pattern":"cover_drone", "spawn_origin":"ahead", "lane_count":3, "cadence":1.30, "burst_count":2, "max_active":5, "projectile_pattern":"bone_bolt", "projectile_speed":215.0, "projectile_count":2, "projectile_radius":8.0}),
		"tracking_mites": _p("Change direction after the gaze flash.", "spawn", "replay", {"spawn_pattern":"tracking_mite", "lane_count":4, "cadence":1.08, "telegraph":0.58, "burst_count":2, "max_active":7, "projectile_pattern":"soft_homing", "projectile_speed":165.0, "projectile_count":1, "tracking_strength":0.32, "projectile_lifetime":3.4}),
		"refracting_defenders": _p("Stand behind a dim prism.", "spawn", "ring", {"spawn_pattern":"prism_cover", "spawn_origin":"ring", "lane_count":4, "cadence":1.18, "burst_count":2, "max_active":6, "projectile_pattern":"split_prism", "projectile_speed":205.0, "projectile_count":3, "projectile_spread":34.0}),
		"sound_cones": _p("Move into the silent cone.", "sweep", "sweep", {"spawn_pattern":"rotating_cone", "spawn_origin":"center", "lane_count":3, "cadence":1.12, "telegraph":0.52, "projectile_pattern":"resonance_wave", "projectile_speed":175.0, "projectile_count":2, "projectile_radius":10.0}),
		"chain_defenders": _p("Separate enemies before their arcs connect.", "spawn", "lane", {"spawn_pattern":"linked_pair", "spawn_origin":"sides", "lane_count":4, "cadence":1.22, "burst_count":2, "max_active":6, "projectile_pattern":"chain_arc", "projectile_speed":225.0, "projectile_count":1, "projectile_radius":9.0}),
		"brood_wave": _p("Clear the nearest hatch first.", "spawn", "lane", {"spawn_pattern":"brood_hatch", "spawn_origin":"ahead", "lane_count":3, "cadence":0.92, "telegraph":0.50, "burst_count":3, "max_active":9, "projectile_pattern":"larval_dash", "projectile_speed":235.0, "projectile_count":1, "projectile_radius":9.0}),
		"delayed_clone_fire": _p("Do not remain on the repeated path.", "spawn", "replay", {"spawn_pattern":"recorded_clone", "lane_count":4, "cadence":1.28, "telegraph":0.62, "burst_count":1, "max_active":5, "projectile_pattern":"delayed_replay", "projectile_speed":220.0, "projectile_count":3, "projectile_spread":18.0}),
		"decoy_bursts": _p("Shoot the core with an uneven pulse.", "spawn", "pocket", {"spawn_pattern":"decoy_core", "spawn_origin":"ahead", "lane_count":4, "cadence":1.16, "burst_count":3, "max_active":7, "projectile_pattern":"false_radial", "projectile_speed":195.0, "projectile_count":4, "projectile_spread":360.0}),

		# Hazard rooms
		"pressure_burst": _p("Occupy the pocket without red capillaries.", "lane", "pocket", {"spawn_pattern":"pressure_pocket", "lane_count":4, "cadence":1.20, "telegraph":0.58, "active_seconds":0.40}),
		"falling_acid": _p("Stay beneath the slow green bead.", "sweep", "lane", {"spawn_pattern":"acid_rain", "spawn_origin":"top", "lane_count":4, "cadence":0.88, "telegraph":0.44, "projectile_pattern":"falling_acid", "projectile_speed":155.0, "projectile_count":3, "projectile_radius":12.0, "projectile_lifetime":3.8}),
		"closing_bone_press": _p("Move to the side marked by marrow light.", "lane", "lane", {"spawn_pattern":"bone_press", "spawn_origin":"sides", "lane_count":2, "cadence":1.38, "telegraph":0.66, "active_seconds":0.52, "safe_clearance":0.16}),
		"inhale_exhale": _p("Anchor behind a rib during inhale.", "sweep", "anchor", {"spawn_pattern":"breath_cycle", "spawn_origin":"center", "lane_count":3, "cadence":1.44, "telegraph":0.62, "active_seconds":0.62, "safe_clearance":0.14}),
		"beam_grid": _p("Move to the cell that never lights.", "lane", "pocket", {"spawn_pattern":"beam_grid", "lane_count":4, "cadence":1.08, "telegraph":0.58, "active_seconds":0.44, "safe_clearance":0.105}),
		"turbine_sweep": _p("Rotate with the slow blade.", "ring", "ring", {"spawn_pattern":"turbine_blade", "spawn_origin":"center", "lane_count":3, "ring_radius":0.29, "rotation_rate":0.62, "cadence":0.86, "telegraph":0.40}),
		"rotating_wells": _p("Orbit outside the active well.", "ring", "ring", {"spawn_pattern":"gravity_well", "spawn_origin":"ring", "lane_count":4, "ring_radius":0.31, "rotation_rate":0.56, "cadence":1.22, "telegraph":0.58, "safe_clearance":0.13}),
		"node_arcs": _p("Cross through a dark node to break the chain.", "lane", "pocket", {"spawn_pattern":"arc_nodes", "lane_count":4, "cadence":1.05, "telegraph":0.54, "projectile_pattern":"node_arc", "projectile_speed":245.0, "projectile_count":1, "projectile_radius":9.0}),
		"path_replay": _p("Leave your last movement lane before the echo.", "lane", "replay", {"spawn_pattern":"path_echo", "lane_count":4, "cadence":1.18, "telegraph":0.60, "projectile_pattern":"echo_trace", "projectile_speed":210.0, "projectile_count":2, "projectile_radius":8.0}),
		"mirrored_walls": _p("Use the single non-reflected gap.", "lane", "lane", {"spawn_pattern":"mirror_wall", "lane_count":4, "cadence":1.12, "telegraph":0.58, "safe_clearance":0.11}),
		"cell_bloom": _p("Pass behind the bloom as it opens.", "ring", "ring", {"spawn_pattern":"cell_bloom", "spawn_origin":"center", "lane_count":3, "ring_radius":0.26, "rotation_rate":0.72, "cadence":1.16, "telegraph":0.56, "projectile_pattern":"bloom_petals", "projectile_speed":170.0, "projectile_count":5, "projectile_spread":360.0, "projectile_radius":8.0}),
		"artery_sweep": _p("Cross after the visible pressure wave.", "sweep", "sweep", {"spawn_pattern":"artery_wall", "spawn_origin":"side", "lane_count":2, "axis":"horizontal", "cadence":1.30, "telegraph":0.64, "active_seconds":0.38, "projectile_pattern":"pressure_wave", "projectile_speed":205.0, "projectile_count":1, "projectile_radius":14.0}),

		# Organ chambers
		"tracking_gaze": _p("Break line of sight behind lens tissue.", "sweep", "pocket", {"spawn_pattern":"gaze_sweep", "spawn_origin":"center", "lane_count":4, "cadence":1.36, "telegraph":0.72, "active_seconds":0.58, "projectile_pattern":"gaze_marker", "projectile_speed":150.0, "projectile_count":1, "tracking_strength":0.38, "projectile_lifetime":3.2}),
		"suction_cycle": _p("Alternate between anchored pockets.", "sweep", "anchor", {"spawn_pattern":"suction_cycle", "spawn_origin":"center", "lane_count":3, "cadence":1.48, "telegraph":0.68, "active_seconds":0.66, "safe_clearance":0.145}),
		"bone_press": _p("Use the marked side lane.", "lane", "lane", {"spawn_pattern":"forge_press", "spawn_origin":"sides", "lane_count":2, "cadence":1.34, "telegraph":0.66, "active_seconds":0.54, "safe_clearance":0.16}),
		"refracted_grid": _p("Move through the unlit cell.", "lane", "pocket", {"spawn_pattern":"refracted_grid", "lane_count":4, "cadence":1.06, "telegraph":0.60, "projectile_pattern":"prism_lance", "projectile_speed":225.0, "projectile_count":2, "projectile_radius":7.0}),
		"turbine_lanes": _p("Move with the rotation.", "ring", "ring", {"spawn_pattern":"reactor_turbine", "spawn_origin":"center", "lane_count":4, "ring_radius":0.30, "rotation_rate":0.64, "cadence":0.88, "telegraph":0.42}),
		"resonance_pulses": _p("Stand between wave fronts.", "ring", "ring", {"spawn_pattern":"resonance_ring", "spawn_origin":"center", "lane_count":3, "ring_radius":0.28, "rotation_rate":0.50, "cadence":1.26, "telegraph":0.62, "projectile_pattern":"expanding_wave", "projectile_speed":185.0, "projectile_count":2, "projectile_radius":11.0}),
		"suction_wells": _p("Orbit outside the active well.", "ring", "ring", {"spawn_pattern":"vortex_well", "spawn_origin":"ring", "lane_count":4, "ring_radius":0.32, "rotation_rate":0.54, "cadence":1.18, "telegraph":0.58, "safe_clearance":0.135}),
		"chain_arcs": _p("Cross through dead nodes.", "lane", "pocket", {"spawn_pattern":"gland_nodes", "lane_count":4, "cadence":1.02, "telegraph":0.56, "projectile_pattern":"chain_lightning", "projectile_speed":250.0, "projectile_count":2, "projectile_radius":9.0}),
		"egg_hatches": _p("Destroy the marked egg before it opens.", "spawn", "lane", {"spawn_pattern":"egg_hatch", "spawn_origin":"ahead", "lane_count":3, "cadence":1.14, "telegraph":0.68, "burst_count":3, "max_active":10, "projectile_pattern":"hatchling_dash", "projectile_speed":230.0, "projectile_count":1, "projectile_radius":10.0}),
		"attack_replay": _p("Change lanes before the recorded attack.", "spawn", "replay", {"spawn_pattern":"attack_recording", "lane_count":4, "cadence":1.20, "telegraph":0.64, "projectile_pattern":"copied_weapon", "projectile_speed":220.0, "projectile_count":3, "projectile_spread":20.0}),
		"delayed_path": _p("Avoid crossing your recent trail.", "lane", "replay", {"spawn_pattern":"delayed_trail", "lane_count":4, "cadence":1.16, "telegraph":0.62, "projectile_pattern":"echo_trail", "projectile_speed":205.0, "projectile_count":2, "projectile_radius":9.0}),
		"mirrored_quadrants": _p("Follow the asymmetric tissue mark.", "lane", "pocket", {"spawn_pattern":"mirror_quadrant", "lane_count":4, "cadence":1.10, "telegraph":0.60, "projectile_pattern":"quadrant_burst", "projectile_speed":215.0, "projectile_count":4, "projectile_spread":90.0}),
	}
	return _cached_profiles
