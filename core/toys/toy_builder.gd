class_name ToyBuilder
extends RefCounted
## Builds detailed toy-style models by merging many shapes into a single mesh.
##
## Colours are stored per vertex, so a whole figure needs only two materials
## (cel-shaded with outline, and glowing). That keeps draw calls low on the web.
## Shape generators (lathe, tube, star) let us make smooth, curvy silhouettes
## rather than plain primitives.

const TOON_SHADER := preload("res://core/visual/toon.gdshader")
const OUTLINE_SHADER := preload("res://core/visual/toon_outline.gdshader")
const GLOW_SHADER := preload("res://core/visual/glow.gdshader")

static var _material_cache := {}
static var _front_sign := 0.0
static var _unit_sphere: SphereMesh

var _solid := _Bucket.new()
var _glow := _Bucket.new()


class _Bucket:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func is_empty() -> bool:
		return verts.is_empty()

	func to_arrays() -> Array:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		if not colors.is_empty():
			arrays[Mesh.ARRAY_COLOR] = colors
		return arrays

	func to_mesh() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, to_arrays())
		return mesh


# --- Adding shapes -----------------------------------------------------------

## Adds `mesh` in the given colour. `glow` parts are self-lit and bloom.
func add(mesh: Mesh, color: Color, xform := Transform3D.IDENTITY, glow := false) -> ToyBuilder:
	var bucket := _glow if glow else _solid
	var arrays := mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		src_indices = arrays[Mesh.ARRAY_INDEX]
	if src_indices.is_empty():
		src_indices.resize(src_verts.size())
		for i in src_verts.size():
			src_indices[i] = i

	var normal_basis := xform.basis.inverse().transposed()
	var mirrored := xform.basis.determinant() < 0.0
	var base := bucket.verts.size()
	var linear := color.srgb_to_linear()
	for i in src_verts.size():
		bucket.verts.append(xform * src_verts[i])
		bucket.normals.append((normal_basis * src_normals[i]).normalized())
		bucket.colors.append(linear)
	for t in range(0, src_indices.size(), 3):
		bucket.indices.append(base + src_indices[t])
		if mirrored:
			bucket.indices.append(base + src_indices[t + 2])
			bucket.indices.append(base + src_indices[t + 1])
		else:
			bucket.indices.append(base + src_indices[t + 1])
			bucket.indices.append(base + src_indices[t + 2])
	return self


## Shorthand for add() with position, rotation (degrees) and scale.
func part(mesh: Mesh, color: Color, pos: Vector3, rot_deg := Vector3.ZERO,
		scl := Vector3.ONE, glow := false) -> ToyBuilder:
	return add(mesh, color, xf(pos, rot_deg, scl), glow)


## A ring of puffy spheres, e.g. fur trim on cuffs, hems and hat brims.
func fluff_ring(center: Vector3, radius: float, puff: float, color: Color,
		count := 14, tilt_deg := Vector3.ZERO, seed := 1) -> ToyBuilder:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tilt := Basis.from_euler(tilt_deg * (PI / 180.0))
	for i in count:
		var angle := TAU * i / count
		var offset := tilt * Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var r := puff * rng.randf_range(0.85, 1.15)
		add(unit_sphere(), color, Transform3D(Basis.from_scale(Vector3.ONE * r), center + offset))
	return self


## A cluster of puffs filling an ellipsoid, e.g. beards, pom-poms, snow piles.
func fluff_blob(center: Vector3, extents: Vector3, puff: float, color: Color,
		count := 20, seed := 1) -> ToyBuilder:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var pos := center + dir * extents * rng.randf_range(0.45, 1.0)
		var r := puff * rng.randf_range(0.75, 1.2)
		add(unit_sphere(), color, Transform3D(Basis.from_scale(Vector3.ONE * r), pos))
	return self


## Puffs placed along a path, e.g. the fur strip down the front of Santa's coat.
func fluff_path(points: PackedVector3Array, puff: float, color: Color, spacing := 0.07, seed := 1) -> ToyBuilder:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var path := smooth_path(points, 8)
	var travelled := spacing
	for i in range(1, path.size()):
		travelled += path[i].distance_to(path[i - 1])
		if travelled >= spacing:
			travelled = 0.0
			var r := puff * rng.randf_range(0.85, 1.15)
			add(unit_sphere(), color, Transform3D(Basis.from_scale(Vector3.ONE * r), path[i]))
	return self


## Produces a MeshInstance3D holding everything added so far.
func build(outline := 0.012, node_name := "Toy") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var surface := 0
	if not _solid.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _solid.to_arrays())
		mesh.surface_set_material(surface, toon_material(outline))
		surface += 1
	if not _glow.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _glow.to_arrays())
		mesh.surface_set_material(surface, glow_material())
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	return instance


# --- Materials ----------------------------------------------------------------

static func toon_material(outline := 0.012) -> ShaderMaterial:
	var key := "toon_%.4f" % outline
	if not _material_cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = TOON_SHADER
		if outline > 0.0:
			var line := ShaderMaterial.new()
			line.shader = OUTLINE_SHADER
			line.set_shader_parameter("thickness", outline)
			mat.next_pass = line
		_material_cache[key] = mat
	return _material_cache[key]


static func glow_material() -> ShaderMaterial:
	if not _material_cache.has("glow"):
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		_material_cache["glow"] = mat
	return _material_cache["glow"]


# --- Primitive shapes ----------------------------------------------------------

static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl), pos)


static func unit_sphere() -> SphereMesh:
	if _unit_sphere == null:
		_unit_sphere = sphere(1.0, 10)
	return _unit_sphere


static func sphere(radius: float, segments := 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(4, segments >> 1)
	return m


static func capsule(radius: float, height: float, segments := 16) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 6
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Torus lying flat in the XZ plane.
static func torus(ring_radius: float, tube_radius: float, ring_segments := 24, tube_segments := 10) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = ring_radius - tube_radius
	m.outer_radius = ring_radius + tube_radius
	m.rings = ring_segments
	m.ring_segments = tube_segments
	return m


# --- Generated shapes ----------------------------------------------------------

## Spins a profile of (radius, height) points around the Y axis, bottom to top.
## Start and end with radius 0 for a closed solid.
static func lathe(profile: PackedVector2Array, segments := 24) -> ArrayMesh:
	var b := _Bucket.new()
	var count := profile.size()
	for i in count:
		var p := profile[i]
		var slope := profile[mini(i + 1, count - 1)] - profile[maxi(i - 1, 0)]
		var n2 := Vector2(slope.y, -slope.x).normalized()
		for s in segments:
			var angle := TAU * s / segments
			b.verts.append(Vector3(cos(angle) * p.x, p.y, sin(angle) * p.x))
			b.normals.append(Vector3(cos(angle) * n2.x, n2.y, sin(angle) * n2.x).normalized())
	for i in count - 1:
		for s in segments:
			var s2 := (s + 1) % segments
			_quad(b, i * segments + s, i * segments + s2, (i + 1) * segments + s, (i + 1) * segments + s2)
	return b.to_mesh()


## A tube following `points`, with a radius per point. Ends are capped.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, segments := 10) -> ArrayMesh:
	var b := _Bucket.new()
	var n := points.size()
	var normal := Vector3.ZERO
	var tangents := PackedVector3Array()
	for i in n:
		var tangent := (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		tangents.append(tangent)
		if i == 0:
			normal = tangent.cross(Vector3.UP)
			if normal.length() < 0.01:
				normal = tangent.cross(Vector3.RIGHT)
			normal = normal.normalized()
		else:
			# Parallel transport keeps the rings from twisting.
			normal = (normal - tangent * normal.dot(tangent)).normalized()
		var binormal := tangent.cross(normal)
		for s in segments:
			var angle := TAU * s / segments
			var dir := normal * cos(angle) + binormal * sin(angle)
			b.verts.append(points[i] + dir * radii[i])
			b.normals.append(dir)
	for i in n - 1:
		for s in segments:
			var s2 := (s + 1) % segments
			_quad(b, i * segments + s, i * segments + s2, (i + 1) * segments + s, (i + 1) * segments + s2)
	# End caps
	for end: int in [0, n - 1]:
		var centre := b.verts.size()
		var outward := -tangents[0] if end == 0 else tangents[n - 1]
		b.verts.append(points[end])
		b.normals.append(outward)
		var ring := end * segments
		for s in segments:
			b.verts.append(b.verts[ring + s])
			b.normals.append(outward)
		for s in segments:
			_tri(b, centre, centre + 1 + s, centre + 1 + (s + 1) % segments)
	return b.to_mesh()


## A tube through smoothed control points (Catmull-Rom), radii interpolated.
static func curve(points: PackedVector3Array, radii: PackedFloat32Array, segments := 10, subdivisions := 6) -> ArrayMesh:
	var path := smooth_path(points, subdivisions)
	return tube(path, resample(radii, path.size()), segments)


## A chunky faceted star (for tree toppers), facing +Z.
static func star(spikes := 5, outer := 0.3, inner := 0.13, depth := 0.08) -> ArrayMesh:
	var b := _Bucket.new()
	var rim := PackedVector3Array()
	for i in spikes * 2:
		var angle := PI / 2.0 + PI * i / spikes
		var r := outer if i % 2 == 0 else inner
		rim.append(Vector3(cos(angle) * r, sin(angle) * r, 0.0))
	for face in [1.0, -1.0]:
		var tip := Vector3(0, 0, depth * face)
		for i in rim.size():
			var a := rim[i]
			var c := rim[(i + 1) % rim.size()]
			var fn := (a - tip).cross(c - tip).normalized()
			if fn.z * face < 0.0:
				fn = -fn
			var base := b.verts.size()
			b.verts.append_array([tip, a, c])
			b.normals.append_array([fn, fn, fn])
			_tri(b, base, base + 1, base + 2)
	return b.to_mesh()


static func smooth_path(points: PackedVector3Array, subdivisions := 6) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		for s in subdivisions:
			var t := float(s) / subdivisions
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[n - 1])
	return out


static func resample(values: PackedFloat32Array, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in count:
		var pos := float(i) / maxi(count - 1, 1) * (values.size() - 1)
		var lo := int(floor(pos))
		var hi := mini(lo + 1, values.size() - 1)
		out.append(lerpf(values[lo], values[hi], pos - lo))
	return out


# --- Triangle helpers ----------------------------------------------------------

static func _quad(b: _Bucket, a: int, a2: int, c: int, c2: int) -> void:
	_tri(b, a, c, a2)
	_tri(b, a2, c, c2)


## Adds a triangle, flipping its winding if needed so it faces along its normals.
static func _tri(b: _Bucket, i0: int, i1: int, i2: int) -> void:
	var face := (b.verts[i1] - b.verts[i0]).cross(b.verts[i2] - b.verts[i0])
	var facing := face.dot(b.normals[i0] + b.normals[i1] + b.normals[i2])
	if facing * _engine_front_sign() < 0.0:
		b.indices.append_array([i0, i2, i1])
	else:
		b.indices.append_array([i0, i1, i2])


## Learns the engine's front-face winding from a built-in sphere, once.
static func _engine_front_sign() -> float:
	if _front_sign == 0.0:
		var arrays := SphereMesh.new().surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var total := 0.0
		for t in range(0, idx.size(), 3):
			var face := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
			total += face.dot(n[idx[t]] + n[idx[t + 1]] + n[idx[t + 2]])
		_front_sign = signf(total)
	return _front_sign
