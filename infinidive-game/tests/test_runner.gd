extends Node

const ChallengeCodeClass := preload("res://scripts/core/challenge_code.gd")
const MutationEngineClass := preload("res://scripts/core/mutation_engine.gd")
const OrganAbilityMapClass := preload("res://scripts/core/organ_ability_map.gd")
const RoomGeneratorClass := preload("res://scripts/core/room_generator.gd")
const ProjectilePoolClass := preload("res://scripts/gameplay/projectile_pool.gd")
const PlayerControllerClass := preload("res://scripts/gameplay/player_controller.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const RunHUDClass := preload("res://scripts/ui/run_hud.gd")
const MainClass := preload("res://scripts/ui/main.gd")
const NestViewClass := preload("res://scripts/ui/nest_view.gd")
const SafeAreaHelperClass := preload("res://scripts/ui/safe_area_helper.gd")
const TutorialFlowClass := preload("res://scripts/core/tutorial_flow.gd")
const AnalyticsServiceClass := preload("res://scripts/services/analytics_service.gd")

const ANALYTICS_CLEAR_TEST_PATH := "user://infinidive_analytics_clear_test.json"
const RESET_ANALYTICS_TEST_PATH := "user://infinidive_reset_analytics_test.json"
const RESET_LEADERBOARD_TEST_PATH := "user://infinidive_reset_leaderboard_test.json"
const TEST_ISOLATION_ENV := "INFINIDIVE_TEST_ISOLATED"

var failures: Array[String] = []
var passed_assertions: Array[String] = []
var passed := 0
var started_ms := 0

func _ready() -> void:
	started_ms = Time.get_ticks_msec()
	call_deferred("_run_all")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		passed_assertions.append(message)
	else:
		failures.append(message)
		push_error("TEST FAILURE: " + message)

func _run_all() -> void:
	await get_tree().process_frame
	var isolated_root := OS.get_environment("XDG_DATA_HOME").strip_edges()
	var user_data_path := ProjectSettings.globalize_path("user://").simplify_path()
	var isolated_prefix := isolated_root.simplify_path().trim_suffix("/") + "/"
	if OS.get_environment(TEST_ISOLATION_ENV) != "1" or isolated_root.is_empty() or not user_data_path.begins_with(isolated_prefix):
		_assert(false, "Main suite refused to run because user:// is not explicitly isolated; set INFINIDIVE_TEST_ISOLATED=1 and XDG_DATA_HOME to a temporary directory")
		_write_junit()
		print("INFINIDIVE TESTS: %d passed, %d failed" % [passed, failures.size()])
		AudioManager.shutdown_for_tests()
		await get_tree().process_frame
		get_tree().quit(1)
		return
	_test_data_integrity()
	_test_organ_orders()
	_test_challenge_codes()
	_test_challenge_code_malformed_and_fuzz()
	_test_mutations()
	_test_localization_and_settings()
	await _test_localized_ui()
	_test_analytics_contract()
	_test_room_generation()
	_test_project_configuration()
	_test_safe_area_math()
	await _test_projectile_pool()
	await _test_player_movement()
	await _test_player_damage_and_dash()
	await _test_pause_resume_control_policy()
	await _test_telegraph_avoidance_and_combat_sfx()
	await _test_mutation_weapon_runtime()
	await _test_meta_save_handoff()
	await _test_save_recovery()
	await _test_save_migration_and_banking()
	await _test_failure_forge_retry_relaunch()
	await _test_reset_local_data_integration()
	await _test_tutorial_scene_handoff()
	await _test_first_core_hook()
	await _test_complete_boss_runs_and_orders()
	_write_junit()
	print("INFINIDIVE TESTS: %d passed, %d failed" % [passed, failures.size()])
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if not failures.is_empty() else 0)

func _test_data_integrity() -> void:
	_assert(GameData.validation_errors.is_empty(), "GameData must pass validation: %s" % [GameData.validation_errors])
	_assert(GameData.bosses.size() == 4, "Exactly four bosses are required")
	_assert(GameData.weapons.size() == 5, "Exactly five weapons are required")
	_assert(GameData.mutations.size() >= 24, "At least 24 mutations are required")
	_assert(GameData.upgrades.size() >= 18, "At least 18 upgrades are required")
	var modules := 0
	var chambers := 0
	for raw_room in GameData.rooms:
		var room: Dictionary = raw_room
		if String(room.type) == "chamber": chambers += 1
		else: modules += 1
	_assert(modules >= 30, "At least 30 authored room modules are required")
	_assert(chambers >= 12, "At least 12 organ chambers are required")
	_assert(RunSceneClass.validate_weapon_catalog(GameData.weapons).is_empty(), "Every weapon must pass its behavior-specific runtime contract")
	var weapon_behaviors: Dictionary = {}
	for raw_weapon in GameData.weapons:
		weapon_behaviors[String((raw_weapon as Dictionary).behavior)]=true
	_assert(weapon_behaviors.size()==5, "All five launch weapons must use distinct runtime behaviors")
	var scatter:=GameData.get_weapon("scatter_maw")
	_assert(RunSceneClass.weapon_range_multiplier(scatter,100.0)>RunSceneClass.weapon_range_multiplier(scatter,400.0), "Scatter Maw must lose damage with distance")

func _test_organ_orders() -> void:
	for raw_boss in GameData.bosses:
		var boss: Dictionary = raw_boss
		var ids: Array[String] = []
		for raw_organ in boss.organs:
			ids.append(String(raw_organ.id))
		for order in _permutations(ids):
			var mapping := OrganAbilityMapClass.new()
			mapping.initialize(boss)
			for organ_id in order:
				var ability := String(mapping.organs[organ_id].ability)
				var abilities_before := mapping.abilities.duplicate(true)
				var change: Dictionary = mapping.destroy_organ(organ_id)
				_assert(not change.is_empty(), "%s organ %s must destroy once" % [boss.id, organ_id])
				_assert(not mapping.is_ability_enabled(ability), "%s must disable %s" % [organ_id, ability])
				for other_ability_value in mapping.abilities:
					var other_ability := String(other_ability_value)
					if other_ability != ability:
						_assert(
							mapping.is_ability_enabled(other_ability) == bool(abilities_before[other_ability].enabled),
							"Destroying %s must not alter unrelated ability %s" % [organ_id, other_ability]
						)
				_assert(mapping.destroy_organ(organ_id).is_empty(), "Organ destruction must be idempotent")
			_assert(mapping.alive_organs().is_empty(), "Every organ order must reach the core")
		var unknown_mapping := OrganAbilityMapClass.new()
		unknown_mapping.initialize(boss)
		var unknown_snapshot := JSON.stringify(unknown_mapping.abilities)
		_assert(unknown_mapping.destroy_organ("__unknown_organ__").is_empty(), "%s must reject an unknown organ" % boss.id)
		_assert(JSON.stringify(unknown_mapping.abilities) == unknown_snapshot, "%s unknown organ input must not mutate abilities" % boss.id)

func _permutations(values: Array[String]) -> Array:
	var result: Array = []
	for a in values:
		for b in values:
			for c in values:
				if a != b and a != c and b != c:
					result.append([a,b,c])
	return result

func _test_challenge_codes() -> void:
	var challenge := {"boss":"null_twin","seed":938221,"weapon":"rail_spine","difficulty":"abyss","modifiers":["dense"]}
	var code: String = ChallengeCodeClass.encode(challenge)
	var decoded: Dictionary = ChallengeCodeClass.decode(code)
	_assert(decoded.boss == challenge.boss and decoded.seed == challenge.seed, "Friend Rift code must round-trip")
	_assert(ChallengeCodeClass.decode(code + "x").is_empty(), "Tampered Friend Rift code must be rejected")
	_assert(ChallengeCodeClass.daily_seed({"year":2026,"month":9,"day":1}) == ChallengeCodeClass.daily_seed({"year":2026,"month":9,"day":1}), "Daily seed must be deterministic")
	var score_win := RunSceneClass.evaluate_friend_target(12000,90000,false,10000,80000)
	_assert(bool(score_win.met) and bool(score_win.score_met), "Friend Rift score targets can be beaten even on a failed boss attempt")
	var time_win := RunSceneClass.evaluate_friend_target(9000,70000,true,10000,80000)
	_assert(bool(time_win.met) and bool(time_win.time_met), "Friend Rift time targets require a winning run inside the target time")
	_assert(not bool(RunSceneClass.evaluate_friend_target(9000,70000,false,10000,80000).met), "A death cannot beat a Friend Rift through its time target")
	_assert(not bool(RunSceneClass.evaluate_friend_target(1,1000,true,0,0).has_target), "A target-free Friend Rift must not claim a comparison result")

func _test_challenge_code_malformed_and_fuzz() -> void:
	var valid_shape := {"b":"gravemaw","s":7719,"w":"pulse_needle","d":"diver","m":[],"t":0,"r":0}
	var malformed_codes: Array[String] = [
		"",
		"ID1",
		"ID1.payload",
		"ID2.payload.checksum",
		"ID1..",
		"ID1.%s.CHECKSUM.extra" % Marshalls.raw_to_base64("{}".to_utf8_buffer()),
		_encoded_challenge_json("[]"),
		_encoded_challenge_json("null"),
		_encoded_challenge_json("{}"),
		_encoded_challenge_dictionary(valid_shape.merged({"b":"unknown_boss"},true)),
		_encoded_challenge_dictionary(valid_shape.merged({"w":"unknown_weapon"},true)),
		_encoded_challenge_dictionary(valid_shape.merged({"d":"impossible"},true)),
		_encoded_challenge_dictionary(valid_shape.merged({"s":0},true)),
		_encoded_challenge_dictionary(valid_shape.merged({"m":"not_an_array"},true)),
		_encoded_challenge_dictionary(valid_shape.merged({"m":["a","b","c","d","e"]},true)),
		_encoded_challenge_dictionary(valid_shape.merged({"m":["x".repeat(900)]},true))
	]
	for malformed_index in malformed_codes.size():
		_assert(
			ChallengeCodeClass.decode(malformed_codes[malformed_index]).is_empty(),
			"Malformed Friend Rift case %d must be rejected" % malformed_index
		)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1F1D1E
	var modifier_pool := ["dense", "fragile", "swift", "mirror"]
	for fuzz_index in 160:
		var modifier_count := rng.randi_range(0,4)
		var modifiers: Array[String] = []
		for modifier_index in modifier_count:
			modifiers.append(String(modifier_pool[(fuzz_index + modifier_index) % modifier_pool.size()]))
		var challenge := {
			"boss": String(ChallengeCodeClass.ALLOWED_BOSSES[rng.randi_range(0,ChallengeCodeClass.ALLOWED_BOSSES.size()-1)]),
			"seed": rng.randi_range(1,2147483646),
			"weapon": String(ChallengeCodeClass.ALLOWED_WEAPONS[rng.randi_range(0,ChallengeCodeClass.ALLOWED_WEAPONS.size()-1)]),
			"difficulty": String(ChallengeCodeClass.ALLOWED_DIFFICULTIES[rng.randi_range(0,ChallengeCodeClass.ALLOWED_DIFFICULTIES.size()-1)]),
			"modifiers": modifiers,
			"target_score": rng.randi_range(0,2000000000),
			"target_time_ms": rng.randi_range(0,2000000000)
		}
		var code := ChallengeCodeClass.encode(challenge)
		var decoded := ChallengeCodeClass.decode(code)
		_assert(
			not decoded.is_empty()
			and String(decoded.boss) == String(challenge.boss)
			and int(decoded.seed) == int(challenge.seed)
			and String(decoded.weapon) == String(challenge.weapon)
			and String(decoded.difficulty) == String(challenge.difficulty)
			and decoded.modifiers == challenge.modifiers
			and int(decoded.target_score) == int(challenge.target_score)
			and int(decoded.target_time_ms) == int(challenge.target_time_ms),
			"Deterministic valid Friend Rift fuzz case %d must round-trip" % fuzz_index
		)

	var raw_alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
	for fuzz_index in 128:
		var length := rng.randi_range(0,180)
		var raw := "FUZZ"
		for character_index in length:
			raw += raw_alphabet[rng.randi_range(0,raw_alphabet.length()-1)]
		var decoded := ChallengeCodeClass.decode(raw)
		_assert(decoded.is_empty() or ChallengeCodeClass.is_valid(decoded), "Raw Friend Rift fuzz case %d must fail closed" % fuzz_index)

func _encoded_challenge_dictionary(packed: Dictionary) -> String:
	return _encoded_challenge_json(JSON.stringify(packed))

func _encoded_challenge_json(json: String) -> String:
	var payload := Marshalls.raw_to_base64(json.to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	return "ID1.%s.%s" % [payload,json.sha256_text().left(7).to_upper()]

func _test_mutations() -> void:
	var engine := MutationEngineClass.new()
	engine.initialize(12031,{"damage_mul":1.0,"projectile_count_add":0,"armor_damage_mul":1.0,"organ_damage_mul":1.0})
	var offer_a: Array[Dictionary] = engine.offer(GameData.mutations,3)
	var engine_b := MutationEngineClass.new()
	engine_b.initialize(12031,{"damage_mul":1.0,"projectile_count_add":0,"armor_damage_mul":1.0,"organ_damage_mul":1.0})
	var offer_b: Array[Dictionary] = engine_b.offer(GameData.mutations,3)
	_assert(offer_a.map(func(item:Dictionary):return item.id) == offer_b.map(func(item:Dictionary):return item.id), "Mutation offers must be seed deterministic")
	_assert(offer_a.size() == 3 and offer_a[0].id != offer_a[1].id, "Mutation offers may not duplicate")
	var split := GameData.get_mutation("split_chamber")
	_assert(engine.apply(split), "Mutation must apply the first time")
	_assert(not engine.apply(split), "Mutation must not apply twice")
	_assert(int(engine.stats.projectile_count_add) == 2, "Split Chamber must add two projectiles")
	_assert(MutationEngineClass.validate_catalog(GameData.mutations).is_empty(), "Every mutation effect key must belong to the runtime contract")
	var exercised_keys: Dictionary = {}
	for raw_mutation in GameData.mutations:
		var mutation: Dictionary = raw_mutation
		var effect_engine:=MutationEngineClass.new()
		effect_engine.initialize(7719,{})
		_assert(effect_engine.apply(mutation), "%s must apply through the effect contract" % mutation.id)
		for raw_key in (mutation.effects as Dictionary):
			var key:=String(raw_key)
			var operation:=String(MutationEngineClass.EFFECT_OPERATIONS.get(key,""))
			var expected: Variant = mutation.effects[raw_key]
			var stored: Variant = effect_engine.stats.get(key,null) if operation in ["add","multiply"] else effect_engine.flags.get(key,null)
			var matches: bool = typeof(expected)==TYPE_BOOL and stored==expected
			if typeof(expected) in [TYPE_INT,TYPE_FLOAT]:
				matches=is_equal_approx(float(stored),float(expected))
			_assert(matches,"%s/%s must reach its declared runtime bucket" % [mutation.id,key])
			exercised_keys[key]=true
	_assert(exercised_keys.size()==MutationEngineClass.EFFECT_OPERATIONS.size(), "The launch catalog must exercise every supported mutation effect key")
	var invalid_effect:={"id":"invalid_effect","effects":{"unwired_key":1.0}}
	var invalid_engine:=MutationEngineClass.new()
	invalid_engine.initialize(1,{})
	_assert(not MutationEngineClass.validate_definition(invalid_effect).is_empty() and not invalid_engine.apply(invalid_effect), "Unknown mutation effects must be rejected before selection")
	var invalid_type:={"id":"invalid_type","effects":{"dash_trail":1.0}}
	_assert(not MutationEngineClass.validate_definition(invalid_type).is_empty(), "Mutation validation must reject a wrong effect value type")

	var needle_engine:=MutationEngineClass.new()
	needle_engine.initialize(2,{})
	needle_engine.apply(GameData.get_mutation("needle_through_bone"))
	_assert(is_equal_approx(needle_engine.damage_multiplier("armor",500.0,1.0,0,0),1.3), "Needle Through Bone must amplify armor damage")
	_assert(is_equal_approx(needle_engine.damage_multiplier("core",500.0,1.0,0,0),1.0), "Needle Through Bone must not amplify final-core damage")
	var deep_engine:=MutationEngineClass.new()
	deep_engine.initialize(3,{})
	deep_engine.apply(GameData.get_mutation("deep_adaptation"))
	_assert(is_equal_approx(deep_engine.damage_multiplier("internal",500.0,1.0,0,0),1.32), "Deep Adaptation must amplify internal damage")
	_assert(is_equal_approx(deep_engine.damage_multiplier("core",500.0,1.0,0,0),0.92), "Deep Adaptation must reduce all external damage")
	var predator_engine:=MutationEngineClass.new()
	predator_engine.initialize(4,{})
	predator_engine.apply(GameData.get_mutation("predator_vector"))
	_assert(predator_engine.damage_multiplier("core",0.0,1.0,0,0)>predator_engine.damage_multiplier("core",500.0,1.0,0,0), "Predator Vector must scale continuously with proximity")
	var wound_engine:=MutationEngineClass.new()
	wound_engine.initialize(5,{})
	wound_engine.apply(GameData.get_mutation("wound_memory"))
	_assert(wound_engine.damage_multiplier("armor",300.0,1.0,0,0,true)>wound_engine.damage_multiplier("armor",300.0,1.0,0,0,false), "Wound Memory must amplify only an active exposed-wound window")
	var rate_engine:=MutationEngineClass.new()
	rate_engine.initialize(6,{})
	rate_engine.apply(GameData.get_mutation("last_pulse"))
	rate_engine.apply(GameData.get_mutation("breach_hunger"))
	_assert(RunSceneClass.effective_fire_interval(1.0,0.2,rate_engine.flags,false)<RunSceneClass.effective_fire_interval(1.0,0.8,rate_engine.flags,false), "Last Pulse must accelerate fire only below its hull threshold")
	_assert(RunSceneClass.effective_fire_interval(1.0,0.8,rate_engine.flags,true)<RunSceneClass.effective_fire_interval(1.0,0.8,rate_engine.flags,false), "Breach Hunger must accelerate fire only during its timer")

func _test_localization_and_settings() -> void:
	var english_keys: Array = LocalizationService.STRINGS.en.keys()
	var hebrew_keys: Array = LocalizationService.STRINGS.he.keys()
	english_keys.sort()
	hebrew_keys.sort()
	_assert(english_keys == hebrew_keys, "English and Hebrew localization tables must contain identical keys")
	var all_strings_present := true
	for key_value in english_keys:
		var key := String(key_value)
		all_strings_present = all_strings_present and not String(LocalizationService.STRINGS.en[key]).strip_edges().is_empty()
		all_strings_present = all_strings_present and not String(LocalizationService.STRINGS.he[key]).strip_edges().is_empty()
	_assert(all_strings_present, "English and Hebrew localization values must not be empty")
	var original_values := SettingsManager.values.duplicate(true)
	SettingsManager.values.language = "en"
	var english_tagline := LocalizationService.text("tagline")
	_assert(not LocalizationService.is_rtl(), "English locale must use left-to-right layout")
	SettingsManager.values.language = "he"
	_assert(LocalizationService.is_rtl(), "Hebrew locale must use right-to-left layout")
	_assert(ThemeDB.fallback_font.has_char("א".unicode_at(0)), "The runtime fallback font must contain Hebrew glyphs")
	_assert(LocalizationService.start_alignment() == HORIZONTAL_ALIGNMENT_RIGHT, "Hebrew text must align to the visual start edge")
	_assert(LocalizationService.layout_direction() == Control.LAYOUT_DIRECTION_RTL, "Hebrew containers must use RTL layout direction")
	_assert(LocalizationService.text("tagline") != english_tagline, "Switching to Hebrew must return translated copy")
	_assert(LocalizationService.text("seed_value",{"value":7719}).contains("7719"), "Localized placeholders must preserve supplied values")
	_assert(LocalizationService.text("__missing_key__") == "__missing_key__", "Missing localization keys must fail visibly instead of returning blank text")
	_assert(LocalizationService.cause_text("ability:homing_eye") == LocalizationService.STRINGS.he.ability_homing_eye, "Stable ability cause IDs must localize only at presentation time")
	_assert(LocalizationService.cause_text("hazard:tracking_gaze") == LocalizationService.content_text("hazard","tracking_gaze","name",""), "Stable hazard cause IDs must localize only at presentation time")
	for raw_boss in GameData.bosses:
		var boss: Dictionary = raw_boss
		var boss_id := String(boss.id)
		for field in ["name","subtitle","fantasy"]:
			_assert(LocalizationService.content_text("boss",boss_id,field,"__missing__") != "__missing__", "Hebrew boss %s/%s must be translated" % [boss_id,field])
		for raw_organ in boss.organs:
			var organ: Dictionary = raw_organ
			var organ_id := String(organ.id)
			for field in ["name","effect"]:
				_assert(LocalizationService.content_text("organ",organ_id,field,"__missing__") != "__missing__", "Hebrew organ %s/%s must be translated" % [organ_id,field])
			var organ_hazard := String(organ.get("hazard",""))
			_assert(LocalizationService.content_text("hazard",organ_hazard,"name","__missing__") != "__missing__", "Hebrew organ hazard %s must be translated" % organ_hazard)
			var ability_id := String(organ.get("ability",""))
			_assert(LocalizationService.ability_text(ability_id) != ability_id.replace("_"," ").capitalize(), "Hebrew boss ability %s must be translated" % ability_id)
	for raw_weapon in GameData.weapons:
		var weapon: Dictionary = raw_weapon
		var weapon_id := String(weapon.id)
		for field in ["name","description","weakness"]:
			_assert(LocalizationService.content_text("weapon",weapon_id,field,"__missing__") != "__missing__", "Hebrew weapon %s/%s must be translated" % [weapon_id,field])
	for raw_mutation in GameData.mutations:
		var mutation: Dictionary = raw_mutation
		var mutation_id := String(mutation.id)
		for field in ["name","description"]:
			_assert(LocalizationService.content_text("mutation",mutation_id,field,"__missing__") != "__missing__", "Hebrew mutation %s/%s must be translated" % [mutation_id,field])
	for raw_upgrade in GameData.upgrades:
		var upgrade: Dictionary = raw_upgrade
		var upgrade_id := String(upgrade.id)
		for field in ["name","description"]:
			_assert(LocalizationService.content_text("upgrade",upgrade_id,field,"__missing__") != "__missing__", "Hebrew upgrade %s/%s must be translated" % [upgrade_id,field])
	for raw_room in GameData.rooms:
		var room: Dictionary = raw_room
		var room_id := String(room.id)
		_assert(LocalizationService.content_text("room",room_id,"safe_rule","__missing__") != "__missing__", "Hebrew room rule %s must be translated" % room_id)
		var room_hazard := String(room.get("hazard",""))
		_assert(LocalizationService.content_text("hazard",room_hazard,"name","__missing__") != "__missing__", "Hebrew room hazard %s must be translated" % room_hazard)
	_assert(LocalizationService.room_type_text("combat") == LocalizationService.STRINGS.he.room_combat, "Hebrew room type labels must be localized")
	SettingsManager.values = original_values
	var required_settings := [
		"master_volume", "music_volume", "sfx_volume", "haptics", "screen_shake",
		"reduced_motion", "projectile_contrast", "damage_flash", "control_sensitivity",
		"dash_method", "handedness", "language", "analytics_opt_in",
		"assist_projectile_speed", "assist_telegraph", "assist_dash_window", "aim_assist"
	]
	var default_settings: Dictionary = SaveManager.default_profile().settings
	var settings_complete := true
	for setting_name in required_settings:
		settings_complete = settings_complete and default_settings.has(setting_name)
	_assert(settings_complete, "Default profile must include every required accessibility and control setting")

func _test_localized_ui() -> void:
	var original_values := SettingsManager.values.duplicate(true)
	SettingsManager.values.language = "he"
	var nest := NestViewClass.new()
	add_child(nest)
	await get_tree().process_frame
	_assert(nest._tagline.text == LocalizationService.STRINGS.he.tagline, "Nest tagline must render the selected Hebrew locale")
	_assert(nest._tagline.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Nest Hebrew copy must align right")
	_assert(nest._difficulty.get_item_text(0) == LocalizationService.STRINGS.he.diver, "Difficulty choices must localize at runtime")
	_assert(nest._boss_title.text == LocalizationService.content_text("boss","gravemaw","name",""), "Nest boss data must use localized content")
	nest._show_hangar()
	await get_tree().process_frame
	var nest_overlay_box := nest._overlay.get_child(0) as VBoxContainer
	_assert(nest_overlay_box.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Nest overlays must mirror their container layout for Hebrew")
	nest._show_rift()
	await get_tree().process_frame
	var rift_text := _collect_ui_text(nest._overlay)
	_assert(rift_text.contains(LocalizationService.STRINGS.he.daily_reset), "Daily Rift must visibly show its deterministic UTC reset")
	nest._show_settings()
	await get_tree().process_frame
	var settings_text := _collect_ui_text(nest._overlay)
	_assert(settings_text.contains(LocalizationService.STRINGS.he.support_feedback), "Settings must expose localized support and feedback")
	_assert(settings_text.contains(LocalizationService.STRINGS.he.privacy_policy), "Settings must expose the localized privacy policy")
	_assert(NestViewClass.NATIVE_PUBLIC_SITE_BASE.begins_with("https://") and NestViewClass.NATIVE_PUBLIC_SITE_BASE.ends_with("/"), "Native support links must use a documented absolute HTTPS base")
	nest.queue_free()
	await get_tree().process_frame

	var hud := RunHUDClass.new()
	add_child(hud)
	await get_tree().process_frame
	hud.show_organ_choices(GameData.bosses[0].organs)
	var organ_box := hud.overlay.get_child(0) as VBoxContainer
	var organ_button := organ_box.get_child(3) as Button
	_assert(organ_box.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Run choice overlays must use RTL layout in Hebrew")
	_assert(organ_button.alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Hebrew organ choices must align to the right edge")
	_assert(organ_button.text.contains(LocalizationService.content_text("organ","hunter_eye","name","")), "Organ choices must render translated data copy")
	hud.show_mutation_choices([GameData.mutations[0]],0)
	await get_tree().process_frame
	var mutation_box := hud.overlay.get_child(0) as VBoxContainer
	var mutation_button := mutation_box.get_child(2) as Button
	_assert(mutation_button.text.contains(LocalizationService.content_text("mutation","split_chamber","name","")), "Mutation choices must render translated data copy")
	hud.show_result({
		"won":false,
		"cause":"ability:homing_eye",
		"score":12345,
		"time_text":"02:34",
		"banked_bio":88,
		"abyss_depth":7,
		"boss_id":"gravemaw",
		"weapon":"pulse_needle",
		"destroyed_organs":["hunter_eye"],
		"mutations":["split_chamber"]
	})
	await get_tree().process_frame
	var result_text := _collect_ui_text(hud.overlay)
	var result_box := hud.overlay.get_child(0) as VBoxContainer
	_assert(result_text.contains(LocalizationService.content_text("boss","gravemaw","name","")), "Result card must identify the localized boss")
	_assert(result_text.contains(LocalizationService.content_text("weapon","pulse_needle","name","")), "Result card must identify the localized weapon")
	_assert(result_text.contains(LocalizationService.content_text("organ","hunter_eye","name","")), "Result card must list destroyed organs")
	_assert(result_text.contains(LocalizationService.content_text("mutation","split_chamber","name","")), "Result card must list major mutations")
	_assert(result_text.contains("12345") and result_text.contains("02:34") and result_text.contains("7"), "Result card must include score, time, and depth")
	_assert(result_text.contains(LocalizationService.STRINGS.he.ability_homing_eye), "Result card must translate the attributable death cause")
	_assert(result_box.get_combined_minimum_size().y <= hud.overlay.size.y-28.0, "Result card must fit inside the 540x960 HUD overlay")
	_assert(not result_text.contains("@"), "Result card must not expose an email address or private account information")
	hud.queue_free()
	await get_tree().process_frame
	SettingsManager.values = original_values

func _collect_ui_text(node:Node)->String:
	var fragments: Array[String] = []
	if node is Label:
		fragments.append((node as Label).text)
	elif node is Button:
		fragments.append((node as Button).text)
	elif node is LineEdit:
		fragments.append((node as LineEdit).placeholder_text)
	for child in node.get_children():
		fragments.append(_collect_ui_text(child))
	return "\n".join(fragments)

func _test_analytics_contract() -> void:
	var required_events := [
		"app_open", "session_start", "tutorial_start", "tutorial_step", "tutorial_complete",
		"first_shot", "first_damage_taken", "first_dash", "first_breach", "first_dive",
		"organ_destroyed", "boss_phase_reached", "mutation_offered", "mutation_selected",
		"player_death", "instant_retry", "run_complete", "weapon_selected", "forge_purchase",
		"nest_upgrade", "daily_rift_start", "daily_rift_complete", "friend_rift_created",
		"friend_rift_opened", "abyss_depth_reached", "settings_changed", "session_end"
	]
	var event_contract_complete := true
	for event_name in required_events:
		event_contract_complete = event_contract_complete and AnalyticsService.ALLOWED_EVENTS.has(event_name)
	_assert(event_contract_complete, "Analytics abstraction must define every required product event")
	var original_values := SettingsManager.values.duplicate(true)
	var queue_size_before := AnalyticsService.queue.size()
	SettingsManager.values.analytics_opt_in = false
	AnalyticsService.track("first_dive", {"seed":7719})
	_assert(AnalyticsService.queue.size() == queue_size_before, "Analytics opt-out must prevent event queueing")
	var sanitized: Dictionary = AnalyticsService._sanitize({"safe":7,"nested":{"private":"drop"},"list":[1,2],"flag":true})
	_assert(sanitized == {"safe":7,"flag":true}, "Analytics properties must discard nested or unsupported values")
	_remove_test_file(ANALYTICS_CLEAR_TEST_PATH)
	var scoped_service := AnalyticsServiceClass.new()
	scoped_service.queue_path = ANALYTICS_CLEAR_TEST_PATH
	scoped_service.queue = [{"event":"first_dive","properties":{},"session_id":"test","timestamp":"2026-09-01T00:00:00Z"}]
	_assert(scoped_service._persist_queue(), "Analytics clear test must persist a scoped local queue")
	_assert(FileAccess.file_exists(ANALYTICS_CLEAR_TEST_PATH), "Analytics queue must exist before explicit local-data deletion")
	_assert(scoped_service.clear_local_data(), "Analytics local-data deletion must report success")
	_assert(scoped_service.queue.is_empty() and not FileAccess.file_exists(ANALYTICS_CLEAR_TEST_PATH), "Analytics local-data deletion must clear memory and remove its file")
	_assert(String(scoped_service.last_storage_status) == "cleared" and scoped_service.clear_local_data(), "Analytics local-data deletion must be inspectable and idempotent")
	scoped_service.free()
	SettingsManager.values = original_values

func _test_room_generation() -> void:
	var generator := RoomGeneratorClass.new()
	for raw_boss in GameData.bosses:
		var boss: Dictionary = raw_boss
		for raw_organ in boss.organs:
			var organ: Dictionary = raw_organ
			var first: Array[Dictionary] = generator.generate(GameData.rooms,String(boss.id),String(organ.id),7719)
			var second: Array[Dictionary] = generator.generate(GameData.rooms,String(boss.id),String(organ.id),7719)
			_assert(generator.validate_layout(first), "%s/%s layout must be safe" % [boss.id,organ.id])
			_assert(first.map(func(item:Dictionary):return item.id) == second.map(func(item:Dictionary):return item.id), "Room layout must be deterministic")

func _test_project_configuration() -> void:
	_assert(String(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items", "Portrait UI must use canvas_items stretching")
	_assert(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand", "Portrait UI must expand for tall and wide phones")
	_assert(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 1, "Mobile orientation must be portrait")
	_assert(String(ProjectSettings.get_setting("rendering/renderer/rendering_method.web")) == "gl_compatibility", "Web must use the Compatibility renderer")

func _test_safe_area_math() -> void:
	var visible := Rect2(Vector2.ZERO, Vector2(540.0, 960.0))
	var safe := SafeAreaHelperClass.rect_from_insets(visible, Vector2(1080.0, 1920.0), Vector4(0.0, 100.0, 0.0, 60.0))
	_assert(is_equal_approx(safe.position.y, 50.0), "Native safe-area top inset must convert into logical coordinates")
	_assert(is_equal_approx(safe.size.y, 880.0), "Native safe-area height must subtract top and bottom insets")
	var fitted := SafeAreaHelperClass.fitted_design_rect(safe)
	_assert(fitted.position.y >= safe.position.y and fitted.end.y <= safe.end.y + 0.01, "Fitted UI must remain inside the safe area")

func _test_projectile_pool() -> void:
	var pool := ProjectilePoolClass.new()
	add_child(pool)
	pool.spawn_player(Vector2(100,100),Vector2(1000,0),25,{"life":1.0})
	var result: Dictionary = pool.step(0.1,[{"id":"target","position":Vector2(190,100),"radius":12}],Vector2(0,0),10)
	_assert(result.target_hits.size() == 1, "Segment collision must catch a fast projectile")
	_assert(pool.player_active.is_empty() and pool._player_free.size() == 1, "Player projectile must return to pool")
	pool.spawn_player(Vector2(20,140),Vector2(3000,0),20,{"life":1.0,"pierce":2,"behavior":"rail"})
	result = pool.step(0.1,[
		{"id":"far","position":Vector2(280,140),"radius":10},
		{"id":"near","position":Vector2(100,140),"radius":10},
		{"id":"mid","position":Vector2(190,140),"radius":10}
	],Vector2(0,0),10)
	_assert(result.target_hits.map(func(hit: Dictionary): return hit.id) == ["near","mid","far"], "Piercing projectiles must hit every crossed target from nearest to farthest")
	_assert(is_equal_approx(float(result.target_hits[0].damage),20.0), "First piercing hit must use full projectile damage")
	_assert(is_equal_approx(float(result.target_hits[1].damage),18.0), "Piercing damage must fall after the first target")
	_assert(is_equal_approx(float(result.target_hits[2].damage),16.2), "Piercing damage falloff must apply for every crossed target")
	_assert(pool.player_active.is_empty(), "A projectile with two pierces must return to the pool after its third hit")
	pool.spawn_enemy(Vector2(100,100),Vector2.ZERO,9,{"group":"qa_enemy_wave"})
	result = pool.step(0.016,[],Vector2(100,100),10)
	_assert(result.player_hits.size() == 1, "Enemy projectile must report player hit")
	_assert(String(result.player_hits[0].group) == "qa_enemy_wave", "Enemy projectile hits must preserve their telegraphed wave identity")
	var all_capacity_spawns_succeeded := true
	for index in ProjectilePoolClass.MAX_PLAYER:
		all_capacity_spawns_succeeded = pool.spawn_player(Vector2(270,500),Vector2.ZERO,1.0,{"life":10.0}) and all_capacity_spawns_succeeded
	_assert(all_capacity_spawns_succeeded, "Projectile pool must accept exactly its configured player capacity")
	_assert(not pool.spawn_player(Vector2(270,500),Vector2.ZERO,1.0), "Projectile pool must reject allocation beyond its hard cap")
	pool.clear_all()
	_assert(pool.player_active.is_empty() and pool.enemy_active.is_empty(), "Clearing the projectile pool must release every active projectile")
	_assert(pool._player_free.size() == ProjectilePoolClass.MAX_PLAYER, "Cleared player projectiles must remain reusable in the pool")
	pool.queue_free()
	await get_tree().process_frame

func _test_player_movement() -> void:
	var player := PlayerControllerClass.new()
	player.position = Vector2(270,700)
	player.combat_bounds = Rect2(24,395,492,450)
	add_child(player)
	var desired_target := Vector2(470,790)
	var screen_target := player.get_viewport().get_canvas_transform() * (desired_target - PlayerControllerClass.FINGER_OFFSET)
	player._set_touch_target(screen_target)
	_assert(player._target.distance_to(desired_target) < 0.75, "Touch targeting must apply the configured finger offset in canvas coordinates")
	var initial_distance := player.position.distance_to(desired_target)
	player._dragging = true
	for frame in 30:
		player._physics_process(1.0/60.0)
	_assert(player.position.distance_to(desired_target) < initial_distance, "Dragging must move the player toward the touch target")
	_assert(player.combat_bounds.has_point(player.position), "Touch movement must keep the player inside combat bounds")
	player._target = Vector2(5000,-5000)
	player._physics_process(1.0/60.0)
	_assert(player.combat_bounds.has_point(player.position), "Out-of-range input must not move the player outside combat bounds")
	_assert(
		player._target.x >= player.combat_bounds.position.x
		and player._target.x <= player.combat_bounds.end.x
		and player._target.y >= player.combat_bounds.position.y
		and player._target.y <= player.combat_bounds.end.y,
		"Out-of-range touch targets must be clamped to combat bounds"
	)
	player.queue_free()

	var player_60 := PlayerControllerClass.new()
	var player_30 := PlayerControllerClass.new()
	for candidate in [player_60,player_30]:
		candidate.position = Vector2(100,700)
		candidate.combat_bounds = Rect2(24,395,492,450)
		add_child(candidate)
		candidate._target = Vector2(480,520)
		candidate._dragging = true
	for frame in 60:
		player_60._physics_process(1.0/60.0)
	for frame in 30:
		player_30._physics_process(1.0/30.0)
	_assert(player_60.position.distance_to(player_30.position) < 12.0, "Movement must remain materially consistent at 30 and 60 physics steps")
	player_60.queue_free()
	player_30.queue_free()
	await get_tree().process_frame

func _test_player_damage_and_dash() -> void:
	var dash_30 := PlayerControllerClass.new()
	var dash_60 := PlayerControllerClass.new()
	for candidate in [dash_30,dash_60]:
		candidate.position = Vector2(100,700)
		candidate.combat_bounds = Rect2(0,350,540,560)
		add_child(candidate)
		_assert(candidate.request_dash(Vector2.RIGHT), "Frame-rate dash probe must start with a ready charge")
	for frame in 5:
		dash_30._physics_process(1.0/30.0)
	dash_30._physics_process(1.0/75.0)
	for frame in 10:
		dash_60._physics_process(1.0/60.0)
	dash_60._physics_process(1.0/75.0)
	_assert(dash_30.position.distance_to(dash_60.position) < 0.01, "Dash travel must be identical at 30 and 60 physics steps")
	_assert(absf(dash_30.position.x - 326.8) < 0.02, "Dash travel must consume exactly its configured 0.18-second window")
	dash_30.queue_free()
	dash_60.queue_free()

	var player := PlayerControllerClass.new()
	player.position = Vector2(270,700)
	add_child(player)
	player.configure({"max_health":100,"dash_cooldown":1.0,"dash_charges":1})
	var started_health := player.health
	_assert(player.request_dash(Vector2.UP), "A ready dash must start")
	_assert(not player.request_dash(Vector2.UP), "Dash cannot be started twice from one charge")
	_assert(not player.take_damage(20,"test"), "Damage inside dash invulnerability must be rejected")
	player.invulnerability = 0.0
	_assert(player.take_damage(20,"test"), "Damage after dash window must apply")
	_assert(player.health == started_health - 20.0, "Damage must subtract exact hull")
	player.invulnerability = 0.0
	player.add_shield_hit()
	var health_before_shield := player.health
	_assert(not player.take_damage(50,"shield test"), "A shield hit must absorb damage")
	_assert(player.health == health_before_shield and player.shield_hits == 0, "Shield absorption must preserve hull and consume one shield")
	player._physics_process(0.5)
	_assert(player.dash_charges == 0, "Dash must not recharge before its configured cooldown")
	player._physics_process(0.5)
	_assert(player.dash_charges == 1 and is_equal_approx(player.dash_ratio(),1.0), "Dash must recover exactly one charge after its cooldown")
	player.queue_free()
	await get_tree().process_frame

func _test_pause_resume_control_policy() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	var run := RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"diver","seed":58117,"mode":"story","competitive":true})
	add_child(run)
	await get_tree().process_frame

	run.state = RunSceneClass.RunState.EXTERIOR
	run._player.set_controls_active(true)
	run._toggle_pause()
	_assert(run._paused and not run._player.controls_active, "Pausing active exterior combat must lock player controls")
	run._on_result_action("resume")
	_assert(not run._paused and run._player.controls_active, "Resuming active exterior combat must restore player controls")
	await get_tree().process_frame

	SaveManager.profile["suspend_regression_marker"] = "mobile-pause-58117"
	run._meta_dirty = false
	run._notification(NOTIFICATION_APPLICATION_PAUSED)
	_assert(run._paused and not run._player.controls_active, "Application-paused notification must synchronously pause combat and lock controls")
	var suspended_save := SaveManager._read_envelope(SaveManager.SAVE_PATH)
	_assert(String(suspended_save.get("suspend_regression_marker", "")) == "mobile-pause-58117", "Application-paused notification must persist the current profile even without pending meta progress")
	run._notification(NOTIFICATION_APPLICATION_RESUMED)
	_assert(run._paused and not run._player.controls_active, "Application-resumed notification must not implicitly unpause active combat")
	run._on_result_action("resume")
	_assert(not run._paused and run._player.controls_active, "Manual resume after application suspension must restore active combat controls")

	run.state = RunSceneClass.RunState.BREACH_OPEN
	run._hud.set_dive_ready(true)
	run._toggle_pause()
	_assert(run._paused and run._hud.overlay.visible and not run._player.controls_active, "Pausing an open breach must show the pause overlay and lock combat controls")
	var paused_overlay_root := run._hud.overlay.get_child(0)
	run._request_dive()
	_assert(run.state == RunSceneClass.RunState.BREACH_OPEN and run._paused and run._hud.overlay.get_child(0) == paused_overlay_root, "A dive request while paused must preserve both the breach state and pause overlay")
	run._on_result_action("resume")
	_assert(not run._paused and run._player.controls_active and not run._hud.overlay.visible, "Manual resume from a paused breach must restore the live breach without a stale overlay")
	run._request_dive()
	_assert(run.state == RunSceneClass.RunState.ORGAN_SELECT and not run._player.controls_active and run._hud.overlay.visible, "A dive request after manual resume must still open the legal organ choice")

	var locked_states := {
		RunSceneClass.RunState.DIVING_IN: "DIVING_IN",
		RunSceneClass.RunState.DIVING_OUT: "DIVING_OUT",
		RunSceneClass.RunState.MUTATION_CHOICE: "MUTATION_CHOICE",
	}
	for locked_state_value in locked_states:
		var locked_state: RunSceneClass.RunState = locked_state_value
		var state_name := String(locked_states[locked_state_value])
		run.state = locked_state
		run._paused = false
		run._player.set_controls_active(false)
		run._player.dash_charges = run._player.max_dash_charges
		run._player.dash_time = 0.0
		run._player.invulnerability = 0.0
		if locked_state == RunSceneClass.RunState.MUTATION_CHOICE:
			run._toggle_pause()
			_assert(not run._paused and not run._player.controls_active, "Mutation choice must reject pause toggles without unlocking controls")
			run._paused = true
			run._hud.show_pause()
		else:
			run._toggle_pause()
			_assert(run._paused and not run._player.controls_active, "%s pause must keep transition controls locked" % state_name)
		var charges_before := run._player.dash_charges
		var dash_count_before := run._dash_count
		run._on_result_action("resume")
		_assert(not run._paused and not run._player.controls_active, "%s resume must preserve the state's control lock" % state_name)
		run._request_dash()
		run._request_directional_dash(Vector2.RIGHT)
		_assert(run._player.dash_charges == charges_before and is_zero_approx(run._player.dash_time), "%s resume must not allow a dash to start" % state_name)
		_assert(is_zero_approx(run._player.invulnerability) and run._dash_count == dash_count_before, "%s resume must not manufacture dash invulnerability" % state_name)
		await get_tree().process_frame

	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	SaveManager.save_profile()

func _test_telegraph_avoidance_and_combat_sfx() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run := RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"diver","seed":72731,"mode":"story","competitive":true})
	add_child(run)
	await get_tree().process_frame
	run.state = RunSceneClass.RunState.EXTERIOR
	run._dash_count = 0
	run.attack_timer = 0.0
	run._telegraph.clear()
	run._update_boss_attacks(0.016)
	_assert(not run._telegraph.is_empty(), "A live exterior attack must begin with a telegraph")
	_assert(int(run._telegraph.get("dash_count_at_start", -1)) == 0, "The telegraph must snapshot dash use before its attack wave")
	run._telegraph.timer = 0.0
	run._update_boss_attacks(0.016)
	_assert(run._attack_avoidance_candidates.size() == 1, "A spawned telegraphed wave must arm one avoidance candidate")
	var wave_id := String(run._attack_avoidance_candidates.keys()[0])
	_assert(run._projectiles.enemy_group_size(wave_id) > 0, "Avoidance cannot resolve before a real hostile wave exists")
	run._open_breach()
	_assert(run._attack_avoidance_candidates.is_empty(), "Forced breach cleanup must cancel pending avoidance instead of granting it")
	_assert(not run._tutorial_flow.has_understood(&"defend"), "Clearing a telegraphed wave through a phase transition must not satisfy defense")

	run.state = RunSceneClass.RunState.EXTERIOR
	run._spawn_attack("basic_rupture", 0.0, run._dash_count)
	wave_id = String(run._attack_avoidance_candidates.keys()[0])
	run._dash_count += 1
	for bullet in run._projectiles.enemy_active:
		if String(bullet.get("group", "")) == wave_id:
			bullet.position = Vector2(-200.0,-200.0)
	var outcome: Dictionary = run._projectiles.step(0.016,[],run._player.position,12.0)
	run._update_attack_avoidance(outcome.player_hits)
	_assert(not run._tutorial_flow.has_understood(&"defend"), "Using Dash after the warning begins must not masquerade as a no-Dash avoidance")

	run._spawn_attack("basic_rupture", 0.0, run._dash_count)
	wave_id = String(run._attack_avoidance_candidates.keys()[0])
	run._projectiles.clear_enemy_group(wave_id)
	run._update_attack_avoidance([{"group":wave_id,"damage":9.0,"cause":"ability:basic_rupture"}])
	_assert(not run._tutorial_flow.has_understood(&"defend"), "Contact with the wave must prevent a false avoidance observation")

	run._spawn_attack("basic_rupture", 0.0, run._dash_count)
	wave_id = String(run._attack_avoidance_candidates.keys()[0])
	run._update_attack_avoidance([])
	_assert(run._attack_avoidance_candidates.has(wave_id), "Avoidance must remain pending while any projectile from the wave is active")
	for bullet in run._projectiles.enemy_active:
		if String(bullet.get("group", "")) == wave_id:
			bullet.position = Vector2(-200.0,-200.0)
	outcome = run._projectiles.step(0.016,[],run._player.position,12.0)
	run._update_attack_avoidance(outcome.player_hits)
	_assert(run._tutorial_flow.has_understood(&"defend"), "A fully expired wave with no contact and no Dash must emit the live telegraph-avoided event")
	_assert(run._attack_avoidance_candidates.is_empty(), "A resolved avoidance candidate must be consumed exactly once")

	var limiter: Dictionary = {}
	_assert(RunSceneClass.should_emit_rate_limited_sfx(limiter,"armor_hit",1.0,0.075), "A combat SFX limiter must allow its first event")
	_assert(not RunSceneClass.should_emit_rate_limited_sfx(limiter,"armor_hit",1.074,0.075), "A combat SFX limiter must suppress same-burst spam")
	_assert(RunSceneClass.should_emit_rate_limited_sfx(limiter,"armor_hit",1.075,0.075), "A combat SFX limiter must reopen exactly at its cooldown boundary")

	run._combat_sfx_last_played.clear()
	run.elapsed = 10.0
	run.state = RunSceneClass.RunState.EXTERIOR
	run.armor_max = 1000.0
	run.armor_health = 1000.0
	run._damage_target({"id":"boss","damage":1.0,"behavior":"pulse"})
	_assert(is_equal_approx(float(run._combat_sfx_last_played.get("armor_hit",-1.0)),10.0), "Exterior armor damage must call the armor-hit SFX path")
	run.elapsed = 10.02
	run._damage_target({"id":"boss","damage":1.0,"behavior":"pulse"})
	_assert(is_equal_approx(float(run._combat_sfx_last_played.armor_hit),10.0), "Rapid armor hits must remain rate-limited")
	run.elapsed = 10.08
	run._damage_target({"id":"boss","damage":1.0,"behavior":"pulse"})
	_assert(is_equal_approx(float(run._combat_sfx_last_played.armor_hit),10.08), "Armor-hit SFX must recover after its short limiter window")

	run.elapsed = 20.0
	run.state = RunSceneClass.RunState.ORGAN_CHAMBER
	run.organ_max = 1000.0
	run.organ_health = 1000.0
	run._damage_target({"id":"organ","damage":1.0,"behavior":"pulse"})
	_assert(is_equal_approx(float(run._combat_sfx_last_played.get("organ_damage",-1.0)),20.0), "Live organ damage must call the organ-damage SFX path")
	run.elapsed = 20.01
	run._damage_target({"id":"organ","damage":1.0,"behavior":"pulse"})
	_assert(is_equal_approx(float(run._combat_sfx_last_played.organ_damage),20.0), "Rapid organ hits must remain rate-limited")

	run._combat_sfx_last_played.erase("boss_phase")
	run.elapsed = 30.0
	run._start_phase(0)
	_assert(not run._combat_sfx_last_played.has("boss_phase"), "Initial spawn must not falsely announce a boss phase transition")
	run._start_phase(1)
	_assert(is_equal_approx(float(run._combat_sfx_last_played.get("boss_phase",-1.0)),30.0), "Returning to a later exterior phase must call the boss-phase SFX path")
	run.elapsed = 31.0
	run.state = RunSceneClass.RunState.DIVING_OUT
	run.phase = 2
	run.current_organ = {"ability":"bone_missiles"}
	run._return_outside()
	_assert(run.state == RunSceneClass.RunState.CORE and is_equal_approx(float(run._combat_sfx_last_played.boss_phase),31.0), "Entering the final core phase must announce the boss transition once")

	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	SaveManager.save_profile()

func _test_mutation_weapon_runtime() -> void:
	var original_profile:=SaveManager.profile.duplicate(true)
	var carried: Array[String] = []
	for raw_mutation in GameData.mutations:
		carried.append(String((raw_mutation as Dictionary).id))
	var run:=RunSceneClass.new()
	run.initialize({
		"boss":"gravemaw",
		"weapon":"arc_swarm",
		"difficulty":"diver",
		"seed":88117,
		"mode":"abyss",
		"competitive":true,
		"carried_mutations":carried
	})
	add_child(run)
	await get_tree().process_frame
	_assert(is_equal_approx(run._player.max_health,(100.0+22.0)*0.72), "Carried Second Skin and Glass Engine must derive hull once from the run base")
	_assert(is_equal_approx(run._player.dash_cooldown,2.15*0.76*1.12), "Carried dash mutations must alter the live dash cooldown")
	_assert(run._player.max_dash_charges==2 and run._player.dash_charges==2, "Ghost Charge must add one usable live dash charge")
	var synced_max:=run._player.max_health
	run._sync_player_mutation_stats({})
	_assert(is_equal_approx(run._player.max_health,synced_max), "Later mutation synchronization must not reapply structural hull effects")
	run._player.health=40.0
	run._sync_player_mutation_stats({"heal_now":22.0})
	_assert(is_equal_approx(run._player.health,62.0), "Second Skin's immediate repair must apply only from the newly selected effect")
	run._player.health=50.0
	run.calm_timer=0.0
	run._update_calm_heal(6.0)
	_assert(is_equal_approx(run._player.health,53.0), "Calm Between Beats must repair hull after six damage-free combat seconds")
	run._player.shield_hits=0
	run._bio_since_shield=0
	run._grant_bio(18,true)
	_assert(run._player.shield_hits==1 and run._bio_since_shield==0, "Symbiotic Guard must convert collected Bio-Matter into a shield at its threshold")
	_assert(is_equal_approx(run._bio_magnet_radius(),144.0), "Cellular Magnet must double the live Bio-Matter attraction radius")
	run._player.health=40.0
	run._enemies.clear()
	for kill_index in 5:
		run._enemies.append({"id":"leech_%d"%kill_index,"position":Vector2(270,500),"health":0.0,"radius":14.0})
		run._kill_enemy(0)
	_assert(is_equal_approx(run._player.health,44.0), "Parasite Leech must repair four hull on every fifth internal kill")
	run._player.dash_time=0.0
	run._player.dash_charges=run._player.max_dash_charges
	_assert(run._player.request_dash(Vector2.UP), "Phase Wake runtime setup must begin a dash")
	_assert(not run._dash_wakes.is_empty(), "Phase Wake must emit a damaging trail sample when a dash starts")

	run.projectiles_clear_and_enemies()
	run.state=RunSceneClass.RunState.EXTERIOR
	run._mutation_engine.initialize(88117,{"damage_mul":1.0,"projectile_count_add":0,"pierce_add":0,"projectile_speed_mul":1.0})
	var expected_projectiles:={"pulse_needle":1,"scatter_maw":5,"rail_spine":1,"arc_swarm":1,"void_orbitals":1}
	for weapon_id in expected_projectiles:
		run._projectiles.clear_all()
		run.weapon_definition=GameData.get_weapon(String(weapon_id))
		run._fire_weapon()
		_assert(run._projectiles.player_active.size()==int(expected_projectiles[weapon_id]), "%s must emit its distinct configured volley" % weapon_id)
		_assert(String(run._projectiles.player_active[0].behavior)==String(run.weapon_definition.behavior), "%s projectile must preserve its runtime behavior" % weapon_id)
	_assert(int(GameData.get_weapon("rail_spine").pierce)==4, "Rail Spine must retain its high-pierce identity")

	run.weapon_definition=GameData.get_weapon("arc_swarm")
	run._enemies=[
		{"id":"arc_1","position":Vector2(100,100),"health":100.0,"radius":14.0},
		{"id":"arc_2","position":Vector2(180,100),"health":100.0,"radius":14.0},
		{"id":"arc_3","position":Vector2(260,100),"health":100.0,"radius":14.0},
		{"id":"arc_4","position":Vector2(340,100),"health":100.0,"radius":14.0}
	]
	run._arc_chain("source",Vector2(80,100),100.0)
	_assert(is_equal_approx(float(run._enemies[0].health),62.0) and is_equal_approx(float(run._enemies[1].health),62.0) and is_equal_approx(float(run._enemies[2].health),62.0), "Arc Swarm must hit its three nearest unique chain targets")
	_assert(is_equal_approx(float(run._enemies[3].health),100.0), "Arc Swarm must stop at its configured chain count")

	run._enemies.clear()
	run.weapon_definition=GameData.get_weapon("void_orbitals")
	run._projectiles.clear_all()
	run.elapsed=0.0
	var orbital_center:=run._player.position+Vector2.RIGHT*float(run.weapon_definition.orbital_radius)
	run._projectiles.spawn_enemy(orbital_center,Vector2.ZERO,9.0,{})
	run._update_orbitals(0.016,false)
	_assert(run._projectiles.enemy_active.is_empty(), "Void Orbitals must consume a hostile projectile within an orbital hit radius")

	run._mutation_engine.initialize(88117,{"damage_mul":1.0,"projectile_count_add":0,"pierce_add":0,"projectile_speed_mul":1.0})
	for mutation_id in ["hungry_orbit","echo_shot","serrated_signal","rupture_tax","wound_memory","emergency_sheath"]:
		run._mutation_engine.apply(GameData.get_mutation(mutation_id))
	run.weapon_definition=GameData.get_weapon("arc_swarm")
	run._projectiles.clear_all()
	run._orbit_growth=0.0
	run.elapsed=0.0
	orbital_center=run._player.position+Vector2.RIGHT*48.0
	run._projectiles.spawn_enemy(orbital_center,Vector2.ZERO,9.0,{})
	run._update_orbitals(0.016,false)
	_assert(run._orbit_growth>0.0 and run._orbit_growth<=float(run._mutation_engine.flags.orbit_growth_cap), "Hungry Orbit must grow after absorbing a hostile projectile without exceeding its cap")
	run.shot_count=4
	run._pending_echoes.clear()
	run._fire_weapon(false)
	_assert(run.shot_count==5 and run._pending_echoes.size()==1, "Echo Shot must schedule exactly on the fifth primary volley")
	run._fire_weapon(true)
	_assert(run.shot_count==5, "Echoed volleys must not advance their own cadence counter")
	run.state=RunSceneClass.RunState.ORGAN_CHAMBER
	run.organ_max=1000.0
	run.organ_health=1000.0
	run._organ_hit_count=0
	for hit_index in 7:
		run._damage_target({"id":"organ","damage":1.0,"behavior":"pulse"})
	_assert(is_equal_approx(run.organ_health,903.0), "Serrated Signal must add 90 tissue damage on the seventh actual organ hit")
	run.state=RunSceneClass.RunState.EXTERIOR
	run.phase=0
	run.run_bio=0
	run._open_breach()
	_assert(run.run_bio==91, "Rupture Tax must increase a 70 Bio-Matter breach reward by 30 percent")
	run.state=RunSceneClass.RunState.DIVING_OUT
	run.phase=0
	run.current_organ={"ability":"homing_eye"}
	run._player.shield_hits=0
	run._return_outside()
	_assert(run._player.shield_hits==1, "Emergency Sheath must grant one shield after leaving an organ")
	_assert(is_equal_approx(run.wound_memory_timer,4.0), "Wound Memory must start its four-second window on return to the exterior")

	run._mutation_engine.initialize(88117,{"damage_mul":1.0,"projectile_count_add":0,"pierce_add":0,"projectile_speed_mul":1.0})
	run._selected_mutations.clear()
	for raw_mutation in GameData.mutations:
		var mutation := raw_mutation as Dictionary
		_assert(run._mutation_engine.apply(mutation), "Mutation exhaustion setup must select %s exactly once" % String(mutation.id))
		run._selected_mutations.append(String(mutation.id))
	_assert(run._mutation_engine.selected_ids.size()==GameData.mutations.size(), "Mutation exhaustion setup must consume the complete launch catalog")
	run.state=RunSceneClass.RunState.MUTATION_CHOICE
	run.phase=2
	run._remaining_rerolls=1
	run._player.set_controls_active(false)
	var exhaustion_bio_before:=run.run_bio
	run._offer_mutations(false)
	_assert(run._offered_mutation_ids.is_empty(), "An exhausted mutation catalog must not fabricate a duplicate offer")
	_assert(run.state==RunSceneClass.RunState.DIVING_OUT, "An exhausted mutation catalog must continue instead of soft-locking MUTATION_CHOICE")
	_assert(run.run_bio==exhaustion_bio_before+RunSceneClass.MUTATION_CATALOG_COMPLETE_BIO_REWARD, "Catalog exhaustion must grant the deterministic continuation reward exactly once")
	var exhaustion_message:=LocalizationService.text("mutation_catalog_complete", {"bio":RunSceneClass.MUTATION_CATALOG_COMPLETE_BIO_REWARD})
	_assert(run._remaining_rerolls==0 and not run._hud.overlay.visible and run._hud.toast_label.text==exhaustion_message, "Catalog exhaustion must close the empty choice UI, explain the reward, and retire unusable rerolls")
	var exhaustion_bio_after:=run.run_bio
	run._offer_mutations(false)
	_assert(run.run_bio==exhaustion_bio_after and run.state==RunSceneClass.RunState.DIVING_OUT, "Repeated empty-offer resolution outside MUTATION_CHOICE must not duplicate the reward")
	run.transition_timer=0.0
	run.hit_stop_timer=0.0
	run._physics_process(0.016)
	_assert(run.state==RunSceneClass.RunState.CORE and run._player.controls_active, "Catalog exhaustion continuation must reach the next playable combat state")

	run._mutation_engine.initialize(88119,{"damage_mul":1.0,"projectile_count_add":0,"pierce_add":0,"projectile_speed_mul":1.0})
	run._selected_mutations.clear()
	for mutation_index in GameData.mutations.size()-2:
		var near_exhaustion_mutation := GameData.mutations[mutation_index] as Dictionary
		_assert(run._mutation_engine.apply(near_exhaustion_mutation), "Near-exhaustion setup must select %s exactly once" % String(near_exhaustion_mutation.id))
		run._selected_mutations.append(String(near_exhaustion_mutation.id))
	run.state=RunSceneClass.RunState.MUTATION_CHOICE
	run.phase=1
	run._remaining_rerolls=1
	run._player.set_controls_active(false)
	run._offer_mutations(false)
	var near_exhaustion_offer := run._offered_mutation_ids.duplicate()
	_assert(near_exhaustion_offer.size()==2, "Near-exhaustion setup must expose the two legal remaining mutations")
	var near_exhaustion_bio_before:=run.run_bio
	run._reroll_mutations()
	_assert(run.state==RunSceneClass.RunState.MUTATION_CHOICE and run._offered_mutation_ids.size()==2, "Near-exhaustion reroll fallback must keep a selectable mutation choice open")
	var sorted_near_exhaustion_offer:=near_exhaustion_offer.duplicate()
	var sorted_fallback_offer:=run._offered_mutation_ids.duplicate()
	sorted_near_exhaustion_offer.sort()
	sorted_fallback_offer.sort()
	_assert(sorted_fallback_offer==sorted_near_exhaustion_offer, "Near-exhaustion reroll fallback must reuse only the prior legal pool when exclusions empty the catalog")
	_assert(run.run_bio==near_exhaustion_bio_before, "Near-exhaustion reroll fallback must not grant the catalog-exhaustion reward")
	_assert(run._remaining_rerolls==0, "Near-exhaustion reroll must consume its one charge exactly once")
	var fallback_offer_after_first_reroll:=run._offered_mutation_ids.duplicate()
	run._reroll_mutations()
	_assert(run._remaining_rerolls==0 and run._offered_mutation_ids==fallback_offer_after_first_reroll, "A reroll request with no charges must not consume again or replace the fallback offer")

	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile=original_profile
	SaveManager.save_profile()

func _test_save_recovery() -> void:
	var original := SaveManager.profile.duplicate(true)
	for path in [SaveManager.SAVE_PATH,SaveManager.BACKUP_PATH,SaveManager.TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile.bio_matter = 123
	_assert(SaveManager.save_profile(), "Primary save must write")
	SaveManager.profile.bio_matter = 456
	_assert(SaveManager.save_profile(), "Second save must rotate backup")
	var backup_before_corruption: Dictionary = SaveManager._read_envelope(SaveManager.BACKUP_PATH)
	_assert(not backup_before_corruption.is_empty(), "Rotated backup must pass checksum validation")
	if not backup_before_corruption.is_empty():
		_assert(int(backup_before_corruption.bio_matter) == 123, "Rotated backup must contain the prior generation")
	var corrupt := FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	corrupt.store_string("{corrupt")
	corrupt = null
	var recovered: Dictionary = SaveManager.load_profile()
	_assert(int(recovered.bio_matter) == 123 and SaveManager.last_load_source == "backup", "Corruption must recover the prior backup")
	SaveManager.profile = original
	SaveManager.save_profile()
	await get_tree().process_frame

func _test_meta_save_handoff() -> void:
	var original := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run := RunSceneClass.new()
	_assert(run._meta_goals.initialize(SaveManager.profile,{"year":2026,"month":9,"day":1}), "RunScene meta goals must initialize against the save profile")
	run._meta_dirty = run._meta_goals.has_pending_profile_changes()
	_assert(run._meta_dirty, "Meta schema normalization and contract activation must request persistence")
	_assert(run._persist_meta_profile(), "RunScene must persist pending meta normalization atomically")
	_assert(not run._meta_dirty and not run._meta_goals.has_pending_profile_changes(), "Only a successful save may acknowledge pending meta changes")
	var first: Dictionary = run._meta_progress("dash_used", {"event_id":"qa-meta-dash-0001"}, false)
	_assert(bool(first.get("changed",false)) and run._meta_dirty, "A goal-changing event must dirty the shared profile")
	var duplicate: Dictionary = run._meta_progress("dash_used", {"event_id":"qa-meta-dash-0001"}, false)
	_assert(bool(duplicate.get("duplicate",false)) and bool(duplicate.get("needs_persist",false)) and run._meta_dirty, "A duplicate must preserve an earlier unsaved dirty latch")
	_assert(run._persist_meta_profile(), "RunScene must persist the meta receipt before acknowledging it")
	var reloaded := SaveManager.load_profile()
	_assert(int((reloaded.get("meta_goal_state",{}) as Dictionary).get("schema_version",0)) == 2, "Persisted meta profile must survive reload at the current schema")
	run.free()
	SaveManager.profile = original
	SaveManager.save_profile()
	await get_tree().process_frame

func _test_save_migration_and_banking() -> void:
	var legacy := {
		"_schema": 1,
		"bank": 87,
		"total_wins": 1,
		"settings": {"language":"he"}
	}
	var migrated: Dictionary = SaveManager._migrate_and_merge(legacy)
	_assert(int(migrated.bio_matter) == 87 and not migrated.has("bank"), "Schema 1 bank currency must migrate to Bio-Matter")
	_assert(bool(migrated.abyss_unlocked), "Legacy victory data must migrate to an unlocked Abyss Loop")
	_assert(String(migrated.settings.language) == "he" and migrated.settings.has("dash_method"), "Nested save defaults must merge without replacing an existing language")
	_assert(migrated.has("processed_run_ids") and migrated.has("contracts"), "Save migration must add current transaction and contract fields")
	_assert(migrated.has("tutorial_presentation"), "Save migration must add resumable tutorial presentation state")
	var legacy_tutorial_complete := SaveManager._migrate_and_merge({
		"_schema": 4,
		"tutorial_complete": true
	})
	_assert(int(legacy_tutorial_complete.tutorial_state.understood_mask) == TutorialFlowClass.FULL_MASK, "A legacy tutorial_complete flag must migrate to all ten understood-step bits")
	var migrated_tutorial := TutorialFlowClass.new()
	migrated_tutorial.restore_state(legacy_tutorial_complete.tutorial_state)
	_assert(migrated_tutorial.is_complete() and migrated_tutorial.understood_count() == TutorialFlowClass.STEP_COUNT, "Migrated legacy tutorial completion must remain semantically complete")
	var malformed_shape := SaveManager._migrate_and_merge({
		"_schema": SaveManager.SAVE_SCHEMA,
		"upgrades": [],
		"settings": "broken",
		"bio_matter": "NaN",
		"future_field": {"keep": true}
	})
	_assert(typeof(malformed_shape.upgrades) == TYPE_DICTIONARY and malformed_shape.upgrades.is_empty(), "Malformed upgrade storage must recover to a typed-safe dictionary")
	_assert(typeof(malformed_shape.settings) == TYPE_DICTIONARY and malformed_shape.settings.has("language"), "Malformed settings storage must recover to the complete default shape")
	_assert(int(malformed_shape.bio_matter) == 0, "Malformed scalar save fields must recover to their safe default")
	_assert(bool(malformed_shape.future_field.keep), "Unknown future save fields must survive shape recovery")

	var original := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	var run_result := {
		"run_id": "qa-bank-once-99213",
		"banked_bio": 140,
		"banked_shards": 1,
		"won": true,
		"boss_id": "gravemaw"
	}
	_assert(SaveManager.bank_run(run_result), "A valid run result must bank once")
	var banked_snapshot := SaveManager.profile.duplicate(true)
	_assert(not SaveManager.bank_run(run_result), "A duplicate run id must be rejected")
	_assert(
		int(SaveManager.profile.bio_matter) == int(banked_snapshot.bio_matter)
		and int(SaveManager.profile.core_shards) == int(banked_snapshot.core_shards)
		and int(SaveManager.profile.total_runs) == int(banked_snapshot.total_runs),
		"Rejected duplicate banking must not change currencies or run totals"
	)
	_assert(int(SaveManager.profile.boss_clears.gravemaw) == 1, "A winning run must record one boss clear")
	_assert(SaveManager.profile.unlocked_weapons.has("rail_spine"), "First GRAVEMAW clear must unlock Rail Spine")
	var original_run_id := String(run_result.run_id)
	for ledger_index in range(30):
		var ledger_result := run_result.duplicate(true)
		ledger_result.run_id = "qa-ledger-%02d" % ledger_index
		ledger_result.banked_bio = 0
		ledger_result.banked_shards = 0
		ledger_result.won = false
		_assert(SaveManager.bank_run(ledger_result), "A unique run must append to the durable banking ledger")
	_assert(SaveManager.profile.processed_run_ids.has(original_run_id), "The transaction ledger must not evict older run IDs")
	_assert(not SaveManager.bank_run(run_result), "An old run must remain non-bankable after many later runs")
	var reloaded := SaveManager.load_profile()
	_assert(int(reloaded.bio_matter) == 140 and reloaded.processed_run_ids.has("qa-bank-once-99213"), "Banked currency and transaction id must survive a save reload")
	SaveManager.profile.bio_matter = 999
	SaveManager.save_profile()
	_assert(SaveManager.reset_progress(), "Intentional progress reset must persist a blank profile")
	var corrupt_reset_primary := FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	corrupt_reset_primary.store_string("{corrupt-after-reset")
	corrupt_reset_primary = null
	var reset_recovered := SaveManager.load_profile()
	_assert(int(reset_recovered.bio_matter) == 0 and SaveManager.last_load_source == "backup", "Reset backup recovery must never resurrect pre-reset progress")
	SaveManager.profile = original
	SaveManager.save_profile()
	await get_tree().process_frame

func _test_failure_forge_retry_relaunch() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	var original_settings := SettingsManager.values.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	SettingsManager.values = SaveManager.profile.settings.duplicate(true)
	SettingsManager.apply_all()
	_assert(SaveManager.save_profile(), "Progression smoke must begin from a persisted fresh profile")

	var main := MainClass.new()
	add_child(main)
	await get_tree().process_frame
	_assert(main.current_view is NestViewClass, "Progression smoke must boot into the Last Nest UI")
	var nest := main.current_view as NestViewClass
	var begin_button := nest.find_child("BeginDive", true, false) as Button
	_assert(begin_button != null and not begin_button.disabled, "Last Nest must expose an enabled semantic Begin Dive button")

	# Seed the global RNG immediately before the real UI press so this smoke's
	# story configuration is reproducible while still exercising the button.
	seed(0x1F1D1E)
	begin_button.emit_signal("pressed")
	var first_run := main.current_view as RunSceneClass
	_assert(first_run != null, "Begin Dive UI action must enter a live run")
	first_run.run_id = "qa-progression-failure-1"
	first_run.transition_timer = 0.0
	first_run._physics_process(0.016)
	_assert(first_run.state == RunSceneClass.RunState.EXTERIOR, "Progression smoke run must reach exterior combat")
	first_run._damage_target({"id":"boss","damage":first_run.armor_max+1.0,"behavior":"pulse"})
	_assert(first_run.state == RunSceneClass.RunState.BREACH_OPEN and first_run.run_bio == 70, "Actual armor damage must open a breach and earn its Bio-Matter")
	_assert(first_run._player.take_damage(first_run._player.max_health+1.0,"bone_cannon"), "A visible boss attack must deliver lethal damage")
	_assert(first_run.state == RunSceneClass.RunState.DEAD and first_run._result_banked, "Failure must enter the result state and atomically bank its reward")
	_assert(int(first_run._result.get("banked_bio",0)) == 55 and int(SaveManager.profile.bio_matter) == 55, "The first failed run must retain enough Bio-Matter for Reinforced Hull")
	_assert(int(SaveManager.profile.total_runs) == 1 and SaveManager.profile.processed_run_ids.has(first_run.run_id), "Failure banking must persist one run receipt exactly once")
	_assert(first_run._hud.overlay.visible, "Failure must present the actual result UI")

	var nest_result_button := first_run._hud.find_child("ResultAction_nest", true, false) as Button
	_assert(nest_result_button != null, "Failure result UI must expose Return to Nest")
	nest_result_button.emit_signal("pressed")
	await get_tree().process_frame
	_assert(main.current_view is NestViewClass, "Return to Nest must replace the failed run with the Nest UI")
	nest = main.current_view as NestViewClass

	var forge_button := nest.find_child("Facility_forge", true, false) as Button
	_assert(forge_button != null and not forge_button.disabled, "A fresh Nest must expose the Forge facility")
	forge_button.emit_signal("pressed")
	var hull_button := nest.find_child("Upgrade_reinforced_hull", true, false) as Button
	_assert(hull_button != null and not hull_button.disabled, "First failure reward must enable the Reinforced Hull purchase")
	hull_button.emit_signal("pressed")
	await get_tree().process_frame
	_assert(int(SaveManager.profile.bio_matter) == 0 and int(SaveManager.profile.upgrades.get("reinforced_hull",0)) == 1, "Forge UI purchase must spend exactly 55 Bio-Matter and grant Hull level one")

	var close_forge := nest.find_child("OverlayClose", true, false) as Button
	_assert(close_forge != null, "Forge overlay must expose a semantic close action")
	close_forge.emit_signal("pressed")
	begin_button = nest.find_child("BeginDive", true, false) as Button
	seed(0x1F1D1F)
	begin_button.emit_signal("pressed")
	var second_run := main.current_view as RunSceneClass
	_assert(second_run != null and is_equal_approx(second_run._player.max_health,110.0), "A run launched after Forge must apply Reinforced Hull to live player health")
	second_run.run_id = "qa-progression-failure-2"
	second_run.transition_timer = 0.0
	second_run._physics_process(0.016)
	second_run._damage_target({"id":"boss","damage":second_run.armor_max+1.0,"behavior":"pulse"})
	second_run.elapsed = 18.0
	_assert(second_run._player.take_damage(second_run._player.max_health+1.0,"gravity_ring"), "The upgraded run must still be able to fail from attributable damage")
	_assert(second_run.state == RunSceneClass.RunState.DEAD and second_run._result_banked, "A post-Forge failure must bank once before retry")
	_assert(int(SaveManager.profile.total_runs) == 2 and SaveManager.profile.processed_run_ids.has(second_run.run_id), "Second failure must add one durable run receipt")

	var retry_config := second_run.config.duplicate(true)
	var retry_button := second_run._hud.find_child("ResultAction_retry", true, false) as Button
	_assert(retry_button != null, "Failure result UI must expose Dive Again")
	retry_button.emit_signal("pressed")
	var retry_run := main.current_view as RunSceneClass
	_assert(retry_run != null and retry_run.state == RunSceneClass.RunState.INTRO, "Dive Again must immediately construct a new run")
	_assert(int(retry_run.config.seed) == int(retry_config.seed) and String(retry_run.config.boss) == String(retry_config.boss), "Immediate retry must preserve deterministic boss and seed configuration")
	_assert(is_equal_approx(retry_run._player.max_health,110.0) and int(SaveManager.profile.total_runs) == 2, "Immediate retry must retain Forge power without duplicating run banking")

	var expected_bio := int(SaveManager.profile.bio_matter)
	var child_output: Array = []
	var child_args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--scene", "res://tests/progression/ProcessRelaunchProbe.tscn",
		"--",
		"--expected-bio=%d" % expected_bio,
		"--expected-runs=2",
		"--expected-upgrade=reinforced_hull:1",
		"--expected-run-ids=qa-progression-failure-1,qa-progression-failure-2"
	])
	var child_exit := OS.execute(OS.get_executable_path(),child_args,child_output,true,false)
	var child_log := "\n".join(PackedStringArray(child_output))
	_assert(child_exit == 0, "A separate Godot process must load the banked and purchased progression: %s" % child_log)
	_assert(child_log.contains("INFINIDIVE RELAUNCH PROBE: PASS"), "Relaunch process must emit explicit persistence evidence")

	# Clear only in-memory state, then reload the same primary envelope in this
	# process too. This catches a child probe that happened to inspect stale data.
	SaveManager.profile = SaveManager.default_profile()
	var reloaded := SaveManager.load_profile()
	_assert(int(reloaded.bio_matter) == expected_bio and int(reloaded.total_runs) == 2, "Parent process reload must match the child process persistence result")
	_assert(int(reloaded.upgrades.get("reinforced_hull",0)) == 1, "Forge ownership must survive process relaunch")

	main.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	SettingsManager.values = original_settings
	SettingsManager.apply_all()
	_assert(SaveManager.save_profile(), "Progression smoke must restore the pre-test profile")
	await get_tree().process_frame

func _test_reset_local_data_integration() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	var original_settings := SettingsManager.values.duplicate(true)
	var original_analytics_path := AnalyticsService.queue_path
	var original_analytics_queue := AnalyticsService.queue.duplicate(true)
	var original_analytics_status := AnalyticsService.last_storage_status
	var original_leaderboard_paths := [LeaderboardService.queue_path, LeaderboardService.backup_path, LeaderboardService.temporary_path]
	var original_leaderboard_entries := LeaderboardService.entries.duplicate(true)
	var original_leaderboard_status := LeaderboardService.last_storage_status
	var original_leaderboard_recovered := LeaderboardService.recovered_from_backup
	for path in [RESET_ANALYTICS_TEST_PATH, RESET_LEADERBOARD_TEST_PATH, RESET_LEADERBOARD_TEST_PATH + ".backup", RESET_LEADERBOARD_TEST_PATH + ".tmp"]:
		_remove_test_file(path)

	AnalyticsService.queue_path = RESET_ANALYTICS_TEST_PATH
	AnalyticsService.queue = [{"event":"run_complete","properties":{},"session_id":"reset-test","timestamp":"2026-09-01T00:00:00Z"}]
	_assert(AnalyticsService._persist_queue(), "Reset integration must stage an analytics queue")
	LeaderboardService.queue_path = RESET_LEADERBOARD_TEST_PATH
	LeaderboardService.backup_path = RESET_LEADERBOARD_TEST_PATH + ".backup"
	LeaderboardService.temporary_path = RESET_LEADERBOARD_TEST_PATH + ".tmp"
	LeaderboardService.entries = [{"generation":1}]
	_assert(LeaderboardService._persist_queue_atomic(), "Reset integration must stage a leaderboard primary")
	LeaderboardService.entries = [{"generation":2}]
	_assert(LeaderboardService._persist_queue_atomic(), "Reset integration must stage a leaderboard recovery backup")
	var staged_temp := FileAccess.open(LeaderboardService.temporary_path, FileAccess.WRITE)
	_assert(staged_temp != null, "Reset integration must stage a leaderboard temporary generation")
	if staged_temp != null:
		staged_temp.store_string("stale-temp")
		staged_temp.flush()
		staged_temp = null

	SaveManager.profile.bio_matter = 999
	_assert(SaveManager.save_profile(), "Reset integration must begin with persisted progress")
	var nest := NestViewClass.new()
	add_child(nest)
	await get_tree().process_frame
	nest._confirm_reset_progress()
	await get_tree().process_frame
	_assert(int(SaveManager.profile.bio_matter) == 0, "Nest Reset Progress must clear the saved gameplay profile")
	_assert(AnalyticsService.queue.is_empty() and not FileAccess.file_exists(RESET_ANALYTICS_TEST_PATH), "Nest Reset Progress must erase the analytics queue")
	_assert(LeaderboardService.entries.is_empty(), "Nest Reset Progress must clear leaderboard entries from memory")
	for path in [RESET_LEADERBOARD_TEST_PATH, RESET_LEADERBOARD_TEST_PATH + ".backup", RESET_LEADERBOARD_TEST_PATH + ".tmp"]:
		_assert(not FileAccess.file_exists(path), "Nest Reset Progress must erase leaderboard storage generation: %s" % path)
	_assert(String(AnalyticsService.last_storage_status) == "cleared" and String(LeaderboardService.last_storage_status) == "cleared", "Nest Reset Progress must complete both local queue deletion APIs")

	nest.queue_free()
	await get_tree().process_frame
	AnalyticsService.queue_path = original_analytics_path
	AnalyticsService.queue = original_analytics_queue
	AnalyticsService.last_storage_status = original_analytics_status
	LeaderboardService.queue_path = String(original_leaderboard_paths[0])
	LeaderboardService.backup_path = String(original_leaderboard_paths[1])
	LeaderboardService.temporary_path = String(original_leaderboard_paths[2])
	LeaderboardService.entries = original_leaderboard_entries
	LeaderboardService.last_storage_status = original_leaderboard_status
	LeaderboardService.recovered_from_backup = original_leaderboard_recovered
	SaveManager.profile = original_profile
	_assert(SaveManager.save_profile(), "Reset integration must restore the pre-test profile")
	_assert(SaveManager.save_profile(), "Reset integration must restore a matching recovery generation")
	SettingsManager.values = original_settings
	SettingsManager.apply_all()

func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_tutorial_scene_handoff() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile.tutorial_state = {"version":1,"understood_mask":TutorialFlowClass.FULL_MASK}
	SaveManager.profile.tutorial_complete = true
	SaveManager.profile.tutorial_step = 10
	SaveManager.profile.tutorial_replay_requested = true
	SaveManager.save_profile()

	var run := RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"diver","seed":44119,"mode":"story"})
	add_child(run)
	await get_tree().process_frame
	_assert(run._tutorial_flow.is_replaying(), "A requested tutorial replay must begin inside the next run")
	_assert(bool(SaveManager.profile.tutorial_presentation.replay_active), "Replay presentation must persist immediately after scene setup")
	_assert(not bool(SaveManager.profile.tutorial_replay_requested), "Replay request must be consumed exactly once")
	var first_prompt_text := run._hud._tutorial_message
	_assert(not first_prompt_text.is_empty() and run._hud.toast_label.modulate.a > 0.99, "Tutorial prompt must remain visibly pinned until its event is understood")
	run._hud.show_toast("TRANSIENT",VisualTheme.BIO)
	run._hud._restore_tutorial_prompt()
	_assert(run._hud.toast_label.text == first_prompt_text and run._hud.toast_label.modulate.a > 0.99, "Transient gameplay feedback must restore the active tutorial prompt")

	var replay_run_events := [
		TutorialFlowClass.EVENT_MOVEMENT_STARTED,
		TutorialFlowClass.EVENT_FIRST_SHOT,
		TutorialFlowClass.EVENT_FIRST_DASH,
		TutorialFlowClass.EVENT_EXPOSED_ARMOR_HIT,
		TutorialFlowClass.EVENT_FIRST_DIVE,
		TutorialFlowClass.EVENT_ORGAN_DESTROYED,
		TutorialFlowClass.EVENT_MUTATION_SELECTED,
		TutorialFlowClass.EVENT_BOSS_ABILITY_CHANGED,
		TutorialFlowClass.EVENT_BOSS_PHASE_REACHED
	]
	for event_id in replay_run_events:
		run._tutorial_observe(event_id)
	_assert(bool(SaveManager.profile.tutorial_presentation.replay_active) and int(SaveManager.profile.tutorial_presentation.replay_mask) == 0x1FF, "Nine replay actions must survive the Run-to-Nest scene boundary")
	run.queue_free()
	await get_tree().process_frame

	SaveManager.profile.bio_matter = 1000
	var nest := NestViewClass.new()
	add_child(nest)
	await get_tree().process_frame
	_assert(nest._stage_label.text == LocalizationService.text("tutorial.spend_first_resource"), "Nest must surface the final Forge tutorial action after a run")
	nest._buy_upgrade("reinforced_hull")
	_assert(not bool(SaveManager.profile.tutorial_presentation.replay_active), "A Forge purchase must complete a replay continued from RunScene")
	_assert(int(SaveManager.profile.tutorial_presentation.replay_mask) == 0, "Completed replay presentation must normalize its transient mask")
	_assert(bool(SaveManager.profile.tutorial_complete) and int(SaveManager.profile.tutorial_step) == 10, "Tutorial replay must preserve complete permanent understanding")
	nest.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	SaveManager.save_profile()

func _test_first_core_hook() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	var run := RunSceneClass.new()
	run.initialize({"boss":"gravemaw","weapon":"pulse_needle","difficulty":"diver","seed":99213,"mode":"story","competitive":true})
	add_child(run)
	for frame in 80:
		await get_tree().physics_frame
	_assert(run.state == RunScene.RunState.EXTERIOR, "Run must enter exterior combat")
	var touch := InputEventScreenTouch.new()
	touch.index = 77
	touch.position = Vector2(270.0, 700.0)
	touch.pressed = true
	Input.parse_input_event(touch)
	await get_tree().process_frame
	_assert(run._player._touch_id == 77, "Transparent HUD space must pass movement touches to the player")
	var release_touch := InputEventScreenTouch.new()
	release_touch.index = touch.index
	release_touch.position = touch.position
	release_touch.pressed = false
	Input.parse_input_event(release_touch)
	await get_tree().process_frame
	run._damage_target({"id":"boss","damage":run.armor_max+1.0,"behavior":"pulse"})
	_assert(run.state == RunScene.RunState.BREACH_OPEN, "Armor destruction must open breach")
	var breach_reward := run.run_bio
	run._open_breach()
	_assert(run.run_bio == breach_reward, "A breach cannot be opened or rewarded twice")
	run._request_dive()
	_assert(run.state == RunScene.RunState.ORGAN_SELECT, "Dive request must open organ order choice")
	_assert(not run._player.controls_active, "Organ selection must lock combat controls")
	var blocked_touch := InputEventScreenTouch.new()
	blocked_touch.index = 78
	blocked_touch.position = run._player.position + Vector2(90.0,82.0)
	blocked_touch.pressed = true
	run._player._unhandled_input(blocked_touch)
	_assert(run._player._touch_id == -1 and not run._player._dragging, "Disabled controls must reject hidden touch state")
	run._request_dive()
	_assert(run.state == RunScene.RunState.ORGAN_SELECT, "A second dive request must not start a duplicate transition")
	run._select_organ("__invalid_organ__")
	_assert(run.state == RunScene.RunState.ORGAN_SELECT, "An invalid organ selection must leave the run in the safe selection state")
	var organ_id: String = run._organ_map.alive_organs()[0]
	var ability: String = String(run._organ_map.organs[organ_id].ability)
	run._select_organ(organ_id)
	run.transition_timer = 0.0
	run.hit_stop_timer = 0.0
	run._physics_process(0.016)
	_assert(run.state == RunScene.RunState.INTERNAL_ROOMS and run._player.controls_active, "Internal combat must restore movement and dash controls")
	var internal_start := run._player.position
	var internal_touch := InputEventScreenTouch.new()
	internal_touch.index = 79
	internal_touch.position = internal_start + Vector2(90.0,82.0)
	internal_touch.pressed = true
	run._player._unhandled_input(internal_touch)
	run._player.invulnerability = 0.52
	run._player._physics_process(0.1)
	_assert(run._player.position.distance_to(internal_start) > 0.1, "A live internal touch must move the player")
	_assert(run._player.invulnerability < 0.52, "Internal combat must advance the damage invulnerability timer")
	internal_touch.pressed = false
	run._player._unhandled_input(internal_touch)
	while run.state == RunScene.RunState.INTERNAL_ROOMS:
		run._start_next_room()
	_assert(run.state == RunScene.RunState.ORGAN_CHAMBER, "Internal route must reach an organ chamber")
	_assert(run._player.controls_active, "Organ chamber combat must keep controls active")
	run._damage_target({"id":"organ","damage":run.organ_max+1.0,"behavior":"pulse"})
	_assert(run.state == RunScene.RunState.MUTATION_CHOICE, "Organ destruction must offer a mutation")
	_assert(not run._player.controls_active, "Mutation choice must lock combat controls")
	_assert(not run._organ_map.is_ability_enabled(ability), "Destroyed organ must disable the linked exterior ability")
	run._select_mutation("__invalid_mutation__")
	_assert(run.state == RunScene.RunState.MUTATION_CHOICE, "An invalid mutation selection must not skip the choice")
	var unoffered_id := ""
	for raw_mutation in GameData.mutations:
		var mutation_id := String((raw_mutation as Dictionary).id)
		if not run._offered_mutation_ids.has(mutation_id):
			unoffered_id = mutation_id
			break
	run._select_mutation(unoffered_id)
	_assert(run.state == RunScene.RunState.MUTATION_CHOICE, "A valid but unoffered mutation must be rejected")
	var offered_id := run._offered_mutation_ids[0]
	run._select_mutation(offered_id)
	run.transition_timer = 0.0
	run.hit_stop_timer = 0.0
	run._physics_process(0.016)
	_assert(run.state == RunScene.RunState.EXTERIOR, "Mutation choice must return to changed exterior battle")
	_assert(run._player.controls_active, "Returning outside must restore combat controls")
	_assert(run._organ_map.destroyed_organs().has(organ_id), "Destroyed organ state must survive the return")
	run.queue_free()
	await get_tree().process_frame
	SaveManager.profile = original_profile
	SaveManager.save_profile()

func _test_complete_boss_runs_and_orders() -> void:
	var original_profile := SaveManager.profile.duplicate(true)
	SaveManager.profile = SaveManager.default_profile()
	_assert(SaveManager.save_profile(), "Complete-run simulations must begin from a persisted clean profile")
	var simulated_runs := 0
	for boss_index in GameData.bosses.size():
		var boss: Dictionary = GameData.bosses[boss_index]
		var organ_ids: Array[String] = []
		for raw_organ in boss.organs:
			organ_ids.append(String((raw_organ as Dictionary).id))
		var orders := _permutations(organ_ids)
		_assert(orders.size() == 6, "%s must expose all six three-organ orders" % boss.id)
		for order_index in orders.size():
			var order: Array = orders[order_index]
			var seed := 41000 + boss_index * 1000 + order_index * 37
			await _simulate_complete_boss_run(boss,order,seed,order_index)
			simulated_runs += 1
	_assert(simulated_runs == 24, "Four bosses across all organ orders must produce 24 complete deterministic simulations")
	_assert(int(SaveManager.profile.total_runs) == 24 and int(SaveManager.profile.total_wins) == 24, "Every complete-run simulation must bank one victory exactly once")
	_assert(bool(SaveManager.profile.abyss_unlocked), "Completing NULL TWIN simulations must unlock Abyss Loop progression")
	_assert(int(SaveManager.profile.nest_stage) == 4, "Repeated complete victories must reach the final stored Nest stage")
	SaveManager.profile = original_profile
	SaveManager.save_profile()
	await get_tree().process_frame

func _simulate_complete_boss_run(boss: Dictionary, organ_order: Array, seed: int, order_index: int) -> void:
	var run := RunSceneClass.new()
	run.initialize({
		"boss": String(boss.id),
		"weapon": "pulse_needle",
		"difficulty": "diver",
		"seed": seed,
		"mode": "story",
		"competitive": true
	})
	add_child(run)
	run.run_id = "qa-full-%s-order-%d" % [String(boss.id),order_index]
	run.transition_timer = 0.0
	run._physics_process(0.016)
	_assert(run.state == RunScene.RunState.EXTERIOR, "%s order %d must begin in exterior combat" % [boss.id,order_index])

	for phase_index in 3:
		var organ_id := String(organ_order[phase_index])
		var linked_ability := String(run._organ_map.organs[organ_id].ability)
		_assert(run._organ_map.is_ability_enabled(linked_ability), "%s/%s ability must be enabled before its dive" % [boss.id,organ_id])
		run._damage_target({"id":"boss","damage":run.armor_max+1.0,"behavior":"pulse"})
		_assert(run.state == RunScene.RunState.BREACH_OPEN, "%s phase %d must open a breach" % [boss.id,phase_index+1])
		run._request_dive()
		_assert(run.state == RunScene.RunState.ORGAN_SELECT, "%s phase %d must request an organ choice" % [boss.id,phase_index+1])
		run._select_organ(organ_id)
		_assert(run.state == RunScene.RunState.DIVING_IN and String(run.current_organ.id) == organ_id, "%s phase %d must dive toward the requested organ" % [boss.id,phase_index+1])
		run.transition_timer = 0.0
		run.hit_stop_timer = 0.0
		run._physics_process(0.016)
		var room_guard := 0
		while run.state == RunScene.RunState.INTERNAL_ROOMS and room_guard < 12:
			run._start_next_room()
			room_guard += 1
		_assert(room_guard < 12 and run.state == RunScene.RunState.ORGAN_CHAMBER, "%s/%s route must reach its chamber without a soft-lock" % [boss.id,organ_id])
		_assert(String(run.current_room.get("organ",organ_id)) == organ_id, "%s dive must end in the selected organ chamber" % organ_id)
		run._damage_target({"id":"organ","damage":run.organ_max+1.0,"behavior":"pulse"})
		_assert(run.state == RunScene.RunState.MUTATION_CHOICE, "%s/%s destruction must offer a mutation" % [boss.id,organ_id])
		_assert(not run._organ_map.is_ability_enabled(linked_ability), "%s/%s destruction must disable %s" % [boss.id,organ_id,linked_ability])
		_assert(run._offered_mutation_ids.size() == 3, "%s phase %d must offer three unique mutations" % [boss.id,phase_index+1])
		var chosen_mutation := run._offered_mutation_ids[0]
		run._select_mutation(chosen_mutation)
		_assert(run._selected_mutations.has(chosen_mutation), "%s phase %d must apply a mutation from the actual offer" % [boss.id,phase_index+1])
		run.transition_timer = 0.0
		run.hit_stop_timer = 0.0
		run._physics_process(0.016)
		var expected_state := RunScene.RunState.CORE if phase_index == 2 else RunScene.RunState.EXTERIOR
		_assert(run.state == expected_state, "%s phase %d must return to the expected exterior state" % [boss.id,phase_index+1])
		_assert(run.phase == phase_index + 1, "%s phase counter must advance exactly once after organ %s" % [boss.id,organ_id])
		for destroyed_index in range(phase_index + 1):
			_assert(run._organ_map.destroyed_organs().has(String(organ_order[destroyed_index])), "%s must retain earlier destroyed organ state" % boss.id)

	_assert(run.state == RunScene.RunState.CORE and run._organ_map.alive_organs().is_empty(), "%s must expose its core only after all three organs" % boss.id)
	run._damage_target({"id":"boss","damage":run.core_max+1.0,"behavior":"pulse"})
	_assert(run.state == RunScene.RunState.VICTORY, "%s order %d must reach victory after core collapse" % [boss.id,order_index])
	_assert(bool(run._result.get("won",false)) and int(run._result.get("organs",0)) == 3, "%s victory result must record all three organs" % boss.id)
	_assert(String(run._result.get("boss_id","")) == String(boss.id) and int(run._result.get("seed",0)) == seed, "%s victory result must preserve deterministic challenge identity" % boss.id)
	_assert(int(run._result.get("banked_bio",0)) > 0 and int(run._result.get("banked_shards",0)) == int(boss.reward_shards), "%s story victory must grant configured permanent rewards" % boss.id)
	_assert(run._result_banked, "%s order %d result must bank successfully" % [boss.id,order_index])
	var banked_bio := int(SaveManager.profile.bio_matter)
	run._complete_run(true,"duplicate completion")
	_assert(int(SaveManager.profile.bio_matter) == banked_bio, "%s completion cannot bank rewards twice" % boss.id)
	run.queue_free()
	await get_tree().process_frame

func _write_junit() -> void:
	var directory := DirAccess.open("res://")
	if directory and not directory.dir_exists("artifacts"):
		directory.make_dir("artifacts")
	var file := FileAccess.open("res://artifacts/headless-tests.xml",FileAccess.WRITE)
	if file == null:
		return
	var duration := float(Time.get_ticks_msec()-started_ms)/1000.0
	file.store_line("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	file.store_line("<testsuite name=\"INFINIDIVE\" tests=\"%d\" failures=\"%d\" time=\"%.3f\">"%[passed+failures.size(),failures.size(),duration])
	for assertion_index in passed_assertions.size():
		file.store_line("<testcase name=\"assertion_%04d\" classname=\"INFINIDIVE\"><system-out>%s</system-out></testcase>" % [assertion_index + 1, passed_assertions[assertion_index].xml_escape()])
	for failure_index in failures.size():
		var failure := failures[failure_index]
		file.store_line("<testcase name=\"failure_%04d\" classname=\"INFINIDIVE\"><failure>%s</failure></testcase>" % [failure_index + 1, failure.xml_escape()])
	file.store_line("</testsuite>")
