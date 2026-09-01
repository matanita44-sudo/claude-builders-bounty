class_name BossVisual
extends Node2D

const SUPPORTED_VISUAL_TOKENS := [
	"blinded_hunter_eye",
	"collapsed_gravity_lung",
	"sealed_bone_forge",
	"cracked_prism_cortex",
	"collapsed_laser_wing",
	"fractured_halo_choir",
	"ruptured_vortex_stomach",
	"grounded_shock_gland",
	"sealed_brood_sac",
	"erased_memory_cortex",
	"stilled_echo_heart",
	"shattered_reflection_lattice"
]

var definition: Dictionary = {}
var mode := "exterior"
var phase := 0
var breach_open := false
var destroyed_organs: Array[String] = []
var organ_visual_states: Dictionary = {}
var selected_organ: Dictionary = {}
var health_ratio := 1.0
var hit_flash := 0.0
var pulse_time := 0.0
var spin := 0.0

func setup(boss_definition: Dictionary) -> void:
	definition = boss_definition.duplicate(true)
	queue_redraw()

func set_exterior(new_phase: int, new_destroyed: Array[String], is_breach_open: bool, new_visual_states: Dictionary = {}) -> void:
	mode = "exterior"
	phase = new_phase
	destroyed_organs = new_destroyed.duplicate()
	organ_visual_states = new_visual_states.duplicate(true)
	if organ_visual_states.is_empty():
		organ_visual_states = _derive_visual_states(new_destroyed)
	breach_open = is_breach_open
	selected_organ = {}
	queue_redraw()

func _derive_visual_states(new_destroyed: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for raw_organ in definition.get("organs", []):
		var organ := raw_organ as Dictionary
		var organ_id := String(organ.get("id", ""))
		if not new_destroyed.has(organ_id):
			continue
		var loss := organ.get("loss", {}) as Dictionary
		result[organ_id] = String(loss.get("visual_token", ""))
	return result

func visual_state_for_organ(organ_id: String) -> String:
	return String(organ_visual_states.get(organ_id, "intact"))

func active_visual_tokens() -> Array[String]:
	var result: Array[String] = []
	for organ_id_value in organ_visual_states:
		var token := String(organ_visual_states[organ_id_value])
		if not token.is_empty():
			result.append(token)
	return result

static func supports_visual_token(token: String) -> bool:
	return token in SUPPORTED_VISUAL_TOKENS

func set_interior(organ: Dictionary) -> void:
	mode = "interior"
	selected_organ = organ.duplicate(true)
	breach_open = false
	queue_redraw()

func set_health(current: float, maximum: float) -> void:
	health_ratio = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	queue_redraw()

func flash_hit() -> void:
	hit_flash = 0.1
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	spin += delta * (0.16 + phase * 0.025)
	hit_flash = maxf(0.0, hit_flash - delta)
	queue_redraw()

func target_position() -> Vector2:
	return position + (Vector2(0, 58) if mode == "exterior" else Vector2.ZERO)

func target_radius() -> float:
	if mode == "interior":
		return 67.0
	match String(definition.get("id", "gravemaw")):
		"abyss_leviathan": return 88.0
		"null_twin": return 82.0
		_: return 96.0

func _draw() -> void:
	if definition.is_empty():
		return
	if mode == "interior":
		_draw_interior()
	else:
		_draw_exterior()

func _palette(index: int, fallback: Color) -> Color:
	var values: Array = definition.get("palette", [])
	if index >= 0 and index < values.size():
		return Color(String(values[index]))
	return fallback

func _draw_exterior() -> void:
	var boss_id := String(definition.get("id", "gravemaw"))
	for ring in range(5, 0, -1):
		var ring_radius := 92.0 + ring * 17.0 + sin(pulse_time * 1.2 + ring) * 3.0
		draw_arc(Vector2(0, 58), ring_radius, spin * (-1.0 if ring % 2 else 1.0), spin + TAU * 0.72, 42, Color(_palette(1, VisualTheme.VULNERABLE), 0.035 + ring * 0.011), 2.0)
	match boss_id:
		"seraph_9": _draw_seraph()
		"abyss_leviathan": _draw_leviathan()
		"null_twin": _draw_null_twin()
		_: _draw_gravemaw()
	_draw_organ_transformations()
	_draw_organ_status()
	if breach_open:
		var breach_radius := 24.0 + sin(pulse_time * 8.0) * 5.0
		draw_circle(Vector2(0,58), breach_radius + 12.0, Color(VisualTheme.VULNERABLE,0.12))
		draw_arc(Vector2(0,58), breach_radius, 0, TAU, 32, VisualTheme.VULNERABLE, 5.0)
		draw_arc(Vector2(0,58), breach_radius + 11.0, 0, TAU, 32, VisualTheme.FRIENDLY, 1.8)

func _draw_gravemaw() -> void:
	var center := Vector2(0,58)
	var body := PackedVector2Array()
	for index in 36:
		var angle := TAU * index / 36.0
		var radius := 101.0 + sin(angle * 5.0 + pulse_time * 0.8) * 9.0 + sin(angle * 11.0) * 4.0
		body.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var color := Color.WHITE if hit_flash > 0.0 else _palette(0, VisualTheme.ARMOR)
	draw_colored_polygon(body, color.darkened(0.48))
	draw_polyline(PackedVector2Array(body + PackedVector2Array([body[0]])), Color(color, 0.65), 3.0)
	for plate in 7:
		var angle := spin * (1.0 if plate % 2 else -0.6) + plate * TAU / 7.0
		var p := center + Vector2(cos(angle), sin(angle)) * 75.0
		var tangent := Vector2(-sin(angle), cos(angle))
		var outward := Vector2(cos(angle), sin(angle))
		var points := PackedVector2Array([p-tangent*23-outward*12,p+tangent*23-outward*12,p+tangent*18+outward*14,p-tangent*18+outward*14])
		draw_colored_polygon(points, color if plate >= phase + 1 else color.darkened(0.55))
		draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]), VisualTheme.ARMOR_SHADOW, 2.0)
	draw_arc(center+Vector2(0,8), 42, 0.1, PI-0.1, 22, Color("#050509"), 18.0)
	for tooth in 6:
		var x := -31.0 + tooth * 12.4
		draw_colored_polygon(PackedVector2Array([center+Vector2(x,-1),center+Vector2(x+7,-1),center+Vector2(x+4,12)]), VisualTheme.ARMOR)

func _draw_seraph() -> void:
	var center := Vector2(0,58)
	var color := Color.WHITE if hit_flash > 0.0 else _palette(0, VisualTheme.ARMOR)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-105),center+Vector2(30,-28),center+Vector2(20,92),center+Vector2(-20,92),center+Vector2(-30,-28)]), color.darkened(0.35))
	for side in [-1.0,1.0]:
		var wing := PackedVector2Array([center+Vector2(side*22,-52),center+Vector2(side*130,-78),center+Vector2(side*76,0),center+Vector2(side*142,42),center+Vector2(side*34,48)])
		var wing_dark: bool = visual_state_for_organ("wing_reactor") == "collapsed_laser_wing" and side < 0.0
		draw_colored_polygon(wing, color.darkened(0.75) if wing_dark else color.darkened(0.15))
		draw_polyline(wing, _palette(2, VisualTheme.FRIENDLY), 2.0)
	var halo_broken := visual_state_for_organ("halo_choir") == "fractured_halo_choir"
	var halo_color := Color(_palette(1, VisualTheme.SHARD), 0.22 if halo_broken else 0.82)
	draw_arc(center+Vector2(0,-88), 58, spin, spin+TAU*(0.65 if halo_broken else 0.92), 42, halo_color, 8.0)
	draw_circle(center+Vector2(0,-36), 15, _palette(2, VisualTheme.FRIENDLY))

func _draw_leviathan() -> void:
	var color := Color.WHITE if hit_flash > 0.0 else _palette(0, VisualTheme.FRIENDLY)
	var points := PackedVector2Array()
	for index in 24:
		var t := float(index) / 23.0
		points.append(Vector2(-160 + t * 320.0, 58 + sin(t * TAU * 1.4 + pulse_time * 0.7) * 48.0))
	draw_polyline(points, color.darkened(0.55), 42.0, true)
	draw_polyline(points, Color(color,0.7), 5.0, true)
	var head := points[-1]
	draw_colored_polygon(PackedVector2Array([head+Vector2(42,0),head+Vector2(-22,-39),head+Vector2(-30,35)]), color.darkened(0.25))
	draw_circle(head+Vector2(5,-8), 6, VisualTheme.ENEMY)
	for scar_index in destroyed_organs.size():
		var t := 0.25 + scar_index * 0.22
		var scar := points[int(t * 23.0)]
		draw_circle(scar, 12.0, Color(VisualTheme.VULNERABLE,0.8))

func _draw_null_twin() -> void:
	var center := Vector2(0,58)
	var color := Color.WHITE if hit_flash > 0.0 else _palette(0, VisualTheme.SHARD)
	for side in [-1.0,1.0]:
		var offset := Vector2(side*53,0)
		draw_arc(center+offset, 73, -PI*0.72 if side>0 else PI*0.28, PI*0.72 if side>0 else PI*1.72, 35, color.darkened(0.16), 27.0)
		draw_arc(center+offset, 86, 0, TAU, 42, Color(color,0.2), 2.0)
	draw_line(center+Vector2(0,-100),center+Vector2(0,100),Color(_palette(2,Color.WHITE),0.8),3.0)
	if visual_state_for_organ("reflection_lattice") == "shattered_reflection_lattice":
		for index in 7:
			draw_line(center+Vector2(-90+index*28,-70),center+Vector2(-70+index*23,78),Color(VisualTheme.VULNERABLE,0.38),2.0)

func _draw_organ_transformations() -> void:
	var center := Vector2(0,58)
	for token in active_visual_tokens():
		match token:
			"blinded_hunter_eye":
				var eye := center+Vector2(0,-48)
				draw_circle(eye,17.0,Color("#08070C"))
				draw_arc(eye,20.0,0.0,TAU,22,Color(VisualTheme.VULNERABLE,0.78),3.0)
				draw_line(eye+Vector2(-15,-11),eye+Vector2(15,11),VisualTheme.ENEMY,5.0)
				draw_line(eye+Vector2(-15,11),eye+Vector2(15,-11),VisualTheme.ENEMY,3.0)
				draw_line(eye+Vector2(0,16),eye+Vector2(-5,34),Color(VisualTheme.VULNERABLE,0.75),4.0)
			"collapsed_gravity_lung":
				var lung := center+Vector2(-54,36)
				for radius in [25.0,17.0,9.0]:
					draw_arc(lung,radius,-PI*0.8,PI*0.8,22,Color(VisualTheme.SHARD,0.55),3.0)
				draw_line(lung+Vector2(-20,-8),lung+Vector2(20,8),VisualTheme.ENEMY,4.0)
				draw_circle(lung+Vector2(-28,5),4.0,Color(VisualTheme.SHARD,0.65))
			"sealed_bone_forge":
				var forge := center+Vector2(55,38)
				draw_rect(Rect2(forge-Vector2(24,17),Vector2(48,34)),Color("#17131A"),true)
				for vent in [-14.0,0.0,14.0]:
					draw_line(forge+Vector2(vent,-12),forge+Vector2(vent,12),Color(VisualTheme.ARMOR,0.8),5.0)
				draw_line(forge+Vector2(-25,-19),forge+Vector2(25,19),VisualTheme.ENEMY,5.0)
			"cracked_prism_cortex":
				var prism := center+Vector2(0,-44)
				var diamond := PackedVector2Array([prism+Vector2(0,-28),prism+Vector2(23,0),prism+Vector2(0,28),prism+Vector2(-23,0),prism+Vector2(0,-28)])
				draw_polyline(diamond,Color(_palette(2,VisualTheme.FRIENDLY),0.85),4.0)
				draw_line(prism+Vector2(-3,-26),prism+Vector2(6,-5),VisualTheme.ENEMY,4.0)
				draw_line(prism+Vector2(6,-5),prism+Vector2(-8,8),VisualTheme.ENEMY,4.0)
				draw_line(prism+Vector2(-8,8),prism+Vector2(3,27),VisualTheme.ENEMY,4.0)
			"collapsed_laser_wing":
				var root := center+Vector2(-28,-35)
				draw_line(root,root+Vector2(-58,56),Color(VisualTheme.ENEMY,0.9),8.0)
				draw_line(root+Vector2(-58,56),root+Vector2(-91,40),Color(VisualTheme.ARMOR,0.65),6.0)
				for spark in 4:
					var spark_pos := root+Vector2(-18-spark*14,20+spark*7)
					draw_line(spark_pos,spark_pos+Vector2(-8,8),Color(VisualTheme.FRIENDLY,0.75),2.0)
			"fractured_halo_choir":
				var halo := center+Vector2(0,-88)
				draw_arc(halo,68.0,-PI*0.88,-PI*0.25,18,VisualTheme.ENEMY,5.0)
				draw_line(halo+Vector2(-44,-44),halo+Vector2(-56,-61),Color(VisualTheme.SHARD,0.72),4.0)
				draw_line(halo+Vector2(47,-39),halo+Vector2(59,-52),Color(VisualTheme.SHARD,0.72),4.0)
			"ruptured_vortex_stomach":
				var vortex := center+Vector2(-42,22)
				draw_circle(vortex,24.0,Color("#071318"))
				for radius in [22.0,15.0,8.0]:
					draw_arc(vortex,radius,spin,spin+PI*1.35,18,Color(VisualTheme.VULNERABLE,0.68),3.0)
				draw_line(vortex+Vector2(-22,-16),vortex+Vector2(22,18),VisualTheme.ENEMY,4.0)
			"grounded_shock_gland":
				var gland := center+Vector2(30,-8)
				var bolt := PackedVector2Array([gland+Vector2(-24,-25),gland+Vector2(-7,-8),gland+Vector2(-16,2),gland+Vector2(8,17),gland+Vector2(23,30)])
				draw_polyline(bolt,Color(VisualTheme.SHARD,0.8),5.0)
				draw_line(gland+Vector2(-28,26),gland+Vector2(27,-28),VisualTheme.ENEMY,5.0)
				draw_circle(gland+Vector2(0,0),8.0,Color(VisualTheme.ENEMY,0.35))
			"sealed_brood_sac":
				var sac := center+Vector2(72,38)
				for offset in [Vector2(-14,3),Vector2(9,-12),Vector2(13,13)]:
					draw_circle(sac+offset,11.0,Color(VisualTheme.TISSUE,0.78))
					draw_line(sac+offset-Vector2(7,7),sac+offset+Vector2(7,7),VisualTheme.ENEMY,3.0)
				draw_arc(sac,31.0,-PI*0.8,PI*0.8,24,Color(VisualTheme.ARMOR,0.75),4.0)
			"erased_memory_cortex":
				var memory := center+Vector2(-53,-15)
				draw_circle(memory,32.0,Color("#0B0712"))
				for stripe in 5:
					var y := -18.0+stripe*9.0
					draw_line(memory+Vector2(-24,y),memory+Vector2(24,y+sin(stripe)*5.0),Color(VisualTheme.ARMOR,0.45),3.0)
				draw_line(memory+Vector2(-29,-29),memory+Vector2(29,29),VisualTheme.ENEMY,5.0)
			"stilled_echo_heart":
				var heart := center+Vector2(52,8)
				draw_circle(heart+Vector2(-9,-5),14.0,Color(VisualTheme.VULNERABLE,0.32))
				draw_circle(heart+Vector2(9,-5),14.0,Color(VisualTheme.VULNERABLE,0.32))
				draw_colored_polygon(PackedVector2Array([heart+Vector2(-21,0),heart+Vector2(21,0),heart+Vector2(0,27)]),Color(VisualTheme.VULNERABLE,0.32))
				draw_line(heart+Vector2(-4,-18),heart+Vector2(5,25),VisualTheme.ENEMY,5.0)
				draw_circle(heart,34.0,Color(VisualTheme.SHARD,0.18),false,3.0)
			"shattered_reflection_lattice":
				for shard in 6:
					var angle := shard*TAU/6.0+0.22
					var inner := center+Vector2.from_angle(angle)*22.0
					var outer := center+Vector2.from_angle(angle+sin(shard)*0.18)*(72.0+shard%2*20.0)
					draw_line(inner,outer,Color(VisualTheme.VULNERABLE,0.72),4.0)
				draw_circle(center,18.0,Color(VisualTheme.FRIENDLY,0.34))

func _draw_organ_status() -> void:
	var organs: Array = definition.get("organs", [])
	for index in organs.size():
		var organ: Dictionary = organs[index]
		var angle := -PI * 0.82 + index * PI * 0.82
		var position_icon := Vector2(0,58) + Vector2(cos(angle),sin(angle))*134.0
		var destroyed := destroyed_organs.has(String(organ.id))
		draw_circle(position_icon, 12.0, Color(VisualTheme.TISSUE,0.95))
		draw_arc(position_icon, 12.0, 0, TAU, 18, VisualTheme.ARMOR_SHADOW if destroyed else _palette((index+1)%3,VisualTheme.VULNERABLE), 2.0)
		if destroyed:
			draw_line(position_icon-Vector2(7,7),position_icon+Vector2(7,7),VisualTheme.ENEMY,3.0)
			draw_line(position_icon+Vector2(7,-7),position_icon-Vector2(7,-7),VisualTheme.ENEMY,3.0)

func _draw_interior() -> void:
	var organ_color := _palette(1, VisualTheme.VULNERABLE)
	for vein in 12:
		var angle := vein * TAU / 12.0 + sin(pulse_time*0.4)*0.08
		var inner := Vector2(cos(angle),sin(angle))*75.0
		var outer := Vector2(cos(angle+sin(vein)*0.14),sin(angle+sin(vein)*0.14))*350.0
		draw_line(inner,outer,Color(organ_color,0.08),5.0+vein%3)
	var pulse := 1.0 + sin(pulse_time*5.0)*0.075
	for layer in range(4,0,-1):
		draw_circle(Vector2.ZERO,(55.0+layer*12.0)*pulse,Color(organ_color,0.025*layer))
	var body := PackedVector2Array()
	for index in 32:
		var angle := index*TAU/32.0
		var radius := (62.0+sin(angle*5.0+pulse_time*2.0)*9.0+sin(angle*9.0)*5.0)*pulse
		body.append(Vector2(cos(angle),sin(angle))*radius)
	draw_colored_polygon(body, Color.WHITE if hit_flash>0 else organ_color.darkened(0.42))
	draw_polyline(PackedVector2Array(body+PackedVector2Array([body[0]])),organ_color.lightened(0.22),3.0)
	draw_circle(Vector2.ZERO,10.0+sin(pulse_time*7.0)*2.0,Color.WHITE)
	draw_arc(Vector2.ZERO,84.0,-PI/2,-PI/2+TAU*health_ratio,48,VisualTheme.BIO if health_ratio>0.3 else VisualTheme.ENEMY,5.0)
