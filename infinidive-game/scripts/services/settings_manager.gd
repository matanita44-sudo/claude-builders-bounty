extends Node

signal setting_changed(key: String, value: Variant)
signal language_changed(locale: String)

const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["en", "he"]
const DEFAULT_REDUCED_MOTION := false
const DEFAULT_DAMAGE_FLASH := 0.7
const DEFAULT_SCREEN_SHAKE := 0.7
const DEFAULT_ANALYTICS_OPT_IN := false
const DAMAGE_FEEDBACK_DURATION_SECONDS := 0.18

var values: Dictionary = {}

func _ready() -> void:
	values = SaveManager.profile.get("settings", SaveManager.default_profile().settings).duplicate(true)
	# The shipped experience is English-first. Never derive this value from the
	# OS/browser locale: Hebrew is entered only through the explicit Settings
	# control (or preserved from a prior explicit selection).
	_normalize_persisted_setting_values()
	values["language"] = normalize_language(values.get("language", DEFAULT_LANGUAGE))
	SaveManager.profile["settings"] = values.duplicate(true)
	apply_all()

func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)

func set_value(key: String, value: Variant, persist_now := true) -> bool:
	var previous_values := values.duplicate(true)
	var previous_settings: Dictionary = SaveManager.profile.get("settings",SaveManager.default_profile().settings).duplicate(true)
	var applied_value: Variant = normalize_setting_value(key,value)
	values[key] = applied_value
	SaveManager.profile.settings = values.duplicate(true)
	if persist_now and not SaveManager.save_profile():
		values = previous_values
		SaveManager.profile.settings = previous_settings
		_apply(key,values.get(key,null))
		return false
	_apply(key, applied_value)
	setting_changed.emit(key, applied_value)
	if key == "language":
		language_changed.emit(String(applied_value))
	return true

func apply_all() -> void:
	_normalize_persisted_setting_values()
	values["language"] = normalize_language(values.get("language", DEFAULT_LANGUAGE))
	SaveManager.profile["settings"] = values.duplicate(true)
	for key in values:
		_apply(String(key), values[key])

func normalize_setting_value(key: String, value: Variant) -> Variant:
	match key:
		"language":
			return normalize_language(value)
		"reduced_motion":
			# Accessibility switches are intentionally strict. Strings and numbers
			# from malformed saves must never silently turn Reduced Motion on/off.
			return value if typeof(value) == TYPE_BOOL else DEFAULT_REDUCED_MOTION
		"damage_flash":
			return _normalized_unit_float(value,DEFAULT_DAMAGE_FLASH)
		"screen_shake":
			return _normalized_unit_float(value,DEFAULT_SCREEN_SHAKE)
		"analytics_opt_in":
			# Consent is never truthy-coerced. A malformed save must agree with the
			# analytics service's fail-closed literal-Boolean contract and render OFF.
			return value if typeof(value) == TYPE_BOOL else DEFAULT_ANALYTICS_OPT_IN
		_:
			return value

func reduced_motion_enabled() -> bool:
	return bool(normalize_setting_value("reduced_motion",values.get("reduced_motion",DEFAULT_REDUCED_MOTION)))

func damage_flash_intensity() -> float:
	return float(normalize_setting_value("damage_flash",values.get("damage_flash",DEFAULT_DAMAGE_FLASH)))

func screen_shake_intensity() -> float:
	return float(normalize_setting_value("screen_shake",values.get("screen_shake",DEFAULT_SCREEN_SHAKE)))

func _normalize_persisted_setting_values() -> void:
	values["reduced_motion"] = normalize_setting_value("reduced_motion",values.get("reduced_motion",DEFAULT_REDUCED_MOTION))
	values["damage_flash"] = normalize_setting_value("damage_flash",values.get("damage_flash",DEFAULT_DAMAGE_FLASH))
	values["screen_shake"] = normalize_setting_value("screen_shake",values.get("screen_shake",DEFAULT_SCREEN_SHAKE))
	values["analytics_opt_in"] = normalize_setting_value("analytics_opt_in",values.get("analytics_opt_in",DEFAULT_ANALYTICS_OPT_IN))

func _normalized_unit_float(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
		return fallback
	return clampf(float(value),0.0,1.0)

func normalize_language(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return DEFAULT_LANGUAGE
	var normalized := String(value).strip_edges().to_lower().replace("_", "-").get_slice("-", 0)
	return normalized if SUPPORTED_LANGUAGES.has(normalized) else DEFAULT_LANGUAGE

func _apply(key: String, value: Variant) -> void:
	match key:
		"master_volume": _set_bus("Master", float(value))
		"music_volume": _set_bus("Music", float(value))
		"sfx_volume": _set_bus("SFX", float(value))
		"language": TranslationServer.set_locale(normalize_language(value))

func _set_bus(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_value, 0.001)))
		AudioServer.set_bus_mute(bus_index, linear_value <= 0.001)

func haptics_enabled() -> bool:
	return bool(values.get("haptics", true))

func pulse_haptic(duration_ms: int = 12, amplitude: float = 0.35) -> void:
	if haptics_enabled():
		Input.vibrate_handheld(duration_ms, amplitude)
