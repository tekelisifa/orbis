extends Node
## Direction artistique : textures générées (disques nets, halos, ombrage de sphère),
## polices, et les 11 formes d'orbes, de l'étincelle à la supernova.

const BG := Color("05060d")

## Univers : chaque univers a ses 11 formes (même taille et mêmes points d'un univers à l'autre).
const UNIVERSES := {
	"cosmos": {"name": "Cosmos", "final": "SUPERNOVA !", "bang": "BIG BANG !"},
	"chats": {"name": "Chats", "final": "CHAT COSMIQUE !", "bang": "MÉGA MIAOU !"},
}
## [nom, couleur du pelage] pour l'univers Chats.
const CATS := [
	["Chaton", Color("ffe2b8")],
	["Minou", Color("b9bccb")],
	["Tigré", Color("a3a9b8")],
	["Roux", Color("ff9b4a")],
	["Siamois", Color("f3e3c8")],
	["Chat noir", Color("2e2b37")],
	["Persan", Color("f6f2ff")],
	["Tricolore", Color("fff4e6")],
	["Chat-lion", Color("f2b35a")],
	["Roi des chats", Color("ffd447")],
	["Chat cosmique", Color("ffffff")],
]

## [nom, rayon, couleur, points]
const TIERS := [
	["Étincelle", 22.0, Color("ffe066"), 1],
	["Goutte", 28.0, Color("5ef2ff"), 3],
	["Bulle", 35.0, Color("7d8bff"), 6],
	["Lune", 43.0, Color("d6dcf0"), 10],
	["Corail", 52.0, Color("ff6f91"), 15],
	["Braise", 62.0, Color("ff9a3c"), 21],
	["Anneaux", 73.0, Color("b98cff"), 28],
	["Océan", 85.0, Color("2fd8a8"), 36],
	["Géante", 98.0, Color("ff4f5e"), 45],
	["Étoile", 112.0, Color("ffd84a"), 55],
	["Supernova", 128.0, Color("ffffff"), 100],
]
const FINAL := 10

var disc: GradientTexture2D
var glow: GradientTexture2D
var shade: GradientTexture2D
var spec: GradientTexture2D
var font: FontVariation
var font_bold: FontVariation
var add_mat: CanvasItemMaterial


func _ready() -> void:
	disc = _radial([[0.0, Color(1, 1, 1, 1)], [0.975, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]], Vector2(0.5, 0.5), 256)
	glow = _radial([[0.0, Color(1, 1, 1, 0.85)], [0.18, Color(1, 1, 1, 0.45)], [0.45, Color(1, 1, 1, 0.14)], [0.75, Color(1, 1, 1, 0.035)], [1.0, Color(1, 1, 1, 0)]], Vector2(0.5, 0.5), 128)
	# Ombrage : clair en haut à gauche, sombre sur le bord bas-droit.
	shade = _radial([[0.0, Color(1, 1, 1, 0.0)], [0.55, Color(0, 0, 0, 0.0)], [0.85, Color(0, 0, 0, 0.28)], [0.975, Color(0, 0, 0, 0.5)], [1.0, Color(0, 0, 0, 0)]], Vector2(0.42, 0.38), 256, Vector2(1.04, 1.04))
	spec = _radial([[0.0, Color(1, 1, 1, 0.9)], [0.35, Color(1, 1, 1, 0.35)], [1.0, Color(1, 1, 1, 0)]], Vector2(0.5, 0.5), 64)
	var base: FontFile = load("res://fonts/Fredoka.ttf")
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	font = FontVariation.new()
	font.base_font = base
	font.variation_opentype = {wght: 500}
	font_bold = FontVariation.new()
	font_bold.base_font = base
	font_bold.variation_opentype = {wght: 640}
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _radial(stops: Array, center: Vector2, size: int, to_scale := Vector2.ONE) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for st in stops:
		offs.append(float(st[0]))
		cols.append(st[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = center
	t.fill_to = center + Vector2(0.5, 0.0) * to_scale
	t.width = size
	t.height = size
	return t


static func radius(tier: int) -> float:
	return float(TIERS[clampi(tier, 0, FINAL)][1])


static func cats() -> bool:
	return Save.universe == "chats"


static func color(tier: int) -> Color:
	if cats():
		return CATS[clampi(tier, 0, FINAL)][1]
	return TIERS[clampi(tier, 0, FINAL)][2]


static func final_text() -> String:
	return str(UNIVERSES[Save.universe]["final"])


static func bang_text() -> String:
	return str(UNIVERSES[Save.universe]["bang"])


static func points(tier: int) -> int:
	return int(TIERS[clampi(tier, 0, FINAL)][3])


static func tier_name(tier: int) -> String:
	if cats():
		return str(CATS[clampi(tier, 0, FINAL)][0])
	return str(TIERS[clampi(tier, 0, FINAL)][0])


## Couleur arc-en-ciel néon pour un angle (0..1).
static func rainbow(u: float, sat := 0.75, val := 1.0) -> Color:
	return Color.from_hsv(fposmod(u, 1.0), sat, val)


func circle(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(disc, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func halo(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(glow, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## Dessine un orbe complet à l'origine locale (le nœud porte la rotation).
## mood : 0 = content, 1 = surpris, 2 = endormi, 3 = ravi.
func draw_orb(ci: CanvasItem, pos: Vector2, r: float, tier: int, mood: int, t: float, blink: bool, alpha := 1.0) -> void:
	if cats():
		draw_cat(ci, pos, r, tier, mood, t, blink, alpha)
		return
	var col := color(tier)
	if tier == FINAL:
		col = rainbow(t * 0.15, 0.25, 1.0)
	var a := Color(1, 1, 1, alpha)
	# Corps.
	circle(ci, pos, r, col * a)
	# Détails propres à certaines formes.
	match tier:
		3:  # Lune : cratères
			for c in [[Vector2(-0.35, 0.3), 0.18], [Vector2(0.4, -0.15), 0.13], [Vector2(0.15, 0.5), 0.1]]:
				circle(ci, pos + (c[0] as Vector2) * r, float(c[1]) * r, Color(0.62, 0.66, 0.8, 0.55 * alpha))
		7:  # Océan : bandes de vagues
			for k in 3:
				var y := (-0.15 + k * 0.28) * r
				var pts := PackedVector2Array()
				for i in 13:
					var x := -r * 0.8 + i * r * 1.6 / 12.0
					if Vector2(x, y).length() < r * 0.92:
						pts.append(pos + Vector2(x, y + sin(i * 0.9 + t * 2.0 + k) * r * 0.05))
				if pts.size() > 1:
					ci.draw_polyline(pts, Color(1, 1, 1, 0.22 * alpha), maxf(2.0, r * 0.05), true)
		8:  # Géante : bandes
			for k in 2:
				var yy := (-0.25 + k * 0.45) * r
				var half := sqrt(maxf(0.0, r * r * 0.86 - yy * yy))
				ci.draw_line(pos + Vector2(-half, yy), pos + Vector2(half, yy), Color(0.6, 0.1, 0.2, 0.35 * alpha), r * 0.12, true)
	# Volume.
	ci.draw_texture_rect(shade, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, a)
	ci.draw_texture_rect(spec, Rect2(pos + Vector2(-0.62, -0.66) * r, Vector2(r, r) * 0.62), false, Color(1, 1, 1, 0.8 * alpha))
	# Anneau de la forme « Anneaux », devant le corps.
	if tier == 6:
		var ring := PackedVector2Array()
		for i in 33:
			var ang := PI * 0.05 + i * PI * 0.9 / 32.0
			ring.append(pos + Vector2(cos(ang) * r * 1.45, sin(ang) * r * 0.42 + r * 0.08))
		ci.draw_polyline(ring, Color(1.0, 0.85, 1.0, 0.85 * alpha), maxf(3.0, r * 0.1), true)
	# Visage.
	_face(ci, pos, r, mood, blink, alpha, tier)


func _face(ci: CanvasItem, pos: Vector2, r: float, mood: int, blink: bool, alpha: float, tier: int) -> void:
	var ink := Color(0.09, 0.05, 0.16, alpha)
	var ex := r * 0.3
	var ey := -r * 0.08
	var er := r * 0.12
	for sx in [-1.0, 1.0]:
		var e := pos + Vector2(sx * ex, ey)
		if blink or mood == 2:
			ci.draw_arc(e + Vector2(0, er * 0.2), er, PI * 0.15, PI * 0.85, 10, ink, maxf(2.0, r * 0.05), true)
		elif mood == 3:
			ci.draw_arc(e + Vector2(0, er * 0.4), er, PI * 1.15, PI * 1.85, 10, ink, maxf(2.0, r * 0.06), true)
		else:
			var h := er * (1.35 if mood == 1 else 1.15)
			ci.draw_texture_rect(disc, Rect2(e - Vector2(er * 0.8, h), Vector2(er * 1.6, h * 2.0)), false, ink)
			circle(ci, e + Vector2(-er * 0.25, -h * 0.4), er * 0.32, Color(1, 1, 1, 0.9 * alpha))
	# Joues.
	if tier != 3:
		for sx in [-1.0, 1.0]:
			circle(ci, pos + Vector2(sx * r * 0.5, r * 0.18), r * 0.13, Color(1.0, 0.45, 0.6, 0.35 * alpha))
	# Bouche.
	var m := pos + Vector2(0, r * 0.26)
	match mood:
		1:
			ci.draw_texture_rect(disc, Rect2(m - Vector2(r * 0.09, r * 0.12), Vector2(r * 0.18, r * 0.24)), false, ink)
		2:
			ci.draw_line(m - Vector2(r * 0.1, 0), m + Vector2(r * 0.1, 0), ink, maxf(2.0, r * 0.045), true)
		_:
			ci.draw_arc(m - Vector2(0, r * 0.1), r * 0.16, PI * 0.2, PI * 0.8, 12, ink, maxf(2.0, r * 0.05), true)


# --- Univers Chats : chats dessinés à la main, du chaton au chat cosmique ---

func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)


func draw_cat(ci: CanvasItem, pos: Vector2, r: float, tier: int, mood: int, t: float, blink: bool, alpha := 1.0) -> void:
	var fur := color(tier)
	if tier == FINAL:
		fur = rainbow(t * 0.15, 0.3, 1.0)
	fur.a = alpha
	var dark := fur.darkened(0.38)
	dark.a = alpha
	var pink := Color(1.0, 0.62, 0.72, alpha)
	# Crinière (chat-lion) et fourrure (persan) derrière la tête.
	if tier == 8:
		for i in 14:
			var a := i * TAU / 14.0 + t * 0.2
			circle(ci, pos + Vector2(cos(a), sin(a)) * r * 0.92, r * 0.34, Color(0.78, 0.42, 0.16, alpha))
	elif tier == 6:
		for i in 16:
			var a := i * TAU / 16.0
			circle(ci, pos + Vector2(cos(a), sin(a)) * r * 0.86, r * 0.24, fur)
	# Oreilles.
	for sx: float in [-1.0, 1.0]:
		var tip := pos + Vector2(sx * 0.66, -1.12) * r
		var b1 := pos + Vector2(sx * 0.16, -0.84) * r
		var b2 := pos + Vector2(sx * 0.95, -0.38) * r
		var ear_col := dark if tier == 4 else fur
		_tri(ci, tip, b1, b2, ear_col)
		var cen := (tip + b1 + b2) / 3.0
		_tri(ci, cen + (tip - cen) * 0.55, cen + (b1 - cen) * 0.55, cen + (b2 - cen) * 0.55, pink if tier != 5 else Color(0.55, 0.35, 0.45, alpha))
	# Tête : bord un peu plus sombre, lumière venant d'en haut à gauche.
	if tier == FINAL:
		halo(ci, pos, r * 1.7, Color(fur.r, fur.g, fur.b, 0.35 * alpha))
	var rim := fur.darkened(0.2)
	rim.a = alpha
	circle(ci, pos, r, rim)
	circle(ci, pos + Vector2(-0.06, -0.06) * r, r * 0.91, fur)
	# Motifs du pelage.
	match tier:
		2, 3:
			var st := dark
			st.a = 0.75 * alpha
			for k in 3:
				var x := (-0.22 + k * 0.22) * r
				ci.draw_line(pos + Vector2(x, -0.95 * r), pos + Vector2(x * 0.8, -0.62 * r), st, maxf(2.0, r * 0.09), true)
			for sx: float in [-1.0, 1.0]:
				for k in 2:
					var y := (0.0 + k * 0.2) * r
					ci.draw_line(pos + Vector2(sx * 0.96 * r, y), pos + Vector2(sx * 0.72 * r, y + 0.04 * r), st, maxf(2.0, r * 0.07), true)
		4:
			ci.draw_texture_rect(disc, Rect2(pos + Vector2(-0.42, -0.2) * r, Vector2(0.84, 0.7) * r), false, Color(0.42, 0.29, 0.22, 0.75 * alpha))
		7:
			circle(ci, pos + Vector2(-0.4, -0.48) * r, r * 0.32, Color(1.0, 0.6, 0.25, alpha))
			circle(ci, pos + Vector2(0.45, 0.42) * r, r * 0.26, Color(0.2, 0.18, 0.22, alpha))
		10:
			for i in 7:
				var a := i * 2.4 + t * 0.4
				var d := r * (0.25 + 0.1 * (i % 4))
				circle(ci, pos + Vector2(cos(a), sin(a)) * d * 1.45, r * 0.05, Color(1, 1, 1, 0.85 * alpha))
	# Reflet.
	ci.draw_texture_rect(spec, Rect2(pos + Vector2(-0.62, -0.66) * r, Vector2(r, r) * 0.55), false, Color(1, 1, 1, 0.55 * alpha))
	# Couronne du roi (et du chat cosmique).
	if tier >= 9:
		var gold := Color(1.0, 0.82, 0.25, alpha) if tier == 9 else rainbow(t * 0.3, 0.5)
		var y0 := -0.8 * r
		var pts := PackedVector2Array([
			pos + Vector2(-0.42 * r, y0), pos + Vector2(-0.5 * r, y0 - 0.42 * r), pos + Vector2(-0.22 * r, y0 - 0.2 * r),
			pos + Vector2(0, y0 - 0.5 * r), pos + Vector2(0.22 * r, y0 - 0.2 * r), pos + Vector2(0.5 * r, y0 - 0.42 * r),
			pos + Vector2(0.42 * r, y0)])
		ci.draw_colored_polygon(pts, gold)
		circle(ci, pos + Vector2(0, y0 - 0.12 * r), r * 0.07, Color(0.9, 0.15, 0.3, alpha))
	_cat_face(ci, pos, r, tier, mood, blink, alpha)


func _cat_face(ci: CanvasItem, pos: Vector2, r: float, tier: int, mood: int, blink: bool, alpha: float) -> void:
	var ink := Color(0.12, 0.07, 0.12, alpha)
	var light := tier == 5
	var line_col := Color(0.95, 0.92, 1.0, alpha) if light else ink
	var iris := Color("8fdc5a") if tier == 5 else (Color("5fb8ff") if tier == 4 else Color("ffb84a"))
	iris.a = alpha
	var er := r * 0.17
	for sx: float in [-1.0, 1.0]:
		var e := pos + Vector2(sx * 0.33 * r, -0.08 * r)
		if blink or mood == 2:
			ci.draw_arc(e + Vector2(0, er * 0.1), er * 0.9, PI * 0.15, PI * 0.85, 10, line_col, maxf(2.0, r * 0.05), true)
		elif mood == 3:
			ci.draw_arc(e + Vector2(0, er * 0.45), er * 0.85, PI * 1.15, PI * 1.85, 10, line_col, maxf(2.0, r * 0.06), true)
		else:
			circle(ci, e, er, iris)
			var pw := er * (0.75 if mood == 1 else 0.28)
			ci.draw_texture_rect(disc, Rect2(e - Vector2(pw, er * 0.85), Vector2(pw * 2.0, er * 1.7)), false, ink)
			circle(ci, e + Vector2(-er * 0.35, -er * 0.4), er * 0.28, Color(1, 1, 1, 0.9 * alpha))
	# Joues.
	if tier != 5:
		for sx: float in [-1.0, 1.0]:
			circle(ci, pos + Vector2(sx * 0.55 * r, 0.2 * r), r * 0.13, Color(1.0, 0.5, 0.6, 0.3 * alpha))
	# Museau : nez, bouche en « w », moustaches.
	var nose := pos + Vector2(0, 0.14 * r)
	_tri(ci, nose + Vector2(-0.08, -0.04) * r, nose + Vector2(0.08, -0.04) * r, nose + Vector2(0, 0.05) * r, Color(1.0, 0.5, 0.62, alpha))
	if mood == 1:
		ci.draw_texture_rect(disc, Rect2(nose + Vector2(-0.07, 0.08) * r, Vector2(0.14, 0.16) * r), false, ink)
	else:
		for sx: float in [-1.0, 1.0]:
			ci.draw_arc(nose + Vector2(sx * 0.075 * r, 0.06 * r), 0.075 * r, 0.0, PI, 10, line_col, maxf(1.5, r * 0.035), true)
	var wc := Color(1, 1, 1, 0.7 * alpha) if tier in [5, 3, 8] else Color(0.25, 0.2, 0.25, 0.55 * alpha)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var from := pos + Vector2(sx * 0.3 * r, (0.12 + k * 0.06) * r)
			var to := pos + Vector2(sx * 0.85 * r, (0.02 + k * 0.13) * r)
			ci.draw_line(from, to, wc, maxf(1.0, r * 0.022), true)
