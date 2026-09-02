extends Node

const StoryOverlayScene := preload("res://scenes/ui/StoryOverlay.tscn")
const StoryPrologueClass := preload("res://scripts/core/story_prologue.gd")

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("STORY OVERLAY TEST FAILURE: " + message)


func _run() -> void:
	var original_settings := SettingsManager.values.duplicate(true)
	SettingsManager.values.language = "en"
	SettingsManager.values.reduced_motion = true
	var english := StoryPrologueClass.localized("en")
	var hebrew := StoryPrologueClass.localized("he")
	_check(StoryPrologueClass.localized("he-IL") == hebrew, "Regional Hebrew locale must normalize to the optional Hebrew presentation")
	_check(StoryPrologueClass.localized("fr-FR") == english, "Unsupported locale must fall back to the English-first presentation")
	_check((english.beats as Array).size() == 4, "The prologue must contain four short English beats")
	_check((hebrew.beats as Array).size() == 4, "The prologue must contain four short Hebrew beats")
	_check(String(english.beats[0].title).contains("AION"), "The opening beat must establish that Aion was devoured")
	_check(String(hebrew.beats[1].title).contains("רציתם נצח — תרעבו לנצח"), "The Hebrew curse must preserve the approved canon")
	_check(String(english.beats[2].title) == "NO WEAPON", "The hero must begin without a weapon")
	_check(String(english.beats[3].title).contains("SPARK WAKES"), "The final beat must awaken Aion's spark")

	var overlay := StoryOverlayScene.instantiate() as StoryOverlay
	add_child(overlay)
	await get_tree().process_frame
	_check(not overlay.is_active(), "The detached story component must remain hidden until data is presented")
	var changed_ids: Array[String] = []
	var finished_events: Array[bool] = []
	var skipped_events: Array[bool] = []
	overlay.beat_changed.connect(func(_index: int, beat_id: String): changed_ids.append(beat_id))
	overlay.finished.connect(func(): finished_events.append(true))
	overlay.skipped.connect(func(): skipped_events.append(true))

	_check(overlay.present(english.beats, english.copy), "Valid externally supplied story data must open the overlay")
	_check(overlay.is_active() and overlay.current_index() == 0 and overlay.beat_count() == 4, "Present must start at the first validated beat")
	_check(overlay.current_beat_id() == "aion_devoured", "The current beat id must be queryable without exposing private data")
	_check(overlay._content.layout_direction == Control.LAYOUT_DIRECTION_LTR, "English story content must use LTR layout")
	_check(overlay.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "English narrative must align to the leading left edge")
	_check(overlay.skip_button.get_combined_minimum_size().x >= 112.0 and overlay.skip_button.get_combined_minimum_size().y >= 52.0, "Skip must keep a touch-safe hit target")
	_check(overlay.continue_button.get_combined_minimum_size().y >= 70.0, "Continue must keep a large one-thumb hit target")
	_check(overlay.pips.get_child_count() == 4, "Every beat must have one visible progress pip")
	_check(is_equal_approx(overlay.panel.position.y, 500.0) and is_equal_approx(overlay.panel.modulate.a, 1.0), "Reduced Motion must show each beat immediately without a slide or fade")
	overlay.continue_button.pressed.emit()
	_check(overlay.current_index() == 1 and overlay.title_label.text.contains("now hunger forever"), "Advance must reveal the canonical curse beat")
	while overlay.current_index() < overlay.beat_count() - 1:
		overlay.advance()
	overlay.advance()
	_check(finished_events.size() == 1 and not overlay.is_active(), "Finishing the final beat must emit once and close the overlay")
	_check(changed_ids == ["aion_devoured", "eternal_hunger", "hero_unarmed", "aion_spark"], "Beat-change events must preserve deterministic narrative order")

	SettingsManager.values.language = "he"
	_check(overlay.present(hebrew.beats, hebrew.copy), "Localized Hebrew data must reopen the same generic component")
	_check(overlay._content.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Hebrew story content must mirror to RTL")
	_check(overlay.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Hebrew narrative must align to the leading right edge")
	_check(overlay.skip_button.text == "דלג" and overlay.continue_button.text == "המשך", "Hebrew navigation copy must come from external data")
	overlay.advance()
	_check(overlay.title_label.text.contains("תרעבו לנצח"), "The displayed Hebrew curse must not fall back to English")
	overlay.skip_button.pressed.emit()
	_check(skipped_events.size() == 1 and not overlay.is_active(), "Skip must emit once and close immediately")

	var malformed: Array = [null, "bad", {}, {"title":"", "body":""}, {"body":"VALID BEAT"}]
	_check(overlay.present(malformed, {}, false), "Malformed entries must be ignored when at least one safe beat remains")
	_check(overlay.beat_count() == 1 and overlay.current_beat_id() == "beat_0", "A valid beat without an id must receive a deterministic local id")
	_check(not overlay.skip_button.visible, "The host must be able to present a non-skippable critical beat")
	overlay.skip_button.pressed.emit()
	_check(overlay.is_active() and skipped_events.size() == 1, "Programmatic skip must respect the host's allow-skip policy")
	overlay.dismiss()
	_check(not overlay.present([{}, null], {}), "An entirely invalid payload must fail closed without a visible empty panel")
	SettingsManager.values.language = "en"
	SettingsManager.values.reduced_motion = false
	_check(overlay.present(english.beats, english.copy), "The same story data must replay safely in standard-motion mode")
	_check(overlay._transition_tween != null and overlay._transition_tween.is_running() and overlay.panel.position.y > 500.0, "Standard motion may use one short bounded card entrance")
	overlay.dismiss()

	SettingsManager.values = original_settings
	overlay.queue_free()
	await get_tree().process_frame
	print("INFINIDIVE STORY OVERLAY TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
