class_name RunScene
extends Node2D

const PermanentUpgradeEngineScript := preload("res://scripts/core/permanent_upgrade_engine.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const RoomMechanicsScript := preload("res://scripts/core/room_mechanics.gd")
const RoomPatternRuntimeScript := preload("res://scripts/core/room_pattern_runtime.gd")
const RoomSpaceScript := preload("res://scripts/core/room_space.gd")
const RoomDefenderEffectsScript := preload("res://scripts/core/room_defender_effects.gd")
const MetaGoalServiceScript := preload("res://scripts/services/meta_goal_service.gd")

signal run_finished(payload: Dictionary)

enum RunState {
	INTRO,
	EXTERIOR,
	BREACH_OPEN,
	ORGAN_SELECT,
	DIVING_IN,
	INTERNAL_ROOMS,
	ORGAN_CHAMBER,
	MUTATION_CHOICE,
	DIVING_OUT,
	CORE,
	DEAD,
	VICTORY
}

const STATE_TEXT_KEYS := {
	RunState.INTRO: "state_intro",
	RunState.EXTERIOR: "state_exterior",
	RunState.BREACH_OPEN: "state_breach_open",
	RunState.ORGAN_SELECT: "state_organ_select",
	RunState.DIVING_IN: "state_diving_in",
	RunState.INTERNAL_ROOMS: "state_internal_rooms",
	RunState.ORGAN_CHAMBER: "state_organ_chamber",
	RunState.MUTATION_CHOICE: "state_mutation_choice",
	RunState.DIVING_OUT: "state_diving_out",
	RunState.CORE: "state_core",
	RunState.DEAD: "state_dead",
	RunState.VICTORY: "state_victory"
}
const QA_STATE_NAMES := [
	"INTRO",
	"EXTERIOR",
	"BREACH_OPEN",
	"ORGAN_SELECT",
	"DIVING_IN",
	"INTERNAL_ROOMS",
	"ORGAN_CHAMBER",
	"MUTATION_CHOICE",
	"DIVING_OUT",
	"CORE",
	"DEAD",
	"VICTORY"
]
const QA_ABILITY_STATUSES := [
	OrganAbilityMap.STATUS_ACTIVE,
	OrganAbilityMap.STATUS_DEGRADED,
	OrganAbilityMap.STATUS_DISABLED
]

const WEAPON_BEHAVIORS := ["pulse", "scatter", "rail", "arc", "orbitals"]
const INTERNAL_DEFENDER_TELEGRAPH_SECONDS := 0.55
const INTERNAL_COMBAT_BOUNDS := Rect2(35.0, 390.0, 470.0, 430.0)
const ROOM_DEFENDER_COMBAT_WINDOW := 3.20
const ROOM_DEFENDER_ARMORED_WINDOW := 4.00
const ROOM_PROJECTILE_TELEGRAPH_HORIZON := 0.82
const ROOM_HISTORY_SAMPLE_SECONDS := 0.05
const ROOM_MOTIF_CLEARANCE_EPSILON := 0.5
const ROOM_MOTIF_SWEEP_MAX_SPATIAL_STEP := 0.5
const ROOM_MOTIF_SWEEP_MAX_SUBSTEPS := 8192
const ROOM_EXECUTION_CONTEXT_VERSION := 2
const ROOM_EMISSION_CONTEXT_VERSION := 1
const MUTATION_CATALOG_COMPLETE_BIO_REWARD := 120
const ROOM_EFFECT_TIMER_BY_FLAG := {
	"orbit_interrupted":"orbit_interrupt_seconds",
	"pincer_side_broken":"priority_mark_seconds",
	"cover_created":"cover_seconds",
	"prism_cover_created":"prism_cover_seconds",
	"tracking_disabled":"tracking_disabled_seconds",
	"emitter_silenced":"emitter_silenced_seconds",
	"link_broken":"link_broken_seconds",
	"hatch_suppressed":"hatch_suppressed_seconds",
	"echo_disrupted":"echo_disrupted_seconds",
	"true_target_revealed":"true_target_revealed_seconds",
}
const COMBAT_SFX_INTERVALS := {
	"armor_hit": 0.075,
	"organ_damage": 0.09,
	"boss_phase": 0.45
}
const WEAPON_SYNERGY_TAGS := {
	"pulse": ["projectile", "timing", "critical", "skill"],
	"scatter": ["close", "multi", "risk"],
	"rail": ["pierce", "exterior", "boss"],
	"arc": ["internal", "projectile", "organ"],
	"orbitals": ["orbital", "defense", "close", "shield"]
}

static var _room_runtime_catalog_checked := false
static var _room_runtime_catalog_errors := PackedStringArray()

var config: Dictionary = {}
var boss_definition: Dictionary = {}
var weapon_definition: Dictionary = {}
var state := RunState.INTRO
var previous_state := RunState.INTRO
var phase := 0
var elapsed := 0.0
var score := 0
var run_bio := 0
var organs_destroyed := 0
var run_id := ""

var armor_health := 1.0
var armor_max := 1.0
var core_health := 1.0
var core_max := 1.0
var organ_health := 1.0
var organ_max := 1.0
var current_organ: Dictionary = {}
var current_room: Dictionary = {}
var room_layout: Array[Dictionary] = []
var room_index := -1
var room_timer := 0.0
var transition_timer := 0.0
var attack_timer := 1.6
var fire_timer := 0.0
var internal_spawn_timer := 0.0
var breach_fury_timer := 0.0
var breach_timer := 0.0
var phase_open_timer := 0.0
var hit_stop_timer := 0.0
var world_shake := 0.0
var shot_count := 0
var shot_streak := 0
var calm_timer := 0.0
var wound_memory_timer := 0.0
var _paused := false
var _result: Dictionary = {}
var _result_banked := false
var _first_shot_sent := false
var _first_damage_sent := false
var _first_dash_sent := false
var _first_breach_sent := false
var _first_dive_sent := false

var _world: Node2D
var _player: PlayerController
var _projectiles: ProjectilePool
var _boss_visual: BossVisual
var _hud: RunHUD
var _rng := RandomNumberGenerator.new()
var _organ_map := OrganAbilityMap.new()
var _mutation_engine := MutationEngine.new()
var _tutorial_flow := TutorialFlowScript.new()
var _meta_goals := MetaGoalServiceScript.new()
var _room_generator := RoomGenerator.new()
var _room_contract: Dictionary = {}
var _room_pattern_plan: Dictionary = {}
var _room_pattern_rejection_key := ""
var _room_elapsed := 0.0
var _room_event_index := 0
var _room_cycle_index := 0
var _active_room_waves: Dictionary = {}
var _active_room_actor_groups: Dictionary = {}
var _active_room_motifs: Dictionary = {}
var _pending_room_emissions: Array[Dictionary] = []
var _room_player_history: Array[Dictionary] = []
var _room_history_next_sample := 0.0
var _room_history_frame_time := 0.0
var _room_history_frame_position := Vector2.ZERO
var _room_history_initialized := false
var _room_previous_player_position := Vector2.ZERO
var _room_runtime_trace: Array[Dictionary] = []
var _room_defender_effect_state: Dictionary = {}
var _room_defender_effect_events: Dictionary = {}
var _room_defender_effect_sources: Dictionary = {}
var _room_defender_covers: Array[Dictionary] = []
var _room_defender_kill_sequence := 0
var _enemies: Array[Dictionary] = []
var _enemy_serial := 0
var _telegraph: Dictionary = {}
var _pending_echoes: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _permanent_stats: Dictionary = {}
var _selected_mutations: Array[String] = []
var _offered_mutation_ids: Array[String] = []
var _remaining_rerolls := 0
var _mutation_choice_count := 0
var _phase_first_hit_available := true
var _organ_hit_count := 0
var _bio_pickups: Array[Dictionary] = []
var _bio_since_shield := 0
var _damage_taken_total := 0.0
var _dash_count := 0
var _target_hit_count := 0
var _peak_projectiles := 0
var _tutorial_start_position := Vector2.ZERO
var _tutorial_movement_seen := false
var _meta_dirty := false
var _last_perfect_dash_count := 0
var _orbit_growth := 0.0
var _dash_wakes: Array[Dictionary] = []
var _dash_wake_serial := 0
var _active_dash_wake_id := 0
var _last_dash_wake_position := Vector2.ZERO
var _dash_wake_hits: Dictionary = {}
var _boss_attack_serial := 0
var _attack_avoidance_candidates: Dictionary = {}
var _combat_sfx_last_played: Dictionary = {}

static func validate_weapon_definition(weapon: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := String(weapon.get("id", "?"))
	var behavior := String(weapon.get("behavior", ""))
	if behavior not in WEAPON_BEHAVIORS:
		errors.append("Weapon %s has unsupported behavior %s" % [id, behavior])
		return errors
	for key in ["damage", "fire_interval", "projectile_speed", "lifetime"]:
		var value: Variant = weapon.get(key, null)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) <= 0.0:
			errors.append("Weapon %s requires positive %s" % [id, key])
	if int(weapon.get("projectile_count", 0)) <= 0:
		errors.append("Weapon %s must fire at least one projectile" % id)
	match behavior:
		"pulse":
			if int(weapon.get("projectile_count", 0)) != 1 or float(weapon.get("spread", 0.0)) != 0.0:
				errors.append("Pulse weapon %s must be a precise single projectile" % id)
		"scatter":
			if int(weapon.get("projectile_count", 0)) < 3 or float(weapon.get("spread", 0.0)) <= 0.0:
				errors.append("Scatter weapon %s requires a multi-projectile spread" % id)
			if float(weapon.get("falloff_start", 0.0)) <= 0.0 or float(weapon.get("falloff_end", 0.0)) <= float(weapon.get("falloff_start", 0.0)):
				errors.append("Scatter weapon %s requires an ordered falloff range" % id)
			if float(weapon.get("falloff_min", 0.0)) <= 0.0 or float(weapon.get("falloff_min", 0.0)) >= 1.0:
				errors.append("Scatter weapon %s requires falloff_min between zero and one" % id)
		"rail":
			if int(weapon.get("pierce", 0)) < 1 or int(weapon.get("projectile_count", 0)) != 1:
				errors.append("Rail weapon %s requires one piercing projectile" % id)
		"arc":
			if int(weapon.get("chain", 0)) < 2 or float(weapon.get("chain_range", 0.0)) <= 0.0:
				errors.append("Arc weapon %s requires multiple bounded chain hops" % id)
			if float(weapon.get("chain_damage_mul", 0.0)) <= 0.0 or float(weapon.get("chain_damage_mul", 0.0)) >= 1.0:
				errors.append("Arc weapon %s requires a reduced chain damage multiplier" % id)
		"orbitals":
			if int(weapon.get("orbitals", 0)) < 1 or float(weapon.get("orbital_dps_mul", 0.0)) <= 0.0:
				errors.append("Orbital weapon %s requires contact orbitals" % id)
			if not bool(weapon.get("absorbs_projectiles", false)):
				errors.append("Orbital weapon %s must consume nearby hostile shots" % id)
	return errors

static func validate_weapon_catalog(weapons: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_behaviors: Dictionary = {}
	for raw_weapon in weapons:
		if typeof(raw_weapon) != TYPE_DICTIONARY:
			errors.append("Weapon catalog contains a non-dictionary entry")
			continue
		var weapon := raw_weapon as Dictionary
		errors.append_array(validate_weapon_definition(weapon))
		var behavior := String(weapon.get("behavior", ""))
		if seen_behaviors.has(behavior):
			errors.append("Weapon behavior %s is duplicated" % behavior)
		seen_behaviors[behavior] = true
	return errors

static func weapon_range_multiplier(weapon: Dictionary, distance: float) -> float:
	if String(weapon.get("behavior", "")) != "scatter":
		return 1.0
	var start := float(weapon.get("falloff_start", 0.0))
	var end := maxf(start + 1.0, float(weapon.get("falloff_end", start + 1.0)))
	var ratio := clampf((distance - start) / (end - start), 0.0, 1.0)
	return lerpf(1.0, float(weapon.get("falloff_min", 1.0)), ratio)

static func effective_fire_interval(base_interval: float, health_ratio: float, mutation_flags: Dictionary, breach_active: bool) -> float:
	var interval:=base_interval
	if health_ratio<0.35:
		interval/=float(mutation_flags.get("low_health_rate_mul",1.0))
	if breach_active:
		interval/=float(mutation_flags.get("breach_rate_mul",1.0))
	return maxf(0.055,interval)

static func evaluate_friend_target(final_score: int, duration_ms: int, won: bool, target_score: int, target_time_ms: int) -> Dictionary:
	var has_score := target_score > 0
	var has_time := target_time_ms > 0
	var score_met := has_score and final_score >= target_score
	var time_met := has_time and won and duration_ms <= target_time_ms
	return {
		"has_target": has_score or has_time,
		"score_met": score_met,
		"time_met": time_met,
		"met": score_met or time_met
	}

static func dive_transition_visual_radius(state_value: int, timer_seconds: float, reduced_motion: bool) -> float:
	# Reduced Motion keeps a stable tunnel frame while the state/timing remains
	# unchanged. Normal rendering expands/contracts across the complete visual
	# range and uses the actual duration of each transition direction.
	if reduced_motion:
		return 260.0
	var duration := 1.15 if state_value==RunState.DIVING_IN else 1.0
	var ratio := clampf(timer_seconds/maxf(0.01,duration),0.0,1.0)
	return (1.0-ratio)*650.0 if state_value==RunState.DIVING_IN else ratio*650.0

static func should_emit_rate_limited_sfx(last_played: Dictionary, sfx_id: String, now_seconds: float, minimum_interval: float) -> bool:
	if sfx_id.is_empty():
		return false
	var safe_interval := maxf(0.0, minimum_interval)
	if last_played.has(sfx_id) and now_seconds - float(last_played[sfx_id]) + 0.000001 < safe_interval:
		return false
	last_played[sfx_id] = now_seconds
	return true

static func basic_rupture_attack_contract() -> Dictionary:
	return {
		"ability_id":"basic_rupture",
		"status":OrganAbilityMap.STATUS_ACTIVE,
		"variant":"intact",
		"telegraph_multiplier":1.0,
		"pattern":{"family":"ring","safe_arc_radians":0.45}
	}

static func build_degraded_attack_specs(attack_contract: Dictionary, origin: Vector2, player_position: Vector2, safe_angle: float, projectile_speed_multiplier: float = 1.0) -> Dictionary:
	var result := {
		"valid": false,
		"ability_id": String(attack_contract.get("ability_id", "")),
		"variant": String(attack_contract.get("variant", "")),
		"family": "",
		"projectiles": [],
		"safe_angle": safe_angle,
		"gap_x": -1.0
	}
	if String(attack_contract.get("status", "")) != OrganAbilityMap.STATUS_DEGRADED:
		return result
	var pattern_value: Variant = attack_contract.get("pattern", null)
	if typeof(pattern_value) != TYPE_DICTIONARY:
		return result
	var pattern := pattern_value as Dictionary
	var family := String(pattern.get("family", ""))
	if family not in OrganAbilityMap.VALID_PATTERN_FAMILIES:
		return result
	var speed := clampf(float(pattern.get("speed", 180.0)), 90.0, 500.0) * clampf(projectile_speed_multiplier, 0.5, 2.0)
	var damage := clampf(float(pattern.get("damage", 8.0)), 1.0, 20.0)
	var cause_id := "ability:%s" % String(attack_contract.get("ability_id", "basic_rupture"))
	var player_angle := (player_position-origin).angle()
	var projectile_specs: Array[Dictionary] = []
	match family:
		"aimed_fan":
			var count := clampi(int(pattern.get("count", 1)), 1, 5)
			var spread := clampf(float(pattern.get("spread_radians", 0.0)), 0.0, 0.42)
			for index in count:
				var centered_index := float(index)-float(count-1)*0.5
				projectile_specs.append({
					"origin": origin,
					"velocity": Vector2.from_angle(player_angle+centered_index*spread)*speed,
					"damage": damage,
					"options": {"radius":5.8,"cause":cause_id}
				})
		"ring":
			var count := clampi(int(pattern.get("count", 12)), 6, 20)
			var safe_arc := clampf(float(pattern.get("safe_arc_radians", 0.72)), 0.65, 1.4)
			for index in count:
				var angle := index*TAU/float(count)
				if absf(wrapf(angle-safe_angle,-PI,PI)) < safe_arc:
					continue
				projectile_specs.append({
					"origin": origin,
					"velocity": Vector2.from_angle(angle)*speed,
					"damage": damage,
					"options": {"radius":6.0,"cause":cause_id}
				})
		"lane":
			var step := clampi(int(pattern.get("step", 38)), 32, 64)
			var gap_half_width := clampf(float(pattern.get("gap_half_width", 90.0)), 72.0, 140.0)
			var safe_flank := -1 if int(pattern.get("safe_flank", 1)) < 0 else 1
			var gap_x := 68.0 if safe_flank < 0 else 472.0
			result.gap_x = gap_x
			for x in range(22,519,step):
				if absf(float(x)-gap_x) < gap_half_width:
					continue
				projectile_specs.append({
					"origin": Vector2(float(x),260.0),
					"velocity": Vector2(0.0,speed),
					"damage": damage,
					"options": {"shape":"wall","radius":8.0,"cause":cause_id}
				})
	result.valid = not projectile_specs.is_empty()
	result.family = family
	result.projectiles = projectile_specs
	return result

func initialize(run_config: Dictionary) -> void:
	config = run_config.duplicate(true)

func qa_snapshot() -> Dictionary:
	var player_position := Vector2.ZERO
	var player_state_present := false
	var controls_active := false
	var dash_time := 0.0
	var dash_charges := 0
	var dash_max_charges := 0
	var dash_recharge := 0.0
	var dash_cooldown := 0.0
	var dash_ratio := 0.0
	if is_instance_valid(_player):
		player_state_present = true
		player_position = _player.position
		controls_active = _player.controls_active
		dash_time = _player.dash_time
		dash_charges = _player.dash_charges
		dash_max_charges = _player.max_dash_charges
		dash_recharge = _player.dash_recharge
		dash_cooldown = _player.dash_cooldown
		dash_ratio = _player.dash_ratio()
	var state_index := int(state)
	var state_valid := state_index >= 0 and state_index < QA_STATE_NAMES.size()
	var state_name: String = QA_STATE_NAMES[state_index] if state_valid else "INVALID"
	var numeric_state_valid := (
		state_valid
		and player_state_present
		and is_finite(player_position.x)
		and is_finite(player_position.y)
		and _dash_count >= 0
		and is_finite(dash_time)
		and dash_time >= 0.0
		and dash_charges >= 0
		and dash_max_charges >= 1
		and dash_charges <= dash_max_charges
		and is_finite(dash_recharge)
		and dash_recharge >= 0.0
		and is_finite(dash_cooldown)
		and dash_cooldown > 0.0
		and is_finite(dash_ratio)
		and dash_ratio >= 0.0
		and dash_ratio <= 1.0
		and is_finite(elapsed)
		and elapsed >= 0.0
	)
	var organ := _qa_organ_snapshot(state_name)
	var player_health_ratio: Variant = null
	if is_instance_valid(_player):
		player_health_ratio = qa_ratio(_player.health, _player.max_health)
	return {
		"view":"run",
		"run_identity_present":not run_id.is_empty(),
		"state":state_name,
		"state_valid":state_valid,
		"numeric_state_valid":numeric_state_valid,
		"player_position":[_qa_json_number(player_position.x), _qa_json_number(player_position.y)],
		"controls_active":controls_active,
		"movement_observed":_tutorial_movement_seen,
		"dash_count":_dash_count,
		"dash_time":_qa_json_number(dash_time),
		"dash_charges":dash_charges,
		"dash_max_charges":dash_max_charges,
		"dash_recharge":_qa_json_number(dash_recharge),
		"dash_cooldown":_qa_json_number(dash_cooldown),
		"dash_ratio":_qa_json_number(dash_ratio),
		"elapsed":_qa_json_number(elapsed),
		"phase":_qa_bounded_integer(phase, 0, 3),
		"health":{
			"player_ratio":player_health_ratio,
			"target_ratio":_qa_target_health_ratio(state_name)
		},
		"organ":organ,
		"ability":_qa_ability_snapshot(organ),
		"boss_visual_state":_qa_boss_visual_state(state_name, organ),
		"mutation":_qa_mutation_snapshot()
	}

static func _qa_json_number(value: float) -> Variant:
	return value if is_finite(value) else null

func _qa_organ_snapshot(state_name: String) -> Dictionary:
	var snapshot := {"id": null, "status": null, "health_ratio": null}
	if _organ_map == null or current_organ.is_empty():
		return snapshot
	var organ_id := String(current_organ.get("id", ""))
	if organ_id.is_empty() or not _organ_map.organs.has(organ_id):
		return snapshot
	snapshot.id = organ_id
	snapshot.status = "destroyed" if _organ_map.destroyed_organs().has(organ_id) else "selected"
	if state_name == "ORGAN_CHAMBER" or snapshot.status == "destroyed":
		snapshot.health_ratio = qa_ratio(organ_health, organ_max)
	return snapshot

func _qa_ability_snapshot(organ: Dictionary) -> Dictionary:
	var snapshot := {"id": null, "status": null}
	var organ_id := String(organ.get("id", ""))
	if organ_id.is_empty() or _organ_map == null:
		return snapshot
	var organ_state_value: Variant = _organ_map.organs.get(organ_id, null)
	if typeof(organ_state_value) != TYPE_DICTIONARY:
		return snapshot
	var ability_id := String((organ_state_value as Dictionary).get("ability", ""))
	if ability_id.is_empty() or not _organ_map.abilities.has(ability_id):
		return snapshot
	var ability_status := _organ_map.ability_status(ability_id)
	if ability_status not in QA_ABILITY_STATUSES:
		return snapshot
	snapshot.id = ability_id
	snapshot.status = ability_status
	return snapshot

func _qa_boss_visual_state(state_name: String, organ: Dictionary) -> Variant:
	if state_name not in ["EXTERIOR", "CORE"] or String(organ.get("status", "")) != "destroyed":
		return null
	if not is_instance_valid(_boss_visual) or _boss_visual.mode != "exterior":
		return null
	var visual_token := _boss_visual.visual_state_for_organ(String(organ.get("id", "")))
	return visual_token if BossVisual.supports_visual_token(visual_token) else null

func _qa_mutation_snapshot() -> Dictionary:
	var offered_count: Variant = _qa_mutation_id_count(_offered_mutation_ids, 3)
	var applied_ids: Variant = _mutation_engine.selected_ids if _mutation_engine != null else null
	var selected_count: Variant = _qa_mutation_id_count(applied_ids, GameData.mutations.size())
	var last_selected_id: Variant = null
	if selected_count != null and int(selected_count) > 0:
		var candidate := String((applied_ids as Array)[-1])
		if not GameData.get_mutation(candidate).is_empty():
			last_selected_id = candidate
	return {
		"offered_count":offered_count,
		"selected_count":selected_count,
		"last_selected_id":last_selected_id
	}

func _qa_target_health_ratio(state_name: String) -> Variant:
	match state_name:
		"EXTERIOR":
			return qa_ratio(armor_health, armor_max)
		"ORGAN_CHAMBER":
			return qa_ratio(organ_health, organ_max)
		"CORE":
			return qa_ratio(core_health, core_max)
		_:
			return null

func _qa_mutation_id_count(raw_ids: Variant, maximum: int) -> Variant:
	if typeof(raw_ids) != TYPE_ARRAY:
		return null
	var ids := raw_ids as Array
	if ids.size() > maximum:
		return null
	var seen: Dictionary = {}
	for raw_id in ids:
		if typeof(raw_id) != TYPE_STRING:
			return null
		var mutation_id := String(raw_id)
		if mutation_id.is_empty() or seen.has(mutation_id) or GameData.get_mutation(mutation_id).is_empty():
			return null
		seen[mutation_id] = true
	return ids.size()

static func _qa_bounded_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return null
	var numeric := float(value)
	if not is_finite(numeric) or numeric != floor(numeric):
		return null
	var integer := int(numeric)
	return integer if integer >= minimum and integer <= maximum else null

static func qa_ratio(current: Variant, maximum: Variant) -> Variant:
	if typeof(current) not in [TYPE_INT, TYPE_FLOAT] or typeof(maximum) not in [TYPE_INT, TYPE_FLOAT]:
		return null
	var current_value := float(current)
	var maximum_value := float(maximum)
	if (
		not is_finite(current_value)
		or not is_finite(maximum_value)
		or maximum_value <= 0.0
		or current_value < 0.0
		or current_value > maximum_value
	):
		return null
	return current_value / maximum_value

func _ready() -> void:
	_apply_config_defaults()
	_mutation_choice_count = maxi(0, int(config.get("mutation_choice_count", 0)))
	boss_definition = GameData.get_boss(String(config.boss))
	weapon_definition = GameData.get_weapon(String(config.weapon))
	if boss_definition.is_empty():
		boss_definition = GameData.bosses[0].duplicate(true)
	AudioManager.set_boss_identity(String(boss_definition.get("id", "gravemaw")))
	if weapon_definition.is_empty():
		weapon_definition = GameData.weapons[0].duplicate(true)
	var mutation_errors:=MutationEngine.validate_catalog(GameData.mutations)
	if not mutation_errors.is_empty():
		push_error("Invalid mutation catalog: %s" % "; ".join(mutation_errors))
	var weapon_errors := validate_weapon_definition(weapon_definition)
	if not weapon_errors.is_empty():
		push_error("Invalid weapon definition: %s" % "; ".join(weapon_errors))
		weapon_definition = GameData.weapons[0].duplicate(true)
	var room_errors := RoomMechanicsScript.validate_catalog(GameData.rooms, true)
	if not room_errors.is_empty():
		push_error("Invalid room mechanics catalog: %s" % "; ".join(room_errors))
	if not _room_runtime_catalog_checked:
		_room_runtime_catalog_errors = RoomPatternRuntimeScript.validate_catalog(GameData.rooms)
		_room_runtime_catalog_checked = true
	if not _room_runtime_catalog_errors.is_empty():
		push_error("Invalid room runtime catalog: %s" % "; ".join(_room_runtime_catalog_errors))
	_rng.seed = int(config.seed)
	run_id = "%d-%d-%d-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), int(config.seed), String(config.boss)]
	if not _meta_goals.initialize(SaveManager.profile):
		push_error("Invalid meta-goal catalogs: %s" % "; ".join(_meta_goals.get_validation_errors()))
	_meta_dirty = _meta_goals.has_pending_profile_changes()
	_organ_map.initialize(boss_definition)
	_permanent_stats = _build_permanent_stats()
	_remaining_rerolls = maxi(0, int(_permanent_stats.get("starting_rerolls", 0)))
	_mutation_engine.initialize(int(config.seed) ^ 0x2f19, {
		"damage_mul": 1.0,
		"armor_damage_mul": 1.0,
		"organ_damage_mul": 1.0,
		"external_damage_mul": 1.0,
		"projectile_speed_mul": 1.0,
		"dash_cooldown_mul": 1.0,
		"max_health_mul": 1.0,
		"magnet_mul": 1.0,
		"breach_reward_mul": 1.0,
		"projectile_count_add": 0,
		"pierce_add": 0,
		"orbitals_add": 0,
		"max_health_add": 0,
		"dash_charges_add": 0
	})
	for carried_id in config.get("carried_mutations",[]):
		var carried := GameData.get_mutation(String(carried_id))
		if not carried.is_empty() and _mutation_engine.apply(carried):
			_selected_mutations.append(String(carried_id))
	_make_stars()
	_build_world()
	_setup_tutorial()
	_start_phase(0)
	_transition(RunState.INTRO)
	transition_timer = 1.15
	AudioManager.set_music_state("exterior",0.25)
	_show_tutorial_prompt(_tutorial_flow.current_prompt())

func _setup_tutorial() -> void:
	_tutorial_start_position = _player.position
	_tutorial_flow.restore_state(SaveManager.profile.get("tutorial_state", {"version":1,"understood_mask":0}))
	_tutorial_flow.prompt_changed.connect(_show_tutorial_prompt)
	_tutorial_flow.flow_completed.connect(func(): AnalyticsService.track("tutorial_complete"))
	if bool(SaveManager.profile.get("tutorial_replay_requested", false)):
		_tutorial_flow.begin_replay()
		SaveManager.profile.tutorial_replay_requested = false
		SaveManager.profile.tutorial_presentation = _tutorial_flow.serialize_presentation()
		SaveManager.save_profile()
	else:
		_tutorial_flow.restore_presentation(SaveManager.profile.get("tutorial_presentation", {"version":1,"replay_active":false,"replay_mask":0}))
	if not _tutorial_flow.is_complete() or _tutorial_flow.is_replaying():
		AnalyticsService.track("tutorial_start", {"replay":_tutorial_flow.is_replaying()})

func _show_tutorial_prompt(prompt: Dictionary) -> void:
	if _hud == null:
		return
	if prompt.is_empty():
		_hud.set_tutorial_prompt("")
		return
	_hud.set_tutorial_prompt(LocalizationService.text(String(prompt.get("message_key", ""))), VisualTheme.FRIENDLY)

func _tutorial_observe(event_id: StringName) -> void:
	var was_replaying := _tutorial_flow.is_replaying()
	if not _tutorial_flow.observe_event(event_id):
		return
	var state_payload: Dictionary = _tutorial_flow.serialize_state()
	SaveManager.profile.tutorial_state = state_payload
	SaveManager.profile.tutorial_presentation = _tutorial_flow.serialize_presentation()
	SaveManager.profile.tutorial_step = _tutorial_flow.understood_count()
	SaveManager.profile.tutorial_complete = _tutorial_flow.is_complete()
	SaveManager.save_profile()
	AnalyticsService.track("tutorial_step", {"step":TutorialFlowScript.step_index_for_event(event_id)+1,"event":String(event_id),"replay":was_replaying})

func _meta_progress(event_name: String, payload: Dictionary, persist_now: bool = false) -> Dictionary:
	var result: Dictionary = _meta_goals.progress(event_name, payload)
	if bool(result.get("needs_persist", false)):
		_meta_dirty = true
	if bool(result.get("changed", false)):
		var reward: Dictionary = result.get("reward", {})
		var bio := int(reward.get("bio_matter", 0))
		var shards := int(reward.get("core_shards", 0))
		if (bio > 0 or shards > 0) and _hud != null:
			_hud.show_toast(LocalizationService.text("meta_reward", {"bio":bio,"shards":shards}), VisualTheme.BIO)
	if persist_now and _meta_dirty:
		_persist_meta_profile()
	return result

func _persist_meta_profile(force_write: bool = false) -> bool:
	if not _meta_dirty and not force_write:
		return true
	if not SaveManager.save_profile():
		return false
	if _meta_dirty:
		_meta_goals.mark_profile_persisted()
	_meta_dirty = false
	return true

func _apply_config_defaults() -> void:
	var defaults := {
		"boss": "gravemaw",
		"weapon": String(SaveManager.profile.get("selected_weapon","pulse_needle")),
		"difficulty": "diver",
		"seed": randi_range(1,2147483000),
		"mode": "story",
		"modifiers": [],
		"competitive": false,
		"abyss_depth": 0
	}
	for key in defaults:
		if not config.has(key):
			config[key] = defaults[key]
	# Competitive policy is derived from the mode, never trusted from a caller.
	# Daily/Friend use one fixed assist profile; Story/Abyss remain personal play.
	config.competitive = String(config.mode) in ["daily", "friend"]
	if String(config.mode) == "daily":
		var utc_day := String(config.get("challenge_day_utc", ""))
		if not ChallengeCode.is_valid_utc_day(utc_day):
			utc_day = ChallengeCode.utc_day_key()
		config.challenge_day_utc = utc_day
		config.challenge_id = ChallengeCode.daily_challenge_id(config, utc_day)
	elif String(config.mode) == "friend":
		config.challenge_day_utc = ""
		config.challenge_id = ChallengeCode.friend_challenge_id(config)
	else:
		config.challenge_day_utc = ""
		config.challenge_id = ""

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_boss_visual = BossVisual.new()
	_boss_visual.position = Vector2(270,170)
	_boss_visual.setup(boss_definition)
	_world.add_child(_boss_visual)
	_projectiles = ProjectilePool.new()
	_world.add_child(_projectiles)
	_player = PlayerController.new()
	_player.position = Vector2(270,790)
	_player.combat_bounds = Rect2(24,395,492,450)
	_player.configure({
		"max_health": _mutated_max_health(),
		"responsiveness": 9.0 + float(SettingsManager.get_value("control_sensitivity",0.72))*7.0,
		"dash_cooldown": _mutated_dash_cooldown(),
		"dash_invulnerability": float(_permanent_stats.dash_invulnerability) * _assist_number("assist_dash_window",1.0),
		"dash_charges": _mutated_dash_charges(),
		"starting_shield": _permanent_stats.starting_shield
	})
	_player.died.connect(_on_player_died)
	_player.damaged.connect(_on_player_damaged)
	_player.dash_started.connect(_on_dash_started)
	_player.dash_gesture_requested.connect(_request_directional_dash)
	_player.dash_ready.connect(func(): AudioManager.play_sfx("dash_ready",1.0,0.55))
	_world.add_child(_player)
	if config.has("starting_health_ratio"):
		_player.health = _player.max_health * clampf(float(config.starting_health_ratio),0.25,1.0)
	_hud = RunHUD.new()
	add_child(_hud)
	_hud.dash_pressed.connect(_request_dash)
	_hud.dive_pressed.connect(_request_dive)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.organ_selected.connect(_select_organ)
	_hud.mutation_selected.connect(_select_mutation)
	_hud.mutation_reroll_requested.connect(_reroll_mutations)
	_hud.result_action.connect(_on_result_action)

func _build_permanent_stats() -> Dictionary:
	var engine := PermanentUpgradeEngineScript.new()
	var owned: Dictionary = SaveManager.profile.get("upgrades", {})
	if not engine.initialize(GameData.upgrades, owned, bool(config.get("competitive", false))):
		push_error("Invalid permanent-upgrade catalog: %s" % "; ".join(engine.validation_errors))
	return engine.export_stats()

func _mutated_max_health() -> float:
	return maxf(1.0, (float(_permanent_stats.max_health) + float(_mutation_engine.stats.get("max_health_add", 0.0))) * float(_mutation_engine.stats.get("max_health_mul", 1.0)))

func _mutated_dash_cooldown() -> float:
	return maxf(0.1, float(_permanent_stats.dash_cooldown) * float(_mutation_engine.stats.get("dash_cooldown_mul", 1.0)))

func _mutated_dash_charges() -> int:
	return maxi(1, int(_permanent_stats.dash_charges) + int(_mutation_engine.stats.get("dash_charges_add", 0)))

func _sync_player_mutation_stats(new_effects: Dictionary = {}) -> void:
	if _player == null:
		return
	var old_cooldown := maxf(0.01, _player.dash_cooldown)
	var recharge_ratio := _player.dash_recharge / old_cooldown
	var old_charge_cap := _player.max_dash_charges
	_player.max_health = _mutated_max_health()
	_player.health = minf(_player.health, _player.max_health)
	_player.dash_cooldown = _mutated_dash_cooldown()
	_player.dash_recharge = clampf(recharge_ratio * _player.dash_cooldown, 0.0, _player.dash_cooldown)
	_player.max_dash_charges = _mutated_dash_charges()
	if _player.max_dash_charges > old_charge_cap:
		_player.dash_charges += _player.max_dash_charges - old_charge_cap
	_player.dash_charges = clampi(_player.dash_charges, 0, _player.max_dash_charges)
	if new_effects.has("heal_now"):
		_player.heal(float(new_effects.heal_now))
	_player.queue_redraw()

func _make_stars() -> void:
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = int(config.seed) ^ 0x671a
	for index in 82:
		_stars.append({"position":Vector2(star_rng.randf_range(0,540),star_rng.randf_range(0,960)),"size":star_rng.randf_range(0.7,2.2),"phase":star_rng.randf_range(0,TAU)})

func _physics_process(delta: float) -> void:
	if _paused or state in [RunState.ORGAN_SELECT,RunState.MUTATION_CHOICE,RunState.DEAD,RunState.VICTORY]:
		return
	if hit_stop_timer > 0.0:
		hit_stop_timer -= delta
		return
	if not _tutorial_movement_seen and _player.position.distance_to(_tutorial_start_position) >= 12.0:
		_tutorial_movement_seen = true
		_tutorial_observe(TutorialFlowScript.EVENT_MOVEMENT_STARTED)
	elapsed += delta
	breach_fury_timer = maxf(0.0,breach_fury_timer-delta)
	if state in [RunState.EXTERIOR, RunState.CORE]:
		phase_open_timer = maxf(0.0, phase_open_timer - delta)
	if world_shake > 0.05 and not bool(SettingsManager.get_value("reduced_motion",false)):
		var strength := world_shake * float(SettingsManager.get_value("screen_shake",0.7))
		_world.position = Vector2(_rng.randf_range(-strength,strength),_rng.randf_range(-strength,strength))
		world_shake *= pow(0.025,delta)
	else:
		_world.position = Vector2.ZERO
		world_shake = 0.0
	match state:
		RunState.INTRO:
			transition_timer -= delta
			if transition_timer <= 0.0:
				_transition(RunState.EXTERIOR)
		RunState.EXTERIOR, RunState.CORE:
			_update_combat(delta,true)
		RunState.BREACH_OPEN:
			_update_player_only(delta)
			breach_timer = maxf(0.0, breach_timer - delta)
			if breach_timer <= 0.0:
				_close_breach()
		RunState.DIVING_IN:
			transition_timer -= delta
			if transition_timer <= 0.0:
				_begin_internal_route()
		RunState.INTERNAL_ROOMS:
			_update_combat(delta,false)
			if state == RunState.INTERNAL_ROOMS:
				_update_room(delta)
		RunState.ORGAN_CHAMBER:
			_update_combat(delta,false)
		RunState.DIVING_OUT:
			transition_timer -= delta
			if transition_timer <= 0.0:
				_return_outside()
	_update_pending_echoes(delta)
	if _projectiles != null:
		_peak_projectiles = maxi(_peak_projectiles, _projectiles.player_active.size() + _projectiles.enemy_active.size())
	_sync_adaptive_music()
	queue_redraw()

func _sync_adaptive_music() -> void:
	if _player == null or state in [RunState.DEAD, RunState.VICTORY]:
		return
	var desired := "exterior"
	var intensity := clampf(0.3 + phase * 0.18, 0.0, 1.0)
	if _player.health_ratio() <= 0.28 and state in [RunState.EXTERIOR, RunState.BREACH_OPEN, RunState.DIVING_IN, RunState.INTERNAL_ROOMS, RunState.ORGAN_CHAMBER, RunState.DIVING_OUT, RunState.CORE]:
		desired = "low_health"
		intensity = 0.92
	else:
		match state:
			RunState.BREACH_OPEN, RunState.ORGAN_SELECT:
				desired = "breach"
				intensity = 0.75
			RunState.DIVING_IN, RunState.DIVING_OUT:
				desired = "dive"
				intensity = 0.72
			RunState.INTERNAL_ROOMS:
				desired = "interior"
				intensity = 0.55
			RunState.ORGAN_CHAMBER, RunState.MUTATION_CHOICE:
				desired = "organ"
				intensity = 0.72
			RunState.CORE:
				desired = "core"
				intensity = 0.9
	if AudioManager.get_music_state() != desired:
		AudioManager.set_music_state(desired, intensity)

func _process(_delta: float) -> void:
	if _hud == null or _player == null:
		return
	var ratio := 1.0
	var boss_id := String(boss_definition.get("id",""))
	var title := LocalizationService.content_text("boss",boss_id,"name",String(boss_definition.get("name",LocalizationService.text("colossus_fallback"))))
	if state == RunState.ORGAN_CHAMBER or state in [RunState.INTERNAL_ROOMS,RunState.DIVING_IN]:
		ratio = organ_health/maxf(1.0,organ_max) if state == RunState.ORGAN_CHAMBER else clampf(room_timer/maxf(0.1,float(current_room.get("duration",1.0))),0,1)
		var organ_id := String(current_organ.get("id",""))
		title = LocalizationService.content_text("organ",organ_id,"name",String(current_organ.get("name",LocalizationService.text("internal_depth"))))
	elif state == RunState.CORE:
		ratio = core_health/maxf(1.0,core_max)
	else:
		ratio = armor_health/maxf(1.0,armor_max)
	var phase_text := LocalizationService.text(String(STATE_TEXT_KEYS.get(state,"state_fallback")))
	if state == RunState.BREACH_OPEN:
		phase_text = LocalizationService.text("breach_timer", {"seconds": "%.1f" % breach_timer})
	if state == RunState.INTERNAL_ROOMS and not current_room.is_empty():
		var room_id := String(current_room.get("id",""))
		var room_type := String(current_room.get("type","room"))
		var room_rule_fallback := LocalizationService.text("keep_moving") if room_id=="fallback" else String(current_room.get("safe_rule",LocalizationService.text("keep_moving")))
		var room_rule := LocalizationService.content_text("room",room_id,"safe_rule",room_rule_fallback)
		phase_text = "%s · %s" % [LocalizationService.room_type_text(room_type),room_rule]
	_hud.update_status(title,ratio,_player.health_ratio(),run_bio,elapsed,phase_text,_player.dash_ratio())

func _update_player_only(delta: float) -> void:
	var hit_result := _projectiles.step(delta,[],_player.position,12.0)
	_apply_player_hits(hit_result.player_hits)

func _update_combat(delta: float, exterior: bool) -> void:
	_update_calm_heal(delta)
	if exterior:
		wound_memory_timer = maxf(0.0, wound_memory_timer - delta)
	_update_bio_pickups(delta)
	_update_enemies(delta)
	_fire_timer_step(delta)
	if not exterior:
		_update_room_defender_effects(delta)
	var targets := _target_infos(exterior)
	var hit_result := _projectiles.step(delta,targets,_player.position,12.0)
	_update_attack_avoidance(hit_result.player_hits)
	for raw_hit in hit_result.target_hits:
		_target_hit_count += 1
		_damage_target(raw_hit)
	_apply_player_hits(hit_result.player_hits)
	if state in [RunState.DEAD,RunState.VICTORY]:
		return
	_update_dash_wakes(delta, exterior)
	_update_orbitals(delta,exterior)
	if exterior:
		_update_boss_attacks(delta)
	else:
		_update_internal_hazards(delta)

func _fire_timer_step(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	var interval := float(weapon_definition.get("fire_interval",0.2))
	fire_timer = effective_fire_interval(interval,_player.health_ratio(),_mutation_engine.flags,breach_fury_timer>0.0)
	if phase_open_timer > 0.0:
		fire_timer /= maxf(0.1, float(_permanent_stats.get("phase_open_rate_mul", 1.0)))
	_fire_weapon()

func _fire_weapon(is_echo := false) -> void:
	var target := _aim_target()
	var origin := _player.position + Vector2(0,-19)
	var direction := (target-origin).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.UP
	var base_count := int(weapon_definition.get("projectile_count",1))
	var mutation_count := int(_mutation_engine.stats.get("projectile_count_add",0))
	var count := maxi(1,base_count+mutation_count)
	var spread := float(weapon_definition.get("spread",0.0))
	if spread <= 0.0 and count > 1:
		spread = 0.13
	var target_distance := origin.distance_to(target)
	var damage := float(weapon_definition.get("damage",20.0))*float(weapon_definition.get("projectile_damage_mul",1.0))*float(_permanent_stats.damage_mul)
	damage *= weapon_range_multiplier(weapon_definition, target_distance)
	damage *= _mutation_engine.damage_multiplier(_current_damage_zone(),target_distance,_player.health_ratio(),organs_destroyed,shot_streak,wound_memory_timer>0.0)
	if is_echo:
		damage *= 0.72
	var speed := float(weapon_definition.get("projectile_speed",600.0))*float(_mutation_engine.stats.get("projectile_speed_mul",1.0))
	var behavior := String(weapon_definition.get("behavior","pulse"))
	for index in count:
		var angle_offset := (float(index)-float(count-1)/2.0)*spread
		_projectiles.spawn_player(origin,direction.rotated(angle_offset)*speed,damage,{
			"radius": 5.0 if behavior=="rail" else 3.5,
			"life": float(weapon_definition.get("lifetime",1.6)),
			"pierce": int(weapon_definition.get("pierce",0))+int(_mutation_engine.stats.get("pierce_add",0)),
			"color": Color(String(weapon_definition.get("color","#54F2E7"))),
			"behavior": behavior,
			"homing": float(_mutation_engine.flags.get("homing_strength",0.0))+(1.2 if behavior=="arc" else 0.0)
		})
	if not is_echo:
		shot_count += 1
		shot_streak = mini(40,shot_streak+1)
	if not _first_shot_sent:
		_first_shot_sent=true
		AnalyticsService.track("first_shot")
		_tutorial_observe(TutorialFlowScript.EVENT_FIRST_SHOT)
	var sfx: String = String({"scatter":"scatter_fire","rail":"rail_fire","arc":"arc_fire","orbitals":"orbital_hit"}.get(behavior,"player_fire"))
	AudioManager.play_sfx(sfx,_rng.randf_range(0.97,1.03),0.55)
	if not is_echo and int(_mutation_engine.flags.get("echo_every",0)) > 0 and shot_count % int(_mutation_engine.flags.echo_every) == 0:
		_pending_echoes.append({"timer":0.24})

func _current_damage_zone() -> String:
	if state in [RunState.INTERNAL_ROOMS, RunState.ORGAN_CHAMBER]:
		return "internal"
	if state == RunState.CORE:
		return "core"
	return "armor"

func _update_pending_echoes(delta: float) -> void:
	for index in range(_pending_echoes.size()-1,-1,-1):
		_pending_echoes[index].timer=float(_pending_echoes[index].timer)-delta
		if float(_pending_echoes[index].timer)<=0.0:
			_pending_echoes.remove_at(index)
			if state in [RunState.EXTERIOR,RunState.CORE,RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER]:
				_fire_weapon(true)

func _aim_target() -> Vector2:
	var nearest := Vector2.ZERO
	var best := INF
	var marked_nearest := Vector2.ZERO
	var marked_best := INF
	for enemy in _enemies:
		var distance := _player.position.distance_squared_to(Vector2(enemy.position))
		if float(enemy.get("effect_priority_seconds",0.0))>0.0 and distance<marked_best:
			marked_best=distance
			marked_nearest=enemy.position
		if distance<best:
			best=distance
			nearest=enemy.position
	if marked_nearest != Vector2.ZERO and _aim_assist_enabled():
		return marked_nearest
	if nearest != Vector2.ZERO and _aim_assist_enabled():
		return nearest
	if state == RunState.ORGAN_CHAMBER:
		var organ_target := _boss_visual.target_position()
		return organ_target if _aim_assist_enabled() else Vector2(_player.position.x,organ_target.y)
	if state in [RunState.EXTERIOR,RunState.CORE]:
		var boss_target := _boss_visual.target_position()
		return boss_target if _aim_assist_enabled() else Vector2(_player.position.x,boss_target.y)
	return Vector2(_player.position.x,180)

func _target_infos(exterior: bool) -> Array:
	var result: Array = []
	for enemy in _enemies:
		result.append({"id":String(enemy.id),"position":Vector2(enemy.position),"radius":float(enemy.radius)})
	if exterior and state in [RunState.EXTERIOR,RunState.CORE]:
		result.append({"id":"boss","position":_boss_visual.target_position(),"radius":_boss_visual.target_radius()})
	elif state == RunState.ORGAN_CHAMBER:
		result.append({"id":"organ","position":_boss_visual.target_position(),"radius":_boss_visual.target_radius()})
	return result

func _damage_target(hit: Dictionary) -> void:
	var target_id := String(hit.id)
	var amount := float(hit.damage)
	if target_id == "boss":
		_boss_visual.flash_hit()
		if state == RunState.CORE:
			core_health=maxf(0.0,core_health-amount)
			_boss_visual.set_health(core_health,core_max)
			score += int(amount*3.0)
			if core_health<=0.0:
				_complete_run(true,"core_collapse")
		elif state == RunState.EXTERIOR:
			_play_combat_sfx_limited("armor_hit", _rng.randf_range(0.96, 1.04), 0.52)
			_tutorial_observe(TutorialFlowScript.EVENT_EXPOSED_ARMOR_HIT)
			armor_health=maxf(0.0,armor_health-amount)
			_boss_visual.set_health(armor_health,armor_max)
			score += int(amount*2.0)
			if armor_health<=0.0:
				_open_breach()
	elif target_id == "organ" and state == RunState.ORGAN_CHAMBER:
		amount *= _room_effect_value_max("true_target_revealed","true_target_damage_multiplier",1.0)
		_boss_visual.flash_hit()
		_play_combat_sfx_limited("organ_damage", _rng.randf_range(0.94, 1.06), 0.58)
		organ_health=maxf(0.0,organ_health-amount)
		score += int(amount*4.0)
		if int(_mutation_engine.flags.get("tear_every",0))>0:
			_organ_hit_count += 1
			if _organ_hit_count%int(_mutation_engine.flags.tear_every)==0:
				var tear_damage := float(_mutation_engine.flags.get("tear_damage",0))
				organ_health=maxf(0.0,organ_health-tear_damage)
				score += int(tear_damage*4.0)
		_boss_visual.set_health(organ_health,organ_max)
		if organ_health<=0.0:
			_destroy_current_organ()
	else:
		for index in _enemies.size():
			if String(_enemies[index].id)==target_id:
				amount *= _room_enemy_damage_multiplier(_enemies[index] as Dictionary)
				_enemies[index].health=float(_enemies[index].health)-amount
				if float(_enemies[index].health)<=0.0:
					_kill_enemy(index)
				break
	if String(hit.get("behavior",""))=="arc":
		_arc_chain(target_id,Vector2(hit.get("position",Vector2.ZERO)),amount)

func _arc_chain(excluded_id: String, start_position: Vector2, initial_damage: float) -> void:
	var remaining_hops := int(weapon_definition.get("chain",0))
	if remaining_hops <= 0:
		return
	var chain_range_squared := pow(float(weapon_definition.get("chain_range",220.0)),2.0)
	var chain_damage := initial_damage*float(weapon_definition.get("chain_damage_mul",0.38))
	var visited := {excluded_id:true}
	var from_position := start_position
	for _hop in remaining_hops:
		var nearest_id := ""
		var nearest_position := Vector2.ZERO
		var best_distance := chain_range_squared
		for enemy in _enemies:
			var enemy_id := String(enemy.id)
			if visited.has(enemy_id):
				continue
			var candidate_position := Vector2(enemy.position)
			var distance_squared := from_position.distance_squared_to(candidate_position)
			if distance_squared <= best_distance:
				best_distance = distance_squared
				nearest_id = enemy_id
				nearest_position = candidate_position
		if nearest_id.is_empty():
			break
		visited[nearest_id] = true
		_damage_enemy_by_id(nearest_id,chain_damage)
		from_position = nearest_position

func _damage_enemy_by_id(enemy_id: String, amount: float) -> bool:
	for index in _enemies.size():
		if String(_enemies[index].id) != enemy_id:
			continue
		amount *= _room_enemy_damage_multiplier(_enemies[index] as Dictionary)
		_enemies[index].health = float(_enemies[index].health)-amount
		if float(_enemies[index].health)<=0.0:
			_kill_enemy(index)
		return true
	return false

func _room_enemy_damage_multiplier(enemy: Dictionary) -> float:
	return maxf(1.0,float(enemy.get("effect_damage_multiplier",1.0))) if float(enemy.get("effect_priority_seconds",0.0))>0.0 else 1.0

func _apply_player_hits(hits: Array) -> void:
	for raw_hit in hits:
		var hit: Dictionary=raw_hit
		var shields_before := _player.shield_hits
		if _player.dash_time > 0.0 and _last_perfect_dash_count < _dash_count:
			_last_perfect_dash_count = _dash_count
			_meta_progress("perfect_dash", {"event_id":"%s:perfect_dash:%d" % [run_id,_dash_count]}, false)
		var incoming_damage := float(hit.damage) * _difficulty_damage()
		var internal_state := state in [RunState.DIVING_IN, RunState.INTERNAL_ROOMS, RunState.ORGAN_CHAMBER, RunState.DIVING_OUT]
		if internal_state:
			incoming_damage *= float(_permanent_stats.get("internal_damage_mul", 1.0))
		var uses_phase_plating := _phase_first_hit_available and state in [RunState.EXTERIOR, RunState.BREACH_OPEN, RunState.CORE]
		if uses_phase_plating:
			incoming_damage *= 1.0 - float(_permanent_stats.get("phase_first_hit_reduction", 0.0))
		var damaged_hull := _player.take_damage(incoming_damage,String(hit.cause))
		if damaged_hull and uses_phase_plating:
			_phase_first_hit_available = false
		if damaged_hull or _player.shield_hits < shields_before:
			shot_streak=0
			calm_timer=0.0

func _update_orbitals(delta: float, exterior: bool) -> void:
	var base_count:=int(weapon_definition.get("orbitals",0))
	var count:=base_count+int(_mutation_engine.stats.get("orbitals_add",0))
	if count<=0:
		return
	var centers:Array[Vector2]=[]
	var orbit_radius := float(weapon_definition.get("orbital_radius",48.0))+_orbit_growth
	for index in count:
		var angle:=elapsed*2.8+index*TAU/count
		centers.append(_player.position+Vector2(cos(angle),sin(angle))*orbit_radius)
	var can_absorb := bool(weapon_definition.get("absorbs_projectiles",false)) or bool(_mutation_engine.flags.get("orbit_absorb",false))
	var consumed:=_projectiles.consume_enemy_near(centers,float(weapon_definition.get("orbital_hit_radius",13.0))+_orbit_growth*0.3) if can_absorb else 0
	if consumed>0:
		score+=consumed*15
		if bool(_mutation_engine.flags.get("orbit_absorb",false)):
			_orbit_growth=minf(float(_mutation_engine.flags.get("orbit_growth_cap",0.0)),_orbit_growth+consumed*float(_mutation_engine.flags.get("orbit_growth_per_absorb",0.0)))
		AudioManager.play_sfx("orbital_hit",1.0,0.35)
	var base_damage:=float(weapon_definition.get("damage",20.0))*delta*float(weapon_definition.get("orbital_dps_mul",1.25))*float(_mutation_engine.flags.get("orbital_damage_mul",1.0))*float(_permanent_stats.damage_mul)
	var damaged_ids: Dictionary = {}
	for center in centers:
		for enemy in _enemies.duplicate():
			var enemy_id := String(enemy.id)
			if damaged_ids.has(enemy_id):
				continue
			if center.distance_to(Vector2(enemy.position)) <= float(enemy.radius)+12.0:
				var enemy_damage:=base_damage*_mutation_engine.damage_multiplier(_current_damage_zone(),_player.position.distance_to(Vector2(enemy.position)),_player.health_ratio(),organs_destroyed,shot_streak,wound_memory_timer>0.0)
				_damage_enemy_by_id(enemy_id,enemy_damage)
				damaged_ids[enemy_id]=true
	var direct_target_id := "boss" if exterior and state in [RunState.EXTERIOR,RunState.CORE] else ("organ" if state==RunState.ORGAN_CHAMBER else "")
	if direct_target_id.is_empty():
		return
	var target_pos:=_boss_visual.target_position()
	for center in centers:
		if center.distance_to(target_pos)<_boss_visual.target_radius()+12.0:
			var amount:=base_damage*_mutation_engine.damage_multiplier(_current_damage_zone(),_player.position.distance_to(target_pos),_player.health_ratio(),organs_destroyed,shot_streak,wound_memory_timer>0.0)
			_damage_target({"id":direct_target_id,"damage":amount,"behavior":"orbitals"})

func _update_boss_attacks(delta: float) -> void:
	if not _telegraph.is_empty():
		_telegraph.timer=float(_telegraph.timer)-delta
		if float(_telegraph.timer)<=0.0:
			var completed_warning := _telegraph.duplicate(true)
			_spawn_attack(
				String(completed_warning.ability),
				float(completed_warning.safe_angle),
				int(completed_warning.get("dash_count_at_start", _dash_count)),
				completed_warning.get("attack_contract", {}) as Dictionary
			)
			_telegraph.clear()
			attack_timer=_rng.randf_range(2.1,3.1)-phase*0.08
		return
	attack_timer-=delta
	if attack_timer<=0.0:
		var attack_contracts: Array[Dictionary] = [basic_rupture_attack_contract()]
		attack_contracts.append_array(_organ_map.attack_contracts())
		var attack_contract := attack_contracts[_rng.randi_range(0,attack_contracts.size()-1)]
		var ability := String(attack_contract.get("ability_id","basic_rupture"))
		var telegraph_multiplier := maxf(1.0,float(attack_contract.get("telegraph_multiplier",1.0)))
		var telegraph_time:=maxf(0.74,0.98-phase*0.04)*telegraph_multiplier*_assist_number("assist_telegraph",1.0)
		_telegraph={
			"ability": ability,
			"timer": telegraph_time,
			"total": telegraph_time,
			"safe_angle": _rng.randf_range(-PI,PI),
			"dash_count_at_start": _dash_count,
			"attack_contract": attack_contract,
			"contract_family": String((attack_contract.get("pattern",{}) as Dictionary).get("family",""))
		}
		var transformed_pattern := attack_contract.get("pattern",{}) as Dictionary
		if String(transformed_pattern.get("family","")) == "lane":
			_telegraph.gap_x = 68.0 if int(transformed_pattern.get("safe_flank",1)) < 0 else 472.0
		AudioManager.play_sfx("enemy_fire",0.72,0.35)

func _spawn_attack(ability: String, safe_angle: float, dash_count_at_telegraph: int = -1, attack_contract: Dictionary = {}) -> void:
	var origin:=_boss_visual.target_position()
	var player_angle:=( _player.position-origin ).angle()
	var projectile_speed:=_difficulty_projectile_speed()
	var cause_id := "ability:%s" % ability
	_boss_attack_serial += 1
	var wave_id := "boss_attack:%d" % _boss_attack_serial
	var warning_dash_count := _dash_count if dash_count_at_telegraph < 0 else dash_count_at_telegraph
	if String(attack_contract.get("status","")) == OrganAbilityMap.STATUS_DEGRADED:
		var plan := build_degraded_attack_specs(attack_contract,origin,_player.position,safe_angle,projectile_speed)
		if bool(plan.get("valid",false)):
			for raw_spec in plan.get("projectiles",[]):
				var spec := raw_spec as Dictionary
				var options := (spec.get("options",{}) as Dictionary).duplicate(true)
				options.group = wave_id
				_projectiles.spawn_enemy(Vector2(spec.origin),Vector2(spec.velocity),float(spec.damage),options)
	elif ability in ["homing_eye","weapon_copy"]:
		for offset in [-0.28,-0.12,0.0,0.12,0.28]:
			_projectiles.spawn_enemy(origin,Vector2.from_angle(player_angle+offset)*250.0*projectile_speed,10.0,{"homing":1.45,"cause":cause_id,"group":wave_id})
	elif ability in ["gravity_ring","suction_waves"]:
		for index in 22:
			var angle:=index*TAU/22.0
			if absf(wrapf(angle-safe_angle,-PI,PI))<0.5:
				continue
			_projectiles.spawn_enemy(origin,Vector2.from_angle(angle)*185.0*projectile_speed,12.0,{"radius":6.0,"cause":cause_id,"group":wave_id})
	elif ability in ["bone_missiles","parasite_swarm"]:
		for index in 8:
			var offset:=(index-3.5)*0.105
			_projectiles.spawn_enemy(origin,Vector2.from_angle(player_angle+offset)*330.0*projectile_speed,11.0,{"radius":6.5,"cause":cause_id,"group":wave_id})
	elif ability in ["laser_wings","echo_dash"]:
		var gap_x:=clampf(_player.position.x+_rng.randf_range(-35,35),90,450)
		for x in range(22,519,34):
			if absf(x-gap_x)<58:
				continue
			_projectiles.spawn_enemy(Vector2(x,260),Vector2(0,315*projectile_speed),13.0,{"shape":"wall","radius":8.0,"cause":cause_id,"group":wave_id})
	elif ability in ["prism_lances","chain_lightning"]:
		for offset in [-0.22,0.0,0.22]:
			_projectiles.spawn_enemy(origin,Vector2.from_angle(player_angle+offset)*430.0*projectile_speed,12.0,{"radius":5.5,"cause":cause_id,"group":wave_id})
	elif ability in ["halo_barrier","false_weakpoints"]:
		for index in 16:
			var angle:=index*TAU/16.0+rotation_phase()
			if index%6==0:
				continue
			_projectiles.spawn_enemy(origin,Vector2.from_angle(angle)*225.0*projectile_speed,10.0,{"cause":cause_id,"group":wave_id})
	else:
		for index in 14:
			var angle:=index*TAU/14.0
			if absf(wrapf(angle-safe_angle,-PI,PI))<0.45:
				continue
			_projectiles.spawn_enemy(origin,Vector2.from_angle(angle)*205.0*projectile_speed,9.0,{"cause":"ability:basic_rupture","group":wave_id})
	if _projectiles.enemy_group_size(wave_id) > 0:
		_attack_avoidance_candidates[wave_id] = {
			"contact": false,
			"dash_count_at_start": warning_dash_count
		}
	AudioManager.play_sfx("enemy_fire",_rng.randf_range(0.82,1.02),0.7)

func _update_attack_avoidance(player_hits: Array) -> void:
	for raw_hit in player_hits:
		var hit := raw_hit as Dictionary
		var group_id := String(hit.get("group", ""))
		if group_id.is_empty() or not _attack_avoidance_candidates.has(group_id):
			continue
		var contacted := _attack_avoidance_candidates[group_id] as Dictionary
		contacted.contact = true
		_attack_avoidance_candidates[group_id] = contacted
	for raw_group_id in _attack_avoidance_candidates.keys():
		var group_id := String(raw_group_id)
		if _projectiles.enemy_group_size(group_id) > 0:
			continue
		var candidate := _attack_avoidance_candidates[group_id] as Dictionary
		var survived_without_dash := (
			not bool(candidate.get("contact", false))
			and _dash_count == int(candidate.get("dash_count_at_start", -1))
			and state in [RunState.EXTERIOR, RunState.CORE]
			and _player != null
			and _player.health > 0.0
		)
		_attack_avoidance_candidates.erase(group_id)
		if survived_without_dash:
			_tutorial_observe(TutorialFlowScript.EVENT_TELEGRAPH_AVOIDED)

func _cancel_attack_avoidance() -> void:
	_attack_avoidance_candidates.clear()

func _play_combat_sfx_limited(sfx_id: String, pitch: float = 1.0, volume: float = 1.0) -> bool:
	var interval := float(COMBAT_SFX_INTERVALS.get(sfx_id, 0.0))
	if not should_emit_rate_limited_sfx(_combat_sfx_last_played, sfx_id, elapsed, interval):
		return false
	AudioManager.play_sfx(sfx_id, pitch, volume)
	return true

func _ability_display(ability: String) -> String:
	return LocalizationService.ability_text(ability)

func rotation_phase() -> float:
	return fmod(elapsed*0.55,TAU)

static func room_space_position(normalized_position: Array) -> Vector2:
	return RoomSpaceScript.normalized_to_world(RoomSpaceScript.clamp_normalized(normalized_position), INTERNAL_COMBAT_BOUNDS)

static func room_space_normalized(screen_position: Vector2) -> Vector2:
	var normalized := RoomSpaceScript.world_to_normalized(screen_position, INTERNAL_COMBAT_BOUNDS)
	return Vector2(float(normalized[0]), float(normalized[1]))

func _place_player_at_room_entry() -> void:
	_player.place_at(room_space_position(RoomMechanicsScript.ENTRY_POINT))
	_room_previous_player_position = _player.position

func _update_internal_hazards(delta: float) -> void:
	if state not in [RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER]:
		return
	if String(current_room.get("type", "")) == "entrance":
		return
	# Unknown or malformed hazards fail closed. Contract resolution installs a
	# validated safe fallback; if even that failed, this room produces no damage.
	if not bool(_room_contract.get("valid", false)):
		return
	_sample_room_player_history()
	_update_pending_room_emissions(delta)
	_update_active_room_motifs(delta)
	if state not in [RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER] or _player.health<=0.0:
		return
	_update_contract_hazards(delta)

func _update_contract_hazards(delta: float) -> void:
	if not bool(_room_pattern_plan.get("valid",false)) or String(_room_pattern_plan.get("room_id","")) != String(_room_contract.get("room_id","")):
		if not _compile_room_pattern_plan():
			return
	_room_elapsed += delta
	_expire_contract_waves()
	_expire_room_actor_groups()
	var duration := maxf(0.1, float(_room_contract.get("duration", 1.0)))
	var events: Array = _room_pattern_plan.get("events", []) if bool(_room_pattern_plan.get("valid", false)) else []
	if events.is_empty():
		return
	if not _telegraph.is_empty():
		_telegraph.timer = float(_telegraph.timer) - delta
		if float(_telegraph.timer) <= 0.0:
			_spawn_contract_pattern(_telegraph.get("event", {}))
			_telegraph.clear()
			_room_event_index += 1
		return
	if state == RunState.ORGAN_CHAMBER and _room_elapsed >= duration and _room_event_index >= events.size() and _active_room_waves.is_empty() and _active_room_actor_groups.is_empty():
		_room_elapsed = fmod(_room_elapsed, duration)
		_room_event_index = 0
		_room_cycle_index += 1
		# A cycle owns its defender-effect lineage. At this boundary every wave
		# and actor is resolved, so retaining receipts/scopes can only leak stale
		# state and grow memory across a long organ fight.
		_reset_room_defender_effects()
		_place_player_at_room_entry()
		_room_player_history.clear()
		_room_history_next_sample = _room_elapsed
		_room_history_frame_time = _room_elapsed
		_room_history_frame_position = room_space_normalized(_player.position)
		_room_history_initialized = false
		_trace_room_runtime("cycle_reset", {"cycle":_room_cycle_index})
	# The authored safe corridor belongs to exactly one active wave. Do not arm
	# the next warning until the prior active window has been retired.
	if not _active_room_waves.is_empty():
		return
	if _room_event_index >= events.size():
		return
	var event := events[_room_event_index] as Dictionary
	var base_telegraph := float((_room_pattern_plan.get("timing", {}) as Dictionary).get("telegraph_seconds", 0.45))
	var assist_telegraph := _assist_number("assist_telegraph", 1.0)
	var telegraph_seconds := base_telegraph * assist_telegraph
	var telegraph_at := maxf(0.0, float(event.get("active_at", 0.0)) - telegraph_seconds)
	if _room_elapsed >= telegraph_at:
		var safe_contract := event.get("safe", {}) as Dictionary
		var safe_position_data: Array = safe_contract.get("position", [0.5,0.5])
		var safe_position := room_space_position(safe_position_data)
		var runtime_event := event.duplicate(true)
		var active_seconds := maxf(0.08, float(event.get("clear_at", 0.0)) - float(event.get("active_at", 0.0)))
		var family := String(_room_contract.get("family", "lane"))
		var pattern_origin := _room_event_origin_world(event)
		runtime_event.runtime_active_seconds = active_seconds
		runtime_event.runtime_telegraph_seconds = telegraph_seconds
		runtime_event.runtime_cycle_index = _room_cycle_index
		runtime_event.runtime_canonical_wave_id = String(event.get("owner_wave_id",""))
		runtime_event.runtime_difficulty_context = _room_difficulty_context(assist_telegraph)
		runtime_event.runtime_gap_x = safe_position.x
		runtime_event.runtime_origin = [pattern_origin.x, pattern_origin.y]
		runtime_event.runtime_wave_id = _room_live_wave_id(runtime_event,_room_cycle_index)
		runtime_event.runtime_effect_scope_id = _room_defender_effect_scope_id(String((event.get("spawn",{}) as Dictionary).get("defender_archetype","none")))
		var telegraph_world_positions := _room_event_world_positions(runtime_event,safe_position)
		if _room_event_has_structural_hazard(runtime_event) and telegraph_world_positions.is_empty():
			_trace_room_runtime("structural_geometry_rejected",{
				"event_index":int(event.get("index",_room_event_index)),
				"wave_id":String(runtime_event.runtime_wave_id),
				"reason":"no_safe_placement",
			})
			_room_event_index += 1
			return
		var serialized_world_positions: Array = []
		for world_position in telegraph_world_positions:
			serialized_world_positions.append([world_position.x,world_position.y])
		runtime_event.runtime_world_positions = serialized_world_positions
		var player_snapshot := _player.position if _player != null else safe_position
		runtime_event.runtime_player_snapshot = [player_snapshot.x,player_snapshot.y]
		runtime_event.runtime_player_history_snapshot = _room_history_snapshot()
		var projectile_runtime := _build_room_projectile_specs(runtime_event,telegraph_world_positions,safe_position,active_seconds)
		runtime_event.runtime_projectile_specs = (projectile_runtime.get("specs",[]) as Array).duplicate(true)
		var runtime_projectile_previews := _build_room_projectile_previews(runtime_event.runtime_projectile_specs as Array)
		if not _room_projectile_previews_valid(runtime_event.runtime_projectile_specs as Array,runtime_projectile_previews):
			_trace_room_runtime("projectile_preview_rejected",{
				"event_index":int(event.get("index",_room_event_index)),
				"wave_id":String(runtime_event.runtime_wave_id),
				"reason":"invalid_or_incomplete_preview",
				"spec_count":int((runtime_event.runtime_projectile_specs as Array).size()),
				"preview_count":runtime_projectile_previews.size(),
			})
			_room_event_index += 1
			return
		runtime_event.runtime_projectile_previews = runtime_projectile_previews
		runtime_event.runtime_projectile_seconds = float(projectile_runtime.get("follow_through_seconds",active_seconds))
		runtime_event.runtime_threat_position = projectile_runtime.get("threat_position",[safe_position.x,safe_position.y])
		runtime_event.runtime_projectile_threat_seconds = float(projectile_runtime.get("threat_seconds",0.0))
		var actor_seconds := _room_defender_combat_seconds(runtime_event)
		runtime_event.runtime_actor_seconds = actor_seconds
		runtime_event.runtime_wave_seconds = active_seconds
		runtime_event.runtime_replay_digest = _room_history_digest()
		var execution_context_digest := _freeze_room_execution_context(runtime_event)
		# A hitch may arrive after the authored activation time. Never compress a
		# warning to a token frame: delay activation for a full visible telegraph.
		var warning_timer := maxf(telegraph_seconds, float(event.get("active_at", 0.0)) - _room_elapsed)
		_telegraph = {
			"source": "room_pattern",
			"ability": String(_room_contract.get("hazard", "cell_bloom")),
			"timer": warning_timer,
			"total": warning_timer,
			"safe_angle": (safe_position - pattern_origin).angle(),
			"safe_position": safe_position,
			"gap_x": float(runtime_event.runtime_gap_x),
			"pattern_origin": pattern_origin,
			"contract_family": family,
			"visual_signature":String(event.get("visual_signature", "")),
			"spawn_visual_token":String((event.get("spawn", {}) as Dictionary).get("visual_token", "")),
			"projectile_visual_token":String((event.get("projectile", {}) as Dictionary).get("visual_token", "")),
			"movement_visual_token":String((event.get("movement", {}) as Dictionary).get("visual_token", "")),
			"event": runtime_event
		}
		_trace_room_runtime("telegraph", {
			"event_index":int(event.get("index", _room_event_index)),
			"wave_id":String(runtime_event.runtime_wave_id),
			"canonical_wave_id":String(runtime_event.runtime_canonical_wave_id),
			"live_wave_id":String(runtime_event.runtime_wave_id),
			"execution_context_digest":execution_context_digest,
			"visual_signature":String(event.get("visual_signature", "")),
			"safe_position":[safe_position.x,safe_position.y],
			"projectile_seconds":float(runtime_event.runtime_projectile_seconds),
			"actor_seconds":actor_seconds,
		})
		AudioManager.play_sfx("heartbeat", 0.9, 0.48)

func _room_event_origin_world(event: Dictionary) -> Vector2:
	var projectile := event.get("projectile", {}) as Dictionary
	var emitters := projectile.get("emitters", []) as Array
	if not emitters.is_empty():
		return room_space_position(emitters[0] as Array)
	var positions := (event.get("spawn", {}) as Dictionary).get("positions", []) as Array
	if not positions.is_empty():
		return room_space_position((positions[0] as Dictionary).get("position", [0.5,0.2]) as Array)
	return room_space_position([0.5,0.2])

static func room_runtime_category(event: Dictionary) -> String:
	return RoomPatternRuntimeScript.runtime_category_for_event(event)

func _sample_room_player_history() -> void:
	if _player == null:
		return
	var current_time := _room_elapsed
	var current_position := room_space_normalized(_player.position)
	if not _room_history_initialized or current_time < _room_history_frame_time:
		_room_history_frame_time = current_time
		_room_history_frame_position = current_position
		_room_history_initialized = true
	while _room_history_next_sample <= current_time + 0.0001:
		var sample_position := current_position
		var frame_seconds := current_time - _room_history_frame_time
		if frame_seconds > 0.0001:
			var ratio := clampf((_room_history_next_sample - _room_history_frame_time) / frame_seconds, 0.0, 1.0)
			sample_position = _room_history_frame_position.lerp(current_position, ratio)
		_room_player_history.append({
			"time_ms":roundi(_room_history_next_sample*1000.0),
			"position":[sample_position.x,sample_position.y],
		})
		_room_history_next_sample += ROOM_HISTORY_SAMPLE_SECONDS
	while _room_player_history.size() > 52:
		_room_player_history.pop_front()
	_room_history_frame_time = current_time
	_room_history_frame_position = current_position

func _room_history_digest() -> String:
	var parts := PackedStringArray()
	for sample in _room_player_history:
		var position := (sample as Dictionary).get("position", [0.5,0.9]) as Array
		parts.append("%d:%d:%d" % [
			int((sample as Dictionary).get("time_ms", 0)),
			roundi(float(position[0])*1000.0),
			roundi(float(position[1])*1000.0),
		])
	return "history:none" if parts.is_empty() else "history:%s" % "|".join(parts).sha256_text().left(16)

static func room_runtime_canonical_digest(label: String, payload: Variant) -> String:
	var canonical: Variant = _room_runtime_canonical_value(payload)
	var serialized: String = JSON.stringify(canonical, "", true, true)
	return "%s:%s" % [label, serialized.sha256_text()]

static func _room_runtime_canonical_value(value: Variant) -> Variant:
	var type_id := typeof(value)
	match type_id:
		TYPE_NIL:
			return {"type":"nil"}
		TYPE_BOOL:
			return {"type":"bool", "value":bool(value)}
		TYPE_INT:
			return {"type":"int", "value":int(value)}
		TYPE_FLOAT:
			var number := float(value)
			if is_nan(number):
				return {"type":"float", "value":"nan"}
			if is_inf(number):
				return {"type":"float", "value":"-inf" if number < 0.0 else "inf"}
			return {"type":"float", "value":number}
		TYPE_STRING, TYPE_STRING_NAME:
			return {"type":"string", "value":String(value)}
		TYPE_VECTOR2:
			var vector := Vector2(value)
			return {"type":"vector2", "x":vector.x, "y":vector.y}
		TYPE_DICTIONARY:
			var source := value as Dictionary
			var keys := source.keys()
			keys.sort_custom(func(first: Variant, second: Variant) -> bool: return String(first) < String(second))
			var entries: Array = []
			for raw_key in keys:
				entries.append([
					_room_runtime_canonical_value(raw_key),
					_room_runtime_canonical_value(source[raw_key]),
				])
			return {"type":"dictionary", "entries":entries}
		TYPE_ARRAY:
			var items: Array = []
			for item in value as Array:
				items.append(_room_runtime_canonical_value(item))
			return {"type":"array", "items":items}
	if type_id >= TYPE_PACKED_BYTE_ARRAY:
		var packed_items: Array = []
		for item in value:
			packed_items.append(_room_runtime_canonical_value(item))
		return {"type":type_string(type_id), "items":packed_items}
	return {"type":type_string(type_id), "value":var_to_str(value)}

func _room_contract_key() -> String:
	return room_runtime_canonical_digest("room-contract-v1", _room_contract)

func _room_history_snapshot() -> Array:
	var snapshot: Array = []
	for raw_sample in _room_player_history:
		var sample := raw_sample as Dictionary
		var position := sample.get("position", [0.5,0.9]) as Array
		if position.size() != 2:
			continue
		snapshot.append({
			"time_ms":int(sample.get("time_ms",0)),
			"position_millionths":[
				roundi(float(position[0])*1000000.0),
				roundi(float(position[1])*1000000.0),
			],
		})
	return snapshot

func _room_difficulty_context(assist_telegraph: float) -> Dictionary:
	var assist_projectile_speed := _assist_number("assist_projectile_speed",1.0)
	return {
		"difficulty":String(config.get("difficulty","diver")),
		"mode":String(config.get("mode","story")),
		"abyss_depth":int(config.get("abyss_depth",0)),
		"competitive":bool(config.get("competitive",false)),
		"assist_telegraph":assist_telegraph,
		"assist_projectile_speed":assist_projectile_speed,
		# This exact multiplier is consumed by the frozen projectile builder below.
		"projectile_speed_multiplier":_difficulty_projectile_speed(),
	}

func _room_live_wave_id(event: Dictionary, cycle_index: int) -> String:
	var canonical_owner := String(event.get("owner_wave_id",event.get("wave_key","")))
	return "room:%s:cycle:%d" % [canonical_owner,cycle_index]

func _room_execution_context_payload(event: Dictionary) -> Dictionary:
	return {
		"schema":ROOM_EXECUTION_CONTEXT_VERSION,
		"plan":{
			"signature":String(_room_pattern_plan.get("plan_signature","")),
			"geometry_signature":String(_room_pattern_plan.get("geometry_signature","")),
			"lifecycle_signature":String(_room_pattern_plan.get("lifecycle_signature","")),
		},
		"event":{
			"index":int(event.get("index",-1)),
			"event_seed":int(event.get("event_seed",-1)),
			"geometry_signature":String(event.get("geometry_signature","")),
			"lifecycle_signature":String(event.get("lifecycle_signature","")),
			"visual_signature":String(event.get("visual_signature","")),
			# These are the executable compiler blocks. Signing their deep values here
			# closes the gap between a valid compiler signature and activation time.
			"spawn":(event.get("spawn",{}) as Dictionary).duplicate(true),
			"projectile":(event.get("projectile",{}) as Dictionary).duplicate(true),
			"movement":(event.get("movement",{}) as Dictionary).duplicate(true),
			"safe":(event.get("safe",{}) as Dictionary).duplicate(true),
			"operations":(event.get("operations",[]) as Array).duplicate(true),
		},
		"room":{
			"room_id":String(_room_pattern_plan.get("room_id",_room_contract.get("room_id",""))),
			"runtime_seed":int(_room_pattern_plan.get("runtime_seed",_room_contract.get("runtime_seed",-1))),
			"contract_key":_room_contract_key(),
			"cycle":_room_cycle_index,
			"frozen_cycle":int(event.get("runtime_cycle_index",-1)),
		},
		"ownership":{
			"canonical_wave_id":String(event.get("owner_wave_id","")),
			"frozen_canonical_wave_id":String(event.get("runtime_canonical_wave_id","")),
			"live_wave_id":String(event.get("runtime_wave_id","")),
		},
		"difficulty":(event.get("runtime_difficulty_context",{}) as Dictionary).duplicate(true),
		"telegraph_seconds":float(event.get("runtime_telegraph_seconds",0.0)),
		"active_seconds":float(event.get("runtime_active_seconds",0.0)),
		"wave_seconds":float(event.get("runtime_wave_seconds",0.0)),
		"actor_seconds":float(event.get("runtime_actor_seconds",0.0)),
		"projectile_seconds":float(event.get("runtime_projectile_seconds",0.0)),
		"projectile_threat_seconds":float(event.get("runtime_projectile_threat_seconds",0.0)),
		"projectile_threat_position":event.get("runtime_threat_position",[]),
		"player_snapshot":event.get("runtime_player_snapshot",[]),
		"player_history_snapshot":event.get("runtime_player_history_snapshot",[]),
		"player_history_digest":String(event.get("runtime_replay_digest","")),
		"world_positions":event.get("runtime_world_positions",[]),
		"effect_scope_id":String(event.get("runtime_effect_scope_id","")),
		"runtime_projectile_specs":event.get("runtime_projectile_specs",[]),
		"runtime_projectile_previews":event.get("runtime_projectile_previews",[]),
	}

func _freeze_room_execution_context(event: Dictionary) -> String:
	var payload := _room_execution_context_payload(event)
	var digest := room_runtime_canonical_digest("room-execution-v2",payload)
	event.runtime_execution_context=payload.duplicate(true)
	event.runtime_execution_context_digest=digest
	return digest

func _validate_room_execution_context(event: Dictionary) -> Dictionary:
	if not event.has("runtime_execution_context_digest") or not event.has("runtime_execution_context"):
		# Direct unsigned helper fixtures remain available, but every compiled event
		# carries geometry identity and therefore must carry its live envelope too.
		return {
			"valid":not event.has("geometry_signature"),
			"reason":"missing_execution_context",
		}
	var frozen_value: Variant = event.get("runtime_execution_context",null)
	if typeof(frozen_value) != TYPE_DICTIONARY:
		return {"valid":false,"reason":"malformed_execution_context"}
	var frozen := frozen_value as Dictionary
	var expected_digest := String(event.get("runtime_execution_context_digest",""))
	var frozen_digest := room_runtime_canonical_digest("room-execution-v2",frozen)
	var current_payload := _room_execution_context_payload(event)
	var current_digest := room_runtime_canonical_digest("room-execution-v2",current_payload)
	var expected_live_owner := _room_live_wave_id(event,_room_cycle_index)
	if String(event.get("runtime_wave_id","")) != expected_live_owner:
		return {
			"valid":false,
			"reason":"live_owner_mismatch",
			"expected_digest":expected_digest,
			"actual_digest":current_digest,
		}
	if expected_digest.is_empty() or frozen_digest != expected_digest:
		return {
			"valid":false,
			"reason":"frozen_context_digest_mismatch",
			"expected_digest":expected_digest,
			"actual_digest":frozen_digest,
		}
	if current_digest != expected_digest:
		return {
			"valid":false,
			"reason":"live_context_digest_mismatch",
			"expected_digest":expected_digest,
			"actual_digest":current_digest,
		}
	return {"valid":true,"digest":expected_digest}

func _room_event_world_positions(event: Dictionary, safe_position: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var runtime_positions := event.get("runtime_world_positions", []) as Array
	if not runtime_positions.is_empty():
		for raw_position in runtime_positions:
			var position_data := raw_position as Array
			if position_data.size()==2:
				positions.append(Vector2(float(position_data[0]),float(position_data[1])))
		return positions
	var spawn := event.get("spawn", {}) as Dictionary
	var source_positions := spawn.get("positions", []) as Array
	var movement := event.get("movement", {}) as Dictionary
	if String(movement.get("source_model", "")) == "replay" and not _room_player_history.is_empty():
		var requested := maxi(1, source_positions.size())
		var history_stride := maxi(1,floori(float(_room_player_history.size())/float(requested)))
		for index in range(requested):
			var history_index := clampi(_room_player_history.size()-1-index*history_stride,0,_room_player_history.size()-1)
			var sample := _room_player_history[history_index] as Dictionary
			positions.append(room_space_position(sample.get("position", [0.5,0.9]) as Array))
	else:
		for raw_record in source_positions:
			var record := raw_record as Dictionary
			positions.append(room_space_position(record.get("position", [0.5,0.2]) as Array))
	var safe_radius := maxf(34.0, float((event.get("safe", {}) as Dictionary).get("clearance", 0.1))*minf(INTERNAL_COMBAT_BOUNDS.size.x, INTERNAL_COMBAT_BOUNDS.size.y))
	for index in range(positions.size()):
		var offset := positions[index]-safe_position
		if offset.length() >= safe_radius+18.0:
			continue
		if offset.length_squared() < 0.001:
			offset = Vector2.LEFT if index%2==0 else Vector2.RIGHT
		positions[index] = safe_position+offset.normalized()*(safe_radius+18.0)
		positions[index].x=clampf(positions[index].x,INTERNAL_COMBAT_BOUNDS.position.x,INTERNAL_COMBAT_BOUNDS.end.x)
		positions[index].y=clampf(positions[index].y,INTERNAL_COMBAT_BOUNDS.position.y,INTERNAL_COMBAT_BOUNDS.end.y)
	return _room_structural_safe_start_positions(event,positions,safe_position,safe_radius)

func _room_structural_safe_start_positions(event: Dictionary, positions: Array[Vector2], safe_position: Vector2, safe_radius: float) -> Array[Vector2]:
	if positions.is_empty():
		return positions
	var spawn := event.get("spawn",{}) as Dictionary
	var collision := spawn.get("collision",{}) as Dictionary
	if not _room_event_has_structural_hazard(event) or not bool(collision.get("enabled",false)):
		return positions
	var motif := {
		"collision":collision,
		"spawn":spawn,
		"positions":positions,
		"safe_position":safe_position,
		"safe_clearance_pixels":safe_radius,
	}
	if _room_motif_signed_safe_clearance(motif,positions) >= ROOM_MOTIF_CLEARANCE_EPSILON:
		return positions
	var centroid := Vector2.ZERO
	for raw_position in positions:
		centroid += Vector2(raw_position)
	centroid /= float(positions.size())
	var preferred_direction := (centroid-safe_position).normalized()
	if preferred_direction.length_squared() <= 0.0001:
		preferred_direction=Vector2.from_angle(float(abs(String(event.get("visual_signature","room")).hash())%360)*PI/180.0)
	var directions: Array[Vector2] = [preferred_direction]
	for direction_index in range(24):
		directions.append(Vector2.from_angle(float(direction_index)*TAU/24.0))
	var best_positions: Array[Vector2] = []
	var best_distance := INF
	for direction in directions:
		var maximum_shift := _room_position_group_shift_limit(positions,direction)
		if maximum_shift <= 0.001:
			continue
		var prior_distance := 0.0
		for search_index in range(1,25):
			var distance := maximum_shift*float(search_index)/24.0
			if distance >= best_distance:
				break
			var candidate := _shift_room_positions(positions,direction*distance)
			if _room_motif_signed_safe_clearance(motif,candidate) < ROOM_MOTIF_CLEARANCE_EPSILON:
				prior_distance=distance
				continue
			var low := prior_distance
			var high := distance
			for _iteration in 10:
				var midpoint := (low+high)*0.5
				var midpoint_positions := _shift_room_positions(positions,direction*midpoint)
				if _room_motif_signed_safe_clearance(motif,midpoint_positions) >= ROOM_MOTIF_CLEARANCE_EPSILON:
					high=midpoint
					candidate=midpoint_positions
				else:
					low=midpoint
			best_distance=high
			best_positions=candidate
			break
	# Never reactivate the original unsafe collider when no in-bounds placement
	# exists. The caller records and skips this malformed event fail-closed.
	return best_positions

static func _room_event_has_structural_hazard(event: Dictionary) -> bool:
	for raw_operation in event.get("operations",[]) as Array:
		if String((raw_operation as Dictionary).get("op","")) == "hold_structural_hazard":
			return true
	return false

static func _shift_room_positions(positions: Array[Vector2], offset: Vector2) -> Array[Vector2]:
	var shifted: Array[Vector2] = []
	for position in positions:
		shifted.append(position+offset)
	return shifted

static func _room_position_group_shift_limit(positions: Array[Vector2], direction: Vector2) -> float:
	var limit := INTERNAL_COMBAT_BOUNDS.size.length()
	for position in positions:
		if direction.x > 0.0001:
			limit=minf(limit,(INTERNAL_COMBAT_BOUNDS.end.x-position.x)/direction.x)
		elif direction.x < -0.0001:
			limit=minf(limit,(INTERNAL_COMBAT_BOUNDS.position.x-position.x)/direction.x)
		if direction.y > 0.0001:
			limit=minf(limit,(INTERNAL_COMBAT_BOUNDS.end.y-position.y)/direction.y)
		elif direction.y < -0.0001:
			limit=minf(limit,(INTERNAL_COMBAT_BOUNDS.position.y-position.y)/direction.y)
	return maxf(0.0,limit)

func _room_projectile_follow_through_seconds(event: Dictionary, active_seconds: float) -> float:
	var projectile := event.get("projectile", {}) as Dictionary
	if int(projectile.get("count", 0)) <= 0:
		return active_seconds
	# Only one published safe corridor may be damaging at a time. The frozen
	# first trajectory is placed to become dangerous inside this window.
	return active_seconds

func _room_defender_combat_seconds(event: Dictionary) -> float:
	var spawn := event.get("spawn",{}) as Dictionary
	if int(spawn.get("enemy_count",0))<=0:
		return 0.0
	var behavior := spawn.get("defender_behavior",{}) as Dictionary
	return ROOM_DEFENDER_ARMORED_WINDOW if String(behavior.get("health_class","medium"))=="armored" else ROOM_DEFENDER_COMBAT_WINDOW

func _build_room_projectile_specs(event: Dictionary, world_positions: Array[Vector2], safe_position: Vector2, active_seconds: float) -> Dictionary:
	var projectile := event.get("projectile",{}) as Dictionary
	var count := clampi(int(projectile.get("count",0)),0,RoomPatternRuntimeScript.MAX_PROJECTILES_PER_EVENT)
	var follow_through := _room_projectile_follow_through_seconds(event,active_seconds)
	if count<=0:
		return {"specs":[],"follow_through_seconds":active_seconds,"max_delay_seconds":0.0,"threat_position":[safe_position.x,safe_position.y]}
	var emitter_data := projectile.get("emitters",[]) as Array
	var emitters: Array[Vector2] = []
	for raw_emitter in emitter_data:
		emitters.append(room_space_position(raw_emitter as Array))
	if emitters.is_empty():
		emitters = world_positions.duplicate()
	if emitters.is_empty():
		emitters.append(room_space_position([0.5,0.2]))
	var directions := projectile.get("directions_degrees",[]) as Array
	var difficulty_context := event.get("runtime_difficulty_context",{}) as Dictionary
	var speed_multiplier := float(difficulty_context.projectile_speed_multiplier) if difficulty_context.has("projectile_speed_multiplier") else _difficulty_projectile_speed()
	var speed := maxf(80.0,float(projectile.get("speed_pixels_per_second",180.0)))*speed_multiplier
	var radius := maxf(4.0,float(projectile.get("radius_pixels",7.0)))
	var damage := maxf(1.0,float(projectile.get("damage",8.0)))
	var travel_model := String(projectile.get("travel_model","linear"))
	var visual_token := String(projectile.get("visual_token","room_spike"))
	var snapshot_data := event.get("runtime_player_snapshot",[safe_position.x,safe_position.y]) as Array
	var frozen_target := Vector2(float(snapshot_data[0]),float(snapshot_data[1])) if snapshot_data.size()==2 else safe_position
	if not is_finite(frozen_target.x) or not is_finite(frozen_target.y):
		frozen_target=safe_position
	var safe_radius := maxf(34.0,float((event.get("safe",{}) as Dictionary).get("clearance",0.1))*minf(INTERNAL_COMBAT_BOUNDS.size.x,INTERNAL_COMBAT_BOUNDS.size.y))
	var projectile_exclusion_radius := safe_radius+radius+14.0
	var threat_speed := speed
	match travel_model:
		"lunge": threat_speed*=1.28
		"expanding": threat_speed*=0.82
		"recorded_path": threat_speed*=0.32
	var threat_delay := clampf(active_seconds*0.58,0.16,minf(0.30,maxf(0.16,active_seconds-0.04)))
	var threat := _room_projectile_threat_segment(event,safe_position,projectile_exclusion_radius,threat_speed,threat_delay)
	var threat_position := Vector2(threat.get("target",safe_position))
	var specs: Array[Dictionary] = []
	var max_delay := 0.0
	for index in range(count):
		var origin := emitters[index%emitters.size()]
		if travel_model=="recorded_path" and not world_positions.is_empty():
			origin=world_positions[index%world_positions.size()]
		var safe_offset := origin-safe_position
		if safe_offset.length()<projectile_exclusion_radius:
			if safe_offset.length_squared()<0.001:
				safe_offset=Vector2.LEFT if index%2==0 else Vector2.RIGHT
			origin=safe_position+safe_offset.normalized()*(projectile_exclusion_radius+1.0)
		var direction_degrees := float(directions[index%directions.size()]) if not directions.is_empty() else -90.0
		var direction := Vector2.from_angle(deg_to_rad(direction_degrees))
		var travel_speed := speed
		match travel_model:
			"lunge": travel_speed*=1.28
			"expanding": travel_speed*=0.82
			"recorded_path": travel_speed*=0.32
		var velocity := _room_safe_velocity(origin,direction*travel_speed,safe_position,projectile_exclusion_radius,follow_through)
		if index==0:
			origin=Vector2(threat.get("origin",origin))
			var target := Vector2(threat.get("target",origin+velocity*threat_delay))
			velocity=(target-origin).normalized()*travel_speed
		var delay := 0.10*float(index%3) if travel_model=="delayed_linear" and index%3!=0 else 0.0
		max_delay=maxf(max_delay,delay)
		specs.append({
			"origin":origin,
			"velocity":velocity,
			"damage":damage,
			"delay_seconds":delay,
			"options":{
				"radius":radius,
				"life":follow_through,
				"visual_token":visual_token,
				"travel_model":travel_model,
				"homing":float(projectile.get("tracking_strength",0.0))*1.8 if travel_model=="soft_homing" else 0.0,
				"frozen_target":frozen_target,
				"safe_position":safe_position,
				# ProjectilePool expands this center-safe disk by the projectile's
				# live radius (including expanding waves). Keep the player's 14 px
				# clearance here and count projectile radius exactly once.
				"safe_radius":safe_radius+14.0,
			}
		})
	specs = _room_projectile_specs_after_defender_effects(specs,event)
	return {
		"specs":specs,
		"follow_through_seconds":follow_through,
		"max_delay_seconds":max_delay,
		"threat_position":[threat_position.x,threat_position.y],
		"threat_seconds":Vector2(threat.get("origin",threat_position)).distance_to(threat_position)/maxf(1.0,threat_speed),
	}

func _build_room_projectile_previews(raw_specs: Array) -> Array[Dictionary]:
	var previews: Array[Dictionary] = []
	if _projectiles==null:
		return previews
	var preview_count := mini(raw_specs.size(),RoomPatternRuntimeScript.MAX_PROJECTILES_PER_EVENT)
	for emission_index in range(preview_count):
		var spec := raw_specs[emission_index] as Dictionary
		var origin := Vector2(spec.get("origin",Vector2.ZERO))
		var velocity := Vector2(spec.get("velocity",Vector2.ZERO))
		var delay_seconds := float(spec.get("delay_seconds",0.0))
		if not is_finite(origin.x) or not is_finite(origin.y) \
				or not is_finite(velocity.x) or not is_finite(velocity.y) \
				or not is_finite(delay_seconds) or delay_seconds<0.0:
			return []
		var options := (spec.get("options",{}) as Dictionary).duplicate(true)
		options.preview_duration=minf(maxf(0.0,float(options.get("life",ROOM_PROJECTILE_TELEGRAPH_HORIZON))),ROOM_PROJECTILE_TELEGRAPH_HORIZON)
		var raw_samples := _projectiles.preview_enemy_travel(origin,velocity,options)
		if raw_samples.is_empty() or raw_samples.size()>ProjectilePool.MAX_PREVIEW_SAMPLES:
			return []
		var samples: Array[Dictionary] = []
		for raw_sample in raw_samples:
			var sample := raw_sample as Dictionary
			var age := float(sample.get("age",NAN))
			var position := Vector2(sample.get("position",Vector2(NAN,NAN)))
			var radius := float(sample.get("radius",NAN))
			if not is_finite(age) or age<0.0 \
					or not is_finite(position.x) or not is_finite(position.y) \
					or not is_finite(radius) or radius<0.0:
				return []
			samples.append({"age":age,"position":position,"radius":radius})
		previews.append({
			"emission_index":emission_index,
			"delay_seconds":delay_seconds,
			"samples":samples,
		})
	return previews

static func _room_projectile_previews_valid(raw_specs: Array, raw_previews: Array) -> bool:
	if raw_specs.size()!=raw_previews.size() or raw_previews.size()>RoomPatternRuntimeScript.MAX_PROJECTILES_PER_EVENT:
		return false
	for preview_index in range(raw_previews.size()):
		if typeof(raw_specs[preview_index])!=TYPE_DICTIONARY or typeof(raw_previews[preview_index])!=TYPE_DICTIONARY:
			return false
		var spec := raw_specs[preview_index] as Dictionary
		var preview := raw_previews[preview_index] as Dictionary
		if int(preview.get("emission_index",-1))!=preview_index:
			return false
		var raw_delay: Variant = preview.get("delay_seconds",NAN)
		if typeof(raw_delay) not in [TYPE_INT,TYPE_FLOAT]:
			return false
		var delay_seconds := float(raw_delay)
		if not is_finite(delay_seconds) or delay_seconds<0.0 or not is_equal_approx(delay_seconds,float(spec.get("delay_seconds",0.0))):
			return false
		var samples_value: Variant = preview.get("samples",null)
		if typeof(samples_value)!=TYPE_ARRAY:
			return false
		var samples := samples_value as Array
		if samples.is_empty() or samples.size()>ProjectilePool.MAX_PREVIEW_SAMPLES:
			return false
		var options := spec.get("options",{}) as Dictionary
		var expected_duration := minf(maxf(0.0,float(options.get("life",ROOM_PROJECTILE_TELEGRAPH_HORIZON))),ROOM_PROJECTILE_TELEGRAPH_HORIZON)
		var previous_age := -INF
		for sample_index in range(samples.size()):
			if typeof(samples[sample_index])!=TYPE_DICTIONARY:
				return false
			var sample := samples[sample_index] as Dictionary
			var raw_age: Variant = sample.get("age",NAN)
			var raw_radius: Variant = sample.get("radius",NAN)
			var raw_position: Variant = sample.get("position",null)
			if typeof(raw_age) not in [TYPE_INT,TYPE_FLOAT] or typeof(raw_radius) not in [TYPE_INT,TYPE_FLOAT] or typeof(raw_position)!=TYPE_VECTOR2:
				return false
			var age := float(raw_age)
			var radius := float(raw_radius)
			var position := raw_position as Vector2
			if not is_finite(age) or age<0.0 or age<=previous_age \
					or not is_finite(position.x) or not is_finite(position.y) \
					or not is_finite(radius) or radius<0.0:
				return false
			if sample_index==0 and (age>0.000001 or not position.is_equal_approx(Vector2(spec.get("origin",Vector2.ZERO)))):
				return false
			previous_age=age
		if absf(previous_age-expected_duration)>0.0001:
			return false
	return true

func _room_projectile_threat_segment(event: Dictionary, safe_position: Vector2, exclusion_radius: float, speed: float, threat_seconds: float) -> Dictionary:
	var projectile := event.get("projectile",{}) as Dictionary
	var primitive := String(projectile.get("primitive",""))
	var inset := INTERNAL_COMBAT_BOUNDS.grow(-20.0)
	var travel_distance := clampf(speed*threat_seconds,18.0,96.0)
	if primitive=="gravity_drop":
		var side := -1.0 if safe_position.x-inset.position.x > inset.end.x-safe_position.x else 1.0
		var hazard_x := clampf(safe_position.x+side*(exclusion_radius+22.0),inset.position.x,inset.end.x)
		if absf(hazard_x-safe_position.x)<exclusion_radius+4.0:
			hazard_x=clampf(safe_position.x-side*(exclusion_radius+22.0),inset.position.x,inset.end.x)
		var target_y := clampf(safe_position.y,inset.position.y+travel_distance,inset.end.y)
		var target := Vector2(hazard_x,target_y)
		return {"origin":target-Vector2.DOWN*travel_distance,"target":target}
	var snapshot_data := event.get("runtime_player_snapshot",[safe_position.x,safe_position.y]) as Array
	var snapshot := Vector2(float(snapshot_data[0]),float(snapshot_data[1])) if snapshot_data.size()==2 else safe_position
	var candidates := [
		{"direction":Vector2.LEFT,"space":safe_position.x-inset.position.x},
		{"direction":Vector2.RIGHT,"space":inset.end.x-safe_position.x},
		{"direction":Vector2.UP,"space":safe_position.y-inset.position.y},
		{"direction":Vector2.DOWN,"space":inset.end.y-safe_position.y},
	]
	candidates.sort_custom(func(first: Dictionary,second: Dictionary)->bool:return float(first.space)>float(second.space))
	var outward := Vector2((candidates[0] as Dictionary).direction)
	var available := float((candidates[0] as Dictionary).space)
	var target_distance := exclusion_radius+18.0
	var target := safe_position+outward*target_distance
	var snapshot_offset := snapshot-safe_position
	if inset.has_point(snapshot) and snapshot_offset.length()>=target_distance:
		outward=snapshot_offset.normalized()
		target=snapshot
		available=_room_distance_to_edge(safe_position,outward,inset)
		target_distance=snapshot_offset.length()
	var origin_distance := minf(available,target_distance+travel_distance)
	if origin_distance>=target_distance+24.0:
		return {"origin":safe_position+outward*origin_distance,"target":target}
	var inner_distance := exclusion_radius+3.0
	var approach_distance := maxf(inner_distance,target_distance-travel_distance)
	return {"origin":safe_position+outward*approach_distance,"target":target}

func _room_projectile_specs_after_defender_effects(raw_specs: Array, event: Dictionary, effect_scope_override: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_specs.is_empty():
		return result
	if _room_defender_effect_state.is_empty():
		for raw_spec in raw_specs:
			result.append(raw_spec as Dictionary)
		return result
	var spawn := event.get("spawn",{}) as Dictionary
	var archetype := String(spawn.get("defender_archetype","none"))
	var effect_scope_id := effect_scope_override if not effect_scope_override.is_empty() else String(event.get("runtime_effect_scope_id",""))
	for raw_spec in raw_specs:
		var spec := (raw_spec as Dictionary).duplicate(true)
		var options := spec.get("options",{}) as Dictionary
		var travel_model := String(options.get("travel_model",(event.get("projectile",{}) as Dictionary).get("travel_model","linear")))
		var suppressed := false
		if _room_effect_flag_active("link_broken",effect_scope_id) and (travel_model=="node_link" or archetype=="arc_linker"):
			suppressed=true
		elif _room_effect_flag_active("hatch_suppressed",effect_scope_id) and (travel_model=="lunge" or archetype=="hatchling"):
			suppressed=true
		elif _room_effect_flag_active("echo_disrupted",effect_scope_id) and (travel_model in ["recorded_path","delayed_linear"] or archetype=="echo_clone"):
			suppressed=true
		elif _room_effect_flag_active("emitter_silenced",effect_scope_id) and archetype=="resonance_mouth":
			suppressed=true
		elif _room_effect_flag_active("true_target_revealed",effect_scope_id) and archetype=="decoy_core":
			suppressed=true
		elif _room_effect_flag_active("tracking_disabled",effect_scope_id) and float(options.get("homing",0.0))>0.0:
			# Straightening a warned homing arc can create a new, untelegraphed
			# collision path. Tracking breaks therefore remove the owned threat.
			suppressed=true
		if suppressed:
			continue
		result.append(spec)
	return result

static func _room_distance_to_edge(origin: Vector2, direction: Vector2, bounds: Rect2) -> float:
	var distances: Array[float] = []
	if direction.x>0.0001:
		distances.append((bounds.end.x-origin.x)/direction.x)
	elif direction.x<-0.0001:
		distances.append((bounds.position.x-origin.x)/direction.x)
	if direction.y>0.0001:
		distances.append((bounds.end.y-origin.y)/direction.y)
	elif direction.y<-0.0001:
		distances.append((bounds.position.y-origin.y)/direction.y)
	var result := INF
	for distance in distances:
		if distance>=0.0:
			result=minf(result,distance)
	return 0.0 if result==INF else result

func _room_effect_scope_snapshot(effect_scope_id: String) -> Dictionary:
	if effect_scope_id.is_empty() or _room_defender_effect_state.is_empty():
		return {}
	var scopes := _room_defender_effect_state.get("scopes",{}) as Dictionary
	return (scopes.get(effect_scope_id,{}) as Dictionary).duplicate(true)

func _room_emission_payload(emission: Dictionary) -> Dictionary:
	return {
		"schema":ROOM_EMISSION_CONTEXT_VERSION,
		"phase":String(emission.get("phase","queued")),
		"wave_id":String(emission.get("wave_id","")),
		"canonical_wave_id":String(emission.get("canonical_wave_id","")),
		"event_index":int(emission.get("event_index",-1)),
		"emission_index":int(emission.get("emission_index",-1)),
		"execution_context_digest":String(emission.get("execution_context_digest","")),
		"parent_emission_digest":String(emission.get("parent_emission_digest","")),
		"spawn_at_room_time":float(emission.get("spawn_at_room_time",0.0)),
		"scheduled_delay_seconds":float(emission.get("scheduled_delay_seconds",0.0)),
		"effect_scope_id":String(emission.get("effect_scope_id","")),
		"effect_scope_state":(emission.get("effect_scope_state",{}) as Dictionary).duplicate(true),
		"effect_state_digest":String(emission.get("effect_state_digest","")),
		"spec":(emission.get("spec",{}) as Dictionary).duplicate(true),
	}

func _freeze_room_emission(spec: Dictionary, event: Dictionary, wave_id: String, emission_index: int, spawn_at_room_time: float, parent_emission_digest: String = "", phase: String = "queued") -> Dictionary:
	var options := spec.get("options",{}) as Dictionary
	var effect_scope_id := String(options.get("effect_scope_id",event.get("runtime_effect_scope_id","")))
	var effect_scope_state := _room_effect_scope_snapshot(effect_scope_id)
	var emission := {
		"phase":phase,
		"wave_id":wave_id,
		"canonical_wave_id":String(event.get("runtime_canonical_wave_id",event.get("owner_wave_id",""))),
		"event_index":int(event.get("index",_room_event_index)),
		"emission_index":emission_index,
		"execution_context_digest":String(event.get("runtime_execution_context_digest","")),
		"parent_emission_digest":parent_emission_digest,
		"spawn_at_room_time":spawn_at_room_time,
		"scheduled_delay_seconds":float(spec.get("delay_seconds",0.0)),
		"effect_scope_id":effect_scope_id,
		"effect_scope_state":effect_scope_state,
		"effect_state_digest":room_runtime_canonical_digest("room-effect-state-v1",effect_scope_state),
		"spec":spec.duplicate(true),
	}
	emission.emission_digest=room_runtime_canonical_digest("room-emission-v1",_room_emission_payload(emission))
	return emission

func _validate_room_emission(emission: Dictionary) -> Dictionary:
	var expected_digest := String(emission.get("emission_digest",""))
	var actual_digest := room_runtime_canonical_digest("room-emission-v1",_room_emission_payload(emission))
	if expected_digest.is_empty() or actual_digest != expected_digest:
		return {
			"valid":false,
			"reason":"emission_digest_mismatch",
			"expected_digest":expected_digest,
			"actual_digest":actual_digest,
		}
	return {"valid":true,"digest":expected_digest}

func _emit_room_projectile_plan(event: Dictionary, wave_id: String, world_positions: Array[Vector2], safe_position: Vector2, active_seconds: float, cause_id: String) -> Dictionary:
	var projectile := event.get("projectile",{}) as Dictionary
	var has_frozen_runtime_specs := event.has("runtime_projectile_specs")
	var runtime_specs := event.get("runtime_projectile_specs",[]) as Array
	if not has_frozen_runtime_specs and int(projectile.get("count",0))>0:
		runtime_specs=(_build_room_projectile_specs(event,world_positions,safe_position,active_seconds).get("specs",[]) as Array)
	var effect_scope_id := String(event.get("runtime_effect_scope_id",_room_defender_effect_scope_id(String((event.get("spawn",{}) as Dictionary).get("defender_archetype","none")))))
	runtime_specs=_room_projectile_specs_after_defender_effects(runtime_specs,event,effect_scope_id)
	if runtime_specs.is_empty():
		var empty_effect_scope_id := String(event.get("runtime_effect_scope_id",""))
		var empty_effect_state := _room_effect_scope_snapshot(empty_effect_scope_id)
		_trace_room_runtime("hold_structural_hazard",{
			"event_index":int(event.get("index",_room_event_index)),
			"wave_id":wave_id,
			"canonical_wave_id":String(event.get("runtime_canonical_wave_id",event.get("owner_wave_id",""))),
			"collider_count":world_positions.size(),
			"effect_state_digest":room_runtime_canonical_digest("room-effect-state-v1",empty_effect_state),
		})
		return {"requested":0,"spawned":0,"pending":0}
	var max_active := clampi(int(projectile.get("max_active",runtime_specs.size())),1,RoomPatternRuntimeScript.MAX_ACTIVE_PROJECTILES)
	var owned_now := _projectiles.enemy_group_size(wave_id)+_pending_room_emission_count(wave_id)
	var available := mini(runtime_specs.size(),maxi(0,max_active-owned_now))
	var spawned := 0
	var pending_count := 0
	var emission_digests: Array = []
	var effect_state_digests: Array = []
	for index in range(available):
		var spec := (runtime_specs[index] as Dictionary).duplicate(true)
		var options := spec.get("options",{}) as Dictionary
		options.cause=cause_id
		options.group=wave_id
		options.parent_group=wave_id
		options.source_archetype=String((event.get("spawn",{}) as Dictionary).get("defender_archetype","none"))
		options.effect_scope_id=effect_scope_id
		spec.options=options
		var delay := float(spec.get("delay_seconds",0.0))
		var emission := _freeze_room_emission(spec,event,wave_id,index,_room_elapsed+delay)
		emission_digests.append(String(emission.emission_digest))
		effect_state_digests.append(String(emission.effect_state_digest))
		if delay>0.0:
			_pending_room_emissions.append(emission)
			pending_count+=1
		elif _spawn_room_projectile_spec(emission):
			spawned+=1
	_trace_room_runtime("emit_projectiles",{
		"event_index":int(event.get("index",_room_event_index)),
		"wave_id":wave_id,
		"canonical_wave_id":String(event.get("runtime_canonical_wave_id",event.get("owner_wave_id",""))),
		"live_wave_id":wave_id,
		"requested_count":runtime_specs.size(),
		"spawned_count":spawned,
		"pending_count":pending_count,
		"travel_model":String(projectile.get("travel_model","linear")),
		"visual_token":String(projectile.get("visual_token","room_spike")),
		"execution_context_digest":String(event.get("runtime_execution_context_digest","")),
		"emission_digests":emission_digests,
		"effect_state_digests":effect_state_digests,
	})
	return {"requested":runtime_specs.size(),"spawned":spawned,"pending":pending_count}

func _pending_room_emission_count(wave_id: String) -> int:
	var count := 0
	for pending in _pending_room_emissions:
		if String((pending as Dictionary).get("wave_id",""))==wave_id:
			count+=1
	return count

func _spawn_room_projectile_spec(emission: Dictionary) -> bool:
	var validation := _validate_room_emission(emission)
	var owner_wave := String(emission.get("wave_id",""))
	if not bool(validation.get("valid",false)):
		_trace_room_runtime("emission_rejected",{
			"wave_id":owner_wave,
			"canonical_wave_id":String(emission.get("canonical_wave_id","")),
			"event_index":int(emission.get("event_index",-1)),
			"emission_index":int(emission.get("emission_index",-1)),
			"reason":String(validation.get("reason","invalid_emission")),
			"expected_digest":String(validation.get("expected_digest","")),
			"actual_digest":String(validation.get("actual_digest","")),
		})
		return false
	var spec := (emission.get("spec",{}) as Dictionary).duplicate(true)
	var options := spec.get("options",{}) as Dictionary
	var effect_scope_id := String(options.get("effect_scope_id",""))
	var live_event := {
		"runtime_wave_id":owner_wave,
		"runtime_canonical_wave_id":String(emission.get("canonical_wave_id","")),
		"runtime_execution_context_digest":String(emission.get("execution_context_digest","")),
		"runtime_effect_scope_id":effect_scope_id,
		"index":int(emission.get("event_index",-1)),
		"spawn":{"defender_archetype":String(options.get("source_archetype","none"))},
		"projectile":{"travel_model":String(options.get("travel_model","linear"))},
	}
	var live_specs := _room_projectile_specs_after_defender_effects([spec],live_event,effect_scope_id)
	if live_specs.is_empty():
		var suppressed_effect_state := _room_effect_scope_snapshot(effect_scope_id)
		_trace_room_runtime("emission_suppressed",{
			"wave_id":owner_wave,
			"canonical_wave_id":String(emission.get("canonical_wave_id","")),
			"emission_digest":String(emission.get("emission_digest","")),
			"effect_state_digest":room_runtime_canonical_digest("room-effect-state-v1",suppressed_effect_state),
		})
		return false
	var live_spec := live_specs[0] as Dictionary
	var final_emission := _freeze_room_emission(
		live_spec,
		live_event,
		owner_wave,
		int(emission.get("emission_index",-1)),
		_room_elapsed,
		String(emission.get("emission_digest","")),
		"spawn"
	)
	var final_validation := _validate_room_emission(final_emission)
	if not bool(final_validation.get("valid",false)):
		_trace_room_runtime("emission_rejected",{
			"wave_id":owner_wave,
			"canonical_wave_id":String(emission.get("canonical_wave_id","")),
			"emission_index":int(emission.get("emission_index",-1)),
			"reason":"adjusted_emission_digest_mismatch",
			"expected_digest":String(final_validation.get("expected_digest","")),
			"actual_digest":String(final_validation.get("actual_digest","")),
		})
		return false
	var spawned := _projectiles.spawn_enemy(
		Vector2(live_spec.get("origin", Vector2.ZERO)),
		Vector2(live_spec.get("velocity", Vector2.ZERO)),
		float(live_spec.get("damage", 1.0)),
		(live_spec.get("options", {}) as Dictionary).duplicate(true)
	)
	_trace_room_runtime("projectile_emission_spawned",{
		"wave_id":owner_wave,
		"canonical_wave_id":String(emission.get("canonical_wave_id","")),
		"emission_index":int(emission.get("emission_index",-1)),
		"queued_emission_digest":String(emission.get("emission_digest","")),
		"adjusted_emission_digest":String(final_emission.get("emission_digest","")),
		"effect_state_digest":String(final_emission.get("effect_state_digest","")),
		"spawned":spawned,
	})
	return spawned

func _update_pending_room_emissions(delta: float) -> void:
	for index in range(_pending_room_emissions.size()-1,-1,-1):
		var pending := _pending_room_emissions[index] as Dictionary
		var wave_id := String(pending.get("wave_id", ""))
		if not _active_room_waves.has(wave_id):
			_pending_room_emissions.remove_at(index)
			continue
		var motif := _active_room_motifs.get(wave_id,{}) as Dictionary
		if not bool(motif.get("emitter_active",true)) or _room_elapsed+delta>float(motif.get("ends_at",INF))+0.0001:
			_pending_room_emissions.remove_at(index)
			continue
		var validation := _validate_room_emission(pending)
		if not bool(validation.get("valid",false)):
			_spawn_room_projectile_spec(pending)
			_pending_room_emissions.remove_at(index)
			continue
		if _room_elapsed+delta+0.0001 >= float(pending.get("spawn_at_room_time",INF)):
			# The spawn helper verifies the frozen record again immediately before
			# applying any legitimate live defender-effect revision.
			_spawn_room_projectile_spec(pending)
			_pending_room_emissions.remove_at(index)

func _room_safe_velocity(origin: Vector2, velocity: Vector2, safe_position: Vector2, safe_radius: float, active_seconds: float) -> Vector2:
	var end := origin+velocity*active_seconds
	if not _segment_near_point(origin,end,safe_position,safe_radius):
		return velocity
	var outward := origin-safe_position
	if outward.length_squared() < 0.001:
		outward = Vector2.LEFT if origin.x < INTERNAL_COMBAT_BOUNDS.get_center().x else Vector2.RIGHT
	var tangent := Vector2(-outward.y,outward.x).normalized()
	if velocity.dot(tangent) < 0.0:
		tangent = -tangent
	var adjusted := (outward.normalized()*0.72+tangent*0.69).normalized()*velocity.length()
	if _segment_near_point(origin,origin+adjusted*active_seconds,safe_position,safe_radius):
		adjusted = outward.normalized()*velocity.length()
	return adjusted

static func _segment_near_point(start: Vector2, finish: Vector2, point: Vector2, radius: float) -> bool:
	var segment := finish-start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start.distance_squared_to(point) <= radius*radius
	var ratio := clampf((point-start).dot(segment)/length_squared,0.0,1.0)
	return (start+segment*ratio).distance_squared_to(point) <= radius*radius

func _update_active_room_motifs(delta: float) -> void:
	if _active_room_motifs.is_empty() or _player == null:
		_room_previous_player_position = _player.position if _player != null else Vector2.ZERO
		return
	var current_player_position := _player.position
	for raw_wave_id in _active_room_motifs.keys():
		var wave_id := String(raw_wave_id)
		var motif := _active_room_motifs[raw_wave_id] as Dictionary
		var ends_at := float(motif.get("ends_at",_room_elapsed+1.0))
		if not bool(motif.get("emitter_active",true)) or _room_elapsed+0.0001>=ends_at:
			continue
		var starts_at := float(motif.get("starts_at", _room_elapsed))
		ends_at=maxf(starts_at+0.01,ends_at)
		var effective_delta := minf(delta,maxf(0.0,ends_at-_room_elapsed))
		var sample_time := _room_elapsed+effective_delta
		motif = _advance_room_motif_geometry(motif,effective_delta,starts_at,ends_at)
		_apply_room_field_force(motif,effective_delta)
		var active_fraction := clampf(effective_delta/maxf(delta,0.0001),0.0,1.0)
		var collision_finish := _room_previous_player_position.lerp(_player.position,active_fraction)
		if _room_motif_hits_segment(motif,_room_previous_player_position,collision_finish):
			_apply_player_hits([{
				"damage":float((motif.get("collision",{}) as Dictionary).get("damage",8.0)),
				"cause":String(motif.get("cause","internal hazard")),
				"position":_player.position,
				"group":wave_id,
			}])
			if state not in [RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER] or _player.health<=0.0 or not _active_room_waves.has(wave_id):
				return
		_active_room_motifs[raw_wave_id] = motif
	_room_previous_player_position = _player.position if _player != null else current_player_position

func _advance_room_motif_geometry(motif: Dictionary, delta: float, starts_at: float, ends_at: float) -> Dictionary:
	var prior_time := clampf(float(motif.get("motion_sample_time",starts_at)),starts_at,ends_at)
	var candidate_time := minf(ends_at,prior_time+maxf(0.0,delta))
	var safe_positions: Array = (motif.get("positions",motif.get("base_positions",[])) as Array).duplicate()
	if candidate_time <= prior_time+0.000001:
		return motif
	var safe_time := prior_time
	var substeps := _room_motif_sweep_substeps(motif,prior_time,candidate_time,starts_at,ends_at)
	if substeps <= 0:
		# An extreme hitch or malformed direct call must not trade safety for a
		# coarser sweep. Freeze this visual hazard for the frame within a hard CPU cap.
		return motif
	for substep_index in range(1,substeps+1):
		var sample_time := lerpf(prior_time,candidate_time,float(substep_index)/float(substeps))
		var sample_progress := clampf((sample_time-starts_at)/maxf(0.01,ends_at-starts_at),0.0,1.0)
		var sample_positions := _moved_room_positions(motif,sample_progress,sample_time)
		if _room_motif_signed_safe_clearance(motif,sample_positions) >= ROOM_MOTIF_CLEARANCE_EPSILON:
			safe_time=sample_time
			safe_positions=sample_positions
			continue
		var low_time := safe_time
		var high_time := sample_time
		for _iteration in 12:
			var midpoint := (low_time+high_time)*0.5
			var midpoint_progress := clampf((midpoint-starts_at)/maxf(0.01,ends_at-starts_at),0.0,1.0)
			var midpoint_positions := _moved_room_positions(motif,midpoint_progress,midpoint)
			if _room_motif_signed_safe_clearance(motif,midpoint_positions) >= ROOM_MOTIF_CLEARANCE_EPSILON:
				low_time=midpoint
				safe_positions=midpoint_positions
			else:
				high_time=midpoint
		safe_time=low_time
		break
	motif.positions=safe_positions
	motif.motion_sample_time=safe_time
	return motif

func _room_motif_sweep_substeps(motif: Dictionary, prior_time: float, candidate_time: float, starts_at: float, ends_at: float) -> int:
	var duration := maxf(0.01,ends_at-starts_at)
	var progress_delta := absf(candidate_time-prior_time)/duration
	var movement := motif.get("movement",{}) as Dictionary
	var maximum_motion := 0.0
	match String(movement.get("source_model","lane")):
		"lane":
			maximum_motion=42.0*progress_delta
		"ring":
			var center := room_space_position(movement.get("center",[0.5,0.5]) as Array)
			var maximum_radius := 0.0
			for raw_position in motif.get("base_positions",[]) as Array:
				maximum_radius=maxf(maximum_radius,Vector2(raw_position).distance_to(center))
			maximum_motion=maximum_radius*absf(float(movement.get("angular_rate",0.0)))*(candidate_time-prior_time)
		"sweep":
			maximum_motion=84.0*progress_delta
		"pocket":
			maximum_motion=12.0*PI*progress_delta
		"replay":
			maximum_motion=28.0*progress_delta
	var required_substeps := maxi(1,ceili(maximum_motion/ROOM_MOTIF_SWEEP_MAX_SPATIAL_STEP))
	return 0 if required_substeps>ROOM_MOTIF_SWEEP_MAX_SUBSTEPS else required_substeps

func _moved_room_positions(motif: Dictionary, progress: float, sample_time: float = -1.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var base_positions: Array = motif.get("base_positions", [])
	var movement := motif.get("movement", {}) as Dictionary
	var model := String(movement.get("source_model", "lane"))
	var starts_at := float(motif.get("starts_at",_room_elapsed))
	var runtime_time := _room_elapsed if sample_time<0.0 else sample_time
	var age := maxf(0.0,runtime_time-starts_at)
	for raw_position in base_positions:
		var position := Vector2(raw_position)
		match model:
			"lane":
				position.y += 42.0*progress
			"ring":
				var center := room_space_position(movement.get("center",[0.5,0.5]) as Array)
				position = center+(position-center).rotated(float(movement.get("angular_rate",0.0))*age)
			"sweep":
				var axis := String(movement.get("axis","vertical"))
				var direction := float(movement.get("direction",1))
				if axis == "horizontal":
					position.x += direction*84.0*progress
				else:
					position.y += direction*84.0*progress
			"pocket":
				var pulse := sin(progress*PI)*12.0
				position += (position-INTERNAL_COMBAT_BOUNDS.get_center()).normalized()*pulse
			"replay":
				position += Vector2(0.0,28.0*progress)
		position.x=clampf(position.x,INTERNAL_COMBAT_BOUNDS.position.x,INTERNAL_COMBAT_BOUNDS.end.x)
		position.y=clampf(position.y,INTERNAL_COMBAT_BOUNDS.position.y,INTERNAL_COMBAT_BOUNDS.end.y)
		result.append(position)
	return result

func _room_motif_signed_safe_clearance(motif: Dictionary, positions: Array) -> float:
	var collision := motif.get("collision",{}) as Dictionary
	if not bool(collision.get("enabled",false)) or positions.is_empty():
		return INF
	var safe_center := Vector2(motif.get("safe_position",INTERNAL_COMBAT_BOUNDS.get_center()))
	var safe_radius := float(motif.get("safe_clearance_pixels",34.0))+12.0
	var unit := minf(INTERNAL_COMBAT_BOUNDS.size.x,INTERNAL_COMBAT_BOUNDS.size.y)
	var shape := String(collision.get("shape","circle"))
	var minimum_clearance := INF
	if shape=="segment_chain" and positions.size()>=2:
		var thickness := maxf(8.0,float(collision.get("thickness_normalized",0.025))*unit)
		for index in range(positions.size()-1):
			minimum_clearance=minf(minimum_clearance,_room_point_segment_distance(safe_center,Vector2(positions[index]),Vector2(positions[index+1]))-thickness-safe_radius)
		return minimum_clearance
	var visual_token := String((motif.get("spawn",{}) as Dictionary).get("visual_token",""))
	for position_index in range(positions.size()):
		var center := Vector2(positions[position_index])
		var clearance := INF
		match shape:
			"box", "cell":
				var half_data := collision.get("half_extents_normalized",[0.055,0.055]) as Array
				var half_extents := Vector2(float(half_data[0])*INTERNAL_COMBAT_BOUNDS.size.x,float(half_data[1])*INTERNAL_COMBAT_BOUNDS.size.y)
				clearance=_room_point_rect_distance(safe_center,Rect2(center-half_extents,half_extents*2.0))-safe_radius
			"arc":
				var arc_radius := maxf(20.0,float(collision.get("radius_normalized",0.24))*unit)
				var arc_thickness := maxf(8.0,float(collision.get("thickness_normalized",0.035))*unit)
				var phase_offset := float(abs(visual_token.hash())%17)*0.07+float(position_index)*0.5
				clearance=_room_point_arc_distance(safe_center,center,arc_radius,-1.05+phase_offset,1.05+phase_offset)-arc_thickness-safe_radius
			_:
				var radius := maxf(10.0,float(collision.get("radius_normalized",0.035))*unit)
				clearance=safe_center.distance_to(center)-radius-safe_radius
		minimum_clearance=minf(minimum_clearance,clearance)
	return minimum_clearance

static func _room_point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish-start
	if segment.length_squared()<=0.0001:
		return point.distance_to(start)
	var ratio := clampf((point-start).dot(segment)/segment.length_squared(),0.0,1.0)
	return point.distance_to(start+segment*ratio)

static func _room_point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var delta_x := maxf(maxf(rect.position.x-point.x,0.0),point.x-rect.end.x)
	var delta_y := maxf(maxf(rect.position.y-point.y,0.0),point.y-rect.end.y)
	return Vector2(delta_x,delta_y).length()

static func _room_point_arc_distance(point: Vector2, center: Vector2, radius: float, start_angle: float, end_angle: float) -> float:
	var offset := point-center
	if offset.length_squared()<=0.0001:
		return radius
	var relative_angle := wrapf(offset.angle()-start_angle,0.0,TAU)
	var span := wrapf(end_angle-start_angle,0.0,TAU)
	if relative_angle<=span:
		return absf(offset.length()-radius)
	return minf(point.distance_to(center+Vector2.from_angle(start_angle)*radius),point.distance_to(center+Vector2.from_angle(end_angle)*radius))

func _apply_room_field_force(motif: Dictionary, delta: float) -> void:
	var movement := motif.get("movement", {}) as Dictionary
	var spawn := motif.get("spawn", {}) as Dictionary
	var source_model := String(movement.get("source_model", ""))
	var primitive := String(spawn.get("primitive", ""))
	if source_model != "anchor" and primitive not in ["sweep_field","gravity_field"]:
		return
	var safe_position := Vector2(motif.get("safe_position",INTERNAL_COMBAT_BOUNDS.get_center()))
	if _player.position.distance_to(safe_position) <= float(motif.get("safe_clearance_pixels",34.0)):
		return
	var direction := Vector2.ZERO
	if primitive == "gravity_field":
		direction = (INTERNAL_COMBAT_BOUNDS.get_center()-_player.position).normalized()
	else:
		var authored_direction := movement.get("force_direction",[1.0,0.0]) as Array
		direction = Vector2(float(authored_direction[0]),float(authored_direction[1])).normalized()
	_player.position += direction*82.0*delta
	_player.position.x=clampf(_player.position.x,INTERNAL_COMBAT_BOUNDS.position.x,INTERNAL_COMBAT_BOUNDS.end.x)
	_player.position.y=clampf(_player.position.y,INTERNAL_COMBAT_BOUNDS.position.y,INTERNAL_COMBAT_BOUNDS.end.y)

func _room_motif_hits_segment(motif: Dictionary, start: Vector2, finish: Vector2) -> bool:
	var collision := motif.get("collision", {}) as Dictionary
	if not bool(collision.get("enabled",false)):
		return false
	var shape := String(collision.get("shape","circle"))
	var positions: Array = motif.get("positions", [])
	var unit := minf(INTERNAL_COMBAT_BOUNDS.size.x,INTERNAL_COMBAT_BOUNDS.size.y)
	if shape == "segment_chain" and positions.size() >= 2:
		var thickness := maxf(8.0,float(collision.get("thickness_normalized",0.025))*unit)+12.0
		for index in range(positions.size()-1):
			if _segments_near(start,finish,Vector2(positions[index]),Vector2(positions[index+1]),thickness):
				return true
		return false
	var visual_token := String((motif.get("spawn",{}) as Dictionary).get("visual_token",""))
	for position_index in range(positions.size()):
		var center := Vector2(positions[position_index])
		match shape:
			"box", "cell":
				var half_data := collision.get("half_extents_normalized",[0.055,0.055]) as Array
				var half_extents := Vector2(float(half_data[0])*INTERNAL_COMBAT_BOUNDS.size.x,float(half_data[1])*INTERNAL_COMBAT_BOUNDS.size.y)+Vector2(12.0,12.0)
				if _segment_intersects_box(start,finish,Rect2(center-half_extents,half_extents*2.0)):
					return true
			"arc":
				var arc_radius := maxf(20.0,float(collision.get("radius_normalized",0.24))*unit)
				var thickness := maxf(8.0,float(collision.get("thickness_normalized",0.035))*unit)+12.0
				var phase_offset := float(abs(visual_token.hash())%17)*0.07+float(position_index)*0.5
				if _segment_hits_arc(start,finish,center,arc_radius,thickness,-1.05+phase_offset,1.05+phase_offset):
					return true
			_:
				var radius := maxf(10.0,float(collision.get("radius_normalized",0.035))*unit)+12.0
				if _segment_near_point(start,finish,center,radius):
					return true
	return false

static func _segment_hits_arc(start: Vector2, finish: Vector2, center: Vector2, radius: float, thickness: float, start_angle: float, end_angle: float) -> bool:
	var samples := clampi(ceili(start.distance_to(finish)/maxf(4.0,thickness*0.5)),2,24)
	for sample_index in range(samples+1):
		var point := start.lerp(finish,float(sample_index)/float(samples))
		var offset := point-center
		if absf(offset.length()-radius)>thickness:
			continue
		var angle := wrapf(offset.angle()-start_angle,0.0,TAU)
		var span := wrapf(end_angle-start_angle,0.0,TAU)
		if angle<=span:
			return true
	return false

static func _segment_intersects_box(start: Vector2, finish: Vector2, box: Rect2) -> bool:
	if box.has_point(start) or box.has_point(finish):
		return true
	for edge in [[box.position,Vector2(box.end.x,box.position.y)],[Vector2(box.end.x,box.position.y),box.end],[box.end,Vector2(box.position.x,box.end.y)],[Vector2(box.position.x,box.end.y),box.position]]:
		if Geometry2D.segment_intersects_segment(start,finish,edge[0],edge[1]) != null:
			return true
	return false

static func _segments_near(first_start: Vector2, first_end: Vector2, second_start: Vector2, second_end: Vector2, radius: float) -> bool:
	if Geometry2D.segment_intersects_segment(first_start,first_end,second_start,second_end) != null:
		return true
	return _segment_near_point(first_start,first_end,second_start,radius) \
		or _segment_near_point(first_start,first_end,second_end,radius) \
		or _segment_near_point(second_start,second_end,first_start,radius) \
		or _segment_near_point(second_start,second_end,first_end,radius)

func _spawn_contract_pattern(event: Dictionary) -> void:
	if event.is_empty():
		return
	var execution_validation := _validate_room_execution_context(event)
	if not bool(execution_validation.get("valid",false)):
		_trace_room_runtime("execution_context_rejected",{
			"event_index":int(event.get("index",_room_event_index)),
			"wave_id":String(event.get("runtime_wave_id","")),
			"canonical_wave_id":String(event.get("runtime_canonical_wave_id",event.get("owner_wave_id",""))),
			"live_wave_id":String(event.get("runtime_wave_id","")),
			"reason":String(execution_validation.get("reason","invalid_execution_context")),
			"expected_digest":String(execution_validation.get("expected_digest",event.get("runtime_execution_context_digest",""))),
			"actual_digest":String(execution_validation.get("actual_digest","")),
		})
		return
	var spawn := event.get("spawn", {}) as Dictionary
	var projectile := event.get("projectile", {}) as Dictionary
	var safe_contract := event.get("safe", {}) as Dictionary
	var safe_data: Array = safe_contract.get("position", [0.5,0.5])
	var safe_position := room_space_position(safe_data)
	var active_seconds := maxf(0.08, float(event.get("runtime_active_seconds", float(event.get("clear_at", 0.0)) - float(event.get("active_at", 0.0)))))
	var wave_id := String(event.get("runtime_wave_id",_room_live_wave_id(event,_room_cycle_index)))
	var canonical_wave_id := String(event.get("runtime_canonical_wave_id",event.get("owner_wave_id","")))
	var category := room_runtime_category(event)
	var world_positions := _room_event_world_positions(event, safe_position)
	var cause_id := "room:%s|hazard:%s|category:%s|event:%d|wave:%s" % [
		String(_room_contract.get("room_id", "fallback")),
		String(_room_contract.get("hazard", "unknown")),
		category,
		int(event.get("index", _room_event_index)),
		wave_id,
	]
	var structural_hazard := _room_event_has_structural_hazard(event)
	if structural_hazard and world_positions.is_empty():
		_trace_room_runtime("structural_geometry_rejected",{
			"event_index":int(event.get("index",_room_event_index)),
			"wave_id":wave_id,
			"reason":"no_safe_placement",
		})
		return
	var motif_collision := (spawn.get("collision", {}) as Dictionary).duplicate(true)
	if not structural_hazard:
		motif_collision.enabled = false
	var projectile_seconds := float(event.get("runtime_projectile_seconds",_room_projectile_follow_through_seconds(event,active_seconds)))
	var actor_seconds := float(event.get("runtime_actor_seconds",_room_defender_combat_seconds(event)))
	var wave_seconds := active_seconds
	_active_room_waves[wave_id] = _room_elapsed + wave_seconds
	_active_room_motifs[wave_id] = {
		"wave_id":wave_id,
		"canonical_wave_id":canonical_wave_id,
		"execution_context_digest":String(event.get("runtime_execution_context_digest","")),
		"category":category,
		"event_index":int(event.get("index", _room_event_index)),
		"visual_signature":String(event.get("visual_signature", "")),
		"spawn":spawn.duplicate(true),
		"projectile":projectile.duplicate(true),
		"movement":(event.get("movement", {}) as Dictionary).duplicate(true),
		"collision":motif_collision,
		"structural_hazard":structural_hazard,
		"emitter_active":true,
		"base_positions":world_positions.duplicate(),
		"positions":world_positions.duplicate(),
		"motion_sample_time":_room_elapsed,
		"safe_position":safe_position,
		"safe_clearance_pixels":maxf(34.0, float(safe_contract.get("clearance", 0.1))*minf(INTERNAL_COMBAT_BOUNDS.size.x, INTERNAL_COMBAT_BOUNDS.size.y)),
		"cause":cause_id,
		"starts_at":_room_elapsed,
		"ends_at":_room_elapsed+active_seconds,
		"hard_ends_at":_room_elapsed+wave_seconds,
		"resolve_seconds":wave_seconds,
		"replay_digest":String(event.get("runtime_replay_digest",_room_history_digest())),
	}
	var defender_id := String(spawn.get("defender_archetype", "none"))
	var effect_scope_id := String(event.get("runtime_effect_scope_id",_room_defender_effect_scope_id(defender_id)))
	var enemy_count := mini(int(spawn.get("enemy_count", 0)), world_positions.size())
	if _room_defender_spawn_suppressed(defender_id,effect_scope_id):
		enemy_count=0
	var max_active := clampi(int(spawn.get("max_active_enemies", 1)), 1, RoomPatternRuntimeScript.MAX_ACTIVE_ENEMIES)
	var event_seed := int(event.get("event_seed", _room_contract.get("runtime_seed", 1)))
	var actor_owner_base := String(spawn.get("actor_owner_id", ""))
	var actor_group := "%s:cycle:%d" % [actor_owner_base,_room_cycle_index] if not actor_owner_base.is_empty() else "room_actor:%s:%d:%d" % [String(_room_contract.get("room_id","fallback")),_room_cycle_index,int(event.get("index",_room_event_index))]
	var spawned_enemies := 0
	for index in range(enemy_count):
		if _spawn_enemy(world_positions[index], _mix_room_seed(event_seed,index), actor_group, max_active, {
			"archetype":defender_id,
			"behavior":(spawn.get("defender_behavior", {}) as Dictionary).duplicate(true),
			"visual_token":String(spawn.get("visual_token", defender_id)),
			"anchor_position":world_positions[index],
			"safe_position":safe_position,
			"cause":cause_id,
			"fire_enabled":false,
			"source_wave":wave_id,
			"actor_owner_id":actor_group,
			"effect_scope_id":effect_scope_id,
		}):
			spawned_enemies+=1
	if spawned_enemies>0:
		_active_room_actor_groups[actor_group]=_room_elapsed+actor_seconds
	var projectile_result := _emit_room_projectile_plan(event,wave_id,world_positions,safe_position,active_seconds,cause_id)
	_trace_room_runtime("activated", {
		"event_index":int(event.get("index", _room_event_index)),
		"wave_id":wave_id,
		"canonical_wave_id":canonical_wave_id,
		"live_wave_id":wave_id,
		"execution_context_digest":String(event.get("runtime_execution_context_digest","")),
		"category":category,
		"spawn_primitive":String(spawn.get("primitive", "")),
		"movement_primitive":String((event.get("movement", {}) as Dictionary).get("primitive", "")),
		"projectile_primitive":String(projectile.get("primitive", "")),
		"enemy_count":spawned_enemies,
		"actor_group":actor_group if spawned_enemies>0 else "",
		"actor_owner_base":actor_owner_base,
		"effect_scope_id":effect_scope_id,
		"projectile_count":int(projectile_result.get("spawned",0))+int(projectile_result.get("pending",0)),
		"structural":structural_hazard,
		"emitter_seconds":active_seconds,
		"projectile_seconds":projectile_seconds,
		"actor_seconds":actor_seconds,
		"resolve_seconds":wave_seconds,
		"replay_digest":String(event.get("runtime_replay_digest",_room_history_digest())),
	})
	AudioManager.play_sfx("heartbeat",0.94,0.62)

func _expire_contract_waves() -> void:
	for raw_group in _active_room_waves.keys():
		var group_id := String(raw_group)
		var motif := _active_room_motifs.get(group_id,{}) as Dictionary
		var emitter_active := bool(motif.get("emitter_active",false))
		if emitter_active and _room_elapsed+0.0001>=float(motif.get("ends_at",_room_elapsed)):
			motif.emitter_active=false
			_active_room_motifs[group_id]=motif
			_clear_pending_room_emissions(group_id)
			_trace_room_runtime("emitter_closed",{
				"wave_id":group_id,
				"projectiles_remaining":_projectiles.enemy_group_size(group_id),
				"defenders_remaining":_source_wave_enemy_count(group_id),
			})
			emitter_active=false
		var descendants_resolved := (
			not emitter_active
			and _projectiles.enemy_group_size(group_id)==0
			and _contract_enemy_count(group_id)==0
			and _pending_room_emission_count(group_id)==0
		)
		var deadline_reached := _room_elapsed+0.0001>=float(_active_room_waves[raw_group])
		if descendants_resolved or deadline_reached:
			_finalize_room_wave(group_id,"descendants_resolved" if descendants_resolved else "transient_boundary")

func _finalize_room_wave(group_id: String, reason: String) -> void:
	var cleared_projectiles := _projectiles.clear_enemy_group(group_id)
	var cleared_enemies := _clear_contract_enemies(group_id)
	_active_room_motifs.erase(group_id)
	_clear_pending_room_emissions(group_id)
	_active_room_waves.erase(group_id)
	_trace_room_runtime("clear_wave",{
		"wave_id":group_id,
		"reason":reason,
		"cleared_projectiles":cleared_projectiles,
		"cleared_defenders":cleared_enemies,
	})

func _clear_contract_waves() -> void:
	for raw_group in _active_room_waves.keys():
		var group_id := String(raw_group)
		_projectiles.clear_enemy_group(group_id)
		_clear_contract_enemies(group_id)
		_active_room_motifs.erase(group_id)
		_clear_pending_room_emissions(group_id)
	_active_room_waves.clear()
	_active_room_motifs.clear()
	_pending_room_emissions.clear()
	_clear_room_actor_groups("boundary_cleanup")
	_reset_room_defender_effects()

func _clear_contract_enemies(group_id: String) -> int:
	var cleared := 0
	for index in range(_enemies.size()-1,-1,-1):
		if String(_enemies[index].get("contract_group", "")) == group_id:
			_enemies.remove_at(index)
			cleared+=1
	return cleared

func _contract_enemy_count(group_id: String) -> int:
	var count := 0
	for enemy in _enemies:
		if String((enemy as Dictionary).get("contract_group",""))==group_id:
			count+=1
	return count

func _source_wave_enemy_count(wave_id: String) -> int:
	var count := 0
	for enemy in _enemies:
		if String((enemy as Dictionary).get("source_wave",""))==wave_id:
			count+=1
	return count

func _expire_room_actor_groups() -> void:
	for raw_group_id in _active_room_actor_groups.keys():
		var group_id := String(raw_group_id)
		var actor_count := _contract_enemy_count(group_id)
		if actor_count==0:
			_active_room_actor_groups.erase(raw_group_id)
			_trace_room_runtime("clear_actor_group",{"actor_group":group_id,"reason":"defeated","cleared_defenders":0})
		elif _room_elapsed+0.0001>=float(_active_room_actor_groups[raw_group_id]):
			var cleared := _clear_contract_enemies(group_id)
			_active_room_actor_groups.erase(raw_group_id)
			_trace_room_runtime("clear_actor_group",{"actor_group":group_id,"reason":"deadline","cleared_defenders":cleared})

func _clear_room_actor_groups(reason: String) -> void:
	for raw_group_id in _active_room_actor_groups.keys():
		var group_id := String(raw_group_id)
		var cleared := _clear_contract_enemies(group_id)
		_trace_room_runtime("clear_actor_group",{"actor_group":group_id,"reason":reason,"cleared_defenders":cleared})
	_active_room_actor_groups.clear()

func _clear_pending_room_emissions(group_id: String) -> void:
	for index in range(_pending_room_emissions.size()-1,-1,-1):
		if String(_pending_room_emissions[index].get("wave_id", "")) == group_id:
			_pending_room_emissions.remove_at(index)

func _mix_room_seed(base_seed: int, index: int) -> int:
	return ((base_seed & 0x7FFFFFFF) ^ ((index + 1) * 1103515245) ^ 0x51A7E) & 0x7FFFFFFF

func _update_room(delta: float) -> void:
	if state != RunState.INTERNAL_ROOMS:
		return
	room_timer-=delta
	if room_timer<=0.0:
		var plan_events := _room_pattern_plan.get("events",[]) as Array
		var pending_event := _room_event_index<plan_events.size()
		if pending_event or not _telegraph.is_empty() or not _active_room_waves.is_empty() or not _active_room_actor_groups.is_empty():
			room_timer=0.0
			return
		_start_next_room()

func _begin_internal_route() -> void:
	_transition(RunState.INTERNAL_ROOMS)
	breach_fury_timer=float(_mutation_engine.flags.get("breach_fury_seconds",0.0))
	# Breach Surge is an entry repair: it must help the upcoming internal route
	# and must never trigger again on the return transition.
	_player.heal(float(_permanent_stats.dive_heal))
	room_index=-1
	_boss_visual.set_interior(current_organ)
	_boss_visual.set_health(1,1)
	_player.combat_bounds=INTERNAL_COMBAT_BOUNDS
	_place_player_at_room_entry()
	# Organ selection and the dive tunnel deliberately lock input. The internal
	# route is live combat, so restore movement/dash before the first room starts.
	_player.set_controls_active(true)
	projectiles_clear_and_enemies()
	AudioManager.set_music_state("interior",0.55)
	_start_next_room()

func _resolve_room_contract(room: Dictionary, room_seed: int) -> Dictionary:
	var resolved := RoomMechanicsScript.contract_for(room, room_seed)
	if bool(resolved.get("valid", false)):
		return resolved
	push_error("Room mechanics rejected %s: %s" % [String(room.get("id","?")), resolved.get("errors", [])])
	var fallback := RoomMechanicsScript.safe_fallback_contract(room, room_seed)
	if not bool(fallback.get("valid", false)):
		push_error("Safe room fallback failed closed: %s" % [fallback.get("errors", [])])
	return fallback

func _compile_room_pattern_plan(report_error: bool = true) -> bool:
	var contract_key := _room_contract_key()
	if not _room_pattern_rejection_key.is_empty() and _room_pattern_rejection_key == contract_key:
		return false
	if _room_pattern_rejection_key != contract_key:
		_room_pattern_rejection_key=""
	_room_pattern_plan = RoomPatternRuntimeScript.compile_contract(_room_contract)
	if bool(_room_pattern_plan.get("valid", false)):
		_room_pattern_rejection_key=""
		_trace_room_runtime("plan_built", {
			"room_id":String(_room_pattern_plan.get("room_id", "")),
			"signature":String(_room_pattern_plan.get("plan_signature", "")),
			"contract_key":contract_key,
		})
		return true
	_room_pattern_rejection_key=contract_key
	_trace_room_runtime("plan_rejected",{
		"contract_key":contract_key,
		"errors":(_room_pattern_plan.get("errors",[]) as Array).duplicate(true),
	})
	if report_error:
		push_error("Room runtime plan rejected %s: %s" % [String(_room_contract.get("room_id", "?")), _room_pattern_plan.get("errors", [])])
	return false

func _trace_room_runtime(operation: String, details: Dictionary = {}) -> void:
	var entry := {
		"operation":operation,
		"room_time_ms":roundi(_room_elapsed*1000.0),
		"room_id":String(_room_contract.get("room_id", "")),
	}
	entry.merge(details, true)
	_room_runtime_trace.append(entry)
	if _room_runtime_trace.size() > 512:
		_room_runtime_trace.pop_front()

func _sync_current_room_to_contract() -> void:
	if _room_contract.is_empty() or String(_room_contract.get("room_id","")) == String(current_room.get("id","")):
		return
	current_room = current_room.duplicate(true)
	for key in ["room_id","room_type","hazard","safe_rule","duration","density","boss","organ"]:
		var room_key := String({"room_id":"id","room_type":"type"}.get(key,key))
		current_room[room_key] = _room_contract.get(key,current_room.get(room_key,null))

func _start_next_room() -> void:
	room_index+=1
	projectiles_clear_and_enemies()
	_room_contract.clear()
	_room_pattern_plan.clear()
	_room_elapsed = 0.0
	_room_event_index = 0
	_room_cycle_index = 0
	_room_player_history.clear()
	_room_history_next_sample = 0.0
	_room_history_frame_time = 0.0
	_room_history_frame_position = Vector2.ZERO
	_room_history_initialized = false
	_room_runtime_trace.clear()
	if room_index>=room_layout.size():
		_begin_organ_chamber()
		return
	current_room=room_layout[room_index]
	if String(current_room.get("type",""))=="chamber":
		_begin_organ_chamber()
		return
	room_timer=float(current_room.get("duration",3.0))
	if String(current_room.get("type", "")) == "entrance":
		attack_timer = room_timer + 1.0
		return
	_place_player_at_room_entry()
	_room_contract = _resolve_room_contract(current_room, int(config.seed) + phase * 991 + room_index * 131)
	_sync_current_room_to_contract()
	_compile_room_pattern_plan()
	attack_timer=0.65

func _begin_organ_chamber() -> void:
	_transition(RunState.ORGAN_CHAMBER)
	AudioManager.set_music_state("organ",0.72)
	_organ_hit_count=0
	current_room=room_layout[-1] if not room_layout.is_empty() else {"id":"fallback_chamber","type":"chamber","boss":String(boss_definition.get("id","fallback_boss")),"organ":String(current_organ.get("id","fallback_organ")),"duration":20.0,"hazard":"cell_bloom","safe_rule":"Pass behind the bloom as it opens.","density":1}
	_room_elapsed = 0.0
	_room_event_index = 0
	_room_cycle_index = 0
	_room_player_history.clear()
	_room_history_next_sample = 0.0
	_room_history_frame_time = 0.0
	_room_history_frame_position = Vector2.ZERO
	_room_history_initialized = false
	_room_runtime_trace.clear()
	_place_player_at_room_entry()
	# Keep the chamber's gameplay-state invariant explicit even when a future
	# route bypasses traversal rooms and enters the organ directly.
	_player.set_controls_active(true)
	_room_contract = _resolve_room_contract(current_room, int(config.seed) + phase * 991 + 0x0A61)
	_sync_current_room_to_contract()
	_compile_room_pattern_plan()
	organ_max=float(current_organ.get("hp",1500))*1.65*_difficulty_hp()
	organ_health=organ_max
	_boss_visual.set_interior(current_organ)
	_boss_visual.set_health(organ_health,organ_max)
	attack_timer=0.7
	var organ_name := LocalizationService.content_text("organ",String(current_organ.get("id","")),"name",String(current_organ.get("name",LocalizationService.text("the_organ"))))
	_hud.show_toast(LocalizationService.text("destroy_organ",{"organ":organ_name}),VisualTheme.VULNERABLE)

func _spawn_enemy(at: Vector2, deterministic_seed: int = 0, contract_group: String = "", max_active: int = 64, options: Dictionary = {}) -> bool:
	if _enemies.size() >= maxi(1,max_active):
		return false
	_enemy_serial+=1
	var local_rng := RandomNumberGenerator.new()
	var local_seed := deterministic_seed if deterministic_seed != 0 else _mix_room_seed(int(config.get("seed",1)),_enemy_serial)
	local_rng.seed = local_seed
	var behavior := options.get("behavior", {}) as Dictionary
	var health_class := String(behavior.get("health_class","medium"))
	var health_multiplier := float({"swarm":0.58,"light":0.78,"medium":1.0,"armored":1.48,"decoy":0.68}.get(health_class,1.0))
	var radius := float({"swarm":10.0,"light":13.0,"medium":15.0,"armored":19.0,"decoy":14.0}.get(health_class,14.0))
	_enemies.append({
		"id":"enemy_%d"%_enemy_serial,
		"position":at,
		"velocity":Vector2(local_rng.randf_range(-65,65),local_rng.randf_range(-18,18)),
		"radius":radius,
		"health":90.0*health_multiplier*_difficulty_hp(),
		"shoot_timer":local_rng.randf_range(1.0,2.2),
		"phase":local_rng.randf_range(0,TAU),
		"local_seed":local_seed,
		"shot_sequence":0,
		"shot_telegraph_timer":0.0,
		"shot_telegraph_total":0.0,
		"shot_target":Vector2.ZERO,
		"contract_group":contract_group,
		"actor_owner_id":String(options.get("actor_owner_id",contract_group)),
		"parent_wave":String(options.get("source_wave",contract_group)),
		"source_wave":String(options.get("source_wave",contract_group)),
		"effect_scope_id":String(options.get("effect_scope_id","")),
		"archetype":String(options.get("archetype","generic")),
		"motion":String(behavior.get("motion","generic_chase")),
		"attack":String(behavior.get("attack","aimed_burst")),
		"health_class":health_class,
		"collision_role":String(behavior.get("collision_role","skirmisher")),
		"visual_token":String(options.get("visual_token","generic_defender")),
		"anchor_position":Vector2(options.get("anchor_position",at)),
		"safe_position":Vector2(options.get("safe_position",Vector2.ZERO)),
		"cause":String(options.get("cause","internal_defender")),
		"fire_enabled":bool(options.get("fire_enabled",true)),
		"effect_priority_seconds":0.0,
		"effect_damage_multiplier":1.0,
		"effect_link_broken_seconds":0.0,
		"effect_hatch_suppressed_seconds":0.0,
		"effect_echo_disrupted_seconds":0.0,
	})
	queue_redraw()
	return true

func _update_enemies(delta: float) -> void:
	for index in _enemies.size():
		var enemy:Dictionary=_enemies[index]
		for timer_key in ["effect_priority_seconds","effect_link_broken_seconds","effect_hatch_suppressed_seconds","effect_echo_disrupted_seconds"]:
			enemy[timer_key]=maxf(0.0,float(enemy.get(timer_key,0.0))-delta)
		if float(enemy.get("effect_priority_seconds",0.0))<=0.0:
			enemy.effect_damage_multiplier=1.0
		enemy.phase=float(enemy.phase)+delta
		enemy = _move_internal_enemy(enemy,delta)
		enemy.position.x=clampf(Vector2(enemy.position).x,35,505)
		enemy.position.y=clampf(Vector2(enemy.position).y,INTERNAL_COMBAT_BOUNDS.position.y,INTERNAL_COMBAT_BOUNDS.end.y)
		var safe_position := Vector2(enemy.get("safe_position",Vector2.ZERO))
		if safe_position != Vector2.ZERO and Vector2(enemy.position).distance_to(safe_position)<52.0:
			var away := Vector2(enemy.position)-safe_position
			if away.length_squared()<0.001:
				away=Vector2.LEFT if int(enemy.local_seed)%2==0 else Vector2.RIGHT
			enemy.position=safe_position+away.normalized()*52.0
		# The event plan emits the defender volley. A second autonomous shot
		# source would violate both the safe corridor and atomic wave cleanup.
		if not bool(enemy.get("fire_enabled",true)):
			_enemies[index]=enemy
			continue
		if float(enemy.get("shot_telegraph_timer",0.0)) > 0.0:
			enemy.shot_telegraph_timer = float(enemy.shot_telegraph_timer)-delta
			if float(enemy.shot_telegraph_timer)<=0.0:
				var target := Vector2(enemy.get("shot_target",_player.position))
				var angle := (target-Vector2(enemy.position)).angle()
				var contract_group := String(enemy.get("contract_group",""))
				var shot_group := contract_group if not contract_group.is_empty() else "defender:%s:%d" % [String(enemy.id),int(enemy.shot_sequence)]
				_projectiles.spawn_enemy(enemy.position,Vector2.from_angle(angle)*215*_difficulty_projectile_speed(),8,{"radius":5.0,"life":3.0,"cause":String(enemy.get("cause","internal_defender")),"group":shot_group,"parent_group":contract_group})
				enemy.shot_sequence = int(enemy.shot_sequence)+1
				var cooldown_rng := RandomNumberGenerator.new()
				cooldown_rng.seed = _mix_room_seed(int(enemy.local_seed),int(enemy.shot_sequence)+97)
				enemy.shoot_timer = cooldown_rng.randf_range(1.5,2.5)
		else:
			enemy.shoot_timer=float(enemy.shoot_timer)-delta
			if float(enemy.shoot_timer)<=0.0:
				var defender_warning := maxf(0.1,INTERNAL_DEFENDER_TELEGRAPH_SECONDS*_assist_number("assist_telegraph",1.0))
				enemy.shot_telegraph_timer = defender_warning
				enemy.shot_telegraph_total = defender_warning
				enemy.shot_target = _player.position
		_enemies[index]=enemy

func _move_internal_enemy(enemy: Dictionary, delta: float) -> Dictionary:
	var position := Vector2(enemy.position)
	var velocity := Vector2(enemy.velocity)
	var anchor := Vector2(enemy.get("anchor_position",position))
	var to_player := _player.position-position
	var phase_value := float(enemy.phase)
	match String(enemy.get("motion","generic_chase")):
		"orbit_arc", "paired_orbit":
			var radius := 24.0 if String(enemy.motion)=="orbit_arc" else 34.0
			var desired := anchor+Vector2.from_angle(phase_value*(1.4 if String(enemy.motion)=="orbit_arc" else -1.15))*radius
			velocity=velocity.lerp((desired-position)*4.0,1.0-exp(-4.0*delta))
		"lane_cross":
			var direction := -1.0 if int(enemy.local_seed)%2==0 else 1.0
			velocity=velocity.lerp(Vector2(direction*82.0,sin(phase_value*2.2)*18.0),1.0-exp(-3.0*delta))
		"cover_anchor":
			velocity=velocity.lerp((anchor-position)*3.2+Vector2(0,sin(phase_value*2.0)*12.0),1.0-exp(-3.5*delta))
		"soft_pursuit":
			velocity=velocity.lerp(to_player.normalized()*72.0,1.0-exp(-1.7*delta))
		"sweep_anchor":
			var desired := anchor+Vector2(sin(phase_value*1.6)*64.0,0.0)
			velocity=velocity.lerp((desired-position)*3.0,1.0-exp(-3.0*delta))
		"lane_rush":
			velocity=velocity.lerp(Vector2(0.0,118.0),1.0-exp(-4.0*delta))
		"echo_follow":
			var mirror_target := Vector2(INTERNAL_COMBAT_BOUNDS.end.x-(_player.position.x-INTERNAL_COMBAT_BOUNDS.position.x),_player.position.y-72.0)
			velocity=velocity.lerp((mirror_target-position).normalized()*68.0,1.0-exp(-2.0*delta))
		"pocket_shift":
			var desired := anchor+Vector2(sin(phase_value*2.4)*28.0,cos(phase_value*1.7)*18.0)
			velocity=velocity.lerp((desired-position)*3.4,1.0-exp(-3.2*delta))
		_:
			velocity=velocity.lerp(to_player.normalized()*58.0,1.0-exp(-1.2*delta))
	if float(enemy.get("effect_echo_disrupted_seconds",0.0))>0.0:
		velocity*=0.42
	elif float(enemy.get("effect_link_broken_seconds",0.0))>0.0:
		velocity*=0.68
	position+=velocity*delta+Vector2(0,sin(phase_value*3.0)*10.0*delta)
	enemy.position=position
	enemy.velocity=velocity
	return enemy

func _reset_room_defender_effects() -> void:
	_room_defender_effect_state={
		"scopes":{},
		"kill_effects_applied":0,
	}
	_room_defender_effect_events.clear()
	_room_defender_effect_sources.clear()
	_room_defender_covers.clear()
	_room_defender_kill_sequence=0

func _room_defender_effect_scope_id(archetype: String) -> String:
	return "room-effect:%s:cycle:%d:%s" % [String(_room_contract.get("room_id","fallback")),_room_cycle_index,archetype]

func _room_effect_flag_active(flag_id: String, effect_scope_id: String) -> bool:
	if _room_defender_effect_state.is_empty() or effect_scope_id.is_empty():
		return false
	var scope := (_room_defender_effect_state.get("scopes",{}) as Dictionary).get(effect_scope_id,{}) as Dictionary
	return float((scope.get("flags",{}) as Dictionary).get(flag_id,0.0))>0.0

func _room_effect_scope_for_owner(owner_wave: String) -> String:
	for raw_scope_id in (_room_defender_effect_state.get("scopes",{}) as Dictionary).keys():
		var scope_id := String(raw_scope_id)
		var scope := (_room_defender_effect_state.scopes as Dictionary)[raw_scope_id] as Dictionary
		if String(scope.get("owner_wave_id",""))==owner_wave:
			return scope_id
	return ""

func _room_effect_flag_active_any(flag_id: String) -> bool:
	for raw_scope in (_room_defender_effect_state.get("scopes",{}) as Dictionary).values():
		if float(((raw_scope as Dictionary).get("flags",{}) as Dictionary).get(flag_id,0.0))>0.0:
			return true
	return false

func _room_effect_value_max(flag_id: String, value_id: String, fallback: float = 1.0) -> float:
	var result := fallback
	for raw_scope in (_room_defender_effect_state.get("scopes",{}) as Dictionary).values():
		var scope := raw_scope as Dictionary
		if float((scope.get("flags",{}) as Dictionary).get(flag_id,0.0))<=0.0:
			continue
		result=maxf(result,float((scope.get("values",{}) as Dictionary).get(value_id,fallback)))
	return result

func _merge_room_defender_state_patch(patch: Dictionary, effect_scope_id: String, owner_wave: String, actor_owner: String) -> void:
	if _room_defender_effect_state.is_empty():
		_reset_room_defender_effects()
	if effect_scope_id.is_empty() or owner_wave.is_empty():
		return
	var scopes := _room_defender_effect_state.get("scopes",{}) as Dictionary
	var scope := scopes.get(effect_scope_id,{"flags":{},"timers":{},"tags":{},"values":{}}) as Dictionary
	scope.effect_scope_id=effect_scope_id
	scope.owner_wave_id=owner_wave
	scope.actor_owner_id=actor_owner
	var state_timers := scope.get("timers",{}) as Dictionary
	var patch_timers := patch.get("timers",{}) as Dictionary
	for raw_timer_key in patch_timers.keys():
		var timer_key := String(raw_timer_key)
		state_timers[timer_key]=maxf(float(state_timers.get(timer_key,0.0)),float(patch_timers[raw_timer_key]))
	scope.timers=state_timers
	var state_flags := scope.get("flags",{}) as Dictionary
	for raw_flag in (patch.get("wave_flags",{}) as Dictionary).keys():
		var flag_id := String(raw_flag)
		if not bool((patch.get("wave_flags",{}) as Dictionary)[raw_flag]):
			continue
		var timer_key := String(ROOM_EFFECT_TIMER_BY_FLAG.get(flag_id,""))
		var duration := float(patch_timers.get(timer_key,0.1))
		state_flags[flag_id]=maxf(float(state_flags.get(flag_id,0.0)),duration)
	scope.flags=state_flags
	var state_tags := scope.get("tags",{}) as Dictionary
	for raw_tag in patch.get("tags_add",[]) as Array:
		state_tags[String(raw_tag)]=true
	scope.tags=state_tags
	scopes[effect_scope_id]=scope
	_room_defender_effect_state.scopes=scopes
	_room_defender_effect_state.kill_effects_applied=int(_room_defender_effect_state.get("kill_effects_applied",0))+int(patch.get("kill_effects_applied_add",0))

func _update_room_defender_effects(delta: float) -> void:
	if _room_defender_effect_state.is_empty() and _room_defender_covers.is_empty():
		return
	var scopes := _room_defender_effect_state.get("scopes",{}) as Dictionary
	for raw_owner_wave in scopes.keys():
		var owner_wave := String(raw_owner_wave)
		var scope := scopes[raw_owner_wave] as Dictionary
		for collection_key in ["flags","timers"]:
			var collection := scope.get(collection_key,{}) as Dictionary
			for raw_key in collection.keys():
				var key := String(raw_key)
				var remaining := maxf(0.0,float(collection[raw_key])-delta)
				if remaining<=0.0:
					collection.erase(raw_key)
				else:
					collection[key]=remaining
			scope[collection_key]=collection
		if float((scope.get("flags",{}) as Dictionary).get("true_target_revealed",0.0))<=0.0:
			(scope.get("values",{}) as Dictionary).erase("true_target_damage_multiplier")
		scopes[owner_wave]=scope
	_room_defender_effect_state.scopes=scopes
	for index in range(_room_defender_covers.size()-1,-1,-1):
		var cover := _room_defender_covers[index] as Dictionary
		cover.life=maxf(0.0,float(cover.get("life",0.0))-delta)
		var absorb_remaining := maxi(0,int(cover.get("absorb_remaining",0)))
		if absorb_remaining>0 and _projectiles!=null:
			var consumed := _projectiles.consume_enemy_near_capped(Vector2(cover.get("position",Vector2.ZERO)),float(cover.get("radius",0.0)),absorb_remaining,String(cover.get("owner_wave_id","")),String(cover.get("effect_scope_id","")))
			cover.absorb_remaining=absorb_remaining-consumed
			if consumed>0:
				score+=consumed*10
				AudioManager.play_sfx("shield_break",1.12,0.24)
		if float(cover.life)<=0.0 or int(cover.get("absorb_remaining",0))<=0:
			_room_defender_covers.remove_at(index)
		else:
			_room_defender_covers[index]=cover
	queue_redraw()

func _apply_room_defender_kill_effect(enemy: Dictionary) -> Dictionary:
	var defender_id := String(enemy.get("id",""))
	if defender_id.is_empty() or _room_defender_effect_sources.has(defender_id):
		return {"applied":false,"reason":"duplicate_or_missing_source"}
	var source_wave := String(enemy.get("source_wave",enemy.get("parent_wave","")))
	if source_wave.is_empty():
		return {"applied":false,"reason":"not_room_owned"}
	_room_defender_kill_sequence+=1
	var remaining_ids: Array[String] = []
	for candidate in _enemies:
		if String((candidate as Dictionary).get("source_wave",""))==source_wave:
			remaining_ids.append(String((candidate as Dictionary).get("id","")))
	var effect := RoomDefenderEffectsScript.compile_kill_effect(enemy,{
		"kill_sequence":_room_defender_kill_sequence,
		"remaining_defender_ids":remaining_ids,
		"true_target_id":"organ" if state==RunState.ORGAN_CHAMBER else "",
		"link_id":String(enemy.get("actor_owner_id",source_wave)),
	})
	if not bool(effect.get("valid",false)):
		return {"applied":false,"reason":"invalid_effect","errors":effect.get("errors",PackedStringArray())}
	var event_id := String(effect.get("effect_event_id",""))
	if event_id.is_empty() or _room_defender_effect_events.has(event_id):
		return {"applied":false,"reason":"duplicate_event"}
	_room_defender_effect_events[event_id]=true
	_room_defender_effect_sources[defender_id]=event_id
	var effect_scope_id := String(enemy.get("effect_scope_id",_room_defender_effect_scope_id(String(enemy.get("archetype","unknown")))))
	_merge_room_defender_state_patch(effect.get("state_patch",{}) as Dictionary,effect_scope_id,String(effect.get("owner_wave_id","")),String(enemy.get("actor_owner_id","")))
	var operation_results: Array[Dictionary] = []
	for raw_operation in effect.get("operations",[]) as Array:
		operation_results.append(_execute_room_defender_operation(raw_operation as Dictionary))
	_trace_room_runtime("defender_kill_effect",{
		"effect_event_id":event_id,
		"effect_id":String(effect.get("effect_id","")),
		"source_defender_id":defender_id,
		"owner_wave_id":String(effect.get("owner_wave_id","")),
		"effect_scope_id":effect_scope_id,
		"operation_results":operation_results.duplicate(true),
	})
	return {"applied":true,"effect":effect,"operation_results":operation_results}

func _execute_room_defender_operation(operation: Dictionary) -> Dictionary:
	var op_id := String(operation.get("op",""))
	var owner_wave := String(operation.get("owner_wave_id",""))
	var affected := 0
	match op_id:
		"spawn_timed_cover":
			var position_data := operation.get("position",[]) as Array
			if position_data.size()==2:
				var duration := maxf(0.05,float(operation.get("duration_seconds",0.05)))
				var effect_scope_id := _room_effect_scope_for_owner(owner_wave)
				_room_defender_covers.append({
					"id":"cover:%s" % String(operation.get("effect_event_id","effect")),
					"owner_wave_id":owner_wave,
					"effect_scope_id":effect_scope_id,
					"position":Vector2(float(position_data[0]),float(position_data[1])),
					"radius":maxf(8.0,float(operation.get("radius_pixels",8.0))),
					"life":duration,
					"duration":duration,
					"absorb_remaining":maxi(0,int(operation.get("absorb_count",0))),
					"material":String(operation.get("material","tissue")),
				})
				affected=1
		"cancel_pending_emissions":
			affected=_cancel_pending_room_emissions_capped(owner_wave,int(operation.get("max_count",0)))
		"clear_owned_projectiles":
			affected=_projectiles.clear_enemy_group_filtered(owner_wave,operation.get("travel_models",[]) as Array,int(operation.get("max_count",0)))
		"mark_priority_target":
			affected=_mark_room_priority_target(owner_wave,operation)
		"disable_tracking":
			var effect_scope_id := _room_effect_scope_for_owner(owner_wave)
			affected=_clear_owned_homing_projectiles(owner_wave,effect_scope_id)
			_trace_room_runtime("tracking_projectiles_suppressed",{
				"owner_wave_id":owner_wave,
				"effect_scope_id":effect_scope_id,
				"affected_count":affected,
			})
		"break_link":
			affected=_mark_room_wave_enemies(owner_wave,"effect_link_broken_seconds",float(operation.get("duration_seconds",0.0)),String(operation.get("link_id","")))
		"suppress_hatch":
			affected=_mark_room_wave_enemies(owner_wave,"effect_hatch_suppressed_seconds",float(operation.get("duration_seconds",0.0)))
		"disrupt_echo":
			affected=_mark_room_wave_enemies(owner_wave,"effect_echo_disrupted_seconds",float(operation.get("duration_seconds",0.0)))
		"reveal_true_target":
			var scopes := _room_defender_effect_state.get("scopes",{}) as Dictionary
			var effect_scope_id := _room_effect_scope_for_owner(owner_wave)
			var scope := scopes.get(effect_scope_id,{"flags":{},"timers":{},"tags":{},"values":{}}) as Dictionary
			var values := scope.get("values",{}) as Dictionary
			values.true_target_id=String(operation.get("true_target_id",""))
			values.true_target_damage_multiplier=maxf(float(values.get("true_target_damage_multiplier",1.0)),float(operation.get("damage_multiplier",1.0)))
			scope.values=values
			scopes[effect_scope_id]=scope
			_room_defender_effect_state.scopes=scopes
			affected=1
		"remove_false_targets":
			affected=_remove_room_false_targets(owner_wave,int(operation.get("max_count",0)))
		_:
			push_error("Unsupported live defender effect operation: %s" % op_id)
	return {"op":op_id,"affected":affected,"owner_wave_id":owner_wave}

func _clear_owned_homing_projectiles(owner_wave: String, effect_scope_id: String) -> int:
	if owner_wave.is_empty() or effect_scope_id.is_empty() or _projectiles==null:
		return 0
	# A warned homing curve must never be straightened after activation: the
	# replacement ray could cross space that the signed preview declared safe.
	# Removing only this canonical wave's homing descendants is monotonic-safe,
	# keeps foreign waves intact, and uses the pool's public ownership boundary.
	return _projectiles.clear_enemy_homing_group(owner_wave,ProjectilePool.MAX_ENEMY)

func _cancel_pending_room_emissions_capped(owner_wave: String, max_count: int) -> int:
	if owner_wave.is_empty() or max_count<=0:
		return 0
	var removed := 0
	for index in range(_pending_room_emissions.size()-1,-1,-1):
		if String(_pending_room_emissions[index].get("wave_id",""))!=owner_wave:
			continue
		_pending_room_emissions.remove_at(index)
		removed+=1
		if removed>=max_count:
			break
	return removed

func _mark_room_priority_target(owner_wave: String, operation: Dictionary) -> int:
	var candidate_ids := operation.get("candidate_ids",[]) as Array
	var selected_index := -1
	var best_distance := INF
	for index in _enemies.size():
		var enemy := _enemies[index] as Dictionary
		if String(enemy.get("source_wave",""))!=owner_wave:
			continue
		var enemy_id := String(enemy.get("id",""))
		if not candidate_ids.is_empty() and enemy_id not in candidate_ids:
			continue
		var distance := _player.position.distance_squared_to(Vector2(enemy.get("position",Vector2.ZERO))) if _player!=null else float(index)
		if distance<best_distance:
			best_distance=distance
			selected_index=index
	if selected_index<0:
		return 0
	_enemies[selected_index].effect_priority_seconds=maxf(float(_enemies[selected_index].get("effect_priority_seconds",0.0)),float(operation.get("duration_seconds",0.0)))
	_enemies[selected_index].effect_damage_multiplier=maxf(float(_enemies[selected_index].get("effect_damage_multiplier",1.0)),float(operation.get("damage_multiplier",1.0)))
	_enemies[selected_index].effect_mark_event_id=String(operation.get("effect_event_id",""))
	return 1

func _mark_room_wave_enemies(owner_wave: String, timer_key: String, duration: float, actor_owner_filter: String = "") -> int:
	var affected := 0
	for index in _enemies.size():
		var enemy := _enemies[index] as Dictionary
		if String(enemy.get("source_wave",""))!=owner_wave:
			continue
		if not actor_owner_filter.is_empty() and String(enemy.get("actor_owner_id",""))!=actor_owner_filter:
			continue
		enemy[timer_key]=maxf(float(enemy.get(timer_key,0.0)),duration)
		_enemies[index]=enemy
		affected+=1
	return affected

func _remove_room_false_targets(owner_wave: String, max_count: int) -> int:
	var removed := 0
	for index in range(_enemies.size()-1,-1,-1):
		var enemy := _enemies[index] as Dictionary
		if String(enemy.get("source_wave",""))!=owner_wave or String(enemy.get("collision_role",""))!="false_target":
			continue
		_enemies.remove_at(index)
		removed+=1
		if removed>=max_count:
			break
	return removed

func _room_defender_spawn_suppressed(archetype: String, effect_scope_id: String) -> bool:
	return (
		(archetype=="arc_linker" and _room_effect_flag_active("link_broken",effect_scope_id))
		or (archetype=="hatchling" and _room_effect_flag_active("hatch_suppressed",effect_scope_id))
		or (archetype=="echo_clone" and _room_effect_flag_active("echo_disrupted",effect_scope_id))
		or (archetype=="decoy_core" and _room_effect_flag_active("true_target_revealed",effect_scope_id))
	)

func _kill_enemy(index: int) -> void:
	if index<0 or index>=_enemies.size():
		return
	var enemy: Dictionary = _enemies.pop_at(index)
	_apply_room_defender_kill_effect(enemy)
	_spawn_bio_pickup(Vector2(enemy.position),7)
	score+=180
	AudioManager.play_sfx("tissue_hit",_rng.randf_range(0.9,1.1),0.6)
	if int(_mutation_engine.flags.get("internal_kill_heal",0))>0:
		var kill_count:=int(_mutation_engine.flags.get("_internal_kills",0))+1
		_mutation_engine.flags._internal_kills=kill_count
		if kill_count%int(_mutation_engine.flags.get("heal_every_kills",5))==0:
			_player.heal(float(_mutation_engine.flags.internal_kill_heal))
	queue_redraw()

func _spawn_bio_pickup(at: Vector2, amount: int) -> void:
	_bio_pickups.append({
		"position":at,
		"velocity":Vector2(_rng.randf_range(-42.0,42.0),_rng.randf_range(-32.0,8.0)),
		"amount":maxi(0,amount),
		"phase":_rng.randf_range(0.0,TAU)
	})

func _bio_magnet_radius() -> float:
	return 72.0*float(_permanent_stats.get("magnet_mul",1.0))*float(_mutation_engine.stats.get("magnet_mul",1.0))

func _update_bio_pickups(delta: float) -> void:
	var magnet_radius := _bio_magnet_radius()
	for index in range(_bio_pickups.size()-1,-1,-1):
		var pickup: Dictionary = _bio_pickups[index]
		pickup.phase=float(pickup.phase)+delta*4.0
		var offset:=_player.position-Vector2(pickup.position)
		if offset.length() <= magnet_radius:
			var pull_speed:=lerpf(145.0,620.0,1.0-clampf(offset.length()/maxf(1.0,magnet_radius),0.0,1.0))
			pickup.velocity=Vector2(pickup.velocity).lerp(offset.normalized()*pull_speed,1.0-exp(-8.0*delta))
		else:
			pickup.velocity=Vector2(pickup.velocity).lerp(Vector2.ZERO,1.0-exp(-2.5*delta))
		pickup.position=Vector2(pickup.position)+Vector2(pickup.velocity)*delta
		if Vector2(pickup.position).distance_to(_player.position)<=18.0:
			_grant_bio(int(pickup.amount),true)
			_bio_pickups.remove_at(index)
			AudioManager.play_sfx("pickup",1.0,0.42)
		else:
			_bio_pickups[index]=pickup

func _grant_bio(amount: int, collected: bool = false) -> void:
	var safe_amount:=maxi(0,amount)
	run_bio+=safe_amount
	if not collected or _player==null:
		return
	var threshold:=int(_mutation_engine.flags.get("shield_every_bio",0))
	if threshold<=0:
		return
	_bio_since_shield+=safe_amount
	var shield_count:=int(floor(float(_bio_since_shield)/float(threshold)))
	if shield_count>0:
		_bio_since_shield-=shield_count*threshold
		_player.add_shield_hit(shield_count)

func _collect_remaining_bio() -> void:
	for pickup in _bio_pickups:
		_grant_bio(int(pickup.amount),true)
	_bio_pickups.clear()

func _update_calm_heal(delta: float) -> void:
	var threshold:=float(_mutation_engine.flags.get("calm_heal_seconds",0.0))
	var heal_amount:=float(_mutation_engine.flags.get("calm_heal",0.0))
	if threshold<=0.0 or heal_amount<=0.0:
		return
	calm_timer+=delta
	while calm_timer>=threshold:
		calm_timer-=threshold
		_player.heal(heal_amount)

func _emit_dash_wake_point() -> void:
	if not bool(_mutation_engine.flags.get("dash_trail",false)):
		return
	_dash_wakes.append({
		"position":_player.position,
		"life":float(_mutation_engine.flags.get("dash_trail_duration",1.2)),
		"group":_active_dash_wake_id
	})
	_last_dash_wake_position=_player.position

func _update_dash_wakes(delta: float, exterior: bool) -> void:
	if _player.dash_time>0.0 and _active_dash_wake_id>0 and _player.position.distance_to(_last_dash_wake_position)>=14.0:
		_emit_dash_wake_point()
	for index in range(_dash_wakes.size()-1,-1,-1):
		_dash_wakes[index].life=float(_dash_wakes[index].life)-delta
		if float(_dash_wakes[index].life)<=0.0:
			_dash_wakes.remove_at(index)
	var targets:=_target_infos(exterior)
	for wake in _dash_wakes:
		var group:=int(wake.group)
		var hits: Dictionary = _dash_wake_hits.get(group,{})
		for raw_target in targets:
			var target: Dictionary = raw_target
			var target_id:=String(target.id)
			if hits.has(target_id):
				continue
			if Vector2(wake.position).distance_to(Vector2(target.position))<=float(target.radius)+15.0:
				hits[target_id]=true
				var damage:=float(_mutation_engine.flags.get("dash_trail_damage",0.0))*float(_permanent_stats.damage_mul)
				damage*=_mutation_engine.damage_multiplier(_current_damage_zone(),_player.position.distance_to(Vector2(target.position)),_player.health_ratio(),organs_destroyed,shot_streak,wound_memory_timer>0.0)
				_damage_target({"id":target_id,"damage":damage,"behavior":"phase_wake"})
		_dash_wake_hits[group]=hits
	var live_groups: Dictionary = {}
	for wake in _dash_wakes:
		live_groups[int(wake.group)]=true
	for raw_group in _dash_wake_hits.keys():
		if not live_groups.has(int(raw_group)):
			_dash_wake_hits.erase(raw_group)

func projectiles_clear_and_enemies() -> void:
	_collect_remaining_bio()
	_cancel_attack_avoidance()
	_projectiles.clear_all()
	_enemies.clear()
	_active_room_waves.clear()
	_active_room_actor_groups.clear()
	_active_room_motifs.clear()
	_pending_room_emissions.clear()
	_pending_echoes.clear()
	_room_pattern_plan.clear()
	_room_pattern_rejection_key=""
	_room_player_history.clear()
	_room_history_next_sample = 0.0
	_room_history_frame_time = 0.0
	_room_history_frame_position = Vector2.ZERO
	_room_history_initialized = false
	_room_previous_player_position = Vector2.ZERO
	_reset_room_defender_effects()
	_telegraph.clear()
	_dash_wakes.clear()
	_dash_wake_hits.clear()

func _open_breach() -> void:
	if state!=RunState.EXTERIOR:
		return
	_transition(RunState.BREACH_OPEN)
	breach_timer = 7.0 * float(_permanent_stats.get("breach_duration_mul", 1.0))
	_grant_bio(int(round((70+phase*25)*float(_mutation_engine.stats.get("breach_reward_mul",1.0)))))
	score+=1200+phase*300
	_cancel_attack_avoidance()
	_projectiles.clear_enemy()
	_boss_visual.set_exterior(phase,_organ_map.destroyed_organs(),true,_organ_map.visual_states())
	_boss_visual.set_health(0,armor_max)
	_hud.set_dive_ready(true)
	_hud.show_toast(LocalizationService.text("breach_enter"),VisualTheme.VULNERABLE)
	AudioManager.play_sfx("breach",1.0,1.0)
	SettingsManager.pulse_haptic(45,0.85)
	world_shake=15.0
	hit_stop_timer=0.09
	if not _first_breach_sent:
		_first_breach_sent=true
		AnalyticsService.track("first_breach",{"seconds":elapsed})

func _close_breach() -> void:
	if state != RunState.BREACH_OPEN:
		return
	breach_timer = 0.0
	armor_health = maxf(1.0, armor_max * 0.18)
	_boss_visual.set_exterior(phase, _organ_map.destroyed_organs(), false, _organ_map.visual_states())
	_boss_visual.set_health(armor_health, armor_max)
	_hud.set_dive_ready(false)
	_hud.show_toast(LocalizationService.text("breach_lost"), VisualTheme.TELEGRAPH)
	_transition(RunState.EXTERIOR)
	attack_timer = 1.0

func _request_dive() -> void:
	if _paused or state!=RunState.BREACH_OPEN:
		return
	breach_timer = 0.0
	_transition(RunState.ORGAN_SELECT)
	_player.set_controls_active(false)
	_hud.set_dive_ready(false)
	var organ_defs:Array=[]
	for organ_id in _organ_map.alive_organs():
		for raw_organ in boss_definition.get("organs",[]):
			var organ:Dictionary=raw_organ
			if String(organ.id)==organ_id:
				organ_defs.append(organ)
	_hud.show_organ_choices(organ_defs, int(_permanent_stats.get("organ_preview", 0)))

func _select_organ(organ_id: String) -> void:
	if state!=RunState.ORGAN_SELECT or not _organ_map.alive_organs().has(organ_id):
		return
	for raw_organ in boss_definition.get("organs",[]):
		var organ:Dictionary=raw_organ
		if String(organ.id)==organ_id:
			current_organ=organ.duplicate(true)
			break
	room_layout=_room_generator.generate(GameData.rooms,String(boss_definition.id),organ_id,int(config.seed)+phase*991+organ_id.hash())
	if not _room_generator.validate_layout(room_layout):
		push_error("Generated invalid room layout; using safe fallback")
		room_layout=[{"id":"entrance","type":"entrance","duration":1.0,"hazard":"none"},{"id":"fallback","type":"chamber","boss":String(boss_definition.id),"organ":organ_id,"duration":20.0,"hazard":"cell_bloom","safe_rule":"Pass behind the bloom as it opens.","density":1}]
	_transition(RunState.DIVING_IN)
	transition_timer=1.15
	_player.set_controls_active(false)
	_projectiles.clear_all()
	AudioManager.set_music_state("dive",0.72)
	AudioManager.play_sfx("dive",1.0,1.0)
	SettingsManager.pulse_haptic(34,0.7)
	if not _first_dive_sent:
		_first_dive_sent=true
		AnalyticsService.track("first_dive",{"seconds":elapsed,"organ":organ_id})
		_tutorial_observe(TutorialFlowScript.EVENT_FIRST_DIVE)

func _destroy_current_organ() -> void:
	if state!=RunState.ORGAN_CHAMBER:
		return
	var change:=_organ_map.destroy_organ(String(current_organ.id))
	if change.is_empty():
		return
	organs_destroyed+=1
	_grant_bio(95+phase*25)
	score+=3500+phase*600
	projectiles_clear_and_enemies()
	_room_contract.clear()
	_room_elapsed = 0.0
	_room_event_index = 0
	_room_cycle_index = 0
	_player.set_controls_active(false)
	world_shake=22.0
	hit_stop_timer=0.13
	AudioManager.play_sfx("organ_destroyed",1.0,1.0)
	SettingsManager.pulse_haptic(80,1.0)
	AnalyticsService.track("organ_destroyed",{"boss":String(boss_definition.id),"organ":String(current_organ.id),"order":organs_destroyed})
	_meta_progress("organ_destroyed", {"event_id":"%s:organ:%s" % [run_id,String(current_organ.id)],"organ_id":String(current_organ.id),"boss_id":String(boss_definition.id)}, true)
	_tutorial_observe(TutorialFlowScript.EVENT_ORGAN_DESTROYED)
	_transition(RunState.MUTATION_CHOICE)
	_mutation_choice_count += 1
	_offer_mutations(false)

func _offer_mutations(is_reroll: bool, excluded: Array[String] = []) -> void:
	var required_rarity := "rare" if int(_permanent_stats.get("rare_protection", 0)) > 0 and _mutation_choice_count > 0 and _mutation_choice_count % 3 == 0 else ""
	var offers := _mutation_engine.offer(GameData.mutations, 3, excluded, required_rarity)
	# Near catalog exhaustion, a reroll may exclude every remaining mutation.
	# Reuse the prior legal pool rather than converting a consumed reroll into an
	# exhaustion reward while selectable mutations still exist.
	if offers.is_empty() and not excluded.is_empty():
		offers = _mutation_engine.offer(GameData.mutations, 3, [], required_rarity)
	_offered_mutation_ids.clear()
	for raw_offer in offers:
		var offer := raw_offer as Dictionary
		_offered_mutation_ids.append(String(offer.get("id", "")))
		_decorate_synergy_offer(offer)
	AnalyticsService.track("mutation_offered", {
		"count": offers.size(),
		"phase": phase,
		"reroll": is_reroll
	})
	if offers.is_empty():
		_resolve_exhausted_mutation_catalog()
		return
	_hud.show_mutation_choices(offers, _remaining_rerolls)

func _resolve_exhausted_mutation_catalog() -> void:
	if state != RunState.MUTATION_CHOICE:
		return
	_remaining_rerolls = 0
	_grant_bio(MUTATION_CATALOG_COMPLETE_BIO_REWARD)
	_hud.hide_overlay()
	_hud.show_toast(LocalizationService.text("mutation_catalog_complete", {"bio":MUTATION_CATALOG_COMPLETE_BIO_REWARD}), VisualTheme.BIO)
	_tutorial_observe(TutorialFlowScript.EVENT_MUTATION_SELECTED)
	_transition(RunState.DIVING_OUT)
	transition_timer = 1.0
	AudioManager.play_sfx("mutation",1.0,0.82)

func _decorate_synergy_offer(offer: Dictionary) -> void:
	var weapon_tags: Array = WEAPON_SYNERGY_TAGS.get(String(weapon_definition.get("behavior", "pulse")), [])
	var matching: Array[String] = []
	for tag_value in offer.get("tags", []):
		var tag := String(tag_value)
		if weapon_tags.has(tag):
			matching.append(tag)
	offer["_synergy"] = not matching.is_empty()
	if not matching.is_empty() and int(_permanent_stats.get("synergy_preview", 0)) > 0:
		offer["_synergy_detail"] = matching[0]

func _reroll_mutations() -> void:
	if state != RunState.MUTATION_CHOICE or _remaining_rerolls <= 0:
		return
	var previous_offer := _offered_mutation_ids.duplicate()
	_remaining_rerolls -= 1
	_offer_mutations(true, previous_offer)

func _select_mutation(mutation_id: String) -> void:
	if state!=RunState.MUTATION_CHOICE:
		return
	if not _offered_mutation_ids.has(mutation_id):
		return
	var mutation:=GameData.get_mutation(mutation_id)
	if mutation.is_empty() or not _mutation_engine.apply(mutation):
		return
	var new_effects: Dictionary = mutation.get("effects",{})
	_offered_mutation_ids.clear()
	_selected_mutations.append(mutation_id)
	var discovered:Array=SaveManager.profile.get("discovered_mutations",[])
	if not discovered.has(mutation_id):
		discovered.append(mutation_id)
		SaveManager.profile.discovered_mutations=discovered
		SaveManager.save_profile()
	_sync_player_mutation_stats(new_effects)
	if new_effects.has("calm_heal_seconds"):
		calm_timer=0.0
	AudioManager.play_sfx("mutation",1.0,0.9)
	AnalyticsService.track("mutation_selected",{"mutation":mutation_id,"weapon":String(weapon_definition.id)})
	_tutorial_observe(TutorialFlowScript.EVENT_MUTATION_SELECTED)
	_transition(RunState.DIVING_OUT)
	transition_timer=1.0
	AudioManager.play_sfx("dive",0.78,0.8)

func _return_outside() -> void:
	phase+=1
	_player.position=Vector2(270,790)
	_player.combat_bounds=Rect2(24,395,492,450)
	_player.reset_physics_interpolation()
	_player.set_controls_active(true)
	if int(_mutation_engine.flags.get("shield_after_organ",0))>0:
		_player.add_shield_hit(int(_mutation_engine.flags.shield_after_organ))
	wound_memory_timer=float(_mutation_engine.flags.get("breach_window_seconds",0.0))
	if phase>=3:
		_transition(RunState.CORE)
		_phase_first_hit_available = true
		phase_open_timer = 4.0
		core_max=float(boss_definition.get("core_health",3600))*_difficulty_hp()
		core_health=core_max
		_boss_visual.set_exterior(phase,_organ_map.destroyed_organs(),false,_organ_map.visual_states())
		_boss_visual.set_health(core_health,core_max)
		_hud.show_toast(LocalizationService.text("all_systems_dead"),VisualTheme.FRIENDLY)
		AudioManager.set_music_state("core",0.9)
		_play_combat_sfx_limited("boss_phase", 0.92, 1.0)
	else:
		_start_phase(phase)
		_transition(RunState.EXTERIOR)
		var changed_ability := String(current_organ.ability)
		var change_text_key := "ability_transformed" if _organ_map.ability_status(changed_ability) == OrganAbilityMap.STATUS_DEGRADED else "ability_disabled"
		_hud.show_toast(LocalizationService.text(change_text_key,{"ability":_ability_display(changed_ability)}),VisualTheme.BIO)
		AudioManager.set_music_state("exterior",0.35+phase*0.18)
	attack_timer=1.4
	_tutorial_observe(TutorialFlowScript.EVENT_BOSS_ABILITY_CHANGED)
	# The first return teaches the visible organ-to-ability change. The next
	# completed exterior phase (or a death) satisfies "finish a phase or fail";
	# firing both events in this frame would silently skip that playable step.
	if phase >= 2:
		_tutorial_observe(TutorialFlowScript.EVENT_BOSS_PHASE_REACHED)
	AnalyticsService.track("boss_phase_reached",{"boss":String(boss_definition.id),"phase":phase+1})

func _start_phase(new_phase: int) -> void:
	phase=new_phase
	_phase_first_hit_available = true
	phase_open_timer = 4.0
	breach_timer = 0.0
	var phase_scales := [3.0,3.5,4.1]
	armor_max=float(boss_definition.get("base_armor",1800))*phase_scales[min(phase,2)]*_difficulty_hp()
	armor_health=armor_max
	_boss_visual.set_exterior(phase,_organ_map.destroyed_organs(),false,_organ_map.visual_states())
	_boss_visual.set_health(armor_health,armor_max)
	if _hud:
		_hud.set_dive_ready(false)
	if new_phase > 0:
		_play_combat_sfx_limited("boss_phase", 1.0, 0.9)
	attack_timer=1.4
	_telegraph.clear()

func _request_dash() -> void:
	if _paused:return
	if _player.request_dash():
		AudioManager.play_sfx("dash",1.0,0.9)
		SettingsManager.pulse_haptic(18,0.52)

func _request_directional_dash(direction: Vector2) -> void:
	if _paused:return
	if _player.request_dash(direction):
		AudioManager.play_sfx("dash",1.0,0.9)
		SettingsManager.pulse_haptic(18,0.52)

func _on_dash_started() -> void:
	_dash_count += 1
	_meta_progress("dash_used", {"event_id":"%s:dash:%d" % [run_id,_dash_count]}, false)
	_tutorial_observe(TutorialFlowScript.EVENT_FIRST_DASH)
	if bool(_mutation_engine.flags.get("dash_trail",false)):
		_dash_wake_serial+=1
		_active_dash_wake_id=_dash_wake_serial
		_dash_wake_hits[_active_dash_wake_id]={}
		_emit_dash_wake_point()
	if not _first_dash_sent:
		_first_dash_sent=true
		AnalyticsService.track("first_dash")

func _on_player_damaged(amount: float,cause: String) -> void:
	_damage_taken_total += amount
	world_shake=9.0
	AudioManager.play_sfx("player_damage",1.0,0.9)
	SettingsManager.pulse_haptic(28,0.65)
	if not _first_damage_sent:
		_first_damage_sent=true
		AnalyticsService.track("first_damage_taken",{"amount":amount,"cause":cause})

func _on_player_died(cause: String) -> void:
	_tutorial_observe(TutorialFlowScript.EVENT_PLAYER_DEATH)
	_complete_run(false,cause)

func _complete_run(won: bool,cause: String) -> void:
	if state in [RunState.DEAD,RunState.VICTORY]:
		return
	_transition(RunState.VICTORY if won else RunState.DEAD)
	_player.set_controls_active(false)
	projectiles_clear_and_enemies()
	var reward_mul:=_difficulty_reward()*float(_permanent_stats.challenge_reward_mul if String(config.mode) in ["daily","friend"] else 1.0)
	if won:
		reward_mul *= float(_permanent_stats.get("victory_reward_mul", 1.0))
	var banked_bio:=int(round(run_bio*reward_mul)) if won else int(round(run_bio*float(_permanent_stats.death_retention)))
	if not won and (elapsed >= 18.0 or int(SaveManager.profile.get("total_runs",0)) == 0):
		banked_bio = maxi(55, banked_bio)
	if won:
		banked_bio+=int(float(boss_definition.get("reward_bio",300))*reward_mul)
	var banked_shards:=int(boss_definition.get("reward_shards",1)) if won and String(config.mode)=="story" else 0
	var final_score := score+int(elapsed*5.0)+organs_destroyed*1200
	var duration_ms := maxi(1000,int(round(elapsed*1000.0)))
	var friend_target := evaluate_friend_target(final_score,duration_ms,won,maxi(0,int(config.get("target_score",0))),maxi(0,int(config.get("target_time_ms",0))))
	_result={
		"run_id":run_id,
		"won":won,
		"cause":cause,
		"score":final_score,
		"elapsed":elapsed,
		"time_text":"%02d:%02d"%[int(elapsed)/60,int(elapsed)%60],
		"organs":organs_destroyed,
		"destroyed_organs":_organ_map.destroyed_organs(),
		"mutations":_selected_mutations.duplicate(),
		"banked_bio":banked_bio,
		"banked_shards":banked_shards,
		"boss_id":String(boss_definition.id),
		"weapon":String(weapon_definition.id),
		"seed":int(config.seed),
		"mode":String(config.mode)
		,"difficulty":String(config.difficulty)
		,"challenge_id":String(config.get("challenge_id",""))
		,"challenge_day_utc":String(config.get("challenge_day_utc",""))
		,"target_score":maxi(0,int(config.get("target_score",0)))
		,"target_time_ms":maxi(0,int(config.get("target_time_ms",0)))
		,"challenge_has_target":bool(friend_target.has_target) and String(config.mode)=="friend"
		,"challenge_target_met":bool(friend_target.met) and String(config.mode)=="friend"
		,"abyss_depth":int(config.get("abyss_depth",0))
	}
	_meta_progress("run_complete", {
		"event_id":"%s:complete" % run_id,
		"won":won,
		"boss_id":String(boss_definition.id),
		"weapon_id":String(weapon_definition.id),
		"difficulty":String(config.difficulty),
		"damage_taken":int(round(_damage_taken_total)),
		"duration_ms":maxi(1000,int(round(elapsed*1000.0)))
	}, false)
	_result_banked=_ensure_result_banked()
	if _result_banked:
		_submit_result_offline()
	_hud.show_result(_result)
	AudioManager.play_sfx("boss_death" if won else "player_death",1.0,1.0)
	AudioManager.set_music_state("victory" if won else "interior",0.3)
	SettingsManager.pulse_haptic(110 if won else 65,1.0)
	AnalyticsService.track("run_complete" if won else "player_death",{"boss":String(boss_definition.id),"seconds":elapsed,"organs":organs_destroyed,"cause":cause})
	if String(config.mode) == "daily":
		AnalyticsService.track("daily_rift_complete", {"boss":String(boss_definition.id),"won":won,"score":int(_result.score)})

func _submit_result_offline() -> void:
	var major_events: Array[String] = []
	for organ_id_value in _organ_map.destroyed_organs():
		major_events.append("organ_%s" % String(organ_id_value))
	major_events.append("boss_victory" if bool(_result.get("won", false)) else "player_death")
	var submission := {
		"run_id": run_id,
		"mode": String(config.mode),
		"challenge_id": String(config.get("challenge_id", "")),
		"challenge_day_utc": String(config.get("challenge_day_utc", "")),
		"boss_id": String(boss_definition.id),
		"weapon_id": String(weapon_definition.id),
		"difficulty": String(config.difficulty),
		"seed": int(config.seed),
		"modifiers": ChallengeCode.canonical_modifiers(config.get("modifiers", [])),
		"target_score": maxi(0, int(config.get("target_score", 0))),
		"target_time_ms": maxi(0, int(config.get("target_time_ms", 0))),
		"score": int(_result.get("score", 0)),
		"duration_ms": maxi(1000, int(round(elapsed * 1000.0))),
		"won": bool(_result.get("won", false)),
		"organs_destroyed": _organ_map.destroyed_organs(),
		"mutations": _selected_mutations.duplicate(),
		"event_summary": {
			"shots_fired": shot_count,
			"hits": _target_hit_count,
			"damage_taken": int(round(_damage_taken_total)),
			"dashes": _dash_count,
			"organs_destroyed": organs_destroyed,
			"max_projectiles": _peak_projectiles,
			"major_events": major_events
		}
	}
	var queue_result: Dictionary = LeaderboardService.submit_run(submission)
	if not bool(queue_result.get("accepted", false)):
		push_warning("Offline run result not queued: %s" % String(queue_result.get("status", "unknown")))

func _ensure_result_banked() -> bool:
	if _result_banked:
		return true
	_result_banked = SaveManager.bank_run(_result)
	if not _result_banked:
		AudioManager.play_sfx("ui_error")
		if _hud:
			_hud.show_toast(LocalizationService.text("save_retry_required"),VisualTheme.ENEMY)
		return false
	# bank_run persists the same profile dictionary, including meta-goal
	# receipts/rewards. Never acknowledge them if that atomic save failed.
	_meta_goals.mark_profile_persisted()
	_meta_dirty = false
	return true

func _on_result_action(action: String) -> void:
	if action in ["retry","nest","share"]:
		var was_banked := _result_banked
		if not _ensure_result_banked():
			return
		if not was_banked:
			_submit_result_offline()
	match action:
		"retry":
			AnalyticsService.track("instant_retry",{"boss":String(boss_definition.id)})
			_meta_progress("instant_retry", {"event_id":"%s:retry" % run_id}, true)
			var retry_config := config.duplicate(true)
			if String(config.mode) == "abyss" and bool(_result.get("won",false)):
				var next_depth := int(config.get("abyss_depth",1))+1
				retry_config.abyss_depth = next_depth
				retry_config.boss = String(GameData.bosses[(next_depth-1)%GameData.bosses.size()].id)
				retry_config.seed = int(config.seed) + next_depth * 104729
				retry_config.carried_mutations = _selected_mutations.duplicate()
				retry_config.mutation_choice_count = _mutation_choice_count
				retry_config.starting_health_ratio = minf(1.0,_player.health_ratio()+0.2)
				AnalyticsService.track("abyss_depth_reached",{"depth":next_depth})
				_meta_progress("abyss_depth_reached", {"event_id":"%s:depth:%d" % [run_id,next_depth],"depth":next_depth}, true)
			run_finished.emit({"action":"retry","config":retry_config,"result":_result})
		"nest": run_finished.emit({"action":"nest","result":_result})
		"resume":
			if not _paused:
				return
			_paused=false
			_sync_player_controls_for_state()
			_hud.hide_overlay()
		"share": _share_result()

func _share_result() -> void:
	var challenge:={"boss":String(boss_definition.id),"seed":int(config.seed),"weapon":String(weapon_definition.id),"difficulty":String(config.difficulty),"modifiers":config.get("modifiers",[]),"target_score":int(_result.get("score",0)),"target_time_ms":int(elapsed*1000.0)}
	var code:=ChallengeCode.encode(challenge)
	DisplayServer.clipboard_set(code)
	_hud.show_toast(LocalizationService.text("friend_rift_copied_short",{"code":code.left(16)}),VisualTheme.SHARD)

func _toggle_pause() -> void:
	if state in [RunState.DEAD,RunState.VICTORY,RunState.ORGAN_SELECT,RunState.MUTATION_CHOICE]:return
	_paused=not _paused
	_sync_player_controls_for_state()
	if _paused:_hud.show_pause()
	else:_hud.hide_overlay()

func _sync_player_controls_for_state() -> void:
	if _player == null:
		return
	var state_accepts_input := state in [
		RunState.INTRO,
		RunState.EXTERIOR,
		RunState.BREACH_OPEN,
		RunState.INTERNAL_ROOMS,
		RunState.ORGAN_CHAMBER,
		RunState.CORE,
	]
	_player.set_controls_active(not _paused and state_accepts_input)

func _pause_for_application_suspend() -> void:
	# Choice/result states already freeze simulation and own their modal UI. Keep
	# those overlays intact while still enforcing their control lock. Every live
	# or transitional combat state gets an explicit, idempotent pause immediately
	# (not deferred, because mobile execution may stop after the notification).
	if state in [RunState.ORGAN_SELECT, RunState.MUTATION_CHOICE, RunState.DEAD, RunState.VICTORY]:
		_sync_player_controls_for_state()
		return
	_paused = true
	_sync_player_controls_for_state()
	if _hud != null:
		_hud.show_pause()

func _transition(next_state: RunState) -> void:
	if state==next_state:
		return
	previous_state=state
	state=next_state
	queue_redraw()

func _difficulty_hp() -> float:
	var base: float = float({"diver":0.84,"deep":1.0,"abyss":1.18}.get(String(config.difficulty),0.84))
	return base*(1.0+maxi(0,int(config.get("abyss_depth",1))-1)*0.08) if String(config.mode)=="abyss" else base

func _difficulty_damage() -> float:
	var base: float = float({"diver":0.78,"deep":1.0,"abyss":1.22}.get(String(config.difficulty),0.78))
	return base*(1.0+maxi(0,int(config.get("abyss_depth",1))-1)*0.05) if String(config.mode)=="abyss" else base

func _difficulty_projectile_speed() -> float:
	var base: float = float({"diver":0.88,"deep":1.0,"abyss":1.13}.get(String(config.difficulty),0.88))
	if String(config.mode)=="abyss":base*=1.0+maxi(0,int(config.get("abyss_depth",1))-1)*0.025
	return base*_assist_number("assist_projectile_speed",1.0)

func _assist_number(key: String, standard_value: float) -> float:
	return standard_value if bool(config.get("competitive",false)) else float(SettingsManager.get_value(key,standard_value))

func _aim_assist_enabled() -> bool:
	return true if bool(config.get("competitive",false)) else bool(SettingsManager.get_value("aim_assist",true))

func _difficulty_reward() -> float:
	return {"diver":0.9,"deep":1.0,"abyss":1.35}.get(String(config.difficulty),0.9)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_pause_for_application_suspend()
		_persist_meta_profile(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist_meta_profile(true)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		# OS resume never grants input by itself. Manual resume still routes through
		# the state-aware policy, and modal/transition states remain locked.
		_sync_player_controls_for_state()

func _decorative_motion_time() -> float:
	return 0.0 if bool(SettingsManager.get_value("reduced_motion",false)) else elapsed

func _draw() -> void:
	var interior:=state in [RunState.DIVING_IN,RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER,RunState.MUTATION_CHOICE,RunState.DIVING_OUT]
	var motion_time:=_decorative_motion_time()
	draw_rect(Rect2(0,0,540,960),VisualTheme.TISSUE.darkened(0.58) if interior else VisualTheme.DEEP_SPACE)
	for star in _stars:
		var point:Vector2=star.position
		var alpha:=0.0 if interior else 0.18+sin(motion_time*1.4+float(star.phase))*0.12
		draw_circle(point,float(star.size),Color(0.72,0.88,1.0,alpha))
	if interior:
		for index in 15:
			var y:=float(index)*72.0+fmod(motion_time*35.0,72.0)-50.0
			var x:=270.0+sin(index*1.7+motion_time*0.45)*205.0
			draw_line(Vector2(0,y),Vector2(x,y+35),Color(VisualTheme.VULNERABLE,0.08),3.0+index%3)
			draw_line(Vector2(540,y+18),Vector2(540-x,y+55),Color(VisualTheme.SHARD,0.06),2.0)
	_draw_active_room_motifs()
	_draw_room_defender_effects()
	for enemy in _enemies:
		_draw_internal_enemy(enemy)
		if float(enemy.get("shot_telegraph_timer",0.0)) > 0.0:
			var p:Vector2=enemy.position
			var target := Vector2(enemy.get("shot_target",p))
			var warning_progress := 1.0-float(enemy.shot_telegraph_timer)/maxf(0.01,float(enemy.get("shot_telegraph_total",0.01)))
			var warning_color := Color(VisualTheme.TELEGRAPH,0.38+warning_progress*0.58)
			draw_dashed_line(p,target,warning_color,2.5,9.0)
			draw_circle(target,12.0+warning_progress*7.0,warning_color,false,2.5)
	for pickup in _bio_pickups:
		var pickup_position:=Vector2(pickup.position)
		var pickup_phase:=0.0 if bool(SettingsManager.get_value("reduced_motion",false)) else float(pickup.phase)
		var pickup_pulse:=2.5+sin(pickup_phase)*0.8
		draw_circle(pickup_position,6.0+pickup_pulse,Color(VisualTheme.BIO,0.16))
		draw_circle(pickup_position,3.2,VisualTheme.BIO)
	for wake in _dash_wakes:
		var wake_alpha:=clampf(float(wake.life)/maxf(0.01,float(_mutation_engine.flags.get("dash_trail_duration",1.2))),0.0,1.0)
		draw_circle(Vector2(wake.position),15.0,Color(VisualTheme.FRIENDLY,wake_alpha*0.18))
		draw_arc(Vector2(wake.position),13.0,0.0,TAU,18,Color(VisualTheme.SHARD,wake_alpha*0.6),2.0)
	_draw_telegraph()
	_draw_orbitals()
	if state in [RunState.DIVING_IN,RunState.DIVING_OUT]:
		var reduced_motion:=bool(SettingsManager.get_value("reduced_motion",false))
		var radius:=dive_transition_visual_radius(state,transition_timer,reduced_motion)
		draw_circle(Vector2(270,430),radius,Color(VisualTheme.DEEP_SPACE,0.68),false,10.0)
		draw_arc(Vector2(270,430),maxf(10,radius),0,TAU,64,VisualTheme.VULNERABLE,8.0)
		if reduced_motion:
			draw_arc(Vector2(270,430),radius+22.0,0,TAU,64,Color(VisualTheme.FRIENDLY,0.72),3.0)

func _draw_telegraph() -> void:
	if _telegraph.is_empty():return
	if String(_telegraph.get("source","")) == "room_pattern":
		_draw_room_pattern_telegraph()
		return
	var progress:=1.0-float(_telegraph.timer)/maxf(0.01,float(_telegraph.total))
	var color:=Color(VisualTheme.TELEGRAPH,0.35+progress*0.6)
	var origin:=Vector2(_telegraph.get("pattern_origin",_boss_visual.target_position() if _boss_visual else Vector2(270,220)))
	var ability:=String(_telegraph.ability)
	var contract_family:=String(_telegraph.get("contract_family",""))
	if _telegraph.has("safe_position"):
		var safe_position := Vector2(_telegraph.safe_position)
		draw_circle(safe_position,34.0+sin(_decorative_motion_time()*8.0)*3.0,Color(VisualTheme.FRIENDLY,0.1+progress*0.12))
		draw_arc(safe_position,38.0,0.0,TAU,30,Color(VisualTheme.FRIENDLY,0.55+progress*0.35),3.0)
		draw_dashed_line(_player.position,safe_position,Color(VisualTheme.FRIENDLY,0.26),2.0,10.0)
	if contract_family=="ring" or ability in ["gravity_ring","suction_waves"] or "vortex" in ability or "pulse" in ability:
		draw_arc(origin,60+progress*170,0,TAU,50,color,3.0)
		# Ring attacks always publish the same angular corridor that their
		# projectile builder will leave empty. This keeps the safe route visible
		# throughout the warning instead of asking the player to discover it only
		# after the bullets already exist.
		var safe_angle := float(_telegraph.get("safe_angle",0.0))
		var attack_contract := _telegraph.get("attack_contract",{}) as Dictionary
		var pattern := attack_contract.get("pattern",{}) as Dictionary
		var safe_arc := clampf(float(pattern.get("safe_arc_radians",0.5)),0.3,1.4)
		var corridor_color := Color(VisualTheme.FRIENDLY,0.5+progress*0.38)
		for boundary in [-safe_arc,safe_arc]:
			var direction := Vector2.from_angle(safe_angle+boundary)
			draw_dashed_line(origin+direction*54.0,origin+direction*235.0,corridor_color,3.0,11.0)
		draw_arc(origin,78.0+progress*126.0,safe_angle-safe_arc,safe_angle+safe_arc,24,corridor_color,5.0)
	elif contract_family in ["lane","sweep"] or ability in ["laser_wings","echo_dash"] or "grid" in ability or "wall" in ability or "lane" in ability:
		var gap_x:=clampf(float(_telegraph.get("gap_x",_player.position.x)),80.0,460.0)
		var wall_y:=origin.y
		draw_dashed_line(Vector2(0,wall_y),Vector2(gap_x-62,wall_y),color,5.0,12.0)
		draw_dashed_line(Vector2(gap_x+62,wall_y),Vector2(540,wall_y),color,5.0,12.0)
	else:
		draw_dashed_line(origin,_player.position,color,4.0,13.0)
		draw_circle(_player.position,18+progress*12,color,false,3.0)

func _draw_room_pattern_telegraph() -> void:
	var progress:=1.0-float(_telegraph.timer)/maxf(0.01,float(_telegraph.total))
	var event := _telegraph.get("event",{}) as Dictionary
	var spawn := event.get("spawn",{}) as Dictionary
	var collision := spawn.get("collision",{}) as Dictionary
	var safe_position := Vector2(_telegraph.get("safe_position",INTERNAL_COMBAT_BOUNDS.get_center()))
	var safe_clearance := maxf(34.0,float((event.get("safe",{}) as Dictionary).get("clearance",0.1))*minf(INTERNAL_COMBAT_BOUNDS.size.x,INTERNAL_COMBAT_BOUNDS.size.y))
	draw_circle(safe_position,safe_clearance,Color(VisualTheme.FRIENDLY,0.08+progress*0.10))
	draw_arc(safe_position,safe_clearance,0.0,TAU,36,Color(VisualTheme.FRIENDLY,0.58+progress*0.34),3.0)
	draw_dashed_line(_player.position,safe_position,Color(VisualTheme.FRIENDLY,0.28+progress*0.18),2.0,10.0)
	var world_positions := _room_event_world_positions(event,safe_position)
	_draw_room_geometry(world_positions,collision,room_runtime_category(event),String(spawn.get("visual_token","")),Color(VisualTheme.TELEGRAPH,0.32+progress*0.58),true)
	var projectile_specs := event.get("runtime_projectile_specs",[]) as Array
	var projectile_previews := event.get("runtime_projectile_previews",[]) as Array
	for raw_preview in projectile_previews:
		var preview := raw_preview as Dictionary
		var emission_index := int(preview.get("emission_index",-1))
		if emission_index<0 or emission_index>=projectile_specs.size():
			continue
		var spec := projectile_specs[emission_index] as Dictionary
		var options := spec.get("options",{}) as Dictionary
		var samples := preview.get("samples",[]) as Array
		if samples.is_empty():
			continue
		var points := PackedVector2Array()
		for raw_sample in samples:
			points.append(Vector2((raw_sample as Dictionary).get("position",Vector2.ZERO)))
		var projectile_color := Color(VisualTheme.TELEGRAPH,0.24+progress*0.48)
		var origin := points[0]
		var initial_radius := maxf(4.0,float((samples[0] as Dictionary).get("radius",options.get("radius",7.0))))
		draw_circle(origin,initial_radius,Color(projectile_color,0.12+progress*0.18))
		draw_arc(origin,initial_radius+3.0,0.0,TAU,14,projectile_color,2.0)
		if points.size()>=2:
			draw_polyline(points,projectile_color,2.0,true)
		if String(options.get("travel_model","linear"))=="expanding":
			var radius_stride := maxi(1,ceili(float(samples.size())/8.0))
			for sample_index in range(radius_stride,samples.size(),radius_stride):
				var sample := samples[sample_index] as Dictionary
				draw_arc(Vector2(sample.position),maxf(1.0,float(sample.radius)),0.0,TAU,16,Color(projectile_color,0.16+progress*0.20),1.5)
			var final_sample := samples[samples.size()-1] as Dictionary
			draw_arc(Vector2(final_sample.position),maxf(1.0,float(final_sample.radius)),0.0,TAU,18,Color(projectile_color,0.30+progress*0.32),2.0)
		var delay_seconds := float(preview.get("delay_seconds",0.0))
		if delay_seconds>0.0:
			var delay_ratio := clampf(delay_seconds/ROOM_PROJECTILE_TELEGRAPH_HORIZON,0.0,1.0)
			var delay_radius := initial_radius+6.0+delay_ratio*12.0
			draw_arc(origin,delay_radius,-PI*0.5,-PI*0.5+TAU*maxf(0.12,delay_ratio),12,Color(projectile_color,0.48+progress*0.30),2.5)

func _draw_active_room_motifs() -> void:
	for raw_wave_id in _active_room_motifs.keys():
		var motif := _active_room_motifs[raw_wave_id] as Dictionary
		if not bool(motif.get("emitter_active",true)):
			continue
		var category := String(motif.get("category","gate"))
		var spawn := motif.get("spawn",{}) as Dictionary
		var accent := _room_category_color(category,String(spawn.get("visual_token","")))
		_draw_room_geometry(motif.get("positions",[]) as Array,motif.get("collision",{}) as Dictionary,category,String(spawn.get("visual_token","")),Color(accent,0.64),false)

func _draw_room_defender_effects() -> void:
	for cover in _room_defender_covers:
		var center := Vector2((cover as Dictionary).get("position",Vector2.ZERO))
		var radius := float((cover as Dictionary).get("radius",34.0))
		var material := String((cover as Dictionary).get("material","tissue"))
		var color: Color = Color("#E7C994") if material=="bone" else (Color("#8EEBFF") if material=="prism" else VisualTheme.BIO)
		var life_ratio := clampf(float((cover as Dictionary).get("life",0.0))/maxf(0.01,float((cover as Dictionary).get("duration",1.0))),0.0,1.0)
		draw_circle(center,radius,Color(color,0.06+life_ratio*0.10))
		var motion_angle:=_decorative_motion_time()*1.8
		draw_arc(center,radius,motion_angle,motion_angle+TAU*0.82,30,Color(color,0.42+life_ratio*0.42),3.0)
		var pips := mini(8,maxi(0,int((cover as Dictionary).get("absorb_remaining",0))))
		for pip in pips:
			var angle := -PI*0.75+float(pip)*PI*1.5/maxf(1.0,float(pips-1))
			draw_circle(center+Vector2.from_angle(angle)*(radius-5.0),2.5,color)

func _draw_room_geometry(positions: Array, collision: Dictionary, category: String, visual_token: String, color: Color, telegraph_only: bool) -> void:
	var shape := String(collision.get("shape","circle"))
	var unit := minf(INTERNAL_COMBAT_BOUNDS.size.x,INTERNAL_COMBAT_BOUNDS.size.y)
	if shape == "segment_chain" and positions.size()>=2:
		var rendered_width := room_collision_render_width(collision,unit)
		for index in range(positions.size()-1):
			var first := Vector2(positions[index])
			var second := Vector2(positions[index+1])
			if telegraph_only:
				draw_dashed_line(first,second,color,rendered_width,10.0)
			else:
				draw_line(first,second,color,rendered_width)
	for index in range(positions.size()):
		var center := Vector2(positions[index])
		var phase_offset := float(abs(visual_token.hash())%17)*0.07+float(index)*0.5
		match shape:
			"box", "cell":
				var half_data := collision.get("half_extents_normalized",[0.055,0.055]) as Array
				var half_extents := Vector2(float(half_data[0])*INTERNAL_COMBAT_BOUNDS.size.x,float(half_data[1])*INTERNAL_COMBAT_BOUNDS.size.y)
				var rect := Rect2(center-half_extents,half_extents*2.0)
				draw_rect(rect,Color(color,0.12 if telegraph_only else 0.22),true)
				draw_rect(rect,color,false,3.0)
			"arc":
				var radius := maxf(20.0,float(collision.get("radius_normalized",0.24))*unit)
				draw_arc(center,radius,-1.05+phase_offset,1.05+phase_offset,22,color,room_collision_render_width(collision,unit))
			"force_field":
				var radius := maxf(18.0,float(collision.get("radius_normalized",0.11))*unit)
				draw_circle(center,radius,Color(color,0.08 if telegraph_only else 0.14))
				for ring in range(1,4):
					draw_arc(center,radius*float(ring)/3.0,phase_offset,phase_offset+PI*1.55,24,color,2.0)
			_:
				var radius := maxf(10.0,float(collision.get("radius_normalized",0.035))*unit)
				draw_circle(center,radius,Color(color,0.12 if telegraph_only else 0.28))
				draw_arc(center,radius,phase_offset,phase_offset+PI*1.65,16,color,3.0)
		if category == "rain":
			draw_line(center-Vector2(0,22),center+Vector2(0,22),color,3.0)
		elif category == "echo":
			draw_arc(center,12.0+sin(_decorative_motion_time()*8.0+phase_offset)*2.0,0.0,TAU,16,Color(VisualTheme.SHARD,color.a),2.0)

static func room_collision_render_width(collision: Dictionary, unit: float) -> float:
	return maxf(8.0,float(collision.get("thickness_normalized",0.025))*unit)*2.0

func _room_category_color(category: String, visual_token: String) -> Color:
	var base: Color = {
		"gate":VisualTheme.VULNERABLE,
		"rain":VisualTheme.ENEMY,
		"radial":VisualTheme.SHARD,
		"sweep":VisualTheme.TELEGRAPH,
		"field":VisualTheme.BIO,
		"node":Color("#84D8FF"),
		"spawn":Color("#FF7A9D"),
		"echo":Color("#B69CFF"),
	}.get(category,VisualTheme.ENEMY)
	var variant := float(abs(visual_token.hash())%9)/100.0
	return base.lightened(variant)

func _draw_internal_enemy(enemy: Dictionary) -> void:
	var p := Vector2(enemy.position)
	var radius := float(enemy.radius)
	var archetype := String(enemy.get("archetype","generic"))
	var color := _room_category_color("spawn",String(enemy.get("visual_token",archetype)))
	if float(enemy.get("effect_priority_seconds",0.0))>0.0:
		draw_arc(p,radius+8.0,-PI*0.35,PI*1.35,20,VisualTheme.VULNERABLE,3.5)
		draw_circle(p-Vector2(0,radius+13.0),3.0,VisualTheme.VULNERABLE)
	match archetype:
		"orbit_sentinel", "prism_guard":
			draw_arc(p,radius,0.0,TAU,22,color,4.0)
			draw_arc(p,radius*0.55,float(enemy.phase),float(enemy.phase)+PI*1.45,14,VisualTheme.SHARD,3.0)
		"pincer_hunter", "arc_linker":
			var points := PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,radius*0.7),p,p+Vector2(-radius,radius*0.7)])
			draw_colored_polygon(points,Color(color,0.3))
			draw_polyline(PackedVector2Array(points+PackedVector2Array([points[0]])),color,2.5)
		"armor_drone":
			draw_rect(Rect2(p-Vector2(radius,radius*0.7),Vector2(radius*2.0,radius*1.4)),Color(color,0.28),true)
			draw_rect(Rect2(p-Vector2(radius,radius*0.7),Vector2(radius*2.0,radius*1.4)),color,false,3.0)
		"tracker_mite", "hatchling":
			var direction := Vector2(enemy.velocity).normalized()
			if direction.length_squared()<0.01:direction=Vector2.DOWN
			var normal := Vector2(-direction.y,direction.x)
			var points := PackedVector2Array([p+direction*radius,p-direction*radius*0.7+normal*radius*0.65,p-direction*radius*0.7-normal*radius*0.65])
			draw_colored_polygon(points,Color(color,0.38))
			draw_polyline(PackedVector2Array(points+PackedVector2Array([points[0]])),color,2.5)
		"echo_clone", "decoy_core":
			draw_circle(p,radius,Color(color,0.14))
			draw_arc(p,radius,0.0,TAU,8,color,3.0)
			draw_line(p-Vector2(radius,0),p+Vector2(radius,0),color,2.0)
		_:
			var points:=PackedVector2Array()
			for index in 8:
				var angle:=index*TAU/8.0+float(enemy.phase)
				points.append(p+Vector2.from_angle(angle)*radius*(1.0 if index%2==0 else 0.58))
			draw_colored_polygon(points,Color(VisualTheme.BIO,0.28))
			draw_polyline(PackedVector2Array(points+PackedVector2Array([points[0]])),VisualTheme.BIO,2.0)

func _draw_orbitals() -> void:
	if weapon_definition.is_empty() or _player==null:return
	var count:=int(weapon_definition.get("orbitals",0))+int(_mutation_engine.stats.get("orbitals_add",0))
	var orbit_radius:=float(weapon_definition.get("orbital_radius",48.0))+_orbit_growth
	for index in count:
		var angle:=elapsed*2.8+index*TAU/maxf(1,count)
		var center:=_player.position+Vector2.from_angle(angle)*orbit_radius
		draw_arc(center,9.0+_orbit_growth*0.16,-PI*0.85,PI*0.85,12,VisualTheme.SHARD,4.0)
