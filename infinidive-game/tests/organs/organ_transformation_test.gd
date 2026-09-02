extends Node

const OrganMap := preload("res://scripts/core/organ_ability_map.gd")
const BossPlanner := preload("res://scripts/core/boss_pattern_planner.gd")
const Factory := preload("res://scripts/core/titan_attack_spec_factory.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const BossVisualClass := preload("res://scripts/gameplay/boss_visual.gd")

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("ORGAN TRANSFORMATION TEST FAILURE: "+message)


func _run() -> void:
	await get_tree().process_frame
	var bosses := _read_bosses()
	_test_contract_catalog(bosses)
	_test_state_transitions_and_visuals(bosses)
	_test_exact_described_patterns(bosses)
	_test_validation_guardrails(bosses)
	_test_phase_rule_catalog_and_all_orders(bosses)
	_test_phase_planner_guardrails(bosses)
	await _test_live_run_scene_consumption(bosses)
	await _test_live_phase_planner_consumption(bosses)
	print("INFINIDIVE ORGAN TRANSFORMATION TESTS: %d passed, %d failed" % [passed,failures.size()])
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)


func _read_bosses() -> Array:
	var file := FileAccess.open("res://data/bosses.json",FileAccess.READ)
	_check(file != null,"Boss catalog must be readable")
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(typeof(parsed) == TYPE_ARRAY,"Boss catalog must parse as an array")
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


func _test_contract_catalog(bosses: Array) -> void:
	_check(bosses.size() == 4,"Launch catalog must retain four bosses")
	var organ_count := 0
	var transform_count := 0
	var disable_count := 0
	var tokens: Dictionary = {}
	var variants: Dictionary = {}
	for raw_boss in bosses:
		var boss := raw_boss as Dictionary
		var errors := OrganMap.validate_boss_definition(boss)
		_check(errors.is_empty(),"%s loss contracts must validate: %s" % [boss.get("id","?"),"; ".join(errors)])
		for raw_organ in boss.get("organs",[]):
			var organ := raw_organ as Dictionary
			var organ_id := String(organ.get("id",""))
			var ability_id := String(organ.get("ability",""))
			var intact_tuning_value: Variant = organ.get("intact_tuning",null)
			var loss := organ.get("loss",{}) as Dictionary
			organ_count += 1
			_check(not organ.has("intact_pattern"),"%s cannot retain the obsolete generic intact_pattern alias" % organ_id)
			_check(typeof(intact_tuning_value) == TYPE_DICTIONARY and Factory.validate_intact_tuning(ability_id,intact_tuning_value).is_empty(),"%s must publish one strict Factory-owned intact_tuning contract" % organ_id)
			var mode := String(loss.get("mode",""))
			transform_count += 1 if mode == OrganMap.LOSS_TRANSFORM else 0
			disable_count += 1 if mode == OrganMap.LOSS_DISABLE else 0
			var token := String(loss.get("visual_token",""))
			var variant := String(loss.get("variant",""))
			_check(not token.is_empty() and not tokens.has(token),"%s must own a globally unique visual token" % organ_id)
			_check(BossVisualClass.supports_visual_token(token),"%s visual token must have a concrete BossVisual drawing" % organ_id)
			_check(not variant.is_empty() and not variants.has(variant),"%s must own a distinct mechanical loss variant" % organ_id)
			tokens[token] = organ_id
			variants[variant] = organ_id
	_check(organ_count == 12,"All twelve launch organs must declare loss contracts")
	_check(transform_count == 7,"Seven described abilities must degrade into safer replacement patterns")
	_check(disable_count == 5,"Five described systems must be sealed completely")
	_check(tokens.size() == 12 and variants.size() == 12,"All organ transformations must remain individually identifiable")


func _test_state_transitions_and_visuals(bosses: Array) -> void:
	for raw_boss in bosses:
		var boss := raw_boss as Dictionary
		for raw_organ in boss.get("organs",[]):
			var organ := raw_organ as Dictionary
			var organ_id := String(organ.get("id",""))
			var ability_id := String(organ.get("ability",""))
			var loss := organ.get("loss",{}) as Dictionary
			var mapping := OrganMap.new()
			mapping.initialize(boss)
			var intact := mapping.attack_contract(ability_id)
			_check(mapping.is_ability_enabled(ability_id),"%s must begin with its intact exterior ability enabled" % organ_id)
			_check(mapping.is_ability_runtime_enabled(ability_id) and String(intact.get("status","")) == OrganMap.STATUS_ACTIVE,"%s intact Factory attack must be runtime-selectable" % organ_id)
			_check((intact.get("intact_tuning",{}) as Dictionary) == (organ.get("intact_tuning",{}) as Dictionary) and (intact.get("pattern",{}) as Dictionary).is_empty(),"%s active OrganAbilityMap contract must copy intact tuning without a generic pattern" % organ_id)
			var change := mapping.destroy_organ(organ_id)
			_check(not change.is_empty() and String(change.get("variant","")) == String(loss.get("variant","")),"%s destruction must apply its authored variant exactly once" % organ_id)
			_check(not mapping.is_ability_enabled(ability_id),"%s destruction must remove the intact ability" % organ_id)
			_check(String(change.get("visual_token","")) == String(loss.get("visual_token","")),"%s state change must expose its authored visual token" % organ_id)
			_check(mapping.visual_states().get(organ_id,"") == loss.get("visual_token",""),"%s map must publish its exterior visual state" % organ_id)
			var mode := String(loss.get("mode",""))
			if mode == OrganMap.LOSS_TRANSFORM:
				_check(mapping.ability_status(ability_id) == OrganMap.STATUS_DEGRADED,"%s must enter degraded rather than disabled state" % organ_id)
				_check(mapping.is_ability_runtime_enabled(ability_id),"%s degraded replacement must remain in the exterior attack pool" % organ_id)
				_check(not mapping.attack_contract(ability_id).is_empty() and mapping.attack_contracts().size() == 3,"%s replacement must coexist with both unrelated intact abilities" % organ_id)
			else:
				_check(mapping.ability_status(ability_id) == OrganMap.STATUS_DISABLED,"%s must enter fully disabled state" % organ_id)
				_check(not mapping.is_ability_runtime_enabled(ability_id),"%s sealed system cannot remain in the exterior attack pool" % organ_id)
				_check(mapping.attack_contract(ability_id).is_empty() and mapping.attack_contracts().size() == 2,"%s sealed pattern must disappear without altering unrelated abilities" % organ_id)
			var visual := BossVisualClass.new()
			visual.setup(boss)
			visual.set_exterior(1,mapping.destroyed_organs(),false,mapping.visual_states())
			_check(visual.visual_state_for_organ(organ_id) == String(loss.get("visual_token","")),"%s BossVisual must expose its unique destroyed state" % organ_id)
			_check(visual.active_visual_tokens() == [String(loss.get("visual_token",""))],"%s BossVisual must activate exactly the requested transformation" % organ_id)
			visual.queue_free()
			_check(mapping.destroy_organ(organ_id).is_empty(),"%s destruction must stay idempotent" % organ_id)


func _test_exact_described_patterns(bosses: Array) -> void:
	var basic_rupture := RunSceneClass.basic_rupture_attack_contract()
	_check(String((basic_rupture.pattern as Dictionary).get("family","")) == "ring","Basic rupture must identify its warning as a ring")
	_check(is_equal_approx(float((basic_rupture.pattern as Dictionary).get("safe_arc_radians",0.0)),0.45),"Basic rupture telegraph must publish the exact safe arc used by its projectile ring")
	var contracts := _destroyed_contracts_by_organ(bosses)
	var origin := Vector2(270,228)
	var player := Vector2(270,790)
	var hunter := RunSceneClass.build_degraded_attack_specs(contracts.hunter_eye,origin,player,0.0,1.0)
	_check(bool(hunter.valid) and String(hunter.family) == "aimed_fan" and (hunter.projectiles as Array).size() == 3,"Hunter Eye must become a three-shot straight salvo")
	for raw_projectile in hunter.projectiles:
		_check(is_zero_approx(float((raw_projectile as Dictionary).options.get("homing",0.0))),"Hunter Eye replacement cannot retain homing")
	var gravity := RunSceneClass.build_degraded_attack_specs(contracts.gravity_lung,origin,player,0.0,1.0)
	_check(bool(gravity.valid) and String(gravity.family) == "ring" and (gravity.projectiles as Array).size() < 16,"Gravity Lung ring must preserve a wider empty channel")
	_check(_max_projectile_speed(gravity) <= 132.01,"Gravity Lung replacement must use its slower authored speed")
	var prism := RunSceneClass.build_degraded_attack_specs(contracts.prism_cortex,origin,player,0.0,1.0)
	_check((prism.projectiles as Array).size() == 2 and float(contracts.prism_cortex.telegraph_multiplier) >= 1.4,"Prism Cortex must lose one lance and telegraph substantially longer")
	var wing := RunSceneClass.build_degraded_attack_specs(contracts.wing_reactor,origin,player,0.0,1.0)
	_check(bool(wing.valid) and String(wing.family) == "lane" and float(wing.gap_x) > 440.0,"Wing Reactor must publish a permanent right safe flank")
	for raw_projectile in wing.projectiles:
		_check(float(Vector2((raw_projectile as Dictionary).origin).x) < 360.0,"Collapsed laser wing cannot fire into the permanent safe flank")
	var halo := RunSceneClass.build_degraded_attack_specs(contracts.halo_choir,origin,player,0.0,1.0)
	_check(bool(halo.valid) and (halo.projectiles as Array).size() < 13,"Fractured halo must leave a non-closing opening")
	var vortex := RunSceneClass.build_degraded_attack_specs(contracts.vortex_stomach,origin,player,0.0,1.0)
	_check(bool(vortex.valid) and (vortex.projectiles as Array).size() < 15 and _max_projectile_speed(vortex) <= 122.01,"Vortex Stomach must produce a slower wave with a larger calm channel")
	var shock := RunSceneClass.build_degraded_attack_specs(contracts.shock_gland,origin,player,0.0,1.0)
	_check(bool(shock.valid) and (shock.projectiles as Array).size() == 1,"Shock Gland must collapse chain lightning to one unchained arc")
	for disabled_id in ["bone_forge","brood_sac","memory_cortex","echo_heart","reflection_lattice"]:
		_check(not contracts.has(disabled_id),"%s described shutdown must not fabricate a replacement projectile pattern" % disabled_id)


func _destroyed_contracts_by_organ(bosses: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_boss in bosses:
		var boss := raw_boss as Dictionary
		for raw_organ in boss.get("organs",[]):
			var organ := raw_organ as Dictionary
			var mapping := OrganMap.new()
			mapping.initialize(boss)
			mapping.destroy_organ(String(organ.id))
			var contract := mapping.attack_contract(String(organ.ability))
			if not contract.is_empty():
				result[String(organ.id)] = contract
	return result


func _max_projectile_speed(plan: Dictionary) -> float:
	var maximum := 0.0
	for raw_projectile in plan.get("projectiles",[]):
		maximum = maxf(maximum,Vector2((raw_projectile as Dictionary).velocity).length())
	return maximum


func _test_validation_guardrails(bosses: Array) -> void:
	if bosses.is_empty():
		return
	var missing := (bosses[0] as Dictionary).duplicate(true)
	var missing_organ := (missing.organs[0] as Dictionary).duplicate(true)
	missing_organ.erase("loss")
	missing.organs[0] = missing_organ
	_check(not OrganMap.validate_boss_definition(missing).is_empty(),"Validator must reject an organ without a loss contract")
	var unsafe := (bosses[0] as Dictionary).duplicate(true)
	var unsafe_organ := (unsafe.organs[0] as Dictionary).duplicate(true)
	var unsafe_loss := (unsafe_organ.loss as Dictionary).duplicate(true)
	var unsafe_pattern := (unsafe_loss.pattern as Dictionary).duplicate(true)
	unsafe_pattern.count = 200
	unsafe_pattern.homing = 1.0
	unsafe_loss.pattern = unsafe_pattern
	unsafe_organ.loss = unsafe_loss
	unsafe.organs[0] = unsafe_organ
	_check(OrganMap.validate_boss_definition(unsafe).size() >= 2,"Validator must reject excessive or secretly homing post-loss salvos")
	var duplicate := (bosses[0] as Dictionary).duplicate(true)
	var duplicate_organ := (duplicate.organs[1] as Dictionary).duplicate(true)
	var duplicate_loss := (duplicate_organ.loss as Dictionary).duplicate(true)
	duplicate_loss.visual_token = String((duplicate.organs[0] as Dictionary).loss.visual_token)
	duplicate_organ.loss = duplicate_loss
	duplicate.organs[1] = duplicate_organ
	_check(not OrganMap.validate_boss_definition(duplicate).is_empty(),"Validator must reject duplicate visual states inside a boss")
	var missing_tuning := (bosses[0] as Dictionary).duplicate(true)
	var missing_tuning_organ := (missing_tuning.organs[0] as Dictionary).duplicate(true)
	missing_tuning_organ.erase("intact_tuning")
	missing_tuning.organs[0] = missing_tuning_organ
	_check(not OrganMap.validate_boss_definition(missing_tuning).is_empty(),"Validator must reject an organ without authoritative intact tuning")
	var obsolete_pattern := (bosses[0] as Dictionary).duplicate(true)
	var obsolete_pattern_organ := (obsolete_pattern.organs[0] as Dictionary).duplicate(true)
	obsolete_pattern_organ.intact_pattern = {"family":"aimed_fan","count":1,"spread_radians":0.0,"speed":180.0,"damage":1.0}
	obsolete_pattern.organs[0] = obsolete_pattern_organ
	_check(not OrganMap.validate_boss_definition(obsolete_pattern).is_empty(),"Validator must reject obsolete intact_pattern data even when it looks bounded")
	var loose_tuning := (bosses[0] as Dictionary).duplicate(true)
	var loose_tuning_organ := (loose_tuning.organs[0] as Dictionary).duplicate(true)
	var loose_tuning_contract := (loose_tuning_organ.intact_tuning as Dictionary).duplicate(true)
	loose_tuning_contract.family = "aimed_fan"
	loose_tuning_organ.intact_tuning = loose_tuning_contract
	loose_tuning.organs[0] = loose_tuning_organ
	_check(not OrganMap.validate_boss_definition(loose_tuning).is_empty(),"Validator must reject unsupported geometry fields inside strict intact tuning")


func _test_phase_rule_catalog_and_all_orders(bosses: Array) -> void:
	var origin := Vector2(270.0,228.0)
	var frozen_player := Vector2(214.0,790.0)
	var safe_angle := 0.41
	for raw_boss in bosses:
		var boss := raw_boss as Dictionary
		var boss_id := String(boss.get("id","?"))
		var source_snapshot := JSON.stringify(boss)
		var catalog_errors := BossPlanner.validate_boss_definition(boss)
		_check(catalog_errors.is_empty(),"%s must expose three valid exterior phase rules: %s" % [boss_id,"; ".join(catalog_errors)])
		var rules := boss.get("phase_rules",[]) as Array
		_check(rules.size() == BossPlanner.PHASE_COUNT,"%s must retain exactly three authored phase rules" % boss_id)
		var phase_signatures: Dictionary = {}
		for phase_index in range(rules.size()):
			var rule := rules[phase_index] as Dictionary
			var signature := BossPlanner.mechanical_signature_for_rule(rule)
			_check(not signature.is_empty() and not phase_signatures.has(signature),"%s phase %d must be mechanically distinct" % [boss_id,phase_index+1])
			phase_signatures[signature] = true
			if phase_index > 0:
				var previous := rules[phase_index-1] as Dictionary
				_check(float(rule.telegraph_seconds) < float(previous.telegraph_seconds),"%s phase %d must tighten but preserve its authored telegraph" % [boss_id,phase_index+1])
				_check(float(rule.cadence_seconds) < float(previous.cadence_seconds),"%s phase %d must use a distinct faster attack rhythm" % [boss_id,phase_index+1])
				_check(int(rule.projectile_budget) > int(previous.projectile_budget),"%s phase %d must own a distinct bounded projectile budget" % [boss_id,phase_index+1])
				_check(float(rule.speed_multiplier) > float(previous.speed_multiplier),"%s phase %d must own a distinct bounded movement pressure" % [boss_id,phase_index+1])
		_check(phase_signatures.size() == 3,"%s must retain three unique mechanical signatures" % boss_id)

		var organ_ids: Array[String] = []
		var organ_by_id: Dictionary = {}
		for raw_organ in boss.get("organs",[]):
			var organ := raw_organ as Dictionary
			var organ_id := String(organ.id)
			organ_ids.append(organ_id)
			organ_by_id[organ_id] = organ
		var orders := _permutations(organ_ids)
		_check(orders.size() == 6,"%s must exercise all six organ orders" % boss_id)
		for raw_order in orders:
			var order := raw_order as Array
			for phase_index in BossPlanner.PHASE_COUNT:
				# Exterior phase N follows N completed dives, so each permutation
				# exercises the exact organ-state prefix seen in a real run.
				var destroyed := order.slice(0,phase_index)
				var selected_abilities: Dictionary = {}
				for attack_index in 10:
					var plan := BossPlanner.build_plan(boss,phase_index,destroyed,771901,attack_index)
					var repeated := BossPlanner.build_plan(boss,phase_index,destroyed,771901,attack_index)
					_check(bool(plan.get("valid",false)),"%s phase %d order %s attack %d must compile: %s" % [boss_id,phase_index+1,order,attack_index,plan.get("errors",[])])
					if not bool(plan.get("valid",false)):
						continue
					_check(plan == repeated,"%s phase %d order %s attack %d must replay deterministically" % [boss_id,phase_index+1,order,attack_index])
					_check(BossPlanner.validate_plan(plan).is_empty(),"%s phase %d plan must independently validate" % [boss_id,phase_index+1])
					_check(int(plan.phase_index) == phase_index and String(plan.boss_id) == boss_id,"%s plan must retain exact boss/phase attribution" % boss_id)
					_check(float(plan.telegraph_seconds) >= BossPlanner.MIN_TELEGRAPH_SECONDS and float(plan.telegraph_seconds) <= BossPlanner.MAX_TELEGRAPH_SECONDS and float(plan.cadence_seconds) >= BossPlanner.MIN_CADENCE_SECONDS,"%s phase %d must preserve bounded reaction timing" % [boss_id,phase_index+1])
					_check(int(plan.projectile_budget) <= BossPlanner.MAX_PROJECTILE_BUDGET,"%s phase %d cannot exceed its projectile budget" % [boss_id,phase_index+1])
					_check(_plan_filters_destroyed_organ(plan,destroyed,organ_by_id),"%s phase %d order %s cannot select an intact or disabled destroyed-organ ability" % [boss_id,phase_index+1,order])
					var specs := BossPlanner.build_projectile_specs(plan,origin,frozen_player,safe_angle)
					if String(plan.get("status","")) == BossPlanner.STATUS_ACTIVE:
						_check(String(plan.get("executor","")) == BossPlanner.EXECUTOR_FACTORY and not plan.has("pattern") and not plan.has("pattern_family") and not plan.has("projectile_count") and Factory.validate_intact_tuning(String(plan.ability_id),plan.get("intact_tuning",null)).is_empty(),"%s phase %d ACTIVE plan must carry only strict tuning owned by TitanAttackSpecFactory" % [boss_id,phase_index+1])
						_check(specs.is_empty(),"%s phase %d ACTIVE plan cannot compile a legacy BossPatternPlanner projectile alias" % [boss_id,phase_index+1])
					else:
						_check(String(plan.get("executor","")) == BossPlanner.EXECUTOR_PLANNER and not plan.has("intact_tuning"),"%s phase %d BASIC/DEGRADED plan must remain exclusively BossPatternPlanner-owned" % [boss_id,phase_index+1])
						_check(int(plan.projectile_count) <= int(plan.projectile_budget) and not specs.is_empty() and specs.size() <= int(plan.projectile_budget),"%s phase %d BASIC/DEGRADED plan must emit a bounded nonzero wave" % [boss_id,phase_index+1])
						_check(_projectile_specs_are_safe(plan,specs,frozen_player,safe_angle),"%s phase %d BASIC/DEGRADED plan must retain exact safe geometry and attributable bounded shots" % [boss_id,phase_index+1])
					selected_abilities[String(plan.ability_id)] = true
				var available_abilities := _available_cycle_abilities(boss,rules[phase_index] as Dictionary,destroyed)
				_check(_dictionary_contains_all(selected_abilities,available_abilities),"%s phase %d order %s deterministic stride must not starve a remaining ability" % [boss_id,phase_index+1,order])
		_check(JSON.stringify(boss) == source_snapshot,"%s planning across all organ orders must never mutate source data" % boss_id)


func _permutations(values: Array[String]) -> Array:
	var result: Array = []
	for first in values:
		for second in values:
			for third in values:
				if first != second and first != third and second != third:
					result.append([first,second,third])
	return result


func _test_phase_planner_guardrails(bosses: Array) -> void:
	if bosses.is_empty():
		return
	var boss := (bosses[0] as Dictionary).duplicate(true)
	var unsafe := boss.duplicate(true)
	var unsafe_rule := (unsafe.phase_rules[0] as Dictionary).duplicate(true)
	unsafe_rule.telegraph_seconds = 0.1
	unsafe_rule.projectile_budget = 200
	var unsafe_fallback := (unsafe_rule.fallback_pattern as Dictionary).duplicate(true)
	unsafe_fallback.count = 200
	unsafe_rule.fallback_pattern = unsafe_fallback
	unsafe.phase_rules[0] = unsafe_rule
	_check(BossPlanner.validate_boss_definition(unsafe).size() >= 3,"Phase validator must reject unreadable warnings and unbounded projectile data")
	var duplicate := boss.duplicate(true)
	var duplicate_rule := (duplicate.phase_rules[0] as Dictionary).duplicate(true)
	duplicate_rule.id = String((duplicate.phase_rules[1] as Dictionary).id)
	duplicate.phase_rules[0] = duplicate_rule
	_check(not BossPlanner.validate_boss_definition(duplicate).is_empty(),"Phase validator must reject duplicate rule identities")
	var missing := boss.duplicate(true)
	missing.phase_rules = (missing.phase_rules as Array).slice(0,2)
	_check(not BossPlanner.validate_boss_definition(missing).is_empty(),"Phase validator must reject a Titan without three phases")
	_check(not bool(BossPlanner.build_plan(boss,-1,[],1,0).get("valid",true)),"Planner must reject negative phase input")
	_check(not bool(BossPlanner.build_plan(boss,0,["unknown_organ"],1,0).get("valid",true)),"Planner must reject unknown destroyed organs without mutating gameplay state")
	_check(not bool(BossPlanner.build_plan(boss,0,[],1,-1).get("valid",true)),"Planner must reject negative attack indices")
	var different_seed_seen := false
	for attack_index in 10:
		var first := BossPlanner.build_plan(boss,0,[],17,attack_index)
		var second := BossPlanner.build_plan(boss,0,[],9973,attack_index)
		if int(first.get("sequence_index",-1)) != int(second.get("sequence_index",-1)):
			different_seed_seen = true
			break
	_check(different_seed_seen,"Distinct run seeds must be able to rotate the deterministic phase sequence")


func _plan_filters_destroyed_organ(plan: Dictionary, destroyed: Array, organ_by_id: Dictionary) -> bool:
	var source_organ := String(plan.get("source_organ",""))
	var status := String(plan.get("status",""))
	if source_organ.is_empty():
		return String(plan.get("ability_id","")) == BossPlanner.BASIC_ABILITY and status == BossPlanner.STATUS_BASIC and String(plan.get("executor","")) == BossPlanner.EXECUTOR_PLANNER
	if not organ_by_id.has(source_organ):
		return false
	if source_organ not in destroyed:
		return status == BossPlanner.STATUS_ACTIVE and String(plan.get("executor","")) == BossPlanner.EXECUTOR_FACTORY
	var organ := organ_by_id[source_organ] as Dictionary
	var loss := organ.get("loss",{}) as Dictionary
	return String(loss.get("mode","")) == BossPlanner.LOSS_TRANSFORM and status == BossPlanner.STATUS_DEGRADED and String(plan.get("executor","")) == BossPlanner.EXECUTOR_PLANNER and String(plan.get("variant","")) == String(loss.get("variant",""))


func _available_cycle_abilities(boss: Dictionary, rule: Dictionary, destroyed: Array) -> Dictionary:
	var disabled: Dictionary = {}
	for raw_organ in boss.get("organs",[]):
		var organ := raw_organ as Dictionary
		if String(organ.id) in destroyed and String((organ.get("loss",{}) as Dictionary).get("mode","")) == BossPlanner.LOSS_DISABLE:
			disabled[String(organ.ability)] = true
	var available: Dictionary = {}
	for raw_ability in rule.get("ability_cycle",[]):
		var ability := String(raw_ability)
		if not disabled.has(ability):
			available[ability] = true
	return available


func _dictionary_contains_all(actual: Dictionary, expected: Dictionary) -> bool:
	for raw_key in expected:
		if not actual.has(String(raw_key)):
			return false
	return true


func _projectile_specs_are_safe(plan: Dictionary, specs: Array, frozen_player: Vector2, safe_angle: float) -> bool:
	var pattern := plan.get("pattern",{}) as Dictionary
	var family := String(pattern.get("family",""))
	var expected_cause := "ability:%s" % String(plan.get("ability_id",""))
	var gap_x := clampf(frozen_player.x,80.0,BossPlanner.ARENA_WIDTH-80.0)
	var safe_flank := int(pattern.get("safe_flank",0))
	if safe_flank < 0:
		gap_x = 68.0
	elif safe_flank > 0:
		gap_x = BossPlanner.ARENA_WIDTH-68.0
	for raw_spec in specs:
		var spec := raw_spec as Dictionary
		var velocity := Vector2(spec.get("velocity",Vector2.ZERO))
		var options := spec.get("options",{}) as Dictionary
		if not velocity.is_finite() or velocity.length() < BossPlanner.MIN_PROJECTILE_SPEED-0.01 or velocity.length() > BossPlanner.MAX_PROJECTILE_SPEED+0.01:
			return false
		if float(spec.get("damage",0.0)) < BossPlanner.MIN_DAMAGE or float(spec.get("damage",0.0)) > BossPlanner.MAX_DAMAGE:
			return false
		if String(options.get("cause","")) != expected_cause:
			return false
		if family == "ring" and absf(wrapf(velocity.angle()-safe_angle,-PI,PI)) < float(pattern.get("safe_arc_radians",0.0))-0.0001:
			return false
		if family == "lane" and absf(float(Vector2(spec.origin).x)-gap_x) < float(pattern.get("gap_half_width",0.0))-0.0001:
			return false
	return true


func _test_live_run_scene_consumption(bosses: Array) -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run := RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"deep","seed":774411,"mode":"story"})
	add_child(run)
	run.set_physics_process(false)
	run.set_process(false)
	await get_tree().process_frame
	var contracts := _destroyed_contracts_by_organ(bosses)
	for organ_id_value in contracts:
		var organ_id := String(organ_id_value)
		var contract := contracts[organ_id] as Dictionary
		var expected := RunSceneClass.build_degraded_attack_specs(contract,run._boss_visual.target_position(),run._player.position,0.35,run._difficulty_projectile_speed())
		run._projectiles.clear_enemy()
		run._attack_avoidance_candidates.clear()
		run._spawn_attack(String(contract.ability_id),0.35,run._dash_count,contract)
		_check(run._projectiles.enemy_active.size() == (expected.projectiles as Array).size(),"RunScene must spawn the authored %s replacement projectile count" % organ_id)
		_check(run._attack_avoidance_candidates.size() == 1,"%s replacement must remain tied to its readable telegraph wave" % organ_id)
		for raw_bullet in run._projectiles.enemy_active:
			var bullet := raw_bullet as Dictionary
			_check(String(bullet.cause) == "ability:%s" % String(contract.ability_id),"%s replacement must retain an attributable damage cause" % organ_id)
			_check(not String(bullet.group).is_empty(),"%s replacement must publish a wave identity for avoidance attribution" % organ_id)
	run.projectiles_clear_and_enemies()
	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile


func _test_live_phase_planner_consumption(bosses: Array) -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	for raw_boss in bosses:
		var boss := raw_boss as Dictionary
		var run := RunSceneClass.new()
		run.initialize({"boss":String(boss.id),"weapon":"pulse_needle","difficulty":"deep","seed":881233,"mode":"story"})
		add_child(run)
		run.set_physics_process(false)
		run.set_process(false)
		await get_tree().process_frame
		# Exercise the same lifecycle boundary as a completed intro. Factory
		# projectile helpers intentionally reject direct hostile spawns in INTRO.
		run.state = RunSceneClass.RunState.EXTERIOR
		for phase_index in BossPlanner.PHASE_COUNT:
			run._start_phase(phase_index)
			run.attack_timer = 0.0
			run._telegraph.clear()
			run._projectiles.clear_enemy()
			run._update_boss_attacks(0.0)
			var warning := run._telegraph.duplicate(true)
			var plan := warning.get("planner_plan",{}) as Dictionary
			_check(bool(plan.get("valid",false)) and int(plan.get("phase_index",-1)) == phase_index,"%s phase %d live combat must consume its authored planner rule" % [boss.id,phase_index+1])
			_check(run._boss_phase_attack_index == 1,"%s phase %d warning must expose its deterministic attack index" % [boss.id,phase_index+1])
			if String(plan.get("status","")) == BossPlanner.STATUS_ACTIVE:
				_check(String(plan.get("executor","")) == BossPlanner.EXECUTOR_FACTORY and String(warning.get("contract_family","")).is_empty() and String(plan.get("pattern_family","")).is_empty(),"%s phase %d ACTIVE warning cannot advertise obsolete generic pattern geometry" % [boss.id,phase_index+1])
			else:
				_check(String(plan.get("executor","")) == BossPlanner.EXECUTOR_PLANNER and String(warning.get("contract_family","")) == String(plan.get("pattern_family","")),"%s phase %d BASIC/DEGRADED warning must expose its exact Planner family" % [boss.id,phase_index+1])
			var warning_target := Vector2(warning.get("target_position",Vector2.INF))
			run._player.position += Vector2(90.0,0.0)
			run._telegraph.timer = 0.0
			run._update_boss_attacks(0.0)
			var runtime_spec_count := run._projectiles.enemy_active.size() + run._pending_boss_emissions.size()
			_check(runtime_spec_count > 0 and runtime_spec_count <= int(plan.get("projectile_budget",0)),"%s phase %d live combat must emit or schedule a nonzero budgeted wave" % [boss.id,phase_index+1])
			_check(is_equal_approx(run.attack_timer,float(plan.get("cadence_seconds",0.0))),"%s phase %d live combat must adopt its data-driven cadence" % [boss.id,phase_index+1])
			var factory_plan := warning.get("factory_plan",{}) as Dictionary
			if String(plan.get("status","")) == BossPlanner.STATUS_ACTIVE:
				var factory_context := factory_plan.get("context",{}) as Dictionary
				_check(BossPlanner.build_projectile_specs(plan,run._boss_visual.target_position(),warning_target,float(warning.safe_angle),run._difficulty_projectile_speed()).is_empty(),"%s phase %d ACTIVE live plan cannot expose a Planner projectile fallback" % [boss.id,phase_index+1])
				_check(bool(factory_plan.get("valid",false)) and (factory_plan.get("intact_tuning",{}) as Dictionary) == (plan.get("intact_tuning",{}) as Dictionary) and runtime_spec_count == (factory_plan.get("projectiles",[]) as Array).size() and Vector2(factory_context.get("player_position",Vector2.INF)).is_equal_approx(warning_target),"%s phase %d ACTIVE wave must execute the complete tuned Factory plan against the frozen telegraphed target" % [boss.id,phase_index+1])
			else:
				var expected_specs := BossPlanner.build_projectile_specs(plan,run._boss_visual.target_position(),warning_target,float(warning.safe_angle),run._difficulty_projectile_speed())
				_check(String(plan.get("executor","")) == BossPlanner.EXECUTOR_PLANNER and not expected_specs.is_empty() and factory_plan.is_empty() and run._pending_boss_emissions.is_empty() and run._projectiles.enemy_active.size() == expected_specs.size(),"%s phase %d BASIC/DEGRADED wave must retain the Planner path and frozen telegraphed target" % [boss.id,phase_index+1])
			run._projectiles.clear_enemy()
		run.projectiles_clear_and_enemies()
		run.queue_free()
		await get_tree().process_frame
	SaveManager.profile = original_profile
