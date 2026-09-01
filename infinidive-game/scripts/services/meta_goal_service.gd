class_name MetaGoalService
extends RefCounted

## Offline, data-driven achievements and rotating contracts.
##
## The caller owns persistence. `initialize()` keeps the supplied profile
## Dictionary by reference and `progress()` only mutates that Dictionary; this
## service never reads or writes a save file and never contacts a network.
## Events which can advance a goal require a stable `event_id`. Only receipts
## for events that actually changed goal/reward state are retained, as SHA-256
## fingerprints. Normal operation never evicts receipts. If an oversized
## legacy ledger is compacted, the resulting full ledger fails closed for
## unknown goal-changing events, so discarded overflow cannot replay rewards.

const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const CONTRACTS_PATH := "res://data/contracts.json"
const CATALOG_SCHEMA := 1
const PROFILE_SCHEMA := 2
const CONTRACT_PROFILE_SCHEMA := 1
const CONTRACT_SLOTS := ["hunt", "build", "skill"]
const METRICS := ["count", "sum", "max", "unique"]
const REWARD_KEYS := ["bio_matter", "core_shards"]
const MAX_EVENT_AMOUNT := 1000000
const MAX_EVENT_RECEIPTS := 4096
const RECEIPT_PREFIX := "r1:"

var validation_errors: Array[String] = []
var achievements: Array = []
var contracts: Array = []
var initialized := false
var active_day_key := ""

var _profile: Dictionary = {}
var _automatic_utc_rollover := true
var _pending_profile_changes := false


func initialize(
	profile: Dictionary,
	utc_date: Dictionary = {},
	achievements_path: String = ACHIEVEMENTS_PATH,
	contracts_path: String = CONTRACTS_PATH
) -> bool:
	_profile = profile
	_automatic_utc_rollover = utc_date.is_empty()
	_pending_profile_changes = false
	validation_errors.clear()
	achievements = _read_catalog(achievements_path, "achievements")
	contracts = _read_catalog(contracts_path, "contracts")
	_validate_catalog(achievements, "achievement", false)
	_validate_catalog(contracts, "contract", true)
	initialized = validation_errors.is_empty()
	if not initialized:
		return false
	if _ensure_profile_shape():
		_pending_profile_changes = true
	activate_contracts_for_date(utc_date)
	return true


func has_network_transport() -> bool:
	return false


func get_validation_errors() -> Array[String]:
	return validation_errors.duplicate()


func has_pending_profile_changes() -> bool:
	return _pending_profile_changes


func mark_profile_persisted() -> void:
	## Call only after the caller's persistence layer reports success.
	_pending_profile_changes = false


func receipt_count() -> int:
	if typeof(_profile.get("meta_goal_state", {})) != TYPE_DICTIONARY:
		return 0
	var state: Dictionary = _profile.get("meta_goal_state", {})
	return (state.get("processed_event_ids", []) as Array).size() if typeof(state.get("processed_event_ids", [])) == TYPE_ARRAY else 0


func receipt_capacity_remaining() -> int:
	return maxi(0, MAX_EVENT_RECEIPTS - receipt_count())


func progress(event_name: String, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": false,
		"duplicate": false,
		"changed": false,
		"needs_persist": _pending_profile_changes,
		"status": "invalid",
		"event": event_name,
		"day_key": active_day_key,
		"updates": [],
		"completions": [],
		"reward": {"bio_matter": 0, "core_shards": 0}
	}
	if not initialized or event_name.strip_edges().is_empty():
		return result
	if _automatic_utc_rollover and day_key_from_utc() != active_day_key:
		activate_contracts_for_date()
		result.day_key = active_day_key
	if _ensure_profile_shape():
		_pending_profile_changes = true
	var event_id := String(payload.get("event_id", "")).strip_edges().left(128)
	var state: Dictionary = _profile.get("meta_goal_state", {})
	var processed: Array = state.get("processed_event_ids", [])
	var receipt := _event_receipt(event_id) if not event_id.is_empty() else ""
	if not receipt.is_empty() and processed.has(receipt):
		result.accepted = true
		result.duplicate = true
		result.status = "duplicate"
		result.needs_persist = _pending_profile_changes
		return result
	var can_change := _event_can_change(event_name, payload)
	if can_change and event_id.is_empty():
		result.status = "missing_event_id"
		result.needs_persist = _pending_profile_changes
		return result
	if can_change and processed.size() >= MAX_EVENT_RECEIPTS:
		# Never evict an old receipt: eviction would let its event advance a
		# future rotating contract. Saturation therefore fails closed.
		result.status = "receipt_capacity"
		result.needs_persist = _pending_profile_changes
		return result

	result.accepted = true
	result.status = "accepted"
	_process_achievement_event(event_name, payload, result)
	_process_contract_event(event_name, payload, result)
	if bool(result.changed):
		state = _profile.get("meta_goal_state", {})
		processed = state.get("processed_event_ids", [])
		if not processed.has(receipt):
			processed.append(receipt)
			state.processed_event_ids = processed
			_profile.meta_goal_state = state
		_pending_profile_changes = true
	result.needs_persist = _pending_profile_changes
	return result


func activate_contracts_for_date(utc_date: Dictionary = {}) -> Array:
	if not initialized:
		return []
	if _ensure_profile_shape():
		_pending_profile_changes = true
	active_day_key = day_key_from_utc(utc_date)
	var selected := select_contract_ids_for_date(utc_date)
	var state: Dictionary = _profile.get("contracts", {})
	var stored_ids: Array = state.get("active_ids", [])
	if String(state.get("day_key", "")) != active_day_key or stored_ids != selected:
		state = {
			"schema_version": CONTRACT_PROFILE_SCHEMA,
			"day_key": active_day_key,
			"active_ids": selected.duplicate(),
			"progress": {},
			"completed": []
		}
		_profile.contracts = state
		_pending_profile_changes = true
	return get_active_contracts()


func refresh_utc_day() -> bool:
	var previous := active_day_key
	activate_contracts_for_date()
	return previous != active_day_key


func select_contract_ids_for_date(utc_date: Dictionary = {}) -> Array:
	if contracts.is_empty():
		return []
	var key := day_key_from_utc(utc_date)
	var selected: Array = []
	for slot_value in CONTRACT_SLOTS:
		var slot := String(slot_value)
		var candidates: Array[String] = []
		for raw_goal in contracts:
			var goal: Dictionary = raw_goal
			if String(goal.get("slot", "")) == slot:
				candidates.append(String(goal.get("id", "")))
		candidates.sort()
		if candidates.is_empty():
			continue
		var index := _stable_index("%s|%s|INFINIDIVE" % [key, slot], candidates.size())
		selected.append(candidates[index])
	return selected


func get_active_contracts() -> Array:
	if not initialized:
		return []
	var state: Dictionary = _profile.get("contracts", {})
	var progress_map: Dictionary = state.get("progress", {})
	var completed: Array = state.get("completed", [])
	var result: Array = []
	for id_value in state.get("active_ids", []):
		var id := String(id_value)
		var goal := _find_goal(contracts, id)
		if goal.is_empty():
			continue
		var status := goal.duplicate(true)
		var goal_state := _normal_goal_state(progress_map.get(id, {}))
		status["progress"] = _display_progress(goal, goal_state)
		status["target"] = int(goal.get("threshold", 1))
		status["completed"] = completed.has(id)
		status["day_key"] = String(state.get("day_key", active_day_key))
		result.append(status)
	return result


func get_achievement_status() -> Array:
	if not initialized:
		return []
	var state: Dictionary = _profile.get("meta_goal_state", {})
	var progress_map: Dictionary = state.get("achievement_progress", {})
	var completed: Array = _profile.get("achievements", [])
	var result: Array = []
	for raw_goal in achievements:
		var goal: Dictionary = raw_goal
		var id := String(goal.get("id", ""))
		var status := goal.duplicate(true)
		var goal_state := _normal_goal_state(progress_map.get(id, {}))
		status["progress"] = _display_progress(goal, goal_state)
		status["target"] = int(goal.get("threshold", 1))
		status["completed"] = completed.has(id)
		result.append(status)
	return result


static func day_key_from_utc(utc_date: Dictionary = {}) -> String:
	var date := utc_date if not utc_date.is_empty() else Time.get_date_dict_from_system(true)
	var year := clampi(int(date.get("year", 1970)), 1970, 9999)
	var month := clampi(int(date.get("month", 1)), 1, 12)
	var day := clampi(int(date.get("day", 1)), 1, _days_in_month(year, month))
	return "%04d-%02d-%02d" % [year, month, day]


func _process_achievement_event(event_name: String, payload: Dictionary, result: Dictionary) -> void:
	var completed: Array = _profile.get("achievements", [])
	var state: Dictionary = _profile.get("meta_goal_state", {})
	var progress_map: Dictionary = state.get("achievement_progress", {})
	for raw_goal in achievements:
		var goal: Dictionary = raw_goal
		var id := String(goal.get("id", ""))
		if completed.has(id) or not _goal_accepts_event(goal, event_name, payload):
			continue
		var goal_state := _normal_goal_state(progress_map.get(id, {}))
		var before := _display_progress(goal, goal_state)
		goal_state = _advance_goal(goal, goal_state, payload)
		var after := _display_progress(goal, goal_state)
		if after == before:
			continue
		progress_map[id] = goal_state
		var is_complete := after >= int(goal.get("threshold", 1))
		result.updates.append(_update_record("achievement", id, after, int(goal.threshold), is_complete))
		result.changed = true
		if is_complete:
			completed.append(id)
			_award_once("achievement:%s" % id, goal, "achievement", result)
	state.achievement_progress = progress_map
	_profile.meta_goal_state = state
	_profile.achievements = completed


func _process_contract_event(event_name: String, payload: Dictionary, result: Dictionary) -> void:
	var state: Dictionary = _profile.get("contracts", {})
	if String(state.get("day_key", "")) != active_day_key:
		return
	var progress_map: Dictionary = state.get("progress", {})
	var completed: Array = state.get("completed", [])
	for id_value in state.get("active_ids", []):
		var id := String(id_value)
		if completed.has(id):
			continue
		var goal := _find_goal(contracts, id)
		if goal.is_empty() or not _goal_accepts_event(goal, event_name, payload):
			continue
		var goal_state := _normal_goal_state(progress_map.get(id, {}))
		var before := _display_progress(goal, goal_state)
		goal_state = _advance_goal(goal, goal_state, payload)
		var after := _display_progress(goal, goal_state)
		if after == before:
			continue
		progress_map[id] = goal_state
		var is_complete := after >= int(goal.get("threshold", 1))
		result.updates.append(_update_record("contract", id, after, int(goal.threshold), is_complete))
		result.changed = true
		if is_complete:
			completed.append(id)
			_award_once("contract:%s:%s" % [active_day_key, id], goal, "contract", result)
	state.progress = progress_map
	state.completed = completed
	_profile.contracts = state


func _award_once(ledger_key: String, goal: Dictionary, kind: String, result: Dictionary) -> void:
	var state: Dictionary = _profile.get("meta_goal_state", {})
	var ledger: Array = state.get("reward_ledger", [])
	if ledger.has(ledger_key):
		return
	ledger.append(ledger_key)
	state.reward_ledger = ledger
	_profile.meta_goal_state = state
	var reward: Dictionary = goal.get("reward", {})
	var bio := maxi(0, int(reward.get("bio_matter", 0)))
	var shards := maxi(0, int(reward.get("core_shards", 0)))
	_profile.bio_matter = maxi(0, int(_profile.get("bio_matter", 0))) + bio
	_profile.core_shards = maxi(0, int(_profile.get("core_shards", 0))) + shards
	result.reward.bio_matter = int(result.reward.bio_matter) + bio
	result.reward.core_shards = int(result.reward.core_shards) + shards
	result.completions.append({
		"kind": kind,
		"id": String(goal.get("id", "")),
		"reward": {"bio_matter": bio, "core_shards": shards}
	})


func _goal_accepts_event(goal: Dictionary, event_name: String, payload: Dictionary) -> bool:
	if String(goal.get("event", "")) != event_name:
		return false
	var match: Dictionary = goal.get("match", {})
	for key_value in match:
		var key := String(key_value)
		if not payload.has(key) or not _matches(payload[key], match[key]):
			return false
	return true


func _event_can_change(event_name: String, payload: Dictionary) -> bool:
	var completed_achievements: Array = _profile.get("achievements", [])
	for raw_goal in achievements:
		var goal: Dictionary = raw_goal
		if not completed_achievements.has(String(goal.get("id", ""))) and _goal_accepts_event(goal, event_name, payload):
			return true
	var contract_state: Dictionary = _profile.get("contracts", {})
	if String(contract_state.get("day_key", "")) != active_day_key:
		return false
	var completed_contracts: Array = contract_state.get("completed", [])
	for id_value in contract_state.get("active_ids", []):
		var id := String(id_value)
		if completed_contracts.has(id):
			continue
		var goal := _find_goal(contracts, id)
		if not goal.is_empty() and _goal_accepts_event(goal, event_name, payload):
			return true
	return false


func _matches(actual: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_ARRAY:
		return (expected as Array).has(actual)
	if typeof(expected) != TYPE_DICTIONARY:
		return actual == expected
	var rule: Dictionary = expected
	if rule.has("eq") and actual != rule.eq:
		return false
	if rule.has("neq") and actual == rule.neq:
		return false
	if rule.has("in"):
		if typeof(rule.get("in")) != TYPE_ARRAY or not (rule.get("in") as Array).has(actual):
			return false
	if rule.has("gte") and float(actual) < float(rule.gte):
		return false
	if rule.has("lte") and float(actual) > float(rule.lte):
		return false
	if rule.has("contains"):
		if typeof(actual) != TYPE_ARRAY or not (actual as Array).has(rule.contains):
			return false
	return true


func _advance_goal(goal: Dictionary, goal_state: Dictionary, payload: Dictionary) -> Dictionary:
	var metric := String(goal.get("metric", "count"))
	var value_key := String(goal.get("value_key", ""))
	match metric:
		"sum":
			var addition := clampf(float(payload.get(value_key, 0.0)), 0.0, float(MAX_EVENT_AMOUNT))
			goal_state.value = float(goal_state.get("value", 0.0)) + addition
		"max":
			var candidate := clampf(float(payload.get(value_key, 0.0)), 0.0, float(MAX_EVENT_AMOUNT))
			goal_state.value = maxf(float(goal_state.get("value", 0.0)), candidate)
		"unique":
			var unique_values: Array = goal_state.get("unique_values", [])
			var incoming: Variant = payload.get(value_key, null)
			var values: Array = incoming if typeof(incoming) == TYPE_ARRAY else [incoming]
			for value in values:
				if value != null and not String(value).is_empty() and not unique_values.has(value):
					unique_values.append(value)
			goal_state.unique_values = unique_values
			goal_state.value = unique_values.size()
		_:
			var amount_key := String(goal.get("amount_key", ""))
			var amount := 1
			if not amount_key.is_empty():
				amount = clampi(int(payload.get(amount_key, 0)), 0, MAX_EVENT_AMOUNT)
			goal_state.value = float(goal_state.get("value", 0.0)) + amount
	return goal_state


func _display_progress(goal: Dictionary, goal_state: Dictionary) -> int:
	var value := int(floor(float(goal_state.get("value", 0.0))))
	return clampi(value, 0, int(goal.get("threshold", 1)))


func _ensure_profile_shape() -> bool:
	var changed := false
	var normalized_bio := maxi(0, int(_profile.get("bio_matter", 0)))
	if not _profile.has("bio_matter") or _profile.get("bio_matter") != normalized_bio:
		_profile.bio_matter = normalized_bio
		changed = true
	var normalized_shards := maxi(0, int(_profile.get("core_shards", 0)))
	if not _profile.has("core_shards") or _profile.get("core_shards") != normalized_shards:
		_profile.core_shards = normalized_shards
		changed = true
	if typeof(_profile.get("achievements", [])) != TYPE_ARRAY:
		_profile.achievements = []
		changed = true
	else:
		var normalized_achievements := _unique_strings(_profile.get("achievements", []))
		if not _profile.has("achievements") or normalized_achievements != _profile.get("achievements", []):
			_profile.achievements = normalized_achievements
			changed = true

	var original_meta: Variant = _profile.get("meta_goal_state", null)
	var meta: Dictionary = {}
	if typeof(original_meta) == TYPE_DICTIONARY:
		meta = (_profile.get("meta_goal_state", {}) as Dictionary).duplicate(true)
	meta.schema_version = PROFILE_SCHEMA
	if typeof(meta.get("achievement_progress", {})) != TYPE_DICTIONARY:
		meta.achievement_progress = {}
	if typeof(meta.get("reward_ledger", [])) != TYPE_ARRAY:
		meta.reward_ledger = []
	else:
		meta.reward_ledger = _unique_strings(meta.get("reward_ledger", []))
	if typeof(meta.get("processed_event_ids", [])) != TYPE_ARRAY:
		meta.processed_event_ids = []
	else:
		meta.processed_event_ids = _normalized_event_receipts(meta.get("processed_event_ids", []))
	if typeof(original_meta) != TYPE_DICTIONARY or meta != original_meta:
		_profile.meta_goal_state = meta
		changed = true

	var original_contracts: Variant = _profile.get("contracts", null)
	var contract_state: Dictionary = {}
	if typeof(original_contracts) == TYPE_DICTIONARY:
		contract_state = (original_contracts as Dictionary).duplicate(true)
	contract_state.schema_version = CONTRACT_PROFILE_SCHEMA
	if typeof(contract_state.get("day_key", "")) != TYPE_STRING:
		contract_state.day_key = ""
	if typeof(contract_state.get("active_ids", [])) != TYPE_ARRAY:
		contract_state.active_ids = []
	if typeof(contract_state.get("progress", {})) != TYPE_DICTIONARY:
		contract_state.progress = {}
	if typeof(contract_state.get("completed", [])) != TYPE_ARRAY:
		contract_state.completed = []
	else:
		contract_state.completed = _unique_strings(contract_state.get("completed", []))
	if typeof(original_contracts) != TYPE_DICTIONARY or contract_state != original_contracts:
		_profile.contracts = contract_state
		changed = true
	return changed


func _event_receipt(event_id: String) -> String:
	if event_id.is_empty():
		return ""
	return RECEIPT_PREFIX + event_id.sha256_text()


func _normalized_event_receipts(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if result.size() >= MAX_EVENT_RECEIPTS:
			# Once saturated, unknown receipts fail closed in progress(). Keeping
			# more entries would only inflate every save without improving safety.
			break
		var text := String(value).strip_edges().left(160)
		if text.is_empty():
			continue
		var receipt := text if _is_event_receipt(text) else _event_receipt(text.left(128))
		if not result.has(receipt):
			result.append(receipt)
	return result


func _is_event_receipt(value: String) -> bool:
	if not value.begins_with(RECEIPT_PREFIX) or value.length() != RECEIPT_PREFIX.length() + 64:
		return false
	var digest := value.substr(RECEIPT_PREFIX.length())
	for character in digest:
		if not character in "0123456789abcdef":
			return false
	return true


func _normal_goal_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"value": 0.0, "unique_values": []}
	var state: Dictionary = (value as Dictionary).duplicate(true)
	state.value = maxf(0.0, float(state.get("value", 0.0)))
	if typeof(state.get("unique_values", [])) != TYPE_ARRAY:
		state.unique_values = []
	return state


func _read_catalog(path: String, root_key: String) -> Array:
	if not FileAccess.file_exists(path):
		validation_errors.append("Missing %s catalog: %s" % [root_key, path])
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		validation_errors.append("Unreadable %s catalog: %s" % [root_key, path])
		return []
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		validation_errors.append("Invalid JSON in %s catalog" % root_key)
		return []
	if typeof(parser.data) != TYPE_DICTIONARY:
		validation_errors.append("%s catalog root must be a Dictionary" % root_key)
		return []
	var decoded: Dictionary = parser.data
	if int(decoded.get("schema_version", 0)) != CATALOG_SCHEMA:
		validation_errors.append("Unsupported %s catalog schema" % root_key)
		return []
	if typeof(decoded.get(root_key, [])) != TYPE_ARRAY:
		validation_errors.append("%s catalog must contain an Array" % root_key)
		return []
	return (decoded.get(root_key, []) as Array).duplicate(true)


func _validate_catalog(values: Array, label: String, requires_slot: bool) -> void:
	if values.is_empty():
		validation_errors.append("%s catalog cannot be empty" % label.capitalize())
		return
	var seen: Dictionary = {}
	var slot_counts := {"hunt": 0, "build": 0, "skill": 0}
	for index in values.size():
		var raw_value: Variant = values[index]
		if typeof(raw_value) != TYPE_DICTIONARY:
			validation_errors.append("Invalid %s entry at index %d" % [label, index])
			continue
		var goal: Dictionary = raw_value
		var id := String(goal.get("id", ""))
		if not _is_safe_id(id) or seen.has(id):
			validation_errors.append("Duplicate or invalid %s id: %s" % [label, id])
		seen[id] = true
		if String(goal.get("event", "")).strip_edges().is_empty():
			validation_errors.append("%s %s has no event" % [label.capitalize(), id])
		var metric := String(goal.get("metric", ""))
		if not METRICS.has(metric):
			validation_errors.append("%s %s has invalid metric" % [label.capitalize(), id])
		if metric in ["sum", "max", "unique"] and String(goal.get("value_key", "")).is_empty():
			validation_errors.append("%s %s metric requires value_key" % [label.capitalize(), id])
		if int(goal.get("threshold", 0)) <= 0:
			validation_errors.append("%s %s has invalid threshold" % [label.capitalize(), id])
		if typeof(goal.get("match", {})) != TYPE_DICTIONARY:
			validation_errors.append("%s %s has invalid match rules" % [label.capitalize(), id])
		else:
			_validate_match_rules(goal.get("match", {}), label, id)
		_validate_localized_text(goal, label, id)
		_validate_reward(goal.get("reward", {}), label, id)
		if requires_slot:
			var slot := String(goal.get("slot", ""))
			if not CONTRACT_SLOTS.has(slot):
				validation_errors.append("Contract %s has invalid slot" % id)
			else:
				slot_counts[slot] = int(slot_counts[slot]) + 1
	if requires_slot:
		for slot in CONTRACT_SLOTS:
			if int(slot_counts.get(slot, 0)) == 0:
				validation_errors.append("Contract catalog has no %s entries" % slot)


func _validate_localized_text(goal: Dictionary, label: String, id: String) -> void:
	for field in ["title", "description"]:
		var localized: Variant = goal.get(field, {})
		if typeof(localized) != TYPE_DICTIONARY:
			validation_errors.append("%s %s has invalid %s" % [label.capitalize(), id, field])
			continue
		for locale in ["en", "he"]:
			if String((localized as Dictionary).get(locale, "")).strip_edges().is_empty():
				validation_errors.append("%s %s is missing %s %s" % [label.capitalize(), id, locale, field])


func _validate_reward(value: Variant, label: String, id: String) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		validation_errors.append("%s %s has invalid reward" % [label.capitalize(), id])
		return
	var reward: Dictionary = value
	var has_positive := false
	for key in reward:
		if not REWARD_KEYS.has(String(key)):
			validation_errors.append("%s %s has unsupported reward key" % [label.capitalize(), id])
	for key in REWARD_KEYS:
		var amount := int(reward.get(key, 0))
		if amount < 0 or amount > 10000:
			validation_errors.append("%s %s has invalid %s reward" % [label.capitalize(), id, key])
		if amount > 0:
			has_positive = true
	if not has_positive:
		validation_errors.append("%s %s reward must be meaningful" % [label.capitalize(), id])


func _validate_match_rules(match_rules: Dictionary, label: String, id: String) -> void:
	for key_value in match_rules:
		var key := String(key_value)
		if key.strip_edges().is_empty() or key.length() > 64:
			validation_errors.append("%s %s has invalid match key" % [label.capitalize(), id])
		var rule: Variant = match_rules[key_value]
		if typeof(rule) == TYPE_ARRAY:
			if (rule as Array).is_empty():
				validation_errors.append("%s %s has an empty match list" % [label.capitalize(), id])
			continue
		if typeof(rule) != TYPE_DICTIONARY:
			continue
		var operators: Dictionary = rule
		if operators.is_empty():
			validation_errors.append("%s %s has an empty match operator" % [label.capitalize(), id])
		for operator_value in operators:
			var operator := String(operator_value)
			if not operator in ["eq", "neq", "in", "gte", "lte", "contains"]:
				validation_errors.append("%s %s has unsupported match operator: %s" % [label.capitalize(), id, operator])
		if operators.has("in") and (typeof(operators.get("in")) != TYPE_ARRAY or (operators.get("in") as Array).is_empty()):
			validation_errors.append("%s %s has invalid in-match values" % [label.capitalize(), id])
		if operators.has("gte") and typeof(operators.get("gte")) not in [TYPE_INT, TYPE_FLOAT]:
			validation_errors.append("%s %s has non-numeric gte match" % [label.capitalize(), id])
		if operators.has("lte") and typeof(operators.get("lte")) not in [TYPE_INT, TYPE_FLOAT]:
			validation_errors.append("%s %s has non-numeric lte match" % [label.capitalize(), id])


func _find_goal(values: Array, id: String) -> Dictionary:
	for raw_goal in values:
		var goal: Dictionary = raw_goal
		if String(goal.get("id", "")) == id:
			return goal
	return {}


func _update_record(kind: String, id: String, value: int, target: int, completed: bool) -> Dictionary:
	return {"kind": kind, "id": id, "progress": value, "target": target, "completed": completed}


func _stable_index(value: String, count: int) -> int:
	var hash_value: int = 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = ((hash_value ^ int(byte)) * 16777619) % 2147483647
	return hash_value % maxi(1, count)


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var text := String(value).strip_edges().left(160)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


func _is_safe_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


static func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
		return 29 if leap else 28
	if month in [4, 6, 9, 11]:
		return 30
	return 31
