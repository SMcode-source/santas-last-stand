class_name SantaToy
extends Node3D
## Santa at life size (1.78 m), built from generated shapes with realistic
## finishes: a velvet coat, fur trim with a soft fuzzy edge, a beard made of
## individual strands, leather boots and gloves, and wire spectacles.
## Idle animation: breathing, looking around and blinking, plus hop() and wave().

const RED := Color("a8101c")
const RED_TROUSERS := Color("8e0e18")
const FUR := Color("f4f1ea")
const FUR_DEEP := Color("c9c4bb")
const HAIR := Color("f1eee9")
const HAIR_ROOT := Color("d2cdc6")
const SKIN := Color("e7b39b")
const CHEEK := Color("de8a7d")
const NOSE := Color("dc8d80")
const LIP := Color("b86a63")
const LEATHER := Color("1d1715")
const GLOVE := Color("231b18")
const SOLE := Color("3a2a20")
const GOLD := Color("d6a63c")
const IRIS := Color("4a78a3")
const PUPIL := Color("0f0b0a")
const EYE_WHITE := Color("efe8e2")

## Coat cross-sections, bottom to top: height, half-width, front depth, back depth.
const COAT := [
	[0.70, 0.27, 0.26, 0.24],
	[0.80, 0.275, 0.28, 0.22],
	[0.92, 0.29, 0.31, 0.21],
	[1.02, 0.295, 0.325, 0.2],
	[1.12, 0.28, 0.305, 0.19],
	[1.24, 0.245, 0.245, 0.176],
	[1.32, 0.222, 0.19, 0.163],
	[1.38, 0.208, 0.15, 0.145],
	[1.43, 0.17, 0.118, 0.112],
	[1.48, 0.1, 0.085, 0.085],
	[1.53, 0.065, 0.065, 0.07],
]
const NECK := Vector3(0, 1.5, 0)
const SHOULDER := Vector3(0.2, 1.35, -0.01)
const UPPER_ARM := 0.285
const FOREARM := 0.25
const ARM_REST := 0.42
const ELBOW_REST := -0.35
## The forearm turns back in, so the hands rest beside the belly.
const ELBOW_IN := -0.3

var _body: Node3D
var _head: Node3D
var _eyes: Node3D
var _arms: Array[Node3D] = []
var _elbows: Array[Node3D] = []

var _time := 0.0
var _hop := 0.0
var _wave := 0.0
var _next_blink := 2.0
var _blink := 0.0


func _ready() -> void:
	name = "Santa"
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_body.add_child(_build_body())

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = NECK
	_body.add_child(_head)
	_head.add_child(_build_head())
	_eyes = Node3D.new()
	_eyes.name = "Eyes"
	_eyes.position = Vector3(0, 0.145, 0.093)
	_head.add_child(_eyes)
	_eyes.add_child(_build_eyes())

	for side: int in [-1, 1]:
		_make_arm(side)


func _process(delta: float) -> void:
	_time += delta
	_hop = maxf(0.0, _hop - delta * 2.4)
	_wave = maxf(0.0, _wave - delta * 0.45)

	# A small, heavy hop and slow breathing.
	var hop_height := sin(_hop * PI) * 0.22 if _hop > 0.0 else 0.0
	var breath := sin(_time * 1.6)
	_body.position.y = hop_height
	_body.scale = Vector3(1.0 + breath * 0.006, 1.0 + breath * 0.004 + hop_height * 0.08, 1.0 + breath * 0.008)

	# Looks around slowly.
	_head.rotation = Vector3(sin(_time * 0.7) * 0.04 - 0.03, sin(_time * 0.45) * 0.18, sin(_time * 0.9) * 0.03)

	var sway := sin(_time * 1.6) * 0.03
	var lift := hop_height * 1.5
	var wave_amount := smoothstep(0.0, 0.15, _wave) * smoothstep(1.0, 0.85, _wave)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var waving := wave_amount if side > 0.0 else 0.0
		_arms[i].rotation = Vector3(sway * side, 0, side * lerpf(ARM_REST + lift, 1.3, waving))
		_elbows[i].rotation = Vector3(lerpf(ELBOW_REST, 0.0, waving), 0,
				side * lerpf(ELBOW_IN, 1.7 + sin(_time * 11.0) * 0.3, waving))

	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(2.5, 5.0)
	_blink = maxf(0.0, _blink - delta)
	_eyes.scale.y = 0.08 if _blink > 0.0 else 1.0


## A little hop of joy.
func hop() -> void:
	if _hop <= 0.0:
		_hop = 1.0


## Waves the right arm for a couple of seconds.
func wave() -> void:
	if _wave <= 0.1:
		_wave = 1.0


# --- Body ----------------------------------------------------------------------

func _build_body() -> MeshInstance3D:
	var b := ToyBuilder.new()

	# Coat, lofted through the cross-sections so he has a real belly.
	var rings: Array[PackedVector3Array] = []
	for row in _coat_rows(4):
		rings.append(_section(row[0], row[1], row[2], row[3], 48, _fold(row[0])))
	b.finished(ToyBuilder.loft(rings), RED, "velvet")

	# Wide leather belt with a brass buckle
	var belt: Array[PackedVector3Array] = []
	for belt_y: float in [0.965, 1.035]:
		var c := _coat_at(belt_y)
		belt.append(_section(belt_y, c[1] + 0.008, c[2] + 0.008, c[3] + 0.008, 40))
	b.finished(ToyBuilder.loft(belt), LEATHER, "leather")
	var buckle_z: float = _coat_at(1.0)[2] + 0.014
	for k in 4:
		var horizontal := k < 2
		var offset := (0.034 if k % 2 == 0 else -0.034)
		var size := Vector3(0.11, 0.014, 0.008) if horizontal else Vector3(0.014, 0.082, 0.008)
		var pos := Vector3(0, 1.0 + offset, buckle_z) if horizontal else Vector3(offset * 1.45, 1.0, buckle_z)
		b.finished(ToyBuilder.box(size), GOLD, "metal", ToyBuilder.xf(pos))
	b.finished(ToyBuilder.cylinder(0.004, 0.004, 0.08, 6), GOLD, "metal",
			ToyBuilder.xf(Vector3(0.0, 1.0, buckle_z + 0.006), Vector3(0, 0, 90)))

	# Fur trim: around the hem, up the front, and a collar
	var hem := PackedVector3Array()
	for s in 33:
		var a := TAU * s / 32.0
		var c := _coat_at(0.715)
		hem.append(_section_point(0.715, c[1] + 0.012, c[2] + 0.012, c[3] + 0.012, a, _fold(0.715)))
	_fur_band(b, hem, 0.04, 1)
	var front := PackedVector3Array()
	var y := 0.74
	while y <= 1.47:
		if absf(y - 1.0) > 0.05:
			front.append(Vector3(0, y, _coat_at(y)[2] + 0.006))
		elif front.size() > 1:
			_fur_band(b, front, 0.028, 2)
			front = PackedVector3Array()
		y += 0.03
	_fur_band(b, front, 0.028, 3)
	var collar := PackedVector3Array()
	for s in 25:
		var a := TAU * s / 24.0
		collar.append(Vector3(cos(a) * 0.085, 1.5 - sin(a) * 0.012, sin(a) * 0.09))
	_fur_band(b, collar, 0.035, 4)

	# Trousers and knee boots
	for side: float in [-1.0, 1.0]:
		var x := 0.11 * side
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(x, 0.78, 0), Vector3(x * 1.02, 0.6, 0.01), Vector3(x, 0.4, 0),
		]), PackedFloat32Array([0.095, 0.082, 0.072]), 16, 3), RED_TROUSERS, "velvet")
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(x, 0.05, -0.01), Vector3(x, 0.14, 0.0), Vector3(x, 0.3, 0.0), Vector3(x, 0.43, 0.0),
		]), PackedFloat32Array([0.064, 0.06, 0.068, 0.074]), 16, 3), LEATHER, "leather")
		# Folded-over boot top
		b.finished(ToyBuilder.lumpy(ToyBuilder.torus(0.076, 0.012, 20, 8), 0.004, 30.0, 5),
				LEATHER, "leather", ToyBuilder.xf(Vector3(x, 0.42, 0)))
		var foot := ToyBuilder.xf(Vector3(x, 0.0, 0.0), Vector3(0, 8 * side, 0))
		b.finished(ToyBuilder.sphere(1.0, 20), LEATHER, "leather",
				foot * ToyBuilder.xf(Vector3(0, 0.06, 0.075), Vector3(-6, 0, 0), Vector3(0.064, 0.052, 0.13)))
		b.finished(ToyBuilder.sphere(1.0, 16), LEATHER, "leather",
				foot * ToyBuilder.xf(Vector3(0, 0.065, -0.02), Vector3.ZERO, Vector3(0.062, 0.06, 0.07)))
		b.finished(ToyBuilder.sphere(1.0, 20), SOLE, "leather",
				foot * ToyBuilder.xf(Vector3(0, 0.014, 0.045), Vector3.ZERO, Vector3(0.069, 0.016, 0.16)))
	return b.build(0.0, "BodyMesh")


# --- Head ----------------------------------------------------------------------

## Built around the top of the neck (NECK), facing +Z.
func _build_head() -> MeshInstance3D:
	var b := ToyBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225

	# Skull, jaw, ears, brow ridge, cheeks and nose, all painted with one skin
	# tone so the rosy cheeks and nose blend in smoothly.
	var skin := _skin_tone
	b.painted_finish(ToyBuilder.sphere(1.0, 32), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.13, 0.005), Vector3.ZERO, Vector3(0.098, 0.118, 0.108)))
	b.painted_finish(ToyBuilder.sphere(1.0, 20), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.07, 0.03), Vector3.ZERO, Vector3(0.085, 0.075, 0.075)))
	for side: float in [-1.0, 1.0]:
		b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
				ToyBuilder.xf(Vector3(0.097 * side, 0.135, -0.005), Vector3(0, 20 * side, 0), Vector3(0.013, 0.032, 0.022)))
		b.painted_finish(ToyBuilder.sphere(1.0, 12), skin, "skin",
				ToyBuilder.xf(Vector3(0.034 * side, 0.163, 0.094), Vector3(0, 0, -8 * side), Vector3(0.022, 0.009, 0.014)))
		b.painted_finish(ToyBuilder.sphere(1.0, 16), skin, "skin",
				ToyBuilder.xf(Vector3(0.046 * side, 0.115, 0.08), Vector3.ZERO, Vector3(0.034, 0.026, 0.017)))
		# Eyelids hug the top and bottom of each eye
		b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
				ToyBuilder.xf(Vector3(0.034 * side, 0.1505, 0.0935), Vector3(-10, 0, 0), Vector3(0.0148, 0.0075, 0.0128)))
		b.painted_finish(ToyBuilder.sphere(1.0, 12), skin, "skin",
				ToyBuilder.xf(Vector3(0.034 * side, 0.1385, 0.094), Vector3.ZERO, Vector3(0.0142, 0.0042, 0.0118)))
		b.painted_finish(ToyBuilder.sphere(1.0, 10), skin, "skin",
				ToyBuilder.xf(Vector3(0.0125 * side, 0.1, 0.109), Vector3.ZERO, Vector3(0.0095, 0.008, 0.009)))
	b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.127, 0.108), Vector3(-22, 0, 0), Vector3(0.0095, 0.028, 0.012)))
	b.painted_finish(ToyBuilder.sphere(1.0, 16), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.104, 0.118), Vector3.ZERO, Vector3(0.016, 0.0145, 0.015)))
	b.finished(ToyBuilder.sphere(1.0, 12), LIP, "skin",
			ToyBuilder.xf(Vector3(0, 0.066, 0.1), Vector3.ZERO, Vector3(0.017, 0.006, 0.008)))

	# Wire spectacles resting on the nose
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.torus(0.019, 0.0014, 24, 5), GOLD, "metal",
				ToyBuilder.xf(Vector3(0.035 * side, 0.143, 0.119), Vector3(90, 0, 0)))
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.054 * side, 0.146, 0.117), Vector3(0.088 * side, 0.149, 0.09),
			Vector3(0.1 * side, 0.146, 0.03), Vector3(0.098 * side, 0.128, -0.005),
		]), PackedFloat32Array([0.0013, 0.0013, 0.0013, 0.0013]), 5, 4), GOLD, "metal")
	b.finished(ToyBuilder.curve(PackedVector3Array([
		Vector3(-0.016, 0.145, 0.12), Vector3(0, 0.15, 0.124), Vector3(0.016, 0.145, 0.12),
	]), PackedFloat32Array([0.0014, 0.0014, 0.0014]), 5, 4), GOLD, "metal")

	# Bushy brows, swept up and out
	for side: float in [-1.0, 1.0]:
		for i in 50:
			var t := rng.randf()
			var root := Vector3((0.012 + t * 0.048) * side, 0.163 + sin(t * PI) * 0.006 + rng.randf_range(-0.003, 0.003),
					0.103 - t * t * 0.02)
			var flow := Vector3((0.012 + t * 0.012) * side, 0.008 - t * 0.012, 0.006)
			var jitter := Vector3(rng.randf_range(-0.004, 0.004), rng.randf_range(-0.004, 0.004), rng.randf_range(0.0, 0.004))
			b.strand(PackedVector3Array([root, root + flow * 0.55 + jitter * 0.5, root + flow + jitter]),
					0.0034, 0.0008, HAIR_ROOT, HAIR, "hair", 3, Vector3(0.035 * side, 0.15, 0.08))

	# Moustache: two full sweeps from under the nose, arching out and down
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.sphere(1.0, 14), HAIR_ROOT, "hair",
				ToyBuilder.xf(Vector3(0.03 * side, 0.08, 0.096), Vector3(0, 18 * side, -20 * side), Vector3(0.034, 0.011, 0.011)))
		var centre := Vector3(0.03 * side, 0.075, 0.075)
		for i in 120:
			var u := rng.randf()
			var root := Vector3((0.003 + u * 0.028) * side, 0.091 - u * 0.01 + rng.randf_range(-0.004, 0.003),
					0.112 - u * 0.008)
			var length := rng.randf_range(0.05, 0.08)
			var droop := rng.randf_range(0.02, 0.04)
			var mid := root + Vector3(length * 0.5 * side, -droop * 0.25, 0.004) + _jitter(rng, 0.004)
			var tip := root + Vector3(length * side, -droop, -0.022 - u * 0.012) + _jitter(rng, 0.006)
			b.strand(PackedVector3Array([root, mid, tip]), 0.005, 0.001, HAIR_ROOT, HAIR, "hair", 4, centre)

	# Beard: a soft volume under long, wavy, layered strands down to the chest
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 24), 0.12, 2.5, 3), HAIR_ROOT, "hair",
			ToyBuilder.xf(Vector3(0, -0.03, 0.05), Vector3(12, 0, 0), Vector3(0.088, 0.12, 0.055)))
	var beard_centre := Vector3(0, -0.02, 0.0)
	for i in 600:
		var theta := rng.randf_range(-1.75, 1.75)
		var v := rng.randf()
		var outward := Vector3(sin(theta), 0, cos(theta))
		var across := Vector3(cos(theta), 0, -sin(theta))
		var front := cos(theta)
		var root := Vector3(sin(theta) * 0.093, lerpf(0.03, 0.065 + absf(sin(theta)) * 0.06, v) + absf(sin(theta)) * 0.02,
				0.01 + cos(theta) * 0.098)
		var length := lerpf(0.09, 0.24, front * front) * rng.randf_range(0.75, 1.1) * lerpf(1.0, 0.8, v)
		var bulge := 0.035 + front * 0.03
		var phase := rng.randf() * TAU
		var curl := rng.randf_range(0.004, 0.009)
		var points := PackedVector3Array([root])
		for k in range(1, 6):
			var t := k / 5.0
			# Swells out over the chin, then gathers towards a rounded point,
			# with a soft wave along each lock.
			var p := root + Vector3.DOWN * length * t + outward * bulge * sin(t * PI * 0.8)
			p.x *= lerpf(1.0, 0.72, t * front)
			p.z += t * 0.025 * front
			p += (across * sin(t * 9.0 + phase) + outward * cos(t * 7.0 + phase) * 0.6) * curl * t
			points.append(_clear_chest(p))
		var shade := rng.randf_range(0.93, 1.0)
		b.strand(points, 0.008, 0.0015, HAIR_ROOT * shade, HAIR * shade, "hair", 4, beard_centre)

	# Hair below the hat, falling to the collar at the sides and back
	for i in 240:
		var theta := rng.randf_range(1.45, TAU - 1.45)
		var outward := Vector3(sin(theta), 0, cos(theta))
		var root := Vector3(sin(theta) * 0.098, rng.randf_range(0.17, 0.2), 0.0 + cos(theta) * 0.105)
		var length := rng.randf_range(0.11, 0.16)
		var points := PackedVector3Array([root])
		for k in range(1, 4):
			var t := k / 3.0
			points.append(root + Vector3.DOWN * length * t + outward * (0.018 * sin(t * PI) + t * 0.012) + _jitter(rng, 0.003) * t)
		var shade := rng.randf_range(0.9, 1.0)
		b.strand(points, 0.006, 0.0013, HAIR_ROOT * shade, HAIR * shade, "hair", 4, Vector3(0, 0.12, 0.0))

	# Floppy velvet hat with a fur brim and pom-pom
	b.finished(ToyBuilder.lumpy(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0.2, -0.005), Vector3(0, 0.29, -0.02), Vector3(0.02, 0.36, -0.06),
		Vector3(0.07, 0.385, -0.12), Vector3(0.12, 0.345, -0.16), Vector3(0.145, 0.27, -0.17),
	]), PackedFloat32Array([0.104, 0.088, 0.064, 0.045, 0.03, 0.016]), 28, 6), 0.006, 22.0, 9), RED, "velvet")
	var brim := PackedVector3Array()
	for s in 29:
		var a := TAU * s / 28.0
		brim.append(Vector3(cos(a) * 0.106, 0.205 + sin(a) * 0.008, -0.005 + sin(a) * 0.116))
	_fur_band(b, brim, 0.03, 5)
	_fur_ball(b, Vector3(0.148, 0.255, -0.17), 0.032, 6)

	return b.build(0.0, "HeadMesh")


## Eyeballs, centred on the Eyes node so blinking squashes them shut.
func _build_eyes() -> MeshInstance3D:
	var b := ToyBuilder.new()
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.034 * side, 0, 0)
		b.finished(ToyBuilder.sphere(0.0125, 16), EYE_WHITE, "eye", ToyBuilder.xf(at))
		b.finished(ToyBuilder.sphere(1.0, 14), IRIS, "eye",
				ToyBuilder.xf(at + Vector3(0, -0.001, 0.0105), Vector3.ZERO, Vector3(0.0062, 0.0062, 0.0028)))
		b.finished(ToyBuilder.sphere(1.0, 10), PUPIL, "eye",
				ToyBuilder.xf(at + Vector3(0, -0.001, 0.0126), Vector3.ZERO, Vector3(0.0028, 0.0028, 0.001)))
	return b.build(0.0, "EyesMesh")


# --- Arms ----------------------------------------------------------------------

## Shoulder pivot holding the sleeve, with an elbow pivot holding the forearm,
## fur cuff and a gloved hand.
func _make_arm(side: int) -> void:
	var s := float(side)
	var shoulder := Node3D.new()
	shoulder.name = "ArmRight" if side > 0 else "ArmLeft"
	shoulder.position = Vector3(SHOULDER.x * s, SHOULDER.y, SHOULDER.z)
	_body.add_child(shoulder)
	var upper := ToyBuilder.new()
	upper.finished(ToyBuilder.sphere(1.0, 20), RED, "velvet",
			ToyBuilder.xf(Vector3(0.0, -0.015, 0), Vector3(0, 0, 25 * s), Vector3(0.07, 0.06, 0.074)))
	upper.finished(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0.004 * s, -UPPER_ARM * 0.5, 0.0), Vector3(0, -UPPER_ARM, 0),
	]), PackedFloat32Array([0.074, 0.066, 0.06]), 18, 3), RED, "velvet")
	shoulder.add_child(upper.build(0.0, "UpperArm"))

	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, -UPPER_ARM, 0)
	shoulder.add_child(elbow)
	var lower := ToyBuilder.new()
	lower.finished(ToyBuilder.sphere(0.06, 16), RED, "velvet", ToyBuilder.xf(Vector3.ZERO))
	lower.finished(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, -FOREARM * 0.5, 0.0), Vector3(0, -FOREARM + 0.02, 0),
	]), PackedFloat32Array([0.058, 0.054, 0.06]), 18, 3), RED, "velvet")
	var cuff := PackedVector3Array()
	for k in 21:
		var a := TAU * k / 20.0
		cuff.append(Vector3(cos(a) * 0.062, -FOREARM + 0.01, sin(a) * 0.062))
	_fur_band(lower, cuff, 0.026, 10 + side)
	_glove(lower, Vector3(0, -FOREARM - 0.005, 0), s)
	elbow.add_child(lower.build(0.0, "Forearm"))

	_arms.append(shoulder)
	_elbows.append(elbow)


## A black leather glove hanging palm-in, fingers gently curled.
func _glove(b: ToyBuilder, wrist: Vector3, s: float) -> void:
	b.finished(ToyBuilder.cylinder(0.036, 0.042, 0.04, 14), GLOVE, "leather", ToyBuilder.xf(wrist + Vector3(0, -0.005, 0)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 18), 0.08, 3.0, 4), GLOVE, "leather",
			ToyBuilder.xf(wrist + Vector3(0, -0.06, 0.004), Vector3.ZERO, Vector3(0.022, 0.048, 0.043)))
	var fingers := [[-0.026, 0.07], [-0.009, 0.08], [0.009, 0.076], [0.025, 0.062]]
	for f: Array in fingers:
		var z: float = f[0]
		var length: float = f[1]
		var top := wrist + Vector3(0, -0.098, z)
		b.finished(ToyBuilder.curve(PackedVector3Array([
			top, top + Vector3(-0.006 * s, -length * 0.5, z * 0.08), top + Vector3(-0.02 * s, -length * 0.92, z * 0.12),
		]), PackedFloat32Array([0.0105, 0.0098, 0.009]), 8, 3), GLOVE, "leather")
	var thumb := wrist + Vector3(-0.012 * s, -0.045, 0.034)
	b.finished(ToyBuilder.curve(PackedVector3Array([
		thumb, thumb + Vector3(-0.01 * s, -0.025, 0.016), thumb + Vector3(-0.022 * s, -0.048, 0.016),
	]), PackedFloat32Array([0.013, 0.0115, 0.0105]), 8, 3), GLOVE, "leather")


# --- Fur and hair helpers --------------------------------------------------------

## A band of fur along `path`: a soft lumpy core, plus short tufts that give it
## a fuzzy, real-fur outline. Tufts never point in towards the body's Y axis.
func _fur_band(b: ToyBuilder, path: PackedVector3Array, radius: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var smooth := ToyBuilder.smooth_path(path, 2)
	var radii := PackedFloat32Array()
	radii.resize(smooth.size())
	radii.fill(radius)
	b.finished(ToyBuilder.lumpy(ToyBuilder.tube(smooth, radii, 10), radius * 0.25, 1.0 / (radius * 1.6), seed),
			FUR_DEEP.lerp(FUR, 0.6), "fur")
	var travelled := 0.0
	for i in range(1, smooth.size()):
		var step := smooth[i].distance_to(smooth[i - 1])
		travelled += step
		var tangent := (smooth[i] - smooth[i - 1]).normalized()
		while travelled > 0.0:
			travelled -= 0.0042
			var at := smooth[i - 1].lerp(smooth[i], rng.randf())
			var inward := Vector3(-at.x, 0, -at.z).normalized()
			var dir := Vector3.ZERO
			for attempt in 4:
				dir = tangent.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
				if dir.dot(inward) < 0.15:
					break
			var axis := smooth[i - 1].lerp(smooth[i], 0.5)
			_tuft(b, at + dir * radius * 0.8, dir, radius * rng.randf_range(0.35, 0.6), rng, axis)


## A round ball of fur, e.g. the pom-pom on the hat.
func _fur_ball(b: ToyBuilder, centre: Vector3, radius: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(radius, 16), radius * 0.2, 1.0 / (radius * 0.8), seed), FUR_DEEP.lerp(FUR, 0.6), "fur")
	for i in 260:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		_tuft(b, centre + dir * radius * 0.85, dir, radius * rng.randf_range(0.3, 0.5), rng, centre)


## A short, soft tuft of fur, lit as part of the band or ball it grows from.
func _tuft(b: ToyBuilder, root: Vector3, dir: Vector3, length: float, rng: RandomNumberGenerator,
		centre: Vector3) -> void:
	var bend := (_jitter(rng, 0.6) + Vector3.DOWN * 0.35) * length
	var tip := root + dir * length + bend
	var shade := rng.randf_range(0.95, 1.0)
	b.strand(PackedVector3Array([root, root + dir * length * 0.55 + bend * 0.3, tip]),
			length * 0.34, length * 0.08, FUR_DEEP.lerp(FUR, 0.5) * shade, FUR * shade, "fur", 3, centre)


## Skin coloured by position on the head: rosy cheeks, a red nose and pink ears.
static func _skin_tone(p: Vector3) -> Color:
	var c := SKIN
	for side: float in [-1.0, 1.0]:
		var cheek := p.distance_to(Vector3(0.05 * side, 0.112, 0.088))
		c = c.lerp(CHEEK, smoothstep(0.05, 0.0, cheek) * 0.7)
	c = c.lerp(NOSE, smoothstep(0.03, 0.0, p.distance_to(Vector3(0, 0.104, 0.118))) * 0.7)
	c = c.lerp(CHEEK, smoothstep(0.085, 0.1, absf(p.x)) * 0.35)
	return c


static func _jitter(rng: RandomNumberGenerator, amount: float) -> Vector3:
	return Vector3(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))


## Keeps head-space beard points in front of the chest so the beard lies on it.
static func _clear_chest(p: Vector3) -> Vector3:
	var c := _coat_at(p.y + NECK.y)
	var across := clampf(p.x / c[1], -1.0, 1.0)
	var surface: float = c[2] * sqrt(1.0 - across * across) + 0.012
	if p.z < surface and p.y < -0.02:
		p.z = lerpf(p.z, surface, clampf(-p.y * 12.0, 0.0, 1.0))
	return p


# --- Coat shape ------------------------------------------------------------------

## The coat's half-width, front depth and back depth at a height, interpolated smoothly.
static func _coat_at(y: float) -> Array:
	var rows := COAT.size()
	if y <= COAT[0][0]:
		return COAT[0]
	if y >= COAT[rows - 1][0]:
		return COAT[rows - 1]
	var i := 0
	while COAT[i + 1][0] < y:
		i += 1
	var t := inverse_lerp(COAT[i][0], COAT[i + 1][0], y)
	var p0: Array = COAT[maxi(i - 1, 0)]
	var p1: Array = COAT[i]
	var p2: Array = COAT[i + 1]
	var p3: Array = COAT[mini(i + 2, rows - 1)]
	var out := [y]
	for k in range(1, 4):
		out.append(_catmull(p0[k], p1[k], p2[k], p3[k], t))
	return out


static func _catmull(a: float, b: float, c: float, d: float, t: float) -> float:
	return 0.5 * (2.0 * b + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (3.0 * b - a - 3.0 * c + d) * t * t * t)


## The coat rows with `steps` smooth in-between rows for each pair.
static func _coat_rows(steps: int) -> Array:
	var out := []
	for i in COAT.size() - 1:
		for k in steps:
			out.append(_coat_at(lerpf(COAT[i][0], COAT[i + 1][0], float(k) / steps)))
	out.append(COAT[COAT.size() - 1])
	return out


static func _section(y: float, half: float, front: float, back: float, segments: int,
		fold := 0.0) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for s in segments:
		ring.append(_section_point(y, half, front, back, TAU * s / segments, fold))
	return ring


## A point on an elliptical cross-section. `fold` ripples it into soft
## vertical cloth folds.
static func _section_point(y: float, half: float, front: float, back: float, angle: float,
		fold := 0.0) -> Vector3:
	var depth := front if sin(angle) > 0.0 else back
	var ripple := 1.0 + fold * (sin(angle * 9.0 + y * 3.0) * 0.7 + sin(angle * 5.0 - y * 7.0) * 0.3)
	return Vector3(cos(angle) * half * ripple, y, sin(angle) * depth * ripple)


## How much the coat folds at a height: the skirt flares into folds below the
## belt, and the cloth bunches slightly above it.
static func _fold(y: float) -> float:
	return smoothstep(0.97, 0.72, y) * 0.045 + smoothstep(1.3, 1.06, y) * smoothstep(1.0, 1.06, y) * 0.012
