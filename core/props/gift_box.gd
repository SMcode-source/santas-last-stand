class_name GiftBox
extends RefCounted
## A wrapped present that looks like it could be opened: a box with a separate,
## slightly wider lid, printed glossy paper, a satin ribbon tied round both, a
## bow of pinched loops with notched tails, and sometimes a gift tag on a string.
## Every present shares the same two materials (paper and ribbon): colours and
## pattern ride in the vertex colours, so presents that never move can be
## merged into one mesh with merge() and drawn in two draw calls.

const PAPER := preload("res://core/visual/wrapping_paper.gdshader")
const RIBBON := preload("res://core/visual/satin_ribbon.gdshader")

enum Pattern { STRIPES, DOTS, SNOWFLAKES, TARTAN, PLAIN }

const PRINT := Color("f4ecdc")
const FOIL := Color("d8b25a")
const KRAFT := Color("c9a57a")
## How far the lid overhangs the box on every side, in metres.
const LID_OVERHANG := 0.008
const RIBBON_THICKNESS := 0.0015

static var _paper_material: ShaderMaterial
static var _ribbon_material: ShaderMaterial


## `pattern` -1 picks one from the paper colour.
static func build(size: Vector3, paper: Color, ribbon: Color, pattern := -1, seed := 1) -> Node3D:
	if pattern < 0:
		pattern = absi(hash(paper.to_html())) % Pattern.PLAIN
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var paper_surface := MeshPieces.new()
	var ribbon_surface := MeshPieces.new()
	var tag_surface := MeshPieces.new()

	var radius := clampf(minf(size.x, size.z) * 0.025, 0.004, 0.012)
	var lid_height := clampf(size.y * 0.22, 0.05, 0.12)
	var body_size := Vector3(size.x, size.y - lid_height * 0.6, size.z)
	var body_centre := Vector3(0, body_size.y / 2.0, 0)
	var lid_size := Vector3(size.x + LID_OVERHANG * 2.0, lid_height, size.z + LID_OVERHANG * 2.0)
	var lid_centre := Vector3(0, size.y - lid_height / 2.0, 0)
	_rounded_box(paper_surface, body_centre, body_size, radius)
	_rounded_box(paper_surface, lid_centre, lid_size, radius)

	# Ribbon round the box and the lid both ways; the second pass sits a hair
	# higher so the two never fight where they cross on top.
	var width := clampf(minf(size.x, size.z) * 0.13, 0.022, 0.05)
	for axis: int in [0, 2]:
		var lift := RIBBON_THICKNESS * (1.0 if axis == 0 else 2.0)
		_band_around(ribbon_surface, body_centre, body_size, radius, axis, width, lift)
		_band_around(ribbon_surface, lid_centre, lid_size, radius, axis, width, lift)

	_bow(ribbon_surface, Vector3(0, size.y + RIBBON_THICKNESS * 2.0, 0), width, minf(size.x, size.z), rng)
	if rng.randf() < 0.6:
		_tag(tag_surface, ribbon_surface, size, width, rng)

	_print(paper_surface, paper, pattern)
	_print(tag_surface, KRAFT, Pattern.PLAIN)
	_append(paper_surface, tag_surface)
	# Gold ribbon is metallic gift ribbon; other colours are satin.
	var gold := ribbon.h > 0.08 and ribbon.h < 0.17 and ribbon.s > 0.4
	ribbon_surface.colors.fill(Color(ribbon.r, ribbon.g, ribbon.b, 1.0 if gold else 0.0))
	var mesh := ArrayMesh.new()
	paper_surface.add_to(mesh, paper_material())
	ribbon_surface.add_to(mesh, ribbon_material())
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	var root := Node3D.new()
	root.name = "Present"
	root.add_child(instance)
	return root


## Merges presents that will never move into one mesh (two draw calls in all).
## Each present keeps the place it was given; the originals are freed.
static func merge(presents: Array[Node3D]) -> MeshInstance3D:
	var merged := [MeshPieces.new(), MeshPieces.new()]
	for present in presents:
		var part := present.get_node("Mesh") as MeshInstance3D
		var xform := present.transform * part.transform
		var normal_basis := xform.basis.inverse().transposed()
		for s in 2:
			var arrays := part.mesh.surface_get_arrays(s)
			var pieces := MeshPieces.new()
			pieces.verts = xform * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			pieces.normals = Transform3D(normal_basis, Vector3.ZERO) * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			pieces.uvs = arrays[Mesh.ARRAY_TEX_UV]
			pieces.colors = arrays[Mesh.ARRAY_COLOR]
			pieces.indices = arrays[Mesh.ARRAY_INDEX]
			_append(merged[s], pieces)
		present.free()
	var mesh := ArrayMesh.new()
	(merged[0] as MeshPieces).add_to(mesh, paper_material())
	(merged[1] as MeshPieces).add_to(mesh, ribbon_material())
	var instance := MeshInstance3D.new()
	instance.name = "Presents"
	instance.mesh = mesh
	return instance


static func paper_material() -> ShaderMaterial:
	if _paper_material == null:
		_paper_material = ShaderMaterial.new()
		_paper_material.shader = PAPER
		_paper_material.set_shader_parameter("noise_tex", CharacterFinish.noise())
		_paper_material.set_shader_parameter("accent_color", FOIL)
		_paper_material.set_shader_parameter("print_on_dark", PRINT)
	return _paper_material


static func ribbon_material() -> ShaderMaterial:
	if _ribbon_material == null:
		_ribbon_material = ShaderMaterial.new()
		_ribbon_material.shader = RIBBON
	return _ribbon_material


## Stores the paper's look in its vertices for the wrapping paper shader: the
## colour (sRGB) in rgb, and in alpha the pattern plus whether the paper is
## light (light papers get a red print, the rest cream). UVs become the print's
## coordinates, projected onto each face from the side it faces.
static func _print(s: MeshPieces, color: Color, pattern: int) -> void:
	var code := pattern + (5 if color.get_luminance() > 0.6 else 0)
	s.colors.fill(Color(color.r, color.g, color.b, (code + 0.5) / 10.0))
	for i in s.verts.size():
		var n := s.normals[i].abs()
		var p := s.verts[i]
		if n.y >= n.x and n.y >= n.z:
			s.uvs[i] = Vector2(p.x, p.z)
		elif n.x >= n.z:
			s.uvs[i] = Vector2(p.z, p.y)
		else:
			s.uvs[i] = Vector2(p.x, p.y)


static func _append(to: MeshPieces, from: MeshPieces) -> void:
	var base := to.verts.size()
	to.verts.append_array(from.verts)
	to.normals.append_array(from.normals)
	to.uvs.append_array(from.uvs)
	to.colors.append_array(from.colors)
	var start := to.indices.size()
	to.indices.append_array(from.indices)
	for i in range(start, to.indices.size()):
		to.indices[i] += base


# --- Shapes ------------------------------------------------------------------

## A box with rounded edges and corners.
static func _rounded_box(s: MeshPieces, centre: Vector3, size: Vector3, radius: float, segs := 3) -> void:
	var half := size / 2.0
	var inner := half - Vector3.ONE * radius
	for axis in 3:
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var us := _ticks(half[u_axis], radius, segs)
		var vs := _ticks(half[v_axis], radius, segs)
		for face_side: float in [-1.0, 1.0]:
			var base := s.verts.size()
			for v in vs:
				for u in us:
					var p := Vector3.ZERO
					p[axis] = face_side * half[axis]
					p[u_axis] = u
					p[v_axis] = v
					var core := p.clamp(-inner, inner)
					var n := (p - core).normalized()
					s.vertex(centre + core + n * radius, n, Vector2(u, v))
			var row := us.size()
			for j in vs.size() - 1:
				for i in row - 1:
					var a := base + j * row + i
					s.quad(a, a + 1, a + row + 1, a + row)


## Grid lines across one face, bunched up at both ends to round the edges evenly.
static func _ticks(half: float, radius: float, segs: int) -> PackedFloat32Array:
	var start := PackedFloat32Array()
	for k in segs + 1:
		start.append(-half + radius * (1.0 - tan(PI / 4.0 * (1.0 - float(k) / segs))))
	var ticks := start.duplicate()
	for k in range(segs, -1, -1):
		ticks.append(-start[k])
	return ticks


## A ribbon band hugging a rounded box all the way round. Its width runs along
## `width_axis`.
static func _band_around(s: MeshPieces, centre: Vector3, size: Vector3, radius: float,
		width_axis: int, width: float, lift: float, segs := 3) -> void:
	var a_axis := (width_axis + 1) % 3
	var b_axis := (width_axis + 2) % 3
	var ha := size[a_axis] / 2.0 - radius
	var hb := size[b_axis] / 2.0 - radius
	var corners := [Vector2(ha, hb), Vector2(-ha, hb), Vector2(-ha, -hb), Vector2(ha, -hb)]
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	for c in 4:
		for k in segs + 1:
			var angle := PI / 2.0 * (c + float(k) / segs)
			var n := Vector2(cos(angle), sin(angle))
			points.append((corners[c] as Vector2) + n * (radius + lift))
			normals.append(n)
	var base := s.verts.size()
	var travelled := 0.0
	var count := points.size()
	for i in count + 1:
		var k := i % count
		if i > 0:
			travelled += points[k].distance_to(points[(i - 1) % count])
		for across in 2:
			var p := Vector3.ZERO
			p[width_axis] = (across - 0.5) * width
			p[a_axis] = points[k].x
			p[b_axis] = points[k].y
			var n := Vector3.ZERO
			n[a_axis] = normals[k].x
			n[b_axis] = normals[k].y
			s.vertex(centre + p, n, Vector2(travelled, across))
	for i in count:
		var a := base + i * 2
		s.quad(a, a + 1, a + 3, a + 2)


## A flat strip of ribbon along `points`, `side` giving its width direction.
## `notch` cuts a V into the far end, as ribbon ends are trimmed.
static func _strip(s: MeshPieces, points: PackedVector3Array, sides: PackedVector3Array,
		widths: PackedFloat32Array, notch := 0.0) -> void:
	var base := s.verts.size()
	var travelled := 0.0
	var last := points.size() - 1
	for i in points.size():
		var tangent := (points[mini(i + 1, last)] - points[maxi(i - 1, 0)]).normalized()
		var normal := sides[i].cross(tangent).normalized()
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		for k in 3:
			var across := k * 0.5
			var p := points[i] + sides[i] * (across - 0.5) * widths[i]
			if i == last and k == 1:
				p -= tangent * notch
			s.vertex(p, normal, Vector2(travelled, across))
	for i in last:
		for k in 2:
			var a := base + i * 3 + k
			s.quad(a, a + 1, a + 4, a + 3)


## A full rosette bow: an outer ring of loops lying low, an inner ring standing
## up, two notched tails and a knot in the middle.
static func _bow(s: MeshPieces, top: Vector3, width: float, box_width: float, rng: RandomNumberGenerator) -> void:
	var knot_height := width * 0.8
	var knot := top + Vector3(0, knot_height * 0.45, 0)
	var big := clampf(box_width * 0.27, 0.06, 0.15)
	var loop_width := width * 1.25
	var spin := rng.randf_range(0.0, TAU)
	for i in 7:
		var yaw := spin + TAU * i / 7.0 + rng.randf_range(-0.15, 0.15)
		var length := big * rng.randf_range(0.9, 1.1)
		_loop(s, knot, yaw, deg_to_rad(rng.randf_range(12.0, 22.0)), length, length * 0.55, loop_width)
	for i in 5:
		var yaw := spin + TAU * (i + 0.5) / 5.0 + rng.randf_range(-0.2, 0.2)
		var length := big * rng.randf_range(0.6, 0.75)
		_loop(s, knot + Vector3.UP * width * 0.25, yaw, deg_to_rad(rng.randf_range(45.0, 62.0)), length, length * 0.6, loop_width * 0.9)
	for i in 2:
		var angle := spin + PI / 7.0 + PI * i + rng.randf_range(-0.25, 0.25)
		_tail(s, knot, top.y, Vector3(cos(angle), 0, sin(angle)), big * 1.6, width)
	_band_around(s, knot + Vector3.UP * width * 0.3, Vector3(width * 0.9, knot_height, width * 0.8), knot_height * 0.35, 0, width * 0.85, 0.0, 2)


## One bow loop: out from the knot at `yaw`, rising at `elevation`, up and
## over and back, pinched where it is gathered into the knot.
static func _loop(s: MeshPieces, knot: Vector3, yaw: float, elevation: float, length: float, height: float, width: float) -> void:
	var flat := Vector3(cos(yaw), 0, sin(yaw))
	var dir := flat * cos(elevation) + Vector3.UP * sin(elevation)
	var lift := flat * -sin(elevation) + Vector3.UP * cos(elevation)
	var side := dir.cross(lift).normalized()
	var points := PackedVector3Array()
	var sides := PackedVector3Array()
	var widths := PackedFloat32Array()
	var segs := 16
	for i in segs + 1:
		var t := float(i) / segs
		var a := TAU * t
		var u := length * 0.5 * (1.0 - cos(a))
		var v := height * 0.5 * sin(a)
		points.append(knot + dir * u + lift * v)
		# Loops twist open a little at the far end, as real ribbon does.
		sides.append(side.rotated(dir, sin(a * 0.5) * 0.3))
		widths.append(width * lerpf(0.3, 1.0, smoothstep(0.0, 0.25, t) * smoothstep(1.0, 0.75, t)))
	_strip(s, points, sides, widths)


## A ribbon tail falling from the knot onto the lid, ending in a V notch.
static func _tail(s: MeshPieces, knot: Vector3, top_y: float, dir: Vector3, length: float, width: float) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	var points := PackedVector3Array()
	var sides := PackedVector3Array()
	var widths := PackedFloat32Array()
	var segs := 10
	var rest := top_y + RIBBON_THICKNESS * 2.0 - knot.y
	for i in segs + 1:
		var t := float(i) / segs
		var drop := rest * smoothstep(0.0, 0.35, t)
		var wave := sin(t * PI * 2.0) * width * 0.25 * t
		points.append(knot + dir * length * t + side * wave + Vector3.UP * drop)
		sides.append(side.rotated(dir, sin(t * PI) * 0.4))
		widths.append(width * lerpf(0.4, 1.0, smoothstep(0.0, 0.2, t)))
	_strip(s, points, sides, widths, width * 0.35)


## A kraft-paper gift tag lying on the lid, tied to the bow with a thin cord.
static func _tag(tag: MeshPieces, cord: MeshPieces, size: Vector3, width: float, rng: RandomNumberGenerator) -> void:
	var corner := Vector3(size.x * 0.27 * (1.0 if rng.randf() < 0.5 else -1.0), size.y + 0.004, size.z * 0.24)
	var tag_size := Vector3(0.06, 0.0015, 0.038)
	var turn := rng.randf_range(-0.6, 0.6)
	var start := tag.verts.size()
	_rounded_box(tag, Vector3.ZERO, tag_size, 0.0007, 1)
	var basis := Basis(Vector3.UP, turn)
	for i in range(start, tag.verts.size()):
		tag.verts[i] = corner + basis * tag.verts[i]
		tag.normals[i] = basis * tag.normals[i]
	# The cord runs from the tag's hole up to the knot.
	var hole := corner + basis * Vector3(-tag_size.x * 0.38, 0.001, 0)
	var knot := Vector3(0, size.y + width * 0.4, 0)
	var points := PackedVector3Array()
	var sides := PackedVector3Array()
	var widths := PackedFloat32Array()
	for i in 9:
		var t := i / 8.0
		points.append(hole.lerp(knot, t) + Vector3.UP * sin(t * PI) * 0.012)
		sides.append((knot - hole).cross(Vector3.UP).normalized())
		widths.append(0.003)
	_strip(cord, points, sides, widths)

