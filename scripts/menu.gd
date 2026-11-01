extends Node
## Menu : une vraie partie se joue toute seule en fond, le titre brille par-dessus.

const Game := preload("res://scripts/game.gd")

var _demo: Node2D
var _title: Control
var _t := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	# Enregistrement de vidéo promo : « godot -- --record=orbite ».
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--record"):
			Save.recording = true
			Save.next_mode = a.get_slice("=", 1) if "=" in a else "orbite"
			get_tree().change_scene_to_file.call_deferred("res://scenes/play.tscn")
			return

	_demo = Node2D.new()
	_demo.set_script(Game)
	_demo.mode = "orbite"
	_demo.demo = true
	add_child(_demo)

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.draw.connect(_draw_title)
	root.add_child(_title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 60
	box.offset_right = -60
	box.offset_bottom = -90
	box.offset_top = -90
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(box)

	box.add_child(_universe_picker())
	box.add_child(_mode_button("ORBITE", "Fais tourner l'arène, garde-les dedans", "orbite", true))
	box.add_child(_mode_button("CHUTE", "Vise, lâche, fusionne jusqu'au sommet", "chute", false))

	var sound := Button.new()
	sound.flat = true
	sound.focus_mode = Control.FOCUS_NONE
	sound.add_theme_font_override("font", Art.font)
	sound.add_theme_font_size_override("font_size", 24)
	sound.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	sound.text = "Son : activé" if Save.sound else "Son : coupé"
	sound.pressed.connect(func() -> void:
		Save.sound = not Save.sound
		Save.store()
		sound.text = "Son : activé" if Save.sound else "Son : coupé")
	box.add_child(sound)
	UI_fade(box)


func UI_fade(c: Control) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, 0.8).set_delay(0.4)


## Choix de l'univers : deux pastilles, celle choisie est pleine.
func _universe_picker() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var lab := Label.new()
	lab.text = "Univers"
	lab.add_theme_font_override("font", Art.font)
	lab.add_theme_font_size_override("font_size", 24)
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	row.add_child(lab)
	var buttons: Array[Button] = []
	for key: String in Art.UNIVERSES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 64)
		b.text = str(Art.UNIVERSES[key]["name"])
		b.add_theme_font_override("font", Art.font_bold)
		b.add_theme_font_size_override("font_size", 26)
		b.set_meta("key", key)
		b.pressed.connect(func() -> void:
			if Save.universe == key:
				return
			Save.buzz(10)
			Save.universe = key
			Save.store()
			Sfx.tick()
			Sfx.start_ambience()
			for o in buttons:
				_style_pill(o))
		buttons.append(b)
		_style_pill(b)
		row.add_child(b)
	return row


func _style_pill(b: Button) -> void:
	var on: bool = Save.universe == str(b.get_meta("key"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.9) if on else Color(1, 1, 1, 0.06)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(0 if on else 2)
	sb.set_corner_radius_all(32)
	sb.anti_aliasing = true
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var fc := Color(0.06, 0.04, 0.14) if on else Color(1, 1, 1, 0.85)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fc)


## Bouton de mode : titre + record sur une ligne, sous-titre court en dessous.
## Les textes sont des Label rognés : rien ne peut déborder de l'écran.
func _mode_button(title: String, sub: String, mode: String, primary: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 132)
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.94) if primary else Color(1, 1, 1, 0.08)
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.set_border_width_all(0 if primary else 2)
	sb.set_corner_radius_all(44)
	sb.anti_aliasing = true
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var fc := Color(0.06, 0.04, 0.14) if primary else Color.WHITE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var best := int(Save.best.get(mode, 0))
	var head := Label.new()
	head.text = title + (("   ★ %d" % best) if best > 0 else "")
	head.add_theme_font_override("font", Art.font_bold)
	head.add_theme_font_size_override("font_size", 40)
	var small := Label.new()
	small.text = sub
	small.add_theme_font_override("font", Art.font)
	small.add_theme_font_size_override("font_size", 22)
	for l: Label in [head, small]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_color", fc if l == head else Color(fc.r, fc.g, fc.b, 0.7))
		col.add_child(l)
	b.pressed.connect(func() -> void:
		Save.buzz(15)
		Save.next_mode = mode
		get_tree().change_scene_to_file("res://scenes/play.tscn"))
	return b


func _process(delta: float) -> void:
	_t += delta
	_title.queue_redraw()


func _draw_title() -> void:
	var vs := _title.get_viewport_rect().size
	var text := "ORBIS"
	var fs := 150
	var w := Art.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2((vs.x - w) * 0.5, vs.y * 0.2)
	# Halo arc-en-ciel derrière le titre.
	_title.draw_set_transform(Vector2.ZERO)
	for i in text.length():
		var ch := text[i]
		var cw := Art.font_bold.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := base + Vector2(cw, sin(_t * 2.2 + i * 0.7) * 8.0)
		var c := Art.rainbow(_t * 0.12 + i * 0.13, 0.6)
		_title.draw_string_outline(Art.font_bold, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 26, Color(c.r, c.g, c.b, 0.35))
		_title.draw_string_outline(Art.font_bold, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, c)
		_title.draw_string(Art.font_bold, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var sub := "Fusionne jusqu'à la forme finale"
	var w2 := Art.font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_title.draw_string(Art.font, Vector2((vs.x - w2) * 0.5, vs.y * 0.2 + 60), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.8))
