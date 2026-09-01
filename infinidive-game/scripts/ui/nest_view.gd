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
	settings_button.text="⚙"
	settings_button.position=Vector2(472,82)
	settings_button.size=Vector2(48,48)
	settings_button.add_theme_font_size_override("font_size",20)
	settings_button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(0.06,0.08,0.13,0.82),20))
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
		button.position=Vector2(facility.position)-Vector2(45,32)
		button.size=Vector2(90,64)
		button.add_theme_font_size_override("font_size",9)
		button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(VisualTheme.FRIENDLY,0.08),28))
		button.add_theme_stylebox_override("hover",VisualTheme.button_style(Color(VisualTheme.FRIENDLY,0.17),28))
		var facility_id:=String(facility.id)
		button.pressed.connect(func():_open_facility(facility_id))
		add_child(button)
		_facility_buttons[facility_id]=button

	var boss_panel:=PanelContainer.new()
	boss_panel.position=Vector2(18,606)
	boss_panel.size=Vector2(504,184)
	boss_panel.add_theme_stylebox_override("panel",VisualTheme.panel_style(Color(0.025,0.04,0.08,0.95),25,Color(VisualTheme.VULNERABLE,0.22)))
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
		button.text=LocalizationService.text(String(facility.key)) if unlocked else LocalizationService.text("locked")
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
	_boss_title.text=LocalizationService.content_text("boss",boss_id,"name",String(boss.get("name","GRAVEMAW")))
	_boss_subtitle.text=LocalizationService.content_text("boss",boss_id,"subtitle",String(boss.get("subtitle","THE ORBITAL DEVOURER")))

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
	var daily:=Button.new();daily.text="%s\n%s · %s"%[LocalizationService.text("daily"),LocalizationService.text("seed_value",{"value":ChallengeCode.daily_seed()}),LocalizationService.text("daily_reset")];daily.custom_minimum_size.y=76;daily.pressed.connect(_start_daily);outer.add_child(daily)
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
	var utc_date:=Time.get_date_dict_from_system(true);var seed:=ChallengeCode.daily_seed(utc_date);var boss:Dictionary=GameData.bosses[seed%GameData.bosses.size()];var weapon:Dictionary=GameData.weapons[(seed/7)%GameData.weapons.size()]
	AnalyticsService.track("daily_rift_start",{"seed":seed})
	var challenge:={"boss":String(boss.id),"weapon":String(weapon.id),"difficulty":"deep","seed":seed,"mode":"daily","competitive":true,"modifiers":["daily_standard"],"challenge_day_utc":ChallengeCode.utc_day_key(utc_date)}
	challenge.challenge_id=ChallengeCode.daily_challenge_id(challenge,String(challenge.challenge_day_utc));start_requested.emit(challenge)

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
	_add_slider(box,"damage_flash",0.0,1.0,0.1)
	_add_slider(box,"control_sensitivity",0.25,1.0,0.05)
	var assist_title:=VisualTheme.label(LocalizationService.text("assist_mode"),15,VisualTheme.FRIENDLY);assist_title.horizontal_alignment=LocalizationService.start_alignment();box.add_child(assist_title)
	_add_slider(box,"assist_projectile_speed",0.6,1.0,0.05)
	_add_slider(box,"assist_telegraph",1.0,1.6,0.1)
	_add_slider(box,"assist_dash_window",1.0,1.5,0.1)
	_add_toggle(box,"aim_assist")
	_add_toggle(box,"analytics_opt_in")
	_add_option(box,"dash_method",["button","double_tap","flick"],["dash_button","dash_double_tap","dash_flick"])
	_add_option(box,"handedness",["right","left"],["hand_right","hand_left"])
	var language:=Button.new();language.alignment=LocalizationService.start_alignment();language.text="%s · %s"%[LocalizationService.text("language"),LocalizationService.text("hebrew") if String(SettingsManager.get_value("language","en"))=="en" else LocalizationService.text("english")];language.custom_minimum_size.y=58;language.pressed.connect(_toggle_language);box.add_child(language)
	var tutorial_replay:=Button.new();tutorial_replay.alignment=LocalizationService.start_alignment();tutorial_replay.text=LocalizationService.text("tutorial_replay");tutorial_replay.custom_minimum_size.y=54;tutorial_replay.pressed.connect(_request_tutorial_replay);box.add_child(tutorial_replay)
	var support:=Button.new();support.alignment=LocalizationService.start_alignment();support.text=LocalizationService.text("support_feedback");support.custom_minimum_size.y=54;support.pressed.connect(func():_open_public_page("support.html"));box.add_child(support)
	var privacy:=Button.new();privacy.alignment=LocalizationService.start_alignment();privacy.text=LocalizationService.text("privacy_policy");privacy.custom_minimum_size.y=54;privacy.pressed.connect(func():_open_public_page("privacy.html"));box.add_child(privacy)
	var reset:=Button.new();reset.alignment=LocalizationService.start_alignment();reset.text=LocalizationService.text("reset_progress");reset.custom_minimum_size.y=54;reset.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(VisualTheme.ENEMY,0.16),16));reset.pressed.connect(_show_reset_confirmation);box.add_child(reset)

func _add_slider(parent:VBoxContainer,key:String,min_value:float,max_value:float,step:float)->void:
	var row:=VBoxContainer.new();row.layout_direction=LocalizationService.layout_direction();parent.add_child(row);var title:=VisualTheme.label(LocalizationService.text(key),12,VisualTheme.TEXT);title.horizontal_alignment=LocalizationService.start_alignment();row.add_child(title);var slider:=HSlider.new();slider.min_value=min_value;slider.max_value=max_value;slider.step=step;slider.value=float(SettingsManager.get_value(key,max_value));slider.value_changed.connect(func(value:float):SettingsManager.set_value(key,value));row.add_child(slider)

func _add_toggle(parent:VBoxContainer,key:String)->void:
	var toggle:=CheckButton.new();toggle.layout_direction=LocalizationService.layout_direction();toggle.text=LocalizationService.text(key);toggle.button_pressed=bool(SettingsManager.get_value(key,false));toggle.toggled.connect(func(value:bool):SettingsManager.set_value(key,value);AnalyticsService.track("settings_changed",{"setting":key}));parent.add_child(toggle)

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

func _toggle_language()->void:
	SettingsManager.set_value("language","he" if String(SettingsManager.get_value("language","en"))=="en" else "en")
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
	draw_rect(Rect2(0,0,size.x if size.x>0 else 540,size.y if size.y>0 else 960),VisualTheme.DEEP_SPACE)
	var stage:=clampi(int(SaveManager.profile.get("nest_stage",0)),0,4)
	for ring in range(8,0,-1):
		var radius:=58.0+ring*27.0+sin(_time*0.4+ring)*3.0
		draw_arc(Vector2(270,365),radius,_time*0.04*(-1 if ring%2 else 1),TAU+_time*0.04,52,Color(VisualTheme.FRIENDLY,0.018+stage*0.008),2.0)
	for path_index in FACILITIES.size():
		var facility:Dictionary=FACILITIES[path_index]
		var unlocked:=stage>=int(facility.stage)
		if path_index>0:
			var previous:Dictionary=FACILITIES[path_index-1]
			draw_line(previous.position,facility.position,Color(VisualTheme.FRIENDLY,0.15 if unlocked else 0.035),5.0)
		var position_value:Vector2=facility.position
		draw_circle(position_value,42.0,Color(0.04,0.08,0.12,0.92) if unlocked else Color(0.025,0.03,0.04,0.9))
		draw_arc(position_value,42,0,TAU,28,Color(VisualTheme.FRIENDLY,0.45 if unlocked else 0.08),2.5)
		if unlocked:
			for light in stage+1:
				var angle:=_time*(0.3+light*0.05)+light*TAU/maxf(1,stage+1)
				draw_circle(position_value+Vector2.from_angle(angle)*(27+light*2),2.2,VisualTheme.BIO if light%2 else VisualTheme.FRIENDLY)
	if stage>=1:
		draw_circle(Vector2(270,365),32+sin(_time*2.0)*2,Color(VisualTheme.SHARD,0.22))
		draw_circle(Vector2(270,365),12,VisualTheme.SHARD)
	if stage>=2:
		for machine in 4:
			var x:=96+machine*116;draw_rect(Rect2(x,520-machine%2*18,34,48+machine%2*18),Color(0.08,0.14,0.17,0.8));draw_rect(Rect2(x+8,530-machine%2*18,5,5),VisualTheme.FRIENDLY)
	if stage>=3:
		for survivor in 5:draw_circle(Vector2(165+survivor*52,565+sin(_time+survivor)*3),5,Color(VisualTheme.TEXT,0.6))
	if stage>=4:
		for plant in 7:
			var p:=Vector2(90+plant*60,585);draw_line(p,p+Vector2(sin(_time*0.5+plant)*8,-22),VisualTheme.BIO,3);draw_circle(p+Vector2(sin(_time*0.5+plant)*8,-22),4,VisualTheme.BIO)
