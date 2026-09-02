class_name RiftResultCard
extends PanelContainer

const ChallengeCodeClass := preload("res://scripts/core/challenge_code.gd")

const INK := Color("#17324B")
const MARBLE := Color("#FFF7E7")
const AQUA := Color("#2CB8BC")
const CORAL := Color("#F25F5C")
const GOLD := Color("#F1BE48")
const BRONZE := Color("#C88936")
const MAX_NICKNAME_LENGTH := 20
const MAX_MAJOR_MUTATIONS := 3

var model: Dictionary = {}


static func sanitize_nickname(raw_value: Variant) -> String:
	# Nicknames are optional, local-only presentation. Keep only printable text,
	# discard address/URL separators, collapse spaces, and never read an account
	# identity into the card automatically.
	var raw := String(raw_value).strip_edges()
	var filtered := ""
	for index in range(raw.length()):
		var character := raw.substr(index, 1)
		var codepoint := raw.unicode_at(index)
		if codepoint < 32 or codepoint == 127 or character in ["@", "/", "\\", ":", "#"]:
			continue
		filtered += character
	var words := filtered.split(" ", false)
	var normalized := " ".join(words).strip_edges()
	return normalized.left(MAX_NICKNAME_LENGTH)


static func build_model(result: Dictionary, challenge_code: String, nickname: String = "") -> Dictionary:
	var code := challenge_code.strip_edges()
	var decoded: Dictionary = ChallengeCodeClass.decode(code)
	if decoded.is_empty():
		return {"valid": false, "reason": "invalid_code"}

	var boss_id := String(result.get("boss_id", ""))
	var weapon_id := String(result.get("weapon", ""))
	var seed := int(result.get("seed", 0))
	var difficulty := String(result.get("difficulty", ""))
	var score := maxi(0, int(result.get("score", 0)))
	var elapsed_ms := maxi(0, int(float(result.get("elapsed", 0.0)) * 1000.0))
	var modifiers := ChallengeCodeClass.canonical_modifiers(result.get("modifiers", []))
	var decoded_modifiers := ChallengeCodeClass.canonical_modifiers(decoded.get("modifiers", []))
	# The card is evidence for the exact run that produced its challenge. Refuse
	# to render a plausible-looking card when the copied code belongs to a
	# different Titan, loadout, seed, rules, score, or completion time.
	if (
		String(decoded.get("boss", "")) != boss_id
		or String(decoded.get("weapon", "")) != weapon_id
		or int(decoded.get("seed", 0)) != seed
			or String(decoded.get("difficulty", "")) != difficulty
			or decoded_modifiers != modifiers
			or int(decoded.get("target_score", -1)) != score
		or int(decoded.get("target_time_ms", -1)) != elapsed_ms
	):
		return {"valid": false, "reason": "run_code_mismatch"}

	var boss_definition: Dictionary = GameData.get_boss(boss_id)
	var weapon_definition: Dictionary = GameData.get_weapon(weapon_id)
	if boss_definition.is_empty() or weapon_definition.is_empty():
		return {"valid": false, "reason": "unknown_content"}

	var allowed_organs: Dictionary = {}
	for raw_organ in boss_definition.get("organs", []):
		var organ: Dictionary = raw_organ
		allowed_organs[String(organ.get("id", ""))] = true
	var destroyed_organs: Array[String] = []
	for raw_organ_id in result.get("destroyed_organs", []):
		var organ_id := String(raw_organ_id)
		if allowed_organs.has(organ_id) and not destroyed_organs.has(organ_id):
			destroyed_organs.append(organ_id)

	var valid_mutations: Array[String] = []
	for raw_mutation_id in result.get("mutations", []):
		var mutation_id := String(raw_mutation_id)
		if not GameData.get_mutation(mutation_id).is_empty() and not valid_mutations.has(mutation_id):
			valid_mutations.append(mutation_id)
	var major_mutations: Array[String] = []
	for mutation_index in range(maxi(0, valid_mutations.size() - MAX_MAJOR_MUTATIONS), valid_mutations.size()):
		major_mutations.append(valid_mutations[mutation_index])

	return {
		"valid": true,
		"won": bool(result.get("won", false)),
		"boss_id": boss_id,
		"weapon_id": weapon_id,
		"score": score,
		"modifiers": modifiers,
		"time_text": "%02d:%02d" % [(elapsed_ms / 1000) / 60, (elapsed_ms / 1000) % 60],
		"depth": clampi(maxi(1, int(result.get("abyss_depth", 0))), 1, 9999),
		"destroyed_organs": destroyed_organs,
		"major_mutations": major_mutations,
		"challenge_code": code,
		"nickname": sanitize_nickname(nickname),
	}


func configure(result: Dictionary, challenge_code: String, nickname: String = "") -> bool:
	model = build_model(result, challenge_code, nickname)
	if not bool(model.get("valid", false)):
		return false
	_build()
	return true


func _build() -> void:
	name = "FriendRiftResultCard"
	custom_minimum_size = Vector2(452, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _card_style())
	var box := VBoxContainer.new()
	box.name = "ResultCardContent"
	box.layout_direction = LocalizationService.layout_direction()
	box.add_theme_constant_override("separation", 5)
	add_child(box)

	var eyebrow := _label(LocalizationService.text("friend_result_card"), 11, BRONZE)
	eyebrow.name = "ResultCardEyebrow"
	box.add_child(eyebrow)
	var nickname := String(model.get("nickname", ""))
	if not nickname.is_empty():
		var nickname_label := _label(nickname, 12, INK)
		nickname_label.name = "ResultCardNickname"
		box.add_child(nickname_label)

	var won := bool(model.get("won", false))
	var accent := AQUA if won else CORAL
	var outcome := LocalizationService.text("colossus_collapsed") if won else LocalizationService.text("diver_lost")
	var outcome_label := _label(outcome, 18, accent)
	outcome_label.name = "ResultCardOutcome"
	box.add_child(outcome_label)
	var score_label := _label(LocalizationService.text("score_value", {"value": String.num_int64(int(model.score))}), 34, INK)
	score_label.name = "ResultCardScore"
	score_label.add_theme_color_override("font_outline_color", Color(MARBLE, 0.9))
	score_label.add_theme_constant_override("outline_size", 2)
	box.add_child(score_label)

	var boss_id := String(model.boss_id)
	var boss_definition: Dictionary = GameData.get_boss(boss_id)
	var boss_title := LocalizationService.content_text("boss", boss_id, "name", String(boss_definition.get("name", boss_id.replace("_", " ").capitalize())))
	var weapon_id := String(model.weapon_id)
	var weapon_definition: Dictionary = GameData.get_weapon(weapon_id)
	var weapon_title := LocalizationService.text("unarmed") if weapon_id.is_empty() else LocalizationService.content_text("weapon", weapon_id, "name", String(weapon_definition.get("name", weapon_id.replace("_", " ").capitalize())))
	var loadout := _label(LocalizationService.text("result_loadout", {"boss": boss_title, "weapon": weapon_title}), 14, INK)
	loadout.name = "ResultCardLoadout"
	box.add_child(loadout)

	var metrics := _label(LocalizationService.text("result_card_metrics", {"time": String(model.time_text), "depth": int(model.depth)}), 12, Color(INK, 0.82))
	metrics.name = "ResultCardMetrics"
	box.add_child(metrics)

	var organ_names: Array[String] = []
	for raw_organ_id in model.destroyed_organs:
		var organ_id := String(raw_organ_id)
		var fallback := organ_id.replace("_", " ").capitalize()
		for raw_organ in boss_definition.get("organs", []):
			var organ: Dictionary = raw_organ
			if String(organ.get("id", "")) == organ_id:
				fallback = String(organ.get("name", fallback))
				break
		organ_names.append(LocalizationService.content_text("organ", organ_id, "name", fallback))
	var organs_value := ", ".join(organ_names) if not organ_names.is_empty() else LocalizationService.text("none")
	var organs := _label(LocalizationService.text("result_organs_destroyed", {"value": organs_value}), 11, Color("#B53F42"))
	organs.name = "ResultCardOrgans"
	organs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(organs)

	var mutation_names: Array[String] = []
	for raw_mutation_id in model.major_mutations:
		var mutation_id := String(raw_mutation_id)
		var definition: Dictionary = GameData.get_mutation(mutation_id)
		mutation_names.append(LocalizationService.content_text("mutation", mutation_id, "name", String(definition.get("name", mutation_id.replace("_", " ").capitalize()))))
	var mutations_value := ", ".join(mutation_names) if not mutation_names.is_empty() else LocalizationService.text("none")
	var mutations := _label(LocalizationService.text("result_mutations", {"value": mutations_value}), 11, Color("#8A5A1D"))
	mutations.name = "ResultCardMutations"
	mutations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mutations)

	var code_title := _label(LocalizationService.text("challenge_code_label"), 10, BRONZE)
	code_title.name = "ResultCardCodeLabel"
	box.add_child(code_title)
	var code_label := _label(String(model.challenge_code), 8, INK)
	code_label.name = "ResultCardCode"
	code_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	code_label.custom_minimum_size.y = 38
	box.add_child(code_label)

	var notice := _label(LocalizationService.text("local_result_unverified"), 9, Color(INK, 0.58))
	notice.name = "ResultCardNotice"
	box.add_child(notice)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := VisualTheme.label(text_value, font_size, color)
	label.horizontal_alignment = LocalizationService.start_alignment()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = MARBLE
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.border_width_left = 6
	style.border_width_bottom = 6
	style.set_corner_radius_all(18)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(INK, 0.2)
	style.shadow_size = 8
	return style
