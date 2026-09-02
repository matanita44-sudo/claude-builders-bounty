class_name StoryOverlay
extends CanvasLayer

const SafeAreaHelperScript := preload("res://scripts/ui/safe_area_helper.gd")
const DESIGN_SIZE := Vector2(540.0, 960.0)
const INK := Color("#17324B")
const MARBLE := Color("#F6EEDB")
const BRONZE := Color("#C88936")
const DEFAULT_COPY := {
	"skip": "SKIP",
	"continue": "CONTINUE",
	"finish": "BEGIN",
	"progress": "{current} / {total}",
}

signal beat_changed(index: int, beat_id: String)
signal finished
signal skipped


class StoryBackdrop:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sky_top := Color("#78D5E1")
		var sky_bottom := Color("#E6F2D4")
		for band_index in range(16):
			var band_ratio := float(band_index) / 15.0
			var band_y := size.y * band_ratio
			var band_height := size.y / 15.0 + 1.0
			draw_rect(Rect2(0.0, band_y, size.x, band_height), sky_top.lerp(sky_bottom, band_ratio))
		var sun := Vector2(size.x - 76.0, 126.0)
		draw_circle(sun, 67.0, Color(1.0, 0.9, 0.48, 0.16))
		draw_circle(sun, 43.0, Color("#FFE98A"))
		for cloud in [
			[Vector2(72, 164), 34.0], [Vector2(111, 158), 48.0], [Vector2(153, 170), 30.0],
			[Vector2(370, 257), 29.0], [Vector2(407, 249), 43.0], [Vector2(448, 260), 27.0],
		]:
			draw_circle(cloud[0], cloud[1], Color(1.0, 1.0, 0.95, 0.62))
		var horizon_y := size.y * 0.49
		draw_colored_polygon(PackedVector2Array([
			Vector2(-30.0, horizon_y + 52.0), Vector2(118.0, horizon_y - 22.0),
			Vector2(228.0, horizon_y + 46.0), Vector2(164.0, horizon_y + 94.0),
			Vector2(42.0, horizon_y + 94.0),
		]), Color("#88B99A"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(322.0, horizon_y + 72.0), Vector2(432.0, horizon_y + 2.0),
			Vector2(578.0, horizon_y + 54.0), Vector2(540.0, horizon_y + 102.0),
			Vector2(360.0, horizon_y + 105.0),
		]), Color("#75A98D"))
		for column_x in [58.0, 91.0, 449.0, 482.0]:
			draw_rect(Rect2(column_x, horizon_y - 22.0, 13.0, 106.0), Color("#E9E5CE"))
			draw_rect(Rect2(column_x - 5.0, horizon_y - 28.0, 23.0, 8.0), Color("#C88936"))


class StorySigil:
	extends Control

	var accent := BRONZE
	var symbol := "spark"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_beat_symbol(value: String, color: Color) -> void:
		symbol = value
		accent = color
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 72.0, Color(MARBLE, 0.88))
		draw_arc(center, 73.0, 0.0, TAU, 72, Color(BRONZE, 0.76), 4.0, true)
		draw_arc(center, 58.0, 0.0, TAU, 72, Color(accent, 0.34), 2.0, true)
		match symbol:
			"devoured":
				draw_arc(center, 38.0, PI * 0.18, TAU - PI * 0.18, 42, accent, 8.0, true)
				for tooth_y in [-18.0, 0.0, 18.0]:
					draw_colored_polygon(PackedVector2Array([
						center + Vector2(26.0, tooth_y - 6.0),
						center + Vector2(44.0, tooth_y),
						center + Vector2(26.0, tooth_y + 6.0),
					]), Color("#F6EEDB"))
			"curse":
				for ray_index in range(8):
					var direction := Vector2.from_angle(float(ray_index) * TAU / 8.0)
					draw_line(center + direction * 22.0, center + direction * 47.0, accent, 5.0, true)
				draw_circle(center, 14.0, accent)
			"unarmed":
				draw_arc(center + Vector2(-17.0, 0.0), 24.0, PI * 0.45, PI * 1.55, 24, accent, 7.0, true)
				draw_arc(center + Vector2(17.0, 0.0), 24.0, -PI * 0.55, PI * 0.55, 24, accent, 7.0, true)
				draw_line(center + Vector2(-5.0, -29.0), center + Vector2(5.0, -13.0), Color(BRONZE, 0.86), 4.0, true)
				draw_line(center + Vector2(-5.0, 13.0), center + Vector2(5.0, 29.0), Color(BRONZE, 0.86), 4.0, true)
			_:
				var points := PackedVector2Array()
				for point_index in range(16):
					var radius := 43.0 if point_index % 2 == 0 else 17.0
					points.append(center + Vector2.from_angle(-PI * 0.5 + float(point_index) * TAU / 16.0) * radius)
				draw_colored_polygon(points, accent)
				draw_circle(center, 8.0, Color("#FFF5B8"))


var root: Control
var backdrop: StoryBackdrop
var panel: PanelContainer
var sigil: StorySigil
var skip_button: Button
var continue_button: Button
var progress_label: Label
var eyebrow_label: Label
var title_label: Label
var body_label: Label
var pips: HBoxContainer
var _content: VBoxContainer
var _beats: Array[Dictionary] = []
var _copy := DEFAULT_COPY.duplicate(true)
var _index := -1
var _transition_tween: Tween


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_apply_safe_layout)
	LocalizationService.locale_changed.connect(_on_locale_changed)
	_apply_safe_layout()
	set_process_unhandled_input(false)


func present(story_beats: Array, localized_copy: Dictionary = {}, allow_skip: bool = true) -> bool:
	_beats.clear()
	for raw_beat in story_beats:
		if typeof(raw_beat) != TYPE_DICTIONARY:
			continue
		var beat := (raw_beat as Dictionary).duplicate(true)
		beat.eyebrow = _bounded_text(beat.get("eyebrow", ""), 72)
		beat.title = _bounded_text(beat.get("title", ""), 120)
		beat.body = _bounded_text(beat.get("body", ""), 280)
		beat.symbol = _bounded_text(beat.get("symbol", "spark"), 24)
		if String(beat.title).is_empty() and String(beat.body).is_empty():
			continue
		beat.id = _bounded_text(beat.get("id", ""), 64)
		if String(beat.id).is_empty():
			beat.id = "beat_%d" % _beats.size()
		_beats.append(beat)
	if _beats.is_empty():
		dismiss()
		return false

	_copy = DEFAULT_COPY.duplicate(true)
	for key in DEFAULT_COPY:
		var supplied: Variant = localized_copy.get(key, null)
		if typeof(supplied) == TYPE_STRING and not String(supplied).strip_edges().is_empty():
			_copy[key] = _bounded_text(supplied, 48)
	_index = 0
	skip_button.visible = allow_skip
	_apply_layout_direction()
	_rebuild_pips()
	root.visible = true
	set_process_unhandled_input(true)
	_render_beat(true)
	return true


func advance() -> void:
	if not is_active():
		return
	if _index >= _beats.size() - 1:
		_close()
		finished.emit()
		return
	_index += 1
	_render_beat(true)


func skip() -> void:
	if not is_active() or not skip_button.visible:
		return
	_close()
	skipped.emit()


func dismiss() -> void:
	_close()
	_beats.clear()
	_index = -1


func is_active() -> bool:
	return is_instance_valid(root) and root.visible and _index >= 0 and _index < _beats.size()


func current_index() -> int:
	return _index


func beat_count() -> int:
	return _beats.size()


func current_beat_id() -> String:
	return String(_beats[_index].get("id", "")) if is_active() else ""


func _build() -> void:
	root = Control.new()
	root.name = "StorySafeRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.visible = false
	add_child(root)

	backdrop = StoryBackdrop.new()
	backdrop.name = "StoryBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = DESIGN_SIZE
	# The backdrop owns unused screen space, so taps cannot leak through to the
	# visible Nest. Story buttons are later siblings and retain first pick order.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(20, 20)
	top_bar.size = Vector2(500, 76)
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color(MARBLE, 0.92), BRONZE, 22, 10))
	root.add_child(top_bar)
	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_line)
	progress_label = _label("1 / 1", 14, INK)
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.custom_minimum_size.x = 88
	top_line.add_child(progress_label)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(top_spacer)
	skip_button = Button.new()
	skip_button.name = "StorySkip"
	skip_button.custom_minimum_size = Vector2(112, 52)
	skip_button.add_theme_font_size_override("font_size", 14)
	_apply_button_style(skip_button, BRONZE, false)
	skip_button.pressed.connect(skip)
	top_line.add_child(skip_button)

	sigil = StorySigil.new()
	sigil.name = "StorySigil"
	sigil.position = Vector2(180, 238)
	sigil.size = Vector2(180, 180)
	root.add_child(sigil)

	panel = PanelContainer.new()
	panel.name = "StoryCard"
	panel.position = Vector2(20, 500)
	panel.size = Vector2(500, 420)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(MARBLE, 0.98), BRONZE, 28, 18))
	root.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	panel.add_child(_content)
	pips = HBoxContainer.new()
	pips.name = "StoryProgressPips"
	pips.add_theme_constant_override("separation", 7)
	_content.add_child(pips)
	eyebrow_label = _label("", 13, Color("#87591E"))
	eyebrow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(eyebrow_label)
	title_label = _label("", 31, INK)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.y = 82
	_content.add_child(title_label)
	body_label = _label("", 18, Color(INK, 0.78))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size.y = 78
	_content.add_child(body_label)
	var content_spacer := Control.new()
	content_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(content_spacer)
	continue_button = Button.new()
	continue_button.name = "StoryContinue"
	continue_button.custom_minimum_size.y = 70
	continue_button.add_theme_font_size_override("font_size", 16)
	continue_button.pressed.connect(advance)
	_content.add_child(continue_button)


func _render_beat(animate: bool) -> void:
	var beat := _beats[_index]
	var accent := _accent_color(beat.get("accent", BRONZE))
	eyebrow_label.text = String(beat.get("eyebrow", ""))
	eyebrow_label.add_theme_color_override("font_color", accent.darkened(0.3))
	title_label.text = String(beat.get("title", ""))
	body_label.text = String(beat.get("body", ""))
	sigil.set_beat_symbol(String(beat.get("symbol", "spark")), accent)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(MARBLE, 0.98), accent, 28, 18))
	_apply_button_style(continue_button, accent, true)
	continue_button.text = String(_copy.finish if _index == _beats.size() - 1 else _copy.continue)
	skip_button.text = String(_copy.skip)
	var progress_text := String(_copy.progress)
	progress_label.text = progress_text.replace("{current}", str(_index + 1)).replace("{total}", str(_beats.size()))
	_update_pips(accent)

	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	var reduced_motion := bool(SettingsManager.get_value("reduced_motion", false))
	panel.position = Vector2(20, 500)
	panel.modulate.a = 1.0
	sigil.modulate.a = 1.0
	if animate and not reduced_motion:
		panel.position.y = 516.0
		panel.modulate.a = 0.0
		sigil.modulate.a = 0.25
		_transition_tween = create_tween().set_parallel(true)
		_transition_tween.tween_property(panel, "position:y", 500.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
		_transition_tween.tween_property(sigil, "modulate:a", 1.0, 0.18)
	beat_changed.emit(_index, String(beat.get("id", "")))


func _rebuild_pips() -> void:
	for child in pips.get_children():
		pips.remove_child(child)
		child.queue_free()
	for pip_index in range(_beats.size()):
		var pip := PanelContainer.new()
		pip.name = "StoryPip_%d" % pip_index
		pip.custom_minimum_size = Vector2(26, 7)
		pips.add_child(pip)


func _update_pips(accent: Color) -> void:
	for pip_index in range(pips.get_child_count()):
		var pip := pips.get_child(pip_index) as PanelContainer
		var color := accent if pip_index == _index else Color(INK, 0.16)
		pip.add_theme_stylebox_override("panel", _pip_style(color))


func _apply_layout_direction() -> void:
	var direction := LocalizationService.layout_direction()
	var alignment := LocalizationService.start_alignment()
	_content.layout_direction = direction
	(_content.get_parent() as Control).layout_direction = direction
	(pips as Control).layout_direction = direction
	(progress_label.get_parent() as Control).layout_direction = direction
	eyebrow_label.horizontal_alignment = alignment
	title_label.horizontal_alignment = alignment
	body_label.horizontal_alignment = alignment
	progress_label.horizontal_alignment = alignment
	continue_button.alignment = alignment
	skip_button.alignment = alignment


func _apply_safe_layout() -> void:
	if is_instance_valid(root):
		SafeAreaHelperScript.fit_design_control(root, DESIGN_SIZE)


func _on_locale_changed(_locale: String) -> void:
	_apply_layout_direction()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and skip_button.visible:
		skip()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	if is_instance_valid(root):
		root.visible = false
	set_process_unhandled_input(false)


func _accent_color(value: Variant) -> Color:
	if typeof(value) == TYPE_COLOR:
		return value as Color
	if typeof(value) == TYPE_STRING:
		return Color.from_string(String(value), BRONZE)
	return BRONZE


func _bounded_text(value: Variant, maximum_characters: int) -> String:
	var text := String(value).strip_edges()
	if text.length() <= maximum_characters:
		return text
	return text.substr(0, maximum_characters).strip_edges()


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(fill: Color, accent: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(accent, 0.82)
	style.set_border_width_all(2)
	style.border_width_left = 3
	style.border_width_bottom = 4
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 10
	return style


func _pip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _apply_button_style(button: Button, accent: Color, primary: bool) -> void:
	var normal_strength := 0.38 if primary else 0.13
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _button_style(MARBLE.lerp(accent, normal_strength), accent, 0.72))
	button.add_theme_stylebox_override("hover", _button_style(MARBLE.lerp(accent, normal_strength + 0.1), accent, 0.94))
	button.add_theme_stylebox_override("pressed", _button_style(MARBLE.lerp(accent, normal_strength + 0.2), accent, 1.0))
	button.add_theme_stylebox_override("focus", _button_style(MARBLE.lerp(accent, normal_strength + 0.06), accent, 1.0))


func _button_style(fill: Color, accent: Color, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(accent, border_alpha)
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
