class_name Painter
extends Node2D
## Calque de dessin : délègue son _draw à une fonction (fond, lumière additive, effets…).

var paint: Callable


static func make(fn: Callable, additive := false) -> Painter:
	var p := Painter.new()
	p.paint = fn
	if additive:
		p.material = Art.add_mat
	return p


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if paint.is_valid():
		paint.call(self)
