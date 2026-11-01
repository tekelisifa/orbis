class_name Orb
extends RigidBody2D
## Un orbe : corps physique + dessin (corps, volume, visage animé) + traînée lumineuse.

signal touched(orb: Orb, other: Node, speed: float)

var tier := 0
var r := 22.0
var age := 0.0
var merging := false
var pop := 0.0          # 0 → 1 à l'apparition (effet de « pop »)
var mood := 0
var trail: PackedVector2Array = []
var _t := 0.0
var _blink_t := 0.0
var _next_blink := 2.0
var _mood_t := 0.0


static func create(t: int, bounce: float) -> Orb:
	var o := Orb.new()
	o.tier = t
	o.r = Art.radius(t)
	var shape := CircleShape2D.new()
	shape.radius = o.r
	var cs := CollisionShape2D.new()
	cs.shape = shape
	o.add_child(cs)
	o.mass = pow(o.r / 30.0, 2.0)
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.35
	o.physics_material_override = pm
	o.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	o.contact_monitor = true
	o.max_contacts_reported = 6
	o.angular_damp = 0.6
	o.linear_damp = 0.05
	o._t = randf() * 10.0
	o._next_blink = randf_range(1.5, 4.0)
	return o


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	touched.emit(self, body, linear_velocity.length())


func _process(delta: float) -> void:
	_t += delta
	age += delta
	pop = minf(1.0, pop + delta * 6.0)
	_blink_t += delta
	if _blink_t > _next_blink:
		_blink_t = -0.12
		_next_blink = randf_range(2.0, 5.0)
	var speed := linear_velocity.length()
	_mood_t = maxf(0.0, _mood_t - delta)
	if _mood_t <= 0.0:
		mood = 1 if speed > 900.0 else (2 if speed < 6.0 and age > 6.0 else 0)
	# Traînée (positions globales récentes).
	trail.append(global_position)
	if trail.size() > 10:
		trail.remove_at(0)
	queue_redraw()


func cheer() -> void:
	mood = 3
	_mood_t = 1.2


func _draw() -> void:
	var s := _ease_pop(pop)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	Art.draw_orb(self, Vector2.ZERO, r, tier, mood, _t, _blink_t < 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ease_pop(x: float) -> float:
	# Petit dépassement élastique.
	var c := 1.70158 * 1.4
	var y := x - 1.0
	return 1.0 + (c + 1.0) * y * y * y + c * y * y
