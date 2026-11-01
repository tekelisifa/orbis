extends Node2D
## Une partie d'Orbis.
## Modes :
## - "chute" : on vise et on lâche l'orbe suivant ; les orbes identiques fusionnent.
##   Perdu si la pile dépasse la ligne rouge trop longtemps.
## - "orbite" : les orbes apparaissent seuls ; on fait tourner l'arène du doigt pour
##   les rapprocher et les garder dedans. Chaque orbe qui s'échappe coûte une vie.
## `demo` : la partie se joue toute seule (fond du menu, vidéos promo).

const FINAL := 10
const DROP_WEIGHTS := [30, 26, 20, 14, 10]
const ORBIT_WEIGHTS := [34, 30, 22, 14]

var mode := "orbite"
var demo := false
var record := false

var center := Vector2(360, 700)
var R := 300.0
var score := 0
var combo := 0
var lives := 3
var over := false
var time := 0.0

var arena: Arena
var orbs: Node2D
var cam: Camera2D
var ui: GameUI

# Chute
var aim_x := 360.0
var current := 0
var next := 0
var drop_cd := 0.0
var danger := 0.0
var spawn_y := 0.0

# Orbite
var rot_target := 0.0
var rot_vel := 0.0
var spawn_t := 0.0
var drag_angle := 0.0
var dragging := false

# Effets
var parts_pos := PackedVector2Array()
var parts_vel := PackedVector2Array()
var parts_life := PackedFloat32Array()
var parts_max := PackedFloat32Array()
var parts_size := PackedFloat32Array()
var parts_col := PackedColorArray()
var waves: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var portals: Array[Vector3] = []
var stars: Array[Vector3] = []
var trauma := 0.0
var _last_merge := -10.0
var _ai_t := 0.0
var _bang := 0.0


func _ready() -> void:
	var vs := get_viewport_rect().size
	R = minf(vs.x * 0.44, 318.0)
	center = Vector2(vs.x * 0.5, vs.y * 0.55)
	for i in 140:
		stars.append(Vector3(randf() * vs.x, randf() * vs.y, randf() * TAU))

	add_child(Painter.make(_draw_background, true))
	add_child(Painter.make(_draw_glow, true))
	arena = Arena.new()
	arena.position = center
	arena.setup(R, deg_to_rad(54.0) if mode == "orbite" else 0.0)
	add_child(arena)
	orbs = Node2D.new()
	add_child(orbs)
	add_child(Painter.make(_draw_fx, true))
	add_child(Painter.make(_draw_top))
	cam = Camera2D.new()
	cam.position = vs * 0.5
	add_child(cam)
	cam.make_current()

	spawn_y = center.y - R * 0.7
	aim_x = center.x
	current = _roll(DROP_WEIGHTS)
	next = _roll(DROP_WEIGHTS)
	if not demo or record:
		ui = GameUI.new()
		ui.game = self
		add_child(ui)
	Sfx.start_ambience()


func _roll(weights: Array) -> int:
	# Vidéo promo : le niveau des orbes lâchés monte avec le temps, pour atteindre
	# la forme finale en une trentaine de secondes.
	if record and mode == "chute":
		var lo := mini(int(time / 3.2), 7)
		return randi_range(lo, lo + 1)
	var total := 0
	for w in weights:
		total += int(w)
	var x := randi() % total
	for i in weights.size():
		x -= int(weights[i])
		if x < 0:
			return i
	return 0


# --- Orbes ---

func spawn(tier: int, pos: Vector2, vel := Vector2.ZERO) -> Orb:
	var o := Orb.create(tier, 0.12 if mode == "chute" else 0.45)
	o.position = pos
	o.linear_velocity = vel
	o.touched.connect(_on_touched)
	orbs.add_child(o)
	return o


func _on_touched(o: Orb, other: Node, speed: float) -> void:
	if other is Arena:
		if speed > 140.0:
			Sfx.bounce(speed / 1500.0)
			var dir := (o.global_position - center).normalized()
			arena.flash_at(o.global_position + dir * o.r, speed / 1500.0)
			_burst(o.global_position + dir * o.r, Art.rainbow(arena.hue + 0.3, 0.4), 4, 120.0, 3.0)
	elif other is Orb:
		var b := other as Orb
		if b.tier == o.tier and not o.merging and not b.merging and not over:
			o.merging = true
			b.merging = true
			_merge.call_deferred(o, b)
		elif speed > 520.0:
			Sfx.bounce(speed / 3000.0)


func _merge(a: Orb, b: Orb) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var pos := (a.global_position * a.mass + b.global_position * b.mass) / (a.mass + b.mass)
	var vel := (a.linear_velocity + b.linear_velocity) * 0.5
	var t := a.tier
	a.queue_free()
	b.queue_free()
	combo = combo + 1 if time - _last_merge < 1.5 else 1
	_last_merge = time
	if t == FINAL:
		_big_bang(pos)
		return
	var nt := t + 1
	var o := spawn(nt, pos, vel * 0.4)
	o.cheer()
	var pts := Art.points(nt) * combo
	score += pts
	var col := Art.color(nt)
	_burst(pos, col, 14 + nt * 2, 260.0 + nt * 20.0, 5.0 + nt * 0.4)
	waves.append({"pos": pos, "r": o.r, "life": 1.0, "col": col, "w": 6.0 + nt})
	Sfx.merge(nt, combo)
	if Art.cats():
		Sfx.meow(nt)
	trauma = minf(1.0, trauma + 0.12 + nt * 0.03)
	Save.buzz(10 + nt * 3)
	_popup(pos + Vector2(0, -o.r - 10), "+%d" % pts, col, 34 + nt * 2)
	if combo >= 2:
		_popup(pos + Vector2(0, -o.r - 52), "COMBO ×%d" % combo, Art.rainbow(time * 0.3), 40 + mini(combo, 6) * 4)
	if Save.discover(nt) and not demo:
		_popup(center + Vector2(0, -R - 80), "Nouvelle forme : %s !" % Art.tier_name(nt), col, 40)
	if nt == FINAL:
		_final_form(pos)


func _final_form(pos: Vector2) -> void:
	Sfx.final_form()
	Save.buzz(120)
	trauma = 1.0
	_burst(pos, Color.WHITE, 90, 700.0, 9.0)
	for k in 3:
		waves.append({"pos": pos, "r": 40.0 + k * 30.0, "life": 1.0 + k * 0.3, "col": Art.rainbow(k * 0.33), "w": 14.0})
	_popup(pos + Vector2(0, -170), Art.final_text(), Color.WHITE, 72)
	score += 200
	_slowmo(0.3, 1.6)


func _big_bang(pos: Vector2) -> void:
	_bang = 1.0
	score += 1000 * maxi(1, combo)
	Sfx.final_form()
	Save.buzz(200)
	trauma = 1.0
	for k in 5:
		waves.append({"pos": pos, "r": 30.0 + k * 40.0, "life": 1.2 + k * 0.25, "col": Art.rainbow(k * 0.2), "w": 18.0})
	_burst(pos, Color.WHITE, 160, 900.0, 10.0)
	_popup(pos + Vector2(0, -150), Art.bang_text(), Color.WHITE, 84)
	_slowmo(0.25, 2.2)


func _slowmo(scale: float, dur: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(dur, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


# --- Effets ---

func _burst(pos: Vector2, col: Color, n: int, speed: float, size: float) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0)
		parts_pos.append(pos)
		parts_vel.append(v)
		var life := randf_range(0.4, 0.9)
		parts_life.append(life)
		parts_max.append(life)
		parts_size.append(size * randf_range(0.6, 1.4))
		var c := col.lerp(Color.WHITE, randf() * 0.5)
		parts_col.append(c)


func _popup(pos: Vector2, text: String, col: Color, size: int) -> void:
	if demo and not record:
		return
	if record:
		pos.y = maxf(pos.y, 330.0)
	popups.append({"pos": pos, "text": text, "col": col, "life": 1.0, "size": size})


# --- Boucle ---

func _process(delta: float) -> void:
	time += delta
	drop_cd = maxf(0.0, drop_cd - delta)
	trauma = maxf(0.0, trauma - delta * 1.6)
	var sh := trauma * trauma * 22.0
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * sh
	_bang = maxf(0.0, _bang - delta * 1.6)

	# Particules.
	for i in range(parts_pos.size() - 1, -1, -1):
		parts_life[i] -= delta
		if parts_life[i] <= 0.0:
			parts_pos.remove_at(i)
			parts_vel.remove_at(i)
			parts_life.remove_at(i)
			parts_max.remove_at(i)
			parts_size.remove_at(i)
			parts_col.remove_at(i)
			continue
		parts_vel[i] = parts_vel[i] * (1.0 - delta * 2.2) + Vector2(0, 220.0) * delta
		parts_pos[i] = parts_pos[i] + parts_vel[i] * delta
	for w in waves:
		w["life"] = float(w["life"]) - delta * 1.4
		w["r"] = float(w["r"]) + delta * 420.0
	waves = waves.filter(func(w: Dictionary) -> bool: return float(w["life"]) > 0.0)
	for p in popups:
		p["life"] = float(p["life"]) - delta * 0.8
		p["pos"] = (p["pos"] as Vector2) + Vector2(0, -60.0) * delta
	popups = popups.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	for i in range(portals.size() - 1, -1, -1):
		var pt := portals[i]
		pt.z -= delta * 2.0
		if pt.z <= 0.0:
			portals.remove_at(i)
		else:
			portals[i] = pt

	if over:
		return
	if mode == "chute":
		_update_drop(delta)
	else:
		_update_orbit(delta)


func _physics_process(delta: float) -> void:
	if mode == "orbite":
		var diff := rot_target - arena.rotation
		rot_vel = lerpf(rot_vel, diff * 14.0, clampf(delta * 10.0, 0.0, 1.0))
		rot_vel = clampf(rot_vel, -7.0, 7.0)
		arena.rotation += rot_vel * delta


# --- Mode Chute ---

func _half_chord(y: float, r: float) -> float:
	var dy := y - center.y
	return sqrt(maxf(0.0, (R - r) * (R - r) - dy * dy))


func _update_drop(delta: float) -> void:
	if demo:
		_ai_t -= delta
		if _ai_t <= 0.0 and drop_cd <= 0.0:
			_ai_t = randf_range(0.45, 0.8)
			aim_x = _ai_pick_x()
			_drop()
	var limit := center.y - R * 0.58
	var high := false
	for o in orbs.get_children():
		var ob := o as Orb
		if ob.age > 2.0 and ob.global_position.y - ob.r < limit and ob.linear_velocity.length() < 120.0:
			high = true
		# Filet de sécurité : un orbe ne doit jamais sortir de l'anneau fermé.
		var d := ob.global_position - center
		if d.length() > R - ob.r + 8.0:
			ob.global_position = center + d.normalized() * (R - ob.r)
			ob.linear_velocity = ob.linear_velocity.slide(d.normalized()) * 0.5
	danger = clampf(danger + (delta if high else -delta * 2.0), 0.0, 3.0)
	if danger >= 3.0:
		if demo:
			_clear_board()
		else:
			_game_over()


func _ai_pick_x() -> float:
	var hw := _half_chord(spawn_y, Art.radius(current))
	var best_x := center.x + randf_range(-hw, hw) * 0.8
	var best_y := INF
	for o in orbs.get_children():
		var ob := o as Orb
		if ob.tier == current and ob.global_position.y < best_y:
			best_y = ob.global_position.y
			best_x = ob.global_position.x
	return clampf(best_x + randf_range(-6, 6), center.x - hw, center.x + hw)


func _drop() -> void:
	if drop_cd > 0.0:
		return
	var r := Art.radius(current)
	var hw := _half_chord(spawn_y, r)
	var x := clampf(aim_x, center.x - hw, center.x + hw)
	spawn(current, Vector2(x, spawn_y), Vector2(0, 80))
	Sfx.tick()
	current = next
	next = _roll(DROP_WEIGHTS)
	drop_cd = 0.42


func _clear_board() -> void:
	for o in orbs.get_children():
		var ob := o as Orb
		_burst(ob.global_position, Art.color(ob.tier), 6, 200.0, 4.0)
		ob.queue_free()
	danger = 0.0


# --- Mode Orbite ---

func _update_orbit(delta: float) -> void:
	spawn_t -= delta
	var interval := lerpf(1.5, 0.55, clampf(time / 180.0, 0.0, 1.0))
	if spawn_t <= 0.0 and orbs.get_child_count() < 46:
		spawn_t = interval
		var p := center + Vector2(randf_range(-R * 0.35, R * 0.35), -R * 0.25 + randf_range(-30, 30))
		portals.append(Vector3(p.x, p.y, 1.0))
		spawn(_roll(ORBIT_WEIGHTS), p, Vector2(randf_range(-120, 120), randf_range(-60, 40)))
	if demo:
		rot_target = sin(time * 0.33) * 0.9 + sin(time * 0.71) * 0.35
	for o in orbs.get_children():
		var ob := o as Orb
		if ob.merging:
			continue
		if ob.global_position.distance_to(center) > R + ob.r + 30.0:
			_escaped(ob)


func _escaped(ob: Orb) -> void:
	_burst(ob.global_position, Color("ff4f5e"), 16, 300.0, 5.0)
	ob.queue_free()
	if demo:
		return
	lives -= 1
	trauma = minf(1.0, trauma + 0.4)
	Save.buzz(60)
	_popup(center + Vector2(0, -R - 70), "Un orbe s'échappe !", Color("ff6f7f"), 40)
	if lives <= 0:
		_game_over()


# --- Fin de partie ---

func _game_over() -> void:
	if over:
		return
	over = true
	Sfx.lose()
	Save.buzz(150)
	var record_best := Save.submit(mode, score)
	if ui:
		ui.show_game_over(score, int(Save.best[mode]), record_best)


# --- Contrôles ---

func _unhandled_input(event: InputEvent) -> void:
	if demo or over:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var p := _to_world(e.position)
		if mode == "chute":
			if e.pressed:
				aim_x = p.x
			else:
				aim_x = p.x
				_drop()
		else:
			dragging = e.pressed
			drag_angle = (p - center).angle()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var p := _to_world(d.position)
		if mode == "chute":
			aim_x = p.x
		elif dragging:
			var a := (p - center).angle()
			var da := wrapf(a - drag_angle, -PI, PI)
			# Loin du centre : on suit le doigt ; près du centre, glisser horizontalement fait tourner.
			if (p - center).length() < 80.0:
				da = d.relative.x * 0.008
			rot_target += da
			drag_angle = a


func _to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


# --- Dessin ---

func _draw_background(ci: CanvasItem) -> void:
	var vs := get_viewport_rect().size
	Art.halo(ci, center + Vector2(-160, -260), 520.0, Color(0.35, 0.12, 0.55, 0.22))
	Art.halo(ci, center + Vector2(200, 180), 480.0, Color(0.05, 0.3, 0.55, 0.2))
	Art.halo(ci, center, R * 1.5, Art.rainbow(arena.hue + 0.5, 0.6, 0.35) * Color(1, 1, 1, 0.25))
	for s in stars:
		var tw := 0.45 + 0.55 * sin(time * 1.7 + s.z * 3.0)
		Art.circle(ci, Vector2(s.x, s.y), 1.2 + fmod(s.z, 1.0), Color(0.8, 0.85, 1.0, 0.55 * tw))
	if _bang > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, _bang * _bang * 0.3))


func _draw_glow(ci: CanvasItem) -> void:
	arena.draw_glow(ci)
	for o in orbs.get_children():
		var ob := o as Orb
		var col := Art.color(ob.tier) if ob.tier != FINAL else Art.rainbow(time * 0.2)
		# Traînée lumineuse.
		if ob.trail.size() > 2:
			var cols := PackedColorArray()
			for i in ob.trail.size():
				var c := col
				c.a = 0.22 * float(i) / ob.trail.size()
				cols.append(c)
			ci.draw_polyline_colors(ob.trail, cols, ob.r * 0.9, true)
		var k := 2.6 if ob.tier < FINAL else 4.0
		Art.halo(ci, ob.global_position, ob.r * k * ob.pop, Color(col.r, col.g, col.b, 0.32 + 0.02 * ob.tier))
		if ob.tier == FINAL:
			for i in 12:
				var a := time * 0.6 + i * TAU / 12.0
				var len := ob.r * (2.2 + 0.5 * sin(time * 3.0 + i))
				var rc := Art.rainbow(time * 0.2 + i / 12.0, 0.6)
				rc.a = 0.35
				var dir := Vector2(cos(a), sin(a))
				var side := Vector2(-dir.y, dir.x) * ob.r * 0.12
				ci.draw_colored_polygon(PackedVector2Array([ob.global_position + side, ob.global_position - side, ob.global_position + dir * len]), rc)
			for i in 6:
				var a2 := -time * 1.3 + i * TAU / 6.0
				Art.halo(ci, ob.global_position + Vector2(cos(a2), sin(a2)) * ob.r * 1.25, 18.0, Art.rainbow(i / 6.0 + time * 0.3, 0.4))


func _draw_fx(ci: CanvasItem) -> void:
	for i in parts_pos.size():
		var f := parts_life[i] / parts_max[i]
		var c := parts_col[i]
		c.a = f
		Art.halo(ci, parts_pos[i], parts_size[i] * 4.0 * f, c)
		Art.circle(ci, parts_pos[i], parts_size[i] * 0.45 * f, Color(1, 1, 1, f))
	for w in waves:
		var c: Color = w["col"]
		var life := float(w["life"])
		c.a = clampf(life, 0.0, 1.0) * 0.8
		ci.draw_arc(w["pos"], float(w["r"]), 0.0, TAU, 64, c, float(w["w"]) * clampf(life, 0.2, 1.0), true)
	for pt in portals:
		var c := Art.rainbow(time * 0.5 + pt.x * 0.001, 0.5)
		c.a = pt.z
		ci.draw_arc(Vector2(pt.x, pt.y), 40.0 * (1.2 - pt.z), 0.0, TAU, 40, c, 4.0, true)
		Art.halo(ci, Vector2(pt.x, pt.y), 70.0 * pt.z, c)


func _draw_top(ci: CanvasItem) -> void:
	if mode == "chute" and not over:
		var limit := center.y - R * 0.58
		var hw := _half_chord(limit, 0.0)
		var pulse := danger / 3.0
		var lc := Color(1, 0.3, 0.4, 0.25 + 0.6 * pulse * (0.5 + 0.5 * sin(time * 18.0)))
		var x := center.x - hw
		while x < center.x + hw:
			ci.draw_line(Vector2(x, limit), Vector2(minf(x + 14.0, center.x + hw), limit), lc, 3.0, true)
			x += 26.0
		# Orbe en attente et guide de visée.
		var r := Art.radius(current)
		var ax := clampf(aim_x, center.x - _half_chord(spawn_y, r), center.x + _half_chord(spawn_y, r))
		var gy := spawn_y + r
		while gy < center.y + R - 10.0:
			ci.draw_line(Vector2(ax, gy), Vector2(ax, gy + 10.0), Color(1, 1, 1, 0.25), 2.0, true)
			gy += 24.0
		var a := 1.0 if drop_cd <= 0.0 else 0.4
		Art.draw_orb(ci, Vector2(ax, spawn_y), r, current, 0, time, false, a)
	for p in popups:
		var life := float(p["life"])
		var size := int(p["size"])
		var text: String = p["text"]
		var c: Color = p["col"]
		c.a = clampf(life * 2.0, 0.0, 1.0)
		var sc := 1.0 + maxf(0.0, (life - 0.85)) * 3.0
		var fs := int(size * sc)
		var w := Art.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos: Vector2 = p["pos"] - Vector2(w * 0.5, 0)
		ci.draw_string_outline(Art.font_bold, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.04, 0.02, 0.1, c.a * 0.9))
		ci.draw_string(Art.font_bold, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
