class_name YuleCat
extends Node3D
## The Yule Cat (a stand-in built from shapes until it comes from Meshy): a
## huge black cat with lamp-yellow eyes, as tall at the shoulder as Santa.
## It prowls the square on its round, sitting now and then to stare, and
## sees further than any Lad. It goes to look at thumps. For the chase the
## level moves it along Santa's trail (follow()); a snowball in the face
## stops it for a moment.

signal struck

enum Mode {PROWL, SIT, INVESTIGATE, POUNCE, PERCH, CHASE, BOLT, OFF}

const PROWL_SPEED := 1.7
const SIT_TIME := 5.0
const SIGHT_RANGE := 14.0
const HALF_ANGLE := 50.0
## It counts this much more than a Lad seeing Santa.
const KEEN := 2.2
const EYE := 1.75
const FUR := Color("16151b")

var mode := Mode.PROWL
var yaw := 0.0
var seeing := 0.0

var _route: PackedVector3Array
var _sits: Array
var _leg := 1
var _timer := 0.0
var _target := Vector3.ZERO
var _time := 0.0
var _pace := 0.0
var _stunned := 0.0
var _figure: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _eyes: MeshInstance3D


func _init(route: Array, sits: Array) -> void:
	name = "YuleCat"
	_route = PackedVector3Array(route)
	_sits = sits
	position = _route[0]
	var ahead := _route[1] - _route[0]
	yaw = atan2(ahead.x, ahead.z)
	_build()
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = PhysicsLayers.HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.8
	capsule.height = 3.2
	shape.shape = capsule
	shape.rotation_degrees.x = 90.0
	shape.position = Vector3(0, 1.2, 0.1)
	hurtbox.add_child(shape)
	add_child(hurtbox)


func eye_position() -> Vector3:
	return global_position + Vector3.UP * EYE + Vector3(sin(yaw), 0, cos(yaw)) * 1.4


## How clearly it sees Santa (already counted extra keen; 0 if not at all).
func watch(santa_pos: Vector3, sneaking: bool) -> float:
	seeing = 0.0
	if mode not in [Mode.PROWL, Mode.SIT, Mode.INVESTIGATE]:
		return 0.0
	var eye := eye_position()
	var target := santa_pos + Vector3.UP * (0.75 if sneaking else 1.25)
	var distance := eye.distance_to(target)
	if distance > SIGHT_RANGE:
		return 0.0
	var flat := Vector2(santa_pos.x - eye.x, santa_pos.z - eye.z)
	if flat.length() > 0.5 and absf(rad_to_deg(Vector2(sin(yaw), cos(yaw)).angle_to(flat))) > HALF_ANGLE:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(eye, target, PhysicsLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	seeing = StealthMeter.strength(distance, SIGHT_RANGE, sneaking) * KEEN
	return seeing


## A thump within earshot: it pads over to look. True if it heard.
func hear(at: Vector3, radius: float) -> bool:
	if mode not in [Mode.PROWL, Mode.SIT]:
		return false
	if Vector2(at.x - position.x, at.z - position.z).length() > radius * 1.3:
		return false
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP, Vector3(at.x, 1.0, at.z), PhysicsLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_target = Vector3(at.x, 0, at.z) if hit.is_empty() else Vector3((hit["position"] as Vector3).x, 0, (hit["position"] as Vector3).z)
	_target += (position - _target).normalized() * 1.6
	mode = Mode.INVESTIGATE
	_timer = 4.0
	return true


## Springs at `at` (Santa's been found).
func pounce(at: Vector3) -> void:
	mode = Mode.POUNCE
	var to := at - position
	yaw = atan2(to.x, to.z)
	rotation.y = yaw
	var land := at - Vector3(to.x, 0, to.z).normalized() * 1.2
	var t := create_tween()
	t.tween_property(_figure, "rotation:x", -0.35, 0.18)
	t.tween_property(self, "position", land, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_figure, "position:y", 1.6, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_figure, "position:y", 0.0, 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.22)
	t.tween_property(_figure, "rotation:x", 0.0, 0.2)


## Waits up on the clifftop for the chase.
func perch(at: Vector3, face: float) -> void:
	mode = Mode.PERCH
	position = at
	yaw = face
	rotation.y = yaw
	visible = true


## Leaps down from the perch to `at`; the chase takes over from there.
func leap_down(at: Vector3) -> void:
	var t := create_tween()
	var mid := (position + at) / 2.0 + Vector3.UP * 2.5
	t.tween_property(self, "position", mid, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", at, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: mode = Mode.CHASE)


## Put at `at` facing `heading` by the chase, moving at `speed`.
func follow(at: Vector3, heading: Vector3, speed: float) -> void:
	mode = Mode.CHASE
	position = at
	if heading.length() > 0.1:
		yaw = atan2(heading.x, heading.z)
	_pace = speed


## A snowball in the face: it flinches and shakes its head.
func stagger() -> void:
	_stunned = 0.7
	var t := create_tween()
	t.tween_property(_head, "rotation:z", 0.5, 0.08)
	t.tween_property(_head, "rotation:z", -0.4, 0.15)
	t.tween_property(_head, "rotation:z", 0.0, 0.2)


## Startled by sleigh bells: it bolts off up the valley.
func bolt(away: Vector3) -> void:
	mode = Mode.BOLT
	_target = away
	_pace = 9.0


func take_hit(_hit: Dictionary) -> void:
	struck.emit()


func _physics_process(delta: float) -> void:
	_time += delta
	_stunned = maxf(0.0, _stunned - delta)
	var speed := 0.0
	match mode:
		Mode.PROWL:
			speed = _walk_to(_route[_leg], delta, PROWL_SPEED)
			if speed == 0.0:
				if _leg in _sits:
					mode = Mode.SIT
					_timer = SIT_TIME
				_leg = (_leg + 1) % _route.size()
		Mode.SIT:
			_timer -= delta
			# Stares one way, then the other.
			yaw += sin(_time * 0.7) * 0.5 * delta
			if _timer <= 0.0:
				mode = Mode.PROWL
		Mode.INVESTIGATE:
			speed = _walk_to(_target, delta, PROWL_SPEED * 1.6)
			if speed == 0.0:
				_timer -= delta
				yaw += sin(_time * 1.3) * 0.6 * delta
				if _timer <= 0.0:
					mode = Mode.PROWL
		Mode.CHASE:
			speed = _pace if _stunned <= 0.0 else 0.0
		Mode.BOLT:
			speed = _walk_to(_target, delta, _pace, 0.5)
			if speed == 0.0:
				mode = Mode.OFF
				visible = false
	rotation.y = yaw
	_animate(delta, speed)


func _walk_to(goal: Vector3, delta: float, speed: float, stop := 0.15) -> float:
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	if to.length() <= stop:
		return 0.0
	var heading := atan2(to.x, to.z)
	var diff := angle_difference(yaw, heading)
	yaw += clampf(diff, -2.4 * delta, 2.4 * delta)
	if absf(diff) > 1.0:
		return 0.0001
	position += to.normalized() * minf(speed * delta, to.length())
	return speed


func _animate(delta: float, speed: float) -> void:
	var sitting := mode == Mode.SIT or mode == Mode.PERCH
	_body.rotation.x = lerpf(_body.rotation.x, -0.42 if sitting else 0.0, minf(1.0, delta * 4.0))
	_body.position.y = lerpf(_body.position.y, -0.25 if sitting else 0.0, minf(1.0, delta * 4.0))
	_head.rotation.x = lerpf(_head.rotation.x, 0.4 if sitting else 0.0, minf(1.0, delta * 4.0))
	if speed > 0.01 and _stunned <= 0.0:
		var gallop := speed > 3.0
		var rate := 5.0 + speed * (2.2 if gallop else 2.6)
		var phase := _time * rate
		for k in 4:
			var offset: float = [0.0, PI, PI * 0.5, PI * 1.5][k] if not gallop else [0.0, 0.3, PI, PI + 0.3][k]
			_legs[k].rotation.x = sin(phase + offset) * (0.75 if gallop else 0.45)
		_figure.position.y = absf(sin(phase)) * (0.12 if gallop else 0.03)
		_body.rotation.z = sin(phase * 0.5) * 0.03
	else:
		for k in 4:
			var tuck := 0.0
			if sitting and k >= 2:
				tuck = -1.2
			_legs[k].rotation.x = lerpf(_legs[k].rotation.x, tuck, minf(1.0, delta * 6.0))
	_tail.rotation.y = sin(_time * 1.3) * 0.5
	_tail.rotation.x = -0.3 + sin(_time * 0.9) * 0.15
	# The eyes narrow when it's seen something.
	_eyes.scale.y = lerpf(_eyes.scale.y, 0.45 if seeing > 0.0 else 1.0, minf(1.0, delta * 6.0))


func _build() -> void:
	_figure = Node3D.new()
	_figure.name = "Figure"
	add_child(_figure)
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3.ZERO
	_figure.add_child(_body)
	var b := ToyBuilder.new()
	# A long, deep chest and lean flanks, shaggy.
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 18), 0.07, 3.0, 7), FUR, "fur",
			ToyBuilder.xf(Vector3(0, 1.25, 0.0), Vector3.ZERO, Vector3(0.62, 0.6, 1.45)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 16), 0.08, 3.0, 9), FUR, "fur",
			ToyBuilder.xf(Vector3(0, 1.32, 0.9), Vector3(-15, 0, 0), Vector3(0.66, 0.72, 0.7)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 16), 0.08, 3.0, 11), FUR, "fur",
			ToyBuilder.xf(Vector3(0, 1.22, -0.9), Vector3.ZERO, Vector3(0.6, 0.62, 0.68)))
	# A ruff of longer fur round the neck.
	b.finished(ToyBuilder.lumpy(ToyBuilder.torus(0.5, 0.2, 18, 8), 0.25, 5.0, 3), FUR.lightened(0.04), "fur",
			ToyBuilder.xf(Vector3(0, 1.62, 1.35), Vector3(70, 0, 0), Vector3(1.0, 1.0, 1.1)))
	_body.add_child(b.build(0.0, "Torso"))
	# Legs: hips and shoulders, each swinging from the top.
	for spot: Vector3 in [Vector3(-0.38, 1.15, 1.0), Vector3(0.38, 1.15, 1.0), Vector3(-0.38, 1.1, -1.0), Vector3(0.38, 1.1, -1.0)]:
		var leg := Node3D.new()
		leg.position = spot
		_body.add_child(leg)
		var lb := ToyBuilder.new()
		var hind := spot.z < 0.0
		var knee := Vector3(0, -0.55, -0.12 if hind else 0.08)
		lb.finished(ToyBuilder.tube(PackedVector3Array([Vector3.ZERO, knee, Vector3(0, -1.05, 0.02)]),
				PackedFloat32Array([0.24 if hind else 0.2, 0.15, 0.12]), 10), FUR, "fur")
		lb.finished(ToyBuilder.sphere(0.17, 10), FUR, "fur", ToyBuilder.xf(Vector3(0, -1.06, 0.1), Vector3.ZERO, Vector3(1.0, 0.55, 1.3)))
		leg.add_child(lb.build(0.0, "Leg"))
		_legs.append(leg)
	# The head, low and forward on the neck.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.75, 1.65)
	_body.add_child(_head)
	var hb := ToyBuilder.new()
	hb.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.42, 16), 0.06, 5.0, 4), FUR, "fur", ToyBuilder.xf(Vector3(0, 0, 0.1), Vector3.ZERO, Vector3(1.1, 0.95, 1.0)))
	hb.finished(ToyBuilder.sphere(0.2, 12), FUR, "fur", ToyBuilder.xf(Vector3(0, -0.1, 0.45), Vector3.ZERO, Vector3(1.0, 0.75, 0.8)))
	hb.finished(ToyBuilder.sphere(0.05, 8), Color("2a2025"), "skin", ToyBuilder.xf(Vector3(0, -0.02, 0.6), Vector3.ZERO, Vector3(1.2, 0.8, 0.8)))
	for side: float in [-1.0, 1.0]:
		hb.finished(ToyBuilder.cylinder(0.0, 0.17, 0.36, 4), FUR, "fur",
				ToyBuilder.xf(Vector3(side * 0.24, 0.42, 0.0), Vector3(-10, 45, side * 18), Vector3(1.0, 1.0, 0.45)))
		hb.finished(ToyBuilder.cylinder(0.0, 0.1, 0.24, 4), Color("3b2c33"), "skin",
				ToyBuilder.xf(Vector3(side * 0.24, 0.4, 0.03), Vector3(-10, 45, side * 18), Vector3(1.0, 1.0, 0.3)))
		for k in 3:
			hb.add(ToyBuilder.cylinder(0.003, 0.004, 0.55, 3), Color("c8c8c0"),
					ToyBuilder.xf(Vector3(side * 0.32, -0.1 + k * 0.035, 0.47), Vector3(0, 0, side * (80 + k * 6))))
	_head.add_child(hb.build(0.0, "Skull"))
	var eb := ToyBuilder.new()
	for side: float in [-1.0, 1.0]:
		eb.add(ToyBuilder.sphere(0.075, 12), Color(1.0, 0.82, 0.2), ToyBuilder.xf(Vector3(side * 0.17, 0.08, 0.42), Vector3.ZERO, Vector3(1.2, 0.85, 0.5)), true)
		eb.add(ToyBuilder.sphere(0.03, 8), Color(0.02, 0.02, 0.02), ToyBuilder.xf(Vector3(side * 0.17, 0.08, 0.455), Vector3.ZERO, Vector3(0.45, 1.6, 0.4)))
	_eyes = eb.build(0.0, "Eyes")
	_head.add_child(_eyes)
	# The tail: long, bushy, curling up at the tip.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.4, -1.5)
	_body.add_child(_tail)
	var tb := ToyBuilder.new()
	tb.finished(ToyBuilder.lumpy(ToyBuilder.curve(PackedVector3Array([Vector3.ZERO, Vector3(0, -0.4, -0.6), Vector3(0.1, -0.5, -1.3),
			Vector3(0.25, -0.1, -1.9), Vector3(0.2, 0.35, -2.1)]), PackedFloat32Array([0.16, 0.15, 0.14, 0.13, 0.1]), 10, 6), 0.05, 6.0, 2),
			FUR, "fur")
	_tail.add_child(tb.build(0.0, "Tail"))
