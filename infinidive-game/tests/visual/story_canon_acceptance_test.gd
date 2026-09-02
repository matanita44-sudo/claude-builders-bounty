extends Node

const HebrewContentClass := preload("res://scripts/services/localized_content_he.gd")
const PlayerControllerClass := preload("res://scripts/gameplay/player_controller.gd")
const StoryPrologueClass := preload("res://scripts/core/story_prologue.gd")

const STORY_PATH := "res://data/story.json"
const EXPECTED_CANON := {
	"gravemaw": {
		"name":"CRONUS",
		"he_name":"קרונוס",
		"organs": {
			"hunter_eye":{"name":"FATE EYE","he_name":"עין הגורל"},
			"gravity_lung":{"name":"GAIA BREATH","he_name":"נשימת גאיה"},
			"bone_forge":{"name":"ADAMANT FORGE","he_name":"כור האדמנט"},
		},
	},
	"seraph_9": {
		"name":"HYPERION",
		"he_name":"היפריון",
		"organs": {
			"prism_cortex":{"name":"DAWN MIND","he_name":"תודעת השחר"},
			"wing_reactor":{"name":"SOLAR MANTLE","he_name":"מעטה השמש"},
			"halo_choir":{"name":"SUN CROWN","he_name":"כתר השמש"},
		},
	},
	"abyss_leviathan": {
		"name":"OCEANUS",
		"he_name":"אוקיינוס",
		"organs": {
			"vortex_stomach":{"name":"WORLDSTREAM HEART","he_name":"לב זרם העולם"},
			"shock_gland":{"name":"STORM PALM","he_name":"כף הסערה"},
			"brood_sac":{"name":"RIVER SPRINGS","he_name":"מעיינות הנהר"},
		},
	},
	"null_twin": {
		"name":"MNEMOSYNE",
		"he_name":"מנמוסינה",
		"organs": {
			"memory_cortex":{"name":"MEMORY CROWN","he_name":"כתר הזיכרון"},
			"echo_heart":{"name":"ECHO HEART","he_name":"לב ההד"},
			"reflection_lattice":{"name":"MUSE VEIL","he_name":"צעיף המוזות"},
		},
	},
}

# The data manifest owns the AION/Titan mythology and uses direct {en,he}
# localized values. StoryPrologue owns the presentation sequence that introduces
# the same premise, shows the hero unarmed, and only then wakes the Aether spark.

var passed := 0
var failures: Array[String] = []
var pending: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("STORY CANON ACCEPTANCE FAILURE: " + message)


func _run() -> void:
	await get_tree().process_frame
	var original_settings := SettingsManager.values.duplicate(true)
	var bosses := _read_json_array("res://data/bosses.json")
	_test_preserved_ids_and_titan_canon(bosses)
	_test_bilingual_boss_content(bosses)
	if FileAccess.file_exists(STORY_PATH):
		_test_story_manifest(_read_json_dictionary(STORY_PATH),bosses)
	else:
		pending.append("Story manifest is not connected yet: %s" % STORY_PATH)
	await _test_story_prologue_presentation()
	SettingsManager.values = original_settings
	SettingsManager.apply_all()
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	for item in pending:
		print("STORY CANON PENDING: " + item)
	print("INFINIDIVE STORY CANON ACCEPTANCE: %d passed, %d failed, %d pending" % [passed,failures.size(),pending.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _read_json_array(path: String) -> Array:
	var file := FileAccess.open(path,FileAccess.READ)
	_check(file != null,"Canon data must be readable: %s" % path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(typeof(parsed) == TYPE_ARRAY,"Canon data must parse as an array: %s" % path)
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	_check(file != null,"Story manifest must be readable: %s" % path)
	if file == null:
		return {}
	var parser := JSON.new()
	var parse_result := parser.parse(file.get_as_text())
	_check(parse_result == OK,"Story manifest must parse without JSON errors: %s" % parser.get_error_message())
	_check(typeof(parser.data) == TYPE_DICTIONARY,"Story manifest root must be a dictionary")
	return parser.data as Dictionary if typeof(parser.data) == TYPE_DICTIONARY else {}


func _test_preserved_ids_and_titan_canon(bosses: Array) -> void:
	_check(bosses.size() == 4,"Canon must retain exactly four launch bosses")
	var by_id := _index_by_id(bosses)
	_check(_same_key_set(by_id,EXPECTED_CANON),"Mechanical boss IDs must remain gravemaw/seraph_9/abyss_leviathan/null_twin")
	var seen_names: Dictionary = {}
	for boss_id_value in EXPECTED_CANON:
		var boss_id := String(boss_id_value)
		var expected := EXPECTED_CANON[boss_id] as Dictionary
		var boss := by_id.get(boss_id,{}) as Dictionary
		_check(not boss.is_empty(),"Preserved boss ID must exist: %s" % boss_id)
		if boss.is_empty():
			continue
		_check(String(boss.get("name","")) == String(expected.name),"%s must present the canonical Titan name %s" % [boss_id,String(expected.name)])
		_check(not String(boss.get("subtitle","")).is_empty(),"%s needs a canonical subtitle" % boss_id)
		_check(not String(boss.get("fantasy","")).is_empty(),"%s needs a canonical mythology premise" % boss_id)
		_check(not seen_names.has(String(boss.name)),"Titan display names must remain unique: %s" % String(boss.name))
		seen_names[String(boss.name)] = true
		var organs := _index_by_id(boss.get("organs",[]) as Array)
		var expected_organs := expected.organs as Dictionary
		_check(_same_key_set(organs,expected_organs),"%s must preserve its three mechanical organ IDs" % boss_id)
		for organ_id_value in expected_organs:
			var organ_id := String(organ_id_value)
			var organ := organs.get(organ_id,{}) as Dictionary
			var expected_organ := expected_organs[organ_id] as Dictionary
			_check(String(organ.get("name","")) == String(expected_organ.name),"%s must present canonical organ name %s" % [organ_id,String(expected_organ.name)])
			_check(not String(organ.get("ability","")).is_empty(),"%s must retain its mechanical ability link" % organ_id)
			_check(not String(organ.get("effect","")).is_empty(),"%s must explain its exterior consequence" % organ_id)
	_check(seen_names.size() == 4,"All four Titans must remain individually named")


func _test_bilingual_boss_content(bosses: Array) -> void:
	var hebrew_bosses := HebrewContentClass.CONTENT.get("boss",{}) as Dictionary
	var hebrew_organs := HebrewContentClass.CONTENT.get("organ",{}) as Dictionary
	var by_id := _index_by_id(bosses)
	for boss_id_value in EXPECTED_CANON:
		var boss_id := String(boss_id_value)
		var expected := EXPECTED_CANON[boss_id] as Dictionary
		var boss := by_id.get(boss_id,{}) as Dictionary
		var he_boss := hebrew_bosses.get(boss_id,{}) as Dictionary
		_check(not he_boss.is_empty(),"Hebrew boss content key must exist: boss/%s" % boss_id)
		_check(String(he_boss.get("name","")) == String(expected.he_name),"boss/%s/name must use the canonical Hebrew Titan name" % boss_id)
		for field in ["subtitle","fantasy"]:
			_check(not String(boss.get(field,"")).is_empty(),"English boss field must exist: boss/%s/%s" % [boss_id,field])
			_check(not String(he_boss.get(field,"")).is_empty(),"Hebrew boss field must exist: boss/%s/%s" % [boss_id,field])
		SettingsManager.values.language = "en"
		_check(LocalizationService.content_text("boss",boss_id,"name",String(boss.get("name",""))) == String(expected.name),"English runtime boss lookup must resolve %s" % boss_id)
		SettingsManager.values.language = "he"
		_check(LocalizationService.content_text("boss",boss_id,"name",String(boss.get("name",""))) == String(expected.he_name),"Hebrew runtime boss lookup must resolve %s" % boss_id)
		for organ_id_value in (expected.organs as Dictionary):
			var organ_id := String(organ_id_value)
			var expected_organ := (expected.organs as Dictionary)[organ_id] as Dictionary
			var organ := _index_by_id(boss.get("organs",[]) as Array).get(organ_id,{}) as Dictionary
			var he_organ := hebrew_organs.get(organ_id,{}) as Dictionary
			_check(not he_organ.is_empty(),"Hebrew organ content key must exist: organ/%s" % organ_id)
			_check(String(he_organ.get("name","")) == String(expected_organ.he_name),"organ/%s/name must use the canonical Hebrew organ name" % organ_id)
			_check(not String(organ.get("effect","")).is_empty(),"English organ effect must exist: organ/%s/effect" % organ_id)
			_check(not String(he_organ.get("effect","")).is_empty(),"Hebrew organ effect must exist: organ/%s/effect" % organ_id)
			SettingsManager.values.language = "en"
			_check(LocalizationService.content_text("organ",organ_id,"name",String(organ.get("name",""))) == String(expected_organ.name),"English runtime organ lookup must resolve %s" % organ_id)
			SettingsManager.values.language = "he"
			_check(LocalizationService.content_text("organ",organ_id,"name",String(organ.get("name",""))) == String(expected_organ.he_name),"Hebrew runtime organ lookup must resolve %s" % organ_id)


func _test_story_manifest(story: Dictionary, bosses: Array) -> void:
	_check(int(story.get("schema_version",0)) == 1,"Story manifest must declare schema_version 1")
	_check(String(story.get("story_id","")) == "aion_eternal_hunger","Story manifest must retain the AION eternal-hunger canon identity")
	var chapters_value: Variant = story.get("chapters",null)
	_check(typeof(chapters_value) == TYPE_ARRAY,"Story manifest must contain a chapters array")
	var chapters := chapters_value as Array if typeof(chapters_value) == TYPE_ARRAY else []
	_check(chapters.size() == 4,"Story Descent must contain exactly four launch chapters")
	var chapter_bosses: Dictionary = {}
	var chapter_ids: Dictionary = {}
	var chapter_orders: Dictionary = {}
	for raw_chapter in chapters:
		_check(typeof(raw_chapter) == TYPE_DICTIONARY,"Every story chapter must be a dictionary")
		if typeof(raw_chapter) != TYPE_DICTIONARY:
			continue
		var chapter := raw_chapter as Dictionary
		var chapter_id := String(chapter.get("id",""))
		var boss_id := String(chapter.get("boss_id",""))
		var order := int(chapter.get("order",0))
		_check(not chapter_id.is_empty() and not chapter_ids.has(chapter_id),"Story chapter IDs must be nonempty and unique: %s" % chapter_id)
		_check(EXPECTED_CANON.has(boss_id) and not chapter_bosses.has(boss_id),"Each story chapter must link one unique launch boss: %s" % boss_id)
		_check(order >= 1 and order <= 4 and not chapter_orders.has(order),"Story chapter order must uniquely cover 1..4")
		chapter_ids[chapter_id] = true
		chapter_bosses[boss_id] = chapter_id
		chapter_orders[order] = chapter_id
		_test_bilingual_value(chapter.get("title",null),"%s/title" % chapter_id)
		_test_bilingual_value(chapter.get("summary",null),"%s/summary" % chapter_id)
		var reward_value: Variant = chapter.get("reward_shard",null)
		_check(typeof(reward_value) == TYPE_DICTIONARY,"%s must grant a named AION shard" % chapter_id)
		var reward := reward_value as Dictionary if typeof(reward_value) == TYPE_DICTIONARY else {}
		_check(String(reward.get("id","")).begins_with("aion_shard_"),"%s reward must remain an AION shard" % chapter_id)
		_test_bilingual_value(reward.get("name",null),"%s/reward_shard/name" % chapter_id)
		var beats_value: Variant = chapter.get("beats",null)
		_check(typeof(beats_value) == TYPE_ARRAY,"%s must contain story beats" % chapter_id)
		var beats := beats_value as Array if typeof(beats_value) == TYPE_ARRAY else []
		_check(beats.size() >= 3,"%s needs intro, first-breach, and victory beats" % chapter_id)
		var moments: Dictionary = {}
		for raw_beat in beats:
			_check(typeof(raw_beat) == TYPE_DICTIONARY,"%s beat must be a dictionary" % chapter_id)
			if typeof(raw_beat) != TYPE_DICTIONARY:
				continue
			var beat := raw_beat as Dictionary
			var moment := String(beat.get("moment",""))
			_check(not String(beat.get("id","")).is_empty(),"%s beat IDs must be nonempty" % chapter_id)
			_check(not String(beat.get("speaker","")).is_empty(),"%s beats must identify a speaker" % chapter_id)
			_check(not moment.is_empty() and not moments.has(moment),"%s beat moments must be nonempty and unique" % chapter_id)
			moments[moment] = true
			_test_bilingual_value(beat.get("text",null),"%s/%s/text" % [chapter_id,String(beat.get("id","?"))])
		for required_moment in ["chapter_intro","first_breach","boss_defeated"]:
			_check(moments.has(required_moment),"%s must narratively cover %s" % [chapter_id,required_moment])
	_check(_same_key_set(chapter_bosses,_index_by_id(bosses)),"Every launch boss must be linked to exactly one Story Descent chapter")
	_check(chapter_orders.size() == 4,"Story chapters must fill all four progression positions")
	for order in range(1,5):
		_check(chapter_orders.has(order),"Story chapter order must contain position %d" % order)
	var ordered_boss_ids := ["gravemaw","seraph_9","abyss_leviathan","null_twin"]
	for index in chapters.size():
		if typeof(chapters[index]) != TYPE_DICTIONARY:
			continue
		var chapter := chapters[index] as Dictionary
		var order := int(chapter.get("order",0))
		if order < 1 or order > ordered_boss_ids.size():
			continue
		_check(String(chapter.get("boss_id","")) == String(ordered_boss_ids[order-1]),"Story order %d must lead to the intended Titan" % order)
		var expected_requirement := "" if order == 1 else String(ordered_boss_ids[order-2])
		_check(String(chapter.get("requires_boss_id","")) == expected_requirement,"Story order %d must require only the preceding Titan" % order)

	var prologue_value: Variant = story.get("prologue",null)
	_check(typeof(prologue_value) == TYPE_DICTIONARY,"Story manifest must contain a prologue dictionary")
	var prologue := prologue_value as Dictionary if typeof(prologue_value) == TYPE_DICTIONARY else {}
	_check(String(prologue.get("id","")) == "prologue_aion_falls","Data prologue must retain the fall of AION canon identity")
	_test_bilingual_value(prologue.get("title",null),"prologue/title")
	var beats_value: Variant = prologue.get("beats",null)
	_check(typeof(beats_value) == TYPE_ARRAY,"Prologue must contain ordered story beats")
	var beats := beats_value as Array if typeof(beats_value) == TYPE_ARRAY else []
	_check(beats.size() >= 4,"Data prologue needs four concise mythology beats")
	var beat_ids: Dictionary = {}
	for index in beats.size():
		var raw_beat: Variant = beats[index]
		_check(typeof(raw_beat) == TYPE_DICTIONARY,"Prologue beat %d must be a dictionary" % index)
		if typeof(raw_beat) != TYPE_DICTIONARY:
			continue
		var beat := raw_beat as Dictionary
		var beat_id := String(beat.get("id",""))
		_check(not beat_id.is_empty() and not beat_ids.has(beat_id),"Data prologue beat IDs must be nonempty and unique")
		beat_ids[beat_id] = true
		_check(String(beat.get("moment","")) == "prologue","Data prologue beats must stay in the prologue moment")
		_check(not String(beat.get("speaker","")).is_empty(),"Data prologue beats must identify a speaker")
		_test_bilingual_value(beat.get("text",null),"prologue/%s/text" % beat_id)


func _test_story_prologue_presentation() -> void:
	var english := StoryPrologueClass.localized("en")
	var hebrew := StoryPrologueClass.localized("he")
	var english_copy := english.get("copy",{}) as Dictionary
	var hebrew_copy := hebrew.get("copy",{}) as Dictionary
	for key in ["skip","continue","finish","progress"]:
		_check(not String(english_copy.get(key,"")).is_empty(),"Story prologue English copy must define %s" % key)
		_check(not String(hebrew_copy.get(key,"")).is_empty(),"Story prologue Hebrew copy must define %s" % key)
	var english_beats := english.get("beats",[]) as Array
	var hebrew_beats := hebrew.get("beats",[]) as Array
	_check(english_beats.size() == 4 and hebrew_beats.size() == 4,"Presented prologue must contain four matching localized beats")
	var expected_ids := ["aion_devoured","eternal_hunger","hero_unarmed","aion_spark"]
	var unarmed_index := -1
	var awakening_index := -1
	for index in mini(english_beats.size(),hebrew_beats.size()):
		var en_beat := english_beats[index] as Dictionary
		var he_beat := hebrew_beats[index] as Dictionary
		var beat_id := String(en_beat.get("id",""))
		_check(beat_id == String(he_beat.get("id","")),"Presented prologue localization order must match at beat %d" % index)
		if index < expected_ids.size():
			_check(beat_id == String(expected_ids[index]),"Presented prologue beat %d must retain the intended canon order" % index)
		for field in ["eyebrow","title","body"]:
			_check(not String(en_beat.get(field,"")).is_empty(),"Presented prologue English %s must exist at beat %s" % [field,beat_id])
			_check(not String(he_beat.get(field,"")).is_empty(),"Presented prologue Hebrew %s must exist at beat %s" % [field,beat_id])
		_check(String(en_beat.get("symbol","")) == String(he_beat.get("symbol","")),"Presented prologue symbol must be language-neutral at beat %s" % beat_id)
		_check(String(en_beat.get("accent","")) == String(he_beat.get("accent","")),"Presented prologue accent must be language-neutral at beat %s" % beat_id)
		if beat_id == "hero_unarmed":
			unarmed_index = index
			_check(String(en_beat.get("symbol","")) == "unarmed","Hero-unarmed beat must use the unarmed presentation")
		elif beat_id == "aion_spark":
			awakening_index = index
			_check(String(en_beat.get("symbol","")) == "spark","AION spark beat must use the awakening presentation")
	_check(unarmed_index >= 0 and awakening_index > unarmed_index,"Hero must be shown unarmed before the Aether/AION spark awakens")

	var player := PlayerControllerClass.new()
	add_child(player)
	await get_tree().process_frame
	var initial := player.presentation_snapshot()
	_check(not bool(initial.get("aether_awakened",true)),"Player presentation must start before Aether awakening")
	_check(not bool(initial.get("visible_weapon",true)),"Unarmed prologue presentation cannot expose a physical weapon")
	_check(not bool(initial.get("muzzle_fire",true)),"Unarmed prologue presentation cannot emit muzzle fire")
	player.set_aether_awakened(true)
	var awakened := player.presentation_snapshot()
	_check(bool(awakened.get("aether_awakened",false)),"Aether presentation must awaken only after the unarmed beat")
	_check(not bool(awakened.get("visible_weapon",true)),"Aether awakening must remain hand-cast rather than add a gun")
	_check(not bool(awakened.get("muzzle_fire",true)),"Aether awakening cannot be presented as muzzle fire")
	player.queue_free()
	await get_tree().process_frame


func _test_bilingual_value(value: Variant, context: String) -> void:
	_check(typeof(value) == TYPE_DICTIONARY,"Bilingual localization value must be a dictionary: %s" % context)
	if typeof(value) != TYPE_DICTIONARY:
		return
	var localized := value as Dictionary
	var english := String(localized.get("en",""))
	var hebrew := String(localized.get("he",""))
	_check(not english.is_empty(),"English localization must exist: %s/en" % context)
	_check(not hebrew.is_empty(),"Hebrew localization must exist: %s/he" % context)
	_check(english != hebrew,"English and Hebrew localization must not collapse to one fallback: %s" % context)


func _index_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_value in values:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue
		var value := raw_value as Dictionary
		var id := String(value.get("id",""))
		if not id.is_empty():
			result[id] = value
	return result


func _same_key_set(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for key in first:
		if not second.has(key):
			return false
	return true
