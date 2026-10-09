class_name ToyBuilder
extends RefCounted
## Builds detailed toy-style models by merging many shapes into a single mesh.
##
## Painted parts store their colour per vertex and share one material; textured
## parts are grouped per texture set; glowing parts share a bloom material.
## That keeps draw calls low on the web. Shape generators (lathe, tube, star)
## give smooth, curvy silhouettes rather than plain primitives.

const TOON_SHADER := preload("res://core/visual/toon.gdshader")
const OUTLINE_SHADER := preload("res://core/visual/toon_outline.gdshader")
const GLOW_SHADER := preload("res://core/visual/glow.gdshader")

## Global art style switch: cel-shaded cartoon, or stylised-realistic PBR.
static var cartoon_shading := false

static var _material_cache := {}
static var _front_sign := 0.0
static var _unit_sphere: SphereMesh
static var _shape_cache := {}
static var _strand_patterns := {}

## Bucket key -> _Bucket. Keys: "painted", "glow", "fin|<finish>" or "tex|<set>|<tile>".
## Textured parts keep their tint and snow in the vertex colour, so every part
## using one texture set shares a single surface (one draw call).
var _buckets := {}
## Bucket key prefixes whose surfaces cast no shadow (see shadowless()).
var _shadowless: Array[String] = ["glow"]


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
	return _append(_bucket("glow" if glow else "painted"), mesh, color, xform)


## Adds `mesh` using a realistic texture set from assets/textures.
## `snow` above 0 lets snow settle on the upward-facing parts.
func textured(mesh: Mesh, texture_set: String, xform := Transform3D.IDENTITY,
		tile_size := 1.0, tint := Color.WHITE, snow := 0.0) -> ToyBuilder:
	var key := "tex|%s|%s" % [texture_set, tile_size]
	return _append(_bucket(key), mesh, Color(tint.r, tint.g, tint.b, snow), xform)


## Adds `mesh` in a colour with a character finish: "velvet", "fur", "hair",
## "skin", "leather", "metal" or "eye" (see CharacterFinish).
func finished(mesh: Mesh, color: Color, finish: String, xform := Transform3D.IDENTITY) -> ToyBuilder:
	return _append(_bucket("fin|" + finish), mesh, color, xform)


## Like finished(), but each vertex is coloured by `paint(position)`, e.g.
## skin with rosy cheeks that blend smoothly into the rest of the face.
func painted_finish(mesh: Mesh, paint: Callable, finish: String, xform := Transform3D.IDENTITY) -> ToyBuilder:
	var bucket := _bucket("fin|" + finish)
	var start := bucket.colors.size()
	_append(bucket, mesh, Color.WHITE, xform)
	for i in range(start, bucket.verts.size()):
		bucket.colors[i] = (paint.call(bucket.verts[i]) as Color).srgb_to_linear()
	return self


## Adds one tapered hair or fur strand through `points`, shading from
## `root_color` to `tip_color`. Written straight into the mesh with no
## intermediate shapes, because beards and fur trims use thousands of them.
## With a `volume_centre`, normals point away from it so a mass of strands is
## lit as one soft volume (a beard, a fur trim) instead of thousands of facets.
func strand(points: PackedVector3Array, root_radius: float, tip_radius: float,
		root_color: Color, tip_color: Color, finish := "hair", sides := 4,
		volume_centre := Vector3.INF) -> ToyBuilder:
	var bucket := _bucket("fin|" + finish)
	var base := bucket.verts.size()
	_strand_rings(bucket, points, root_radius, tip_radius, root_color, tip_color, sides)
	if volume_centre.is_finite():
		for i in points.size():
			var out := (points[i] - volume_centre).normalized()
			for k in sides:
				var v := base + i * sides + k
				bucket.normals[v] = (out + bucket.normals[v] * 0.35).normalized()
	var pattern := _strand_pattern(points.size(), sides)
	var start := bucket.indices.size()
	bucket.indices.resize(start + pattern.size())
	for k in pattern.size():
		bucket.indices[start + k] = pattern[k] + base
	return self


static func _strand_rings(bucket: _Bucket, points: PackedVector3Array, root_radius: float,
		tip_radius: float, root_color: Color, tip_color: Color, sides: int) -> void:
	var n := points.size()
	var normal := Vector3.ZERO
	for i in n:
		var t := float(i) / (n - 1)
		var tangent := (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		if i == 0:
			normal = tangent.cross(Vector3.UP if absf(tangent.y) < 0.95 else Vector3.RIGHT).normalized()
		else:
			normal = (normal - tangent * normal.dot(tangent)).normalized()
		var binormal := tangent.cross(normal)
		var radius := lerpf(root_radius, tip_radius, t)
		var color := root_color.lerp(tip_color, t).srgb_to_linear()
		for s in sides:
			var angle := TAU * s / sides
			var dir := normal * cos(angle) + binormal * sin(angle)
			bucket.verts.append(points[i] + dir * radius)
			bucket.normals.append(dir)
			bucket.colors.append(color)


## Triangle indices for a strand of `points` rings with `sides` each. Every
## strand's frame has the same handedness, so one pattern serves them all.
static func _strand_pattern(points: int, sides: int) -> PackedInt32Array:
	var key := points * 100 + sides
	if not _strand_patterns.has(key):
		var probe := _Bucket.new()
		var line := PackedVector3Array()
		for i in points:
			line.append(Vector3(0.1 * i, i, 0.0))
		_strand_rings(probe, line, 1.0, 1.0, Color.WHITE, Color.WHITE, sides)
		for i in points - 1:
			for s in sides:
				var s2 := (s + 1) % sides
				_quad(probe, i * sides + s, i * sides + s2, (i + 1) * sides + s, (i + 1) * sides + s2)
		_strand_patterns[key] = probe.indices
	return _strand_patterns[key]


func _bucket(key: String) -> _Bucket:
	if not _buckets.has(key):
		_buckets[key] = _Bucket.new()
	return _buckets[key]


func _append(bucket: _Bucket, mesh: Mesh, color: Color, xform: Transform3D) -> ToyBuilder:
	var src := _arrays_of(mesh)
	var src_verts: PackedVector3Array = src[0]
	var src_normals: PackedVector3Array = src[1]
	var src_indices: PackedInt32Array = src[2]

	# Whole-array transforms run natively, which matters a lot in the web build.
	var normal_basis := xform.basis.inverse().transposed()
	normal_basis = normal_basis * (1.0 / pow(absf(normal_basis.determinant()), 1.0 / 3.0))
	var base := bucket.verts.size()
	bucket.verts.append_array(xform * src_verts)
	bucket.normals.append_array(Transform3D(normal_basis, Vector3.ZERO) * src_normals)
	var colors := PackedColorArray()
	colors.resize(src_verts.size())
	colors.fill(color.srgb_to_linear())
	bucket.colors.append_array(colors)

	var mirrored := xform.basis.determinant() < 0.0
	var start := bucket.indices.size()
	var count := src_indices.size()
	bucket.indices.resize(start + count)
	var second := 2 if mirrored else 1
	var third := 1 if mirrored else 2
	for t in range(0, count, 3):
		bucket.indices[start + t] = base + src_indices[t]
		bucket.indices[start + t + 1] = base + src_indices[t + second]
		bucket.indices[start + t + 2] = base + src_indices[t + third]
	return self


## Vertex, normal and index arrays of a mesh. Cached for the shared primitives,
## which are reused hundreds of times per model.
static func _arrays_of(mesh: Mesh) -> Array:
	if mesh.has_meta("toy_arrays"):
		return mesh.get_meta("toy_arrays")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i
	var result := [verts, arrays[Mesh.ARRAY_NORMAL], indices]
	if mesh is PrimitiveMesh:
		mesh.set_meta("toy_arrays", result)
	return result


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
## `outline` only applies when cartoon_shading is on.
## Parts whose bucket key starts with `prefix` ("fin|", "fin|eye", "painted"...)
## cast no shadow. Small trinkets like baubles and beads add a lot of
## triangles to the shadow pass for shadows nobody would notice; glowing parts
## never cast one.
func shadowless(prefix: String) -> ToyBuilder:
	_shadowless.append(prefix)
	return self


## Builds the mesh: one surface (draw call) per bucket. Shadowless surfaces go
## in a child MeshInstance3D named "NoShadow".
func build(outline := 0.012, node_name := "Toy") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var unshadowed := ArrayMesh.new()
	for key: String in _buckets:
		var bucket: _Bucket = _buckets[key]
		if bucket.is_empty():
			continue
		var target := unshadowed if _shadowless.any(func(p: String) -> bool: return key.begins_with(p)) else mesh
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bucket.to_arrays())
		target.surface_set_material(target.get_surface_count() - 1, _material_for(key, outline))
	var instance := MeshInstance3D.new()
	instance.name = node_name
	if mesh.get_surface_count() == 0:
		# Nothing casts a shadow: the whole thing is one shadowless mesh.
		instance.mesh = unshadowed
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return instance
	instance.mesh = mesh
	if unshadowed.get_surface_count() > 0:
		var child := MeshInstance3D.new()
		child.name = "NoShadow"
		child.mesh = unshadowed
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_child(child)
	return instance


# --- Materials ----------------------------------------------------------------

static func _material_for(key: String, outline: float) -> Material:
	if key == "glow":
		return glow_material()
	if key.begins_with("fin|"):
		return CharacterFinish.material(key.get_slice("|", 1))
	if key == "painted":
		return toon_material(outline) if cartoon_shading else PbrLibrary.painted()
	var parts := key.split("|")
	return PbrLibrary.vertex_tinted(parts[1], float(parts[2]))


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


## Primitive shapes are cached by their parameters: callers must not modify them.
static func _cached(key: String, make: Callable) -> PrimitiveMesh:
	if not _shape_cache.has(key):
		_shape_cache[key] = make.call()
	return _shape_cache[key]


static func sphere(radius: float, segments := 16) -> SphereMesh:
	return _cached("s%s|%d" % [radius, segments], _make_sphere.bind(radius, segments))


static func _make_sphere(radius: float, segments: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(4, segments >> 1)
	return m


static func capsule(radius: float, height: float, segments := 16) -> CapsuleMesh:
	return _cached("c%s|%s|%d" % [radius, height, segments], _make_capsule.bind(radius, height, segments))


static func _make_capsule(radius: float, height: float, segments: int) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = 6
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 16) -> CylinderMesh:
	return _cached("y%s|%s|%s|%d" % [top, bottom, height, segments], _make_cylinder.bind(top, bottom, height, segments))


static func _make_cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


static func box(size: Vector3) -> BoxMesh:
	return _cached("b%s" % size, _make_box.bind(size))


static func _make_box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Torus lying flat in the XZ plane.
static func torus(ring_radius: float, tube_radius: float, ring_segments := 24, tube_segments := 10) -> TorusMesh:
	return _cached("t%s|%s|%d|%d" % [ring_radius, tube_radius, ring_segments, tube_segments],
			_make_torus.bind(ring_radius, tube_radius, ring_segments, tube_segments))


static func _make_torus(ring_radius: float, tube_radius: float, ring_segments: int, tube_segments: int) -> TorusMesh:
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


## Skins a stack of closed rings (each with the same number of points, bottom
## to top) into a smooth surface with capped ends, e.g. a coat with a belly.
static func loft(rings: Array[PackedVector3Array]) -> ArrayMesh:
	var b := _Bucket.new()
	var count := rings.size()
	var seg := rings[0].size()
	var centres := PackedVector3Array()
	for i in count:
		var centre := Vector3.ZERO
		for p in rings[i]:
			centre += p
		centres.append(centre / seg)
		for s in seg:
			var along := rings[i][(s + 1) % seg] - rings[i][(s + seg - 1) % seg]
			var up := rings[mini(i + 1, count - 1)][s] - rings[maxi(i - 1, 0)][s]
			var n := along.cross(up).normalized()
			if n.dot(rings[i][s] - centres[i]) < 0.0:
				n = -n
			b.verts.append(rings[i][s])
			b.normals.append(n)
	for i in count - 1:
		for s in seg:
			var s2 := (s + 1) % seg
			_quad(b, i * seg + s, i * seg + s2, (i + 1) * seg + s, (i + 1) * seg + s2)
	for end: int in [0, count - 1]:
		var outward := Vector3.DOWN if end == 0 else Vector3.UP
		var centre := b.verts.size()
		b.verts.append(centres[end])
		b.normals.append(outward)
		for s in seg:
			b.verts.append(rings[end][s])
			b.normals.append(outward)
		for s in seg:
			_tri(b, centre, centre + 1 + s, centre + 1 + (s + 1) % seg)
	return b.to_mesh()


## Pushes vertices in and out along their normals with smooth 3D noise, so
## shapes look natural rather than machine-made (snow drifts, fur, branches).
static func lumpy(mesh: Mesh, amount: float, frequency := 4.0, seed := 1) -> ArrayMesh:
	var src := _arrays_of(mesh)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	var verts: PackedVector3Array = src[0].duplicate()
	var normals: PackedVector3Array = src[1]
	for i in verts.size():
		verts[i] += normals[i] * noise.get_noise_3dv(verts[i]) * amount
	var b := _Bucket.new()
	b.verts = verts
	b.normals = normals
	b.indices = src[2]
	return b.to_mesh()


## A closed ring of snow, as if lying along a branch tier, rim or brim.
static func snow_ring(radius: float, thickness: float, segments := 16) -> ArrayMesh:
	var t := thickness
	return lathe(PackedVector2Array([
		Vector2(radius - t, t * 0.6), Vector2(radius - t * 0.2, -t * 0.1), Vector2(radius + t * 0.5, t * 0.25),
		Vector2(radius + t * 0.2, t * 0.9), Vector2(radius - t * 0.6, t * 1.1), Vector2(radius - t, t * 0.6),
	]), segments)


## A soft, lumpy blanket of snow lying on a flat `size` area (x by z), about
## `thickness` deep, that rounds off and droops over its edges.
static func snow_sheet(size: Vector2, thickness: float, seed := 1, cell := 0.12) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.6
	var half := size / 2.0
	var lip := thickness * 1.2
	var nx := int((size.x + lip * 2.0) / cell) + 1
	var nz := int((size.y + lip * 2.0) / cell) + 1
	var b := _Bucket.new()
	var heights := PackedFloat32Array()
	for j in nz + 1:
		for i in nx + 1:
			var x := lerpf(-half.x - lip, half.x + lip, float(i) / nx)
			var z := lerpf(-half.y - lip, half.y + lip, float(j) / nz)
			var inside := minf(half.x - absf(x), half.y - absf(z))
			var y: float
			if inside >= 0.0:
				y = thickness * smoothstep(0.0, thickness * 2.5, inside) * (1.0 + noise.get_noise_2d(x, z) * 0.35)
				y = maxf(y, thickness * 0.15)
			else:
				# Past the edge the snow curls down over it.
				y = thickness * 0.15 - thickness * 1.3 * smoothstep(0.0, lip, -inside)
			heights.append(y)
			b.verts.append(Vector3(x, y, z))
	var row := nx + 1
	for j in nz + 1:
		for i in nx + 1:
			var l := heights[j * row + maxi(i - 1, 0)]
			var r := heights[j * row + mini(i + 1, nx)]
			var d := heights[maxi(j - 1, 0) * row + i]
			var u := heights[mini(j + 1, nz) * row + i]
			b.normals.append(Vector3(l - r, 2.0 * cell, d - u).normalized())
	for j in nz:
		for i in nx:
			_quad(b, j * row + i, j * row + i + 1, (j + 1) * row + i, (j + 1) * row + i + 1)
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
