class_name SantaToy
extends Node3D
## Santa at life size, modelled on realistic reference renders: a portly
## figure in a knee-length velvet coat with thick fur trim, a low leather
## belt under the belly, baggy trousers tucked into fur-cuffed boots, and
## hands resting on his belt. Beard, moustache, brows and hair are made of
## individual wavy locks. Idle animation: breathing, looking around and
## blinking, plus hop() and wave().

const RED := Color("a50f1b")
const RED_TROUSERS := Color("930d18")
const FUR := Color("f5f2ec")
const FUR_DEEP := Color("cdc8bf")
const HAIR := Color("f3f1ed")
const HAIR_ROOT := Color("d6d1ca")
const SKIN := Color("e9b59c")
const CHEEK := Color("e08578")
const NOSE := Color("de8a7c")
const LIP := Color("b4645d")
const LEATHER := Color("5e3822")
const SOLE := Color("24170f")
const GOLD := Color("c9a046")
const IRIS := Color("5b8fbf")
const PUPIL := Color("0f0b0a")
const EYE_WHITE := Color("f0ebe6")

## Coat cross-sections, bottom to top: height, half-width, front depth, back depth.
const COAT := [
	[0.5, 0.3, 0.3, 0.25],
	[0.59, 0.303, 0.318, 0.24],
	[0.68, 0.308, 0.335, 0.235],
	[0.78, 0.315, 0.35, 0.23],
	[0.87, 0.32, 0.365, 0.225],
	[0.97, 0.325, 0.38, 0.22],
	[1.07, 0.316, 0.365, 0.215],
	[1.17, 0.296, 0.325, 0.205],
	[1.26, 0.272, 0.265, 0.195],
	[1.34, 0.252, 0.205, 0.182],
	[1.4, 0.232, 0.165, 0.162],
	[1.45, 0.175, 0.125, 0.122],
	[1.49, 0.105, 0.092, 0.092],
	[1.52, 0.07, 0.07, 0.07],
]
const BELT_Y := 0.86
const NECK := Vector3(0, 1.5, 0)
## The head is modelled at true scale, then enlarged slightly as in the references.
const HEAD_SCALE := 1.14
const SHOULDER := Vector3(0.245, 1.355, -0.015)
const UPPER_ARM := 0.28
const FOREARM := 0.25

## Arm poses, for the right arm (the left is mirrored): the direction of the
## upper arm, the forearm and the fingers, and which way the palm faces.
## At rest his hands sit on his belt; when waving the right hand is raised.
const REST := [Vector3(0.45, -0.85, -0.22), Vector3(-0.3, -0.47, 0.83), Vector3(-0.18, -0.79, 0.56), Vector3(-0.95, 0.0, -0.31)]
const WAVE := [Vector3(0.9, 0.3, 0.3), Vector3(0.15, 1.0, 0.25), Vector3(0.1, 1.0, 0.1), Vector3(0.0, 0.0, 1.0)]

var _body: Node3D
var _head: Node3D
var _eyes: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _wrists: Array[Node3D] = []

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
	_head.scale = Vector3.ONE * HEAD_SCALE
	_body.add_child(_head)
	_head.add_child(_build_head())
	_eyes = Node3D.new()
	_eyes.name = "Eyes"
	_eyes.position = Vector3(0, 0.146, 0.092)
	_head.add_child(_eyes)
	_eyes.add_child(_build_eyes())

	for side: int in [-1, 1]:
		_make_arm(side)
	_process(0.0)


func _process(delta: float) -> void:
	_time += delta
	_hop = maxf(0.0, _hop - delta * 2.4)
	_wave = maxf(0.0, _wave - delta * 0.45)

	# A small, heavy hop and slow breathing.
	var hop_height := sin(_hop * PI) * 0.18 if _hop > 0.0 else 0.0
	var breath := sin(_time * 1.6)
	_body.position.y = hop_height
	_body.scale = Vector3(1.0 + breath * 0.006, 1.0 + breath * 0.004, 1.0 + breath * 0.009)

	# Looks around slowly.
	_head.rotation = Vector3(sin(_time * 0.7) * 0.04 - 0.02, sin(_time * 0.45) * 0.16, sin(_time * 0.9) * 0.03)

	var wave_amount := smoothstep(0.0, 0.15, _wave) * smoothstep(1.0, 0.85, _wave)
	var flap := sin(_time * 11.0) * 0.45
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var w := wave_amount if side > 0.0 else 0.0
		var pose := []
		for k in 4:
			var target: Vector3 = WAVE[k]
			if k == 1:
				target += Vector3(flap, 0, 0)
			pose.append((REST[k] as Vector3).lerp(target, w))
		# Elbows lift a little with each breath and hop.
		pose[0] += Vector3(0.04 * breath + hop_height * 1.5, hop_height, 0)
		_pose_arm(i, side, pose)

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


# --- Arm posing ------------------------------------------------------------------

## Points the shoulder, elbow and wrist joints along a pose (given for the right
## arm, mirrored for the left). Every limb is modelled hanging down its -Y axis.
func _pose_arm(i: int, side: float, pose: Array) -> void:
	var mirror := Vector3(side, 1, 1)
	var upper := _bone(pose[0] * mirror)
	var lower := _bone(pose[1] * mirror)
	var fingers: Vector3 = (pose[2] * mirror).normalized()
	var palm: Vector3 = pose[3] * mirror
	# The glove's palm faces its local -X (right hand) or +X (left hand).
	var y := -fingers
	var x := (-palm * side - y * (-palm * side).dot(y)).normalized()
	var hand := Basis(x, y, x.cross(y))
	_shoulders[i].basis = upper
	_elbows[i].basis = upper.inverse() * lower
	_wrists[i].basis = lower.inverse() * hand


## A joint basis whose -Y axis points along `down`, facing forward as far as possible.
static func _bone(down: Vector3) -> Basis:
	var y := -down.normalized()
	var z := (Vector3.BACK - y * Vector3.BACK.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


# --- Body ------------------------------------------------------------------------

func _build_body() -> MeshInstance3D:
	var b := ToyBuilder.new()

	# Coat, lofted through the cross-sections so he has a real belly, with the
	# skirt falling in soft folds.
	var rings: Array[PackedVector3Array] = []
	for row in _coat_rows(4):
		rings.append(_section(row[0], row[1], row[2], row[3], 56, _fold(row[0])))
	b.finished(ToyBuilder.loft(rings), RED, "velvet")

	# Wide leather belt low under the belly, with a brass buckle
	var belt: Array[PackedVector3Array] = []
	for belt_y: float in [BELT_Y - 0.045, BELT_Y + 0.045]:
		var c := _coat_at(belt_y)
		belt.append(_section(belt_y, c[1] + 0.006, c[2] + 0.006, c[3] + 0.006, 56))
	b.finished(ToyBuilder.loft(belt), LEATHER, "leather")
	var buckle_z: float = _coat_at(BELT_Y)[2] + 0.016
	for k in 4:
		var horizontal := k < 2
		var offset := 0.045 if k % 2 == 0 else -0.045
		var size := Vector3(0.14, 0.016, 0.01) if horizontal else Vector3(0.016, 0.106, 0.01)
		var pos := Vector3(0, BELT_Y + offset, buckle_z) if horizontal else Vector3(offset * 1.4, BELT_Y, buckle_z)
		b.finished(ToyBuilder.box(size), GOLD, "metal", ToyBuilder.xf(pos))
	b.finished(ToyBuilder.cylinder(0.005, 0.005, 0.1, 6), GOLD, "metal",
			ToyBuilder.xf(Vector3(0.0, BELT_Y, buckle_z + 0.006), Vector3(0, 0, 90)))

	# Thick fur trim: the hem, a shawl collar, and down the front opening
	var hem := PackedVector3Array()
	for s in 41:
		var a := TAU * s / 40.0
		var c := _coat_at(0.53)
		hem.append(_section_point(0.53, c[1] + 0.02, c[2] + 0.02, c[3] + 0.02, a, _fold(0.53)))
	_fur_band(b, hem, 0.058, 1)
	var collar := PackedVector3Array()
	for s in 29:
		var a := TAU * s / 28.0
		collar.append(Vector3(cos(a) * 0.12, 1.47 - sin(a) * 0.03, sin(a) * 0.11))
	_fur_band(b, collar, 0.05, 2)
	var front := PackedVector3Array()
	var y := 0.56
	while y <= 1.44:
		if absf(y - BELT_Y) > 0.055:
			front.append(Vector3(0, y, _coat_at(y)[2] + 0.008))
		elif front.size() > 1:
			_fur_band(b, front, 0.04, 3)
			front = PackedVector3Array()
		y += 0.03
	_fur_band(b, front, 0.04, 4)

	# Baggy trousers tucked into fur-cuffed boots, feet turned slightly out
	for side: float in [-1.0, 1.0]:
		var x := 0.145 * side
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(x * 0.9, 0.68, 0), Vector3(x, 0.48, 0.01), Vector3(x, 0.27, 0),
		]), PackedFloat32Array([0.13, 0.12, 0.092]), 18, 3), RED_TROUSERS, "velvet")
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(x, 0.05, -0.01), Vector3(x, 0.12, 0.0), Vector3(x, 0.2, 0.0), Vector3(x, 0.28, 0.0),
		]), PackedFloat32Array([0.07, 0.074, 0.082, 0.088]), 18, 3), LEATHER, "leather")
		var cuff := PackedVector3Array()
		for k in 21:
			var a := TAU * k / 20.0
			cuff.append(Vector3(x + cos(a) * 0.096, 0.285, sin(a) * 0.096))
		_fur_band(b, cuff, 0.036, 20 + int(side), Vector2(x, 0))
		var foot := ToyBuilder.xf(Vector3(x, 0.0, 0.0), Vector3(0, 12 * side, 0))
		b.finished(ToyBuilder.sphere(1.0, 20), LEATHER, "leather",
				foot * ToyBuilder.xf(Vector3(0, 0.062, 0.08), Vector3(-6, 0, 0), Vector3(0.072, 0.056, 0.14)))
		b.finished(ToyBuilder.sphere(1.0, 16), LEATHER, "leather",
				foot * ToyBuilder.xf(Vector3(0, 0.07, -0.02), Vector3.ZERO, Vector3(0.07, 0.065, 0.075)))
		b.finished(ToyBuilder.sphere(1.0, 20), SOLE, "leather",
				foot * ToyBuilder.xf(Vector3(0, 0.015, 0.05), Vector3.ZERO, Vector3(0.078, 0.017, 0.17)))
	return b.build(0.0, "BodyMesh")


# --- Head ------------------------------------------------------------------------

## Built at true scale around the top of the neck (NECK), facing +Z.
func _build_head() -> MeshInstance3D:
	var b := ToyBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225

	# Skull, jaw, ears, brow ridge, full cheeks and nose, all painted with one
	# skin tone so the rosy cheeks and nose blend in smoothly.
	var skin := _skin_tone
	b.painted_finish(ToyBuilder.sphere(1.0, 32), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.13, 0.005), Vector3.ZERO, Vector3(0.098, 0.118, 0.108)))
	b.painted_finish(ToyBuilder.sphere(1.0, 20), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.07, 0.03), Vector3.ZERO, Vector3(0.086, 0.076, 0.076)))
	for side: float in [-1.0, 1.0]:
		b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
				ToyBuilder.xf(Vector3(0.097 * side, 0.135, -0.005), Vector3(0, 20 * side, 0), Vector3(0.014, 0.033, 0.022)))
		b.painted_finish(ToyBuilder.sphere(1.0, 12), skin, "skin",
				ToyBuilder.xf(Vector3(0.036 * side, 0.166, 0.093), Vector3(0, 0, -8 * side), Vector3(0.024, 0.009, 0.014)))
		b.painted_finish(ToyBuilder.sphere(1.0, 16), skin, "skin",
				ToyBuilder.xf(Vector3(0.046 * side, 0.112, 0.074), Vector3(0, 25 * side, 0), Vector3(0.036, 0.03, 0.02)))
		# Eyelids hug the top and bottom of each eye
		b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
				ToyBuilder.xf(Vector3(0.036 * side, 0.1545, 0.0915), Vector3(-10, 0, 0), Vector3(0.0158, 0.0072, 0.0135)))
		b.painted_finish(ToyBuilder.sphere(1.0, 12), skin, "skin",
				ToyBuilder.xf(Vector3(0.036 * side, 0.1365, 0.093), Vector3.ZERO, Vector3(0.015, 0.0042, 0.0125)))
		b.painted_finish(ToyBuilder.sphere(1.0, 10), skin, "skin",
				ToyBuilder.xf(Vector3(0.0125 * side, 0.0995, 0.105), Vector3(0, 20 * side, 0), Vector3(0.0075, 0.0068, 0.0085)))
	b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.128, 0.106), Vector3(-22, 0, 0), Vector3(0.0085, 0.026, 0.0105)))
	b.painted_finish(ToyBuilder.sphere(1.0, 16), skin, "skin",
			ToyBuilder.xf(Vector3(0, 0.104, 0.1155), Vector3(-10, 0, 0), Vector3(0.0128, 0.0125, 0.0145)))
	b.finished(ToyBuilder.sphere(1.0, 12), LIP, "skin",
			ToyBuilder.xf(Vector3(0, 0.058, 0.097), Vector3(8, 0, 0), Vector3(0.018, 0.007, 0.009)))
	_face_lines(b, rng)

	# Wire spectacles resting on the nose
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.torus(0.021, 0.0014, 24, 5), GOLD, "metal",
				ToyBuilder.xf(Vector3(0.037 * side, 0.144, 0.121), Vector3(90, 0, 0)))
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.058 * side, 0.147, 0.118), Vector3(0.09 * side, 0.15, 0.09),
			Vector3(0.101 * side, 0.147, 0.03), Vector3(0.099 * side, 0.128, -0.005),
		]), PackedFloat32Array([0.0013, 0.0013, 0.0013, 0.0013]), 5, 4), GOLD, "metal")
	b.finished(ToyBuilder.curve(PackedVector3Array([
		Vector3(-0.016, 0.146, 0.122), Vector3(0, 0.151, 0.126), Vector3(0.016, 0.146, 0.122),
	]), PackedFloat32Array([0.0014, 0.0014, 0.0014]), 5, 4), GOLD, "metal")

	# Big bushy brows, sweeping up and out over the eyes
	for side: float in [-1.0, 1.0]:
		var centre := Vector3(0.04 * side, 0.155, 0.08)
		for i in 80:
			var t := rng.randf()
			var root := Vector3((0.01 + t * 0.055) * side, 0.166 + sin(t * PI) * 0.007 + rng.randf_range(-0.004, 0.004),
					0.104 - t * t * 0.024)
			var length := rng.randf_range(0.022, 0.038) * lerpf(0.7, 1.2, t)
			var flow := Vector3(0.8 * side, 0.45 - t * 0.9, 0.3).normalized() * length
			var mid := root + flow * 0.5 + Vector3(0, 0.004, 0.003) + _jitter(rng, 0.003)
			b.strand(PackedVector3Array([root, mid, root + flow + _jitter(rng, 0.005)]),
					0.0042, 0.0009, HAIR_ROOT, HAIR, "hair", 3, centre)

	# Heavy moustache: sweeps from under the nose, down past the mouth corners,
	# and curls at the ends.
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.sphere(1.0, 14), HAIR_ROOT, "hair",
				ToyBuilder.xf(Vector3(0.032 * side, 0.078, 0.096), Vector3(0, 18 * side, -24 * side), Vector3(0.036, 0.013, 0.012)))
		var centre := Vector3(0.035 * side, 0.07, 0.07)
		for i in 190:
			var u := rng.randf()
			var root := Vector3((0.003 + u * 0.03) * side, 0.092 - u * 0.012 + rng.randf_range(-0.005, 0.003),
					0.117 - u * 0.006)
			var length := rng.randf_range(0.06, 0.095)
			var droop := rng.randf_range(0.035, 0.06)
			var curl := rng.randf_range(0.0, 0.02)
			var p1 := root + Vector3(length * 0.35 * side, -droop * 0.3, 0.006) + _jitter(rng, 0.004)
			var p2 := root + Vector3(length * 0.75 * side, -droop * 0.85, -0.006) + _jitter(rng, 0.005)
			var tip := root + Vector3(length * side, -droop + curl, -0.02 - u * 0.01) + _jitter(rng, 0.006)
			b.strand(PackedVector3Array([root, p1, p2, tip]), 0.0068, 0.0012, HAIR_ROOT, HAIR, "hair", 5, centre)

	# Beard: a soft volume under long, curly locks, wider than the face and
	# falling to a rounded point on the chest.
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 24), 0.12, 2.5, 3), HAIR_ROOT, "hair",
			ToyBuilder.xf(Vector3(0, -0.04, 0.05), Vector3(12, 0, 0), Vector3(0.1, 0.13, 0.06)))
	var beard_centre := Vector3(0, -0.02, 0.0)
	var locks: Array[PackedVector3Array] = []
	for i in 95:
		var theta := rng.randf_range(-1.7, 1.7)
		var v := rng.randf()
		var outward := Vector3(sin(theta), 0, cos(theta))
		var across := Vector3(cos(theta), 0, -sin(theta))
		var front := cos(theta)
		var root := Vector3(sin(theta) * 0.092, lerpf(0.025, 0.06 + absf(sin(theta)) * 0.06, v) + absf(sin(theta)) * 0.02,
				0.01 + cos(theta) * 0.096)
		var length := lerpf(0.1, 0.25, front * front) * rng.randf_range(0.8, 1.1) * lerpf(1.0, 0.8, v)
		# Locks near the mouth lie flatter so the moustache sits on top; side
		# locks stay close to the jaw so the beard isn't wider than the face.
		var bulge := (0.025 + front * 0.04) * lerpf(1.0, 0.45, v * front * front)
		var phase := rng.randf() * TAU
		var curl := rng.randf_range(0.008, 0.016)
		var path := PackedVector3Array([root])
		for k in range(1, 9):
			var t := k / 8.0
			# Swells out over the chin, then gathers towards a rounded point,
			# each lock curling as it falls.
			var p := root + Vector3.DOWN * length * t + outward * bulge * sin(t * PI * 0.8)
			p.x *= lerpf(1.0, 0.7, t)
			p.z += t * 0.02 * front
			p += (across * sin(t * 6.0 + phase) + outward * cos(t * 6.0 + phase) * 0.6) * curl * sqrt(t)
			path.append(p)
		locks.append(path)
	for lock in locks:
		var spread := rng.randf_range(0.004, 0.0065)
		for j in 9:
			var offset := _jitter(rng, spread)
			var stretch := rng.randf_range(0.85, 1.05)
			var points := PackedVector3Array()
			for k in lock.size():
				var t := k / float(lock.size() - 1)
				# Strands fan out from the lock's root and gather again at its tip.
				var p := lock[0].lerp(lock[k], stretch) + offset * sin(t * PI * 0.85) * 1.6
				points.append(_clear_chest(p))
			var shade := rng.randf_range(0.9, 1.0) * (0.84 if rng.randf() < 0.15 else 1.0)
			var tint := HAIR.lerp(Color("eee6d6"), 0.5) if rng.randf() < 0.25 else HAIR
			b.strand(points, 0.0075, 0.0015, HAIR_ROOT * shade, tint * shade, "hair", 4, beard_centre)

	# Wavy white hair puffing out at the sides and back below the hat
	var hair_centre := Vector3(0, 0.12, -0.01)
	for i in 340:
		var theta := rng.randf_range(1.3, TAU - 1.3)
		var outward := Vector3(sin(theta), 0, cos(theta))
		var root := Vector3(sin(theta) * 0.1, rng.randf_range(0.17, 0.215), -0.005 + cos(theta) * 0.107)
		var length := rng.randf_range(0.11, 0.17)
		var phase := rng.randf() * TAU
		var points := PackedVector3Array([root])
		for k in range(1, 5):
			var t := k / 4.0
			var p := root + Vector3.DOWN * length * t + outward * (0.035 * sin(t * PI * 0.9) + t * 0.015)
			p += Vector3(0, 0, 0.01).rotated(Vector3.UP, theta) * sin(t * 9.0 + phase) + _jitter(rng, 0.004) * t
			points.append(p)
		var shade := rng.randf_range(0.92, 1.0)
		b.strand(points, 0.007, 0.0014, HAIR_ROOT * shade, HAIR * shade, "hair", 4, hair_centre)

	# Floppy velvet hat sitting above the forehead, with a thick fur brim and pom-pom
	b.finished(ToyBuilder.lumpy(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0.22, -0.008), Vector3(0, 0.31, -0.025), Vector3(0.02, 0.38, -0.07),
		Vector3(0.075, 0.405, -0.13), Vector3(0.13, 0.36, -0.17), Vector3(0.155, 0.28, -0.18),
	]), PackedFloat32Array([0.106, 0.09, 0.066, 0.046, 0.03, 0.017]), 28, 6), 0.007, 22.0, 9), RED, "velvet")
	var brim := PackedVector3Array()
	for s in 33:
		var a := TAU * s / 32.0
		brim.append(Vector3(cos(a) * 0.107, 0.222 + sin(a) * 0.01, -0.008 + sin(a) * 0.117))
	_fur_band(b, brim, 0.038, 5)
	_fur_ball(b, Vector3(0.158, 0.26, -0.18), 0.036, 6)

	return b.build(0.0, "HeadMesh")


## Wrinkles and small features that make the face read as a real, older face:
## soft bags under the eyes, nostrils, forehead lines, laugh lines at the eye
## corners and pale lashes.
func _face_lines(b: ToyBuilder, rng: RandomNumberGenerator) -> void:
	var skin := _skin_tone
	for side: float in [-1.0, 1.0]:
		b.painted_finish(ToyBuilder.sphere(1.0, 14), skin, "skin",
				ToyBuilder.xf(Vector3(0.037 * side, 0.1305, 0.0905), Vector3(-15, 8 * side, 0), Vector3(0.016, 0.0055, 0.009)))
		b.finished(ToyBuilder.sphere(1.0, 10), Color("6e3a30"), "skin",
				ToyBuilder.xf(Vector3(0.0085 * side, 0.0935, 0.1115), Vector3(-25, 25 * side, 0), Vector3(0.0045, 0.0018, 0.0055)))
		# Laugh lines fanning out from the outer eye corner
		for k in 3:
			var a := deg_to_rad(-25.0 + k * 25.0)
			var start := Vector3(0.054 * side, 0.146, 0.087)
			var dir := Vector3(cos(a) * side * 0.55, sin(a), -0.45 * absf(cos(a))).normalized()
			b.painted_finish(ToyBuilder.curve(PackedVector3Array([
				start, start + dir * 0.008, start + dir * 0.015 + Vector3(0, 0, -0.003),
			]), PackedFloat32Array([0.0004, 0.0012, 0.0003]), 5, 3), skin, "skin")
		# Pale lashes along the upper lid
		var lash_colour := Color("bdb6ad")
		for i in 26:
			var u := lerpf(-1.0, 1.0, (i + rng.randf()) / 26.0)
			var root := Vector3(0.036 * side + u * 0.0128, 0.1492 - u * u * 0.0035, 0.1035 - u * u * 0.0045)
			var out := Vector3(u * 0.25, 0.25, 1.0).normalized()
			b.strand(PackedVector3Array([root, root + out * 0.003, root + out * 0.0055 + Vector3(0, 0.0022, 0)]),
					0.00045, 0.00015, lash_colour, lash_colour.lightened(0.3), "hair", 3)
	# Three shallow forehead folds following the curve of the skull
	for k in 3:
		var y := 0.18 + k * 0.0115
		var squash := sqrt(1.0 - pow((y - 0.13) / 0.118, 2.0))
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 9:
			var a := lerpf(-0.62, 0.62, i / 8.0) * (1.0 - k * 0.08)
			points.append(Vector3(sin(a) * 0.098 * squash * 0.985, y + absf(a) * 0.006, 0.005 + cos(a) * 0.108 * squash * 0.985))
			radii.append(0.0024 * sin(PI * i / 8.0))
		b.painted_finish(ToyBuilder.curve(points, radii, 6, 3), skin, "skin")


## Eyeballs, centred on the Eyes node so blinking squashes them shut.
func _build_eyes() -> MeshInstance3D:
	var b := ToyBuilder.new()
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.036 * side, 0, 0)
		# Off-white, a little pink towards the corners
		b.painted_finish(ToyBuilder.sphere(0.0138, 24), func(v: Vector3) -> Color:
			return EYE_WHITE.lerp(Color("e8beb4"), smoothstep(0.006, 0.0125, absf(v.x - at.x)) * 0.6),
			"eye", ToyBuilder.xf(at))
		# Iris: a dark outer ring, blue flecked body and a paler ring round the pupil
		var iris_centre := at + Vector3(0, -0.0005, 0.0115)
		b.painted_finish(ToyBuilder.sphere(1.0, 32), func(v: Vector3) -> Color:
			var r := Vector2(v.x - iris_centre.x, v.y - iris_centre.y).length() / 0.0074
			var c := IRIS.lerp(Color("9cc4e2"), smoothstep(0.55, 0.3, r) * 0.6)
			return c.lerp(Color("23415e"), smoothstep(0.75, 0.97, r)),
			"eye", ToyBuilder.xf(iris_centre, Vector3.ZERO, Vector3(0.0074, 0.0074, 0.003)))
		b.finished(ToyBuilder.sphere(1.0, 10), PUPIL, "eye",
				ToyBuilder.xf(at + Vector3(0, -0.0005, 0.0139), Vector3.ZERO, Vector3(0.0032, 0.0032, 0.001)))
	return b.build(0.0, "EyesMesh")


# --- Arms ------------------------------------------------------------------------

## A shoulder joint holding the sleeve, an elbow joint holding the forearm and
## fur cuff, and a wrist joint holding the gloved hand.
func _make_arm(side: int) -> void:
	var s := float(side)
	var shoulder := Node3D.new()
	shoulder.name = "ArmRight" if side > 0 else "ArmLeft"
	shoulder.position = Vector3(SHOULDER.x * s, SHOULDER.y, SHOULDER.z)
	_body.add_child(shoulder)
	var upper := ToyBuilder.new()
	upper.finished(ToyBuilder.sphere(1.0, 20), RED, "velvet",
			ToyBuilder.xf(Vector3(0.0, -0.01, 0), Vector3.ZERO, Vector3(0.086, 0.08, 0.088)))
	upper.finished(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, -UPPER_ARM * 0.5, 0.0), Vector3(0, -UPPER_ARM, 0),
	]), PackedFloat32Array([0.088, 0.082, 0.076]), 18, 3), RED, "velvet")
	shoulder.add_child(upper.build(0.0, "UpperArm"))

	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, -UPPER_ARM, 0)
	shoulder.add_child(elbow)
	var lower := ToyBuilder.new()
	lower.finished(ToyBuilder.sphere(0.076, 16), RED, "velvet", ToyBuilder.xf(Vector3.ZERO))
	lower.finished(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, -FOREARM * 0.5, 0.0), Vector3(0, -FOREARM + 0.03, 0),
	]), PackedFloat32Array([0.074, 0.07, 0.074]), 18, 3), RED, "velvet")
	var cuff := PackedVector3Array()
	for k in 21:
		var a := TAU * k / 20.0
		cuff.append(Vector3(cos(a) * 0.075, -FOREARM + 0.03, sin(a) * 0.075))
	_fur_band(lower, cuff, 0.036, 10 + side)
	elbow.add_child(lower.build(0.0, "Forearm"))

	var wrist := Node3D.new()
	wrist.name = "Wrist"
	wrist.position = Vector3(0, -FOREARM, 0)
	elbow.add_child(wrist)
	var hand := ToyBuilder.new()
	_glove(hand, s)
	wrist.add_child(hand.build(0.0, "Glove"))

	_shoulders.append(shoulder)
	_elbows.append(elbow)
	_wrists.append(wrist)


## A brown leather glove, palm facing -X (right) or +X (left), fingers gently curled.
func _glove(b: ToyBuilder, s: float) -> void:
	b.finished(ToyBuilder.cylinder(0.042, 0.048, 0.05, 14), LEATHER, "leather", ToyBuilder.xf(Vector3(0, 0.0, 0)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 18), 0.08, 3.0, 4), LEATHER, "leather",
			ToyBuilder.xf(Vector3(0.002 * s, -0.062, 0.004), Vector3.ZERO, Vector3(0.026, 0.052, 0.048)))
	var fingers := [[-0.03, 0.075], [-0.011, 0.086], [0.009, 0.082], [0.028, 0.068]]
	for f: Array in fingers:
		var z: float = f[0]
		var length: float = f[1]
		var top := Vector3(0, -0.103, z)
		b.finished(ToyBuilder.curve(PackedVector3Array([
			top, top + Vector3(-0.008 * s, -length * 0.5, z * 0.08), top + Vector3(-0.024 * s, -length * 0.9, z * 0.12),
		]), PackedFloat32Array([0.0122, 0.0114, 0.0104]), 8, 3), LEATHER, "leather")
	var thumb := Vector3(-0.014 * s, -0.048, 0.038)
	b.finished(ToyBuilder.curve(PackedVector3Array([
		thumb, thumb + Vector3(-0.012 * s, -0.028, 0.018), thumb + Vector3(-0.026 * s, -0.052, 0.018),
	]), PackedFloat32Array([0.0148, 0.013, 0.0118]), 8, 3), LEATHER, "leather")


# --- Fur and hair helpers ----------------------------------------------------------

## A band of fur along `path`: a soft lumpy core, plus short tufts that give it
## a fuzzy, real-fur outline. Tufts never point in towards the vertical axis
## through `centre_xz` (the body, a leg, an arm).
func _fur_band(b: ToyBuilder, path: PackedVector3Array, radius: float, seed: int,
		centre_xz := Vector2.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var smooth := ToyBuilder.smooth_path(path, 2)
	var radii := PackedFloat32Array()
	radii.resize(smooth.size())
	radii.fill(radius)
	b.finished(ToyBuilder.lumpy(ToyBuilder.tube(smooth, radii, 12), radius * 0.25, 1.0 / (radius * 1.6), seed),
			FUR_DEEP.lerp(FUR, 0.6), "fur")
	var travelled := 0.0
	for i in range(1, smooth.size()):
		travelled += smooth[i].distance_to(smooth[i - 1])
		var tangent := (smooth[i] - smooth[i - 1]).normalized()
		var axis := smooth[i - 1].lerp(smooth[i], 0.5)
		while travelled > 0.0:
			travelled -= 0.005
			var at := smooth[i - 1].lerp(smooth[i], rng.randf())
			var inward := Vector3(centre_xz.x - at.x, 0, centre_xz.y - at.z).normalized()
			var dir := Vector3.ZERO
			for attempt in 4:
				dir = tangent.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
				if dir.dot(inward) < 0.15:
					break
			_tuft(b, at + dir * radius * 0.75, dir, radius * rng.randf_range(0.22, 0.38), rng, axis)


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
	var bend := (_jitter(rng, 0.5) + Vector3.DOWN * 0.15) * length
	var tip := root + dir * length + bend
	var shade := rng.randf_range(0.95, 1.0)
	b.strand(PackedVector3Array([root, root + dir * length * 0.55 + bend * 0.3, tip]),
			length * 0.42, length * 0.22, FUR_DEEP.lerp(FUR, 0.5) * shade, FUR * shade, "fur", 4, centre)


## Skin coloured by position on the head: rosy cheeks, a red nose and pink ears.
static func _skin_tone(p: Vector3) -> Color:
	var c := SKIN
	for side: float in [-1.0, 1.0]:
		var cheek := p.distance_to(Vector3(0.05 * side, 0.112, 0.088))
		c = c.lerp(CHEEK, smoothstep(0.06, 0.0, cheek) * 0.5)
	c = c.lerp(NOSE, smoothstep(0.032, 0.0, p.distance_to(Vector3(0, 0.104, 0.12))) * 0.75)
	c = c.lerp(CHEEK, smoothstep(0.085, 0.1, absf(p.x)) * 0.35)
	return c


static func _jitter(rng: RandomNumberGenerator, amount: float) -> Vector3:
	return Vector3(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))


## Keeps head-space beard points in front of the chest so the beard lies on it.
static func _clear_chest(p: Vector3) -> Vector3:
	var c := _coat_at(NECK.y + p.y * HEAD_SCALE)
	var across := clampf(p.x * HEAD_SCALE / c[1], -1.0, 1.0)
	var surface: float = (c[2] * sqrt(1.0 - across * across) + 0.02) / HEAD_SCALE
	if p.z < surface and p.y < -0.02:
		p.z = lerpf(p.z, surface, clampf(-p.y * 12.0, 0.0, 1.0))
	return p


# --- Coat shape --------------------------------------------------------------------

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


## How much the coat folds at a height: the skirt falls in folds below the
## belt, and the cloth bunches slightly above it.
static func _fold(y: float) -> float:
	return smoothstep(BELT_Y - 0.04, 0.52, y) * 0.05 \
			+ smoothstep(BELT_Y + 0.25, BELT_Y + 0.05, y) * smoothstep(BELT_Y, BELT_Y + 0.05, y) * 0.015
