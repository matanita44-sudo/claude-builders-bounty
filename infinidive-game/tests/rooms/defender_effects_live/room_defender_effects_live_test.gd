extends Node

const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const Effects := preload("res://scripts/core/room_defender_effects.gd")

var passed := 0
var failures: Array[String] = []
var live_operations: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("ROOM DEFENDER EFFECTS LIVE FAILURE: " + message)


func _run() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run := RunSceneClass.new()
	run.initialize({
		"boss":"gravemaw",
		"weapon":"pulse_needle",
		"difficulty":"deep",
		"seed":620041,
		"mode":"story",
		"competitive":false,
	})
	add_child(run)
	run.set_process(false)
	run.set_physics_process(false)
	run._player.set_physics_process(false)
	run._player.set_process_unhandled_input(false)

	for raw_archetype in Effects.EXPECTED_ARCHETYPE_ROLES.keys():
		_test_archetype(run,String(raw_archetype),String(Effects.EXPECTED_ARCHETYPE_ROLES[raw_archetype]))
	for raw_operation in Effects.OPERATION_IDS:
		var operation := String(raw_operation)
		_check(live_operations.has(operation),"Operation %s must produce a live state mutation" % operation)

	_test_successor_lineage_after_source_clear(run)
	_test_frozen_suppression_does_not_rebuild(run)
	_test_organ_cycle_effect_cleanup(run)
	_test_boundary_cleanup(run)
	run.projectiles_clear_and_enemies()
	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	print("INFINIDIVE ROOM DEFENDER EFFECTS LIVE TESTS: %d passed, %d failed" % [passed,failures.size()])
	AudioManager.shutdown_for_tests()
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_archetype(run: Node, archetype: String, role: String) -> void:
	var prepared := _prepare_case(run,archetype,role)
	var source_wave := String(prepared.source_wave)
	var actor_owner := String(prepared.actor_owner)
	var foreign_wave := String(prepared.foreign_wave)
	var effect_scope_id := String(prepared.effect_scope_id)
	var foreign_effect_scope_id := String(prepared.foreign_effect_scope_id)
	var source_enemy := prepared.source_enemy as Dictionary
	var projectile_count_before: int = run._projectiles.enemy_group_size(source_wave)
	var state_count_before := int(run._room_defender_effect_state.get("kill_effects_applied",0))
	var queued_tracking_emission: Dictionary = {}
	var queued_nonhoming_emission: Dictionary = {}
	if archetype=="tracker_mite":
		var queued_spec := _projectile_spec("linear",1.8)
		var queued_options := queued_spec.options as Dictionary
		queued_options.effect_scope_id=effect_scope_id
		queued_options.source_archetype=archetype
		queued_options.group=source_wave
		queued_options.parent_group=source_wave
		queued_spec.options=queued_options
		queued_tracking_emission=run._freeze_room_emission(queued_spec,_event_for(archetype,effect_scope_id),source_wave,800,run._room_elapsed+1.0)
		var queued_nonhoming_spec := _projectile_spec("soft_homing",0.0)
		var queued_nonhoming_options := queued_nonhoming_spec.options as Dictionary
		queued_nonhoming_options.effect_scope_id=effect_scope_id
		queued_nonhoming_options.source_archetype=archetype
		queued_nonhoming_options.group=source_wave
		queued_nonhoming_options.parent_group=source_wave
		queued_nonhoming_spec.options=queued_nonhoming_options
		queued_nonhoming_emission=run._freeze_room_emission(queued_nonhoming_spec,_event_for(archetype,effect_scope_id),source_wave,801,run._room_elapsed+1.0)
		run._pending_room_emissions.append(queued_tracking_emission)
		run._pending_room_emissions.append(queued_nonhoming_emission)
	run._kill_enemy(int(prepared.source_index))
	_check(_enemy_by_id(run._enemies,String(source_enemy.id)).is_empty(),"%s kill must remove its live source defender" % archetype)
	var trace := _last_trace(run._room_runtime_trace,"defender_kill_effect")
	_check(not trace.is_empty(),"%s kill must execute and trace a compiled live effect" % archetype)
	_check(String(trace.get("source_defender_id",""))==String(source_enemy.id),"%s trace must retain its source defender" % archetype)
	_check(String(trace.get("owner_wave_id",""))==source_wave,"%s trace must retain transient source-wave ownership" % archetype)
	var scopes := run._room_defender_effect_state.get("scopes",{}) as Dictionary
	_check(scopes.has(effect_scope_id) and not scopes.has(foreign_effect_scope_id),"%s state patch must exist only in its bounded effect lineage" % archetype)
	var source_flags := ((scopes.get(effect_scope_id,{}) as Dictionary).get("flags",{}) as Dictionary)
	for raw_flag in source_flags.keys():
		var flag_id := String(raw_flag)
		_check(run._room_effect_flag_active(flag_id,effect_scope_id),"%s flag %s must be active in lineage A" % [archetype,flag_id])
		_check(not run._room_effect_flag_active(flag_id,foreign_effect_scope_id),"%s flag %s must not leak into unrelated lineage B" % [archetype,flag_id])
	for raw_result in trace.get("operation_results",[]) as Array:
		var result := raw_result as Dictionary
		if int(result.get("affected",0))>0:
			live_operations[String(result.get("op",""))]=true

	var second_application: Dictionary = run._apply_room_defender_kill_effect(source_enemy)
	_check(not bool(second_application.get("applied",false)),"%s kill effect must be idempotent by source defender" % archetype)
	_check(int(run._room_defender_effect_state.get("kill_effects_applied",0))==state_count_before+1,"%s duplicate application must not advance state" % archetype)

	match archetype:
		"armor_drone":
			_check(not run._room_defender_covers.is_empty(),"Armor Drone kill must spawn live timed cover")
			var before_absorb: int = run._projectiles.enemy_group_size(source_wave)
			run._update_room_defender_effects(1.0/60.0)
			_check(run._projectiles.enemy_group_size(source_wave)<before_absorb,"Timed cover must absorb an enemy projectile in its radius")
			run._update_room_defender_effects(6.0)
			_check(run._room_defender_covers.is_empty(),"Timed cover must expire without leaking into later room state")
		"pincer_hunter":
			var marked := _first_marked_enemy(run._enemies,source_wave)
			_check(not marked.is_empty(),"Pincer kill must mark a surviving priority target")
			if not marked.is_empty():
				var health_before := float(marked.health)
				run._damage_enemy_by_id(String(marked.id),10.0)
				var after := _enemy_by_id(run._enemies,String(marked.id))
				_check(not after.is_empty() and health_before-float(after.health)>10.5,"Priority mark must amplify live damage")
		"tracker_mite":
			var tracking_specs: Array = run._room_projectile_specs_after_defender_effects([
				_projectile_spec("soft_homing",1.8),
				_projectile_spec("soft_homing",0.0),
				_projectile_spec("linear",1.8),
				_projectile_spec("linear",0.0),
			],_event_for(archetype,effect_scope_id))
			_check(tracking_specs.size()==2 and _spec_exists(tracking_specs,"soft_homing",0.0) and _spec_exists(tracking_specs,"linear",0.0),"Tracking break must suppress every future actual-homing spec while preserving non-homing specs, including soft_homing travel")
			_check(_owned_homing_count(run,source_wave)==0,"Tracking break must clear already-live owned homing instead of straightening it")
			_check(_owned_nonhoming_soft_count(run,source_wave)==1,"Tracking break must preserve an active same-owner soft_homing projectile whose actual homing is zero")
			_check(run._projectiles.enemy_group_size(source_wave)==projectile_count_before-4,"Tracking break must remove exactly the owned linear-homing and soft-homing descendants without replacements")
			_check(_pending_emission_present(run._pending_room_emissions,source_wave,800) and _pending_emission_present(run._pending_room_emissions,source_wave,801),"Tracking break must preserve queued descendants until their authenticated spawn decision")
			_check(not run._spawn_room_projectile_spec(queued_tracking_emission),"Tracking break must suppress a previously queued linear-homing emission at spawn time")
			_check(run._projectiles.enemy_group_size(source_wave)==projectile_count_before-4,"Suppressed queued homing must not create a straight-path replacement")
			_check(run._spawn_room_projectile_spec(queued_nonhoming_emission),"Tracking break must allow a previously queued non-homing soft_homing emission")
			_check(run._projectiles.enemy_group_size(source_wave)==projectile_count_before-3 and _owned_nonhoming_soft_count(run,source_wave)==2,"Allowed queued non-homing soft_homing must spawn exactly once without replacing a suppressed path")
			var foreign_tracking: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("soft_homing",1.8)],_event_for(archetype,foreign_effect_scope_id))
			_check(foreign_tracking.size()==1 and float(((foreign_tracking[0] as Dictionary).options as Dictionary).get("homing",0.0))>0.0 and _owned_homing_count(run,foreign_wave)==1,"Tracking break in wave A must not alter wave B specs or active homing")
		"arc_linker":
			var linked_specs: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("node_link",0.0)],_event_for(archetype,effect_scope_id))
			_check(linked_specs.is_empty(),"Link break must suppress subsequent node-link specs")
			_check(run._room_defender_spawn_suppressed("arc_linker",effect_scope_id),"Link break must suppress a subsequent linker spawn in its lineage")
			_check(not run._room_defender_spawn_suppressed("arc_linker",foreign_effect_scope_id),"Link break must not suppress unrelated-lineage actors")
			_check(_enemy_timer_count(run,source_wave,"effect_link_broken_seconds")>0,"Link break must modify surviving linked actors")
		"hatchling":
			var hatch_specs: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("lunge",0.0)],_event_for(archetype,effect_scope_id))
			_check(hatch_specs.is_empty(),"Hatch suppression must suppress subsequent lunge specs")
			_check(run._room_defender_spawn_suppressed("hatchling",effect_scope_id),"Hatch suppression must suppress subsequent hatchling spawns in its lineage")
			_check(not run._room_defender_spawn_suppressed("hatchling",foreign_effect_scope_id),"Hatch suppression must not suppress unrelated-lineage actors")
			_check(_enemy_timer_count(run,source_wave,"effect_hatch_suppressed_seconds")>0,"Hatch suppression must modify surviving hatch actors")
		"echo_clone":
			var echo_specs: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("recorded_path",0.0)],_event_for(archetype,effect_scope_id))
			_check(echo_specs.is_empty(),"Echo disruption must suppress subsequent recorded-path specs")
			_check(run._room_defender_spawn_suppressed("echo_clone",effect_scope_id),"Echo disruption must suppress subsequent echo spawns in its lineage")
			_check(not run._room_defender_spawn_suppressed("echo_clone",foreign_effect_scope_id),"Echo disruption must not suppress unrelated-lineage actors")
			_check(_enemy_timer_count(run,source_wave,"effect_echo_disrupted_seconds")>0,"Echo disruption must modify surviving echo actors")
		"decoy_core":
			_check(_source_wave_enemy_count(run._enemies,source_wave)==0,"Decoy reveal must remove the remaining false targets without rewards")
			_check(run._room_effect_flag_active("true_target_revealed",effect_scope_id),"Decoy reveal must expose the true-target state")
			_check(run._room_effect_value_max("true_target_revealed","true_target_damage_multiplier",1.0)>1.0,"Revealed target must receive its authored damage multiplier")
			_check(run._room_defender_spawn_suppressed("decoy_core",effect_scope_id),"True-target reveal must suppress subsequent false-target spawns in its lineage")
			_check(not run._room_defender_spawn_suppressed("decoy_core",foreign_effect_scope_id),"Reveal must not remove unrelated-lineage false-target spawns")
		"resonance_mouth":
			_check(_pending_wave_count(run._pending_room_emissions,source_wave)==8,"Emitter silence must cancel its authored capped 32 of 40 owned pending emissions")
		"orbit_sentinel":
			_check(projectile_count_before-run._projectiles.enemy_group_size(source_wave)>=2,"Orbit interrupt must clear its capped owned volley")

	var actor_survivors := _actor_owner_count(run._enemies,actor_owner)
	if archetype!="decoy_core":
		_check(actor_survivors>0,"%s effect must leave a live actor descendant for lifecycle verification" % archetype)
	_check(run._projectiles.enemy_group_size(foreign_wave)==1,"%s effect must not clear or absorb wave B projectiles" % archetype)
	_check(_pending_wave_count(run._pending_room_emissions,foreign_wave)==2,"%s effect must not cancel wave B pending emissions" % archetype)


func _prepare_case(run: Node, archetype: String, role: String) -> Dictionary:
	run.projectiles_clear_and_enemies()
	run._room_runtime_trace.clear()
	run._room_contract={"room_id":"defender_effects_live","hazard":"effect_probe"}
	run._room_elapsed=0.0
	run.state=RunSceneClass.RunState.ORGAN_CHAMBER if archetype=="decoy_core" else RunSceneClass.RunState.INTERNAL_ROOMS
	var source_wave := "room:defender_effects:%s" % archetype
	var foreign_wave := "room:defender_effects:foreign:%s" % archetype
	var effect_scope_id := "room-effect:defender_effects_live:cycle:0:%s" % archetype
	var foreign_effect_scope_id := "room-effect:defender_effects_live:cycle:0:foreign_%s" % archetype
	var actor_owner := "actor:defender_effects:%s:cycle:0" % archetype
	var behavior := {"collision_role":role,"health_class":"medium","motion":"pocket_shift","attack":"aimed_burst"}
	var position := Vector2(220.0,540.0)
	var primary_spawned: bool = run._spawn_enemy(position,7001,actor_owner,64,{
		"archetype":archetype,
		"behavior":behavior,
		"source_wave":source_wave,
		"actor_owner_id":actor_owner,
		"effect_scope_id":effect_scope_id,
		"fire_enabled":false,
	})
	_check(primary_spawned,"%s source defender must spawn" % archetype)
	for companion_index in 2:
		run._spawn_enemy(position+Vector2(56.0+companion_index*42.0,24.0),7100+companion_index,actor_owner,64,{
			"archetype":archetype,
			"behavior":behavior,
			"source_wave":source_wave,
			"actor_owner_id":actor_owner,
			"effect_scope_id":effect_scope_id,
			"fire_enabled":false,
		})
	run._active_room_actor_groups[actor_owner]=4.0
	for model in ["linear","soft_homing","expanding","node_link","recorded_path","delayed_linear","lunge"]:
		for bullet_index in 2:
			var bullet_position := position+Vector2(float(bullet_index)*3.0,0.0) if archetype=="armor_drone" and model=="linear" else Vector2(420.0,float(430+bullet_index*18))
			run._projectiles.spawn_enemy(bullet_position,Vector2.ZERO,4.0,{
				"group":source_wave,
				"parent_group":source_wave,
				"effect_scope_id":effect_scope_id,
				"travel_model":model,
				"homing":1.6 if model in ["soft_homing","linear"] else 0.0,
				"life":8.0,
			})
	if archetype=="tracker_mite":
		run._projectiles.spawn_enemy(Vector2(404.0,466.0),Vector2(-90.0,0.0),4.0,{
			"group":source_wave,
			"parent_group":source_wave,
			"effect_scope_id":effect_scope_id,
			"travel_model":"soft_homing",
			"homing":0.0,
			"life":8.0,
		})
	for pending_index in 40:
		run._pending_room_emissions.append({"delay":1.0,"wave_id":source_wave,"spec":_projectile_spec("delayed_linear",0.0)})
	run._projectiles.spawn_enemy(position,Vector2.ZERO,4.0,{
		"group":foreign_wave,
		"parent_group":foreign_wave,
		"effect_scope_id":foreign_effect_scope_id,
		"travel_model":"soft_homing",
		"homing":1.6,
		"life":8.0,
	})
	for foreign_pending_index in 2:
		run._pending_room_emissions.append({"delay":1.0,"wave_id":foreign_wave,"spec":_projectile_spec("delayed_linear",0.0)})
	return {
		"source_wave":source_wave,
		"foreign_wave":foreign_wave,
		"effect_scope_id":effect_scope_id,
		"foreign_effect_scope_id":foreign_effect_scope_id,
		"actor_owner":actor_owner,
		"source_index":0,
		"source_enemy":(run._enemies[0] as Dictionary).duplicate(true),
	}


func _test_boundary_cleanup(run: Node) -> void:
	_prepare_case(run,"armor_drone","cover")
	run._kill_enemy(0)
	_check(not run._room_defender_effect_events.is_empty() and not run._room_defender_covers.is_empty(),"Boundary probe must begin with live defender effect state")
	run.projectiles_clear_and_enemies()
	_check(run._room_defender_effect_events.is_empty(),"Room boundary must clear defender effect event ids")
	_check(run._room_defender_effect_sources.is_empty(),"Room boundary must clear defender effect source ids")
	_check(run._room_defender_covers.is_empty(),"Room boundary must clear timed covers")
	_check((run._room_defender_effect_state.scopes as Dictionary).is_empty(),"Room boundary must clear owner-scoped effect flags and timers")
	_check(run._room_defender_kill_sequence==0,"Room boundary must reset deterministic kill sequencing")


func _test_organ_cycle_effect_cleanup(run: Node) -> void:
	var prepared := _prepare_case(run,"armor_drone","cover")
	var old_source_id := String((prepared.source_enemy as Dictionary).id)
	run._kill_enemy(int(prepared.source_index))
	var old_receipts: Array = run._room_defender_effect_events.keys().duplicate()
	var old_scopes: Array = (run._room_defender_effect_state.scopes as Dictionary).keys().duplicate()
	_check(not old_receipts.is_empty() and not old_scopes.is_empty() and not run._room_defender_covers.is_empty(),"Organ-cycle probe must begin with live scopes, receipts, sources, and cover")

	# Resolve every transient and actor descendant without using the broad room
	# cleanup helper: the organ-cycle boundary itself must prune effect state.
	run._projectiles.clear_enemy()
	run._pending_room_emissions.clear()
	run._active_room_waves.clear()
	run._active_room_motifs.clear()
	run._clear_room_actor_groups("cycle_test_resolved")
	_check(run._active_room_waves.is_empty() and run._active_room_actor_groups.is_empty(),"Organ cycle may reset only after wave and actor owners resolve")
	run._room_contract={"valid":true,"room_id":"defender_effect_cycle_probe","duration":0.10,"hazard":"effect_probe"}
	run._room_pattern_plan={
		"valid":true,
		"room_id":"defender_effect_cycle_probe",
		"events":[{"index":0,"telegraph_at":99.0}],
	}
	run._room_elapsed=0.11
	run._room_event_index=1
	run._room_cycle_index=0
	run.state=RunSceneClass.RunState.ORGAN_CHAMBER
	run._update_contract_hazards(0.0)
	_check(run._room_cycle_index==1,"Resolved organ chamber must advance exactly one cycle")
	_check((run._room_defender_effect_state.scopes as Dictionary).is_empty(),"Organ-cycle reset must prune every old effect scope")
	_check(run._room_defender_effect_events.is_empty(),"Organ-cycle reset must prune old effect receipts")
	_check(run._room_defender_effect_sources.is_empty(),"Organ-cycle reset must prune old defender-source ids")
	_check(run._room_defender_covers.is_empty(),"Organ-cycle reset must prune old timed covers")
	_check(run._room_defender_kill_sequence==0,"Organ-cycle reset must restart deterministic kill sequencing")
	for old_receipt in old_receipts:
		_check(not run._room_defender_effect_events.has(old_receipt),"Old organ-cycle receipt must not survive reset")
	for old_scope in old_scopes:
		_check(not (run._room_defender_effect_state.scopes as Dictionary).has(old_scope),"Old organ-cycle scope must not survive reset")
	_check(not run._room_defender_effect_sources.has(old_source_id),"Old organ-cycle source id must not survive reset")

	var new_wave := "room:defender_effect_cycle_probe:1:0"
	var new_actor_owner := "actor:defender_effect_cycle_probe:1:0"
	var new_scope: String = run._room_defender_effect_scope_id("armor_drone")
	var spawned: bool = run._spawn_enemy(Vector2(250.0,540.0),88001,new_actor_owner,4,{
		"archetype":"armor_drone",
		"behavior":{"collision_role":"cover","health_class":"medium","motion":"cover_anchor"},
		"source_wave":new_wave,
		"actor_owner_id":new_actor_owner,
		"effect_scope_id":new_scope,
		"fire_enabled":false,
	})
	_check(spawned,"New organ cycle must spawn a fresh defender normally")
	var new_source_id := String((run._enemies[0] as Dictionary).id) if spawned else ""
	if spawned:
		run._kill_enemy(0)
	_check((run._room_defender_effect_state.scopes as Dictionary).has(new_scope),"New organ cycle must apply a fresh effect scope normally")
	_check(run._room_defender_effect_events.size()==1 and run._room_defender_effect_sources.has(new_source_id),"New organ cycle must create only its fresh receipt and source id")
	_check(run._room_defender_covers.size()==1 and run._room_defender_kill_sequence==1,"New organ cycle must create fresh cover and restart kill sequencing at one")


func _test_successor_lineage_after_source_clear(run: Node) -> void:
	var hatch_case := _prepare_case(run,"hatchling","charger")
	var hatch_wave := String(hatch_case.source_wave)
	var hatch_scope := String(hatch_case.effect_scope_id)
	var unrelated_scope := String(hatch_case.foreign_effect_scope_id)
	run._projectiles.clear_enemy_group(hatch_wave)
	run._clear_pending_room_emissions(hatch_wave)
	_check(run._projectiles.enemy_group_size(hatch_wave)==0 and _pending_wave_count(run._pending_room_emissions,hatch_wave)==0,"Source-clear probe must retire transient hatch descendants before defender death")
	run._kill_enemy(int(hatch_case.source_index))
	var successor_hatch_event := _event_for("hatchling",hatch_scope)
	var successor_hatch_specs: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("lunge",0.0)],successor_hatch_event)
	var unrelated_hatch_specs: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("lunge",0.0)],_event_for("hatchling",unrelated_scope))
	_check(successor_hatch_specs.is_empty() and run._room_defender_spawn_suppressed("hatchling",hatch_scope),"Defender killed after source cleanup must suppress a successor in the same bounded lineage")
	_check(unrelated_hatch_specs.size()==1 and not run._room_defender_spawn_suppressed("hatchling",unrelated_scope),"Post-cleanup hatch effect must not leak into an unrelated lineage")

	var tracking_case := _prepare_case(run,"tracker_mite","pursuer")
	var tracking_wave := String(tracking_case.source_wave)
	var tracking_scope := String(tracking_case.effect_scope_id)
	var unrelated_tracking_scope := String(tracking_case.foreign_effect_scope_id)
	run._projectiles.clear_enemy_group(tracking_wave)
	run._clear_pending_room_emissions(tracking_wave)
	run._kill_enemy(int(tracking_case.source_index))
	var successor_tracking: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("soft_homing",1.7)],_event_for("tracker_mite",tracking_scope))
	var successor_nonhoming: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("soft_homing",0.0)],_event_for("tracker_mite",tracking_scope))
	var unrelated_tracking: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("soft_homing",1.7)],_event_for("tracker_mite",unrelated_tracking_scope))
	_check(successor_tracking.is_empty(),"Tracking break must suppress a same-lineage homing successor after transient source cleanup")
	_check(successor_nonhoming.size()==1 and _spec_exists(successor_nonhoming,"soft_homing",0.0),"Tracking break must preserve a same-lineage non-homing soft_homing successor after transient source cleanup")
	_check(unrelated_tracking.size()==1 and float(((unrelated_tracking[0] as Dictionary).options as Dictionary).get("homing",0.0))>0.0,"Post-cleanup tracking effect must not alter an unrelated lineage")

	var cover_case := _prepare_case(run,"armor_drone","cover")
	var cover_wave := String(cover_case.source_wave)
	var cover_scope := String(cover_case.effect_scope_id)
	var cover_foreign_wave := String(cover_case.foreign_wave)
	var cover_position := Vector2((cover_case.source_enemy as Dictionary).position)
	run._projectiles.clear_enemy_group(cover_wave)
	run._clear_pending_room_emissions(cover_wave)
	run._kill_enemy(int(cover_case.source_index))
	var successor_wave := "room:defender_effects:successor:armor"
	run._projectiles.spawn_enemy(cover_position,Vector2.ZERO,4.0,{
		"group":successor_wave,
		"parent_group":successor_wave,
		"effect_scope_id":cover_scope,
		"travel_model":"linear",
		"life":5.0,
	})
	_check(run._projectiles.enemy_group_size(successor_wave)==1,"Cover successor probe must spawn after its transient source wave was cleared")
	run._update_room_defender_effects(1.0/60.0)
	_check(run._projectiles.enemy_group_size(successor_wave)==0,"Timed cover must absorb a successor projectile in the same bounded lineage")
	_check(run._projectiles.enemy_group_size(cover_foreign_wave)==1,"Timed cover must leave a colocated unrelated-lineage projectile alive")


func _test_frozen_suppression_does_not_rebuild(run: Node) -> void:
	var prepared := _prepare_case(run,"hatchling","charger")
	var source_wave := String(prepared.source_wave)
	var effect_scope_id := String(prepared.effect_scope_id)
	run._kill_enemy(int(prepared.source_index))
	var event := _event_for("hatchling",effect_scope_id)
	event.projectile={"count":1,"travel_model":"lunge","max_active":1}
	var frozen_specs: Array = run._room_projectile_specs_after_defender_effects([_projectile_spec("lunge",0.0)],event)
	_check(frozen_specs.is_empty(),"Suppressed telegraph must freeze an explicit empty projectile plan")
	event.runtime_projectile_specs=frozen_specs
	run._update_room_defender_effects(6.0)
	_check(not run._room_effect_flag_active("hatch_suppressed",effect_scope_id),"Freeze regression probe must let suppression expire before activation")
	var before: int = run._projectiles.enemy_active.size()
	var world_positions: Array[Vector2] = [Vector2(180.0,480.0)]
	var result: Dictionary = run._emit_room_projectile_plan(event,"room:frozen_suppression",world_positions,Vector2(270.0,730.0),0.5,"frozen_probe")
	_check(int(result.get("requested",-1))==0 and run._projectiles.enemy_active.size()==before,"Explicitly frozen empty plan must not rebuild after suppression expires")


func _event_for(archetype: String, effect_scope_id: String) -> Dictionary:
	return {"runtime_effect_scope_id":effect_scope_id,"spawn":{"defender_archetype":archetype},"projectile":{"travel_model":"linear"}}


func _projectile_spec(travel_model: String, homing: float) -> Dictionary:
	return {
		"origin":Vector2(420.0,520.0),
		"velocity":Vector2(-120.0,0.0),
		"damage":4.0,
		"delay_seconds":0.0,
		"options":{"travel_model":travel_model,"homing":homing,"life":4.0},
	}


func _last_trace(trace: Array, operation: String) -> Dictionary:
	for index in range(trace.size()-1,-1,-1):
		var entry := trace[index] as Dictionary
		if String(entry.get("operation",""))==operation:
			return entry
	return {}


func _enemy_by_id(enemies: Array, enemy_id: String) -> Dictionary:
	for enemy in enemies:
		if String((enemy as Dictionary).get("id",""))==enemy_id:
			return enemy as Dictionary
	return {}


func _first_marked_enemy(enemies: Array, source_wave: String) -> Dictionary:
	for enemy in enemies:
		var item := enemy as Dictionary
		if String(item.get("source_wave",""))==source_wave and float(item.get("effect_priority_seconds",0.0))>0.0:
			return item
	return {}


func _source_wave_enemy_count(enemies: Array, source_wave: String) -> int:
	var count := 0
	for enemy in enemies:
		if String((enemy as Dictionary).get("source_wave",""))==source_wave:
			count+=1
	return count


func _actor_owner_count(enemies: Array, actor_owner: String) -> int:
	var count := 0
	for enemy in enemies:
		if String((enemy as Dictionary).get("actor_owner_id",""))==actor_owner:
			count+=1
	return count


func _enemy_timer_count(run: Node, source_wave: String, timer_key: String) -> int:
	var count := 0
	for enemy in run._enemies:
		var item := enemy as Dictionary
		if String(item.get("source_wave",""))==source_wave and float(item.get(timer_key,0.0))>0.0:
			count+=1
	return count


func _owned_homing_count(run: Node, source_wave: String) -> int:
	var count := 0
	for bullet in run._projectiles.enemy_active:
		var item := bullet as Dictionary
		if String(item.get("parent_group",""))==source_wave and float(item.get("homing",0.0))>0.0:
			count+=1
	return count


func _owned_nonhoming_soft_count(run: Node, source_wave: String) -> int:
	var count := 0
	for bullet in run._projectiles.enemy_active:
		var item := bullet as Dictionary
		if String(item.get("parent_group",""))==source_wave and String(item.get("travel_model",""))=="soft_homing" and is_zero_approx(float(item.get("homing",-1.0))):
			count+=1
	return count


func _pending_emission_present(pending_emissions: Array, source_wave: String, emission_index: int) -> bool:
	for raw_emission in pending_emissions:
		var emission := raw_emission as Dictionary
		if String(emission.get("wave_id",""))==source_wave and int(emission.get("emission_index",-1))==emission_index:
			return true
	return false


func _spec_exists(specs: Array, travel_model: String, homing: float) -> bool:
	for raw_spec in specs:
		var options := ((raw_spec as Dictionary).get("options",{}) as Dictionary)
		if String(options.get("travel_model",""))==travel_model and is_equal_approx(float(options.get("homing",-1.0)),homing):
			return true
	return false


func _pending_wave_count(pending_emissions: Array, source_wave: String) -> int:
	var count := 0
	for pending in pending_emissions:
		if String((pending as Dictionary).get("wave_id",""))==source_wave:
			count+=1
	return count
