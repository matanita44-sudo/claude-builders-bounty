class_name ProjectilePool
extends Node2D

const MAX_PLAYER := 190
const MAX_ENEMY := 350

const TRAVEL_LINEAR := "linear"
const TRAVEL_DELAYED_LINEAR := "delayed_linear"
const TRAVEL_SOFT_HOMING := "soft_homing"
const TRAVEL_EXPANDING := "expanding"
const TRAVEL_NODE_LINK := "node_link"
const TRAVEL_LUNGE := "lunge"
const TRAVEL_RECORDED_PATH := "recorded_path"
const SUPPORTED_TRAVEL_MODELS := [
	TRAVEL_LINEAR,
	TRAVEL_DELAYED_LINEAR,
	TRAVEL_SOFT_HOMING,
	TRAVEL_EXPANDING,
	TRAVEL_NODE_LINK,
	TRAVEL_LUNGE,
	TRAVEL_RECORDED_PATH,
]

const DEFAULT_EXPANSION_RATE := 16.0
const DEFAULT_EXPANSION_MAX_SCALE := 2.4
const DEFAULT_LINK_AMPLITUDE := 7.0
const DEFAULT_LINK_FREQUENCY_HZ := 1.75
const DEFAULT_LUNGE_WINDUP_SECONDS := 0.16
const DEFAULT_LUNGE_BURST_SECONDS := 0.22
const DEFAULT_LUNGE_WINDUP_MULTIPLIER := 0.25
const DEFAULT_LUNGE_BURST_MULTIPLIER := 2.4
const DEFAULT_LUNGE_RECOVERY_MULTIPLIER := 0.72
const DEFAULT_RECORDED_PATH_SECONDS := 0.72
const DEFAULT_RECORDED_PATH_AMPLITUDE := 7.0
const MAX_EXPANSION_RATE := 120.0
const MAX_EXPANSION_SCALE := 5.0
const MAX_LINK_AMPLITUDE := 48.0
const MAX_LINK_FREQUENCY_HZ := 6.0
const MAX_LUNGE_STAGE_SECONDS := 2.0
const MAX_LUNGE_MULTIPLIER := 4.0
const MAX_RECORDED_PATH_SECONDS := 3.0
const MAX_RECORDED_PATH_POINTS := 8
const MAX_RECORDED_PATH_AMPLITUDE := 48.0
const MAX_RECORDED_PATH_SPEED := 2000.0
const PLAYER_ACTIVE_BOUNDS := Rect2(-80.0,-100.0,700.0,1160.0)
const PLAYER_HOMING_SUBSTEP_SECONDS := 1.0/120.0
const MAX_PLAYER_FRAME_SEGMENTS := 64
const ENEMY_ACTIVE_BOUNDS := Rect2(-100.0,-120.0,740.0,1200.0)
const SAFE_MOTION_SUBSTEP_SECONDS := 1.0/120.0
const SAFE_HOMING_WARMUP_SECONDS := 0.05
const MAX_SAFE_FRAME_SEGMENTS := 64
const PREVIEW_SAMPLE_RATE_HZ := 60.0
const PREVIEW_STEP_SECONDS := 1.0/PREVIEW_SAMPLE_RATE_HZ
const DEFAULT_PREVIEW_SECONDS := 0.8
const MAX_PREVIEW_SECONDS := 0.82
const MAX_PREVIEW_SAMPLES := 51

var player_active: Array[Dictionary] = []
var enemy_active: Array[Dictionary] = []
var _player_free: Array[Dictionary] = []
var _enemy_free: Array[Dictionary] = []

func spawn_player(origin: Vector2, velocity: Vector2, damage: float, options: Dictionary = {}) -> bool:
	if player_active.size() >= MAX_PLAYER:
		return false
	var bullet: Dictionary = _player_free.pop_back() if not _player_free.is_empty() else {}
	var frame_motion_points: Array = bullet.get("frame_motion_points",[]) as Array
	bullet.clear()
	frame_motion_points.clear()
	bullet.merge({
		"position": origin,
		"previous": origin,
		"velocity": velocity,
		"damage": damage,
		"radius": float(options.get("radius", 4.0)),
		"life": float(options.get("life", 1.6)),
		"pierce": int(options.get("pierce", 0)),
		"color": options.get("color", VisualTheme.FRIENDLY),
		"behavior": String(options.get("behavior", "pulse")),
		"homing": float(options.get("homing", 0.0)),
		"hit_ids": {},
		"frame_motion_points":frame_motion_points,
	})
	player_active.append(bullet)
	return true

func spawn_enemy(origin: Vector2, velocity: Vector2, damage: float, options: Dictionary = {}) -> bool:
	if enemy_active.size() >= MAX_ENEMY:
		return false
	var bullet: Dictionary = _enemy_free.pop_back() if not _enemy_free.is_empty() else {}
	_configure_enemy_bullet(bullet,origin,velocity,damage,options)
	enemy_active.append(bullet)
	return true

func preview_enemy_travel(origin: Vector2, velocity: Vector2, options: Dictionary = {}) -> Array[Dictionary]:
	var bullet: Dictionary = {}
	_configure_enemy_bullet(bullet,origin,velocity,0.0,options)
	var maximum_duration := minf(MAX_PREVIEW_SECONDS,float(bullet.max_life))
	var default_duration := minf(DEFAULT_PREVIEW_SECONDS,maximum_duration)
	var requested_duration := _bounded_parameter(options,"preview_duration",default_duration,0.0,MAX_PREVIEW_SECONDS)
	var preview_duration := minf(maximum_duration,requested_duration)
	var samples: Array[Dictionary] = [_enemy_preview_sample(bullet)]
	while float(bullet.age)<preview_duration-0.000001 and samples.size()<MAX_PREVIEW_SAMPLES:
		var sample_delta := minf(PREVIEW_STEP_SECONDS,preview_duration-float(bullet.age))
		if sample_delta<=0.000001:
			break
		bullet.previous=bullet.position
		_reset_enemy_frame_motion(bullet)
		bullet.age=float(bullet.age)+sample_delta
		_advance_enemy_travel(bullet,sample_delta,Vector2.ZERO)
		_finalize_enemy_frame_motion(bullet)
		bullet.life=float(bullet.max_life)-float(bullet.age)
		samples.append(_enemy_preview_sample(bullet))
	return samples

func _configure_enemy_bullet(bullet: Dictionary, origin: Vector2, velocity: Vector2, damage: float, options: Dictionary) -> void:
	var spawn_origin := origin if is_finite(origin.x) and is_finite(origin.y) else Vector2.ZERO
	var configured_velocity := velocity if is_finite(velocity.x) and is_finite(velocity.y) else Vector2.ZERO
	var safe_position := Vector2.ZERO
	var safe_position_value: Variant = _finite_vector2(options.get("safe_position",Vector2.ZERO))
	if safe_position_value!=null:
		safe_position=safe_position_value as Vector2
	var safe_radius := _finite_nonnegative_parameter(options.get("safe_radius",0.0),0.0)
	var projectile_radius := _finite_nonnegative_parameter(options.get("radius",7.0),7.0)
	var authored_life := _finite_nonnegative_parameter(options.get("life",7.0),7.0)
	var homing := _finite_nonnegative_parameter(options.get("homing",0.0),0.0)
	var travel_model := String(options.get("travel_model",TRAVEL_LINEAR))
	if travel_model not in SUPPORTED_TRAVEL_MODELS:
		travel_model=TRAVEL_LINEAR
	var raw_travel_parameters: Variant = options.get("travel_parameters",{})
	var travel_parameters: Dictionary = raw_travel_parameters as Dictionary if raw_travel_parameters is Dictionary else {}
	var frozen_target := Vector2.ZERO
	var frozen_target_enabled := false
	if options.has("frozen_target"):
		var frozen_target_value: Variant = _finite_vector2(options.get("frozen_target"))
		if frozen_target_value!=null:
			frozen_target=frozen_target_value as Vector2
			frozen_target_enabled=true
	var spawn_clearance := safe_radius+projectile_radius
	if safe_radius>0.0 and spawn_origin.distance_to(safe_position)<spawn_clearance:
		var outward := spawn_origin-safe_position
		if outward.length_squared()<0.001:
			outward=Vector2.RIGHT
		spawn_origin=safe_position+outward.normalized()*(spawn_clearance+1.0)
	var frame_motion_points: Array = bullet.get("frame_motion_points",[]) as Array
	var frame_motion_radii: Array = bullet.get("frame_motion_radii",[]) as Array
	bullet.clear()
	frame_motion_points.clear()
	frame_motion_radii.clear()
	bullet.merge({
		"position": spawn_origin,
		"previous": spawn_origin,
		"velocity": configured_velocity,
		"initial_velocity": configured_velocity,
		"motion_origin": spawn_origin,
		"motion_offset": Vector2.ZERO,
		"damage": damage,
		"radius": projectile_radius,
		"base_radius": projectile_radius,
		"life": authored_life,
		"max_life": authored_life,
		"shape": String(options.get("shape", "spike")),
		"homing": homing,
		"frozen_target_enabled": frozen_target_enabled,
		"frozen_target": frozen_target,
		"cause": String(options.get("cause", "hostile projectile")),
		"group": String(options.get("group", "")),
		"parent_group": String(options.get("parent_group", options.get("group", ""))),
		"effect_scope_id": String(options.get("effect_scope_id", "")),
		"visual_token": String(options.get("visual_token", "hostile_spike")),
		"travel_model": travel_model,
		"safe_position": safe_position,
		"safe_radius": safe_radius,
		"safe_min_swept_clearance": spawn_origin.distance_to(safe_position)-safe_radius-projectile_radius if safe_radius>0.0 else INF,
		"safe_substep_count": 0,
		"homing_target_initialized": false,
		"homing_previous_target": Vector2.ZERO,
		"frame_motion_points": frame_motion_points,
		"frame_motion_radii": frame_motion_radii,
		"frame_motion_overflowed": false,
		"frame_motion_budget_exceeded": false,
		"age": 0.0
	})
	_configure_enemy_travel(bullet,travel_parameters)

func _enemy_preview_sample(bullet: Dictionary) -> Dictionary:
	return {
		"age":float(bullet.age),
		"position":Vector2(bullet.position),
		"radius":float(bullet.radius),
	}

func step(delta: float, targets: Array, player_position: Vector2, player_radius: float) -> Dictionary:
	var result := {"target_hits": [], "player_hits": [], "phased": 0}
	for index in range(player_active.size() - 1, -1, -1):
		var bullet: Dictionary = player_active[index]
		bullet.previous = bullet.position
		var remaining_life := maxf(0.0,float(bullet.life))
		var frame_delta := maxf(0.0,delta)
		var travel_delta := minf(frame_delta,remaining_life)
		var motion_points: Array = _advance_player_motion(bullet,travel_delta,targets)
		bullet.life=remaining_life-travel_delta
		# Resolve the swept path before lifetime or bounds retirement. Only the
		# portion before the first arena exit belongs to the live projectile.
		var remove := _resolve_player_motion_hits(bullet,motion_points,targets,result.target_hits as Array)
		if remaining_life<=frame_delta+0.000001:
			remove=true
		if remove:
			_release_player(index)
	for index in range(enemy_active.size() - 1, -1, -1):
		var bullet: Dictionary = enemy_active[index]
		bullet.previous = bullet.position
		_reset_enemy_frame_motion(bullet)
		var previous_age := float(bullet.age)
		var remaining_life := maxf(0.0,float(bullet.max_life)-previous_age)
		var travel_delta := minf(maxf(0.0,delta),remaining_life)
		bullet.age = previous_age+travel_delta
		var travel_model := String(bullet.get("travel_model",TRAVEL_LINEAR))
		_advance_enemy_travel(bullet,travel_delta,player_position)
		_finalize_enemy_frame_motion(bullet)
		bullet.life = float(bullet.max_life)-float(bullet.age)
		var expired := remaining_life<=maxf(0.0,delta)+0.000001
		var motion_overflowed := bool(bullet.frame_motion_overflowed)
		var motion_untrusted := motion_overflowed or _enemy_over_budget_motion_requires_retirement(bullet,previous_age,float(bullet.age))
		var exited_bounds := _enemy_frame_exited_bounds(bullet) or _enemy_over_budget_continuous_exit(bullet,previous_age,float(bullet.age))
		var remove := motion_untrusted or exited_bounds
		# Bounds retirement happens after collision over the portion of this
		# frame's path that was still inside the active arena. A fast projectile
		# may cross the player and leave the bounds in the same frame. If a hitch
		# exceeds the bounded motion budget, retire without damage: a coarse curve
		# could otherwise exit and re-enter entirely between sampled endpoints.
		var motion_hit: Variant = _first_enemy_motion_hit(bullet,player_position,player_radius,previous_age,float(bullet.age)) if remaining_life>0.0 and not motion_untrusted else null
		if motion_hit!=null:
			result.player_hits.append({
				"damage": float(bullet.damage),
				"cause": String(bullet.cause),
				"position": motion_hit as Vector2,
				"group": String(bullet.group)
			})
			remove = true
		elif expired:
			remove=true
		if remove:
			_release_enemy(index)
	queue_redraw()
	return result

func clear_enemy() -> void:
	while not enemy_active.is_empty():
		_release_enemy(enemy_active.size() - 1)

func clear_enemy_group(group_id: String) -> int:
	if group_id.is_empty():
		return 0
	var cleared := 0
	for index in range(enemy_active.size() - 1, -1, -1):
		if String(enemy_active[index].get("group", "")) != group_id and String(enemy_active[index].get("parent_group", "")) != group_id:
			continue
		_release_enemy(index)
		cleared += 1
	if cleared > 0:
		queue_redraw()
	return cleared

func clear_enemy_group_filtered(group_id: String, travel_models: Array, max_count: int) -> int:
	if group_id.is_empty() or max_count <= 0:
		return 0
	var cleared := 0
	for index in range(enemy_active.size() - 1, -1, -1):
		var bullet := enemy_active[index] as Dictionary
		if String(bullet.get("group", "")) != group_id and String(bullet.get("parent_group", "")) != group_id:
			continue
		if not travel_models.is_empty() and String(bullet.get("travel_model", "linear")) not in travel_models:
			continue
		_release_enemy(index)
		cleared += 1
		if cleared >= max_count:
			break
	if cleared > 0:
		queue_redraw()
	return cleared

func clear_enemy_homing_group(group_id: String, max_count: int = MAX_ENEMY) -> int:
	if group_id.is_empty() or max_count <= 0:
		return 0
	var cleared := 0
	for index in range(enemy_active.size() - 1, -1, -1):
		var bullet := enemy_active[index] as Dictionary
		if String(bullet.get("group", "")) != group_id and String(bullet.get("parent_group", "")) != group_id:
			continue
		if float(bullet.get("homing", 0.0)) <= 0.0:
			continue
		_release_enemy(index)
		cleared += 1
		if cleared >= max_count:
			break
	if cleared > 0:
		queue_redraw()
	return cleared

func enemy_group_size(group_id: String) -> int:
	var count := 0
	for bullet in enemy_active:
		if String(bullet.get("group", "")) == group_id or String(bullet.get("parent_group", "")) == group_id:
			count += 1
	return count

func clear_all() -> void:
	clear_enemy()
	while not player_active.is_empty():
		_release_player(player_active.size() - 1)

func consume_enemy_near(centers: Array[Vector2], radius: float) -> int:
	var consumed := 0
	for index in range(enemy_active.size() - 1, -1, -1):
		var position_value: Vector2 = enemy_active[index].position
		var should_consume := false
		for center in centers:
			if position_value.distance_squared_to(center) <= radius * radius:
				should_consume = true
				break
		if should_consume:
			_release_enemy(index)
			consumed += 1
	if consumed > 0:
		queue_redraw()
	return consumed

func consume_enemy_near_capped(center: Vector2, radius: float, max_count: int, group_id: String = "", effect_scope_id: String = "") -> int:
	if radius <= 0.0 or max_count <= 0:
		return 0
	var consumed := 0
	for index in range(enemy_active.size() - 1, -1, -1):
		var bullet := enemy_active[index] as Dictionary
		if not effect_scope_id.is_empty() and String(bullet.get("effect_scope_id", "")) != effect_scope_id:
			continue
		if effect_scope_id.is_empty() and not group_id.is_empty() and String(bullet.get("group", "")) != group_id and String(bullet.get("parent_group", "")) != group_id:
			continue
		var combined_radius := radius + float(bullet.get("radius", 0.0))
		if Vector2(bullet.get("position", Vector2.ZERO)).distance_squared_to(center) > combined_radius * combined_radius:
			continue
		_release_enemy(index)
		consumed += 1
		if consumed >= max_count:
			break
	if consumed > 0:
		queue_redraw()
	return consumed

func _configure_enemy_travel(bullet: Dictionary, parameters: Dictionary) -> void:
	var travel_model := String(bullet.travel_model)
	match travel_model:
		TRAVEL_EXPANDING:
			bullet.expansion_rate=_bounded_parameter(parameters,"expansion_rate",DEFAULT_EXPANSION_RATE,0.0,MAX_EXPANSION_RATE)
			bullet.expansion_max_scale=_bounded_parameter(parameters,"expansion_max_scale",DEFAULT_EXPANSION_MAX_SCALE,1.0,MAX_EXPANSION_SCALE)
		TRAVEL_NODE_LINK:
			var initial_velocity := Vector2(bullet.initial_velocity)
			var direction := initial_velocity.normalized() if initial_velocity.length_squared()>0.0001 else Vector2.RIGHT
			bullet.link_normal=Vector2(-direction.y,direction.x)
			bullet.link_amplitude=_bounded_parameter(parameters,"link_amplitude",DEFAULT_LINK_AMPLITUDE,0.0,MAX_LINK_AMPLITUDE)
			bullet.link_frequency_hz=_bounded_parameter(parameters,"link_frequency_hz",DEFAULT_LINK_FREQUENCY_HZ,0.01,MAX_LINK_FREQUENCY_HZ)
			bullet.link_phase_radians=_bounded_parameter(parameters,"link_phase_radians",0.0,-TAU,TAU)
		TRAVEL_LUNGE:
			var initial_velocity := Vector2(bullet.initial_velocity)
			bullet.lunge_direction=initial_velocity.normalized() if initial_velocity.length_squared()>0.0001 else Vector2.ZERO
			bullet.lunge_speed=initial_velocity.length()
			bullet.lunge_windup_seconds=_bounded_parameter(parameters,"windup_seconds",DEFAULT_LUNGE_WINDUP_SECONDS,0.0,MAX_LUNGE_STAGE_SECONDS)
			bullet.lunge_burst_seconds=_bounded_parameter(parameters,"burst_seconds",DEFAULT_LUNGE_BURST_SECONDS,0.0,MAX_LUNGE_STAGE_SECONDS)
			bullet.lunge_windup_multiplier=_bounded_parameter(parameters,"windup_multiplier",DEFAULT_LUNGE_WINDUP_MULTIPLIER,0.0,MAX_LUNGE_MULTIPLIER)
			bullet.lunge_burst_multiplier=_bounded_parameter(parameters,"burst_multiplier",DEFAULT_LUNGE_BURST_MULTIPLIER,0.0,MAX_LUNGE_MULTIPLIER)
			bullet.lunge_recovery_multiplier=_bounded_parameter(parameters,"recovery_multiplier",DEFAULT_LUNGE_RECOVERY_MULTIPLIER,0.0,MAX_LUNGE_MULTIPLIER)
		TRAVEL_RECORDED_PATH:
			var duration_default := minf(DEFAULT_RECORDED_PATH_SECONDS,maxf(0.2,float(bullet.max_life)*0.8))
			bullet.recorded_path_seconds=_bounded_parameter(parameters,"path_duration",duration_default,0.05,MAX_RECORDED_PATH_SECONDS)
			bullet.recorded_path_points=_recorded_path_points(
				Vector2(bullet.motion_origin),
				Vector2(bullet.initial_velocity),
				float(bullet.recorded_path_seconds),
				parameters
			)
			bullet.recorded_path_exit_velocity=_bounded_vector_parameter(parameters.get("path_exit_velocity",bullet.initial_velocity),Vector2(bullet.initial_velocity),MAX_RECORDED_PATH_SPEED)

func _advance_enemy_travel(bullet: Dictionary, delta: float, player_position: Vector2) -> void:
	var travel_model := String(bullet.get("travel_model",TRAVEL_LINEAR))
	var prior_position := Vector2(bullet.position)
	var special_model := travel_model in [TRAVEL_EXPANDING,TRAVEL_NODE_LINK,TRAVEL_LUNGE,TRAVEL_RECORDED_PATH]
	var homing_model := not special_model and float(bullet.get("homing",0.0))>0.0 and float(bullet.age)<=1.5
	var homing_target := Vector2(bullet.frozen_target) if bool(bullet.get("frozen_target_enabled",false)) else player_position
	if homing_model and delta>0.0:
		_advance_homing_travel(bullet,float(bullet.age)-delta,float(bullet.age),homing_target)
		return
	if special_model and delta>0.0:
		_advance_special_travel(bullet,float(bullet.age)-delta,float(bullet.age))
		return
	var next_position := prior_position+Vector2(bullet.velocity)*delta
	var model_velocity := Vector2(bullet.velocity)
	if special_model:
		next_position=_special_position_at(bullet,float(bullet.age))+Vector2(bullet.motion_offset)
		model_velocity=_special_velocity_at(bullet,float(bullet.age))
	elif homing_model:
		var homing_direction := _homing_direction_at(bullet,float(bullet.age),homing_target)
		next_position=Vector2(bullet.motion_origin)+homing_direction*Vector2(bullet.initial_velocity).length()*float(bullet.age)
		model_velocity=homing_direction*Vector2(bullet.initial_velocity).length()
	if travel_model==TRAVEL_EXPANDING:
		bullet.radius=_expanding_radius_at(bullet,float(bullet.age))
	if float(bullet.get("safe_radius",0.0))>0.0 and delta>0.0:
		var clearance := float(bullet.safe_radius)+float(bullet.radius)
		var safe_velocity := _velocity_avoiding_safe_zone(
			prior_position,
			(next_position-prior_position)/delta,
			Vector2(bullet.safe_position),
			clearance,
			delta
		)
		next_position=_project_outside_safe_disk(prior_position+safe_velocity*delta,prior_position,Vector2(bullet.safe_position),clearance)
		model_velocity=(next_position-prior_position)/delta
	bullet.position=next_position
	bullet.velocity=model_velocity

func _advance_homing_travel(bullet: Dictionary, from_age: float, to_age: float, current_target: Vector2) -> void:
	var position := Vector2(bullet.position)
	var velocity := Vector2(bullet.velocity)
	var use_safe_zone := float(bullet.get("safe_radius",0.0))>0.0
	var start_target := Vector2(bullet.homing_previous_target) if bool(bullet.homing_target_initialized) else current_target
	var interval := maxf(0.000001,to_age-from_age)
	var sample_age := maxf(0.0,from_age)
	var requested_substep_count := maxi(1,int(ceil(interval/SAFE_MOTION_SUBSTEP_SECONDS-0.00001)))
	var substep_count := mini(requested_substep_count,MAX_SAFE_FRAME_SEGMENTS)
	if requested_substep_count>MAX_SAFE_FRAME_SEGMENTS:
		bullet.frame_motion_budget_exceeded=true
	var sample_delta := interval/float(substep_count)
	for substep_index in substep_count:
		sample_age+=sample_delta
		var target_alpha := clampf((sample_age-from_age)/interval,0.0,1.0)
		var sampled_target := start_target.lerp(current_target,target_alpha)
		var homing_age := maxf(0.0,sample_age-SAFE_HOMING_WARMUP_SECONDS) if use_safe_zone else sample_age
		var homing_direction := _homing_direction_at(bullet,homing_age,sampled_target)
		var requested_position := Vector2(bullet.motion_origin)+homing_direction*Vector2(bullet.initial_velocity).length()*sample_age+Vector2(bullet.motion_offset)
		var adjusted_position := requested_position
		if use_safe_zone:
			var clearance := float(bullet.safe_radius)+float(bullet.radius)
			var safe_velocity := _velocity_avoiding_safe_zone(
				position,
				(requested_position-position)/sample_delta,
				Vector2(bullet.safe_position),
				clearance,
				sample_delta
			)
			adjusted_position=_project_outside_safe_disk(position+safe_velocity*sample_delta,position,Vector2(bullet.safe_position),clearance)
			if adjusted_position.distance_squared_to(requested_position)>0.0001:
				bullet.motion_offset=Vector2(bullet.motion_offset)+(adjusted_position-requested_position)
			_record_safe_substep(bullet,position,adjusted_position,clearance)
		_append_enemy_frame_motion_point(bullet,adjusted_position)
		velocity=(adjusted_position-position)/sample_delta
		position=adjusted_position
	bullet.position=position
	bullet.velocity=velocity if use_safe_zone else _homing_direction_at(bullet,to_age,current_target)*Vector2(bullet.initial_velocity).length()
	bullet.homing_previous_target=current_target
	bullet.homing_target_initialized=true

func _homing_direction_at(bullet: Dictionary, age: float, target_position: Vector2) -> Vector2:
	var initial_velocity := Vector2(bullet.initial_velocity)
	if initial_velocity.length_squared()<=0.0001:
		return Vector2.ZERO
	var initial_direction := initial_velocity.normalized()
	var target_offset := target_position-Vector2(bullet.motion_origin)
	if target_offset.length_squared()<=0.0001:
		return initial_direction
	var response := 1.0-exp(-float(bullet.homing)*maxf(0.0,age))
	var blended := initial_direction.lerp(target_offset.normalized(),clampf(response,0.0,1.0))
	return blended.normalized() if blended.length_squared()>0.0001 else initial_direction

func _advance_special_travel(bullet: Dictionary, from_age: float, to_age: float) -> void:
	var position := Vector2(bullet.position)
	var velocity := Vector2(bullet.velocity)
	var use_safe_zone := float(bullet.get("safe_radius",0.0))>0.0
	var sample_age := maxf(0.0,from_age)
	var interval := maxf(0.000001,to_age-from_age)
	var requested_substep_count := maxi(1,int(ceil(interval/SAFE_MOTION_SUBSTEP_SECONDS-0.00001)))
	var substep_count := mini(requested_substep_count,MAX_SAFE_FRAME_SEGMENTS)
	if requested_substep_count>MAX_SAFE_FRAME_SEGMENTS:
		bullet.frame_motion_budget_exceeded=true
	var sample_delta := interval/float(substep_count)
	for substep_index in substep_count:
		sample_age+=sample_delta
		if String(bullet.travel_model)==TRAVEL_EXPANDING:
			bullet.radius=_expanding_radius_at(bullet,sample_age)
		var requested_position := _special_position_at(bullet,sample_age)+Vector2(bullet.motion_offset)
		var adjusted_position := requested_position
		if use_safe_zone:
			var clearance := float(bullet.safe_radius)+float(bullet.radius)
			var safe_velocity := _velocity_avoiding_safe_zone(
				position,
				(requested_position-position)/sample_delta,
				Vector2(bullet.safe_position),
				clearance,
				sample_delta
			)
			adjusted_position=_project_outside_safe_disk(position+safe_velocity*sample_delta,position,Vector2(bullet.safe_position),clearance)
			if adjusted_position.distance_squared_to(requested_position)>0.0001:
				bullet.motion_offset=Vector2(bullet.motion_offset)+(adjusted_position-requested_position)
			_record_safe_substep(bullet,position,adjusted_position,clearance)
		_append_enemy_frame_motion_point(bullet,adjusted_position)
		velocity=(adjusted_position-position)/sample_delta
		position=adjusted_position
	bullet.position=position
	bullet.velocity=velocity

func _special_position_at(bullet: Dictionary, age: float) -> Vector2:
	match String(bullet.travel_model):
		TRAVEL_EXPANDING:
			return Vector2(bullet.motion_origin)+Vector2(bullet.initial_velocity)*age
		TRAVEL_NODE_LINK:
			var phase := float(bullet.link_phase_radians)
			var angular_speed := TAU*float(bullet.link_frequency_hz)
			var lateral := float(bullet.link_amplitude)*(sin(phase+angular_speed*age)-sin(phase))
			return Vector2(bullet.motion_origin)+Vector2(bullet.initial_velocity)*age+Vector2(bullet.link_normal)*lateral
		TRAVEL_LUNGE:
			return Vector2(bullet.motion_origin)+Vector2(bullet.lunge_direction)*_lunge_distance_at(bullet,age)
		TRAVEL_RECORDED_PATH:
			return _recorded_position_at(bullet,age)
	return Vector2(bullet.position)

func _special_velocity_at(bullet: Dictionary, age: float) -> Vector2:
	match String(bullet.travel_model):
		TRAVEL_EXPANDING:
			return Vector2(bullet.initial_velocity)
		TRAVEL_NODE_LINK:
			var phase := float(bullet.link_phase_radians)
			var angular_speed := TAU*float(bullet.link_frequency_hz)
			return Vector2(bullet.initial_velocity)+Vector2(bullet.link_normal)*float(bullet.link_amplitude)*angular_speed*cos(phase+angular_speed*age)
		TRAVEL_LUNGE:
			return Vector2(bullet.lunge_direction)*float(bullet.lunge_speed)*_lunge_multiplier_at(bullet,age)
		TRAVEL_RECORDED_PATH:
			return _recorded_velocity_at(bullet,age)
	return Vector2(bullet.velocity)

func _expanding_radius_at(bullet: Dictionary, age: float) -> float:
	return minf(
		float(bullet.base_radius)*float(bullet.expansion_max_scale),
		float(bullet.base_radius)+float(bullet.expansion_rate)*age
	)

func _record_safe_substep(bullet: Dictionary, from: Vector2, to: Vector2, clearance: float) -> void:
	var segment := to-from
	var closest_t := 0.0
	if segment.length_squared()>0.000001:
		closest_t=clampf((Vector2(bullet.safe_position)-from).dot(segment)/segment.length_squared(),0.0,1.0)
	var swept_clearance := (from+segment*closest_t).distance_to(Vector2(bullet.safe_position))-clearance
	bullet.safe_min_swept_clearance=minf(float(bullet.safe_min_swept_clearance),swept_clearance)
	bullet.safe_substep_count=int(bullet.safe_substep_count)+1

func _reset_enemy_frame_motion(bullet: Dictionary) -> void:
	var points := bullet.frame_motion_points as Array
	var radii := bullet.frame_motion_radii as Array
	points.clear()
	radii.clear()
	points.append(Vector2(bullet.position))
	radii.append(float(bullet.radius))
	bullet.frame_motion_overflowed=false
	bullet.frame_motion_budget_exceeded=false

func _append_enemy_frame_motion_point(bullet: Dictionary, point: Vector2) -> void:
	var points := bullet.frame_motion_points as Array
	var radii := bullet.frame_motion_radii as Array
	if points.size()<MAX_SAFE_FRAME_SEGMENTS+1:
		points.append(point)
		radii.append(float(bullet.radius))
		return
	points[points.size()-1]=point
	radii[radii.size()-1]=float(bullet.radius)
	bullet.frame_motion_overflowed=true

func _finalize_enemy_frame_motion(bullet: Dictionary) -> void:
	var points := bullet.frame_motion_points as Array
	var radii := bullet.frame_motion_radii as Array
	if points.is_empty():
		points.append(Vector2(bullet.previous))
		radii.append(float(bullet.radius))
	if points.size()==1 or not Vector2(points[points.size()-1]).is_equal_approx(Vector2(bullet.position)):
		_append_enemy_frame_motion_point(bullet,Vector2(bullet.position))

func _first_enemy_motion_hit(bullet: Dictionary, center: Vector2, player_radius: float, from_age: float, to_age: float) -> Variant:
	if bool(bullet.get("frame_motion_budget_exceeded",false)) and float(bullet.get("safe_radius",0.0))<=0.0 and String(bullet.get("travel_model",TRAVEL_LINEAR))==TRAVEL_RECORDED_PATH:
		return _first_recorded_path_motion_hit(bullet,center,player_radius,from_age,to_age)
	var points := bullet.frame_motion_points as Array
	var radii := bullet.frame_motion_radii as Array
	if points.size()<2:
		if not ENEMY_ACTIVE_BOUNDS.has_point(Vector2(bullet.previous)):
			return null
		return _enemy_segment_hit_in_bounds(
			Vector2(bullet.previous),
			Vector2(bullet.position),
			center,
			player_radius+float(bullet.radius),
			player_radius+float(bullet.radius)
		)
	for point_index in range(points.size()-1):
		var from := Vector2(points[point_index])
		var to := Vector2(points[point_index+1])
		if not ENEMY_ACTIVE_BOUNDS.has_point(from):
			return null
		var start_radius := player_radius+float(radii[point_index]) if radii.size()==points.size() else player_radius+float(bullet.radius)
		var end_radius := player_radius+float(radii[point_index+1]) if radii.size()==points.size() else start_radius
		var hit: Variant = _enemy_segment_hit_in_bounds(from,to,center,start_radius,end_radius)
		if hit!=null:
			return hit
		if not ENEMY_ACTIVE_BOUNDS.has_point(to):
			# The first arena exit is terminal. Later authored curve points may
			# re-enter during this hitch, but they no longer belong to a live shot.
			return null
	return null

func _first_recorded_path_motion_hit(bullet: Dictionary, center: Vector2, player_radius: float, from_age: float, to_age: float) -> Variant:
	var ordered_points: Array[Vector2] = [_special_position_at(bullet,from_age)+Vector2(bullet.motion_offset)]
	var path_points := bullet.recorded_path_points as PackedVector2Array
	var duration := float(bullet.recorded_path_seconds)
	if path_points.size()>=2 and duration>0.0:
		for point_index in path_points.size():
			var point_age := duration*float(point_index)/float(path_points.size()-1)
			if point_age<=from_age+0.000001 or point_age>=to_age-0.000001:
				continue
			ordered_points.append(_special_position_at(bullet,point_age)+Vector2(bullet.motion_offset))
	ordered_points.append(_special_position_at(bullet,to_age)+Vector2(bullet.motion_offset))
	var combined_radius := player_radius+float(bullet.radius)
	for point_index in range(ordered_points.size()-1):
		var from := ordered_points[point_index]
		var to := ordered_points[point_index+1]
		if not ENEMY_ACTIVE_BOUNDS.has_point(from):
			return null
		var hit: Variant = _enemy_segment_hit_in_bounds(from,to,center,combined_radius,combined_radius)
		if hit!=null:
			return hit
		if not ENEMY_ACTIVE_BOUNDS.has_point(to):
			return null
	return null

func _enemy_over_budget_motion_requires_retirement(bullet: Dictionary, from_age: float, to_age: float) -> bool:
	if not bool(bullet.get("frame_motion_budget_exceeded",false)):
		return false
	# Safe-zone travel is the bounded substep simulation itself; preserving its
	# published chain is required for the authored detour contract. For the
	# closed-form curves below, inspect their unsampled continuous path.
	if float(bullet.get("safe_radius",0.0))>0.0:
		return false
	match String(bullet.get("travel_model",TRAVEL_LINEAR)):
		TRAVEL_NODE_LINK:
			return _node_link_interval_exits_bounds(bullet,from_age,to_age)
	# A long homing curve has no bounded analytic extrema representation here.
	# Retiring without damage is safer than accepting an aliased exit/re-entry.
	if float(bullet.get("homing",0.0))>0.0:
		return true
	return false

func _enemy_over_budget_continuous_exit(bullet: Dictionary, from_age: float, to_age: float) -> bool:
	if not bool(bullet.get("frame_motion_budget_exceeded",false)) or float(bullet.get("safe_radius",0.0))>0.0:
		return false
	if String(bullet.get("travel_model",TRAVEL_LINEAR))==TRAVEL_RECORDED_PATH:
		return _recorded_path_interval_exits_bounds(bullet,from_age,to_age)
	return false

func _node_link_interval_exits_bounds(bullet: Dictionary, from_age: float, to_age: float) -> bool:
	if _enemy_special_position_exits_bounds(bullet,from_age) or _enemy_special_position_exits_bounds(bullet,to_age):
		return true
	var angular_speed := TAU*float(bullet.link_frequency_hz)
	if angular_speed<=0.000001:
		return false
	var initial_velocity := Vector2(bullet.initial_velocity)
	var normal := Vector2(bullet.link_normal)
	var amplitude := float(bullet.link_amplitude)
	var phase := float(bullet.link_phase_radians)
	for component_index in 2:
		var linear_component := initial_velocity.x if component_index==0 else initial_velocity.y
		var normal_component := normal.x if component_index==0 else normal.y
		var derivative_amplitude := normal_component*amplitude*angular_speed
		if absf(derivative_amplitude)<=0.000001:
			continue
		var cosine_value := -linear_component/derivative_amplitude
		if cosine_value<-1.0 or cosine_value>1.0:
			continue
		var principal_angle := acos(clampf(cosine_value,-1.0,1.0))
		for signed_principal in [principal_angle,-principal_angle]:
			var first_cycle := int(ceil((phase+angular_speed*from_age-float(signed_principal))/TAU-0.000001))
			var last_cycle := int(floor((phase+angular_speed*to_age-float(signed_principal))/TAU+0.000001))
			for cycle_index in range(first_cycle,last_cycle+1):
				var candidate_age := (float(signed_principal)+TAU*float(cycle_index)-phase)/angular_speed
				if candidate_age<from_age-0.000001 or candidate_age>to_age+0.000001:
					continue
				if _enemy_special_position_exits_bounds(bullet,candidate_age):
					return true
	return false

func _recorded_path_interval_exits_bounds(bullet: Dictionary, from_age: float, to_age: float) -> bool:
	if _enemy_special_position_exits_bounds(bullet,from_age) or _enemy_special_position_exits_bounds(bullet,to_age):
		return true
	var points := bullet.recorded_path_points as PackedVector2Array
	var duration := float(bullet.recorded_path_seconds)
	if points.size()<2 or duration<=0.0:
		return false
	for point_index in points.size():
		var point_age := duration*float(point_index)/float(points.size()-1)
		if point_age<from_age-0.000001 or point_age>to_age+0.000001:
			continue
		if _enemy_special_position_exits_bounds(bullet,point_age):
			return true
	return false

func _enemy_special_position_exits_bounds(bullet: Dictionary, age: float) -> bool:
	var position := _special_position_at(bullet,age)+Vector2(bullet.motion_offset)
	return not ENEMY_ACTIVE_BOUNDS.has_point(position)

func _enemy_frame_exited_bounds(bullet: Dictionary) -> bool:
	var points := bullet.frame_motion_points as Array
	if points.is_empty():
		return not ENEMY_ACTIVE_BOUNDS.has_point(Vector2(bullet.position))
	for raw_point in points:
		if not ENEMY_ACTIVE_BOUNDS.has_point(Vector2(raw_point)):
			return true
	return false

func _enemy_segment_hit_in_bounds(from: Vector2, to: Vector2, center: Vector2, start_radius: float, end_radius: float) -> Variant:
	var interval := _segment_rect_interval(from,to,ENEMY_ACTIVE_BOUNDS)
	if interval.x<0.0:
		return null
	var clipped_from := from.lerp(to,interval.x)
	var clipped_to := from.lerp(to,interval.y)
	var clipped_start_radius := lerpf(start_radius,end_radius,interval.x)
	var clipped_end_radius := lerpf(start_radius,end_radius,interval.y)
	var hit_t := _swept_changing_radius_t(clipped_from,clipped_to,center,clipped_start_radius,clipped_end_radius)
	return clipped_from.lerp(clipped_to,hit_t) if hit_t>=0.0 else null

static func _segment_rect_interval(from: Vector2, to: Vector2, bounds: Rect2) -> Vector2:
	var direction := to-from
	var t_min := 0.0
	var t_max := 1.0
	var boundaries: Array[Vector2] = [
		Vector2(-direction.x,from.x-bounds.position.x),
		Vector2(direction.x,bounds.end.x-from.x),
		Vector2(-direction.y,from.y-bounds.position.y),
		Vector2(direction.y,bounds.end.y-from.y),
	]
	for boundary: Vector2 in boundaries:
		var divisor: float = boundary.x
		var distance: float = boundary.y
		if absf(divisor)<=0.000001:
			if distance<0.0:
				return Vector2(-1.0,-1.0)
			continue
		var ratio: float = distance/divisor
		if divisor<0.0:
			t_min=maxf(t_min,ratio)
		else:
			t_max=minf(t_max,ratio)
		if t_min>t_max:
			return Vector2(-1.0,-1.0)
	return Vector2(t_min,t_max)

func _swept_changing_radius_t(from: Vector2, to: Vector2, center: Vector2, start_radius: float, end_radius: float) -> float:
	var offset := from-center
	var travel := to-from
	var radius_delta := end_radius-start_radius
	var coefficient_a := travel.dot(travel)-radius_delta*radius_delta
	var coefficient_b := 2.0*(offset.dot(travel)-start_radius*radius_delta)
	var coefficient_c := offset.dot(offset)-start_radius*start_radius
	if coefficient_c<=0.0:
		return 0.0
	if absf(coefficient_a)<=0.000001:
		if coefficient_b>=-0.000001:
			return -1.0
		var linear_t := -coefficient_c/coefficient_b
		return linear_t if linear_t>=0.0 and linear_t<=1.0 else -1.0
	var discriminant := coefficient_b*coefficient_b-4.0*coefficient_a*coefficient_c
	if discriminant<0.0:
		return -1.0
	var root_scale := sqrt(maxf(0.0,discriminant))
	var first_root := (-coefficient_b-root_scale)/(2.0*coefficient_a)
	var second_root := (-coefficient_b+root_scale)/(2.0*coefficient_a)
	var earliest := minf(first_root,second_root)
	var latest := maxf(first_root,second_root)
	if earliest>=0.0 and earliest<=1.0:
		return earliest
	if latest>=0.0 and latest<=1.0:
		return latest
	return -1.0

func _lunge_distance_at(bullet: Dictionary, age: float) -> float:
	var remaining := maxf(0.0,age)
	var distance := 0.0
	var windup := float(bullet.lunge_windup_seconds)
	var windup_time := minf(remaining,windup)
	distance+=windup_time*float(bullet.lunge_windup_multiplier)
	remaining-=windup_time
	var burst := float(bullet.lunge_burst_seconds)
	var burst_time := minf(remaining,burst)
	distance+=burst_time*float(bullet.lunge_burst_multiplier)
	remaining-=burst_time
	distance+=remaining*float(bullet.lunge_recovery_multiplier)
	return distance*float(bullet.lunge_speed)

func _lunge_multiplier_at(bullet: Dictionary, age: float) -> float:
	if age<float(bullet.lunge_windup_seconds):
		return float(bullet.lunge_windup_multiplier)
	if age<float(bullet.lunge_windup_seconds)+float(bullet.lunge_burst_seconds):
		return float(bullet.lunge_burst_multiplier)
	return float(bullet.lunge_recovery_multiplier)

func _recorded_path_points(origin: Vector2, velocity: Vector2, duration: float, parameters: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var raw_points: Variant = parameters.get("path_points",[])
	var relative: bool = bool(parameters.get("path_relative",false)) if parameters.get("path_relative",false) is bool else false
	var raw_count: int = 0
	if raw_points is Array:
		raw_count=(raw_points as Array).size()
	elif raw_points is PackedVector2Array:
		raw_count=(raw_points as PackedVector2Array).size()
	if raw_count>=2 and raw_count<=MAX_RECORDED_PATH_POINTS:
		for raw_point in raw_points:
			var point_value: Variant = _finite_vector2(raw_point)
			if point_value==null:
				points.clear()
				break
			var point := point_value as Vector2
			if relative:
				if absf(point.x)>ENEMY_ACTIVE_BOUNDS.size.length() or absf(point.y)>ENEMY_ACTIVE_BOUNDS.size.length():
					points.clear()
					break
				point=origin+point
			elif not ENEMY_ACTIVE_BOUNDS.grow(160.0).has_point(point):
				points.clear()
				break
			points.append(point)
	if points.is_empty() or not points[0].is_equal_approx(origin):
		points.insert(0,origin)
	if points.size()>MAX_RECORDED_PATH_POINTS:
		points=PackedVector2Array([origin])
	if points.size()<2:
		var direction := velocity.normalized() if velocity.length_squared()>0.0001 else Vector2.RIGHT
		var normal := Vector2(-direction.y,direction.x)
		var amplitude := _bounded_parameter(parameters,"path_lateral_amplitude",DEFAULT_RECORDED_PATH_AMPLITUDE,0.0,MAX_RECORDED_PATH_AMPLITUDE)
		points.append(origin+velocity*duration*0.28+normal*amplitude)
		points.append(origin+velocity*duration*0.62-normal*amplitude)
		points.append(origin+velocity*duration)
	return points

func _recorded_position_at(bullet: Dictionary, age: float) -> Vector2:
	var points := bullet.recorded_path_points as PackedVector2Array
	var duration := float(bullet.recorded_path_seconds)
	if points.size()<2 or duration<=0.0:
		return Vector2(bullet.motion_origin)+Vector2(bullet.initial_velocity)*age
	if age>=duration:
		return points[points.size()-1]+Vector2(bullet.recorded_path_exit_velocity)*(age-duration)
	var segment_value := clampf(age/duration,0.0,1.0)*float(points.size()-1)
	var segment_index := mini(int(floor(segment_value)),points.size()-2)
	return points[segment_index].lerp(points[segment_index+1],segment_value-float(segment_index))

func _recorded_velocity_at(bullet: Dictionary, age: float) -> Vector2:
	var points := bullet.recorded_path_points as PackedVector2Array
	var duration := float(bullet.recorded_path_seconds)
	if points.size()<2 or duration<=0.0:
		return Vector2(bullet.initial_velocity)
	if age>=duration:
		return Vector2(bullet.recorded_path_exit_velocity)
	var segment_value := clampf(age/duration,0.0,1.0)*float(points.size()-1)
	var segment_index := mini(int(floor(segment_value)),points.size()-2)
	return (points[segment_index+1]-points[segment_index])*float(points.size()-1)/duration

func _bounded_parameter(parameters: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var raw: Variant = parameters.get(key,fallback)
	var value_type := typeof(raw)
	if value_type!=TYPE_INT and value_type!=TYPE_FLOAT:
		return fallback
	var value := float(raw)
	if not is_finite(value) or value<minimum or value>maximum:
		return fallback
	return value

func _finite_nonnegative_parameter(raw: Variant, fallback: float) -> float:
	if typeof(raw) not in [TYPE_INT,TYPE_FLOAT]:
		return fallback
	var value := float(raw)
	return maxf(0.0,value) if is_finite(value) else fallback

func _bounded_vector_parameter(raw: Variant, fallback: Vector2, max_length: float) -> Vector2:
	var candidate: Variant = _finite_vector2(raw)
	if candidate==null:
		return fallback
	var value := candidate as Vector2
	if value.length()>max_length:
		return fallback
	return value

func _finite_vector2(value: Variant) -> Variant:
	var parsed: Vector2
	if value is Vector2:
		parsed=value
	elif value is Array and (value as Array).size()==2:
		var x_value: Variant = (value as Array)[0]
		var y_value: Variant = (value as Array)[1]
		if typeof(x_value) not in [TYPE_INT,TYPE_FLOAT] or typeof(y_value) not in [TYPE_INT,TYPE_FLOAT]:
			return null
		parsed=Vector2(float(x_value),float(y_value))
	else:
		return null
	if not is_finite(parsed.x) or not is_finite(parsed.y):
		return null
	return parsed

func _project_outside_safe_disk(candidate: Vector2, previous: Vector2, center: Vector2, clearance: float) -> Vector2:
	var offset := candidate-center
	if offset.length_squared()>=clearance*clearance:
		return candidate
	if offset.length_squared()<=0.0001:
		offset=previous-center
	if offset.length_squared()<=0.0001:
		offset=Vector2.RIGHT
	return center+offset.normalized()*(clearance+0.01)

func _release_player(index: int) -> void:
	var bullet: Dictionary = player_active.pop_at(index)
	var frame_motion_points: Array = bullet.get("frame_motion_points",[]) as Array
	frame_motion_points.clear()
	bullet.clear()
	bullet.frame_motion_points=frame_motion_points
	_player_free.append(bullet)

func _release_enemy(index: int) -> void:
	var bullet: Dictionary = enemy_active.pop_at(index)
	var frame_motion_points: Array = bullet.get("frame_motion_points",[]) as Array
	var frame_motion_radii: Array = bullet.get("frame_motion_radii",[]) as Array
	frame_motion_points.clear()
	frame_motion_radii.clear()
	bullet.clear()
	bullet.frame_motion_points=frame_motion_points
	bullet.frame_motion_radii=frame_motion_radii
	_enemy_free.append(bullet)

func _advance_player_motion(bullet: Dictionary, duration: float, targets: Array) -> Array:
	var points := bullet.frame_motion_points as Array
	points.clear()
	points.append(Vector2(bullet.position))
	if duration<=0.0:
		return points
	var homing_rate := maxf(0.0,float(bullet.homing))
	if homing_rate<=0.0 or targets.is_empty():
		bullet.position=Vector2(bullet.position)+Vector2(bullet.velocity)*duration
		points.append(Vector2(bullet.position))
		return points
	var substep_count := clampi(
		int(ceil(duration/PLAYER_HOMING_SUBSTEP_SECONDS-0.00001)),
		1,
		MAX_PLAYER_FRAME_SEGMENTS
	)
	var substep_delta := duration/float(substep_count)
	var position := Vector2(bullet.position)
	var velocity := Vector2(bullet.velocity)
	for substep_index in substep_count:
		var nearest := _nearest_target(position,targets)
		if nearest.is_empty():
			position+=velocity*substep_delta
			points.append(position)
			continue
		var target_offset := Vector2(nearest.position)-position
		var desired := target_offset.normalized()*velocity.length()
		var decay := exp(-homing_rate*substep_delta)
		var response := 1.0-decay
		# This is the closed-form displacement and end velocity for a constant
		# desired velocity over the substep. Re-evaluating the target at 120 Hz
		# keeps curved pursuit stable at 30/60/120 Hz without changing the
		# authored homing response rate.
		position+=desired*substep_delta+(velocity-desired)*(response/homing_rate)
		velocity=desired+(velocity-desired)*decay
		points.append(position)
	bullet.position=position
	bullet.velocity=velocity
	return points

func _resolve_player_motion_hits(bullet: Dictionary, points: Array, targets: Array, target_hits: Array) -> bool:
	if points.is_empty() or not PLAYER_ACTIVE_BOUNDS.has_point(Vector2(points[0])):
		return true
	for point_index in range(points.size()-1):
		var from := Vector2(points[point_index])
		var to := Vector2(points[point_index+1])
		if not PLAYER_ACTIVE_BOUNDS.has_point(from):
			return true
		var active_interval := _segment_rect_interval(from,to,PLAYER_ACTIVE_BOUNDS)
		if active_interval.x<0.0:
			return true
		var active_from := from.lerp(to,active_interval.x)
		var active_to := from.lerp(to,active_interval.y)
		var collisions: Array[Dictionary] = []
		for raw_target in targets:
			var target: Dictionary = raw_target
			var target_id := String(target.get("id", ""))
			if bullet.hit_ids.has(target_id):
				continue
			var combined_radius := float(target.radius)+float(bullet.radius)
			var hit_t := _swept_changing_radius_t(
				active_from,
				active_to,
				Vector2(target.position),
				combined_radius,
				combined_radius
			)
			if hit_t>=0.0:
				collisions.append({"t":hit_t,"id":target_id})
		collisions.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.t)<float(second.t))
		for collision in collisions:
			var target_id := String(collision.id)
			if bullet.hit_ids.has(target_id):
				continue
			var hit_position := active_from.lerp(active_to,float(collision.t))
			target_hits.append({
				"id":target_id,
				"damage":float(bullet.damage),
				"position":hit_position,
				"behavior":bullet.behavior,
			})
			bullet.hit_ids[target_id]=true
			if int(bullet.pierce)>0:
				bullet.pierce=int(bullet.pierce)-1
				bullet.damage=float(bullet.damage)*0.9
			else:
				return true
		if active_interval.y<1.0-0.000001 or not PLAYER_ACTIVE_BOUNDS.has_point(to):
			# First exit is terminal; no later homing subsegment may re-enter and hit.
			return true
	return false

func _nearest_target(position: Vector2, targets: Array) -> Dictionary:
	var nearest: Dictionary = {}
	var best := INF
	for raw_target in targets:
		var target: Dictionary = raw_target
		var distance := position.distance_squared_to(Vector2(target.position))
		if distance < best:
			best = distance
			nearest = target
	return nearest

func _segment_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	return _segment_circle_t(a, b, center, radius) >= 0.0

func _segment_circle_t(a: Vector2, b: Vector2, center: Vector2, radius: float) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return 0.0 if a.distance_squared_to(center) <= radius * radius else -1.0
	var t := clampf((center - a).dot(ab) / length_squared, 0.0, 1.0)
	return t if (a + ab * t).distance_squared_to(center) <= radius * radius else -1.0

func _velocity_avoiding_safe_zone(position: Vector2, velocity: Vector2, safe_position: Vector2, safe_radius: float, delta: float) -> Vector2:
	if velocity.length_squared() <= 0.001 or safe_radius <= 0.0:
		return velocity
	var next_position := position+velocity*maxf(delta,0.05)
	if _segment_circle_t(position,next_position,safe_position,safe_radius) < 0.0:
		return velocity
	var outward := position-safe_position
	if outward.length_squared() <= 0.001:
		outward = Vector2.RIGHT
	var tangent := Vector2(-outward.y,outward.x).normalized()
	if velocity.dot(tangent)<0.0:
		tangent=-tangent
	return (outward.normalized()*0.74+tangent*0.67).normalized()*velocity.length()

func _draw() -> void:
	for bullet in player_active:
		var pos: Vector2 = bullet.position
		var dir := Vector2(bullet.velocity).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var color: Color = bullet.color
		match String(bullet.behavior):
			"rail":
				draw_line(pos - dir * 21.0, pos + dir * 17.0, color, 5.0)
				draw_line(pos - dir * 27.0, pos + dir * 20.0, Color(color, 0.24), 11.0)
			"scatter":
				draw_colored_polygon(PackedVector2Array([pos+dir*8,pos-dir*5+normal*5,pos-dir*5-normal*5]), color)
			"arc":
				draw_arc(pos, 7.0, -PI*0.65, PI*0.65, 8, color, 3.0)
			_:
				draw_line(pos - dir * 8.0, pos + dir * 8.0, color, 4.0)
	for bullet in enemy_active:
		var pos: Vector2 = bullet.position
		var radius := float(bullet.radius)
		var color := Color("#FF9B45") if bool(SettingsManager.get_value("projectile_contrast", false)) else VisualTheme.ENEMY
		match String(bullet.get("travel_model","linear")):
			"expanding":
				draw_circle(pos,radius,Color(color,0.16))
				draw_arc(pos,radius,0.0,TAU,18,color,3.0)
			"node_link":
				draw_arc(pos,radius,-PI*0.8,PI*0.8,9,color,3.0)
				draw_circle(pos,maxf(1.8,radius*0.3),Color.WHITE)
			"lunge":
				var direction := Vector2(bullet.velocity).normalized()
				var normal := Vector2(-direction.y,direction.x)
				var points := PackedVector2Array([pos+direction*radius*1.5,pos-direction*radius+normal*radius*0.65,pos-direction*radius-normal*radius*0.65])
				draw_colored_polygon(points,color)
				draw_polyline(PackedVector2Array(points+PackedVector2Array([points[0]])),Color(0.05,0.02,0.04,1),2.0)
			"recorded_path", "delayed_linear":
				draw_rect(Rect2(pos-Vector2(radius,radius),Vector2(radius*2.0,radius*2.0)),Color(color,0.18),true)
				draw_arc(pos,radius*1.25,float(bullet.age)*4.0,float(bullet.age)*4.0+PI*1.45,12,color,2.5)
			"soft_homing":
				draw_circle(pos,radius,Color(color,0.28))
				draw_arc(pos,radius,0.0,TAU,14,color,2.5)
				draw_circle(pos,maxf(1.8,radius*0.28),Color.WHITE)
			_:
				var points := PackedVector2Array([pos+Vector2(0,-radius),pos+Vector2(radius,0),pos+Vector2(0,radius),pos+Vector2(-radius,0)])
				draw_colored_polygon(points, color)
				draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]), Color(0.05,0.02,0.04,1), 2.0)
				draw_circle(pos, maxf(1.8, radius * 0.25), Color.WHITE)
