class_name OrganAbilityMap
extends RefCounted

var boss_id := ""
var organs: Dictionary = {}
var abilities: Dictionary = {}

func initialize(boss: Dictionary) -> void:
	boss_id = String(boss.get("id", ""))
	organs.clear()
	abilities.clear()
	for raw_organ in boss.get("organs", []):
		var organ: Dictionary = raw_organ
		var organ_id := String(organ.get("id", ""))
		var ability_id := String(organ.get("ability", ""))
		organs[organ_id] = {"destroyed": false, "ability": ability_id, "definition": organ.duplicate(true)}
		abilities[ability_id] = {"enabled": true, "source_organ": organ_id, "strength": 1.0}

func destroy_organ(organ_id: String) -> Dictionary:
	if not organs.has(organ_id):
		return {}
	var organ_state: Dictionary = organs[organ_id]
	if bool(organ_state.destroyed):
		return {}
	organ_state.destroyed = true
	organs[organ_id] = organ_state
	var ability_id := String(organ_state.ability)
	var ability_state: Dictionary = abilities.get(ability_id, {})
	ability_state.enabled = false
	ability_state.strength = 0.0
	abilities[ability_id] = ability_state
	return {"organ_id": organ_id, "ability_id": ability_id, "effect": organ_state.definition.get("effect", "")}

func is_ability_enabled(ability_id: String) -> bool:
	return bool(abilities.get(ability_id, {}).get("enabled", false))

func alive_organs() -> Array[String]:
	var result: Array[String] = []
	for organ_id in organs:
		if not bool(organs[organ_id].destroyed):
			result.append(String(organ_id))
	return result

func destroyed_organs() -> Array[String]:
	var result: Array[String] = []
	for organ_id in organs:
		if bool(organs[organ_id].destroyed):
			result.append(String(organ_id))
	return result
