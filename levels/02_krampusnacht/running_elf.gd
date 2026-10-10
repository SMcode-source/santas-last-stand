class_name RunningElf
extends Node3D
## A freed elf scampering off to the church: a small stand-in figure (green
## tunic, striped stockings, a long hat with a bobble) until the elves come
## from Meshy. Runs along a path of points, then slips in through the door.

const SPEED := 4.2

var _legs: Array[Node3D] = []
var _figure: Node3D
var _time := 0.0


func _ready() -> void:
	name = "RunningElf"
	_figure = Node3D.new()
	add_child(_figure)
	var b := ToyBuilder.new()
	var skin := Color("f1c7a5")
	var tunic := Color("2f7a3c")
	b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.3), Vector2(0.19, 0.3), Vector2(0.15, 0.45),
			Vector2(0.12, 0.6), Vector2(0.08, 0.66), Vector2(0.0, 0.67)]), 12), tunic, "velvet")
	# A jagged hem.
	for k in 8:
		var a := TAU * k / 8.0
		b.finished(ToyBuilder.cylinder(0.0, 0.05, 0.08, 4), tunic, "velvet",
				ToyBuilder.xf(Vector3(cos(a) * 0.16, 0.27, sin(a) * 0.16), Vector3(180, 0, 0)))
	b.finished(ToyBuilder.torus(0.135, 0.018, 14, 5), Color("2b1d14"), "leather", ToyBuilder.xf(Vector3(0, 0.42, 0)))
	b.finished(ToyBuilder.box(Vector3(0.05, 0.04, 0.02)), Color("d8b25a"), "metal", ToyBuilder.xf(Vector3(0, 0.42, 0.15)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(side * 0.13, 0.6, 0), Vector3(side * 0.2, 0.47, 0.05),
				Vector3(side * 0.22, 0.38, 0.1)]), PackedFloat32Array([0.035, 0.03, 0.028]), 6), tunic, "velvet")
		b.finished(ToyBuilder.sphere(0.03, 6), skin, "skin", ToyBuilder.xf(Vector3(side * 0.22, 0.36, 0.11)))
		b.finished(ToyBuilder.cylinder(0.0, 0.03, 0.09, 5), skin, "skin",
				ToyBuilder.xf(Vector3(side * 0.1, 0.77, -0.01), Vector3(0, 0, -side * 75)))
	b.finished(ToyBuilder.sphere(0.1, 12), skin, "skin", ToyBuilder.xf(Vector3(0, 0.76, 0.0), Vector3.ZERO, Vector3(1, 1.05, 1)))
	b.finished(ToyBuilder.sphere(0.022, 6), Color("e59a83"), "skin", ToyBuilder.xf(Vector3(0, 0.75, 0.1)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.sphere(0.012, 6), Color("1b1410"), "eye", ToyBuilder.xf(Vector3(side * 0.035, 0.79, 0.09)))
	b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 0.82, 0), Vector3(0, 0.98, -0.04), Vector3(0.0, 1.06, -0.16),
			Vector3(0.0, 1.02, -0.27)]), PackedFloat32Array([0.105, 0.06, 0.03, 0.012]), 10, 5), tunic, "velvet")
	b.finished(ToyBuilder.torus(0.1, 0.022, 14, 5), Color("f2ede2"), "fur", ToyBuilder.xf(Vector3(0, 0.83, 0)))
	b.finished(ToyBuilder.sphere(0.035, 8), Color("f2ede2"), "fur", ToyBuilder.xf(Vector3(0, 1.0, -0.28)))
	_figure.add_child(b.build(0.0, "Elf"))
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.07, 0.32, 0)
		_figure.add_child(leg)
		var lb := ToyBuilder.new()
		for k in 4:
			lb.finished(ToyBuilder.cylinder(0.032, 0.032, 0.07, 6), Color("c8352e") if k % 2 == 0 else Color("f2ede2"), "velvet",
					ToyBuilder.xf(Vector3(0, -0.035 - k * 0.07, 0)))
		lb.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, -0.3, -0.02), Vector3(0, -0.31, 0.08), Vector3(0, -0.27, 0.13)]),
				PackedFloat32Array([0.04, 0.035, 0.015]), 6, 4), Color("3b2a1e"), "leather")
		leg.add_child(lb.build(0.0, "Leg"))
		_legs.append(leg)


## Runs through `way` and disappears at the end.
func run(way: PackedVector3Array) -> void:
	var t := create_tween()
	# A startled hop out of the sack first.
	t.tween_property(self, "position:y", position.y + 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var from := Vector3(position.x, 0.0, position.z)
	for point in way:
		var seconds := from.distance_to(point) / SPEED
		var heading := atan2(point.x - from.x, point.z - from.z)
		t.tween_callback(func() -> void: rotation.y = heading)
		t.tween_property(self, "position", point, seconds)
		from = point
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	var stride := sin(_time * 16.0)
	_figure.position.y = absf(stride) * 0.05
	_figure.rotation.x = 0.18
	if _legs.size() == 2:
		_legs[0].rotation.x = stride * 0.7
		_legs[1].rotation.x = -stride * 0.7
