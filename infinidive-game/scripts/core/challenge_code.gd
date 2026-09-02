class_name ChallengeCode
extends RefCounted

const PREFIX := "ID1"
const ALLOWED_BOSSES := ["gravemaw", "seraph_9", "abyss_leviathan", "null_twin"]
const ALLOWED_WEAPONS := ["pulse_needle", "scatter_maw", "rail_spine", "arc_swarm", "void_orbitals"]
const ALLOWED_DIFFICULTIES := ["diver", "deep", "abyss"]
const COMPETITIVE_MODES := ["daily", "friend"]

## One versioned rules contract drives both the Daily Rift UI and runtime.
## Accessibility presentation preferences (for example reduced motion and
## contrast) remain personal, while every setting that can affect score/time is
## fixed so two players receive the same combat challenge.
const DAILY_STANDARD_RULES := {
	"id": "daily_standard_v1",
	"difficulty": "deep",
	"modifiers": ["daily_standard"],
	"assist_projectile_speed": 1.0,
	"assist_telegraph": 1.0,
	"assist_dash_window": 1.0,
	"aim_assist": true,
	"combat_upgrades_enabled": false,
}

static func daily_standard_rules() -> Dictionary:
	return DAILY_STANDARD_RULES.duplicate(true)

static func encode(challenge: Dictionary) -> String:
	var normalized := {
		"b": String(challenge.get("boss", "gravemaw")),
		"s": clampi(int(challenge.get("seed", 1)), 1, 2147483646),
		"w": String(challenge.get("weapon", "pulse_needle")),
		"d": String(challenge.get("difficulty", "diver")),
		"m": challenge.get("modifiers", []),
		"t": maxi(0, int(challenge.get("target_score", 0))),
		"r": maxi(0, int(challenge.get("target_time_ms", 0)))
	}
	var json := JSON.stringify(normalized)
	var payload := Marshalls.raw_to_base64(json.to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	return "%s.%s.%s" % [PREFIX, payload, json.sha256_text().left(7).to_upper()]

static func decode(code: String) -> Dictionary:
	var parts := code.strip_edges().split(".")
	if parts.size() != 3 or parts[0] != PREFIX or parts[1].length() > 512:
		return {}
	var payload := parts[1].replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var raw := Marshalls.base64_to_raw(payload)
	var json := raw.get_string_from_utf8()
	if json.sha256_text().left(7).to_upper() != parts[2]:
		return {}
	var value: Variant = JSON.parse_string(json)
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var packed: Dictionary = value
	var decoded := {
		"boss": String(packed.get("b", "")),
		"seed": int(packed.get("s", 0)),
		"weapon": String(packed.get("w", "")),
		"difficulty": String(packed.get("d", "")),
		"modifiers": packed.get("m", []),
		"target_score": maxi(0, int(packed.get("t", 0))),
		"target_time_ms": maxi(0, int(packed.get("r", 0)))
	}
	if not is_valid(decoded):
		return {}
	decoded.challenge_id = friend_challenge_id(decoded)
	return decoded

static func is_valid(challenge: Dictionary) -> bool:
	return (
		ALLOWED_BOSSES.has(String(challenge.get("boss", "")))
		and ALLOWED_WEAPONS.has(String(challenge.get("weapon", "")))
		and ALLOWED_DIFFICULTIES.has(String(challenge.get("difficulty", "")))
		and int(challenge.get("seed", 0)) > 0
		and typeof(challenge.get("modifiers", [])) == TYPE_ARRAY
		and (challenge.get("modifiers", []) as Array).size() <= 4
	)

static func daily_seed(date: Dictionary = {}) -> int:
	var use_date := date if not date.is_empty() else Time.get_date_dict_from_system(true)
	var key := "%04d-%02d-%02d-INFINIDIVE" % [int(use_date.year), int(use_date.month), int(use_date.day)]
	# Keep every deterministic hash inside the same validated seed range. Using
	# abs(hash) can exceed the upper bound for one signed-hash edge case.
	return posmod(key.hash(), 2147483646) + 1

static func utc_day_key(date: Dictionary = {}) -> String:
	# Time.get_date_dict_from_system(true) explicitly requests UTC. Keeping the
	# day in the run config means a retry after midnight remains on the same board.
	var use_date := date if not date.is_empty() else Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(use_date.get("year", 0)), int(use_date.get("month", 0)), int(use_date.get("day", 0))]

static func is_valid_utc_day(value: String) -> bool:
	if value.length() != 10 or value.substr(4, 1) != "-" or value.substr(7, 1) != "-":
		return false
	var year_text := value.substr(0, 4)
	var month_text := value.substr(5, 2)
	var day_text := value.substr(8, 2)
	if not year_text.is_valid_int() or not month_text.is_valid_int() or not day_text.is_valid_int():
		return false
	var year := int(year_text)
	var month := int(month_text)
	var day := int(day_text)
	if year < 2020 or year > 2200 or month < 1 or month > 12 or day < 1:
		return false
	var days_in_month := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var leap_year := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	if leap_year:
		days_in_month[1] = 29
	return day <= int(days_in_month[month - 1])

static func daily_challenge_id(challenge: Dictionary, utc_day: String = "") -> String:
	var day := utc_day if not utc_day.is_empty() else utc_day_key()
	if not is_valid_utc_day(day):
		return ""
	var rules := _canonical_identity_rules(challenge, false)
	var payload := {
		"utc_day": day,
		"seed": int(rules.seed),
		"boss": String(rules.boss),
		"weapon": String(rules.weapon),
		"difficulty": String(rules.difficulty),
		"modifiers": rules.modifiers
	}
	return "daily_%s_%s" % [day, JSON.stringify(payload, "", true).sha256_text().left(32)]

static func friend_challenge_id(challenge: Dictionary) -> String:
	var payload := _canonical_identity_rules(challenge, true)
	return "friend_%s" % JSON.stringify(payload, "", true).sha256_text().left(32)

static func canonical_challenge_id(mode: String, challenge: Dictionary, utc_day: String = "") -> String:
	match mode:
		"daily":
			return daily_challenge_id(challenge, utc_day)
		"friend":
			return friend_challenge_id(challenge)
		_:
			return ""

static func canonical_modifiers(raw: Variant) -> Array[String]:
	var modifiers: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return modifiers
	for value in raw as Array:
		modifiers.append(String(value))
	modifiers.sort()
	return modifiers

static func _canonical_identity_rules(challenge: Dictionary, include_targets: bool) -> Dictionary:
	var rules := {
		"boss": String(challenge.get("boss", challenge.get("boss_id", ""))),
		"seed": int(challenge.get("seed", 0)),
		"weapon": String(challenge.get("weapon", challenge.get("weapon_id", ""))),
		"difficulty": String(challenge.get("difficulty", "")),
		"modifiers": canonical_modifiers(challenge.get("modifiers", []))
	}
	if include_targets:
		rules.target_score = maxi(0, int(challenge.get("target_score", 0)))
		rules.target_time_ms = maxi(0, int(challenge.get("target_time_ms", 0)))
	return rules
