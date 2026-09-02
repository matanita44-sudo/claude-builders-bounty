class_name TutorialFlow
extends RefCounted

## Contextual, event-driven tutorial progression. Persistent understanding and
## replay presentation are deliberately separate: replaying or resetting the
## prompts can never clear steps the player has already demonstrated.

signal prompt_changed(prompt: Dictionary)
signal step_understood(step_id: StringName, observed_event: StringName)
signal flow_completed
signal replay_completed

const SAVE_VERSION := 1
const PRESENTATION_VERSION := 1
const STEP_COUNT := 10
const FULL_MASK := (1 << STEP_COUNT) - 1

const EVENT_MOVEMENT_STARTED := &"movement_started"
const EVENT_FIRST_SHOT := &"first_shot"
const EVENT_FIRST_DASH := &"first_dash"
const EVENT_TELEGRAPH_AVOIDED := &"telegraphed_attack_avoided"
const EVENT_ARMOR_BREACHED := &"armor_breached"
const EVENT_FIRST_DIVE := &"first_dive"
const EVENT_ORGAN_DESTROYED := &"organ_destroyed"
const EVENT_MUTATION_SELECTED := &"mutation_selected"
const EVENT_BOSS_ABILITY_CHANGED := &"boss_ability_changed"
const EVENT_BOSS_PHASE_REACHED := &"boss_phase_reached"
const EVENT_PLAYER_DEATH := &"player_death"
const EVENT_FORGE_PURCHASE := &"forge_purchase"

const STEP_DEFINITIONS: Array[Dictionary] = [
	{
		"id": &"move",
		"message_key": &"tutorial.drag_to_move",
		"events": [EVENT_MOVEMENT_STARTED]
	},
	{
		"id": &"auto_fire",
		"message_key": &"tutorial.auto_fire",
		"events": [EVENT_FIRST_SHOT]
	},
	{
		"id": &"defend",
		"message_key": &"tutorial.avoid_or_dash",
		"events": [EVENT_FIRST_DASH, EVENT_TELEGRAPH_AVOIDED]
	},
	{
		"id": &"break_armor",
		"message_key": &"tutorial.hit_exposed_armor",
		"events": [EVENT_ARMOR_BREACHED]
	},
	{
		"id": &"enter_breach",
		"message_key": &"tutorial.enter_breach",
		"events": [EVENT_FIRST_DIVE]
	},
	{
		"id": &"destroy_organ",
		"message_key": &"tutorial.destroy_organ",
		"events": [EVENT_ORGAN_DESTROYED]
	},
	{
		"id": &"choose_mutation",
		"message_key": &"tutorial.choose_mutation",
		"events": [EVENT_MUTATION_SELECTED]
	},
	{
		"id": &"observe_change",
		"message_key": &"tutorial.observe_boss_change",
		"events": [EVENT_BOSS_ABILITY_CHANGED]
	},
	{
		"id": &"finish_or_fail",
		"message_key": &"tutorial.finish_phase_or_die",
		"events": [EVENT_BOSS_PHASE_REACHED, EVENT_PLAYER_DEATH]
	},
	{
		"id": &"spend_resource",
		"message_key": &"tutorial.spend_first_resource",
		"events": [EVENT_FORGE_PURCHASE]
	}
]

const EVENT_TO_STEP := {
	EVENT_MOVEMENT_STARTED: 0,
	EVENT_FIRST_SHOT: 1,
	EVENT_FIRST_DASH: 2,
	EVENT_TELEGRAPH_AVOIDED: 2,
	EVENT_ARMOR_BREACHED: 3,
	EVENT_FIRST_DIVE: 4,
	EVENT_ORGAN_DESTROYED: 5,
	EVENT_MUTATION_SELECTED: 6,
	EVENT_BOSS_ABILITY_CHANGED: 7,
	EVENT_BOSS_PHASE_REACHED: 8,
	EVENT_PLAYER_DEATH: 8,
	EVENT_FORGE_PURCHASE: 9
}

var _understood_mask := 0
var _replay_mask := 0
var _replay_active := false

## Records a gameplay event. Events may arrive out of order; the corresponding
## step is remembered and automatically skipped when earlier prompts catch up.
## Repeated observations in the same normal/replay pass are idempotent.
func observe_event(observed_event: StringName) -> bool:
	if not EVENT_TO_STEP.has(observed_event):
		return false
	var step_index := int(EVENT_TO_STEP[observed_event])
	var bit := 1 << step_index
	var active_mask := _replay_mask if _replay_active else _understood_mask
	if (active_mask & bit) != 0:
		return false
	var previous_prompt_id := current_step_id()
	var was_complete := is_complete()
	_understood_mask |= bit
	if _replay_active:
		_replay_mask |= bit
	step_understood.emit(StringName(STEP_DEFINITIONS[step_index].id), observed_event)
	if not was_complete and is_complete():
		flow_completed.emit()
	if _replay_active and _replay_mask == FULL_MASK:
		_replay_active = false
		_replay_mask = 0
		replay_completed.emit()
	_emit_prompt_if_changed(previous_prompt_id)
	return true

## Re-presents all ten prompts, even if they were understood previously. New
## observations still improve persistent progress if replay starts mid-tutorial.
func begin_replay() -> void:
	_replay_active = true
	_replay_mask = 0
	prompt_changed.emit(current_prompt())

## Leaves replay and returns to the first not-yet-understood normal step.
## Persistent progress is intentionally untouched.
func reset_presentation() -> void:
	_replay_active = false
	_replay_mask = 0
	prompt_changed.emit(current_prompt())

func is_replaying() -> bool:
	return _replay_active

func is_complete() -> bool:
	return _understood_mask == FULL_MASK

func understood_count() -> int:
	return _bit_count(_understood_mask)

func pending_count() -> int:
	return STEP_COUNT - understood_count()

func has_understood(step_id: StringName) -> bool:
	var index := step_index_for_id(step_id)
	return index >= 0 and (_understood_mask & (1 << index)) != 0

func current_step_id() -> StringName:
	var index := _next_pending_index()
	return &"" if index < 0 else StringName(STEP_DEFINITIONS[index].id)

func current_message_key() -> StringName:
	var index := _next_pending_index()
	return &"" if index < 0 else StringName(STEP_DEFINITIONS[index].message_key)

## Returns a detached dictionary so UI callers cannot mutate the contract.
## An empty dictionary means the active normal/replay pass has no prompt left.
func current_prompt() -> Dictionary:
	var index := _next_pending_index()
	if index < 0:
		return {}
	var prompt: Dictionary = STEP_DEFINITIONS[index].duplicate(true)
	prompt["index"] = index
	prompt["step_number"] = index + 1
	prompt["step_count"] = STEP_COUNT
	prompt["replay"] = _replay_active
	return prompt

## Minimal permanent SaveManager payload. Replay state is presentation-only and
## is never mixed into this progression payload.
func serialize_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"understood_mask": _understood_mask
	}

## Transient replay presentation is serialized separately so a scene change can
## continue the requested replay without mixing it into permanent progression.
## A completed or inactive replay always has a normalized zero replay mask.
func serialize_presentation() -> Dictionary:
	return {
		"version": PRESENTATION_VERSION,
		"replay_active": _replay_active,
		"replay_mask": _replay_mask if _replay_active else 0
	}

## Restores a validated minimal payload. Invalid input fails closed without
## changing either persistent understanding or the current replay pass.
func restore_state(raw_state: Variant) -> bool:
	if typeof(raw_state) != TYPE_DICTIONARY:
		return false
	var state := raw_state as Dictionary
	if not _is_integer_number(state.get("version", null)):
		return false
	if int(state.version) != SAVE_VERSION:
		return false
	if not _is_integer_number(state.get("understood_mask", null)):
		return false
	var restored_mask := int(state.understood_mask)
	if restored_mask < 0:
		return false
	_understood_mask = restored_mask & FULL_MASK
	_replay_active = false
	_replay_mask = 0
	return true

## Restores only transient replay presentation. Validation is completed before
## either field is changed, so malformed payloads preserve the current pass.
## Unknown high mask bits are bounded to the ten-step contract. A full replay
## mask is equivalent to a finished replay and therefore normalizes inactive.
func restore_presentation(raw_presentation: Variant) -> bool:
	if typeof(raw_presentation) != TYPE_DICTIONARY:
		return false
	var presentation := raw_presentation as Dictionary
	if not _is_integer_number(presentation.get("version", null)):
		return false
	if int(presentation.version) != PRESENTATION_VERSION:
		return false
	if typeof(presentation.get("replay_active", null)) != TYPE_BOOL:
		return false
	if not _is_integer_number(presentation.get("replay_mask", null)):
		return false
	var restored_mask := int(presentation.replay_mask)
	if restored_mask < 0:
		return false
	var restored_active := bool(presentation.replay_active)
	restored_mask &= FULL_MASK
	if not restored_active or restored_mask == FULL_MASK:
		restored_active = false
		restored_mask = 0
	_replay_active = restored_active
	_replay_mask = restored_mask
	return true

static func step_index_for_id(step_id: StringName) -> int:
	for index in STEP_COUNT:
		if StringName(STEP_DEFINITIONS[index].id) == step_id:
			return index
	return -1

static func step_index_for_event(observed_event: StringName) -> int:
	return int(EVENT_TO_STEP.get(observed_event, -1))

static func definitions() -> Array[Dictionary]:
	var detached: Array[Dictionary] = []
	for definition in STEP_DEFINITIONS:
		detached.append(definition.duplicate(true))
	return detached

func _next_pending_index() -> int:
	var active_mask := _replay_mask if _replay_active else _understood_mask
	for index in STEP_COUNT:
		if (active_mask & (1 << index)) == 0:
			return index
	return -1

func _emit_prompt_if_changed(previous_prompt_id: StringName) -> void:
	if current_step_id() != previous_prompt_id:
		prompt_changed.emit(current_prompt())

static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number)

static func _bit_count(mask: int) -> int:
	var count := 0
	var remaining := mask & FULL_MASK
	while remaining != 0:
		count += remaining & 1
		remaining >>= 1
	return count
