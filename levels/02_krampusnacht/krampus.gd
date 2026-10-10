class_name Krampus
extends CharacterBody3D
## Krampus as he fights in the church square: a towering, hunched goat-demon
## with great ridged horns, shaggy black fur, a long red tongue, cowbells on
## his belt, a bundle of birch rods in one fist and a chain in the other.
## (A stand-in built from code until his Meshy model is rigged.)
##
## The level moves him and plays his moves: winding the chain up, lashing it,
## holding it taut when Santa catches it, being slammed down and getting up.

## A blow landed on him: the level decides what it does.
signal struck(hit: Dictionary)

const HEIGHT := 2.6
const HAND := Vector3(0.62, 1.05, 0.35)

var _visual: Node3D
var _body: Node3D
var _arm: Node3D
var _chain: MeshInstance3D
var _eyes: MeshInstance3D
var _aura: CPUParticles3D
var _glow: OmniLight3D
var _bells: Node3D
var _time := 0.0
var _down := false
var _holding := false
var _lashing: Tween
var _hurt: Area3D


func _init() -> void:
	name = "Krampus"
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.WALKER_BOUNDS
	collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	add_child(shape)


func _ready() -> void:
	_build()
	_hurt = Area3D.new()
	_hurt.name = "Hurtbox"
	_hurt.collision_layer = PhysicsLayers.HURTBOX
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.75
	capsule.height = 2.6
	shape.shape = capsule
	shape.position.y = 1.3
	_hurt.add_child(shape)
	add_child(_hurt)
	set_dark(true)


func take_hit(hit: Dictionary) -> void:
	struck.emit(hit)


## Turns to face `at` (flat), smoothly unless `instant`.
func face(at: Vector3, instant := false) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() < 0.05 or _down:
		return
	var yaw := atan2(to.x, to.z)
	rotation.y = yaw if instant else lerp_angle(rotation.y, yaw, 0.12)


## Strides towards `at` at `speed`, sliding round anything in the way.
func stride_to(at: Vector3, speed: float) -> void:
	var to := Vector3(at.x - global_position.x, 0, at.z - global_position.z)
	velocity = to.normalized() * speed if to.length() > 0.1 else Vector3.ZERO
	move_and_slide()
	global_position.y = 0.0


## Where the chain leaves his fist, in the world.
func hand_position() -> Vector3:
	return _arm.global_transform * Vector3(0.0, -0.75, 0.15)


# --- His moves ---

## Draws the chain back over his shoulder, eyes blazing, for `seconds`.
func wind_up(seconds: float) -> void:
	_release()
	var t := create_tween()
	t.tween_property(_arm, "rotation", Vector3(-2.6, 0.0, -0.5), seconds * 0.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_eyes, "scale", Vector3.ONE * 2.2, seconds * 0.8)
	t.parallel().tween_property(_glow, "light_energy", 3.0, seconds * 0.8)
	_show_chain(1.3, Vector3(0, -1, -0.3))
	Audio.play_sfx("ring", 0.35, -10.0)


## Lashes the chain out at `target`.
func lash(target: Vector3) -> void:
	if _lashing and _lashing.is_valid():
		_lashing.kill()
	var from := hand_position()
	var reach := clampf(from.distance_to(target + Vector3.UP), 1.0, 6.5)
	_lashing = create_tween()
	_lashing.tween_property(_arm, "rotation", Vector3(0.9, 0.0, 0.0), 0.09)
	_lashing.parallel().tween_method(func(f: float) -> void: _aim_chain(target + Vector3.UP, reach * f), 0.2, 1.0, 0.09)
	_lashing.tween_interval(0.12)
	_lashing.tween_method(func(f: float) -> void: _aim_chain(target + Vector3.UP, reach * f), 1.0, 0.2, 0.25)
	_lashing.tween_callback(_release)
	_lashing.parallel().tween_property(_eyes, "scale", Vector3.ONE, 0.3)
	_lashing.parallel().tween_property(_glow, "light_energy", 1.0, 0.3)
	Audio.play_sfx("click", 0.4, 2.0)


## The chain held taut between his fist and `to` (call every frame).
func hold_chain(to: Vector3) -> void:
	if _lashing and _lashing.is_valid():
		_lashing.kill()
	_holding = true
	_arm.rotation = _arm.rotation.lerp(Vector3(0.7, 0.0, 0.0), 0.3)
	_aim_chain(to, hand_position().distance_to(to))


## Lets go of a held chain.
func let_go() -> void:
	if _holding:
		_holding = false
		_release()


## Yanked off his feet by his own chain and slammed onto the cobbles,
## pulled towards `toward`.
func slammed(toward: Vector3) -> void:
	_holding = false
	_down = true
	_release()
	var flat := Vector3(toward.x - global_position.x, 0, toward.z - global_position.z).normalized()
	rotation.y = atan2(flat.x, flat.z)
	var t := create_tween()
	t.tween_property(_visual, "position", Vector3(0, 2.2, 0.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_visual, "rotation:x", -1.2, 0.25)
	t.tween_property(_visual, "position", Vector3(0, 0.35, 1.4), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_visual, "rotation:x", -PI / 2.0, 0.18)
	t.tween_callback(func() -> void: Audio.play_sfx("click", 0.25, 6.0))
	_ring_bells()


## Back on his hooves.
func get_up() -> void:
	var t := create_tween()
	t.tween_property(_visual, "position", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(_visual, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_BACK)
	t.tween_callback(func() -> void: _down = false)


## Shrugs a punch off, and in the dark visibly drinks it in.
func shrug(dark: bool) -> void:
	var t := create_tween()
	t.tween_property(_body, "rotation:x", -0.15, 0.08)
	t.tween_property(_body, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC)
	if dark:
		var flare := create_tween()
		flare.tween_property(_glow, "light_energy", 4.0, 0.1)
		flare.tween_property(_glow, "light_energy", 1.0, 0.6)
		_aura.restart()


## Catches Santa's fist and shoves him off.
func shove() -> void:
	var t := create_tween()
	t.tween_property(_body, "position:z", 0.5, 0.1)
	t.tween_property(_body, "position:z", 0.0, 0.35)
	_ring_bells()


## A howl, head thrown back.
func howl() -> void:
	var t := create_tween()
	t.tween_property(_body, "rotation:x", -0.45, 0.3)
	t.tween_interval(0.6)
	t.tween_property(_body, "rotation:x", 0.0, 0.5)


## In the dark he is cloaked in drifting shadow and his eyes burn red; in the
## light the shadow burns off.
func set_dark(on: bool) -> void:
	_aura.emitting = on
	_glow.light_color = Color(1.0, 0.25, 0.1) if on else Color(1.0, 0.6, 0.35)


## Leaps in an arc to `to` over `seconds`.
func leap_to(to: Vector3, seconds := 0.9) -> Tween:
	var from := global_position
	var t := create_tween()
	t.tween_method(func(f: float) -> void:
		global_position = from.lerp(to, f) + Vector3.UP * sin(f * PI) * 3.0, 0.0, 1.0, seconds)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void:
		var squash := create_tween()
		squash.tween_property(_visual, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
		squash.tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		_ring_bells())
	return t


func _process(delta: float) -> void:
	_time += delta
	if not _down:
		# Heavy breathing, a slow sway.
		_body.position.y = sin(_time * 1.8) * 0.03
		_body.rotation.z = sin(_time * 0.9) * 0.03
	_bells.rotation.z = sin(_time * 7.0) * 0.08 * clampf(velocity.length() / 2.0, 0.2, 1.0)


func _release() -> void:
	_holding = false
	var t := create_tween()
	t.tween_property(_arm, "rotation", Vector3(0.15, 0.0, 0.0), 0.35)
	_show_chain(1.3, Vector3(0, -1, 0.1))


## Shows the chain hanging from his fist along `direction` (in his space).
func _show_chain(length: float, direction: Vector3) -> void:
	var from := hand_position()
	var to := from + global_transform.basis * direction.normalized() * length
	_aim_chain(to, length)


func _aim_chain(at: Vector3, length: float) -> void:
	var from := hand_position()
	var dir := at - from
	if dir.length() < 0.01:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	_chain.global_transform = Transform3D(Basis.looking_at(dir, up, true), from)
	_chain.scale = Vector3(1, 1, maxf(length, 0.05))


func _ring_bells() -> void:
	Audio.play_sfx("bell", 0.6, -12.0)


func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)
	var b := ToyBuilder.new()
	var fur := Color("1d1614")
	var face := Color("2c1f1b")
	var horn := Color("cbb995")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1620
	# Goat legs: thigh forward, hock back, hooves.
	for side: float in [-1.0, 1.0]:
		var points := PackedVector3Array([Vector3(side * 0.24, 1.12, 0.0), Vector3(side * 0.28, 0.7, 0.24),
				Vector3(side * 0.25, 0.36, -0.16), Vector3(side * 0.22, 0.08, 0.04)])
		b.finished(ToyBuilder.tube(points, PackedFloat32Array([0.2, 0.15, 0.1, 0.075]), 8), fur, "fur")
		b.finished(ToyBuilder.cylinder(0.07, 0.1, 0.12, 8), Color("15100e"), "leather", ToyBuilder.xf(Vector3(side * 0.22, 0.06, 0.07)))
		b.finished(ToyBuilder.box(Vector3(0.02, 0.1, 0.1)), Color("0c0908"), "leather", ToyBuilder.xf(Vector3(side * 0.22, 0.06, 0.15)))
	# A massive hunched torso.
	b.finished(ToyBuilder.lumpy(ToyBuilder.capsule(0.48, 1.35, 14), 0.08, 4.0, 5), fur, "fur",
			ToyBuilder.xf(Vector3(0, 1.62, 0.12), Vector3(24, 0, 0), Vector3(1.1, 1.0, 0.9)))
	# Shaggy hair hanging all over him.
	for k in 420:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.95, 2.2)
		var r := 0.45 + 0.1 * sin(y * 2.5)
		var root := Vector3(cos(a) * r * 1.05, y, sin(a) * r * 0.9 + 0.12 + (y - 1.6) * 0.42)
		var hang := rng.randf_range(0.18, 0.42)
		var tip := root + Vector3(cos(a) * 0.08, -hang, sin(a) * 0.06)
		b.strand(PackedVector3Array([root, root.lerp(tip, 0.5) + Vector3(cos(a), 0, sin(a)) * 0.05, tip]), 0.045, 0.005,
				fur, fur.lightened(0.12), "fur", 4, Vector3(0, 1.6, 0.12))
	# A belt of iron chain and a row of cowbells.
	b.finished(ToyBuilder.torus(0.5, 0.04, 24, 6), Color("3a3a3e"), "metal", ToyBuilder.xf(Vector3(0, 1.12, 0.04), Vector3(8, 0, 0), Vector3(1.05, 1, 0.92)))
	# The left arm, its fist full of birch rods.
	b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(-0.58, 2.05, 0.3), Vector3(-0.72, 1.6, 0.42), Vector3(-0.66, 1.15, 0.58)]),
			PackedFloat32Array([0.15, 0.12, 0.1]), 8), fur, "fur")
	b.finished(ToyBuilder.sphere(0.12, 10), face, "skin", ToyBuilder.xf(Vector3(-0.66, 1.08, 0.62)))
	for k in 11:
		var spread := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
		b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(-0.66, 0.85, 0.66) + spread * 0.3, Vector3(-0.66, 1.4, 0.6) + spread,
				Vector3(-0.64, 1.75, 0.55) + spread * 1.6]), PackedFloat32Array([0.012, 0.009, 0.004]), 4), Color("6b4a33"), "leather")
	b.finished(ToyBuilder.torus(0.05, 0.018, 10, 5), Color("a51f24"), "velvet", ToyBuilder.xf(Vector3(-0.66, 1.2, 0.63)))
	# Head: long goat skull, dark face, beard, burning eyes, teeth, tongue.
	var head := Vector3(0, 2.35, 0.62)
	b.finished(ToyBuilder.sphere(0.24, 14), face, "skin", ToyBuilder.xf(head, Vector3(20, 0, 0), Vector3(0.9, 0.95, 1.25)))
	b.finished(ToyBuilder.sphere(0.13, 12), face, "skin", ToyBuilder.xf(head + Vector3(0, -0.12, 0.26), Vector3(30, 0, 0), Vector3(1.0, 0.8, 1.3)))
	b.finished(ToyBuilder.sphere(0.04, 8), Color("120c0a"), "skin", ToyBuilder.xf(head + Vector3(0, -0.1, 0.42)))
	for k in 60:
		var a := rng.randf_range(-1.2, 1.2)
		var root := head + Vector3(sin(a) * 0.12, -0.2, 0.2 + cos(a) * 0.08)
		b.strand(PackedVector3Array([root, root + Vector3(sin(a) * 0.03, -0.18, 0.02), root + Vector3(sin(a) * 0.05, -0.38, -0.02)]),
				0.025, 0.004, fur, fur.lightened(0.2), "fur", 4, head)
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.cylinder(0.0, 0.016, 0.07, 4), Color("e8e0cc"), "leather",
				ToyBuilder.xf(head + Vector3(side * 0.06, -0.22, 0.34), Vector3(180, 0, 0)))
		# Long drooping ears.
		b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.12, 8), 0.02, 4.0, 2), face, "skin",
				ToyBuilder.xf(head + Vector3(side * 0.28, 0.0, -0.04), Vector3(0, 0, side * 60), Vector3(0.35, 1.0, 0.18)))
		# Great ridged horns, sweeping up, back and out.
		var horn_points := PackedVector3Array([head + Vector3(side * 0.12, 0.16, -0.02), head + Vector3(side * 0.28, 0.48, -0.22),
				head + Vector3(side * 0.42, 0.72, -0.5), head + Vector3(side * 0.6, 0.78, -0.82), head + Vector3(side * 0.78, 0.6, -1.0)])
		b.finished(ToyBuilder.curve(horn_points, PackedFloat32Array([0.09, 0.075, 0.055, 0.035, 0.008]), 10, 8), horn, "leather")
		var smooth := ToyBuilder.smooth_path(horn_points, 4)
		for k in range(1, smooth.size() - 3, 2):
			var at := smooth[k]
			var along := (smooth[k + 1] - smooth[k - 1]).normalized()
			b.finished(ToyBuilder.torus(0.085 * (1.0 - float(k) / smooth.size()) + 0.015, 0.012, 12, 4), horn.darkened(0.15), "leather",
					Transform3D(Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2.0), at))
	b.finished(ToyBuilder.curve(PackedVector3Array([head + Vector3(0, -0.2, 0.36), head + Vector3(0.02, -0.38, 0.42),
			head + Vector3(0.05, -0.6, 0.36), head + Vector3(0.04, -0.75, 0.3)]), PackedFloat32Array([0.045, 0.04, 0.032, 0.01]), 8, 5),
			Color("b3202c"), "skin")
	_body.add_child(b.build(0.0, "Figure"))
	var eyes := ToyBuilder.new()
	for side: float in [-1.0, 1.0]:
		eyes.add(ToyBuilder.sphere(0.035, 8), Color(1.0, 0.3, 0.08), ToyBuilder.xf(head + Vector3(side * 0.11, 0.06, 0.2)), true)
	_eyes = eyes.build(0.0, "Eyes")
	_body.add_child(_eyes)
	# Cowbells, on their own node so they can swing.
	_bells = Node3D.new()
	_bells.position = Vector3(0, 1.08, 0.12)
	_body.add_child(_bells)
	var bb := ToyBuilder.new()
	var bell := ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.065, 0.1),
			Vector2(0.045, 0.16), Vector2(0.0, 0.17)]), 10)
	for k in 5:
		var a := lerpf(-1.1, 1.1, k / 4.0)
		bb.finished(bell, Color("8a6d3b"), "metal", ToyBuilder.xf(Vector3(sin(a) * 0.52, -0.22, cos(a) * 0.46), Vector3(0, rad_to_deg(a), 0),
				Vector3(1.0, 1.0, 0.7)))
	_bells.add_child(bb.build(0.0, "Cowbells"))
	# The right arm on a shoulder pivot, swinging the chain.
	_arm = Node3D.new()
	_arm.name = "WhipArm"
	_arm.position = Vector3(0.6, 2.05, 0.3)
	_body.add_child(_arm)
	var ab := ToyBuilder.new()
	ab.finished(ToyBuilder.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.1, -0.4, 0.08), Vector3(0.04, -0.7, 0.15)]),
			PackedFloat32Array([0.15, 0.12, 0.1]), 8), fur, "fur")
	ab.finished(ToyBuilder.sphere(0.12, 10), face, "skin", ToyBuilder.xf(Vector3(0.02, -0.76, 0.16)))
	for k in 4:
		ab.finished(ToyBuilder.cylinder(0.0, 0.018, 0.12, 4), horn, "leather",
				ToyBuilder.xf(Vector3(-0.04 + k * 0.035, -0.86, 0.22), Vector3(150, 0, 0)))
	_arm.add_child(ab.build(0.0, "Arm"))
	_arm.rotation.x = 0.15
	# The chain: a metre of links along +z, stretched to length.
	_chain = MeshInstance3D.new()
	_chain.name = "Chain"
	_chain.top_level = true
	var cb := ToyBuilder.new()
	for k in 16:
		cb.finished(ToyBuilder.torus(0.028, 0.008, 10, 4), Color("4a4a50"), "metal",
				ToyBuilder.xf(Vector3(0, 0, (k + 0.5) / 16.0), Vector3(0, 0, 90 * (k % 2)), Vector3(1.0, 1.0, 0.75)))
	_chain.mesh = cb.build(0.0, "Links").mesh
	add_child(_chain)
	_glow = OmniLight3D.new()
	_glow.light_energy = 1.0
	_glow.omni_range = 4.5
	_glow.position = head + Vector3(0, 0, 0.6)
	_body.add_child(_glow)
	# Drifting shadow: dark wisps rising off him while the village is dark.
	_aura = CPUParticles3D.new()
	_aura.amount = 28
	_aura.lifetime = 1.6
	_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = 0.8
	_aura.direction = Vector3.UP
	_aura.spread = 25.0
	_aura.initial_velocity_min = 0.4
	_aura.initial_velocity_max = 0.9
	_aura.gravity = Vector3(0, 0.3, 0)
	_aura.scale_amount_min = 0.8
	_aura.scale_amount_max = 1.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = WinterProps.soft_dot()
	mat.albedo_color = Color(0.06, 0.02, 0.05, 0.55)
	quad.material = mat
	_aura.mesh = quad
	_aura.position = Vector3(0, 1.4, 0.1)
	_visual.add_child(_aura)
	_show_chain.call_deferred(1.3, Vector3(0, -1, 0.1))
