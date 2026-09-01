class_name VisualTheme
extends RefCounted

const SPACE := Color("#070A0F")
const DEEP_SPACE := Color("#03050C")
const TISSUE := Color("#19101D")
const ARMOR := Color("#D7D0BD")
const ARMOR_SHADOW := Color("#59606B")
const FRIENDLY := Color("#54F2E7")
const ENEMY := Color("#FF4D5E")
const TELEGRAPH := Color("#FFC857")
const VULNERABLE := Color("#F32D83")
const BIO := Color("#92E65D")
const SHARD := Color("#A78BFA")
const TEXT := Color("#F4F1E8")
const MUTED := Color("#8D98A5")

static func panel_style(color: Color = Color(0.035, 0.055, 0.1, 0.94), radius: float = 22.0, border: Color = Color(1, 1, 1, 0.1)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func button_style(color: Color, radius: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.border_color = color.lightened(0.18)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node
