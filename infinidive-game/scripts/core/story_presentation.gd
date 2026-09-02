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
