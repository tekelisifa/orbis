extends Node
## Scène de jeu : crée la partie dans le mode choisi au menu.

const Game := preload("res://scripts/game.gd")


func _ready() -> void:
	var g := Node2D.new()
	g.set_script(Game)
	g.mode = Save.next_mode
	g.record = Save.recording
	g.demo = Save.recording
	add_child(g)
