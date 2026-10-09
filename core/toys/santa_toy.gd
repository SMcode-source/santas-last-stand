class_name SantaToy
extends Node3D
## Santa, built as a detailed toy figure, with procedural idle animation:
## breathing, looking around, blinking, plus hop() and wave().

const RED := Color("c8102e")
const RED_DARK := Color("9e0b22")
const FUR := Color("f7f4ee")
const SKIN := Color("f5c9a6")
const CHEEK := Color("f0968a")
const NOSE := Color("ec8f7c")
const BOOT := Color("26201f")
const SOLE := Color("4a2c17")
const BELT := Color("2a1f1d")
const GOLD := Color("e5b638")
const MITTEN := Color("2f6b3a")
const SACK := Color("8b5e34")
const PUPIL := Color("2b1d1a")
const EYE_WHITE := Color("ffffff")

## Coat silhouette as (radius, height) points, bottom to top.
const COAT_PROFILE := [
	Vector2(0.0, 0.34), Vector2(0.5, 0.34), Vector2(0.56, 0.4), Vector2(0.6, 0.55),
	Vector2(0.62, 0.72), Vector2(0.6, 0.9), Vector2(0.54, 1.05), Vector2(0.46, 1.17),
	Vector2(0.36, 1.27), Vector2(0.24, 1.34), Vector2(0.0, 1.37),
]

var _body: Node3D
var _head: Node3D
var _eyes: Node3D
var _arm_left: Node3D
var _arm_right: Node3D

var _time := 0.0
var _hop := 0.0
var _wave := 0.0
var _next_blink := 2.0
var _blink := 0.0


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_body.add_child(_build_torso())

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.34, 0)
	_body.add_child(_head)
	_head.add_child(_build_head())
	_eyes = Node3D.new()
	_eyes.name = "Eyes"
	_eyes.position = Vector3(0, 0.44, 0)
	_head.add_child(_eyes)
	_eyes.add_child(_build_eyes())

	_arm_left = _make_arm(-1)
	_arm_right = _make_arm(1)


func _process(delta: float) -> void:
	_time += delta
	_hop = maxf(0.0, _hop - delta * 2.2)
	_wave = maxf(0.0, _wave - delta * 0.45)

	# Body: gentle breathing, plus squash-and-stretch hop.
	var hop_height := sin(_hop * PI) * 0.7 if _hop > 0.0 else 0.0
	var breath := sin(_time * 2.2)
	_body.position.y = breath * 0.015 + hop_height
	var stretch := 1.0 + breath * 0.012 + hop_height * 0.18
	_body.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))

	# Head: looks around slowly.
	_head.rotation = Vector3(sin(_time * 0.9) * 0.05, sin(_time * 0.6) * 0.3, sin(_time * 1.1) * 0.06)

	# Arms: idle sway, raised during a hop, waving when asked.
	var sway := sin(_time * 2.2) * 0.08
	var lift := hop_height * 1.2
	_arm_left.rotation = Vector3(sway, 0, -0.08 - lift)
	var wave_amount := smoothstep(0.0, 0.15, _wave) * smoothstep(1.0, 0.85, _wave)
	var wave_angle := 2.5 + sin(_time * 12.0) * 0.3
	_arm_right.rotation = Vector3(-sway, 0, lerpf(0.08 + lift, wave_angle, wave_amount))

	# Blinking.
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 4.5)
	_blink = maxf(0.0, _blink - delta)
	_eyes.scale.y = 0.1 if _blink > 0.0 else 1.0


## A little hop of joy.
func hop() -> void:
	if _hop <= 0.0:
		_hop = 1.0


## Waves the right arm for a couple of seconds.
func wave() -> void:
	if _wave <= 0.1:
		_wave = 1.0


# --- Model ---------------------------------------------------------------------

func _build_torso() -> MeshInstance3D:
	var b := ToyBuilder.new()

	# Boots
	for side in [-1.0, 1.0]:
		var x: float = 0.2 * side
		b.part(ToyBuilder.cylinder(0.13, 0.14, 0.27), BOOT, Vector3(x, 0.2, 0))
		b.part(ToyBuilder.sphere(1.0), BOOT, Vector3(x, 0.1, 0.1), Vector3.ZERO, Vector3(0.15, 0.11, 0.24))
		b.part(ToyBuilder.box(Vector3(0.3, 0.05, 0.44)), SOLE, Vector3(x, 0.025, 0.06))

	# Coat, hem and collar fur, and the fur strip down the front
	b.add(ToyBuilder.lathe(PackedVector2Array(COAT_PROFILE), 28), RED)
	b.fluff_ring(Vector3(0, 0.37, 0), 0.53, 0.075, FUR, 26, Vector3.ZERO, 3)
	b.fluff_ring(Vector3(0, 1.32, 0), 0.27, 0.075, FUR, 16, Vector3.ZERO, 5)
	var strip := PackedVector3Array()
	var y := 0.4
	while y <= 1.3:
		strip.append(Vector3(0, y, _coat_radius(y) + 0.01))
		y += 0.1
	b.fluff_path(strip, 0.065, FUR, 0.055, 7)

	# Belt and buckle
	b.part(ToyBuilder.cylinder(0.637, 0.637, 0.12, 28), BELT, Vector3(0, 0.72, 0))
	var buckle_z := 0.65
	b.part(ToyBuilder.box(Vector3(0.24, 0.04, 0.05)), GOLD, Vector3(0, 0.79, buckle_z))
	b.part(ToyBuilder.box(Vector3(0.24, 0.04, 0.05)), GOLD, Vector3(0, 0.65, buckle_z))
	b.part(ToyBuilder.box(Vector3(0.04, 0.18, 0.05)), GOLD, Vector3(-0.1, 0.72, buckle_z))
	b.part(ToyBuilder.box(Vector3(0.04, 0.18, 0.05)), GOLD, Vector3(0.1, 0.72, buckle_z))
	b.part(ToyBuilder.box(Vector3(0.12, 0.025, 0.03)), GOLD, Vector3(0.02, 0.72, buckle_z + 0.01))

	# Sack of presents on his back, with a strap across the chest
	b.part(ToyBuilder.sphere(1.0, 18), SACK, Vector3(0.05, 0.98, -0.55), Vector3(0, 0, 8), Vector3(0.42, 0.5, 0.32))
	b.fluff_blob(Vector3(0.05, 0.95, -0.6), Vector3(0.3, 0.35, 0.18), 0.14, SACK, 10, 11)
	b.part(ToyBuilder.cylinder(0.09, 0.15, 0.14), SACK, Vector3(0.0, 1.45, -0.52), Vector3(0, 0, 8))
	b.part(ToyBuilder.torus(0.1, 0.025), Color("d9c27a"), Vector3(0.0, 1.43, -0.52), Vector3(0, 0, 8))
	b.part(ToyBuilder.box(Vector3(0.2, 0.2, 0.2)), Color("2e86de"), Vector3(0.08, 1.58, -0.5), Vector3(10, 25, 12))
	b.part(ToyBuilder.box(Vector3(0.21, 0.21, 0.05)), GOLD, Vector3(0.08, 1.58, -0.5), Vector3(10, 25, 12))
	b.add(ToyBuilder.curve(PackedVector3Array([
		Vector3(-0.1, 1.4, -0.55), Vector3(-0.14, 1.66, -0.55), Vector3(-0.08, 1.75, -0.55), Vector3(-0.02, 1.7, -0.55),
	]), PackedFloat32Array([0.03, 0.03, 0.03, 0.03]), 8), Color("e8e8e8"))
	var strap := PackedVector3Array()
	for i in 7:
		var t := i / 6.0
		var sy := lerpf(1.27, 0.82, t)
		var sx := lerpf(-0.3, 0.46, t)
		var r := _coat_radius(sy) + 0.025
		strap.append(Vector3(sx, sy, sqrt(maxf(r * r - sx * sx, 0.0))))
	b.add(ToyBuilder.curve(strap, PackedFloat32Array([0.035, 0.035]), 8), SOLE)

	return b.build(0.012, "Torso")


func _build_head() -> MeshInstance3D:
	var b := ToyBuilder.new()

	b.part(ToyBuilder.sphere(0.34, 24), SKIN, Vector3(0, 0.36, 0))
	for side in [-1.0, 1.0]:
		b.part(ToyBuilder.sphere(1.0), SKIN, Vector3(0.33 * side, 0.38, 0), Vector3.ZERO, Vector3(0.045, 0.075, 0.06))
		b.part(ToyBuilder.sphere(1.0), CHEEK, Vector3(0.17 * side, 0.3, 0.27), Vector3.ZERO, Vector3(0.085, 0.07, 0.05))
		# Bushy eyebrows
		b.add(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.05 * side, 0.55, 0.31), Vector3(0.13 * side, 0.585, 0.295), Vector3(0.22 * side, 0.55, 0.25),
		]), PackedFloat32Array([0.028, 0.042, 0.022]), 8), FUR)
		# Curled moustache
		b.add(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.0, 0.3, 0.37), Vector3(0.1 * side, 0.285, 0.37), Vector3(0.2 * side, 0.3, 0.31), Vector3(0.26 * side, 0.36, 0.24),
		]), PackedFloat32Array([0.05, 0.055, 0.04, 0.022]), 10), FUR)
		# Spectacles: rims and arms
		b.part(ToyBuilder.torus(0.075, 0.011, 20, 6), GOLD, Vector3(0.12 * side, 0.44, 0.34), Vector3(90, 0, 0))
		b.add(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.195 * side, 0.45, 0.33), Vector3(0.29 * side, 0.46, 0.17), Vector3(0.33 * side, 0.43, 0.0),
		]), PackedFloat32Array([0.01, 0.01, 0.01]), 6), GOLD)
	b.add(ToyBuilder.curve(PackedVector3Array([
		Vector3(-0.047, 0.45, 0.352), Vector3(0, 0.465, 0.365), Vector3(0.047, 0.45, 0.352),
	]), PackedFloat32Array([0.01, 0.01, 0.01]), 6), GOLD)

	b.part(ToyBuilder.sphere(0.08), NOSE, Vector3(0, 0.36, 0.34))

	# Big cloud of a beard, plus hair around the back and sides
	b.part(ToyBuilder.sphere(1.0, 18), FUR, Vector3(0, 0.13, 0.1), Vector3.ZERO, Vector3(0.3, 0.24, 0.22))
	b.fluff_blob(Vector3(0, 0.1, 0.16), Vector3(0.27, 0.17, 0.14), 0.105, FUR, 30, 21)
	b.fluff_blob(Vector3(0, -0.06, 0.18), Vector3(0.16, 0.1, 0.09), 0.1, FUR, 12, 22)
	b.fluff_blob(Vector3(0, 0.32, -0.17), Vector3(0.3, 0.14, 0.14), 0.09, FUR, 16, 23)
	for side in [-1.0, 1.0]:
		b.fluff_blob(Vector3(0.29 * side, 0.26, 0.04), Vector3(0.05, 0.1, 0.08), 0.075, FUR, 6, 24)

	# Floppy hat with fur brim and pom-pom
	b.add(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0.58, 0), Vector3(0, 0.82, -0.03), Vector3(0.06, 1.0, -0.07),
		Vector3(0.2, 1.1, -0.1), Vector3(0.34, 1.05, -0.1), Vector3(0.4, 0.92, -0.08),
	]), PackedFloat32Array([0.33, 0.28, 0.2, 0.12, 0.07, 0.05]), 20), RED)
	b.fluff_ring(Vector3(0, 0.61, 0), 0.32, 0.085, FUR, 18, Vector3(-8, 0, 6), 25)
	b.part(ToyBuilder.sphere(0.085), FUR, Vector3(0.41, 0.86, -0.08))
	b.fluff_blob(Vector3(0.41, 0.86, -0.08), Vector3(0.05, 0.05, 0.05), 0.06, FUR, 8, 26)

	return b.build(0.01, "Head")


func _build_eyes() -> MeshInstance3D:
	var b := ToyBuilder.new()
	for side in [-1.0, 1.0]:
		b.part(ToyBuilder.sphere(1.0), EYE_WHITE, Vector3(0.12 * side, 0, 0.28), Vector3.ZERO, Vector3(0.065, 0.072, 0.04))
		b.part(ToyBuilder.sphere(1.0), PUPIL, Vector3(0.12 * side, -0.005, 0.31), Vector3.ZERO, Vector3(0.043, 0.048, 0.03))
		b.part(ToyBuilder.sphere(0.013), Color.WHITE, Vector3(0.105 * side, 0.015, 0.338), Vector3.ZERO, Vector3.ONE, true)
	return b.build(0.0, "Eyes")


func _make_arm(side: int) -> Node3D:
	var s := float(side)
	var pivot := Node3D.new()
	pivot.name = "ArmRight" if side > 0 else "ArmLeft"
	pivot.position = Vector3(0.4 * s, 1.2, 0)
	_body.add_child(pivot)

	var b := ToyBuilder.new()
	b.part(ToyBuilder.sphere(0.13), RED, Vector3.ZERO)
	b.add(ToyBuilder.curve(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0.1 * s, -0.22, 0.04), Vector3(0.16 * s, -0.45, 0.1),
	]), PackedFloat32Array([0.12, 0.11, 0.1]), 12), RED)
	b.fluff_ring(Vector3(0.16 * s, -0.47, 0.1), 0.1, 0.05, FUR, 11, Vector3(0, 0, -15 * s), 30 + side)
	b.part(ToyBuilder.sphere(1.0), MITTEN, Vector3(0.17 * s, -0.6, 0.12), Vector3.ZERO, Vector3(0.105, 0.12, 0.095))
	b.part(ToyBuilder.capsule(0.04, 0.14), MITTEN, Vector3(0.1 * s, -0.56, 0.18), Vector3(0, 0, 40 * s))
	pivot.add_child(b.build(0.012, "Arm"))
	return pivot


func _coat_radius(height: float) -> float:
	for i in range(1, COAT_PROFILE.size()):
		var lo: Vector2 = COAT_PROFILE[i - 1]
		var hi: Vector2 = COAT_PROFILE[i]
		if height <= hi.y:
			return lerpf(lo.x, hi.x, inverse_lerp(lo.y, hi.y, height))
	return 0.0
