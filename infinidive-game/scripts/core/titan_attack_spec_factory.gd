class_name TitanAttackSpecFactory
extends RefCounted

## Pure compiler for the twelve intact exterior Titan abilities.
##
## The caller supplies every input which may change a pattern. The factory has
## no Node ownership, clock, or shared RNG state, so identical contexts produce
## identical attack plans. Plans contain ProjectilePool-compatible spawn specs
## plus bounded effect directives for mechanics which are not projectiles.

const SPEC_VERSION := 1
const STATUS_DISABLED := "disabled"
const DEFAULT_ARENA := Rect2(22.0, 228.0, 496.0, 692.0)
const DEFAULT_COMBAT_BOUNDS := Rect2(24.0, 395.0, 492.0, 450.0)
const MAX_PROJECTILES_PER_ATTACK := 24
const MAX_EFFECT_DIRECTIVES := 4
const MIN_TELEGRAPH_SECONDS := 0.74
const MAX_TELEGRAPH_SECONDS := 1.80
const MIN_SAFE_CLEARANCE_PX := 72.0
const MAX_SAFE_CLEARANCE_PX := 180.0
const MIN_SPEED_MULTIPLIER := 0.5
const MAX_SPEED_MULTIPLIER := 2.0
const GUIDANCE_EDGE_MARGIN_PX := 24.0
const GUIDANCE_SAFE_RADIUS_PX := 34.0
const GUIDANCE_CORRIDOR_HALF_WIDTH_PX := 12.0
const GUIDANCE_MAX_PLAYER_SPEED_PX := 620.0
const GUIDANCE_MAX_HAZARD_HORIZON_SECONDS := 4.0
const VALID_WEAPON_ARCHETYPES := ["pulse", "scatter", "rail", "arc", "orbitals"]

const ABILITY_IDS := [
	"homing_eye",
	"gravity_ring",
	"bone_missiles",
	"prism_lances",
	"laser_wings",
	"halo_barrier",
	"suction_waves",
	"chain_lightning",
	"parasite_swarm",
	"weapon_copy",
	"echo_dash",
	"false_weakpoints",
]

# `mechanic` is deliberately one-to-one with ability id. Validation rejects an
# alias even if its numbers or art tokens differ.
const ABILITY_BLUEPRINTS := {
	"homing_eye": {
		"mechanic": "fate_lock_pursuit",
		"projectile_budget": 3,
		"telegraph_seconds": 1.04,
		"base_speed": 238.0,
		"damage": 10.0,
		"visual_token": "fate_eye_sickle_star",
		"cause_token": "ability:homing_eye",
		"safe_kind": "lateral_break",
	},
	"gravity_ring": {
		"mechanic": "harvest_gravity_ring",
		"projectile_budget": 22,
		"telegraph_seconds": 1.12,
		"base_speed": 176.0,
		"damage": 11.0,
		"visual_token": "gaia_gravity_seed",
		"cause_token": "ability:gravity_ring",
		"safe_kind": "angular_gap",
	},
	"bone_missiles": {
		"mechanic": "adamant_staggered_salvo",
		"projectile_budget": 7,
		"telegraph_seconds": 0.96,
		"base_speed": 325.0,
		"damage": 11.0,
		"visual_token": "adamant_sickle_shard",
		"cause_token": "ability:bone_missiles",
		"safe_kind": "salvo_flank",
	},
	"prism_lances": {
		"mechanic": "dawn_prism_lane_sequence",
		"projectile_budget": 3,
		"telegraph_seconds": 1.18,
		"base_speed": 430.0,
		"damage": 12.0,
		"visual_token": "dawn_prism_lance",
		"cause_token": "ability:prism_lances",
		"safe_kind": "prism_lane_gap",
	},
	"laser_wings": {
		"mechanic": "solar_mantle_lane_burn",
		"projectile_budget": 13,
		"telegraph_seconds": 1.10,
		"base_speed": 305.0,
		"damage": 13.0,
		"visual_token": "solar_mantle_ray",
		"cause_token": "ability:laser_wings",
		"safe_kind": "vertical_corridor",
	},
	"halo_barrier": {
		"mechanic": "sun_crown_barrier_arc",
		"projectile_budget": 16,
		"telegraph_seconds": 1.16,
		"base_speed": 214.0,
		"damage": 9.0,
		"visual_token": "sun_crown_orb",
		"cause_token": "ability:halo_barrier",
		"safe_kind": "rotating_arc_gap",
	},
	"suction_waves": {
		"mechanic": "worldstream_bounded_pull",
		"projectile_budget": 18,
		"telegraph_seconds": 1.22,
		"base_speed": 150.0,
		"damage": 9.0,
		"visual_token": "worldstream_tide_orb",
		"cause_token": "ability:suction_waves",
		"safe_kind": "calm_channel",
	},
	"chain_lightning": {
		"mechanic": "storm_node_link",
		"projectile_budget": 4,
		"telegraph_seconds": 1.08,
		"base_speed": 286.0,
		"damage": 10.0,
		"visual_token": "storm_link_arc",
		"cause_token": "ability:chain_lightning",
		"safe_kind": "unlinked_lane",
	},
	"parasite_swarm": {
		"mechanic": "river_sprite_lunge_swarm",
		"projectile_budget": 5,
		"telegraph_seconds": 1.02,
		"base_speed": 218.0,
		"damage": 10.0,
		"visual_token": "river_sprite_actor",
		"cause_token": "ability:parasite_swarm",
		"safe_kind": "swarm_split",
	},
	"weapon_copy": {
		"mechanic": "memory_weapon_translation",
		"projectile_budget": 7,
		"telegraph_seconds": 1.26,
		"base_speed": 310.0,
		"damage": 10.0,
		"visual_token": "memory_copy_shot",
		"cause_token": "ability:weapon_copy",
		"safe_kind": "translated_weapon_counter",
	},
	"echo_dash": {
		"mechanic": "echo_recorded_dash_path",
		"projectile_budget": 1,
		"telegraph_seconds": 1.28,
		"base_speed": 250.0,
		"damage": 13.0,
		"visual_token": "echo_dash_trail",
		"cause_token": "ability:echo_dash",
		"safe_kind": "recorded_path_flank",
	},
	"false_weakpoints": {
		"mechanic": "muse_veil_decoy_wounds",
		"projectile_budget": 6,
		"telegraph_seconds": 1.34,
		"base_speed": 236.0,
		"damage": 9.0,
		"visual_token": "muse_decoy_shard",
		"cause_token": "ability:false_weakpoints",
		"safe_kind": "true_wound_lane",
	},
}


static func ability_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id in ABILITY_IDS:
		result.append(String(raw_id))
	return result


static func blueprint_for(ability_id: String) -> Dictionary:
	return (ABILITY_BLUEPRINTS.get(ability_id, {}) as Dictionary).duplicate(true)


static func deterministic_safe_angle(seed: int, boss_id: String, phase_index: int, attack_index: int, player_bearing: float = PI*0.5) -> float:
	# Hash the index as part of the key instead of adding it as a small linear
	# offset. Adjacent attack indices must produce visibly different openings,
	# while remaining stable for an identical deterministic challenge context.
	var mixed:=_mixed_seed(seed,"%s:safe:%d:%d" % [boss_id,clampi(phase_index,0,2),maxi(0,attack_index)],0)
	var unit:=float(mixed-1)/2147483628.0
	# Keep the opening in a sector the frozen player can actually reach. A fully
	# random 360-degree gap can point behind the Titan, outside the portrait
	# combat bounds, even while its metadata claims the ring is fair.
	return wrapf(player_bearing+lerpf(-0.58,0.58,clampf(unit,0.0,1.0)),-PI,PI)


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	if ABILITY_IDS.size() != 12 or ABILITY_BLUEPRINTS.size() != 12:
		errors.append("Exterior ability factory requires exactly twelve blueprints")
	var seen_ids: Dictionary = {}
	var mechanics: Dictionary = {}
	var visuals: Dictionary = {}
	var causes: Dictionary = {}
	for raw_id in ABILITY_IDS:
		var ability_id := String(raw_id)
		if ability_id.is_empty() or seen_ids.has(ability_id):
			errors.append("Ability ids must be non-empty and unique")
		seen_ids[ability_id] = true
		var blueprint_value: Variant = ABILITY_BLUEPRINTS.get(ability_id, null)
		if typeof(blueprint_value) != TYPE_DICTIONARY:
			errors.append("Ability %s lacks a blueprint" % ability_id)
			continue
		var blueprint := blueprint_value as Dictionary
		var mechanic := String(blueprint.get("mechanic", ""))
		var visual := String(blueprint.get("visual_token", ""))
		var cause := String(blueprint.get("cause_token", ""))
		if mechanic.is_empty() or mechanics.has(mechanic):
			errors.append("Ability %s requires a mechanically unique compiler" % ability_id)
		if visual.is_empty() or visuals.has(visual):
			errors.append("Ability %s requires a unique visual token" % ability_id)
		if cause != "ability:%s" % ability_id or causes.has(cause):
			errors.append("Ability %s requires its unique stable damage cause" % ability_id)
		mechanics[mechanic] = ability_id
		visuals[visual] = ability_id
		causes[cause] = ability_id
		var budget := int(blueprint.get("projectile_budget", 0))
		if budget < 1 or budget > MAX_PROJECTILES_PER_ATTACK:
			errors.append("Ability %s projectile budget is outside the global cap" % ability_id)
		var telegraph := _numeric(blueprint.get("telegraph_seconds", null), -1.0)
		if telegraph < MIN_TELEGRAPH_SECONDS or telegraph > MAX_TELEGRAPH_SECONDS:
			errors.append("Ability %s telegraph is outside the readability bound" % ability_id)
		if _numeric(blueprint.get("base_speed", null), 0.0) <= 0.0:
			errors.append("Ability %s requires a positive speed" % ability_id)
		if _numeric(blueprint.get("damage", null), 0.0) <= 0.0:
			errors.append("Ability %s requires positive damage" % ability_id)
		if String(blueprint.get("safe_kind", "")).is_empty():
			errors.append("Ability %s requires explicit safe-path metadata" % ability_id)
	for raw_blueprint_id in ABILITY_BLUEPRINTS:
		if String(raw_blueprint_id) not in ABILITY_IDS:
			errors.append("Unordered ability blueprint %s is not launch-owned" % String(raw_blueprint_id))
	return errors


static func build_attack(ability_id: String, context: Dictionary, runtime_contract: Dictionary = {}) -> Dictionary:
	if not ABILITY_BLUEPRINTS.has(ability_id):
		return _rejected(ability_id, "unknown_ability")
	var filter_reason := _contract_filter_reason(ability_id, runtime_contract)
	if not filter_reason.is_empty():
		var filtered := _rejected(ability_id, filter_reason)
		filtered["filtered"] = true
		return filtered
	var clean_context := _sanitize_context(context)
	var blueprint := blueprint_for(ability_id)
	var strength := _contract_strength(runtime_contract)
	var plan := {
		"valid": true,
		"filtered": false,
		"version": SPEC_VERSION,
		"ability_id": ability_id,
		"mechanic": String(blueprint.get("mechanic", "")),
		"visual_token": String(blueprint.get("visual_token", "")),
		"cause_token": String(blueprint.get("cause_token", "")),
		"telegraph": {
			"seconds": float(blueprint.get("telegraph_seconds", 1.0)),
			"shape_token": String(blueprint.get("safe_kind", "")),
			"visual_token": "%s_warning" % String(blueprint.get("visual_token", "")),
		},
		"projectile_budget": mini(int(blueprint.get("projectile_budget", 1)), int(clean_context.projectile_budget_cap)),
		"projectiles": [],
		"effect_directives": [],
		"safe_paths": [],
		"context": clean_context.duplicate(true),
		"runtime_status": String(runtime_contract.get("status", "active")),
		"strength": strength,
		"group_token": _group_token(ability_id, clean_context),
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = _mixed_seed(int(clean_context.seed), ability_id, int(clean_context.attack_index))
	match ability_id:
		"homing_eye":
			_build_homing_eye(plan, blueprint, clean_context, rng)
		"gravity_ring":
			_build_gravity_ring(plan, blueprint, clean_context, rng)
		"bone_missiles":
			_build_bone_missiles(plan, blueprint, clean_context, rng)
		"prism_lances":
			_build_prism_lances(plan, blueprint, clean_context, rng)
		"laser_wings":
			_build_laser_wings(plan, blueprint, clean_context, rng)
		"halo_barrier":
			_build_halo_barrier(plan, blueprint, clean_context, rng)
		"suction_waves":
			_build_suction_waves(plan, blueprint, clean_context, rng)
		"chain_lightning":
			_build_chain_lightning(plan, blueprint, clean_context, rng)
		"parasite_swarm":
			_build_parasite_swarm(plan, blueprint, clean_context, rng)
		"weapon_copy":
			_build_weapon_copy(plan, blueprint, clean_context, rng)
		"echo_dash":
			_build_echo_dash(plan, blueprint, clean_context, rng)
		"false_weakpoints":
			_build_false_weakpoints(plan, blueprint, clean_context, rng)
	if not _finalize_safe_guidance(plan, clean_context):
		plan["valid"] = false
		plan["reason"] = "infeasible_safe_guidance"
	var plan_errors := validate_attack_plan(plan)
	if not plan_errors.is_empty():
		plan["valid"] = false
		plan["errors"] = plan_errors
	return plan


static func build_runtime_pool(runtime_contracts: Array, context: Dictionary) -> Dictionary:
	var by_id: Dictionary = {}
	var errors: Array[String] = []
	for raw_contract in runtime_contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			errors.append("Runtime attack pool contains a non-dictionary contract")
			continue
		var contract := raw_contract as Dictionary
		var ability_id := String(contract.get("ability_id", ""))
		if ability_id.is_empty() or by_id.has(ability_id):
			errors.append("Runtime attack pool requires unique non-empty ability ids")
			continue
		by_id[ability_id] = contract.duplicate(true)
	var attacks: Array[Dictionary] = []
	var filtered_ids: Array[String] = []
	for ability_id in ABILITY_IDS:
		if not by_id.has(ability_id):
			continue
		var plan := build_attack(ability_id, context, by_id[ability_id] as Dictionary)
		if bool(plan.get("filtered", false)):
			filtered_ids.append(ability_id)
		elif bool(plan.get("valid", false)):
			attacks.append(plan)
		else:
			errors.append_array(plan.get("errors", ["Ability %s plan rejected" % ability_id]) as Array)
	for raw_contract_id in by_id:
		var contract_id := String(raw_contract_id)
		if contract_id not in ABILITY_IDS:
			errors.append("Runtime attack pool references unknown ability %s" % contract_id)
	return {
		"valid": errors.is_empty(),
		"attacks": attacks,
		"filtered_ability_ids": filtered_ids,
		"errors": errors,
	}


static func validate_attack_plan(plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ability_id := String(plan.get("ability_id", ""))
	if not ABILITY_BLUEPRINTS.has(ability_id):
		errors.append("Attack plan references an unknown ability")
		return errors
	var blueprint := ABILITY_BLUEPRINTS[ability_id] as Dictionary
	if String(plan.get("mechanic", "")) != String(blueprint.get("mechanic", "")):
		errors.append("Attack plan mechanic does not match its ability")
	if String(plan.get("visual_token", "")) != String(blueprint.get("visual_token", "")):
		errors.append("Attack plan visual token does not match its ability")
	if String(plan.get("cause_token", "")) != String(blueprint.get("cause_token", "")):
		errors.append("Attack plan cause token does not match its ability")
	var budget := int(plan.get("projectile_budget", 0))
	var projectiles_value: Variant = plan.get("projectiles", null)
	if typeof(projectiles_value) != TYPE_ARRAY:
		errors.append("Attack plan projectiles must be an array")
	else:
		var projectiles := projectiles_value as Array
		if projectiles.is_empty() or projectiles.size() > budget or projectiles.size() > MAX_PROJECTILES_PER_ATTACK:
			errors.append("Attack plan exceeds or fails its non-zero projectile budget")
		for projectile_index in projectiles.size():
			var raw_projectile: Variant = projectiles[projectile_index]
			if typeof(raw_projectile) != TYPE_DICTIONARY:
				errors.append("Projectile %d is not a dictionary" % projectile_index)
				continue
			errors.append_array(_validate_projectile(raw_projectile as Dictionary, plan, projectile_index))
	var effects_value: Variant = plan.get("effect_directives", null)
	if typeof(effects_value) != TYPE_ARRAY:
		errors.append("Attack effect directives must be an array")
	else:
		var effects := effects_value as Array
		if effects.is_empty() or effects.size() > MAX_EFFECT_DIRECTIVES:
			errors.append("Attack must publish one to four bounded effect directives")
		for raw_effect in effects:
			if typeof(raw_effect) != TYPE_DICTIONARY:
				errors.append("Attack effect directive is not a dictionary")
				continue
			var effect := raw_effect as Dictionary
			if String(effect.get("type", "")).is_empty() or not bool(effect.get("bounded", false)):
				errors.append("Every effect directive requires a type and explicit bound")
			var duration := _numeric(effect.get("duration_seconds", null), -1.0)
			if duration < 0.0 or duration > 4.0:
				errors.append("Effect directive duration is outside the four-second cap")
	var safe_paths_value: Variant = plan.get("safe_paths", null)
	if typeof(safe_paths_value) != TYPE_ARRAY or (safe_paths_value as Array).is_empty():
		errors.append("Attack plan requires an explicit safe path")
	else:
		for raw_safe_path in safe_paths_value as Array:
			if typeof(raw_safe_path) != TYPE_DICTIONARY:
				errors.append("Safe path is not a dictionary")
				continue
			var safe_path := raw_safe_path as Dictionary
			if String(safe_path.get("kind", "")) != String(blueprint.get("safe_kind", "")):
				errors.append("Safe path kind does not match its ability blueprint")
			var clearance := _numeric(safe_path.get("minimum_clearance_px", null), -1.0)
			if clearance < MIN_SAFE_CLEARANCE_PX or clearance > MAX_SAFE_CLEARANCE_PX:
				errors.append("Safe path clearance is outside the readable bound")
			var reaction := _numeric(safe_path.get("reaction_seconds", null), -1.0)
			if reaction < MIN_TELEGRAPH_SECONDS or reaction > MAX_TELEGRAPH_SECONDS:
				errors.append("Safe path reaction time is outside the readability bound")
			errors.append_array(_validate_safe_guidance(plan, safe_path))
	if String(plan.get("group_token", "")).is_empty():
		errors.append("Attack plan requires deterministic wave ownership")
	return errors


static func _build_homing_eye(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var target_angle := (Vector2(context.player_position) - Vector2(context.origin)).angle()
	var speed := _speed(blueprint, context)
	for offset in [-0.17, 0.0, 0.17]:
		_add_projectile(plan, Vector2(context.origin), Vector2.from_angle(target_angle + offset) * speed, blueprint, {
			"radius": 6.0,
			"homing": 1.05,
			"frozen_target": Vector2(context.player_position),
			"travel_model": "soft_homing",
		})
	var escape_side := -1 if rng.randi_range(0, 1) == 0 else 1
	_add_effect(plan, "target_lock", 1.5, {"turn_response": 1.05, "target_snapshot": Vector2(context.player_position)})
	_add_safe_path(plan, blueprint, {"escape_side": escape_side, "center_line_angle": target_angle, "lane_width_px": 108.0})


static func _build_gravity_ring(plan: Dictionary, blueprint: Dictionary, context: Dictionary, _rng: RandomNumberGenerator) -> void:
	var safe_angle := float(context.safe_angle)
	var safe_half_arc := 0.62
	var speed := _speed(blueprint, context)
	for index in 22:
		var angle := float(index) * TAU / 22.0
		if absf(wrapf(angle - safe_angle, -PI, PI)) < safe_half_arc:
			continue
		_add_projectile(plan, Vector2(context.origin), Vector2.from_angle(angle) * speed, blueprint, {
			"radius": 5.5,
			"travel_model": "expanding",
			"travel_parameters": {"expansion_rate": 7.0, "expansion_max_scale": 1.65},
		})
	_add_effect(plan, "gravity_ring_pulse", 1.8, {
		"radial_acceleration": 70.0,
		"maximum_speed_delta": 82.0,
		"safe_angle":safe_angle,
		"safe_half_arc_radians":safe_half_arc,
	})
	_add_safe_path(plan, blueprint, {"center_angle": safe_angle, "half_arc_radians": safe_half_arc, "radius_px": 300.0})


static func _build_bone_missiles(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var target_angle := (Vector2(context.player_position) - Vector2(context.origin)).angle()
	var speed := _speed(blueprint, context)
	var delay_step := 0.085
	for index in 7:
		var centered := float(index) - 3.0
		_add_projectile(plan, Vector2(context.origin), Vector2.from_angle(target_angle + centered * 0.09) * speed, blueprint, {
			"radius": 6.5,
			"travel_model": "delayed_linear",
			"emission_delay_seconds": float(index) * delay_step,
			"shape": "sickle_shard",
		})
	var safe_side := -1 if rng.randi_range(0, 1) == 0 else 1
	_add_effect(plan, "staggered_salvo", 0.51, {"emission_count": 7, "delay_step_seconds": delay_step})
	_add_safe_path(plan, blueprint, {"safe_side": safe_side, "fan_half_angle": 0.27, "lane_width_px": 96.0})


static func _build_prism_lances(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var arena := context.arena as Rect2
	var gap_index := rng.randi_range(0, 3)
	var lane_centers := [
		arena.position.x + arena.size.x * 0.15,
		arena.position.x + arena.size.x * 0.38,
		arena.position.x + arena.size.x * 0.62,
		arena.position.x + arena.size.x * 0.85,
	]
	var speed := _speed(blueprint, context)
	var emitted := 0
	for lane_index in lane_centers.size():
		if lane_index == gap_index:
			continue
		_add_projectile(plan, Vector2(float(lane_centers[lane_index]), arena.position.y), Vector2.DOWN * speed, blueprint, {
			"radius": 7.0,
			"shape": "prism_lance",
			"travel_model": "linear",
			"emission_delay_seconds": float(emitted) * 0.12,
		})
		emitted += 1
	_add_effect(plan, "prism_lane_sequence", 0.36, {"lane_centers": lane_centers.duplicate(), "safe_lane_index": gap_index})
	_add_safe_path(plan, blueprint, {"lane_center_x": float(lane_centers[gap_index]), "lane_index": gap_index, "lane_width_px": 92.0})


static func _build_laser_wings(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var arena := context.arena as Rect2
	var gap_center := clampf(float(context.player_position.x) + rng.randf_range(-26.0, 26.0), arena.position.x + 92.0, arena.end.x - 92.0)
	var gap_half_width := 68.0
	var step := 38
	var speed := _speed(blueprint, context)
	var lane_xs: Array[float] = []
	for x in range(int(arena.position.x), int(arena.end.x) + 1, step):
		if absf(float(x) - gap_center) < gap_half_width:
			continue
		lane_xs.append(float(x))
		_add_projectile(plan, Vector2(float(x), arena.position.y), Vector2.DOWN * speed, blueprint, {
			"radius": 8.0,
			"shape": "laser_wall",
			"travel_model": "linear",
		})
	_add_effect(plan, "lane_afterglow", 2.45, {
		"gap_center_x": gap_center,
		"gap_half_width": gap_half_width,
		"lane_xs": lane_xs,
		"beam_half_width_px": 8.0,
		"origin_y": arena.position.y,
		"travel_speed": speed,
		"trail_length_px": 82.0,
		"damage": 6.0,
		"damage_tick_cap": 1,
	})
	_add_safe_path(plan, blueprint, {"lane_center_x": gap_center, "lane_width_px": gap_half_width * 2.0})


static func _build_halo_barrier(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var safe_angle := wrapf(float(context.safe_angle) + rng.randf_range(-0.12, 0.12), -PI, PI)
	var safe_half_arc := 0.54
	var rotation_offset := float(context.phase_index) * 0.16
	var speed := _speed(blueprint, context)
	for index in 16:
		var angle := float(index) * TAU / 16.0 + rotation_offset
		if absf(wrapf(angle - safe_angle, -PI, PI)) < safe_half_arc:
			continue
		_add_projectile(plan, Vector2(context.origin), Vector2.from_angle(angle) * speed, blueprint, {
			"radius": 6.0,
			"shape": "halo_orb",
			"travel_model": "linear",
		})
	_add_effect(plan, "temporary_boss_barrier", 1.6, {"damage_reduction": 0.35, "open_arc_angle": safe_angle, "open_arc_half_width": safe_half_arc})
	_add_safe_path(plan, blueprint, {"center_angle": safe_angle, "half_arc_radians": safe_half_arc, "rotation_direction": 1 if rotation_offset >= 0.0 else -1})


static func _build_suction_waves(plan: Dictionary, blueprint: Dictionary, context: Dictionary, _rng: RandomNumberGenerator) -> void:
	var safe_angle := float(context.safe_angle)
	var safe_half_arc := 0.72
	var speed := _speed(blueprint, context)
	for index in 18:
		var angle := float(index) * TAU / 18.0
		if absf(wrapf(angle - safe_angle, -PI, PI)) < safe_half_arc:
			continue
		_add_projectile(plan, Vector2(context.origin), Vector2.from_angle(angle) * speed, blueprint, {
			"radius": 7.0,
			"shape": "tide_wave",
			"travel_model": "expanding",
			"travel_parameters": {"expansion_rate": 12.0, "expansion_max_scale": 2.1},
		})
	_add_effect(plan, "bounded_pull", 1.45, {
		"center": Vector2(context.origin),
		"radius_px": 430.0,
		"acceleration_px_per_second_sq": 88.0,
		"maximum_speed_delta_px_per_second": 96.0,
		"maximum_position_delta_px": 56.0,
		"safe_angle":safe_angle,
		"safe_half_arc_radians":safe_half_arc,
	})
	_add_safe_path(plan, blueprint, {"center_angle": safe_angle, "half_arc_radians": safe_half_arc, "pull_multiplier": 0.0})


static func _build_chain_lightning(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var arena := context.arena as Rect2
	var safe_lane := rng.randi_range(0, 2)
	var lane_width := arena.size.x / 3.0
	var nodes: Array[Vector2] = []
	var links: Array[Dictionary] = []
	for lane_index in 3:
		if lane_index == safe_lane:
			continue
		var lane_center := arena.position.x + lane_width * (float(lane_index) + 0.5)
		var first:=Vector2(lane_center - 32.0, arena.position.y + 70.0)
		var second:=Vector2(lane_center + 32.0, arena.position.y + 275.0)
		nodes.append(first)
		nodes.append(second)
		links.append({"from":first,"to":second,"lane_index":lane_index})
		links.append({"from":second,"to":first,"lane_index":lane_index})
	var speed := _speed(blueprint, context)
	for node_index in nodes.size():
		var node := nodes[node_index]
		var target_node := nodes[node_index+1] if node_index%2==0 else nodes[node_index-1]
		var direction := (target_node - node).normalized()
		_add_projectile(plan, node, direction * speed, blueprint, {
			"radius": 8.0,
			"life":clampf(node.distance_to(target_node)/maxf(1.0,speed),0.25,1.25),
			"travel_model": "node_link",
			"travel_parameters": {"link_amplitude": 22.0, "link_frequency_hz": 2.2, "link_phase_radians": float(node_index) * 0.7},
		})
	_add_effect(plan, "linked_nodes", 1.25, {"nodes": nodes.duplicate(), "links":links, "safe_lane_index":safe_lane, "maximum_hops": 3, "chain_radius_px": 74.0})
	_add_safe_path(plan, blueprint, {"lane_center_x": arena.position.x + lane_width * (float(safe_lane) + 0.5), "lane_index": safe_lane, "lane_width_px": 104.0})


static func _build_parasite_swarm(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var arena := context.arena as Rect2
	var split_side := -1 if rng.randi_range(0, 1) == 0 else 1
	var speed := _speed(blueprint, context)
	var actor_specs: Array[Dictionary] = []
	for index in 5:
		var origin := Vector2(arena.position.x + arena.size.x * (float(index) + 1.0) / 6.0, arena.position.y + 34.0)
		var target := Vector2(context.player_position) + Vector2(float(index - 2) * 26.0, 0.0)
		var velocity := (target - origin).normalized() * speed
		_add_projectile(plan, origin, velocity, blueprint, {
			"radius": 9.0,
			"shape": "sprite_actor",
			"travel_model": "lunge",
			"travel_parameters": {"windup_seconds": 0.22, "burst_seconds": 0.24, "windup_multiplier": 0.18, "burst_multiplier": 2.75, "recovery_multiplier": 0.58},
		})
		actor_specs.append({"spawn": origin, "lunge_target": target, "actor_token": "river_sprite"})
	_add_effect(plan, "spawn_lunge_actors", 1.2, {"actors": actor_specs, "actor_cap": 5, "despawn_seconds": 2.6})
	_add_safe_path(plan, blueprint, {"split_side": split_side, "separation_px": 116.0, "lane_width_px": 102.0})


static func _build_weapon_copy(plan: Dictionary, blueprint: Dictionary, context: Dictionary, _rng: RandomNumberGenerator) -> void:
	var archetype := String(context.weapon_archetype)
	var origin := Vector2(context.origin)
	var player_angle := (Vector2(context.player_position) - origin).angle()
	var speed := _speed(blueprint, context)
	var counter_token := "sidestep"
	match archetype:
		"scatter":
			counter_token = "leave_close_cone"
			for offset in [-0.32, -0.16, 0.0, 0.16, 0.32]:
				_add_projectile(plan, origin, Vector2.from_angle(player_angle + offset) * speed * 0.82, blueprint, {"radius": 5.5, "shape": "copied_scatter", "travel_model": "linear"})
		"rail":
			counter_token = "cross_rail_warning"
			_add_projectile(plan, origin, Vector2.from_angle(player_angle) * speed * 1.35, blueprint, {"radius": 9.0, "shape": "copied_rail", "travel_model": "delayed_linear", "emission_delay_seconds": 0.18, "piercing_warning": true})
		"arc":
			counter_token = "break_arc_alignment"
			for offset in [-0.18, 0.0, 0.18]:
				_add_projectile(plan, origin, Vector2.from_angle(player_angle + offset) * speed, blueprint, {"radius": 7.0, "shape": "copied_arc", "travel_model": "node_link", "travel_parameters": {"link_amplitude": 18.0, "link_frequency_hz": 1.8, "link_phase_radians": offset * 4.0}})
		"orbitals":
			counter_token = "exit_orbital_ring"
			for index in 6:
				var angle := float(index) * TAU / 6.0
				_add_projectile(plan, origin, Vector2.from_angle(angle) * speed * 0.72, blueprint, {"radius": 7.0, "shape": "copied_orbital", "travel_model": "expanding", "travel_parameters": {"expansion_rate": 5.0, "expansion_max_scale": 1.55}})
		_:
			counter_token = "sidestep_pulse_echo"
			for offset in [-0.10, 0.0, 0.10]:
				_add_projectile(plan, origin, Vector2.from_angle(player_angle + offset) * speed, blueprint, {"radius": 5.5, "shape": "copied_pulse", "travel_model": "delayed_linear", "emission_delay_seconds": absf(offset) * 0.8})
	_add_effect(plan, "weapon_copy", 1.3, {"source_archetype": archetype, "translation_rule": counter_token, "copy_damage_cap": 12.0})
	_add_safe_path(plan, blueprint, {"source_archetype": archetype, "counter_token": counter_token, "lane_width_px": 96.0})


static func _build_echo_dash(plan: Dictionary, blueprint: Dictionary, context: Dictionary, _rng: RandomNumberGenerator) -> void:
	var path := context.dash_path as Array[Vector2]
	var duration := clampf(0.16 * float(path.size() - 1), 0.32, 1.12)
	var exit_direction := path[path.size() - 1] - path[path.size() - 2]
	if exit_direction.length_squared() < 0.001:
		exit_direction = Vector2.DOWN
	var exit_velocity := exit_direction.normalized() * _speed(blueprint, context) * 0.55
	_add_projectile(plan, path[0], exit_velocity, blueprint, {
		"radius": 11.0,
		"shape": "echo_trail_head",
		"travel_model": "recorded_path",
		"travel_parameters": {
			"path_duration": duration,
			"path_points": path.duplicate(),
			"path_relative": false,
			"path_exit_velocity": exit_velocity,
		},
	})
	_add_effect(plan, "recorded_dash_danger_trail", duration, {
		"path_points": path.duplicate(),
		"trail_radius_px": 22.0,
		"point_cap": 8,
		"damage": 8.0,
		"maximum_hits": 1,
	})
	var path_center := _path_center(path)
	var safe_side := -1 if path_center.x >= (context.arena as Rect2).get_center().x else 1
	_add_safe_path(plan, blueprint, {"safe_side": safe_side, "path_point_count": path.size(), "trail_radius_px": 22.0, "lane_width_px": 104.0})


static func _build_false_weakpoints(plan: Dictionary, blueprint: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> void:
	var arena := context.arena as Rect2
	var true_position := Vector2(context.origin)
	var decoys: Array[Vector2] = []
	var horizontal_offsets := [-118.0, 0.0, 118.0]
	var jitter := rng.randf_range(-12.0, 12.0)
	for index in horizontal_offsets.size():
		var decoy := Vector2(true_position.x + float(horizontal_offsets[index]) + jitter, true_position.y + 54.0 + float(index % 2) * 42.0)
		decoys.append(_clamp_point(decoy, arena, 18.0))
	var speed := _speed(blueprint, context)
	for decoy_index in decoys.size():
		var decoy := decoys[decoy_index]
		var base_angle := (Vector2(context.player_position) - decoy).angle()
		for offset in [-0.08, 0.08]:
			_add_projectile(plan, decoy, Vector2.from_angle(base_angle + offset) * speed, blueprint, {"radius": 6.0, "shape": "mirror_shard", "travel_model": "linear", "decoy_index": decoy_index})
	_add_effect(plan, "spawn_decoy_weakpoints", 2.4, {
		"decoy_positions": decoys.duplicate(),
		"true_position": true_position,
		"decoy_count": 3,
		"decoys_take_damage": false,
		"maximum_retaliation_shots": 6,
		"aim_decoy_index": rng.randi_range(0, decoys.size() - 1),
	})
	_add_safe_path(plan, blueprint, {"true_position": true_position, "decoy_positions": decoys.duplicate(), "lane_width_px": 92.0})


static func _add_projectile(plan: Dictionary, origin: Vector2, velocity: Vector2, blueprint: Dictionary, extra_options: Dictionary) -> void:
	var projectiles := plan.projectiles as Array
	if projectiles.size() >= int(plan.projectile_budget):
		return
	var options := extra_options.duplicate(true)
	options["cause"] = String(plan.cause_token)
	options["group"] = String(plan.group_token)
	options["visual_token"] = String(plan.visual_token)
	options["life"] = clampf(_numeric(options.get("life", 4.0), 4.0), 0.25, 7.0)
	if not options.has("travel_model"):
		options["travel_model"] = "linear"
	projectiles.append({
		"origin": origin,
		"velocity": velocity,
		"damage": float(blueprint.get("damage", 1.0)) * float(plan.strength),
		"options": options,
	})


static func _add_effect(plan: Dictionary, type: String, duration_seconds: float, properties: Dictionary) -> void:
	var effects := plan.effect_directives as Array
	if effects.size() >= MAX_EFFECT_DIRECTIVES:
		return
	var effect := properties.duplicate(true)
	effect["type"] = type
	effect["bounded"] = true
	effect["duration_seconds"] = clampf(duration_seconds, 0.0, 4.0)
	effect["cause_token"] = String(plan.cause_token)
	effects.append(effect)


static func _add_safe_path(plan: Dictionary, blueprint: Dictionary, properties: Dictionary) -> void:
	var safe_path := properties.duplicate(true)
	safe_path["kind"] = String(blueprint.get("safe_kind", ""))
	safe_path["minimum_clearance_px"] = clampf(_numeric(properties.get("lane_width_px", properties.get("separation_px", 96.0)), 96.0), MIN_SAFE_CLEARANCE_PX, MAX_SAFE_CLEARANCE_PX)
	safe_path["reaction_seconds"] = float((plan.telegraph as Dictionary).seconds)
	safe_path["instruction_token"] = "safe:%s" % String(blueprint.get("safe_kind", ""))
	(plan.safe_paths as Array).append(safe_path)


static func _finalize_safe_guidance(plan: Dictionary, context: Dictionary) -> bool:
	var safe_paths := plan.get("safe_paths", []) as Array
	if safe_paths.size() != 1:
		return false
	var safe_path := safe_paths[0] as Dictionary
	var target_value: Variant = _resolve_safe_target(plan, safe_path, context)
	if target_value == null:
		return false
	var target := target_value as Vector2
	var player_position := Vector2(context.player_position)
	var reaction_seconds := float(safe_path.get("reaction_seconds", MIN_TELEGRAPH_SECONDS))
	var movement := target - player_position
	var resolved_side := 0
	var aimed_direction := (player_position - Vector2(context.origin)).normalized()
	if aimed_direction.length_squared() > 0.0001 and movement.length_squared() > 0.0001:
		resolved_side = 1 if aimed_direction.cross(movement) > 0.0 else -1
	safe_path["safe_target"] = target
	safe_path["safe_radius_px"] = GUIDANCE_SAFE_RADIUS_PX
	safe_path["corridor_start"] = player_position
	safe_path["corridor_end"] = target
	safe_path["corridor_half_width_px"] = GUIDANCE_CORRIDOR_HALF_WIDTH_PX
	safe_path["corridor_clear_until_seconds"] = reaction_seconds
	safe_path["arrival_seconds"] = player_position.distance_to(target) / GUIDANCE_MAX_PLAYER_SPEED_PX
	safe_path["hazard_horizon_seconds"] = _guidance_hazard_horizon(plan)
	safe_path["resolved_side"] = resolved_side
	safe_path["guidance_clamped"] = true
	for side_key in ["safe_side", "escape_side", "split_side"]:
		if safe_path.has(side_key) and resolved_side != 0:
			safe_path[side_key] = resolved_side
	safe_paths[0] = safe_path
	plan["safe_paths"] = safe_paths
	for projectile_index in (plan.projectiles as Array).size():
		var projectile := (plan.projectiles as Array)[projectile_index] as Dictionary
		var options := (projectile.get("options", {}) as Dictionary).duplicate(true)
		options["safe_position"] = target
		options["safe_radius"] = GUIDANCE_SAFE_RADIUS_PX
		projectile["options"] = options
		(plan.projectiles as Array)[projectile_index] = projectile
	for directive_index in (plan.effect_directives as Array).size():
		var directive := (plan.effect_directives as Array)[directive_index] as Dictionary
		directive["safe_target"] = target
		directive["safe_radius_px"] = GUIDANCE_SAFE_RADIUS_PX
		(plan.effect_directives as Array)[directive_index] = directive
	return true


static func _resolve_safe_target(plan: Dictionary, safe_path: Dictionary, context: Dictionary) -> Variant:
	var player_position := Vector2(context.player_position)
	var reaction_seconds := float(safe_path.get("reaction_seconds", MIN_TELEGRAPH_SECONDS))
	var maximum_distance := reaction_seconds * GUIDANCE_MAX_PLAYER_SPEED_PX
	var candidates := _guidance_candidates(safe_path, context)
	for candidate in candidates:
		if player_position.distance_to(candidate) > maximum_distance + 0.001:
			continue
		if not _candidate_matches_safe_semantics(candidate, safe_path, context):
			continue
		if not _candidate_clears_effect_hazards(candidate, plan):
			continue
		return candidate
	return null


static func _guidance_candidates(safe_path: Dictionary, context: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var bounds := context.combat_bounds as Rect2
	var player_position := Vector2(context.player_position)
	var origin := Vector2(context.origin)
	var clamp_margin := maxf(GUIDANCE_EDGE_MARGIN_PX, GUIDANCE_SAFE_RADIUS_PX)
	if safe_path.has("lane_center_x"):
		var lane_x := float(safe_path.lane_center_x)
		for y_offset in [0.0, -72.0, 72.0, -144.0, 144.0, -216.0, 216.0]:
			_append_guidance_candidate(result, Vector2(lane_x, player_position.y + float(y_offset)), bounds, clamp_margin)
	if safe_path.has("center_angle") and safe_path.has("half_arc_radians"):
		var center_angle := float(safe_path.center_angle)
		var half_arc := float(safe_path.half_arc_radians)
		var base_distance := origin.distance_to(player_position)
		for angle_offset in [0.0, -half_arc * 0.28, half_arc * 0.28, -half_arc * 0.52, half_arc * 0.52]:
			for distance_offset in [0.0, -72.0, 72.0, -144.0, 144.0, -216.0, 216.0]:
				var radial_distance := maxf(72.0, base_distance + float(distance_offset))
				_append_guidance_candidate(result, origin + Vector2.from_angle(center_angle + float(angle_offset)) * radial_distance, bounds, clamp_margin)
	var requested_side := int(safe_path.get("safe_side", safe_path.get("escape_side", safe_path.get("split_side", 0))))
	if requested_side != 0:
		var aimed_direction := (player_position - origin).normalized()
		if aimed_direction.length_squared() < 0.0001:
			aimed_direction = Vector2.DOWN
		var normal := Vector2(-aimed_direction.y, aimed_direction.x)
		for side in [requested_side, -requested_side]:
			for distance in [108.0, 144.0, 78.0, 186.0, 234.0, 294.0]:
				_append_guidance_candidate(result, player_position + normal * float(side) * float(distance), bounds, clamp_margin)
	var keyed_rotation := float(posmod(int(context.seed) + int(context.attack_index) * 13, 24)) * TAU / 24.0
	for distance in [72.0, 108.0, 144.0, 190.0, 240.0, 310.0, 390.0]:
		for direction_index in 24:
			var angle := keyed_rotation + float(direction_index) * TAU / 24.0
			_append_guidance_candidate(result, player_position + Vector2.from_angle(angle) * float(distance), bounds, clamp_margin)
	for y_fraction in [0.12, 0.32, 0.52, 0.72, 0.88]:
		for x_fraction in [0.08, 0.25, 0.5, 0.75, 0.92]:
			_append_guidance_candidate(result, bounds.position + Vector2(bounds.size.x * float(x_fraction), bounds.size.y * float(y_fraction)), bounds, clamp_margin)
	return result


static func _append_guidance_candidate(result: Array[Vector2], raw_candidate: Vector2, bounds: Rect2, margin: float) -> void:
	if not _is_finite_vector(raw_candidate):
		return
	var candidate := _clamp_point(raw_candidate, bounds, margin)
	for existing in result:
		if existing.distance_squared_to(candidate) < 0.01:
			return
	result.append(candidate)


static func _candidate_matches_safe_semantics(candidate: Vector2, safe_path: Dictionary, context: Dictionary) -> bool:
	var player_position := Vector2(context.player_position)
	if player_position.distance_to(candidate) < MIN_SAFE_CLEARANCE_PX - 0.001:
		return false
	if safe_path.has("lane_center_x"):
		var half_width := maxf(GUIDANCE_SAFE_RADIUS_PX, float(safe_path.get("lane_width_px", 96.0)) * 0.5)
		if absf(candidate.x - float(safe_path.lane_center_x)) + GUIDANCE_SAFE_RADIUS_PX > half_width + 0.001:
			return false
	if safe_path.has("center_angle") and safe_path.has("half_arc_radians"):
		var origin := Vector2(context.origin)
		var distance := origin.distance_to(candidate)
		if distance <= GUIDANCE_SAFE_RADIUS_PX:
			return false
		var angular_radius := asin(clampf(GUIDANCE_SAFE_RADIUS_PX / distance, 0.0, 0.95))
		var angle_delta := absf(wrapf((candidate - origin).angle() - float(safe_path.center_angle), -PI, PI))
		if angle_delta + angular_radius > float(safe_path.half_arc_radians) + 0.001:
			return false
	return true


static func _candidate_clears_effect_hazards(candidate: Vector2, plan: Dictionary) -> bool:
	for raw_directive in plan.effect_directives as Array:
		var directive := raw_directive as Dictionary
		match String(directive.get("type", "")):
			"lane_afterglow":
				var required_lane_clearance := GUIDANCE_SAFE_RADIUS_PX + maxf(1.0, float(directive.get("beam_half_width_px", 8.0)))
				for raw_x in directive.get("lane_xs", []):
					if absf(candidate.x - float(raw_x)) < required_lane_clearance - 0.001:
						return false
			"recorded_dash_danger_trail":
				var path := directive.get("path_points", []) as Array
				var required_trail_clearance := GUIDANCE_SAFE_RADIUS_PX + maxf(1.0, float(directive.get("trail_radius_px", 22.0)))
				for point_index in range(maxi(0, path.size() - 1)):
					if _point_segment_distance(candidate, Vector2(path[point_index]), Vector2(path[point_index + 1])) < required_trail_clearance - 0.001:
						return false
			"gravity_ring_pulse", "bounded_pull":
				if directive.has("safe_angle") and directive.has("safe_half_arc_radians"):
					var center := Vector2(directive.get("center", (plan.context as Dictionary).origin))
					var distance := center.distance_to(candidate)
					if distance <= GUIDANCE_SAFE_RADIUS_PX:
						return false
					var angular_radius := asin(clampf(GUIDANCE_SAFE_RADIUS_PX / distance, 0.0, 0.95))
					var angle_delta := absf(wrapf((candidate - center).angle() - float(directive.safe_angle), -PI, PI))
					if angle_delta + angular_radius > float(directive.safe_half_arc_radians) + 0.001:
						return false
	return true


static func _guidance_hazard_horizon(plan: Dictionary) -> float:
	var horizon := float((plan.telegraph as Dictionary).get("seconds", MIN_TELEGRAPH_SECONDS))
	for raw_projectile in plan.projectiles as Array:
		var options := ((raw_projectile as Dictionary).get("options", {}) as Dictionary)
		horizon = maxf(horizon, float(options.get("life", 4.0)) + float(options.get("emission_delay_seconds", 0.0)))
	for raw_directive in plan.effect_directives as Array:
		horizon = maxf(horizon, float((raw_directive as Dictionary).get("duration_seconds", 0.0)))
	return clampf(horizon, MIN_TELEGRAPH_SECONDS, GUIDANCE_MAX_HAZARD_HORIZON_SECONDS)


static func _validate_safe_guidance(plan: Dictionary, safe_path: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var context_value: Variant = plan.get("context", null)
	if typeof(context_value) != TYPE_DICTIONARY:
		return ["Safe guidance requires sanitized attack context"]
	var context := context_value as Dictionary
	var combat_bounds_value: Variant = context.get("combat_bounds", null)
	if not combat_bounds_value is Rect2:
		return ["Safe guidance requires explicit player combat bounds"]
	var combat_bounds := combat_bounds_value as Rect2
	var target_value: Variant = safe_path.get("safe_target", null)
	var corridor_start_value: Variant = safe_path.get("corridor_start", null)
	var corridor_end_value: Variant = safe_path.get("corridor_end", null)
	if not _is_finite_vector(target_value) or not _is_finite_vector(corridor_start_value) or not _is_finite_vector(corridor_end_value):
		return ["Safe guidance requires finite absolute target and corridor endpoints"]
	var target := target_value as Vector2
	var corridor_start := corridor_start_value as Vector2
	var corridor_end := corridor_end_value as Vector2
	var safe_radius := _numeric(safe_path.get("safe_radius_px", null), -1.0)
	var corridor_half_width := _numeric(safe_path.get("corridor_half_width_px", null), -1.0)
	if safe_radius < 24.0 or safe_radius > 48.0:
		errors.append("Safe target radius is outside the player-readable bound")
	if corridor_half_width < 8.0 or corridor_half_width > safe_radius:
		errors.append("Safe corridor width is outside the player-readable bound")
	if not _disk_inside_rect(target, safe_radius, combat_bounds):
		errors.append("Safe target leaves player combat bounds")
	if not _point_inside_rect_inclusive(corridor_start, combat_bounds) or not _disk_inside_rect(corridor_end, corridor_half_width, combat_bounds):
		errors.append("Safe corridor leaves player combat bounds")
	if not corridor_end.is_equal_approx(target):
		errors.append("Safe corridor must terminate at the absolute safe target")
	var reaction := _numeric(safe_path.get("reaction_seconds", null), -1.0)
	var arrival := _numeric(safe_path.get("arrival_seconds", null), -1.0)
	var expected_arrival := corridor_start.distance_to(target) / GUIDANCE_MAX_PLAYER_SPEED_PX
	if arrival < 0.0 or not is_equal_approx(arrival, expected_arrival) or arrival > reaction + 0.001:
		errors.append("Safe target is not reachable during the telegraph")
	if not is_equal_approx(_numeric(safe_path.get("corridor_clear_until_seconds", null), -1.0), reaction):
		errors.append("Safe corridor lifetime must cover the complete telegraph")
	var hazard_horizon := _numeric(safe_path.get("hazard_horizon_seconds", null), -1.0)
	if hazard_horizon < reaction or hazard_horizon > GUIDANCE_MAX_HAZARD_HORIZON_SECONDS:
		errors.append("Safe target hazard horizon is outside the attack bound")
	if not _candidate_matches_safe_semantics(target, safe_path, context) or not _candidate_clears_effect_hazards(target, plan):
		errors.append("Safe target overlaps authored hazard geometry")
	for raw_projectile in plan.projectiles as Array:
		var options := ((raw_projectile as Dictionary).get("options", {}) as Dictionary)
		if not _is_finite_vector(options.get("safe_position", null)) or not Vector2(options.safe_position).is_equal_approx(target):
			errors.append("Projectile runtime lost the absolute safe target")
			break
		if _numeric(options.get("safe_radius", null), -1.0) + 0.001 < safe_radius:
			errors.append("Projectile runtime safe disk is smaller than its guidance")
			break
	return errors


static func _disk_inside_rect(center: Vector2, radius: float, bounds: Rect2) -> bool:
	return center.x - radius >= bounds.position.x - 0.001 \
		and center.x + radius <= bounds.end.x + 0.001 \
		and center.y - radius >= bounds.position.y - 0.001 \
		and center.y + radius <= bounds.end.y + 0.001


static func _point_inside_rect_inclusive(point: Vector2, bounds: Rect2) -> bool:
	return point.x >= bounds.position.x - 0.001 \
		and point.x <= bounds.end.x + 0.001 \
		and point.y >= bounds.position.y - 0.001 \
		and point.y <= bounds.end.y + 0.001


static func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.000001:
		return point.distance_to(start)
	var alpha := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * alpha)


static func _validate_projectile(projectile: Dictionary, plan: Dictionary, index: int) -> Array[String]:
	var errors: Array[String] = []
	var origin_value: Variant = projectile.get("origin", null)
	var velocity_value: Variant = projectile.get("velocity", null)
	if not _is_finite_vector(origin_value):
		errors.append("Projectile %d has a non-finite origin" % index)
	if not _is_finite_vector(velocity_value) or (velocity_value as Vector2).length() <= 0.0 or (velocity_value as Vector2).length() > 1100.0:
		errors.append("Projectile %d velocity is outside the runtime bound" % index)
	var damage := _numeric(projectile.get("damage", null), -1.0)
	if damage <= 0.0 or damage > 20.0:
		errors.append("Projectile %d damage is outside the runtime bound" % index)
	var options_value: Variant = projectile.get("options", null)
	if typeof(options_value) != TYPE_DICTIONARY:
		errors.append("Projectile %d lacks runtime options" % index)
		return errors
	var options := options_value as Dictionary
	if String(options.get("cause", "")) != String(plan.get("cause_token", "")):
		errors.append("Projectile %d lost its attributable cause" % index)
	if String(options.get("group", "")) != String(plan.get("group_token", "")):
		errors.append("Projectile %d lost its deterministic wave owner" % index)
	if String(options.get("visual_token", "")) != String(plan.get("visual_token", "")):
		errors.append("Projectile %d lost its ability visual token" % index)
	if _numeric(options.get("radius", 7.0), -1.0) <= 0.0 or _numeric(options.get("radius", 7.0), -1.0) > 16.0:
		errors.append("Projectile %d radius is outside the readable bound" % index)
	if _numeric(options.get("life", null), -1.0) < 0.25 or _numeric(options.get("life", null), -1.0) > 7.0:
		errors.append("Projectile %d lifetime is outside the pool bound" % index)
	return errors


static func _contract_filter_reason(ability_id: String, contract: Dictionary) -> String:
	if contract.is_empty():
		return ""
	if String(contract.get("ability_id", ability_id)) != ability_id:
		return "contract_ability_mismatch"
	if contract.has("runtime_enabled") and contract.get("runtime_enabled") is bool and not bool(contract.runtime_enabled):
		return "organ_disabled"
	if String(contract.get("status", "active")) == STATUS_DISABLED:
		return "organ_disabled"
	var strength_value: Variant = contract.get("strength", 1.0)
	if typeof(strength_value) in [TYPE_INT, TYPE_FLOAT] and (not is_finite(float(strength_value)) or float(strength_value) <= 0.0):
		return "organ_disabled"
	return ""


static func _contract_strength(contract: Dictionary) -> float:
	if contract.is_empty():
		return 1.0
	return clampf(_numeric(contract.get("strength", 1.0), 1.0), 0.15, 1.0)


static func _sanitize_context(context: Dictionary) -> Dictionary:
	var arena := DEFAULT_ARENA
	var arena_value: Variant = context.get("arena", DEFAULT_ARENA)
	if arena_value is Rect2:
		var candidate := arena_value as Rect2
		if _is_finite_vector(candidate.position) and _is_finite_vector(candidate.size) and candidate.size.x >= 360.0 and candidate.size.y >= 500.0:
			arena = candidate
	var combat_bounds := _sanitize_combat_bounds(context.get("combat_bounds", DEFAULT_COMBAT_BOUNDS), arena)
	var origin := _finite_vector_or(context.get("origin", Vector2(arena.get_center().x, arena.position.y + 40.0)), Vector2(arena.get_center().x, arena.position.y + 40.0))
	var player_position := _finite_vector_or(context.get("player_position", Vector2(combat_bounds.get_center().x, combat_bounds.end.y - 54.0)), Vector2(combat_bounds.get_center().x, combat_bounds.end.y - 54.0))
	origin = _clamp_point(origin, arena, 12.0)
	# Preserve the exact legal player snapshot used by targeting. Safe guidance
	# is clamped independently; moving an edge player inward here would make the
	# warning disagree with the frozen target consumed at spawn time.
	player_position = _clamp_point(player_position, combat_bounds, 0.0)
	var safe_angle := _numeric(context.get("safe_angle", (player_position - origin).angle()), (player_position - origin).angle())
	safe_angle = wrapf(safe_angle, -PI, PI)
	var weapon_archetype := String(context.get("weapon_archetype", "pulse"))
	if weapon_archetype not in VALID_WEAPON_ARCHETYPES:
		weapon_archetype = "pulse"
	return {
		"arena": arena,
		"combat_bounds": combat_bounds,
		"origin": origin,
		"player_position": player_position,
		"safe_angle": safe_angle,
		"seed": _bounded_seed(context.get("seed", 0)),
		"attack_index": clampi(_bounded_int(context.get("attack_index", 0), 0), 0, 1000000),
		"phase_index": clampi(_bounded_int(context.get("phase_index", 0), 0), 0, 2),
		"speed_multiplier": clampf(_numeric(context.get("speed_multiplier", 1.0), 1.0), MIN_SPEED_MULTIPLIER, MAX_SPEED_MULTIPLIER),
		"projectile_budget_cap": clampi(_bounded_int(context.get("projectile_budget_cap", MAX_PROJECTILES_PER_ATTACK), MAX_PROJECTILES_PER_ATTACK), 1, MAX_PROJECTILES_PER_ATTACK),
		"weapon_archetype": weapon_archetype,
		"dash_path": _sanitize_dash_path(context.get("dash_path", []), player_position, arena),
	}


static func _sanitize_combat_bounds(raw_bounds: Variant, arena: Rect2) -> Rect2:
	if raw_bounds is Rect2:
		var candidate := raw_bounds as Rect2
		if _is_finite_vector(candidate.position) \
			and _is_finite_vector(candidate.size) \
			and candidate.size.x >= 240.0 \
			and candidate.size.y >= 260.0 \
			and candidate.position.x >= arena.position.x \
			and candidate.position.y >= arena.position.y \
			and candidate.end.x <= arena.end.x \
			and candidate.end.y <= arena.end.y:
			return candidate
	var default_intersection := arena.intersection(DEFAULT_COMBAT_BOUNDS)
	if default_intersection.size.x >= 240.0 and default_intersection.size.y >= 260.0:
		return default_intersection
	return Rect2(
		arena.position + Vector2(2.0, arena.size.y * 0.25),
		Vector2(maxf(240.0, arena.size.x - 4.0), maxf(260.0, arena.size.y * 0.65))
	).intersection(arena)


static func _sanitize_dash_path(raw_path: Variant, player_position: Vector2, arena: Rect2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if raw_path is Array or raw_path is PackedVector2Array:
		for raw_point in raw_path:
			if result.size() >= 8:
				break
			if not _is_finite_vector(raw_point):
				continue
			var point := _clamp_point(raw_point as Vector2, arena, 12.0)
			if result.is_empty() or result.back().distance_to(point) >= 2.0:
				result.append(point)
	if result.size() < 2:
		var start := _clamp_point(player_position + Vector2(-46.0, 20.0), arena, 12.0)
		var finish := _clamp_point(player_position + Vector2(46.0, -76.0), arena, 12.0)
		if start.distance_to(finish) < 2.0:
			finish = _clamp_point(start + Vector2(72.0, 0.0), arena, 12.0)
		result = [start, finish]
	return result


static func _path_center(path: Array[Vector2]) -> Vector2:
	var total := Vector2.ZERO
	for point in path:
		total += point
	return total / float(maxi(1, path.size()))


static func _speed(blueprint: Dictionary, context: Dictionary) -> float:
	return clampf(float(blueprint.get("base_speed", 180.0)) * float(context.speed_multiplier), 90.0, 900.0)


static func _group_token(ability_id: String, context: Dictionary) -> String:
	return "titan:%s:%d:%d" % [ability_id, int(context.seed), int(context.attack_index)]


static func _mixed_seed(seed: int, ability_id: String, attack_index: int) -> int:
	var value := posmod(seed, 2147483629)
	value = posmod(value * 48271 + _stable_hash(ability_id), 2147483629)
	value = posmod(value * 69621 + attack_index * 7919, 2147483629)
	return maxi(1, value)


static func _stable_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ int(byte)) * 16777619) & 0x7fffffff
	return result


static func _bounded_seed(raw: Variant) -> int:
	var value := _bounded_int(raw, 0)
	return posmod(value, 2147483629)


static func _bounded_int(raw: Variant, fallback: int) -> int:
	if typeof(raw) != TYPE_INT:
		return fallback
	return int(raw)


static func _numeric(raw: Variant, fallback: float) -> float:
	if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var value := float(raw)
	return value if is_finite(value) else fallback


static func _is_finite_vector(raw: Variant) -> bool:
	return raw is Vector2 and is_finite((raw as Vector2).x) and is_finite((raw as Vector2).y)


static func _finite_vector_or(raw: Variant, fallback: Vector2) -> Vector2:
	return raw as Vector2 if _is_finite_vector(raw) else fallback


static func _clamp_point(point: Vector2, arena: Rect2, margin: float) -> Vector2:
	var maximum_x := maxf(arena.position.x + margin, arena.end.x - margin)
	var maximum_y := maxf(arena.position.y + margin, arena.end.y - margin)
	return Vector2(
		clampf(point.x, arena.position.x + margin, maximum_x),
		clampf(point.y, arena.position.y + margin, maximum_y)
	)


static func _rejected(ability_id: String, reason: String) -> Dictionary:
	return {
		"valid": false,
		"filtered": false,
		"ability_id": ability_id,
		"reason": reason,
		"projectiles": [],
		"effect_directives": [],
		"safe_paths": [],
		"errors": ["Attack %s rejected: %s" % [ability_id, reason]],
	}
