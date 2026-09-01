class_name PermanentUpgradeEngine
extends RefCounted

## Permanent progression has an explicit runtime contract. Every launch effect
## key is listed here with its destination stat and stacking rule; suffixes are
## never interpreted. This keeps data errors from silently becoming purchases
## that do nothing.
const EFFECT_SCHEMA := {
	"max_health_add": {"stat": "max_health", "operation": "add", "kind": "number"},
	"phase_first_hit_reduction": {"stat": "phase_first_hit_reduction", "operation": "reduction_stack", "kind": "ratio"},
	"starting_shield": {"stat": "starting_shield", "operation": "int_add", "kind": "integer"},
	"dash_cooldown_mul": {"stat": "dash_cooldown", "operation": "multiply", "kind": "positive"},
	"dash_invuln_add": {"stat": "dash_invulnerability", "operation": "add", "kind": "number"},
	"breach_duration_mul": {"stat": "breach_duration_mul", "operation": "multiply", "kind": "positive"},
	"damage_mul": {"stat": "damage_mul", "operation": "multiply", "kind": "positive"},
	"phase_open_rate_mul": {"stat": "phase_open_rate_mul", "operation": "multiply", "kind": "positive"},
	"synergy_preview": {"stat": "synergy_preview", "operation": "max_int", "kind": "integer"},
	"magnet_mul": {"stat": "magnet_mul", "operation": "multiply", "kind": "positive"},
	"death_retention_add": {"stat": "death_retention", "operation": "add", "kind": "number"},
	"victory_reward_mul": {"stat": "victory_reward_mul", "operation": "multiply", "kind": "positive"},
	"internal_damage_mul": {"stat": "internal_damage_mul", "operation": "multiply", "kind": "positive"},
	"dive_heal_add": {"stat": "dive_heal", "operation": "add", "kind": "number"},
	"organ_preview": {"stat": "organ_preview", "operation": "max_int", "kind": "integer"},
	"starting_rerolls_add": {"stat": "starting_rerolls", "operation": "int_add", "kind": "integer"},
	"rare_protection": {"stat": "rare_protection", "operation": "max_int", "kind": "integer"},
	"challenge_reward_mul": {"stat": "challenge_reward_mul", "operation": "multiply", "kind": "positive"}
}

const LAUNCH_EFFECT_KEYS: Array[String] = [
	"max_health_add",
	"phase_first_hit_reduction",
	"starting_shield",
	"dash_cooldown_mul",
	"dash_invuln_add",
	"breach_duration_mul",
	"damage_mul",
	"phase_open_rate_mul",
	"synergy_preview",
	"magnet_mul",
	"death_retention_add",
	"victory_reward_mul",
	"internal_damage_mul",
	"dive_heal_add",
	"organ_preview",
	"starting_rerolls_add",
	"rare_protection",
	"challenge_reward_mul"
]

## Competitive challenges normalize every combat-affecting permanent upgrade.
## The Rift Dividend is deliberately retained because it changes only the
## post-run Bio-Matter payout; it cannot change score, time, survivability, or
## any action performed during the ranked run.
const COMPETITIVE_ALLOWED_EFFECT_KEYS: Array[String] = ["challenge_reward_mul"]

const DEFAULT_STATS := {
	"max_health": 100.0,
	"phase_first_hit_reduction": 0.0,
	"starting_shield": 0,
	"dash_cooldown": 2.15,
	"dash_invulnerability": 0.32,
	"dash_charges": 1,
	"breach_duration_mul": 1.0,
	"damage_mul": 1.0,
	"phase_open_rate_mul": 1.0,
	"synergy_preview": 0,
	"magnet_mul": 1.0,
	"death_retention": 0.55,
	"victory_reward_mul": 1.0,
	"internal_damage_mul": 1.0,
	"dive_heal": 0.0,
	"organ_preview": 0,
	"starting_rerolls": 0,
	"rare_protection": 0,
	"challenge_reward_mul": 1.0
}

const STAT_LIMITS := {
	"max_health": Vector2(1.0, 10000.0),
	"phase_first_hit_reduction": Vector2(0.0, 0.85),
	"starting_shield": Vector2(0.0, 20.0),
	"dash_cooldown": Vector2(0.1, 30.0),
	"dash_invulnerability": Vector2(0.0, 2.0),
	"dash_charges": Vector2(1.0, 20.0),
	"breach_duration_mul": Vector2(0.1, 10.0),
	"damage_mul": Vector2(0.1, 100.0),
	"phase_open_rate_mul": Vector2(0.1, 10.0),
	"synergy_preview": Vector2(0.0, 10.0),
	"magnet_mul": Vector2(0.1, 20.0),
	"death_retention": Vector2(0.0, 0.88),
	"victory_reward_mul": Vector2(0.1, 20.0),
	"internal_damage_mul": Vector2(0.05, 10.0),
	"dive_heal": Vector2(0.0, 1000.0),
	"organ_preview": Vector2(0.0, 10.0),
	"starting_rerolls": Vector2(0.0, 20.0),
	"rare_protection": Vector2(0.0, 10.0),
	"challenge_reward_mul": Vector2(0.1, 20.0)
}

var stats: Dictionary = DEFAULT_STATS.duplicate(true)
var effective_levels: Dictionary = {}
var consumed_effect_keys: Array[String] = []
var validation_errors: Array[String] = []
var ownership_warnings: Array[String] = []

## Validates and aggregates owned launch upgrades. Invalid catalogs fail closed:
## callers receive defaults and `initialize` returns false.
func initialize(upgrade_catalog: Array, owned_levels: Dictionary, competitive: bool = false, base_stats: Dictionary = {}) -> bool:
	validation_errors = validate_catalog(upgrade_catalog, true)
	ownership_warnings.clear()
	effective_levels.clear()
	consumed_effect_keys.clear()
	stats = DEFAULT_STATS.duplicate(true)
	_apply_base_overrides(base_stats)
	if not validation_errors.is_empty():
		return false
	var known_ids := _catalog_by_id(upgrade_catalog)
	for raw_id in owned_levels:
		var owned_id := String(raw_id)
		if not known_ids.has(owned_id):
			ownership_warnings.append("Unknown owned upgrade ignored: %s" % owned_id)
	# Normalize every known level before evaluating dependencies so catalog order
	# cannot change ownership eligibility.
	for raw_upgrade in upgrade_catalog:
		var upgrade := raw_upgrade as Dictionary
		var id := String(upgrade.get("id", ""))
		var level := _normalized_owned_level(owned_levels.get(id, 0), int(upgrade.get("max_level", 1)), id)
		effective_levels[id] = level
	_enforce_owned_prerequisites(upgrade_catalog)
	for raw_upgrade in upgrade_catalog:
		var upgrade := raw_upgrade as Dictionary
		var id := String(upgrade.get("id", ""))
		var level := int(effective_levels.get(id, 0))
		if level <= 0:
			continue
		var effects := upgrade.get("effects", {}) as Dictionary
		for raw_key in effects:
			var effect_key := String(raw_key)
			if competitive and not COMPETITIVE_ALLOWED_EFFECT_KEYS.has(effect_key):
				continue
			_apply_effect(effect_key, effects[raw_key], level)
	_clamp_stats()
	return true

func export_stats() -> Dictionary:
	return stats.duplicate(true)

## Sums only catalog-backed, clamped levels whose full prerequisite chain is
## satisfied. UI progression must use this instead of summing raw save values,
## which may include retired ids, corrupt values, or levels above the cap.
static func normalized_total_levels(upgrade_catalog: Array, owned_levels: Dictionary) -> int:
	var engine := PermanentUpgradeEngine.new()
	if not engine.initialize(upgrade_catalog, owned_levels, false):
		return 0
	var total := 0
	for raw_level in engine.effective_levels.values():
		total += int(raw_level)
	return total

static func validate_definition(upgrade: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := String(upgrade.get("id", ""))
	var label := id if not id.is_empty() else "?"
	if id.is_empty():
		errors.append("Upgrade id is missing")
	var max_level_value: Variant = upgrade.get("max_level", null)
	if not _is_integer_number(max_level_value) or int(max_level_value) <= 0:
		errors.append("Upgrade %s requires a positive integer max_level" % label)
	for cost_key in ["base_cost", "cost_scale"]:
		var cost_value: Variant = upgrade.get(cost_key, null)
		if typeof(cost_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(cost_value)) or float(cost_value) <= 0.0:
			errors.append("Upgrade %s requires positive finite %s" % [label, cost_key])
	var raw_effects: Variant = upgrade.get("effects", null)
	if typeof(raw_effects) != TYPE_DICTIONARY or (raw_effects as Dictionary).is_empty():
		errors.append("Upgrade %s requires a non-empty effects dictionary" % label)
		return errors
	for raw_key in raw_effects:
		var key := String(raw_key)
		if not EFFECT_SCHEMA.has(key):
			errors.append("Upgrade %s uses unsupported effect %s" % [label, key])
			continue
		var value: Variant = (raw_effects as Dictionary)[raw_key]
		if not _effect_value_is_valid(key, value):
			errors.append("Upgrade %s has invalid value for effect %s" % [label, key])
	var raw_requirement: Variant = upgrade.get("requires", "")
	if not String(raw_requirement).is_empty() and not bool(parse_requirement(raw_requirement).valid):
		errors.append("Upgrade %s has invalid requires value %s" % [label, String(raw_requirement)])
	return errors

## `require_launch_coverage` makes the 1.0 data contract strict: all eighteen
## supported effects must appear in the supplied catalog at least once.
static func validate_catalog(upgrade_catalog: Array, require_launch_coverage: bool = false) -> Array[String]:
	var errors: Array[String] = []
	var catalog := _catalog_by_id(upgrade_catalog)
	var seen_effects: Dictionary = {}
	if catalog.size() != upgrade_catalog.size():
		errors.append("Upgrade catalog contains a non-dictionary, duplicate, or missing id")
	for raw_upgrade in upgrade_catalog:
		if typeof(raw_upgrade) != TYPE_DICTIONARY:
			errors.append("Upgrade catalog contains a non-dictionary entry")
			continue
		var upgrade := raw_upgrade as Dictionary
		errors.append_array(validate_definition(upgrade))
		for raw_key in (upgrade.get("effects", {}) as Dictionary):
			seen_effects[String(raw_key)] = true
	var requirement_parent: Dictionary = {}
	for raw_upgrade in upgrade_catalog:
		if typeof(raw_upgrade) != TYPE_DICTIONARY:
			continue
		var upgrade := raw_upgrade as Dictionary
		var id := String(upgrade.get("id", ""))
		var requirement := parse_requirement(upgrade.get("requires", ""))
		if bool(requirement.empty):
			continue
		if not bool(requirement.valid):
			continue
		var required_id := String(requirement.id)
		if not catalog.has(required_id):
			errors.append("Upgrade %s requires unknown upgrade %s" % [id, required_id])
			continue
		var target := catalog[required_id] as Dictionary
		if int(requirement.level) > int(target.get("max_level", 0)):
			errors.append("Upgrade %s requires unreachable level %d of %s" % [id, int(requirement.level), required_id])
		requirement_parent[id] = required_id
	for raw_id in requirement_parent:
		var start_id := String(raw_id)
		var cursor := start_id
		var visited: Dictionary = {}
		while requirement_parent.has(cursor):
			if visited.has(cursor):
				errors.append("Upgrade prerequisite cycle includes %s" % start_id)
				break
			visited[cursor] = true
			cursor = String(requirement_parent[cursor])
	if require_launch_coverage:
		for effect_key in LAUNCH_EFFECT_KEYS:
			if not seen_effects.has(effect_key):
				errors.append("Launch upgrade catalog does not exercise effect %s" % effect_key)
	return errors

## Parses the intentionally small `upgrade_id:level` prerequisite language.
## Empty requirements are valid and marked with `empty=true`.
static func parse_requirement(raw_requirement: Variant) -> Dictionary:
	var text := String(raw_requirement).strip_edges()
	if text.is_empty():
		return {"valid": true, "empty": true, "id": "", "level": 0}
	var pieces := text.split(":", false, 2)
	if pieces.size() != 2:
		return {"valid": false, "empty": false, "id": "", "level": 0}
	var required_id := String(pieces[0]).strip_edges()
	var level_text := String(pieces[1]).strip_edges()
	if required_id.is_empty() or not level_text.is_valid_int():
		return {"valid": false, "empty": false, "id": required_id, "level": 0}
	var required_level := int(level_text)
	return {
		"valid": required_level > 0,
		"empty": false,
		"id": required_id,
		"level": required_level
	}

static func prerequisite_met(upgrade: Dictionary, owned_levels: Dictionary) -> bool:
	var requirement := parse_requirement(upgrade.get("requires", ""))
	if not bool(requirement.valid):
		return false
	if bool(requirement.empty):
		return true
	return _safe_owned_level(owned_levels.get(String(requirement.id), 0)) >= int(requirement.level)

## A single purchase gate for Forge integration. It enforces the declared
## prerequisite and max level before returning the next deterministic cost.
static func purchase_gate(upgrade: Dictionary, owned_levels: Dictionary) -> Dictionary:
	var definition_errors := validate_definition(upgrade)
	if not definition_errors.is_empty():
		return {"allowed": false, "reason": "invalid_definition", "errors": definition_errors, "cost": -1}
	var id := String(upgrade.id)
	var max_level := int(upgrade.max_level)
	var level := clampi(_safe_owned_level(owned_levels.get(id, 0)), 0, max_level)
	if level >= max_level:
		return {"allowed": false, "reason": "max_level", "level": level, "max_level": max_level, "cost": -1}
	var requirement := parse_requirement(upgrade.get("requires", ""))
	if not prerequisite_met(upgrade, owned_levels):
		return {
			"allowed": false,
			"reason": "prerequisite",
			"level": level,
			"max_level": max_level,
			"requires": requirement,
			"cost": -1
		}
	var cost := int(round(float(upgrade.base_cost) * pow(float(upgrade.cost_scale), level)))
	return {"allowed": true, "reason": "ok", "level": level, "max_level": max_level, "cost": cost}

static func _catalog_by_id(upgrade_catalog: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_upgrade in upgrade_catalog:
		if typeof(raw_upgrade) != TYPE_DICTIONARY:
			continue
		var upgrade := raw_upgrade as Dictionary
		var id := String(upgrade.get("id", ""))
		if id.is_empty() or result.has(id):
			continue
		result[id] = upgrade
	return result

static func _effect_value_is_valid(key: String, value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	var schema := EFFECT_SCHEMA[key] as Dictionary
	match String(schema.kind):
		"integer":
			return _is_integer_number(value) and int(value) >= 0
		"positive":
			return float(value) > 0.0
		"ratio":
			return float(value) >= 0.0 and float(value) < 1.0
		_:
			return float(value) >= 0.0

static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	return float(value) == floor(float(value))

static func _safe_owned_level(raw_level: Variant) -> int:
	if typeof(raw_level) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	if not is_finite(float(raw_level)):
		return 0
	return maxi(0, int(raw_level))

func _normalized_owned_level(raw_level: Variant, max_level: int, id: String) -> int:
	if typeof(raw_level) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw_level)):
		ownership_warnings.append("Invalid owned level ignored for %s" % id)
		return 0
	var numeric := float(raw_level)
	if numeric != floor(numeric):
		ownership_warnings.append("Fractional owned level truncated for %s" % id)
	var requested := int(numeric)
	var normalized := clampi(requested, 0, max_level)
	if requested != normalized:
		ownership_warnings.append("Owned level clamped for %s" % id)
	return normalized

func _enforce_owned_prerequisites(upgrade_catalog: Array) -> void:
	# Catalog validation rejects cycles, so repeatedly removing ineligible nodes
	# converges in at most catalog.size() passes and handles dependency chains.
	var changed := true
	while changed:
		changed = false
		for raw_upgrade in upgrade_catalog:
			var upgrade := raw_upgrade as Dictionary
			var id := String(upgrade.get("id", ""))
			if int(effective_levels.get(id, 0)) <= 0:
				continue
			var requirement := parse_requirement(upgrade.get("requires", ""))
			if bool(requirement.empty):
				continue
			var required_id := String(requirement.id)
			var required_level := int(requirement.level)
			if int(effective_levels.get(required_id, 0)) >= required_level:
				continue
			effective_levels[id] = 0
			ownership_warnings.append(
				"Owned upgrade %s ignored: prerequisite %s level %d is not met" % [id, required_id, required_level]
			)
			changed = true

func _apply_base_overrides(base_stats: Dictionary) -> void:
	for raw_key in base_stats:
		var key := String(raw_key)
		if not DEFAULT_STATS.has(key):
			ownership_warnings.append("Unknown base stat ignored: %s" % key)
			continue
		var value: Variant = base_stats[raw_key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			ownership_warnings.append("Invalid base stat ignored: %s" % key)
			continue
		stats[key] = value
	_clamp_stats()

func _apply_effect(key: String, raw_value: Variant, level: int) -> void:
	var schema := EFFECT_SCHEMA[key] as Dictionary
	var stat := String(schema.stat)
	var value := float(raw_value)
	match String(schema.operation):
		"add":
			stats[stat] = float(stats[stat]) + value * level
		"int_add":
			stats[stat] = int(stats[stat]) + int(raw_value) * level
		"multiply":
			stats[stat] = float(stats[stat]) * pow(value, level)
		"reduction_stack":
			stats[stat] = 1.0 - (1.0 - float(stats[stat])) * pow(1.0 - value, level)
		"max_int":
			stats[stat] = maxi(int(stats[stat]), int(raw_value))
	if not consumed_effect_keys.has(key):
		consumed_effect_keys.append(key)

func _clamp_stats() -> void:
	for raw_key in STAT_LIMITS:
		var key := String(raw_key)
		var limits := STAT_LIMITS[key] as Vector2
		if typeof(DEFAULT_STATS[key]) == TYPE_INT:
			stats[key] = clampi(int(stats[key]), int(limits.x), int(limits.y))
		else:
			stats[key] = clampf(float(stats[key]), limits.x, limits.y)
