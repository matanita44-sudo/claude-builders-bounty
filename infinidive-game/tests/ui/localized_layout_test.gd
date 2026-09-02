extends Node

const NestViewClass := preload("res://scripts/ui/nest_view.gd")
const RunHUDClass := preload("res://scripts/ui/run_hud.gd")
const ChallengeCodeClass := preload("res://scripts/core/challenge_code.gd")

const PORTRAIT_SIZES := [Vector2i(540, 960), Vector2i(375, 667)]
const LOCALES := ["en", "he"]
const HEBREW_PLACEHOLDER_ONLY_KEYS := ["result_loadout"]
const SCREEN_TOLERANCE := 1.25
const OVERLAP_TOLERANCE := 1.0
const CRITICAL_KEYS := {
	"nest": [
		"tagline", "begin_dive", "last_nest", "nest_stage_4",
		"story_descent", "offline_footer"
	],
	"settings": [
		"settings", "settings_subtitle", "master_volume", "music_volume",
		"sfx_volume", "haptics", "screen_shake", "reduced_motion",
		"projectile_contrast", "damage_flash", "control_sensitivity",
		"assist_mode", "assist_projectile_speed", "assist_telegraph",
		"assist_dash_window", "aim_assist", "analytics_opt_in", "dash_method",
		"handedness", "language", "tutorial_replay", "support_feedback",
		"privacy_policy", "reset_progress"
	],
	"tutorial": ["tutorial.enter_breach", "phase_dash", "dive_locked"],
	"organ": [
		"organ_order_eyebrow", "organ_choice_title", "organ_choice_body",
		"organ_scan"
	],
	"mutation": [
		"mutation_eyebrow", "mutation_choice_title", "synergy_detail", "rare",
		"reroll_left"
	],
	"pause": ["dive_paused", "pause_body", "resume", "abandon_to_nest"],
	"result": [
		"diver_lost", "nest_remembers", "killed_by", "score_value",
		"result_loadout", "result_organs_destroyed", "result_mutations",
		"result_metrics", "friend_target_missed", "dive_again", "share_rift",
		"friend_share_unavailable", "return_to_nest"
	],
	"result_card": [
		"friend_result_card", "colossus_collapsed", "score_value",
		"result_loadout", "result_card_metrics", "result_organs_destroyed",
		"result_mutations", "challenge_code_label", "local_result_unverified",
		"dive_again", "return_to_nest"
	],
}

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("LOCALIZED LAYOUT TEST FAILURE: " + message)


func _run() -> void:
	await get_tree().process_frame
	var original_profile := SaveManager.profile.duplicate(true)
	var original_settings := SettingsManager.values.duplicate(true)
	var baseline := SaveManager.default_profile()
	baseline.nest_stage = 4
	baseline.abyss_unlocked = true
	baseline.unlocked_bosses = ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]
	baseline.unlocked_weapons = ["pulse_needle", "scatter_maw", "rail_spine", "arc_swarm", "void_orbitals"]
	baseline.bio_matter = 12345
	baseline.core_shards = 88

	for locale_value in LOCALES:
		var locale := String(locale_value)
		SettingsManager.values = baseline.settings.duplicate(true)
		SettingsManager.values.language = locale
		_assert_localization_catalog(locale)
		for size_value in PORTRAIT_SIZES:
			var logical_size := Vector2i(size_value)
			SaveManager.profile = baseline.duplicate(true)
			SettingsManager.values = baseline.settings.duplicate(true)
			SettingsManager.values.language = locale
			await _test_nest(locale, logical_size)
			await _test_settings(locale, logical_size)
			await _test_hud_scenario("tutorial", locale, logical_size)
			await _test_hud_scenario("organ", locale, logical_size)
			await _test_hud_scenario("mutation", locale, logical_size)
			await _test_hud_scenario("pause", locale, logical_size)
			await _test_hud_scenario("result", locale, logical_size)
			await _test_hud_scenario("result_card", locale, logical_size)

	SaveManager.profile = original_profile
	SettingsManager.values = original_settings
	SettingsManager.apply_all()
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	print("INFINIDIVE LOCALIZED LAYOUT TESTS: %d passed, %d failed" % [passed, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _assert_localization_catalog(locale: String) -> void:
	var locale_table: Dictionary = LocalizationService.STRINGS.get(locale, {})
	for scenario_value in CRITICAL_KEYS:
		var scenario := String(scenario_value)
		for key_value in CRITICAL_KEYS[scenario]:
			var key := String(key_value)
			var label := "%s/%s localization %s" % [locale, scenario, key]
			_check(locale_table.has(key), label + " must exist")
			if not locale_table.has(key):
				continue
			var value := String(locale_table[key]).strip_edges()
			_check(not value.is_empty() and value != key, label + " must not be blank or fall back to its key")
			if locale == "he" and key not in HEBREW_PLACEHOLDER_ONLY_KEYS:
				_check(_contains_hebrew(value), label + " must contain Hebrew copy")
	_assert_localized_content(locale)


func _assert_localized_content(locale: String) -> void:
	var boss := GameData.get_boss("gravemaw")
	var english_boss := String(boss.get("name", ""))
	var localized_boss := LocalizationService.content_text("boss", "gravemaw", "name", english_boss)
	_check(not localized_boss.strip_edges().is_empty(), "%s boss content must not be blank" % locale)
	var weapon := GameData.get_weapon("pulse_needle")
	var english_weapon := String(weapon.get("name", ""))
	var localized_weapon := LocalizationService.content_text("weapon", "pulse_needle", "name", english_weapon)
	_check(not localized_weapon.strip_edges().is_empty(), "%s weapon content must not be blank" % locale)
	for raw_organ in boss.get("organs", []):
		var organ := raw_organ as Dictionary
		var organ_id := String(organ.get("id", ""))
		var localized_name := LocalizationService.content_text("organ", organ_id, "name", String(organ.get("name", "")))
		var localized_effect := LocalizationService.content_text("organ", organ_id, "effect", String(organ.get("effect", "")))
		_check(not localized_name.strip_edges().is_empty(), "%s organ %s name must not be blank" % [locale, organ_id])
		_check(not localized_effect.strip_edges().is_empty(), "%s organ %s effect must not be blank" % [locale, organ_id])
		if locale == "he":
			_check(_contains_hebrew(localized_name) and _contains_hebrew(localized_effect), "Hebrew organ %s content must not fall back to English" % organ_id)
	for mutation_id_value in ["split_chamber", "phase_wake", "hungry_orbit"]:
		var mutation_id := String(mutation_id_value)
		var mutation := GameData.get_mutation(mutation_id)
		var localized_name := LocalizationService.content_text("mutation", mutation_id, "name", String(mutation.get("name", "")))
		var localized_description := LocalizationService.content_text("mutation", mutation_id, "description", String(mutation.get("description", "")))
		_check(not localized_name.strip_edges().is_empty(), "%s mutation %s name must not be blank" % [locale, mutation_id])
		_check(not localized_description.strip_edges().is_empty(), "%s mutation %s description must not be blank" % [locale, mutation_id])
		if locale == "he":
			_check(_contains_hebrew(localized_name) and _contains_hebrew(localized_description), "Hebrew mutation %s content must not fall back to English" % mutation_id)
	if locale == "he":
		_check(_contains_hebrew(localized_boss), "Hebrew boss name must not fall back to English")
		_check(_contains_hebrew(localized_weapon), "Hebrew weapon name must not fall back to English")


func _test_nest(locale: String, logical_size: Vector2i) -> void:
	var viewport := _make_viewport(logical_size)
	var nest := NestViewClass.new()
	viewport.add_child(nest)
	await _settle_layout()
	nest.set_process(false)
	var context := _context("nest", locale, logical_size)
	_check(nest.size.is_equal_approx(Vector2(540, 960)), context + " must retain the authored design canvas")
	_check(_expected_root_scale(logical_size).is_equal_approx(nest.scale), context + " must fit the design canvas without cropping")
	_check(nest._tagline.horizontal_alignment == _expected_alignment(locale), context + " tagline must align to the locale start edge")
	_check(nest._mode_label.horizontal_alignment == _expected_alignment(locale), context + " mode label must align to the locale start edge")
	_check(nest._tagline.layout_direction == _expected_direction(locale), context + " tagline must use the locale direction")
	var settings_button := nest.get_node_or_null("SettingsButton") as Button
	_check(settings_button != null, context + " must expose a semantic Settings button")
	if settings_button != null:
		_check(settings_button.text == "⚙", context + " Settings must use the recognizable gear glyph instead of an unexplained abbreviation")
		_check(settings_button.tooltip_text == LocalizationService.text("settings"), context + " Settings glyph must expose a localized tooltip")
		_check(settings_button.accessibility_name == LocalizationService.text("settings"), context + " Settings glyph must expose a localized accessibility name")
	var boss_card := nest.get_node_or_null("BossCard") as PanelContainer
	var boss_portrait := nest.find_child("BossPortrait", true, false) as TextureRect
	_check(boss_card != null and boss_portrait != null, context + " boss selection must include a real Titan portrait")
	if boss_card != null and boss_portrait != null:
		_check(boss_portrait.texture is AtlasTexture, context + " boss portrait must use the authored Titan bust crop")
		_check(boss_portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, context + " Titan bust must fill its portrait frame without distortion")
		_check(_rect_inside(_screen_rect(boss_portrait), _screen_rect(boss_card)), context + " Titan portrait must stay inside the compact boss card")
		var boss_ids := _baseline_boss_ids()
		for boss_index in range(boss_ids.size()):
			var boss_id := boss_ids[boss_index]
			nest._boss_index = boss_index
			nest._refresh_boss()
			var bust := boss_portrait.texture as AtlasTexture
			_check(bust != null and bust.atlas == NestViewClass.TITAN_PORTRAITS[boss_id], context + " %s must use its matching authored Titan art" % boss_id)
			_check(bust != null and bust.region.size.y < bust.atlas.get_height(), context + " %s portrait must use the compact bust crop" % boss_id)
	var gradient := nest._sky_gradient_for(4)
	_check(gradient != null and gradient.width == 540 and gradient.height == 446, context + " sky must use the full-resolution smooth gradient texture")
	_check(nest._sky_gradient_for(4) == gradient, context + " sky gradient must be cached instead of allocated every animation frame")
	for facility_value in NestViewClass.FACILITIES:
		var facility := facility_value as Dictionary
		var facility_id := String(facility.get("id", ""))
		var facility_button := nest.get_node_or_null("Facility_%s" % facility_id) as Button
		var chip := nest.get_node_or_null("Facility_%s/FacilityCaptionChip_%s" % [facility_id,facility_id]) as PanelContainer
		var caption := nest.get_node_or_null("Facility_%s/FacilityCaptionChip_%s/FacilityCaption_%s" % [facility_id,facility_id,facility_id]) as Label
		_check(facility_button != null and chip != null and caption != null, context + " %s must expose a dedicated caption chip" % facility_id)
		if facility_button != null and chip != null and caption != null:
			_check(chip.position.y >= 68.0, context + " %s caption chip must begin below its facility silhouette" % facility_id)
			var chip_style := chip.get_theme_stylebox("panel") as StyleBoxFlat
			_check(chip_style != null and chip_style.bg_color.a >= 0.85, context + " %s caption chip must retain an opaque readable background" % facility_id)
			_check(caption.text == LocalizationService.text(String(facility.get("key", ""))), context + " %s caption must use localized copy" % facility_id)
			_check(_rect_inside(_screen_rect(caption), _screen_rect(chip)), context + " %s caption must stay inside its chip" % facility_id)
	_assert_surface_geometry(nest, viewport, context)
	await _destroy_viewport(viewport)


func _baseline_boss_ids() -> Array[String]:
	return ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]


func _test_settings(locale: String, logical_size: Vector2i) -> void:
	var viewport := _make_viewport(logical_size)
	var nest := NestViewClass.new()
	viewport.add_child(nest)
	await _settle_layout()
	nest.set_process(false)
	nest._show_settings()
	await _settle_layout()
	var context := _context("settings", locale, logical_size)
	_check(nest._overlay.visible, context + " overlay must be visible")
	var content := nest._overlay.get_child(0) as Control if nest._overlay.get_child_count() == 1 else null
	_check(content != null, context + " must expose one settings content root")
	if content != null:
		_check(content.layout_direction == _expected_direction(locale), context + " content must use the locale direction")
		_assert_leading_copy(content, locale, context)
	# The settings panel is modal. Background Nest controls remain drawn, but the
	# panel intercepts them; overlap checks therefore operate on the active layer.
	_assert_surface_geometry(nest._overlay, viewport, context)
	await _assert_scroll_actions_reachable(nest._overlay, viewport, context)
	await _destroy_viewport(viewport)


func _test_hud_scenario(scenario: String, locale: String, logical_size: Vector2i) -> void:
	var viewport := _make_viewport(logical_size)
	var hud := RunHUDClass.new()
	viewport.add_child(hud)
	await _settle_layout()
	match scenario:
		"tutorial":
			hud.set_tutorial_prompt(LocalizationService.text("tutorial.enter_breach"))
		"organ":
			var organs := (GameData.get_boss("gravemaw").get("organs", []) as Array).duplicate(true)
			hud.show_organ_choices(organs, 1)
		"mutation":
			var mutations: Array = []
			for mutation_id_value in ["split_chamber", "phase_wake", "hungry_orbit"]:
				var mutation := GameData.get_mutation(String(mutation_id_value))
				mutation["_synergy"] = true
				mutation["_synergy_detail"] = "projectile_count"
				mutations.append(mutation)
			hud.show_mutation_choices(mutations, 2)
		"pause":
			hud.show_pause()
		"result":
			hud.show_result(_result_payload(false))
		"result_card":
			var result := _result_payload(true)
			var code := ChallengeCodeClass.encode({
				"boss": result.boss_id,
				"seed": result.seed,
				"weapon": result.weapon,
				"difficulty": result.difficulty,
				"modifiers": result.modifiers,
				"target_score": result.score,
				"target_time_ms": int(float(result.elapsed) * 1000.0),
			})
			_check(hud.show_share_card(result, code, "AION DIVER"), _context(scenario, locale, logical_size) + " must accept the exact run-bound Friend Rift code")
	await _settle_layout()
	var context := _context(scenario, locale, logical_size)
	_check(_expected_root_scale(logical_size).is_equal_approx(hud.root.scale), context + " must fit the design canvas without cropping")
	if scenario == "tutorial":
		_check(hud.toast_label.text == LocalizationService.text("tutorial.enter_breach"), context + " prompt must use localized copy")
		_check(hud.toast_label.layout_direction == _expected_direction(locale), context + " prompt must use the locale direction")
		_check(is_equal_approx(hud.toast_label.modulate.a, 1.0), context + " prompt must be visibly presented")
	else:
		_check(hud.overlay.visible, context + " decision overlay must be visible")
		var content := hud.overlay.get_child(0) as Control if hud.overlay.get_child_count() == 1 else null
		_check(content != null, context + " must expose one decision content root")
		if content != null:
			_check(content.layout_direction == _expected_direction(locale), context + " content must use the locale direction")
			_assert_leading_copy(content, locale, context)
		if scenario == "result_card":
			var card_content := hud.overlay.find_child("ResultCardContent", true, false) as Control
			_check(card_content != null, context + " must render the Friend Rift ResultCard")
			if card_content != null:
				_check(card_content.layout_direction == _expected_direction(locale), context + " card must use the locale direction")
	# Decision overlays are modal over combat. Check the active decision layer so
	# fixed combat buttons behind it are not mistaken for simultaneous actions.
	_assert_surface_geometry(hud.root if scenario == "tutorial" else hud.overlay, viewport, context)
	await _destroy_viewport(viewport)


func _result_payload(won: bool) -> Dictionary:
	return {
		"won": won,
		"cause": "ability:gravity_ring",
		"score": 98765,
		"segment_score": 98765,
		"abyss_score": 0,
		"mode": "friend",
		"boss_id": "gravemaw",
		"weapon": "pulse_needle",
		"seed": 112233,
		"difficulty": "deep",
		"modifiers": ["mirror_projectiles"],
		"destroyed_organs": ["hunter_eye", "gravity_lung", "bone_forge"],
		"mutations": ["split_chamber", "phase_wake", "hungry_orbit", "needle_through_bone"],
		"time_text": "02:05",
		"elapsed": 125.432,
		"abyss_depth": 0,
		"banked_bio": 456,
		"challenge_has_target": true,
		"challenge_target_met": false,
	}


func _make_viewport(logical_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "LayoutViewport_%dx%d" % [logical_size.x, logical_size.y]
	viewport.size = logical_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	viewport.transparent_bg = true
	add_child(viewport)
	return viewport


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _destroy_viewport(viewport: SubViewport) -> void:
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _assert_surface_geometry(surface: Node, viewport: SubViewport, context: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var labels := _visible_labels(surface)
	_check(not labels.is_empty(), context + " must expose visible labels")
	for label in labels:
		var rect := _screen_rect(label)
		_check(rect.size.x > 0.5 and rect.size.y > 0.5, context + " label %s must have nonzero rendered size" % _node_path(label, surface))
		_check(not label.text.strip_edges().is_empty(), context + " visible label %s must not be blank" % _node_path(label, surface))

	var actions := _visible_actions(surface)
	_check(not actions.is_empty(), context + " must expose at least one actionable control")
	var fully_visible_actions: Array[Control] = []
	for action in actions:
		var scroll := _scroll_ancestor(action, surface)
		var action_rect := _screen_rect(action)
		var minimum := action.get_combined_minimum_size()
		_check(action.size.x + SCREEN_TOLERANCE >= minimum.x and action.size.y + SCREEN_TOLERANCE >= minimum.y, context + " action %s must not be smaller than its content minimum" % _node_path(action, surface))
		if scroll == null:
			_check(_rect_inside(action_rect, bounds), context + " action %s must stay fully on-screen: %s" % [_node_path(action, surface), str(action_rect)])
			if _rect_inside(action_rect, bounds):
				fully_visible_actions.append(action)
		elif _rect_inside(action_rect, _screen_rect(scroll)) and _rect_inside(action_rect, bounds):
			fully_visible_actions.append(action)
	_assert_no_action_overlap(fully_visible_actions, surface, context)


func _assert_scroll_actions_reachable(surface: Node, viewport: SubViewport, context: String) -> void:
	var screen_bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	for action in _visible_actions(surface):
		var scroll := _scroll_ancestor(action, surface)
		if scroll == null:
			continue
		scroll.ensure_control_visible(action)
		await _settle_layout()
		var action_rect := _screen_rect(action)
		var visible_bounds := _screen_rect(scroll).intersection(screen_bounds)
		_check(_rect_inside(action_rect, visible_bounds), context + " scroll action %s must become fully visible when requested" % _node_path(action, surface))


func _assert_no_action_overlap(actions: Array[Control], surface: Node, context: String) -> void:
	for first_index in range(actions.size()):
		for second_index in range(first_index + 1, actions.size()):
			var first := actions[first_index]
			var second := actions[second_index]
			if first.is_ancestor_of(second) or second.is_ancestor_of(first):
				continue
			var intersection := _screen_rect(first).intersection(_screen_rect(second))
			_check(intersection.size.x <= OVERLAP_TOLERANCE or intersection.size.y <= OVERLAP_TOLERANCE, context + " critical actions %s and %s must not overlap" % [_node_path(first, surface), _node_path(second, surface)])


func _assert_leading_copy(content: Node, locale: String, context: String) -> void:
	var expected_alignment := _expected_alignment(locale)
	var checked := 0
	for node in _descendants(content):
		if not node.is_visible_in_tree():
			continue
		if node is Label:
			var label := node as Label
			if label.text.strip_edges().is_empty() or label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				continue
			checked += 1
			_check(label.horizontal_alignment == expected_alignment, context + " label %s must align to the locale start edge" % _node_path(label, content))
		elif node is Button and not node is OptionButton and not node is CheckButton:
			var button := node as Button
			if button.text.strip_edges().is_empty() or button.alignment == HORIZONTAL_ALIGNMENT_CENTER:
				continue
			checked += 1
			_check(button.alignment == expected_alignment, context + " button %s must align to the locale start edge" % _node_path(button, content))
	_check(checked > 0, context + " must expose locale-leading copy for RTL/LTR verification")


func _visible_labels(root_node: Node) -> Array[Label]:
	var result: Array[Label] = []
	for node in _descendants(root_node):
		if node is Label and node.is_visible_in_tree() and not (node as Label).text.strip_edges().is_empty():
			result.append(node as Label)
	return result


func _visible_actions(root_node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for node in _descendants(root_node):
		if not node is Control or not node.is_visible_in_tree():
			continue
		var control := node as Control
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control is ScrollBar:
			continue
		if control is BaseButton:
			if (control as BaseButton).disabled:
				continue
			result.append(control)
		elif control is Slider or control is LineEdit or control is TextEdit:
			result.append(control)
	return result


func _descendants(root_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = []
	for child in root_node.get_children():
		pending.append(child)
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		result.append(node)
		for child in node.get_children():
			pending.append(child)
	return result


func _scroll_ancestor(control: Control, stop_at: Node) -> ScrollContainer:
	var cursor := control.get_parent()
	while cursor != null and cursor != stop_at:
		if cursor is ScrollContainer:
			return cursor as ScrollContainer
		cursor = cursor.get_parent()
	return null


func _screen_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner_value in corners:
		var corner := Vector2(corner_value)
		minimum.x = minf(minimum.x, corner.x)
		minimum.y = minf(minimum.y, corner.y)
		maximum.x = maxf(maximum.x, corner.x)
		maximum.y = maxf(maximum.y, corner.y)
	return Rect2(minimum, maximum - minimum)


func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - SCREEN_TOLERANCE
		and inner.position.y >= outer.position.y - SCREEN_TOLERANCE
		and inner.end.x <= outer.end.x + SCREEN_TOLERANCE
		and inner.end.y <= outer.end.y + SCREEN_TOLERANCE
		and inner.size.x > 0.5
		and inner.size.y > 0.5
	)


func _expected_root_scale(logical_size: Vector2i) -> Vector2:
	var scale_value := minf(1.0, minf(float(logical_size.x) / 540.0, float(logical_size.y) / 960.0))
	return Vector2.ONE * scale_value


func _expected_direction(locale: String) -> Control.LayoutDirection:
	return Control.LAYOUT_DIRECTION_RTL if locale == "he" else Control.LAYOUT_DIRECTION_LTR


func _expected_alignment(locale: String) -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_RIGHT if locale == "he" else HORIZONTAL_ALIGNMENT_LEFT


func _contains_hebrew(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint >= 0x0590 and codepoint <= 0x05FF:
			return true
	return false


func _context(scenario: String, locale: String, logical_size: Vector2i) -> String:
	return "%s/%s/%dx%d" % [scenario, locale, logical_size.x, logical_size.y]


func _node_path(node: Node, root_node: Node) -> String:
	return String(root_node.get_path_to(node))
