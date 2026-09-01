extends Node

const Effects := preload("res://scripts/core/room_defender_effects.gd")
const Runtime := preload("res://scripts/core/room_pattern_runtime.gd")

const REQUIRED_OPERATION_BY_ARCHETYPE := {
	"orbit_sentinel": "clear_owned_projectiles",
	"pincer_hunter": "mark_priority_target",
	"armor_drone": "spawn_timed_cover",
	"tracker_mite": "disable_tracking",
	"prism_guard": "spawn_timed_cover",
	"resonance_mouth": "cancel_pending_emissions",
	"arc_linker": "break_link",
	"hatchling": "suppress_hatch",
	"echo_clone": "disrupt_echo",
	"decoy_core": "reveal_true_target",
}

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("ROOM DEFENDER EFFECT TEST FAILURE: " + message)


func _run() -> void:
	await get_tree().process_frame
	_test_registry_matches_runtime()
	_test_every_authored_effect()
	_test_semantic_operation_coverage()
	_test_determinism_and_input_immutability()
	_test_role_fallbacks()
	_test_fail_closed_contract()
	_test_bounds_and_scaling()
	_test_tampered_results_rejected()
	print("INFINIDIVE ROOM DEFENDER EFFECT TESTS: %d passed, %d failed" % [passed, failures.size()])
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_registry_matches_runtime() -> void:
	_check(Effects.validate_registry(Runtime.DEFENDER_ARCHETYPES).is_empty(), "Effect registry must exactly match the live runtime defender registry")
	_check(Effects.supported_archetypes().size() == 10, "Exactly ten launch defender archetypes need authored kill effects")
	_check(Effects.supported_collision_roles().size() == 9, "The ten defenders must cover their nine distinct collision roles")
	_check(_same_strings(Effects.supported_archetypes(), _dictionary_keys(Runtime.DEFENDER_ARCHETYPES)), "No runtime defender may lack a kill-effect profile")
	for raw_archetype in Runtime.DEFENDER_ARCHETYPES.keys():
		var archetype := String(raw_archetype)
		var runtime_role := String((Runtime.DEFENDER_ARCHETYPES[raw_archetype] as Dictionary).get("collision_role", ""))
		_check(String(Effects.EXPECTED_ARCHETYPE_ROLES.get(archetype, "")) == runtime_role, "%s effect role must equal its runtime collision role" % archetype)


func _test_every_authored_effect() -> void:
	var effect_ids: Dictionary = {}
	var event_ids: Dictionary = {}
	for index in range(Effects.supported_archetypes().size()):
		var archetype := String(Effects.supported_archetypes()[index])
		var role := String(Effects.EXPECTED_ARCHETYPE_ROLES[archetype])
		var defender := _defender(archetype, role, index)
		var context := _context(index)
		var result := Effects.compile_kill_effect(defender, context)
		_check(bool(result.get("valid", false)), "%s must compile a valid kill effect: %s" % [archetype, result.get("errors", [])])
		if not bool(result.get("valid", false)):
			continue
		_check(Effects.validate_result(result).is_empty(), "%s compiled result must independently validate" % archetype)
		_check(not bool(result.get("used_role_fallback", true)), "%s must use its authored profile, not a role fallback" % archetype)
		_check(String(result.get("owner_wave_id", "")) == "room:test:0:%d" % index, "%s operations must remain scoped to their source wave" % archetype)
		_check(String(result.get("source_defender_id", "")) == "defender_%d" % index, "%s result must retain the killed defender id" % archetype)
		_check(String(result.get("signature", "")).begins_with("defender-effect-v1:"), "%s result must expose a versioned deterministic signature" % archetype)
		_check(not effect_ids.has(String(result.effect_id)), "%s must retain a distinct authored effect id" % archetype)
		effect_ids[String(result.effect_id)] = true
		_check(not event_ids.has(String(result.effect_event_id)), "%s kill event id must be unique to its source" % archetype)
		event_ids[String(result.effect_event_id)] = true
		var operations := result.operations as Array
		_check(not operations.is_empty(), "%s must emit at least one executable operation" % archetype)
		_check(_operation_names(operations).has(String(REQUIRED_OPERATION_BY_ARCHETYPE[archetype])), "%s must expose its defining gameplay operation" % archetype)
		for raw_operation in operations:
			var operation := raw_operation as Dictionary
			_check(String(operation.get("owner_wave_id", "")) == String(result.owner_wave_id), "%s operation cannot escape the source wave" % archetype)
			_check(String(operation.get("source_defender_id", "")) == String(result.source_defender_id), "%s operation must retain source attribution" % archetype)
			_check(String(operation.get("effect_event_id", "")) == String(result.effect_event_id), "%s operation must share the idempotency event id" % archetype)
			_check(String(operation.get("coordinate_space", "")) == Effects.COORDINATE_SPACE, "%s operation must publish its coordinate space" % archetype)
			_check((operation.get("position", []) as Array).size() == 2, "%s operation must use a serialized two-dimensional position" % archetype)
		var patch := result.state_patch as Dictionary
		_check(String(patch.get("merge_policy", "")) == "max_timers_union_tags", "%s state patch must declare deterministic merge behavior" % archetype)
		_check(int(patch.get("kill_effects_applied_add", 0)) == 1, "%s state patch must count exactly one applied kill effect" % archetype)
		_check(String(patch.get("source_defender_removed", "")) == String(result.source_defender_id), "%s state patch must identify the removed defender" % archetype)
	_check(effect_ids.size() == 10, "All ten launch archetypes must retain distinct kill-effect identities")
	_check(event_ids.size() == 10, "All ten representative kills must retain distinct idempotency ids")


func _test_semantic_operation_coverage() -> void:
	var operations_by_archetype: Dictionary = {}
	var all_operations: Dictionary = {}
	for index in range(Effects.supported_archetypes().size()):
		var archetype := String(Effects.supported_archetypes()[index])
		var role := String(Effects.EXPECTED_ARCHETYPE_ROLES[archetype])
		var result := Effects.compile_kill_effect(_defender(archetype, role, index), _context(index))
		var names := _operation_names(result.get("operations", []) as Array)
		operations_by_archetype[archetype] = names
		for operation in names:
			all_operations[String(operation)] = true
	_check("spawn_timed_cover" in operations_by_archetype.armor_drone and "spawn_timed_cover" in operations_by_archetype.prism_guard, "Armor and prism defenders must leave distinct timed cover")
	_check("cancel_pending_emissions" in operations_by_archetype.resonance_mouth, "Killing an emitter must cancel its pending volley")
	_check("clear_owned_projectiles" not in operations_by_archetype.tracker_mite, "Tracker plans must not clear non-homing projectiles merely because their travel model is soft_homing")
	_check("mark_priority_target" in operations_by_archetype.pincer_hunter, "Killing one pincer must mark the surviving side")
	_check("break_link" in operations_by_archetype.arc_linker, "Killing a link node must break the live chain")
	_check("suppress_hatch" in operations_by_archetype.hatchling, "Killing a hatchling must suppress its source hatch")
	_check("disrupt_echo" in operations_by_archetype.echo_clone, "Killing an echo clone must disrupt replay behavior")
	_check("reveal_true_target" in operations_by_archetype.decoy_core and "remove_false_targets" in operations_by_archetype.decoy_core, "Killing a decoy core must reveal truth and remove false targets")
	_check("disable_tracking" in operations_by_archetype.tracker_mite, "Tracker death must disable tracking rather than only award currency")
	_check(all_operations.size() == Effects.OPERATION_IDS.size(), "Launch profiles must exercise every supported defender-effect operation")


func _test_determinism_and_input_immutability() -> void:
	var defender := _defender("echo_clone", "mirror", 31)
	var context := {
		"kill_sequence": 7,
		"duration_multiplier": 1.25,
		"remaining_defender_ids": ["enemy_z", "enemy_a", "enemy_z", "defender_31"],
		"true_target_id": "organ",
		"link_id": "room:test:link",
	}
	var defender_snapshot := defender.duplicate(true)
	var context_snapshot := context.duplicate(true)
	var first := Effects.compile_kill_effect(defender, context)
	var second := Effects.compile_kill_effect(defender, context)
	_check(first == second, "Identical defender/context input must compile byte-for-byte equivalent plans")
	_check(defender == defender_snapshot and context == context_snapshot, "Pure effect compilation must not mutate source dictionaries")
	_check((first.state_patch as Dictionary).remaining_defender_ids == ["enemy_a", "enemy_z"], "Remaining defender ids must be sorted, unique, and exclude the killed source")
	var reordered := context.duplicate(true)
	reordered.remaining_defender_ids = ["enemy_a", "enemy_z"]
	var third := Effects.compile_kill_effect(defender, reordered)
	_check(String(first.signature) == String(third.signature), "Equivalent remaining-defender sets must produce the same signature")
	var next_kill := context.duplicate(true)
	next_kill.kill_sequence = 8
	var fourth := Effects.compile_kill_effect(defender, next_kill)
	_check(String(first.effect_event_id) != String(fourth.effect_event_id) and String(first.signature) != String(fourth.signature), "Kill sequence must produce a new idempotency id and signature")
	var rounded := Effects.compile_kill_effect({
		"id":"rounding_probe",
		"archetype":"armor_drone",
		"collision_role":"cover",
		"parent_wave":"room:test:rounding",
		"position":[123.45678, 654.32109],
	})
	var rounded_position := (((rounded.operations as Array)[0] as Dictionary).position as Array)
	_check(
		rounded_position.size() == 2
		and is_equal_approx(float(rounded_position[0]), 123.457)
		and is_equal_approx(float(rounded_position[1]), 654.321),
		"World positions must be serialized to stable millipixel precision"
	)


func _test_role_fallbacks() -> void:
	var fallback_signatures: Dictionary = {}
	for index in range(Effects.supported_collision_roles().size()):
		var role := String(Effects.supported_collision_roles()[index])
		var result := Effects.compile_kill_effect({
			"id":"future_%s" % role,
			"archetype":"future_%s" % role,
			"collision_role":role,
			"parent_wave":"room:future:0:%d" % index,
			"position":Vector2(90.0 + index * 11.0, 520.0),
		})
		_check(bool(result.get("valid", false)), "Known collision role %s must provide a bounded future-archetype fallback" % role)
		_check(bool(result.get("used_role_fallback", false)), "Unknown archetype %s must identify role-fallback use" % role)
		_check(Effects.validate_result(result).is_empty(), "Role fallback %s must independently validate" % role)
		fallback_signatures[String(result.signature)] = true
	_check(fallback_signatures.size() == Effects.supported_collision_roles().size(), "Each collision-role fallback must retain distinct behavior")


func _test_fail_closed_contract() -> void:
	var valid := _defender("armor_drone", "cover", 50)
	var cases := [
		{"name":"missing id", "value":_without(valid, "id")},
		{"name":"missing owner", "value":_without(_without(valid, "parent_wave"), "contract_group")},
		{"name":"missing position", "value":_without(valid, "position")},
		{"name":"mismatched role", "value":_with(valid, "collision_role", "mirror")},
		{"name":"unknown archetype and role", "value":_with(_with(valid, "archetype", "unknown"), "collision_role", "unknown")},
		{"name":"non-finite position", "value":_with(valid, "position", Vector2(NAN, 450.0))},
	]
	for raw_case in cases:
		var test_case := raw_case as Dictionary
		var result := Effects.compile_kill_effect(test_case.value as Dictionary)
		_check(not bool(result.get("valid", true)), "%s must fail closed" % String(test_case.name))
		_check((result.get("operations", []) as Array).is_empty(), "%s cannot emit an unscoped side effect" % String(test_case.name))
		_check((result.get("state_patch", {}) as Dictionary).is_empty(), "%s cannot mutate wave state" % String(test_case.name))
		_check(not (result.get("errors", PackedStringArray()) as PackedStringArray).is_empty(), "%s must explain its rejection" % String(test_case.name))


func _test_bounds_and_scaling() -> void:
	var high := Effects.compile_kill_effect(_defender("armor_drone", "cover", 70), {"duration_multiplier":1000.0})
	var low := Effects.compile_kill_effect(_defender("armor_drone", "cover", 71), {"duration_multiplier":-1000.0})
	var high_cover := (high.operations as Array)[0] as Dictionary
	var low_cover := (low.operations as Array)[0] as Dictionary
	_check(float(high_cover.duration_seconds) <= Effects.MAX_DURATION_SECONDS, "Extreme positive duration scale must remain bounded")
	_check(is_equal_approx(float(low_cover.duration_seconds), 1.30), "Extreme negative duration scale must clamp to the documented 0.5 multiplier")
	_check(float(high_cover.radius_pixels) <= Effects.MAX_COVER_RADIUS_PIXELS, "Cover radius must remain bounded")
	for archetype in Effects.supported_archetypes():
		var result := Effects.compile_kill_effect(_defender(archetype, String(Effects.EXPECTED_ARCHETYPE_ROLES[archetype]), 80 + archetype.hash() % 1000), {"duration_multiplier":2.0})
		for raw_operation in result.operations as Array:
			var operation := raw_operation as Dictionary
			if operation.has("duration_seconds"):
				_check(float(operation.duration_seconds) > 0.0 and float(operation.duration_seconds) <= Effects.MAX_DURATION_SECONDS, "%s duration must remain positive and capped" % archetype)
			if operation.has("max_count"):
				var limit := Effects.MAX_PENDING_CANCEL_COUNT if String(operation.op) == "cancel_pending_emissions" else Effects.MAX_PROJECTILE_CLEAR_COUNT
				_check(int(operation.max_count) >= 0 and int(operation.max_count) <= limit, "%s clear/cancel count must remain bounded" % archetype)


func _test_tampered_results_rejected() -> void:
	var source := Effects.compile_kill_effect(_defender("armor_drone", "cover", 99))
	var reordered := source.duplicate(true)
	(reordered.operations as Array)[0] = _dictionary_with_reversed_key_order((reordered.operations[0] as Dictionary))
	reordered.state_patch = _dictionary_with_reversed_key_order(reordered.state_patch as Dictionary)
	_check(Effects.validate_result(reordered).is_empty(), "Canonical validation must ignore dictionary insertion order")
	_check(String(reordered.signature)==String(source.signature), "Equivalent key ordering must retain a stable deterministic signature")
	var reordered_operations := Effects.compile_kill_effect(_defender("prism_guard", "cover", 100))
	(reordered_operations.operations as Array).reverse()
	_check(not Effects.validate_result(reordered_operations).is_empty(), "Canonical validation must detect semantic operation ordering changes")
	var escaped_owner := source.duplicate(true)
	(escaped_owner.operations[0] as Dictionary).owner_wave_id = "room:other:wave"
	_check(not Effects.validate_result(escaped_owner).is_empty(), "Validation must reject an operation re-scoped to another wave")
	var coherent_owner_tamper := source.duplicate(true)
	coherent_owner_tamper.owner_wave_id = "room:other:wave"
	for raw_operation in coherent_owner_tamper.operations as Array:
		(raw_operation as Dictionary).owner_wave_id = "room:other:wave"
	_check(not Effects.validate_result(coherent_owner_tamper).is_empty(), "Signature validation must reject a coherently tampered owner")
	var unknown_operation := source.duplicate(true)
	(unknown_operation.operations[0] as Dictionary).op = "erase_everything"
	_check(not Effects.validate_result(unknown_operation).is_empty(), "Validation must reject unknown executor operations")
	var infinite_duration := source.duplicate(true)
	(infinite_duration.operations[0] as Dictionary).duration_seconds = 999.0
	_check(not Effects.validate_result(infinite_duration).is_empty(), "Validation must reject an unbounded cover duration")
	var infinite_radius := source.duplicate(true)
	(infinite_radius.operations[0] as Dictionary).radius_pixels = 999.0
	_check(not Effects.validate_result(infinite_radius).is_empty(), "Validation must reject an unbounded cover radius")
	var infinite_absorption := source.duplicate(true)
	(infinite_absorption.operations[0] as Dictionary).absorb_count = 999
	_check(not Effects.validate_result(infinite_absorption).is_empty(), "Validation must reject unbounded cover absorption")
	var infinite_timer := source.duplicate(true)
	(infinite_timer.state_patch as Dictionary).timers.cover_seconds = 999.0
	_check(not Effects.validate_result(infinite_timer).is_empty(), "Validation must reject an unbounded state timer")
	var semantic_radius := source.duplicate(true)
	(semantic_radius.operations[0] as Dictionary).radius_pixels = float((semantic_radius.operations[0] as Dictionary).radius_pixels)-1.0
	_check(not Effects.validate_result(semantic_radius).is_empty(), "Signature validation must reject an in-bounds cover-radius tamper")
	var semantic_duration := source.duplicate(true)
	(semantic_duration.operations[0] as Dictionary).duration_seconds = float((semantic_duration.operations[0] as Dictionary).duration_seconds)-0.1
	_check(not Effects.validate_result(semantic_duration).is_empty(), "Signature validation must reject an in-bounds cover-duration tamper")
	var semantic_flag := source.duplicate(true)
	(semantic_flag.state_patch as Dictionary).wave_flags.cover_created = false
	_check(not Effects.validate_result(semantic_flag).is_empty(), "Signature validation must reject an owner-state flag tamper")
	var forged_signature := source.duplicate(true)
	forged_signature.signature = "defender-effect-v1:000000000000000000000000"
	_check(not Effects.validate_result(forged_signature).is_empty(), "Validation must reject a nonempty but noncanonical signature")
	var nan_duration := source.duplicate(true)
	(nan_duration.operations[0] as Dictionary).duration_seconds = NAN
	_resign(nan_duration)
	_check(not Effects.validate_result(nan_duration).is_empty(), "Finite validation must reject NaN operation duration even with a recomputed signature")
	var infinite_radius_value := source.duplicate(true)
	(infinite_radius_value.operations[0] as Dictionary).radius_pixels = INF
	_resign(infinite_radius_value)
	_check(not Effects.validate_result(infinite_radius_value).is_empty(), "Finite validation must reject infinite cover radius even with a recomputed signature")
	var nan_absorption := source.duplicate(true)
	(nan_absorption.operations[0] as Dictionary).absorb_count = NAN
	_resign(nan_absorption)
	_check(not Effects.validate_result(nan_absorption).is_empty(), "Finite validation must reject NaN cover absorption count")
	var nan_position := source.duplicate(true)
	(nan_position.operations[0] as Dictionary).position = [NAN,520.0]
	_resign(nan_position)
	_check(not Effects.validate_result(nan_position).is_empty(), "Finite validation must reject NaN serialized positions")
	var infinite_position := source.duplicate(true)
	(infinite_position.operations[0] as Dictionary).position = [120.0,-INF]
	_resign(infinite_position)
	_check(not Effects.validate_result(infinite_position).is_empty(), "Finite validation must reject infinite serialized positions")
	var nan_timer := source.duplicate(true)
	(nan_timer.state_patch as Dictionary).timers.cover_seconds = NAN
	_resign(nan_timer)
	_check(not Effects.validate_result(nan_timer).is_empty(), "Finite validation must reject NaN state timers")
	var infinite_state_value := source.duplicate(true)
	(infinite_state_value.state_patch as Dictionary).values = {"future_multiplier":INF}
	_resign(infinite_state_value)
	_check(not Effects.validate_result(infinite_state_value).is_empty(), "Finite validation must reject infinite future state values")
	var count_source := Effects.compile_kill_effect(_defender("orbit_sentinel","skirmisher",101))
	(count_source.operations[0] as Dictionary).max_count = NAN
	_resign(count_source)
	_check(not Effects.validate_result(count_source).is_empty(), "Finite validation must reject NaN pending/projectile counts")
	var damage_source := Effects.compile_kill_effect(_defender("pincer_hunter","flanker",102),{"remaining_defender_ids":["survivor"]})
	(damage_source.operations[0] as Dictionary).damage_multiplier = INF
	_resign(damage_source)
	_check(not Effects.validate_result(damage_source).is_empty(), "Finite validation must reject infinite damage values")


func _defender(archetype: String, role: String, index: int) -> Dictionary:
	return {
		"id":"defender_%d" % index,
		"archetype":archetype,
		"collision_role":role,
		"contract_group":"room:test:0:%d" % index,
		"parent_wave":"room:test:0:%d" % index,
		"position":Vector2(100.0 + index * 7.0, 510.0 + index * 3.0),
	}


func _context(index: int) -> Dictionary:
	return {
		"kill_sequence":index,
		"duration_multiplier":1.0,
		"remaining_defender_ids":["survivor_b", "survivor_a", "survivor_b"],
		"true_target_id":"organ",
		"link_id":"room:test:link:%d" % index,
	}


func _operation_names(operations: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_operation in operations:
		result.append(String((raw_operation as Dictionary).get("op", "")))
	return result


func _dictionary_keys(values: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for key in values.keys():
		result.append(String(key))
	result.sort()
	return result


func _same_strings(first: PackedStringArray, second: PackedStringArray) -> bool:
	var left := first.duplicate()
	var right := second.duplicate()
	left.sort()
	right.sort()
	return left == right


func _without(source: Dictionary, key: String) -> Dictionary:
	var result := source.duplicate(true)
	result.erase(key)
	return result


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[key] = value
	return result


func _dictionary_with_reversed_key_order(source: Dictionary) -> Dictionary:
	var keys := source.keys()
	keys.reverse()
	var result: Dictionary = {}
	for raw_key in keys:
		result[raw_key]=source[raw_key]
	return result


func _resign(result: Dictionary) -> void:
	result.signature=Effects._result_signature(result)
