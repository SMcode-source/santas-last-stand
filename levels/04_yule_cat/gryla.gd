class_name Gryla
extends Node3D
## Grýla, the ogress of the mountains and mother of the Yule Lads (a
## stand-in built from shapes until she comes from Meshy): huge and hunched,
## in a patched sackcloth dress, with a nose like a turnip, a wild grey mane,
## two little horns, and hooves. She looms on the clifftop at the start,
## and snores in her great chair in the cave until the cage door creaks.

enum Pose {STAND, ASLEEP, SHOUT}

const SKIN := Color("9aa08a")
const DRESS := Color("5e4a3a")
const HAIR := Color("a8a49c")

var pose := Pose.STAND

var _time := 0.0
var _figure: Node3D
var _torso: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _snore: Label3D


func _init() -> void:
	name = "Gryla"
	_build()


## Slumped asleep in her chair, snoring.
func sleep_in_chair(seat: Transform3D) -> void:
	global_transform = seat
	pose = Pose.ASLEEP
	_figure.position = Vector3(0, -0.15, 0.12)
	_snore.visible = true


## Stands bolt upright and bellows.
func wake() -> void:
	pose = Pose.SHOUT
	_snore.visible = false
	var t := create_tween()
	t.tween_property(_figure, "position", Vector3(0, 0, 0.7), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	match pose:
		Pose.STAND:
			_torso.rotation.x = 0.28 + sin(_time * 1.1) * 0.02
			_head.rotation.x = -0.15
			for k in 2:
				_arms[k].rotation.x = lerpf(_arms[k].rotation.x, 0.1, minf(1.0, delta * 3.0))
		Pose.ASLEEP:
			var breath := sin(_time * 1.4)
			_torso.rotation.x = 0.1 + breath * 0.03
			_head.rotation.x = 0.55 + breath * 0.04
			_head.rotation.z = 0.25
			for k in 2:
				_arms[k].rotation.x = -0.4
			_snore.position.y = 3.0 + fmod(_time * 0.4, 1.0) * 0.6
			_snore.modulate.a = 1.0 - fmod(_time * 0.4, 1.0)
		Pose.SHOUT:
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.1, minf(1.0, delta * 5.0))
			_head.rotation.x = lerpf(_head.rotation.x, -0.35, minf(1.0, delta * 5.0))
			_head.rotation.z = lerpf(_head.rotation.z, 0.0, minf(1.0, delta * 5.0))
			for k in 2:
				_arms[k].rotation.x = lerpf(_arms[k].rotation.x, -2.4 + sin(_time * 7.0 + k) * 0.25, minf(1.0, delta * 5.0))


func _build() -> void:
	_figure = Node3D.new()
	_figure.name = "Figure"
	add_child(_figure)
	var b := ToyBuilder.new()
	# Hooves under a ragged hem.
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.cylinder(0.13, 0.17, 0.2, 10), Color("2c2622"), "leather", ToyBuilder.xf(Vector3(side * 0.28, 0.1, 0.05)))
		b.finished(ToyBuilder.cylinder(0.12, 0.13, 0.6, 10), SKIN.darkened(0.15), "skin", ToyBuilder.xf(Vector3(side * 0.28, 0.48, 0.0)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.55), Vector2(0.75, 0.55), Vector2(0.78, 0.9),
			Vector2(0.7, 1.4), Vector2(0.0, 1.45)]), 16), 0.05, 4.0, 3), DRESS, "velvet")
	for k in 12:
		var a := TAU * k / 12.0
		b.finished(ToyBuilder.cylinder(0.0, 0.12, 0.2, 4), DRESS, "velvet",
				ToyBuilder.xf(Vector3(cos(a) * 0.68, 0.5, sin(a) * 0.68), Vector3(180, k * 20.0, 0)))
	_figure.add_child(b.build(0.0, "Legs"))
	# The torso hinges at the waist so she can hunch, slump and rear up.
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.4, 0)
	_figure.add_child(_torso)
	var tb := ToyBuilder.new()
	tb.finished(ToyBuilder.lumpy(ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.72, -0.05), Vector2(0.8, 0.35),
			Vector2(0.72, 0.8), Vector2(0.45, 1.05), Vector2(0.0, 1.1)]), 16), 0.05, 4.0, 5), DRESS, "velvet")
	# Patches and a rope belt.
	tb.finished(ToyBuilder.box(Vector3(0.3, 0.26, 0.04)), Color("7a6a50"), "velvet", ToyBuilder.xf(Vector3(0.25, 0.45, 0.74), Vector3(0, 10, 8)))
	tb.finished(ToyBuilder.box(Vector3(0.22, 0.2, 0.04)), Color("4a5a4a"), "velvet", ToyBuilder.xf(Vector3(-0.35, 0.7, 0.62), Vector3(0, -25, -6)))
	tb.finished(ToyBuilder.torus(0.76, 0.04, 20, 6), Color("8a7450"), "leather", ToyBuilder.xf(Vector3(0, 0.05, 0)))
	_torso.add_child(tb.build(0.0, "Torso"))
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.66, 0.9, 0.05)
		_torso.add_child(arm)
		var ab := ToyBuilder.new()
		ab.finished(ToyBuilder.tube(PackedVector3Array([Vector3.ZERO, Vector3(side * 0.15, -0.55, 0.1), Vector3(side * 0.18, -1.1, 0.22)]),
				PackedFloat32Array([0.17, 0.14, 0.12]), 10), DRESS, "velvet")
		ab.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.17, 10), 0.15, 5.0, 2), SKIN, "skin",
				ToyBuilder.xf(Vector3(side * 0.18, -1.27, 0.24), Vector3.ZERO, Vector3(0.85, 1.1, 0.7)))
		for k in 4:
			ab.finished(ToyBuilder.cylinder(0.012, 0.03, 0.14, 5), SKIN.darkened(0.2), "skin",
					ToyBuilder.xf(Vector3(side * (0.12 + k * 0.04), -1.42, 0.3), Vector3(20, 0, 0)))
		arm.add_child(ab.build(0.0, "Arm"))
		_arms.append(arm)
	# The head, thrust forward.
	_head = Node3D.new()
	_head.position = Vector3(0, 1.1, 0.2)
	_torso.add_child(_head)
	var hb := ToyBuilder.new()
	hb.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.38, 16), 0.08, 4.0, 6), SKIN, "skin", ToyBuilder.xf(Vector3(0, 0.3, 0.05), Vector3.ZERO, Vector3(1.0, 1.1, 0.95)))
	hb.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.13, 12), 0.12, 6.0, 8), SKIN.lerp(Color("a07060"), 0.3), "skin",
			ToyBuilder.xf(Vector3(0, 0.26, 0.45), Vector3(-25, 0, 0), Vector3(0.9, 0.9, 1.7)))
	hb.finished(ToyBuilder.sphere(0.03, 6), SKIN.darkened(0.3), "skin", ToyBuilder.xf(Vector3(0.07, 0.18, 0.58)))
	hb.add(ToyBuilder.box(Vector3(0.3, 0.05, 0.05)), Color("2a1414"), ToyBuilder.xf(Vector3(0, 0.08, 0.37), Vector3(0, 0, 3)))
	for side: float in [-1.0, 1.0]:
		hb.finished(ToyBuilder.sphere(0.035, 8), Color("e8d47a"), "eye", ToyBuilder.xf(Vector3(side * 0.13, 0.4, 0.33)))
		hb.finished(ToyBuilder.sphere(0.017, 6), Color("0b0b0b"), "eye", ToyBuilder.xf(Vector3(side * 0.13, 0.4, 0.365)))
		hb.finished(ToyBuilder.curve(PackedVector3Array([Vector3(side * 0.2, 0.6, 0.05), Vector3(side * 0.28, 0.75, 0.0), Vector3(side * 0.26, 0.86, -0.08)]),
				PackedFloat32Array([0.05, 0.035, 0.01]), 6, 4), Color("d8cdb4"), "leather")
	# A wild grey mane.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for k in 9:
		var a := lerpf(-2.4, 2.4, k / 8.0)
		hb.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.2, 10), 0.3, 8.0, k), HAIR, "hair",
				ToyBuilder.xf(Vector3(sin(a) * 0.32, 0.45 - absf(a) * 0.12 + rng.randf_range(-0.05, 0.05), cos(a) * -0.1 - 0.12),
						Vector3(0, rng.randf() * 90.0, 0), Vector3(1.0, 1.5, 0.9)))
	_head.add_child(hb.build(0.0, "Head"))
	_snore = Label3D.new()
	_snore.text = "Z z z"
	_snore.font_size = 64
	_snore.pixel_size = 0.006
	_snore.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_snore.modulate = Color(0.9, 0.95, 1.0)
	_snore.outline_size = 8
	_snore.position = Vector3(0.6, 3.0, 0.4)
	_snore.visible = false
	add_child(_snore)
