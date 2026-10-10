class_name Pacer
extends Node3D
## Walks a character back and forth along a route on flat ground, stopping a
## while at each end: a sentry on watch, a miser pacing his yard.

var model: CastModel
## Points walked between, in order and back again (global, on the ground).
var route: Array[Vector3] = []
var speed := 1.0
## How long it stands at each stop (seconds).
var pause := 3.0
## Plays the walk this much faster or slower to match `speed`.
var stride := 1.0

var _leg := 0
var _forward := true
var _waiting := 0.0


func _init(character: CastModel, points: Array[Vector3], walk_speed := 1.0) -> void:
	model = character
	route = points
	speed = walk_speed
	add_child(model)


func _ready() -> void:
	global_position = route[0]
	_waiting = pause * 0.5


func _process(delta: float) -> void:
	if route.size() < 2:
		return
	if _waiting > 0.0:
		_waiting -= delta
		model.play("")
		return
	var next := _leg + (1 if _forward else -1)
	var to := route[next] - global_position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		global_position = route[next]
		_leg = next
		if _leg == route.size() - 1 or _leg == 0:
			_forward = not _forward
			_waiting = pause
		return
	var dir := to.normalized()
	global_position += dir * step
	# The model faces +z: turn smoothly towards where it is going.
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 6.0))
	model.play("Walking", stride)
