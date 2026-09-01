class_name RoomDefenderEffects
extends RefCounted

## Pure, deterministic kill-effect compiler for authored internal defenders.
##
## This class performs no scene mutation. It converts a killed defender plus a
## small runtime context into bounded, wave-scoped operations that RunScene can
## execute later. All positions are serialized as world-pixel arrays so plans
## can also be recorded in deterministic challenge/replay summaries.

const EFFECT_VERSION := 1
const COORDINATE_SPACE := "run_world_pixels"
const MAX_DURATION_SECONDS := 5.0
const MAX_COVER_RADIUS_PIXELS := 96.0
const MAX_PROJECTILE_CLEAR_COUNT := 12
const MAX_PENDING_CANCEL_COUNT := 32

const OPERATION_IDS := [
	"spawn_timed_cover",
	"cancel_pending_emissions",
	"clear_owned_projectiles",
	"mark_priority_target",
	"disable_tracking",
	"break_link",
	"suppress_hatch",
	"disrupt_echo",
	"reveal_true_target",
	"remove_false_targets",
]

const EXPECTED_ARCHETYPE_ROLES := {
	"orbit_sentinel": "skirmisher",
	"pincer_hunter": "flanker",
	"armor_drone": "cover",
	"tracker_mite": "pursuer",
	"prism_guard": "cover",
	"resonance_mouth": "emitter",
	"arc_linker": "link_node",
	"hatchling": "charger",
	"echo_clone": "mirror",
	"decoy_core": "false_target",
}

## Profiles are declarative. Templates contain only bounded parameters; common
## ownership, source, position, and event-id fields are injected by compile().
const ARCHETYPE_PROFILES := {
	"orbit_sentinel": {
		"collision_role": "skirmisher",
		"effect_id": "orbit_interrupt",
		"operations": [
			{"op":"cancel_pending_emissions", "max_count":2, "filter":"source_wave"},
			{"op":"clear_owned_projectiles", "max_count":2, "travel_models":["linear"]},
		],
		"state_patch": {
			"wave_flags":{"orbit_interrupted":true},
			"timers":{"orbit_interrupt_seconds":1.25},
			"tags_add":["interrupt", "skirmisher_kill"],
		},
	},
	"pincer_hunter": {
		"collision_role": "flanker",
		"effect_id": "pincer_mark",
		"operations": [
			{"op":"mark_priority_target", "duration_seconds":2.20, "target_selector":"paired_survivor", "damage_multiplier":1.20},
			{"op":"cancel_pending_emissions", "max_count":1, "filter":"source_wave"},
		],
		"state_patch": {
			"wave_flags":{"pincer_side_broken":true},
			"timers":{"priority_mark_seconds":2.20},
			"tags_add":["marked_target", "flanker_kill"],
		},
	},
	"armor_drone": {
		"collision_role": "cover",
		"effect_id": "bone_cover",
		"operations": [
			{"op":"spawn_timed_cover", "duration_seconds":2.60, "radius_pixels":50.0, "absorb_count":6, "material":"bone"},
		],
		"state_patch": {
			"wave_flags":{"cover_created":true},
			"timers":{"cover_seconds":2.60},
			"tags_add":["cover", "armor_kill"],
		},
	},
	"tracker_mite": {
		"collision_role": "pursuer",
		"effect_id": "tracking_break",
		"operations": [
			{"op":"disable_tracking", "duration_seconds":2.10, "target_scope":"owned_wave"},
		],
		"state_patch": {
			"wave_flags":{"tracking_disabled":true},
			"timers":{"tracking_disabled_seconds":2.10},
			"tags_add":["tracking_break", "pursuer_kill"],
		},
	},
	"prism_guard": {
		"collision_role": "cover",
		"effect_id": "prism_cover",
		"operations": [
			{"op":"spawn_timed_cover", "duration_seconds":1.90, "radius_pixels":42.0, "absorb_count":4, "material":"prism"},
			{"op":"clear_owned_projectiles", "max_count":2, "travel_models":["linear"]},
		],
		"state_patch": {
			"wave_flags":{"prism_cover_created":true},
			"timers":{"prism_cover_seconds":1.90},
			"tags_add":["cover", "prism_kill"],
		},
	},
	"resonance_mouth": {
		"collision_role": "emitter",
		"effect_id": "emitter_silence",
		"operations": [
			{"op":"cancel_pending_emissions", "max_count":32, "filter":"source_wave"},
			{"op":"clear_owned_projectiles", "max_count":6, "travel_models":["expanding"]},
		],
		"state_patch": {
			"wave_flags":{"emitter_silenced":true},
			"timers":{"emitter_silenced_seconds":1.80},
			"tags_add":["silence", "emitter_kill"],
		},
	},
	"arc_linker": {
		"collision_role": "link_node",
		"effect_id": "link_break",
		"operations": [
			{"op":"break_link", "duration_seconds":2.50, "link_selector":"source_wave_chain"},
			{"op":"clear_owned_projectiles", "max_count":6, "travel_models":["node_link"]},
		],
		"state_patch": {
			"wave_flags":{"link_broken":true},
			"timers":{"link_broken_seconds":2.50},
			"tags_add":["link_break", "node_kill"],
		},
	},
	"hatchling": {
		"collision_role": "charger",
		"effect_id": "hatch_suppression",
		"operations": [
			{"op":"suppress_hatch", "duration_seconds":2.25, "spawn_selector":"source_wave_hatch"},
			{"op":"cancel_pending_emissions", "max_count":3, "filter":"source_wave"},
		],
		"state_patch": {
			"wave_flags":{"hatch_suppressed":true},
			"timers":{"hatch_suppressed_seconds":2.25},
			"tags_add":["spawn_suppression", "charger_kill"],
		},
	},
	"echo_clone": {
		"collision_role": "mirror",
		"effect_id": "echo_disruption",
		"operations": [
			{"op":"disrupt_echo", "duration_seconds":2.40, "target_scope":"source_wave"},
			{"op":"cancel_pending_emissions", "max_count":6, "filter":"source_wave"},
			{"op":"clear_owned_projectiles", "max_count":8, "travel_models":["recorded_path", "delayed_linear"]},
		],
		"state_patch": {
			"wave_flags":{"echo_disrupted":true},
			"timers":{"echo_disrupted_seconds":2.40},
			"tags_add":["echo_disruption", "mirror_kill"],
		},
	},
	"decoy_core": {
		"collision_role": "false_target",
		"effect_id": "decoy_reveal",
		"operations": [
			{"op":"reveal_true_target", "duration_seconds":3.00, "target_selector":"true_wave_target", "damage_multiplier":1.15},
			{"op":"remove_false_targets", "max_count":4, "target_scope":"source_wave"},
		],
		"state_patch": {
			"wave_flags":{"true_target_revealed":true},
			"timers":{"true_target_revealed_seconds":3.00},
			"tags_add":["reveal", "false_target_kill"],
		},
	},
}

## Unknown future archetypes can still fail safely into their declared role.
## These profiles intentionally remain weaker than the authored variants.
const ROLE_FALLBACKS := {
	"skirmisher": {"effect_id":"role_interrupt", "operations":[{"op":"clear_owned_projectiles", "max_count":1, "travel_models":[]}]},
	"flanker": {"effect_id":"role_priority_mark", "operations":[{"op":"mark_priority_target", "duration_seconds":1.40, "target_selector":"nearest_same_wave", "damage_multiplier":1.10}]},
	"cover": {"effect_id":"role_cover", "operations":[{"op":"spawn_timed_cover", "duration_seconds":1.25, "radius_pixels":34.0, "absorb_count":2, "material":"tissue"}]},
	"pursuer": {"effect_id":"role_tracking_break", "operations":[{"op":"disable_tracking", "duration_seconds":1.25, "target_scope":"owned_wave"}]},
	"emitter": {"effect_id":"role_silence", "operations":[{"op":"cancel_pending_emissions", "max_count":2, "filter":"source_wave"}]},
	"link_node": {"effect_id":"role_link_break", "operations":[{"op":"break_link", "duration_seconds":1.40, "link_selector":"source_wave_chain"}]},
	"charger": {"effect_id":"role_spawn_suppression", "operations":[{"op":"suppress_hatch", "duration_seconds":1.20, "spawn_selector":"source_wave_hatch"}]},
	"mirror": {"effect_id":"role_echo_disruption", "operations":[{"op":"disrupt_echo", "duration_seconds":1.30, "target_scope":"source_wave"}]},
	"false_target": {"effect_id":"role_reveal", "operations":[{"op":"reveal_true_target", "duration_seconds":1.60, "target_selector":"true_wave_target", "damage_multiplier":1.05}]},
}


## Required defender keys: id, archetype, collision_role, parent_wave (or
## contract_group), and position. Optional context keys: kill_sequence,
## duration_multiplier, remaining_defender_ids, true_target_id, and link_id.
##
## Executors must deduplicate effect_event_id before applying operations, apply
## every operation only to owner_wave_id, then merge state_patch using its
## max_timers_union_tags policy. Invalid input always returns zero operations.
static func compile_kill_effect(defender: Dictionary, context: Dictionary = {}) -> Dictionary:
	var errors := PackedStringArray()
	var defender_id := String(defender.get("id", "")).strip_edges()
	var archetype := String(defender.get("archetype", "")).strip_edges()
	var role := String(defender.get("collision_role", "")).strip_edges()
	var owner_wave_id := String(defender.get("parent_wave", defender.get("contract_group", ""))).strip_edges()
	if defender_id.is_empty():
		errors.append("Defender kill effect requires a source defender id")
	if archetype.is_empty():
		errors.append("Defender kill effect requires an archetype")
	if owner_wave_id.is_empty():
		errors.append("Defender kill effect requires a non-empty owning wave")
	var position_result := _serialized_position(defender.get("position", null))
	if not bool(position_result.get("valid", false)):
		errors.append("Defender kill effect requires a finite two-dimensional position")
	var profile: Dictionary = {}
	var used_role_fallback := false
	if ARCHETYPE_PROFILES.has(archetype):
		profile = (ARCHETYPE_PROFILES[archetype] as Dictionary).duplicate(true)
		var expected_role := String(profile.get("collision_role", ""))
		if role.is_empty():
			role = expected_role
		elif role != expected_role:
			errors.append("Archetype %s requires collision role %s, received %s" % [archetype, expected_role, role])
	elif ROLE_FALLBACKS.has(role):
		profile = (ROLE_FALLBACKS[role] as Dictionary).duplicate(true)
		used_role_fallback = true
	else:
		errors.append("Unsupported defender archetype/role: %s/%s" % [archetype, role])
	if not errors.is_empty():
		return _rejected_effect(defender_id, archetype, role, owner_wave_id, errors)

	var duration_multiplier := clampf(float(context.get("duration_multiplier", 1.0)), 0.5, 2.0)
	var remaining_ids := _sorted_unique_strings(context.get("remaining_defender_ids", []))
	remaining_ids.erase(defender_id)
	var effect_id := String(profile.get("effect_id", "role_effect"))
	var stable_source := "%d|%s|%s|%s|%s|%d" % [
		EFFECT_VERSION,
		owner_wave_id,
		defender_id,
		archetype,
		effect_id,
		int(context.get("kill_sequence", 0)),
	]
	var event_id := "defender-effect:%s" % stable_source.sha256_text().left(20)
	var position := position_result.get("position", [0.0, 0.0]) as Array
	var operations: Array[Dictionary] = []
	for raw_template in profile.get("operations", []) as Array:
		var operation := (raw_template as Dictionary).duplicate(true)
		operation["owner_wave_id"] = owner_wave_id
		operation["source_defender_id"] = defender_id
		operation["source_archetype"] = archetype
		operation["effect_event_id"] = event_id
		operation["coordinate_space"] = COORDINATE_SPACE
		operation["position"] = position.duplicate()
		if operation.has("duration_seconds"):
			operation["duration_seconds"] = _bounded_duration(float(operation.duration_seconds) * duration_multiplier)
		if operation.has("radius_pixels"):
			operation["radius_pixels"] = clampf(float(operation.radius_pixels), 8.0, MAX_COVER_RADIUS_PIXELS)
		if operation.has("max_count"):
			var operation_limit := MAX_PENDING_CANCEL_COUNT if String(operation.op) == "cancel_pending_emissions" else MAX_PROJECTILE_CLEAR_COUNT
			operation["max_count"] = clampi(int(operation.max_count), 0, operation_limit)
		if String(operation.op) == "mark_priority_target":
			operation["candidate_ids"] = remaining_ids.duplicate()
		if String(operation.op) == "break_link":
			operation["link_id"] = String(context.get("link_id", owner_wave_id))
		if String(operation.op) == "reveal_true_target":
			operation["true_target_id"] = String(context.get("true_target_id", ""))
		operations.append(operation)

	var state_patch := _scaled_state_patch(profile.get("state_patch", {}) as Dictionary, duration_multiplier)
	state_patch["merge_policy"] = "max_timers_union_tags"
	state_patch["source_defender_removed"] = defender_id
	state_patch["kill_effects_applied_add"] = 1
	state_patch["remaining_defender_ids"] = remaining_ids.duplicate()
	var result := {
		"valid": true,
		"version": EFFECT_VERSION,
		"effect_id": effect_id,
		"effect_event_id": event_id,
		"source_defender_id": defender_id,
		"source_archetype": archetype,
		"collision_role": role,
		"owner_wave_id": owner_wave_id,
		"used_role_fallback": used_role_fallback,
		"operations": operations,
		"state_patch": state_patch,
		"errors": PackedStringArray(),
	}
	result["signature"] = _result_signature(result)
	var result_errors := validate_result(result)
	if not result_errors.is_empty():
		return _rejected_effect(defender_id, archetype, role, owner_wave_id, result_errors)
	return result


static func validate_registry(runtime_archetypes: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	if ARCHETYPE_PROFILES.size() != EXPECTED_ARCHETYPE_ROLES.size():
		errors.append("Defender effect registry must contain exactly ten launch archetypes")
	var effect_ids: Dictionary = {}
	for raw_archetype in EXPECTED_ARCHETYPE_ROLES.keys():
		var archetype := String(raw_archetype)
		if not ARCHETYPE_PROFILES.has(archetype):
			errors.append("Missing defender effect profile: %s" % archetype)
			continue
		var profile := ARCHETYPE_PROFILES[archetype] as Dictionary
		var expected_role := String(EXPECTED_ARCHETYPE_ROLES[archetype])
		if String(profile.get("collision_role", "")) != expected_role:
			errors.append("Defender effect role mismatch: %s" % archetype)
		if not ROLE_FALLBACKS.has(expected_role):
			errors.append("Missing collision-role fallback: %s" % expected_role)
		var effect_id := String(profile.get("effect_id", ""))
		if effect_id.is_empty() or effect_ids.has(effect_id):
			errors.append("Defender effect ids must be non-empty and unique: %s" % archetype)
		effect_ids[effect_id] = true
		_validate_operation_templates(profile.get("operations", []) as Array, archetype, errors)
	if not runtime_archetypes.is_empty():
		if runtime_archetypes.size() != EXPECTED_ARCHETYPE_ROLES.size():
			errors.append("Runtime/effect defender archetype counts differ")
		for raw_archetype in runtime_archetypes.keys():
			var archetype := String(raw_archetype)
			if not EXPECTED_ARCHETYPE_ROLES.has(archetype):
				errors.append("Runtime archetype has no kill effect: %s" % archetype)
				continue
			var behavior := runtime_archetypes[raw_archetype] as Dictionary
			if String(behavior.get("collision_role", "")) != String(EXPECTED_ARCHETYPE_ROLES[archetype]):
				errors.append("Runtime/effect collision role differs: %s" % archetype)
	for raw_role in ROLE_FALLBACKS.keys():
		_validate_operation_templates((ROLE_FALLBACKS[raw_role] as Dictionary).get("operations", []) as Array, "role:%s" % String(raw_role), errors)
	return errors


static func validate_result(result: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not bool(result.get("valid", false)):
		errors.append("Kill-effect result is marked invalid")
		return errors
	var owner_wave_id := String(result.get("owner_wave_id", ""))
	var defender_id := String(result.get("source_defender_id", ""))
	var event_id := String(result.get("effect_event_id", ""))
	if owner_wave_id.is_empty() or defender_id.is_empty() or event_id.is_empty():
		errors.append("Kill-effect result lost source attribution")
	var operations := result.get("operations", []) as Array
	if operations.is_empty():
		errors.append("Kill-effect result contains no executable operation")
	for raw_operation in operations:
		var operation := raw_operation as Dictionary
		if String(operation.get("op", "")) not in OPERATION_IDS:
			errors.append("Kill-effect result contains an unsupported operation")
			break
		if String(operation.get("owner_wave_id", "")) != owner_wave_id or String(operation.get("source_defender_id", "")) != defender_id or String(operation.get("effect_event_id", "")) != event_id:
			errors.append("Kill-effect operation escaped its owning wave/source")
			break
		var position := operation.get("position", []) as Array
		if position.size() != 2 or String(operation.get("coordinate_space", "")) != COORDINATE_SPACE:
			errors.append("Kill-effect operation lost its coordinate contract")
			break
		if not _is_finite_number(position[0]) or not _is_finite_number(position[1]):
			errors.append("Kill-effect operation position must contain finite numbers")
			break
		if operation.has("duration_seconds"):
			var duration_value: Variant = operation.duration_seconds
			if not _is_finite_number(duration_value) or float(duration_value) <= 0.0 or float(duration_value) > MAX_DURATION_SECONDS:
				errors.append("Kill-effect operation duration is non-finite or unbounded")
				break
		if operation.has("max_count"):
			var max_count_limit := MAX_PENDING_CANCEL_COUNT if String(operation.op) == "cancel_pending_emissions" else MAX_PROJECTILE_CLEAR_COUNT
			var max_count_value: Variant = operation.max_count
			if typeof(max_count_value) != TYPE_INT or not _is_finite_number(max_count_value) or int(max_count_value) < 0 or int(max_count_value) > max_count_limit:
				errors.append("Kill-effect operation count is non-integral, non-finite, or unbounded")
				break
		if operation.has("damage_multiplier"):
			var damage_multiplier_value: Variant = operation.damage_multiplier
			if not _is_finite_number(damage_multiplier_value) or float(damage_multiplier_value) <= 0.0:
				errors.append("Kill-effect damage multiplier must be finite and positive")
				break
		if String(operation.op) == "spawn_timed_cover":
			var radius_value: Variant = operation.get("radius_pixels", 0.0)
			if not _is_finite_number(radius_value) or float(radius_value) <= 0.0 or float(radius_value) > MAX_COVER_RADIUS_PIXELS:
				errors.append("Timed cover radius is non-finite or unbounded")
				break
			var absorption_value: Variant = operation.get("absorb_count", 0)
			if typeof(absorption_value) != TYPE_INT or not _is_finite_number(absorption_value) or int(absorption_value) <= 0 or int(absorption_value) > MAX_PROJECTILE_CLEAR_COUNT:
				errors.append("Timed cover absorption count is non-integral, non-finite, or unbounded")
				break
	var state_patch := result.get("state_patch", {}) as Dictionary
	if state_patch.is_empty():
		errors.append("Kill-effect result contains no deterministic state patch")
	else:
		if _contains_nonfinite_number(state_patch):
			errors.append("Kill-effect state patch contains a non-finite numeric value")
		for raw_timer in (state_patch.get("timers", {}) as Dictionary).values():
			if not _is_finite_number(raw_timer) or float(raw_timer) <= 0.0 or float(raw_timer) > MAX_DURATION_SECONDS:
				errors.append("Kill-effect state timer is non-finite or unbounded")
				break
		var applied_add: Variant = state_patch.get("kill_effects_applied_add",null)
		if typeof(applied_add) != TYPE_INT or int(applied_add) != 1:
			errors.append("Kill-effect state application count must be exactly one integer")
		for raw_flag in (state_patch.get("wave_flags",{}) as Dictionary).values():
			if typeof(raw_flag) != TYPE_BOOL or not bool(raw_flag):
				errors.append("Kill-effect state flags must be explicit true booleans")
				break
	var published_signature := String(result.get("signature", ""))
	if published_signature.is_empty():
		errors.append("Kill-effect result contains no deterministic signature")
	elif published_signature != _result_signature(result):
		errors.append("Kill-effect result signature does not match its canonical payload")
	return errors


static func supported_archetypes() -> PackedStringArray:
	var result := PackedStringArray()
	for archetype in ARCHETYPE_PROFILES.keys():
		result.append(String(archetype))
	result.sort()
	return result


static func supported_collision_roles() -> PackedStringArray:
	var result := PackedStringArray()
	for role in ROLE_FALLBACKS.keys():
		result.append(String(role))
	result.sort()
	return result


static func _validate_operation_templates(templates: Array, source: String, errors: PackedStringArray) -> void:
	if templates.is_empty():
		errors.append("Defender effect profile has no operations: %s" % source)
		return
	for raw_template in templates:
		var template := raw_template as Dictionary
		if String(template.get("op", "")) not in OPERATION_IDS:
			errors.append("Defender effect profile uses an unsupported operation: %s" % source)


static func _scaled_state_patch(template: Dictionary, duration_multiplier: float) -> Dictionary:
	var patch := template.duplicate(true)
	var timers := patch.get("timers", {}) as Dictionary
	for raw_key in timers.keys():
		timers[raw_key] = _bounded_duration(float(timers[raw_key]) * duration_multiplier)
	patch["timers"] = timers
	var tags := _sorted_unique_strings(patch.get("tags_add", []))
	patch["tags_add"] = tags
	return patch


static func _serialized_position(raw_position: Variant) -> Dictionary:
	var x := 0.0
	var y := 0.0
	if typeof(raw_position) == TYPE_VECTOR2:
		x = float((raw_position as Vector2).x)
		y = float((raw_position as Vector2).y)
	elif typeof(raw_position) == TYPE_ARRAY and (raw_position as Array).size() == 2:
		x = float((raw_position as Array)[0])
		y = float((raw_position as Array)[1])
	else:
		return {"valid":false, "position":[]}
	# Reject NaN and infinities without allowing them into signatures/replays.
	if is_nan(x) or is_nan(y) or is_inf(x) or is_inf(y):
		return {"valid":false, "position":[]}
	return {"valid":true, "position":[snappedf(x, 0.001), snappedf(y, 0.001)]}


static func _sorted_unique_strings(raw_values: Variant) -> Array[String]:
	var seen: Dictionary = {}
	if typeof(raw_values) == TYPE_ARRAY or typeof(raw_values) == TYPE_PACKED_STRING_ARRAY:
		for raw_value in raw_values:
			var value := String(raw_value).strip_edges()
			if not value.is_empty():
				seen[value] = true
	var result: Array[String] = []
	for raw_key in seen.keys():
		result.append(String(raw_key))
	result.sort()
	return result


static func _bounded_duration(value: float) -> float:
	return snappedf(clampf(value, 0.05, MAX_DURATION_SECONDS), 0.001)


static func _is_finite_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return not is_nan(numeric_value) and not is_inf(numeric_value)


static func _contains_nonfinite_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return is_nan(float(value)) or is_inf(float(value))
		TYPE_DICTIONARY:
			for nested_value in (value as Dictionary).values():
				if _contains_nonfinite_number(nested_value):
					return true
		TYPE_ARRAY:
			for nested_value in value as Array:
				if _contains_nonfinite_number(nested_value):
					return true
	return false


static func _result_signature(result: Dictionary) -> String:
	var signed_payload := {
		"version":int(result.get("version",EFFECT_VERSION)),
		"effect_id":String(result.get("effect_id","")),
		"effect_event_id":String(result.get("effect_event_id","")),
		"source_defender_id":String(result.get("source_defender_id","")),
		"source_archetype":String(result.get("source_archetype","")),
		"collision_role":String(result.get("collision_role","")),
		"owner_wave_id":String(result.get("owner_wave_id","")),
		"used_role_fallback":bool(result.get("used_role_fallback",false)),
		"operations":result.get("operations",[]),
		"state_patch":result.get("state_patch",{}),
	}
	var source := _canonical_json(signed_payload)
	return "defender-effect-v%d:%s" % [EFFECT_VERSION, source.sha256_text().left(24)]


static func _canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary := value as Dictionary
			var keys: Array[String] = []
			for raw_key in dictionary.keys():
				keys.append(String(raw_key))
			keys.sort()
			var dictionary_parts := PackedStringArray()
			for key in keys:
				dictionary_parts.append("%s:%s" % [JSON.stringify(key),_canonical_json(dictionary[key])])
			return "{%s}" % ",".join(dictionary_parts)
		TYPE_ARRAY:
			var array_parts := PackedStringArray()
			for item in value as Array:
				array_parts.append(_canonical_json(item))
			return "[%s]" % ",".join(array_parts)
		TYPE_PACKED_STRING_ARRAY:
			var packed_parts := PackedStringArray()
			for item in value as PackedStringArray:
				packed_parts.append(JSON.stringify(String(item)))
			return "[%s]" % ",".join(packed_parts)
		TYPE_FLOAT:
			var numeric_value := float(value)
			if is_nan(numeric_value):
				return JSON.stringify("<nan>")
			if is_inf(numeric_value):
				return JSON.stringify("<+inf>" if numeric_value > 0.0 else "<-inf>")
			return JSON.stringify(numeric_value)
		_:
			return JSON.stringify(value)


static func _rejected_effect(defender_id: String, archetype: String, role: String, owner_wave_id: String, errors: PackedStringArray) -> Dictionary:
	return {
		"valid": false,
		"version": EFFECT_VERSION,
		"effect_id": "none",
		"effect_event_id": "",
		"source_defender_id": defender_id,
		"source_archetype": archetype,
		"collision_role": role,
		"owner_wave_id": owner_wave_id,
		"used_role_fallback": false,
		"operations": [],
		"state_patch": {},
		"signature": "",
		"errors": errors.duplicate(),
	}
