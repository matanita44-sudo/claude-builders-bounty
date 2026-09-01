extends Node

const NestViewScript := preload("res://scripts/ui/nest_view.gd")
const RunSceneScript := preload("res://scripts/gameplay/run_scene.gd")

var current_view: Node

func _ready() -> void:
	_show_nest()

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
