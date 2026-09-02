class_name NestView
extends Control

const SafeAreaHelperScript := preload("res://scripts/ui/safe_area_helper.gd")
const PermanentUpgradeEngineScript := preload("res://scripts/core/permanent_upgrade_engine.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const MetaGoalServiceScript := preload("res://scripts/services/meta_goal_service.gd")
const NATIVE_PUBLIC_SITE_BASE := "https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/"

signal start_requested(config: Dictionary)

const FACILITIES := [
	{"id":"hangar","key":"hangar","position":Vector2(75,350),"stage":0},
	{"id":"forge","key":"forge","position":Vector2(195,286),"stage":0},
	{"id":"research","key":"research","position":Vector2(348,285),"stage":1},
	{"id":"rift","key":"rift","position":Vector2(462,356),"stage":1},
	{"id":"trophies","key":"trophies","position":Vector2(145,475),"stage":2},
	{"id":"core","key":"core","position":Vector2(391,472),"stage":3}
]

var _time:=0.0
var _boss_index:=0
var _difficulty:OptionButton
var _boss_title:Label
var _boss_subtitle:Label
var _currency:Label
var _stage_label:Label
var _hunt_button:Button
var _overlay:PanelContainer
var _facility_buttons:Dictionary={}
var _logo:Label
var _tagline:Label
var _mode_label:Label
var _footer:Label
var _meta_goals := MetaGoalServiceScript.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_PASS
	_build_ui()
	var previous_contract_day := String((SaveManager.profile.get("contracts", {}) as Dictionary).get("day_key", ""))
	if not _meta_goals.initialize(SaveManager.profile):
		push_error("Invalid meta-goal catalogs: %s" % "; ".join(_meta_goals.get_validation_errors()))
	elif previous_contract_day != _meta_goals.active_day_key:
		SaveManager.save_profile()
	get_viewport().size_changed.connect(_apply_safe_layout)
	_apply_safe_layout()
	_refresh_all()
	AudioManager.set_music_state("nest",0.2+int(SaveManager.profile.get("nest_stage",0))*0.13)
	LocalizationService.locale_changed.connect(_on_locale_changed)
	queue_redraw()

func _apply_safe_layout() -> void:
	SafeAreaHelperScript.fit_design_control(self)

func _process(delta:float)->void:
	# Sanctuary structures remain visible in Reduced Motion, but decorative
	# clouds, aether, water, and ornaments freeze at a stable pose. Avoid redrawing
	# that identical frame every tick so the accessibility mode also saves power.
	if SettingsManager.reduced_motion_enabled():
		return
	_time+=delta
	queue_redraw()

func _build_ui()->void:
	_logo=VisualTheme.label("INFINIDIVE",44)
	_logo.position=Vector2(22,22)
	_logo.size=Vector2(340,58)
	add_child(_logo)
	_tagline=VisualTheme.label("",13,VisualTheme.MUTED)
	_tagline.position=Vector2(24,78)
	_tagline.size=Vector2(410,38)
	add_child(_tagline)
	_currency=VisualTheme.label("",12,VisualTheme.BIO)
	_currency.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_currency.position=Vector2(330,28)
	_currency.size=Vector2(186,52)
	add_child(_currency)
	var settings_button:=Button.new()
	settings_button.text="SET"
	settings_button.position=Vector2(472,82)
	settings_button.size=Vector2(48,48)
	settings_button.add_theme_font_size_override("font_size",12)
	settings_button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color("#173B55",0.88),20))
	settings_button.pressed.connect(_show_settings)
	add_child(settings_button)

	_stage_label=VisualTheme.label("",11,VisualTheme.FRIENDLY)
	_stage_label.position=Vector2(22,134)
	_stage_label.size=Vector2(496,30)
	_stage_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stage_label)

	for facility in FACILITIES:
		var button:=Button.new()
		button.name="Facility_%s"%String(facility.id)
		button.position=Vector2(facility.position)-Vector2(52,38)
		button.size=Vector2(104,76)
		button.add_theme_font_size_override("font_size",9)
		button.add_theme_color_override("font_color",Color("#102D4D"))
		button.add_theme_color_override("font_hover_color",Color("#102D4D"))
		button.add_theme_color_override("font_disabled_color",Color("#60777F"))
		button.add_theme_color_override("font_shadow_color",Color(1,1,1,0.72))
		button.add_theme_constant_override("shadow_offset_x",1)
		button.add_theme_constant_override("shadow_offset_y",2)
		button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(1,1,1,0.035),22))
		button.add_theme_stylebox_override("hover",VisualTheme.button_style(Color("#DFFDF3",0.34),22))
		button.add_theme_stylebox_override("pressed",VisualTheme.button_style(Color("#FFD66E",0.28),22))
		button.add_theme_stylebox_override("disabled",VisualTheme.button_style(Color("#6E858B",0.035),22))
		var facility_id:=String(facility.id)
		button.pressed.connect(func():_open_facility(facility_id))
		add_child(button)
		_facility_buttons[facility_id]=button

	var boss_panel:=PanelContainer.new()
	boss_panel.position=Vector2(18,606)
	boss_panel.size=Vector2(504,184)
	boss_panel.add_theme_stylebox_override("panel",VisualTheme.panel_style(Color("#102D4D",0.95),25,Color("#F3BE45",0.42)))
	add_child(boss_panel)
	var boss_box:=VBoxContainer.new()
	boss_box.add_theme_constant_override("separation",6)
	boss_panel.add_child(boss_box)
	var row:=HBoxContainer.new()
	boss_box.add_child(row)
	var prev:=Button.new();prev.text="‹";prev.custom_minimum_size=Vector2(46,46);prev.pressed.connect(func():_cycle_boss(-1));row.add_child(prev)
	var title_box:=VBoxContainer.new();title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title_box)
	_boss_title=VisualTheme.label("",22);_boss_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title_box.add_child(_boss_title)
	_boss_subtitle=VisualTheme.label("",10,VisualTheme.MUTED);_boss_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title_box.add_child(_boss_subtitle)
	var next:=Button.new();next.text="›";next.custom_minimum_size=Vector2(46,46);next.pressed.connect(func():_cycle_boss(1));row.add_child(next)
	var options:=HBoxContainer.new();boss_box.add_child(options)
	_mode_label=VisualTheme.label("",11,VisualTheme.SHARD);_mode_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;options.add_child(_mode_label)
	_difficulty=OptionButton.new();_difficulty.add_item("DIVER");_difficulty.add_item("DEEP");_difficulty.add_item("ABYSS");_difficulty.selected=0;options.add_child(_difficulty)

	_hunt_button=Button.new()
	_hunt_button.name="BeginDive"
	_hunt_button.position=Vector2(18,806)
	_hunt_button.size=Vector2(504,72)
	_hunt_button.add_theme_font_size_override("font_size",17)
	_hunt_button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(VisualTheme.FRIENDLY,0.82),22))
	_hunt_button.add_theme_color_override("font_color",VisualTheme.DEEP_SPACE)
	_hunt_button.pressed.connect(_start_story)
	add_child(_hunt_button)
	_footer=VisualTheme.label("",9,VisualTheme.MUTED)
	_footer.position=Vector2(18,895);_footer.size=Vector2(504,30);_footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(_footer)

	_overlay=PanelContainer.new()
	_overlay.position=Vector2(14,126)
	_overlay.size=Vector2(512,760)
	_overlay.add_theme_stylebox_override("panel",VisualTheme.panel_style(Color(0.012,0.021,0.046,0.985),26,Color(VisualTheme.FRIENDLY,0.2)))
	_overlay.visible=false
	add_child(_overlay)

func _refresh_all()->void:
	var rtl:=LocalizationService.is_rtl()
	_tagline.text=LocalizationService.text("tagline")
	_tagline.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	_tagline.layout_direction=LocalizationService.layout_direction()
	_currency.text="%s %d\n%s %d"%[LocalizationService.text("bio"),int(SaveManager.profile.get("bio_matter",0)),LocalizationService.text("shards"),int(SaveManager.profile.get("core_shards",0))]
	_currency.layout_direction=LocalizationService.layout_direction()
	var stage:=clampi(int(SaveManager.profile.get("nest_stage",0)),0,4)
	var tutorial := _tutorial_from_profile()
	if tutorial.current_step_id() == TutorialFlowScript.STEP_DEFINITIONS[9].id:
		_stage_label.text = LocalizationService.text(String(tutorial.current_message_key()))
		_stage_label.add_theme_color_override("font_color",VisualTheme.BIO)
	else:
		_stage_label.text="%s · %s"%[LocalizationService.text("last_nest"),LocalizationService.text("nest_stage_%d"%stage)]
		_stage_label.add_theme_color_override("font_color",VisualTheme.FRIENDLY)
	_hunt_button.text=LocalizationService.text("begin_dive")
	_mode_label.text=LocalizationService.text("story_descent")
	_mode_label.horizontal_alignment=LocalizationService.start_alignment()
	_difficulty.set_item_text(0,LocalizationService.text("diver"))
	_difficulty.set_item_text(1,LocalizationService.text("deep"))
	_difficulty.set_item_text(2,LocalizationService.text("abyss"))
	_difficulty.layout_direction=LocalizationService.layout_direction()
	_footer.text=LocalizationService.text("offline_footer",{"version":String(ProjectSettings.get_setting("application/config/version","0.1.0"))})
	for facility in FACILITIES:
		var button:Button=_facility_buttons[String(facility.id)]
		var unlocked:=stage>=int(facility.stage)
		if String(facility.id)=="core" and bool(SaveManager.profile.get("abyss_unlocked",false)):
			unlocked=true
		button.disabled=not unlocked
		button.add_theme_color_override("font_color",Color("#102D4D") if unlocked else Color("#60777F"))
		# The first line reserves the facility silhouette instead of covering it
		# with a menu-card label. The full button remains a generous touch target.
		button.text="\n%s"%(LocalizationService.text(String(facility.key)) if unlocked else LocalizationService.text("locked"))
	_refresh_boss()
	queue_redraw()

func _on_locale_changed(_locale:String)->void:
	_hide_overlay()
	_refresh_all()

func _unlocked_bosses()->Array[String]:
	var result:Array[String]=[]
	for id_value in SaveManager.profile.get("unlocked_bosses",["gravemaw"]):
		result.append(String(id_value))
	if result.is_empty():result.append("gravemaw")
	return result

func _cycle_boss(direction:int)->void:
	var bosses:=_unlocked_bosses()
	_boss_index=wrapi(_boss_index+direction,0,bosses.size())
	_refresh_boss()
	AudioManager.play_sfx("ui_confirm",1.0,0.5)

func _refresh_boss()->void:
	var bosses:=_unlocked_bosses()
	_boss_index=clampi(_boss_index,0,bosses.size()-1)
	var boss:=GameData.get_boss(bosses[_boss_index])
	var boss_id:=String(boss.get("id","gravemaw"))
	_boss_title.text=LocalizationService.content_text("boss",boss_id,"name",String(boss.get("name","CRONUS")))
	_boss_subtitle.text=LocalizationService.content_text("boss",boss_id,"subtitle",String(boss.get("subtitle","THE GILDED HARVESTER")))

func _selected_boss_id()->String:
	return _unlocked_bosses()[_boss_index]

func _start_story()->void:
	var difficulty_ids:=["diver","deep","abyss"]
	start_requested.emit({"boss":_selected_boss_id(),"weapon":String(SaveManager.profile.get("selected_weapon","pulse_needle")),"difficulty":difficulty_ids[_difficulty.selected],"seed":randi_range(1,2147483000),"mode":"story"})

func _open_facility(id:String)->void:
	AudioManager.play_sfx("ui_confirm",1.0,0.55)
	match id:
		"hangar":_show_hangar()
		"forge":_show_forge()
		"research":_show_research()
		"rift":_show_rift()
		"trophies":_show_trophies()
		"core":_show_core()

func _overlay_box(title:String,subtitle:String="")->VBoxContainer:
	_clear_overlay()
	_overlay.visible=true
	var outer:=VBoxContainer.new();outer.layout_direction=LocalizationService.layout_direction();outer.add_theme_constant_override("separation",10);_overlay.add_child(outer)
	var head:=HBoxContainer.new();outer.add_child(head)
	var title_label:=VisualTheme.label(title,28);title_label.horizontal_alignment=LocalizationService.start_alignment();title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title_label)
	var close:=Button.new();close.name="OverlayClose";close.text="×";close.tooltip_text=LocalizationService.text("close");close.custom_minimum_size=Vector2(48,48);close.pressed.connect(_hide_overlay);head.add_child(close)
	if not subtitle.is_empty():
		var sub:=VisualTheme.label(subtitle,12,VisualTheme.MUTED);sub.horizontal_alignment=LocalizationService.start_alignment();sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;sub.custom_minimum_size.y=38;outer.add_child(sub)
	return outer

func _scroll_for(parent:VBoxContainer)->VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(scroll)
	var box:=VBoxContainer.new();box.layout_direction=LocalizationService.layout_direction();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8);scroll.add_child(box)
	return box

func _show_hangar()->void:
	var outer:=_overlay_box(LocalizationService.text("hangar"),LocalizationService.text("hangar_subtitle"))
	var box:=_scroll_for(outer)
	for raw_weapon in GameData.weapons:
		var weapon:Dictionary=raw_weapon
		var id:=String(weapon.id)
		var unlocked_weapons: Array = SaveManager.profile.get("unlocked_weapons",[])
		var unlocked: bool = unlocked_weapons.has(id)
		var cost:=int(weapon.get("unlock_shards",0))
		var button:=Button.new()
		button.custom_minimum_size.y=96;button.alignment=LocalizationService.start_alignment();button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.add_theme_font_size_override("font_size",13)
		var weapon_name:=LocalizationService.content_text("weapon",id,"name",String(weapon.name))
		var weapon_description:=LocalizationService.content_text("weapon",id,"description",String(weapon.description))
		var status:=LocalizationService.text("equipped") if String(SaveManager.profile.get("selected_weapon",""))==id else (LocalizationService.text("select") if unlocked else LocalizationService.text("unlock_shards",{"count":cost}))
		button.text="%s\n%s\n%s"%[weapon_name,weapon_description,status]
		button.add_theme_stylebox_override("normal",VisualTheme.panel_style(Color(Color(String(weapon.color)),0.08),16,Color(Color(String(weapon.color)),0.25)))
		button.pressed.connect(func():_select_or_unlock_weapon(id,cost))
		box.add_child(button)

func _select_or_unlock_weapon(id:String,cost:int)->void:
	var profile_before := SaveManager.profile.duplicate(true)
	var unlocked:Array=SaveManager.profile.get("unlocked_weapons",[])
	if not unlocked.has(id):
		if int(SaveManager.profile.get("core_shards",0))<cost:
			AudioManager.play_sfx("ui_error")
			return
		SaveManager.profile.core_shards=int(SaveManager.profile.core_shards)-cost
		unlocked.append(id);SaveManager.profile.unlocked_weapons=unlocked
	SaveManager.profile.selected_weapon=id
	if not SaveManager.save_profile():
		SaveManager.profile = profile_before
		AudioManager.play_sfx("ui_error")
		_show_hangar();_refresh_all()
		return
	AnalyticsService.track("weapon_selected",{"weapon":id})
	AudioManager.play_sfx("ui_confirm")
	_show_hangar();_refresh_all()

func _show_forge()->void:
	var outer:=_overlay_box(LocalizationService.text("forge"),LocalizationService.text("forge_subtitle"))
	var tutorial := _tutorial_from_profile()
	if tutorial.current_step_id() == TutorialFlowScript.STEP_DEFINITIONS[9].id:
		var prompt := VisualTheme.label(LocalizationService.text(String(tutorial.current_message_key())),13,VisualTheme.BIO)
		prompt.horizontal_alignment=LocalizationService.start_alignment();prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;prompt.custom_minimum_size.y=44;outer.add_child(prompt)
	var box:=_scroll_for(outer)
	var owned:Dictionary=SaveManager.profile.get("upgrades",{})
	for raw_upgrade in GameData.upgrades:
		var upgrade:Dictionary=raw_upgrade
		var id:=String(upgrade.id);var max_level:=int(upgrade.max_level)
		var gate: Dictionary = PermanentUpgradeEngineScript.purchase_gate(upgrade, owned)
		var level:=int(gate.get("level",0))
		var cost:=int(gate.get("cost",-1))
		var button:=Button.new();button.custom_minimum_size.y=88;button.alignment=LocalizationService.start_alignment();button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.add_theme_font_size_override("font_size",12)
		button.name="Upgrade_%s"%id
		var upgrade_name:=LocalizationService.content_text("upgrade",id,"name",String(upgrade.name))
		var upgrade_description:=LocalizationService.content_text("upgrade",id,"description",String(upgrade.description))
		var cost_text:=LocalizationService.text("maximum") if String(gate.get("reason",""))=="max_level" else LocalizationService.text("cost_bio",{"count":cost})
		if String(gate.get("reason",""))=="prerequisite":
			var requirement: Dictionary = gate.get("requires", {})
			var required_upgrade := GameData.get_upgrade(String(requirement.get("id","")))
			var required_name := LocalizationService.content_text("upgrade",String(requirement.get("id","")),"name",String(required_upgrade.get("name",requirement.get("id",""))))
			cost_text = LocalizationService.text("upgrade_requires", {"name":required_name,"level":int(requirement.get("level",1))})
		button.text="%s  %d/%d\n%s\n%s"%[upgrade_name,level,max_level,upgrade_description,cost_text]
		button.disabled=not bool(gate.get("allowed",false))
		button.add_theme_stylebox_override("normal",VisualTheme.panel_style(Color(VisualTheme.BIO,0.07),14,Color(VisualTheme.BIO,0.2)))
		button.pressed.connect(func():_buy_upgrade(id))
		box.add_child(button)

func _buy_upgrade(id:String)->void:
	var owned:Dictionary=SaveManager.profile.get("upgrades",{})
	var upgrade := GameData.get_upgrade(id)
	var gate: Dictionary = PermanentUpgradeEngineScript.purchase_gate(upgrade, owned)
	var level:=int(gate.get("level",0))
	var cost:=int(gate.get("cost",-1))
	if not bool(gate.get("allowed",false)) or int(SaveManager.profile.get("bio_matter",0))<cost:
		AudioManager.play_sfx("ui_error");return
	var profile_before := SaveManager.profile.duplicate(true)
	SaveManager.profile.bio_matter=int(SaveManager.profile.bio_matter)-cost
	owned[id]=level+1;SaveManager.profile.upgrades=owned
	var total_levels:=PermanentUpgradeEngineScript.normalized_total_levels(GameData.upgrades, owned)
	SaveManager.profile.nest_stage=clampi(maxi(int(SaveManager.profile.get("nest_stage",0)),total_levels/4),0,4)
	var tutorial := TutorialFlowScript.new()
	tutorial.restore_state(SaveManager.profile.get("tutorial_state", {"version":1,"understood_mask":0}))
	tutorial.restore_presentation(SaveManager.profile.get("tutorial_presentation", {"version":1,"replay_active":false,"replay_mask":0}))
	var was_replaying := tutorial.is_replaying()
	var tutorial_changed := tutorial.observe_event(TutorialFlowScript.EVENT_FORGE_PURCHASE)
	if tutorial_changed:
		SaveManager.profile.tutorial_state = tutorial.serialize_state()
		SaveManager.profile.tutorial_presentation = tutorial.serialize_presentation()
		SaveManager.profile.tutorial_step = tutorial.understood_count()
		SaveManager.profile.tutorial_complete = tutorial.is_complete()
	if not SaveManager.save_profile():
		SaveManager.profile = profile_before
		AudioManager.play_sfx("ui_error")
		_show_forge();_refresh_all()
		return
	if tutorial_changed:
		AnalyticsService.track("tutorial_step", {"step":10,"event":"forge_purchase","replay":was_replaying})
		if tutorial.is_complete():
			AnalyticsService.track("tutorial_complete")
	AnalyticsService.track("forge_purchase",{"upgrade":id,"level":level+1})
	AudioManager.play_sfx("mutation");SettingsManager.pulse_haptic(32,0.6)
	_show_forge();_refresh_all()

func _show_research()->void:
	var outer:=_overlay_box(LocalizationService.text("research"),LocalizationService.text("research_subtitle"))
	var box:=_scroll_for(outer)
	for raw_boss in GameData.bosses:
		var boss:Dictionary=raw_boss
		var boss_id:=String(boss.id)
		var title:=VisualTheme.label(LocalizationService.content_text("boss",boss_id,"name",String(boss.name)),18,Color(String(boss.palette[1])));title.horizontal_alignment=LocalizationService.start_alignment();box.add_child(title)
		for raw_organ in boss.organs:
			var organ:Dictionary=raw_organ
			var organ_id:=String(organ.id)
			var organ_name:=LocalizationService.content_text("organ",organ_id,"name",String(organ.name))
			var organ_effect:=LocalizationService.content_text("organ",organ_id,"effect",String(organ.effect))
			var text:=VisualTheme.label("%s — %s"%[organ_name,organ_effect],11,VisualTheme.MUTED);text.horizontal_alignment=LocalizationService.start_alignment();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.y=42;box.add_child(text)

func _show_rift()->void:
	var outer:=_overlay_box(LocalizationService.text("rift"),LocalizationService.text("rift_subtitle"))
	var preview:=_daily_challenge()
	var preview_boss:=GameData.get_boss(String(preview.boss))
	var preview_weapon:=GameData.get_weapon(String(preview.weapon))
	var daily:=Button.new();daily.name="DailyRiftButton";daily.text="%s\n%s · %s\n%s · %s\n%s"%[LocalizationService.text("daily"),LocalizationService.content_text("boss",String(preview.boss),"name",String(preview_boss.get("name",""))),LocalizationService.content_text("weapon",String(preview.weapon),"name",String(preview_weapon.get("name",""))),LocalizationService.text("seed_value",{"value":int(preview.seed)}),LocalizationService.text("daily_reset"),LocalizationService.text("daily_standard_profile",{"difficulty":LocalizationService.text(String(preview.difficulty))})];daily.custom_minimum_size.y=124;daily.pressed.connect(_start_daily);outer.add_child(daily)
	var input:=LineEdit.new();input.layout_direction=LocalizationService.layout_direction();input.alignment=LocalizationService.start_alignment();input.placeholder_text=LocalizationService.text("paste_code");input.custom_minimum_size.y=54;outer.add_child(input)
	var open:=Button.new();open.text=LocalizationService.text("open_rift");open.custom_minimum_size.y=58;open.pressed.connect(func():_open_friend_code(input.text));outer.add_child(open)
	var create:=Button.new();create.text=LocalizationService.text("create_friend_rift");create.custom_minimum_size.y=58;create.pressed.connect(_create_friend_code);outer.add_child(create)
	var contract_title := VisualTheme.label(LocalizationService.text("daily_contracts"),15,VisualTheme.BIO);contract_title.horizontal_alignment=LocalizationService.start_alignment();outer.add_child(contract_title)
	for raw_contract in _meta_goals.get_active_contracts():
		var contract: Dictionary = raw_contract
		var locale := "he" if LocalizationService.is_rtl() else "en"
		var title_map: Dictionary = contract.get("title", {})
		var contract_name := String(title_map.get(locale,title_map.get("en",contract.get("id",""))))
		var status := LocalizationService.text("completed") if bool(contract.get("completed",false)) else LocalizationService.text("goal_progress", {"value":int(contract.get("progress",0)),"target":int(contract.get("target",1))})
		var label := VisualTheme.label("%s · %s" % [contract_name,status],11,VisualTheme.BIO if bool(contract.get("completed",false)) else VisualTheme.MUTED);label.horizontal_alignment=LocalizationService.start_alignment();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.y=34;outer.add_child(label)

func _start_daily()->void:
	var challenge:=_daily_challenge()
	AnalyticsService.track("daily_rift_start",{"seed":int(challenge.seed),"ruleset":String(challenge.daily_ruleset_id)})
	challenge.challenge_id=ChallengeCode.daily_challenge_id(challenge,String(challenge.challenge_day_utc));start_requested.emit(challenge)

func _daily_challenge(utc_date:Dictionary={}) -> Dictionary:
	var use_date:=utc_date if not utc_date.is_empty() else Time.get_date_dict_from_system(true)
	var seed:=ChallengeCode.daily_seed(use_date)
	var boss:Dictionary=GameData.bosses[seed%GameData.bosses.size()]
	var weapon:Dictionary=GameData.weapons[(seed/7)%GameData.weapons.size()]
	var rules:=ChallengeCode.daily_standard_rules()
	return {
		"boss":String(boss.id),
		"weapon":String(weapon.id),
		"difficulty":String(rules.difficulty),
		"seed":seed,
		"mode":"daily",
		"competitive":true,
		"modifiers":(rules.modifiers as Array).duplicate(),
		"daily_ruleset_id":String(rules.id),
		"challenge_day_utc":ChallengeCode.utc_day_key(use_date),
	}

func _create_friend_code()->void:
	var challenge:={"boss":_selected_boss_id(),"weapon":String(SaveManager.profile.get("selected_weapon","pulse_needle")),"difficulty":"deep","seed":randi_range(1,2147483000),"modifiers":[]}
	var code:=ChallengeCode.encode(challenge);DisplayServer.clipboard_set(code);AnalyticsService.track("friend_rift_created",{"boss":challenge.boss});AudioManager.play_sfx("ui_confirm")
	var outer:=_overlay_box(LocalizationService.text("friend"),LocalizationService.text("friend_code_copied"));var label:=VisualTheme.label(code,12,VisualTheme.SHARD);label.horizontal_alignment=LocalizationService.start_alignment();label.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY;label.custom_minimum_size.y=120;outer.add_child(label)

func _open_friend_code(code:String)->void:
	var decoded:=ChallengeCode.decode(code)
	if decoded.is_empty():AudioManager.play_sfx("ui_error");return
	decoded.mode="friend";decoded.competitive=true;AnalyticsService.track("friend_rift_opened",{"boss":String(decoded.boss)});start_requested.emit(decoded)

func _show_trophies()->void:
	var outer:=_overlay_box(LocalizationService.text("trophies"),LocalizationService.text("trophies_subtitle"))
	var box:=_scroll_for(outer);var clears:Dictionary=SaveManager.profile.get("boss_clears",{})
	for raw_boss in GameData.bosses:
		var boss:Dictionary=raw_boss;var boss_id:=String(boss.id);var count:=int(clears.get(boss_id,0));var boss_name:=LocalizationService.content_text("boss",boss_id,"name",String(boss.name));var label:=VisualTheme.label("%s   ×%d"%[boss_name,count],20,Color(String(boss.palette[1])) if count>0 else VisualTheme.MUTED);label.horizontal_alignment=LocalizationService.start_alignment();box.add_child(label)
	var achievement_title := VisualTheme.label(LocalizationService.text("achievements"),17,VisualTheme.SHARD);achievement_title.horizontal_alignment=LocalizationService.start_alignment();box.add_child(achievement_title)
	var locale := "he" if LocalizationService.is_rtl() else "en"
	for raw_achievement in _meta_goals.get_achievement_status():
		var achievement: Dictionary = raw_achievement
		var title_map: Dictionary = achievement.get("title", {})
		var achievement_name := String(title_map.get(locale,title_map.get("en",achievement.get("id",""))))
		var status := LocalizationService.text("completed") if bool(achievement.get("completed",false)) else LocalizationService.text("goal_progress", {"value":int(achievement.get("progress",0)),"target":int(achievement.get("target",1))})
		var label := VisualTheme.label("%s · %s" % [achievement_name,status],11,VisualTheme.BIO if bool(achievement.get("completed",false)) else VisualTheme.MUTED);label.horizontal_alignment=LocalizationService.start_alignment();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.y=34;box.add_child(label)

func _show_core()->void:
	var outer:=_overlay_box(LocalizationService.text("core"),LocalizationService.text("core_subtitle"))
	var button:=Button.new();button.text=LocalizationService.text("abyss_loop") if bool(SaveManager.profile.get("abyss_unlocked",false)) else LocalizationService.text("locked");button.disabled=not bool(SaveManager.profile.get("abyss_unlocked",false));button.custom_minimum_size.y=80;button.pressed.connect(_start_abyss);outer.add_child(button)

func _start_abyss()->void:
	var seed:=randi_range(1,2147483000);start_requested.emit({"boss":"gravemaw","weapon":String(SaveManager.profile.get("selected_weapon","pulse_needle")),"difficulty":"abyss","seed":seed,"mode":"abyss","abyss_depth":1})

func _show_settings()->void:
	var outer:=_overlay_box(LocalizationService.text("settings"),LocalizationService.text("settings_subtitle"))
	var box:=_scroll_for(outer)
	_add_slider(box,"master_volume",0.0,1.0,0.05)
	_add_slider(box,"music_volume",0.0,1.0,0.05)
	_add_slider(box,"sfx_volume",0.0,1.0,0.05)
	_add_toggle(box,"haptics")
	_add_slider(box,"screen_shake",0.0,1.0,0.1)
	_add_toggle(box,"reduced_motion")
	_add_toggle(box,"projectile_contrast")
	_add_percent_slider(box,"damage_flash")
	_add_slider(box,"control_sensitivity",0.25,1.0,0.05)
	var assist_title:=VisualTheme.label(LocalizationService.text("assist_mode"),15,VisualTheme.FRIENDLY);assist_title.horizontal_alignment=LocalizationService.start_alignment();box.add_child(assist_title)
	_add_slider(box,"assist_projectile_speed",0.6,1.0,0.05)
	_add_slider(box,"assist_telegraph",1.0,1.6,0.1)
	_add_slider(box,"assist_dash_window",1.0,1.5,0.1)
	_add_toggle(box,"aim_assist")
	_add_toggle(box,"analytics_opt_in")
	_add_option(box,"dash_method",["button","double_tap","flick"],["dash_button","dash_double_tap","dash_flick"])
	_add_option(box,"handedness",["right","left"],["hand_right","hand_left"])
	var language_row:=HBoxContainer.new();language_row.name="LanguageSelector";language_row.layout_direction=LocalizationService.layout_direction();box.add_child(language_row)
	var language_title:=VisualTheme.label(LocalizationService.text("language"),12);language_title.horizontal_alignment=LocalizationService.start_alignment();language_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;language_row.add_child(language_title)
	var language_option:=OptionButton.new();language_option.name="LanguageOption";language_option.layout_direction=LocalizationService.layout_direction();language_option.custom_minimum_size=Vector2(176,58);language_option.add_item(LocalizationService.text("english"));language_option.add_item(LocalizationService.text("hebrew"));language_option.selected=0 if LocalizationService.current_locale()=="en" else 1;language_option.item_selected.connect(_select_language);language_row.add_child(language_option)
	var tutorial_replay:=Button.new();tutorial_replay.alignment=LocalizationService.start_alignment();tutorial_replay.text=LocalizationService.text("tutorial_replay");tutorial_replay.custom_minimum_size.y=54;tutorial_replay.pressed.connect(_request_tutorial_replay);box.add_child(tutorial_replay)
	var support:=Button.new();support.alignment=LocalizationService.start_alignment();support.text=LocalizationService.text("support_feedback");support.custom_minimum_size.y=54;support.pressed.connect(func():_open_public_page("support.html"));box.add_child(support)
	var privacy:=Button.new();privacy.alignment=LocalizationService.start_alignment();privacy.text=LocalizationService.text("privacy_policy");privacy.custom_minimum_size.y=54;privacy.pressed.connect(func():_open_public_page("privacy.html"));box.add_child(privacy)
	var terms:=Button.new();terms.name="TermsLink";terms.alignment=LocalizationService.start_alignment();terms.text="תנאי שימוש" if LocalizationService.is_rtl() else "Terms of Use";terms.custom_minimum_size.y=54;terms.pressed.connect(func():_open_public_page("terms.html"));box.add_child(terms)
	var notices:=Button.new();notices.name="NoticesLink";notices.alignment=LocalizationService.start_alignment();notices.text="הודעות קוד פתוח" if LocalizationService.is_rtl() else "Open-Source Notices";notices.custom_minimum_size.y=54;notices.pressed.connect(func():_open_public_page("notices.html"));box.add_child(notices)
	var reset:=Button.new();reset.alignment=LocalizationService.start_alignment();reset.text=LocalizationService.text("reset_progress");reset.custom_minimum_size.y=54;reset.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(VisualTheme.ENEMY,0.16),16));reset.pressed.connect(_show_reset_confirmation);box.add_child(reset)

func _add_slider(parent:VBoxContainer,key:String,min_value:float,max_value:float,step:float)->void:
	var row:=VBoxContainer.new();row.layout_direction=LocalizationService.layout_direction();parent.add_child(row);var title:=VisualTheme.label(LocalizationService.text(key),12,VisualTheme.TEXT);title.horizontal_alignment=LocalizationService.start_alignment();row.add_child(title);var slider:=HSlider.new();slider.min_value=min_value;slider.max_value=max_value;slider.step=step;slider.value=float(SettingsManager.get_value(key,max_value));slider.value_changed.connect(func(value:float):SettingsManager.set_value(key,value));row.add_child(slider)

func _add_percent_slider(parent:VBoxContainer,key:String)->void:
	var row:=VBoxContainer.new()
	row.layout_direction=LocalizationService.layout_direction()
	parent.add_child(row)
	var title:=VisualTheme.label("",12,VisualTheme.TEXT)
	title.horizontal_alignment=LocalizationService.start_alignment()
	row.add_child(title)
	var slider:=HSlider.new()
	slider.name="%sPercent"%key.to_pascal_case()
	slider.min_value=0.0
	slider.max_value=100.0
	slider.step=10.0
	slider.value=SettingsManager.damage_flash_intensity()*100.0 if key=="damage_flash" else clampf(float(SettingsManager.get_value(key,1.0)),0.0,1.0)*100.0
	var update_title:=func(percent:float)->void:
		title.text="%s — %d%%"%[LocalizationService.text(key),roundi(percent)]
	update_title.call(slider.value)
	slider.value_changed.connect(func(percent:float):
		var previous:=float(SettingsManager.get_value(key,0.0))*100.0
		if not SettingsManager.set_value(key,percent/100.0):
			slider.set_value_no_signal(previous)
			update_title.call(previous)
			AudioManager.play_sfx("ui_error")
			return
		update_title.call(percent)
		AnalyticsService.track("settings_changed",{"setting":key})
	)
	row.add_child(slider)

func _add_toggle(parent:VBoxContainer,key:String)->void:
	var toggle:=CheckButton.new();toggle.layout_direction=LocalizationService.layout_direction();toggle.text=LocalizationService.text(key);toggle.button_pressed=_toggle_display_value(key);toggle.toggled.connect(func(value:bool):
		_apply_toggle_value(key,value)
		# Reconcile from the actual stored state instead of assuming that every
		# failure rolled the preference back. Analytics cleanup can fail after the
		# opt-out itself was durably saved, and must remain visibly OFF in that case.
		_sync_toggle_display(toggle,key)
	);parent.add_child(toggle)

func _toggle_display_value(key:String)->bool:
	var stored_value: Variant = SettingsManager.get_value(key,false)
	if key=="analytics_opt_in":
		return typeof(stored_value)==TYPE_BOOL and stored_value==true
	return bool(stored_value)

func _sync_toggle_display(toggle:CheckButton,key:String)->void:
	toggle.set_pressed_no_signal(_toggle_display_value(key))

func _clear_analytics_local_data()->bool:
	return AnalyticsService.clear_local_data()

func _apply_toggle_value(key:String,value:bool)->bool:
	# Persist opt-out before attempting deletion so no new diagnostics can enter
	# the queue even if the filesystem refuses the cleanup. The error cue makes
	# that rare failure observable, and AnalyticsService retries it at next boot.
	if not SettingsManager.set_value(key,value):
		AudioManager.play_sfx("ui_error")
		return false
	if key=="analytics_opt_in" and not value:
		if not _clear_analytics_local_data():
			AudioManager.play_sfx("ui_error")
			return false
	AnalyticsService.track("settings_changed",{"setting":key})
	return true

func _add_option(parent:VBoxContainer,key:String,ids:Array,label_keys:Array)->void:
	var row:=HBoxContainer.new()
	row.layout_direction=LocalizationService.layout_direction()
	parent.add_child(row)
	var title:=VisualTheme.label(LocalizationService.text(key),12)
	title.horizontal_alignment=LocalizationService.start_alignment()
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var option:=OptionButton.new()
	option.layout_direction=LocalizationService.layout_direction()
	for label_key in label_keys:
		option.add_item(LocalizationService.text(String(label_key)))
	var current:=ids.find(SettingsManager.get_value(key,ids[0]))
	option.selected=maxi(0,current)
	option.item_selected.connect(func(index:int):SettingsManager.set_value(key,ids[index]);AnalyticsService.track("settings_changed",{"setting":key}))
	row.add_child(option)

func _select_language(index:int)->void:
	var languages:=["en","he"]
	if index<0 or index>=languages.size():
		AudioManager.play_sfx("ui_error")
		return
	var requested:=String(languages[index])
	if requested==LocalizationService.current_locale():
		return
	if not SettingsManager.set_value("language",requested):
		AudioManager.play_sfx("ui_error")
		_show_settings()
		return
	AnalyticsService.track("settings_changed",{"setting":"language"})
	_show_settings();_refresh_all()

func _request_tutorial_replay()->void:
	SaveManager.profile.tutorial_replay_requested = true
	SaveManager.profile.tutorial_presentation = {"version":1,"replay_active":false,"replay_mask":0}
	SaveManager.save_profile()
	AudioManager.play_sfx("ui_confirm")
	_show_settings()

func _tutorial_from_profile() -> TutorialFlow:
	var tutorial: TutorialFlow = TutorialFlowScript.new()
	tutorial.restore_state(SaveManager.profile.get("tutorial_state", {"version":1,"understood_mask":0}))
	tutorial.restore_presentation(SaveManager.profile.get("tutorial_presentation", {"version":1,"replay_active":false,"replay_mask":0}))
	return tutorial

func _show_reset_confirmation()->void:
	var outer := _overlay_box(LocalizationService.text("reset_progress"), LocalizationService.text("reset_warning"))
	var confirm := Button.new();confirm.text=LocalizationService.text("reset_confirm");confirm.custom_minimum_size.y=72;confirm.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(VisualTheme.ENEMY,0.34),18));confirm.pressed.connect(_confirm_reset_progress);outer.add_child(confirm)
	var cancel := Button.new();cancel.text=LocalizationService.text("cancel");cancel.custom_minimum_size.y=60;cancel.pressed.connect(_show_settings);outer.add_child(cancel)

func _confirm_reset_progress()->void:
	if not SaveManager.reset_progress():
		AudioManager.play_sfx("ui_error")
		return
	# The profile, analytics queue, and every leaderboard recovery generation
	# are distinct stores. Report failure unless all local-data stores clear.
	var analytics_cleared := AnalyticsService.clear_local_data()
	var leaderboard_cleared := LeaderboardService.clear_local_data()
	SettingsManager.values = SaveManager.profile.settings.duplicate(true)
	SettingsManager.apply_all()
	_meta_goals = MetaGoalServiceScript.new()
	_meta_goals.initialize(SaveManager.profile)
	if not analytics_cleared or not leaderboard_cleared:
		AudioManager.play_sfx("ui_error")
		return
	_hide_overlay()
	_refresh_all()
	AudioManager.play_sfx("ui_confirm")

func _open_public_page(page_name:String)->void:
	var target:=page_name if OS.has_feature("web") else NATIVE_PUBLIC_SITE_BASE+page_name
	if OS.shell_open(target)!=OK:
		AudioManager.play_sfx("ui_error")

func _hide_overlay()->void:
	_overlay.visible=false;_clear_overlay()

func _clear_overlay()->void:
	for child in _overlay.get_children():child.queue_free()

func _draw()->void:
	var canvas_width:=size.x if size.x>0 else 540.0
	var canvas_height:=size.y if size.y>0 else 960.0
	var stage:=clampi(int(SaveManager.profile.get("nest_stage",0)),0,4)
	draw_rect(Rect2(0,0,canvas_width,canvas_height),Color("#102D4D"))
	_draw_sky_background(stage)
	_draw_floating_island(stage)
	_draw_temple_frame(stage)
	_draw_divine_paths(stage)
	_draw_sanctuary_growth(stage)
	for facility_value in FACILITIES:
		var facility:Dictionary=facility_value
		var unlocked:=stage>=int(facility.stage)
		if String(facility.id)=="core" and bool(SaveManager.profile.get("abyss_unlocked",false)):
			unlocked=true
		_draw_facility(facility,unlocked,stage)
	_draw_island_edge(stage)

func _draw_sky_background(stage:int)->void:
	var sky_top:=Color("#3F91C5").lerp(Color("#5BCDE1"),float(stage)/5.0)
	var sky_bottom:=Color("#B9E9EE").lerp(Color("#E5FFF4"),float(stage)/5.0)
	for band in 14:
		var amount:=float(band)/13.0
		draw_rect(Rect2(0,154.0+amount*446.0,540,36),sky_top.lerp(sky_bottom,amount))
	var sun:=Vector2(442,214)
	for halo in range(4,0,-1):
		draw_circle(sun,26.0+halo*13.0,Color("#FFF1A8",0.028+stage*0.008))
	draw_circle(sun,25.0,Color("#FFF0A3"))
	draw_circle(sun-Vector2(5,5),8.0,Color("#FFFCE2",0.85))
	for cloud in 5:
		var cloud_x:=34.0+cloud*126.0
		var cloud_y:=218.0+(cloud%2)*73.0+sin(_time*0.18+cloud)*2.5
		_draw_cloud(Vector2(cloud_x,cloud_y),0.72+cloud%3*0.14,0.42)
	# Tiny distant islands establish a playful sky-world without competing with
	# the interactive sanctuary in the foreground.
	for distant in 3:
		var distant_center:=Vector2(92+distant*178,278+distant%2*42)
		draw_colored_polygon(PackedVector2Array([
			distant_center+Vector2(-26,0),distant_center+Vector2(25,0),
			distant_center+Vector2(10,18),distant_center+Vector2(0,29),
			distant_center+Vector2(-13,17)
		]),Color("#52798D",0.28))
		draw_line(distant_center+Vector2(-23,-2),distant_center+Vector2(22,-2),Color("#EAF8E4",0.45),3.0,true)

func _draw_cloud(center:Vector2,scale_value:float,alpha:float)->void:
	var shade:=Color("#C6E4EA",alpha*0.72)
	var light:=Color("#F8FFFB",alpha)
	draw_circle(center+Vector2(0,6)*scale_value,24.0*scale_value,shade)
	draw_circle(center+Vector2(-20,0)*scale_value,17.0*scale_value,light)
	draw_circle(center+Vector2(2,-10)*scale_value,23.0*scale_value,light)
	draw_circle(center+Vector2(25,2)*scale_value,16.0*scale_value,light)
	draw_rect(Rect2(center+Vector2(-28,-2)*scale_value,Vector2(56,20)*scale_value),light)

func _draw_floating_island(stage:int)->void:
	var island_top:=PackedVector2Array([
		Vector2(44,259),Vector2(115,231),Vector2(211,241),Vector2(270,225),
		Vector2(338,241),Vector2(431,231),Vector2(500,264),Vector2(520,468),
		Vector2(483,526),Vector2(270,568),Vector2(56,526),Vector2(20,468)
	])
	draw_colored_polygon(island_top,Color("#183F59",0.35))
	var terrace:=PackedVector2Array([
		Vector2(47,270),Vector2(493,270),Vector2(511,470),Vector2(475,514),
		Vector2(270,548),Vector2(65,514),Vector2(29,470)
	])
	draw_colored_polygon(terrace,Color("#DDE5D7"))
	var lawn:=PackedVector2Array([
		Vector2(58,282),Vector2(482,282),Vector2(494,462),Vector2(462,496),
		Vector2(270,528),Vector2(78,496),Vector2(46,462)
	])
	draw_colored_polygon(lawn,Color("#7BCB8B").lerp(Color("#9BE39D"),float(stage)*0.09))
	draw_polyline(_closed_polygon(terrace),Color("#173B55"),7.0,true)
	draw_polyline(_closed_polygon(lawn),Color("#F8F1D8"),4.0,true)
	# Marble terraces and bronze inlay make the home feel like a place rather
	# than a menu while keeping every facility in a readable pocket.
	for step in 3:
		var radius:=64.0+step*30.0
		draw_arc(Vector2(270,376),radius,0,TAU,44,Color("#F6F0D8",0.42-step*0.07),8.0-step,true)
		draw_arc(Vector2(270,376),radius,0,TAU,44,Color("#B97832",0.25+stage*0.025),2.0,true)
	# Rocky underside and a few bright waterfalls sell the floating island.
	draw_colored_polygon(PackedVector2Array([
		Vector2(57,516),Vector2(270,568),Vector2(483,516),Vector2(407,551),
		Vector2(347,574),Vector2(270,600),Vector2(193,574),Vector2(125,551)
	]),Color("#728697"))
	draw_polyline(PackedVector2Array([Vector2(57,516),Vector2(270,568),Vector2(483,516)]),Color("#F7EED5"),6.0,true)
	if stage>=2:
		for fall in 3:
			var fall_x:=183.0+fall*87.0
			var fall_length:=22.0+fall%2*12.0
			draw_line(Vector2(fall_x,548),Vector2(fall_x+sin(_time*0.4+fall)*2.0,548+fall_length),Color("#BDF9FA",0.78),5.0,true)
			draw_circle(Vector2(fall_x,548+fall_length),4.0,Color("#E7FFFF",0.7))

func _draw_temple_frame(stage:int)->void:
	# Broken columns remain in state zero; each restoration tier raises a more
	# complete, festive sanctuary around the same familiar touch layout.
	var column_height:=50.0+stage*5.0
	for side in [-1,1]:
		var x:=33.0 if side<0 else 507.0
		var top_y:=326.0-column_height
		_draw_temple_column(Vector2(x,326),column_height,stage>0)
		if stage>=1:
			draw_line(Vector2(x,top_y),Vector2(103 if side<0 else 437,246),Color("#F7F0D8"),8.0,true)
			draw_line(Vector2(x,top_y-2),Vector2(103 if side<0 else 437,244),Color("#B97832"),2.0,true)
	if stage==0:
		draw_colored_polygon(PackedVector2Array([Vector2(46,505),Vector2(77,487),Vector2(103,512)]),Color("#AAB3AA"))
		draw_colored_polygon(PackedVector2Array([Vector2(418,500),Vector2(458,486),Vector2(485,514)]),Color("#929F9B"))
		draw_polyline(PackedVector2Array([Vector2(252,350),Vector2(267,360),Vector2(260,377)]),Color("#5A6670"),3.0,true)
	if stage>=3:
		var banner_colors:=[Color("#24B8C7"),Color("#FF7759"),Color("#F3BE45"),Color("#8369D8")]
		for banner in 4:
			var banner_x:=174.0+banner*64.0
			draw_line(Vector2(banner_x,237),Vector2(banner_x+32,237),Color("#B97832"),3.0,true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(banner_x+2,239),Vector2(banner_x+30,239),Vector2(banner_x+25,262),
				Vector2(banner_x+16,255),Vector2(banner_x+7,262)
			]),banner_colors[banner])

func _draw_temple_column(base:Vector2,height:float,restored:bool)->void:
	var column_color:=Color("#F7F0D8") if restored else Color("#C4C8BB")
	draw_rect(Rect2(base+Vector2(-12,-height),Vector2(24,height)),Color("#173B55"))
	draw_rect(Rect2(base+Vector2(-9,-height+2),Vector2(18,height-4)),column_color)
	for groove in 3:
		draw_line(base+Vector2(-5+groove*5,-height+6),base+Vector2(-5+groove*5,-6),Color("#AFC4BB",0.72),1.5)
	draw_rect(Rect2(base+Vector2(-16,-height-7),Vector2(32,10)),Color("#173B55"))
	draw_rect(Rect2(base+Vector2(-13,-height-5),Vector2(26,6)),Color("#D99B46" if restored else "#A9ADA3"))
	draw_rect(Rect2(base+Vector2(-15,-5),Vector2(30,8)),Color("#E7DABF"))

func _draw_divine_paths(stage:int)->void:
	var altar:=Vector2(270,371)
	for facility_value in FACILITIES:
		var facility:Dictionary=facility_value
		var unlocked:=stage>=int(facility.stage)
		if String(facility.id)=="core" and bool(SaveManager.profile.get("abyss_unlocked",false)):
			unlocked=true
		var target:=Vector2(facility.position)
		var control:=Vector2((altar.x+target.x)*0.5,altar.y+(target.y-altar.y)*0.22)
		var path:=_quadratic_curve(altar,control,target,18)
		draw_polyline(path,Color("#F8F1D8",0.88),12.0,true)
		draw_polyline(path,Color("#B97832",0.68 if unlocked else 0.22),3.0,true)
		if unlocked and stage>0:
			var flow:=fposmod(_time*0.18+float(String(facility.id).hash()%17)/17.0,1.0)
			var light_position:=_quadratic_point(altar,control,target,flow)
			draw_circle(light_position,5.0,Color("#FFFFFF",0.8))
			draw_circle(light_position,3.0,Color("#38D5D5"))

func _draw_sanctuary_growth(stage:int)->void:
	_draw_aether_altar(stage)
	if stage>=2:
		for workshop in 3:
			var x:=92.0+workshop*178.0
			var y:=526.0-workshop%2*7.0
			draw_circle(Vector2(x,y),15.0,Color("#173B55"))
			draw_circle(Vector2(x,y),11.0,Color("#D99B46"))
			for tooth in 6:
				var angle:=tooth*TAU/6.0+_time*0.12
				draw_line(Vector2(x,y)+Vector2.from_angle(angle)*10.0,Vector2(x,y)+Vector2.from_angle(angle)*16.0,Color("#B97832"),4.0,true)
	if stage>=3:
		for keeper in 4:
			var keeper_x:=115.0+keeper*104.0
			var keeper_y:=552.0-(keeper%2)*5.0
			var sway:=sin(_time*0.7+keeper)*1.5
			draw_circle(Vector2(keeper_x+sway,keeper_y-12),5.0,Color("#F1C49D"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(keeper_x-6+sway,keeper_y-6),Vector2(keeper_x+6+sway,keeper_y-6),
				Vector2(keeper_x+10+sway,keeper_y+10),Vector2(keeper_x-10+sway,keeper_y+10)
			]),Color("#39B9C4") if keeper%2==0 else Color("#FF7759"))
	if stage>=4:
		for laurel in 9:
			var root:=Vector2(42+laurel*57,508+laurel%2*12)
			var lean:=sin(_time*0.35+laurel)*4.0
			draw_line(root,root+Vector2(lean,-24),Color("#2D845B"),3.0,true)
			draw_circle(root+Vector2(lean-5,-14),5.0,Color("#77D47C"))
			draw_circle(root+Vector2(lean+5,-20),5.0,Color("#9BE38C"))
		for star in 7:
			var angle:=star*TAU/7.0+_time*0.08
			var star_position:=Vector2(270,211)+Vector2.from_angle(angle)*Vector2(55,25)
			draw_circle(star_position,2.6,Color("#FFF3A6",0.9))

func _draw_aether_altar(stage:int)->void:
	var center:=Vector2(270,371)
	draw_circle(center+Vector2(0,4),44.0,Color("#173B55"))
	draw_circle(center,40.0,Color("#F8F1D8"))
	draw_arc(center,34.0,0,TAU,36,Color("#B97832"),5.0,true)
	for spoke in 8:
		var angle:=spoke*TAU/8.0
		draw_line(center+Vector2.from_angle(angle)*21.0,center+Vector2.from_angle(angle)*32.0,Color("#D99B46"),4.0,true)
	if stage==0:
		draw_circle(center,16.0,Color("#9BA8A7"))
		draw_polyline(PackedVector2Array([center+Vector2(-11,-7),center+Vector2(1,0),center+Vector2(-5,15)]),Color("#556A77"),3.0,true)
		return
	var breath:=1.0+sin(_time*1.2)*0.055
	draw_circle(center,28.0*breath,Color("#45D7D2",0.24+stage*0.035))
	draw_circle(center,19.0*breath,Color("#173B55"))
	draw_colored_polygon(PackedVector2Array([
		center+Vector2(0,-24),center+Vector2(10,-3),center+Vector2(4,15),
		center+Vector2(-4,15),center+Vector2(-10,-3)
	]),Color("#47E2DE"))
	draw_line(center+Vector2(0,-19),center+Vector2(0,10),Color("#F4FFFF",0.84),2.0,true)
	for halo in stage:
		var radius:=48.0+halo*7.0
		var phase:=_time*(0.13+halo*0.025)*(-1.0 if halo%2 else 1.0)
		draw_arc(center,radius,phase,phase+PI*1.4,32,Color("#F2BE4D",0.35+halo*0.035),3.0,true)

func _quadratic_curve(start:Vector2,control:Vector2,end:Vector2,segments:int)->PackedVector2Array:
	var points:=PackedVector2Array()
	for segment in segments+1:
		points.append(_quadratic_point(start,control,end,float(segment)/float(segments)))
	return points

func _quadratic_point(start:Vector2,control:Vector2,end:Vector2,amount:float)->Vector2:
	var inverse:=1.0-amount
	return start*inverse*inverse+control*2.0*inverse*amount+end*amount*amount

func _facility_color(id:String)->Color:
	match id:
		"hangar":return Color("#24B8C7")
		"forge":return Color("#FF7759")
		"research":return Color("#4DCB88")
		"rift":return Color("#8369D8")
		"trophies":return Color("#F3BE45")
		"core":return Color("#E84D83")
	return Color("#24B8C7")

func _draw_facility(facility:Dictionary,unlocked:bool,stage:int)->void:
	var id:=String(facility.id)
	var center:=Vector2(facility.position)
	var accent:=_facility_color(id)
	var energy:=accent.lightened(0.1) if unlocked else Color("#91A5A5")
	var plinth:=PackedVector2Array([
		center+Vector2(-42,15),center+Vector2(-32,-25),center+Vector2(31,-25),
		center+Vector2(42,15),center+Vector2(35,28),center+Vector2(-35,28)
	])
	var shadow:=PackedVector2Array()
	for point in plinth:
		shadow.append(point+Vector2(0,5))
	draw_colored_polygon(shadow,Color("#173B55",0.48))
	draw_colored_polygon(plinth,Color("#F7F0D8") if unlocked else Color("#C8CFCA"))
	draw_polyline(_closed_polygon(plinth),Color("#173B55"),6.0,true)
	draw_polyline(_closed_polygon(plinth),Color("#B97832" if unlocked else "#829096"),3.0,true)
	if unlocked:
		draw_circle(center-Vector2(0,5),34.0+sin(_time*0.8+float(id.hash()%7))*1.2,Color(accent,0.12+stage*0.012))
	match id:
		"hangar":_draw_hangar_facility(center,energy,unlocked)
		"forge":_draw_forge_facility(center,energy,unlocked)
		"research":_draw_research_facility(center,energy,unlocked)
		"rift":_draw_rift_facility(center,energy,unlocked)
		"trophies":_draw_trophy_facility(center,energy,unlocked)
		"core":_draw_core_facility(center,energy,unlocked)

func _draw_hangar_facility(center:Vector2,color:Color,unlocked:bool)->void:
	# Winged launch gate: a mythic-tech dock for the Diver craft.
	draw_arc(center+Vector2(0,-5),24.0,PI,TAU,22,Color("#173B55"),8.0,true)
	draw_arc(center+Vector2(0,-5),24.0,PI,TAU,22,Color(color,0.95 if unlocked else 0.34),4.0,true)
	for side in [-1,1]:
		var wing:=PackedVector2Array([
			center+Vector2(side*7,-10),center+Vector2(side*25,-23),
			center+Vector2(side*20,-8),center+Vector2(side*31,-5),
			center+Vector2(side*9,2)
		])
		draw_colored_polygon(wing,Color(color,0.9 if unlocked else 0.25))
		draw_polyline(_closed_polygon(wing),Color("#173B55"),3.0,true)
	var craft:=PackedVector2Array([center+Vector2(0,-19),center+Vector2(8,5),center+Vector2(0,11),center+Vector2(-8,5)])
	draw_colored_polygon(craft,Color("#FFF5D8") if unlocked else Color("#9BA9A8"))
	draw_polyline(_closed_polygon(craft),Color("#173B55"),3.0,true)

func _draw_forge_facility(center:Vector2,color:Color,unlocked:bool)->void:
	# Hephaestian brazier and anvil, readable even at phone scale.
	var bowl:=PackedVector2Array([center+Vector2(-22,2),center+Vector2(22,2),center+Vector2(13,15),center+Vector2(-13,15)])
	draw_colored_polygon(bowl,Color("#B97832") if unlocked else Color("#879493"))
	draw_polyline(_closed_polygon(bowl),Color("#173B55"),4.0,true)
	var flame_height:=sin(_time*1.6)*2.0
	var flame:=PackedVector2Array([
		center+Vector2(-10,1),center+Vector2(-4,-18-flame_height),center+Vector2(1,-10),
		center+Vector2(8,-27+flame_height),center+Vector2(12,0)
	])
	draw_colored_polygon(flame,Color(color,0.95 if unlocked else 0.25))
	draw_polyline(flame,Color("#FFD66E",0.8 if unlocked else 0.16),2.0,true)
	draw_line(center+Vector2(-13,-23),center+Vector2(14,-23),Color("#173B55"),6.0,true)
	draw_line(center+Vector2(7,-30),center+Vector2(7,-14),Color("#D99B46" if unlocked else "#879493"),4.0,true)

func _draw_research_facility(center:Vector2,color:Color,unlocked:bool)->void:
	# Oracle basin with a floating constellation sphere.
	draw_colored_polygon(PackedVector2Array([center+Vector2(-23,7),center+Vector2(23,7),center+Vector2(14,17),center+Vector2(-14,17)]),Color("#B97832" if unlocked else "#889493"))
	draw_arc(center+Vector2(0,5),22.0,0,PI,24,Color("#173B55"),6.0,true)
	draw_arc(center+Vector2(0,5),19.0,0,PI,24,Color(color,0.94 if unlocked else 0.25),4.0,true)
	draw_circle(center+Vector2(0,-13),12.0,Color("#173B55"))
	draw_circle(center+Vector2(0,-13),9.0,Color(color,0.72 if unlocked else 0.18))
	for star in 3:
		var angle:=_time*0.35+star*TAU/3.0
		draw_circle(center+Vector2(0,-13)+Vector2.from_angle(angle)*6.0,1.7,Color("#FFF7CE",0.9 if unlocked else 0.2))

func _draw_rift_facility(center:Vector2,color:Color,unlocked:bool)->void:
	for ring in 3:
		var offset:=_time*(0.35+ring*0.08)*(-1.0 if ring%2 else 1.0)
		draw_arc(center+Vector2(0,-5),13.0+ring*7.0,offset,offset+PI*1.55,24,Color("#173B55"),6.0-ring*0.35,true)
		draw_arc(center+Vector2(0,-5),13.0+ring*7.0,offset,offset+PI*1.55,24,Color(color,(0.94-ring*0.14) if unlocked else 0.22),3.0-ring*0.45,true)
	if unlocked:
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-20),center+Vector2(8,-5),center+Vector2(0,10),center+Vector2(-8,-5)]),Color("#E9DFFF",0.72))
	for foot in [-1,1]:
		draw_line(center+Vector2(foot*20,9),center+Vector2(foot*26,20),Color("#B97832" if unlocked else "#879493"),5.0,true)

func _draw_trophy_facility(center:Vector2,color:Color,unlocked:bool)->void:
	# Victory shrine: shield, spear and paired laurel branches.
	draw_circle(center+Vector2(0,-6),17.0,Color("#173B55"))
	draw_circle(center+Vector2(0,-6),13.0,Color(color,0.86 if unlocked else 0.2))
	draw_colored_polygon(PackedVector2Array([center+Vector2(-8,-11),center+Vector2(8,-11),center+Vector2(6,2),center+Vector2(0,9),center+Vector2(-6,2)]),Color("#FFF3CB" if unlocked else "#9AA5A2"))
	for side in [-1,1]:
		draw_arc(center+Vector2(side*9,-4),20.0,-PI*0.65 if side<0 else PI*0.65,PI*0.05 if side<0 else PI*1.35,18,Color("#4FAE69" if unlocked else "#879493"),3.0,true)
	draw_line(center+Vector2(-23,-25),center+Vector2(20,17),Color("#B97832" if unlocked else "#879493"),4.0,true)

func _draw_core_facility(center:Vector2,color:Color,unlocked:bool)->void:
	for ring in 2:
		var phase:=_time*(0.2+ring*0.08)*(-1.0 if ring else 1.0)
		draw_arc(center+Vector2(0,-4),25.0-ring*8.0,phase,phase+PI*1.45,26,Color("#173B55"),7.0-ring,true)
		draw_arc(center+Vector2(0,-4),25.0-ring*8.0,phase,phase+PI*1.45,26,Color(color,(0.88-ring*0.15) if unlocked else 0.18),3.5,true)
	var crystal:=PackedVector2Array([center+Vector2(0,-27),center+Vector2(11,-5),center+Vector2(4,17),center+Vector2(-4,17),center+Vector2(-11,-5)])
	draw_colored_polygon(crystal,Color(color,0.8 if unlocked else 0.16))
	draw_polyline(_closed_polygon(crystal),Color("#173B55"),3.0,true)
	draw_line(center+Vector2(0,-23),center+Vector2(0,13),Color(1,1,1,0.72 if unlocked else 0.08),2.0,true)

func _draw_island_edge(stage:int)->void:
	_draw_cloud(Vector2(42,585+sin(_time*0.17)*2.0),1.15,0.76)
	_draw_cloud(Vector2(498,588+sin(_time*0.17+2.0)*2.0),1.18,0.76)
	draw_line(Vector2(0,602),Vector2(540,602),Color("#EAFBFA",0.72),4.0,true)
	draw_line(Vector2(68,597),Vector2(472,597),Color("#D99B46",0.34+stage*0.035),2.0,true)

func _closed_polygon(points:PackedVector2Array)->PackedVector2Array:
	var closed:=PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed
