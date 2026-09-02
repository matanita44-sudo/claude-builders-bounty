class_name OrganAbilityMap
extends RefCounted

const TitanAttackSpecFactoryScript := preload("res://scripts/core/titan_attack_spec_factory.gd")

const LOSS_DISABLE := "disable"
const LOSS_TRANSFORM := "transform"
const STATUS_ACTIVE := "active"
const STATUS_DEGRADED := "degraded"
const STATUS_DISABLED := "disabled"
const VALID_PATTERN_FAMILIES := ["aimed_fan", "ring", "lane"]

var boss_id := ""
var organs: Dictionary = {}
var abilities: Dictionary = {}


static func validate_boss_definition(boss: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var boss_label := String(boss.get("id", "?"))
	var visual_tokens: Dictionary = {}
	for raw_organ in boss.get("organs", []):
		if typeof(raw_organ) != TYPE_DICTIONARY:
			errors.append("Boss %s contains a non-dictionary organ" % boss_label)
			continue
		var organ := raw_organ as Dictionary
		var organ_id := String(organ.get("id", "?"))
		var ability_id := String(organ.get("ability", ""))
		if organ.has("intact_pattern"):
			errors.append("Organ %s retains obsolete intact_pattern data" % organ_id)
		errors.append_array(TitanAttackSpecFactoryScript.validate_intact_tuning(
			ability_id,
			organ.get("intact_tuning", null)
		))
		var loss_value: Variant = organ.get("loss", null)
		if typeof(loss_value) != TYPE_DICTIONARY:
			errors.append("Organ %s requires a loss contract" % organ_id)
			continue
		var loss := loss_value as Dictionary
		var mode := String(loss.get("mode", ""))
		if mode not in [LOSS_DISABLE, LOSS_TRANSFORM]:
			errors.append("Organ %s has unsupported loss mode %s" % [organ_id, mode])
		var variant := String(loss.get("variant", ""))
		if variant.is_empty():
			errors.append("Organ %s requires a post-loss variant" % organ_id)
		var visual_token := String(loss.get("visual_token", ""))
		if visual_token.is_empty() or visual_tokens.has(visual_token):
			errors.append("Organ %s requires a unique visual token" % organ_id)
		visual_tokens[visual_token] = true
		var strength_value: Variant = loss.get("strength", null)
		if typeof(strength_value) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("Organ %s requires numeric post-loss strength" % organ_id)
		else:
			var strength := float(strength_value)
			if mode == LOSS_DISABLE and not is_zero_approx(strength):
				errors.append("Disabled organ %s must have zero strength" % organ_id)
			if mode == LOSS_TRANSFORM and (strength <= 0.0 or strength >= 1.0):
				errors.append("Transformed organ %s strength must be between zero and one" % organ_id)
		var telegraph_value: Variant = loss.get("telegraph_multiplier", null)
		if typeof(telegraph_value) not in [TYPE_INT, TYPE_FLOAT] or float(telegraph_value) < 1.0:
			errors.append("Organ %s post-loss telegraph cannot be shorter than its intact warning" % organ_id)
		var pattern_value: Variant = loss.get("pattern", null)
		if mode == LOSS_DISABLE:
			if typeof(pattern_value) == TYPE_DICTIONARY and not (pattern_value as Dictionary).is_empty():
				errors.append("Disabled organ %s cannot retain an attack pattern" % organ_id)
			continue
		if typeof(pattern_value) != TYPE_DICTIONARY:
			errors.append("Transformed organ %s requires an attack pattern" % organ_id)
			continue
		errors.append_array(_validate_pattern(organ_id, pattern_value as Dictionary))
	return errors


static func _validate_pattern(organ_id: String, pattern: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var family := String(pattern.get("family", ""))
	if family not in VALID_PATTERN_FAMILIES:
		errors.append("Organ %s has unsupported transformed pattern family %s" % [organ_id, family])
		return errors
	for numeric_key in ["speed", "damage"]:
		var value: Variant = pattern.get(numeric_key, null)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) <= 0.0:
			errors.append("Organ %s pattern requires positive %s" % [organ_id, numeric_key])
	match family:
		"aimed_fan":
			var count := int(pattern.get("count", 0))
			var spread := float(pattern.get("spread_radians", -1.0))
			if count < 1 or count > 5:
				errors.append("Organ %s aimed fan count must be between one and five" % organ_id)
			if spread < 0.0 or spread > 0.42:
				errors.append("Organ %s aimed fan spread is outside the readable bound" % organ_id)
			if float(pattern.get("homing", 0.0)) != 0.0:
				errors.append("Organ %s transformed aimed fan must not retain hidden homing" % organ_id)
		"ring":
			var count := int(pattern.get("count", 0))
			var safe_arc := float(pattern.get("safe_arc_radians", 0.0))
			if count < 6 or count > 20:
				errors.append("Organ %s transformed ring count must be between six and twenty" % organ_id)
			if safe_arc < 0.65 or safe_arc > 1.4:
				errors.append("Organ %s transformed ring requires a readable bounded safe arc" % organ_id)
		"lane":
			var step := int(pattern.get("step", 0))
			var gap := float(pattern.get("gap_half_width", 0.0))
			var safe_flank := int(pattern.get("safe_flank", 0))
			if step < 32 or step > 64:
				errors.append("Organ %s transformed lane step is outside the projectile budget" % organ_id)
			if gap < 72.0 or gap > 140.0:
				errors.append("Organ %s transformed lane needs a readable safe gap" % organ_id)
			if safe_flank not in [-1, 1]:
				errors.append("Organ %s transformed lane must name one permanent safe flank" % organ_id)
	return errors


func initialize(boss: Dictionary) -> void:
	boss_id = String(boss.get("id", ""))
	organs.clear()
	abilities.clear()
	for raw_organ in boss.get("organs", []):
		var organ: Dictionary = raw_organ
		var organ_id := String(organ.get("id", ""))
		var ability_id := String(organ.get("ability", ""))
		var loss := (organ.get("loss", {}) as Dictionary).duplicate(true)
		organs[organ_id] = {
			"destroyed": false,
			"ability": ability_id,
			"definition": organ.duplicate(true),
			"loss": loss
		}
		abilities[ability_id] = {
			"enabled": true,
			"runtime_enabled": true,
			"source_organ": organ_id,
			"strength": 1.0,
			"status": STATUS_ACTIVE,
			"variant": "intact",
			"visual_token": "",
			"telegraph_multiplier": 1.0,
			"intact_tuning": (organ.get("intact_tuning", {}) as Dictionary).duplicate(true),
			"pattern": {}
		}


func destroy_organ(organ_id: String) -> Dictionary:
	if not organs.has(organ_id):
		return {}
	var organ_state: Dictionary = organs[organ_id]
	if bool(organ_state.destroyed):
		return {}
	organ_state.destroyed = true
	organs[organ_id] = organ_state
	var ability_id := String(organ_state.ability)
	var loss := organ_state.get("loss", {}) as Dictionary
	var loss_mode := String(loss.get("mode", LOSS_DISABLE))
	var ability_state: Dictionary = abilities.get(ability_id, {})
	# `enabled` keeps its original meaning: the intact organ ability is gone.
	# `runtime_enabled` distinguishes a described degraded replacement from a
	# completely sealed system without breaking callers that use the old API.
	ability_state.enabled = false
	ability_state.runtime_enabled = loss_mode == LOSS_TRANSFORM
	ability_state.status = STATUS_DEGRADED if loss_mode == LOSS_TRANSFORM else STATUS_DISABLED
	ability_state.strength = float(loss.get("strength", 0.0)) if loss_mode == LOSS_TRANSFORM else 0.0
	ability_state.variant = String(loss.get("variant", "disabled"))
	ability_state.visual_token = String(loss.get("visual_token", ""))
	ability_state.telegraph_multiplier = float(loss.get("telegraph_multiplier", 1.0))
	ability_state.intact_tuning = {}
	ability_state.pattern = (loss.get("pattern", {}) as Dictionary).duplicate(true)
	abilities[ability_id] = ability_state
	return {
		"organ_id": organ_id,
		"ability_id": ability_id,
		"effect": organ_state.definition.get("effect", ""),
		"loss_mode": loss_mode,
		"status": ability_state.status,
		"variant": ability_state.variant,
		"visual_token": ability_state.visual_token,
		"attack_contract": attack_contract(ability_id)
	}


func is_ability_enabled(ability_id: String) -> bool:
	return bool(abilities.get(ability_id, {}).get("enabled", false))


func is_ability_runtime_enabled(ability_id: String) -> bool:
	return bool(abilities.get(ability_id, {}).get("runtime_enabled", false))


func ability_status(ability_id: String) -> String:
	return String(abilities.get(ability_id, {}).get("status", STATUS_DISABLED))


func attack_contract(ability_id: String) -> Dictionary:
	var ability_state: Dictionary = abilities.get(ability_id, {})
	if ability_state.is_empty() or not bool(ability_state.get("runtime_enabled", false)):
		return {}
	return {
		"ability_id": ability_id,
		"source_organ": String(ability_state.get("source_organ", "")),
		"status": String(ability_state.get("status", STATUS_ACTIVE)),
		"variant": String(ability_state.get("variant", "intact")),
		"strength": float(ability_state.get("strength", 1.0)),
		"telegraph_multiplier": float(ability_state.get("telegraph_multiplier", 1.0)),
		"visual_token": String(ability_state.get("visual_token", "")),
		"intact_tuning": (ability_state.get("intact_tuning", {}) as Dictionary).duplicate(true),
		"pattern": (ability_state.get("pattern", {}) as Dictionary).duplicate(true)
	}


func attack_contracts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability_id_value in abilities:
		var contract := attack_contract(String(ability_id_value))
		if not contract.is_empty():
			result.append(contract)
	return result


func visual_states() -> Dictionary:
	var result: Dictionary = {}
	for organ_id_value in organs:
		var organ_id := String(organ_id_value)
		var organ_state := organs[organ_id] as Dictionary
		if not bool(organ_state.get("destroyed", false)):
			continue
		var loss := organ_state.get("loss", {}) as Dictionary
		result[organ_id] = String(loss.get("visual_token", ""))
	return result


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
