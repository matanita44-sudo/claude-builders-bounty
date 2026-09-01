class_name RoomSpace
extends RefCounted

## Shared pure coordinate transform for authored internal-room geometry.

const ID := "room_normalized"
const MIN_COORDINATE := 0.04
const MAX_COORDINATE := 0.96


static func normalized_to_world(point: Array, room_rect: Rect2) -> Vector2:
	if point.size() != 2 or room_rect.size.x <= 0.0 or room_rect.size.y <= 0.0:
		return room_rect.position + room_rect.size * 0.5
	return room_rect.position + Vector2(float(point[0]) * room_rect.size.x, float(point[1]) * room_rect.size.y)


static func world_to_normalized(point: Vector2, room_rect: Rect2) -> Array[float]:
	if room_rect.size.x <= 0.0 or room_rect.size.y <= 0.0:
		return [0.5, 0.5]
	var relative := point - room_rect.position
	return [relative.x / room_rect.size.x, relative.y / room_rect.size.y]


static func clamp_normalized(point: Array) -> Array[float]:
	if point.size() != 2:
		return [0.5, 0.5]
	return [
		clampf(float(point[0]), MIN_COORDINATE, MAX_COORDINATE),
		clampf(float(point[1]), MIN_COORDINATE, MAX_COORDINATE),
	]


static func inside_normalized(point: Array) -> bool:
	return point.size() == 2 \
		and float(point[0]) >= MIN_COORDINATE \
		and float(point[0]) <= MAX_COORDINATE \
		and float(point[1]) >= MIN_COORDINATE \
		and float(point[1]) <= MAX_COORDINATE


static func normalized_clearance_to_world(clearance: float, room_rect: Rect2) -> float:
	return maxf(0.0, clearance) * minf(room_rect.size.x, room_rect.size.y)
