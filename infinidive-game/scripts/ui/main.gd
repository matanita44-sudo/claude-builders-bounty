extends Node

const NestViewScript := preload("res://scripts/ui/nest_view.gd")
const RunSceneScript := preload("res://scripts/gameplay/run_scene.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const StoryOverlayScript := preload("res://scripts/ui/story_overlay.gd")
const StoryPrologueScript := preload("res://scripts/core/story_prologue.gd")
const StoryServiceScript := preload("res://scripts/services/story_service.gd")
const StoryPresentationScript := preload("res://scripts/core/story_presentation.gd")
const NativeStoreCaptureScript := preload("res://scripts/debug/native_store_capture.gd")
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
var _story_overlay: StoryOverlay
var _pending_story_run: Dictionary = {}
var _pending_story_result: Dictionary = {}
var _story_catalog: StoryService = StoryServiceScript.new()
var _native_store_capture: Node

func _ready() -> void:
	_qa_enabled = _qa_query_enabled()
	set_process(_qa_enabled)
	if not _story_catalog.initialize():
		push_error("Story catalog failed validation: %s" % ", ".join(_story_catalog.get_validation_errors()))
	_show_nest()
	_native_store_capture = NativeStoreCaptureScript.new()
	add_child(_native_store_capture)
	if not _native_store_capture.try_start(self):
		_native_store_capture.queue_free()
		_native_store_capture = null
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
	_clear_story_overlay()
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
	if _should_present_aion_prologue(config):
		_present_aion_prologue(config)
		return
	if _should_present_chapter_intro(config):
		_present_chapter_intro(config)
		return
	_launch_run(config)

func _launch_run(config: Dictionary) -> void:
	if _qa_enabled:
		_qa_run_generation += 1
	_clear_view()
	var run := RunSceneScript.new()
	run.initialize(_story_run_config(config))
	run.run_finished.connect(_on_run_finished)
	add_child(run)
	current_view=run

func _story_run_config(config: Dictionary) -> Dictionary:
	var prepared := config.duplicate(true)
	prepared.erase("story_first_breach_notice")
	if not _should_present_chapter_breach(prepared):
		return prepared
	var chapter := _story_catalog.get_chapter_for_boss(String(prepared.get("boss","")))
	var presentation := StoryPresentationScript.chapter_breach(_story_catalog,chapter,LocalizationService.current_locale())
	var beats: Array = presentation.get("beats",[])
	if beats.size() != 1 or typeof(beats[0]) != TYPE_DICTIONARY:
		return prepared
	prepared["story_first_breach_notice"] = (beats[0] as Dictionary).duplicate(true)
	return prepared

func _should_present_chapter_breach(config: Dictionary) -> bool:
	if _qa_enabled or OS.get_environment("INFINIDIVE_TEST_ISOLATED") == "1":
		return false
	if not _story_catalog.initialized or String(config.get("mode","story")) != "story":
		return false
	var boss_id := String(config.get("boss",""))
	var chapter := _story_catalog.get_chapter_for_boss(boss_id)
	if chapter.is_empty() or _story_boss_completed(boss_id):
		return false
	if not StoryPresentationScript.presented_ledger_is_valid(SaveManager.profile):
		return false
	var beat_id := _story_breach_beat_id(chapter)
	return not beat_id.is_empty() and not StoryPresentationScript.has_presented_beat(SaveManager.profile,beat_id)

func _story_breach_beat_id(chapter: Dictionary) -> String:
	for raw_beat in chapter.get("beats",[]):
		if typeof(raw_beat) != TYPE_DICTIONARY:
			continue
		var beat: Dictionary = raw_beat
		if String(beat.get("moment","")) == "first_breach":
			return String(beat.get("id","")).strip_edges()
	return ""

func _should_present_aion_prologue(config: Dictionary) -> bool:
	if _qa_enabled or OS.get_environment("INFINIDIVE_TEST_ISOLATED") == "1":
		return false
	if String(config.get("mode","story")) != "story" or String(config.get("boss","")) != "gravemaw":
		return false
	var tutorial_state: Dictionary = SaveManager.profile.get("tutorial_state",{})
	return int(tutorial_state.get("understood_mask",0)) == 0

func _present_aion_prologue(config: Dictionary) -> void:
	_clear_story_overlay()
	_pending_story_run = config.duplicate(true)
	_pending_story_run["aether_prologue"] = true
	_pending_story_run["story_intro_seen"] = true
	_story_overlay = StoryOverlayScript.new()
	_story_overlay.finished.connect(_finish_aion_prologue)
	_story_overlay.skipped.connect(_finish_aion_prologue)
	add_child(_story_overlay)
	var locale := LocalizationService.current_locale()
	var presentation: Dictionary = StoryPrologueScript.localized(locale)
	if not _story_overlay.present(presentation.get("beats",[]),presentation.get("copy",{}),true):
		_finish_aion_prologue()

func _finish_aion_prologue() -> void:
	var config := _pending_story_run.duplicate(true)
	_pending_story_run.clear()
	_clear_story_overlay()
	if not config.is_empty():
		_launch_run(config)

func _should_present_chapter_intro(config: Dictionary) -> bool:
	if _qa_enabled or OS.get_environment("INFINIDIVE_TEST_ISOLATED") == "1":
		return false
	if not _story_catalog.initialized or bool(config.get("story_intro_seen",false)):
		return false
	if String(config.get("mode","story")) != "story":
		return false
	var boss_id := String(config.get("boss",""))
	if _story_catalog.get_chapter_for_boss(boss_id).is_empty():
		return false
	return not _story_boss_completed(boss_id)

func _present_chapter_intro(config: Dictionary) -> void:
	var chapter := _story_catalog.get_chapter_for_boss(String(config.get("boss","")))
	var locale := LocalizationService.current_locale()
	var presentation := StoryPresentationScript.chapter_intro(_story_catalog,chapter,locale)
	_pending_story_run = config.duplicate(true)
	_pending_story_run["story_intro_seen"] = true
	_clear_story_overlay()
	_story_overlay = StoryOverlayScript.new()
	_story_overlay.finished.connect(_finish_chapter_intro)
	_story_overlay.skipped.connect(_finish_chapter_intro)
	add_child(_story_overlay)
	if not _story_overlay.present(presentation.get("beats",[]),presentation.get("copy",{}),true):
		_finish_chapter_intro()

func _finish_chapter_intro() -> void:
	var config := _pending_story_run.duplicate(true)
	_pending_story_run.clear()
	_clear_story_overlay()
	if not config.is_empty():
		_launch_run(config)

func _clear_story_overlay() -> void:
	if is_instance_valid(_story_overlay):
		_story_overlay.queue_free()
	_story_overlay = null

func _on_run_finished(payload: Dictionary) -> void:
	if _should_present_chapter_victory(payload):
		_present_chapter_victory(payload)
		return
	_continue_run_finished(payload)

func _should_present_chapter_victory(payload: Dictionary) -> bool:
	if _qa_enabled or OS.get_environment("INFINIDIVE_TEST_ISOLATED") == "1":
		return false
	var result: Dictionary = payload.get("result",{})
	if not bool(result.get("won",false)) or String(result.get("mode","")) != "story":
		return false
	var boss_id := String(result.get("boss_id",""))
	if _story_catalog.get_chapter_for_boss(boss_id).is_empty():
		return false
	return bool(result.get("story_first_clear",false))

func _story_boss_completed(boss_id: String) -> bool:
	var boss_index := StoryServiceScript.REQUIRED_BOSS_ORDER.find(boss_id)
	if boss_index < 0:
		return false
	var required_depth := boss_index + 1
	var progress: Dictionary = SaveManager.profile.get("difficulty_progress",{})
	for raw_depth in progress.values():
		if int(raw_depth) >= required_depth:
			return true
	return false

func _present_chapter_victory(payload: Dictionary) -> void:
	var result: Dictionary = payload.get("result",{})
	var chapter := _story_catalog.get_chapter_for_boss(String(result.get("boss_id","")))
	var locale := LocalizationService.current_locale()
	var presentation := StoryPresentationScript.chapter_victory(_story_catalog,chapter,locale)
	_pending_story_result = payload.duplicate(true)
	_clear_story_overlay()
	_story_overlay = StoryOverlayScript.new()
	_story_overlay.finished.connect(_finish_chapter_victory)
	_story_overlay.skipped.connect(_finish_chapter_victory)
	add_child(_story_overlay)
	if not _story_overlay.present(presentation.get("beats",[]),presentation.get("copy",{}),true):
		_finish_chapter_victory()

func _finish_chapter_victory() -> void:
	var payload := _pending_story_result.duplicate(true)
	_pending_story_result.clear()
	_clear_story_overlay()
	if not payload.is_empty():
		_continue_run_finished(payload)

func _continue_run_finished(payload: Dictionary) -> void:
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
