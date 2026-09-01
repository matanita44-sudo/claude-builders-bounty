class_name RunScene
extends Node2D

const PermanentUpgradeEngineScript := preload("res://scripts/core/permanent_upgrade_engine.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const RoomMechanicsScript := preload("res://scripts/core/room_mechanics.gd")
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

const WEAPON_BEHAVIORS := ["pulse", "scatter", "rail", "arc", "orbitals"]
const INTERNAL_DEFENDER_TELEGRAPH_SECONDS := 0.55
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
var _room_elapsed := 0.0
var _room_event_index := 0
var _room_cycle_index := 0
var _active_room_waves: Dictionary = {}
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

func _persist_meta_profile() -> bool:
	if not _meta_dirty:
		return true
	if not SaveManager.save_profile():
		return false
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
	var targets := _target_infos(exterior)
	var hit_result := _projectiles.step(delta,targets,_player.position,12.0)
	_update_attack_avoidance(hit_result.player_hits)
	for raw_hit in hit_result.target_hits:
		_target_hit_count += 1
		_damage_target(raw_hit)
	_apply_player_hits(hit_result.player_hits)
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
	for enemy in _enemies:
		var distance := _player.position.distance_squared_to(Vector2(enemy.position))
		if distance<best:
			best=distance
			nearest=enemy.position
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
		_enemies[index].health = float(_enemies[index].health)-amount
		if float(_enemies[index].health)<=0.0:
			_kill_enemy(index)
		return true
	return false

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

func _update_internal_hazards(delta: float) -> void:
	if state not in [RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER]:
		return
	if String(current_room.get("type", "")) == "entrance":
		return
	# Unknown or malformed hazards fail closed. Contract resolution installs a
	# validated safe fallback; if even that failed, this room produces no damage.
	if not bool(_room_contract.get("valid", false)):
		return
	_update_contract_hazards(delta)

func _update_contract_hazards(delta: float) -> void:
	_room_elapsed += delta
	_expire_contract_waves()
	var duration := maxf(0.1, float(_room_contract.get("duration", 1.0)))
	var events: Array = _room_contract.get("events", [])
	if not _telegraph.is_empty():
		_telegraph.timer = float(_telegraph.timer) - delta
		if float(_telegraph.timer) <= 0.0:
			_spawn_contract_pattern(_telegraph.get("event", {}))
			_telegraph.clear()
			_room_event_index += 1
		return
	if state == RunState.ORGAN_CHAMBER and _room_elapsed >= duration and _room_event_index >= events.size() and _active_room_waves.is_empty():
		_room_elapsed = fmod(_room_elapsed, duration)
		_room_event_index = 0
		_room_cycle_index += 1
	# The authored safe corridor belongs to exactly one active wave. Do not arm
	# the next warning until the prior active window has been retired.
	if not _active_room_waves.is_empty():
		return
	if _room_event_index >= events.size():
		return
	var event := events[_room_event_index] as Dictionary
	var base_telegraph := float((_room_contract.get("timing", {}) as Dictionary).get("telegraph_seconds", 0.45))
	var telegraph_seconds := base_telegraph * _assist_number("assist_telegraph", 1.0)
	var telegraph_at := maxf(0.0, float(event.get("active_at", 0.0)) - telegraph_seconds)
	if _room_elapsed >= telegraph_at:
		var safe_position_data: Array = event.get("safe_position", [0.5,0.5])
		var safe_position := Vector2(float(safe_position_data[0]) * 540.0, 330.0 + float(safe_position_data[1]) * 420.0)
		var runtime_event := event.duplicate(true)
		var active_seconds := maxf(0.08, float(event.get("clear_at", 0.0)) - float(event.get("active_at", 0.0)))
		var family := String(_room_contract.get("family", "lane"))
		var projectile := _room_contract.get("projectile", {}) as Dictionary
		var effective_speed := maxf(150.0, float(projectile.get("speed_pixels_per_second", 230.0))) * _difficulty_projectile_speed()
		var pattern_origin := Vector2(270.0, 225.0)
		if family == "ring":
			var toward_player := _player.position - pattern_origin
			var reachable_distance := effective_speed * active_seconds * 0.68
			if toward_player.length() > reachable_distance + 55.0:
				pattern_origin = _player.position - toward_player.normalized() * reachable_distance
		else:
			pattern_origin.y = clampf(_player.position.y - effective_speed * active_seconds * 0.68, 275.0, _player.position.y - 36.0)
		runtime_event.runtime_active_seconds = active_seconds
		runtime_event.runtime_gap_x = clampf(safe_position.x, 80.0, 460.0)
		runtime_event.runtime_origin = [pattern_origin.x, pattern_origin.y]
		runtime_event.runtime_wave_id = "room:%s:%d:%d" % [String(_room_contract.get("room_id", "fallback")), _room_cycle_index, int(event.get("index", _room_event_index))]
		# A hitch may arrive after the authored activation time. Never compress a
		# warning to a token frame: delay activation for a full visible telegraph.
		var warning_timer := maxf(telegraph_seconds, float(event.get("active_at", 0.0)) - _room_elapsed)
		_telegraph = {
			"ability": String(_room_contract.get("hazard", "cell_bloom")),
			"timer": warning_timer,
			"total": warning_timer,
			"safe_angle": (safe_position - pattern_origin).angle(),
			"safe_position": safe_position,
			"gap_x": float(runtime_event.runtime_gap_x),
			"pattern_origin": pattern_origin,
			"contract_family": family,
			"event": runtime_event
		}
		AudioManager.play_sfx("heartbeat", 0.9, 0.48)

func _spawn_contract_pattern(event: Dictionary) -> void:
	var family := String(_room_contract.get("family", "lane"))
	var hazard := String(_room_contract.get("hazard", "cell_bloom"))
	var projectile: Dictionary = _room_contract.get("projectile", {})
	var spawn: Dictionary = _room_contract.get("spawn", {})
	var safe_data: Array = event.get("safe_position", [0.5,0.5])
	var safe_position := Vector2(float(safe_data[0]) * 540.0, 330.0 + float(safe_data[1]) * 420.0)
	var speed := maxf(150.0, float(projectile.get("speed_pixels_per_second", 230.0))) * _difficulty_projectile_speed()
	var radius := maxf(5.0, float(projectile.get("radius_pixels", 8.0)))
	var damage := maxf(7.0, float(projectile.get("damage", 10.0)))
	var active_seconds := maxf(0.08, float(event.get("runtime_active_seconds", float(event.get("clear_at", 0.0)) - float(event.get("active_at", 0.0)))))
	var lifetime := clampf(float(projectile.get("lifetime_seconds", active_seconds)), 0.05, active_seconds)
	var cause_id := "hazard:%s" % hazard
	var wave_id := String(event.get("runtime_wave_id", "room:%s:%d:%d" % [String(_room_contract.get("room_id", "fallback")), _room_cycle_index, _room_event_index]))
	var origin_data: Array = event.get("runtime_origin", [270.0,225.0])
	var pattern_origin := Vector2(float(origin_data[0]),float(origin_data[1]))
	var gap_x := clampf(float(event.get("runtime_gap_x", safe_position.x)),80.0,460.0)
	_active_room_waves[wave_id] = _room_elapsed + active_seconds
	match family:
		"ring":
			var safe_angle := (safe_position-pattern_origin).angle()
			var count := maxi(14, int(projectile.get("count", 0)) * 4)
			for index in count:
				var angle := index * TAU / count
				if absf(wrapf(angle-safe_angle,-PI,PI)) < 0.52:
					continue
				_projectiles.spawn_enemy(pattern_origin,Vector2.from_angle(angle)*speed,damage,{"radius":radius,"life":lifetime,"cause":cause_id,"group":wave_id})
		"spawn":
			var burst := clampi(int(event.get("spawn_count", spawn.get("burst_count", 2))), 1, 5)
			var max_active := clampi(int(spawn.get("max_active", 1)), 1, 64)
			var available := maxi(0, max_active - _enemies.size())
			var event_seed := int(event.get("event_seed", _room_contract.get("runtime_seed", 1)))
			for index in mini(burst, available):
				var x := 70.0 + fmod(float(index) * 137.0 + float(event.get("phase",0.0)) * 190.0, 400.0)
				if absf(x-gap_x) < 76.0:
					x = 45.0 if gap_x > 270.0 else 495.0
				_spawn_enemy(Vector2(clampf(x,45.0,495.0),320.0+index%2*70.0), _mix_room_seed(event_seed,index), wave_id, max_active)
			var projectile_count := clampi(int(projectile.get("count", 0)), 0, 7)
			if bool(projectile.get("enabled", false)):
				for index in projectile_count:
					var origin := Vector2(70.0 + index * (400.0/maxf(1.0,projectile_count-1)),pattern_origin.y)
					var away := -1.0 if origin.x < gap_x else 1.0
					var velocity := Vector2(away*0.28,1.0).normalized()*speed
					_projectiles.spawn_enemy(origin,velocity,damage,{"radius":radius,"life":lifetime,"cause":cause_id,"group":wave_id})
		_:
			var spacing := 30 if family=="lane" else 34
			for x in range(20,521,spacing):
				if absf(float(x)-gap_x) < 62.0:
					continue
				_projectiles.spawn_enemy(Vector2(x,pattern_origin.y),Vector2(0,speed),damage,{"radius":radius,"life":lifetime,"cause":cause_id,"group":wave_id})
	AudioManager.play_sfx("heartbeat",0.94,0.62)

func _expire_contract_waves() -> void:
	for raw_group in _active_room_waves.keys():
		var group_id := String(raw_group)
		if _room_elapsed + 0.0001 < float(_active_room_waves[raw_group]):
			continue
		_projectiles.clear_enemy_group(group_id)
		_clear_contract_enemies(group_id)
		_active_room_waves.erase(raw_group)

func _clear_contract_waves() -> void:
	for raw_group in _active_room_waves.keys():
		var group_id := String(raw_group)
		_projectiles.clear_enemy_group(group_id)
		_clear_contract_enemies(group_id)
	_active_room_waves.clear()

func _clear_contract_enemies(group_id: String) -> void:
	for index in range(_enemies.size()-1,-1,-1):
		if String(_enemies[index].get("contract_group", "")) == group_id:
			_enemies.remove_at(index)

func _mix_room_seed(base_seed: int, index: int) -> int:
	return ((base_seed & 0x7FFFFFFF) ^ ((index + 1) * 1103515245) ^ 0x51A7E) & 0x7FFFFFFF

func _update_room(delta: float) -> void:
	room_timer-=delta
	if room_timer<=0.0:
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
	_player.position=Vector2(270,790)
	_player.combat_bounds=Rect2(24,360,492,490)
	_player.reset_physics_interpolation()
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
	_room_elapsed = 0.0
	_room_event_index = 0
	_room_cycle_index = 0
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
	_room_contract = _resolve_room_contract(current_room, int(config.seed) + phase * 991 + room_index * 131)
	_sync_current_room_to_contract()
	attack_timer=0.65
	var enemy_count:=1
	match String(current_room.get("type","")):
		"combat": enemy_count=4
		"hazard": enemy_count=2
	var room_seed := int(_room_contract.get("runtime_seed", int(config.seed)))
	var spawn_limit := clampi(int((_room_contract.get("spawn", {}) as Dictionary).get("max_active", enemy_count)),enemy_count,64)
	for index in enemy_count:
		var enemy_seed := _mix_room_seed(room_seed,index)
		var enemy_rng := RandomNumberGenerator.new()
		enemy_rng.seed = enemy_seed
		_spawn_enemy(Vector2(85+index*(370.0/maxf(1.0,enemy_count-1)),enemy_rng.randf_range(320,500)),enemy_seed,"",spawn_limit)

func _begin_organ_chamber() -> void:
	_transition(RunState.ORGAN_CHAMBER)
	AudioManager.set_music_state("organ",0.72)
	_organ_hit_count=0
	current_room=room_layout[-1] if not room_layout.is_empty() else {"id":"fallback_chamber","type":"chamber","boss":String(boss_definition.get("id","fallback_boss")),"organ":String(current_organ.get("id","fallback_organ")),"duration":20.0,"hazard":"cell_bloom","safe_rule":"Pass behind the bloom as it opens.","density":1}
	_room_elapsed = 0.0
	_room_event_index = 0
	_room_cycle_index = 0
	_room_contract = _resolve_room_contract(current_room, int(config.seed) + phase * 991 + 0x0A61)
	_sync_current_room_to_contract()
	organ_max=float(current_organ.get("hp",1500))*1.65*_difficulty_hp()
	organ_health=organ_max
	_boss_visual.set_interior(current_organ)
	_boss_visual.set_health(organ_health,organ_max)
	attack_timer=0.7
	var chamber_seed := int(_room_contract.get("runtime_seed", int(config.seed)))
	var chamber_limit := clampi(int((_room_contract.get("spawn", {}) as Dictionary).get("max_active", 2)),2,64)
	_spawn_enemy(Vector2(130,460),_mix_room_seed(chamber_seed,0),"",chamber_limit)
	_spawn_enemy(Vector2(410,500),_mix_room_seed(chamber_seed,1),"",chamber_limit)
	var organ_name := LocalizationService.content_text("organ",String(current_organ.get("id","")),"name",String(current_organ.get("name",LocalizationService.text("the_organ"))))
	_hud.show_toast(LocalizationService.text("destroy_organ",{"organ":organ_name}),VisualTheme.VULNERABLE)

func _spawn_enemy(at: Vector2, deterministic_seed: int = 0, contract_group: String = "", max_active: int = 64) -> bool:
	if _enemies.size() >= maxi(1,max_active):
		return false
	_enemy_serial+=1
	var local_rng := RandomNumberGenerator.new()
	var local_seed := deterministic_seed if deterministic_seed != 0 else _mix_room_seed(int(config.get("seed",1)),_enemy_serial)
	local_rng.seed = local_seed
	_enemies.append({
		"id":"enemy_%d"%_enemy_serial,
		"position":at,
		"velocity":Vector2(local_rng.randf_range(-65,65),local_rng.randf_range(-18,18)),
		"radius":14.0,
		"health":90.0*_difficulty_hp(),
		"shoot_timer":local_rng.randf_range(1.0,2.2),
		"phase":local_rng.randf_range(0,TAU),
		"local_seed":local_seed,
		"shot_sequence":0,
		"shot_telegraph_timer":0.0,
		"shot_telegraph_total":0.0,
		"shot_target":Vector2.ZERO,
		"contract_group":contract_group
	})
	queue_redraw()
	return true

func _update_enemies(delta: float) -> void:
	for index in _enemies.size():
		var enemy:Dictionary=_enemies[index]
		enemy.phase=float(enemy.phase)+delta
		var to_player:=_player.position-Vector2(enemy.position)
		enemy.velocity=Vector2(enemy.velocity).lerp(to_player.normalized()*58.0,1.0-exp(-1.2*delta))
		enemy.position=Vector2(enemy.position)+Vector2(enemy.velocity)*delta+Vector2(0,sin(float(enemy.phase)*3.0)*14.0*delta)
		enemy.position.x=clampf(Vector2(enemy.position).x,35,505)
		enemy.position.y=clampf(Vector2(enemy.position).y,300,675)
		if float(enemy.get("shot_telegraph_timer",0.0)) > 0.0:
			enemy.shot_telegraph_timer = float(enemy.shot_telegraph_timer)-delta
			if float(enemy.shot_telegraph_timer)<=0.0:
				var target := Vector2(enemy.get("shot_target",_player.position))
				var angle := (target-Vector2(enemy.position)).angle()
				var shot_group := "defender:%s:%d" % [String(enemy.id),int(enemy.shot_sequence)]
				_projectiles.spawn_enemy(enemy.position,Vector2.from_angle(angle)*215*_difficulty_projectile_speed(),8,{"radius":5.0,"life":3.0,"cause":"internal_defender","group":shot_group})
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

func _kill_enemy(index: int) -> void:
	if index<0 or index>=_enemies.size():
		return
	var enemy: Dictionary = _enemies.pop_at(index)
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
	if state!=RunState.BREACH_OPEN:
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
	_hud.show_mutation_choices(offers, _remaining_rerolls)

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
	_result_banked=SaveManager.bank_run(_result)
	if _result_banked:
		# bank_run persists the same profile dictionary, including meta-goal
		# receipts/rewards. Never acknowledge them if that atomic save failed.
		_meta_goals.mark_profile_persisted()
		_meta_dirty = false
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

func _on_result_action(action: String) -> void:
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
			_paused=false
			_player.set_controls_active(true)
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
	_player.set_controls_active(not _paused)
	if _paused:_hud.show_pause()
	else:_hud.hide_overlay()

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
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		_persist_meta_profile()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _paused and state not in [RunState.DEAD,RunState.VICTORY]:
		call_deferred("_toggle_pause")

func _draw() -> void:
	var interior:=state in [RunState.DIVING_IN,RunState.INTERNAL_ROOMS,RunState.ORGAN_CHAMBER,RunState.MUTATION_CHOICE,RunState.DIVING_OUT]
	draw_rect(Rect2(0,0,540,960),VisualTheme.TISSUE.darkened(0.58) if interior else VisualTheme.DEEP_SPACE)
	for star in _stars:
		var point:Vector2=star.position
		var alpha:=0.0 if interior else 0.18+sin(elapsed*1.4+float(star.phase))*0.12
		draw_circle(point,float(star.size),Color(0.72,0.88,1.0,alpha))
	if interior:
		for index in 15:
			var y:=float(index)*72.0+fmod(elapsed*35.0,72.0)-50.0
			var x:=270.0+sin(index*1.7+elapsed*0.45)*205.0
			draw_line(Vector2(0,y),Vector2(x,y+35),Color(VisualTheme.VULNERABLE,0.08),3.0+index%3)
			draw_line(Vector2(540,y+18),Vector2(540-x,y+55),Color(VisualTheme.SHARD,0.06),2.0)
	for enemy in _enemies:
		var p:Vector2=enemy.position
		var radius:=float(enemy.radius)
		var points:=PackedVector2Array()
		for index in 8:
			var angle:=index*TAU/8.0+float(enemy.phase)
			points.append(p+Vector2.from_angle(angle)*radius*(1.0 if index%2==0 else 0.58))
		draw_colored_polygon(points,Color(VisualTheme.BIO,0.28))
		draw_polyline(PackedVector2Array(points+PackedVector2Array([points[0]])),VisualTheme.BIO,2.0)
		if float(enemy.get("shot_telegraph_timer",0.0)) > 0.0:
			var target := Vector2(enemy.get("shot_target",p))
			var warning_progress := 1.0-float(enemy.shot_telegraph_timer)/maxf(0.01,float(enemy.get("shot_telegraph_total",0.01)))
			var warning_color := Color(VisualTheme.TELEGRAPH,0.38+warning_progress*0.58)
			draw_dashed_line(p,target,warning_color,2.5,9.0)
			draw_circle(target,12.0+warning_progress*7.0,warning_color,false,2.5)
	for pickup in _bio_pickups:
		var pickup_position:=Vector2(pickup.position)
		var pickup_pulse:=2.5+sin(float(pickup.phase))*0.8
		draw_circle(pickup_position,6.0+pickup_pulse,Color(VisualTheme.BIO,0.16))
		draw_circle(pickup_position,3.2,VisualTheme.BIO)
	for wake in _dash_wakes:
		var wake_alpha:=clampf(float(wake.life)/maxf(0.01,float(_mutation_engine.flags.get("dash_trail_duration",1.2))),0.0,1.0)
		draw_circle(Vector2(wake.position),15.0,Color(VisualTheme.FRIENDLY,wake_alpha*0.18))
		draw_arc(Vector2(wake.position),13.0,0.0,TAU,18,Color(VisualTheme.SHARD,wake_alpha*0.6),2.0)
	_draw_telegraph()
	_draw_orbitals()
	if state in [RunState.DIVING_IN,RunState.DIVING_OUT]:
		var ratio:=clampf(transition_timer/1.15,0,1)
		var radius:=(1.0-ratio)*650.0 if state==RunState.DIVING_IN else ratio*650.0
		draw_circle(Vector2(270,430),radius,Color(VisualTheme.DEEP_SPACE,0.68),false,10.0)
		draw_arc(Vector2(270,430),maxf(10,radius),0,TAU,64,VisualTheme.VULNERABLE,8.0)

func _draw_telegraph() -> void:
	if _telegraph.is_empty():return
	var progress:=1.0-float(_telegraph.timer)/maxf(0.01,float(_telegraph.total))
	var color:=Color(VisualTheme.TELEGRAPH,0.35+progress*0.6)
	var origin:=Vector2(_telegraph.get("pattern_origin",_boss_visual.target_position() if _boss_visual else Vector2(270,220)))
	var ability:=String(_telegraph.ability)
	var contract_family:=String(_telegraph.get("contract_family",""))
	if _telegraph.has("safe_position"):
		var safe_position := Vector2(_telegraph.safe_position)
		draw_circle(safe_position,34.0+sin(elapsed*8.0)*3.0,Color(VisualTheme.FRIENDLY,0.1+progress*0.12))
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

func _draw_orbitals() -> void:
	if weapon_definition.is_empty() or _player==null:return
	var count:=int(weapon_definition.get("orbitals",0))+int(_mutation_engine.stats.get("orbitals_add",0))
	var orbit_radius:=float(weapon_definition.get("orbital_radius",48.0))+_orbit_growth
	for index in count:
		var angle:=elapsed*2.8+index*TAU/maxf(1,count)
		var center:=_player.position+Vector2.from_angle(angle)*orbit_radius
		draw_arc(center,9.0+_orbit_growth*0.16,-PI*0.85,PI*0.85,12,VisualTheme.SHARD,4.0)
