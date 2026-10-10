extends Node3D
## Snowmen to punch and pelt. A hit sets one wobbling on its base; enough hits
## burst it into lumps of snow, and a few seconds later it builds itself up
## again. All of them are drawn in one batch (a MultiMesh), so a crowd costs
## no more draw calls than one.

signal broken(index: int)

const HEALTH := 3.0
const REBUILD_SECONDS := 4.0
## How springy the wobble is, and how fast it dies away.
const STIFFNESS := 38.0
const DAMPING := 3.2
const MAX_TILT := 0.45

var _spots: Array[Transform3D] = []
var _health := PackedFloat32Array()
var _tilt := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _axes := PackedVector3Array()
## Seconds since it burst, or below 0 while standing.
var _down := PackedFloat32Array()
var _bodies: Array[StaticBody3D] = []
var _multimesh: MultiMesh
var _burst: CPUParticles3D


## Snowmen standing at `spots` (positions and turns on the ground).
func _init(spots: Array[Transform3D]) -> void:
	name = "SnowmanTargets"
	_spots = spots
	var count := spots.size()
	_health.resize(count)
	_health.fill(HEALTH)
	_tilt.resize(count)
	_spin.resize(count)
	_axes.resize(count)
	_axes.fill(Vector3.RIGHT)
	_down.resize(count)
	_down.fill(-1.0)
	var model := WinterProps.snowman(3)
	var mesh: Mesh = (model.get_node("Mesh") as MeshInstance3D).mesh
	model.free()
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = mesh
	_multimesh.instance_count = count
	var drawn := MultiMeshInstance3D.new()
	drawn.name = "Snowmen"
	drawn.multimesh = _multimesh
	add_child(drawn)
	for i in count:
		_multimesh.set_instance_transform(i, spots[i])
		var body := _Snowman.new()
		body.index = i
		body.targets = self
		body.transform = spots[i]
		add_child(body)
		_bodies.append(body)
	_burst = _make_burst()
	add_child(_burst)


func is_standing(index: int) -> bool:
	return _down[index] < 0.0


## A punch or snowball landed on snowman `index` (see SantaController).
func hit(index: int, hit_info: Dictionary) -> void:
	if not is_standing(index):
		return
	var direction: Vector3 = hit_info.get("direction", Vector3.FORWARD)
	direction.y = 0.0
	if direction.length() < 0.01:
		direction = Vector3.FORWARD
	# Tip away from the blow: about the axis across it.
	_axes[index] = Vector3.UP.cross(direction.normalized()).normalized()
	_spin[index] += float(hit_info.get("force", 3.0)) * 0.9
	_health[index] -= float(hit_info.get("damage", 1.0))
	if _health[index] <= 0.0:
		_break(index)


func _break(index: int) -> void:
	_down[index] = 0.0
	_bodies[index].set_enabled(false)
	_burst.global_position = _spots[index].origin + Vector3.UP * 1.0
	_burst.restart()
	_burst.visible = true
	broken.emit(index)


func _process(delta: float) -> void:
	for i in _spots.size():
		if _down[i] >= 0.0:
			_rebuild(i, delta)
		elif _tilt[i] != 0.0 or _spin[i] != 0.0:
			_wobble(i, delta)


func _wobble(i: int, delta: float) -> void:
	_spin[i] += (-STIFFNESS * _tilt[i] - DAMPING * _spin[i]) * delta
	_tilt[i] = clampf(_tilt[i] + _spin[i] * delta, -MAX_TILT, MAX_TILT)
	if absf(_tilt[i]) < 0.002 and absf(_spin[i]) < 0.01:
		_tilt[i] = 0.0
		_spin[i] = 0.0
	# Rocks on the edge of its base, not round its middle.
	var rock := Basis(_axes[i], _tilt[i])
	var base := _spots[i]
	_multimesh.set_instance_transform(i, Transform3D(rock * base.basis, base.origin))


## Lies in pieces for a while, then grows back with a little bounce.
func _rebuild(i: int, delta: float) -> void:
	_down[i] += delta
	var grow := clampf((_down[i] - REBUILD_SECONDS) / 0.6, 0.0, 1.0)
	# Eases out past full size and settles back (an "ease out back" curve).
	var size := 1.0 + 2.7 * pow(grow - 1.0, 3.0) + 1.7 * pow(grow - 1.0, 2.0)
	var base := _spots[i]
	_multimesh.set_instance_transform(i, Transform3D(base.basis.scaled(Vector3.ONE * maxf(size, 0.001)), base.origin))
	if grow >= 1.0:
		_down[i] = -1.0
		_health[i] = HEALTH
		_tilt[i] = 0.0
		_spin[i] = 0.0
		_bodies[i].set_enabled(true)


func _make_burst() -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.name = "Burst"
	burst.emitting = false
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 24
	burst.lifetime = 1.2
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.5
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.gravity = Vector3(0, -12, 0)
	burst.angular_velocity_min = -200.0
	burst.angular_velocity_max = 200.0
	burst.scale_amount_min = 0.1
	burst.scale_amount_max = 0.24
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.75, 1))
	shrink.add_point(Vector2(1, 0))
	burst.scale_amount_curve = shrink
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.25, 2.0, 7), "snow_02", Transform3D.IDENTITY, 1.0,
			WinterProps.SNOW_TINT)
	var lump := b.build(0.0, "Lump")
	burst.mesh = lump.mesh
	lump.free()
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.visible = false
	burst.finished.connect(func() -> void: burst.visible = false)
	return burst


## One snowman's solid body and the area punches and snowballs land on.
class _Snowman extends StaticBody3D:
	var index := 0
	var targets: Node
	var _hurt: Area3D

	func _init() -> void:
		collision_layer = PhysicsLayers.WORLD
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var body := CylinderShape3D.new()
		body.radius = 0.5
		body.height = 2.2
		shape.shape = body
		shape.position.y = 1.1
		add_child(shape)
		_hurt = Area3D.new()
		_hurt.collision_layer = PhysicsLayers.HURTBOX
		_hurt.collision_mask = 0
		_hurt.monitoring = false
		var area_shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.6
		capsule.height = 2.3
		area_shape.shape = capsule
		area_shape.position.y = 1.15
		_hurt.add_child(area_shape)
		add_child(_hurt)

	func take_hit(hit: Dictionary) -> void:
		targets.hit(index, hit)

	func set_enabled(on: bool) -> void:
		process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
