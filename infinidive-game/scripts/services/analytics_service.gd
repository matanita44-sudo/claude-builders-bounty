extends Node

const ALLOWED_EVENTS := [
	"app_open", "session_start", "tutorial_start", "tutorial_step", "tutorial_complete",
	"first_shot", "first_damage_taken", "first_dash", "first_breach", "first_dive",
	"organ_destroyed", "boss_phase_reached", "mutation_offered", "mutation_selected",
	"player_death", "instant_retry", "run_complete", "weapon_selected", "forge_purchase",
	"nest_upgrade", "daily_rift_start", "daily_rift_complete", "friend_rift_created",
	"friend_rift_opened", "abyss_depth_reached", "settings_changed", "session_end"
]
const QUEUE_PATH := "user://analytics_queue.json"
const MAX_QUEUE := 500

var queue: Array = []
var queue_path := QUEUE_PATH
var session_id := ""
var session_started_ms := 0
var last_storage_status := "not_loaded"

func _ready() -> void:
	session_id = "%s-%s" % [Time.get_unix_time_from_system(), randi_range(100000, 999999)]
	session_started_ms = Time.get_ticks_msec()
	_load_queue()
	track("app_open", {"version": ProjectSettings.get_setting("application/config/version", "0")})
	track("session_start")

func track(event_name: String, properties: Dictionary = {}) -> void:
	if not ALLOWED_EVENTS.has(event_name):
		push_warning("AnalyticsService rejected undefined event: " + event_name)
		return
	if not bool(SettingsManager.get_value("analytics_opt_in", false)):
		return
	queue.append({
		"event": event_name,
		"properties": _sanitize(properties),
		"session_id": session_id,
		"timestamp": Time.get_datetime_string_from_system(true)
	})
	if queue.size() > MAX_QUEUE:
		queue = queue.slice(queue.size() - MAX_QUEUE)
	_persist_queue()

func _sanitize(properties: Dictionary) -> Dictionary:
	var safe: Dictionary = {}
	for key in properties:
		var value: Variant = properties[key]
		if typeof(value) in [TYPE_STRING, TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			safe[String(key).left(48)] = value
	return safe

func _load_queue() -> void:
	if not FileAccess.file_exists(queue_path):
		last_storage_status = "empty"
		return
	var file := FileAccess.open(queue_path, FileAccess.READ)
	if file == null:
		last_storage_status = "open_failed"
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		queue = parsed
		last_storage_status = "loaded"
	else:
		last_storage_status = "corrupt_empty"

func _persist_queue() -> bool:
	var file := FileAccess.open(queue_path, FileAccess.WRITE)
	if file == null:
		last_storage_status = "write_failed"
		return false
	file.store_string(JSON.stringify(queue))
	file.flush()
	file = null
	last_storage_status = "saved"
	return true

## Permanently clears the on-device analytics outbox. The in-memory queue is
## changed only after the file removal succeeds, so callers never receive a
## false success while events remain recoverable on disk.
func clear_local_data() -> bool:
	if FileAccess.file_exists(queue_path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(queue_path))
		if remove_error != OK or FileAccess.file_exists(queue_path):
			last_storage_status = "clear_failed"
			push_error("AnalyticsService: failed to clear local queue")
			return false
	queue.clear()
	last_storage_status = "cleared"
	return true

func export_offline_queue() -> Array:
	return queue.duplicate(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		track("session_end", {"duration_ms": Time.get_ticks_msec() - session_started_ms})
