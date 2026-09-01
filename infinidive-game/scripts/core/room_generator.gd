class_name RoomGenerator
extends RefCounted

var _rng := RandomNumberGenerator.new()

func generate(all_rooms: Array, boss_id: String, organ_id: String, seed: int) -> Array[Dictionary]:
	_rng.seed = seed
	var traversals: Array[Dictionary] = []
	var combats: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var chamber: Dictionary = {}
	for raw_room in all_rooms:
		var room: Dictionary = raw_room
		if String(room.get("boss", "any")) not in ["any", boss_id]:
			continue
		match String(room.get("type", "")):
			"traversal": traversals.append(room)
			"combat": combats.append(room)
			"hazard": hazards.append(room)
			"chamber":
				if String(room.get("organ", "")) == organ_id:
					chamber = room
	var result: Array[Dictionary] = [{"id":"entrance","type":"entrance","duration":1.3,"hazard":"none"}]
	for source in [traversals, combats, hazards]:
		if not source.is_empty():
			result.append(source[_rng.randi_range(0, source.size() - 1)].duplicate(true))
	if not chamber.is_empty():
		result.append(chamber.duplicate(true))
	return result

func validate_layout(layout: Array) -> bool:
	if layout.size() < 2 or String(layout[0].get("type", "")) != "entrance":
		return false
	if String(layout[-1].get("type", "")) != "chamber":
		return false
	for raw_room in layout:
		var room: Dictionary = raw_room
		if float(room.get("duration", 0.0)) < 0.0 or not room.has("safe_rule") and String(room.get("hazard", "none")) != "none":
			return false
	return true
