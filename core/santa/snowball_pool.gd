class_name SnowballPool
extends Node3D
## Thrown snowballs: a fixed handful, reused, flying on an arc and all drawn
## in one batch. Each one sweeps a ray along its path every physics step, so
## even a fast throw cannot pass through a thin target. Whatever it hits gets
## take_hit(hit) if it (or a parent) has one, and bursts into a puff of snow.

signal hit_landed(target: Node, at: Vector3)
## Any snowball bursting on anything (a thump someone might hear).
signal splashed(at: Vector3)

const RADIUS := 0.1
## Seconds a snowball flies before it is put back unused.
const LIFETIME := 3.0

var gravity := 9.0
var damage := 1.0
## What a snowball can hit.
var collision_mask := PhysicsLayers.WORLD | PhysicsLayers.HURTBOX
## Bodies a snowball passes through (the thrower).
var exclude: Array[RID] = []

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _throwers: Array[Node] = []
var _multimesh: MultiMesh
var _puffs: Array[CPUParticles3D] = []
var _next_puff := 0


func _init(size := 8) -> void:
	name = "Snowballs"
	top_level = true
	_positions.resize(size)
	_velocities.resize(size)
	_ages.resize(size)
	_ages.fill(-1.0)
	_throwers.resize(size)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = _ball_mesh()
	_multimesh.instance_count = size
	_multimesh.visible_instance_count = 0
	var balls := MultiMeshInstance3D.new()
	balls.name = "Balls"
	balls.multimesh = _multimesh
	balls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(balls)
	for i in 2:
		var puff := _make_puff()
		_puffs.append(puff)
		add_child(puff)


## Throws a snowball from `from` with `velocity`. Returns false if all are in the air.
func launch(from: Vector3, velocity: Vector3, thrower: Node = null) -> bool:
	for i in _ages.size():
		if _ages[i] < 0.0:
			_positions[i] = from
			_velocities[i] = velocity
			_ages[i] = 0.0
			_throwers[i] = thrower
			return true
	return false


## How many snowballs are in the air.
func in_flight() -> int:
	var count := 0
	for age in _ages:
		if age >= 0.0:
			count += 1
	return count


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in _ages.size():
		if _ages[i] < 0.0:
			continue
		_ages[i] += delta
		var from := _positions[i]
		_velocities[i] += Vector3.DOWN * gravity * delta
		var to := from + _velocities[i] * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, exclude)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			_strike(i, hit)
		elif _ages[i] > LIFETIME:
			_ages[i] = -1.0
		else:
			_positions[i] = to
	_draw()


func _strike(i: int, hit: Dictionary) -> void:
	var at: Vector3 = hit["position"]
	var receiver := hit_receiver(hit["collider"])
	if receiver:
		receiver.take_hit({"kind": "snowball", "damage": damage, "force": 3.0,
				"direction": _velocities[i].normalized(), "at": at, "by": _throwers[i]})
		hit_landed.emit(receiver, at)
	_ages[i] = -1.0
	_burst(at, hit["normal"])
	splashed.emit(at)


## The node that takes a hit on `collider`: the first of it and its parents
## with a take_hit method, or null.
static func hit_receiver(collider: Object) -> Node:
	var node := collider as Node
	while node != null:
		if node.has_method("take_hit"):
			return node
		node = node.get_parent()
	return null


func _draw() -> void:
	var shown := 0
	for i in _ages.size():
		if _ages[i] >= 0.0:
			_multimesh.set_instance_transform(shown, Transform3D(Basis.IDENTITY, _positions[i]))
			shown += 1
	_multimesh.visible_instance_count = shown


func _burst(at: Vector3, normal: Vector3) -> void:
	var puff := _puffs[_next_puff]
	_next_puff = (_next_puff + 1) % _puffs.size()
	puff.global_position = at
	puff.direction = normal
	puff.visible = true
	puff.restart()


static func _ball_mesh() -> Mesh:
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 10), 0.12, 3.0, 4), "snow_02",
			ToyBuilder.xf(Vector3.ZERO, Vector3.ZERO, Vector3.ONE * RADIUS), 0.5, WinterProps.SNOW_TINT)
	var built := b.build(0.0, "Ball")
	var mesh := built.mesh
	built.free()
	return mesh


func _make_puff() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.name = "Puff"
	puff.emitting = false
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 12
	puff.lifetime = 0.5
	puff.spread = 70.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.6
	puff.gravity = Vector3(0, -6, 0)
	puff.scale_amount_min = 0.05
	puff.scale_amount_max = 0.11
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	puff.color_ramp = fade
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = WinterProps.soft_dot()
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	quad.material = mat
	puff.mesh = quad
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.visible = false
	puff.finished.connect(func() -> void: puff.visible = false)
	return puff
