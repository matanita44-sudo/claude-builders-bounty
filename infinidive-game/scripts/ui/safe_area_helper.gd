class_name SafeAreaHelper
extends RefCounted

const DEFAULT_DESIGN_SIZE := Vector2(540.0, 960.0)


static func logical_safe_rect(viewport: Viewport) -> Rect2:
	var visible := viewport.get_visible_rect()
	if visible.size.x <= 0.0 or visible.size.y <= 0.0:
		return Rect2(Vector2.ZERO, DEFAULT_DESIGN_SIZE)

	if OS.has_feature("web"):
		var web_metrics := _web_safe_area_metrics()
		if not web_metrics.is_empty():
			return rect_from_insets(
				visible,
				Vector2(float(web_metrics.get("width", 0.0)), float(web_metrics.get("height", 0.0))),
				Vector4(
					float(web_metrics.get("left", 0.0)),
					float(web_metrics.get("top", 0.0)),
					float(web_metrics.get("right", 0.0)),
					float(web_metrics.get("bottom", 0.0))
				)
			)

	if OS.has_feature("android") or OS.has_feature("ios"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var native_safe := DisplayServer.get_display_safe_area()
		if window_size.x > 0.0 and window_size.y > 0.0 and native_safe.size.x > 0 and native_safe.size.y > 0:
			return rect_from_insets(
				visible,
				window_size,
				Vector4(
					float(native_safe.position.x),
					float(native_safe.position.y),
					maxf(0.0, window_size.x - float(native_safe.end.x)),
					maxf(0.0, window_size.y - float(native_safe.end.y))
				)
			)

	return visible


static func rect_from_insets(visible: Rect2, source_size: Vector2, insets: Vector4) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return visible
	var scale := Vector2(visible.size.x / source_size.x, visible.size.y / source_size.y)
	var left := clampf(insets.x * scale.x, 0.0, visible.size.x * 0.45)
	var top := clampf(insets.y * scale.y, 0.0, visible.size.y * 0.45)
	var right := clampf(insets.z * scale.x, 0.0, visible.size.x * 0.45)
	var bottom := clampf(insets.w * scale.y, 0.0, visible.size.y * 0.45)
	return Rect2(
		visible.position + Vector2(left, top),
		Vector2(maxf(1.0, visible.size.x - left - right), maxf(1.0, visible.size.y - top - bottom))
	)


static func fitted_design_rect(safe_rect: Rect2, design_size: Vector2 = DEFAULT_DESIGN_SIZE) -> Rect2:
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return safe_rect
	var fit_scale := minf(1.0, minf(safe_rect.size.x / design_size.x, safe_rect.size.y / design_size.y))
	fit_scale = maxf(fit_scale, 0.01)
	var fitted_size := design_size * fit_scale
	return Rect2(safe_rect.position + (safe_rect.size - fitted_size) * 0.5, fitted_size)


static func fit_design_control(control: Control, design_size: Vector2 = DEFAULT_DESIGN_SIZE) -> void:
	var fitted := fitted_design_rect(logical_safe_rect(control.get_viewport()), design_size)
	control.set_anchor(SIDE_LEFT, 0.0)
	control.set_anchor(SIDE_TOP, 0.0)
	control.set_anchor(SIDE_RIGHT, 0.0)
	control.set_anchor(SIDE_BOTTOM, 0.0)
	control.pivot_offset = Vector2.ZERO
	control.position = fitted.position
	control.size = design_size
	control.scale = Vector2(fitted.size.x / design_size.x, fitted.size.y / design_size.y)


static func _web_safe_area_metrics() -> Dictionary:
	var encoded: Variant = JavaScriptBridge.eval("JSON.stringify(window.INFINIDIVE_SAFE_AREA || null)")
	if typeof(encoded) != TYPE_STRING or String(encoded).is_empty() or String(encoded) == "null":
		return {}
	var decoded: Variant = JSON.parse_string(String(encoded))
	return decoded if typeof(decoded) == TYPE_DICTIONARY else {}
