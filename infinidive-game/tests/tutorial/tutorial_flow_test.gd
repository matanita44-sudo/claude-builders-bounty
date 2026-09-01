extends Node

const TutorialFlowClass := preload("res://scripts/core/tutorial_flow.gd")

var passed := 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("TUTORIAL FLOW TEST FAILURE: " + message)

func _run() -> void:
	_test_contract()
	_test_ordering_skip_and_idempotence()
	_test_complete_path_and_alternative_event()
	_test_minimal_serialization_and_validation()
	_test_replay_and_reset_preserve_progress()
	_test_presentation_serialization()
	_test_presentation_validation_preserves_state()
	_test_detached_views()
	print("INFINIDIVE TUTORIAL FLOW TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

func _test_contract() -> void:
	var definitions: Array[Dictionary] = TutorialFlowClass.definitions()
	_check(definitions.size() == 10, "Tutorial must expose exactly ten required steps")
	var ids: Dictionary = {}
	var keys: Dictionary = {}
	for index in definitions.size():
		var definition := definitions[index]
		var step_id := StringName(definition.get("id", &""))
		var message_key := StringName(definition.get("message_key", &""))
		_check(not step_id.is_empty(), "Step %d must have an id" % index)
		_check(String(message_key).begins_with("tutorial."), "Step %s must expose a localized message key" % step_id)
		_check(not (definition.get("events", []) as Array).is_empty(), "Step %s must have an observed gameplay event" % step_id)
		ids[step_id] = true
		keys[message_key] = true
		_check(TutorialFlowClass.step_index_for_id(step_id) == index, "Step id %s must resolve to its ordered index" % step_id)
		for event_value in definition.events:
			_check(TutorialFlowClass.step_index_for_event(StringName(event_value)) == index, "Event %s must resolve to step %s" % [event_value, step_id])
	_check(ids.size() == 10, "Tutorial step ids must be unique")
	_check(keys.size() == 10, "Tutorial message keys must be unique")
	_check(TutorialFlowClass.step_index_for_event(&"unknown_event") == -1, "Unknown events must not resolve")

func _test_ordering_skip_and_idempotence() -> void:
	var flow = TutorialFlowClass.new()
	var signals := {"understood": 0, "prompt": 0}
	flow.step_understood.connect(func(_step_id: StringName, _event: StringName) -> void: signals.understood += 1)
	flow.prompt_changed.connect(func(_prompt: Dictionary) -> void: signals.prompt += 1)
	_check(flow.current_step_id() == &"move", "A fresh tutorial must start with movement")
	_check(flow.current_message_key() == &"tutorial.drag_to_move", "Fresh prompt must expose the movement localization key")
	_check(flow.pending_count() == 10 and flow.understood_count() == 0, "Fresh tutorial must have ten pending steps")
	_check(flow.observe_event(TutorialFlowClass.EVENT_FIRST_SHOT), "An out-of-order understood action must be recorded")
	_check(flow.current_step_id() == &"move", "Out-of-order understanding must not hide an earlier pending prompt")
	_check(flow.has_understood(&"auto_fire"), "Out-of-order event must persist understanding")
	_check(not flow.observe_event(TutorialFlowClass.EVENT_FIRST_SHOT), "Repeated event must be idempotent")
	_check(int(signals.understood) == 1, "Idempotent event must emit step_understood only once")
	_check(int(signals.prompt) == 0, "Out-of-order event must not emit an unchanged prompt")
	_check(flow.observe_event(TutorialFlowClass.EVENT_MOVEMENT_STARTED), "Movement event must complete the first step")
	_check(flow.current_step_id() == &"defend", "Flow must skip the already-understood automatic-fire step")
	_check(int(signals.prompt) == 1, "Advancing over understood steps must emit one new prompt")
	var snapshot := flow.serialize_state()
	_check(not flow.observe_event(&"unknown_event"), "Unknown event must fail closed")
	_check(flow.serialize_state() == snapshot, "Unknown event must not mutate tutorial progress")

func _test_complete_path_and_alternative_event() -> void:
	var flow = TutorialFlowClass.new()
	var signals := {"completion": 0}
	flow.flow_completed.connect(func() -> void: signals.completion += 1)
	var events: Array[StringName] = [
		TutorialFlowClass.EVENT_MOVEMENT_STARTED,
		TutorialFlowClass.EVENT_FIRST_SHOT,
		TutorialFlowClass.EVENT_TELEGRAPH_AVOIDED,
		TutorialFlowClass.EVENT_EXPOSED_ARMOR_HIT,
		TutorialFlowClass.EVENT_FIRST_DIVE,
		TutorialFlowClass.EVENT_ORGAN_DESTROYED,
		TutorialFlowClass.EVENT_MUTATION_SELECTED,
		TutorialFlowClass.EVENT_BOSS_ABILITY_CHANGED,
		TutorialFlowClass.EVENT_PLAYER_DEATH,
		TutorialFlowClass.EVENT_FORGE_PURCHASE
	]
	for event_id in events:
		_check(flow.observe_event(event_id), "Required tutorial event %s must advance once" % event_id)
	_check(flow.is_complete(), "All ten demonstrated actions must complete the tutorial")
	_check(flow.current_prompt().is_empty(), "No instruction may remain after all steps are understood")
	_check(flow.current_step_id().is_empty() and flow.current_message_key().is_empty(), "Completed flow must expose no stale prompt ids")
	_check(flow.pending_count() == 0 and flow.understood_count() == 10, "Completed counters must be exact")
	_check(int(signals.completion) == 1, "Tutorial completion signal must fire once")
	_check(not flow.observe_event(TutorialFlowClass.EVENT_BOSS_PHASE_REACHED), "Alternative phase event must be idempotent after death taught the same step")
	_check(int(signals.completion) == 1, "Repeated completion events must not repeat completion signal")

	var phase_flow = TutorialFlowClass.new()
	_check(phase_flow.observe_event(TutorialFlowClass.EVENT_BOSS_PHASE_REACHED), "Finishing a phase must satisfy the finish-or-fail step")
	_check(phase_flow.has_understood(&"finish_or_fail"), "Phase completion must mark the shared finish-or-fail step")
	_check(not phase_flow.observe_event(TutorialFlowClass.EVENT_PLAYER_DEATH), "Death must be idempotent after phase completion")

func _test_minimal_serialization_and_validation() -> void:
	var source = TutorialFlowClass.new()
	source.observe_event(TutorialFlowClass.EVENT_MOVEMENT_STARTED)
	source.observe_event(TutorialFlowClass.EVENT_FIRST_DASH)
	source.observe_event(TutorialFlowClass.EVENT_ORGAN_DESTROYED)
	var state := source.serialize_state()
	_check(state.size() == 2, "Serialized tutorial state must contain only version and bitmask")
	_check(int(state.version) == TutorialFlowClass.SAVE_VERSION, "Serialized tutorial state must be versioned")
	_check(typeof(state.understood_mask) == TYPE_INT, "Serialized understanding must use a compact integer bitmask")
	_check(not state.has("replay") and not state.has("current_step"), "Presentation state must not enter the save payload")
	var json_state: Variant = JSON.parse_string(JSON.stringify(state))
	var restored = TutorialFlowClass.new()
	_check(restored.restore_state(json_state), "JSON-round-tripped minimal state must restore")
	_check(restored.serialize_state() == state, "Restored state must preserve the exact understood bitmask")
	_check(restored.current_step_id() == &"auto_fire", "Restore must resume at the first not-yet-understood step")
	_check(restored.has_understood(&"move") and restored.has_understood(&"defend") and restored.has_understood(&"destroy_organ"), "Restore must preserve non-contiguous understood steps")

	var stable_state := restored.serialize_state()
	_check(not restored.restore_state({"version": 99, "understood_mask": 0}), "Unsupported save version must be rejected")
	_check(not restored.restore_state({"version": 1, "understood_mask": -1}), "Negative bitmask must be rejected")
	_check(not restored.restore_state({"version": 1, "understood_mask": 1.5}), "Fractional bitmask must be rejected")
	_check(not restored.restore_state({"version": "1", "understood_mask": 1}), "String version must be rejected")
	_check(not restored.restore_state([]), "Non-dictionary tutorial state must be rejected")
	_check(restored.serialize_state() == stable_state, "Invalid restore attempts must preserve current progress")
	_check(restored.restore_state({"version": 1.0, "understood_mask": float(TutorialFlowClass.FULL_MASK)}), "Integral JSON-style floats must restore safely")
	_check(restored.is_complete(), "Full persisted bitmask must restore completion")
	_check(restored.restore_state({"version": 1, "understood_mask": TutorialFlowClass.FULL_MASK | (1 << 20)}), "Unknown future bits must be sanitized")
	_check(restored.serialize_state().understood_mask == TutorialFlowClass.FULL_MASK, "Unknown future bits must not leak back into saves")

func _test_replay_and_reset_preserve_progress() -> void:
	var flow = TutorialFlowClass.new()
	flow.observe_event(TutorialFlowClass.EVENT_MOVEMENT_STARTED)
	flow.observe_event(TutorialFlowClass.EVENT_FIRST_SHOT)
	flow.observe_event(TutorialFlowClass.EVENT_FIRST_DASH)
	var persistent_before := flow.serialize_state()
	_check(flow.current_step_id() == &"break_armor", "Normal flow must reach the fourth pending step")
	flow.begin_replay()
	_check(flow.is_replaying(), "Replay must enter a distinct presentation pass")
	_check(flow.current_step_id() == &"move", "Replay must re-present the first instruction")
	_check(bool(flow.current_prompt().replay), "Replay prompt must be explicitly labelled for UI callers")
	_check(flow.serialize_state() == persistent_before, "Starting replay must not change persistent understanding")
	_check(flow.observe_event(TutorialFlowClass.EVENT_MOVEMENT_STARTED), "Previously understood movement may advance once in replay")
	_check(not flow.observe_event(TutorialFlowClass.EVENT_MOVEMENT_STARTED), "Replay observations must also be idempotent")
	_check(flow.current_step_id() == &"auto_fire", "Replay must advance in tutorial order")
	_check(flow.serialize_state() == persistent_before, "Re-observing understood replay steps must not rewrite progression")
	flow.reset_presentation()
	_check(not flow.is_replaying(), "Reset must leave replay mode")
	_check(flow.current_step_id() == &"break_armor", "Reset must return to normal progress, not erase it")
	_check(flow.serialize_state() == persistent_before, "Reset must preserve every understood step")

	var completed = TutorialFlowClass.new()
	for event_id in _canonical_events():
		completed.observe_event(event_id)
	var complete_state := completed.serialize_state()
	var signals := {"replay": 0}
	completed.replay_completed.connect(func() -> void: signals.replay += 1)
	completed.begin_replay()
	for event_id in _canonical_events():
		_check(completed.observe_event(event_id), "Complete-save replay event %s must advance its replay pass" % event_id)
	_check(int(signals.replay) == 1, "Completing replay must emit exactly one replay_completed signal")
	_check(not completed.is_replaying(), "Replay must close itself after the tenth demonstrated action")
	_check(completed.current_prompt().is_empty(), "Completed replay must leave no stale instruction")
	_check(completed.serialize_state() == complete_state, "Full replay must preserve the original complete save")
	completed.reset_presentation()
	_check(completed.serialize_state() == complete_state, "Reset after replay must not erase completed progression")

func _test_presentation_serialization() -> void:
	var source = TutorialFlowClass.new()
	_check(source.restore_state({"version": 1, "understood_mask": TutorialFlowClass.FULL_MASK}), "Presentation test must begin from completed permanent progress")
	_check(source.serialize_presentation() == {"version":1,"replay_active":false,"replay_mask":0}, "Normal presentation must serialize as inactive with a zero mask")
	source.begin_replay()
	for event_id in _canonical_events().slice(0,4):
		_check(source.observe_event(event_id), "Replay setup event %s must advance" % event_id)
	var permanent_before := source.serialize_state()
	var presentation := source.serialize_presentation()
	_check(presentation.size() == 3, "Presentation payload must contain only version, active state, and replay mask")
	_check(int(presentation.version) == TutorialFlowClass.PRESENTATION_VERSION, "Presentation payload must be versioned independently")
	_check(bool(presentation.replay_active), "Active replay must serialize as active")
	_check(int(presentation.replay_mask) == 0x0F, "Four replay steps must serialize as the bounded low four bits")
	_check(not permanent_before.has("replay_active") and not permanent_before.has("replay_mask"), "Permanent state must never contain replay presentation")

	var restored = TutorialFlowClass.new()
	_check(restored.restore_state(permanent_before), "Cross-scene target must restore permanent progress")
	_check(restored.restore_presentation(presentation), "Valid active presentation must restore across scenes")
	_check(restored.is_replaying(), "Restored presentation must continue replay mode")
	_check(restored.current_step_id() == &"enter_breach", "Restored replay must resume at the fifth presentation step")
	_check(restored.serialize_state() == permanent_before, "Restoring presentation must not alter permanent understanding")
	for event_id in _canonical_events().slice(4):
		_check(restored.observe_event(event_id), "Restored replay event %s must continue the pass" % event_id)
	_check(not restored.is_replaying(), "Completing a restored replay must normalize it inactive")
	_check(restored.serialize_presentation() == {"version":1,"replay_active":false,"replay_mask":0}, "Completed replay presentation must serialize normalized")

	var bounded = TutorialFlowClass.new()
	bounded.restore_state(permanent_before)
	_check(bounded.restore_presentation({"version":1,"replay_active":true,"replay_mask":(1 << 23) | 0x05}), "Non-negative presentation masks with future bits must restore safely")
	_check(bounded.serialize_presentation().replay_mask == 0x05, "Presentation mask must be bounded to the ten launch steps")
	_check(bounded.current_step_id() == &"auto_fire", "Bounded sparse replay mask must resume at its first missing step")
	_check(bounded.restore_presentation({"version":1,"replay_active":false,"replay_mask":0x1A}), "Inactive presentation may restore from a stale non-zero mask")
	_check(bounded.serialize_presentation() == {"version":1,"replay_active":false,"replay_mask":0}, "Inactive presentation must normalize its mask to zero")
	_check(bounded.restore_presentation({"version":1,"replay_active":true,"replay_mask":TutorialFlowClass.FULL_MASK}), "A fully observed replay payload must restore safely")
	_check(not bounded.is_replaying() and int(bounded.serialize_presentation().replay_mask) == 0, "A full replay mask must normalize to completed inactive presentation")

func _test_presentation_validation_preserves_state() -> void:
	var flow = TutorialFlowClass.new()
	flow.restore_state({"version":1,"understood_mask":0x15})
	flow.begin_replay()
	flow.observe_event(TutorialFlowClass.EVENT_MOVEMENT_STARTED)
	flow.observe_event(TutorialFlowClass.EVENT_FIRST_DASH)
	var persistent_before := flow.serialize_state()
	var presentation_before := flow.serialize_presentation()
	var invalid_payloads: Array = [
		[],
		{},
		{"version":99,"replay_active":true,"replay_mask":1},
		{"version":"1","replay_active":true,"replay_mask":1},
		{"version":1,"replay_active":"true","replay_mask":1},
		{"version":1,"replay_active":true,"replay_mask":-1},
		{"version":1,"replay_active":true,"replay_mask":1.25},
		{"version":1,"replay_active":true},
		{"version":1,"replay_mask":1}
	]
	for invalid_index in invalid_payloads.size():
		_check(not flow.restore_presentation(invalid_payloads[invalid_index]), "Invalid presentation payload %d must be rejected" % invalid_index)
		_check(flow.serialize_presentation() == presentation_before, "Invalid presentation payload %d must preserve the active replay pass" % invalid_index)
		_check(flow.serialize_state() == persistent_before, "Invalid presentation payload %d must preserve permanent progress" % invalid_index)
	_check(flow.restore_presentation({"version":1.0,"replay_active":true,"replay_mask":5.0}), "Integral JSON-style presentation numbers must restore")
	_check(flow.serialize_presentation() == presentation_before, "Equivalent JSON-style presentation must preserve exact state")

func _test_detached_views() -> void:
	var flow = TutorialFlowClass.new()
	var prompt := flow.current_prompt()
	prompt.id = &"tampered"
	(prompt.events as Array).clear()
	_check(flow.current_step_id() == &"move", "Mutating a returned prompt must not alter flow state")
	_check((flow.current_prompt().events as Array).size() == 1, "Nested prompt data must also be detached")
	var definitions: Array[Dictionary] = TutorialFlowClass.definitions()
	definitions[0].id = &"tampered"
	_check(TutorialFlowClass.step_index_for_id(&"move") == 0, "Mutating exported definitions must not alter the static contract")

func _canonical_events() -> Array[StringName]:
	return [
		TutorialFlowClass.EVENT_MOVEMENT_STARTED,
		TutorialFlowClass.EVENT_FIRST_SHOT,
		TutorialFlowClass.EVENT_FIRST_DASH,
		TutorialFlowClass.EVENT_EXPOSED_ARMOR_HIT,
		TutorialFlowClass.EVENT_FIRST_DIVE,
		TutorialFlowClass.EVENT_ORGAN_DESTROYED,
		TutorialFlowClass.EVENT_MUTATION_SELECTED,
		TutorialFlowClass.EVENT_BOSS_ABILITY_CHANGED,
		TutorialFlowClass.EVENT_BOSS_PHASE_REACHED,
		TutorialFlowClass.EVENT_FORGE_PURCHASE
	]
