extends Node

const EngineClass := preload("res://scripts/core/permanent_upgrade_engine.gd")

var passed := 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("PERMANENT UPGRADE TEST FAILURE: " + message)

func _run() -> void:
	var catalog := _read_catalog()
	_check(catalog.size() == 18, "Launch catalog must contain exactly 18 permanent upgrades")
	_test_catalog_contract(catalog)
	_test_every_effect_aggregates(catalog)
	_test_prerequisite_gate(catalog)
	_test_owned_prerequisite_enforcement(catalog)
	_test_level_sanitization(catalog)
	_test_fail_closed(catalog)
	print("INFINIDIVE PERMANENT UPGRADE TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

func _read_catalog() -> Array:
	var file := FileAccess.open("res://data/upgrades.json", FileAccess.READ)
	_check(file != null, "Upgrade data must be readable")
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(typeof(parsed) == TYPE_ARRAY, "Upgrade data must parse as an array")
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []

func _test_catalog_contract(catalog: Array) -> void:
	var validation := EngineClass.validate_catalog(catalog, true)
	_check(validation.is_empty(), "Launch catalog must satisfy the explicit effect contract: %s" % "; ".join(validation))
	_check(EngineClass.EFFECT_SCHEMA.size() == 18, "Runtime contract must define exactly 18 supported effects")
	_check(EngineClass.LAUNCH_EFFECT_KEYS.size() == 18, "Launch effect list must contain exactly 18 keys")
	var unique: Dictionary = {}
	for effect_key in EngineClass.LAUNCH_EFFECT_KEYS:
		unique[String(effect_key)] = true
		_check(EngineClass.EFFECT_SCHEMA.has(effect_key), "Launch effect must have a runtime schema: %s" % effect_key)
	_check(unique.size() == 18, "Launch effect list must not contain duplicates")

func _test_every_effect_aggregates(catalog: Array) -> void:
	var owned: Dictionary = {}
	for raw_upgrade in catalog:
		var upgrade := raw_upgrade as Dictionary
		owned[String(upgrade.id)] = int(upgrade.max_level)
	var engine := EngineClass.new()
	_check(engine.initialize(catalog, owned), "Valid launch catalog must initialize")
	_check(engine.validation_errors.is_empty(), "Valid launch catalog must produce no validation errors")
	_check(engine.consumed_effect_keys.size() == 18, "Owning all launch upgrades must consume all 18 effects")
	for effect_key in EngineClass.LAUNCH_EFFECT_KEYS:
		_check(engine.consumed_effect_keys.has(effect_key), "Aggregation must consume effect %s" % effect_key)
	_check(_near(float(engine.stats.max_health), 150.0), "Reinforced Hull must add five levels of hull")
	_check(_near(float(engine.stats.phase_first_hit_reduction), 0.784), "Reactive Plating must stack multiplicatively and remain below immunity")
	_check(int(engine.stats.starting_shield) == 1, "Starting Sheath must grant one shield")
	_check(_near(float(engine.stats.dash_cooldown), 2.15 * pow(0.94, 5)), "Phase Coils must multiply dash cooldown at every level")
	_check(_near(float(engine.stats.dash_invulnerability), 0.425), "Wide Phase must add its invulnerability window")
	_check(int(engine.stats.dash_charges) == 1, "Permanent defaults must preserve one base dash charge")
	_check(_near(float(engine.stats.breach_duration_mul), pow(1.2, 3)), "Breach Anchor must multiply breach duration")
	_check(_near(float(engine.stats.damage_mul), pow(1.05, 5)), "Weapon Calibration must multiply damage")
	_check(_near(float(engine.stats.phase_open_rate_mul), pow(1.12, 3)), "Warm Chamber must multiply phase-open fire rate")
	_check(int(engine.stats.synergy_preview) == 1, "Mastery Socket must unlock synergy preview")
	_check(_near(float(engine.stats.magnet_mul), pow(1.14, 5)), "Grave Magnet must multiply pickup range")
	_check(_near(float(engine.stats.death_retention), 0.85), "Failure Vault must add retention without exceeding its cap")
	_check(_near(float(engine.stats.victory_reward_mul), pow(1.08, 3)), "Core Dividend must multiply victory rewards")
	_check(_near(float(engine.stats.internal_damage_mul), pow(0.94, 5)), "Organ Lining must multiply internal damage taken")
	_check(_near(float(engine.stats.dive_heal), 12.0), "Breach Surge must add dive repair")
	_check(int(engine.stats.organ_preview) == 1, "Anatomy Scan must unlock organ preview")
	_check(int(engine.stats.starting_rerolls) == 2, "Research Reroll must add rerolls")
	_check(int(engine.stats.rare_protection) == 1, "Rarity Filter must unlock rare protection")
	_check(_near(float(engine.stats.challenge_reward_mul), pow(1.12, 3)), "Rift Dividend must multiply challenge rewards")
	var competitive := EngineClass.new()
	_check(competitive.initialize(catalog, owned, true), "Competitive initialization must still validate the catalog")
	for raw_stat_key in EngineClass.DEFAULT_STATS:
		var stat_key := String(raw_stat_key)
		if stat_key == "challenge_reward_mul":
			continue
		_check(
			competitive.stats[stat_key] == EngineClass.DEFAULT_STATS[stat_key],
			"Competitive runs must normalize combat/performance stat %s" % stat_key
		)
	_check(
		_near(float(competitive.stats.challenge_reward_mul), pow(1.12, 3)),
		"Competitive Daily/Friend runs must retain the meta-only Rift Dividend payout"
	)
	_check(
		competitive.consumed_effect_keys == EngineClass.COMPETITIVE_ALLOWED_EFFECT_KEYS,
		"Competitive aggregation must consume only the explicit meta-reward allowlist"
	)

func _test_prerequisite_gate(catalog: Array) -> void:
	var starting_sheath := _find(catalog, "starting_sheath")
	var parsed := EngineClass.parse_requirement(starting_sheath.requires)
	_check(bool(parsed.valid) and not bool(parsed.empty), "Starting Sheath prerequisite must parse")
	_check(String(parsed.id) == "reinforced_hull" and int(parsed.level) == 2, "Prerequisite parser must preserve id and level")
	_check(not EngineClass.prerequisite_met(starting_sheath, {}), "Missing prerequisite must remain locked")
	_check(not EngineClass.prerequisite_met(starting_sheath, {"reinforced_hull": 1}), "Insufficient prerequisite level must remain locked")
	_check(EngineClass.prerequisite_met(starting_sheath, {"reinforced_hull": 2}), "Required prerequisite level must unlock")
	var locked := EngineClass.purchase_gate(starting_sheath, {"reinforced_hull": 1})
	_check(not bool(locked.allowed) and String(locked.reason) == "prerequisite", "Purchase gate must enforce requires")
	var open := EngineClass.purchase_gate(starting_sheath, {"reinforced_hull": 2})
	_check(bool(open.allowed) and int(open.cost) == 260, "Unlocked first purchase must expose configured cost")
	var maxed := EngineClass.purchase_gate(starting_sheath, {"reinforced_hull": 2, "starting_sheath": 1})
	_check(not bool(maxed.allowed) and String(maxed.reason) == "max_level", "Purchase gate must reject maxed upgrades")
	_check(not bool(EngineClass.parse_requirement("broken").valid), "Malformed prerequisite must fail closed")
	_check(not bool(EngineClass.parse_requirement("reinforced_hull:0").valid), "Zero-level prerequisite must fail closed")

func _test_owned_prerequisite_enforcement(catalog: Array) -> void:
	var orphan := EngineClass.new()
	_check(orphan.initialize(catalog, {"starting_sheath": 1}), "Trusted catalog must load an injected orphan ownership map safely")
	_check(int(orphan.effective_levels.starting_sheath) == 0, "Owned dependent upgrade must be disabled when its prerequisite is absent")
	_check(int(orphan.stats.starting_shield) == 0, "Injected Starting Sheath must not grant a shield without Reinforced Hull 2")
	var found_warning := false
	for warning_value in orphan.ownership_warnings:
		if "starting_sheath" in String(warning_value) and "reinforced_hull" in String(warning_value):
			found_warning = true
			break
	_check(found_warning, "Ignored prerequisite ownership must emit an inspectable warning")

	var eligible := EngineClass.new()
	_check(eligible.initialize(catalog, {"reinforced_hull": 2, "starting_sheath": 1}), "Satisfied ownership prerequisite must initialize")
	_check(int(eligible.effective_levels.starting_sheath) == 1, "Satisfied dependent upgrade must retain its owned level")
	_check(int(eligible.stats.starting_shield) == 1, "Satisfied Starting Sheath must grant its shield")

	var malformed_owned := {
		"unknown_retired_upgrade": 999,
		"reinforced_hull": 999,
		"starting_sheath": 1,
		"phase_coils": -8,
		"research_reroll": 999,
		"weapon_calibration": "five"
	}
	_check(
		EngineClass.normalized_total_levels(catalog, malformed_owned) == 8,
		"Normalized total must count only known clamped eligible levels (Hull 5 + Sheath 1 + Reroll 2)"
	)
	_check(
		EngineClass.normalized_total_levels(catalog, {"starting_sheath": 1, "unknown": 400}) == 0,
		"Unknown and prerequisite-orphan levels must never advance Nest progression"
	)
	var invalid_catalog := catalog.duplicate(true)
	(invalid_catalog[0] as Dictionary).effects = {"not_supported": 1}
	_check(
		EngineClass.normalized_total_levels(invalid_catalog, {"reinforced_hull": 5}) == 0,
		"Invalid catalogs must fail closed instead of contributing progression levels"
	)

func _test_level_sanitization(catalog: Array) -> void:
	var engine := EngineClass.new()
	var owned := {
		"reinforced_hull": 999,
		"phase_coils": -4,
		"research_reroll": 1.75,
		"missing_upgrade": 3,
		"weapon_calibration": "five"
	}
	_check(engine.initialize(catalog, owned), "Malformed ownership values must not invalidate trusted catalog data")
	_check(int(engine.effective_levels.reinforced_hull) == 5, "Owned levels above max must clamp")
	_check(int(engine.effective_levels.phase_coils) == 0, "Negative owned levels must clamp to zero")
	_check(int(engine.effective_levels.research_reroll) == 1, "Fractional owned levels must truncate deterministically")
	_check(int(engine.effective_levels.weapon_calibration) == 0, "Non-numeric owned levels must be ignored")
	_check(engine.ownership_warnings.size() >= 4, "Every malformed ownership condition must be inspectable")
	_check(_near(float(engine.stats.max_health), 150.0), "Clamped ownership must aggregate only legal levels")
	_check(_near(float(engine.stats.dash_cooldown), 2.15), "Negative levels must never reverse a multiplier")

func _test_fail_closed(catalog: Array) -> void:
	var invalid_effect := catalog.duplicate(true)
	(invalid_effect[0] as Dictionary).effects = {"unwired_effect": 99}
	var engine := EngineClass.new()
	_check(not engine.initialize(invalid_effect, {"reinforced_hull": 1}), "Unknown upgrade effects must fail initialization")
	_check(not engine.validation_errors.is_empty(), "Rejected catalog must expose validation errors")
	_check(engine.export_stats() == EngineClass.DEFAULT_STATS, "Rejected catalog must return neutral defaults")
	var missing_coverage := catalog.duplicate(true)
	missing_coverage.remove_at(missing_coverage.size() - 1)
	_check(not EngineClass.validate_catalog(missing_coverage, true).is_empty(), "Launch validation must reject missing effect coverage")
	var bad_requirement := catalog.duplicate(true)
	(bad_requirement[0] as Dictionary).requires = "missing_upgrade:1"
	_check(not EngineClass.validate_catalog(bad_requirement, true).is_empty(), "Unknown prerequisite targets must be rejected")
	var cyclic := catalog.duplicate(true)
	(cyclic[0] as Dictionary).requires = "reactive_plating:1"
	(cyclic[1] as Dictionary).requires = "reinforced_hull:1"
	_check(not EngineClass.validate_catalog(cyclic, true).is_empty(), "Prerequisite cycles must be rejected")

func _find(catalog: Array, id: String) -> Dictionary:
	for raw_upgrade in catalog:
		var upgrade := raw_upgrade as Dictionary
		if String(upgrade.get("id", "")) == id:
			return upgrade
	return {}

func _near(actual: float, expected: float, epsilon: float = 0.00001) -> bool:
	return absf(actual - expected) <= epsilon
