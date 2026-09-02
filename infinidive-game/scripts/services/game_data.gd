extends Node

const OrganAbilityMapScript := preload("res://scripts/core/organ_ability_map.gd")
const BossPatternPlannerScript := preload("res://scripts/core/boss_pattern_planner.gd")
const TitanCollapseCatalogScript := preload("res://scripts/gameplay/titan_collapse_catalog.gd")

const DATA_FILES := {
	"bosses": "res://data/bosses.json",
	"weapons": "res://data/weapons.json",
	"mutations": "res://data/mutations.json",
	"upgrades": "res://data/upgrades.json",
	"rooms": "res://data/rooms.json",
	"titan_collapses": "res://data/titan_collapses.json"
}

var bosses: Array = []
var weapons: Array = []
var mutations: Array = []
var upgrades: Array = []
var rooms: Array = []
var titan_collapses: Array = []
var validation_errors: Array[String] = []

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	validation_errors.clear()
	bosses = _read_array(DATA_FILES.bosses)
	weapons = _read_array(DATA_FILES.weapons)
	mutations = _read_array(DATA_FILES.mutations)
	upgrades = _read_array(DATA_FILES.upgrades)
	rooms = _read_array(DATA_FILES.rooms) if FileAccess.file_exists(DATA_FILES.rooms) else []
	titan_collapses = _read_array(DATA_FILES.titan_collapses)
	_validate()
	if not validation_errors.is_empty():
		for problem in validation_errors:
			push_error("GameData: " + problem)

func _read_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		validation_errors.append("Cannot open %s" % path)
		return []
	var value: Variant = JSON.parse_string(file.get_as_text())
	if typeof(value) != TYPE_ARRAY:
		validation_errors.append("Expected an array in %s" % path)
		return []
	return value as Array

func _validate() -> void:
	_validate_unique_ids(bosses, "boss")
	_validate_unique_ids(weapons, "weapon")
	_validate_unique_ids(mutations, "mutation")
	_validate_unique_ids(upgrades, "upgrade")
	validation_errors.append_array(TitanCollapseCatalogScript.validate_catalog(titan_collapses))
	if bosses.size() < 4:
		validation_errors.append("Release data requires four bosses")
	if weapons.size() < 5:
		validation_errors.append("Release data requires five weapons")
	if mutations.size() < 24:
		validation_errors.append("Release data requires 24 mutations")
	if upgrades.size() < 18:
		validation_errors.append("Release data requires 18 permanent upgrades")
	var module_count := 0
	var chamber_count := 0
	for raw_room in rooms:
		var room: Dictionary = raw_room
		if String(room.get("type", "")) == "chamber":
			chamber_count += 1
		else:
			module_count += 1
		if String(room.get("hazard", "none")) != "none" and String(room.get("safe_rule", "")).is_empty():
			validation_errors.append("Room %s has no safe path rule" % room.get("id", "?"))
	if module_count < 30:
		validation_errors.append("Release data requires 30 authored room modules")
	if chamber_count < 12:
		validation_errors.append("Release data requires 12 organ chambers")
	for boss_value in bosses:
		var boss: Dictionary = boss_value
		var organs: Array = boss.get("organs", [])
		if organs.size() != 3:
			validation_errors.append("Boss %s must have exactly three organs" % boss.get("id", "?"))
		var ability_ids: Dictionary = {}
		for organ_value in organs:
			var organ: Dictionary = organ_value
			var ability_id := String(organ.get("ability", ""))
			if ability_id.is_empty() or ability_ids.has(ability_id):
				validation_errors.append("Boss %s has an invalid organ ability map" % boss.get("id", "?"))
			ability_ids[ability_id] = true
		validation_errors.append_array(OrganAbilityMapScript.validate_boss_definition(boss))
		validation_errors.append_array(BossPatternPlannerScript.validate_boss_definition(boss))

func _validate_unique_ids(values: Array, label: String) -> void:
	var seen: Dictionary = {}
	for raw_value in values:
		if typeof(raw_value) != TYPE_DICTIONARY:
			validation_errors.append("Invalid %s entry" % label)
			continue
		var value: Dictionary = raw_value
		var id := String(value.get("id", ""))
		if id.is_empty() or seen.has(id):
			validation_errors.append("Duplicate or missing %s id: %s" % [label, id])
		seen[id] = true

func find_by_id(values: Array, id: String) -> Dictionary:
	for raw_value in values:
		var value: Dictionary = raw_value
		if String(value.get("id", "")) == id:
			return value.duplicate(true)
	return {}

func get_boss(id: String) -> Dictionary:
	return find_by_id(bosses, id)

func get_weapon(id: String) -> Dictionary:
	return find_by_id(weapons, id)

func get_mutation(id: String) -> Dictionary:
	return find_by_id(mutations, id)

func get_upgrade(id: String) -> Dictionary:
	return find_by_id(upgrades, id)
