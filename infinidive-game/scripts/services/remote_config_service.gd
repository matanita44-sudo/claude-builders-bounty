extends Node

## Local, fail-closed feature configuration. This service intentionally has no
## HTTP client or vendor SDK. A future transport adapter can consume its
## snapshot, but changing JSON alone cannot start network traffic.

signal config_loaded(snapshot: Dictionary)

const CONFIG_PATH := "res://data/remote_config.json"
const FEATURE_DEFAULTS := {
	"backend_transport_enabled": false,
	"remote_config_transport_enabled": false,
	"analytics_transport_enabled": false,
	"leaderboard_remote_enabled": false,
	"daily_remote_sync_enabled": false,
	"friend_rift_remote_enabled": false,
	"cloud_save_enabled": false,
	"monetization_enabled": false,
	"ads_enabled": false,
	"iap_enabled": false,
	"rewarded_revive_enabled": false,
	"rewarded_bio_bonus_enabled": false
}
const LIMIT_DEFAULTS := {
	"offline_submission_queue": 256,
	"leaderboard_page_size": 50,
	"maximum_score": 50000000,
	"maximum_run_duration_ms": 14400000
}

var _snapshot: Dictionary = _safe_defaults()
var last_load_status := "not_loaded"

func _ready() -> void:
	load_local_config()

func load_local_config(path: String = CONFIG_PATH) -> bool:
	_snapshot = _safe_defaults()
	if not FileAccess.file_exists(path):
		last_load_status = "missing_using_safe_defaults"
		config_loaded.emit(export_snapshot())
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_load_status = "unreadable_using_safe_defaults"
		config_loaded.emit(export_snapshot())
		return false
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	if typeof(decoded) != TYPE_DICTIONARY:
		last_load_status = "invalid_using_safe_defaults"
		config_loaded.emit(export_snapshot())
		return false
	var source: Dictionary = decoded
	if int(source.get("schema_version", 0)) != 1:
		last_load_status = "unsupported_schema_using_safe_defaults"
		config_loaded.emit(export_snapshot())
		return false
	var raw_features: Variant = source.get("features", {})
	if typeof(raw_features) == TYPE_DICTIONARY:
		for key in FEATURE_DEFAULTS:
			var value: Variant = (raw_features as Dictionary).get(key, false)
			_snapshot.features[key] = value if typeof(value) == TYPE_BOOL else false
	var raw_limits: Variant = source.get("limits", {})
	if typeof(raw_limits) == TYPE_DICTIONARY:
		_snapshot.limits.offline_submission_queue = clampi(
			int((raw_limits as Dictionary).get("offline_submission_queue", LIMIT_DEFAULTS.offline_submission_queue)), 1, 2000
		)
		_snapshot.limits.leaderboard_page_size = clampi(
			int((raw_limits as Dictionary).get("leaderboard_page_size", LIMIT_DEFAULTS.leaderboard_page_size)), 1, 100
		)
		_snapshot.limits.maximum_score = clampi(
			int((raw_limits as Dictionary).get("maximum_score", LIMIT_DEFAULTS.maximum_score)), 1000, 100000000
		)
		_snapshot.limits.maximum_run_duration_ms = clampi(
			int((raw_limits as Dictionary).get("maximum_run_duration_ms", LIMIT_DEFAULTS.maximum_run_duration_ms)), 1000, 86400000
		)
	_snapshot.environment = String(source.get("environment", "production")).left(24)
	var raw_transport: Variant = source.get("transport", {})
	if typeof(raw_transport) == TYPE_DICTIONARY:
		_snapshot.transport = {
			"provider": String((raw_transport as Dictionary).get("provider", "none")).left(32),
			"endpoint": String((raw_transport as Dictionary).get("endpoint", "")).left(256)
		}
	last_load_status = "loaded_local"
	config_loaded.emit(export_snapshot())
	return true

func is_enabled(feature: String) -> bool:
	if not FEATURE_DEFAULTS.has(feature):
		return false
	return bool((_snapshot.get("features", {}) as Dictionary).get(feature, false))

func get_limit(limit_name: String) -> int:
	return int((_snapshot.get("limits", {}) as Dictionary).get(limit_name, 0))

func export_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func has_network_transport() -> bool:
	# There is deliberately no transport implementation in the launch client.
	# This remains false even if a malformed or locally edited config requests it.
	return false

static func _safe_defaults() -> Dictionary:
	return {
		"schema_version": 1,
		"environment": "production",
		"features": FEATURE_DEFAULTS.duplicate(true),
		"limits": LIMIT_DEFAULTS.duplicate(true),
		"transport": {"provider": "none", "endpoint": ""}
	}
