class_name RunHUD
extends CanvasLayer

const SafeAreaHelperScript := preload("res://scripts/ui/safe_area_helper.gd")
const RiftResultCardClass := preload("res://scripts/ui/result_card.gd")
const MYTHIC_INK := Color("#17324B")
const MYTHIC_MARBLE := Color("#EAF3E7")
const MYTHIC_MARBLE_WARM := Color("#F7EBD2")
const MYTHIC_AQUA := Color("#2CB8BC")
const MYTHIC_CORAL := Color("#F25F5C")
const MYTHIC_BRONZE := Color("#C88936")
const MYTHIC_GOLD := Color("#F1BE48")


class ActionRing:
	extends Control

	var accent := VisualTheme.FRIENDLY
	var progress := 0.0
	var available := true

	func _init(color: Color = VisualTheme.FRIENDLY) -> void:
		accent = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_progress(value: float) -> void:
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

	func set_available(value: bool) -> void:
		available = value
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.45
		var active_color := accent if available else VisualTheme.MUTED
		draw_circle(center, radius - 5.0, Color("#EFF4DF"))
		draw_arc(center, radius, 0.0, TAU, 64, Color(active_color, 0.16), 2.0, true)
		draw_arc(center, radius - 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(active_color, 0.92), 4.0, true)
		for tick_index in range(8):
			var angle := -PI * 0.5 + float(tick_index) * TAU / 8.0
			var direction := Vector2.from_angle(angle)
			draw_line(center + direction * (radius - 1.0), center + direction * (radius + 4.0), Color(active_color, 0.42), 1.5, true)
		var chevron_y := 16.0
		draw_polyline(PackedVector2Array([
			Vector2(center.x - 5.0, chevron_y + 4.0),
			Vector2(center.x, chevron_y),
			Vector2(center.x + 5.0, chevron_y + 4.0)
		]), Color(active_color, 0.8 if available else 0.28), 2.0, true)


class BarTicks:
	extends Control

	var tick_color := Color.WHITE
	var divisions := 10

	func _init(color: Color = Color.WHITE, count: int = 10) -> void:
		tick_color = color
		divisions = maxi(2, count)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if size.x <= 0.0:
			return
		for tick_index in range(1, divisions):
			var x := size.x * float(tick_index) / float(divisions)
			draw_line(Vector2(x, 2.0), Vector2(x, size.y - 2.0), Color(tick_color, 0.11), 1.0)


class MythicTrim:
	extends Control

	var accent := Color("#C88936")

	func _init(color: Color = Color("#C88936")) -> void:
		accent = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center_x := size.x * 0.5
		draw_line(Vector2(30.0, 3.0), Vector2(center_x - 10.0, 3.0), Color(accent, 0.68), 2.0, true)
		draw_line(Vector2(center_x + 10.0, 3.0), Vector2(size.x - 30.0, 3.0), Color(accent, 0.68), 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(center_x, -1.0),
			Vector2(center_x + 6.0, 3.0),
			Vector2(center_x, 7.0),
			Vector2(center_x - 6.0, 3.0)
		]), Color(accent, 0.88))
		for side in [-1.0, 1.0]:
			var edge_x := 18.0 if side < 0.0 else size.x - 18.0
			draw_polyline(PackedVector2Array([
				Vector2(edge_x + side * 8.0, 14.0),
				Vector2(edge_x, 8.0),
				Vector2(edge_x - side * 8.0, 14.0)
			]), Color(accent, 0.62), 2.0, true)


class DamageEdgeFeedback:
	extends Control

	var remaining_seconds := 0.0
	var duration_seconds := SettingsManager.DAMAGE_FEEDBACK_DURATION_SECONDS
	var intensity := 0.0
	var stable_alpha := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func trigger(configured_intensity: float, reduced_motion: bool) -> bool:
		intensity = clampf(configured_intensity,0.0,1.0)
		stable_alpha = reduced_motion
		remaining_seconds = duration_seconds if intensity > 0.0 else 0.0
		visible = remaining_seconds > 0.0
		queue_redraw()
		return visible

	func clear() -> void:
		remaining_seconds = 0.0
		intensity = 0.0
		visible = false
		queue_redraw()

	func _process(delta: float) -> void:
		if remaining_seconds <= 0.0:
			return
		remaining_seconds = maxf(0.0,remaining_seconds-maxf(0.0,delta))
		if remaining_seconds <= 0.0:
			visible = false
		queue_redraw()

	func _draw() -> void:
		if intensity <= 0.0 or remaining_seconds <= 0.0:
			return
		var life_ratio := clampf(remaining_seconds/maxf(0.001,duration_seconds),0.0,1.0)
		var alpha := intensity*(0.34 if stable_alpha else 0.34*life_ratio)
		var edge_depth := 24.0
		var edge_color := Color(MYTHIC_CORAL,alpha)
		# Only the four borders are painted. The center of the combat field never
		# receives a full-screen damage wash, preserving projectile readability.
		draw_rect(Rect2(0,0,size.x,edge_depth),edge_color)
		draw_rect(Rect2(0,size.y-edge_depth,size.x,edge_depth),edge_color)
		draw_rect(Rect2(0,edge_depth,edge_depth,maxf(0.0,size.y-edge_depth*2.0)),edge_color)
		draw_rect(Rect2(size.x-edge_depth,edge_depth,edge_depth,maxf(0.0,size.y-edge_depth*2.0)),edge_color)

signal dash_pressed
signal dive_pressed
signal pause_pressed
signal organ_selected(organ_id: String)
signal mutation_selected(mutation_id: String)
signal mutation_reroll_requested
signal result_action(action: String)

var root: Control
var boss_name: Label
var boss_bar: ProgressBar
var player_bar: ProgressBar
var phase_label: Label
var resource_label: Label
var timer_label: Label
var dash_button: Button
var dive_button: Button
var overlay: PanelContainer
var toast_label: Label
var toast_panel: PanelContainer
var _toast_tween: Tween
var _tutorial_message := ""
var _tutorial_color := VisualTheme.FRIENDLY
var _toast_is_transient := false
var _dash_ring: ActionRing
var _dive_ring: ActionRing
var _player_in_danger := false
var damage_edge_feedback: DamageEdgeFeedback

func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_apply_safe_layout)
	_apply_safe_layout()

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Gameplay controls use fixed physical positions; only text containers mirror.
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	damage_edge_feedback = DamageEdgeFeedback.new()
	damage_edge_feedback.name = "DamageEdgeFeedback"
	damage_edge_feedback.position = Vector2.ZERO
	damage_edge_feedback.size = Vector2(540,960)
	root.add_child(damage_edge_feedback)

	var top_panel := PanelContainer.new()
	top_panel.name = "CombatStatusFrame"
	top_panel.position = Vector2(12,14)
	top_panel.size = Vector2(516,112)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(MYTHIC_MARBLE, 0.97), MYTHIC_BRONZE, 18, 0.82))
	root.add_child(top_panel)
	var top_trim := MythicTrim.new(MYTHIC_BRONZE)
	top_trim.position = top_panel.position
	top_trim.size = top_panel.size
	root.add_child(top_trim)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(top)
	var line := HBoxContainer.new()
	line.layout_direction = LocalizationService.layout_direction()
	line.add_theme_constant_override("separation", 8)
	line.custom_minimum_size.y = 23
	top.add_child(line)
	boss_name = VisualTheme.label(LocalizationService.content_text("boss","gravemaw","name","CRONUS"), 15)
	boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_name.horizontal_alignment = LocalizationService.start_alignment()
	boss_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_color", MYTHIC_INK)
	boss_name.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.9))
	boss_name.add_theme_constant_override("outline_size", 1)
	line.add_child(boss_name)
	var resource_pill := PanelContainer.new()
	resource_pill.add_theme_stylebox_override("panel", _pill_style(Color(MYTHIC_AQUA, 0.17), Color(MYTHIC_AQUA, 0.72)))
	line.add_child(resource_pill)
	resource_label = VisualTheme.label(LocalizationService.text("bio_short_value", {"value": 0}), 12, Color("#16757C"))
	resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource_label.custom_minimum_size.x = 70
	resource_label.layout_direction = LocalizationService.layout_direction()
	resource_pill.add_child(resource_label)
	timer_label = VisualTheme.label("00:00", 12, Color(MYTHIC_INK, 0.7))
	timer_label.custom_minimum_size.x = 47
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	line.add_child(timer_label)

	boss_bar = ProgressBar.new()
	boss_bar.name = "BossIntegrity"
	boss_bar.layout_direction = Control.LAYOUT_DIRECTION_LTR
	boss_bar.show_percentage = true
	boss_bar.custom_minimum_size.y = 17
	boss_bar.add_theme_font_size_override("font_size", 10)
	boss_bar.add_theme_color_override("font_color", Color(1.0, 0.95, 0.98, 0.94))
	boss_bar.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.02, 0.96))
	boss_bar.add_theme_constant_override("outline_size", 2)
	boss_bar.add_theme_stylebox_override("background", _bar_style(Color("#C6D9D4"), Color(MYTHIC_BRONZE, 0.46), 8))
	boss_bar.add_theme_stylebox_override("fill", _bar_style(MYTHIC_CORAL, Color("#FF9D73"), 8))
	top.add_child(boss_bar)
	var boss_ticks := BarTicks.new(Color.WHITE, 12)
	boss_bar.add_child(boss_ticks)
	boss_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var player_line := HBoxContainer.new()
	player_line.add_theme_constant_override("separation", 8)
	top.add_child(player_line)
	var hull_marker := ColorRect.new()
	hull_marker.color = MYTHIC_AQUA
	hull_marker.custom_minimum_size = Vector2(4, 10)
	hull_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_line.add_child(hull_marker)
	player_bar = ProgressBar.new()
	player_bar.name = "DiverIntegrity"
	player_bar.layout_direction = Control.LAYOUT_DIRECTION_LTR
	player_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_bar.show_percentage = true
	player_bar.custom_minimum_size.y = 12
	player_bar.add_theme_font_size_override("font_size", 9)
	player_bar.add_theme_color_override("font_color", Color(0.94, 1.0, 0.92, 0.92))
	player_bar.add_theme_color_override("font_outline_color", Color(0.0, 0.035, 0.01, 0.96))
	player_bar.add_theme_constant_override("outline_size", 2)
	player_bar.add_theme_stylebox_override("background", _bar_style(Color("#CFE1D9"), Color(MYTHIC_AQUA, 0.42), 6))
	player_bar.add_theme_stylebox_override("fill", _bar_style(MYTHIC_AQUA, Color("#77E0D0"), 6))
	player_line.add_child(player_bar)
	var player_ticks := BarTicks.new(Color.WHITE, 8)
	player_bar.add_child(player_ticks)
	player_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var phase_panel := PanelContainer.new()
	phase_panel.name = "CombatPhaseChip"
	phase_panel.position = Vector2(108,136)
	phase_panel.size = Vector2(324,38)
	phase_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_panel.add_theme_stylebox_override("panel", _panel_style(Color("#BCEBE4"), MYTHIC_AQUA, 19, 0.82))
	root.add_child(phase_panel)
	phase_label = VisualTheme.label(LocalizationService.text("state_exterior"), 13, MYTHIC_INK)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE, 0.84))
	phase_label.add_theme_constant_override("outline_size", 1)
	phase_panel.add_child(phase_label)

	var left_handed := String(SettingsManager.get_value("handedness", "right")) == "left"
	var dash_at := Vector2(422, 836) if left_handed else Vector2(14, 836)
	var dive_at := Vector2(14, 836) if left_handed else Vector2(422, 836)
	_dash_ring = ActionRing.new(MYTHIC_AQUA)
	_dash_ring.name = "DashChargeRing"
	_dash_ring.position = dash_at
	_dash_ring.size = Vector2(104, 104)
	_dash_ring.set_progress(1.0)
	root.add_child(_dash_ring)
	dash_button = _round_button(LocalizationService.text("phase_dash"), dash_at + Vector2(9, 9), MYTHIC_AQUA)
	dash_button.name = "DashAction"
	dash_button.pressed.connect(func(): dash_pressed.emit())
	root.add_child(dash_button)
	_dive_ring = ActionRing.new(MYTHIC_CORAL)
	_dive_ring.name = "DiveReadyRing"
	_dive_ring.position = dive_at
	_dive_ring.size = Vector2(104, 104)
	_dive_ring.set_progress(0.0)
	_dive_ring.set_available(false)
	root.add_child(_dive_ring)
	dive_button = _round_button(LocalizationService.text("dive_locked"), dive_at + Vector2(9, 9), MYTHIC_CORAL)
	dive_button.name = "DiveAction"
	dive_button.disabled = true
	dive_button.pressed.connect(func(): dive_pressed.emit())
	root.add_child(dive_button)

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "II"
	pause_button.position = Vector2(478,132)
	pause_button.size = Vector2(50,46)
	pause_button.add_theme_font_size_override("font_size", 19)
	pause_button.add_theme_color_override("font_color", MYTHIC_INK)
	pause_button.add_theme_stylebox_override("normal", _panel_style(MYTHIC_MARBLE_WARM, MYTHIC_BRONZE, 19, 0.72))
	pause_button.add_theme_stylebox_override("hover", _panel_style(_tinted_surface(MYTHIC_GOLD, 0.22), MYTHIC_BRONZE, 19, 0.94))
	pause_button.add_theme_stylebox_override("pressed", _panel_style(_tinted_surface(MYTHIC_GOLD, 0.38), MYTHIC_BRONZE, 19, 1.0))
	pause_button.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_button)

	toast_panel = PanelContainer.new()
	toast_panel.name = "CombatToast"
	toast_panel.position = Vector2(64,184)
	toast_panel.size = Vector2(412,54)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color("#255B72"), MYTHIC_GOLD, 15, 0.82))
	toast_panel.modulate.a = 0.0
	root.add_child(toast_panel)
	toast_label = VisualTheme.label("", 13)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.layout_direction = LocalizationService.layout_direction()
	toast_label.modulate.a = 0.0
	toast_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
	toast_label.add_theme_constant_override("outline_size", 2)
	toast_panel.add_child(toast_label)

	overlay = PanelContainer.new()
	overlay.name = "DecisionOverlay"
	overlay.position = Vector2(14,224)
	overlay.size = Vector2(512,596)
	overlay.add_theme_stylebox_override("panel", _overlay_style(MYTHIC_BRONZE))
	overlay.visible = false
	root.add_child(overlay)

func _apply_safe_layout() -> void:
	if is_instance_valid(root):
		SafeAreaHelperScript.fit_design_control(root)

func _tinted_surface(accent: Color, strength: float, alpha: float = 0.98) -> Color:
	var color := MYTHIC_MARBLE.lerp(accent, clampf(strength, 0.0, 1.0))
	color.a = alpha
	return color

func _panel_style(fill: Color, accent: Color, radius: int, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(accent, border_alpha)
	style.set_border_width_all(2)
	style.border_width_left = 3
	style.border_width_bottom = 3
	style.set_corner_radius_all(radius)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.shadow_color = Color(MYTHIC_INK, 0.18)
	style.shadow_size = 8
	return style

func _overlay_style(accent: Color) -> StyleBoxFlat:
	var style := _panel_style(Color(MYTHIC_MARBLE_WARM, 0.985), accent, 26, 0.82)
	style.border_width_top = 3
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(MYTHIC_INK, 0.24)
	style.shadow_size = 13
	return style

func _pill_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _bar_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _card_style(fill: Color, accent: Color, radius: int, border_alpha: float) -> StyleBoxFlat:
	var style := _panel_style(fill, accent, radius, border_alpha)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(MYTHIC_INK, 0.13)
	style.shadow_size = 7
	return style

func _round_button(text_value: String, at: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = Vector2(86,86)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE, 0.82))
	button.add_theme_color_override("font_color", MYTHIC_INK)
	button.add_theme_color_override("font_hover_color", MYTHIC_INK)
	button.add_theme_color_override("font_pressed_color", MYTHIC_INK)
	button.add_theme_color_override("font_disabled_color", Color(MYTHIC_INK, 0.46))
	button.add_theme_stylebox_override("normal", _card_style(_tinted_surface(color, 0.29), color, 43, 0.68))
	button.add_theme_stylebox_override("hover", _card_style(_tinted_surface(color, 0.41), color, 43, 0.94))
	button.add_theme_stylebox_override("pressed", _card_style(_tinted_surface(color, 0.56), color, 43, 1.0))
	button.add_theme_stylebox_override("focus", _card_style(_tinted_surface(color, 0.36), color, 43, 1.0))
	button.add_theme_stylebox_override("disabled", _card_style(Color("#D7DDD3"), Color("#93A6A1"), 43, 0.46))
	return button

func _apply_choice_style(button: Button, accent: Color, radius: int = 16) -> void:
	button.layout_direction = LocalizationService.layout_direction()
	button.add_theme_color_override("font_color", MYTHIC_INK)
	button.add_theme_color_override("font_hover_color", MYTHIC_INK)
	button.add_theme_color_override("font_pressed_color", MYTHIC_INK)
	button.add_theme_color_override("font_focus_color", MYTHIC_INK)
	button.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE, 0.68))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_stylebox_override("normal", _card_style(_tinted_surface(accent, 0.12), accent, radius, 0.64))
	button.add_theme_stylebox_override("hover", _card_style(_tinted_surface(accent, 0.23), accent, radius, 0.94))
	button.add_theme_stylebox_override("pressed", _card_style(_tinted_surface(accent, 0.35), accent, radius, 1.0))
	button.add_theme_stylebox_override("focus", _card_style(_tinted_surface(accent, 0.19), accent, radius, 1.0))

func _apply_result_action_style(button: Button, accent: Color, primary: bool) -> void:
	var strength := 0.22 if primary else 0.09
	button.add_theme_color_override("font_color", MYTHIC_INK if primary else Color(MYTHIC_INK, 0.86))
	button.add_theme_color_override("font_hover_color", MYTHIC_INK)
	button.add_theme_color_override("font_pressed_color", MYTHIC_INK)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _card_style(_tinted_surface(accent, strength), accent, 15, 0.66 if primary else 0.42))
	button.add_theme_stylebox_override("hover", _card_style(_tinted_surface(accent, strength + 0.09), accent, 15, 0.9))
	button.add_theme_stylebox_override("pressed", _card_style(_tinted_surface(accent, strength + 0.18), accent, 15, 1.0))
	button.add_theme_stylebox_override("focus", _card_style(_tinted_surface(accent, strength + 0.05), accent, 15, 0.94))

func update_status(boss_title: String, boss_ratio: float, player_ratio: float, bio: int, elapsed: float, phase_text: String, dash_ratio: float) -> void:
	boss_name.text = boss_title
	boss_bar.value = clampf(boss_ratio, 0, 1) * 100.0
	var safe_player_ratio := clampf(player_ratio, 0, 1)
	player_bar.value = safe_player_ratio * 100.0
	var player_in_danger := safe_player_ratio <= 0.3
	if player_in_danger != _player_in_danger:
		_player_in_danger = player_in_danger
		var fill_color := MYTHIC_CORAL if player_in_danger else MYTHIC_AQUA
		var border_color := Color("#FF9D73") if player_in_danger else Color("#77E0D0")
		player_bar.add_theme_stylebox_override("fill", _bar_style(fill_color, border_color, 6))
	resource_label.text = LocalizationService.text("bio_short_value", {"value": bio})
	timer_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	phase_label.text = phase_text
	var safe_dash_ratio := clampf(dash_ratio, 0.0, 1.0)
	_dash_ring.set_progress(safe_dash_ratio)
	dash_button.text = LocalizationService.text("phase_ready") if safe_dash_ratio >= 1.0 else LocalizationService.text("phase_charge", {"percent": int(safe_dash_ratio * 100.0)})

func set_dive_ready(ready: bool) -> void:
	dive_button.disabled = not ready
	dive_button.text = LocalizationService.text("dive_now") if ready else LocalizationService.text("dive_locked")
	_dive_ring.set_available(ready)
	_dive_ring.set_progress(1.0 if ready else 0.0)

func show_toast(message: String, color: Color = VisualTheme.TEXT, duration_seconds: float = 1.45) -> void:
	_toast_is_transient = true
	toast_label.text = message
	toast_label.add_theme_color_override("font_color",color)
	toast_panel.size = Vector2(412,72 if message.contains("\n") else 54)
	if _toast_tween and _toast_tween.is_running():
		_toast_tween.kill()
	var reduced_motion := SettingsManager.reduced_motion_enabled()
	toast_label.modulate.a = 1.0 if reduced_motion else 0.0
	toast_panel.modulate.a = toast_label.modulate.a
	_toast_tween = create_tween()
	if not reduced_motion:
		_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.15)
		_toast_tween.parallel().tween_property(toast_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(clampf(duration_seconds,1.0,4.0))
	if not reduced_motion:
		_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.28)
		_toast_tween.parallel().tween_property(toast_panel, "modulate:a", 0.0, 0.28)
	_toast_tween.tween_callback(_restore_tutorial_prompt)

func show_damage_feedback() -> bool:
	return damage_edge_feedback.trigger(
		SettingsManager.damage_flash_intensity(),
		SettingsManager.reduced_motion_enabled()
	)

func set_tutorial_prompt(message: String, color: Color = VisualTheme.FRIENDLY) -> void:
	_tutorial_message = message
	_tutorial_color = color
	if not _toast_is_transient:
		_restore_tutorial_prompt()

func _restore_tutorial_prompt() -> void:
	_toast_is_transient = false
	toast_panel.size = Vector2(412,54)
	if _tutorial_message.is_empty():
		toast_label.text = ""
		toast_label.modulate.a = 0.0
		toast_panel.modulate.a = 0.0
		return
	toast_label.text = _tutorial_message
	toast_label.add_theme_color_override("font_color",_tutorial_color)
	toast_label.modulate.a = 1.0
	toast_panel.modulate.a = 1.0

func show_organ_choices(organs: Array, preview_level: int = 0) -> void:
	# The breach prompt has already done its job once this selector is open.
	# Clear it now so it cannot reappear after the overlay closes.
	set_tutorial_prompt("")
	_clear_overlay()
	overlay.add_theme_stylebox_override("panel", _overlay_style(MYTHIC_CORAL))
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation", 11)
	overlay.add_child(box)
	var eyebrow := VisualTheme.label(LocalizationService.text("organ_order_eyebrow"), 12, Color("#8A5A1D"))
	eyebrow.horizontal_alignment = LocalizationService.start_alignment()
	eyebrow.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.9))
	eyebrow.add_theme_constant_override("outline_size", 1)
	box.add_child(eyebrow)
	var title := VisualTheme.label(LocalizationService.text("organ_choice_title"), 30, MYTHIC_INK)
	title.horizontal_alignment = LocalizationService.start_alignment()
	title.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.88))
	title.add_theme_constant_override("outline_size", 2)
	box.add_child(title)
	var body := VisualTheme.label(LocalizationService.text("organ_choice_body"), 14, Color(MYTHIC_INK, 0.74))
	body.horizontal_alignment = LocalizationService.start_alignment()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = 54
	box.add_child(body)
	for organ_index in range(organs.size()):
		var raw_organ: Variant = organs[organ_index]
		var organ: Dictionary = raw_organ
		var button := Button.new()
		var organ_id := String(organ.get("id",""))
		button.name = "OrganChoice_%s" % organ_id
		var organ_name := LocalizationService.content_text("organ",organ_id,"name",String(organ.get("name",LocalizationService.text("organ_fallback"))))
		var organ_effect := LocalizationService.content_text("organ",organ_id,"effect",String(organ.get("effect","")))
		var details := "%02d / %s\n%s" % [organ_index + 1, organ_name, organ_effect]
		if preview_level > 0:
			details += "\n— " + LocalizationService.text("organ_scan", {"hp": int(organ.get("hp", 0)), "hazard": LocalizationService.hazard_text(String(organ.get("hazard", "none")))})
		button.text = details
		button.custom_minimum_size.y = 94 if preview_level <= 0 else 105
		button.alignment = LocalizationService.start_alignment()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		_apply_choice_style(button, MYTHIC_CORAL, 17)
		button.pressed.connect(func(): hide_overlay(); organ_selected.emit(organ_id))
		box.add_child(button)

func show_mutation_choices(mutations: Array, rerolls: int) -> void:
	_clear_overlay()
	overlay.add_theme_stylebox_override("panel", _overlay_style(MYTHIC_BRONZE))
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)
	var eyebrow := VisualTheme.label(LocalizationService.text("mutation_eyebrow"), 12, Color("#8A5A1D"))
	eyebrow.horizontal_alignment = LocalizationService.start_alignment()
	eyebrow.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.9))
	eyebrow.add_theme_constant_override("outline_size", 1)
	box.add_child(eyebrow)
	var title := VisualTheme.label(LocalizationService.text("mutation_choice_title"), 30, MYTHIC_INK)
	title.horizontal_alignment = LocalizationService.start_alignment()
	title.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.88))
	title.add_theme_constant_override("outline_size", 2)
	box.add_child(title)
	for mutation_index in range(mutations.size()):
		var raw_mutation: Variant = mutations[mutation_index]
		var mutation: Dictionary = raw_mutation
		var button := Button.new()
		var mutation_id := String(mutation.get("id",""))
		button.name = "MutationChoice_%s" % mutation_id
		var mutation_name := LocalizationService.content_text("mutation",mutation_id,"name",String(mutation.get("name",LocalizationService.text("mutation_fallback"))))
		var mutation_description := LocalizationService.content_text("mutation",mutation_id,"description",String(mutation.get("description","")))
		var badge := ""
		if bool(mutation.get("_synergy", false)):
			badge = LocalizationService.text("synergy_detail", {"tag": String(mutation.get("_synergy_detail", "")).replace("_", " ").to_upper()}) if mutation.has("_synergy_detail") else LocalizationService.text("synergy")
			badge = badge.replace("◆", "+")
		if String(mutation.get("rarity", "common")) == "rare":
			badge = (badge + " · " if not badge.is_empty() else "") + LocalizationService.text("rare")
		button.text = "%02d / %s\n%s%s" % [mutation_index + 1, mutation_name, mutation_description, "\n— " + badge if not badge.is_empty() else ""]
		button.custom_minimum_size.y = 108
		button.alignment = LocalizationService.start_alignment()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		_apply_choice_style(button, MYTHIC_GOLD, 17)
		button.pressed.connect(func(): hide_overlay(); mutation_selected.emit(mutation_id))
		box.add_child(button)
	if rerolls > 0:
		var reroll_button := Button.new()
		reroll_button.name = "MutationReroll"
		reroll_button.text = LocalizationService.text("reroll_left",{"count":rerolls})
		reroll_button.alignment = LocalizationService.start_alignment()
		reroll_button.custom_minimum_size.y = 50
		reroll_button.add_theme_font_size_override("font_size", 13)
		_apply_result_action_style(reroll_button, MYTHIC_BRONZE, false)
		reroll_button.pressed.connect(func(): mutation_reroll_requested.emit())
		box.add_child(reroll_button)

func show_result(result: Dictionary) -> void:
	_clear_overlay()
	var won := bool(result.get("won",false))
	var result_accent := MYTHIC_AQUA if won else MYTHIC_CORAL
	var result_text_accent := Color("#187B7F") if won else Color("#B53F42")
	overlay.add_theme_stylebox_override("panel", _overlay_style(result_accent))
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation", 8)
	overlay.add_child(box)
	var result_eyebrow := VisualTheme.label(LocalizationService.text("colossus_collapsed") if won else LocalizationService.text("diver_lost"), 12, result_text_accent)
	result_eyebrow.horizontal_alignment = LocalizationService.start_alignment()
	result_eyebrow.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.9))
	result_eyebrow.add_theme_constant_override("outline_size", 1)
	box.add_child(result_eyebrow)
	var result_title := VisualTheme.label(LocalizationService.text("victory") if won else LocalizationService.text("nest_remembers"), 34, MYTHIC_INK)
	result_title.horizontal_alignment = LocalizationService.start_alignment()
	result_title.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.9))
	result_title.add_theme_constant_override("outline_size", 2)
	box.add_child(result_title)
	var cause_text := LocalizationService.cause_text(String(result.get("cause","unknown_attack")))
	var cause := LocalizationService.text("victory_body") if won else LocalizationService.text("killed_by",{"cause":cause_text})
	var cause_label := VisualTheme.label(cause, 13, Color(MYTHIC_INK, 0.72))
	cause_label.horizontal_alignment = LocalizationService.start_alignment()
	cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cause_label)
	var score := VisualTheme.label(LocalizationService.text("score_value",{"value":String.num_int64(int(result.get("score",0)))}), 44, result_text_accent)
	score.horizontal_alignment = LocalizationService.start_alignment()
	score.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.92))
	score.add_theme_constant_override("outline_size", 2)
	box.add_child(score)
	var boss_id := String(result.get("boss_id",""))
	var boss_definition := GameData.get_boss(boss_id)
	var boss_title := LocalizationService.content_text("boss",boss_id,"name",String(boss_definition.get("name",LocalizationService.text("colossus_fallback"))))
	var weapon_id := String(result.get("weapon",""))
	var weapon_definition := GameData.get_weapon(weapon_id)
	var weapon_title := LocalizationService.content_text("weapon",weapon_id,"name",String(weapon_definition.get("name",weapon_id.replace("_"," ").capitalize())))
	var loadout := VisualTheme.label(LocalizationService.text("result_loadout",{"boss":boss_title,"weapon":weapon_title}), 13, MYTHIC_INK)
	loadout.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(loadout)
	var destroyed_names: Array[String] = []
	for organ_id_value in result.get("destroyed_organs",[]):
		var organ_id := String(organ_id_value)
		var organ_fallback := organ_id.replace("_"," ").capitalize()
		for raw_organ in boss_definition.get("organs",[]):
			var organ: Dictionary = raw_organ
			if String(organ.get("id",""))==organ_id:
				organ_fallback=String(organ.get("name",organ_fallback))
				break
		destroyed_names.append(LocalizationService.content_text("organ",organ_id,"name",organ_fallback))
	var destroyed_value := ", ".join(destroyed_names) if not destroyed_names.is_empty() else LocalizationService.text("none")
	var organs_label := VisualTheme.label(LocalizationService.text("result_organs_destroyed",{"value":destroyed_value}), 12, Color("#B53F42"))
	organs_label.horizontal_alignment = LocalizationService.start_alignment()
	organs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(organs_label)
	var mutation_ids: Array = result.get("mutations",[])
	var mutation_names: Array[String] = []
	for mutation_index in range(maxi(0,mutation_ids.size()-3),mutation_ids.size()):
		var mutation_id := String(mutation_ids[mutation_index])
		var mutation_definition := GameData.get_mutation(mutation_id)
		mutation_names.append(LocalizationService.content_text("mutation",mutation_id,"name",String(mutation_definition.get("name",mutation_id.replace("_"," ").capitalize()))))
	if mutation_ids.size()>3:
		mutation_names.append(LocalizationService.text("more_count",{"count":mutation_ids.size()-3}))
	var mutations_value := ", ".join(mutation_names) if not mutation_names.is_empty() else LocalizationService.text("none")
	var mutations_label := VisualTheme.label(LocalizationService.text("result_mutations",{"value":mutations_value}), 12, Color("#8A5A1D"))
	mutations_label.horizontal_alignment = LocalizationService.start_alignment()
	mutations_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mutations_label)
	var metrics := VisualTheme.label(LocalizationService.text("result_metrics",{"time":result.get("time_text","00:00"),"depth":maxi(1,int(result.get("abyss_depth",0))),"bio":int(result.get("banked_bio",0))}), 12, MYTHIC_INK)
	metrics.horizontal_alignment = LocalizationService.start_alignment()
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(metrics)
	if bool(result.get("challenge_has_target",false)):
		var target_key := "friend_target_beaten" if bool(result.get("challenge_target_met",false)) else "friend_target_missed"
		var target_label := VisualTheme.label(LocalizationService.text(target_key), 13, Color("#187B7F") if bool(result.get("challenge_target_met",false)) else Color("#8A5A1D"))
		target_label.horizontal_alignment = LocalizationService.start_alignment()
		box.add_child(target_label)
	var friend_share_available := RiftResultCardClass.can_convert_result_to_friend_challenge(result)
	for pair in [["retry","dive_again"],["share","share_rift"],["nest","return_to_nest"]]:
		if String(pair[0]) == "share" and not friend_share_available:
			var share_notice := VisualTheme.label(LocalizationService.text("friend_share_unavailable"), 11, Color(MYTHIC_INK, 0.72))
			share_notice.name = "ResultShareUnavailable"
			share_notice.horizontal_alignment = LocalizationService.start_alignment()
			share_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			share_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			share_notice.custom_minimum_size.y = 48
			box.add_child(share_notice)
			continue
		var button := Button.new()
		# Stable semantic names support diagnostics and let headless UI smoke tests
		# exercise the same buttons a player presses.
		button.name = "ResultAction_%s" % String(pair[0])
		button.text = LocalizationService.text(String(pair[1]))
		button.alignment = LocalizationService.start_alignment()
		button.custom_minimum_size.y = 48
		var action: String = pair[0]
		var action_accent := MYTHIC_GOLD if action == "share" else result_accent
		_apply_result_action_style(button, action_accent, action == "retry")
		button.pressed.connect(func(): result_action.emit(action))
		box.add_child(button)


func show_share_card(result: Dictionary, challenge_code: String, nickname: String = "") -> bool:
	# Sharing is deliberately local and explicit: RunScene owns the clipboard
	# action, while this HUD renders a screenshot-ready card bound to the fields
	# encoded by ID1. Unsupported state or a mismatched/tampered code never
	# replaces the result UI.
	var card := RiftResultCardClass.new()
	if not card.configure(result, challenge_code, nickname):
		card.free()
		return false
	_clear_overlay()
	var won := bool(result.get("won", false))
	var result_accent := MYTHIC_AQUA if won else MYTHIC_CORAL
	overlay.add_theme_stylebox_override("panel", _overlay_style(MYTHIC_GOLD))
	overlay.visible = true
	var box := VBoxContainer.new()
	box.name = "FriendRiftShareView"
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation", 7)
	overlay.add_child(box)
	box.add_child(card)
	for pair in [["retry", "dive_again"], ["nest", "return_to_nest"]]:
		var button := Button.new()
		var action: String = pair[0]
		button.name = "ResultCardAction_%s" % action
		button.text = LocalizationService.text(String(pair[1]))
		button.alignment = LocalizationService.start_alignment()
		button.custom_minimum_size.y = 44
		_apply_result_action_style(button, result_accent, action == "retry")
		button.pressed.connect(func(): result_action.emit(action))
		box.add_child(button)
	return true

func show_pause() -> void:
	_clear_overlay()
	overlay.add_theme_stylebox_override("panel", _overlay_style(MYTHIC_BRONZE))
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation", 14)
	overlay.add_child(box)
	var pause_title := VisualTheme.label(LocalizationService.text("dive_paused"), 32, MYTHIC_INK)
	pause_title.horizontal_alignment = LocalizationService.start_alignment()
	pause_title.add_theme_color_override("font_outline_color", Color(MYTHIC_MARBLE_WARM, 0.9))
	pause_title.add_theme_constant_override("outline_size", 2)
	box.add_child(pause_title)
	var pause_body := VisualTheme.label(LocalizationService.text("pause_body"), 14, Color(MYTHIC_INK, 0.72))
	pause_body.horizontal_alignment = LocalizationService.start_alignment()
	pause_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_body.custom_minimum_size.y = 56
	box.add_child(pause_body)
	for pair in [["resume","resume"],["nest","abandon_to_nest"]]:
		var button := Button.new()
		button.text = LocalizationService.text(String(pair[1]))
		button.name = "PauseAction_%s" % String(pair[0])
		button.alignment = LocalizationService.start_alignment()
		button.custom_minimum_size.y = 62
		var action:String=pair[0]
		_apply_result_action_style(button, MYTHIC_AQUA if action == "resume" else MYTHIC_CORAL, action == "resume")
		button.pressed.connect(func(): result_action.emit(action))
		box.add_child(button)

func hide_overlay() -> void:
	overlay.visible = false
	_clear_overlay()

func _clear_overlay() -> void:
	for child in overlay.get_children():
		child.queue_free()
