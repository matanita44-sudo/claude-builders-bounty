extends Node

const Story := preload("res://scripts/services/story_service.gd")
const FIXTURE_PATH := "user://infinidive_story_fixture.json"
const RAW_FIXTURE_PATH := "user://infinidive_story_raw_fixture.json"

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool,message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("STORY SERVICE TEST FAILURE: " + message)


func _run() -> void:
	_cleanup()
	_test_shipped_catalog_and_canon()
	_test_unlock_order_and_save_boundary()
	_test_beat_lookup_and_localization()
	_test_invalid_data_fails_closed()
	_cleanup()
	print("INFINIDIVE STORY SERVICE TESTS: %d passed, %d failed" % [passed,failures.size()])
	if not failures.is_empty():
		for failure in failures:
			print(" - " + failure)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_shipped_catalog_and_canon() -> void:
	var service := Story.new()
	_check(service.initialize(),"Shipped story catalog must initialize")
	_check(service.initialized,"Successful initialization must set the ready state")
	_check(service.get_validation_errors().is_empty(),"Shipped story catalog must validate cleanly")
	_check(service.get_story_id()=="aion_eternal_hunger","Story catalog must expose the AION canon ID")
	var prologue := service.get_prologue()
	_check(String(prologue.get("id",""))=="prologue_aion_falls","Prologue ID must remain stable")
	_check((prologue.get("beats",[]) as Array).size()==4,"Prologue must teach the complete premise in four short beats")
	_check(service.localized_field(prologue,"title","en").contains("FEAST"),"English prologue title must name the forbidden feast")
	_check(not service.localized_field(prologue,"title","he").is_empty(),"Prologue title must include Hebrew")
	var chapters := service.get_chapters()
	_check(chapters.size()==4,"Canon must contain exactly four launch chapters")
	var actual_order: Array[String] = []
	var shard_ids: Dictionary = {}
	var all_canon_text := ""
	for index in chapters.size():
		var chapter: Dictionary = chapters[index]
		var boss_id := String(chapter.get("boss_id",""))
		actual_order.append(boss_id)
		_check(int(chapter.get("order",-1))==index+1,"Chapter order must remain contiguous at %d" % (index+1))
		_check(boss_id==Story.REQUIRED_BOSS_ORDER[index],"Chapter %d must retain its canonical boss ID" % (index+1))
		var expected_requirement := "" if index==0 else Story.REQUIRED_BOSS_ORDER[index-1]
		_check(String(chapter.get("requires_boss_id",""))==expected_requirement,"Chapter %d must require the previous Titan" % (index+1))
		_check(not service.localized_field(chapter,"title","en").is_empty(),"Chapter %d requires an English title" % (index+1))
		_check(not service.localized_field(chapter,"title","he").is_empty(),"Chapter %d requires a Hebrew title" % (index+1))
		_check(not service.localized_field(chapter,"summary","en").is_empty(),"Chapter %d requires an English summary" % (index+1))
		_check(not service.localized_field(chapter,"summary","he").is_empty(),"Chapter %d requires a Hebrew summary" % (index+1))
		var shard: Dictionary = chapter.get("reward_shard",{})
		var shard_id := String(shard.get("id",""))
		_check(shard_id.begins_with("aion_shard_"),"Chapter %d must restore a named AION shard" % (index+1))
		_check(not shard_ids.has(shard_id),"Every restored AION shard must be unique")
		shard_ids[shard_id] = true
		var beats: Array = chapter.get("beats",[])
		_check(beats.size()==3,"Chapter %d must contain intro, breach, and victory beats" % (index+1))
		for beat_index in beats.size():
			var beat: Dictionary = beats[beat_index]
			_check(String(beat.get("moment",""))==Story.REQUIRED_CHAPTER_MOMENTS[beat_index],"Chapter %d beat order must remain deterministic" % (index+1))
			all_canon_text += " " + service.localized_field(beat,"text","en")
	_check(actual_order==Story.REQUIRED_BOSS_ORDER,"Launch story must retain the four-Titan progression")
	_check(shard_ids.size()==4,"Four chapters must return four different living shards")
	var prologue_text := ""
	for raw_beat in prologue.get("beats",[]):
		prologue_text += " " + service.localized_field(raw_beat as Dictionary,"text","en")
	_check(prologue_text.contains("AION") and prologue_text.contains("eternity"),"Prologue must establish AION as god of eternity")
	_check(prologue_text.contains("hunger forever"),"Prologue must establish the eternal-hunger curse")
	_check(all_canon_text.contains("returns"),"Every chapter arc must culminate in returning AION's power")
	var mutable_copy := chapters[0]
	mutable_copy["boss_id"] = "tampered"
	_check(String(service.get_chapters()[0].boss_id)=="gravemaw","Catalog getters must return defensive copies")
	service = null


func _test_unlock_order_and_save_boundary() -> void:
	var service := Story.new()
	_check(service.initialize(),"Unlock-order service must initialize")
	var completion_steps := [
		[],
		["gravemaw"],
		["gravemaw","seraph_9"],
		["gravemaw","seraph_9","abyss_leviathan"],
		["gravemaw","seraph_9","abyss_leviathan","null_twin"],
	]
	for step in completion_steps.size():
		var unlocked := service.get_unlocked_chapters(completion_steps[step])
		_check(unlocked.size()==mini(step+1,4),"Completion step %d must unlock exactly the next canonical chapter" % step)
		for chapter_index in unlocked.size():
			_check(String(unlocked[chapter_index].boss_id)==Story.REQUIRED_BOSS_ORDER[chapter_index],"Unlocked chapters must preserve canonical order")
	var corrupted_order := service.get_unlocked_chapters(["seraph_9","null_twin"])
	_check(corrupted_order.size()==1 and String(corrupted_order[0].boss_id)=="gravemaw","Out-of-order legacy progress must fail closed without skipping Titans")
	var duplicates := service.get_unlocked_chapters(["gravemaw","gravemaw","unknown_boss"])
	_check(duplicates.size()==2,"Duplicate and unknown boss IDs must not distort unlock state")
	_check(String(service.get_next_chapter([]).boss_id)=="gravemaw","Fresh progress must point to Cronus")
	_check(String(service.get_next_chapter(["gravemaw"]).boss_id)=="seraph_9","First clear must point to Hyperion")
	_check(service.get_next_chapter(completion_steps[4]).is_empty(),"Complete story must expose no phantom next chapter")
	_check(service.get_restored_shard_ids([]).is_empty(),"Fresh progress must not fabricate restored shards")
	_check(service.get_restored_shard_ids(["gravemaw","seraph_9"])==["aion_shard_beginning","aion_shard_radiance"],"Restored shards must follow completed canonical chapters")
	_check(service.get_restored_shard_ids(["seraph_9"]).is_empty(),"Out-of-order save data must not grant a later shard")
	_check(not service.is_story_complete(completion_steps[3]),"Three Titan clears must not complete the four-shard story")
	_check(service.is_story_complete(completion_steps[4]),"Four canonical clears must complete the launch story")
	var source := FileAccess.get_file_as_string("res://scripts/services/story_service.gd")
	_check(not source.contains("SaveManager"),"StoryService must remain independent from the save singleton")
	_check(not source.contains("save_profile"),"StoryService must never persist or migrate profile data itself")
	var inert := Story.new()
	_check(inert.get_unlocked_chapters([]).is_empty(),"Uninitialized service must fail closed for unlocks")
	_check(inert.get_next_chapter([]).is_empty(),"Uninitialized service must fail closed for next chapter")
	_check(inert.get_restored_shard_ids(completion_steps[4]).is_empty(),"Uninitialized service must not infer saved shards")
	service = null
	inert = null


func _test_beat_lookup_and_localization() -> void:
	var service := Story.new()
	_check(service.initialize(),"Beat-lookup service must initialize")
	var prologue_beat := service.get_beat("prologue_hunger_curse")
	_check(not prologue_beat.is_empty(),"Known prologue beat must resolve")
	_check(String(prologue_beat.get("moment",""))=="prologue","Prologue beat must expose its moment")
	_check(String(prologue_beat.get("speaker",""))=="AION","Hunger curse must be voiced by AION")
	_check(service.get_chapter_id_for_beat("prologue_hunger_curse").is_empty(),"Prologue beat must not masquerade as a chapter beat")
	var breach := service.get_beat("oceanus_breach")
	_check(String(breach.get("moment",""))=="first_breach","Known breach beat must expose its trigger")
	_check(service.get_chapter_id_for_beat("oceanus_breach")=="chapter_oceanus","Beat index must resolve its owning chapter")
	_check(service.localized_field(breach,"text","en").contains("organ"),"English beat lookup must return authored copy")
	_check(service.localized_field(breach,"text","he-IL").contains("איבר"),"Regional Hebrew locale must normalize to the authored translation")
	_check(service.localized_field(breach,"text","fr-FR")==service.localized_field(breach,"text","en"),"Unsupported locale must fall back to English")
	_check(service.localized_field(breach,"missing","en").is_empty(),"Missing localized field must fail closed")
	_check(service.get_beat("missing_beat").is_empty(),"Unknown beat ID must return an empty dictionary")
	_check(service.get_chapter_id_for_beat("missing_beat").is_empty(),"Unknown beat ID must have no owner")
	_check(String(service.get_chapter("chapter_hyperion").boss_id)=="seraph_9","Chapter ID index must resolve Hyperion")
	_check(String(service.get_chapter_for_boss("null_twin").id)=="chapter_mnemosyne","Boss index must resolve Mnemosyne")
	_check(service.get_chapter("missing_chapter").is_empty(),"Unknown chapter ID must fail closed")
	_check(service.get_chapter_for_boss("missing_boss").is_empty(),"Unknown boss ID must fail closed")
	var mutable := service.get_beat("cronus_intro")
	mutable["speaker"] = "TAMPERED"
	_check(String(service.get_beat("cronus_intro").speaker)=="ARCHIVE","Beat lookup must return a defensive copy")
	var all_ids: Dictionary = {}
	var total_beats := 0
	for raw_beat in service.get_prologue().get("beats",[]):
		var beat: Dictionary = raw_beat
		all_ids[String(beat.id)] = true
		total_beats += 1
	for chapter in service.get_chapters():
		for raw_beat in chapter.get("beats",[]):
			var beat: Dictionary = raw_beat
			all_ids[String(beat.id)] = true
			total_beats += 1
	_check(total_beats==16,"Launch catalog must expose four prologue and twelve chapter beats")
	_check(all_ids.size()==total_beats,"Every story beat ID must be globally unique")
	service = null


func _test_invalid_data_fails_closed() -> void:
	var missing := Story.new()
	_check(not missing.initialize("user://story-file-does-not-exist.json"),"Missing story catalog must be rejected")
	_check(_errors_contain(missing,"Cannot open"),"Missing catalog must report its open failure")
	_write_raw(RAW_FIXTURE_PATH,"{ definitely not json")
	var malformed := Story.new()
	_check(not malformed.initialize(RAW_FIXTURE_PATH),"Malformed story JSON must be rejected")
	_check(_errors_contain(malformed,"Invalid story JSON"),"Malformed JSON must report a bounded parse error")
	_write_raw(RAW_FIXTURE_PATH,"[]")
	var wrong_root := Story.new()
	_check(not wrong_root.initialize(RAW_FIXTURE_PATH),"Array story root must be rejected")
	_check(_errors_contain(wrong_root,"root must be a dictionary"),"Wrong root type must report its contract failure")
	var shipped := _read_shipped_story()
	_check(not shipped.is_empty(),"Invalid-data tests require a readable shipped fixture")

	var wrong_schema := shipped.duplicate(true)
	wrong_schema.schema_version = 99
	_expect_invalid(wrong_schema,"schema_version","Wrong schema")

	var wrong_order := shipped.duplicate(true)
	wrong_order.chapters[1].boss_id = "null_twin"
	_expect_invalid(wrong_order,"invalid boss order","Boss order tamper")

	var wrong_gate := shipped.duplicate(true)
	wrong_gate.chapters[2].requires_boss_id = "gravemaw"
	_expect_invalid(wrong_gate,"unlock requirement","Unlock-chain tamper")

	var duplicate_beat := shipped.duplicate(true)
	duplicate_beat.chapters[0].beats[0].id = "prologue_hunger_curse"
	_expect_invalid(duplicate_beat,"duplicate or missing beat id","Duplicate global beat")

	var missing_hebrew := shipped.duplicate(true)
	missing_hebrew.chapters[3].summary.erase("he")
	_expect_invalid(missing_hebrew,"requires he text","Missing Hebrew")

	var missing_shard := shipped.duplicate(true)
	missing_shard.chapters[0].reward_shard = []
	_expect_invalid(missing_shard,"requires reward_shard","Malformed shard")

	var extra_chapter := shipped.duplicate(true)
	extra_chapter.chapters.append(extra_chapter.chapters[3].duplicate(true))
	_expect_invalid(extra_chapter,"exactly four chapters","Extra chapter")

	var failed := Story.new()
	_check(failed.initialize(),"Reinitialization guard requires a valid indexed state first")
	_check(not failed.initialize(FIXTURE_PATH),"Last invalid fixture must remain rejected")
	_check(failed.get_story_id().is_empty(),"Rejected catalog must not publish partial story state")
	_check(failed.get_chapters().is_empty(),"Rejected catalog must not publish partial chapters")
	_check(failed.get_beat("mnemosyne_victory").is_empty(),"Rejected catalog must not retain a stale beat index")
	missing = null
	malformed = null
	wrong_root = null
	failed = null


func _expect_invalid(candidate: Dictionary,error_fragment: String,label: String) -> void:
	_write_json(FIXTURE_PATH,candidate)
	var service := Story.new()
	_check(not service.initialize(FIXTURE_PATH),"%s must be rejected" % label)
	_check(_errors_contain(service,error_fragment),"%s must report %s" % [label,error_fragment])
	_check(not service.initialized,"%s must leave service uninitialized" % label)
	service = null


func _errors_contain(service: StoryService,fragment: String) -> bool:
	for error_value in service.get_validation_errors():
		if String(error_value).contains(fragment):
			return true
	return false


func _read_shipped_story() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	return parsed as Dictionary if typeof(parsed)==TYPE_DICTIONARY else {}


func _write_json(path: String,value: Dictionary) -> void:
	_write_raw(path,JSON.stringify(value))


func _write_raw(path: String,value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	_check(file!=null,"Story test fixture must open for writing")
	if file!=null:
		file.store_string(value)


func _cleanup() -> void:
	for path in [FIXTURE_PATH,RAW_FIXTURE_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
