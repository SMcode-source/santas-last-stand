class_name MovingPlatform
extends AnimatableBody3D
## A platform gliding back and forth between two points, easing at each end
## and pausing there for a moment. Characters standing on it ride along (the
## physics engine carries them). Give it a mesh and a collision shape as
## children, or use make() for a snowy plank deck.

## Where it goes to and fro, as offsets from where it starts.
var from := Vector3.ZERO
var to := Vector3(4, 0, 0)
## Seconds for one way across.
var travel_time := 3.0
## Seconds it waits at each end.
var pause := 0.6
## Seconds into its cycle it starts (to set platforms out of step).
var phase := 0.0

var _start := Vector3.ZERO
var _time := 0.0


## A snowy plank deck of `size`, travelling from `at` by `offset` and back.
static func make(size: Vector3, at: Vector3, offset: Vector3, seconds := 3.0) -> MovingPlatform:
	var platform := MovingPlatform.new()
	platform.name = "MovingPlatform"
	platform.position = at
	platform.to = offset
	platform.travel_time = seconds
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.box(size), "brown_planks_04", ToyBuilder.xf(Vector3.ZERO), 1.0, Color("b08a70"))
	b.textured(ToyBuilder.snow_sheet(Vector2(size.x, size.z), 0.06, 5, 0.1), "snow_02",
			ToyBuilder.xf(Vector3(0, size.y / 2.0, 0)), 1.5, WinterProps.SNOW_TINT)
	platform.add_child(b.build(0.0, "Mesh"))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(0, 0.08, 0)
	shape.shape = box
	shape.position.y = 0.04
	platform.add_child(shape)
	return platform


func _init() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	sync_to_physics = true


func _ready() -> void:
	_start = position
	_time = phase


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle := (travel_time + pause) * 2.0
	var t := fposmod(_time, cycle)
	var along: float
	if t < travel_time:
		along = smoothstep(0.0, travel_time, t)
	elif t < travel_time + pause:
		along = 1.0
	elif t < travel_time * 2.0 + pause:
		along = 1.0 - smoothstep(0.0, travel_time, t - travel_time - pause)
	else:
		along = 0.0
	position = _start + from.lerp(to, along)
