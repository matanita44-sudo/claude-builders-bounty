extends Node

const Factory := preload("res://scripts/core/titan_attack_spec_factory.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const Planner := preload("res://scripts/core/boss_pattern_planner.gd")
const ProjectilePoolClass := preload("res://scripts/gameplay/projectile_pool.gd")
const EXPECTED_COUNTS := {
	"homing_eye": 3,
	"gravity_ring": 18,
	"bone_missiles": 7,
	"prism_lances": 3,
	"laser_wings": -1,
	"halo_barrier": -1,
	"suction_waves": -1,
	"chain_lightning": 4,
	"parasite_swarm": 5,
	"weapon_copy": 3,
	"echo_dash": 1,
	"false_weakpoints": 6,
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
		push_error("TITAN ATTACK SPEC FACTORY FAILURE: " + message)


func _run() -> void:
	_test_catalog_identity()
	_test_all_plans_are_bounded_and_deterministic()
	_test_edge_and_corner_safe_guidance()
	_test_cronus_mechanics()
	_test_hyperion_mechanics()
	_test_oceanus_mechanics()
	_test_mnemosyne_mechanics()
	_test_weapon_copy_archetypes()
	_test_invalid_context_fails_to_safe_bounds()
	_test_contract_filtering_and_runtime_pool()
	_test_validator_rejects_tampering()
	await _test_live_runtime_integration()
	print("INFINIDIVE TITAN ATTACK SPEC FACTORY TESTS: %d passed, %d failed" % [passed, failures.size()])
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_edge_and_corner_safe_guidance() -> void:
	var combat_bounds:=Factory.DEFAULT_COMBAT_BOUNDS as Rect2
	var corners: Array[Vector2]=[
		combat_bounds.position,
		Vector2(combat_bounds.end.x,combat_bounds.position.y),
		Vector2(combat_bounds.position.x,combat_bounds.end.y),
		combat_bounds.end,
	]
	for ability_id in Factory.ability_ids():
		for corner in corners:
			var plan:=Factory.build_attack(ability_id,_context({"combat_bounds":combat_bounds,"player_position":corner}))
			_check(bool(plan.get("valid",false)),"%s must resolve feasible safe guidance from combat corner %s" % [ability_id,corner])
			var clean_context:=plan.get("context",{}) as Dictionary
			_check(Vector2(clean_context.get("player_position",Vector2.INF)).is_equal_approx(corner),"%s edge targeting must preserve the exact frozen player snapshot at %s" % [ability_id,corner])
			var safe:=((plan.get("safe_paths",[]) as Array)[0] as Dictionary) if not (plan.get("safe_paths",[]) as Array).is_empty() else {}
			var safe_target:=Vector2(safe.get("safe_target",Vector2.INF))
			_check(_safe_disk_inside_bounds(safe_target,float(safe.get("safe_radius_px",0.0)),combat_bounds),"%s safe target must remain wholly inside combat bounds from %s" % [ability_id,corner])
			_check(_guidance_corridor_inside_bounds(safe,combat_bounds) and Vector2(safe.get("corridor_start",Vector2.INF)).is_equal_approx(corner),"%s absolute guidance corridor must start at the frozen corner and never leave combat bounds" % ability_id)
			_check(float(safe.get("arrival_seconds",INF))<=float(safe.get("reaction_seconds",0.0))+0.001,"%s safe target must be reachable before the corner telegraph expires" % ability_id)
			_check(_runtime_safe_target_survives(plan),"%s projectile/effect sweep must clear the published corner safe target for the authored horizon" % ability_id)

	var named_side_attacks:=["homing_eye","bone_missiles","parasite_swarm","echo_dash"]
	var edge_cases:=[
		{"position":Vector2(combat_bounds.position.x,combat_bounds.get_center().y),"outward":Vector2.LEFT},
		{"position":Vector2(combat_bounds.end.x,combat_bounds.get_center().y),"outward":Vector2.RIGHT},
		{"position":Vector2(combat_bounds.get_center().x,combat_bounds.position.y),"outward":Vector2.UP},
		{"position":Vector2(combat_bounds.get_center().x,combat_bounds.end.y),"outward":Vector2.DOWN},
	]
	for ability_id in named_side_attacks:
		for raw_edge_case in edge_cases:
			var edge_case:=raw_edge_case as Dictionary
			var edge_position:=Vector2(edge_case.position)
			var plan:=Factory.build_attack(String(ability_id),_context({"combat_bounds":combat_bounds,"player_position":edge_position}))
			_check(bool(plan.get("valid",false)),"%s must resolve absolute guidance from edge midpoint %s" % [ability_id,edge_position])
			var safe:=((plan.safe_paths as Array)[0] as Dictionary) if bool(plan.get("valid",false)) else {}
			var safe_target:=Vector2(safe.get("safe_target",Vector2.INF))
			var movement:=safe_target-edge_position
			_check(movement.length()>=Factory.MIN_SAFE_CLEARANCE_PX-0.001,"%s edge guidance must produce a meaningful escape rather than a wall-clamped no-op" % ability_id)
			_check(movement.dot(Vector2(edge_case.outward))<=0.001,"%s edge guidance cannot point outward from player combat bounds" % ability_id)
			var aimed_direction:=(edge_position-Vector2((plan.context as Dictionary).origin)).normalized()
			var expected_side:=1 if aimed_direction.cross(movement)>0.0 else -1
			_check(int(safe.get("resolved_side",0))==expected_side,"%s safe-side metadata must describe the resolved absolute edge target" % ability_id)
			_check(_runtime_safe_target_survives(plan),"%s named edge attack must keep every runtime hazard outside its resolved target" % ability_id)

	var outside_tamper:=Factory.build_attack("homing_eye",_context()).duplicate(true)
	((outside_tamper.safe_paths as Array)[0] as Dictionary).safe_target=Vector2(-500.0,-500.0)
	_check(not Factory.validate_attack_plan(outside_tamper).is_empty(),"Validator must reject absolute guidance outside player combat bounds")
	var projectile_tamper:=Factory.build_attack("bone_missiles",_context()).duplicate(true)
	(((projectile_tamper.projectiles as Array)[0] as Dictionary).options as Dictionary).erase("safe_position")
	_check(not Factory.validate_attack_plan(projectile_tamper).is_empty(),"Validator must reject a projectile which drops the compiled safe target")
	var echo_tamper:=Factory.build_attack("echo_dash",_context()).duplicate(true)
	var echo_path:=((_effect(echo_tamper,"recorded_dash_danger_trail").path_points) as Array)
	((echo_tamper.safe_paths as Array)[0] as Dictionary).safe_target=Vector2(echo_path[0])
	_check(not Factory.validate_attack_plan(echo_tamper).is_empty(),"Validator must reject an Echo target inside the recorded danger trail")
	var constrained_bounds:=Rect2(150.0,500.0,240.0,260.0)
	var saturating_dash_path:=[
		Vector2(184.0,534.0),Vector2(218.0,726.0),Vector2(252.0,534.0),Vector2(286.0,726.0),
		Vector2(320.0,534.0),Vector2(354.0,726.0),Vector2(354.0,534.0),Vector2(184.0,726.0),
	]
	var infeasible_echo:=Factory.build_attack("echo_dash",_context({"combat_bounds":constrained_bounds,"player_position":constrained_bounds.get_center(),"dash_path":saturating_dash_path}))
	_check(not bool(infeasible_echo.get("valid",true)) and String(infeasible_echo.get("reason",""))=="infeasible_safe_guidance","Factory must fail closed when authored hazard geometry leaves no reachable safe target")


func _context(overrides: Dictionary = {}) -> Dictionary:
	var result := {
		"arena": Rect2(22.0, 228.0, 496.0, 692.0),
		"origin": Vector2(270.0, 282.0),
		"player_position": Vector2(306.0, 792.0),
		"safe_angle": 1.23,
		"seed": 774411,
		"attack_index": 8,
		"phase_index": 1,
		"speed_multiplier": 1.0,
		"weapon_archetype": "pulse",
		"dash_path": [Vector2(202.0, 802.0), Vector2(245.0, 744.0), Vector2(316.0, 704.0)],
	}
	result.merge(overrides, true)
	return result


func _test_catalog_identity() -> void:
	var errors := Factory.validate_catalog()
	_check(errors.is_empty(), "Twelve-ability blueprint catalog must validate: %s" % "; ".join(errors))
	var ids := Factory.ability_ids()
	_check(ids.size() == 12, "Factory must own all twelve launch Titan abilities")
	_check(ids == Factory.ABILITY_IDS, "Public ability order must be stable and authored")
	var mechanics: Dictionary = {}
	var visuals: Dictionary = {}
	var causes: Dictionary = {}
	var safe_kinds: Dictionary = {}
	var visual_families: Dictionary = {}
	for ability_id in ids:
		var blueprint := Factory.blueprint_for(ability_id)
		_check(not blueprint.is_empty(), "%s must expose a data blueprint" % ability_id)
		_check(String(blueprint.cause_token) == "ability:%s" % ability_id, "%s cause must remain stable and attributable" % ability_id)
		_check(not mechanics.has(blueprint.mechanic), "%s cannot alias another ability compiler" % ability_id)
		_check(not visuals.has(blueprint.visual_token), "%s cannot reuse another ability visual" % ability_id)
		_check(not causes.has(blueprint.cause_token), "%s cannot reuse another damage cause" % ability_id)
		_check(not safe_kinds.has(blueprint.safe_kind), "%s must teach a distinct safe-path rule" % ability_id)
		mechanics[blueprint.mechanic] = ability_id
		visuals[blueprint.visual_token] = ability_id
		causes[blueprint.cause_token] = ability_id
		safe_kinds[blueprint.safe_kind] = ability_id
		var visual_family:=ProjectilePoolClass.enemy_visual_family(String(blueprint.visual_token),"","linear")
		_check(not visual_families.has(visual_family),"%s must render with a distinct hostile silhouette family" % ability_id)
		visual_families[visual_family]=ability_id
		blueprint["mechanic"] = "caller_mutation"
		_check(String(Factory.blueprint_for(ability_id).mechanic) != "caller_mutation", "%s blueprint access must be copy-safe" % ability_id)
	_check(mechanics.size() == 12 and visuals.size() == 12 and causes.size() == 12 and safe_kinds.size() == 12 and visual_families.size()==12, "All launch abilities must remain mechanically and perceptually unique")
	var player_bearing:=1.48
	var keyed_angle:=Factory.deterministic_safe_angle(774411,"gravemaw",1,8,player_bearing)
	_check(is_equal_approx(keyed_angle,Factory.deterministic_safe_angle(774411,"gravemaw",1,8,player_bearing)),"Safe-angle derivation must be deterministic and independent of shared visual/audio RNG")
	_check(absf(wrapf(keyed_angle-player_bearing,-PI,PI))<=0.58001,"Keyed ring opening must stay inside the frozen player's reachable lower sector")
	_check(not is_equal_approx(keyed_angle,Factory.deterministic_safe_angle(774411,"gravemaw",1,9,player_bearing)),"Distinct attack indices must not reuse one fixed safe angle")


func _test_all_plans_are_bounded_and_deterministic() -> void:
	var fingerprints: Dictionary = {}
	for ability_id in Factory.ability_ids():
		var context := _context()
		var context_before := context.duplicate(true)
		var first := Factory.build_attack(ability_id, context)
		var second := Factory.build_attack(ability_id, context)
		_check(first == second, "%s plan must be deterministic for identical supplied context" % ability_id)
		_check(context == context_before, "%s factory must not mutate caller context" % ability_id)
		_check(bool(first.valid), "%s intact plan must compile" % ability_id)
		var validation_errors := Factory.validate_attack_plan(first)
		_check(validation_errors.is_empty(), "%s compiled plan must validate: %s" % [ability_id, "; ".join(validation_errors)])
		var projectiles := first.projectiles as Array
		_check(not projectiles.is_empty() and projectiles.size() <= int(first.projectile_budget), "%s must emit a non-zero bounded projectile set" % ability_id)
		if int(EXPECTED_COUNTS[ability_id]) >= 0:
			_check(projectiles.size() == int(EXPECTED_COUNTS[ability_id]), "%s must preserve its exact authored projectile count" % ability_id)
		else:
			_check(projectiles.size() < int(first.projectile_budget), "%s safe opening must consume part of its projectile budget" % ability_id)
		_check((first.effect_directives as Array).size() >= 1 and (first.effect_directives as Array).size() <= Factory.MAX_EFFECT_DIRECTIVES, "%s must publish bounded non-projectile mechanics" % ability_id)
		_check((first.safe_paths as Array).size() == 1, "%s must publish exactly one primary readable safe path" % ability_id)
		var safe_path := (first.safe_paths as Array)[0] as Dictionary
		_check(float(safe_path.minimum_clearance_px) >= Factory.MIN_SAFE_CLEARANCE_PX, "%s safe path must preserve player-scale clearance" % ability_id)
		_check(float(safe_path.reaction_seconds) >= Factory.MIN_TELEGRAPH_SECONDS, "%s safe path must publish sufficient reaction time" % ability_id)
		_check(String(safe_path.instruction_token).begins_with("safe:"), "%s safe path must expose a presentation token" % ability_id)
		_check(_all_projectiles_attributable(first), "%s projectiles must preserve cause, owner and visual identity" % ability_id)
		_check(_all_projectiles_finite(first), "%s projectile data must be finite and runtime bounded" % ability_id)
		var fingerprint := _mechanical_fingerprint(first)
		_check(not fingerprints.has(fingerprint), "%s emitted plan cannot alias another ability fingerprint" % ability_id)
		fingerprints[fingerprint] = ability_id
		var next_attack := Factory.build_attack(ability_id, _context({"attack_index": 9}))
		_check(String(next_attack.group_token) != String(first.group_token), "%s attack index must produce distinct deterministic wave ownership" % ability_id)
	_check(fingerprints.size() == 12, "All twelve intact abilities must compile to unique plan fingerprints")


func _test_cronus_mechanics() -> void:
	var homing := Factory.build_attack("homing_eye", _context())
	for raw_projectile in homing.projectiles:
		var options := (raw_projectile as Dictionary).options as Dictionary
		_check(String(options.travel_model) == "soft_homing" and float(options.homing) > 0.0, "Fate Eye must use real soft-homing travel")
		_check(Vector2(options.frozen_target).is_equal_approx(Vector2(306.0, 792.0)), "Fate Eye lock must snapshot the telegraphed player position")
	_check(String(_effect(homing, "target_lock").type) == "target_lock", "Fate Eye must publish its target-lock directive")

	var gravity := Factory.build_attack("gravity_ring", _context())
	_check(_travel_models(gravity) == ["expanding"], "Gravity Ring must be an expanding collision pattern")
	_check(String(_effect(gravity, "gravity_ring_pulse").type) == "gravity_ring_pulse", "Gravity Ring must publish a bounded radial force")
	_check(float(_effect(gravity, "gravity_ring_pulse").maximum_speed_delta) <= 82.0, "Gravity Ring force must have an explicit speed-delta cap")
	_check(_ring_gap_is_empty(gravity, 1.23, 0.62), "Gravity Ring must leave the telegraphed angular gap empty")

	var missiles := Factory.build_attack("bone_missiles", _context())
	var delays: Array[float] = []
	for raw_projectile in missiles.projectiles:
		delays.append(float(((raw_projectile as Dictionary).options as Dictionary).emission_delay_seconds))
	_check(delays.size() == 7 and delays[0] == 0.0 and delays[6] > 0.5, "Adamant missiles must be a seven-beat staggered salvo")
	_check(delays == delays.duplicate().map(func(value: float) -> float: return value), "Missile delay fixture must remain ordered")
	_check(int(_effect(missiles, "staggered_salvo").emission_count) == 7, "Missile effect must cap its authored emission count")


func _test_hyperion_mechanics() -> void:
	var prism := Factory.build_attack("prism_lances", _context())
	var prism_effect := _effect(prism, "prism_lane_sequence")
	_check((prism.projectiles as Array).size() == 3 and int(prism_effect.safe_lane_index) in [0, 1, 2, 3], "Prism Lances must attack three of four warned lanes")
	for raw_projectile in prism.projectiles:
		_check(Vector2((raw_projectile as Dictionary).velocity).is_equal_approx(Vector2.DOWN * 430.0), "Prism Lances must descend in precise vertical lanes")
	var safe_lane_x := float(((prism.safe_paths as Array)[0] as Dictionary).lane_center_x)
	_check(_minimum_projectile_origin_x_distance(prism, safe_lane_x) >= 80.0, "Prism safe lane must stay physically empty")

	var wings := Factory.build_attack("laser_wings", _context())
	var wing_effect := _effect(wings, "lane_afterglow")
	_check(not wing_effect.is_empty() and float(wing_effect.gap_half_width) >= 68.0, "Laser Wings must publish a wide persistent lane opening")
	_check(_minimum_projectile_origin_x_distance(wings, float(wing_effect.gap_center_x)) >= float(wing_effect.gap_half_width), "Laser Wing projectiles cannot spawn inside the safe corridor")

	var halo := Factory.build_attack("halo_barrier", _context())
	var barrier := _effect(halo, "temporary_boss_barrier")
	_check(not barrier.is_empty() and float(barrier.damage_reduction) > 0.0 and float(barrier.damage_reduction) < 0.5, "Halo Choir must create a bounded partial barrier, not invulnerability")
	_check(float(barrier.duration_seconds) <= 1.6, "Halo barrier must expire quickly")
	_check(_ring_gap_is_empty(halo, float(barrier.open_arc_angle), float(barrier.open_arc_half_width)), "Halo barrier must leave its warned rotating arc open")


func _test_oceanus_mechanics() -> void:
	var suction := Factory.build_attack("suction_waves", _context())
	var pull := _effect(suction, "bounded_pull")
	_check(not pull.is_empty(), "Suction Waves must publish an explicit pull directive")
	_check(float(pull.acceleration_px_per_second_sq) <= 88.0 and float(pull.maximum_speed_delta_px_per_second) <= 96.0, "Suction pull acceleration and velocity influence must be capped")
	_check(float(pull.maximum_position_delta_px) <= 56.0 and float(pull.duration_seconds) <= 1.45, "Suction pull displacement and duration must be capped")
	_check(_ring_gap_is_empty(suction, 1.23, 0.72), "Suction wave must preserve its calm channel")

	var chain := Factory.build_attack("chain_lightning", _context())
	var linked := _effect(chain, "linked_nodes")
	_check(_travel_models(chain) == ["node_link"], "Storm Palm must use the real node-link travel model")
	_check((linked.nodes as Array).size() == 4 and int(linked.maximum_hops) == 3, "Storm Palm must expose a four-node, three-hop chain bound")
	_check(int(((chain.safe_paths as Array)[0] as Dictionary).lane_index) in [0, 1, 2], "Storm Palm must leave one named unlinked lane")
	var safe_lane:=int(linked.safe_lane_index)
	var arena:=(_context().arena as Rect2)
	var lane_width:=arena.size.x/3.0
	var safe_left:=arena.position.x+lane_width*float(safe_lane)
	var safe_right:=safe_left+lane_width
	var links:=linked.links as Array
	_check(links.size()==4,"Storm node graph must publish four bounded within-lane links")
	for link_index in links.size():
		var link:=links[link_index] as Dictionary
		var projectile:=(chain.projectiles as Array)[link_index] as Dictionary
		var options:=projectile.options as Dictionary
		var origin:=Vector2(projectile.origin)
		var end:=origin+Vector2(projectile.velocity)*float(options.life)
		var curve_margin:=float((options.travel_parameters as Dictionary).link_amplitude)+float(options.radius)
		var remains_outside:=maxf(origin.x,end.x)+curve_margin<safe_left if int(link.lane_index)<safe_lane else minf(origin.x,end.x)-curve_margin>safe_right
		_check(int(link.lane_index)!=safe_lane and remains_outside,"Every full-lifetime Storm link must retire before entering the named safe lane")

	var parasites := Factory.build_attack("parasite_swarm", _context())
	var actors := _effect(parasites, "spawn_lunge_actors")
	_check(_travel_models(parasites) == ["lunge"], "River sprites must use windup-burst-recovery lunge travel")
	_check(int(actors.actor_cap) == 5 and (actors.actors as Array).size() == 5, "Parasite swarm must enforce its five-actor cap")
	for raw_projectile in parasites.projectiles:
		var options := (raw_projectile as Dictionary).options as Dictionary
		_check(float((options.travel_parameters as Dictionary).windup_seconds) >= 0.2, "Every river sprite must telegraph before its lunge burst")


func _test_mnemosyne_mechanics() -> void:
	var dash_path := [Vector2(202.0, 802.0), Vector2(245.0, 744.0), Vector2(316.0, 704.0)]
	var echo := Factory.build_attack("echo_dash", _context({"dash_path": dash_path}))
	var echo_options := (((echo.projectiles as Array)[0] as Dictionary).options as Dictionary)
	var echo_parameters := echo_options.travel_parameters as Dictionary
	_check(String(echo_options.travel_model) == "recorded_path", "Echo Heart must use recorded-path travel")
	_check((echo_parameters.path_points as Array) == dash_path, "Echo Heart must replay the supplied bounded player dash path exactly")
	_check(int(_effect(echo, "recorded_dash_danger_trail").point_cap) == 8, "Echo danger trail must expose the same eight-point input cap")

	var decoys := Factory.build_attack("false_weakpoints", _context())
	var decoy_effect := _effect(decoys, "spawn_decoy_weakpoints")
	_check(int(decoy_effect.decoy_count) == 3 and (decoy_effect.decoy_positions as Array).size() == 3, "Muse Veil must create exactly three visual decoy wounds")
	_check(not bool(decoy_effect.decoys_take_damage), "False wounds cannot secretly accept real boss damage")
	_check(int(decoy_effect.maximum_retaliation_shots) == 6 and (decoys.projectiles as Array).size() == 6, "False-wound retaliation must be explicitly capped at six shards")
	_check(Vector2(decoy_effect.true_position).is_equal_approx(Vector2(270.0, 282.0)), "False weakpoints must preserve the true target position in their directive")


func _test_weapon_copy_archetypes() -> void:
	var signatures: Dictionary = {}
	var expected_counts := {"pulse": 3, "scatter": 5, "rail": 1, "arc": 3, "orbitals": 6}
	for archetype in Factory.VALID_WEAPON_ARCHETYPES:
		var copy := Factory.build_attack("weapon_copy", _context({"weapon_archetype": archetype}))
		var effect := _effect(copy, "weapon_copy")
		_check(String(effect.source_archetype) == archetype, "Memory Crown must name copied %s archetype" % archetype)
		_check((copy.projectiles as Array).size() == int(expected_counts[archetype]), "%s copy must translate to a distinct bounded count" % archetype)
		var signature := "%s|%s|%d" % [effect.translation_rule, ",".join(_travel_models(copy)), (copy.projectiles as Array).size()]
		_check(not signatures.has(signature), "%s weapon copy translation cannot alias another archetype" % archetype)
		signatures[signature] = true
	_check(signatures.size() == 5, "All five launch weapons require distinct hostile translations")
	var invalid := Factory.build_attack("weapon_copy", _context({"weapon_archetype": "unsupported"}))
	_check(String(_effect(invalid, "weapon_copy").source_archetype) == "pulse", "Unknown copy archetype must fail closed to the readable pulse translation")


func _test_invalid_context_fails_to_safe_bounds() -> void:
	var oversized_path: Array = []
	for index in 20:
		oversized_path.append(Vector2(-10000.0 + float(index) * 1000.0, 10000.0))
	var invalid_context := {
		"arena": Rect2(0.0, 0.0, 10.0, 10.0),
		"origin": Vector2(NAN, INF),
		"player_position": Vector2(INF, NAN),
		"safe_angle": INF,
		"seed": "not-an-int",
		"attack_index": -999,
		"phase_index": 999,
		"speed_multiplier": INF,
		"weapon_archetype": "unknown",
		"dash_path": oversized_path,
	}
	for ability_id in Factory.ability_ids():
		var plan := Factory.build_attack(ability_id, invalid_context)
		_check(bool(plan.valid), "%s must sanitize malformed context into a playable plan" % ability_id)
		_check(Factory.validate_attack_plan(plan).is_empty(), "%s sanitized plan must remain valid" % ability_id)
		_check(_all_projectiles_finite(plan), "%s sanitized plan must contain only finite bounded projectiles" % ability_id)
		var clean := plan.context as Dictionary
		_check((clean.arena as Rect2) == Factory.DEFAULT_ARENA, "%s invalid arena must fall back to production bounds" % ability_id)
		_check(float(clean.speed_multiplier) == 1.0 and String(clean.weapon_archetype) == "pulse", "%s invalid scalar context must fail closed" % ability_id)
		_check((clean.dash_path as Array).size() <= 8, "%s dash history must never exceed the recorded-path cap" % ability_id)
	_check(not bool(Factory.build_attack("unknown", _context()).valid), "Unknown ability ids must fail closed")


func _test_contract_filtering_and_runtime_pool() -> void:
	var active := {"ability_id": "homing_eye", "status": "active", "runtime_enabled": true, "strength": 1.0}
	var degraded := {"ability_id": "gravity_ring", "status": "degraded", "runtime_enabled": true, "strength": 0.5}
	var disabled_status := {"ability_id": "bone_missiles", "status": "disabled", "runtime_enabled": true, "strength": 1.0}
	var disabled_runtime := {"ability_id": "prism_lances", "status": "active", "runtime_enabled": false, "strength": 1.0}
	var disabled_strength := {"ability_id": "laser_wings", "status": "active", "runtime_enabled": true, "strength": 0.0}
	_check(bool(Factory.build_attack("homing_eye", _context(), active).valid), "Active intact contract must compile")
	var degraded_plan := Factory.build_attack("gravity_ring", _context(), degraded)
	_check(bool(degraded_plan.valid) and is_equal_approx(float(degraded_plan.strength), 0.5), "Runtime-enabled degraded contract must compile at authored strength")
	_check(is_equal_approx(float(((degraded_plan.projectiles as Array)[0] as Dictionary).damage), 5.5), "Degraded strength must scale projectile damage exactly once")
	for disabled_case in [disabled_status, disabled_runtime, disabled_strength]:
		var ability_id := String((disabled_case as Dictionary).ability_id)
		var filtered := Factory.build_attack(ability_id, _context(), disabled_case)
		_check(not bool(filtered.valid) and bool(filtered.filtered) and String(filtered.reason) == "organ_disabled", "%s disabled organ contract must be mechanically filtered" % ability_id)
		_check((filtered.projectiles as Array).is_empty(), "%s disabled ability cannot leak projectile specs" % ability_id)
	var mismatch := Factory.build_attack("homing_eye", _context(), {"ability_id": "gravity_ring", "runtime_enabled": true})
	_check(not bool(mismatch.valid) and bool(mismatch.filtered) and String(mismatch.reason) == "contract_ability_mismatch", "Contract/ability mismatch must fail closed")

	var runtime_pool := Factory.build_runtime_pool([disabled_strength, degraded, active, disabled_runtime, disabled_status], _context())
	_check(bool(runtime_pool.valid), "Mixed runtime pool must validate after disabled filtering")
	var attacks := runtime_pool.attacks as Array
	_check(attacks.size() == 2, "Runtime pool must retain only active and degraded abilities")
	_check(String((attacks[0] as Dictionary).ability_id) == "homing_eye" and String((attacks[1] as Dictionary).ability_id) == "gravity_ring", "Runtime pool ordering must follow the stable catalog, not input order")
	_check(runtime_pool.filtered_ability_ids == ["bone_missiles", "prism_lances", "laser_wings"], "Runtime pool must report every organ-filtered ability deterministically")
	var malformed_pool := Factory.build_runtime_pool([active, active, {"ability_id": "unknown", "runtime_enabled": true}], _context())
	_check(not bool(malformed_pool.valid) and (malformed_pool.errors as Array).size() >= 2, "Duplicate and unknown runtime contracts must reject the pool")


func _test_validator_rejects_tampering() -> void:
	var baseline := Factory.build_attack("suction_waves", _context())
	var overflow := baseline.duplicate(true)
	for extra_index in 30:
		(overflow.projectiles as Array).append(((baseline.projectiles as Array)[0] as Dictionary).duplicate(true))
	_check(not Factory.validate_attack_plan(overflow).is_empty(), "Validator must reject projectile-budget overflow")
	var no_safe_path := baseline.duplicate(true)
	(no_safe_path.safe_paths as Array).clear()
	_check(not Factory.validate_attack_plan(no_safe_path).is_empty(), "Validator must reject attacks without a safe path")
	var unbounded_pull := baseline.duplicate(true)
	var effects := unbounded_pull.effect_directives as Array
	(effects[0] as Dictionary).bounded = false
	_check(not Factory.validate_attack_plan(unbounded_pull).is_empty(), "Validator must reject an unbounded effect directive")
	var wrong_cause := baseline.duplicate(true)
	(((wrong_cause.projectiles as Array)[0] as Dictionary).options as Dictionary).cause = "ability:other"
	_check(not Factory.validate_attack_plan(wrong_cause).is_empty(), "Validator must reject projectile cause laundering")
	var excessive_velocity := baseline.duplicate(true)
	((excessive_velocity.projectiles as Array)[0] as Dictionary).velocity = Vector2(5000.0, 0.0)
	_check(not Factory.validate_attack_plan(excessive_velocity).is_empty(), "Validator must reject excessive projectile velocity")


func _test_live_runtime_integration() -> void:
	var original_profile:=SaveManager.profile.duplicate(true)
	SaveManager.profile=SaveManager.default_profile()
	var run:=RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"deep","seed":774411,"mode":"story"})
	add_child(run)
	run.set_physics_process(false)
	run.set_process(false)
	await get_tree().process_frame
	# The helper is exercised at the same lifecycle boundary used after the intro
	# transition. ProjectilePool intentionally rejects hostile spawns in INTRO.
	run.state=RunSceneClass.RunState.EXTERIOR

	var boss:=_boss_definition("gravemaw")
	var active_plan:=_find_planner_plan(boss,[],"homing_eye")
	_check(bool(active_plan.valid) and String(active_plan.status)==Planner.STATUS_ACTIVE,"Live fixture must locate an intact planner-owned Fate Eye selection")
	var active_context:=_context({
		"origin":run._boss_visual.target_position(),
		"player_position":run._player.position,
		"attack_index":int(active_plan.attack_index),
		"phase_index":int(active_plan.phase_index),
		"projectile_budget_cap":int(active_plan.projectile_budget),
	})
	var active_factory:=Factory.build_attack("homing_eye",active_context,{"ability_id":"homing_eye","status":"active","runtime_enabled":true,"strength":1.0})
	var planner_specs:=Planner.build_projectile_specs(active_plan,run._boss_visual.target_position(),run._player.position,1.23,1.0)
	run._spawn_attack("homing_eye",1.23,run._dash_count,{"ability_id":"homing_eye","status":"active"},active_plan,run._player.position,active_factory)
	_check(run._projectiles.enemy_active.size()==(active_factory.projectiles as Array).size(),"ACTIVE runtime must spawn Factory specs exactly")
	_check(run._projectiles.enemy_active.size()!=planner_specs.size(),"ACTIVE runtime must not silently fall back to the old planner projectile alias")
	_check((run._active_boss_effects as Array).size()==1 and String((run._active_boss_effects[0] as Dictionary).type)=="target_lock","ACTIVE runtime must consume Factory effect directives")
	var active_group:=String((run._projectiles.enemy_active[0] as Dictionary).group)
	_check(active_group.begins_with("boss_attack:") and run._attack_avoidance_candidates.has(active_group),"Factory projectile ownership must be rebound to the live boss wave")
	var active_safe:=((active_factory.safe_paths as Array)[0] as Dictionary)
	_check((run._projectiles.enemy_active as Array).all(func(projectile: Dictionary)->bool:return Vector2(projectile.safe_position).is_equal_approx(Vector2(active_safe.safe_target)) and float(projectile.safe_radius)>=float(active_safe.safe_radius_px)),"ACTIVE runtime must preserve the exact Factory safe disk on every live projectile")

	run.projectiles_clear_and_enemies()
	var basic_plan:=_find_planner_plan(boss,[],Planner.BASIC_ABILITY)
	var basic_specs:=Planner.build_projectile_specs(basic_plan,run._boss_visual.target_position(),run._player.position,1.23,1.0)
	run._spawn_attack(Planner.BASIC_ABILITY,1.23,run._dash_count,{"ability_id":Planner.BASIC_ABILITY,"status":Planner.STATUS_BASIC},basic_plan,run._player.position,{})
	_check(run._projectiles.enemy_active.size()==basic_specs.size(),"BASIC phase fallback must remain compiled by BossPatternPlanner")
	_check(run._active_boss_effects.is_empty(),"BASIC fallback cannot fabricate Factory-only effects")

	run.projectiles_clear_and_enemies()
	var degraded_plan:=_find_planner_plan(boss,["hunter_eye"],"homing_eye")
	var degraded_specs:=Planner.build_projectile_specs(degraded_plan,run._boss_visual.target_position(),run._player.position,1.23,1.0)
	run._spawn_attack("homing_eye",1.23,run._dash_count,{"ability_id":"homing_eye","status":Planner.STATUS_DEGRADED},degraded_plan,run._player.position,{})
	_check(String(degraded_plan.status)==Planner.STATUS_DEGRADED and run._projectiles.enemy_active.size()==degraded_specs.size(),"DEGRADED organ replacement must remain compiled by BossPatternPlanner")
	_check(run._active_boss_effects.is_empty(),"DEGRADED replacement cannot reactivate its intact Factory mechanic")

	run.projectiles_clear_and_enemies()
	var bone:=Factory.build_attack("bone_missiles",active_context)
	run._spawn_attack("bone_missiles",1.23,run._dash_count,{"ability_id":"bone_missiles","status":"active"},{"valid":true,"status":"active"},run._player.position,bone)
	_check(run._projectiles.enemy_active.size()==1 and run._pending_boss_emissions.size()==6,"Staggered bone salvo must spawn beat zero and queue six real delayed emissions")
	var bone_group:=String((run._projectiles.enemy_active[0] as Dictionary).group)
	run._projectiles.clear_enemy()
	run._update_attack_avoidance([])
	_check(run._attack_avoidance_candidates.has(bone_group),"Avoidance ownership must survive a temporary gap while delayed emissions remain pending")
	run._update_pending_boss_emissions(0.6)
	_check(run._pending_boss_emissions.is_empty() and run._projectiles.enemy_active.size()==6,"Delayed emission scheduler must release every remaining salvo beat once")
	_check((run._projectiles.enemy_active as Array).all(func(projectile: Dictionary)->bool:return String(projectile.group)==bone_group),"Every delayed projectile must retain the live wave group")

	run.projectiles_clear_and_enemies()
	var rail_copy:=Factory.build_attack("weapon_copy",_context({"origin":run._boss_visual.target_position(),"player_position":run._player.position,"weapon_archetype":"rail"}))
	run._spawn_attack("weapon_copy",1.23,run._dash_count,{"ability_id":"weapon_copy","status":"active"},{"valid":true,"status":"active"},run._player.position,rail_copy)
	_check(run._projectiles.enemy_active.is_empty() and run._pending_boss_emissions.size()==1,"A fully delayed copied Rail shot must remain queued rather than spawning early")
	_check(run._attack_avoidance_candidates.size()==1,"A fully delayed Factory wave must still receive avoidance ownership")
	run._update_pending_boss_emissions(0.2)
	_check(run._projectiles.enemy_active.size()==1 and run._pending_boss_emissions.is_empty(),"Copied Rail delay must resolve to one live projectile")

	run.projectiles_clear_and_enemies()
	var halo:=Factory.build_attack("halo_barrier",active_context)
	run._activate_factory_effects(halo,"barrier:test")
	_check(is_equal_approx(run._active_boss_barrier_multiplier(),0.65),"Halo directive must become a real 35% boss-damage barrier")
	run.state=RunSceneClass.RunState.EXTERIOR
	run.armor_max=1000.0
	run.armor_health=1000.0
	run._damage_target({"id":"boss","damage":100.0,"behavior":"pulse"})
	_check(is_equal_approx(run.armor_health,935.0),"Boss damage routing must apply the live barrier multiplier exactly once")

	run._clear_boss_attack_runtime()
	var suction:=Factory.build_attack("suction_waves",active_context)
	run._activate_factory_effects(suction,"pull:test")
	run._player.position=Vector2(24.0,650.0)
	run._player.velocity=Vector2.ZERO
	var position_before:=run._player.position
	run._update_active_boss_effects(0.5)
	var pull_effect:=run._active_boss_effects[0] as Dictionary
	_check(float(pull_effect.applied_speed_delta)>0.0 and float(pull_effect.applied_speed_delta)<=96.0,"Bounded pull must apply a non-zero velocity change under its authored cap")
	_check(float(pull_effect.applied_position_delta)<=56.0 and position_before.distance_to(run._player.position)<=56.0,"Bounded pull must preserve its direct displacement cap")
	run._clear_boss_attack_runtime()
	run._activate_factory_effects(suction,"pull-safe:test")
	var pull_origin:=Vector2((suction.context as Dictionary).origin)
	var calm_position:=pull_origin+Vector2.from_angle(float(((suction.safe_paths as Array)[0] as Dictionary).center_angle))*390.0
	run._player.position=Vector2(clampf(calm_position.x,24.0,516.0),clampf(calm_position.y,395.0,845.0))
	run._player.velocity=Vector2.ZERO
	position_before=run._player.position
	run._update_active_boss_effects(0.5)
	pull_effect=run._active_boss_effects[0] as Dictionary
	_check(is_zero_approx(float(pull_effect.applied_speed_delta)) and run._player.position.is_equal_approx(position_before),"Published calm channel must suppress the live suction force completely")

	run._clear_boss_attack_runtime()
	var decoys:=Factory.build_attack("false_weakpoints",active_context)
	run._activate_factory_effects(decoys,"decoy:test")
	var decoy_targets:=run._active_decoy_targets()
	_check(decoy_targets.size()==3 and run._active_decoy_aim_target() is Vector2,"Decoy directive must create three live targets and redirect assisted aim")
	var armor_before:=run.armor_health
	run._damage_target({"id":String(decoy_targets[0].id),"damage":999.0,"behavior":"pulse"})
	_check(is_equal_approx(run.armor_health,armor_before),"A false weakpoint hit must never damage the real Titan")
	_check(int((run._active_boss_effects[0] as Dictionary).decoy_hit_count)==1,"Decoy hit routing must record visible disruption feedback")

	run._clear_boss_attack_runtime()
	var echo_path:=[Vector2(190.0,790.0),Vector2(270.0,720.0),Vector2(340.0,700.0)]
	var echo:=Factory.build_attack("echo_dash",_context({"origin":run._boss_visual.target_position(),"player_position":run._player.position,"dash_path":echo_path}))
	run._activate_factory_effects(echo,"echo:test")
	run._player.position=Vector2(270.0,720.0)
	run._player.invulnerability=0.0
	var health_before:=run._player.health
	run._update_active_boss_effects(0.016)
	_check(run._player.health<health_before and int((run._active_boss_effects[0] as Dictionary).hit_count)==1,"Recorded dash trail must be a real attributable one-hit hazard")
	run._player.invulnerability=0.0
	var health_after_first:=run._player.health
	run._update_active_boss_effects(0.016)
	_check(is_equal_approx(run._player.health,health_after_first),"Recorded dash trail maximum-hit cap must prevent repeated damage")

	run._clear_boss_attack_runtime()
	var wing:=Factory.build_attack("laser_wings",active_context)
	run._activate_factory_effects(wing,"wing:test")
	var wing_effect:=run._active_boss_effects[0] as Dictionary
	run._player.position=Vector2(float((wing_effect.lane_xs as Array)[0]),650.0)
	run._player.invulnerability=0.0
	wing_effect.elapsed=(run._player.position.y-float(wing_effect.origin_y))/float(wing_effect.travel_speed)
	run._active_boss_effects[0]=wing_effect
	health_before=run._player.health
	run._apply_lane_afterglow(run._active_boss_effects[0] as Dictionary)
	_check(run._player.health<health_before and int((run._active_boss_effects[0] as Dictionary).hit_count)==1,"Laser lane directive must create a moving, capped afterglow hazard")

	run._clear_boss_attack_runtime()
	run._last_completed_dash_path.clear()
	run._player.position=Vector2(230.0,790.0)
	run._player.dash_time=0.12
	run._on_dash_started()
	run._player.position=Vector2(270.0,750.0)
	run._update_dash_path_recording()
	run._player.position=Vector2(330.0,705.0)
	run._player.dash_time=0.0
	run._update_dash_path_recording()
	_check(run._last_completed_dash_path.size()>=3 and run._last_completed_dash_path.size()<=RunSceneClass.BOSS_DASH_PATH_MAX_POINTS,"RunScene must record the completed real dash path within the Factory point cap")
	_check(Vector2(run._last_completed_dash_path.back()).is_equal_approx(Vector2(330.0,705.0)),"Recorded dash path must retain the actual final player position")

	run._boss_phase_attack_index=7
	run._pending_boss_emissions=[{"remaining":1.0,"wave_id":"stale","spec":{}}]
	run._active_boss_effects=[{"type":"target_lock","remaining":1.0}]
	run.phase=2
	run._return_outside()
	_check(run.state==RunSceneClass.RunState.CORE and run.phase==3,"Third organ return must enter the real Core state")
	_check(run._boss_phase_attack_index==0 and run._pending_boss_emissions.is_empty() and run._active_boss_effects.is_empty(),"Core entry must begin a fresh deterministic attack cycle without stale phase hazards")
	var core_seed:=1
	while core_seed<1000 and String(Planner.build_plan(boss,2,[],core_seed,0).get("status",""))!=Planner.STATUS_ACTIVE:
		core_seed+=1
	run.config.seed=core_seed
	run.attack_timer=0.0
	run._telegraph.clear()
	var core_target:=run._player.position
	run._update_boss_attacks(0.016)
	var core_warning:=run._telegraph as Dictionary
	var core_planner:=core_warning.get("planner_plan",{}) as Dictionary
	var core_factory:=core_warning.get("factory_plan",{}) as Dictionary
	_check(bool(core_planner.get("valid",false)) and int(core_planner.phase_index)==2 and int(core_planner.attack_index)==0,"Core must clamp to authored exterior phase three and execute attack index zero")
	_check(bool(core_factory.get("valid",false)),"Core ACTIVE ability must route through the Titan Factory instead of going silent")
	_check(is_equal_approx(float((core_factory.context as Dictionary).speed_multiplier),1.08),"Core Factory speed must include the phase-three 1.08 multiplier")
	_check(Vector2((core_factory.context as Dictionary).player_position).is_equal_approx(core_target),"Core Factory target geometry must freeze at telegraph start")
	var core_safe:=((core_factory.safe_paths as Array)[0] as Dictionary)
	_check((core_factory.context as Dictionary).combat_bounds==run._player.combat_bounds and Vector2(core_warning.safe_position).is_equal_approx(Vector2(core_safe.safe_target)),"RunScene must render the same combat-bounded absolute target validated by the Factory")
	var core_bearing:=(core_target-Vector2((core_factory.context as Dictionary).origin)).angle()
	_check(absf(wrapf(float((core_factory.context as Dictionary).safe_angle)-core_bearing,-PI,PI))<=0.58001,"Core safe opening must remain reachable from the frozen player bearing")

	run._telegraph.clear()
	run._clear_boss_attack_runtime()
	run.state=RunSceneClass.RunState.EXTERIOR
	run._player.health=1.0
	run._player.invulnerability=0.0
	run._player.position=Vector2(270.0,720.0)
	run._activate_factory_effects(echo,"lethal-echo:test")
	run._update_active_boss_effects(0.016)
	_check(run.state==RunSceneClass.RunState.DEAD and run._active_boss_effects.is_empty(),"Lethal direct effect must complete death cleanup without indexing the synchronously cleared effect array")

	run.projectiles_clear_and_enemies()
	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile=original_profile


func _boss_definition(boss_id: String) -> Dictionary:
	for raw_boss in GameData.bosses:
		var boss:=raw_boss as Dictionary
		if String(boss.get("id",""))==boss_id:
			return boss
	return {}


func _find_planner_plan(boss: Dictionary, destroyed_organs: Array, ability_id: String) -> Dictionary:
	for phase_index in 3:
		for attack_index in 32:
			var plan:=Planner.build_plan(boss,phase_index,destroyed_organs,774411,attack_index)
			if bool(plan.get("valid",false)) and String(plan.get("ability_id",""))==ability_id:
				return plan
	return {}


func _effect(plan: Dictionary, effect_type: String) -> Dictionary:
	for raw_effect in plan.get("effect_directives", []):
		var effect := raw_effect as Dictionary
		if String(effect.get("type", "")) == effect_type:
			return effect
	return {}


func _travel_models(plan: Dictionary) -> Array[String]:
	var models: Array[String] = []
	for raw_projectile in plan.projectiles:
		var model := String((((raw_projectile as Dictionary).options as Dictionary).get("travel_model", "linear")))
		if model not in models:
			models.append(model)
	models.sort()
	return models


func _mechanical_fingerprint(plan: Dictionary) -> String:
	var effect_types: Array[String] = []
	for raw_effect in plan.effect_directives:
		effect_types.append(String((raw_effect as Dictionary).type))
	effect_types.sort()
	return "%s|%s|%s|%s" % [String(plan.mechanic), ",".join(_travel_models(plan)), ",".join(effect_types), String(((plan.safe_paths as Array)[0] as Dictionary).kind)]


func _all_projectiles_attributable(plan: Dictionary) -> bool:
	for raw_projectile in plan.projectiles:
		var options := (raw_projectile as Dictionary).options as Dictionary
		if String(options.cause) != String(plan.cause_token) or String(options.group) != String(plan.group_token) or String(options.visual_token) != String(plan.visual_token):
			return false
	return true


func _all_projectiles_finite(plan: Dictionary) -> bool:
	for raw_projectile in plan.projectiles:
		var projectile := raw_projectile as Dictionary
		var origin := Vector2(projectile.origin)
		var velocity := Vector2(projectile.velocity)
		var damage := float(projectile.damage)
		if not is_finite(origin.x) or not is_finite(origin.y) or not is_finite(velocity.x) or not is_finite(velocity.y) or not is_finite(damage):
			return false
		if velocity.length() <= 0.0 or velocity.length() > 1100.0 or damage <= 0.0 or damage > 20.0:
			return false
	return true


func _ring_gap_is_empty(plan: Dictionary, safe_angle: float, half_arc: float) -> bool:
	var origin := Vector2((plan.context as Dictionary).origin)
	for raw_projectile in plan.projectiles:
		var velocity := Vector2((raw_projectile as Dictionary).velocity)
		var projectile_origin := Vector2((raw_projectile as Dictionary).origin)
		if not projectile_origin.is_equal_approx(origin):
			continue
		if absf(wrapf(velocity.angle() - safe_angle, -PI, PI)) < half_arc - 0.0001:
			return false
	return true


func _minimum_projectile_origin_x_distance(plan: Dictionary, x: float) -> float:
	var result := INF
	for raw_projectile in plan.projectiles:
		result = minf(result, absf(Vector2((raw_projectile as Dictionary).origin).x - x))
	return result


func _safe_disk_inside_bounds(center: Vector2, radius: float, bounds: Rect2) -> bool:
	return center.is_finite() and radius>0.0 \
		and center.x-radius>=bounds.position.x-0.001 \
		and center.x+radius<=bounds.end.x+0.001 \
		and center.y-radius>=bounds.position.y-0.001 \
		and center.y+radius<=bounds.end.y+0.001


func _guidance_corridor_inside_bounds(safe: Dictionary, bounds: Rect2) -> bool:
	var start_value: Variant=safe.get("corridor_start",null)
	var end_value: Variant=safe.get("corridor_end",null)
	if not start_value is Vector2 or not end_value is Vector2:
		return false
	var start:=start_value as Vector2
	var finish:=end_value as Vector2
	if not start.is_finite() or not finish.is_finite():
		return false
	for sample_index in 33:
		var point:=start.lerp(finish,float(sample_index)/32.0)
		if point.x<bounds.position.x-0.001 or point.x>bounds.end.x+0.001 or point.y<bounds.position.y-0.001 or point.y>bounds.end.y+0.001:
			return false
	return finish.is_equal_approx(Vector2(safe.get("safe_target",Vector2.INF)))


func _runtime_safe_target_survives(plan: Dictionary) -> bool:
	if not bool(plan.get("valid",false)):
		return false
	var safe_paths:=plan.get("safe_paths",[]) as Array
	if safe_paths.size()!=1:
		return false
	var safe:=safe_paths[0] as Dictionary
	var target:=Vector2(safe.get("safe_target",Vector2.INF))
	var safe_radius:=float(safe.get("safe_radius_px",0.0))
	var pool:=ProjectilePoolClass.new()
	for raw_projectile in plan.projectiles:
		var projectile:=raw_projectile as Dictionary
		if not pool.spawn_enemy(Vector2(projectile.origin),Vector2(projectile.velocity),float(projectile.damage),(projectile.options as Dictionary).duplicate(true)):
			pool.free()
			return false
	if not _pool_clears_safe_disk(pool,target,safe_radius):
		pool.free()
		return false
	var remaining:=float(safe.get("hazard_horizon_seconds",0.0))
	while remaining>0.0001 and not pool.enemy_active.is_empty():
		var step:=minf(1.0/60.0,remaining)
		var result:=pool.step(step,[],target,12.0)
		if not (result.get("player_hits",[]) as Array).is_empty() or not _pool_clears_safe_disk(pool,target,safe_radius):
			pool.free()
			return false
		remaining-=step
	pool.free()
	return _safe_target_clears_direct_effects(plan,target,safe_radius)


func _pool_clears_safe_disk(pool: Node, target: Vector2, safe_radius: float) -> bool:
	for raw_bullet in pool.enemy_active:
		var bullet:=raw_bullet as Dictionary
		if Vector2(bullet.position).distance_to(target)-float(bullet.radius)<safe_radius-0.03:
			return false
	return true


func _safe_target_clears_direct_effects(plan: Dictionary, target: Vector2, safe_radius: float) -> bool:
	for raw_directive in plan.effect_directives:
		var directive:=raw_directive as Dictionary
		match String(directive.get("type","")):
			"lane_afterglow":
				for raw_x in directive.get("lane_xs",[]):
					if absf(target.x-float(raw_x))<safe_radius+float(directive.get("beam_half_width_px",8.0))-0.001:
						return false
			"recorded_dash_danger_trail":
				var path:=directive.get("path_points",[]) as Array
				for point_index in range(maxi(0,path.size()-1)):
					if _test_point_segment_distance(target,Vector2(path[point_index]),Vector2(path[point_index+1]))<safe_radius+float(directive.get("trail_radius_px",22.0))-0.001:
						return false
			"gravity_ring_pulse","bounded_pull":
				var center:=Vector2(directive.get("center",(plan.context as Dictionary).origin))
				var distance:=center.distance_to(target)
				if distance<=safe_radius:
					return false
				var angle_padding:=asin(clampf(safe_radius/distance,0.0,0.95))
				if absf(wrapf((target-center).angle()-float(directive.safe_angle),-PI,PI))+angle_padding>float(directive.safe_half_arc_radians)+0.001:
					return false
	return true


func _test_point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment:=finish-start
	if segment.length_squared()<=0.000001:
		return point.distance_to(start)
	var alpha:=clampf((point-start).dot(segment)/segment.length_squared(),0.0,1.0)
	return point.distance_to(start+segment*alpha)
