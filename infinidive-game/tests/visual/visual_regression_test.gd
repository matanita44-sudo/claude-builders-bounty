extends Node

const BossVisualClass := preload("res://scripts/gameplay/boss_visual.gd")
const NestViewClass := preload("res://scripts/ui/nest_view.gd")
const PlayerControllerClass := preload("res://scripts/gameplay/player_controller.gd")
const ProjectilePoolClass := preload("res://scripts/gameplay/projectile_pool.gd")
const RunHUDClass := preload("res://scripts/ui/run_hud.gd")
const RunSceneClass := preload("res://scripts/gameplay/run_scene.gd")
const TitanCollapseCatalogClass := preload("res://scripts/gameplay/titan_collapse_catalog.gd")

const HIGH_CONTRAST_PROJECTILE := Color("#FF9B45")
const COMBAT_BACKGROUND_PATHS := [
	"res://assets/art/backgrounds/sky_battle.png",
	"res://assets/art/backgrounds/divine_interior.png",
]
const VISUAL_SCRIPT_PATHS := [
	"res://scripts/ui/visual_theme.gd",
	"res://scripts/ui/nest_view.gd",
	"res://scripts/ui/run_hud.gd",
	"res://scripts/gameplay/boss_visual.gd",
	"res://scripts/gameplay/titan_collapse_catalog.gd",
	"res://scripts/gameplay/player_controller.gd",
	"res://scripts/gameplay/projectile_pool.gd",
	"res://scripts/gameplay/run_scene.gd",
]
const VISUAL_SCENE_PATHS := [
	"res://scenes/main/Main.tscn",
]
const RASTER_ASSETS := [
	{"path":"res://assets/store/app-icon-1024.png", "size":Vector2i(1024,1024)},
	{"path":"res://assets/store/google-play-feature-1024x500.png", "size":Vector2i(1024,500)},
	{"path":"res://assets/store/social-card-1200x630.png", "size":Vector2i(1200,630)},
	{"path":"res://assets/platform/ios/launch_screen.png", "size":Vector2i(1170,2532)},
	{"path":"res://assets/platform/ios/launch_screen@2x.png", "size":Vector2i(780,1688)},
	{"path":"res://assets/store/gameplay/exterior-combat-1080x1920.png", "size":Vector2i(1080,1920)},
	{"path":"res://assets/store/gameplay/breach-open-1080x1920.png", "size":Vector2i(1080,1920)},
	{"path":"res://assets/store/gameplay/organ-choice-1080x1920.png", "size":Vector2i(1080,1920)},
	{"path":"res://assets/store/gameplay/internal-zone-1080x1920.png", "size":Vector2i(1080,1920)},
	{"path":"res://assets/store/gameplay/nest-1080x1920.png", "size":Vector2i(1080,1920)},
]
const VECTOR_ASSETS := [
	{"path":"res://assets/brand/app_icon.svg", "size":Vector2i(1024,1024)},
	{"path":"res://assets/brand/logo_mark.svg", "size":Vector2i(1024,1024)},
	{"path":"res://assets/brand/wordmark.svg", "size":Vector2i(1600,420)},
	{"path":"res://assets/brand/feature_graphic.svg", "size":Vector2i(1024,500)},
]
const FACILITY_STAGE := {
	"hangar":0,
	"forge":0,
	"research":1,
	"rift":1,
	"trophies":2,
	"core":3,
}
const EXPECTED_TARGET_RADII := {
	"gravemaw":96.0,
	"seraph_9":96.0,
	"abyss_leviathan":88.0,
	"null_twin":82.0,
}
const TARGET_PORTRAIT_PIXEL_SIZES := [
	Vector2(540.0,960.0),
	Vector2(1080.0,1920.0),
	Vector2(1260.0,2736.0),
	Vector2(1290.0,2796.0),
	Vector2(1320.0,2868.0),
]
const DESIGN_SIZE := Vector2(540.0,960.0)

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("VISUAL REGRESSION TEST FAILURE: " + message)


func _run() -> void:
	await get_tree().process_frame
	var original_profile := SaveManager.profile.duplicate(true)
	var original_settings := SettingsManager.values.duplicate(true)
	_test_visual_resources_parse()
	_test_asset_contract()
	await _test_titan_hud_composition_contract()
	await _test_projectile_contrast_contract()
	await _test_reduced_motion_contract()
	_test_titan_organ_anchor_contract()
	await _test_boss_visual_states()
	_test_titan_collapse_contract()
	await _test_five_nest_states()
	SaveManager.profile = original_profile
	SettingsManager.values = original_settings
	SettingsManager.apply_all()
	AudioManager.shutdown_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	print("INFINIDIVE VISUAL REGRESSION TESTS: %d passed, %d failed" % [passed,failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _test_visual_resources_parse() -> void:
	for path_value in VISUAL_SCRIPT_PATHS:
		var path := String(path_value)
		_check(ResourceLoader.exists(path),"Visual script must remain addressable: %s" % path)
		var resource := ResourceLoader.load(path)
		_check(resource is Script,"Visual script must parse as Script: %s" % path)
		_check(resource is Script and (resource as Script).can_instantiate(),"Visual script must remain instantiable: %s" % path)
	for path_value in VISUAL_SCENE_PATHS:
		var path := String(path_value)
		_check(ResourceLoader.exists(path),"Visual entry scene must remain addressable: %s" % path)
		var resource := ResourceLoader.load(path)
		_check(resource is PackedScene,"Visual entry scene must parse as PackedScene: %s" % path)
		_check(resource is PackedScene and (resource as PackedScene).can_instantiate(),"Visual entry scene must remain instantiable: %s" % path)
	_check(GameData.validation_errors.is_empty(),"Visual gate requires a parse-valid game-data catalog: %s" % "; ".join(GameData.validation_errors))


func _test_asset_contract() -> void:
	for raw_contract in RASTER_ASSETS:
		var contract := raw_contract as Dictionary
		var path := String(contract.path)
		_check(FileAccess.file_exists(path),"Required raster asset must exist: %s" % path)
		_check(ResourceLoader.exists(path),"Required raster asset must be imported: %s" % path)
		var resource := ResourceLoader.load(path)
		_check(resource is Texture2D,"Required raster asset must load as Texture2D: %s" % path)
		if resource is Texture2D:
			var texture := resource as Texture2D
			_check(Vector2i(texture.get_width(),texture.get_height()) == Vector2i(contract.size),"Required raster asset must keep %s: %s" % [str(contract.size),path])
		else:
			_check(false,"Required raster dimensions could not be checked: %s" % path)
	for raw_contract in VECTOR_ASSETS:
		var contract := raw_contract as Dictionary
		var path := String(contract.path)
		_check(FileAccess.file_exists(path),"Required vector identity asset must exist: %s" % path)
		_check(ResourceLoader.exists(path),"Required vector identity asset must be imported: %s" % path)
		var resource := ResourceLoader.load(path)
		_check(resource is Texture2D,"Required vector identity asset must load as Texture2D: %s" % path)
		if resource is Texture2D:
			var texture := resource as Texture2D
			_check(Vector2i(texture.get_width(),texture.get_height()) == Vector2i(contract.size),"Required vector identity asset must keep %s: %s" % [str(contract.size),path])
		else:
			_check(false,"Required vector dimensions could not be checked: %s" % path)


func _test_titan_hud_composition_contract() -> void:
	var focus_rect := BossVisualClass.exterior_focus_bounds_at(RunSceneClass.EXTERIOR_BOSS_POSITION)
	var portrait_rect := BossVisualClass.exterior_portrait_bounds_at(RunSceneClass.EXTERIOR_BOSS_POSITION)
	var phase_rect := RunHUDClass.PHASE_CHIP_RECT
	var toast_rect := RunHUDClass.GUIDANCE_TOAST_RECT
	var player_envelope := Rect2(
		RunSceneClass.EXTERIOR_COMBAT_BOUNDS.position-Vector2(20.0,34.0),
		RunSceneClass.EXTERIOR_COMBAT_BOUNDS.size+Vector2(40.0,68.0)
	)
	var left_action_ring := Rect2(14.0,836.0,104.0,104.0)
	var right_action_ring := Rect2(422.0,836.0,104.0,104.0)
	_check(RunSceneClass.EXTERIOR_BOSS_POSITION.is_equal_approx(Vector2(270.0,230.0)),"Exterior Titan must retain the reviewed lower composition anchor")
	_check(focus_rect.position.y >= phase_rect.end.y+4.0,"Titan face and highest organ must keep a readable gap below the phase chip")
	_check(
		toast_rect.position.y >= portrait_rect.end.y+24.0
		and toast_rect.position.y >= player_envelope.end.y+4.0
		and not toast_rect.intersects(left_action_ring)
		and not toast_rect.intersects(right_action_ring),
		"Tutorial guidance must own the bottom-center HUD lane without covering the Titan, Diver, or action rings"
	)
	_check(not focus_rect.intersects(phase_rect) and not focus_rect.intersects(toast_rect),"Titan face/highest organ cannot be covered by persistent guidance HUD")
	for target_size in TARGET_PORTRAIT_PIXEL_SIZES:
		var screen_focus := _shared_design_rect_on_target(focus_rect,target_size)
		var screen_portrait := _shared_design_rect_on_target(portrait_rect,target_size)
		var screen_phase := _shared_design_rect_on_target(phase_rect,target_size)
		var screen_toast := _shared_design_rect_on_target(toast_rect,target_size)
		var context := "%dx%d" % [int(target_size.x),int(target_size.y)]
		_check(not screen_focus.intersects(screen_phase),"%s shared portrait fit must keep the Titan face/top organ clear of the phase chip" % context)
		_check(not screen_portrait.intersects(screen_toast),"%s shared portrait fit must keep tutorial guidance below the Titan portrait" % context)

	var hud := RunHUDClass.new()
	add_child(hud)
	await get_tree().process_frame
	var phase_panel := hud.root.get_node_or_null("CombatPhaseChip") as Control
	_check(phase_panel != null and Rect2(phase_panel.position,phase_panel.size) == phase_rect,"Runtime phase chip must consume the tested composition rectangle")
	hud.show_toast("FIRST LINE\nSECOND LINE")
	_check(hud.toast_panel.position.is_equal_approx(toast_rect.position) and is_equal_approx(hud.toast_panel.size.x,toast_rect.size.x) and hud.toast_panel.size.y <= toast_rect.size.y,"Runtime one/two-line guidance must remain inside the tested composition rectangle")
	if is_instance_valid(hud._toast_tween):
		hud._toast_tween.kill()
	hud.queue_free()
	await get_tree().process_frame


func _shared_design_rect_on_target(design_rect: Rect2, target_size: Vector2) -> Rect2:
	var scale_factor := minf(target_size.x/DESIGN_SIZE.x,target_size.y/DESIGN_SIZE.y)
	var origin := (target_size-DESIGN_SIZE*scale_factor)*0.5
	return Rect2(origin+design_rect.position*scale_factor,design_rect.size*scale_factor)


func _test_projectile_contrast_contract() -> void:
	var source_file := FileAccess.open("res://scripts/gameplay/projectile_pool.gd",FileAccess.READ)
	_check(source_file != null,"Projectile renderer source must be readable")
	var source := source_file.get_as_text() if source_file != null else ""
	_check(source.contains("SettingsManager.get_value(\"projectile_contrast\""),"Enemy projectile renderer must consume the projectile-contrast setting")
	_check(source.contains("Color(\"#FF9B45\")"),"Enemy projectile renderer must retain the authored high-contrast hue")
	_check(ProjectilePoolClass.MYTHIC_INK.is_equal_approx(Color("#17324B")),"Every projectile family must share the mythic-ink readability edge")
	_check(ProjectilePoolClass.INK_EDGE_WIDTH_PX >= 2.0 and ProjectilePoolClass.INK_EDGE_WIDTH_PX <= 3.0,"Projectile readability edge must stay within 2-3 logical pixels")
	_check(is_equal_approx(ProjectilePoolClass.ink_stroke_width(4.0),9.0),"A projectile under-stroke must add the ink edge on both sides of its bright core")
	for helper_name in ["_draw_ink_line","_draw_ink_arc","_draw_ink_polygon","_draw_ink_circle"]:
		_check(source.contains(String(helper_name)),"Projectile renderer must retain its shared %s primitive" % helper_name)
	var run_source_file := FileAccess.open("res://scripts/gameplay/run_scene.gd",FileAccess.READ)
	_check(run_source_file != null,"Telegraph renderer source must be readable")
	var run_source := run_source_file.get_as_text() if run_source_file != null else ""
	for helper_name in ["_draw_warning_line","_draw_warning_dashed_line","_draw_warning_arc","_draw_warning_polyline","_draw_warning_rect_outline"]:
		_check(run_source.contains(String(helper_name)),"Telegraph renderer must retain its shared %s primitive" % helper_name)
	_check(run_source.count("_draw_warning_dashed_line(") >= 13,"Exterior, room, defender, and safe-path dashed warnings must all use the shared ink edge")
	_check(run_source.count("_draw_warning_arc(") >= 16,"Exterior, room-projectile, defender, and safe-path rings must all use the shared ink edge")
	_check(run_source.contains("if telegraph_only:") and run_source.contains("_draw_warning_rect_outline(rect,color,3.0)"),"Authored room geometry must outline only its warning state, not ambient active art")
	var early_warning_ink := RunSceneClass.telegraph_ink_color(Color(VisualTheme.TELEGRAPH,0.2))
	var final_warning_ink := RunSceneClass.telegraph_ink_color(Color(VisualTheme.TELEGRAPH,0.95))
	_check(Color(early_warning_ink,1.0).is_equal_approx(Color(ProjectilePoolClass.MYTHIC_INK,1.0)),"Telegraphs must share the exact projectile mythic-ink hue")
	_check(early_warning_ink.a >= 0.64 and final_warning_ink.a > early_warning_ink.a and final_warning_ink.a <= ProjectilePoolClass.INK_OPACITY,"Telegraph ink must stay visible early while preserving readiness progress")
	_check(_rgb_distance(VisualTheme.FRIENDLY,VisualTheme.TELEGRAPH) >= 0.8,"Aqua safe paths must remain unmistakable from gold danger warnings")
	for background in [VisualTheme.SPACE,VisualTheme.DEEP_SPACE,VisualTheme.TISSUE]:
		var normal_ratio := _contrast_ratio(VisualTheme.ENEMY,background)
		var high_ratio := _contrast_ratio(HIGH_CONTRAST_PROJECTILE,background)
		_check(normal_ratio >= 4.5,"Default hostile projectiles must remain readable against %s" % background.to_html(false))
		_check(high_ratio >= 7.0,"High-contrast hostile projectiles must exceed enhanced contrast against %s" % background.to_html(false))
		_check(high_ratio > normal_ratio + 2.0,"High-contrast mode must materially improve contrast against %s" % background.to_html(false))
	_check(_contrast_ratio(VisualTheme.FRIENDLY,VisualTheme.DEEP_SPACE) >= 7.0,"Friendly projectiles must remain visually distinct against exterior space")
	_check(_rgb_distance(HIGH_CONTRAST_PROJECTILE,VisualTheme.FRIENDLY) >= 0.45,"High-contrast hostile and friendly projectiles must not converge on the same hue")

	var projectile_cores := {
		"hostile_default":VisualTheme.ENEMY,
		"hostile_high_contrast":HIGH_CONTRAST_PROJECTILE,
		"telegraph":VisualTheme.TELEGRAPH,
		"safe_path":VisualTheme.FRIENDLY,
		"room_vulnerable":VisualTheme.VULNERABLE,
		"room_shard":VisualTheme.SHARD,
		"room_bio":VisualTheme.BIO,
	}
	for raw_weapon in GameData.weapons:
		var weapon := raw_weapon as Dictionary
		projectile_cores["weapon:%s" % String(weapon.get("id","unknown"))] = Color(String(weapon.get("color","#54F2E7")))
	for core_name_value in projectile_cores:
		var core_name := String(core_name_value)
		var core_color := projectile_cores[core_name] as Color
		_check(_contrast_ratio(core_color,ProjectilePoolClass.MYTHIC_INK) >= 3.0,"%s core must remain distinct from its mythic-ink edge" % core_name)
	for background_path_value in COMBAT_BACKGROUND_PATHS:
		var background_path := String(background_path_value)
		var background_texture := ResourceLoader.load(background_path) as Texture2D
		_check(background_texture != null,"Current combat background must load for image-backed contrast: %s" % background_path)
		if background_texture == null:
			continue
		var background_image := background_texture.get_image()
		_check(background_image != null and not background_image.is_empty(),"Current combat background must expose pixels for contrast: %s" % background_path)
		if background_image == null or background_image.is_empty():
			continue
		for core_name_value in projectile_cores:
			var core_name := String(core_name_value)
			var core_color := projectile_cores[core_name] as Color
			var pair_samples := _image_backed_projectile_pair_contrast(background_image,core_color,ProjectilePoolClass.MYTHIC_INK)
			_check(float(pair_samples.get("minimum",0.0)) >= 1.8,"%s ink/core pair must never disappear into %s" % [core_name,background_path])
			_check(float(pair_samples.get("enhanced_fraction",0.0)) >= 0.875,"%s ink/core pair must reach 3:1 across at least 87.5%% of %s" % [core_name,background_path])

	var pool := ProjectilePoolClass.new()
	add_child(pool)
	for behavior_index in ["pulse","scatter","rail","arc","orbitals"].size():
		var behavior := String(["pulse","scatter","rail","arc","orbitals"][behavior_index])
		_check(pool.spawn_player(Vector2(76+behavior_index*88,220),Vector2.UP*600.0,12.0,{"behavior":behavior,"color":Color(String((GameData.weapons[behavior_index] as Dictionary).get("color","#54F2E7")))}),"Every player projectile family must reach the outlined draw pool: %s" % behavior)
	for index in ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size():
		var travel_model := String(ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS[index])
		_check(pool.spawn_enemy(Vector2(80+index*48,320),Vector2(0,120),8.0,{"travel_model":travel_model,"radius":7.0}),"Projectile renderer must accept visual travel model %s" % travel_model)
	_check(pool.enemy_active.size() == ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size(),"Every hostile travel silhouette must reach the draw pool")
	var titan_visual_families: Dictionary = {}
	for visual_token_value in ProjectilePoolClass.TITAN_VISUAL_FAMILIES:
		var visual_token := String(visual_token_value)
		var expected_family := String(ProjectilePoolClass.TITAN_VISUAL_FAMILIES[visual_token])
		var actual_family := ProjectilePoolClass.enemy_visual_family(visual_token,"","linear")
		_check(actual_family==expected_family,"%s must route to its authored outlined projectile family" % visual_token)
		_check(not titan_visual_families.has(actual_family),"Titan projectile silhouettes must remain unique: %s" % actual_family)
		titan_visual_families[actual_family]=visual_token
		var family_index := titan_visual_families.size()-1
		_check(pool.spawn_enemy(Vector2(70+(family_index%6)*78,430+(family_index/6)*90),Vector2(0,120),8.0,{"visual_token":visual_token,"radius":8.0}),"Outlined Titan projectile family must reach the live draw pool: %s" % actual_family)
	_check(titan_visual_families.size()==ProjectilePoolClass.TITAN_VISUAL_FAMILIES.size(),"Every authored Titan projectile family must own a distinct outlined silhouette")
	_check(pool.enemy_active.size()==ProjectilePoolClass.SUPPORTED_TRAVEL_MODELS.size()+ProjectilePoolClass.TITAN_VISUAL_FAMILIES.size(),"Travel fallbacks and all Titan projectile families must redraw together")
	SettingsManager.set_value("projectile_contrast",false,false)
	pool.queue_redraw()
	await get_tree().process_frame
	SettingsManager.set_value("projectile_contrast",true,false)
	pool.queue_redraw()
	await get_tree().process_frame
	_check(bool(SettingsManager.get_value("projectile_contrast",false)),"Projectile-contrast setting must remain active through a redraw")
	pool.clear_all()
	pool.queue_free()
	await get_tree().process_frame


func _image_backed_projectile_pair_contrast(background: Image, core_color: Color, ink_color: Color) -> Dictionary:
	var sample_count := 0
	var enhanced_count := 0
	var minimum_ratio := INF
	# An eight-pixel grid covers 8,160 real pixels per 540x960 launch image,
	# including painted clouds, marble, energy, shadows, and empty field.
	for sample_y in range(0,background.get_height(),8):
		for sample_x in range(0,background.get_width(),8):
			var background_color := background.get_pixel(sample_x,sample_y)
			var pair_ratio := maxf(_contrast_ratio(core_color,background_color),_contrast_ratio(ink_color,background_color))
			minimum_ratio=minf(minimum_ratio,pair_ratio)
			sample_count+=1
			if pair_ratio>=3.0:
				enhanced_count+=1
	return {
		"minimum":minimum_ratio if sample_count>0 else 0.0,
		"enhanced_fraction":float(enhanced_count)/float(sample_count) if sample_count>0 else 0.0,
		"samples":sample_count,
	}


func _test_reduced_motion_contract() -> void:
	_check(SettingsManager.normalize_setting_value("reduced_motion",1) == false,"Reduced Motion must remain a typed Boolean contract")
	_check(is_zero_approx(float(SettingsManager.normalize_setting_value("damage_flash",-1.0))) and is_equal_approx(float(SettingsManager.normalize_setting_value("damage_flash",2.0)),1.0),"Damage Flash must clamp to the complete 0-100 percent range")
	SettingsManager.set_value("reduced_motion",false,false)
	var boss := BossVisualClass.new()
	boss.setup(GameData.get_boss("gravemaw"))
	boss.set_process(false)
	add_child(boss)
	var initial_pulse := boss.pulse_time
	var initial_spin := boss.spin
	boss._process(0.5)
	_check(boss.pulse_time > initial_pulse,"Boss decorative pulse must animate when Reduced Motion is off")
	_check(boss.spin > initial_spin,"Boss decorative rotation must animate when Reduced Motion is off")
	SettingsManager.set_value("reduced_motion",true,false)
	var frozen_pulse := boss.pulse_time
	var frozen_spin := boss.spin
	boss.flash_hit()
	boss._process(0.04)
	_check(is_equal_approx(boss.pulse_time,frozen_pulse),"Reduced Motion must freeze boss pulse")
	_check(is_equal_approx(boss.spin,frozen_spin),"Reduced Motion must freeze boss rotation")
	_check(boss.hit_flash < 0.1,"Reduced Motion must not freeze gameplay-readable hit feedback state")
	SettingsManager.set_value("damage_flash",0.0,false)
	boss.flash_hit()
	_check(is_zero_approx(boss.hit_flash),"Zero Damage Flash must suppress both Titan and organ hit flashes")
	boss.queue_free()
	await get_tree().process_frame
	var reduced_player := PlayerControllerClass.new()
	reduced_player._trail = [Vector2(4,4),Vector2(8,8)]
	reduced_player._physics_process(1.0/60.0)
	_check(reduced_player._trail.is_empty(),"Reduced Motion must discard retained decorative Diver trail samples")
	reduced_player.free()

	_check(is_equal_approx(PlayerControllerClass.invulnerability_alpha(0.3,true),0.72),"Reduced Motion must use a stable invulnerability alpha")
	_check(is_equal_approx(PlayerControllerClass.invulnerability_alpha(0.1,true),PlayerControllerClass.invulnerability_alpha(0.3,true)),"Reduced Motion invulnerability must not blink over time")
	_check(not is_equal_approx(PlayerControllerClass.invulnerability_alpha(0.10,false),PlayerControllerClass.invulnerability_alpha(0.125,false)),"Standard invulnerability feedback must retain its animated blink")
	_check(PlayerControllerClass.damage_flash_color(VisualTheme.FRIENDLY,0.0,true).is_equal_approx(VisualTheme.FRIENDLY),"Zero damage-flash intensity must fully suppress whitening")
	_check(PlayerControllerClass.damage_flash_color(VisualTheme.FRIENDLY,1.0,true).is_equal_approx(Color.WHITE),"Full damage-flash intensity must remain visible")
	var frozen_in := RunSceneClass.dive_transition_visual_radius(RunSceneClass.RunState.DIVING_IN,0.1,true)
	var frozen_out := RunSceneClass.dive_transition_visual_radius(RunSceneClass.RunState.DIVING_OUT,0.9,true)
	_check(is_equal_approx(frozen_in,260.0) and is_equal_approx(frozen_out,260.0),"Reduced Motion must replace dive zoom with one stable frame")
	_check(not is_equal_approx(RunSceneClass.dive_transition_visual_radius(RunSceneClass.RunState.DIVING_IN,0.1,false),RunSceneClass.dive_transition_visual_radius(RunSceneClass.RunState.DIVING_IN,0.9,false)),"Standard dive transition must retain visual movement")

	var hud := RunHUDClass.new()
	add_child(hud)
	await get_tree().process_frame
	SettingsManager.set_value("reduced_motion",true,false)
	hud.show_toast("REDUCED")
	_check(is_equal_approx(hud.toast_label.modulate.a,1.0),"Reduced Motion toast must appear without a fade-in")
	SettingsManager.set_value("damage_flash",0.0,false)
	_check(not hud.show_damage_feedback() and not hud.damage_edge_feedback.visible,"Zero Damage Flash must suppress the screen-edge cue")
	SettingsManager.set_value("damage_flash",1.0,false)
	var edge_started := hud.show_damage_feedback()
	var edge_duration_bounded := hud.damage_edge_feedback.remaining_seconds <= SettingsManager.DAMAGE_FEEDBACK_DURATION_SECONDS
	hud.damage_edge_feedback._process(SettingsManager.DAMAGE_FEEDBACK_DURATION_SECONDS+0.001)
	_check(edge_started and edge_duration_bounded and not hud.damage_edge_feedback.visible,"Damage feedback must remain edge-only and expire within 0.18 seconds")
	SettingsManager.set_value("reduced_motion",false,false)
	hud.show_toast("STANDARD")
	_check(is_zero_approx(hud.toast_label.modulate.a),"Standard toast may retain its short fade-in")
	if is_instance_valid(hud._toast_tween):
		hud._toast_tween.kill()
	hud.queue_free()
	await get_tree().process_frame


func _test_titan_organ_anchor_contract() -> void:
	var catalog := BossVisualClass.titan_organ_anchor_catalog()
	var seen_organs: Dictionary = {}
	var anchor_signatures: Dictionary = {}
	_check(catalog.size()==4,"Titan organ-anchor catalog must cover all four launch portraits")
	for raw_boss in GameData.bosses:
		var boss := raw_boss as Dictionary
		var boss_id := String(boss.get("id",""))
		var portrait_rect := BossVisualClass.titan_portrait_rect(boss_id)
		var anchors: Dictionary = catalog.get(boss_id,{})
		var positions: Array[Vector2] = []
		var signature_parts: Array[String] = []
		_check(anchors.size()==3,"%s must own exactly three portrait-specific organ anchors" % boss_id)
		for raw_organ in boss.get("organs",[]):
			var organ := raw_organ as Dictionary
			var organ_id := String(organ.get("id",""))
			var token := String((organ.get("loss",{}) as Dictionary).get("visual_token",""))
			var normalized := BossVisualClass.titan_organ_anchor_normalized(boss_id,organ_id)
			var position := BossVisualClass.titan_organ_anchor_position(boss_id,organ_id)
			var token_position := BossVisualClass.titan_visual_token_anchor_position(boss_id,token)
			_check(anchors.has(organ_id),"%s/%s must have an authored normalized anchor" % [boss_id,organ_id])
			_check(normalized.x>=0.10 and normalized.x<=0.90 and normalized.y>=0.08 and normalized.y<=0.92,"%s/%s normalized anchor must stay inside the readable portrait field" % [boss_id,organ_id])
			_check(position.is_finite() and portrait_rect.grow(-6.0).has_point(position),"%s/%s anchor must map through its actual texture aspect into the portrait" % [boss_id,organ_id])
			_check(token_position.is_equal_approx(position),"%s destroyed visual %s must reuse its intact on-body anchor" % [organ_id,token])
			_check(BossVisualClass.ORGAN_NODE_COLORS.has(organ_id),"%s must retain a readable authored node color" % organ_id)
			_check(not seen_organs.has(organ_id),"Organ anchors must remain globally unique: %s" % organ_id)
			seen_organs[organ_id]=boss_id
			positions.append(position)
			signature_parts.append("%.2f,%.2f" % [normalized.x,normalized.y])
		for left_index in positions.size():
			for right_index in range(left_index+1,positions.size()):
				_check(positions[left_index].distance_to(positions[right_index])>=42.0,"%s on-body organ nodes must not visually merge" % boss_id)
		var signature := "|".join(signature_parts)
		_check(not anchor_signatures.has(signature),"%s must not reuse another Titan's anchor layout" % boss_id)
		anchor_signatures[signature]=boss_id
	_check(seen_organs.size()==12,"Portrait anchor catalog must map all twelve launch organs exactly once")
	_check(anchor_signatures.size()==4,"All four Titans must retain distinct on-body organ layouts")
	var source_file := FileAccess.open("res://scripts/gameplay/boss_visual.gd",FileAccess.READ)
	var source := source_file.get_as_text() if source_file!=null else ""
	_check(source_file!=null and source.contains("_draw_titan_organ_nodes"),"BossVisual must render the normalized on-body status layer")
	_check(not source.contains("_draw_organ_status"),"Duplicate outer-orbit organ badges must remain removed")


func _test_boss_visual_states() -> void:
	var all_tokens: Dictionary = {}
	_check(GameData.bosses.size() == 4,"Visual boss gate requires all four launch bosses")
	for raw_boss in GameData.bosses:
		var definition := raw_boss as Dictionary
		var boss_id := String(definition.id)
		var destroyed: Array[String] = []
		var states: Dictionary = {}
		_check((definition.get("organs",[]) as Array).size() == 3,"%s must retain exactly three visible organ-loss states" % boss_id)
		for raw_organ in definition.get("organs",[]):
			var organ := raw_organ as Dictionary
			var organ_id := String(organ.id)
			var token := String((organ.loss as Dictionary).visual_token)
			destroyed.append(organ_id)
			states[organ_id] = token
			_check(not token.is_empty(),"%s must retain a nonempty exterior visual token" % organ_id)
			_check(BossVisualClass.supports_visual_token(token),"%s token must remain drawable by BossVisual" % organ_id)
			_check(not all_tokens.has(token),"Exterior organ-loss token must stay globally unique: %s" % token)
			all_tokens[token] = organ_id
		var visual := BossVisualClass.new()
		visual.setup(definition)
		visual.position = Vector2(270,145)
		visual.set_exterior(2,destroyed,false,states)
		visual.set_process(false)
		add_child(visual)
		await get_tree().process_frame
		_check(visual.active_visual_tokens().size() == 3,"%s must draw all three cumulative organ scars" % boss_id)
		for organ_id_value in destroyed:
			var organ_id := String(organ_id_value)
			_check(visual.visual_state_for_organ(organ_id) == String(states[organ_id]),"%s must expose its exact active visual state" % organ_id)
		_check(is_equal_approx(visual.target_radius(),float(EXPECTED_TARGET_RADII[boss_id])),"%s exterior target geometry must remain stable" % boss_id)
		_check(visual.target_position().is_equal_approx(Vector2(270,203)),"%s exterior target center must remain aligned with the silhouette" % boss_id)
		visual.set_interior((definition.organs as Array)[0] as Dictionary)
		_check(is_equal_approx(visual.target_radius(),67.0),"%s interior organ target geometry must remain stable" % boss_id)
		_check(visual.target_position().is_equal_approx(Vector2(270,145)),"%s interior target center must remain aligned with its chamber" % boss_id)
		visual.queue_free()
		await get_tree().process_frame
	_check(all_tokens.size() == 12,"All twelve organ-loss visuals must remain distinct")
	_check(all_tokens.size() == BossVisualClass.SUPPORTED_VISUAL_TOKENS.size(),"BossVisual token registry must match the authored boss catalog exactly")
	for token_value in BossVisualClass.SUPPORTED_VISUAL_TOKENS:
		_check(all_tokens.has(String(token_value)),"BossVisual registry cannot contain an unauthored token: %s" % String(token_value))


func _test_titan_collapse_contract() -> void:
	var profiles := TitanCollapseCatalogClass.load_catalog()
	_check(profiles.size() == 4,"Titan collapse catalog must retain four launch profiles")
	_check(TitanCollapseCatalogClass.validate_catalog(profiles).is_empty(),"Authored Titan collapse catalog must pass strict validation")
	var seen_styles: Dictionary = {}
	var seen_finals: Dictionary = {}
	var seen_body_transforms: Dictionary = {}
	for raw_profile in profiles:
		var profile := raw_profile as Dictionary
		var boss_id := String(profile.get("boss_id", ""))
		var style_token := String(profile.get("style_token", ""))
		var final_token := String(profile.get("final_token", ""))
		var cues := profile.get("cues", []) as Array
		var loaded_profile := TitanCollapseCatalogClass.profile_for(boss_id)
		_check(not loaded_profile.is_empty() and String(loaded_profile.get("style_token", "")) == style_token,"%s collapse profile must round-trip through the validated catalog" % boss_id)
		_check(not style_token.is_empty() and not seen_styles.has(style_token),"%s must own a distinct collapse visual language" % boss_id)
		_check(not final_token.is_empty() and not seen_finals.has(final_token),"%s must own a distinct terminal collapse seal" % boss_id)
		_check(cues.size() == 4,"%s collapse must retain four authored visual/audio beats" % boss_id)
		_check(float(profile.get("duration_seconds",0.0)) > float(profile.get("reduced_motion_duration_seconds",0.0)) and float(profile.get("reduced_motion_duration_seconds",0.0)) >= 0.1,"%s must publish bounded standard and reduced-motion durations" % boss_id)
		seen_styles[style_token] = true
		seen_finals[final_token] = true

		var visual := BossVisualClass.new()
		visual.setup(GameData.get_boss(boss_id))
		var started_events: Array = []
		var cue_events: Array = []
		var completed_events: Array = []
		visual.collapse_started.connect(func(started_boss_id: String, duration_seconds: float, reduced_motion: bool) -> void:
			started_events.append({"boss_id":started_boss_id,"duration":duration_seconds,"reduced":reduced_motion})
		)
		visual.collapse_cue.connect(func(cue_index: int, visual_token: String, audio_token: String) -> void:
			cue_events.append({"index":cue_index,"visual":visual_token,"audio":audio_token})
		)
		visual.collapse_completed.connect(func(completed_boss_id: String, interrupted: bool, reason: String) -> void:
			completed_events.append({"boss_id":completed_boss_id,"interrupted":interrupted,"reason":reason})
		)
		_check(visual.start_collapse(false),"%s collapse must start from an authored profile" % boss_id)
		var start_snapshot := visual.collapse_visual_snapshot()
		_check(String(start_snapshot.get("style_token","")) == style_token and String(start_snapshot.get("final_token","")) == final_token,"%s BossVisual must expose the authored visual identity" % boss_id)
		_check(started_events.size() == 1 and String((started_events[0] as Dictionary).get("boss_id","")) == boss_id and not bool((started_events[0] as Dictionary).get("reduced",true)),"%s collapse must emit one typed standard-motion start event" % boss_id)
		_check(cue_events.size() == 1 and int((cue_events[0] as Dictionary).get("index",-1)) == 0,"%s collapse must emit its time-zero cue immediately" % boss_id)
		var duration := float(profile.get("duration_seconds",0.0))
		_check(visual.advance_collapse(duration*0.5),"%s collapse must accept deterministic manual advancement" % boss_id)
		var midpoint := visual.collapse_visual_snapshot()
		_check(visual.is_collapsing() and is_equal_approx(float(midpoint.get("progress",0.0)),0.5),"%s collapse midpoint must remain running at exact normalized progress" % boss_id)
		_check(visual.advance_collapse(duration),"%s collapse must safely consume a frame longer than its remaining duration" % boss_id)
		_check(visual.is_collapse_complete() and is_equal_approx(visual.collapse_progress(),1.0),"%s collapse must reach a stable completed state" % boss_id)
		var body_transform := visual.collapse_body_transform()
		var body_offset := Vector2(body_transform.get("offset",Vector2.ZERO))
		var body_signature := "%0.3f:%0.3f:%0.3f:%0.3f:%0.3f" % [body_offset.x,body_offset.y,float(body_transform.get("rotation",0.0)),Vector2(body_transform.get("scale",Vector2.ONE)).x,Vector2(body_transform.get("scale",Vector2.ONE)).y]
		_check(body_offset.length() >= 30.0 and not seen_body_transforms.has(body_signature),"%s standard collapse must end in a distinct physical Titan pose" % boss_id)
		seen_body_transforms[body_signature] = true
		_check(completed_events.size() == 1 and not bool((completed_events[0] as Dictionary).get("interrupted",true)) and String((completed_events[0] as Dictionary).get("reason","")) == "sequence_complete","%s collapse must emit exactly one natural completion" % boss_id)
		_check(cue_events.size() == cues.size() and String((cue_events[-1] as Dictionary).get("audio","")) == "boss_death","%s large-delta completion must emit every cue once and end in boss_death" % boss_id)
		_check((visual.collapse_active_visual_tokens as Array).size() == cues.size(),"%s collapse must retain every activated visual token for capture/replay" % boss_id)
		_check(not visual.start_collapse(false) and not visual.advance_collapse(1.0) and completed_events.size() == 1,"%s completed collapse must reject duplicate start, advancement, and completion" % boss_id)
		visual.free()
	_check(seen_styles.size() == 4 and seen_finals.size() == 4 and seen_body_transforms.size() == 4,"All four Titans must remain visually distinct through their final collapse frame")

	var reduced_profile := TitanCollapseCatalogClass.profile_for("seraph_9")
	var reduced_visual := BossVisualClass.new()
	reduced_visual.setup(GameData.get_boss("seraph_9"))
	var reduced_completions: Array = []
	reduced_visual.collapse_completed.connect(func(boss_id: String, interrupted: bool, reason: String) -> void:
		reduced_completions.append({"boss_id":boss_id,"interrupted":interrupted,"reason":reason})
	)
	_check(reduced_visual.start_collapse(true),"Reduced Motion must retain an authored Hyperion collapse path")
	var reduced_snapshot := reduced_visual.collapse_visual_snapshot()
	_check(bool(reduced_snapshot.get("reduced_motion",false)) and is_equal_approx(float(reduced_snapshot.get("duration_seconds",0.0)),float(reduced_profile.get("reduced_motion_duration_seconds",-1.0))),"Reduced Motion must select the profile's explicit short duration")
	_check(is_equal_approx(float(reduced_snapshot.get("visual_progress",0.0)),1.0) and Vector2(reduced_snapshot.get("body_offset",Vector2.ONE)).is_zero_approx() and is_zero_approx(float(reduced_snapshot.get("body_rotation",1.0))),"Reduced Motion must use a stable final tableau instead of spatial animation")
	_check(reduced_visual.advance_collapse(float(reduced_profile.get("reduced_motion_duration_seconds",0.0))*2.0),"Reduced Motion collapse must complete safely across a large frame")
	_check(reduced_visual.is_collapse_complete() and reduced_completions.size() == 1,"Reduced Motion collapse must preserve the exact-once completion signal")
	_check(float(reduced_profile.get("reduced_motion_duration_seconds",0.0)) < float(reduced_profile.get("duration_seconds",0.0)),"Reduced Motion duration must be shorter than the standard sequence")
	reduced_visual.free()

	var interrupted_visual := BossVisualClass.new()
	interrupted_visual.setup(GameData.get_boss("null_twin"))
	var interruption_cues: Array = []
	var interruption_completions: Array = []
	interrupted_visual.collapse_cue.connect(func(index: int, visual_token: String, audio_token: String) -> void:
		interruption_cues.append({"index":index,"visual":visual_token,"audio":audio_token})
	)
	interrupted_visual.collapse_completed.connect(func(boss_id: String, interrupted: bool, reason: String) -> void:
		interruption_completions.append({"boss_id":boss_id,"interrupted":interrupted,"reason":reason})
	)
	_check(interrupted_visual.start_collapse(false),"Interruption test must start an authored Mnemosyne sequence")
	_check(interrupted_visual.advance_collapse(0.01),"A running collapse must advance before interruption")
	_check(interrupted_visual.interrupt_collapse("scene_transition"),"A running collapse must support immediate interruption completion")
	var interruption_snapshot := interrupted_visual.collapse_visual_snapshot()
	_check(interrupted_visual.is_collapse_complete() and bool(interruption_snapshot.get("interrupted",false)) and String(interruption_snapshot.get("completion_reason","")) == "scene_transition","Interrupted collapse must expose its terminal reason")
	_check(interruption_cues.size() == 1 and interruption_completions.size() == 1 and bool((interruption_completions[0] as Dictionary).get("interrupted",false)),"Interruption must avoid bursting pending audio cues and emit one completion")
	_check(not interrupted_visual.interrupt_collapse("duplicate") and interruption_completions.size() == 1,"Repeated interruption must not duplicate collapse completion")
	interrupted_visual.free()

	var duplicate_catalog := profiles.duplicate(true)
	(duplicate_catalog[1] as Dictionary)["boss_id"] = String((duplicate_catalog[0] as Dictionary).get("boss_id",""))
	_check(not TitanCollapseCatalogClass.validate_catalog(duplicate_catalog).is_empty(),"Collapse validation must reject duplicate or missing Titan identities")
	var malformed_cues := profiles.duplicate(true)
	((malformed_cues[0] as Dictionary).get("cues",[]) as Array)[1] = {"at":0.0,"visual_token":"unknown","audio_token":"unknown"}
	_check(TitanCollapseCatalogClass.validate_catalog(malformed_cues).size() >= 3,"Collapse validation must reject unsorted timing and unsupported visual/audio tokens")
	_check(not TitanCollapseCatalogClass.validate_catalog({}).is_empty(),"Collapse validation must reject a non-array root")
	_check(TitanCollapseCatalogClass.profile_for("unknown_titan").is_empty(),"Unknown Titans must fail closed without borrowing another collapse identity")
	var missing_profile_visual := BossVisualClass.new()
	missing_profile_visual.setup({"id":"unknown_titan"})
	var missing_profile_completions: Array = []
	missing_profile_visual.collapse_completed.connect(func(boss_id: String, interrupted: bool, reason: String) -> void:
		missing_profile_completions.append({"boss_id":boss_id,"interrupted":interrupted,"reason":reason})
	)
	_check(not missing_profile_visual.start_collapse(false) and missing_profile_visual.is_collapse_complete() and missing_profile_completions.size() == 1 and String((missing_profile_completions[0] as Dictionary).get("reason","")) == "invalid_profile","Missing collapse data must fail safe through the same immediate completion signal")
	missing_profile_visual.free()
	var reconfigured_visual := BossVisualClass.new()
	reconfigured_visual.setup(GameData.get_boss("gravemaw"))
	var reconfigured_completions: Array = []
	reconfigured_visual.collapse_completed.connect(func(boss_id: String, interrupted: bool, reason: String) -> void:
		reconfigured_completions.append({"boss_id":boss_id,"interrupted":interrupted,"reason":reason})
	)
	_check(reconfigured_visual.start_collapse(false),"Reconfiguration guard must begin from a valid collapse")
	reconfigured_visual.setup(GameData.get_boss("seraph_9"))
	_check(reconfigured_completions.size() == 1 and String((reconfigured_completions[0] as Dictionary).get("boss_id","")) == "gravemaw" and String((reconfigured_completions[0] as Dictionary).get("reason","")) == "boss_reconfigured" and reconfigured_visual.collapse_state == BossVisualClass.CollapseState.IDLE,"Boss replacement must complete the old sequence once before resetting visual state")
	reconfigured_visual.free()


func _test_five_nest_states() -> void:
	var baseline := SaveManager.default_profile()
	var english_stage_names: Dictionary = {}
	var hebrew_stage_names: Dictionary = {}
	SettingsManager.values = baseline.settings.duplicate(true)
	for stage in 5:
		SettingsManager.values.language = "en"
		english_stage_names[stage] = LocalizationService.text("nest_stage_%d" % stage)
		SettingsManager.values.language = "he"
		hebrew_stage_names[stage] = LocalizationService.text("nest_stage_%d" % stage)
		_check(not String(english_stage_names[stage]).is_empty(),"Nest stage %d needs an English identity" % stage)
		_check(not String(hebrew_stage_names[stage]).is_empty(),"Nest stage %d needs a Hebrew identity" % stage)
		_check(String(english_stage_names[stage]) != String(hebrew_stage_names[stage]),"Nest stage %d localizations must not collapse to one fallback" % stage)
	_check(_unique_value_count(english_stage_names) == 5,"The Last Nest must retain five distinct English states")
	_check(_unique_value_count(hebrew_stage_names) == 5,"The Last Nest must retain five distinct Hebrew states")

	SettingsManager.values.language = "en"
	var expected_enabled_counts := [2,4,5,6,6]
	var state_signatures: Dictionary = {}
	for stage in 5:
		SaveManager.profile = baseline.duplicate(true)
		SaveManager.profile.nest_stage = stage
		var nest := NestViewClass.new()
		nest.set_process(false)
		add_child(nest)
		await get_tree().process_frame
		nest.queue_redraw()
		await get_tree().process_frame
		_check(nest._stage_label.text.contains(String(english_stage_names[stage])),"Nest stage %d must present its authored state name" % stage)
		var enabled_count := 0
		var signature := String(english_stage_names[stage])
		for facility_id_value in FACILITY_STAGE:
			var facility_id := String(facility_id_value)
			var button := nest.get_node_or_null("Facility_%s" % facility_id) as Button
			_check(button != null,"Nest state %d must retain Facility_%s" % [stage,facility_id])
			if button == null:
				continue
			var expected_enabled := stage >= int(FACILITY_STAGE[facility_id])
			_check(button.disabled == not expected_enabled,"Nest state %d must apply the %s unlock threshold" % [stage,facility_id])
			if not button.disabled:
				enabled_count += 1
			signature += ":%s=%s" % [facility_id,str(not button.disabled)]
		_check(enabled_count == expected_enabled_counts[stage],"Nest state %d must expose its exact facility count" % stage)
		_check(not state_signatures.has(signature),"Nest state %d must remain distinguishable from every earlier state" % stage)
		state_signatures[signature] = true
		if stage == 0:
			SaveManager.profile.abyss_unlocked = true
			nest._refresh_all()
			var core_button := nest.get_node_or_null("Facility_core") as Button
			_check(core_button != null and not core_button.disabled,"Abyss completion must visibly wake the Core before stage three")
		var time_before := nest._time
		SettingsManager.set_value("reduced_motion",false,false)
		nest._process(0.25)
		_check(nest._time > time_before,"Nest state %d machinery must animate in standard motion" % stage)
		SettingsManager.set_value("reduced_motion",true,false)
		var frozen_time := nest._time
		nest._process(0.25)
		_check(is_equal_approx(nest._time,frozen_time),"Nest state %d must freeze decorative motion in Reduced Motion" % stage)
		nest.queue_free()
		await get_tree().process_frame
	_check(state_signatures.size() == 5,"The Last Nest visual-state contract must contain exactly five states")


func _relative_luminance(color: Color) -> float:
	return 0.2126*_linear_channel(color.r)+0.7152*_linear_channel(color.g)+0.0722*_linear_channel(color.b)


func _linear_channel(value: float) -> float:
	return value/12.92 if value <= 0.04045 else pow((value+0.055)/1.055,2.4)


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance,second_luminance)+0.05)/(minf(first_luminance,second_luminance)+0.05)


func _rgb_distance(first: Color, second: Color) -> float:
	return Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()


func _unique_value_count(values: Dictionary) -> int:
	var unique: Dictionary = {}
	for value in values.values():
		unique[value] = true
	return unique.size()
