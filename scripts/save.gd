extends Node
## Meilleurs scores, formes découvertes, réglages.

const PATH := "user://orbis.cfg"

var best := {"chute": 0, "orbite": 0}
var discovered := 1
var sound := true
var haptics := true
var universe := "cosmos"
## Valeurs de session (non sauvegardées).
var next_mode := "orbite"
var recording := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	best["chute"] = int(cfg.get_value("best", "chute", 0))
	best["orbite"] = int(cfg.get_value("best", "orbite", 0))
	discovered = int(cfg.get_value("progress", "discovered", 1))
	sound = bool(cfg.get_value("options", "sound", true))
	haptics = bool(cfg.get_value("options", "haptics", true))
	universe = str(cfg.get_value("options", "universe", "cosmos"))


func store() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("best", "chute", best["chute"])
	cfg.set_value("best", "orbite", best["orbite"])
	cfg.set_value("progress", "discovered", discovered)
	cfg.set_value("options", "sound", sound)
	cfg.set_value("options", "haptics", haptics)
	cfg.set_value("options", "universe", universe)
	cfg.save(PATH)


## Enregistre un score ; renvoie true si c'est un nouveau record.
func submit(mode: String, score: int) -> bool:
	if score > int(best.get(mode, 0)):
		best[mode] = score
		store()
		return true
	return false


func discover(tier: int) -> bool:
	if tier + 1 > discovered:
		discovered = tier + 1
		store()
		return true
	return false


func buzz(ms: int) -> void:
	if haptics:
		Input.vibrate_handheld(ms)
