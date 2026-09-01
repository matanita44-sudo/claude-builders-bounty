class_name MutationEngine
extends RefCounted

## Mutation effects use an explicit contract. Suffixes are deliberately not
## interpreted: several contextual effects end in `_mul` but must remain flags
## for RunScene to evaluate only while their condition is true.
const EFFECT_OPERATIONS := {
	"projectile_count_add": "add",
	"pierce_add": "add",
	"orbitals_add": "add",
	"max_health_add": "add",
	"dash_charges_add": "add",
	"damage_mul": "multiply",
	"armor_damage_mul": "multiply",
	"organ_damage_mul": "multiply",
	"external_damage_mul": "multiply",
	"projectile_speed_mul": "multiply",
	"dash_cooldown_mul": "multiply",
	"max_health_mul": "multiply",
	"magnet_mul": "multiply",
	"breach_reward_mul": "multiply",
	"dash_trail": "flag_bool",
	"dash_trail_damage": "flag_number",
	"dash_trail_duration": "flag_number",
	"orbit_absorb": "flag_bool",
	"orbit_growth_per_absorb": "flag_number",
	"orbit_growth_cap": "flag_number",
	"orbital_damage_mul": "flag_number",
	"low_health_rate_mul": "flag_number",
	"internal_kill_heal": "flag_number",
	"heal_every_kills": "flag_number",
	"damage_per_organ": "flag_number",
	"echo_every": "flag_number",
	"breach_fury_seconds": "flag_number",
	"breach_rate_mul": "flag_number",
	"shield_after_organ": "flag_number",
	"homing_strength": "flag_number",
	"heal_now": "flag_number",
	"tear_every": "flag_number",
	"tear_damage": "flag_number",
	"breach_window_damage_mul": "flag_number",
	"breach_window_seconds": "flag_number",
	"shield_every_bio": "flag_number",
	"close_damage_mul": "flag_number",
	"close_damage_range": "flag_number",
	"calm_heal_seconds": "flag_number",
	"calm_heal": "flag_number",
	"streak_damage_step": "flag_number",
	"streak_damage_cap": "flag_number"
}

const ALLOWED_RARITIES := ["common", "uncommon", "rare"]

var selected_ids: Array[String] = []
var stats: Dictionary = {}
var flags: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func initialize(seed: int, base_stats: Dictionary) -> void:
	_rng.seed = seed
	selected_ids.clear()
	stats = base_stats.duplicate(true)
	flags.clear()

static func validate_definition(mutation: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := String(mutation.get("id", ""))
	if id.is_empty():
		errors.append("Mutation id is missing")
	if String(mutation.get("rarity", "")) not in ALLOWED_RARITIES:
		errors.append("Mutation %s requires a supported rarity" % [id if not id.is_empty() else "?"])
	var raw_effects: Variant = mutation.get("effects", null)
	if typeof(raw_effects) != TYPE_DICTIONARY or (raw_effects as Dictionary).is_empty():
		errors.append("Mutation %s requires a non-empty effects dictionary" % [id if not id.is_empty() else "?"])
		return errors
	var effects := raw_effects as Dictionary
	for raw_key in effects:
		var key := String(raw_key)
		if not EFFECT_OPERATIONS.has(key):
			errors.append("Mutation %s uses unsupported effect %s" % [id, key])
			continue
		var value: Variant = effects[raw_key]
		var operation := String(EFFECT_OPERATIONS[key])
		if operation == "flag_bool":
			if typeof(value) != TYPE_BOOL:
				errors.append("Mutation %s effect %s must be boolean" % [id, key])
			continue
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			errors.append("Mutation %s effect %s must be a finite number" % [id, key])
			continue
		if operation == "multiply" and float(value) <= 0.0:
			errors.append("Mutation %s multiplier %s must be greater than zero" % [id, key])
		elif operation in ["add", "flag_number"] and float(value) < 0.0:
			errors.append("Mutation %s effect %s may not be negative" % [id, key])
	return errors

static func validate_catalog(all_mutations: Array) -> Array[String]:
	var errors: Array[String] = []
	for raw_mutation in all_mutations:
		if typeof(raw_mutation) != TYPE_DICTIONARY:
			errors.append("Mutation catalog contains a non-dictionary entry")
			continue
		errors.append_array(validate_definition(raw_mutation as Dictionary))
	return errors

func offer(all_mutations: Array, count: int = 3, excluded: Array[String] = [], required_rarity: String = "") -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for raw_mutation in all_mutations:
		if typeof(raw_mutation) != TYPE_DICTIONARY:
			continue
		var mutation := raw_mutation as Dictionary
		var id := String(mutation.get("id", ""))
		if not selected_ids.has(id) and not excluded.has(id) and validate_definition(mutation).is_empty():
			candidates.append(mutation)
	var result: Array[Dictionary] = []
	if not required_rarity.is_empty() and required_rarity in ALLOWED_RARITIES and count > 0:
		var required_candidates: Array[Dictionary] = []
		for candidate in candidates:
			if String(candidate.get("rarity", "")) == required_rarity:
				required_candidates.append(candidate)
		if not required_candidates.is_empty():
			var required := required_candidates[_rng.randi_range(0, required_candidates.size() - 1)]
			result.append(required.duplicate(true))
			for index in range(candidates.size() - 1, -1, -1):
				if String(candidates[index].get("id", "")) == String(required.get("id", "")):
					candidates.remove_at(index)
					break
	while not candidates.is_empty() and result.size() < count:
		var index := _rng.randi_range(0, candidates.size() - 1)
		result.append(candidates.pop_at(index).duplicate(true))
	return result

func apply(mutation: Dictionary) -> bool:
	var id := String(mutation.get("id", ""))
	if id.is_empty() or selected_ids.has(id) or not validate_definition(mutation).is_empty():
		return false
	selected_ids.append(id)
	var effects: Dictionary = mutation.effects
	for raw_key in effects:
		var key := String(raw_key)
		var value: Variant = effects[raw_key]
		match String(EFFECT_OPERATIONS[key]):
			"multiply":
				stats[key] = float(stats.get(key, 1.0)) * float(value)
			"add":
				stats[key] = float(stats.get(key, 0.0)) + float(value)
			_:
				flags[key] = value
	return true

func damage_multiplier(
	zone: String,
	distance: float,
	_health_ratio: float,
	organs_destroyed: int,
	shot_streak: int,
	wound_exposed: bool = false
) -> float:
	var multiplier := float(stats.get("damage_mul", 1.0))
	match zone:
		"internal":
			multiplier *= float(stats.get("organ_damage_mul", 1.0))
		"armor":
			multiplier *= float(stats.get("armor_damage_mul", 1.0))
			multiplier *= float(stats.get("external_damage_mul", 1.0))
		"core":
			multiplier *= float(stats.get("external_damage_mul", 1.0))
	if flags.has("damage_per_organ"):
		multiplier *= 1.0 + float(flags.damage_per_organ) * organs_destroyed
	if flags.has("close_damage_mul"):
		var close_range := maxf(1.0, float(flags.get("close_damage_range", 235.0)))
		var proximity := clampf(1.0 - distance / close_range, 0.0, 1.0)
		multiplier *= lerpf(1.0, float(flags.close_damage_mul), proximity)
	if wound_exposed and zone in ["armor", "core"]:
		multiplier *= float(flags.get("breach_window_damage_mul", 1.0))
	if flags.has("streak_damage_step"):
		multiplier *= 1.0 + minf(float(flags.get("streak_damage_cap", 0.0)), shot_streak * float(flags.streak_damage_step))
	return multiplier

func reset() -> void:
	selected_ids.clear()
	stats.clear()
	flags.clear()
