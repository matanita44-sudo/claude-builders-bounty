class_name StoryPresentation
extends RefCounted

## Adapts the data-only story catalog to the generic StoryOverlay contract.
## Keeping this outside Main prevents narrative copy, localization and visual
## choices from leaking into scene-transition code.

const CHAPTER_ACCENTS := {
	"gravemaw": "#D8A533",
	"seraph_9": "#F1BE48",
	"abyss_leviathan": "#2CB8BC",
	"null_twin": "#9B78C6",
}
const STORY_STATE_PROFILE_KEY := "story_state"
const STORY_STATE_VERSION := 1


static func chapter_intro(service: StoryService, chapter: Dictionary, locale: String) -> Dictionary:
	if service == null or chapter.is_empty():
		return {}
	var beat := _beat_for_moment(chapter,"chapter_intro")
	if beat.is_empty():
		return {}
	var is_hebrew := _normalized_locale(locale) == "he"
	var order := maxi(1,int(chapter.get("order",1)))
	return {
		"beats": [{
			"id": String(beat.get("id","chapter_intro")),
			"eyebrow": ("פרק %d" if is_hebrew else "CHAPTER %d") % order,
			"title": service.localized_field(chapter,"title",locale),
			"body": service.localized_field(beat,"text",locale),
			"symbol": "titan",
			"accent": _accent_for_chapter(chapter),
		}],
		"copy": {
			"skip": "דלג" if is_hebrew else "SKIP",
			"continue": "המשך" if is_hebrew else "CONTINUE",
			"finish": "התייצב מול הטיטאן" if is_hebrew else "FACE THE TITAN",
			"progress": "{current} / {total}",
		},
	}


static func chapter_breach(service: StoryService, chapter: Dictionary, locale: String) -> Dictionary:
	if service == null or chapter.is_empty():
		return {}
	var beat := _beat_for_moment(chapter,"first_breach")
	if beat.is_empty():
		return {}
	var is_hebrew := _normalized_locale(locale) == "he"
	return {
		"beats": [{
			"id": String(beat.get("id","chapter_breach")),
			"speaker": String(beat.get("speaker","AION")),
			"eyebrow": "איון · הפרצה פתוחה" if is_hebrew else "AION · BREACH OPEN",
			"title": service.localized_field(chapter,"title",locale),
			"body": service.localized_field(beat,"text",locale),
			"symbol": "breach",
			"accent": _accent_for_chapter(chapter),
		}],
		"copy": {
			"skip": "דלג" if is_hebrew else "SKIP",
			"continue": "המשך" if is_hebrew else "CONTINUE",
			"finish": "צלול" if is_hebrew else "DIVE",
			"progress": "{current} / {total}",
		},
	}


static func presented_ledger_is_valid(profile: Dictionary) -> bool:
	if not profile.has(STORY_STATE_PROFILE_KEY):
		return true
	var raw_state: Variant = profile.get(STORY_STATE_PROFILE_KEY,{})
	if typeof(raw_state) != TYPE_DICTIONARY:
		return false
	var story_state := raw_state as Dictionary
	var raw_version: Variant = story_state.get("version",null)
	if typeof(raw_version) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw_version)) or float(raw_version) != floor(float(raw_version)) or int(raw_version) != STORY_STATE_VERSION:
		return false
	var raw_ledger: Variant = story_state.get("presented_beat_ids",null)
	if typeof(raw_ledger) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for raw_id in raw_ledger as Array:
		if typeof(raw_id) != TYPE_STRING:
			return false
		var beat_id := String(raw_id).strip_edges()
		if beat_id.is_empty() or beat_id.length() > 64 or seen.has(beat_id):
			return false
		seen[beat_id] = true
	return true


static func presented_beat_ids(profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not presented_ledger_is_valid(profile):
		return result
	var story_state: Dictionary = profile.get(STORY_STATE_PROFILE_KEY,{})
	for raw_id in story_state.get("presented_beat_ids",[]):
		result.append(String(raw_id))
	return result


static func has_presented_beat(profile: Dictionary, beat_id: String) -> bool:
	return not beat_id.is_empty() and presented_beat_ids(profile).has(beat_id)


static func chapter_victory(service: StoryService, chapter: Dictionary, locale: String) -> Dictionary:
	if service == null or chapter.is_empty():
		return {}
	var beat := _beat_for_moment(chapter,"boss_defeated")
	var shard: Dictionary = chapter.get("reward_shard",{})
	if beat.is_empty() or shard.is_empty():
		return {}
	var is_hebrew := _normalized_locale(locale) == "he"
	return {
		"beats": [{
			"id": String(beat.get("id","chapter_victory")),
			"eyebrow": "שבר איון הושב" if is_hebrew else "AION SHARD RESTORED",
			"title": service.localized_field(shard,"name",locale),
			"body": service.localized_field(beat,"text",locale),
			"symbol": "shard",
			"accent": _accent_for_chapter(chapter),
		}],
		"copy": {
			"skip": "דלג" if is_hebrew else "SKIP",
			"continue": "המשך" if is_hebrew else "CONTINUE",
			"finish": "חזור לקן האחרון" if is_hebrew else "RETURN TO THE NEST",
			"progress": "{current} / {total}",
		},
	}


static func _beat_for_moment(chapter: Dictionary, moment: String) -> Dictionary:
	for raw_beat in chapter.get("beats",[]):
		if typeof(raw_beat) != TYPE_DICTIONARY:
			continue
		var beat: Dictionary = raw_beat
		if String(beat.get("moment","")) == moment:
			return beat.duplicate(true)
	return {}


static func _accent_for_chapter(chapter: Dictionary) -> String:
	return String(CHAPTER_ACCENTS.get(String(chapter.get("boss_id","")),"#C88936"))


static func _normalized_locale(locale: String) -> String:
	return locale.to_lower().replace("_","-").get_slice("-",0)
