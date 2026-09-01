extends Node

signal setting_changed(key: String, value: Variant)
signal language_changed(locale: String)

var values: Dictionary = {}

func _ready() -> void:
	values = SaveManager.profile.get("settings", SaveManager.default_profile().settings).duplicate(true)
	apply_all()

func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)

func set_value(key: String, value: Variant, persist_now := true) -> void:
	values[key] = value
	SaveManager.profile.settings = values.duplicate(true)
	_apply(key, value)
	setting_changed.emit(key, value)
	if key == "language":
		language_changed.emit(String(value))
	if persist_now:
		SaveManager.save_profile()

func apply_all() -> void:
	for key in values:
		_apply(String(key), values[key])

func _apply(key: String, value: Variant) -> void:
	match key:
		"master_volume": _set_bus("Master", float(value))
		"music_volume": _set_bus("Music", float(value))
		"sfx_volume": _set_bus("SFX", float(value))
		"language": TranslationServer.set_locale(String(value))

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
