class_name PlayerController
extends Node2D

signal died(cause: String)
signal damaged(amount: float, cause: String)
signal dash_started
signal dash_ready
signal dash_gesture_requested(direction: Vector2)

const FINGER_OFFSET := Vector2(0.0, -82.0)
const DEAD_ZONE := 8.0
const HERO_TEXTURE_PATH := "res://assets/art/heroes/aion_diver_unarmed.png"
const HERO_TEXTURE: Texture2D=preload("res://assets/art/heroes/aion_diver_unarmed.png")
const HERO_TEXTURE_RECT:=Rect2(-20,-34,40,67)
const HERO_TEXTURE_SPARK_POSITION:=Vector2(8,-2)
const HERO_INK := Color("#203354")
const HERO_SKIN := Color("#F2B88D")
const HERO_TUNIC := Color("#4FBFD0")
const HERO_MANTLE := Color("#FF7F6E")
const AETHER_GOLD := Color("#FFD35A")

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
var aether_awakened := false
var _hero_texture: Texture2D

func _ready() -> void:
	_target = position
	_load_hero_texture()
	set_process_unhandled_input(true)
	queue_redraw()

func _load_hero_texture() -> void:
	# Preload keeps the authored hero in every export. The procedural drawing
	# remains a fail-safe should a platform return an invalid imported texture.
	_hero_texture=HERO_TEXTURE

func set_aether_awakened(value: bool) -> void:
	aether_awakened=value
	queue_redraw()

func presentation_snapshot() -> Dictionary:
	return {
		"aether_awakened":aether_awakened,
		"visible_weapon":false,
		"muzzle_fire":false,
		"hero_asset_loaded":_hero_texture!=null
	}

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
	# The trail is decorative, so Reduced Motion removes its retained samples as
	# well as the draw call. This prevents a stale ribbon appearing after the
	# preference is changed during a run.
	if SettingsManager.reduced_motion_enabled():
		_trail.clear()
	else:
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
	_damage_flash = SettingsManager.DAMAGE_FEEDBACK_DURATION_SECONDS if SettingsManager.damage_flash_intensity() > 0.0 else 0.0
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
	var reduced_motion:=SettingsManager.reduced_motion_enabled()
	if not reduced_motion:
		for index in range(_trail.size() - 1, -1, -1):
			var point := to_local(_trail[index])
			var alpha := (1.0 - float(index) / maxf(1.0, _trail.size())) * 0.17
			draw_circle(point, 3.0 + (12 - index) * 0.28, Color(VisualTheme.FRIENDLY, alpha))
	var flash_strength := SettingsManager.damage_flash_intensity()
	var hero_alpha:=invulnerability_alpha(invulnerability,reduced_motion)
	var lean:=clampf(velocity.x/maxf(1.0,max_speed),-1.0,1.0)*0.12
	if _hero_texture!=null:
		var texture_modulate:=damage_flash_color(Color.WHITE,flash_strength,_damage_flash>0.0)
		texture_modulate.a=hero_alpha
		draw_texture_rect(_hero_texture,HERO_TEXTURE_RECT,false,texture_modulate)
		if not aether_awakened:
			_draw_dormant_aether_cover(hero_alpha,flash_strength)
	else:
		_draw_procedural_hero(hero_alpha,flash_strength,lean)
	if aether_awakened:
		_draw_aether_spark(hero_alpha,reduced_motion,HERO_TEXTURE_SPARK_POSITION if _hero_texture!=null else Vector2(0,3))
	draw_arc(Vector2.ZERO, 25.0, -PI * 0.8, PI * 0.8, 28, Color(1,1,1,0.15), 3.0)
	draw_arc(Vector2.ZERO, 25.0, -PI * 0.8, -PI * 0.8 + PI * 1.6 * health_ratio(), 28, VisualTheme.BIO if health_ratio() > 0.35 else VisualTheme.ENEMY, 3.0)
	if shield_hits > 0:
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 32, VisualTheme.SHARD, 2.0)
	if dash_time > 0.0:
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, Color(VisualTheme.FRIENDLY, 0.65), 4.0)

func _hero_color(base_color: Color, alpha: float, flash_strength: float) -> Color:
	var result:=damage_flash_color(base_color,flash_strength,_damage_flash>0.0)
	result.a=alpha
	return result

func _leaned(points: PackedVector2Array, lean: float) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point in points:
		result.append(point+Vector2(-point.y*lean,0))
	return result

func _draw_hero_piece(points: PackedVector2Array, color: Color, outline: Color, width: float, lean: float) -> void:
	var leaned_points:=_leaned(points,lean)
	draw_colored_polygon(leaned_points,color)
	var closed:=leaned_points.duplicate()
	closed.append(leaned_points[0])
	draw_polyline(closed,outline,width,true)

func _draw_procedural_hero(alpha: float, flash_strength: float, lean: float) -> void:
	var ink:=_hero_color(HERO_INK,alpha,flash_strength)
	var mantle:=_hero_color(HERO_MANTLE,alpha,flash_strength)
	var tunic:=_hero_color(HERO_TUNIC,alpha,flash_strength)
	var skin:=_hero_color(HERO_SKIN,alpha,flash_strength)
	# A tiny readable human silhouette: empty hands, cloth, head and legs. No
	# physical weapon geometry is authored in either presentation state.
	_draw_hero_piece(PackedVector2Array([Vector2(-8,-5),Vector2(-15,16),Vector2(-2,12),Vector2(0,18),Vector2(3,12),Vector2(15,16),Vector2(8,-5)]),mantle,ink,2.3,lean)
	_draw_hero_piece(PackedVector2Array([Vector2(-8,7),Vector2(-1,7),Vector2(-2,20),Vector2(-8,20)]),tunic.darkened(0.12),ink,2.0,lean)
	_draw_hero_piece(PackedVector2Array([Vector2(1,7),Vector2(8,7),Vector2(8,20),Vector2(2,20)]),tunic,ink,2.0,lean)
	_draw_hero_piece(PackedVector2Array([Vector2(-9,-7),Vector2(9,-7),Vector2(8,8),Vector2(0,13),Vector2(-8,8)]),tunic,ink,2.4,lean)
	var left_arm:=_leaned(PackedVector2Array([Vector2(-8,-4),Vector2(-14,1),Vector2(-8,5)]),lean)
	var right_arm:=_leaned(PackedVector2Array([Vector2(8,-4),Vector2(14,1),Vector2(8,5)]),lean)
	draw_polyline(left_arm,ink,5.0,true)
	draw_polyline(right_arm,ink,5.0,true)
	draw_polyline(left_arm,skin,2.8,true)
	draw_polyline(right_arm,skin,2.8,true)
	var left_hand:=Vector2(-8,5)+Vector2(-5*lean,0)
	var right_hand:=Vector2(8,5)+Vector2(-5*lean,0)
	draw_circle(left_hand,3.2,ink)
	draw_circle(right_hand,3.2,ink)
	draw_circle(left_hand,2.0,skin)
	draw_circle(right_hand,2.0,skin)
	var head_center:=Vector2(0,-15)+Vector2(15*lean,0)
	draw_circle(head_center+Vector2(1,2),7.0,ink)
	draw_circle(head_center,6.0,skin)
	var hair:=_leaned(PackedVector2Array([Vector2(-6,-16),Vector2(-4,-22),Vector2(1,-23),Vector2(7,-19),Vector2(5,-14),Vector2(2,-18),Vector2(-2,-16)]),lean)
	draw_colored_polygon(hair,_hero_color(Color("#4A3971"),alpha,flash_strength))
	draw_polyline(PackedVector2Array([head_center+Vector2(-3,-1),head_center+Vector2(-1,-2)]),ink,1.2,true)
	draw_polyline(PackedVector2Array([head_center+Vector2(1,-2),head_center+Vector2(3,-1)]),ink,1.2,true)

func _draw_dormant_aether_cover(alpha: float, flash_strength: float) -> void:
	# The authored portrait includes Aion's future hand spark. Before awakening,
	# a warm gauntlet seal covers it so the opening reads as genuinely unarmed.
	var outline:=_hero_color(HERO_INK,alpha,flash_strength)
	var seal:=_hero_color(Color("#D9A06F"),alpha,flash_strength)
	draw_circle(HERO_TEXTURE_SPARK_POSITION,6.2,outline)
	draw_circle(HERO_TEXTURE_SPARK_POSITION,4.8,seal)
	draw_arc(HERO_TEXTURE_SPARK_POSITION,3.2,-PI*0.75,PI*0.7,14,Color("#F3C492",alpha*0.68),1.2,true)

func _draw_aether_spark(alpha: float, reduced_motion: bool, center: Vector2) -> void:
	var beat:=0.0 if reduced_motion else sin(float(Time.get_ticks_msec())*0.012)*1.2
	for radius in [13.0,9.0]:
		draw_circle(center,radius+beat*0.25,Color(VisualTheme.FRIENDLY,alpha*(0.06 if radius>10.0 else 0.1)))
	var diamond:=PackedVector2Array([center+Vector2(0,-7-beat),center+Vector2(5,0),center+Vector2(0,7+beat),center+Vector2(-5,0)])
	draw_colored_polygon(diamond,Color(AETHER_GOLD,alpha))
	draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),Color(HERO_INK,alpha*0.72),1.7,true)
	draw_circle(center-Vector2(1,2),2.0,Color(1,1,1,alpha))
	for ray in 4:
		var angle:=ray*PI/2.0+PI/4.0
		draw_line(center+Vector2.from_angle(angle)*8.0,center+Vector2.from_angle(angle)*(11.0+beat),Color(VisualTheme.FRIENDLY,alpha*0.72),1.5,true)
