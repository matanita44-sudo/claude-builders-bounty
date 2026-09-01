extends Node

const NestViewScript := preload("res://scripts/ui/nest_view.gd")
const RunSceneScript := preload("res://scripts/gameplay/run_scene.gd")
const QA_SCHEMA := "infinidive.qa.v1"
const QA_PUBLISH_INTERVAL := 0.1

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
		"view":"nest"
	}
	if is_instance_valid(current_view) and current_view is RunScene:
		snapshot.merge((current_view as RunScene).qa_snapshot(), true)
	JavaScriptBridge.eval("globalThis.__INFINIDIVE_QA_STATE = %s;" % JSON.stringify(snapshot), true)
