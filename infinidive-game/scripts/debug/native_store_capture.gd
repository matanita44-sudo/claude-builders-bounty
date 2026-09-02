class_name NativeStoreCapture
extends Node

const RunSceneScript := preload("res://scripts/gameplay/run_scene.gd")

const SCHEMA := "infinidive.native-ios-store-capture.v1"
const VISUAL_IDENTITY := "current-bright-gameplay-v1"
const ACTIVATION_TOKEN := "ios-simulator-ci-v1"
const CAPTURE_ARGUMENT := "--infinidive-native-store-capture=%s" % ACTIVATION_TOKEN
const STAGE_ARGUMENT_PREFIX := "--infinidive-capture-stage="
const READY_FILENAME := "native-store-capture-ready.json"
const STAGES := [
	"nest",
	"titan-exterior",
	"breach-open",
	"organ-chamber",
	"mutation-choice",
	"post-organ-titan",
]
const STAGE_ELAPSED_SECONDS := {
	"titan-exterior": 12.0,
	"breach-open": 21.0,
	"organ-chamber": 37.0,
	"mutation-choice": 44.0,
	"post-organ-titan": 52.0,
}
const CAPTURE_CONFIG := {
	"boss": "gravemaw",
	"weapon": "pulse_needle",
	"difficulty": "diver",
	"seed": 24681357,
	"mode": "story",
	"competitive": false,
}

var _main: Node
var _request: Dictionary = {}


static func evaluate_request(
	debug_build: bool,
	ios_feature: bool,
	environment: Dictionary,
	arguments: PackedStringArray
) -> Dictionary:
	# Deliberately require independent build, platform, CI, environment, and
	# command-line gates. A normal local Debug build still cannot enter this lane.
	if not debug_build or not ios_feature:
		return {}
	if String(environment.get("CI", "")) != "true":
		return {}
	if String(environment.get("INFINIDIVE_NATIVE_STORE_CAPTURE", "")) != ACTIVATION_TOKEN:
		return {}

	var activation_count := 0
	var stage_count := 0
	var requested_stage := ""
	for argument_value in arguments:
		var argument := String(argument_value)
		if argument == CAPTURE_ARGUMENT:
			activation_count += 1
		elif argument.begins_with(STAGE_ARGUMENT_PREFIX):
			stage_count += 1
			requested_stage = argument.trim_prefix(STAGE_ARGUMENT_PREFIX)
	if activation_count != 1 or stage_count != 1 or requested_stage not in STAGES:
		return {}
	return {
		"stage": requested_stage,
		"debug_build": true,
		"ios_feature": true,
		"explicit_ci": true,
		"explicit_environment": true,
		"explicit_argument": true,
	}


static func request_from_runtime() -> Dictionary:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		arguments = OS.get_cmdline_args()
	return evaluate_request(
		OS.is_debug_build(),
		OS.has_feature("ios"),
		{
			"CI": OS.get_environment("CI"),
			"INFINIDIVE_NATIVE_STORE_CAPTURE": OS.get_environment(
				"INFINIDIVE_NATIVE_STORE_CAPTURE"
			),
		},
		arguments
	)


func try_start(main_node: Node) -> bool:
	_request = request_from_runtime()
	if _request.is_empty() or main_node == null or not is_instance_valid(main_node):
		return false
	_main = main_node
	call_deferred("_prepare_capture")
	return true


func _prepare_capture() -> void:
	await _wait_process_frames(3)
	var stage := String(_request.get("stage", ""))
	var runtime_snapshot: Dictionary
	if stage == "nest":
		var nest: Node = _main.get("current_view")
		if nest == null or not is_instance_valid(nest) or not nest is NestView:
			_fail_closed("nest view was not ready")
			return
		nest.set_process(false)
		nest.queue_redraw()
		runtime_snapshot = {
			"view": "nest",
			"state": null,
			"boss_id": null,
			"destroyed_organs": [],
		}
	else:
		_main.call("_launch_run", CAPTURE_CONFIG.duplicate(true))
		await _wait_process_frames(4)
		var run: Node = _main.get("current_view")
		if run == null or not is_instance_valid(run) or not run is RunScene:
			_fail_closed("run scene was not ready")
			return
		if not _prepare_run_stage(run, stage):
			_fail_closed("stage transition failed: %s" % stage)
			return
		_freeze_run(run, stage)
		await _wait_process_frames(3)
		runtime_snapshot = _runtime_snapshot(run)

	var marker := {
		"schema": SCHEMA,
		"visual_identity": VISUAL_IDENTITY,
		"qa_only": true,
		"release_eligible": false,
		"stage": stage,
		"stage_index": STAGES.find(stage),
		"capture_seed": int(CAPTURE_CONFIG.seed),
		"gate": _request.duplicate(true),
		"runtime": runtime_snapshot,
	}
	if not _write_ready_marker(marker):
		_fail_closed("could not write readiness marker")
		return
	print("INFINIDIVE_NATIVE_STORE_CAPTURE_READY|%s|%s" % [stage, SCHEMA])


func _prepare_run_stage(run: Node, stage: String) -> bool:
	run.set("_paused", false)
	run.call("_transition", RunSceneScript.RunState.EXTERIOR)
	run.call("_start_phase", 0)
	if int(run.get("state")) != RunSceneScript.RunState.EXTERIOR:
		return false
	match stage:
		"titan-exterior":
			var armor_max := float(run.get("armor_max"))
			var armor_health := armor_max * 0.72
			run.set("armor_health", armor_health)
			var exterior_visual: Node = run.get("_boss_visual")
			exterior_visual.call("set_health", armor_health, armor_max)
		"breach-open":
			run.call("_damage_target", {
				"id": "boss",
				"damage": float(run.get("armor_max")) + 1.0,
				"behavior": "pulse",
			})
			if int(run.get("state")) != RunSceneScript.RunState.BREACH_OPEN:
				return false
		"organ-chamber", "mutation-choice", "post-organ-titan":
			if not _enter_first_organ_chamber(run):
				return false
			if stage in ["mutation-choice", "post-organ-titan"]:
				run.call("_damage_target", {
					"id": "organ",
					"damage": float(run.get("organ_max")) + 1.0,
					"behavior": "pulse",
				})
				if int(run.get("state")) != RunSceneScript.RunState.MUTATION_CHOICE:
					return false
				var changed_map := run.get("_organ_map") as OrganAbilityMap
				if changed_map == null or changed_map.destroyed_organs() != ["hunter_eye"]:
					return false
			if stage == "post-organ-titan":
				var offered: Array = run.get("_offered_mutation_ids")
				if offered.is_empty():
					return false
				run.call("_select_mutation", String(offered[0]))
				if int(run.get("state")) != RunSceneScript.RunState.DIVING_OUT:
					return false
				run.call("_return_outside")
				if int(run.get("state")) != RunSceneScript.RunState.EXTERIOR or int(run.get("phase")) != 1:
					return false
				var post_armor_max := float(run.get("armor_max"))
				var post_armor_health := post_armor_max * 0.64
				run.set("armor_health", post_armor_health)
				var post_visual: Node = run.get("_boss_visual")
				post_visual.call("set_health", post_armor_health, post_armor_max)
		_:
			return false
	run.set("elapsed", float(STAGE_ELAPSED_SECONDS.get(stage, 0.0)))
	run.queue_redraw()
	return true


func _enter_first_organ_chamber(run: Node) -> bool:
	run.call("_open_breach")
	if int(run.get("state")) != RunSceneScript.RunState.BREACH_OPEN:
		return false
	run.call("_request_dive")
	if int(run.get("state")) != RunSceneScript.RunState.ORGAN_SELECT:
		return false
	var organ_map := run.get("_organ_map") as OrganAbilityMap
	if organ_map == null or not organ_map.alive_organs().has("hunter_eye"):
		return false
	run.call("_select_organ", "hunter_eye")
	if int(run.get("state")) != RunSceneScript.RunState.DIVING_IN:
		return false
	run.call("_begin_internal_route")
	run.call("_begin_organ_chamber")
	return int(run.get("state")) == RunSceneScript.RunState.ORGAN_CHAMBER


func _freeze_run(run: Node, stage: String) -> void:
	run.set("_paused", true)
	run.set_physics_process(false)
	var player: Node = run.get("_player")
	if player != null and is_instance_valid(player):
		player.call("set_controls_active", false)
		player.set_physics_process(false)
		player.set_process(false)
	var boss_visual: Node = run.get("_boss_visual")
	if boss_visual != null and is_instance_valid(boss_visual):
		boss_visual.set_process(false)
	var projectile_pool: Node = run.get("_projectiles")
	if projectile_pool != null and is_instance_valid(projectile_pool):
		projectile_pool.set_process(false)
		projectile_pool.set_physics_process(false)
	# Let RunScene update the final state label once, then freeze its decorative
	# clock. Choice overlays remain live Controls but no input is injected in CI.
	run.call_deferred("set_process", false)
	run.set("elapsed", float(STAGE_ELAPSED_SECONDS.get(stage, run.get("elapsed"))))
	run.queue_redraw()


func _runtime_snapshot(run: Node) -> Dictionary:
	var projected: Dictionary = run.call("qa_snapshot")
	var organ_map := run.get("_organ_map") as OrganAbilityMap
	if organ_map == null:
		return {}
	return {
		"view": "run",
		"state": projected.get("state", null),
		"phase": projected.get("phase", null),
		"boss_id": String((run.get("boss_definition") as Dictionary).get("id", "")),
		"organ": (projected.get("organ", {}) as Dictionary).duplicate(true),
		"ability": (projected.get("ability", {}) as Dictionary).duplicate(true),
		"mutation": (projected.get("mutation", {}) as Dictionary).duplicate(true),
		"boss_visual_state": projected.get("boss_visual_state", null),
		"destroyed_organs": organ_map.destroyed_organs(),
	}


func _write_ready_marker(marker: Dictionary) -> bool:
	var final_path := "user://%s" % READY_FILENAME
	var temporary_path := final_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(marker, "  ") + "\n")
	file.flush()
	file.close()
	var final_absolute := ProjectSettings.globalize_path(final_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_absolute)
	return DirAccess.rename_absolute(temporary_absolute, final_absolute) == OK


func _wait_process_frames(count: int) -> void:
	for _index in maxi(0, count):
		await get_tree().process_frame


func _fail_closed(reason: String) -> void:
	push_error("Native iOS store capture refused: %s" % reason)
	print("INFINIDIVE_NATIVE_STORE_CAPTURE_FAILED|%s" % reason)
