class_name GameUI
extends CanvasLayer
## Interface de partie : score, record, prochain orbe, vies, chaîne d'évolution, fin de partie.

var game: Node
var _top: Control
var _score: Label
var _best: Label
var _over: Control
var _shown_score := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_hud)
	root.add_child(_top)

	_score = _label("0", 92, Color.WHITE)
	_score.anchor_right = 1.0
	_score.offset_top = 70
	root.add_child(_score)
	_best = _label("", 26, Color(0.75, 0.8, 1.0, 0.8))
	_best.anchor_right = 1.0
	_best.offset_top = 182
	root.add_child(_best)

	if not game.record:
		var menu := _button("MENU", 26)
		menu.anchor_left = 0.0
		menu.offset_left = 26
		menu.offset_top = 40
		menu.custom_minimum_size = Vector2(130, 70)
		menu.pressed.connect(_to_menu)
		root.add_child(menu)

	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.visible = false
	root.add_child(_over)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Art.font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.09, 0.9))
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Art.font_bold)
	b.add_theme_font_size_override("font_size", size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95) if primary else Color(1, 1, 1, 0.08)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(0 if primary else 2)
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.anti_aliasing = true
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var fc := Color(0.06, 0.04, 0.14) if primary else Color.WHITE
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fc)
	b.pressed.connect(func() -> void: Save.buzz(12))
	return b


func _process(delta: float) -> void:
	_shown_score = lerpf(_shown_score, float(game.score), clampf(delta * 10.0, 0.0, 1.0))
	if absf(_shown_score - game.score) < 1.0:
		_shown_score = game.score
	_score.text = str(int(round(_shown_score)))
	var best := int(Save.best.get(game.mode, 0))
	_best.text = "RECORD %d" % maxi(best, game.score) if not game.record else ""
	_top.queue_redraw()


func _draw_hud() -> void:
	var vs := _top.get_viewport_rect().size
	var t: float = game.time
	if game.record:
		var hook := "Atteindra-t-elle la forme finale ?"
		var fs := 46
		var w := Art.font_bold.get_string_size(hook, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_top.draw_string_outline(Art.font_bold, Vector2((vs.x - w) * 0.5, 260), hook, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.03, 0.02, 0.09, 0.9))
		_top.draw_string(Art.font_bold, Vector2((vs.x - w) * 0.5, 260), hook, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var wm := "ORBIS"
		var w2 := Art.font_bold.get_string_size(wm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		_top.draw_string(Art.font_bold, Vector2((vs.x - w2) * 0.5, vs.y - 60), wm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.55))
	# Prochain orbe (Chute) ou vies (Orbite).
	if game.mode == "chute":
		var p := Vector2(vs.x - 80, 120)
		_top.draw_string(Art.font, p + Vector2(-40, -48), "SUIVANT", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(1, 1, 1, 0.6))
		Art.draw_orb(_top, p, minf(Art.radius(game.next), 30.0), game.next, 0, t, false)
	elif not game.record:
		for i in 3:
			var p := Vector2(vs.x - 150 + i * 46, 110)
			var on: bool = i < game.lives
			Art.halo(_top, p, 30.0, Color(1, 0.35, 0.5, 0.35 if on else 0.0))
			Art.circle(_top, p, 13.0, Color(1, 0.4, 0.55) if on else Color(1, 1, 1, 0.15))
	# Chaîne d'évolution.
	var n := Art.FINAL + 1
	var y := vs.y - 120.0 if not game.record else vs.y - 150.0
	var x0 := 46.0
	var step := (vs.x - 92.0) / (n - 1)
	for i in n:
		var p := Vector2(x0 + i * step, y)
		var known: bool = i < Save.discovered
		var r := 11.0 + i * 1.3
		if i < n - 1:
			_top.draw_line(p + Vector2(r + 2, 0), Vector2(x0 + (i + 1) * step - (11.0 + (i + 1) * 1.3) - 2, y), Color(1, 1, 1, 0.15), 2.0, true)
		if known:
			Art.draw_orb(_top, p, r, i, 0, t, false)
		else:
			Art.circle(_top, p, r, Color(1, 1, 1, 0.08))
			_top.draw_string(Art.font_bold, p + Vector2(-r, r * 0.45), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.2), Color(1, 1, 1, 0.3))


func show_game_over(score: int, best: int, is_record: bool) -> void:
	_over.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(dim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.anchor_right = 1.0
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 70
	box.offset_right = -70
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_over.add_child(box)
	box.add_child(_label("NOUVEAU RECORD !" if is_record else "FIN DE PARTIE", 52, Color("ffd84a") if is_record else Color.WHITE))
	box.add_child(_label(str(score), 120, Color.WHITE))
	box.add_child(_label("Record : %d" % best, 30, Color(0.75, 0.8, 1.0)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)
	var again := _button("REJOUER", 40, true)
	again.custom_minimum_size = Vector2(0, 110)
	again.pressed.connect(func() -> void:
		Save.next_mode = game.mode
		get_tree().reload_current_scene())
	box.add_child(again)
	var menu := _button("MENU", 34)
	menu.custom_minimum_size = Vector2(0, 96)
	menu.pressed.connect(_to_menu)
	box.add_child(menu)
	box.modulate.a = 0.0
	box.scale = Vector2(0.9, 0.9)
	var tw := box.create_tween().set_parallel()
	tw.tween_property(box, "modulate:a", 1.0, 0.4).set_delay(0.5)
	tw.tween_property(box, "scale", Vector2.ONE, 0.5).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
