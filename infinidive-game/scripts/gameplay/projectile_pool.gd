class_name ProjectilePool
extends Node2D

const MAX_PLAYER := 190
const MAX_ENEMY := 350

var player_active: Array[Dictionary] = []
var enemy_active: Array[Dictionary] = []
var _player_free: Array[Dictionary] = []
var _enemy_free: Array[Dictionary] = []

func spawn_player(origin: Vector2, velocity: Vector2, damage: float, options: Dictionary = {}) -> bool:
	if player_active.size() >= MAX_PLAYER:
		return false
	var bullet: Dictionary = _player_free.pop_back() if not _player_free.is_empty() else {}
	bullet.clear()
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
		"hit_ids": {}
	})
	player_active.append(bullet)
	return true

func spawn_enemy(origin: Vector2, velocity: Vector2, damage: float, options: Dictionary = {}) -> bool:
	if enemy_active.size() >= MAX_ENEMY:
		return false
	var bullet: Dictionary = _enemy_free.pop_back() if not _enemy_free.is_empty() else {}
	bullet.clear()
	bullet.merge({
		"position": origin,
		"previous": origin,
		"velocity": velocity,
		"damage": damage,
		"radius": float(options.get("radius", 7.0)),
		"life": float(options.get("life", 7.0)),
		"shape": String(options.get("shape", "spike")),
		"homing": float(options.get("homing", 0.0)),
		"cause": String(options.get("cause", "hostile projectile")),
		"group": String(options.get("group", "")),
		"age": 0.0
	})
	enemy_active.append(bullet)
	return true

func step(delta: float, targets: Array, player_position: Vector2, player_radius: float) -> Dictionary:
	var result := {"target_hits": [], "player_hits": [], "phased": 0}
	for index in range(player_active.size() - 1, -1, -1):
		var bullet: Dictionary = player_active[index]
		bullet.previous = bullet.position
		if float(bullet.homing) > 0.0 and not targets.is_empty():
			var nearest := _nearest_target(bullet.position, targets)
			if not nearest.is_empty():
				var desired := (Vector2(nearest.position) - Vector2(bullet.position)).normalized() * Vector2(bullet.velocity).length()
				bullet.velocity = Vector2(bullet.velocity).lerp(desired, clampf(float(bullet.homing) * delta, 0.0, 1.0))
		bullet.position = Vector2(bullet.position) + Vector2(bullet.velocity) * delta
		bullet.life = float(bullet.life) - delta
		var remove := float(bullet.life) <= 0.0 or not Rect2(-80,-100,700,1160).has_point(bullet.position)
		if not remove:
			var collisions: Array[Dictionary] = []
			for raw_target in targets:
				var target: Dictionary = raw_target
				var target_id := String(target.get("id", ""))
				if bullet.hit_ids.has(target_id):
					continue
				var hit_t := _segment_circle_t(bullet.previous, bullet.position, target.position, float(target.radius) + float(bullet.radius))
				if hit_t >= 0.0:
					collisions.append({"t":hit_t,"target":target,"id":target_id})
			collisions.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.t) < float(second.t))
			for collision in collisions:
				var target_id := String(collision.id)
				var hit_position := Vector2(bullet.previous).lerp(Vector2(bullet.position), float(collision.t))
				result.target_hits.append({"id":target_id,"damage":float(bullet.damage),"position":hit_position,"behavior":bullet.behavior})
				bullet.hit_ids[target_id] = true
				if int(bullet.pierce) > 0:
					bullet.pierce = int(bullet.pierce) - 1
					bullet.damage = float(bullet.damage) * 0.9
				else:
					remove = true
					break
		if remove:
			_release_player(index)
	for index in range(enemy_active.size() - 1, -1, -1):
		var bullet: Dictionary = enemy_active[index]
		bullet.previous = bullet.position
		bullet.age = float(bullet.age) + delta
		if float(bullet.homing) > 0.0 and float(bullet.age) < 1.5:
			var desired := (player_position - Vector2(bullet.position)).normalized() * Vector2(bullet.velocity).length()
			bullet.velocity = Vector2(bullet.velocity).lerp(desired, clampf(float(bullet.homing) * delta, 0.0, 1.0))
		bullet.position = Vector2(bullet.position) + Vector2(bullet.velocity) * delta
		bullet.life = float(bullet.life) - delta
		var remove := float(bullet.life) <= 0.0 or not Rect2(-100,-120,740,1200).has_point(bullet.position)
		if not remove and _segment_circle(bullet.previous, bullet.position, player_position, player_radius + float(bullet.radius)):
			result.player_hits.append({
				"damage": float(bullet.damage),
				"cause": String(bullet.cause),
				"position": bullet.position,
				"group": String(bullet.group)
			})
			remove = true
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
		if String(enemy_active[index].get("group", "")) != group_id:
			continue
		_release_enemy(index)
		cleared += 1
	if cleared > 0:
		queue_redraw()
	return cleared

func enemy_group_size(group_id: String) -> int:
	var count := 0
	for bullet in enemy_active:
		if String(bullet.get("group", "")) == group_id:
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

func _release_player(index: int) -> void:
	var bullet: Dictionary = player_active.pop_at(index)
	bullet.clear()
	_player_free.append(bullet)

func _release_enemy(index: int) -> void:
	var bullet: Dictionary = enemy_active.pop_at(index)
	bullet.clear()
	_enemy_free.append(bullet)

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
		var points := PackedVector2Array([pos+Vector2(0,-radius),pos+Vector2(radius,0),pos+Vector2(0,radius),pos+Vector2(-radius,0)])
		draw_colored_polygon(points, color)
		draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]), Color(0.05,0.02,0.04,1), 2.0)
		draw_circle(pos, maxf(1.8, radius * 0.25), Color.WHITE)
