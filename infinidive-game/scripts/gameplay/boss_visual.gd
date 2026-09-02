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

const EXTERIOR_CENTER := Vector2(0, 58)
const INK_OUTLINE := Color("#18132E")
const BIO_TEAL := Color("#35E6D0")
const CORE_GOLD := Color("#FFC857")
const TITAN_TEXTURES := {
	"gravemaw": preload("res://assets/art/titans/cronus.png"),
	"seraph_9": preload("res://assets/art/titans/hyperion.png"),
	"abyss_leviathan": preload("res://assets/art/titans/oceanus.png"),
	"null_twin": preload("res://assets/art/titans/mnemosyne.png")
}

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
	# Boss silhouettes, scars, breach state, and health remain fully readable in
	# Reduced Motion; only decorative breathing and rotation are frozen.
	if not bool(SettingsManager.get_value("reduced_motion", false)):
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
		_draw_divine_interior()
	else:
		_draw_exterior()

func _palette(index: int, fallback: Color) -> Color:
	var values: Array = definition.get("palette", [])
	if index >= 0 and index < values.size():
		return Color(String(values[index]))
	return fallback

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result

func _ellipse_point(center: Vector2, angle: float, radius_x: float, radius_y: float) -> Vector2:
	return center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)

func _organic_ellipse(center: Vector2, radius_x: float, radius_y: float, count: int, seed_phase: float, motion_scale: float = 1.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in count:
		var angle := TAU * float(index) / float(count)
		var distortion := sin(angle * 5.0 + seed_phase) * 0.052
		distortion += sin(angle * 9.0 - seed_phase * 0.47) * 0.026
		distortion += sin(angle * 13.0 + 1.9) * 0.018
		var breath := sin(pulse_time * 1.35 + angle * 2.0) * 0.012 * motion_scale
		result.append(_ellipse_point(center, angle, radius_x * (1.0 + distortion + breath), radius_y * (1.0 + distortion + breath)))
	return result

func _flash_color(color: Color, amount: float = 0.72) -> Color:
	if hit_flash <= 0.0:
		return color
	return color.lerp(Color.WHITE, amount)

func _draw_soft_glow(center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	for layer in range(5, 0, -1):
		var t := float(layer) / 5.0
		draw_circle(center, radius * (1.0 + t * 0.85), Color(color, 0.022 * strength * (6.0 - layer)))

func _draw_layered_line(points: PackedVector2Array, outer: Color, inner: Color, outer_width: float, inner_width: float) -> void:
	draw_polyline(points, outer, outer_width, true)
	draw_polyline(points, inner, inner_width, true)

func _draw_exterior() -> void:
	var boss_id := String(definition.get("id", "gravemaw"))
	# A restrained celestial aura establishes scale and depth without competing
	# with enemy projectiles. Reduced Motion freezes the offset and rotation.
	for side in [-1.0,1.0]:
		var cloud_center := EXTERIOR_CENTER+Vector2(side*116,88)
		for puff in 4:
			draw_circle(cloud_center+Vector2(side*puff*13,-puff%2*7),24.0+puff*4.0,Color("#E8FAFF",0.045+puff*0.012))
		draw_arc(cloud_center,64.0,PI*0.08,PI*0.92,34,Color("#BFEFFF",0.11),4.0,true)
	_draw_soft_glow(EXTERIOR_CENTER, 115.0, _palette(1, VisualTheme.VULNERABLE), 0.65)
	draw_arc(EXTERIOR_CENTER+Vector2(0,8),173.0,spin*0.35,spin*0.35+PI*0.42,44,Color(BIO_TEAL,0.17),3.0,true)
	draw_arc(EXTERIOR_CENTER+Vector2(0,8),181.0,PI+spin*0.22,PI+spin*0.22+PI*0.28,32,Color(CORE_GOLD,0.14),3.0,true)
	for ring in range(5, 0, -1):
		var ring_radius := 108.0 + ring * 15.0 + sin(pulse_time * 1.2 + ring) * 2.2
		var ring_start := spin * (-1.0 if ring % 2 else 0.72) + ring * 0.58
		var ring_span := TAU * (0.44 + ring * 0.055)
		draw_arc(EXTERIOR_CENTER + Vector2(0, 8), ring_radius, ring_start, ring_start + ring_span, 48, Color(_palette(1, VisualTheme.VULNERABLE), 0.024 + ring * 0.012), 2.0 if ring < 4 else 1.0, true)
	if not _draw_titan_texture(boss_id):
		match boss_id:
			"seraph_9": _draw_hyperion()
			"abyss_leviathan": _draw_oceanus()
			"null_twin": _draw_mnemosyne()
			_: _draw_cronus()
	_draw_divine_transformations()
	_draw_organ_status()
	if breach_open:
		_draw_breach()

func _draw_titan_texture(boss_id: String) -> bool:
	var texture: Texture2D = TITAN_TEXTURES.get(boss_id)
	if texture == null or texture.get_height() <= 0:
		return false
	# Keep the face below the persistent top HUD while still filling the upper
	# half of a portrait phone like a true Titan-scale encounter.
	var portrait_height := 310.0
	var portrait_width := portrait_height * float(texture.get_width()) / float(texture.get_height())
	var portrait_rect := Rect2(-portrait_width * 0.5, -52.0, portrait_width, portrait_height)
	# A soft offset silhouette separates the detailed illustration from the sky
	# while retaining the cheerful palette and colossal raid-boss scale.
	draw_texture_rect(texture,Rect2(portrait_rect.position+Vector2(6,8),portrait_rect.size),false,Color(0.08,0.12,0.20,0.25))
	draw_texture_rect(texture,portrait_rect,false,Color.WHITE)
	if hit_flash > 0.0:
		draw_texture_rect(texture,portrait_rect,false,Color(1.0,1.0,1.0,clampf(hit_flash*4.5,0.0,0.42)))
	_draw_titan_texture_nodes(boss_id)
	_draw_phase_cracks(Color("#FFF0A8"))
	return true

func _draw_titan_texture_nodes(boss_id: String) -> void:
	match boss_id:
		"seraph_9":
			_draw_divine_node(Vector2(0,-43),Color("#FFE06B"),"prism",11.0)
			_draw_divine_node(Vector2(-77,26),Color("#FF8B47"),"wing",13.0)
			_draw_divine_node(Vector2(57,39),BIO_TEAL,"halo",13.0)
		"abyss_leviathan":
			_draw_divine_node(Vector2(-20,82),Color("#49C6DD"),"vortex",13.0)
			_draw_divine_node(Vector2(38,42),Color("#FFE06B"),"shock",13.0)
			_draw_divine_node(Vector2(76,28),Color("#72E6B7"),"brood",13.0)
		"null_twin":
			_draw_divine_node(Vector2(0,-43),Color("#C69AF0"),"memory",11.0)
			_draw_divine_node(Vector2(31,47),Color("#FF7FA2"),"heart",13.0)
			_draw_divine_node(Vector2(-28,87),Color("#EFAF55"),"lattice",13.0)
		_:
			_draw_divine_node(Vector2(0,-46),CORE_GOLD,"eye",12.0)
			_draw_divine_node(Vector2(-43,50),BIO_TEAL,"rings",13.0)
			_draw_divine_node(Vector2(66,33),Color("#FF8B47"),"forge",13.0)

func _draw_chunk(points: PackedVector2Array, fill: Color, outline_width: float = 5.0, shadow_offset: Vector2 = Vector2(4,6)) -> void:
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point+shadow_offset)
	draw_colored_polygon(shadow,Color(INK_OUTLINE,0.3))
	draw_colored_polygon(points,_flash_color(fill,0.64))
	draw_polyline(_closed(points),Color(INK_OUTLINE,0.92),outline_width,true)

func _draw_titan_base(skin: Color, tunic: Color, mantle: Color, trim: Color, hair: Color, feminine: bool = false) -> void:
	var shoulder := 86.0 if feminine else 101.0
	var waist := 61.0 if feminine else 72.0
	# Monumental arms break the frame like a mobile-game raid boss, while the
	# centered chest keeps every existing gameplay target aligned.
	var left_arm := PackedVector2Array([
		Vector2(-shoulder+6,20),Vector2(-shoulder-36,45),Vector2(-shoulder-43,96),
		Vector2(-shoulder-25,130),Vector2(-shoulder+5,123),Vector2(-shoulder+20,67)
	])
	var right_arm := PackedVector2Array()
	for point in left_arm:
		right_arm.append(Vector2(-point.x,point.y))
	_draw_chunk(left_arm,skin.darkened(0.045),6.0)
	_draw_chunk(right_arm,skin,6.0)
	# Bright mantle blocks anchor the silhouette without dense texture.
	var left_mantle := PackedVector2Array([Vector2(-shoulder-8,17),Vector2(-shoulder-39,39),Vector2(-shoulder-22,72),Vector2(-shoulder+22,58),Vector2(-shoulder+24,27)])
	var right_mantle := PackedVector2Array()
	for point in left_mantle:
		right_mantle.append(Vector2(-point.x,point.y))
	_draw_chunk(left_mantle,mantle,4.5,Vector2(2,4))
	_draw_chunk(right_mantle,mantle.lightened(0.035),4.5,Vector2(2,4))
	var torso := PackedVector2Array([
		Vector2(-shoulder,27),Vector2(-62,7),Vector2(62,7),Vector2(shoulder,27),
		Vector2(waist+10,139),Vector2(43,158),Vector2(-43,158),Vector2(-waist-10,139)
	])
	_draw_chunk(torso,tunic,7.0)
	var breastplate := PackedVector2Array([
		Vector2(-58,24),Vector2(0,12),Vector2(58,24),Vector2(48,99),
		Vector2(0,124),Vector2(-48,99)
	])
	_draw_chunk(breastplate,tunic.lightened(0.09),4.0,Vector2(2,4))
	draw_polyline(PackedVector2Array([Vector2(-49,40),Vector2(0,58),Vector2(49,40)]),Color(trim,0.88),4.0,true)
	draw_line(Vector2(0,58),Vector2(0,115),Color(trim,0.56),3.0,true)
	# Bracers add one broad readable accent per arm.
	for side in [-1.0,1.0]:
		var bracer := PackedVector2Array([
			Vector2(side*(shoulder+23),82),Vector2(side*(shoulder+41),88),
			Vector2(side*(shoulder+31),119),Vector2(side*(shoulder+8),113)
		])
		_draw_chunk(bracer,trim,3.5,Vector2(2,3))
	var neck := PackedVector2Array([Vector2(-24,-8),Vector2(24,-8),Vector2(29,28),Vector2(-29,28)])
	_draw_chunk(neck,skin,4.0,Vector2(2,3))
	# Hair mass precedes the face and supplies a unique crown silhouette.
	var hair_mass := PackedVector2Array([
		Vector2(-46,-75),Vector2(-24,-96),Vector2(9,-101),Vector2(39,-85),
		Vector2(51,-57),Vector2(44,-18),Vector2(27,9),Vector2(-30,9),
		Vector2(-49,-22),Vector2(-54,-55)
	])
	_draw_chunk(hair_mass,hair,5.5,Vector2(3,5))
	var face_width := 34.0 if feminine else 39.0
	var face := PackedVector2Array([
		Vector2(-face_width,-70),Vector2(-face_width-3,-45),Vector2(-32,-13),
		Vector2(-17,6),Vector2(0,15),Vector2(17,6),Vector2(32,-13),
		Vector2(face_width+3,-45),Vector2(face_width,-70),Vector2(18,-84),Vector2(-18,-84)
	])
	_draw_chunk(face,skin,5.0,Vector2(2,4))
	# Friendly, confident expression: clear at phone scale, never grotesque.
	for side in [-1.0,1.0]:
		draw_line(Vector2(side*10,-48),Vector2(side*24,-50),Color(INK_OUTLINE,0.82),3.0,true)
		draw_circle(Vector2(side*16,-43),3.8,Color(trim,0.96))
		draw_circle(Vector2(side*16-1,-44),1.4,Color.WHITE)
	draw_polyline(PackedVector2Array([Vector2(-3,-38),Vector2(-6,-22),Vector2(1,-17)]),Color(INK_OUTLINE,0.54),2.0,true)
	draw_arc(Vector2(0,-8),13.0,PI*0.18,PI*0.82,16,Color(INK_OUTLINE,0.72),2.5,true)

func _draw_phase_cracks(color: Color) -> void:
	for crack in clampi(phase,0,3)*2:
		var x := -47.0+crack*18.0
		var y := 68.0+(crack%2)*17.0
		draw_polyline(PackedVector2Array([Vector2(x,y),Vector2(x+7,y+7),Vector2(x+3,y+15),Vector2(x+12,y+23)]),Color(INK_OUTLINE,0.76),4.0,true)
		draw_line(Vector2(x+1,y+1),Vector2(x+6,y+6),Color(color,0.76),1.8,true)

func _draw_divine_node(node_position: Vector2, color: Color, glyph: String, radius: float = 14.0) -> void:
	_draw_soft_glow(node_position,radius+7.0,color,0.85)
	draw_circle(node_position+Vector2(2,3),radius+3.0,Color(INK_OUTLINE,0.86))
	draw_circle(node_position,radius,Color("#FFF8E5"))
	draw_arc(node_position,radius,0,TAU,28,Color(color,0.96),4.0,true)
	draw_circle(node_position,radius-5.0,Color(color,0.26))
	_draw_organ_glyph(node_position,glyph,color.darkened(0.18))

func _draw_cronus() -> void:
	# Cronus: sovereign of the harvest. The crescent sickle and devourer crest
	# retain Gravemaw's gameplay identity without depicting another rock beast.
	var sickle_root := Vector2(-126,150)
	var sickle_tip := Vector2(73,-58)
	_draw_layered_line(PackedVector2Array([sickle_root,sickle_tip]),Color(INK_OUTLINE,0.94),Color("#C47A2C"),18.0,11.0)
	draw_line(sickle_root+Vector2(2,-2),sickle_tip,Color("#FFE28A"),3.0,true)
	draw_arc(Vector2(78,-54),77.0,-PI*0.62,PI*0.62,54,Color(INK_OUTLINE,0.94),19.0,true)
	draw_arc(Vector2(78,-54),77.0,-PI*0.62,PI*0.62,54,CORE_GOLD,12.0,true)
	draw_arc(Vector2(78,-54),73.0,-PI*0.55,PI*0.54,46,Color("#FFF0A8"),3.0,true)
	_draw_titan_base(Color("#F1B784"),Color("#36BFAE"),Color("#FF6B6B"),CORE_GOLD,Color("#F7E2B7"))
	# Chunky royal crown and white harvest beard.
	var crown := PackedVector2Array([Vector2(-31,-84),Vector2(-27,-111),Vector2(-10,-95),Vector2(0,-119),Vector2(12,-95),Vector2(30,-111),Vector2(32,-82)])
	_draw_chunk(crown,CORE_GOLD,4.0,Vector2(2,3))
	var beard := PackedVector2Array([Vector2(-31,-12),Vector2(-19,17),Vector2(-7,8),Vector2(0,34),Vector2(9,8),Vector2(22,17),Vector2(33,-12),Vector2(18,2),Vector2(0,-4),Vector2(-18,2)])
	_draw_chunk(beard,Color("#FFF2D2"),3.5,Vector2(2,3))
	# A bright stylized devourer crest replaces horror teeth with heraldry.
	draw_arc(Vector2(0,65),25.0,0.18,PI-0.18,24,Color("#FF6B6B"),8.0,true)
	for tooth in 5:
		var x := -16.0+tooth*8.0
		draw_colored_polygon(PackedVector2Array([Vector2(x,60),Vector2(x+6,60),Vector2(x+3,69)]),Color("#FFF8E5"))
	_draw_divine_node(Vector2(0,-46),CORE_GOLD,"eye",12.0)
	_draw_divine_node(Vector2(-43,50),BIO_TEAL,"rings",13.0)
	_draw_divine_node(Vector2(66,33),Color("#FF8B47"),"forge",13.0)
	_draw_phase_cracks(Color("#FFF0A8"))

func _draw_hyperion() -> void:
	# Hyperion's dawn wheel and mantle rays communicate scale before the body.
	var halo_center := Vector2(0,-48)
	for ray in 18:
		var angle := ray*TAU/18.0+spin*0.11
		var inner := halo_center+Vector2.from_angle(angle)*73.0
		var outer := halo_center+Vector2.from_angle(angle)*(93.0+(ray%2)*14.0)
		var tangent := Vector2(-sin(angle),cos(angle))*5.5
		var ray_points := PackedVector2Array([inner-tangent,outer,inner+tangent])
		draw_colored_polygon(ray_points,Color(CORE_GOLD,0.7 if ray%2 else 0.9))
	draw_circle(halo_center,76.0,Color("#FFCB57",0.16))
	draw_arc(halo_center,70.0,0,TAU,60,Color("#FF9A47",0.78),9.0,true)
	# Dawn mantle panels echo wings while staying recognizably humanoid.
	for side in [-1.0,1.0]:
		var mantle_rays := PackedVector2Array([Vector2(side*65,-4),Vector2(side*154,-40),Vector2(side*122,14),Vector2(side*161,55),Vector2(side*75,65)])
		_draw_chunk(mantle_rays,Color("#FF9A47"),5.0,Vector2(3,5))
		draw_line(Vector2(side*76,11),Vector2(side*139,48),Color("#FFF0A8",0.82),4.0,true)
	_draw_titan_base(Color("#F7C38B"),Color("#64CDE5"),Color("#FF7B53"),CORE_GOLD,Color("#E99B3D"))
	var sun_crown := PackedVector2Array([Vector2(-29,-82),Vector2(-19,-108),Vector2(-6,-91),Vector2(0,-117),Vector2(8,-91),Vector2(22,-108),Vector2(30,-82)])
	_draw_chunk(sun_crown,Color("#FFE06B"),4.0,Vector2(2,3))
	# Solar breastplate and three essence seals.
	draw_circle(Vector2(0,62),27.0,Color(INK_OUTLINE,0.82))
	draw_circle(Vector2(0,59),23.0,Color("#FFB84D"))
	for ray in 8:
		draw_line(Vector2.from_angle(ray*TAU/8.0)*12.0+Vector2(0,59),Vector2.from_angle(ray*TAU/8.0)*20.0+Vector2(0,59),Color("#FFF3B0"),3.0,true)
	_draw_divine_node(Vector2(0,-43),Color("#FFE06B"),"prism",11.0)
	_draw_divine_node(Vector2(-77,26),Color("#FF8B47"),"wing",13.0)
	_draw_divine_node(Vector2(57,39),BIO_TEAL,"halo",13.0)
	_draw_phase_cracks(Color("#FFF0A8"))

func _draw_oceanus() -> void:
	# Oceanus is the world-river in humanoid form: broad water ribbons circle a
	# sea-king silhouette, with a trident kept behind the readable hit mass.
	for band in 4:
		var radius := 118.0+band*15.0
		var start := -PI*0.92+band*0.42+spin*0.09
		draw_arc(Vector2(0,48),radius,start,start+PI*1.2,58,Color("#4ED6E8",0.16+band*0.035),7.0-band,true)
	var trident_x := 118.0
	_draw_layered_line(PackedVector2Array([Vector2(trident_x,156),Vector2(trident_x,-91)]),Color(INK_OUTLINE,0.9),Color("#F6D36B"),12.0,7.0)
	for offset in [-17.0,0.0,17.0]:
		draw_polyline(PackedVector2Array([Vector2(trident_x,-72),Vector2(trident_x+offset,-101),Vector2(trident_x+offset*0.72,-70)]),Color("#F6D36B"),6.0,true)
	_draw_titan_base(Color("#7ED8E0"),Color("#3198C5"),Color("#6BE0C1"),Color("#F6D36B"),Color("#E6FBF7"))
	# Shell pauldrons and a river beard make Oceanus distinct at thumbnail size.
	for side in [-1.0,1.0]:
		var shell_center := Vector2(side*92,28)
		draw_arc(shell_center,27.0,PI*0.2,PI*1.8,26,Color(INK_OUTLINE,0.9),12.0,true)
		draw_arc(shell_center,27.0,PI*0.2,PI*1.8,26,Color("#B6F1E6"),7.0,true)
		for rib in 3:
			draw_line(shell_center,shell_center+Vector2.from_angle(-0.55+rib*0.55)*24.0,Color("#3B9BC2",0.54),2.0,true)
	var wave_beard := PackedVector2Array([Vector2(-32,-10),Vector2(-25,15),Vector2(-9,5),Vector2(-4,34),Vector2(9,13),Vector2(21,28),Vector2(34,-10),Vector2(15,1),Vector2(0,-5),Vector2(-15,1)])
	_draw_chunk(wave_beard,Color("#C9F8F1"),3.5,Vector2(2,3))
	for curl in [-18.0,0.0,18.0]:
		draw_arc(Vector2(curl,12),9.0,-PI*0.2,PI*1.35,18,Color("#4ABBD1",0.82),2.5,true)
	_draw_divine_node(Vector2(-20,82),Color("#49C6DD"),"vortex",13.0)
	_draw_divine_node(Vector2(38,42),Color("#FFE06B"),"shock",13.0)
	_draw_divine_node(Vector2(76,28),Color("#72E6B7"),"brood",13.0)
	_draw_phase_cracks(Color("#C8FFF4"))

func _draw_mnemosyne() -> void:
	# Mnemosyne is ringed by soft echo silhouettes and nine Muse lights. These
	# are broad memory shapes, not a copied twin-character or mirror UI.
	for side in [-1.0,1.0]:
		var echo := PackedVector2Array([
			Vector2(side*22,-91),Vector2(side*58,-72),Vector2(side*76,-20),
			Vector2(side*95,64),Vector2(side*69,139),Vector2(side*29,157)
		])
		draw_polyline(echo,Color("#B98AE8",0.2),26.0,true)
		draw_polyline(echo,Color("#FFE3F3",0.2),5.0,true)
	for ribbon in 3:
		var y := -2.0+ribbon*55.0
		draw_polyline(PackedVector2Array([Vector2(-151,y+20),Vector2(-82,y-14),Vector2(0,y+9),Vector2(82,y-14),Vector2(151,y+20)]),Color("#B98AE8",0.13+ribbon*0.035),7.0,true)
	_draw_titan_base(Color("#F3BDA7"),Color("#F8EDE7"),Color("#B98AE8"),Color("#EFAF55"),Color("#694B9B"),true)
	# Braids, memory diadem, and nine orbiting Muse sparks.
	for side in [-1.0,1.0]:
		draw_polyline(PackedVector2Array([Vector2(side*32,-56),Vector2(side*43,-26),Vector2(side*39,8),Vector2(side*51,37)]),Color(INK_OUTLINE,0.9),12.0,true)
		draw_polyline(PackedVector2Array([Vector2(side*32,-56),Vector2(side*43,-26),Vector2(side*39,8),Vector2(side*51,37)]),Color("#7F5CB0"),7.0,true)
	draw_arc(Vector2(0,-66),34.0,PI,TAU,28,Color("#EFAF55"),5.0,true)
	for muse in 9:
		var angle := PI+float(muse)*PI/8.0
		var spark := Vector2(cos(angle)*61.0,sin(angle)*47.0)+Vector2(0,-47)
		draw_circle(spark+Vector2(1,2),4.2,Color(INK_OUTLINE,0.44))
		draw_circle(spark,3.2,Color("#FFF0A8"))
	# An open scroll crest signals authored memory rather than generic magic.
	_draw_layered_line(PackedVector2Array([Vector2(-37,61),Vector2(0,72),Vector2(37,61)]),Color(INK_OUTLINE,0.7),Color("#EFAF55"),8.0,4.0)
	_draw_divine_node(Vector2(0,-43),Color("#C69AF0"),"memory",11.0)
	_draw_divine_node(Vector2(31,47),Color("#FF7FA2"),"heart",13.0)
	_draw_divine_node(Vector2(-28,87),Color("#EFAF55"),"lattice",13.0)
	_draw_phase_cracks(Color("#FFF0D5"))

func _draw_breach() -> void:
	var center := EXTERIOR_CENTER+Vector2(0,10)
	var beat := sin(pulse_time*7.0)
	var inner_radius := 27.0+beat*2.5
	_draw_soft_glow(center,41.0,CORE_GOLD,1.8)
	# A broken divine seal replaces a biological wound while preserving the
	# exact same breach timing and target position.
	for shard in 12:
		var angle := float(shard)*TAU/12.0+spin*0.24
		var tangent := Vector2(-sin(angle),cos(angle))
		var outward := Vector2(cos(angle),sin(angle))
		var root := center+outward*(inner_radius-3.0)
		var shard_length := 15.0+float((shard*5)%4)*2.5+beat*(1.0 if shard%2 else -0.6)
		var points := PackedVector2Array([
			root-tangent*6.0,root+outward*shard_length-tangent*3.0,
			root+outward*(shard_length+5.0),root+outward*shard_length+tangent*3.0,
			root+tangent*6.0
		])
		var shard_color := Color("#FFF4B8") if shard%3==0 else BIO_TEAL if shard%3==1 else Color("#FF8A78")
		draw_colored_polygon(points,Color(shard_color,0.96))
		draw_polyline(_closed(points),Color(INK_OUTLINE,0.88),2.4,true)
		var glint := CORE_GOLD if shard%2==0 else Color.WHITE
		draw_polyline(PackedVector2Array([points[0],points[1],points[2]]),Color(glint,0.7),1.8,true)
	var rim := _organic_ellipse(center,inner_radius+9.0,inner_radius+7.0,36,2.8,0.48)
	draw_polyline(_closed(rim),Color(INK_OUTLINE,0.96),9.0,true)
	draw_polyline(_closed(rim),Color(CORE_GOLD,0.96),5.0,true)
	var opening := _organic_ellipse(center,inner_radius,inner_radius*0.86,36,0.7,0.24)
	draw_colored_polygon(opening,Color("#245DA8",0.98))
	for depth_ring in range(4,0,-1):
		var ring_radius := 5.0+depth_ring*5.0
		var tunnel_color := BIO_TEAL if depth_ring%2 else CORE_GOLD
		draw_arc(center+Vector2(0,depth_ring*1.5),ring_radius,spin*(0.4+depth_ring*0.08),spin*(0.4+depth_ring*0.08)+TAU*0.76,28,Color(tunnel_color,0.12+depth_ring*0.095),2.5,true)
	draw_circle(center+Vector2(0,6),5.0+beat*0.8,Color(BIO_TEAL,0.9))
	draw_circle(center+Vector2(-1.5,4.5),2.0,Color.WHITE)

func _draw_broken_divine_node(node_position: Vector2, color: Color, glyph: String) -> void:
	_draw_soft_glow(node_position,20.0,Color("#FF6F75"),0.7)
	draw_circle(node_position+Vector2(2,3),17.0,Color(INK_OUTLINE,0.82))
	draw_circle(node_position,14.0,Color("#FFF8E5",0.94))
	draw_arc(node_position,14.0,-PI*0.86,-PI*0.18,14,Color(color,0.9),4.0,true)
	draw_arc(node_position,14.0,PI*0.14,PI*0.73,14,Color(color,0.62),4.0,true)
	_draw_organ_glyph(node_position,glyph,Color(INK_OUTLINE,0.72))
	draw_polyline(PackedVector2Array([node_position+Vector2(-12,-13),node_position+Vector2(-2,-3),node_position+Vector2(-7,5),node_position+Vector2(12,14)]),Color("#FF6475"),4.0,true)

func _draw_divine_transformations() -> void:
	for token in active_visual_tokens():
		match token:
			"blinded_hunter_eye":
				var eye := Vector2(0,-46)
				_draw_broken_divine_node(eye,CORE_GOLD,"eye")
				draw_line(eye+Vector2(-17,-11),eye+Vector2(17,11),Color("#FF6475"),5.0,true)
				draw_colored_polygon(PackedVector2Array([eye+Vector2(-4,17),eye+Vector2(2,28),eye+Vector2(7,17)]),Color("#FFD765"))
			"collapsed_gravity_lung":
				var lung := Vector2(-43,50)
				_draw_broken_divine_node(lung,BIO_TEAL,"rings")
				for radius in [24.0,31.0]:
					draw_arc(lung,radius,-PI*0.85,PI*0.18,24,Color(BIO_TEAL,0.35),3.0,true)
				draw_line(lung+Vector2(-19,-14),lung+Vector2(20,15),Color("#FF6475"),4.0,true)
			"sealed_bone_forge":
				var forge := Vector2(66,33)
				_draw_broken_divine_node(forge,Color("#FF9B4A"),"forge")
				for bind in [-8.0,0.0,8.0]:
					draw_line(forge+Vector2(-18,bind-6),forge+Vector2(18,bind+6),Color("#8E4773"),3.0,true)
				draw_circle(forge+Vector2(19,-13),4.0,Color(CORE_GOLD,0.68))
			"cracked_prism_cortex":
				var prism := Vector2(0,-43)
				_draw_broken_divine_node(prism,Color("#FFE06B"),"prism")
				draw_line(prism+Vector2(0,-19),prism+Vector2(-5,-3),Color("#FF6475"),4.0,true)
				draw_line(prism+Vector2(-5,-3),prism+Vector2(7,17),Color("#FF6475"),4.0,true)
				for shard in [-1.0,1.0]:
					draw_colored_polygon(PackedVector2Array([prism+Vector2(shard*15,-13),prism+Vector2(shard*29,-20),prism+Vector2(shard*21,-5)]),Color("#FFF2A5",0.84))
			"collapsed_laser_wing":
				var root := Vector2(-77,26)
				_draw_broken_divine_node(root,Color("#FF9A47"),"wing")
				var broken_mantle := PackedVector2Array([root+Vector2(-8,-16),root+Vector2(-49,3),root+Vector2(-27,20),root+Vector2(-63,45),root+Vector2(-8,31)])
				draw_polyline(broken_mantle,Color(INK_OUTLINE,0.72),9.0,true)
				draw_polyline(broken_mantle,Color("#FF6475",0.72),4.0,true)
			"fractured_halo_choir":
				var halo := Vector2(0,-48)
				draw_arc(halo,72.0,-PI*0.86,-PI*0.2,24,Color("#FF6475"),8.0,true)
				draw_arc(halo,72.0,0.08,PI*0.63,24,Color(CORE_GOLD,0.54),8.0,true)
				for shard in [-1.0,1.0]:
					draw_colored_polygon(PackedVector2Array([halo+Vector2(shard*51,-51),halo+Vector2(shard*69,-68),halo+Vector2(shard*59,-40)]),Color("#FFE785",0.74))
			"ruptured_vortex_stomach":
				var vortex := Vector2(-20,82)
				_draw_broken_divine_node(vortex,Color("#49C6DD"),"vortex")
				for radius in [21.0,28.0]:
					draw_arc(vortex,radius,spin,spin+PI*1.15,28,Color("#5BE0E9",0.56),3.0,true)
				for drop in 3:
					draw_circle(vortex+Vector2(-25+drop*9,23+drop*4),3.5-drop*0.5,Color("#C8FFF4",0.82))
			"grounded_shock_gland":
				var gland := Vector2(38,42)
				_draw_broken_divine_node(gland,Color("#FFE06B"),"shock")
				draw_polyline(PackedVector2Array([gland+Vector2(-21,-24),gland+Vector2(-7,-8),gland+Vector2(-14,0),gland+Vector2(4,15),gland+Vector2(16,29)]),Color("#FF6475"),4.0,true)
				draw_line(gland+Vector2(-22,25),gland+Vector2(22,25),Color("#4F78A8"),5.0,true)
			"sealed_brood_sac":
				var sac := Vector2(76,28)
				_draw_broken_divine_node(sac,Color("#72E6B7"),"brood")
				for offset in [Vector2(-12,18),Vector2(0,22),Vector2(12,17)]:
					draw_circle(sac+offset,6.0,Color("#D4FFF0"))
					draw_line(sac+offset-Vector2(4,4),sac+offset+Vector2(4,4),Color("#FF6475"),2.5,true)
			"erased_memory_cortex":
				var memory := Vector2(0,-43)
				_draw_broken_divine_node(memory,Color("#C69AF0"),"memory")
				for stripe in 5:
					var y := -15.0+stripe*7.0
					draw_line(memory+Vector2(-21,y),memory+Vector2(21,y+2),Color("#8C70A8",0.48-stripe*0.055),2.5,true)
				draw_line(memory+Vector2(-22,-18),memory+Vector2(23,18),Color("#FF6475"),5.0,true)
			"stilled_echo_heart":
				var heart := Vector2(31,47)
				_draw_broken_divine_node(heart,Color("#FF7FA2"),"heart")
				draw_line(heart+Vector2(-2,-20),heart+Vector2(5,19),Color("#FF6475"),5.0,true)
				draw_arc(heart,27.0,-PI*0.7,PI*0.18,22,Color("#B98AE8",0.36),3.0,true)
			"shattered_reflection_lattice":
				var lattice := Vector2(-28,87)
				_draw_broken_divine_node(lattice,Color("#EFAF55"),"lattice")
				for shard in 7:
					var angle := shard*TAU/7.0+0.18
					var inner := lattice+Vector2.from_angle(angle)*17.0
					var outer := lattice+Vector2.from_angle(angle+sin(shard)*0.13)*(35.0+shard%2*8.0)
					draw_line(inner,outer,Color("#B98AE8",0.72),3.5,true)

func _draw_organ_status() -> void:
	var organs: Array = definition.get("organs", [])
	for index in organs.size():
		var organ: Dictionary = organs[index]
		var angle := -PI * 0.82 + index * PI * 0.82
		var direction := Vector2(cos(angle),sin(angle))
		var position_icon := EXTERIOR_CENTER + direction*172.0
		var destroyed := destroyed_organs.has(String(organ.id))
		var status_color := Color(VisualTheme.ENEMY, 0.72) if destroyed else _palette((index+1)%3,VisualTheme.VULNERABLE)
		draw_line(EXTERIOR_CENTER+direction*134.0,position_icon-direction*17.0,Color(status_color,0.22 if destroyed else 0.4),3.0,true)
		draw_circle(position_icon+Vector2(2,3),18.0,Color(INK_OUTLINE,0.34))
		draw_circle(position_icon,16.0,Color("#FFF8E5",0.98))
		draw_arc(position_icon,16.0,0,TAU,28,Color(status_color,0.48 if destroyed else 0.94),3.0,true)
		draw_arc(position_icon,11.0,-PI*0.72,PI*0.32,18,Color(status_color,0.16 if destroyed else 0.36),1.2,true)
		if destroyed:
			draw_line(position_icon-Vector2(8,8),position_icon+Vector2(8,8),Color(VisualTheme.ENEMY,0.92),3.0,true)
			draw_line(position_icon+Vector2(8,-8),position_icon-Vector2(8,-8),Color("#5E1A2B"),2.0,true)
		else:
			_draw_organ_glyph(position_icon,String(organ.get("icon","")),status_color)

func _draw_organ_glyph(center: Vector2, icon: String, color: Color) -> void:
	match icon:
		"eye":
			draw_arc(center,8.0,PI,TAU,14,color,1.8,true)
			draw_arc(center,8.0,0,PI,14,color,1.8,true)
			draw_circle(center,2.7,color)
		"rings", "halo":
			draw_arc(center,8.0,0,TAU,18,color,1.7,true)
			draw_arc(center,4.5,0,TAU,14,Color(color,0.62),1.4,true)
		"forge":
			for x in [-5.0,0.0,5.0]:
				draw_line(center+Vector2(x,-7),center+Vector2(x,7),color,1.8,true)
		"prism":
			draw_polyline(PackedVector2Array([center+Vector2(0,-8),center+Vector2(7,0),center+Vector2(0,8),center+Vector2(-7,0),center+Vector2(0,-8)]),color,1.8,true)
		"wing":
			draw_polyline(PackedVector2Array([center+Vector2(-7,6),center+Vector2(-1,-7),center+Vector2(2,1),center+Vector2(8,-4)]),color,2.0,true)
		"vortex":
			for radius in [8.0,5.0,2.5]:
				draw_arc(center,radius,-PI*0.4,PI*1.3,14,Color(color,0.55+radius*0.045),1.5,true)
		"shock":
			draw_polyline(PackedVector2Array([center+Vector2(-4,-8),center+Vector2(2,-2),center+Vector2(-2,1),center+Vector2(5,8)]),color,2.4,true)
		"brood":
			for offset in [Vector2(-4,2),Vector2(3,-3),Vector2(4,5)]:
				draw_circle(center+offset,3.2,Color(color,0.78))
		"memory":
			for y in [-5.0,0.0,5.0]:
				draw_line(center+Vector2(-7,y),center+Vector2(7,y+2),Color(color,0.82),1.5,true)
		"heart":
			draw_circle(center+Vector2(-3,-2),4.5,Color(color,0.72))
			draw_circle(center+Vector2(3,-2),4.5,Color(color,0.72))
			draw_colored_polygon(PackedVector2Array([center+Vector2(-7,0),center+Vector2(7,0),center+Vector2(0,8)]),Color(color,0.72))
		"lattice":
			for angle in [0.0,PI/3.0,PI*2.0/3.0]:
				draw_line(center+Vector2.from_angle(angle)*8.0,center-Vector2.from_angle(angle)*8.0,color,1.7,true)
		_:
			draw_circle(center,5.0,Color(color,0.72))

func _draw_divine_interior() -> void:
	var boss_id := String(definition.get("id","gravemaw"))
	var primary := CORE_GOLD
	var secondary := BIO_TEAL
	match boss_id:
		"seraph_9":
			primary=Color("#FFB84D")
			secondary=Color("#FFE98A")
		"abyss_leviathan":
			primary=Color("#48C9DC")
			secondary=Color("#86EDC3")
		"null_twin":
			primary=Color("#B98AE8")
			secondary=Color("#FF91B7")
	var organ_id := String(selected_organ.get("id","essence"))
	var seed_phase := float(abs(organ_id.hash())%1000)*0.013
	var pulse := 1.0+sin(pulse_time*4.2+seed_phase)*0.035
	# Divine essence replaces anatomical gore: long light paths preserve the
	# spatial connection to the Titan outside while leaving enemy shots legible.
	for ray in 16:
		var angle := ray*TAU/16.0+spin*0.08
		var start := Vector2.from_angle(angle)*76.0
		var bend := Vector2.from_angle(angle+sin(ray*1.7)*0.12)*176.0
		var finish := Vector2.from_angle(angle)*355.0
		var ray_color := primary if ray%2==0 else secondary
		_draw_layered_line(PackedVector2Array([start,bend,finish]),Color(INK_OUTLINE,0.08),Color(ray_color,0.11),8.0+ray%3*2.0,3.0)
	for orbit in range(6,0,-1):
		var radius := 78.0+orbit*35.0
		var start_angle := seed_phase+orbit*0.61+spin*(0.18 if orbit%2 else -0.12)
		draw_arc(Vector2.ZERO,radius,start_angle,start_angle+PI*(0.55+orbit*0.07),72,Color(primary if orbit%2 else secondary,0.025+orbit*0.018),5.0,true)
	# Constellation anchors make each chamber feel authored by its deterministic
	# organ ID, not assembled from random biological clutter.
	var anchors := PackedVector2Array()
	for point_index in 9:
		var angle := point_index*TAU/9.0+seed_phase*0.17
		var distance := 112.0+float((point_index*17)%5)*18.0
		anchors.append(Vector2.from_angle(angle)*distance)
	for point_index in anchors.size():
		var from := anchors[point_index]
		var to := anchors[(point_index+3)%anchors.size()]
		draw_line(from,to,Color(secondary,0.08),2.0,true)
		draw_circle(from,4.0,Color(primary,0.52))
		draw_circle(from-Vector2(1,1),1.5,Color.WHITE)
	_draw_soft_glow(Vector2.ZERO,84.0,primary,1.4)
	var shadow := _organic_ellipse(Vector2(5,8),78.0*pulse,70.0*pulse,40,seed_phase,0.25)
	draw_colored_polygon(shadow,Color(INK_OUTLINE,0.68))
	# Faceted celestial seal sized to the unchanged 67px collision target.
	var outer_crystal := PackedVector2Array([
		Vector2(0,-70)*pulse,Vector2(48,-47)*pulse,Vector2(69,-4)*pulse,
		Vector2(50,48)*pulse,Vector2(0,68)*pulse,Vector2(-50,48)*pulse,
		Vector2(-69,-4)*pulse,Vector2(-48,-47)*pulse
	])
	_draw_chunk(outer_crystal,primary.lightened(0.12),6.0,Vector2(3,5))
	var inner_crystal := PackedVector2Array([Vector2(0,-52),Vector2(38,-24),Vector2(35,29),Vector2(0,51),Vector2(-35,29),Vector2(-38,-24)])
	draw_colored_polygon(inner_crystal,Color(secondary,0.78))
	draw_polyline(_closed(inner_crystal),Color("#FFF8E5",0.72),3.0,true)
	for point in outer_crystal:
		draw_line(Vector2.ZERO,point,Color("#FFF8E5",0.2),2.0,true)
	var icon := String(selected_organ.get("icon",""))
	draw_circle(Vector2.ZERO,25.0,Color(INK_OUTLINE,0.78))
	draw_circle(Vector2.ZERO,20.0,Color("#FFF8E5"))
	_draw_organ_glyph(Vector2.ZERO,icon,primary.darkened(0.18))
	draw_circle(Vector2(-6,-7),3.0,Color.WHITE)
	var health_color := Color("#65DFA1") if health_ratio>0.3 else Color("#FF6475")
	draw_arc(Vector2.ZERO,86.0,-PI/2,-PI/2+TAU*health_ratio,64,Color(health_color,0.94),7.0,true)
	draw_arc(Vector2.ZERO,86.0,-PI/2+TAU*health_ratio,-PI/2+TAU,64,Color(INK_OUTLINE,0.28),5.0,true)
	for anchor in 8:
		var anchor_angle := anchor*TAU/8.0
		var anchor_point := Vector2.from_angle(anchor_angle)*86.0
		draw_colored_polygon(PackedVector2Array([anchor_point+Vector2.from_angle(anchor_angle-0.7)*5.0,anchor_point+Vector2.from_angle(anchor_angle)*10.0,anchor_point+Vector2.from_angle(anchor_angle+0.7)*5.0]),Color("#FFF0A8"))
	if hit_flash>0.0:
		draw_colored_polygon(outer_crystal,Color(1,1,1,0.18))
