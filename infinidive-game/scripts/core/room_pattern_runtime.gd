class_name RoomPatternRuntime
extends RefCounted

## Pure compiler from RoomMechanics contracts to deterministic runtime plans.
## It owns no Nodes and performs no side effects: callers may compile, validate,
## replay, or render the returned operations without coupling to scene state.

const RoomMechanicsScript := preload("res://scripts/core/room_mechanics.gd")
const RoomSpaceScript := preload("res://scripts/core/room_space.gd")

const PLAN_VERSION := 3
const MAX_EVENTS := 64
const MAX_HAZARDS_PER_EVENT := 12
const MAX_ENEMIES_PER_EVENT := 8
const MAX_ACTIVE_ENEMIES := 12
const MAX_PROJECTILES_PER_EVENT := 32
const MAX_ACTIVE_PROJECTILES := 48
const COORDINATE_SPACE := RoomSpaceScript.ID
## RunScene resolves the player's 12 px collision radius against a 430 px
## short-edge internal arena. Keep the compiler slightly conservative so a
## safe disk remains valid when the same normalized plan is scaled nearby.
const PLAYER_RADIUS_NORMALIZED := 0.03
const SAFE_GEOMETRY_EPSILON := 0.002
## Room projectile waves are intentionally transient. Their effective life is
## the authored active window so one safe corridor can never overlap the next.
const MAX_DELAYED_EMISSION_SECONDS := 0.20
const DELAYED_EMISSION_STEP_SECONDS := 0.10
const EMISSION_BOUNDARY_GUARD_SECONDS := 0.04
const MIN_THREAT_TIME_SECONDS := 0.16
const MAX_THREAT_TIME_SECONDS := 0.30
const MIN_ACTIVE_WINDOW_SECONDS := MIN_THREAT_TIME_SECONDS + EMISSION_BOUNDARY_GUARD_SECONDS
const MAX_ROOM_DURATION_SECONDS := 120.0
const MAX_CADENCE_SECONDS := 10.0
const MAX_TELEGRAPH_SECONDS := 5.0
const MAX_ACTIVE_WINDOW_SECONDS := 10.0
const MAX_INITIAL_DELAY_SECONDS := 10.0
const MAX_EXIT_TRANSITION_SECONDS := 10.0
const MIN_EVENT_GAP_SECONDS := 0.039
const MAX_SAFE_PATH_WAYPOINTS := MAX_EVENTS * 3 + 4
const MAX_SAFE_CLEARANCE_NORMALIZED := 0.40
const MAX_MOVEMENT_SPEED_NORMALIZED := 8.0
const MAX_RING_RADIUS_NORMALIZED := 0.46
const MAX_ROTATION_RATE := TAU
const MIN_PROJECTILE_SPEED_PIXELS_PER_SECOND := 80.0
const MAX_PROJECTILE_SPEED_PIXELS_PER_SECOND := 2000.0
const MIN_PROJECTILE_RADIUS_PIXELS := 4.0
const MAX_PROJECTILE_RADIUS_PIXELS := 96.0
const MAX_AUTHORED_PROJECTILE_LIFETIME_SECONDS := 30.0
const MIN_PROJECTILE_DAMAGE := 1.0
const MAX_PROJECTILE_DAMAGE := 1000.0
const MAX_PROJECTILE_SPREAD_DEGREES := 360.0
const MAX_DIRECTION_DEGREES := 1080.0
const MAX_COLLISION_RADIUS_NORMALIZED := 0.50
const MAX_COLLISION_THICKNESS_NORMALIZED := 0.25
const MAX_SEED_VALUE := 0x7FFFFFFF
## Generous source-side ceiling that still makes count multiplication safe in a
## signed 31-bit replay field. Existing runtime caps remain the effective limit.
const MAX_SOURCE_REQUEST_COUNT := 178956970
## Defenders outlive their transient emitter under a separate owner. These
## values mirror the live executor and never serialize the next telegraph.
const MIN_ACTOR_RESOLUTION_SECONDS := 2.50
const ACTOR_RESOLUTION_SECONDS := 3.20
const ARMORED_ACTOR_RESOLUTION_SECONDS := 4.00

const MOVEMENT_BEHAVIORS := {
	"lane": {"primitive":"lane_step", "visual":"lane_guide"},
	"ring": {"primitive":"orbit_arc", "visual":"orbit_guide"},
	"sweep": {"primitive":"side_sweep", "visual":"sweep_guide"},
	"anchor": {"primitive":"anchor_hold", "visual":"anchor_guide"},
	"pocket": {"primitive":"pocket_shift", "visual":"pocket_guide"},
	"replay": {"primitive":"echo_follow", "visual":"echo_guide"},
}

const SPAWN_BEHAVIORS := {
	"membrane_gate": {"primitive":"lane_gate", "visual":"membrane_gate", "defender":"none"},
	"paired_vessels": {"primitive":"paired_barrier", "visual":"paired_vessels", "defender":"none"},
	"rib_arc": {"primitive":"rotating_arc", "visual":"rib_arc", "defender":"none"},
	"light_gate": {"primitive":"lane_gate", "visual":"light_gate", "defender":"none"},
	"current_pulse": {"primitive":"sweep_field", "visual":"current_pulse", "defender":"none"},
	"decoy_lane": {"primitive":"lane_gate", "visual":"decoy_lane", "defender":"none"},
	"cell_drop": {"primitive":"drop_field", "visual":"cell_drop", "defender":"none"},
	"heartbeat_wall": {"primitive":"sweep_wall", "visual":"heartbeat_wall", "defender":"none"},
	"orbital_defender": {"primitive":"radial_cluster", "visual":"orbital_defender", "defender":"orbit_sentinel"},
	"pincer_pair": {"primitive":"pincer_pair", "visual":"pincer_pair", "defender":"pincer_hunter"},
	"cover_drone": {"primitive":"cover_line", "visual":"cover_drone", "defender":"armor_drone"},
	"tracking_mite": {"primitive":"tracked_pack", "visual":"tracking_mite", "defender":"tracker_mite"},
	"prism_cover": {"primitive":"radial_cluster", "visual":"prism_cover", "defender":"prism_guard"},
	"rotating_cone": {"primitive":"cone_sweep", "visual":"rotating_cone", "defender":"resonance_mouth"},
	"linked_pair": {"primitive":"node_chain", "visual":"linked_pair", "defender":"arc_linker"},
	"brood_hatch": {"primitive":"hatch_wave", "visual":"brood_hatch", "defender":"hatchling"},
	"recorded_clone": {"primitive":"replay_trace", "visual":"recorded_clone", "defender":"echo_clone"},
	"decoy_core": {"primitive":"decoy_cluster", "visual":"decoy_core", "defender":"decoy_core"},
	"pressure_pocket": {"primitive":"pocket_field", "visual":"pressure_pocket", "defender":"none"},
	"acid_rain": {"primitive":"drop_field", "visual":"acid_rain", "defender":"none"},
	"bone_press": {"primitive":"paired_barrier", "visual":"bone_press", "defender":"none"},
	"breath_cycle": {"primitive":"sweep_field", "visual":"breath_cycle", "defender":"none"},
	"beam_grid": {"primitive":"grid_cells", "visual":"beam_grid", "defender":"none"},
	"turbine_blade": {"primitive":"rotating_arc", "visual":"turbine_blade", "defender":"none"},
	"gravity_well": {"primitive":"gravity_field", "visual":"gravity_well", "defender":"none"},
	"arc_nodes": {"primitive":"node_chain", "visual":"arc_nodes", "defender":"none"},
	"path_echo": {"primitive":"replay_trace", "visual":"path_echo", "defender":"none"},
	"mirror_wall": {"primitive":"paired_barrier", "visual":"mirror_wall", "defender":"none"},
	"cell_bloom": {"primitive":"radial_cluster", "visual":"cell_bloom", "defender":"none"},
	"artery_wall": {"primitive":"sweep_wall", "visual":"artery_wall", "defender":"none"},
	"gaze_sweep": {"primitive":"cone_sweep", "visual":"gaze_sweep", "defender":"none"},
	"suction_cycle": {"primitive":"gravity_field", "visual":"suction_cycle", "defender":"none"},
	"forge_press": {"primitive":"paired_barrier", "visual":"forge_press", "defender":"none"},
	"refracted_grid": {"primitive":"grid_cells", "visual":"refracted_grid", "defender":"none"},
	"reactor_turbine": {"primitive":"rotating_arc", "visual":"reactor_turbine", "defender":"none"},
	"resonance_ring": {"primitive":"radial_cluster", "visual":"resonance_ring", "defender":"none"},
	"vortex_well": {"primitive":"gravity_field", "visual":"vortex_well", "defender":"none"},
	"gland_nodes": {"primitive":"node_chain", "visual":"gland_nodes", "defender":"none"},
	"egg_hatch": {"primitive":"hatch_wave", "visual":"egg_hatch", "defender":"hatchling"},
	"attack_recording": {"primitive":"replay_trace", "visual":"attack_recording", "defender":"echo_clone"},
	"delayed_trail": {"primitive":"replay_trace", "visual":"delayed_trail", "defender":"none"},
	"mirror_quadrant": {"primitive":"grid_cells", "visual":"mirror_quadrant", "defender":"none"},
}

const PROJECTILE_BEHAVIORS := {
	"none_structural": {"primitive":"structural_only", "visual":"none", "travel":"none"},
	"falling_cells": {"primitive":"gravity_drop", "visual":"falling_cell", "travel":"linear"},
	"radial_single": {"primitive":"radial_burst", "visual":"immune_orb", "travel":"linear"},
	"inward_fan": {"primitive":"converging_fan", "visual":"pincer_spike", "travel":"linear"},
	"bone_bolt": {"primitive":"aimed_burst", "visual":"bone_bolt", "travel":"linear"},
	"soft_homing": {"primitive":"tracked_shot", "visual":"optic_mite", "travel":"soft_homing"},
	"split_prism": {"primitive":"split_fan", "visual":"prism_split", "travel":"linear"},
	"resonance_wave": {"primitive":"wave_front", "visual":"resonance_wave", "travel":"expanding"},
	"chain_arc": {"primitive":"linked_arc", "visual":"chain_arc", "travel":"node_link"},
	"larval_dash": {"primitive":"dash_lunge", "visual":"larval_dash", "travel":"lunge"},
	"delayed_replay": {"primitive":"replay_burst", "visual":"delayed_replay", "travel":"delayed_linear"},
	"false_radial": {"primitive":"decoy_radial", "visual":"false_radial", "travel":"linear"},
	"falling_acid": {"primitive":"gravity_drop", "visual":"acid_bead", "travel":"linear"},
	"node_arc": {"primitive":"linked_arc", "visual":"node_arc", "travel":"node_link"},
	"echo_trace": {"primitive":"replay_trace", "visual":"echo_trace", "travel":"recorded_path"},
	"bloom_petals": {"primitive":"petal_radial", "visual":"bloom_petal", "travel":"linear"},
	"pressure_wave": {"primitive":"wave_front", "visual":"pressure_wave", "travel":"expanding"},
	"gaze_marker": {"primitive":"tracked_marker", "visual":"gaze_marker", "travel":"soft_homing"},
	"prism_lance": {"primitive":"prism_line", "visual":"prism_lance", "travel":"linear"},
	"expanding_wave": {"primitive":"ring_wave", "visual":"expanding_wave", "travel":"expanding"},
	"chain_lightning": {"primitive":"linked_arc", "visual":"chain_lightning", "travel":"node_link"},
	"hatchling_dash": {"primitive":"dash_lunge", "visual":"hatchling_dash", "travel":"lunge"},
	"copied_weapon": {"primitive":"replay_burst", "visual":"copied_weapon", "travel":"delayed_linear"},
	"echo_trail": {"primitive":"replay_trace", "visual":"echo_trail", "travel":"recorded_path"},
	"quadrant_burst": {"primitive":"quadrant_fan", "visual":"quadrant_burst", "travel":"linear"},
}

const DEFENDER_ARCHETYPES := {
	"orbit_sentinel": {"motion":"orbit_arc", "attack":"radial_burst", "health_class":"light", "collision_role":"skirmisher"},
	"pincer_hunter": {"motion":"lane_cross", "attack":"converging_fan", "health_class":"light", "collision_role":"flanker"},
	"armor_drone": {"motion":"cover_anchor", "attack":"aimed_burst", "health_class":"armored", "collision_role":"cover"},
	"tracker_mite": {"motion":"soft_pursuit", "attack":"tracked_shot", "health_class":"light", "collision_role":"pursuer"},
	"prism_guard": {"motion":"orbit_arc", "attack":"split_fan", "health_class":"medium", "collision_role":"cover"},
	"resonance_mouth": {"motion":"sweep_anchor", "attack":"wave_front", "health_class":"medium", "collision_role":"emitter"},
	"arc_linker": {"motion":"paired_orbit", "attack":"linked_arc", "health_class":"medium", "collision_role":"link_node"},
	"hatchling": {"motion":"lane_rush", "attack":"dash_lunge", "health_class":"swarm", "collision_role":"charger"},
	"echo_clone": {"motion":"echo_follow", "attack":"replay_burst", "health_class":"medium", "collision_role":"mirror"},
	"decoy_core": {"motion":"pocket_shift", "attack":"decoy_radial", "health_class":"decoy", "collision_role":"false_target"},
}

const ALLOWED_SPAWN_ORIGINS := ["ahead", "ring", "sides", "top", "center", "side"]
const RUNTIME_CATEGORIES := ["gate", "rain", "radial", "sweep", "field", "node", "spawn", "echo"]


static func compile_contract(contract: Dictionary) -> Dictionary:
	var errors := validate_source_contract(contract)
	if not errors.is_empty():
		return _rejected_plan(contract, errors)
	var movement_source := contract.get("movement", {}) as Dictionary
	var spawn_source := contract.get("spawn", {}) as Dictionary
	var projectile_source := contract.get("projectile", {}) as Dictionary
	var movement_id := String(movement_source.get("model", ""))
	var spawn_id := String(spawn_source.get("pattern", ""))
	var projectile_id := String(projectile_source.get("pattern", ""))
	var movement_behavior := (MOVEMENT_BEHAVIORS[movement_id] as Dictionary).duplicate(true)
	var spawn_behavior := (SPAWN_BEHAVIORS[spawn_id] as Dictionary).duplicate(true)
	var projectile_behavior := (PROJECTILE_BEHAVIORS[projectile_id] as Dictionary).duplicate(true)
	var defender_id := String(spawn_behavior.get("defender", "none"))
	var safe_path := (contract.get("safe_path", []) as Array).duplicate(true)
	var safe_signature := safe_path_signature(safe_path)
	var source_events := contract.get("events", []) as Array
	var event_plans: Array[Dictionary] = []
	var primitive_ids: Dictionary = {}
	primitive_ids[String(movement_behavior.primitive)] = true
	primitive_ids[String(spawn_behavior.primitive)] = true
	primitive_ids[String(projectile_behavior.primitive)] = true
	var event_limit := mini(source_events.size(), MAX_EVENTS)
	for event_index in range(event_limit):
		var source_event := source_events[event_index] as Dictionary
		var event_plan := _compile_event(
			contract,
			source_event,
			movement_id,
			movement_behavior,
			spawn_id,
			spawn_behavior,
			projectile_id,
			projectile_behavior,
			defender_id
		)
		event_plans.append(event_plan)
	var plan_visual := _visual_signature(spawn_id, spawn_behavior, projectile_id, projectile_behavior, movement_id, movement_behavior, defender_id, -1, int(contract.get("runtime_seed", 0)))
	var plan := {
		"valid": true,
		"version": PLAN_VERSION,
		"room_id": String(contract.get("room_id", "")),
		"hazard": String(contract.get("hazard", "")),
		"family": String(contract.get("family", "")),
		"duration": float(contract.get("duration", 0.0)),
		"runtime_seed": int(contract.get("runtime_seed", 0)),
		"coordinate_space": COORDINATE_SPACE,
			"source": {
				"spawn_pattern": spawn_id,
				"projectile_pattern": projectile_id,
				"movement_model": movement_id,
			},
			# RunScene consumes contract timing directly. Preserve the exact validated
			# payload in the canonical plan so replay identity binds those live values.
			"timing": (contract.get("timing", {}) as Dictionary).duplicate(true),
		"primitive_ids": _sorted_keys(primitive_ids),
		"defender_archetype": defender_id,
		"defender_behavior": {} if defender_id == "none" else (DEFENDER_ARCHETYPES[defender_id] as Dictionary).duplicate(true),
		"limits": {
			"max_events": MAX_EVENTS,
			"max_hazards_per_event": MAX_HAZARDS_PER_EVENT,
			"max_enemies_per_event": MAX_ENEMIES_PER_EVENT,
			"max_active_enemies": mini(int(spawn_source.get("max_active", 1)), MAX_ACTIVE_ENEMIES),
			"max_projectiles_per_event": MAX_PROJECTILES_PER_EVENT,
			"max_active_projectiles": MAX_ACTIVE_PROJECTILES,
		},
		"safe_path": safe_path,
		"safe_path_signature": safe_signature,
		"visual_signature": plan_visual,
		"events": event_plans,
	}
	plan["geometry_signature"] = geometry_signature_for_plan(plan)
	plan["lifecycle_signature"] = lifecycle_signature_for_plan(plan)
	plan["plan_signature"] = _plan_signature(plan)
	var plan_errors := validate_plan(plan)
	if not plan_errors.is_empty():
		return _rejected_plan(contract, plan_errors)
	return plan


static func compile_room(room: Dictionary, challenge_seed: int) -> Dictionary:
	return compile_contract(RoomMechanicsScript.build_contract(room, challenge_seed))


static func validate_source_contract(contract: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not bool(contract.get("valid", false)):
		errors.append("RoomMechanics contract must be valid before compilation")
		return errors
	var duration_value: Variant = contract.get("duration", null)
	if not _number_in_range(duration_value, MIN_ACTIVE_WINDOW_SECONDS, MAX_ROOM_DURATION_SECONDS):
		errors.append("Room duration must be finite and bounded")
	var duration := float(duration_value) if _is_finite_number(duration_value) else 0.0
	var runtime_seed_value: Variant = contract.get("runtime_seed", null)
	if not _integer_in_range(runtime_seed_value, 0, MAX_SEED_VALUE):
		errors.append("Runtime seed must be a bounded non-negative integer")
	var runtime_seed := int(runtime_seed_value) if typeof(runtime_seed_value) == TYPE_INT else 0
	var room_id := String(contract.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		errors.append("Room contract requires a stable room id")
	var timing_value: Variant = contract.get("timing", null)
	if typeof(timing_value) != TYPE_DICTIONARY:
		errors.append("Room timing payload must be a dictionary")
	var timing := timing_value as Dictionary if typeof(timing_value) == TYPE_DICTIONARY else {}
	_validate_timing_payload(timing, duration, "Source", errors)
	var cadence := float(timing.get("cadence", 0.0)) if _is_finite_number(timing.get("cadence", null)) else 0.0
	var telegraph_seconds := float(timing.get("telegraph_seconds", 0.0)) if _is_finite_number(timing.get("telegraph_seconds", null)) else 0.0
	var authored_active_seconds := float(timing.get("active_seconds", 0.0)) if _is_finite_number(timing.get("active_seconds", null)) else 0.0
	var spawn_value: Variant = contract.get("spawn", null)
	var projectile_value: Variant = contract.get("projectile", null)
	var movement_value: Variant = contract.get("movement", null)
	if typeof(spawn_value) != TYPE_DICTIONARY:
		errors.append("Room spawn payload must be a dictionary")
	if typeof(projectile_value) != TYPE_DICTIONARY:
		errors.append("Room projectile payload must be a dictionary")
	if typeof(movement_value) != TYPE_DICTIONARY:
		errors.append("Room movement payload must be a dictionary")
	if typeof(spawn_value) != TYPE_DICTIONARY or typeof(projectile_value) != TYPE_DICTIONARY or typeof(movement_value) != TYPE_DICTIONARY:
		return errors
	var spawn := spawn_value as Dictionary
	var projectile := projectile_value as Dictionary
	var movement := movement_value as Dictionary
	var spawn_id := String(spawn.get("pattern", ""))
	var projectile_id := String(projectile.get("pattern", ""))
	var movement_id := String(movement.get("model", ""))
	if not SPAWN_BEHAVIORS.has(spawn_id):
		errors.append("Unmapped spawn.pattern: %s" % spawn_id)
	if not PROJECTILE_BEHAVIORS.has(projectile_id):
		errors.append("Unmapped projectile.pattern: %s" % projectile_id)
	if not MOVEMENT_BEHAVIORS.has(movement_id):
		errors.append("Unmapped movement.model: %s" % movement_id)
	if String(spawn.get("origin", "")) not in ALLOWED_SPAWN_ORIGINS:
		errors.append("Unmapped spawn.origin: %s" % String(spawn.get("origin", "")))
	if not _integer_in_range(spawn.get("burst_count", null), 1, MAX_SOURCE_REQUEST_COUNT) or not _integer_in_range(spawn.get("max_active", null), 1, MAX_SOURCE_REQUEST_COUNT):
		errors.append("Spawn counts must be bounded integers before compilation")
	if not _number_in_range(spawn.get("cadence", null), MIN_ACTIVE_WINDOW_SECONDS, MAX_CADENCE_SECONDS) or absf(float(spawn.get("cadence", 0.0)) - cadence) > 0.001:
		errors.append("Spawn cadence must be finite, bounded, and match room timing")
	if bool(projectile.get("enabled", false)) and not _integer_in_range(projectile.get("count", null), 1, MAX_SOURCE_REQUEST_COUNT):
		errors.append("Enabled projectile pattern must request a positive count")
	elif not bool(projectile.get("enabled", false)) and not _integer_in_range(projectile.get("count", null), 0, MAX_SOURCE_REQUEST_COUNT):
		errors.append("Disabled projectile count must be a bounded integer")
	if not bool(projectile.get("enabled", false)) and projectile_id != "none_structural":
		errors.append("Disabled projectile contract must use none_structural")
	if bool(projectile.get("enabled", false)) and projectile_id == "none_structural":
		errors.append("Enabled projectile contract cannot use none_structural")
	var lane_count_value: Variant = movement.get("lane_count", null)
	if not _integer_in_range(lane_count_value, 2, MAX_HAZARDS_PER_EVENT):
		errors.append("Movement lane count must be a bounded integer")
	var lane_count := int(lane_count_value) if typeof(lane_count_value) == TYPE_INT else 0
	if String(movement.get("axis", "")) not in ["horizontal", "vertical"]:
		errors.append("Movement axis is unsupported")
	if not _number_in_range(movement.get("ring_radius", null), 0.0, MAX_RING_RADIUS_NORMALIZED):
		errors.append("Movement ring radius must be finite and bounded")
	if not _number_in_range(movement.get("rotation_rate", null), -MAX_ROTATION_RATE, MAX_ROTATION_RATE):
		errors.append("Movement rotation rate must be finite and bounded")
	if not _number_in_range(movement.get("max_required_speed_normalized", null), 0.001, MAX_MOVEMENT_SPEED_NORMALIZED):
		errors.append("Movement speed must be finite and bounded")
	if not _number_in_range(contract.get("safe_clearance_normalized", null), 0.001, MAX_SAFE_CLEARANCE_NORMALIZED):
		errors.append("Safe clearance must be finite and bounded")
	var projectile_enabled := bool(projectile.get("enabled", false))
	var minimum_projectile_speed := MIN_PROJECTILE_SPEED_PIXELS_PER_SECOND if projectile_enabled else 0.0
	var minimum_projectile_radius := MIN_PROJECTILE_RADIUS_PIXELS if projectile_enabled else 0.001
	var minimum_projectile_damage := MIN_PROJECTILE_DAMAGE if projectile_enabled else 0.001
	if not _number_in_range(projectile.get("speed_pixels_per_second", null), minimum_projectile_speed, MAX_PROJECTILE_SPEED_PIXELS_PER_SECOND):
		errors.append("Projectile speed must be finite, bounded, and executable without runtime clamping")
	if not _number_in_range(projectile.get("radius_pixels", null), minimum_projectile_radius, MAX_PROJECTILE_RADIUS_PIXELS):
		errors.append("Projectile radius must be finite and bounded")
	if not _number_in_range(projectile.get("lifetime_seconds", null), 0.001, MAX_AUTHORED_PROJECTILE_LIFETIME_SECONDS):
		errors.append("Authored projectile lifetime must be finite and bounded")
	if not _number_in_range(projectile.get("spread_degrees", null), 0.0, MAX_PROJECTILE_SPREAD_DEGREES):
		errors.append("Projectile spread must be finite and bounded")
	if not _number_in_range(projectile.get("tracking_strength", null), 0.0, 1.0):
		errors.append("Projectile tracking strength must be finite and bounded")
	if not _number_in_range(projectile.get("damage", null), minimum_projectile_damage, MAX_PROJECTILE_DAMAGE):
		errors.append("Projectile damage must be finite and bounded")
	var safe_path_value: Variant = contract.get("safe_path", null)
	if typeof(safe_path_value) != TYPE_ARRAY:
		errors.append("Source safe path must be an array")
	else:
		_validate_safe_path_payload(safe_path_value as Array, duration, "Source", errors)
	var events_value: Variant = contract.get("events", null)
	if typeof(events_value) != TYPE_ARRAY:
		errors.append("Execution plan events must be an array")
		return errors
	var events := events_value as Array
	if events.is_empty():
		errors.append("Execution plan requires at least one event")
		return errors
	if events.size() > MAX_EVENTS:
		errors.append("Execution plan event count exceeds the runtime cap")
		return errors
	var seen_indices: Dictionary = {}
	var seen_wave_ids: Dictionary = {}
	var seen_actor_ids: Dictionary = {}
	var prior_active_at := -1.0
	var prior_clear_at := -1.0
	var defender_id := String((SPAWN_BEHAVIORS.get(spawn_id, {}) as Dictionary).get("defender", "none"))
	for index in range(events.size()):
		if typeof(events[index]) != TYPE_DICTIONARY:
			errors.append("Event %d must be a dictionary" % index)
			continue
		var event := events[index] as Dictionary
		var event_index_value: Variant = event.get("index", null)
		var event_seed_value: Variant = event.get("event_seed", null)
		if not _integer_in_range(event_index_value, 0, MAX_SEED_VALUE):
			errors.append("Event %d index must be a bounded non-negative integer" % index)
			continue
		if not _integer_in_range(event_seed_value, 0, MAX_SEED_VALUE):
			errors.append("Event %d seed must be a bounded non-negative integer" % index)
			continue
		var source_index := int(event_index_value)
		if seen_indices.has(source_index):
			errors.append("Event schedule contains duplicate event index %d" % source_index)
		seen_indices[source_index] = true
		var compiled_seed := int(event_seed_value) ^ runtime_seed
		var wave_id := _wave_key(room_id, source_index, compiled_seed)
		if seen_wave_ids.has(wave_id):
			errors.append("Event schedule contains duplicate wave ownership %s" % wave_id)
		seen_wave_ids[wave_id] = true
		if defender_id != "none":
			var actor_id := "actor:%s" % wave_id
			if seen_actor_ids.has(actor_id):
				errors.append("Event schedule contains duplicate actor ownership %s" % actor_id)
			seen_actor_ids[actor_id] = true
		var telegraph_value: Variant = event.get("telegraph_at", null)
		var active_value: Variant = event.get("active_at", null)
		var clear_value: Variant = event.get("clear_at", null)
		if not _number_in_range(telegraph_value, 0.0, duration) or not _number_in_range(active_value, 0.0, duration) or not _number_in_range(clear_value, 0.0, duration):
			errors.append("Event %d timing must be finite and remain within room duration" % index)
			continue
		var telegraph_at := float(telegraph_value)
		var active_at := float(active_value)
		var clear_at := float(clear_value)
		var active_seconds := clear_at - active_at
		if active_at <= telegraph_at or clear_at <= active_at:
			errors.append("Event %d timing is not telegraph-before-active-before-clear" % index)
		if active_seconds < MIN_ACTIVE_WINDOW_SECONDS - 0.000001 or active_seconds > MAX_ACTIVE_WINDOW_SECONDS + 0.000001:
			errors.append("Event %d active window is outside executable bounds" % index)
		if absf((active_at - telegraph_at) - telegraph_seconds) > 0.001:
			errors.append("Event %d telegraph window diverges from canonical room timing" % index)
		if absf(active_seconds - authored_active_seconds) > 0.001:
			errors.append("Event %d active window diverges from canonical room timing" % index)
		if prior_active_at >= 0.0 and absf((active_at - prior_active_at) - cadence) > 0.001:
			errors.append("Event %d activation cadence diverges from canonical room timing" % index)
		if prior_clear_at >= 0.0 and telegraph_at < prior_clear_at + MIN_EVENT_GAP_SECONDS - 0.000001:
			errors.append("Event %d overlaps the prior event or its reaction gap" % index)
		prior_active_at = active_at
		prior_clear_at = clear_at
		var safe_position_value: Variant = event.get("safe_position", null)
		if typeof(safe_position_value) != TYPE_ARRAY or not _finite_normalized_point(safe_position_value as Array):
			errors.append("Event %d has no finite normalized safe position" % index)
		if not _number_in_range(event.get("phase", 0.0), 0.0, 1.0):
			errors.append("Event %d phase must be finite and normalized" % index)
		if not _integer_in_range(event.get("safe_lane", null), 0, lane_count - 1):
			errors.append("Event %d safe lane must be an integer within movement lane count" % index)
		if not _integer_in_range(event.get("spawn_count", null), 1, MAX_SOURCE_REQUEST_COUNT):
			errors.append("Event %d spawn count must be a positive integer" % index)
		var hazard_lanes_value: Variant = event.get("hazard_lanes", null)
		if typeof(hazard_lanes_value) != TYPE_ARRAY or (hazard_lanes_value as Array).size() > MAX_HAZARDS_PER_EVENT:
			errors.append("Event %d hazard lanes are missing or unbounded" % index)
		else:
			for lane_value in hazard_lanes_value as Array:
				if not _integer_in_range(lane_value, 0, maxi(0, lane_count - 1)):
					errors.append("Event %d hazard lane must be a bounded integer" % index)
					break
	return errors


static func validate_plan(plan: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not bool(plan.get("valid", false)):
		errors.append("Execution plan is marked invalid")
		return errors
	if not _integer_in_range(plan.get("version", null), PLAN_VERSION, PLAN_VERSION):
		errors.append("Execution plan version is unsupported")
	if String(plan.get("coordinate_space", "")) != COORDINATE_SPACE:
		errors.append("Execution plan coordinate space is unsupported")
	var duration_value: Variant = plan.get("duration", null)
	if not _number_in_range(duration_value, MIN_ACTIVE_WINDOW_SECONDS, MAX_ROOM_DURATION_SECONDS):
		errors.append("Plan duration must be finite and bounded")
	var duration := float(duration_value) if _is_finite_number(duration_value) else 0.0
	if not _integer_in_range(plan.get("runtime_seed", null), 0, MAX_SEED_VALUE):
		errors.append("Plan runtime seed must be a bounded non-negative integer")
	var room_id := String(plan.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		errors.append("Plan requires a stable room id")
	var timing_value: Variant = plan.get("timing", null)
	if typeof(timing_value) != TYPE_DICTIONARY:
		errors.append("Plan timing payload must be a dictionary")
	var timing := timing_value as Dictionary if typeof(timing_value) == TYPE_DICTIONARY else {}
	_validate_timing_payload(timing, duration, "Plan", errors)
	var cadence := float(timing.get("cadence", 0.0)) if _is_finite_number(timing.get("cadence", null)) else 0.0
	var telegraph_seconds := float(timing.get("telegraph_seconds", 0.0)) if _is_finite_number(timing.get("telegraph_seconds", null)) else 0.0
	var authored_active_seconds := float(timing.get("active_seconds", 0.0)) if _is_finite_number(timing.get("active_seconds", null)) else 0.0
	var source_value: Variant = plan.get("source", null)
	if typeof(source_value) != TYPE_DICTIONARY:
		errors.append("Plan source payload must be a dictionary")
		return errors
	var source := source_value as Dictionary
	var spawn_pattern := String(source.get("spawn_pattern", ""))
	var projectile_pattern := String(source.get("projectile_pattern", ""))
	var movement_model := String(source.get("movement_model", ""))
	if not SPAWN_BEHAVIORS.has(spawn_pattern):
		errors.append("Plan lost its spawn.pattern mapping")
	if not PROJECTILE_BEHAVIORS.has(projectile_pattern):
		errors.append("Plan lost its projectile.pattern mapping")
	if not MOVEMENT_BEHAVIORS.has(movement_model):
		errors.append("Plan lost its movement.model mapping")
	if not SPAWN_BEHAVIORS.has(spawn_pattern) or not PROJECTILE_BEHAVIORS.has(projectile_pattern) or not MOVEMENT_BEHAVIORS.has(movement_model):
		return errors
	var expected_spawn_behavior := SPAWN_BEHAVIORS[spawn_pattern] as Dictionary
	var expected_projectile_behavior := PROJECTILE_BEHAVIORS[projectile_pattern] as Dictionary
	var expected_movement_behavior := MOVEMENT_BEHAVIORS[movement_model] as Dictionary
	var expected_defender_id := String(expected_spawn_behavior.get("defender", "none"))
	var expected_defender_behavior: Dictionary = {} if expected_defender_id == "none" else DEFENDER_ARCHETYPES[expected_defender_id] as Dictionary
	if String(plan.get("defender_archetype", "")) != expected_defender_id or plan.get("defender_behavior", null) != expected_defender_behavior:
		errors.append("Plan defender identity diverges from its canonical spawn profile")
	var expected_plan_visual := _visual_signature(spawn_pattern, expected_spawn_behavior, projectile_pattern, expected_projectile_behavior, movement_model, expected_movement_behavior, expected_defender_id, -1, int(plan.get("runtime_seed", 0)))
	if String(plan.get("visual_signature", "")) != expected_plan_visual:
		errors.append("Plan visual identity diverges from its canonical registry profile")
	var safe_path_value: Variant = plan.get("safe_path", null)
	var safe_path_is_valid := false
	if typeof(safe_path_value) != TYPE_ARRAY:
		errors.append("Plan safe path must be an array")
	else:
		var safe_path_error_count := errors.size()
		_validate_safe_path_payload(safe_path_value as Array, duration, "Plan", errors)
		safe_path_is_valid = errors.size() == safe_path_error_count
	if String(plan.get("safe_path_signature", "")).is_empty():
		errors.append("Plan must expose a safe-path signature")
	elif safe_path_is_valid and String(plan.get("safe_path_signature", "")) != safe_path_signature(safe_path_value as Array):
		errors.append("Plan safe-path signature does not match its canonical payload")
	if String(plan.get("visual_signature", "")).is_empty() or String(plan.get("geometry_signature", "")).is_empty() or String(plan.get("lifecycle_signature", "")).is_empty() or String(plan.get("plan_signature", "")).is_empty():
		errors.append("Plan must expose visual and replay signatures")
	var events_value: Variant = plan.get("events", null)
	if typeof(events_value) != TYPE_ARRAY:
		errors.append("Plan events payload must be an array")
		return errors
	var events := events_value as Array
	if events.is_empty() or events.size() > MAX_EVENTS:
		errors.append("Plan event count is empty or unbounded")
		return errors
	var seen_indices: Dictionary = {}
	var seen_wave_ids: Dictionary = {}
	var seen_actor_ids: Dictionary = {}
	var prior_active_at := -1.0
	var prior_clear_at := -1.0
	for event_ordinal in range(events.size()):
		if typeof(events[event_ordinal]) != TYPE_DICTIONARY:
			errors.append("Plan event %d must be a dictionary" % event_ordinal)
			break
		var event := events[event_ordinal] as Dictionary
		var spawn_value: Variant = event.get("spawn", null)
		var projectile_value: Variant = event.get("projectile", null)
		var movement_value: Variant = event.get("movement", null)
		if typeof(spawn_value) != TYPE_DICTIONARY or typeof(projectile_value) != TYPE_DICTIONARY or typeof(movement_value) != TYPE_DICTIONARY:
			errors.append("Plan event spawn, projectile, and movement payloads must be dictionaries")
			break
		var spawn := spawn_value as Dictionary
		var projectile := projectile_value as Dictionary
		var movement := movement_value as Dictionary
		var event_index_value: Variant = event.get("index", null)
		if not _integer_in_range(event_index_value, 0, MAX_SEED_VALUE):
			errors.append("Plan event index must be a bounded non-negative integer")
			break
		var event_index := int(event_index_value)
		if seen_indices.has(event_index):
			errors.append("Plan event indices must be globally unique")
			break
		seen_indices[event_index] = true
		var event_seed_value: Variant = event.get("event_seed", null)
		if not _integer_in_range(event_seed_value, 0, MAX_SEED_VALUE):
			errors.append("Plan event seed must be a bounded non-negative integer")
			break
		var event_seed := int(event_seed_value)
		var expected_owner_wave_id := _wave_key(room_id, event_index, event_seed)
		if String(spawn.get("source_pattern", "")) != spawn_pattern \
			or String(spawn.get("primitive", "")) != String(expected_spawn_behavior.get("primitive", "")) \
			or String(spawn.get("visual_token", "")) != String(expected_spawn_behavior.get("visual", "")) \
			or String(spawn.get("defender_archetype", "")) != expected_defender_id \
			or spawn.get("defender_behavior", null) != expected_defender_behavior:
			errors.append("Event spawn payload diverges from its canonical registry profile")
			break
		if String(projectile.get("source_pattern", "")) != projectile_pattern \
			or String(projectile.get("primitive", "")) != String(expected_projectile_behavior.get("primitive", "")) \
			or String(projectile.get("visual_token", "")) != String(expected_projectile_behavior.get("visual", "")) \
			or String(projectile.get("travel_model", "")) != String(expected_projectile_behavior.get("travel", "")):
			errors.append("Event projectile payload diverges from its canonical registry profile")
			break
		if String(movement.get("source_model", "")) != movement_model \
			or String(movement.get("primitive", "")) != String(expected_movement_behavior.get("primitive", "")) \
			or String(movement.get("visual_token", "")) != String(expected_movement_behavior.get("visual", "")):
			errors.append("Event movement payload diverges from its canonical registry profile")
			break
		var expected_event_visual := _visual_signature(spawn_pattern, expected_spawn_behavior, projectile_pattern, expected_projectile_behavior, movement_model, expected_movement_behavior, expected_defender_id, event_index, event_seed)
		if String(event.get("visual_signature", "")) != expected_event_visual:
			errors.append("Event visual identity diverges from its canonical registry profile")
			break
		var telegraph_value: Variant = event.get("telegraph_at", null)
		var active_value: Variant = event.get("active_at", null)
		var clear_value: Variant = event.get("clear_at", null)
		if not _number_in_range(telegraph_value, 0.0, duration) or not _number_in_range(active_value, 0.0, duration) or not _number_in_range(clear_value, 0.0, duration):
			errors.append("Event timing must be finite and remain within room duration")
			break
		var telegraph_at := float(telegraph_value)
		var active_at := float(active_value)
		var clear_at := float(clear_value)
		var active_seconds := clear_at - active_at
		if String(event.get("runtime_category", "")) != runtime_category_for_event(event):
			errors.append("Event runtime category diverges from its canonical profile")
			break
		if telegraph_at < 0.0 or active_at <= telegraph_at or clear_at <= active_at:
			errors.append("Event timing is not telegraph-before-active-before-clear")
			break
		if active_seconds < MIN_ACTIVE_WINDOW_SECONDS - 0.000001 or active_seconds > MAX_ACTIVE_WINDOW_SECONDS + 0.000001:
			errors.append("Event active window is outside executable bounds")
			break
		if absf((active_at - telegraph_at) - telegraph_seconds) > 0.001 or absf(active_seconds - authored_active_seconds) > 0.001:
			errors.append("Event timing diverges from the canonical plan timing payload")
			break
		if prior_active_at >= 0.0 and absf((active_at - prior_active_at) - cadence) > 0.001:
			errors.append("Event activation cadence diverges from canonical plan timing")
			break
		if prior_clear_at >= 0.0 and telegraph_at < prior_clear_at + MIN_EVENT_GAP_SECONDS - 0.000001:
			errors.append("Plan events overlap or omit the bounded reaction gap")
			break
		prior_active_at = active_at
		prior_clear_at = clear_at
		var collision_value: Variant = spawn.get("collision", null)
		if typeof(collision_value) != TYPE_DICTIONARY:
			errors.append("Event movement/collision payload is malformed")
			break
		_validate_movement_plan_payload(movement, duration, errors)
		_validate_collision_payload(collision_value as Dictionary, errors)
		_validate_projectile_plan_payload(projectile, active_seconds, errors)
		if not errors.is_empty():
			break
		var collision := collision_value as Dictionary
		var canonical_collision := _collision_for_primitive(String(expected_spawn_behavior.get("primitive", "")), float(collision.get("damage", 0.0)))
		if collision != canonical_collision:
			errors.append("Event collision payload diverges from its canonical spawn primitive")
			break
		var canonical_projectile_enabled := String(expected_projectile_behavior.get("travel", "none")) != "none"
		if canonical_projectile_enabled != (int(projectile.get("count", 0)) > 0):
			errors.append("Event projectile count diverges from its canonical structural/emission profile")
			break
		if not _integer_in_range(spawn.get("hazard_count", null), 0, MAX_HAZARDS_PER_EVENT):
			errors.append("Event hazard count exceeds its cap")
			break
		if not _integer_in_range(spawn.get("enemy_count", null), 0, MAX_ENEMIES_PER_EVENT):
			errors.append("Event enemy count exceeds its cap")
			break
		if not _integer_in_range(spawn.get("max_active_enemies", null), 1, MAX_ACTIVE_ENEMIES):
			errors.append("Active enemy cap exceeds the runtime ceiling")
			break
		if not _integer_in_range(projectile.get("count", null), 0, MAX_PROJECTILES_PER_EVENT):
			errors.append("Event projectile count exceeds its cap")
			break
		if not _integer_in_range(projectile.get("max_active", null), 0, MAX_ACTIVE_PROJECTILES):
			errors.append("Active projectile cap exceeds the runtime ceiling")
			break
		if (expected_defender_id == "none") != (int(spawn.get("enemy_count", 0)) == 0):
			errors.append("Event enemy count diverges from its canonical defender profile")
			break
		var positions_value: Variant = spawn.get("positions", null)
		if typeof(positions_value) != TYPE_ARRAY:
			errors.append("Spawn plan positions must be an array")
			break
		var positions := positions_value as Array
		if positions.size() != int(spawn.get("hazard_count", 0)) or positions.size() < int(spawn.get("enemy_count", 0)) or positions.size() > MAX_HAZARDS_PER_EVENT:
			errors.append("Spawn plan positions are missing or unbounded")
			break
		if int(spawn.get("max_active_enemies", 0)) < int(spawn.get("enemy_count", 0)):
			errors.append("Active enemy cap is below the executable enemy count")
			break
		for raw_position in positions:
			if typeof(raw_position) != TYPE_DICTIONARY:
				errors.append("Spawn position record is malformed")
				break
			var position_value: Variant = (raw_position as Dictionary).get("position", null)
			if typeof(position_value) != TYPE_ARRAY or not _finite_normalized_point(position_value as Array):
				errors.append("Spawn position leaves room-normalized space")
				break
		if not errors.is_empty():
			break
		var safe_value: Variant = event.get("safe", null)
		if typeof(safe_value) != TYPE_DICTIONARY:
			errors.append("Event safe payload must be a dictionary")
			break
		var safe := safe_value as Dictionary
		var compiled_lane_count := int(movement.get("lane_count", 0)) if typeof(movement.get("lane_count", null)) == TYPE_INT else 0
		if not _integer_in_range(safe.get("lane", null), 0, compiled_lane_count - 1):
			errors.append("Event safe lane must be an integer within compiled movement lane count")
			break
		var safe_position_value: Variant = safe.get("position", null)
		if typeof(safe_position_value) != TYPE_ARRAY:
			errors.append("Event safe position must be an array")
			break
		var safe_position := safe_position_value as Array
		var safe_clearance := float(safe.get("clearance", 0.0)) if _is_finite_number(safe.get("clearance", null)) else -1.0
		var player_radius := float(safe.get("player_radius_normalized", -1.0)) if _is_finite_number(safe.get("player_radius_normalized", null)) else -1.0
		if not _finite_normalized_point(safe_position) or safe_clearance <= 0.0 or safe_clearance > MAX_SAFE_CLEARANCE_NORMALIZED:
			errors.append("Event safe disk is invalid")
			break
		if player_radius < PLAYER_RADIUS_NORMALIZED - 0.000001:
			errors.append("Event safe disk omits the bounded player radius")
			break
		if not structural_geometry_clears_safe_disk(positions, spawn.get("collision", {}) as Dictionary, safe_position, safe_clearance, player_radius):
			errors.append("Structural collision geometry intersects the published safe disk")
			break
		var projectile_count := int(projectile.get("count", 0))
		if projectile_count > 0:
			var expected_target_mode := "player_snapshot" if float(projectile.get("tracking_strength", 0.0)) > 0.0 else "authored_safe_corridor"
			if String(projectile.get("target_mode", "")) != expected_target_mode or String(projectile.get("damage_source", "")) != "room_projectile:%s" % projectile_pattern:
				errors.append("Projectile target/damage identity diverges from its canonical profile")
				break
			if (projectile.get("directions_degrees", []) as Array).size() != projectile_count:
				errors.append("Projectile direction count does not match its emission count")
				break
			if (projectile.get("emitters", []) as Array).is_empty():
				errors.append("Projectile plan has no emitter")
				break
			if not is_equal_approx(float(projectile.get("lifetime_seconds", -1.0)), active_seconds):
				errors.append("Projectile lifetime must end at the transient wave boundary")
				break
			if float(projectile.get("authored_lifetime_seconds", 0.0)) <= 0.0:
				errors.append("Projectile plan lost its non-blocking authored lifetime metadata")
				break
			var expected_delay := _delayed_emission_seconds(projectile, active_seconds)
			if not is_equal_approx(float(projectile.get("max_delay_seconds", -1.0)), expected_delay):
				errors.append("Projectile delayed tail does not match its bounded emission plan")
				break
			if expected_delay > MAX_DELAYED_EMISSION_SECONDS + 0.000001 or expected_delay >= active_seconds - EMISSION_BOUNDARY_GUARD_SECONDS + 0.000001:
				errors.append("Projectile delayed emission crosses the transient wave boundary")
				break
			var expected_threat_time := _threat_time_seconds(active_seconds)
			if not is_equal_approx(float(projectile.get("threat_time_seconds", -1.0)), expected_threat_time):
				errors.append("Projectile threat timing does not match the executable active window")
				break
			if float(projectile.get("threat_time_seconds", 0.0)) > active_seconds - EMISSION_BOUNDARY_GUARD_SECONDS + 0.000001:
				errors.append("Projectile threat timing crosses the transient wave boundary")
				break
		elif not is_zero_approx(float(projectile.get("lifetime_seconds", 0.0))) or not is_zero_approx(float(projectile.get("max_delay_seconds", 0.0))) or not is_zero_approx(float(projectile.get("threat_time_seconds", 0.0))) or String(projectile.get("damage_source", "")) != "none":
			errors.append("Structural-only projectile plan fabricated transient lifetime metadata")
			break
		var owner_wave_id := String(event.get("owner_wave_id", ""))
		if owner_wave_id != expected_owner_wave_id or String(event.get("wave_key", "")) != owner_wave_id or String(projectile.get("owner_wave_id", "")) != owner_wave_id or String(projectile.get("parent_wave_key", "")) != owner_wave_id or String(spawn.get("owner_wave_id", "")) != owner_wave_id or String(spawn.get("wave_key", "")) != owner_wave_id or String(movement.get("owner_wave_id", "")) != owner_wave_id:
			errors.append("Event/projectile cleanup attribution is incomplete")
			break
		if seen_wave_ids.has(owner_wave_id):
			errors.append("Plan wave ownership must be globally unique")
			break
		seen_wave_ids[owner_wave_id] = true
		var telegraph_payload_value: Variant = event.get("telegraph", null)
		if typeof(telegraph_payload_value) != TYPE_DICTIONARY:
			errors.append("Event telegraph payload must be a dictionary")
			break
		var telegraph := telegraph_payload_value as Dictionary
		if telegraph.is_empty():
			errors.append("Event has no explicit telegraph drawing plan")
			break
		if String(telegraph.get("owner_wave_id", "")) != owner_wave_id \
			or String(telegraph.get("coordinate_space", "")) != COORDINATE_SPACE \
			or String(telegraph.get("motif", "")) != String(expected_spawn_behavior.get("visual", "")) \
			or String(telegraph.get("projectile_motif", "")) != String(expected_projectile_behavior.get("visual", "")) \
			or String(telegraph.get("motion_motif", "")) != String(expected_movement_behavior.get("visual", "")) \
			or String(telegraph.get("signature", "")) != expected_event_visual \
			or not is_equal_approx(float(telegraph.get("starts_at", -1.0)), telegraph_at) \
			or not is_equal_approx(float(telegraph.get("ends_at", -1.0)), active_at) \
			or telegraph.get("positions", []) != positions \
			or telegraph.get("safe_position", []) != safe_position \
			or not is_equal_approx(float(telegraph.get("safe_clearance", -1.0)), safe_clearance):
			errors.append("Telegraph payload diverges from executable event geometry/timing")
			break
		var operations_value: Variant = event.get("operations", null)
		if typeof(operations_value) != TYPE_ARRAY:
			errors.append("Event operations payload must be an array")
			break
		var operations := operations_value as Array
		if operations.size() != 6:
			errors.append("Event execution operations are incomplete")
			break
		var expected_emission_operation := "emit_projectiles" if projectile_count > 0 else "hold_structural_hazard"
		var expected_operations := ["telegraph", "apply_movement", "spawn", expected_emission_operation, "close_emitter", "clear_wave"]
		for operation_index in range(operations.size()):
			if typeof(operations[operation_index]) != TYPE_DICTIONARY:
				errors.append("Event lifecycle operation must be a dictionary")
				break
			var operation := operations[operation_index] as Dictionary
			if String(operation.get("op", "")) != String(expected_operations[operation_index]):
				errors.append("Event lifecycle operations are out of order")
				break
			if String(operation.get("owner_wave_id", "")) != String(event.get("owner_wave_id", "")):
				errors.append("Event operation lost transient-wave ownership")
				break
		if not errors.is_empty():
			break
		var spawn_operation := operations[2] as Dictionary
		var emission_operation := operations[3] as Dictionary
		var close_operation := operations[4] as Dictionary
		var clear_operation := operations[5] as Dictionary
		var telegraph_operation := operations[0] as Dictionary
		var movement_operation := operations[1] as Dictionary
		if typeof(telegraph_operation.get("plan", null)) != TYPE_DICTIONARY or typeof(movement_operation.get("plan", null)) != TYPE_DICTIONARY or typeof(spawn_operation.get("plan", null)) != TYPE_DICTIONARY or (projectile_count > 0 and typeof(emission_operation.get("plan", null)) != TYPE_DICTIONARY):
			errors.append("Event lifecycle operation plan must be a dictionary")
			break
		if not is_equal_approx(float(telegraph_operation.get("at", -1.0)), telegraph_at) or (telegraph_operation.get("plan", {}) as Dictionary) != telegraph:
			errors.append("Telegraph operation diverges from the event telegraph plan")
			break
		if not is_equal_approx(float(movement_operation.get("at", -1.0)), telegraph_at) or not is_equal_approx(float(movement_operation.get("until", -1.0)), clear_at) or (movement_operation.get("plan", {}) as Dictionary) != (event.get("movement", {}) as Dictionary):
			errors.append("Movement operation diverges from the event movement plan")
			break
		if not is_equal_approx(float(spawn_operation.get("at", -1.0)), active_at):
			errors.append("Spawn operation does not start at event activation")
			break
		if (spawn_operation.get("plan", {}) as Dictionary) != spawn:
			errors.append("Spawn operation plan diverges from the event spawn plan")
			break
		if projectile_count > 0 and (emission_operation.get("plan", {}) as Dictionary) != projectile:
			errors.append("Projectile operation plan diverges from the event projectile plan")
			break
		if not is_equal_approx(float(emission_operation.get("at", -1.0)), active_at):
			errors.append("Emission/structural operation does not start at event activation")
			break
		if projectile_count == 0 and (not is_equal_approx(float(emission_operation.get("until", -1.0)), clear_at) or emission_operation.get("collision", {}) != spawn.get("collision", {}) or emission_operation.get("positions", []) != positions):
			errors.append("Structural hold operation diverges from event collision geometry")
			break
		if not is_equal_approx(float(close_operation.get("at", -1.0)), clear_at):
			errors.append("Emitter must close at the authored transient boundary")
			break
		if not is_equal_approx(float(clear_operation.get("at", -1.0)), clear_at) or String(clear_operation.get("mode", "")) != "force" or String(clear_operation.get("reason", "")) != "transient_boundary" or clear_operation.has("when") or clear_operation.has("timeout_seconds"):
			errors.append("Transient wave must force-clear at its authored boundary")
			break
		if close_operation.has("actor_owner_id") or clear_operation.has("actor_owner_id"):
			errors.append("Transient cleanup must not target the independent defender owner")
			break
		var actor_owner_id := String(spawn.get("actor_owner_id", ""))
		var actor_resolution_seconds := float(spawn.get("actor_resolution_seconds", -1.0)) if _is_finite_number(spawn.get("actor_resolution_seconds", null)) else -1.0
		var enemy_count := int(spawn.get("enemy_count", 0))
		if enemy_count > 0:
			var expected_actor_seconds := _actor_resolution_seconds(spawn)
			if actor_owner_id != "actor:%s" % expected_owner_wave_id:
				errors.append("Defenders must use an owner separate from the transient wave")
				break
			if seen_actor_ids.has(actor_owner_id):
				errors.append("Plan actor ownership must be globally unique")
				break
			seen_actor_ids[actor_owner_id] = true
			if actor_resolution_seconds < MIN_ACTOR_RESOLUTION_SECONDS or actor_resolution_seconds > ARMORED_ACTOR_RESOLUTION_SECONDS or not is_equal_approx(actor_resolution_seconds, expected_actor_seconds):
				errors.append("Defender actor resolution window is invalid")
				break
			if String(spawn_operation.get("actor_owner_id", "")) != actor_owner_id or not is_equal_approx(float(spawn_operation.get("actor_resolution_seconds", -1.0)), actor_resolution_seconds):
				errors.append("Spawn operation lost defender actor resolution metadata")
				break
			if bool(spawn_operation.get("blocks_next_event", true)) or not bool(spawn_operation.get("blocks_room_exit", false)):
				errors.append("Defender actors must not serialize telegraphs but must resolve before room exit")
				break
		elif not actor_owner_id.is_empty() or not is_zero_approx(actor_resolution_seconds) or bool(spawn_operation.get("blocks_next_event", false)) or bool(spawn_operation.get("blocks_room_exit", false)):
			errors.append("Actor-free spawn plan must not fabricate ownership or blocking flags")
			break
		if String(event.get("visual_signature", "")).is_empty() or String(event.get("safe_signature", "")).is_empty() or String(event.get("geometry_signature", "")).is_empty() or String(event.get("lifecycle_signature", "")).is_empty():
			errors.append("Event signatures are incomplete")
			break
		if String(event.get("geometry_signature", "")) != geometry_signature_for_event(event):
			errors.append("Event geometry signature does not match executable topology")
			break
		if String(event.get("lifecycle_signature", "")) != lifecycle_signature_for_event(event):
			errors.append("Event lifecycle signature does not match executable operations")
			break
	var semantic_plan_is_safe_to_digest := errors.is_empty()
	if semantic_plan_is_safe_to_digest:
		if String(plan.get("geometry_signature", "")) != geometry_signature_for_plan(plan):
			errors.append("Plan geometry signature does not match executable topology")
		if String(plan.get("lifecycle_signature", "")) != lifecycle_signature_for_plan(plan):
			errors.append("Plan lifecycle signature does not match executable operations")
		if String(plan.get("plan_signature", "")) != _plan_signature(plan):
			errors.append("Plan signature does not match its compiled lifecycle")
	return errors


static func validate_catalog(rooms: Array, challenge_seed: int = 0x1F1D1E) -> PackedStringArray:
	var errors := validate_runtime_registry()
	for index in range(rooms.size()):
		if typeof(rooms[index]) != TYPE_DICTIONARY:
			errors.append("Room catalog entry %d is not a dictionary" % index)
			continue
		var room := rooms[index] as Dictionary
		var contract := RoomMechanicsScript.build_contract(room, challenge_seed + index * 977)
		var source_errors := validate_source_contract(contract)
		for error in source_errors:
			errors.append("%s: %s" % [String(room.get("id", index)), String(error)])
		if not source_errors.is_empty():
			continue
		var plan := compile_contract(contract)
		if not bool(plan.get("valid", false)):
			for error in plan.get("errors", []):
				errors.append("%s: %s" % [String(room.get("id", index)), String(error)])
	return errors


static func validate_runtime_registry() -> PackedStringArray:
	var errors := PackedStringArray()
	for pattern in SPAWN_BEHAVIORS:
		var behavior := SPAWN_BEHAVIORS[pattern] as Dictionary
		if String(behavior.get("primitive", "")).is_empty() or String(behavior.get("visual", "")).is_empty():
			errors.append("spawn.pattern %s has an incomplete behavior" % String(pattern))
		var defender := String(behavior.get("defender", ""))
		if defender != "none" and not DEFENDER_ARCHETYPES.has(defender):
			errors.append("spawn.pattern %s references unknown defender %s" % [String(pattern), defender])
	for pattern in PROJECTILE_BEHAVIORS:
		var behavior := PROJECTILE_BEHAVIORS[pattern] as Dictionary
		if String(behavior.get("primitive", "")).is_empty() or String(behavior.get("visual", "")).is_empty() or String(behavior.get("travel", "")).is_empty():
			errors.append("projectile.pattern %s has an incomplete behavior" % String(pattern))
	for model in MOVEMENT_BEHAVIORS:
		var behavior := MOVEMENT_BEHAVIORS[model] as Dictionary
		if String(behavior.get("primitive", "")).is_empty() or String(behavior.get("visual", "")).is_empty():
			errors.append("movement.model %s has an incomplete behavior" % String(model))
	for archetype in DEFENDER_ARCHETYPES:
		var behavior := DEFENDER_ARCHETYPES[archetype] as Dictionary
		for required in ["motion", "attack", "health_class", "collision_role"]:
			if String(behavior.get(required, "")).is_empty():
				errors.append("Defender archetype %s is missing %s" % [String(archetype), required])
	return errors


static func supported_spawn_patterns() -> PackedStringArray:
	return _sorted_keys(SPAWN_BEHAVIORS)


static func supported_projectile_patterns() -> PackedStringArray:
	return _sorted_keys(PROJECTILE_BEHAVIORS)


static func supported_movement_models() -> PackedStringArray:
	return _sorted_keys(MOVEMENT_BEHAVIORS)


static func supported_defender_archetypes() -> PackedStringArray:
	return _sorted_keys(DEFENDER_ARCHETYPES)


static func runtime_category_for_event(event: Dictionary) -> String:
	var movement := event.get("movement", {}) as Dictionary
	var spawn := event.get("spawn", {}) as Dictionary
	var primitive := String(spawn.get("primitive", ""))
	if String(movement.get("source_model", "")) == "replay" or primitive in ["replay_trace", "tracked_pack"]:
		return "echo"
	if primitive in ["sweep_wall", "cone_sweep"]:
		return "sweep"
	if primitive == "node_chain":
		return "node"
	if String(spawn.get("defender_archetype", "none")) != "none":
		return "spawn"
	if primitive in ["lane_gate", "paired_barrier", "grid_cells", "pocket_field"]:
		return "gate"
	if primitive == "drop_field":
		return "rain"
	if primitive in ["rotating_arc", "radial_cluster"]:
		return "radial"
	if primitive in ["sweep_field", "gravity_field"]:
		return "field"
	return "gate"


static func supported_primitives() -> PackedStringArray:
	var values: Dictionary = {}
	for behavior in SPAWN_BEHAVIORS.values():
		values[String((behavior as Dictionary).primitive)] = true
	for behavior in PROJECTILE_BEHAVIORS.values():
		values[String((behavior as Dictionary).primitive)] = true
	for behavior in MOVEMENT_BEHAVIORS.values():
		values[String((behavior as Dictionary).primitive)] = true
	return _sorted_keys(values)


static func safe_path_signature(safe_path: Array) -> String:
	var parts := PackedStringArray(["safe-v1"])
	for raw_waypoint in safe_path:
		var waypoint := raw_waypoint as Dictionary
		var position := waypoint.get("position", []) as Array
		if position.size() != 2:
			parts.append("invalid")
			continue
		parts.append("%d:%d:%d:%d" % [
			roundi(float(waypoint.get("time", 0.0)) * 1000.0),
			roundi(float(position[0]) * 10000.0),
			roundi(float(position[1]) * 10000.0),
			roundi(float(waypoint.get("clearance", 0.0)) * 10000.0),
		])
	return "|".join(parts)


static func geometry_signature_for_plan(plan: Dictionary) -> String:
	# Hash the complete executable plan payload, not a hand-maintained projection.
	# Keeping events separate avoids making their own derived signatures recursive
	# while still making future executable fields part of replay identity by
	# default.
	var plan_payload := plan.duplicate(true)
	plan_payload.erase("events")
	plan_payload.erase("geometry_signature")
	plan_payload.erase("lifecycle_signature")
	plan_payload.erase("plan_signature")
	var parts := PackedStringArray(["geometry-v2", _canonical_json(plan_payload)])
	for raw_event in plan.get("events", []):
		parts.append(geometry_signature_for_event(raw_event as Dictionary))
	return "geometry-v2:%s" % "|".join(parts).sha256_text().left(32)


static func geometry_signature_for_event(event: Dictionary) -> String:
	# The event payload contains the exact telegraph, movement, spawn, collision,
	# emitter, projectile, and operation plans consumed by executors. Canonical
	# JSON covers every present executable field (including future additions)
	# while excluding only signatures derived from this same payload.
	var event_payload := event.duplicate(true)
	event_payload.erase("geometry_signature")
	event_payload.erase("lifecycle_signature")
	event_payload.erase("plan_signature")
	return "event-geometry-v2:%s" % _canonical_json(event_payload).sha256_text().left(32)


static func lifecycle_signature_for_plan(plan: Dictionary) -> String:
	var parts := PackedStringArray(["lifecycle-v2"])
	for raw_event in plan.get("events", []):
		parts.append(lifecycle_signature_for_event(raw_event as Dictionary))
	return "|".join(parts)


static func lifecycle_signature_for_event(event: Dictionary) -> String:
	var parts := PackedStringArray([
		"event-lifecycle-v2",
		String(event.get("owner_wave_id", "")),
		"t%d:%d:%d" % [
			roundi(float(event.get("telegraph_at", 0.0)) * 1000.0),
			roundi(float(event.get("active_at", 0.0)) * 1000.0),
			roundi(float(event.get("clear_at", 0.0)) * 1000.0),
		],
	])
	var spawn := event.get("spawn", {}) as Dictionary
	parts.append("actor:%s:%d:%d" % [
		String(spawn.get("actor_owner_id", "")),
		roundi(float(spawn.get("actor_resolution_seconds", 0.0)) * 1000.0),
		int(spawn.get("enemy_count", 0)),
	])
	var projectile := event.get("projectile", {}) as Dictionary
	parts.append("projectile:%d:%d:%d:%d" % [
		int(projectile.get("count", 0)),
		roundi(float(projectile.get("lifetime_seconds", 0.0)) * 1000.0),
		roundi(float(projectile.get("max_delay_seconds", 0.0)) * 1000.0),
		roundi(float(projectile.get("threat_time_seconds", 0.0)) * 1000.0),
	])
	for raw_operation in event.get("operations", []):
		var operation := raw_operation as Dictionary
		parts.append("%s@%d>%d:%s:%s:%s:%d:%d:%d" % [
			String(operation.get("op", "")),
			roundi(float(operation.get("at", -1.0)) * 1000.0),
			roundi(float(operation.get("until", -1.0)) * 1000.0),
			String(operation.get("mode", "")),
			String(operation.get("reason", "")),
			String(operation.get("actor_owner_id", "")),
			roundi(float(operation.get("actor_resolution_seconds", 0.0)) * 1000.0),
			1 if bool(operation.get("blocks_room_exit", false)) else 0,
			1 if bool(operation.get("blocks_next_event", false)) else 0,
		])
	return ":".join(parts)


static func _compile_event(
	contract: Dictionary,
	event: Dictionary,
	movement_id: String,
	movement_behavior: Dictionary,
	spawn_id: String,
	spawn_behavior: Dictionary,
	projectile_id: String,
	projectile_behavior: Dictionary,
	defender_id: String
) -> Dictionary:
	var safe_position := (event.get("safe_position", [0.5, 0.5]) as Array).duplicate()
	var event_seed := int(event.get("event_seed", 0)) ^ int(contract.get("runtime_seed", 0))
	var wave_key := _wave_key(String(contract.get("room_id", "room")), int(event.get("index", 0)), event_seed)
	var spawn_plan := _compile_spawn(contract, event, spawn_id, spawn_behavior, defender_id, event_seed)
	var projectile_plan := _compile_projectiles(contract, event, projectile_id, projectile_behavior, spawn_plan, event_seed)
	var actor_resolution_seconds := _actor_resolution_seconds(spawn_plan)
	var actor_owner_id := "actor:%s" % wave_key if actor_resolution_seconds > 0.0 else ""
	spawn_plan["wave_key"] = wave_key
	spawn_plan["owner_wave_id"] = wave_key
	spawn_plan["actor_owner_id"] = actor_owner_id
	spawn_plan["actor_resolution_seconds"] = actor_resolution_seconds
	projectile_plan["parent_wave_key"] = wave_key
	projectile_plan["owner_wave_id"] = wave_key
	projectile_plan["damage_source"] = "room_projectile:%s" % projectile_id if int(projectile_plan.get("count", 0)) > 0 else "none"
	var movement_plan := _compile_movement(contract, event, movement_id, movement_behavior, event_seed)
	movement_plan["owner_wave_id"] = wave_key
	var visual := _visual_signature(spawn_id, spawn_behavior, projectile_id, projectile_behavior, movement_id, movement_behavior, defender_id, int(event.get("index", 0)), event_seed)
	var event_safe_signature := "event-safe:%d:%d:%d:%d" % [
		int(event.get("safe_lane", 0)),
		roundi(float(safe_position[0]) * 10000.0),
		roundi(float(safe_position[1]) * 10000.0),
		roundi(float(contract.get("safe_clearance_normalized", 0.0)) * 10000.0),
	]
	var telegraph_plan := {
		"coordinate_space": COORDINATE_SPACE,
		"starts_at": float(event.get("telegraph_at", 0.0)),
		"ends_at": float(event.get("active_at", 0.0)),
		"motif": String(spawn_behavior.visual),
		"projectile_motif": String(projectile_behavior.visual),
		"motion_motif": String(movement_behavior.visual),
		"positions": (spawn_plan.get("positions", []) as Array).duplicate(true),
		"safe_position": safe_position.duplicate(),
		"safe_clearance": float(contract.get("safe_clearance_normalized", 0.0)),
		"player_radius_normalized": PLAYER_RADIUS_NORMALIZED,
		"color_role": "danger_telegraph",
		"signature": visual,
		"owner_wave_id": wave_key,
	}
	var operations: Array[Dictionary] = [
		{"op":"telegraph", "at":float(event.get("telegraph_at", 0.0)), "owner_wave_id":wave_key, "plan":telegraph_plan.duplicate(true)},
		{"op":"apply_movement", "at":float(event.get("telegraph_at", 0.0)), "until":float(event.get("clear_at", 0.0)), "owner_wave_id":wave_key, "plan":movement_plan.duplicate(true)},
		{
			"op":"spawn",
			"at":float(event.get("active_at", 0.0)),
			"owner_wave_id":wave_key,
			"actor_owner_id":actor_owner_id,
			"actor_resolution_seconds":actor_resolution_seconds,
			"blocks_next_event":false,
			"blocks_room_exit":actor_resolution_seconds > 0.0,
			"plan":spawn_plan.duplicate(true),
		},
	]
	if int(projectile_plan.get("count", 0)) > 0:
		operations.append({"op":"emit_projectiles", "at":float(event.get("active_at", 0.0)), "owner_wave_id":wave_key, "plan":projectile_plan.duplicate(true)})
	else:
		operations.append({"op":"hold_structural_hazard", "at":float(event.get("active_at", 0.0)), "until":float(event.get("clear_at", 0.0)), "owner_wave_id":wave_key, "collision":spawn_plan.get("collision", {}).duplicate(true), "positions":(spawn_plan.get("positions", []) as Array).duplicate(true)})
	operations.append({"op":"close_emitter", "at":float(event.get("clear_at", 0.0)), "event_index":int(event.get("index", 0)), "owner_wave_id":wave_key})
	operations.append({"op":"clear_wave", "at":float(event.get("clear_at", 0.0)), "mode":"force", "reason":"transient_boundary", "event_index":int(event.get("index", 0)), "owner_wave_id":wave_key})
	var event_plan := {
		"index": int(event.get("index", 0)),
		"event_seed": event_seed,
		"wave_key": wave_key,
		"owner_wave_id": wave_key,
		"telegraph_at": float(event.get("telegraph_at", 0.0)),
		"active_at": float(event.get("active_at", 0.0)),
		"clear_at": float(event.get("clear_at", 0.0)),
		"movement": movement_plan,
		"spawn": spawn_plan,
		"projectile": projectile_plan,
		"telegraph": telegraph_plan,
		"safe": {
			"lane": int(event.get("safe_lane", 0)),
			"position": safe_position,
			"clearance": float(contract.get("safe_clearance_normalized", 0.0)),
			"player_radius_normalized": PLAYER_RADIUS_NORMALIZED,
			"hazard_lanes": (event.get("hazard_lanes", []) as Array).duplicate(),
		},
		"safe_signature": event_safe_signature,
		"visual_signature": visual,
		"operations": operations,
	}
	event_plan["runtime_category"] = runtime_category_for_event(event_plan)
	event_plan["geometry_signature"] = geometry_signature_for_event(event_plan)
	event_plan["lifecycle_signature"] = lifecycle_signature_for_event(event_plan)
	return event_plan


static func _compile_spawn(contract: Dictionary, event: Dictionary, pattern_id: String, behavior: Dictionary, defender_id: String, event_seed: int) -> Dictionary:
	var source := contract.get("spawn", {}) as Dictionary
	var requested := maxi(1, int(event.get("spawn_count", source.get("burst_count", 1))))
	var max_active := mini(maxi(1, int(source.get("max_active", 1))), MAX_ACTIVE_ENEMIES)
	var enemy_count := 0 if defender_id == "none" else mini(requested, mini(MAX_ENEMIES_PER_EVENT, max_active))
	var geometry_count := mini(maxi(requested, (event.get("hazard_lanes", []) as Array).size()), MAX_HAZARDS_PER_EVENT)
	if defender_id != "none":
		geometry_count = maxi(geometry_count, enemy_count)
	var primitive := String(behavior.primitive)
	var positions := _spawn_positions(primitive, String(source.get("origin", "ahead")), event, contract.get("movement", {}) as Dictionary, geometry_count, event_seed)
	var collision := _collision_for_primitive(primitive, float(contract.get("projectile", {}).get("damage", 10.0)))
	_enforce_safe_clearance(
		positions,
		event.get("safe_position", [0.5, 0.5]) as Array,
		float(contract.get("safe_clearance_normalized", 0.0)),
		collision,
		event_seed,
		float(contract.get("safe_clearance_normalized", 0.0)) + PLAYER_RADIUS_NORMALIZED if defender_id != "none" else 0.0
	)
	var archetype_behavior: Dictionary = {}
	if defender_id != "none":
		archetype_behavior = (DEFENDER_ARCHETYPES[defender_id] as Dictionary).duplicate(true)
	return {
		"source_pattern": pattern_id,
		"primitive": primitive,
		"origin": String(source.get("origin", "ahead")),
		"visual_token": String(behavior.visual),
		"requested_count": requested,
		"hazard_count": mini(positions.size(), MAX_HAZARDS_PER_EVENT),
		"enemy_count": enemy_count,
		"max_active_enemies": max_active,
		"positions": positions,
		"coordinate_space": COORDINATE_SPACE,
		"collision": collision,
		"defender_archetype": defender_id,
		"defender_behavior": archetype_behavior,
	}


static func _compile_projectiles(contract: Dictionary, event: Dictionary, pattern_id: String, behavior: Dictionary, spawn_plan: Dictionary, event_seed: int) -> Dictionary:
	var source := contract.get("projectile", {}) as Dictionary
	var enabled := bool(source.get("enabled", false))
	var active_seconds := maxf(0.0, float(event.get("clear_at", 0.0)) - float(event.get("active_at", 0.0)))
	if not enabled:
		return {
			"source_pattern": pattern_id,
			"primitive": String(behavior.primitive),
			"visual_token": String(behavior.visual),
			"travel_model": String(behavior.travel),
			"requested_count": 0,
			"count": 0,
			"max_active": 0,
			"directions_degrees": [],
			"emitters": [],
			"coordinate_space": COORDINATE_SPACE,
			"authored_lifetime_seconds": float(source.get("lifetime_seconds", 0.0)),
			"lifetime_seconds": 0.0,
			"max_delay_seconds": 0.0,
			"threat_time_seconds": 0.0,
		}
	var per_emitter := maxi(1, int(source.get("count", 1)))
	var emitter_count := maxi(1, int(spawn_plan.get("enemy_count", 0)))
	if int(spawn_plan.get("enemy_count", 0)) == 0:
		emitter_count = mini(maxi(1, int(spawn_plan.get("hazard_count", 1))), 4)
	var requested := per_emitter * emitter_count
	var emitted := mini(requested, MAX_PROJECTILES_PER_EVENT)
	var positions := spawn_plan.get("positions", []) as Array
	var emitters: Array = []
	for index in range(mini(emitter_count, positions.size())):
		emitters.append((positions[index] as Dictionary).get("position", [0.5, 0.2]))
	if emitters.is_empty():
		emitters.append([0.5, 0.2])
	var directions := _projectile_directions(String(behavior.primitive), emitted, float(source.get("spread_degrees", 0.0)), event, emitters[0] as Array, event_seed)
	var tracking := clampf(float(source.get("tracking_strength", 0.0)), 0.0, 1.0)
	var lifecycle_probe := {"travel_model":String(behavior.travel), "count":emitted}
	return {
		"source_pattern": pattern_id,
		"primitive": String(behavior.primitive),
		"visual_token": String(behavior.visual),
		"travel_model": String(behavior.travel),
		"requested_count": requested,
		"count": emitted,
		"max_active": mini(MAX_ACTIVE_PROJECTILES, maxi(emitted, per_emitter * mini(int(spawn_plan.get("max_active_enemies", 1)), MAX_ACTIVE_ENEMIES))),
		"per_emitter": per_emitter,
		"emitters": emitters,
		"coordinate_space": COORDINATE_SPACE,
		"directions_degrees": directions,
		"speed_pixels_per_second": float(source.get("speed_pixels_per_second", 0.0)),
		"radius_pixels": float(source.get("radius_pixels", 0.0)),
		"authored_lifetime_seconds": float(source.get("lifetime_seconds", 0.0)),
		"lifetime_seconds": active_seconds,
		"max_delay_seconds": _delayed_emission_seconds(lifecycle_probe, active_seconds),
		"threat_time_seconds": _threat_time_seconds(active_seconds),
		"damage": float(source.get("damage", 0.0)),
		"tracking_strength": tracking,
		"target_mode": "player_snapshot" if tracking > 0.0 else "authored_safe_corridor",
	}


static func _delayed_emission_seconds(projectile: Dictionary, active_seconds: float) -> float:
	if String(projectile.get("travel_model", "")) != "delayed_linear":
		return 0.0
	var delayed_steps := mini(2, maxi(0, int(projectile.get("count", 0)) - 1))
	var authored_delay := DELAYED_EMISSION_STEP_SECONDS * float(delayed_steps)
	return minf(authored_delay, maxf(0.0, active_seconds - EMISSION_BOUNDARY_GUARD_SECONDS))


static func _threat_time_seconds(active_seconds: float) -> float:
	var latest_threat := minf(MAX_THREAT_TIME_SECONDS, maxf(0.0, active_seconds - EMISSION_BOUNDARY_GUARD_SECONDS))
	if latest_threat <= 0.0:
		return 0.0
	var earliest_threat := minf(MIN_THREAT_TIME_SECONDS, latest_threat)
	return clampf(active_seconds * 0.58, earliest_threat, latest_threat)


static func _actor_resolution_seconds(spawn_plan: Dictionary) -> float:
	if int(spawn_plan.get("enemy_count", 0)) <= 0:
		return 0.0
	var behavior := spawn_plan.get("defender_behavior", {}) as Dictionary
	var resolution := ARMORED_ACTOR_RESOLUTION_SECONDS if String(behavior.get("health_class", "medium")) == "armored" else ACTOR_RESOLUTION_SECONDS
	return clampf(resolution, MIN_ACTOR_RESOLUTION_SECONDS, ARMORED_ACTOR_RESOLUTION_SECONDS)


static func _compile_movement(contract: Dictionary, event: Dictionary, model_id: String, behavior: Dictionary, event_seed: int) -> Dictionary:
	var source := contract.get("movement", {}) as Dictionary
	var safe := (event.get("safe_position", [0.5, 0.5]) as Array).duplicate()
	var phase := float(event.get("phase", 0.0))
	var direction := -1 if (event_seed & 1) == 0 else 1
	var plan := {
		"source_model": model_id,
		"primitive": String(behavior.primitive),
		"visual_token": String(behavior.visual),
		"axis": String(source.get("axis", "vertical")),
		"lane_count": int(source.get("lane_count", 0)),
		"max_required_speed_normalized": float(source.get("max_required_speed_normalized", 0.0)),
		"coordinate_space": COORDINATE_SPACE,
	}
	match model_id:
		"lane":
			plan["waypoints"] = [[safe[0], 0.88], safe.duplicate(), [safe[0], 0.12]]
			plan["lane"] = int(event.get("safe_lane", 0))
		"ring":
			plan["center"] = [0.5, 0.51]
			plan["radius_normalized"] = float(source.get("ring_radius", 0.25))
			plan["start_angle_radians"] = phase * TAU
			plan["angular_rate"] = float(source.get("rotation_rate", 0.0)) * float(direction)
		"sweep":
			plan["from"] = [0.08 if direction > 0 else 0.92, safe[1]]
			plan["to"] = [0.92 if direction > 0 else 0.08, safe[1]]
			plan["direction"] = direction
		"anchor":
			plan["anchor_position"] = safe.duplicate()
			plan["force_direction"] = [float(direction), 0.0]
			plan["release_at"] = float(event.get("clear_at", 0.0))
		"pocket":
			plan["pockets"] = [safe.duplicate(), [clampf(1.0 - float(safe[0]), 0.08, 0.92), clampf(float(safe[1]) - 0.14, 0.08, 0.92)]]
			plan["active_pocket"] = int(event.get("index", 0)) % 2
		"replay":
			plan["recorded_lane"] = int(event.get("safe_lane", 0))
			plan["echo_delay_seconds"] = maxf(0.18, float(event.get("active_at", 0.0)) - float(event.get("telegraph_at", 0.0)))
			plan["recording_signature"] = "echo:%d:%d" % [event_seed, int(event.get("index", 0))]
	return plan


static func _spawn_positions(primitive: String, origin: String, event: Dictionary, movement: Dictionary, requested_count: int, event_seed: int) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	var safe := event.get("safe_position", [0.5, 0.5]) as Array
	var safe_lane := int(event.get("safe_lane", 0))
	var lane_count := maxi(2, int(movement.get("lane_count", 3)))
	var hazard_lanes := event.get("hazard_lanes", []) as Array
	var phase := float(event.get("phase", 0.0)) * TAU
	var count := mini(maxi(1, requested_count), MAX_HAZARDS_PER_EVENT)
	match primitive:
		"lane_gate", "pocket_field", "grid_cells":
			for index in range(count):
				var lane := int(hazard_lanes[index % maxi(1, hazard_lanes.size())]) if not hazard_lanes.is_empty() else (safe_lane + 1 + index) % lane_count
				var row := index / lane_count
				positions.append(_position_record(_lane_x(lane, lane_count), clampf(0.28 + float(row) * 0.18, 0.12, 0.84), "blocked_cell", lane))
		"paired_barrier", "pincer_pair":
			for index in range(count):
				var side := -1.0 if index % 2 == 0 else 1.0
				var depth := 0.24 + float(index / 2) * 0.13
				positions.append(_position_record(0.50 + side * (0.36 - float(index / 2) * 0.025), clampf(depth, 0.12, 0.84), "left" if side < 0.0 else "right", index % lane_count))
		"rotating_arc", "radial_cluster", "decoy_cluster":
			var radius := float(movement.get("ring_radius", 0.25))
			for index in range(count):
				var angle := phase + TAU * float(index) / float(count)
				positions.append(_position_record(0.5 + cos(angle) * radius, 0.48 + sin(angle) * radius, "orbit", index))
		"sweep_field", "sweep_wall", "cone_sweep":
			var horizontal := String(movement.get("axis", "vertical")) == "horizontal"
			for index in range(count):
				var progress := (float(index) + 0.5) / float(count)
				positions.append(_position_record(progress if horizontal else (0.10 if (event_seed & 1) == 0 else 0.90), (0.10 if horizontal else progress), "sweep", index))
		"drop_field":
			for index in range(count):
				var lane := int(hazard_lanes[index % maxi(1, hazard_lanes.size())]) if not hazard_lanes.is_empty() else (safe_lane + 1 + index) % lane_count
				positions.append(_position_record(_lane_x(lane, lane_count), 0.08 + 0.025 * float(index % 3), "drop", lane))
		"cover_line", "tracked_pack":
			for index in range(count):
				var lane := (safe_lane + 1 + index) % lane_count
				positions.append(_position_record(_lane_x(lane, lane_count), 0.25 + 0.12 * float(index % 3), "defender", lane))
		"node_chain":
			for index in range(count):
				var progress := (float(index) + 1.0) / float(count + 1)
				var x := 0.18 + progress * 0.64
				if absf(x - float(safe[0])) < 0.12:
					x = clampf(1.0 - x, 0.08, 0.92)
				positions.append(_position_record(x, 0.25 + 0.34 * float(index % 2), "link_node", index))
		"hatch_wave":
			for index in range(count):
				var lane := (safe_lane + 1 + index) % lane_count
				positions.append(_position_record(_lane_x(lane, lane_count), 0.18 + 0.08 * float(index % 2), "egg", lane))
		"replay_trace":
			for index in range(count):
				var offset := (float(index) - float(count - 1) * 0.5) * 0.08
				positions.append(_position_record(clampf(1.0 - float(safe[0]) + offset, 0.08, 0.92), clampf(float(safe[1]) - 0.18, 0.08, 0.92), "echo", index))
		"gravity_field":
			for index in range(count):
				var angle := phase + TAU * float(index) / float(count)
				positions.append(_position_record(0.5 + cos(angle) * 0.26, 0.5 + sin(angle) * 0.26, "well", index))
		_:
			for index in range(count):
				positions.append(_position_record(0.5, 0.2 + 0.08 * float(index), origin, index))
	return positions


static func _projectile_directions(primitive: String, count: int, spread_degrees: float, event: Dictionary, emitter: Array, event_seed: int) -> Array[float]:
	var directions: Array[float] = []
	if count <= 0:
		return directions
	var safe := event.get("safe_position", [0.5, 0.5]) as Array
	var base := rad_to_deg(atan2(float(safe[1]) - float(emitter[1]), (1.0 - float(safe[0])) - float(emitter[0])))
	var phase := float(event.get("phase", 0.0)) * 360.0 + float(event_seed % 17)
	match primitive:
		"gravity_drop":
			for index in range(count):
				directions.append(90.0 + (float(index % 3) - 1.0) * 3.0)
		"radial_burst", "decoy_radial", "petal_radial", "ring_wave":
			for index in range(count):
				directions.append(fposmod(phase + 360.0 * float(index) / float(count), 360.0))
		"converging_fan", "split_fan", "aimed_burst", "prism_line", "quadrant_fan":
			var spread := spread_degrees if spread_degrees > 0.0 else (90.0 if primitive == "quadrant_fan" else 22.0)
			for index in range(count):
				var offset := 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, float(index) / float(count - 1))
				directions.append(base + offset)
		"wave_front":
			for index in range(count):
				directions.append(0.0 if (index + event_seed) % 2 == 0 else 180.0)
		"linked_arc":
			for index in range(count):
				directions.append(fposmod(phase + 45.0 * float(index), 360.0))
		"dash_lunge", "tracked_shot", "tracked_marker", "replay_burst", "replay_trace":
			for index in range(count):
				directions.append(base + (float(index % 3) - 1.0) * 8.0)
		_:
			for index in range(count):
				directions.append(base)
	return directions


static func _visual_signature(spawn_id: String, spawn_behavior: Dictionary, projectile_id: String, projectile_behavior: Dictionary, movement_id: String, movement_behavior: Dictionary, defender_id: String, event_index: int, seed: int) -> String:
	return "visual-v1:%s/%s/%s>%s/%s/%s>%s/%s>%s@%d:%d" % [
		spawn_id,
		String(spawn_behavior.primitive),
		String(spawn_behavior.visual),
		projectile_id,
		String(projectile_behavior.primitive),
		String(projectile_behavior.visual),
		movement_id,
		String(movement_behavior.primitive),
		defender_id,
		event_index,
		abs(seed) % 997,
	]


static func _plan_signature(plan: Dictionary) -> String:
	return plan_signature_for_plan(plan)


static func plan_signature_for_plan(plan: Dictionary) -> String:
	var payload := plan.duplicate(true)
	payload.erase("plan_signature")
	return "room-plan-v%d:%s" % [PLAN_VERSION, _canonical_json(payload).sha256_text().left(32)]


static func _canonical_json(value: Variant) -> String:
	# Sorted keys make dictionary insertion order irrelevant; full precision keeps
	# small but executable numeric changes from collapsing to one replay identity.
	return JSON.stringify(value, "", true, true)


static func _wave_key(room_id: String, event_index: int, event_seed: int) -> String:
	return "%s:%d:%d" % [room_id, event_index, event_seed]


static func _is_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)


static func _number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	if not _is_finite_number(value):
		return false
	var number := float(value)
	return number >= minimum and number <= maximum


static func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum and int(value) <= maximum


static func _finite_normalized_point(point: Array) -> bool:
	return point.size() == 2 \
		and _number_in_range(point[0], RoomSpaceScript.MIN_COORDINATE, RoomSpaceScript.MAX_COORDINATE) \
		and _number_in_range(point[1], RoomSpaceScript.MIN_COORDINATE, RoomSpaceScript.MAX_COORDINATE)


static func _validate_timing_payload(timing: Dictionary, duration: float, prefix: String, errors: PackedStringArray) -> void:
	if not _number_in_range(timing.get("cadence", null), MIN_ACTIVE_WINDOW_SECONDS, MAX_CADENCE_SECONDS):
		errors.append("%s cadence must be finite and bounded" % prefix)
	if not _number_in_range(timing.get("telegraph_seconds", null), 0.001, MAX_TELEGRAPH_SECONDS):
		errors.append("%s telegraph duration must be finite and bounded" % prefix)
	if not _number_in_range(timing.get("active_seconds", null), MIN_ACTIVE_WINDOW_SECONDS, MAX_ACTIVE_WINDOW_SECONDS):
		errors.append("%s active duration must be finite and bounded" % prefix)
	if not _number_in_range(timing.get("initial_delay", null), 0.0, minf(MAX_INITIAL_DELAY_SECONDS, maxf(0.0, duration))):
		errors.append("%s initial delay must be finite and bounded by room duration" % prefix)
	if not _number_in_range(timing.get("exit_transition_seconds", null), 0.001, minf(MAX_EXIT_TRANSITION_SECONDS, maxf(0.001, duration))):
		errors.append("%s exit transition must be finite and bounded by room duration" % prefix)
	if _is_finite_number(timing.get("cadence", null)) and _is_finite_number(timing.get("telegraph_seconds", null)) and _is_finite_number(timing.get("active_seconds", null)):
		var minimum_cadence := float(timing.telegraph_seconds) + float(timing.active_seconds) + MIN_EVENT_GAP_SECONDS
		if float(timing.cadence) + 0.000001 < minimum_cadence:
			errors.append("%s cadence overlaps its telegraph, active window, or reaction gap" % prefix)


static func _validate_safe_path_payload(safe_path: Array, duration: float, prefix: String, errors: PackedStringArray) -> void:
	if safe_path.is_empty() or safe_path.size() > MAX_SAFE_PATH_WAYPOINTS:
		errors.append("%s safe path is empty or unbounded" % prefix)
		return
	var prior_time := -1.0
	for waypoint_index in range(safe_path.size()):
		if typeof(safe_path[waypoint_index]) != TYPE_DICTIONARY:
			errors.append("%s safe-path waypoint %d is malformed" % [prefix, waypoint_index])
			return
		var waypoint := safe_path[waypoint_index] as Dictionary
		var time_value: Variant = waypoint.get("time", null)
		var clearance_value: Variant = waypoint.get("clearance", null)
		var position_value: Variant = waypoint.get("position", null)
		if not _number_in_range(time_value, 0.0, duration) or float(time_value) <= prior_time:
			errors.append("%s safe-path times must be finite, bounded, and strictly increasing" % prefix)
			return
		if typeof(position_value) != TYPE_ARRAY or not _finite_normalized_point(position_value as Array):
			errors.append("%s safe-path position must be finite and normalized" % prefix)
			return
		if not _number_in_range(clearance_value, 0.001, MAX_SAFE_CLEARANCE_NORMALIZED):
			errors.append("%s safe-path clearance must be finite and bounded" % prefix)
			return
		prior_time = float(time_value)


static func _validate_collision_payload(collision: Dictionary, errors: PackedStringArray) -> void:
	if not bool(collision.get("enabled", false)) or String(collision.get("coordinate_space", "")) != COORDINATE_SPACE:
		errors.append("Collision payload must be enabled in room-normalized space")
		return
	var shape := String(collision.get("shape", ""))
	if shape not in ["circle", "box", "cell", "arc", "segment_chain", "force_field"]:
		errors.append("Collision payload uses an unsupported shape")
		return
	if not _number_in_range(collision.get("damage", null), 0.001, MAX_PROJECTILE_DAMAGE):
		errors.append("Collision damage must be finite and bounded")
	if not _number_in_range(collision.get("radius_normalized", null), 0.0, MAX_COLLISION_RADIUS_NORMALIZED):
		errors.append("Collision radius must be finite and bounded")
	if shape in ["arc", "segment_chain"] and not _number_in_range(collision.get("thickness_normalized", null), 0.001, MAX_COLLISION_THICKNESS_NORMALIZED):
		errors.append("Collision thickness must be finite and bounded")
	if shape in ["box", "cell"]:
		var half_extents_value: Variant = collision.get("half_extents_normalized", null)
		if typeof(half_extents_value) != TYPE_ARRAY or (half_extents_value as Array).size() != 2 or not _number_in_range((half_extents_value as Array)[0], 0.001, MAX_COLLISION_RADIUS_NORMALIZED) or not _number_in_range((half_extents_value as Array)[1], 0.001, MAX_COLLISION_RADIUS_NORMALIZED):
			errors.append("Collision half-extents must be finite and bounded")


static func _validate_movement_plan_payload(movement: Dictionary, duration: float, errors: PackedStringArray) -> void:
	var model := String(movement.get("source_model", ""))
	if model not in MOVEMENT_BEHAVIORS or String(movement.get("coordinate_space", "")) != COORDINATE_SPACE or String(movement.get("owner_wave_id", "")).is_empty():
		errors.append("Movement plan lost its model, coordinate space, or ownership")
		return
	if not _number_in_range(movement.get("max_required_speed_normalized", null), 0.001, MAX_MOVEMENT_SPEED_NORMALIZED):
		errors.append("Movement plan speed must be finite and bounded")
	if not _integer_in_range(movement.get("lane_count", null), 2, MAX_HAZARDS_PER_EVENT):
		errors.append("Movement plan lane count must be a bounded integer")
	if String(movement.get("axis", "")) not in ["horizontal", "vertical"]:
		errors.append("Movement plan axis is unsupported")
	match model:
		"lane":
			var waypoints_value: Variant = movement.get("waypoints", null)
			if typeof(waypoints_value) != TYPE_ARRAY or (waypoints_value as Array).is_empty():
				errors.append("Lane movement requires bounded waypoints")
			else:
				for waypoint in waypoints_value as Array:
					if typeof(waypoint) != TYPE_ARRAY or not _finite_normalized_point(waypoint as Array):
						errors.append("Lane movement waypoint must be finite and normalized")
						break
			var lane_count := int(movement.get("lane_count", 0)) if typeof(movement.get("lane_count", null)) == TYPE_INT else 0
			if not _integer_in_range(movement.get("lane", null), 0, lane_count - 1):
				errors.append("Lane movement lane must be an integer within movement lane count")
		"ring":
			var center_value: Variant = movement.get("center", null)
			if typeof(center_value) != TYPE_ARRAY or not _finite_normalized_point(center_value as Array) or not _number_in_range(movement.get("radius_normalized", null), 0.0, MAX_RING_RADIUS_NORMALIZED) or not _number_in_range(movement.get("start_angle_radians", null), -TAU, TAU) or not _number_in_range(movement.get("angular_rate", null), -MAX_ROTATION_RATE, MAX_ROTATION_RATE):
				errors.append("Ring movement geometry/rate must be finite and bounded")
		"sweep":
			var from_value: Variant = movement.get("from", null)
			var to_value: Variant = movement.get("to", null)
			if typeof(from_value) != TYPE_ARRAY or typeof(to_value) != TYPE_ARRAY or not _finite_normalized_point(from_value as Array) or not _finite_normalized_point(to_value as Array) or not _integer_in_range(movement.get("direction", null), -1, 1) or int(movement.get("direction", 0)) == 0:
				errors.append("Sweep movement geometry/direction is invalid")
		"anchor":
			var anchor_value: Variant = movement.get("anchor_position", null)
			var force_value: Variant = movement.get("force_direction", null)
			if typeof(anchor_value) != TYPE_ARRAY or not _finite_normalized_point(anchor_value as Array) or typeof(force_value) != TYPE_ARRAY or (force_value as Array).size() != 2 or not _number_in_range((force_value as Array)[0], -1.0, 1.0) or not _number_in_range((force_value as Array)[1], -1.0, 1.0) or not _number_in_range(movement.get("release_at", null), 0.0, duration):
				errors.append("Anchor movement force/release must be finite and bounded")
		"pocket":
			var pockets_value: Variant = movement.get("pockets", null)
			if typeof(pockets_value) != TYPE_ARRAY or (pockets_value as Array).is_empty():
				errors.append("Pocket movement requires bounded positions")
			else:
				for pocket in pockets_value as Array:
					if typeof(pocket) != TYPE_ARRAY or not _finite_normalized_point(pocket as Array):
						errors.append("Pocket movement position must be finite and normalized")
						break
		"replay":
			if not _number_in_range(movement.get("echo_delay_seconds", null), 0.001, MAX_TELEGRAPH_SECONDS):
				errors.append("Replay movement delay must be finite and bounded")


static func _validate_projectile_plan_payload(projectile: Dictionary, active_seconds: float, errors: PackedStringArray) -> void:
	if String(projectile.get("coordinate_space", "")) != COORDINATE_SPACE or String(projectile.get("owner_wave_id", "")).is_empty():
		errors.append("Projectile plan lost its coordinate space or ownership")
		return
	if String(projectile.get("travel_model", "")) not in ["none", "linear", "soft_homing", "expanding", "node_link", "lunge", "delayed_linear", "recorded_path"]:
		errors.append("Projectile travel model is unsupported")
	if not _number_in_range(projectile.get("authored_lifetime_seconds", null), 0.001, MAX_AUTHORED_PROJECTILE_LIFETIME_SECONDS):
		errors.append("Authored projectile lifetime metadata must be finite and bounded")
	if not _integer_in_range(projectile.get("count", null), 0, MAX_PROJECTILES_PER_EVENT):
		errors.append("Projectile plan count must be a bounded integer")
		return
	var count := int(projectile.get("count", 0))
	if count <= 0:
		if not _integer_in_range(projectile.get("max_active", null), 0, 0):
			errors.append("Structural-only projectile plan must keep its active cap at zero")
		return
	if not _integer_in_range(projectile.get("max_active", null), count, MAX_ACTIVE_PROJECTILES):
		errors.append("Projectile plan active cap is below its executable count")
		return
	if not _number_in_range(projectile.get("speed_pixels_per_second", null), MIN_PROJECTILE_SPEED_PIXELS_PER_SECOND, MAX_PROJECTILE_SPEED_PIXELS_PER_SECOND):
		errors.append("Projectile plan speed must be finite and bounded")
	if not _number_in_range(projectile.get("radius_pixels", null), MIN_PROJECTILE_RADIUS_PIXELS, MAX_PROJECTILE_RADIUS_PIXELS):
		errors.append("Projectile plan radius must be finite and bounded")
	if not _number_in_range(projectile.get("lifetime_seconds", null), MIN_ACTIVE_WINDOW_SECONDS, MAX_ACTIVE_WINDOW_SECONDS):
		errors.append("Projectile plan lifetime must be finite and bounded")
	if not _number_in_range(projectile.get("max_delay_seconds", null), 0.0, MAX_DELAYED_EMISSION_SECONDS):
		errors.append("Projectile plan delay must be finite and bounded")
	if not _number_in_range(projectile.get("threat_time_seconds", null), 0.0, minf(MAX_THREAT_TIME_SECONDS, maxf(0.0, active_seconds - EMISSION_BOUNDARY_GUARD_SECONDS))):
		errors.append("Projectile plan threat time must be finite and bounded")
	if not _number_in_range(projectile.get("damage", null), MIN_PROJECTILE_DAMAGE, MAX_PROJECTILE_DAMAGE):
		errors.append("Projectile plan damage must be finite and bounded")
	if not _number_in_range(projectile.get("tracking_strength", null), 0.0, 1.0):
		errors.append("Projectile tracking strength must be finite and bounded")
	var emitters_value: Variant = projectile.get("emitters", null)
	if typeof(emitters_value) != TYPE_ARRAY or (emitters_value as Array).is_empty() or (emitters_value as Array).size() > MAX_ENEMIES_PER_EVENT:
		errors.append("Projectile emitters are empty or unbounded")
	else:
		for emitter in emitters_value as Array:
			if typeof(emitter) != TYPE_ARRAY or not _finite_normalized_point(emitter as Array):
				errors.append("Projectile emitter must be finite and normalized")
				break
	var directions_value: Variant = projectile.get("directions_degrees", null)
	if typeof(directions_value) != TYPE_ARRAY or (directions_value as Array).size() != count:
		errors.append("Projectile directions do not match their bounded count")
	else:
		for direction in directions_value as Array:
			if not _number_in_range(direction, -MAX_DIRECTION_DEGREES, MAX_DIRECTION_DEGREES):
				errors.append("Projectile direction must be finite and bounded")
				break


static func _position_record(x: float, y: float, role: String, lane: int) -> Dictionary:
	return {"position":RoomSpaceScript.clamp_normalized([x, y]), "role":role, "lane":lane}


static func structural_geometry_clearance(positions: Array, collision: Dictionary, safe_position: Array) -> float:
	if not bool(collision.get("enabled", false)) or positions.is_empty() or safe_position.size() != 2:
		return INF
	var shape := String(collision.get("shape", "circle"))
	var minimum := INF
	if shape == "segment_chain":
		var thickness := maxf(0.0, float(collision.get("thickness_normalized", 0.0)))
		if positions.size() == 1:
			var only_position := _record_position(positions[0])
			return _point_distance(safe_position, only_position) - maxf(thickness, float(collision.get("radius_normalized", 0.0)))
		for index in range(positions.size() - 1):
			var start := _record_position(positions[index])
			var finish := _record_position(positions[index + 1])
			minimum = minf(minimum, _point_segment_distance(safe_position, start, finish) - thickness)
		return minimum
	for raw_position in positions:
		var center := _record_position(raw_position)
		var clearance := 0.0
		match shape:
			"box", "cell":
				var half_extents := collision.get("half_extents_normalized", [0.0, 0.0]) as Array
				clearance = _point_box_distance(safe_position, center, half_extents)
			"arc":
				var radius := maxf(0.0, float(collision.get("radius_normalized", 0.0)))
				var thickness := maxf(0.0, float(collision.get("thickness_normalized", 0.0)))
				clearance = absf(_point_distance(safe_position, center) - radius) - thickness
			_:
				clearance = _point_distance(safe_position, center) - maxf(0.0, float(collision.get("radius_normalized", 0.0)))
		minimum = minf(minimum, clearance)
	return minimum


static func structural_geometry_clears_safe_disk(
	positions: Array,
	collision: Dictionary,
	safe_position: Array,
	safe_clearance: float,
	player_radius: float = PLAYER_RADIUS_NORMALIZED
) -> bool:
	var required := maxf(0.0, safe_clearance) + maxf(PLAYER_RADIUS_NORMALIZED, player_radius) + SAFE_GEOMETRY_EPSILON
	return structural_geometry_clearance(positions, collision, safe_position) + 0.000001 >= required


static func _enforce_safe_clearance(positions: Array[Dictionary], safe_position: Array, clearance: float, collision: Dictionary, seed: int, minimum_center_clearance: float = 0.0) -> void:
	if positions.is_empty() or safe_position.size() != 2:
		return
	if structural_geometry_clears_safe_disk(positions, collision, safe_position, clearance) and _centers_clear_safe_disk(positions, safe_position, minimum_center_clearance):
		return
	if String(collision.get("shape", "circle")) == "segment_chain":
		_relocate_segment_chain(positions, safe_position, clearance, collision, seed)
		return
	for index in range(positions.size()):
		var single: Array = [positions[index]]
		if structural_geometry_clears_safe_disk(single, collision, safe_position, clearance) and _centers_clear_safe_disk(single, safe_position, minimum_center_clearance):
			continue
		var record := positions[index]
		var original := record.get("position", [0.5, 0.5]) as Array
		record["position"] = _nearest_clear_position(original, safe_position, clearance, collision, seed + index * 977, minimum_center_clearance)
		positions[index] = record


static func _nearest_clear_position(original: Array, safe_position: Array, clearance: float, collision: Dictionary, seed: int, minimum_center_clearance: float) -> Array:
	var shape := String(collision.get("shape", "circle"))
	var safe_disk := maxf(0.0, clearance) + PLAYER_RADIUS_NORMALIZED + SAFE_GEOMETRY_EPSILON
	var candidate_distances: Array[float] = []
	if shape == "arc":
		var radius := maxf(0.0, float(collision.get("radius_normalized", 0.0)))
		var thickness := maxf(0.0, float(collision.get("thickness_normalized", 0.0)))
		var inner := radius - thickness - safe_disk
		if inner >= 0.0:
			candidate_distances.append(maxf(0.0, inner - SAFE_GEOMETRY_EPSILON))
		candidate_distances.append(radius + thickness + safe_disk + SAFE_GEOMETRY_EPSILON)
	else:
		candidate_distances.append(safe_disk + _collision_bounding_radius(collision) + SAFE_GEOMETRY_EPSILON)
	var original_vector := Vector2(float(original[0]) - float(safe_position[0]), float(original[1]) - float(safe_position[1]))
	var base_angle := original_vector.angle() if original_vector.length_squared() > 0.000001 else float(abs(seed) % 360) * PI / 180.0
	var best := RoomSpaceScript.clamp_normalized(original)
	var best_distance := INF
	for distance in candidate_distances:
		for direction_index in range(18):
			var angle := base_angle if direction_index == 0 else base_angle + PI + TAU * float(direction_index - 1) / 17.0
			var direction := Vector2.from_angle(angle)
			var raw_candidate := [
				float(safe_position[0]) + direction.x * distance,
				float(safe_position[1]) + direction.y * distance,
			]
			var candidate := RoomSpaceScript.clamp_normalized(raw_candidate)
			var candidate_record := {"position":candidate}
			if not structural_geometry_clears_safe_disk([candidate_record], collision, safe_position, clearance) or _point_distance(candidate, safe_position) + 0.000001 < minimum_center_clearance:
				continue
			var movement := _point_distance(original, candidate)
			if movement + 0.000001 < best_distance:
				best = candidate
				best_distance = movement
	if best_distance < INF:
		return best
	# Every launch shape fits on at least one side of the normalized arena. Keep
	# this deterministic fallback so malformed-but-bounded inputs fail closed in
	# validation instead of producing an out-of-bounds point.
	for corner in [[0.04, 0.04], [0.96, 0.04], [0.96, 0.96], [0.04, 0.96]]:
		if structural_geometry_clears_safe_disk([{"position":corner}], collision, safe_position, clearance) and _point_distance(corner, safe_position) + 0.000001 >= minimum_center_clearance:
			return corner.duplicate()
	return best


static func _centers_clear_safe_disk(positions: Array, safe_position: Array, minimum_clearance: float) -> bool:
	if minimum_clearance <= 0.0:
		return true
	for raw_position in positions:
		if _point_distance(_record_position(raw_position), safe_position) + 0.000001 < minimum_clearance:
			return false
	return true


static func _relocate_segment_chain(positions: Array[Dictionary], safe_position: Array, clearance: float, collision: Dictionary, seed: int) -> void:
	var required_line_distance := maxf(0.0, clearance) + PLAYER_RADIUS_NORMALIZED + maxf(0.0, float(collision.get("thickness_normalized", 0.0))) + SAFE_GEOMETRY_EPSILON * 2.0
	var original := positions.duplicate(true)
	var candidates: Array[Array] = []
	var right_x := float(safe_position[0]) + required_line_distance
	var left_x := float(safe_position[0]) - required_line_distance
	var lower_y := float(safe_position[1]) + required_line_distance
	var upper_y := float(safe_position[1]) - required_line_distance
	if right_x <= 0.96:
		candidates.append(_chain_on_axis(original, true, right_x))
	if left_x >= 0.04:
		candidates.append(_chain_on_axis(original, true, left_x))
	if lower_y <= 0.96:
		candidates.append(_chain_on_axis(original, false, lower_y))
	if upper_y >= 0.04:
		candidates.append(_chain_on_axis(original, false, upper_y))
	var best: Array = []
	var best_cost := INF
	for candidate_index in range(candidates.size()):
		var candidate := candidates[(candidate_index + abs(seed)) % candidates.size()]
		if not structural_geometry_clears_safe_disk(candidate, collision, safe_position, clearance):
			continue
		var cost := 0.0
		for index in range(candidate.size()):
			cost += pow(_point_distance(_record_position(original[index]), _record_position(candidate[index])), 2.0)
		if cost + 0.000001 < best_cost:
			best = candidate
			best_cost = cost
	if best.is_empty():
		return
	for index in range(positions.size()):
		positions[index] = (best[index] as Dictionary).duplicate(true)


static func _chain_on_axis(source: Array[Dictionary], vertical: bool, coordinate: float) -> Array:
	var result: Array[Dictionary] = source.duplicate(true)
	for index in range(result.size()):
		var record := result[index]
		var point := record.get("position", [0.5, 0.5]) as Array
		record["position"] = [coordinate, clampf(float(point[1]), 0.04, 0.96)] if vertical else [clampf(float(point[0]), 0.04, 0.96), coordinate]
		result[index] = record
	return result


static func _collision_bounding_radius(collision: Dictionary) -> float:
	var shape := String(collision.get("shape", "circle"))
	if shape in ["box", "cell"]:
		var half_extents := collision.get("half_extents_normalized", [0.0, 0.0]) as Array
		if half_extents.size() != 2:
			return 0.0
		return Vector2(float(half_extents[0]), float(half_extents[1])).length()
	return maxf(0.0, float(collision.get("radius_normalized", 0.0)))


static func _record_position(raw_record: Variant) -> Array:
	if typeof(raw_record) == TYPE_DICTIONARY:
		return ((raw_record as Dictionary).get("position", [0.5, 0.5]) as Array)
	if typeof(raw_record) == TYPE_ARRAY:
		return raw_record as Array
	return [0.5, 0.5]


static func _point_distance(first: Array, second: Array) -> float:
	if first.size() != 2 or second.size() != 2:
		return 0.0
	return Vector2(float(first[0]) - float(second[0]), float(first[1]) - float(second[1])).length()


static func _point_box_distance(point: Array, center: Array, half_extents: Array) -> float:
	if point.size() != 2 or center.size() != 2 or half_extents.size() != 2:
		return 0.0
	var dx := maxf(absf(float(point[0]) - float(center[0])) - maxf(0.0, float(half_extents[0])), 0.0)
	var dy := maxf(absf(float(point[1]) - float(center[1])) - maxf(0.0, float(half_extents[1])), 0.0)
	return sqrt(dx * dx + dy * dy)


static func _point_segment_distance(point: Array, start: Array, finish: Array) -> float:
	if point.size() != 2 or start.size() != 2 or finish.size() != 2:
		return 0.0
	var p := Vector2(float(point[0]), float(point[1]))
	var a := Vector2(float(start[0]), float(start[1]))
	var b := Vector2(float(finish[0]), float(finish[1]))
	var segment := b - a
	if segment.length_squared() <= 0.0000001:
		return p.distance_to(a)
	var ratio := clampf((p - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return p.distance_to(a + segment * ratio)


static func _collision_for_primitive(primitive: String, damage: float) -> Dictionary:
	var collision := {"enabled":true, "shape":"circle", "radius_normalized":0.035, "damage":maxf(damage, 0.0), "coordinate_space":COORDINATE_SPACE}
	match primitive:
		"lane_gate", "paired_barrier", "sweep_wall", "cover_line":
			collision["shape"] = "box"
			collision["half_extents_normalized"] = [0.055, 0.12]
		"rotating_arc", "cone_sweep":
			collision["shape"] = "arc"
			collision["radius_normalized"] = 0.24
			collision["thickness_normalized"] = 0.035
		"sweep_field", "gravity_field":
			collision["shape"] = "force_field"
			collision["radius_normalized"] = 0.11
		"node_chain", "replay_trace":
			collision["shape"] = "segment_chain"
			collision["thickness_normalized"] = 0.025
		"grid_cells", "pocket_field":
			collision["shape"] = "cell"
			collision["half_extents_normalized"] = [0.07, 0.07]
	return collision


static func _inside_normalized(position: Array) -> bool:
	return RoomSpaceScript.inside_normalized(position)


static func _append_point_signature(parts: PackedStringArray, point: Array) -> void:
	if point.size() != 2:
		parts.append("invalid-point")
		return
	parts.append("p%d,%d" % [roundi(float(point[0]) * 10000.0), roundi(float(point[1]) * 10000.0)])


static func _lane_x(lane: int, lane_count: int) -> float:
	return 0.125 + (float(lane) + 0.5) * (0.75 / float(maxi(1, lane_count)))


static func _sorted_keys(values: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for key in values:
		result.append(String(key))
	result.sort()
	return result


static func _rejected_plan(contract: Dictionary, errors: PackedStringArray) -> Dictionary:
	return {
		"valid": false,
		"version": PLAN_VERSION,
		"room_id": String(contract.get("room_id", "")),
		"errors": errors.duplicate(),
	}
