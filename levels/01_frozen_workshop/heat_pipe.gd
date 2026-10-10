class_name HeatPipe
extends MeshInstance3D
## An iron pipe along a path of points, its corners bent round smoothly.
## heat() sends a glowing front along it from the first point to the last,
## melting the frost off as it goes.

signal heated

const SHADER := preload("res://levels/01_frozen_workshop/heat_pipe.gdshader")
## How fast the heat travels, in metres per second.
const SPEED := 14.0

var length := 0.0
var hot := false
var _material: ShaderMaterial


func _init(points: Array, radius := 0.22, bend := 0.9) -> void:
	name = "HeatPipe"
	var path := _bent(points, bend)
	mesh = _tube(path, radius)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("time_offset", randf() * 10.0)
	material_override = _material
	# Flanges at every straight join and at both ends.
	var b := ToyBuilder.new()
	for k in points.size():
		var p: Vector3 = points[k]
		var dir: Vector3 = ((points[mini(k + 1, points.size() - 1)] as Vector3) - (points[maxi(k - 1, 0)] as Vector3)).normalized()
		if k > 0 and k < points.size() - 1:
			continue
		b.finished(ToyBuilder.cylinder(radius * 1.35, radius * 1.35, 0.1, 14), Color("34302c"), "metal",
				Transform3D(_basis_along(dir), p))
	add_child(b.build(0.0, "Flanges"))


## Sends heat along the pipe (straight to hot with `instant`).
func heat(instant := false, delay := 0.0) -> void:
	if hot:
		return
	hot = true
	if instant:
		_material.set_shader_parameter("front", length + 1.0)
		_material.set_shader_parameter("glow", 1.0)
		heated.emit()
		return
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_method(func(f: float) -> void: _material.set_shader_parameter("front", f), 0.0, length + 1.0, length / SPEED)
	t.parallel().tween_method(func(g: float) -> void: _material.set_shader_parameter("glow", g), 0.0, 1.0, length / SPEED)
	t.tween_callback(heated.emit)


## Cools it back down (a spent pipe in the boss fight).
func cool(seconds := 2.0) -> void:
	var t := create_tween()
	t.tween_method(func(g: float) -> void: _material.set_shader_parameter("glow", g), 1.0, 0.0, seconds)


## The path with each inner corner replaced by a quarter-ish arc.
static func _bent(points: Array, bend: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(points[0])
	for k in range(1, points.size() - 1):
		var a: Vector3 = points[k - 1]
		var p: Vector3 = points[k]
		var c: Vector3 = points[k + 1]
		var r := minf(bend, minf(a.distance_to(p), p.distance_to(c)) * 0.45)
		var enter := p + (a - p).normalized() * r
		var leave := p + (c - p).normalized() * r
		for j in 7:
			var t := j / 6.0
			# A quadratic curve through the corner.
			out.append(enter.lerp(p, t).lerp(p.lerp(leave, t), t))
	out.append(points[points.size() - 1])
	return out


static func _basis_along(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var side := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := side.cross(up).normalized()
	return Basis(x, up, x.cross(up))


## A tube through `path`, with UV.x the distance along it in metres and
## UV.y the way round.
func _tube(path: PackedVector3Array, radius: float) -> ArrayMesh:
	const SIDES := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travelled := 0.0
	var side := Vector3.ZERO
	var rings: Array = []
	for k in path.size():
		var ahead: Vector3
		if k == 0:
			ahead = path[1] - path[0]
		elif k == path.size() - 1:
			ahead = path[k] - path[k - 1]
		else:
			ahead = (path[k + 1] - path[k - 1])
		ahead = ahead.normalized()
		if k > 0:
			travelled += path[k].distance_to(path[k - 1])
		# Carry the ring's orientation along the pipe so it never twists.
		if k == 0:
			side = ahead.cross(Vector3.UP if absf(ahead.y) < 0.9 else Vector3.RIGHT)
		side = (side - ahead * side.dot(ahead)).normalized()
		var top := side.cross(ahead).normalized()
		rings.append([path[k], side, top, travelled])
	length = travelled
	for k in rings.size() - 1:
		for s in SIDES:
			var quad := []
			for corner: Array in [[k, s], [k + 1, s], [k + 1, s + 1], [k, s + 1]]:
				var ring: Array = rings[corner[0]]
				var a := TAU * float(corner[1]) / SIDES
				var n: Vector3 = (ring[1] as Vector3) * cos(a) + (ring[2] as Vector3) * sin(a)
				quad.append([(ring[0] as Vector3) + n * radius, n, Vector2(ring[3], float(corner[1]) / SIDES)])
			for i: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(quad[i][1])
				st.set_uv(quad[i][2])
				st.add_vertex(quad[i][0])
	return st.commit()
