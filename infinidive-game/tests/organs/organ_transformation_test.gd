extends Node

const OrganMap := preload("res://scripts/core/organ_ability_map.gd")
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
	await _test_live_run_scene_consumption(bosses)
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
			var loss := organ.get("loss",{}) as Dictionary
			organ_count += 1
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
			_check(mapping.is_ability_runtime_enabled(ability_id) and String(intact.get("status","")) == OrganMap.STATUS_ACTIVE,"%s intact pattern must be runtime-selectable" % organ_id)
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
