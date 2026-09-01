extends Node

const ProjectilePoolClass := preload("res://scripts/gameplay/projectile_pool.gd")
const MODELS := ["linear","delayed_linear","soft_homing","expanding","node_link","lunge","recorded_path"]
const ORIGIN := Vector2(150.0,300.0)
const VELOCITY := Vector2(100.0,0.0)

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed+=1
	else:
		failures.append(message)
		push_error("PROJECTILE TRAVEL MODEL FAILURE: "+message)


func _run() -> void:
	_test_linear_and_gravity_vector_semantics()
	_test_motion_identity_at_30_and_60_hz()
	_test_preview_contract_and_pool_immutability()
	_test_preview_live_parity_at_30_and_60_hz()
	_test_preview_safe_parity_at_30_and_60_hz()
	_test_preview_model_breakpoints()
	_test_frozen_homing_target_and_dynamic_fallback()
	_test_delayed_linear_and_soft_homing_parity()
	_test_player_homing_response_at_30_60_120_hz()
	_test_collision_and_ownership_at_30_and_60_hz()
	_test_safe_zone_clearance_at_30_and_60_hz()
	_test_production_safe_soft_homing_at_30_and_60_hz()
	_test_safe_motion_segment_collision_paths()
	_test_nonlinear_collision_substeps_without_safe_metadata()
	_test_expanding_radius_continuous_sweep()
	_test_frame_motion_pool_reuse()
	_test_invalid_travel_parameters_use_bounded_defaults()
	_test_final_partial_lifetime_collision()
	_test_player_retirement_sweeps()
	_test_bounds_exit_swept_collision_and_reuse()
	_test_extreme_curve_hitch_fails_terminal()
	_test_lifetime_at_30_and_60_hz()
	_test_owner_filtered_cleanup()
	_test_owned_homing_cleanup_is_monotonic()
	_test_pool_cap_and_reuse()
	print("INFINIDIVE PROJECTILE TRAVEL MODEL TESTS: %d passed, %d failed" % [passed,failures.size()])
	AudioManager.shutdown_for_tests()
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_linear_and_gravity_vector_semantics() -> void:
	for fps in [30,60]:
		var linear := _simulate("linear",fps,0.6,VELOCITY,{})
		_check(Vector2(linear.position).distance_to(ORIGIN+VELOCITY*0.6)<0.01,"Linear motion must retain constant authored velocity at %d Hz" % fps)
		_check(Vector2(linear.velocity).is_equal_approx(VELOCITY),"Linear velocity must remain unchanged at %d Hz" % fps)
		var gravity_drop_velocity := Vector2(40.0,120.0)
		var gravity_drop := _simulate("linear",fps,0.5,gravity_drop_velocity,{})
		_check(Vector2(gravity_drop.position).distance_to(ORIGIN+gravity_drop_velocity*0.5)<0.01,"Gravity-drop vectors must preserve their authored downward linear trajectory at %d Hz" % fps)
	var fallback := _simulate("unsupported_model",60,0.5,VELOCITY,{})
	_check(String(fallback.travel_model)=="linear","Unknown travel metadata must fail closed to linear")
	_check(Vector2(fallback.position).distance_to(ORIGIN+VELOCITY*0.5)<0.01,"Unknown travel metadata fallback must preserve linear displacement")


func _test_motion_identity_at_30_and_60_hz() -> void:
	var end_states: Dictionary = {}
	for model in MODELS:
		var sample_seconds := 0.4 if model=="recorded_path" else 0.6
		var state_30 := _simulate(model,30,sample_seconds,VELOCITY,_parameters_for(model))
		var state_60 := _simulate(model,60,sample_seconds,VELOCITY,_parameters_for(model))
		_check(Vector2(state_30.position).distance_to(Vector2(state_60.position))<0.02,"%s position must be deterministic at 30/60 Hz" % model)
		_check(Vector2(state_30.velocity).distance_to(Vector2(state_60.velocity))<0.02,"%s velocity must be deterministic at 30/60 Hz" % model)
		_check(absf(float(state_30.radius)-float(state_60.radius))<0.001,"%s collision radius must be deterministic at 30/60 Hz" % model)
		_check(absf(float(state_30.age)-sample_seconds)<0.001 and absf(float(state_60.age)-sample_seconds)<0.001,"%s absolute motion clock must match elapsed simulation time" % model)
		end_states[model]=state_60
	var linear := end_states.linear as Dictionary
	var expanding := end_states.expanding as Dictionary
	var linked := end_states.node_link as Dictionary
	var lunge := end_states.lunge as Dictionary
	var recorded := end_states.recorded_path as Dictionary
	_check(float(expanding.radius)>float(expanding.base_radius)+5.0,"Expanding waves must grow their live collision radius")
	_check(Vector2(expanding.position).distance_to(Vector2(linear.position))<0.01,"Expansion must not silently change the authored center trajectory")
	_check(absf(Vector2(linked.position).y-ORIGIN.y)>5.0,"Node links must arc transversely instead of remaining a scalar linear shot")
	_check(Vector2(lunge.position).x>Vector2(linear.position).x+10.0,"Lunges must expose a real windup/burst/recovery distance curve")
	_check(Vector2(recorded.position).distance_to(Vector2(195.0,340.0))<0.02,"Recorded-path projectiles must traverse authored world-space path points")
	_check(absf(Vector2(recorded.position).y-ORIGIN.y)>30.0,"Recorded-path motion must be spatially distinct from its linear chord")


func _test_preview_contract_and_pool_immutability() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_player(Vector2(90.0,200.0),Vector2(50.0,0.0),2.0,{"life":2.0})
	pool.spawn_enemy(ORIGIN,VELOCITY,3.0,{"travel_model":"node_link","travel_parameters":_parameters_for("node_link"),"life":2.0})
	var live_before := (pool.enemy_active[0] as Dictionary).duplicate(true)
	var player_before := (pool.player_active[0] as Dictionary).duplicate(true)
	var enemy_free_before := pool._enemy_free.size()
	var player_free_before := pool._player_free.size()
	for model in MODELS:
		var options := _preview_options(model,ORIGIN,false)
		options.preview_duration=0.82
		var options_before := options.duplicate(true)
		var samples := pool.preview_enemy_travel(ORIGIN,VELOCITY,options)
		_check(samples.size()==ProjectilePoolClass.MAX_PREVIEW_SAMPLES,"%s preview at the published duration cap must contain exactly %d samples" % [model,ProjectilePoolClass.MAX_PREVIEW_SAMPLES])
		_check(_preview_samples_are_finite_and_ordered(samples),"%s preview samples must remain finite, non-negative and strictly age ordered" % model)
		_check(absf(float(samples[0].age))<0.000001 and absf(float(samples[samples.size()-1].age)-0.82)<0.00001,"%s preview must include age zero and the exact bounded endpoint" % model)
		_check(options==options_before,"%s preview must not mutate its caller-owned options or travel metadata" % model)
	var invalid_duration := pool.preview_enemy_travel(ORIGIN,VELOCITY,{"travel_model":"linear","life":2.0,"preview_duration":INF})
	_check(invalid_duration.size()<=ProjectilePoolClass.MAX_PREVIEW_SAMPLES and float(invalid_duration[invalid_duration.size()-1].age)<=ProjectilePoolClass.MAX_PREVIEW_SECONDS,"Invalid preview duration must fail to a finite bounded default")
	var short_life := pool.preview_enemy_travel(ORIGIN,VELOCITY,{"travel_model":"linear","life":0.2,"preview_duration":0.82})
	_check(absf(float(short_life[short_life.size()-1].age)-0.2)<0.00001,"Preview must stop at projectile lifetime before the public duration cap")
	_check(pool.enemy_active.size()==1 and pool.player_active.size()==1,"Preview must not add, remove or release live pool entries")
	_check(pool._enemy_free.size()==enemy_free_before and pool._player_free.size()==player_free_before,"Preview must not consume or grow either free list")
	_check((pool.enemy_active[0] as Dictionary)==live_before,"Preview must not mutate an existing enemy dictionary")
	_check((pool.player_active[0] as Dictionary)==player_before,"Preview must not mutate an existing player dictionary")
	pool.clear_all()
	pool.free()


func _test_preview_live_parity_at_30_and_60_hz() -> void:
	for fps in [30,60]:
		for model in MODELS:
			var parity := _preview_live_parity(model,fps,false)
			_check(bool(parity.complete),"%s preview/live parity fixture must remain live through 0.8 seconds at %d Hz" % [model,fps])
			_check(float(parity.maximum_age_delta)<0.00001,"%s preview ages must match live runtime at %d Hz" % [model,fps])
			_check(float(parity.maximum_position_delta)<0.02,"%s preview positions must match live runtime at %d Hz (delta %.5f)" % [model,fps,float(parity.maximum_position_delta)])
			_check(float(parity.maximum_radius_delta)<0.001,"%s preview radii must match live runtime at %d Hz (delta %.5f)" % [model,fps,float(parity.maximum_radius_delta)])


func _test_preview_safe_parity_at_30_and_60_hz() -> void:
	for fps in [30,60]:
		for model in MODELS:
			var parity := _preview_live_parity(model,fps,true)
			_check(bool(parity.complete),"%s safe preview/live fixture must remain live through 0.8 seconds at %d Hz" % [model,fps])
			_check(float(parity.maximum_age_delta)<0.00001,"%s safe preview ages must match live detours at %d Hz" % [model,fps])
			_check(float(parity.maximum_position_delta)<0.05,"%s safe preview positions must match live detours at %d Hz (delta %.5f)" % [model,fps,float(parity.maximum_position_delta)])
			_check(float(parity.maximum_radius_delta)<0.001,"%s safe preview radii must match live detours at %d Hz" % [model,fps])
			_check(float(parity.minimum_preview_safe_clearance)>=-0.02,"%s preview must retain its full radius outside the authored safe disk at %d Hz" % [model,fps])


func _test_preview_model_breakpoints() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var lunge := pool.preview_enemy_travel(ORIGIN,VELOCITY,_preview_options("lunge",ORIGIN,false))
	var lunge_pre_windup := _preview_sample_at_age(lunge,11.0/60.0)
	var lunge_windup := _preview_sample_at_age(lunge,0.2)
	var lunge_post_windup := _preview_sample_at_age(lunge,13.0/60.0)
	var lunge_pre_recovery := _preview_sample_at_age(lunge,23.0/60.0)
	var lunge_recovery := _preview_sample_at_age(lunge,0.4)
	var lunge_post_recovery := _preview_sample_at_age(lunge,25.0/60.0)
	_check(not lunge_windup.is_empty() and not lunge_recovery.is_empty(),"Lunge preview must sample both authored stage breakpoints exactly")
	var windup_step := Vector2(lunge_windup.position).distance_to(Vector2(lunge_pre_windup.position))
	var burst_step := Vector2(lunge_post_windup.position).distance_to(Vector2(lunge_windup.position))
	var burst_end_step := Vector2(lunge_recovery.position).distance_to(Vector2(lunge_pre_recovery.position))
	var recovery_step := Vector2(lunge_post_recovery.position).distance_to(Vector2(lunge_recovery.position))
	_check(burst_step>windup_step*5.0,"Lunge preview must expose the windup-to-burst speed transition")
	_check(burst_end_step>recovery_step*2.0,"Lunge preview must expose the burst-to-recovery speed transition")
	var recorded := pool.preview_enemy_travel(ORIGIN,VELOCITY,_preview_options("recorded_path",ORIGIN,false))
	for expected in [
		{"age":0.2,"position":Vector2(170.0,260.0)},
		{"age":0.4,"position":Vector2(195.0,340.0)},
		{"age":0.6,"position":Vector2(230.0,300.0)},
	]:
		var sample := _preview_sample_at_age(recorded,float(expected.age))
		_check(not sample.is_empty() and Vector2(sample.position).distance_to(Vector2(expected.position))<0.02,"Recorded-path preview must land on authored breakpoint %.1f" % float(expected.age))
	var expanding_options := _preview_options("expanding",ORIGIN,false)
	expanding_options.radius=6.0
	var expanding := pool.preview_enemy_travel(ORIGIN,VELOCITY,expanding_options)
	var expansion_cap := _preview_sample_at_age(expanding,0.6)
	var expansion_after_cap := _preview_sample_at_age(expanding,37.0/60.0)
	_check(absf(float(expansion_cap.radius)-24.0)<0.001 and absf(float(expansion_after_cap.radius)-24.0)<0.001,"Expanding preview must sample and retain its authored radius cap breakpoint")
	pool.free()


func _test_frozen_homing_target_and_dynamic_fallback() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var frozen_options := _preview_options("soft_homing",ORIGIN,false)
	frozen_options.frozen_target=Vector2(520.0,220.0)
	var frozen_preview := pool.preview_enemy_travel(ORIGIN,VELOCITY,frozen_options)
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,frozen_options)
	for frame in 24:
		var irrelevant_dynamic_target := Vector2(520.0,430.0+sin(float(frame))*80.0)
		pool.step(1.0/60.0,[],irrelevant_dynamic_target,0.0)
	var frozen_live := pool.enemy_active[0] as Dictionary
	var frozen_expected := _preview_sample_at_age(frozen_preview,0.4)
	_check(Vector2(frozen_live.position).distance_to(Vector2(frozen_expected.position))<0.02,"Frozen soft-homing target must ignore dynamic player movement and preserve preview parity")
	pool.clear_enemy()
	var up := _simulate_dynamic_homing_fallback(Vector2(520.0,220.0))
	var down := _simulate_dynamic_homing_fallback(Vector2(520.0,380.0))
	_check(Vector2(up).distance_to(Vector2(down))>8.0,"Soft homing without a frozen target must retain the dynamic runtime target fallback")
	pool.free()


func _test_delayed_linear_and_soft_homing_parity() -> void:
	for fps in [30,60]:
		var linear := _simulate("linear",fps,0.6,VELOCITY,{})
		var delayed := _simulate("delayed_linear",fps,0.6,VELOCITY,{})
		_check(Vector2(delayed.position).distance_to(Vector2(linear.position))<0.01,"Delayed-linear motion after external emission delay must retain linear parity at %d Hz" % fps)
	var homing_30 := _simulate_moving_homing_target(30)
	var homing_60 := _simulate_moving_homing_target(60)
	_check(Vector2(homing_30.position).distance_to(Vector2(homing_60.position))<0.05,"Soft-homing moving-target position must be deterministic at 30/60 Hz")
	_check(Vector2(homing_30.velocity).distance_to(Vector2(homing_60.velocity))<0.05,"Soft-homing moving-target velocity must be deterministic at 30/60 Hz")
	_check(Vector2(homing_60.position).y<ORIGIN.y-8.0,"Soft homing must materially turn toward the moving target")


func _test_player_homing_response_at_30_60_120_hz() -> void:
	var states: Dictionary = {}
	for fps in [30,60,120]:
		var state := _simulate_player_homing(fps)
		states[fps]=state
		var position := Vector2(state.position)
		var velocity := Vector2(state.velocity)
		_check(is_finite(position.x) and is_finite(position.y) and is_finite(velocity.x) and is_finite(velocity.y),"Player homing must remain finite at %d Hz" % fps)
	# The runtime evaluates pursuit in shared 1/120-second slices. The 0.03 px
	# position and 0.02 px/s velocity tolerances cover only float accumulation;
	# they are two orders of magnitude below the former multi-pixel drift.
	for rate_pair in [[30,60],[60,120],[30,120]]:
		var lower := states[int(rate_pair[0])] as Dictionary
		var higher := states[int(rate_pair[1])] as Dictionary
		var position_delta := Vector2(lower.position).distance_to(Vector2(higher.position))
		var velocity_delta := Vector2(lower.velocity).distance_to(Vector2(higher.velocity))
		_check(position_delta<0.03,"Player homing position must match at %d/%d Hz (delta %.6f px)" % [rate_pair[0],rate_pair[1],position_delta])
		_check(velocity_delta<0.02,"Player homing velocity must match at %d/%d Hz (delta %.6f px/s)" % [rate_pair[0],rate_pair[1],velocity_delta])
	_check(Vector2((states[120] as Dictionary).position).x>125.0,"Frame-independent player homing must retain a material turn toward its target")


func _test_collision_and_ownership_at_30_and_60_hz() -> void:
	for fps in [30,60]:
		for model in MODELS:
			var target := _collision_target(model)
			var collision := _simulate_until_player_hit(model,fps,target,_parameters_for(model))
			_check(bool(collision.hit),"%s swept collision must hit its model path at %d Hz" % [model,fps])
			_check(int(collision.hit_count)==1,"%s collision must resolve exactly once at %d Hz" % [model,fps])
			_check(String(collision.group)=="wave:%s" % model,"%s hit must preserve transient wave ownership at %d Hz" % [model,fps])
			_check(int(collision.active)==0 and int(collision.free)==1,"%s hit must return its dictionary to the pool at %d Hz" % [model,fps])
	var linear_off_axis := _simulate_until_player_hit("linear",60,Vector2(185.0,318.0),{})
	var expanding_off_axis := _simulate_until_player_hit("expanding",60,Vector2(185.0,318.0),_parameters_for("expanding"))
	_check(not bool(linear_off_axis.hit),"A fixed-radius linear shot must miss the expansion-only collision probe")
	_check(bool(expanding_off_axis.hit),"An expanding wave must use its grown radius for live collision")


func _test_safe_zone_clearance_at_30_and_60_hz() -> void:
	for fps in [30,60]:
		for model in MODELS:
			var safe_probe := _simulate_safe_zone_crossing(model,fps,false)
			_check(float(safe_probe.spawn_surface_clearance)>=float(safe_probe.authored_safe_radius)+0.99,"%s spawn frame must place the full projectile body outside the authored safe disk at %d Hz" % [model,fps])
			_check(int(safe_probe.samples)>5,"%s safe-zone probe must execute across multiple frames at %d Hz" % [model,fps])
			_check(float(safe_probe.minimum_surface_clearance)>=float(safe_probe.authored_safe_radius)-0.02,"%s must keep its full live radius outside the authored safe disk at %d Hz" % [model,fps])
			_check(float(safe_probe.maximum_radius)>16.0 if model=="expanding" else true,"Expanding safe-zone probe must exercise a materially grown live radius at %d Hz" % fps)
			_check(int(safe_probe.maximum_frame_segments)>=1 and int(safe_probe.maximum_frame_segments)<=ProjectilePoolClass.MAX_SAFE_FRAME_SEGMENTS,"%s must publish a bounded actual motion chain at %d Hz" % [model,fps])
			_check(bool(safe_probe.frame_chain_integrity) and not bool(safe_probe.frame_chain_overflowed),"%s frame motion chain must begin/end on live positions without overflow at %d Hz" % [model,fps])
			var outside_hit := _simulate_safe_zone_crossing(model,fps,true)
			_check(bool(outside_hit.hit),"%s must remain collidable at a separate outside-safe target at %d Hz" % [model,fps])
			_check(String(outside_hit.group)=="safe-wave:%s" % model,"%s outside-safe hit must preserve wave ownership at %d Hz" % [model,fps])
	for model in MODELS:
		var detour_30 := _simulate_safe_zone_crossing(model,30,false)
		var detour_60 := _simulate_safe_zone_crossing(model,60,false)
		_check(Vector2(detour_30.final_position).distance_to(Vector2(detour_60.final_position))<0.05,"%s safe-zone detour position must be deterministic at 30/60 Hz" % model)
		_check(Vector2(detour_30.final_velocity).distance_to(Vector2(detour_60.final_velocity))<0.05,"%s safe-zone detour velocity must be deterministic at 30/60 Hz" % model)


func _test_production_safe_soft_homing_at_30_and_60_hz() -> void:
	var probe_30 := _simulate_safe_moving_homing(30)
	var probe_60 := _simulate_safe_moving_homing(60)
	for fps_probe in [{"fps":30,"probe":probe_30},{"fps":60,"probe":probe_60}]:
		var fps := int(fps_probe.fps)
		var probe := fps_probe.probe as Dictionary
		_check(int(probe.safe_substeps)>=int(0.8/ProjectilePoolClass.SAFE_MOTION_SUBSTEP_SECONDS)-2,"Safe soft homing must execute bounded internal substeps at %d Hz" % fps)
		_check(float(probe.minimum_surface_clearance)>=float(probe.safe_radius)-0.02,"Safe soft homing must keep its full live radius outside the authored disk at %d Hz" % fps)
		_check(float(probe.minimum_internal_swept_clearance)>=-0.02,"Every internal soft-homing detour segment must clear the authored safe disk at %d Hz" % fps)
		_check(float(probe.minimum_external_swept_clearance)>=-0.02,"Every published soft-homing frame segment must clear the authored safe disk at %d Hz" % fps)
		_check(float(probe.final_motion_offset)>1.0,"Soft homing must retain persistent detour state after avoiding the safe disk at %d Hz" % fps)
		_check(float(probe.minimum_offset_after_detour)>0.5,"Soft homing detour state must never reset to motion_origin after activation at %d Hz" % fps)
		var maximum_continuous_step := 400.0/float(fps)*3.0
		_check(float(probe.maximum_frame_displacement)<=maximum_continuous_step,"Soft homing must not jump discontinuously after detouring at %d Hz (step %.4f)" % [fps,float(probe.maximum_frame_displacement)])
		_check(int(probe.maximum_frame_segments)>=2 and int(probe.maximum_frame_segments)<=ProjectilePoolClass.MAX_SAFE_FRAME_SEGMENTS,"Safe soft homing must publish a bounded actual subsegment chain at %d Hz" % fps)
		_check(bool(probe.frame_chain_integrity) and not bool(probe.frame_chain_overflowed),"Safe soft-homing segment chain must begin/end on live positions without overflow at %d Hz" % fps)
		_check(not bool(probe.unexpected_hit),"Safe soft-homing detour must not fabricate a player hit at %d Hz" % fps)
	var position_delta := Vector2(probe_30.final_position).distance_to(Vector2(probe_60.final_position))
	var velocity_delta := Vector2(probe_30.final_velocity).distance_to(Vector2(probe_60.final_velocity))
	_check(position_delta<0.05,"Production-safe moving soft-homing final position must match at 30/60 Hz (delta %.4f)" % position_delta)
	_check(velocity_delta<0.05,"Production-safe moving soft-homing final velocity must match at 30/60 Hz (delta %.4f)" % velocity_delta)
	for fps in [30,60]:
		var outside_hit := _simulate_safe_homing_outside_hit(fps)
		_check(bool(outside_hit.hit),"Safe soft homing must still collide with an outside-safe player at %d Hz" % fps)
		_check(String(outside_hit.group)=="safe-homing-live","Outside-safe homing collision must preserve wave ownership at %d Hz" % fps)
		_check(int(outside_hit.free)==1,"Outside-safe homing collision must release exactly once at %d Hz" % fps)


func _test_safe_motion_segment_collision_paths() -> void:
	var safe_models := ["expanding","node_link","lunge","recorded_path","soft_homing"]
	for model in safe_models:
		var high_speed := _simulate_protected_chord_case(model,false)
		_assert_protected_chord_case(high_speed,"%s high-speed stress" % model)
		var hitch := _simulate_protected_chord_case(model,true)
		_assert_protected_chord_case(hitch,"%s hitch" % model)


func _test_nonlinear_collision_substeps_without_safe_metadata() -> void:
	var linked_hitch := _simulate_unprotected_nonlinear_hitch(
		"node_link",
		Vector2(116.6667,348.0),
		{"link_amplitude":48.0,"link_frequency_hz":1.5,"link_phase_radians":0.0},
		0.0
	)
	var linked_60 := _simulate_unprotected_nonlinear_hitch(
		"node_link",
		Vector2(116.6667,348.0),
		{"link_amplitude":48.0,"link_frequency_hz":1.5,"link_phase_radians":0.0},
		60.0
	)
	_check(int(linked_hitch.hits)==1 and int(linked_60.hits)==1,"Node-link curve must hit its exact intermediate apex during a 1/3-second hitch just as it does at 60 Hz")
	_check(int(linked_hitch.free)==1 and int(linked_60.free)==1,"Node-link intermediate hits must release exactly once at hitch and 60 Hz")
	_check(int(linked_hitch.maximum_segments)>2 and int(linked_hitch.maximum_segments)<=ProjectilePoolClass.MAX_SAFE_FRAME_SEGMENTS,"Node-link hitch collision chain must be bounded even without safe metadata")
	_check(not bool(linked_hitch.overflowed),"Node-link 1/3-second hitch must fit its bounded collision chain without overflow")

	var homing_target := Vector2(100.0,500.0)
	var homing_probe := Vector2(133.53,357.66)
	var homing_hitch := _simulate_unprotected_nonlinear_hitch("soft_homing",homing_probe,{},0.0,homing_target,6.0)
	var homing_60 := _simulate_unprotected_nonlinear_hitch("soft_homing",homing_probe,{},60.0,homing_target,6.0)
	_check(int(homing_hitch.hits)==1 and int(homing_60.hits)==1,"No-safe soft homing must preserve the same curved-path hit during a hitch and at 60 Hz")
	_check(int(homing_hitch.free)==1 and int(homing_60.free)==1,"No-safe soft-homing collision must release exactly once at hitch and 60 Hz")
	_check(int(homing_hitch.maximum_segments)>2 and int(homing_hitch.maximum_segments)<=ProjectilePoolClass.MAX_SAFE_FRAME_SEGMENTS,"No-safe soft-homing hitch chain must remain bounded")
	_check(not bool(homing_hitch.overflowed),"No-safe soft-homing 1/3-second hitch must not overflow its collision chain")


func _assert_protected_chord_case(probe: Dictionary, label: String) -> void:
	_check(bool(probe.active),"%s protected-chord projectile must remain live for inspection" % label)
	_check(float(probe.outer_chord_clearance)<=0.0,"%s fixture outer chord must intersect the protected player (clearance %.4f)" % [label,float(probe.outer_chord_clearance)])
	_check(float(probe.internal_clearance)>0.0,"%s ordered internal subsegments must avoid the protected player" % label)
	_check(float(probe.safe_swept_clearance)>=-0.02,"%s internal subsegments must preserve authored safe clearance" % label)
	_check(int(probe.hit_count)==0,"%s must not fabricate a hit from its outer-frame chord" % label)
	_check(int(probe.frame_segments)>=2 and int(probe.frame_segments)<=ProjectilePoolClass.MAX_SAFE_FRAME_SEGMENTS,"%s must retain a bounded ordered segment chain" % label)
	_check(not bool(probe.overflowed),"%s bounded segment chain must not overflow" % label)
	_check(bool(probe.chain_integrity),"%s segment and radius chains must align with actual frame endpoints" % label)
	_check(String(probe.group)=="protected:%s" % String(probe.model),"%s live projectile must preserve owner identity" % label)


func _test_frame_motion_pool_reuse() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(Vector2(191.0,500.0),Vector2(1200.0,0.0),4.0,{
		"travel_model":"node_link",
		"travel_parameters":{"link_amplitude":8.0,"link_frequency_hz":1.0},
		"safe_position":Vector2(270.0,500.0),
		"safe_radius":72.0,
		"radius":6.0,
		"life":2.0,
	})
	pool.step(0.1,[],Vector2(-1000.0,-1000.0),0.0)
	var used := pool.enemy_active[0] as Dictionary
	_check((used.frame_motion_points as Array).size()>2,"Safe-substepped projectile must publish more than one actual segment before pooling")
	pool.clear_enemy()
	var released := pool._enemy_free[0] as Dictionary
	_check((released.frame_motion_points as Array).is_empty() and (released.frame_motion_radii as Array).is_empty(),"Released projectile must clear all per-frame segment state")
	pool.spawn_enemy(Vector2(100.0,300.0),Vector2(100.0,0.0),4.0,{"travel_model":"linear","radius":4.0,"life":2.0})
	var reused := pool.enemy_active[0] as Dictionary
	_check((reused.frame_motion_points as Array).is_empty() and (reused.frame_motion_radii as Array).is_empty(),"Reused projectile must begin without stale frame segments")
	_check(not bool(reused.frame_motion_overflowed),"Reused projectile must reset its frame-segment overflow state")
	pool.step(0.1,[],Vector2(-1000.0,-1000.0),0.0)
	reused=pool.enemy_active[0] as Dictionary
	var reused_points := reused.frame_motion_points as Array
	var reused_radii := reused.frame_motion_radii as Array
	_check(reused_points.size()==2 and reused_radii.size()==2,"Normal motion must retain its single-segment collision fast path after reuse")
	_check(Vector2(reused_points[0]).is_equal_approx(Vector2(100.0,300.0)) and Vector2(reused_points[1]).is_equal_approx(Vector2(110.0,300.0)),"Reused normal segment must contain only the current frame trajectory")
	pool.clear_all()
	pool.free()


func _test_expanding_radius_continuous_sweep() -> void:
	var prior_false_positive_30 := _simulate_expanding_sweep_boundary(30,319.4,Vector2(400.0,0.0))
	var prior_false_positive_60 := _simulate_expanding_sweep_boundary(60,319.4,Vector2(400.0,0.0))
	_check(int(prior_false_positive_30.hits)==0 and int(prior_false_positive_60.hits)==0,"Continuously expanding radius must reject the former 30 Hz retroactive-radius false hit at both rates")
	var initial_boundary_30 := _simulate_expanding_sweep_boundary(30,318.9,Vector2(400.0,0.0))
	var initial_boundary_60 := _simulate_expanding_sweep_boundary(60,318.9,Vector2(400.0,0.0))
	_check(int(initial_boundary_30.hits)==1 and int(initial_boundary_60.hits)==1,"A true initial-radius boundary hit must resolve once at 30/60 Hz")
	_check(int(initial_boundary_30.free)==1 and int(initial_boundary_60.free)==1,"True expanding boundary hits must release exactly once at both rates")
	var growth_hit_30 := _simulate_expanding_sweep_boundary(30,319.3,Vector2.ZERO)
	var growth_hit_60 := _simulate_expanding_sweep_boundary(60,319.3,Vector2.ZERO)
	_check(int(growth_hit_30.hits)==1 and int(growth_hit_60.hits)==1,"Analytic changing-radius sweep must preserve a real growth-only hit at 30/60 Hz")
	_check(Vector2(growth_hit_30.hit_position).distance_to(Vector2(growth_hit_60.hit_position))<0.01,"Growth-only hit position must be frame-rate invariant")


func _test_invalid_travel_parameters_use_bounded_defaults() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,{"travel_model":"expanding","travel_parameters":{"expansion_rate":NAN,"expansion_max_scale":1.0e30},"life":2.0})
	var expanding := pool.enemy_active.back() as Dictionary
	_check(is_equal_approx(float(expanding.expansion_rate),ProjectilePoolClass.DEFAULT_EXPANSION_RATE),"NaN expansion rate must fall back to its bounded default")
	_check(is_equal_approx(float(expanding.expansion_max_scale),ProjectilePoolClass.DEFAULT_EXPANSION_MAX_SCALE),"Huge expansion scale must fall back to its bounded default")
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,{"travel_model":"node_link","travel_parameters":{"link_amplitude":INF,"link_frequency_hz":1.0e30,"link_phase_radians":"invalid"},"life":2.0})
	var linked := pool.enemy_active.back() as Dictionary
	_check(is_equal_approx(float(linked.link_amplitude),ProjectilePoolClass.DEFAULT_LINK_AMPLITUDE),"Infinite link amplitude must fall back to its bounded default")
	_check(is_equal_approx(float(linked.link_frequency_hz),ProjectilePoolClass.DEFAULT_LINK_FREQUENCY_HZ),"Huge link frequency must fall back to its bounded default")
	_check(is_zero_approx(float(linked.link_phase_radians)),"Non-numeric link phase must fall back to zero")
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,{"travel_model":"lunge","travel_parameters":{"windup_seconds":-2.0,"burst_seconds":NAN,"windup_multiplier":INF,"burst_multiplier":99.0,"recovery_multiplier":"invalid"},"life":2.0})
	var lunge := pool.enemy_active.back() as Dictionary
	_check(is_equal_approx(float(lunge.lunge_windup_seconds),ProjectilePoolClass.DEFAULT_LUNGE_WINDUP_SECONDS),"Negative lunge windup must fall back to its bounded default")
	_check(is_equal_approx(float(lunge.lunge_burst_seconds),ProjectilePoolClass.DEFAULT_LUNGE_BURST_SECONDS),"NaN lunge burst duration must fall back to its bounded default")
	_check(is_equal_approx(float(lunge.lunge_windup_multiplier),ProjectilePoolClass.DEFAULT_LUNGE_WINDUP_MULTIPLIER),"Infinite lunge windup multiplier must fall back to its bounded default")
	_check(is_equal_approx(float(lunge.lunge_burst_multiplier),ProjectilePoolClass.DEFAULT_LUNGE_BURST_MULTIPLIER),"Huge lunge burst multiplier must fall back to its bounded default")
	_check(is_equal_approx(float(lunge.lunge_recovery_multiplier),ProjectilePoolClass.DEFAULT_LUNGE_RECOVERY_MULTIPLIER),"Non-numeric lunge recovery must fall back to its bounded default")
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,{"travel_model":"recorded_path","travel_parameters":{"path_duration":NAN,"path_lateral_amplitude":1.0e30,"path_points":[Vector2(NAN,300.0),Vector2(1.0e30,300.0)],"path_exit_velocity":Vector2(1.0e30,1.0e30)},"life":2.0})
	var recorded := pool.enemy_active.back() as Dictionary
	_check(is_equal_approx(float(recorded.recorded_path_seconds),ProjectilePoolClass.DEFAULT_RECORDED_PATH_SECONDS),"NaN path duration must fall back to its bounded default")
	_check(Vector2(recorded.recorded_path_exit_velocity).is_equal_approx(VELOCITY),"Huge path exit velocity must fall back to the authored initial velocity")
	var recorded_points := recorded.recorded_path_points as PackedVector2Array
	_check(recorded_points.size()==4,"Invalid recorded path points must be replaced by the bounded generated path")
	var path_is_finite := true
	for point in recorded_points:
		path_is_finite=path_is_finite and is_finite(point.x) and is_finite(point.y) and point.length()<5000.0
	_check(path_is_finite,"Generated fallback path must contain only finite bounded points")
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,{"travel_model":"node_link","travel_parameters":"invalid-container","life":2.0})
	var invalid_container := pool.enemy_active.back() as Dictionary
	_check(is_equal_approx(float(invalid_container.link_amplitude),ProjectilePoolClass.DEFAULT_LINK_AMPLITUDE),"Non-dictionary travel metadata must fall back to model defaults")
	pool.clear_all()
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==5,"Invalid metadata probes must remain within normal pool ownership and cleanup")
	pool.free()


func _test_final_partial_lifetime_collision() -> void:
	for fps in [30,60]:
		var pool := ProjectilePoolClass.new()
		add_child(pool)
		pool.spawn_enemy(Vector2(100.0,300.0),Vector2(200.0,0.0),7.0,{"travel_model":"linear","radius":0.25,"life":0.325,"group":"lifetime-boundary"})
		var hits := 0
		for frame in int(ceil(0.4*float(fps))):
			var result := pool.step(1.0/float(fps),[],Vector2(164.6,300.0),0.25)
			hits+=(result.player_hits as Array).size()
			if pool.enemy_active.is_empty():
				break
		_check(hits==1,"Final partial lifetime segment must still resolve its swept hit at %d Hz" % fps)
		_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Lifetime-boundary hit must release exactly once at %d Hz" % fps)
		pool.free()


func _test_player_retirement_sweeps() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var pre_exit_target := [{"id":"pre-exit","position":Vector2(300.0,300.0),"radius":1.0}]
	pool.spawn_player(Vector2(100.0,300.0),Vector2(2000.0,0.0),7.0,{"radius":1.0,"life":2.0,"behavior":"rail_spine"})
	var crossing := pool.step(1.0,pre_exit_target,Vector2.ZERO,0.0)
	var crossing_hits := crossing.target_hits as Array
	_check(crossing_hits.size()==1,"Player projectile must register exactly one hit before leaving active bounds in the same frame")
	var crossing_hit := crossing_hits[0] as Dictionary if crossing_hits.size()==1 else {}
	_check(String(crossing_hit.get("id",""))=="pre-exit" and is_equal_approx(float(crossing_hit.get("damage",0.0)),7.0) and String(crossing_hit.get("behavior",""))=="rail_spine" and Vector2(crossing_hit.get("position",Vector2.ZERO)).x<ProjectilePoolClass.PLAYER_ACTIVE_BOUNDS.end.x,"Pre-exit sweep must preserve target identity, damage, behavior and an in-bounds hit position")
	_check(pool.player_active.is_empty() and pool._player_free.size()==1,"Bounds-crossing player projectile must release exactly once after its valid sweep")

	var after_exit_target := [{"id":"after-exit","position":Vector2(800.0,300.0),"radius":1.0}]
	pool.spawn_player(Vector2(100.0,300.0),Vector2(2000.0,0.0),7.0,{"radius":1.0,"life":2.0,"behavior":"rail_spine"})
	var beyond_bounds := pool.step(1.0,after_exit_target,Vector2.ZERO,0.0)
	_check((beyond_bounds.target_hits as Array).is_empty(),"Player collision must ignore every path portion after the first active-bounds exit")
	_check(pool.player_active.is_empty() and pool._player_free.size()==1,"Post-exit rejection must retain exact single-release pool ownership")

	var final_life_target := [{"id":"final-life","position":Vector2(164.6,340.0),"radius":0.25}]
	pool.spawn_player(Vector2(100.0,340.0),Vector2(200.0,0.0),5.0,{"radius":0.25,"life":0.325,"behavior":"pulse"})
	var final_life := pool.step(0.4,final_life_target,Vector2.ZERO,0.0)
	_check((final_life.target_hits as Array).size()==1,"Player projectile must sweep its exact final partial-lifetime segment before expiry")
	_check(pool.player_active.is_empty() and pool._player_free.size()==1,"Final-lifetime hit and expiry must release the player projectile exactly once")

	var expired_path_target := [{"id":"expired-path","position":Vector2(166.0,360.0),"radius":0.25}]
	pool.spawn_player(Vector2(100.0,360.0),Vector2(200.0,0.0),5.0,{"radius":0.25,"life":0.325,"behavior":"pulse"})
	var expired_path := pool.step(0.4,expired_path_target,Vector2.ZERO,0.0)
	_check((expired_path.target_hits as Array).is_empty(),"Player collision must ignore motion that would occur after authored lifetime")
	_check(pool.player_active.is_empty() and pool._player_free.size()==1,"Lifetime clipping without a hit must preserve exact single-release ownership")

	var repeated_target := {"id":"repeat","position":Vector2(140.0,400.0),"radius":1.0}
	var repeat_target := [repeated_target,repeated_target]
	pool.spawn_player(Vector2(100.0,400.0),Vector2(200.0,0.0),10.0,{"radius":1.0,"life":2.0,"pierce":2,"behavior":"needle"})
	var first_pass := pool.step(0.3,repeat_target,Vector2.ZERO,0.0)
	_check((first_pass.target_hits as Array).size()==1,"Piercing player projectile must report its first swept target hit exactly once")
	var piercing_live := pool.player_active[0] as Dictionary if pool.player_active.size()==1 else {}
	_check(pool.player_active.size()==1 and int(piercing_live.get("pierce",-1))==1 and is_equal_approx(float(piercing_live.get("damage",0.0)),9.0) and String(piercing_live.get("behavior",""))=="needle","Swept resolution must preserve pierce decrement, damage falloff and behavior")
	var second_pass := pool.step(0.3,repeat_target,Vector2.ZERO,0.0)
	_check((second_pass.target_hits as Array).is_empty() and pool.player_active.size()==1,"A piercing player projectile must never hit the same target twice across later frames")
	pool.clear_all()

	var overlap_targets := [
		{"id":"broad-first","position":Vector2(160.0,440.0),"radius":50.0},
		{"id":"narrow-second","position":Vector2(130.0,440.0),"radius":1.0},
	]
	pool.spawn_player(Vector2(100.0,440.0),Vector2(200.0,0.0),10.0,{"radius":0.0,"life":2.0,"behavior":"ordering"})
	var nonpiercing_order := pool.step(0.5,overlap_targets,Vector2.ZERO,0.0)
	var nonpiercing_hits := nonpiercing_order.target_hits as Array
	_check(nonpiercing_hits.size()==1 and String((nonpiercing_hits[0] as Dictionary).id)=="broad-first","Non-piercing sweep must select the earliest circle entry, not the closest target center")
	_check(nonpiercing_hits.size()==1 and absf(Vector2((nonpiercing_hits[0] as Dictionary).position).x-110.0)<0.001,"Player hit position must report the first physical contact point")
	_check(pool.player_active.is_empty() and pool._player_free.size()==1,"First-contact ordering must preserve exact non-piercing release ownership")

	pool.spawn_player(Vector2(100.0,440.0),Vector2(200.0,0.0),10.0,{"radius":0.0,"life":2.0,"pierce":1,"behavior":"ordering"})
	var piercing_order := pool.step(0.5,overlap_targets,Vector2.ZERO,0.0)
	var ordered_hits := piercing_order.target_hits as Array
	_check(ordered_hits.map(func(hit: Dictionary): return hit.id)==["broad-first","narrow-second"],"Piercing sweep must apply damage in first-contact order across different target radii")
	_check(ordered_hits.size()==2 and is_equal_approx(float((ordered_hits[0] as Dictionary).damage),10.0) and is_equal_approx(float((ordered_hits[1] as Dictionary).damage),9.0),"Piercing damage falloff must follow physical first-contact order")
	_check(pool._player_free.size()==1,"Player sweep fixtures must reuse one bounded projectile dictionary")
	pool.free()


func _test_bounds_exit_swept_collision_and_reuse() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var options := {"travel_model":"linear","radius":1.0,"life":2.0,"group":"bounds-exit"}
	pool.spawn_enemy(Vector2(100.0,300.0),Vector2(2000.0,0.0),7.0,options)
	var crossing := pool.step(1.0,[],Vector2(300.0,300.0),1.0)
	_check((crossing.player_hits as Array).size()==1,"High-speed projectile must hit exactly once before leaving active bounds in the same frame")
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Bounds-crossing hit must release its projectile exactly once")

	pool.spawn_enemy(Vector2(100.0,300.0),Vector2(2000.0,0.0),7.0,options)
	var near_miss := pool.step(1.0,[],Vector2(300.0,303.0),1.0)
	_check((near_miss.player_hits as Array).is_empty(),"Parallel high-speed path outside the combined radii must remain a near-miss while exiting bounds")
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Bounds-exit near-miss must still retire and pool exactly once")

	pool.spawn_enemy(Vector2(100.0,300.0),Vector2(2000.0,0.0),7.0,options)
	var beyond_bounds := pool.step(1.0,[],Vector2(800.0,300.0),1.0)
	_check((beyond_bounds.player_hits as Array).is_empty(),"Collision must ignore the portion of a high-speed path traveled after the projectile leaves active bounds")
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Out-of-bounds collision rejection must preserve single-release ownership")

	var reentry_options := {
		"travel_model":"recorded_path",
		"travel_parameters":{
			"path_duration":1.0,
			"path_points":[
				Vector2(100.0,250.0),
				Vector2(700.0,250.0),
				Vector2(700.0,450.0),
				Vector2(300.0,450.0),
			],
			"path_exit_velocity":Vector2.ZERO,
		},
		"radius":1.0,
		"life":2.0,
		"group":"recorded-reentry",
	}
	pool.spawn_enemy(Vector2(100.0,250.0),Vector2.ZERO,7.0,reentry_options)
	var reentry_only := pool.step(1.0,[],Vector2(500.0,450.0),1.0)
	_check((reentry_only.player_hits as Array).is_empty(),"Recorded path must not collide on a same-hitch re-entry after its first arena exit")
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Recorded path must retire at its first arena exit even when its final authored point re-enters")

	pool.spawn_enemy(Vector2(100.0,250.0),Vector2.ZERO,7.0,reentry_options)
	var before_first_exit := pool.step(1.0,[],Vector2(300.0,250.0),1.0)
	_check((before_first_exit.player_hits as Array).size()==1,"Recorded path must preserve exactly one true hit before its first arena exit")
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Pre-exit recorded-path hit must preserve exact single-release ownership")

	pool.spawn_enemy(Vector2(120.0,360.0),Vector2(20.0,0.0),2.0,{"travel_model":"linear","radius":2.0,"life":1.0,"group":"bounds-reuse"})
	var reused := pool.enemy_active[0] as Dictionary
	_check(String(reused.group)=="bounds-reuse" and Vector2(reused.position).is_equal_approx(Vector2(120.0,360.0)),"Dictionary reused after bounds retirement must reset position and ownership")
	var reused_result := pool.step(0.1,[],Vector2(500.0,500.0),1.0)
	_check((reused_result.player_hits as Array).is_empty() and pool.enemy_active.size()==1,"Reused bounds-retired projectile must not carry a stale collision or removal state")
	pool.clear_all()
	_check(pool._enemy_free.size()==1,"Bounds-exit reuse cycle must retain one bounded projectile dictionary")
	pool.free()


func _test_extreme_curve_hitch_fails_terminal() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(Vector2(100.0,-100.0),Vector2(1.0,0.0),7.0,{
		"travel_model":"node_link",
		"travel_parameters":{"link_amplitude":48.0,"link_frequency_hz":6.0,"link_phase_radians":0.0},
		"radius":0.25,
		"life":7.0,
		"group":"extreme-hitch",
	})
	# 16/3 seconds sampled in exactly 64 equal slices aliases every sine sample
	# back to y=-100, although the true curve exits through y=-120 each cycle.
	var aliased_reentry := pool.step(16.0/3.0,[],Vector2(104.0,-100.0),0.25)
	_check((aliased_reentry.player_hits as Array).is_empty(),"Over-budget curved hitch must fail terminal without a false post-exit player hit")
	_check(pool.enemy_active.is_empty() and pool._enemy_free.size()==1,"Over-budget curved hitch must retire and pool exactly once")

	pool.spawn_enemy(Vector2(100.0,300.0),Vector2(20.0,0.0),2.0,{"travel_model":"linear","radius":1.0,"life":1.0,"group":"post-overflow-reuse"})
	var reused := pool.enemy_active[0] as Dictionary
	_check(not bool(reused.frame_motion_overflowed) and String(reused.group)=="post-overflow-reuse","Dictionary reused after fail-terminal retirement must reset overflow and ownership")
	var normal_step := pool.step(0.1,[],Vector2(500.0,500.0),1.0)
	_check((normal_step.player_hits as Array).is_empty() and pool.enemy_active.size()==1,"Reused overflow-retired dictionary must retain normal bounded motion")
	pool.clear_all()
	pool.free()


func _test_lifetime_at_30_and_60_hz() -> void:
	for fps in [30,60]:
		var pool := ProjectilePoolClass.new()
		add_child(pool)
		for model in MODELS:
			_check(pool.spawn_enemy(ORIGIN,Vector2(12.0,0.0),3.0,{"travel_model":model,"travel_parameters":_parameters_for(model),"life":0.35}),"%s lifetime probe must spawn at %d Hz" % [model,fps])
		for frame in int(ceil(0.4*float(fps))):
			pool.step(1.0/float(fps),[],Vector2(-1000.0,-1000.0),0.0)
		_check(pool.enemy_active.is_empty(),"All travel models must expire at their authored lifetime at %d Hz" % fps)
		_check(pool._enemy_free.size()==MODELS.size(),"Expired travel models must return every dictionary to the pool at %d Hz" % fps)
		pool.free()


func _test_owner_filtered_cleanup() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	for model in MODELS:
		pool.spawn_enemy(ORIGIN,Vector2.ZERO,1.0,{
			"travel_model":model,
			"travel_parameters":_parameters_for(model),
			"group":"child:%s" % model,
			"parent_group":"lineage:room-wave",
			"effect_scope_id":"room-effect:lineage",
			"life":2.0,
		})
	_check(pool.enemy_group_size("lineage:room-wave")==MODELS.size(),"Parent lineage must own every travel-model descendant")
	var cleared_link := pool.clear_enemy_group_filtered("lineage:room-wave",["node_link"],1)
	_check(cleared_link==1,"Filtered cleanup must clear exactly its capped node-link descendant")
	_check(_active_model_count(pool,"node_link")==0,"Filtered cleanup must not leave a matching node-link descendant")
	_check(pool.enemy_group_size("lineage:room-wave")==MODELS.size()-1,"Filtered cleanup must preserve unrelated travel models in the same lineage")
	var cleared_rest := pool.clear_enemy_group("lineage:room-wave")
	_check(cleared_rest==MODELS.size()-1 and pool.enemy_active.is_empty(),"Parent cleanup must retire all remaining travel-model descendants")
	_check(pool._enemy_free.size()==MODELS.size(),"Ownership cleanup must return every descendant dictionary to the pool")
	pool.free()


func _test_owned_homing_cleanup_is_monotonic() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(Vector2(100.0,300.0),Vector2(200.0,0.0),3.0,{"travel_model":"linear","homing":1.4,"group":"child:linear","parent_group":"owner:a","life":2.0})
	pool.spawn_enemy(Vector2(100.0,320.0),Vector2(200.0,0.0),3.0,{"travel_model":"soft_homing","homing":1.8,"group":"owner:a","life":2.0})
	pool.spawn_enemy(Vector2(100.0,340.0),Vector2(200.0,0.0),3.0,{"travel_model":"linear","homing":0.0,"group":"child:safe","parent_group":"owner:a","life":2.0})
	pool.spawn_enemy(Vector2(100.0,360.0),Vector2(200.0,0.0),3.0,{"travel_model":"linear","homing":1.6,"group":"owner:b","life":2.0})
	var first_clear := pool.clear_enemy_homing_group("owner:a",1)
	_check(first_clear==1 and pool.enemy_group_size("owner:a")==2,"Homing cleanup cap must remove exactly one canonical group/parent-owned threat")
	_check(_active_owned_homing_count(pool,"owner:a")==1,"Capped cleanup must leave one still-homing owned threat, never a straightened replacement")
	var second_clear := pool.clear_enemy_homing_group("owner:a",ProjectilePoolClass.MAX_ENEMY)
	_check(second_clear==1 and pool.enemy_group_size("owner:a")==1,"Second cleanup must remove the remaining owned homing threat and preserve same-owner non-homing fire")
	_check(_active_owned_homing_count(pool,"owner:a")==0,"Owned homing cleanup must leave no straight-path successor")
	_check(pool.enemy_group_size("owner:b")==1 and _active_owned_homing_count(pool,"owner:b")==1,"Owned homing cleanup must preserve every foreign-group homing threat")
	_check(pool._enemy_free.size()==2,"Cleared homing threats must return their dictionaries to the bounded free list")
	pool.spawn_enemy(Vector2(120.0,380.0),Vector2.ZERO,1.0,{"travel_model":"linear","homing":0.0,"group":"reuse","life":1.0})
	var reused := pool.enemy_active.back() as Dictionary
	_check(is_zero_approx(float(reused.homing)) and String(reused.group)=="reuse","Reused homing dictionary must not retain stale tracking or ownership")
	pool.clear_all()
	pool.free()


func _test_pool_cap_and_reuse() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	for cycle in 4:
		var spawned := 0
		for index in ProjectilePoolClass.MAX_ENEMY:
			var model := String(MODELS[index%MODELS.size()])
			if pool.spawn_enemy(Vector2(270.0,500.0),Vector2.ZERO,1.0,{"travel_model":model,"travel_parameters":_parameters_for(model),"life":0.01}):
				spawned+=1
		_check(spawned==ProjectilePoolClass.MAX_ENEMY,"Pool cycle %d must accept exactly the hard enemy cap" % cycle)
		_check(not pool.spawn_enemy(Vector2(270.0,500.0),Vector2.ZERO,1.0),"Pool cycle %d must reject allocation beyond the hard cap" % cycle)
		_check(pool.enemy_active.size()==ProjectilePoolClass.MAX_ENEMY,"Pool cycle %d must never exceed MAX_ENEMY" % cycle)
		pool.step(0.02,[],Vector2(-1000.0,-1000.0),0.0)
		_check(pool.enemy_active.is_empty(),"Pool cycle %d must release every expired travel-model projectile" % cycle)
		_check(pool._enemy_free.size()==ProjectilePoolClass.MAX_ENEMY,"Pool cycle %d must reuse the same bounded free-list capacity" % cycle)
	pool.free()


func _simulate(model: String, fps: int, seconds: float, velocity: Vector2, parameters: Dictionary) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(ORIGIN,velocity,9.0,{
		"radius":7.0,
		"life":2.0,
		"travel_model":model,
		"travel_parameters":parameters,
	})
	var frames := int(round(seconds*float(fps)))
	for frame in frames:
		pool.step(1.0/float(fps),[],Vector2(-1000.0,-1000.0),0.0)
	var state := (pool.enemy_active[0] as Dictionary).duplicate(true)
	pool.clear_all()
	pool.free()
	return state


func _simulate_moving_homing_target(fps: int) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(ORIGIN,VELOCITY,5.0,{"travel_model":"soft_homing","homing":1.6,"radius":4.0,"life":2.0})
	for frame in int(round(0.8*float(fps))):
		var elapsed := float(frame+1)/float(fps)
		var moving_target := Vector2(350.0+45.0*elapsed,180.0+30.0*sin(elapsed*PI))
		pool.step(1.0/float(fps),[],moving_target,0.0)
	var state := (pool.enemy_active[0] as Dictionary).duplicate(true)
	pool.clear_all()
	pool.free()
	return state


func _simulate_player_homing(fps: int) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var target := [{"id":"homing-target","position":Vector2(450.0,180.0),"radius":0.1}]
	pool.spawn_player(Vector2(100.0,620.0),Vector2(0.0,-260.0),4.0,{
		"radius":2.0,
		"life":2.0,
		"homing":3.0,
		"behavior":"arc_swarm",
	})
	for frame in int(round(0.8*float(fps))):
		pool.step(1.0/float(fps),target,Vector2.ZERO,0.0)
	var state := (pool.player_active[0] as Dictionary).duplicate(true)
	pool.clear_all()
	pool.free()
	return state


func _simulate_until_player_hit(model: String, fps: int, target: Vector2, parameters: Dictionary) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var group_id := "wave:%s" % model
	pool.spawn_enemy(ORIGIN,VELOCITY,9.0,{
		"radius":5.0,
		"life":1.2,
		"travel_model":model,
		"travel_parameters":parameters,
		"group":group_id,
		"parent_group":"owner:%s" % model,
		"effect_scope_id":"effect:%s" % model,
	})
	var live := pool.enemy_active[0] as Dictionary
	_check(String(live.parent_group)=="owner:%s" % model,"%s spawn must preserve parent owner metadata at %d Hz" % [model,fps])
	_check(String(live.effect_scope_id)=="effect:%s" % model,"%s spawn must preserve effect lineage metadata at %d Hz" % [model,fps])
	var hit_count := 0
	var hit_group := ""
	for frame in int(ceil(0.8*float(fps))):
		var result := pool.step(1.0/float(fps),[],target,3.0)
		hit_count+=(result.player_hits as Array).size()
		if not (result.player_hits as Array).is_empty():
			hit_group=String(((result.player_hits as Array)[0] as Dictionary).group)
		if pool.enemy_active.is_empty():
			break
	var outcome := {"hit":hit_count>0,"hit_count":hit_count,"group":hit_group,"active":pool.enemy_active.size(),"free":pool._enemy_free.size()}
	pool.clear_all()
	pool.free()
	return outcome


func _simulate_safe_zone_crossing(model: String, fps: int, with_outside_target: bool) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var origin := Vector2(80.0,500.0)
	var safe_center := Vector2(270.0,500.0)
	var authored_safe_radius := 72.0
	var group_id := "safe-wave:%s" % model
	pool.spawn_enemy(origin,Vector2(400.0,0.0),8.0,{
		"radius":6.0,
		"life":1.2,
		"travel_model":model,
		"travel_parameters":_safe_parameters_for(model,origin),
		"safe_position":safe_center,
		"safe_radius":authored_safe_radius,
		"group":group_id,
		"parent_group":"safe-owner:%s" % model,
	})
	var spawned_bullet := pool.enemy_active[0] as Dictionary
	var spawn_surface_clearance := Vector2(spawned_bullet.position).distance_to(safe_center)-float(spawned_bullet.radius)
	var minimum_surface_clearance := INF
	var minimum_center_clearance := INF
	var maximum_radius := 0.0
	var samples := 0
	var hit := false
	var hit_group := ""
	var final_position := Vector2(spawned_bullet.position)
	var final_velocity := Vector2(spawned_bullet.velocity)
	var frame_start := Vector2(spawned_bullet.position)
	var maximum_frame_segments := 0
	var frame_chain_integrity := true
	var frame_chain_overflowed := false
	var player_position := Vector2(140.0,500.0) if with_outside_target else Vector2(-1000.0,-1000.0)
	var player_radius := 18.0 if with_outside_target else 0.0
	for frame in int(round(0.8*float(fps))):
		var result := pool.step(1.0/float(fps),[],player_position,player_radius)
		if not (result.player_hits as Array).is_empty():
			hit=true
			hit_group=String(((result.player_hits as Array)[0] as Dictionary).group)
		if pool.enemy_active.is_empty():
			break
		var bullet := pool.enemy_active[0] as Dictionary
		var frame_points := bullet.frame_motion_points as Array
		maximum_frame_segments=maxi(maximum_frame_segments,maxi(0,frame_points.size()-1))
		frame_chain_integrity=frame_chain_integrity and frame_points.size()>=2 and Vector2(frame_points[0]).is_equal_approx(frame_start) and Vector2(frame_points[frame_points.size()-1]).is_equal_approx(Vector2(bullet.position))
		frame_chain_overflowed=frame_chain_overflowed or bool(bullet.frame_motion_overflowed)
		final_position=Vector2(bullet.position)
		final_velocity=Vector2(bullet.velocity)
		var radius := float(bullet.radius)
		var center_clearance := Vector2(bullet.position).distance_to(safe_center)
		minimum_center_clearance=minf(minimum_center_clearance,center_clearance)
		minimum_surface_clearance=minf(minimum_surface_clearance,center_clearance-radius)
		maximum_radius=maxf(maximum_radius,radius)
		samples+=1
		frame_start=Vector2(bullet.position)
	var outcome := {
		"spawn_surface_clearance":spawn_surface_clearance,
		"samples":samples,
		"minimum_surface_clearance":minimum_surface_clearance,
		"minimum_center_clearance":minimum_center_clearance,
		"maximum_radius":maximum_radius,
		"authored_safe_radius":authored_safe_radius,
		"hit":hit,
		"group":hit_group,
		"final_position":final_position,
		"final_velocity":final_velocity,
		"maximum_frame_segments":maximum_frame_segments,
		"frame_chain_integrity":frame_chain_integrity,
		"frame_chain_overflowed":frame_chain_overflowed,
	}
	pool.clear_all()
	pool.free()
	return outcome


func _simulate_safe_moving_homing(fps: int) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var origin := Vector2(80.0,500.0)
	var safe_center := Vector2(270.0,500.0)
	var safe_radius := 72.0
	pool.spawn_enemy(origin,Vector2(400.0,0.0),8.0,{
		"radius":6.0,
		"life":1.2,
		"travel_model":"soft_homing",
		"homing":1.6,
		"safe_position":safe_center,
		"safe_radius":safe_radius,
		"group":"safe-homing-live",
		"parent_group":"safe-homing-owner",
		"effect_scope_id":"safe-homing-effect",
	})
	var bullet := pool.enemy_active[0] as Dictionary
	var last_position := Vector2(bullet.position)
	var last_origin_distance := last_position.distance_to(origin)
	var minimum_surface_clearance := last_position.distance_to(safe_center)-float(bullet.radius)
	var minimum_external_swept_clearance := INF
	var largest_origin_distance_drop := 0.0
	var minimum_offset_after_detour := INF
	var maximum_frame_displacement := 0.0
	var detour_started := false
	var unexpected_hit := false
	var maximum_frame_segments := 0
	var frame_chain_integrity := true
	var frame_chain_overflowed := false
	for frame in int(round(0.8*float(fps))):
		var elapsed := float(frame+1)/float(fps)
		var moving_target := Vector2(540.0,480.0+40.0*elapsed)
		var result := pool.step(1.0/float(fps),[],moving_target,0.0)
		unexpected_hit=unexpected_hit or not (result.player_hits as Array).is_empty()
		if pool.enemy_active.is_empty():
			break
		bullet=pool.enemy_active[0] as Dictionary
		var position := Vector2(bullet.position)
		var frame_points := bullet.frame_motion_points as Array
		maximum_frame_segments=maxi(maximum_frame_segments,maxi(0,frame_points.size()-1))
		frame_chain_integrity=frame_chain_integrity and frame_points.size()>=2 and Vector2(frame_points[0]).is_equal_approx(last_position) and Vector2(frame_points[frame_points.size()-1]).is_equal_approx(position)
		frame_chain_overflowed=frame_chain_overflowed or bool(bullet.frame_motion_overflowed)
		maximum_frame_displacement=maxf(maximum_frame_displacement,position.distance_to(last_position))
		var clearance := safe_radius+float(bullet.radius)
		minimum_external_swept_clearance=minf(minimum_external_swept_clearance,_segment_surface_clearance(last_position,position,safe_center,clearance))
		minimum_surface_clearance=minf(minimum_surface_clearance,position.distance_to(safe_center)-float(bullet.radius))
		var origin_distance := position.distance_to(origin)
		largest_origin_distance_drop=maxf(largest_origin_distance_drop,last_origin_distance-origin_distance)
		var offset_length := Vector2(bullet.motion_offset).length()
		if offset_length>1.0:
			detour_started=true
		if detour_started:
			minimum_offset_after_detour=minf(minimum_offset_after_detour,offset_length)
		last_origin_distance=origin_distance
		last_position=position
	var outcome := {
		"safe_radius":safe_radius,
		"safe_substeps":int(bullet.get("safe_substep_count",0)) if not pool.enemy_active.is_empty() else 0,
		"minimum_surface_clearance":minimum_surface_clearance,
		"minimum_internal_swept_clearance":float(bullet.get("safe_min_swept_clearance",-INF)) if not pool.enemy_active.is_empty() else -INF,
		"minimum_external_swept_clearance":minimum_external_swept_clearance,
		"final_motion_offset":Vector2(bullet.get("motion_offset",Vector2.ZERO)).length() if not pool.enemy_active.is_empty() else 0.0,
		"largest_origin_distance_drop":largest_origin_distance_drop,
		"minimum_offset_after_detour":minimum_offset_after_detour if detour_started else 0.0,
		"maximum_frame_displacement":maximum_frame_displacement,
		"unexpected_hit":unexpected_hit,
		"final_position":Vector2(bullet.get("position",Vector2.ZERO)) if not pool.enemy_active.is_empty() else Vector2.ZERO,
		"final_velocity":Vector2(bullet.get("velocity",Vector2.ZERO)) if not pool.enemy_active.is_empty() else Vector2.ZERO,
		"maximum_frame_segments":maximum_frame_segments,
		"frame_chain_integrity":frame_chain_integrity,
		"frame_chain_overflowed":frame_chain_overflowed,
	}
	pool.clear_all()
	pool.free()
	return outcome


func _simulate_safe_homing_outside_hit(fps: int) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(Vector2(80.0,500.0),Vector2(400.0,0.0),8.0,{
		"radius":6.0,
		"life":1.2,
		"travel_model":"soft_homing",
		"homing":1.6,
		"safe_position":Vector2(270.0,500.0),
		"safe_radius":72.0,
		"group":"safe-homing-live",
		"parent_group":"safe-homing-owner",
	})
	var hits := 0
	var group := ""
	for frame in int(round(0.4*float(fps))):
		var result := pool.step(1.0/float(fps),[],Vector2(140.0,500.0),10.0)
		hits+=(result.player_hits as Array).size()
		if not (result.player_hits as Array).is_empty():
			group=String(((result.player_hits as Array)[0] as Dictionary).group)
		if pool.enemy_active.is_empty():
			break
	var outcome := {"hit":hits==1,"group":group,"free":pool._enemy_free.size()}
	pool.clear_all()
	pool.free()
	return outcome


func _simulate_protected_chord_case(model: String, hitch: bool) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var origin := Vector2(191.0,500.0)
	var safe_center := Vector2(270.0,500.0)
	var safe_radius := 72.0
	var projectile_radius := 6.0
	var player_radius := 62.0
	var frame_delta := 0.55 if hitch else 0.3
	var speed := 700.0 if hitch else 1400.0
	var velocity := Vector2(speed,0.0)
	var parameters := _protected_chord_parameters(model,origin,velocity,frame_delta)
	pool.spawn_enemy(origin,velocity,8.0,{
		"radius":projectile_radius,
		"life":1.5,
		"travel_model":model,
		"travel_parameters":parameters,
		"homing":1.6 if model=="soft_homing" else 0.0,
		"safe_position":safe_center,
		"safe_radius":safe_radius,
		"group":"protected:%s" % model,
		"parent_group":"protected-owner:%s" % model,
	})
	var frame_start := Vector2((pool.enemy_active[0] as Dictionary).position)
	var result := pool.step(frame_delta,[],safe_center,player_radius)
	var hit_count := (result.player_hits as Array).size()
	var active := not pool.enemy_active.is_empty()
	var frame_end := frame_start
	var points: Array = []
	var radii: Array = []
	var safe_swept_clearance := -INF
	var overflowed := true
	var group := ""
	if active:
		var bullet := pool.enemy_active[0] as Dictionary
		frame_end=Vector2(bullet.position)
		points=bullet.frame_motion_points as Array
		radii=bullet.frame_motion_radii as Array
		safe_swept_clearance=float(bullet.safe_min_swept_clearance)
		overflowed=bool(bullet.frame_motion_overflowed)
		group=String(bullet.group)
	var outer_chord_clearance := _segment_surface_clearance(frame_start,frame_end,safe_center,player_radius+projectile_radius)
	var internal_clearance := INF
	if points.size()>=2:
		for point_index in range(points.size()-1):
			var radius_at_segment := player_radius+maxf(float(radii[point_index]),float(radii[point_index+1])) if radii.size()==points.size() else player_radius+projectile_radius
			internal_clearance=minf(internal_clearance,_segment_surface_clearance(Vector2(points[point_index]),Vector2(points[point_index+1]),safe_center,radius_at_segment))
	var chain_integrity := active and points.size()==radii.size() and points.size()>=2 and Vector2(points[0]).is_equal_approx(frame_start) and Vector2(points[points.size()-1]).is_equal_approx(frame_end)
	var outcome := {
		"model":model,
		"active":active,
		"hit_count":hit_count,
		"outer_chord_clearance":outer_chord_clearance,
		"internal_clearance":internal_clearance,
		"safe_swept_clearance":safe_swept_clearance,
		"frame_segments":maxi(0,points.size()-1),
		"overflowed":overflowed,
		"chain_integrity":chain_integrity,
		"group":group,
	}
	pool.clear_all()
	pool.free()
	return outcome


func _protected_chord_parameters(model: String, origin: Vector2, velocity: Vector2, duration: float) -> Dictionary:
	match model:
		"expanding":
			return {"expansion_rate":30.0,"expansion_max_scale":4.0}
		"node_link":
			return {"link_amplitude":8.0,"link_frequency_hz":1.0}
		"lunge":
			return {"windup_seconds":0.0,"burst_seconds":1.0,"windup_multiplier":1.0,"burst_multiplier":1.0,"recovery_multiplier":1.0}
		"recorded_path":
			return {
				"path_duration":duration,
				"path_points":[origin,origin+velocity*duration*0.33,origin+velocity*duration*0.66,origin+velocity*duration],
				"path_exit_velocity":velocity,
			}
	return {}


func _simulate_expanding_sweep_boundary(fps: int, player_y: float, velocity: Vector2) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_enemy(Vector2(100.0,300.0),velocity,5.0,{
		"travel_model":"expanding",
		"travel_parameters":{"expansion_rate":16.0,"expansion_max_scale":4.0},
		"radius":7.0,
		"life":1.0,
		"group":"expanding-boundary",
	})
	var hits := 0
	var hit_position := Vector2.ZERO
	for frame in int(round((1.0/30.0)*float(fps))):
		var result := pool.step(1.0/float(fps),[],Vector2(100.0,player_y),12.0)
		hits+=(result.player_hits as Array).size()
		if not (result.player_hits as Array).is_empty():
			hit_position=Vector2(((result.player_hits as Array)[0] as Dictionary).position)
		if pool.enemy_active.is_empty():
			break
	var outcome := {"hits":hits,"hit_position":hit_position,"free":pool._enemy_free.size()}
	pool.clear_all()
	pool.free()
	return outcome


func _simulate_unprotected_nonlinear_hitch(model: String, player_position: Vector2, parameters: Dictionary, fps: float, homing_target: Vector2 = Vector2.ZERO, homing: float = 0.0) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var velocity := Vector2(100.0,0.0) if model=="node_link" else Vector2(400.0,0.0)
	var options := {
		"travel_model":model,
		"travel_parameters":parameters,
		"homing":homing,
		"radius":1.0,
		"life":1.0,
		"group":"unprotected:%s" % model,
	}
	if homing>0.0:
		options.frozen_target=homing_target
	var maximum_segments := 0
	var overflowed := false
	var frame_count := 1 if fps<=0.0 else int(round(float(fps)/3.0))
	var delta := 1.0/3.0 if fps<=0.0 else 1.0/fps
	pool.spawn_enemy(Vector2(100.0,300.0),velocity,5.0,options)
	for frame in frame_count:
		pool.step(delta,[],Vector2(-1000.0,-1000.0),0.0)
		if not pool.enemy_active.is_empty():
			var bullet := pool.enemy_active[0] as Dictionary
			maximum_segments=maxi(maximum_segments,(bullet.frame_motion_points as Array).size()-1)
			overflowed=overflowed or bool(bullet.frame_motion_overflowed)
	pool.clear_enemy()
	pool.spawn_enemy(Vector2(100.0,300.0),velocity,5.0,options)
	var hits := 0
	for frame in frame_count:
		var result := pool.step(delta,[],player_position,0.5)
		hits+=(result.player_hits as Array).size()
		if pool.enemy_active.is_empty():
			break
	var outcome := {
		"hits":hits,
		"free":pool._enemy_free.size(),
		"maximum_segments":maximum_segments,
		"overflowed":overflowed,
	}
	pool.clear_all()
	pool.free()
	return outcome


func _preview_options(model: String, origin: Vector2, safe: bool) -> Dictionary:
	var options := {
		"travel_model":model,
		"travel_parameters":_safe_parameters_for(model,origin) if safe else _parameters_for(model),
		"radius":6.0,
		"life":1.2,
		"preview_duration":0.8,
	}
	if model=="soft_homing":
		options.homing=1.6
		options.frozen_target=Vector2(520.0,460.0) if safe else Vector2(520.0,220.0)
	if safe:
		options.safe_position=Vector2(270.0,500.0)
		options.safe_radius=72.0
	return options


func _preview_live_parity(model: String, fps: int, safe: bool) -> Dictionary:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var origin := Vector2(80.0,500.0) if safe else ORIGIN
	var velocity := Vector2(400.0,0.0) if safe else VELOCITY
	var options := _preview_options(model,origin,safe)
	var preview := pool.preview_enemy_travel(origin,velocity,options)
	var spawned := pool.spawn_enemy(origin,velocity,1.0,options)
	var complete := spawned
	var maximum_age_delta := 0.0
	var maximum_position_delta := 0.0
	var maximum_radius_delta := 0.0
	var minimum_preview_safe_clearance := INF
	if safe:
		for sample in preview:
			minimum_preview_safe_clearance=minf(
				minimum_preview_safe_clearance,
				Vector2(sample.position).distance_to(Vector2(options.safe_position))-float(options.safe_radius)-float(sample.radius)
			)
	var sample_stride := int(round(ProjectilePoolClass.PREVIEW_SAMPLE_RATE_HZ/float(fps)))
	for frame in int(round(0.8*float(fps))):
		var result := pool.step(1.0/float(fps),[],Vector2(-1000.0,-1000.0),0.0)
		if not (result.player_hits as Array).is_empty() or pool.enemy_active.is_empty():
			complete=false
			break
		var preview_index := (frame+1)*sample_stride
		if preview_index>=preview.size():
			complete=false
			break
		var sample := preview[preview_index] as Dictionary
		var live := pool.enemy_active[0] as Dictionary
		maximum_age_delta=maxf(maximum_age_delta,absf(float(live.age)-float(sample.age)))
		maximum_position_delta=maxf(maximum_position_delta,Vector2(live.position).distance_to(Vector2(sample.position)))
		maximum_radius_delta=maxf(maximum_radius_delta,absf(float(live.radius)-float(sample.radius)))
	var outcome := {
		"complete":complete,
		"maximum_age_delta":maximum_age_delta,
		"maximum_position_delta":maximum_position_delta,
		"maximum_radius_delta":maximum_radius_delta,
		"minimum_preview_safe_clearance":minimum_preview_safe_clearance,
	}
	pool.clear_all()
	pool.free()
	return outcome


func _preview_samples_are_finite_and_ordered(samples: Array[Dictionary]) -> bool:
	if samples.is_empty() or samples.size()>ProjectilePoolClass.MAX_PREVIEW_SAMPLES:
		return false
	var previous_age := -INF
	for sample in samples:
		var age := float(sample.get("age",NAN))
		var position := Vector2(sample.get("position",Vector2(NAN,NAN)))
		var radius := float(sample.get("radius",NAN))
		if not is_finite(age) or not is_finite(position.x) or not is_finite(position.y) or not is_finite(radius) or radius<0.0:
			return false
		if age<=previous_age:
			return false
		previous_age=age
	return true


func _preview_sample_at_age(samples: Array[Dictionary], age: float) -> Dictionary:
	for sample in samples:
		if absf(float(sample.age)-age)<0.00001:
			return sample
	return {}


func _simulate_dynamic_homing_fallback(target: Vector2) -> Vector2:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	var options := _preview_options("soft_homing",ORIGIN,false)
	options.erase("frozen_target")
	pool.spawn_enemy(ORIGIN,VELOCITY,1.0,options)
	for frame in 24:
		pool.step(1.0/60.0,[],target,0.0)
	var position := Vector2((pool.enemy_active[0] as Dictionary).position)
	pool.clear_all()
	pool.free()
	return position


func _segment_surface_clearance(from: Vector2, to: Vector2, center: Vector2, clearance: float) -> float:
	var segment := to-from
	var closest_t := 0.0
	if segment.length_squared()>0.000001:
		closest_t=clampf((center-from).dot(segment)/segment.length_squared(),0.0,1.0)
	return (from+segment*closest_t).distance_to(center)-clearance


func _parameters_for(model: String) -> Dictionary:
	match model:
		"expanding":
			return {"expansion_rate":30.0,"expansion_max_scale":4.0}
		"node_link":
			return {"link_amplitude":14.0,"link_frequency_hz":1.0,"link_phase_radians":0.0}
		"lunge":
			return {"windup_seconds":0.2,"burst_seconds":0.2,"windup_multiplier":0.25,"burst_multiplier":3.0,"recovery_multiplier":0.5}
		"recorded_path":
			return {"path_duration":0.6,"path_points":[ORIGIN,Vector2(170.0,260.0),Vector2(195.0,340.0),Vector2(230.0,300.0)],"path_exit_velocity":VELOCITY}
	return {}


func _safe_parameters_for(model: String, origin: Vector2) -> Dictionary:
	match model:
		"expanding":
			return {"expansion_rate":30.0,"expansion_max_scale":4.0}
		"node_link":
			return {"link_amplitude":8.0,"link_frequency_hz":1.0}
		"lunge":
			return {"windup_seconds":0.16,"burst_seconds":0.22,"windup_multiplier":0.25,"burst_multiplier":2.4,"recovery_multiplier":0.72}
		"recorded_path":
			return {"path_duration":0.8,"path_points":[origin,Vector2(160.0,500.0),Vector2(380.0,500.0),Vector2(500.0,500.0)],"path_exit_velocity":Vector2(400.0,0.0)}
	return {}


func _collision_target(model: String) -> Vector2:
	match model:
		"expanding":
			return Vector2(185.0,318.0)
		"node_link":
			return Vector2(190.0,ORIGIN.y+14.0*sin(TAU*0.4))
		"lunge":
			return Vector2(185.0,300.0)
		"recorded_path":
			return Vector2(170.0,260.0)
	return Vector2(185.0,300.0)


func _active_model_count(pool: Node, model: String) -> int:
	var count := 0
	for raw_bullet in pool.enemy_active:
		if String((raw_bullet as Dictionary).get("travel_model",""))==model:
			count+=1
	return count


func _active_owned_homing_count(pool: Node, owner: String) -> int:
	var count := 0
	for raw_bullet in pool.enemy_active:
		var bullet := raw_bullet as Dictionary
		if String(bullet.get("group",""))!=owner and String(bullet.get("parent_group",""))!=owner:
			continue
		if float(bullet.get("homing",0.0))>0.0:
			count+=1
	return count
