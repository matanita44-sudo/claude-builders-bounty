class_name BossPatternPlanner
extends RefCounted

## Pure, deterministic compiler for exterior Titan phase rules.
##
## The planner owns no Nodes, RNG state, or mutable gameplay state. Callers
## provide the boss definition, current phase, destroyed organs, run seed, and
## attack index; the same inputs always produce the same bounded plan.

const PLAN_VERSION := 1
const BASIC_ABILITY := "basic_rupture"
const STATUS_BASIC := "basic"
const STATUS_ACTIVE := "active"
const STATUS_DEGRADED := "degraded"
const LOSS_DISABLE := "disable"
const LOSS_TRANSFORM := "transform"
const VALID_FAMILIES := ["aimed_fan", "ring", "lane"]

const PHASE_COUNT := 3
const MIN_TELEGRAPH_SECONDS := 0.74
const MAX_TELEGRAPH_SECONDS := 2.40
const MIN_CADENCE_SECONDS := 1.80
const MAX_CADENCE_SECONDS := 3.40
const MIN_PROJECTILE_BUDGET := 8
const MAX_PROJECTILE_BUDGET := 20
const MIN_PROJECTILE_SPEED := 90.0
const MAX_PROJECTILE_SPEED := 480.0
const MIN_DAMAGE := 1.0
const MAX_DAMAGE := 15.0
const MIN_SAFETY_MARGIN := 1.0
const MAX_SAFETY_MARGIN := 1.25
const MIN_SPEED_MULTIPLIER := 0.85
const MAX_SPEED_MULTIPLIER := 1.10
const ARENA_WIDTH := 540.0
const LANE_START_X := 22.0
const LANE_END_X := 519.0


static func validate_boss_definition(boss: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var boss_id := String(boss.get("id", "?")).strip_edges()
	var organ_values: Variant = boss.get("organs", null)
	if typeof(organ_values) != TYPE_ARRAY or (organ_values as Array).size() != 3:
		errors.append("Boss %s requires exactly three organs before phase planning" % boss_id)
		return errors
	var organs := organ_values as Array
	var abilities: Dictionary = {}
	for raw_organ in organs:
		if typeof(raw_organ) != TYPE_DICTIONARY:
			errors.append("Boss %s contains an invalid organ phase source" % boss_id)
			continue
		var organ := raw_organ as Dictionary
		var organ_id := String(organ.get("id", "?")).strip_edges()
		var ability_id := String(organ.get("ability", "")).strip_edges()
		if ability_id.is_empty() or abilities.has(ability_id):
			errors.append("Boss %s has an invalid phase ability %s" % [boss_id, ability_id])
		else:
			abilities[ability_id] = organ_id
		var intact_value: Variant = organ.get("intact_pattern", null)
		if typeof(intact_value) != TYPE_DICTIONARY:
			errors.append("Organ %s requires an intact exterior pattern" % organ_id)
		else:
			errors.append_array(_validate_pattern("Organ %s intact" % organ_id, intact_value as Dictionary))

	var rules_value: Variant = boss.get("phase_rules", null)
	if typeof(rules_value) != TYPE_ARRAY:
		errors.append("Boss %s requires a phase_rules array" % boss_id)
		return errors
	var rules := rules_value as Array
	if rules.size() != PHASE_COUNT:
		errors.append("Boss %s requires exactly three exterior phase rules" % boss_id)
	var rule_ids: Dictionary = {}
	var mechanics: Dictionary = {}
	var signatures: Dictionary = {}
	for phase_index in rules.size():
		var raw_rule: Variant = rules[phase_index]
		if typeof(raw_rule) != TYPE_DICTIONARY:
			errors.append("Boss %s phase %d is not a dictionary" % [boss_id, phase_index + 1])
			continue
		var rule := raw_rule as Dictionary
		var rule_id := String(rule.get("id", "")).strip_edges()
		if rule_id.is_empty() or rule_ids.has(rule_id):
			errors.append("Boss %s phase %d requires a unique rule id" % [boss_id, phase_index + 1])
		rule_ids[rule_id] = true
		if int(rule.get("phase", -1)) != phase_index:
			errors.append("Boss %s rule %s must declare zero-based phase %d" % [boss_id, rule_id, phase_index])
		var mechanic := String(rule.get("mechanic", "")).strip_edges()
		if mechanic.is_empty() or mechanics.has(mechanic):
			errors.append("Boss %s rule %s requires a distinct mechanic" % [boss_id, rule_id])
		mechanics[mechanic] = true
		var focus := String(rule.get("focus_ability", ""))
		if not abilities.has(focus):
			errors.append("Boss %s rule %s focuses an unknown ability %s" % [boss_id, rule_id, focus])
		var cycle_value: Variant = rule.get("ability_cycle", null)
		if typeof(cycle_value) != TYPE_ARRAY:
			errors.append("Boss %s rule %s requires an ability cycle" % [boss_id, rule_id])
		else:
			var cycle := cycle_value as Array
			if cycle.size() < 5 or cycle.size() > 8:
				errors.append("Boss %s rule %s ability cycle must contain five to eight entries" % [boss_id, rule_id])
			var coverage: Dictionary = {}
			var focus_count := 0
			for raw_ability in cycle:
				var ability_id := String(raw_ability)
				if ability_id != BASIC_ABILITY and not abilities.has(ability_id):
					errors.append("Boss %s rule %s references unknown ability %s" % [boss_id, rule_id, ability_id])
				coverage[ability_id] = true
				focus_count += 1 if ability_id == focus else 0
			if not coverage.has(BASIC_ABILITY):
				errors.append("Boss %s rule %s must retain a basic fallback" % [boss_id, rule_id])
			for raw_ability_id in abilities:
				if not coverage.has(String(raw_ability_id)):
					errors.append("Boss %s rule %s omits organ ability %s" % [boss_id, rule_id, raw_ability_id])
			if focus_count < 2:
				errors.append("Boss %s rule %s must mechanically emphasize its focus ability" % [boss_id, rule_id])
		var stride := int(rule.get("selection_stride", 0))
		if stride < 1 or stride > 3:
			errors.append("Boss %s rule %s selection stride must be between one and three" % [boss_id, rule_id])
		var telegraph := _numeric(rule.get("telegraph_seconds", null), -1.0)
		if telegraph < MIN_TELEGRAPH_SECONDS or telegraph > 1.40:
			errors.append("Boss %s rule %s telegraph is outside the authored readability bound" % [boss_id, rule_id])
		var cadence := _numeric(rule.get("cadence_seconds", null), -1.0)
		if cadence < MIN_CADENCE_SECONDS or cadence > MAX_CADENCE_SECONDS:
			errors.append("Boss %s rule %s cadence is outside the safe bound" % [boss_id, rule_id])
		var budget := int(rule.get("projectile_budget", 0))
		if budget < MIN_PROJECTILE_BUDGET or budget > MAX_PROJECTILE_BUDGET:
			errors.append("Boss %s rule %s projectile budget is outside the safe bound" % [boss_id, rule_id])
		var speed_multiplier := _numeric(rule.get("speed_multiplier", null), -1.0)
		if speed_multiplier < MIN_SPEED_MULTIPLIER or speed_multiplier > MAX_SPEED_MULTIPLIER:
			errors.append("Boss %s rule %s speed multiplier is outside the safe bound" % [boss_id, rule_id])
		var safety_margin := _numeric(rule.get("safety_margin", null), -1.0)
		if safety_margin < MIN_SAFETY_MARGIN or safety_margin > MAX_SAFETY_MARGIN:
			errors.append("Boss %s rule %s safety margin is outside the safe bound" % [boss_id, rule_id])
		var fallback_value: Variant = rule.get("fallback_pattern", null)
		if typeof(fallback_value) != TYPE_DICTIONARY:
			errors.append("Boss %s rule %s requires a fallback pattern" % [boss_id, rule_id])
		else:
			errors.append_array(_validate_pattern("Boss %s rule %s fallback" % [boss_id, rule_id], fallback_value as Dictionary))
		var signature := mechanical_signature_for_rule(rule)
		if signatures.has(signature):
			errors.append("Boss %s phases %d and %d are mechanically identical" % [boss_id, int(signatures[signature]) + 1, phase_index + 1])
		signatures[signature] = phase_index
	return errors


static func build_plan(boss: Dictionary, phase_index: int, destroyed_organs: Array, seed: int, attack_index: int) -> Dictionary:
	var errors := validate_boss_definition(boss)
	if phase_index < 0 or phase_index >= PHASE_COUNT:
		errors.append("Phase index %d is outside the launch phase range" % phase_index)
	if attack_index < 0:
		errors.append("Attack index cannot be negative")
	var organ_by_id: Dictionary = {}
	for raw_organ in boss.get("organs", []):
		if typeof(raw_organ) == TYPE_DICTIONARY:
			var organ := raw_organ as Dictionary
			organ_by_id[String(organ.get("id", ""))] = organ
	var destroyed: Dictionary = {}
	for raw_organ_id in destroyed_organs:
		var organ_id := String(raw_organ_id)
		if not organ_by_id.has(organ_id):
			errors.append("Unknown destroyed organ %s" % organ_id)
		else:
			destroyed[organ_id] = true
	if not errors.is_empty():
		return _rejected_plan(boss, phase_index, errors)

	var rules := boss.get("phase_rules", []) as Array
	var rule := rules[phase_index] as Dictionary
	var ability_entries: Dictionary = {}
	for raw_organ in boss.get("organs", []):
		var organ := raw_organ as Dictionary
		var organ_id := String(organ.get("id", ""))
		var ability_id := String(organ.get("ability", ""))
		if not destroyed.has(organ_id):
			ability_entries[ability_id] = {
				"ability_id": ability_id,
				"source_organ": organ_id,
				"status": STATUS_ACTIVE,
				"variant": "intact",
				"telegraph_multiplier": 1.0,
				"pattern": (organ.get("intact_pattern", {}) as Dictionary).duplicate(true),
			}
			continue
		var loss := organ.get("loss", {}) as Dictionary
		if String(loss.get("mode", LOSS_DISABLE)) != LOSS_TRANSFORM:
			continue
		ability_entries[ability_id] = {
			"ability_id": ability_id,
			"source_organ": organ_id,
			"status": STATUS_DEGRADED,
			"variant": String(loss.get("variant", "degraded")),
			"telegraph_multiplier": maxf(1.0, float(loss.get("telegraph_multiplier", 1.0))),
			"pattern": (loss.get("pattern", {}) as Dictionary).duplicate(true),
		}

	var candidates: Array[Dictionary] = []
	for raw_ability in rule.get("ability_cycle", []):
		var ability_id := String(raw_ability)
		if ability_id == BASIC_ABILITY:
			candidates.append({
				"ability_id": BASIC_ABILITY,
				"source_organ": "",
				"status": STATUS_BASIC,
				"variant": String(rule.get("mechanic", "phase_fallback")),
				"telegraph_multiplier": 1.0,
				"pattern": (rule.get("fallback_pattern", {}) as Dictionary).duplicate(true),
			})
		elif ability_entries.has(ability_id):
			candidates.append((ability_entries[ability_id] as Dictionary).duplicate(true))
	if candidates.is_empty():
		return _rejected_plan(boss, phase_index, ["Phase rule has no runtime candidates after organ filtering"])

	var stable_seed := _mix_seed(seed, String(boss.get("id", "")), phase_index)
	var authored_stride := int(rule.get("selection_stride", 1))
	var stride := _coprime_stride(authored_stride, candidates.size())
	var sequence_index := posmod(stable_seed + attack_index * stride, candidates.size())
	var selected := (candidates[sequence_index] as Dictionary).duplicate(true)
	var budget := int(rule.get("projectile_budget", MAX_PROJECTILE_BUDGET))
	var pattern := _bounded_pattern(
		selected.get("pattern", {}) as Dictionary,
		budget,
		float(rule.get("speed_multiplier", 1.0)),
		float(rule.get("safety_margin", 1.0))
	)
	var telegraph := clampf(
		float(rule.get("telegraph_seconds", MIN_TELEGRAPH_SECONDS)) * float(selected.get("telegraph_multiplier", 1.0)),
		MIN_TELEGRAPH_SECONDS,
		MAX_TELEGRAPH_SECONDS
	)
	var plan := {
		"valid": true,
		"version": PLAN_VERSION,
		"boss_id": String(boss.get("id", "")),
		"phase_index": phase_index,
		"phase_number": phase_index + 1,
		"phase_rule_id": String(rule.get("id", "")),
		"mechanic": String(rule.get("mechanic", "")),
		"mechanical_signature": mechanical_signature_for_rule(rule),
		"focus_ability": String(rule.get("focus_ability", "")),
		"ability_id": String(selected.get("ability_id", BASIC_ABILITY)),
		"source_organ": String(selected.get("source_organ", "")),
		"status": String(selected.get("status", STATUS_BASIC)),
		"variant": String(selected.get("variant", "")),
		"telegraph_seconds": telegraph,
		"cadence_seconds": float(rule.get("cadence_seconds", 2.5)),
		"projectile_budget": budget,
		"projectile_count": mini(_estimated_projectile_count(pattern), budget),
		"pattern_family": String(pattern.get("family", "")),
		"pattern": pattern,
		"selection_stride": stride,
		"authored_selection_stride": authored_stride,
		"sequence_index": sequence_index,
		"candidate_count": candidates.size(),
		"seed": seed,
		"attack_index": attack_index,
		"destroyed_organs": _sorted_strings(destroyed.keys()),
	}
	var plan_errors := validate_plan(plan)
	if not plan_errors.is_empty():
		return _rejected_plan(boss, phase_index, plan_errors)
	return plan


static func build_projectile_specs(plan: Dictionary, origin: Vector2, player_position: Vector2, safe_angle: float, runtime_speed_multiplier: float = 1.0) -> Array[Dictionary]:
	if not bool(plan.get("valid", false)) or not validate_plan(plan).is_empty():
		return []
	var pattern := plan.get("pattern", {}) as Dictionary
	var family := String(pattern.get("family", ""))
	var speed := float(pattern.get("speed", MIN_PROJECTILE_SPEED)) * clampf(runtime_speed_multiplier, 0.5, 2.0)
	var damage := float(pattern.get("damage", MIN_DAMAGE))
	var ability_id := String(plan.get("ability_id", BASIC_ABILITY))
	var cause_id := "ability:%s" % ability_id
	var budget := int(plan.get("projectile_budget", MAX_PROJECTILE_BUDGET))
	var result: Array[Dictionary] = []
	match family:
		"aimed_fan":
			var count := mini(int(pattern.get("count", 1)), budget)
			var spread := float(pattern.get("spread_radians", 0.0))
			var player_angle := (player_position - origin).angle()
			for index in count:
				var centered_index := float(index) - float(count - 1) * 0.5
				result.append({
					"origin": origin,
					"velocity": Vector2.from_angle(player_angle + centered_index * spread) * speed,
					"damage": damage,
					"options": {"radius": 5.8, "homing": float(pattern.get("homing", 0.0)), "cause": cause_id},
				})
		"ring":
			var count := mini(int(pattern.get("count", 8)), budget)
			var safe_arc := float(pattern.get("safe_arc_radians", 0.45))
			for index in count:
				var angle := index * TAU / float(count)
				if absf(wrapf(angle - safe_angle, -PI, PI)) < safe_arc:
					continue
				result.append({
					"origin": origin,
					"velocity": Vector2.from_angle(angle) * speed,
					"damage": damage,
					"options": {"radius": 6.0, "cause": cause_id},
				})
		"lane":
			var step := int(pattern.get("step", 40))
			var gap_half_width := float(pattern.get("gap_half_width", 72.0))
			var safe_flank := int(pattern.get("safe_flank", 0))
			var gap_x := clampf(player_position.x, 80.0, ARENA_WIDTH - 80.0)
			if safe_flank < 0:
				gap_x = 68.0
			elif safe_flank > 0:
				gap_x = ARENA_WIDTH - 68.0
			for x in range(int(LANE_START_X), int(LANE_END_X), step):
				if result.size() >= budget:
					break
				if absf(float(x) - gap_x) < gap_half_width:
					continue
				result.append({
					"origin": Vector2(float(x), 260.0),
					"velocity": Vector2(0.0, speed),
					"damage": damage,
					"options": {"shape": "wall", "radius": 8.0, "cause": cause_id},
				})
	if result.size() > budget:
		result.resize(budget)
	return result


static func validate_plan(plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not bool(plan.get("valid", false)):
		errors.append("Plan is not marked valid")
		return errors
	if int(plan.get("version", 0)) != PLAN_VERSION:
		errors.append("Plan version does not match the runtime")
	var phase_index := int(plan.get("phase_index", -1))
	if phase_index < 0 or phase_index >= PHASE_COUNT:
		errors.append("Plan phase is outside the launch range")
	var telegraph := float(plan.get("telegraph_seconds", 0.0))
	if telegraph < MIN_TELEGRAPH_SECONDS or telegraph > MAX_TELEGRAPH_SECONDS:
		errors.append("Plan telegraph is outside runtime bounds")
	var cadence := float(plan.get("cadence_seconds", 0.0))
	if cadence < MIN_CADENCE_SECONDS or cadence > MAX_CADENCE_SECONDS:
		errors.append("Plan cadence is outside runtime bounds")
	var budget := int(plan.get("projectile_budget", 0))
	if budget < MIN_PROJECTILE_BUDGET or budget > MAX_PROJECTILE_BUDGET:
		errors.append("Plan projectile budget is outside runtime bounds")
	var count := int(plan.get("projectile_count", -1))
	if count < 1 or count > budget:
		errors.append("Plan projectile count exceeds its bounded budget")
	var pattern_value: Variant = plan.get("pattern", null)
	if typeof(pattern_value) != TYPE_DICTIONARY:
		errors.append("Plan has no executable pattern")
	else:
		errors.append_array(_validate_pattern("Plan", pattern_value as Dictionary))
	var status := String(plan.get("status", ""))
	if status not in [STATUS_BASIC, STATUS_ACTIVE, STATUS_DEGRADED]:
		errors.append("Plan has an unsupported ability status")
	if String(plan.get("ability_id", "")).is_empty():
		errors.append("Plan has no attributable ability")
	return errors


static func mechanical_signature_for_rule(rule: Dictionary) -> String:
	var source := {
		"focus": String(rule.get("focus_ability", "")),
		"cycle": (rule.get("ability_cycle", []) as Array).duplicate(),
		"stride": int(rule.get("selection_stride", 0)),
		"telegraph": float(rule.get("telegraph_seconds", 0.0)),
		"cadence": float(rule.get("cadence_seconds", 0.0)),
		"budget": int(rule.get("projectile_budget", 0)),
		"speed": float(rule.get("speed_multiplier", 0.0)),
		"safety": float(rule.get("safety_margin", 0.0)),
		"fallback": (rule.get("fallback_pattern", {}) as Dictionary).duplicate(true),
	}
	return JSON.stringify(source).sha256_text()


static func _validate_pattern(label: String, pattern: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var family := String(pattern.get("family", ""))
	if family not in VALID_FAMILIES:
		errors.append("%s uses unsupported pattern family %s" % [label, family])
		return errors
	var speed := _numeric(pattern.get("speed", null), -1.0)
	if speed < MIN_PROJECTILE_SPEED or speed > MAX_PROJECTILE_SPEED:
		errors.append("%s speed is outside the readable bound" % label)
	var damage := _numeric(pattern.get("damage", null), -1.0)
	if damage < MIN_DAMAGE or damage > MAX_DAMAGE:
		errors.append("%s damage is outside the bounded hit range" % label)
	match family:
		"aimed_fan":
			var count := int(pattern.get("count", 0))
			var spread := _numeric(pattern.get("spread_radians", null), -1.0)
			var homing := _numeric(pattern.get("homing", 0.0), -1.0)
			if count < 1 or count > 8:
				errors.append("%s aimed fan count must be between one and eight" % label)
			if spread < 0.0 or spread > 0.24:
				errors.append("%s aimed fan spread is outside the readable bound" % label)
			if homing < 0.0 or homing > 1.60 or (homing > 0.0 and count > 5):
				errors.append("%s homing pressure is outside the readable bound" % label)
		"ring":
			var count := int(pattern.get("count", 0))
			var safe_arc := _numeric(pattern.get("safe_arc_radians", null), -1.0)
			if count < 8 or count > 24:
				errors.append("%s ring count must be between eight and twenty-four" % label)
			if safe_arc < 0.45 or safe_arc > 1.40:
				errors.append("%s ring must preserve a readable safe arc" % label)
		"lane":
			var step := int(pattern.get("step", 0))
			var gap := _numeric(pattern.get("gap_half_width", null), -1.0)
			var flank := int(pattern.get("safe_flank", 99))
			if step < 32 or step > 64:
				errors.append("%s lane step is outside the projectile budget" % label)
			if gap < 58.0 or gap > 150.0:
				errors.append("%s lane must preserve a readable safe gap" % label)
			if flank not in [-1, 0, 1]:
				errors.append("%s lane safe flank must be left, dynamic, or right" % label)
	return errors


static func _bounded_pattern(source: Dictionary, budget: int, speed_multiplier: float, safety_margin: float) -> Dictionary:
	var pattern := source.duplicate(true)
	var family := String(pattern.get("family", ""))
	pattern.speed = clampf(float(pattern.get("speed", MIN_PROJECTILE_SPEED)) * speed_multiplier, MIN_PROJECTILE_SPEED, MAX_PROJECTILE_SPEED)
	pattern.damage = clampf(float(pattern.get("damage", MIN_DAMAGE)), MIN_DAMAGE, MAX_DAMAGE)
	match family:
		"aimed_fan":
			pattern.count = clampi(int(pattern.get("count", 1)), 1, mini(8, budget))
			pattern.spread_radians = clampf(float(pattern.get("spread_radians", 0.0)) / safety_margin, 0.0, 0.24)
			pattern.homing = clampf(float(pattern.get("homing", 0.0)), 0.0, 1.60)
		"ring":
			pattern.count = clampi(int(pattern.get("count", 8)), 8, mini(24, budget))
			pattern.safe_arc_radians = clampf(float(pattern.get("safe_arc_radians", 0.45)) * safety_margin, 0.45, 1.40)
		"lane":
			pattern.step = clampi(int(pattern.get("step", 40)), 32, 64)
			pattern.gap_half_width = clampf(float(pattern.get("gap_half_width", 72.0)) * safety_margin, 58.0, 150.0)
			pattern.safe_flank = clampi(int(pattern.get("safe_flank", 0)), -1, 1)
	return pattern


static func _estimated_projectile_count(pattern: Dictionary) -> int:
	match String(pattern.get("family", "")):
		"aimed_fan", "ring":
			return int(pattern.get("count", 1))
		"lane":
			var step := maxi(1, int(pattern.get("step", 40)))
			return maxi(1, int(ceil((LANE_END_X - LANE_START_X) / float(step))))
	return 0


static func _mix_seed(seed: int, boss_id: String, phase_index: int) -> int:
	var text_value := 17
	for character_index in boss_id.length():
		text_value = posmod(text_value * 131 + boss_id.unicode_at(character_index), 2147483647)
	var normalized_seed := posmod(seed, 2147483647)
	return posmod(normalized_seed * 1103515245 + text_value * 97 + (phase_index + 1) * 104729, 2147483647)


static func _coprime_stride(authored_stride: int, candidate_count: int) -> int:
	if candidate_count <= 1:
		return 1
	var stride := clampi(authored_stride, 1, candidate_count - 1)
	while stride > 1 and _greatest_common_divisor(stride, candidate_count) != 1:
		stride -= 1
	return stride


static func _greatest_common_divisor(left: int, right: int) -> int:
	var a := absi(left)
	var b := absi(right)
	while b != 0:
		var remainder := a % b
		a = b
		b = remainder
	return a


static func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	result.sort()
	return result


static func _numeric(value: Variant, fallback: float) -> float:
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


static func _rejected_plan(boss: Dictionary, phase_index: int, errors: Array) -> Dictionary:
	var messages: Array[String] = []
	for raw_error in errors:
		messages.append(String(raw_error))
	return {
		"valid": false,
		"version": PLAN_VERSION,
		"boss_id": String(boss.get("id", "")),
		"phase_index": phase_index,
		"errors": messages,
	}
