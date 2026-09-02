extends Node

const StoryServiceClass := preload("res://scripts/services/story_service.gd")
const StoryPresentationClass := preload("res://scripts/core/story_presentation.gd")
const MainScript := preload("res://scripts/ui/main.gd")
const RunSceneScript := preload("res://scripts/gameplay/run_scene.gd")

const EXPECTED_ACCENTS := {
	"gravemaw": "#D8A533",
	"seraph_9": "#F1BE48",
	"abyss_leviathan": "#2CB8BC",
	"null_twin": "#9B78C6",
}

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool,message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("STORY PRESENTATION TEST FAILURE: " + message)


func _run() -> void:
	_check(OS.get_environment("INFINIDIVE_TEST_ISOLATED") == "1","Story presentation suite must run in the isolated test profile")
	_check(String(SaveManager.default_profile().settings.language) == "en","Fresh profiles must launch the game in English")
	var service := StoryServiceClass.new()
	_check(service.initialize(),"Shipped story catalog must initialize for presentation tests")
	var chapters := service.get_chapters()
	_check(chapters.size() == 4,"Presentation suite must cover all four launch chapters")
	_test_all_chapter_presentations(service,chapters)
	_test_locale_normalization_and_fail_closed(service,chapters[0] if not chapters.is_empty() else {})
	_test_main_decision_helpers()
	_test_run_scene_story_marker()
	print("INFINIDIVE STORY PRESENTATION TESTS: %d passed, %d failed" % [passed,failures.size()])
	if not failures.is_empty():
		for failure in failures:
			print(" - " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_all_chapter_presentations(service: StoryService,chapters: Array[Dictionary]) -> void:
	for chapter_index in chapters.size():
		var chapter := chapters[chapter_index]
		var boss_id := String(chapter.get("boss_id",""))
		_check(boss_id == StoryServiceClass.REQUIRED_BOSS_ORDER[chapter_index],"Chapter %d presentation must retain canonical Titan order" % (chapter_index+1))
		var intro_beat := _beat_for_moment(chapter,"chapter_intro")
		var victory_beat := _beat_for_moment(chapter,"boss_defeated")
		var shard: Dictionary = chapter.get("reward_shard",{})
		_check(not intro_beat.is_empty(),"%s must provide a chapter-intro beat" % boss_id)
		_check(not victory_beat.is_empty(),"%s must provide a first-clear victory beat" % boss_id)
		_check(not shard.is_empty(),"%s must provide a restored AION shard" % boss_id)
		for locale in ["en","he"]:
			var is_hebrew: bool = String(locale) == "he"
			var accent := String(EXPECTED_ACCENTS.get(boss_id,""))
			_assert_card(
				"%s/%s/intro" % [boss_id,locale],
				StoryPresentationClass.chapter_intro(service,chapter,locale),
				String(intro_beat.get("id","")),
				("פרק %d" if is_hebrew else "CHAPTER %d") % int(chapter.get("order",1)),
				service.localized_field(chapter,"title",locale),
				service.localized_field(intro_beat,"text",locale),
				"titan",
				accent,
				"התייצב מול הטיטאן" if is_hebrew else "FACE THE TITAN"
			)
			_assert_card(
				"%s/%s/victory" % [boss_id,locale],
				StoryPresentationClass.chapter_victory(service,chapter,locale),
				String(victory_beat.get("id","")),
				"שבר איון הושב" if is_hebrew else "AION SHARD RESTORED",
				service.localized_field(shard,"name",locale),
				service.localized_field(victory_beat,"text",locale),
				"shard",
				accent,
				"חזור לקן האחרון" if is_hebrew else "RETURN TO THE NEST"
			)


func _assert_card(
	context: String,
	presentation: Dictionary,
	expected_id: String,
	expected_eyebrow: String,
	expected_title: String,
	expected_body: String,
	expected_symbol: String,
	expected_accent: String,
	expected_finish: String
) -> void:
	_check(not presentation.is_empty(),"%s must produce a presentation payload" % context)
	var beats: Array = presentation.get("beats",[])
	_check(beats.size() == 1,"%s must produce exactly one focused story card" % context)
	var beat: Dictionary = {}
	if not beats.is_empty() and typeof(beats[0]) == TYPE_DICTIONARY:
		beat = beats[0]
	var copy: Dictionary = presentation.get("copy",{})
	for key in ["skip","continue","finish","progress"]:
		_check(not String(copy.get(key,"")).is_empty(),"%s must define nonempty %s copy" % [context,key])
	_check(String(beat.get("id","")) == expected_id,"%s must preserve the authored beat ID" % context)
	_check(String(beat.get("eyebrow","")) == expected_eyebrow,"%s must use locale-correct eyebrow copy" % context)
	_check(String(beat.get("title","")) == expected_title and not expected_title.is_empty(),"%s must use the catalog-localized title" % context)
	_check(String(beat.get("body","")) == expected_body and not expected_body.is_empty(),"%s must use the catalog-localized body" % context)
	_check(String(beat.get("symbol","")) == expected_symbol,"%s must use the intended language-neutral symbol" % context)
	_check(String(beat.get("accent","")) == expected_accent,"%s must retain its Titan accent" % context)
	_check(String(copy.get("finish","")) == expected_finish,"%s must use locale-correct finish copy" % context)


func _test_locale_normalization_and_fail_closed(service: StoryService,chapter: Dictionary) -> void:
	if chapter.is_empty():
		_check(false,"Locale tests require the first canonical chapter")
		return
	var shard: Dictionary = chapter.get("reward_shard",{})
	var hebrew_intro := StoryPresentationClass.chapter_intro(service,chapter,"HE_il")
	var hebrew_victory := StoryPresentationClass.chapter_victory(service,chapter,"he-IL")
	var english_intro := StoryPresentationClass.chapter_intro(service,chapter,"EN_us")
	var fallback_intro := StoryPresentationClass.chapter_intro(service,chapter,"fr-FR")
	_check(_card_title(hebrew_intro) == service.localized_field(chapter,"title","he"),"Underscored Hebrew locale must normalize to Hebrew intro copy")
	_check(_card_title(hebrew_victory) == service.localized_field(shard,"name","he"),"Regional Hebrew locale must normalize to Hebrew victory copy")
	_check(_card_title(english_intro) == service.localized_field(chapter,"title","en"),"Underscored English locale must normalize to English intro copy")
	_check(_card_title(fallback_intro) == service.localized_field(chapter,"title","en"),"Unsupported presentation locale must use the catalog's English fallback")
	var unknown_accent := chapter.duplicate(true)
	unknown_accent["boss_id"] = "unknown_titan"
	_check(_card_accent(StoryPresentationClass.chapter_intro(service,unknown_accent,"en")) == "#C88936","Unknown Titan presentation must use the bounded fallback accent")
	_check(StoryPresentationClass.chapter_intro(null,chapter,"en").is_empty(),"Null story service must reject intro presentation")
	_check(StoryPresentationClass.chapter_victory(null,chapter,"en").is_empty(),"Null story service must reject victory presentation")
	_check(StoryPresentationClass.chapter_intro(service,{},"en").is_empty(),"Empty chapter must reject intro presentation")
	_check(StoryPresentationClass.chapter_victory(service,{},"en").is_empty(),"Empty chapter must reject victory presentation")
	var without_intro := _chapter_without_moment(chapter,"chapter_intro")
	var without_victory := _chapter_without_moment(chapter,"boss_defeated")
	_check(StoryPresentationClass.chapter_intro(service,without_intro,"en").is_empty(),"Chapter without intro beat must fail closed")
	_check(StoryPresentationClass.chapter_victory(service,without_victory,"en").is_empty(),"Chapter without victory beat must fail closed")
	var without_shard := chapter.duplicate(true)
	without_shard.erase("reward_shard")
	_check(StoryPresentationClass.chapter_victory(service,without_shard,"en").is_empty(),"Victory without reward shard must fail closed")
	var snapshot := chapter.duplicate(true)
	StoryPresentationClass.chapter_intro(service,chapter,"en")
	StoryPresentationClass.chapter_victory(service,chapter,"he")
	_check(chapter == snapshot,"Presentation adaptation must not mutate story catalog data")


func _test_main_decision_helpers() -> void:
	var initial_test_environment := OS.get_environment("INFINIDIVE_TEST_ISOLATED")
	var original_profile := SaveManager.profile.duplicate(true)
	OS.set_environment("INFINIDIVE_TEST_ISOLATED","")
	SaveManager.profile = SaveManager.default_profile()
	var main = MainScript.new()
	main.set("_qa_enabled",false)
	var main_catalog: StoryService = main.get("_story_catalog")
	_check(main_catalog.initialize(),"Detached Main helper fixture must initialize its story catalog")
	for boss_index in StoryServiceClass.REQUIRED_BOSS_ORDER.size():
		var boss_id: String = StoryServiceClass.REQUIRED_BOSS_ORDER[boss_index]
		var config := {"mode":"story","boss":boss_id}
		SaveManager.profile["difficulty_progress"] = {"diver":0,"deep":0,"abyss":0}
		_check(bool(main.call("_should_present_chapter_intro",config)),"Fresh %s Story chapter must request its intro" % boss_id)
		SaveManager.profile["difficulty_progress"] = {"diver":boss_index+1,"deep":0,"abyss":0}
		_check(not bool(main.call("_should_present_chapter_intro",config)),"Cleared %s Story chapter must not repeat its intro" % boss_id)
		var payload := {"action":"nest","result":{"won":true,"mode":"story","boss_id":boss_id,"story_first_clear":true}}
		_check(bool(main.call("_should_present_chapter_victory",payload)),"First %s Story clear must request its victory beat" % boss_id)
		payload.result.story_first_clear = false
		_check(not bool(main.call("_should_present_chapter_victory",payload)),"Repeated %s Story clear must not repeat its victory beat" % boss_id)
	SaveManager.profile["difficulty_progress"] = {"diver":0,"deep":0,"abyss":0}
	_check(not bool(main.call("_should_present_chapter_intro",{"mode":"story","boss":"gravemaw","story_intro_seen":true})),"Prologue handoff flag must suppress a duplicate Cronus chapter intro")
	_check(not bool(main.call("_should_present_chapter_intro",{"mode":"daily","boss":"gravemaw"})),"Non-Story run must not request chapter intro")
	_check(not bool(main.call("_should_present_chapter_intro",{"mode":"story","boss":"unknown_titan"})),"Unknown boss must not request chapter intro")
	var valid_victory := {"result":{"won":true,"mode":"story","boss_id":"gravemaw","story_first_clear":true}}
	main.set("_qa_enabled",true)
	_check(not bool(main.call("_should_present_chapter_intro",{"mode":"story","boss":"seraph_9"})),"QA mode must suppress chapter intro overlays")
	_check(not bool(main.call("_should_present_chapter_victory",valid_victory)),"QA mode must suppress chapter victory overlays")
	main.set("_qa_enabled",false)
	_check(not bool(main.call("_should_present_chapter_victory",{"result":{"won":false,"mode":"story","boss_id":"gravemaw"}})),"Loss must not request chapter victory")
	_check(not bool(main.call("_should_present_chapter_victory",{"result":{"won":true,"mode":"abyss","boss_id":"gravemaw"}})),"Non-Story win must not request chapter victory")
	_check(not bool(main.call("_should_present_chapter_victory",{"result":{"won":true,"mode":"story","boss_id":"unknown_titan"}})),"Unknown boss win must not request chapter victory")
	_check(not bool(main.call("_should_present_chapter_victory",{})),"Missing run result must not request chapter victory")
	var missing_first_clear := {"result":{"won":true,"mode":"story","boss_id":"gravemaw"}}
	_check(not bool(main.call("_should_present_chapter_victory",missing_first_clear)),"Result without an explicit first-clear marker must not claim chapter victory")
	OS.set_environment("INFINIDIVE_TEST_ISOLATED","1")
	_check(not bool(main.call("_should_present_chapter_intro",{"mode":"story","boss":"seraph_9"})),"Isolated automation must suppress chapter intro overlays")
	_check(not bool(main.call("_should_present_chapter_victory",valid_victory)),"Isolated automation must suppress chapter victory overlays")
	main.free()
	SaveManager.profile = original_profile
	OS.set_environment("INFINIDIVE_TEST_ISOLATED",initial_test_environment)


func _test_run_scene_story_marker() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	var run = RunSceneScript.new()
	SaveManager.profile["difficulty_progress"] = {"diver":0,"deep":0,"abyss":0}
	_check(not bool(run.call("_story_boss_completed_before_run","unknown_titan")),"Unknown Titan must not be marked as a completed Story chapter")
	_check(not bool(run.call("_story_boss_completed_before_run","gravemaw")),"Fresh profile must mark Cronus as a first Story clear candidate")
	SaveManager.profile["difficulty_progress"] = {"diver":1,"deep":0,"abyss":0}
	_check(bool(run.call("_story_boss_completed_before_run","gravemaw")),"Story depth one must mark Cronus complete")
	_check(not bool(run.call("_story_boss_completed_before_run","seraph_9")),"Story depth one must leave Hyperion incomplete")
	SaveManager.profile["difficulty_progress"] = {"diver":2,"deep":0,"abyss":0}
	_check(bool(run.call("_story_boss_completed_before_run","seraph_9")),"Story depth two must mark Hyperion complete")
	_check(not bool(run.call("_story_boss_completed_before_run","abyss_leviathan")),"Story depth two must leave Oceanus incomplete")
	SaveManager.profile["difficulty_progress"] = {"diver":3,"deep":0,"abyss":0}
	_check(bool(run.call("_story_boss_completed_before_run","abyss_leviathan")),"Story depth three must mark Oceanus complete")
	_check(not bool(run.call("_story_boss_completed_before_run","null_twin")),"Story depth three must leave Mnemosyne incomplete")
	SaveManager.profile["difficulty_progress"] = {"diver":0,"deep":0,"abyss":4}
	_check(bool(run.call("_story_boss_completed_before_run","null_twin")),"Any Story difficulty reaching depth four must mark Mnemosyne complete")
	SaveManager.profile["difficulty_progress"] = {"diver":0,"deep":4,"abyss":0}
	_check(bool(run.call("_story_boss_completed_before_run","gravemaw")),"Higher-difficulty Story progress must also mark earlier chapters complete")
	run.free()
	SaveManager.profile = original_profile


func _beat_for_moment(chapter: Dictionary,moment: String) -> Dictionary:
	for raw_beat in chapter.get("beats",[]):
		if typeof(raw_beat) == TYPE_DICTIONARY and String((raw_beat as Dictionary).get("moment","")) == moment:
			return (raw_beat as Dictionary).duplicate(true)
	return {}


func _chapter_without_moment(chapter: Dictionary,moment: String) -> Dictionary:
	var result := chapter.duplicate(true)
	var filtered: Array = []
	for raw_beat in chapter.get("beats",[]):
		if typeof(raw_beat) != TYPE_DICTIONARY or String((raw_beat as Dictionary).get("moment","")) != moment:
			filtered.append((raw_beat as Dictionary).duplicate(true) if typeof(raw_beat) == TYPE_DICTIONARY else raw_beat)
	result["beats"] = filtered
	return result


func _card_title(presentation: Dictionary) -> String:
	var beats: Array = presentation.get("beats",[])
	return String((beats[0] as Dictionary).get("title","")) if not beats.is_empty() and typeof(beats[0]) == TYPE_DICTIONARY else ""


func _card_accent(presentation: Dictionary) -> String:
	var beats: Array = presentation.get("beats",[])
	return String((beats[0] as Dictionary).get("accent","")) if not beats.is_empty() and typeof(beats[0]) == TYPE_DICTIONARY else ""
