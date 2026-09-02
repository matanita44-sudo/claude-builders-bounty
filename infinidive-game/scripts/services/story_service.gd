class_name StoryService
extends RefCounted

## Read-only, data-driven narrative catalog.
##
## The service deliberately owns no profile state and never reads or writes a
## save. Callers pass completed boss IDs into the progression helpers, keeping
## every existing save schema compatible while story presentation can evolve.

const STORY_PATH := "res://data/story.json"
const SCHEMA_VERSION := 1
const REQUIRED_BOSS_ORDER: Array[String] = [
	"gravemaw",
	"seraph_9",
	"abyss_leviathan",
	"null_twin",
]
const REQUIRED_CHAPTER_MOMENTS: Array[String] = [
	"chapter_intro",
	"first_breach",
	"boss_defeated",
]
const SUPPORTED_LOCALES: Array[String] = ["en","he"]

var validation_errors: Array[String] = []
var initialized := false

var _story: Dictionary = {}
var _chapters_by_id: Dictionary = {}
var _chapters_by_boss: Dictionary = {}
var _beats_by_id: Dictionary = {}
var _beat_chapter_ids: Dictionary = {}


func initialize(path: String = STORY_PATH) -> bool:
	_reset()
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		validation_errors.append("Cannot open story catalog: %s" % path)
		return false
	var parser := JSON.new()
	var parse_result := parser.parse(file.get_as_text())
	if parse_result != OK:
		validation_errors.append("Invalid story JSON at line %d" % parser.get_error_line())
		return false
	if typeof(parser.data) != TYPE_DICTIONARY:
		validation_errors.append("Story catalog root must be a dictionary")
		return false
	var candidate: Dictionary = parser.data
	_validate_story(candidate)
	if not validation_errors.is_empty():
		return false
	_story = candidate.duplicate(true)
	_index_story()
	initialized = true
	return true


func get_validation_errors() -> Array[String]:
	return validation_errors.duplicate()


func get_story_id() -> String:
	return String(_story.get("story_id","")) if initialized else ""


func get_prologue() -> Dictionary:
	return (_story.get("prologue",{}) as Dictionary).duplicate(true) if initialized else {}


func get_chapters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not initialized:
		return result
	for raw_chapter in _story.get("chapters",[]):
		result.append((raw_chapter as Dictionary).duplicate(true))
	return result


func get_chapter(chapter_id: String) -> Dictionary:
	if not initialized or not _chapters_by_id.has(chapter_id):
		return {}
	return (_chapters_by_id[chapter_id] as Dictionary).duplicate(true)


func get_chapter_for_boss(boss_id: String) -> Dictionary:
	if not initialized or not _chapters_by_boss.has(boss_id):
		return {}
	return (_chapters_by_boss[boss_id] as Dictionary).duplicate(true)


func get_beat(beat_id: String) -> Dictionary:
	if not initialized or not _beats_by_id.has(beat_id):
		return {}
	return (_beats_by_id[beat_id] as Dictionary).duplicate(true)


func get_chapter_id_for_beat(beat_id: String) -> String:
	return String(_beat_chapter_ids.get(beat_id,"")) if initialized else ""


func get_unlocked_chapters(completed_bosses: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not initialized:
		return result
	var completed := _normalized_completed_bosses(completed_bosses)
	var chain_intact := true
	for raw_chapter in _story.get("chapters",[]):
		var chapter: Dictionary = raw_chapter
		var requirement := String(chapter.get("requires_boss_id",""))
		if not requirement.is_empty():
			chain_intact = chain_intact and completed.has(requirement)
		if chain_intact:
			result.append(chapter.duplicate(true))
	return result


func get_next_chapter(completed_bosses: Array) -> Dictionary:
	var completed := _normalized_completed_bosses(completed_bosses)
	for chapter in get_unlocked_chapters(completed_bosses):
		if not completed.has(String(chapter.get("boss_id",""))):
			return chapter
	return {}


func get_restored_shard_ids(completed_bosses: Array) -> Array[String]:
	var result: Array[String] = []
	if not initialized:
		return result
	var completed := _normalized_completed_bosses(completed_bosses)
	var chain_intact := true
	for raw_chapter in _story.get("chapters",[]):
		var chapter: Dictionary = raw_chapter
		var boss_id := String(chapter.get("boss_id",""))
		var requirement := String(chapter.get("requires_boss_id",""))
		if not requirement.is_empty():
			chain_intact = chain_intact and completed.has(requirement)
		if not chain_intact or not completed.has(boss_id):
			break
		var shard: Dictionary = chapter.get("reward_shard",{})
		result.append(String(shard.get("id","")))
	return result


func is_story_complete(completed_bosses: Array) -> bool:
	return initialized and get_restored_shard_ids(completed_bosses).size() == REQUIRED_BOSS_ORDER.size()


func localized_field(entry: Dictionary, field: String, locale: String = "en") -> String:
	if typeof(entry.get(field,{})) != TYPE_DICTIONARY:
		return ""
	var translations: Dictionary = entry.get(field,{})
	var normalized_locale := locale.to_lower().replace("_","-").get_slice("-",0)
	if not SUPPORTED_LOCALES.has(normalized_locale):
		normalized_locale = "en"
	return String(translations.get(normalized_locale,translations.get("en","")))


func _reset() -> void:
	validation_errors.clear()
	initialized = false
	_story.clear()
	_chapters_by_id.clear()
	_chapters_by_boss.clear()
	_beats_by_id.clear()
	_beat_chapter_ids.clear()


func _validate_story(candidate: Dictionary) -> void:
	if int(candidate.get("schema_version",-1)) != SCHEMA_VERSION:
		validation_errors.append("Story schema_version must be %d" % SCHEMA_VERSION)
	if String(candidate.get("story_id","")).strip_edges().is_empty():
		validation_errors.append("Story catalog requires story_id")
	if typeof(candidate.get("prologue",{})) != TYPE_DICTIONARY:
		validation_errors.append("Story catalog requires a prologue dictionary")
	else:
		_validate_prologue(candidate.get("prologue",{}))
	if typeof(candidate.get("chapters",[])) != TYPE_ARRAY:
		validation_errors.append("Story catalog requires a chapters array")
		return
	var chapters: Array = candidate.get("chapters",[])
	if chapters.size() != REQUIRED_BOSS_ORDER.size():
		validation_errors.append("Story catalog requires exactly four chapters")
	var chapter_ids: Dictionary = {}
	var shard_ids: Dictionary = {}
	var beat_ids := _prologue_beat_ids(candidate.get("prologue",{}))
	for index in chapters.size():
		var raw_chapter: Variant = chapters[index]
		if typeof(raw_chapter) != TYPE_DICTIONARY:
			validation_errors.append("Chapter %d must be a dictionary" % (index+1))
			continue
		_validate_chapter(raw_chapter as Dictionary,index,chapter_ids,shard_ids,beat_ids)


func _validate_prologue(prologue: Dictionary) -> void:
	if String(prologue.get("id","")).strip_edges().is_empty():
		validation_errors.append("Prologue requires id")
	_validate_localized_map(prologue.get("title",{}),"Prologue title")
	if typeof(prologue.get("beats",[])) != TYPE_ARRAY:
		validation_errors.append("Prologue requires beats array")
		return
	var beats: Array = prologue.get("beats",[])
	if beats.size() < 3:
		validation_errors.append("Prologue requires at least three beats")
	var local_ids: Dictionary = {}
	for raw_beat in beats:
		if typeof(raw_beat) != TYPE_DICTIONARY:
			validation_errors.append("Prologue beat must be a dictionary")
			continue
		_validate_beat(raw_beat as Dictionary,"prologue",local_ids,"Prologue")


func _validate_chapter(
	chapter: Dictionary,
	index: int,
	chapter_ids: Dictionary,
	shard_ids: Dictionary,
	beat_ids: Dictionary
) -> void:
	var label := "Chapter %d" % (index+1)
	var chapter_id := String(chapter.get("id","")).strip_edges()
	if chapter_id.is_empty() or chapter_ids.has(chapter_id):
		validation_errors.append("%s has duplicate or missing id: %s" % [label,chapter_id])
	else:
		chapter_ids[chapter_id] = true
	if int(chapter.get("order",-1)) != index+1:
		validation_errors.append("%s order must be %d" % [label,index+1])
	var boss_id := String(chapter.get("boss_id",""))
	if index >= REQUIRED_BOSS_ORDER.size() or boss_id != REQUIRED_BOSS_ORDER[index]:
		validation_errors.append("%s has invalid boss order: %s" % [label,boss_id])
	var expected_requirement := ""
	if index>0 and index-1<REQUIRED_BOSS_ORDER.size():
		expected_requirement = REQUIRED_BOSS_ORDER[index-1]
	elif index>0:
		expected_requirement = "__invalid_extra_chapter__"
	if String(chapter.get("requires_boss_id","")) != expected_requirement:
		validation_errors.append("%s has invalid unlock requirement" % label)
	_validate_localized_map(chapter.get("title",{}),"%s title" % label)
	_validate_localized_map(chapter.get("summary",{}),"%s summary" % label)
	if typeof(chapter.get("reward_shard",{})) != TYPE_DICTIONARY:
		validation_errors.append("%s requires reward_shard" % label)
	else:
		var shard: Dictionary = chapter.get("reward_shard",{})
		var shard_id := String(shard.get("id","")).strip_edges()
		if shard_id.is_empty() or shard_ids.has(shard_id):
			validation_errors.append("%s has duplicate or missing shard id: %s" % [label,shard_id])
		else:
			shard_ids[shard_id] = true
		_validate_localized_map(shard.get("name",{}),"%s shard name" % label)
	if typeof(chapter.get("beats",[])) != TYPE_ARRAY:
		validation_errors.append("%s requires beats array" % label)
		return
	var beats: Array = chapter.get("beats",[])
	if beats.size() != REQUIRED_CHAPTER_MOMENTS.size():
		validation_errors.append("%s requires exactly three beats" % label)
	for beat_index in beats.size():
		var raw_beat: Variant = beats[beat_index]
		if typeof(raw_beat) != TYPE_DICTIONARY:
			validation_errors.append("%s beat %d must be a dictionary" % [label,beat_index+1])
			continue
		var expected_moment := REQUIRED_CHAPTER_MOMENTS[beat_index] if beat_index<REQUIRED_CHAPTER_MOMENTS.size() else ""
		_validate_beat(raw_beat as Dictionary,expected_moment,beat_ids,label)


func _validate_beat(beat: Dictionary,expected_moment: String,seen_ids: Dictionary,label: String) -> void:
	var beat_id := String(beat.get("id","")).strip_edges()
	if beat_id.is_empty() or seen_ids.has(beat_id):
		validation_errors.append("%s has duplicate or missing beat id: %s" % [label,beat_id])
	else:
		seen_ids[beat_id] = true
	if String(beat.get("moment","")) != expected_moment:
		validation_errors.append("%s beat %s has invalid moment" % [label,beat_id])
	if String(beat.get("speaker","")).strip_edges().is_empty():
		validation_errors.append("%s beat %s requires speaker" % [label,beat_id])
	_validate_localized_map(beat.get("text",{}),"%s beat %s text" % [label,beat_id])


func _validate_localized_map(raw_value: Variant,label: String) -> void:
	if typeof(raw_value) != TYPE_DICTIONARY:
		validation_errors.append("%s must be localized" % label)
		return
	var values: Dictionary = raw_value
	for locale in SUPPORTED_LOCALES:
		if String(values.get(locale,"")).strip_edges().is_empty():
			validation_errors.append("%s requires %s text" % [label,locale])


func _prologue_beat_ids(raw_prologue: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw_prologue) != TYPE_DICTIONARY:
		return result
	var prologue: Dictionary = raw_prologue
	if typeof(prologue.get("beats",[])) != TYPE_ARRAY:
		return result
	for raw_beat in prologue.get("beats",[]):
		if typeof(raw_beat) == TYPE_DICTIONARY:
			var id := String((raw_beat as Dictionary).get("id","")).strip_edges()
			if not id.is_empty():
				result[id] = true
	return result


func _index_story() -> void:
	var prologue: Dictionary = _story.get("prologue",{})
	for raw_beat in prologue.get("beats",[]):
		var beat: Dictionary = raw_beat
		var beat_id := String(beat.get("id",""))
		_beats_by_id[beat_id] = beat.duplicate(true)
		_beat_chapter_ids[beat_id] = ""
	for raw_chapter in _story.get("chapters",[]):
		var chapter: Dictionary = raw_chapter
		var chapter_id := String(chapter.get("id",""))
		var boss_id := String(chapter.get("boss_id",""))
		_chapters_by_id[chapter_id] = chapter.duplicate(true)
		_chapters_by_boss[boss_id] = chapter.duplicate(true)
		for raw_beat in chapter.get("beats",[]):
			var beat: Dictionary = raw_beat
			var beat_id := String(beat.get("id",""))
			_beats_by_id[beat_id] = beat.duplicate(true)
			_beat_chapter_ids[beat_id] = chapter_id


func _normalized_completed_bosses(raw_values: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_value in raw_values:
		var boss_id := String(raw_value)
		if REQUIRED_BOSS_ORDER.has(boss_id):
			result[boss_id] = true
	return result
