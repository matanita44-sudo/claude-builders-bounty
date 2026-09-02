extends Node

const NestViewScript := preload("res://scripts/ui/nest_view.gd")
const RunSceneScript := preload("res://scripts/gameplay/run_scene.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const QA_SCHEMA := "infinidive.qa.v2"
const QA_PUBLISH_INTERVAL := 0.1
const QA_RUN_SCALAR_FIELDS := [
	"view",
	"run_identity_present",
	"state",
	"state_valid",
	"numeric_state_valid",
	"controls_active",
	"movement_observed",
	"dash_count",
	"dash_time",
	"dash_charges",
	"dash_max_charges",
	"dash_recharge",
	"dash_cooldown",
	"dash_ratio",
	"elapsed",
	"phase",
	"boss_visual_state"
]
const QA_SAVE_SOURCES := ["default", "primary", "backup"]

var current_view: Node
var _qa_enabled := false
var _qa_publish_accumulator := 0.0
var _qa_revision := 0
var _qa_run_generation := 0

func _ready() -> void:
	_qa_enabled = _qa_query_enabled()
	set_process(_qa_enabled)
	_show_nest()
	if _qa_enabled:
		_publish_qa_state()

func _process(delta: float) -> void:
	if not _qa_enabled:
		return
	_qa_publish_accumulator += delta
	if _qa_publish_accumulator < QA_PUBLISH_INTERVAL:
		return
	_qa_publish_accumulator = fmod(_qa_publish_accumulator, QA_PUBLISH_INTERVAL)
	_publish_qa_state()

func _exit_tree() -> void:
	if _qa_enabled and OS.has_feature("web"):
		JavaScriptBridge.eval("delete globalThis.__INFINIDIVE_QA_STATE;", true)

func _clear_view() -> void:
	if is_instance_valid(current_view):
		current_view.queue_free()
		current_view = null

func _show_nest() -> void:
	_clear_view()
	var nest := NestViewScript.new()
	nest.start_requested.connect(_start_run)
	add_child(nest)
	current_view=nest

func _start_run(config: Dictionary) -> void:
	if _qa_enabled:
		_qa_run_generation += 1
	_clear_view()
	var run := RunSceneScript.new()
	run.initialize(config)
	run.run_finished.connect(_on_run_finished)
	add_child(run)
	current_view=run

func _on_run_finished(payload: Dictionary) -> void:
	match String(payload.get("action","nest")):
		"retry": _start_run(payload.get("config",{}))
		_: _show_nest()

func _qa_query_enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	var query := String(window.location.search).trim_prefix("?")
	for entry in query.split("&", false):
		var pair := entry.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "infinidive_qa" and pair[1] == "1":
			return true
	return false

func _publish_qa_state() -> void:
	if not _qa_enabled or not OS.has_feature("web"):
		return
	_qa_revision += 1
	var snapshot := {
		"schema":QA_SCHEMA,
		"revision":_qa_revision,
		"run_generation":_qa_run_generation,
		"view":"nest",
		"phase":null,
		"health":{"player_ratio":null, "target_ratio":null},
		"organ":{"id":null, "status":null, "health_ratio":null},
		"ability":{"id":null, "status":null},
		"boss_visual_state":null,
		"mutation":{"offered_count":null, "selected_count":null, "last_selected_id":null},
		"persistence":_qa_persistence_snapshot()
	}
	if is_instance_valid(current_view) and current_view is RunScene:
		snapshot.merge(_qa_run_snapshot(current_view as RunScene), true)
	JavaScriptBridge.eval("globalThis.__INFINIDIVE_QA_STATE = %s;" % JSON.stringify(snapshot), true)

func _qa_run_snapshot(run: RunScene) -> Dictionary:
	return project_qa_run_snapshot(run.qa_snapshot())

static func project_qa_run_snapshot(runtime: Dictionary) -> Dictionary:
	# Deep-project the established contract. Do not forward runtime dictionaries
	# or arrays: future nested gameplay fields must opt in explicitly instead of
	# becoming observable through the public Web QA query by accident.
	var snapshot: Dictionary = {}
	for field in QA_RUN_SCALAR_FIELDS:
		if runtime.has(field):
			snapshot[field] = runtime[field]
	var raw_position: Variant = runtime.get("player_position", null)
	if typeof(raw_position) == TYPE_ARRAY and (raw_position as Array).size() == 2:
		snapshot.player_position = [
			(raw_position as Array)[0],
			(raw_position as Array)[1]
		]
	else:
		snapshot.player_position = null
	var raw_health: Variant = runtime.get("health", null)
	var health := raw_health as Dictionary if typeof(raw_health) == TYPE_DICTIONARY else {}
	snapshot.health = {
		"player_ratio":health.get("player_ratio", null),
		"target_ratio":health.get("target_ratio", null)
	}
	var raw_organ: Variant = runtime.get("organ", null)
	var organ := raw_organ as Dictionary if typeof(raw_organ) == TYPE_DICTIONARY else {}
	snapshot.organ = {
		"id":organ.get("id", null),
		"status":organ.get("status", null),
		"health_ratio":organ.get("health_ratio", null)
	}
	var raw_ability: Variant = runtime.get("ability", null)
	var ability := raw_ability as Dictionary if typeof(raw_ability) == TYPE_DICTIONARY else {}
	snapshot.ability = {
		"id":ability.get("id", null),
		"status":ability.get("status", null)
	}
	var raw_mutation: Variant = runtime.get("mutation", null)
	var mutation := raw_mutation as Dictionary if typeof(raw_mutation) == TYPE_DICTIONARY else {}
	snapshot.mutation = {
		"offered_count":mutation.get("offered_count", null),
		"selected_count":mutation.get("selected_count", null),
		"last_selected_id":mutation.get("last_selected_id", null)
	}
	return snapshot

func _qa_persistence_snapshot() -> Dictionary:
	var tutorial_step_count: Variant = null
	var mutation_discovery_count: Variant = null
	if typeof(SaveManager.profile) == TYPE_DICTIONARY:
		tutorial_step_count = _qa_tutorial_understood_count(
			SaveManager.profile.get("tutorial_state", null)
		)
		mutation_discovery_count = _qa_mutation_id_count(
			SaveManager.profile.get("discovered_mutations", null),
			GameData.mutations.size()
		)
	var save_source := String(SaveManager.last_load_source)
	return {
		"tutorial_step_count": tutorial_step_count,
		"mutation_discovery_count": mutation_discovery_count,
		"save_source": save_source if save_source in QA_SAVE_SOURCES else null
	}

func _qa_tutorial_understood_count(raw_state: Variant) -> Variant:
	if typeof(raw_state) != TYPE_DICTIONARY:
		return null
	var state := raw_state as Dictionary
	var version: Variant = _qa_bounded_integer(
		state.get("version", null),
		TutorialFlowScript.SAVE_VERSION,
		TutorialFlowScript.SAVE_VERSION
	)
	var mask: Variant = _qa_bounded_integer(
		state.get("understood_mask", null),
		0,
		TutorialFlowScript.FULL_MASK
	)
	if version == null or mask == null:
		return null
	var remaining := int(mask)
	var count := 0
	while remaining != 0:
		count += remaining & 1
		remaining >>= 1
	return count

func _qa_mutation_id_count(raw_ids: Variant, maximum: int) -> Variant:
	if typeof(raw_ids) != TYPE_ARRAY:
		return null
	var ids := raw_ids as Array
	if ids.size() < 0 or ids.size() > maximum:
		return null
	var seen: Dictionary = {}
	for raw_id in ids:
		if typeof(raw_id) != TYPE_STRING:
			return null
		var mutation_id := String(raw_id)
		if mutation_id.is_empty() or seen.has(mutation_id) or GameData.get_mutation(mutation_id).is_empty():
			return null
		seen[mutation_id] = true
	return ids.size()

static func _qa_bounded_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return null
	var numeric := float(value)
	if not is_finite(numeric) or numeric != floor(numeric):
		return null
	var integer := int(numeric)
	return integer if integer >= minimum and integer <= maximum else null
