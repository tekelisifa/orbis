class_name Arena
extends AnimatableBody2D
## L'arène : un anneau néon arc-en-ciel, avec une ouverture (mode Orbite) qui tourne.
## Collision : segments le long du cercle, sauf dans l'ouverture.

const SEGMENTS := 120

var radius := 300.0
var gap := 0.0            # largeur de l'ouverture en radians (0 = anneau fermé)
var hue := 0.0
var flashes: Array[Vector3] = []   # (angle local, intensité, teinte)
var _shape: CollisionShape2D


func setup(r: float, gap_rad: float) -> void:
	radius = r
	gap = gap_rad
	sync_to_physics = true
	var seg := ConcavePolygonShape2D.new()
	var pts := PackedVector2Array()
	var start := -PI * 0.5 + gap * 0.5
	var span := TAU - gap
	for i in SEGMENTS:
		var a0 := start + span * i / SEGMENTS
		var a1 := start + span * (i + 1) / SEGMENTS
		pts.append(Vector2(cos(a0), sin(a0)) * (radius + 6.0))
		pts.append(Vector2(cos(a1), sin(a1)) * (radius + 6.0))
	seg.segments = pts
	_shape = CollisionShape2D.new()
	_shape.shape = seg
	add_child(_shape)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	pm.friction = 0.5
	physics_material_override = pm


## Un orbe touche l'anneau : un éclat de lumière à cet endroit.
func flash_at(global_point: Vector2, strength: float) -> void:
	var local := to_local(global_point)
	flashes.append(Vector3(local.angle(), clampf(strength, 0.2, 1.0), hue))
	if flashes.size() > 24:
		flashes.remove_at(0)


func _process(delta: float) -> void:
	hue = fposmod(hue + delta * 0.05, 1.0)
	for i in range(flashes.size() - 1, -1, -1):
		var f := flashes[i]
		f.y -= delta * 2.2
		if f.y <= 0.0:
			flashes.remove_at(i)
		else:
			flashes[i] = f
	queue_redraw()


func ring_points(rr: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var start := -PI * 0.5 + gap * 0.5
	var span := TAU - gap
	var n := 160
	for i in n + 1:
		var a := start + span * i / n
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


func ring_colors(count: int, val := 1.0, alpha := 1.0) -> PackedColorArray:
	var cols := PackedColorArray()
	for i in count:
		var c := Art.rainbow(hue + float(i) / float(count - 1) * 0.85, 0.72, val)
		c.a = alpha
		cols.append(c)
	return cols


## Cœur net de l'anneau (le halo est dessiné par la couche lumineuse).
func _draw() -> void:
	var pts := ring_points(radius)
	draw_polyline_colors(pts, ring_colors(pts.size()), 7.0, true)
	draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0, true)
	# Extrémités de l'ouverture : petites perles lumineuses.
	if gap > 0.0:
		for a in [-PI * 0.5 + gap * 0.5, -PI * 0.5 - gap * 0.5]:
			Art.circle(self, Vector2(cos(a), sin(a)) * radius, 9.0, Color(1, 1, 1, 0.95))


## Halo additif de l'anneau et éclats, dessinés par la couche lumineuse.
func draw_glow(ci: CanvasItem) -> void:
	var xf := get_global_transform()
	var pts := ring_points(radius)
	for i in pts.size():
		pts[i] = xf * pts[i]
	ci.draw_polyline_colors(pts, ring_colors(pts.size(), 1.0, 0.16), 34.0, true)
	ci.draw_polyline_colors(pts, ring_colors(pts.size(), 1.0, 0.28), 14.0, true)
	for f in flashes:
		var p: Vector2 = xf * (Vector2(cos(f.x), sin(f.x)) * radius)
		var c := Art.rainbow(f.z + 0.5, 0.35, 1.0)
		c.a = f.y * 0.9
		Art.halo(ci, p, 70.0 * f.y + 20.0, c)
