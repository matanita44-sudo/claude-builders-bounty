class_name RunHUD
extends CanvasLayer

const SafeAreaHelperScript := preload("res://scripts/ui/safe_area_helper.gd")

signal dash_pressed
signal dive_pressed
signal pause_pressed
signal organ_selected(organ_id: String)
signal mutation_selected(mutation_id: String)
signal mutation_reroll_requested
signal result_action(action: String)

var root: Control
var boss_name: Label
var boss_bar: ProgressBar
var player_bar: ProgressBar
var phase_label: Label
var resource_label: Label
var timer_label: Label
var dash_button: Button
var dive_button: Button
var overlay: PanelContainer
var toast_label: Label
var _toast_tween: Tween
var _tutorial_message := ""
var _tutorial_color := VisualTheme.FRIENDLY
var _toast_is_transient := false

func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_apply_safe_layout)
	_apply_safe_layout()

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Gameplay controls use fixed physical positions; only text containers mirror.
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(14,18)
	top_panel.size = Vector2(512,94)
	top_panel.add_theme_stylebox_override("panel",VisualTheme.panel_style(Color(0.02,0.035,0.075,0.78),16))
	root.add_child(top_panel)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation",5)
	top_panel.add_child(top)
	var line := HBoxContainer.new()
	line.layout_direction = LocalizationService.layout_direction()
	top.add_child(line)
	boss_name = VisualTheme.label(LocalizationService.content_text("boss","gravemaw","name","GRAVEMAW"),13)
	boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_name.horizontal_alignment = LocalizationService.start_alignment()
	line.add_child(boss_name)
	resource_label = VisualTheme.label(LocalizationService.text("bio_short_value",{"value":0}),12,VisualTheme.BIO)
	line.add_child(resource_label)
	timer_label = VisualTheme.label(" 00:00",12,VisualTheme.MUTED)
	line.add_child(timer_label)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size.y = 9
	boss_bar.add_theme_stylebox_override("background",VisualTheme.button_style(Color(1,1,1,0.07),5))
	boss_bar.add_theme_stylebox_override("fill",VisualTheme.button_style(VisualTheme.VULNERABLE,5))
	top.add_child(boss_bar)
	player_bar = ProgressBar.new()
	player_bar.show_percentage = false
	player_bar.custom_minimum_size.y = 6
	player_bar.add_theme_stylebox_override("background",VisualTheme.button_style(Color(1,1,1,0.05),4))
	player_bar.add_theme_stylebox_override("fill",VisualTheme.button_style(VisualTheme.BIO,4))
	top.add_child(player_bar)

	phase_label = VisualTheme.label(LocalizationService.text("state_exterior"),12,VisualTheme.TEXT)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.position = Vector2(40,126)
	phase_label.size = Vector2(460,40)
	root.add_child(phase_label)

	var left_handed := String(SettingsManager.get_value("handedness","right")) == "left"
	dash_button = _round_button(LocalizationService.text("phase_dash"),Vector2(430,842) if left_handed else Vector2(18,842),VisualTheme.FRIENDLY)
	dash_button.pressed.connect(func(): dash_pressed.emit())
	root.add_child(dash_button)
	dive_button = _round_button(LocalizationService.text("dive_locked"),Vector2(18,842) if left_handed else Vector2(430,842),VisualTheme.VULNERABLE)
	dive_button.disabled = true
	dive_button.pressed.connect(func(): dive_pressed.emit())
	root.add_child(dive_button)

	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.position = Vector2(480,122)
	pause_button.size = Vector2(44,44)
	pause_button.add_theme_font_size_override("font_size",18)
	pause_button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(0.04,0.06,0.1,0.7),18))
	pause_button.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_button)

	toast_label = VisualTheme.label("",13)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.layout_direction = LocalizationService.layout_direction()
	toast_label.position = Vector2(70,190)
	toast_label.size = Vector2(400,48)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	overlay = PanelContainer.new()
	overlay.position = Vector2(18,220)
	overlay.size = Vector2(504,600)
	overlay.add_theme_stylebox_override("panel",VisualTheme.panel_style(Color(0.015,0.025,0.055,0.98),28,Color(VisualTheme.FRIENDLY,0.2)))
	overlay.visible = false
	root.add_child(overlay)

func _apply_safe_layout() -> void:
	if is_instance_valid(root):
		SafeAreaHelperScript.fit_design_control(root)

func _round_button(text_value: String, at: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = Vector2(92,92)
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_color_override("font_color",VisualTheme.TEXT)
	button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(color,0.16),46))
	button.add_theme_stylebox_override("hover",VisualTheme.button_style(Color(color,0.24),46))
	button.add_theme_stylebox_override("pressed",VisualTheme.button_style(Color(color,0.38),46))
	button.add_theme_stylebox_override("disabled",VisualTheme.button_style(Color(0.2,0.2,0.25,0.12),46))
	return button

func update_status(boss_title: String, boss_ratio: float, player_ratio: float, bio: int, elapsed: float, phase_text: String, dash_ratio: float) -> void:
	boss_name.text = boss_title
	boss_bar.value = clampf(boss_ratio,0,1)*100.0
	player_bar.value = clampf(player_ratio,0,1)*100.0
	resource_label.text = LocalizationService.text("bio_short_value",{"value":bio})
	timer_label.text = " %02d:%02d" % [int(elapsed)/60,int(elapsed)%60]
	phase_label.text = phase_text
	dash_button.text = LocalizationService.text("phase_ready") if dash_ratio >= 1.0 else LocalizationService.text("phase_charge",{"percent":int(dash_ratio*100.0)})

func set_dive_ready(ready: bool) -> void:
	dive_button.disabled = not ready
	dive_button.text = LocalizationService.text("dive_now") if ready else LocalizationService.text("dive_locked")

func show_toast(message: String, color: Color = VisualTheme.TEXT) -> void:
	_toast_is_transient = true
	toast_label.text = message
	toast_label.add_theme_color_override("font_color",color)
	if _toast_tween and _toast_tween.is_running():
		_toast_tween.kill()
	toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label,"modulate:a",1.0,0.15)
	_toast_tween.tween_interval(1.45)
	_toast_tween.tween_property(toast_label,"modulate:a",0.0,0.28)
	_toast_tween.tween_callback(_restore_tutorial_prompt)

func set_tutorial_prompt(message: String, color: Color = VisualTheme.FRIENDLY) -> void:
	_tutorial_message = message
	_tutorial_color = color
	if not _toast_is_transient:
		_restore_tutorial_prompt()

func _restore_tutorial_prompt() -> void:
	_toast_is_transient = false
	if _tutorial_message.is_empty():
		toast_label.text = ""
		toast_label.modulate.a = 0.0
		return
	toast_label.text = _tutorial_message
	toast_label.add_theme_color_override("font_color",_tutorial_color)
	toast_label.modulate.a = 1.0

func show_organ_choices(organs: Array, preview_level: int = 0) -> void:
	_clear_overlay()
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation",12)
	overlay.add_child(box)
	var eyebrow := VisualTheme.label(LocalizationService.text("organ_order_eyebrow"),11,VisualTheme.FRIENDLY)
	eyebrow.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(eyebrow)
	var title := VisualTheme.label(LocalizationService.text("organ_choice_title"),27)
	title.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(title)
	var body := VisualTheme.label(LocalizationService.text("organ_choice_body"),13,VisualTheme.MUTED)
	body.horizontal_alignment = LocalizationService.start_alignment()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = 52
	box.add_child(body)
	for raw_organ in organs:
		var organ: Dictionary = raw_organ
		var button := Button.new()
		var organ_id := String(organ.get("id",""))
		var organ_name := LocalizationService.content_text("organ",organ_id,"name",String(organ.get("name",LocalizationService.text("organ_fallback"))))
		var organ_effect := LocalizationService.content_text("organ",organ_id,"effect",String(organ.get("effect","")))
		var details := "%s\n%s" % [organ_name,organ_effect]
		if preview_level > 0:
			details += "\n" + LocalizationService.text("organ_scan", {"hp": int(organ.get("hp", 0)), "hazard": LocalizationService.hazard_text(String(organ.get("hazard", "none")))})
		button.text = details
		button.custom_minimum_size.y = 92
		button.alignment = LocalizationService.start_alignment()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size",13)
		button.add_theme_stylebox_override("normal",VisualTheme.panel_style(Color(VisualTheme.VULNERABLE,0.1),16,Color(VisualTheme.VULNERABLE,0.3)))
		button.pressed.connect(func(): hide_overlay(); organ_selected.emit(organ_id))
		box.add_child(button)

func show_mutation_choices(mutations: Array, rerolls: int) -> void:
	_clear_overlay()
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation",10)
	overlay.add_child(box)
	var eyebrow := VisualTheme.label(LocalizationService.text("mutation_eyebrow"),11,VisualTheme.SHARD)
	eyebrow.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(eyebrow)
	var title := VisualTheme.label(LocalizationService.text("mutation_choice_title"),27)
	title.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(title)
	for raw_mutation in mutations:
		var mutation: Dictionary = raw_mutation
		var button := Button.new()
		var mutation_id := String(mutation.get("id",""))
		var mutation_name := LocalizationService.content_text("mutation",mutation_id,"name",String(mutation.get("name",LocalizationService.text("mutation_fallback"))))
		var mutation_description := LocalizationService.content_text("mutation",mutation_id,"description",String(mutation.get("description","")))
		var badge := ""
		if bool(mutation.get("_synergy", false)):
			badge = LocalizationService.text("synergy_detail", {"tag": String(mutation.get("_synergy_detail", "")).replace("_", " ").to_upper()}) if mutation.has("_synergy_detail") else LocalizationService.text("synergy")
		if String(mutation.get("rarity", "common")) == "rare":
			badge = (badge + " · " if not badge.is_empty() else "") + LocalizationService.text("rare")
		button.text = "%s\n%s%s" % [mutation_name,mutation_description,"\n" + badge if not badge.is_empty() else ""]
		button.custom_minimum_size.y = 105
		button.alignment = LocalizationService.start_alignment()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size",13)
		button.add_theme_stylebox_override("normal",VisualTheme.panel_style(Color(VisualTheme.SHARD,0.1),16,Color(VisualTheme.SHARD,0.32)))
		button.pressed.connect(func(): hide_overlay(); mutation_selected.emit(mutation_id))
		box.add_child(button)
	if rerolls > 0:
		var reroll_button := Button.new()
		reroll_button.text = LocalizationService.text("reroll_left",{"count":rerolls})
		reroll_button.alignment = LocalizationService.start_alignment()
		reroll_button.custom_minimum_size.y = 52
		reroll_button.add_theme_font_size_override("font_size", 13)
		reroll_button.add_theme_stylebox_override("normal", VisualTheme.button_style(Color(VisualTheme.SHARD, 0.12), 16))
		reroll_button.pressed.connect(func(): mutation_reroll_requested.emit())
		box.add_child(reroll_button)

func show_result(result: Dictionary) -> void:
	_clear_overlay()
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation",8)
	overlay.add_child(box)
	var won := bool(result.get("won",false))
	var result_eyebrow := VisualTheme.label(LocalizationService.text("colossus_collapsed") if won else LocalizationService.text("diver_lost"),12,VisualTheme.BIO if won else VisualTheme.ENEMY)
	result_eyebrow.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(result_eyebrow)
	var result_title := VisualTheme.label(LocalizationService.text("victory") if won else LocalizationService.text("nest_remembers"),34)
	result_title.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(result_title)
	var cause_text := LocalizationService.cause_text(String(result.get("cause","unknown_attack")))
	var cause := LocalizationService.text("victory_body") if won else LocalizationService.text("killed_by",{"cause":cause_text})
	var cause_label := VisualTheme.label(cause,13,VisualTheme.MUTED)
	cause_label.horizontal_alignment = LocalizationService.start_alignment()
	cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cause_label)
	var score := VisualTheme.label(LocalizationService.text("score_value",{"value":String.num_int64(int(result.get("score",0)))}),44,VisualTheme.FRIENDLY)
	score.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(score)
	var boss_id := String(result.get("boss_id",""))
	var boss_definition := GameData.get_boss(boss_id)
	var boss_title := LocalizationService.content_text("boss",boss_id,"name",String(boss_definition.get("name",LocalizationService.text("colossus_fallback"))))
	var weapon_id := String(result.get("weapon",""))
	var weapon_definition := GameData.get_weapon(weapon_id)
	var weapon_title := LocalizationService.content_text("weapon",weapon_id,"name",String(weapon_definition.get("name",weapon_id.replace("_"," ").capitalize())))
	var loadout := VisualTheme.label(LocalizationService.text("result_loadout",{"boss":boss_title,"weapon":weapon_title}),13,VisualTheme.TEXT)
	loadout.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(loadout)
	var destroyed_names: Array[String] = []
	for organ_id_value in result.get("destroyed_organs",[]):
		var organ_id := String(organ_id_value)
		var organ_fallback := organ_id.replace("_"," ").capitalize()
		for raw_organ in boss_definition.get("organs",[]):
			var organ: Dictionary = raw_organ
			if String(organ.get("id",""))==organ_id:
				organ_fallback=String(organ.get("name",organ_fallback))
				break
		destroyed_names.append(LocalizationService.content_text("organ",organ_id,"name",organ_fallback))
	var destroyed_value := ", ".join(destroyed_names) if not destroyed_names.is_empty() else LocalizationService.text("none")
	var organs_label := VisualTheme.label(LocalizationService.text("result_organs_destroyed",{"value":destroyed_value}),11,VisualTheme.MUTED)
	organs_label.horizontal_alignment = LocalizationService.start_alignment()
	organs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(organs_label)
	var mutation_ids: Array = result.get("mutations",[])
	var mutation_names: Array[String] = []
	for mutation_index in range(maxi(0,mutation_ids.size()-3),mutation_ids.size()):
		var mutation_id := String(mutation_ids[mutation_index])
		var mutation_definition := GameData.get_mutation(mutation_id)
		mutation_names.append(LocalizationService.content_text("mutation",mutation_id,"name",String(mutation_definition.get("name",mutation_id.replace("_"," ").capitalize()))))
	if mutation_ids.size()>3:
		mutation_names.append(LocalizationService.text("more_count",{"count":mutation_ids.size()-3}))
	var mutations_value := ", ".join(mutation_names) if not mutation_names.is_empty() else LocalizationService.text("none")
	var mutations_label := VisualTheme.label(LocalizationService.text("result_mutations",{"value":mutations_value}),11,VisualTheme.MUTED)
	mutations_label.horizontal_alignment = LocalizationService.start_alignment()
	mutations_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mutations_label)
	var metrics := VisualTheme.label(LocalizationService.text("result_metrics",{"time":result.get("time_text","00:00"),"depth":maxi(1,int(result.get("abyss_depth",0))),"bio":int(result.get("banked_bio",0))}),12,VisualTheme.TEXT)
	metrics.horizontal_alignment = LocalizationService.start_alignment()
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(metrics)
	if bool(result.get("challenge_has_target",false)):
		var target_key := "friend_target_beaten" if bool(result.get("challenge_target_met",false)) else "friend_target_missed"
		var target_label := VisualTheme.label(LocalizationService.text(target_key),13,VisualTheme.BIO if bool(result.get("challenge_target_met",false)) else VisualTheme.TELEGRAPH)
		target_label.horizontal_alignment = LocalizationService.start_alignment()
		box.add_child(target_label)
	for pair in [["retry","dive_again"],["share","share_rift"],["nest","return_to_nest"]]:
		var button := Button.new()
		button.text = LocalizationService.text(String(pair[1]))
		button.alignment = LocalizationService.start_alignment()
		button.custom_minimum_size.y = 50
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_stylebox_override("normal",VisualTheme.button_style(Color(VisualTheme.FRIENDLY,0.18),17))
		var action: String = pair[0]
		button.pressed.connect(func(): result_action.emit(action))
		box.add_child(button)

func show_pause() -> void:
	_clear_overlay()
	overlay.visible = true
	var box := VBoxContainer.new()
	box.layout_direction = LocalizationService.layout_direction()
	overlay.add_child(box)
	var pause_title := VisualTheme.label(LocalizationService.text("dive_paused"),30)
	pause_title.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(pause_title)
	var pause_body := VisualTheme.label(LocalizationService.text("pause_body"),13,VisualTheme.MUTED)
	pause_body.horizontal_alignment = LocalizationService.start_alignment()
	box.add_child(pause_body)
	for pair in [["resume","resume"],["nest","abandon_to_nest"]]:
		var button := Button.new()
		button.text = LocalizationService.text(String(pair[1]))
		button.alignment = LocalizationService.start_alignment()
		button.custom_minimum_size.y=62
		var action:String=pair[0]
		button.pressed.connect(func(): result_action.emit(action))
		box.add_child(button)

func hide_overlay() -> void:
	overlay.visible = false
	_clear_overlay()

func _clear_overlay() -> void:
	for child in overlay.get_children():
		child.queue_free()
