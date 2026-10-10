class_name FlightCourse
extends Node3D
## The flight in to the village, on rails: the sleigh follows the valley up
## through the Alps while the player steers it about within its lane. Glowing
## rings hang along the way, set to either side, high and low, to teach the
## steering; flying through one tops up the boost. Nothing fails here.

signal ring_passed(index: int)
signal ring_missed(index: int)

const RING_RADIUS := 2.3
const NEXT := Color(1.0, 0.78, 0.25)
const WAITING := Color(0.3, 0.55, 1.0)
const PASSED := Color(0.35, 1.0, 0.45)
const MISSED := Color(0.25, 0.25, 0.3)
## Where the rings hang: fraction of the way along, and offset in the lane
## (right, up) in metres.
const RINGS := [
	[0.06, Vector2(0, 0)], [0.1, Vector2(4, 0)], [0.14, Vector2(-4, 1)], [0.19, Vector2(0, 3)],
	[0.24, Vector2(0, -3)], [0.3, Vector2(-5, -2)], [0.35, Vector2(5, 2)], [0.41, Vector2(-5, 2)],
	[0.5, Vector2(0, 0)], [0.56, Vector2(5, -2)], [0.62, Vector2(-3, -3)], [0.68, Vector2(3, 3)],
	[0.74, Vector2(-5, 0)], [0.8, Vector2(5, 0)],
]

var path: Path3D
var passed := 0
var next := 0
var length := 0.0

var _at := PackedFloat32Array()
var _offset := PackedVector2Array()
var _multimesh: MultiMesh
var _state := PackedInt32Array()


func _init() -> void:
	name = "FlightCourse"
	path = Path3D.new()
	path.name = "Rail"
	path.curve = preload("res://levels/02_krampusnacht/village_layout.gd").flight_curve()
	add_child(path)
	length = path.curve.get_baked_length()
	for spec: Array in RINGS:
		_at.append(float(spec[0]) * length)
		_offset.append(spec[1])
		_state.append(0)
	_build_rings()


## Checks the sleigh against the next ring as it goes by (call every physics frame).
func track(sleigh: SleighController) -> void:
	while next < _at.size() and sleigh.rail_progress >= _at[next]:
		if sleigh.rail_offset.distance_to(_offset[next]) <= RING_RADIUS:
			_state[next] = 1
			passed += 1
			sleigh.boost_meter = minf(1.0, sleigh.boost_meter + 0.25)
			Audio.play_sfx("ring", 1.0 + 0.04 * passed, -4.0)
			ring_passed.emit(next)
		else:
			_state[next] = 2
			ring_missed.emit(next)
		next += 1
		_colour_rings()


## How far along the flight the sleigh is (0 to 1).
func progress_of(sleigh: SleighController) -> float:
	return sleigh.rail_progress / length if length > 0.0 else 0.0


func _frame(distance: float) -> Transform3D:
	return path.transform * path.curve.sample_baked_with_rotation(distance, true, true)


func _build_rings() -> void:
	var b := ToyBuilder.new()
	b.add(ToyBuilder.torus(RING_RADIUS, 0.12, 40, 8), Color.WHITE, Transform3D.IDENTITY, true)
	var built := b.build(0.0, "Ring")
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = built.mesh
	built.free()
	_multimesh.instance_count = _at.size()
	for i in _at.size():
		var frame := _frame(_at[i])
		var right := frame.basis.x.normalized()
		var up := frame.basis.y.normalized()
		var centre := frame.origin + right * _offset[i].x + up * _offset[i].y
		var ahead := -frame.basis.z.normalized()
		var facing := Basis.looking_at(ahead, up) * Basis(Vector3.RIGHT, PI / 2.0)
		_multimesh.set_instance_transform(i, Transform3D(facing, centre))
	var drawn := MultiMeshInstance3D.new()
	drawn.name = "Rings"
	drawn.multimesh = _multimesh
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drawn)
	_colour_rings()


func _colour_rings() -> void:
	for i in _at.size():
		var colour := WAITING
		match _state[i]:
			1:
				colour = PASSED
			2:
				colour = MISSED
			_:
				if i == next:
					colour = NEXT
		_multimesh.set_instance_color(i, colour)
