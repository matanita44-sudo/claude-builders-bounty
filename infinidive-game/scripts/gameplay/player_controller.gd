class_name PlayerController
extends Node2D

signal died(cause: String)
signal damaged(amount: float, cause: String)
signal dash_started
signal dash_ready
signal dash_gesture_requested(direction: Vector2)

const FINGER_OFFSET := Vector2(0.0, -82.0)
const DEAD_ZONE := 8.0

var max_health := 100.0
var health := 100.0
var shield_hits := 0
var responsiveness := 12.0
var max_speed := 620.0
var combat_bounds := Rect2(22.0, 390.0, 496.0, 455.0)
var invulnerability := 0.0
var dash_duration := 0.18
var dash_invulnerability := 0.34
var dash_cooldown := 2.15
var max_dash_charges := 1
var dash_charges := 1
var dash_recharge := 0.0
var dash_time := 0.0
var velocity := Vector2.ZERO
var _target := Vector2.ZERO
var _dragging := false
var _touch_id := -1
var _last_input := Vector2.UP
var _trail: Array[Vector2] = []
var _damage_flash := 0.0
var _dash_announced_empty := false
var controls_active := true
var _touch_started_ms := 0
var _touch_started_position := Vector2.ZERO
var _last_tap_ms := -1000
var _last_tap_position := Vector2.ZERO
var _flick_sent := false

func _ready() -> void:
	_target = position
	set_process_unhandled_input(true)
	queue_redraw()

func configure(stats: Dictionary) -> void:
	max_health = float(stats.get("max_health", 100.0))
	health = max_health
	responsiveness = float(stats.get("responsiveness", 12.0))
	dash_cooldown = float(stats.get("dash_cooldown", 2.15))
	dash_invulnerability = float(stats.get("dash_invulnerability", 0.34))
	max_dash_charges = maxi(1, int(stats.get("dash_charges", 1)))
	dash_charges = max_dash_charges
	shield_hits = int(stats.get("starting_shield", 0))

func _unhandled_input(event: InputEvent) -> void:
	# Menus, pause, and dive transitions own the touch surface while controls are
	# disabled. Do not retain a hidden drag target or emit a gesture that can leak
	# into the next playable state.
	if not controls_active:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_id == -1:
			var now := Time.get_ticks_msec()
			if String(SettingsManager.get_value("dash_method","button")) == "double_tap" and now - _last_tap_ms <= 310 and touch.position.distance_to(_last_tap_position) <= 72.0:
				dash_gesture_requested.emit((_target - position).normalized() if _target.distance_to(position) > DEAD_ZONE else Vector2.UP)
			_last_tap_ms = now
			_last_tap_position = touch.position
			_touch_started_ms = now
			_touch_started_position = touch.position
			_flick_sent = false
			_touch_id = touch.index
			_dragging = true
			_set_touch_target(touch.position)
		elif not touch.pressed and touch.index == _touch_id:
			_touch_id = -1
			_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_id:
			_set_touch_target(drag.position)
			if not _flick_sent and String(SettingsManager.get_value("dash_method","button")) == "flick" and Time.get_ticks_msec() - _touch_started_ms <= 280:
				var flick := drag.position - _touch_started_position
				if flick.length() >= 78.0:
					_flick_sent = true
					dash_gesture_requested.emit(flick.normalized())

func _set_touch_target(screen_position: Vector2) -> void:
	var local_target := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	local_target += FINGER_OFFSET
	local_target.x = clampf(local_target.x, combat_bounds.position.x, combat_bounds.end.x)
	local_target.y = clampf(local_target.y, combat_bounds.position.y, combat_bounds.end.y)
	if local_target.distance_to(position) >= DEAD_ZONE:
		_target = local_target

func _physics_process(delta: float) -> void:
	if not controls_active:
		velocity = Vector2.ZERO
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	_damage_flash = maxf(0.0, _damage_flash - delta)
	if dash_charges < max_dash_charges:
		dash_recharge += delta
		if dash_recharge >= dash_cooldown:
			dash_recharge -= dash_cooldown
			dash_charges += 1
			_dash_announced_empty = false
			dash_ready.emit()
	var follow_delta := delta
	if dash_time > 0.0:
		var dash_delta := minf(delta, dash_time)
		dash_time = maxf(0.0, dash_time - dash_delta)
		position += velocity * dash_delta
		follow_delta -= dash_delta
	if follow_delta > 0.0:
		var offset := _target - position
		if _dragging and offset.length() > DEAD_ZONE:
			var desired := offset.normalized() * minf(max_speed, offset.length() * responsiveness)
			var blend := 1.0 - exp(-responsiveness * follow_delta)
			velocity = velocity.lerp(desired, blend)
			_last_input = velocity.normalized() if velocity.length_squared() > 1.0 else _last_input
		else:
			velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * follow_delta))
		position += velocity * follow_delta
	position.x = clampf(position.x, combat_bounds.position.x, combat_bounds.end.x)
	position.y = clampf(position.y, combat_bounds.position.y, combat_bounds.end.y)
	_target.x = clampf(_target.x, combat_bounds.position.x, combat_bounds.end.x)
	_target.y = clampf(_target.y, combat_bounds.position.y, combat_bounds.end.y)
	_trail.push_front(position)
	if _trail.size() > 13:
		_trail.pop_back()
	queue_redraw()

func request_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if not controls_active:
		return false
	if dash_charges <= 0 or dash_time > 0.0:
		_dash_announced_empty = true
		return false
	var use_direction := direction.normalized() if direction.length_squared() > 0.1 else _last_input
	if use_direction.length_squared() < 0.1:
		use_direction = Vector2.UP
	dash_charges -= 1
	dash_time = dash_duration
	invulnerability = maxf(invulnerability, dash_invulnerability)
	velocity = use_direction * 1260.0
	dash_started.emit()
	queue_redraw()
	return true

func take_damage(amount: float, cause: String) -> bool:
	if invulnerability > 0.0 or health <= 0.0:
		return false
	if shield_hits > 0:
		shield_hits -= 1
		invulnerability = 0.45
		AudioManager.play_sfx("shield_break")
		SettingsManager.pulse_haptic(22, 0.5)
		queue_redraw()
		return false
	health = maxf(0.0, health - amount)
	invulnerability = 0.52
	_damage_flash = 0.24
	damaged.emit(amount, cause)
	if health <= 0.0:
		died.emit(cause)
	queue_redraw()
	return true

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	queue_redraw()

func add_shield_hit(count: int = 1) -> void:
	shield_hits += maxi(0, count)
	queue_redraw()

func health_ratio() -> float:
	return health / maxf(1.0, max_health)

func dash_ratio() -> float:
	if dash_charges > 0:
		return 1.0
	return clampf(dash_recharge / maxf(0.01, dash_cooldown), 0.0, 1.0)

func set_controls_active(active: bool) -> void:
	controls_active = active
	if not active:
		_dragging = false
		_touch_id = -1
		velocity = Vector2.ZERO
		_target = position

func place_at(safe_position: Vector2) -> void:
	position = Vector2(
		clampf(safe_position.x, combat_bounds.position.x, combat_bounds.end.x),
		clampf(safe_position.y, combat_bounds.position.y, combat_bounds.end.y)
	)
	_target = position
	velocity = Vector2.ZERO
	reset_physics_interpolation()

static func damage_flash_color(base_color: Color, intensity: float, active: bool) -> Color:
	return base_color.lerp(Color.WHITE,clampf(intensity,0.0,1.0)) if active else base_color

static func invulnerability_alpha(time_remaining: float, reduced_motion: bool) -> float:
	if time_remaining <= 0.0:
		return 1.0
	if reduced_motion:
		return 0.72
	return 0.4 if int(time_remaining * 24.0) % 2 == 0 else 1.0

func _draw() -> void:
	if not bool(SettingsManager.get_value("reduced_motion",false)):
		for index in range(_trail.size() - 1, -1, -1):
			var point := to_local(_trail[index])
			var alpha := (1.0 - float(index) / maxf(1.0, _trail.size())) * 0.17
			draw_circle(point, 3.0 + (12 - index) * 0.28, Color(VisualTheme.FRIENDLY, alpha))
	var angle := velocity.angle() + PI / 2.0 if velocity.length_squared() > 16.0 else 0.0
	var transform_points := PackedVector2Array([Vector2(0,-18),Vector2(11,13),Vector2(0,8),Vector2(-11,13)])
	for index in transform_points.size():
		transform_points[index] = transform_points[index].rotated(angle)
	var flash_strength := clampf(float(SettingsManager.get_value("damage_flash",0.7)),0.0,1.0)
	var body_color := damage_flash_color(VisualTheme.FRIENDLY,flash_strength,_damage_flash>0.0)
	body_color.a = invulnerability_alpha(invulnerability,bool(SettingsManager.get_value("reduced_motion",false)))
	draw_colored_polygon(transform_points, body_color)
	draw_polyline(PackedVector2Array([transform_points[1], transform_points[0], transform_points[3]]), Color.WHITE, 2.0)
	draw_circle(Vector2.ZERO, 5.0, VisualTheme.DEEP_SPACE)
	draw_arc(Vector2.ZERO, 25.0, -PI * 0.8, PI * 0.8, 28, Color(1,1,1,0.15), 3.0)
	draw_arc(Vector2.ZERO, 25.0, -PI * 0.8, -PI * 0.8 + PI * 1.6 * health_ratio(), 28, VisualTheme.BIO if health_ratio() > 0.35 else VisualTheme.ENEMY, 3.0)
	if shield_hits > 0:
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 32, VisualTheme.SHARD, 2.0)
	if dash_time > 0.0:
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, Color(VisualTheme.FRIENDLY, 0.65), 4.0)
