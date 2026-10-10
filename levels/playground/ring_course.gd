extends Node3D
## A loop of glowing rings for the sleigh to fly through in order. The next
## ring shines gold, the rest a cool blue; flying through the right one flashes
## it green and tops up the boost meter. A smooth Path3D runs through all their
## centres, for trying the sleigh's rails mode. One draw call for every ring.

signal ring_passed(index: int, lap: int)

const RING_RADIUS := 3.0
const NEXT := Color(1.0, 0.78, 0.25)
const WAITING := Color(0.3, 0.55, 1.0)
const PASSED := Color(0.35, 1.0, 0.45)

var centres := PackedVector3Array()
var normals := PackedVector3Array()
## The ring to fly through next.
var next := 0
var lap := 0
var path: Path3D
## Seconds into the current lap, and the best lap so far (0 if none).
var lap_time := 0.0
var best_lap := 0.0

var _multimesh: MultiMesh
var _flash := PackedFloat32Array()
var _side := PackedFloat32Array()
var _timing := false
## The ring whose side the sleigh was on last step (-1 at the start).
var _watching := -1


## Rings at `points`, flown in that order and back to the first.
func _init(points: PackedVector3Array) -> void:
	name = "RingCourse"
	centres = points
	var count := points.size()
	for i in count:
		normals.append((points[(i + 1) % count] - points[(i + count - 1) % count]).normalized())
	_flash.resize(count)
	_side.resize(count)
	_build_rings()
	_build_path()


func _build_rings() -> void:
	var b := ToyBuilder.new()
	b.add(ToyBuilder.torus(RING_RADIUS, 0.13, 40, 8), Color.WHITE, Transform3D.IDENTITY, true)
	var built := b.build(0.0, "Ring")
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = built.mesh
	built.free()
	_multimesh.instance_count = centres.size()
	for i in centres.size():
		# The torus lies flat; stand it up facing along the course.
		var facing := Basis.looking_at(normals[i]) * Basis(Vector3.RIGHT, PI / 2.0)
		_multimesh.set_instance_transform(i, Transform3D(facing, centres[i]))
	var drawn := MultiMeshInstance3D.new()
	drawn.name = "Rings"
	drawn.multimesh = _multimesh
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drawn)
	_colour_rings()


## A smooth closed loop through the ring centres.
func _build_path() -> void:
	var curve := Curve3D.new()
	var count := centres.size()
	for i in count + 1:
		var at := centres[i % count]
		var span := (centres[(i + 1) % count] - centres[(i + count - 1) % count]) / 6.0
		curve.add_point(at, -span, span)
	path = Path3D.new()
	path.name = "RingPath"
	path.curve = curve
	add_child(path)


## Watches `body` (the sleigh) for flying through the next ring.
func track(body: Node3D, delta: float) -> void:
	if _timing:
		lap_time += delta
	var i := next
	var offset := body.global_position - centres[i]
	var side := offset.dot(normals[i])
	var across := (offset - normals[i] * side).length()
	if _watching == i and _side[i] < 0.0 and side >= 0.0 and across < RING_RADIUS:
		_pass(i)
	_side[i] = side
	_watching = i


## Forgets which side of the next ring the sleigh was on (after it jumps).
func lose_track() -> void:
	_watching = -1


func _pass(i: int) -> void:
	_flash[i] = 1.0
	next = (i + 1) % centres.size()
	if i == 0:
		if _timing and lap_time > 1.0:
			best_lap = lap_time if best_lap <= 0.0 else minf(best_lap, lap_time)
		lap_time = 0.0
		_timing = true
		lap += 1
	ring_passed.emit(i, lap)
	_colour_rings()


func _process(delta: float) -> void:
	var fading := false
	for i in _flash.size():
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta * 1.5)
			fading = true
	if fading:
		_colour_rings()


func _colour_rings() -> void:
	for i in centres.size():
		var colour := NEXT if i == next else WAITING * 0.6
		colour = colour.lerp(PASSED, _flash[i])
		_multimesh.set_instance_color(i, colour)
