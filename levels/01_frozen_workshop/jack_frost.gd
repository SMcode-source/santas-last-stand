class_name JackFrost
extends Node3D
## Jack Frost as he appears in the Clock Tower fight: a lean, frost-blue
## sprite with spiky icicle hair, wrapped in a shell of ice crystals that
## nothing can hurt. (A stand-in built from code until his Meshy model is
## rigged.) He hops from gear to gear, throws ice shards, and loses his
## armour when steam hits him.

## A blow landed on him: the level decides what it does.
signal struck(hit: Dictionary)

const HOP_TIME := 0.7
const HOP_HEIGHT := 3.2

var armoured := true
var _body: Node3D
var _armour: Node3D
var _hurt: Area3D
var _bob := randf() * 10.0
var _hopping: Tween
var _base_y := 0.0


func _init() -> void:
	name = "JackFrost"


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var b := ToyBuilder.new()
	var skin := Color("bcd8ec")
	var coat := Color("3d6fa8")
	var ice := Color("d8f0ff")
	# Legs, a long icy coat with a jagged hem, thin arms.
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(side * 0.12, 0.0, 0.02), Vector3(side * 0.13, 0.5, 0.0),
				Vector3(side * 0.11, 0.9, 0.0)]), PackedFloat32Array([0.06, 0.07, 0.09]), 8), Color("24364f"), "velvet")
		b.finished(ToyBuilder.box(Vector3(0.13, 0.08, 0.3)), Color("1b2433"), "leather", ToyBuilder.xf(Vector3(side * 0.12, 0.04, 0.07)))
		b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(side * 0.26, 1.42, 0.0), Vector3(side * 0.42, 1.12, 0.08),
				Vector3(side * 0.5, 0.86, 0.22)]), PackedFloat32Array([0.065, 0.055, 0.045]), 8), coat, "velvet")
		b.finished(ToyBuilder.sphere(0.06, 8), skin, "skin", ToyBuilder.xf(Vector3(side * 0.52, 0.8, 0.26)))
	b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.62), Vector2(0.3, 0.64), Vector2(0.26, 0.9),
			Vector2(0.21, 1.2), Vector2(0.27, 1.42), Vector2(0.14, 1.52), Vector2(0.0, 1.53)]), 14), coat, "velvet")
	for k in 9:
		var a := TAU * k / 9.0
		b.finished(ToyBuilder.cylinder(0.0, 0.07, 0.22, 4), coat, "velvet",
				ToyBuilder.xf(Vector3(cos(a) * 0.27, 0.55, sin(a) * 0.27), Vector3(180, 0, 0)))
	# Head, pointed ears and nose, glowing eyes, a sly grin.
	b.finished(ToyBuilder.sphere(0.17, 14), skin, "skin", ToyBuilder.xf(Vector3(0, 1.7, 0.0), Vector3.ZERO, Vector3(0.9, 1.08, 0.95)))
	b.finished(ToyBuilder.cylinder(0.0, 0.03, 0.1, 6), skin, "skin", ToyBuilder.xf(Vector3(0, 1.7, 0.19), Vector3(90, 0, 0)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.cylinder(0.0, 0.045, 0.16, 6), skin, "skin",
				ToyBuilder.xf(Vector3(side * 0.17, 1.74, -0.02), Vector3(0, 0, -side * 70)))
		b.add(ToyBuilder.sphere(0.025, 8), Color(0.55, 0.9, 1.0), ToyBuilder.xf(Vector3(side * 0.06, 1.74, 0.14)), true)
	b.finished(ToyBuilder.box(Vector3(0.1, 0.012, 0.01)), Color("23324a"), "skin", ToyBuilder.xf(Vector3(0, 1.62, 0.155), Vector3(0, 0, 8)))
	# Spiky icicle hair swept back.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 16:
		var a := rng.randf_range(-2.4, 2.4)
		var lift := rng.randf_range(0.0, 0.9)
		var root := Vector3(sin(a) * 0.13, 1.8 + lift * 0.06, cos(a) * 0.1 - 0.02)
		var tip := root + Vector3(sin(a) * 0.12, 0.16 + lift * 0.12, -0.18 - lift * 0.1)
		b.finished(ToyBuilder.tube(PackedVector3Array([root, tip]), PackedFloat32Array([0.05, 0.004]), 5), ice, "eye")
	var figure := b.build(0.0, "Figure")
	_body.add_child(figure)

	# The armour: a shell of jagged crystals.
	var ab := ToyBuilder.new()
	for k in 26:
		var y := rng.randf_range(0.2, 1.75)
		var a := rng.randf_range(0.0, TAU)
		var r := 0.3 + 0.08 * sin(y * 3.0)
		var at := Vector3(cos(a) * r, y, sin(a) * r)
		var out := Vector3(cos(a), rng.randf_range(-0.3, 0.6), sin(a)).normalized()
		var length := rng.randf_range(0.25, 0.5)
		ab.finished(ToyBuilder.tube(PackedVector3Array([at - out * 0.05, at + out * length]),
				PackedFloat32Array([rng.randf_range(0.06, 0.1), 0.005]), 5), Color("a9dcf7"), "eye")
	ab.finished(ToyBuilder.lumpy(ToyBuilder.capsule(0.36, 1.9, 12), 0.05, 3.0, 3), Color(0.75, 0.9, 1.0), "eye",
			ToyBuilder.xf(Vector3(0, 0.98, 0)))
	_armour = ab.build(0.0, "Armour")
	_body.add_child(_armour)

	var light := OmniLight3D.new()
	light.light_color = Color("9fd8ff")
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 1.4, 0.6)
	_body.add_child(light)

	_hurt = Area3D.new()
	_hurt.name = "Hurtbox"
	_hurt.collision_layer = PhysicsLayers.HURTBOX
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	_hurt.add_child(shape)
	add_child(_hurt)


func _process(delta: float) -> void:
	_bob += delta
	_body.position.y = sin(_bob * 2.2) * 0.06 + 0.08
	_body.rotation.z = sin(_bob * 1.3) * 0.04


func take_hit(hit: Dictionary) -> void:
	struck.emit(hit)


## Turns to face `at` (flat).
func face(at: Vector3) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = atan2(to.x, to.z)


## Leaps in an arc to `to`.
func hop_to(to: Vector3) -> void:
	if _hopping and _hopping.is_valid():
		_hopping.kill()
	var from := global_position
	_hopping = create_tween()
	_hopping.tween_method(func(t: float) -> void:
		global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * HOP_HEIGHT, 0.0, 1.0, HOP_TIME)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_armoured(on: bool) -> void:
	armoured = on
	var t := create_tween()
	if on:
		_armour.visible = true
		t.tween_property(_armour, "scale", Vector3.ONE, 0.35).from(Vector3(0.6, 0.2, 0.6)).set_trans(Tween.TRANS_BACK)
	else:
		t.tween_property(_armour, "scale", Vector3(1.3, 0.05, 1.3), 0.3)
		t.tween_callback(func() -> void: _armour.visible = false)


## Knocked back by a blow while his armour is off.
func reel(direction: Vector3) -> void:
	var t := create_tween()
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	t.tween_property(_body, "rotation:x", -0.6, 0.12)
	t.parallel().tween_property(_body, "position:z", -0.4, 0.12)
	t.tween_property(_body, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC)
	t.parallel().tween_property(_body, "position:z", 0.0, 0.5)
	if flat.length() > 0.1:
		face(global_position - flat)
