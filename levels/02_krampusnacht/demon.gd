class_name Demon
extends CharacterBody3D
## One of Krampus's helpers: a hunched, shaggy little demon with stubby horns
## and ember eyes (a stand-in built from code until the cast comes from
## Meshy). Some lie in wait and pounce on Santa; others carry an elf in a
## sack towards the bridge. Knock a carrier and he drops the sack and turns
## to fight. They swipe with their claws after a short wind-up, which a
## parry turns aside, leaving the demon dazed.

## Claws out: the level decides whether they land (Santa may be parrying).
signal swiped(demon: Demon)
## Picked sack `sack_index` up and set off for the bridge.
signal took_sack(demon: Demon, sack_index: int)
## Knocked down while carrying sack `sack_index` (or beaten before he cut it down).
signal dropped_sack(demon: Demon, sack_index: int)
## Carried sack `sack_index` over the bridge.
signal escaped(demon: Demon, sack_index: int)
signal beaten(demon: Demon)

enum Mode {WAIT, FETCH, CARRY, LURK, FIGHT, WINDUP, DAZED, GONE}

const HEALTH := 4.0
const REACH := 1.65
const STOP_AT := 1.25
const WINDUP := 0.6
const COOLDOWN := Vector2(1.3, 2.2)
const POUNCE_RANGE := 9.0

var mode := Mode.LURK
var santa: Node3D
## Sack to carry, and how long to wait before cutting it down.
var sack: ElfSack
var delay := 0.0
var route := PackedVector3Array()
var carry_speed := 1.9
var chase_speed := 3.1
## Above 1 is gentler (Cocoa Mode): slower wind-ups.
var gentleness := 1.0

var _health := HEALTH
var _route_i := 0
var _timer := 0.0
var _cooldown := 0.0
var _visual: Node3D
var _body: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eyes: MeshInstance3D
var _carry: Node3D
var _hurt: Area3D
var _time := randf() * 10.0
var _knock := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Demon"
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.WALKER_BOUNDS
	collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	shape.shape = capsule
	# Floats just clear of the ground, so lips like the bridge deck don't snag it.
	shape.position.y = 0.75
	add_child(shape)
	add_to_group("demons")
	_rng.randomize()


func _ready() -> void:
	_build()
	_hurt = Area3D.new()
	_hurt.name = "Hurtbox"
	_hurt.collision_layer = PhysicsLayers.HURTBOX
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.4
	shape.shape = capsule
	shape.position.y = 0.7
	_hurt.add_child(shape)
	add_child(_hurt)
	_cooldown = _rng.randf_range(0.3, 1.0)


## Makes this demon fetch `the_sack` after `wait` seconds and carry it along `way`.
func fetch(the_sack: ElfSack, wait: float, way: PackedVector3Array) -> void:
	sack = the_sack
	delay = wait
	route = way
	mode = Mode.WAIT


func is_gone() -> bool:
	return mode == Mode.GONE


func is_winding_up() -> bool:
	return mode == Mode.WINDUP


func take_hit(hit: Dictionary) -> void:
	if mode == Mode.GONE:
		return
	_health -= float(hit.get("damage", 1.0))
	var push: Vector3 = hit.get("direction", Vector3.ZERO)
	_knock = Vector3(push.x, 0, push.z).normalized() * float(hit.get("force", 5.0)) * 0.9
	Audio.play_sfx("click", 0.55, -2.0)
	_flinch()
	# A sack he has hold of drops now; one still hanging, when he goes down.
	if sack and (sack.state != ElfSack.State.HANGING or _health <= 0.0):
		var dropped := sack
		sack = null
		dropped_sack.emit(self, dropped.index)
	if _health <= 0.0:
		_poof()
		return
	mode = Mode.DAZED
	_timer = 0.55


## Santa's guard met his claws: he reels, dazed.
func parried() -> void:
	if mode == Mode.GONE:
		return
	mode = Mode.DAZED
	_timer = 1.3
	_knock = (global_position - santa.global_position).normalized() * 4.0 if santa else Vector3.ZERO
	_flinch()


func _physics_process(delta: float) -> void:
	if mode == Mode.GONE:
		return
	_time += delta
	_cooldown -= delta
	var goal := Vector3.INF
	var speed := 0.0
	match mode:
		Mode.WAIT:
			_face(santa.global_position if santa else global_position + Vector3.BACK)
			delay -= delta
			if delay <= 0.0 and sack:
				mode = Mode.FETCH
				_timer = 0.7
				sack.cut_down()
			elif santa and _flat(santa.global_position).distance_to(_flat(global_position)) < 2.6:
				# Caught at it before he cut the sack down: he fights, and the
				# sack drops when he goes down.
				mode = Mode.FIGHT
		Mode.FETCH:
			_timer -= delta
			if _timer <= 0.0 and sack:
				if sack.state == ElfSack.State.GROUND:
					sack.carry_on(_carry)
					mode = Mode.CARRY
					_route_i = 1
					took_sack.emit(self, sack.index)
				elif sack.state != ElfSack.State.FALLING:
					mode = Mode.FIGHT
		Mode.CARRY:
			if _route_i >= route.size():
				var lost := sack
				sack = null
				mode = Mode.GONE
				escaped.emit(self, lost.index if lost else -1)
				queue_free()
				return
			goal = route[_route_i]
			speed = carry_speed
			if _flat(goal).distance_to(_flat(global_position)) < 0.6:
				_route_i += 1
		Mode.LURK:
			if santa and _flat(santa.global_position).distance_to(_flat(global_position)) < POUNCE_RANGE:
				mode = Mode.FIGHT
		Mode.FIGHT:
			if santa:
				var gap := _flat(santa.global_position).distance_to(_flat(global_position))
				_face(santa.global_position)
				if gap > STOP_AT:
					goal = santa.global_position
					speed = chase_speed
				if gap < REACH and _cooldown <= 0.0:
					mode = Mode.WINDUP
					_timer = WINDUP * gentleness
		Mode.WINDUP:
			if santa:
				_face(santa.global_position)
			_timer -= delta
			if _timer <= 0.0:
				mode = Mode.FIGHT
				_cooldown = _rng.randf_range(COOLDOWN.x, COOLDOWN.y)
				_lunge()
				swiped.emit(self)
		Mode.DAZED:
			_timer -= delta
			if _timer <= 0.0:
				mode = Mode.FIGHT
	var move := Vector3.ZERO
	if goal.is_finite():
		var to := _flat(goal) - _flat(global_position)
		if to.length() > 0.05:
			move = Vector3(to.x, 0, to.y).normalized() * speed
			if mode == Mode.CARRY:
				_face(goal)
	move += _separation() * 1.5
	velocity = move + _knock
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-delta * 7.0))
	move_and_slide()
	global_position.y = 0.0
	_animate(move.length(), delta)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group("demons"):
		if other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var d := away.length()
		if d < 1.2 and d > 0.01:
			push += away / d * (1.2 - d)
	return push


func _face(at: Vector3) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.25)


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# --- Looks ---

func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)
	var b := ToyBuilder.new()
	var fur := Color("3a2620")
	var dark := Color("1c1210")
	var horn := Color("cdbb98")
	# A hunched, shaggy body.
	b.finished(ToyBuilder.lumpy(ToyBuilder.capsule(0.3, 0.85, 12), 0.06, 5.0, 11), fur, "fur",
			ToyBuilder.xf(Vector3(0, 0.78, 0.04), Vector3(22, 0, 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 70:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.5, 1.1)
		var root := Vector3(cos(a) * 0.27, y, sin(a) * 0.25 + 0.04)
		var tip := root + Vector3(cos(a) * 0.08, -rng.randf_range(0.12, 0.22), sin(a) * 0.06)
		b.strand(PackedVector3Array([root, root.lerp(tip, 0.5) + Vector3(cos(a), 0, sin(a)) * 0.03, tip]), 0.03, 0.004,
				fur, fur.lightened(0.15), "fur", 4, Vector3(0, 0.8, 0.04))
	# Head: a snouty face, ember eyes, pointed ears, stubby curved horns.
	b.finished(ToyBuilder.sphere(0.2, 12), dark, "skin", ToyBuilder.xf(Vector3(0, 1.22, 0.2), Vector3.ZERO, Vector3(0.95, 0.9, 1.05)))
	b.finished(ToyBuilder.sphere(0.1, 10), dark.lightened(0.08), "skin", ToyBuilder.xf(Vector3(0, 1.15, 0.36), Vector3.ZERO, Vector3(1.0, 0.75, 1.0)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.cylinder(0.0, 0.05, 0.16, 5), dark, "skin",
				ToyBuilder.xf(Vector3(side * 0.18, 1.27, 0.16), Vector3(0, 0, -side * 70)))
		b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(side * 0.09, 1.36, 0.16), Vector3(side * 0.14, 1.48, 0.1),
				Vector3(side * 0.13, 1.56, 0.0)]), PackedFloat32Array([0.04, 0.025, 0.006]), 6, 4), horn, "leather")
		b.finished(ToyBuilder.cylinder(0.0, 0.012, 0.05, 4), Color("e8e0cc"), "leather",
				ToyBuilder.xf(Vector3(side * 0.04, 1.08, 0.42), Vector3(180, 0, 0)))
	# A thin tail ending in a tuft.
	b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 0.5, -0.25), Vector3(0, 0.35, -0.5), Vector3(0.1, 0.45, -0.75),
			Vector3(0.12, 0.65, -0.82)]), PackedFloat32Array([0.035, 0.025, 0.018, 0.012]), 6, 5), fur, "fur")
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.06, 8), 0.02, 6.0, 3), dark, "fur", ToyBuilder.xf(Vector3(0.12, 0.68, -0.83)))
	_body.add_child(b.build(0.0, "Figure"))
	var eyes := ToyBuilder.new()
	for side: float in [-1.0, 1.0]:
		eyes.add(ToyBuilder.sphere(0.03, 8), Color(1.0, 0.55, 0.12), ToyBuilder.xf(Vector3(side * 0.08, 1.27, 0.37)), true)
	_eyes = eyes.build(0.0, "Eyes")
	_body.add_child(_eyes)
	# Arms with claws, and goat legs, each on a pivot so they can swing.
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.27, 1.02, 0.12)
		_body.add_child(arm)
		var ab := ToyBuilder.new()
		ab.finished(ToyBuilder.tube(PackedVector3Array([Vector3.ZERO, Vector3(side * 0.08, -0.25, 0.08), Vector3(side * 0.06, -0.48, 0.16)]),
				PackedFloat32Array([0.07, 0.055, 0.045]), 6), fur, "fur")
		for k in 3:
			ab.finished(ToyBuilder.cylinder(0.0, 0.015, 0.1, 4), horn, "leather",
					ToyBuilder.xf(Vector3(side * 0.06 + (k - 1) * 0.03, -0.55, 0.2), Vector3(160, 0, 0)))
		arm.add_child(ab.build(0.0, "Arm"))
		_arms.append(arm)
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.14, 0.5, 0.0)
		_visual.add_child(leg)
		var lb := ToyBuilder.new()
		lb.finished(ToyBuilder.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, -0.2, 0.12), Vector3(0, -0.38, -0.06), Vector3(0, -0.5, 0.02)]),
				PackedFloat32Array([0.09, 0.07, 0.05, 0.045]), 6), fur, "fur")
		lb.finished(ToyBuilder.cylinder(0.05, 0.06, 0.06, 6), dark, "leather", ToyBuilder.xf(Vector3(0, -0.5, 0.03)))
		leg.add_child(lb.build(0.0, "Leg"))
		_legs.append(leg)
	_carry = Node3D.new()
	_carry.name = "Carry"
	_carry.position = Vector3(0.12, 0.85, -0.38)
	_body.add_child(_carry)


func _animate(speed: float, delta: float) -> void:
	var stride := sin(_time * (5.0 + speed * 3.0))
	var moving := clampf(speed / 2.0, 0.0, 1.0)
	_body.position.y = absf(stride) * 0.05 * moving + sin(_time * 2.0) * 0.015
	for k in _legs.size():
		_legs[k].rotation.x = stride * 0.6 * moving * (1.0 if k == 0 else -1.0)
	var raise := 0.0
	match mode:
		Mode.WINDUP:
			raise = -2.4
		Mode.CARRY, Mode.FETCH:
			raise = -1.6
	for k in _arms.size():
		var swing := -stride * 0.5 * moving * (1.0 if k == 0 else -1.0)
		var target := raise if raise != 0.0 and (mode == Mode.WINDUP or k == 0) else swing
		_arms[k].rotation.x = lerpf(_arms[k].rotation.x, target, 1.0 - exp(-delta * 14.0))
	var glow := 1.8 if mode == Mode.WINDUP else 1.0
	_eyes.scale = _eyes.scale.lerp(Vector3.ONE * glow, 1.0 - exp(-delta * 12.0))
	_body.rotation.x = lerpf(_body.rotation.x, 0.25 if mode == Mode.CARRY else 0.0, 1.0 - exp(-delta * 6.0))


func _flinch() -> void:
	var t := create_tween()
	t.tween_property(_visual, "rotation:x", -0.5, 0.08)
	t.tween_property(_visual, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC)


func _lunge() -> void:
	var t := create_tween()
	t.tween_property(_body, "position:z", 0.35, 0.08)
	t.tween_property(_body, "position:z", 0.0, 0.25)
	for arm in _arms:
		arm.rotation.x = 0.6


## Sent packing (Krampus calls his helpers off): gone in a puff of soot.
func banish() -> void:
	if mode != Mode.GONE:
		_poof(false)


## Vanishes in a puff of soot.
func _poof(counted := true) -> void:
	mode = Mode.GONE
	_hurt.queue_free()
	collision_layer = 0
	if counted:
		beaten.emit(self)
	var puff := CPUParticles3D.new()
	puff.amount = 18
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.lifetime = 0.9
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.5
	puff.gravity = Vector3(0, 0.5, 0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = WinterProps.soft_dot()
	mat.albedo_color = Color(0.12, 0.1, 0.1, 0.7)
	quad.material = mat
	puff.mesh = quad
	puff.position = Vector3(0, 0.8, 0)
	add_child(puff)
	puff.emitting = true
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector3(1.3, 0.05, 1.3), 0.25)
	t.tween_interval(1.0)
	t.tween_callback(queue_free)
