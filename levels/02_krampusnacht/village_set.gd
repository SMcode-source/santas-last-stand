class_name VillageSet
extends RefCounted
## The static set of Level 2, "Krampusnacht": the land (the valley the
## flight comes up, the plateau and the gorge), the Alpine village with its
## chalets, the church square and market, the church with its onion-domed
## bell tower, the bridge over the gorge, the forest, and the Alps all round.
## Everything here stands still; the level adds what moves or lights up.
##
## Each region is merged into its own mesh, so the renderer can skip regions
## out of view and each region only gathers the lights near it.

const L := preload("res://levels/02_krampusnacht/village_layout.gd")
const STONE := "old_stone_wall"
const TIMBER := "wood_trunk_wall"
const PLANKS := "brown_planks_04"
const ROCK := "rock_face_03"
const PLASTER := Color("e6dfd2")
const OLD_PLASTER := Color("d9cdb8")
const DARK_TIMBER := Color("6f5240")
const ROOF_PLANKS := Color("5a4538")
const SHUTTER := Color("2f5a3c")
const RED_SHUTTER := Color("7a2a26")
const IRON := Color("25272b")
const COPPER := Color("4f7d69")
const GOLD := Color("d8b25a")
const ROOF_PITCH := 24.0


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "VillageSet"
	root.add_child(_land())
	root.add_child(_gorge())
	root.add_child(_street())
	root.add_child(_square())
	root.add_child(_church())
	root.add_child(_outskirts())
	root.add_child(_alps())
	root.add_child(_bounds())
	return root


# --- The land ---

## One big snowfield over the valley, plateau and far bank, cut by the gorge.
## Split into tiles so each lamp only touches the tiles it reaches.
static func _land() -> Node3D:
	var root := Node3D.new()
	root.name = "Land"
	var noise := FastNoiseLite.new()
	noise.seed = 52
	noise.frequency = 0.02
	var xs: Array[float] = []
	var x := -520.0
	while x <= 520.0:
		xs.append(x)
		x += 10.0
	for edge: float in [L.GORGE_WEST - 0.2, L.GORGE_WEST + 0.8, L.GORGE_EAST - 0.8, L.GORGE_EAST + 0.2]:
		if edge not in xs:
			xs.append(edge)
	xs.sort()
	var zs: Array[float] = []
	var z := -420.0
	while z <= 1260.0:
		zs.append(z)
		z += 10.0
	var heights := []
	for zi in zs.size():
		var row := PackedFloat32Array()
		for xi in xs.size():
			row.append(L.land_height(xs[xi], zs[zi], noise))
		heights.append(row)
	var point := func(xi: int, zi: int) -> Vector3:
		return Vector3(xs[xi], (heights[zi] as PackedFloat32Array)[xi], zs[zi])
	var material := PbrLibrary.snow_ground()
	const TILE := 14
	for tz in range(0, zs.size() - 1, TILE):
		for tx in range(0, xs.size() - 1, TILE):
			var x_end := mini(tx + TILE, xs.size() - 1)
			var z_end := mini(tz + TILE, zs.size() - 1)
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			for zi in range(tz, z_end + 1):
				for xi in range(tx, x_end + 1):
					verts.append(point.call(xi, zi))
					var across: Vector3 = point.call(mini(xi + 1, xs.size() - 1), zi) - point.call(maxi(xi - 1, 0), zi)
					var along: Vector3 = point.call(xi, mini(zi + 1, zs.size() - 1)) - point.call(xi, maxi(zi - 1, 0))
					normals.append(along.cross(across).normalized())
			var width := x_end - tx + 1
			var indices := PackedInt32Array()
			for zi in z_end - tz:
				for xi in x_end - tx:
					var a := zi * width + xi
					indices.append_array([a, a + 1, a + width, a + 1, a + width + 1, a + width])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var grid := ArrayMesh.new()
			grid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			grid.surface_set_material(0, material)
			var tile := MeshInstance3D.new()
			tile.name = "Land%d_%d" % [tx, tz]
			tile.mesh = grid
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(tile)
	# The plateau and the far bank are flat where anyone walks.
	var solid := StaticBody3D.new()
	solid.name = "Ground"
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	for spec: Array in [[Vector3(20.5, -1.0, 10.0), Vector3(99.0, 2.0, 160.0)],
			[Vector3(-58.0, -1.0, 0.0), Vector3(30.0, 2.0, 240.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		shape.shape = box
		shape.position = spec[0]
		solid.add_child(shape)
	root.add_child(solid)
	return root


# --- The gorge and the bridge ---

static func _gorge() -> Node3D:
	var s := SetBuilder.new("Gorge")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var depth := -L.GORGE_FLOOR + 1.0
	# Rock faces down both sides, in rough slabs.
	for side: float in [-1.0, 1.0]:
		var face_x := L.GORGE_EAST if side < 0.0 else L.GORGE_WEST
		var z := -180.0
		while z < 180.0:
			var length := rng.randf_range(6.0, 10.0)
			var size := Vector3(3.0, depth, length + 1.0)
			var at := Vector3(face_x + side * 1.2 + rng.randf_range(-0.25, 0.25), -depth / 2.0 - 0.12, z + length / 2.0)
			s.b.textured(ToyBuilder.lumpy(ToyBuilder.box(size), 0.35, 0.35, int(z)), ROCK,
					ToyBuilder.xf(at, Vector3(rng.randf_range(-2, 2), rng.randf_range(-4, 4), 0)), 3.0, Color("9b9aa0"), 0.5)
			z += length
	# A frozen river at the bottom.
	var river := MeshInstance3D.new()
	river.name = "FrozenRiver"
	var sheet := BoxMesh.new()
	sheet.size = Vector3(L.GORGE_EAST - L.GORGE_WEST, 0.2, 400.0)
	river.mesh = sheet
	river.material_override = WorkshopSet.thin_ice_material()
	river.position = Vector3((L.GORGE_EAST + L.GORGE_WEST) / 2.0, L.GORGE_FLOOR + 0.3, 0.0)
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.root.add_child(river)
	# A low stone wall along the village edge, open at the bridge.
	var wall_x := L.GORGE_EAST + 0.45
	for span: Vector2 in [Vector2(L.BOUNDS.position.y, L.BRIDGE_Z - L.BRIDGE_HALF - 0.6),
			Vector2(L.BRIDGE_Z + L.BRIDGE_HALF + 0.6, L.BOUNDS.end.y)]:
		var length := span.y - span.x
		s.block(Vector3(wall_x, 0.45, (span.x + span.y) / 2.0), Vector3(0.55, 0.9, length), STONE,
				Color("c8c1b6"), true, int(span.x))
	_bridge(s)
	return s.finish("Gorge")


static func _bridge(s: SetBuilder) -> void:
	var z := L.BRIDGE_Z
	var from := L.GORGE_EAST + 0.6
	var to := L.BRIDGE_END_X - 1.0
	var mid := (from + to) / 2.0
	var length := from - to
	# Deck of planks on two heavy beams, with snow along it.
	s.block(Vector3(mid, -0.15, z), Vector3(length, 0.3, L.BRIDGE_HALF * 2.0 + 0.2), PLANKS, Color("9b7a60"), true, 5)
	for side: float in [-1.0, 1.0]:
		s.log_beam(Vector3(mid, -0.45, z + side * (L.BRIDGE_HALF - 0.1)), Vector3(0, 0, 90), 0.22, length + 0.6, false)
		# Railings: posts and a top rail, with crossed braces between.
		var post_z := z + side * (L.BRIDGE_HALF + 0.05)
		var count := int(length / 1.8)
		for k in count + 1:
			var px := from - k * length / count
			s.b.textured(ToyBuilder.box(Vector3(0.14, 1.1, 0.14)), TIMBER, ToyBuilder.xf(Vector3(px, 0.55, post_z)), 1.0,
					DARK_TIMBER, 0.4)
			if k < count:
				var next_x := from - (k + 1) * length / count
				for dir: float in [-1.0, 1.0]:
					var a := Vector3(px, 0.15 if dir > 0 else 0.95, post_z)
					var b := Vector3(next_x, 0.95 if dir > 0 else 0.15, post_z)
					s.b.textured(ToyBuilder.tube(PackedVector3Array([a, b]), PackedFloat32Array([0.04, 0.04]), 5), TIMBER,
							Transform3D.IDENTITY, 1.0, DARK_TIMBER, 0.3)
		s.b.textured(ToyBuilder.box(Vector3(length, 0.1, 0.16)), TIMBER, ToyBuilder.xf(Vector3(mid, 1.12, post_z)), 1.0,
				DARK_TIMBER, 0.6)
		s.collider(Vector3(mid, 0.7, post_z), Vector3(length, 1.4, 0.2))
	# Two stone piers down to the river, and timber struts up to the deck.
	for px: float in [L.GORGE_EAST - 4.6, L.GORGE_WEST + 4.6]:
		var height := -L.GORGE_FLOOR - 0.6
		s.block(Vector3(px, -0.6 - height / 2.0, z), Vector3(2.0, height, 4.2), STONE, Color("a9a39a"), false, int(px))
		for dir: float in [-1.0, 1.0]:
			s.b.textured(ToyBuilder.tube(PackedVector3Array([Vector3(px + dir * 0.8, -6.5, z), Vector3(px + dir * 3.8, -0.6, z)]),
					PackedFloat32Array([0.16, 0.14]), 6), TIMBER, Transform3D.IDENTITY, 1.0, DARK_TIMBER)
	# A gate at the village end: two stone posts and a little shingled roof.
	for side: float in [-1.0, 1.0]:
		s.block(Vector3(from + 0.3, 1.3, z + side * (L.BRIDGE_HALF + 0.45)), Vector3(0.7, 2.6, 0.7), STONE, Color("c8c1b6"), true, 9)
	s.b.textured(ToyBuilder.box(Vector3(0.5, 0.3, L.BRIDGE_HALF * 2.0 + 1.8)), TIMBER, ToyBuilder.xf(Vector3(from + 0.3, 2.75, z)),
			1.0, DARK_TIMBER)
	for side: float in [-1.0, 1.0]:
		var xf := ToyBuilder.xf(Vector3(from + 0.3 + side * 0.45, 3.1, z), Vector3(0, 0, -side * 35))
		s.b.textured(ToyBuilder.box(Vector3(1.1, 0.12, L.BRIDGE_HALF * 2.0 + 2.2)), PLANKS, xf, 1.0, ROOF_PLANKS, 0.8)


# --- The main street and the landing field ---

static func _street() -> Node3D:
	var s := SetBuilder.new("Street")
	var panes := MeshPieces.new()
	for i in 6:
		_chalet(s, panes, L.CHALETS[i])
	for i in 4:
		_lamp_post(s, L.LAMPS[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	# Fences round the landing field.
	for k in 6:
		var fx := -14.0 + k * 5.6
		if absf(fx) < 3.0:
			continue
		s.put(WinterProps.fence(5.0), Vector3(fx, 0, L.BOUNDS.end.y - 0.6), 0.0)
	# Woodpiles against the chalets, and a hay sledge left in the street.
	for spec: Array in [[Vector3(-6.6, 0, 37.0), 90.0], [Vector3(6.8, 0, 22.0), -90.0], [Vector3(-6.4, 0, 12.0), 90.0]]:
		_woodpile(s, spec[0], spec[1], rng)
	_sledge(s, Vector3(3.0, 0, 46.0), -20.0)
	# Drifts piled along the house fronts.
	for spec: Array in L.CHALETS.slice(0, 6):
		var at: Vector3 = spec[0]
		var out := Vector3(-signf(at.x), 0, 0)
		for k in 3:
			var p := at + out * (float(spec[3]) / 2.0 + 0.6) + Vector3(0, 0, (k - 1) * 2.6 + rng.randf_range(-0.5, 0.5))
			WinterProps.add_snow_mound(s.b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.4, 0.7, 1.0)), p), k)
	var root := s.finish("Street")
	panes.add_to((root.get_node("Street") as MeshInstance3D).mesh, WinterProps.window_material())
	return root


## An Alpine chalet: whitewashed ground floor on a stone plinth, a timber
## upper floor with a carved balcony across the front, green shutters, and a
## wide, low roof heaped with snow. `spec` is [centre, yaw, width, depth, seed];
## the front (door, balcony) faces local +z.
static func _chalet(s: SetBuilder, panes: MeshPieces, spec: Array) -> void:
	var at: Vector3 = spec[0]
	var w: float = spec[2]
	var d: float = spec[3]
	var seed: int = spec[4]
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), at)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var plaster := PLASTER if seed % 3 != 0 else OLD_PLASTER
	var shutter := SHUTTER if seed % 4 != 1 else RED_SHUTTER
	var lower := 3.0
	var eave := 5.7
	_put(s, base, ToyBuilder.box(Vector3(w + 0.24, 0.55, d + 0.24)), STONE, Vector3(0, 0.27, 0), Color("bdb6ab"), 1.0, 0.4)
	s.b.finished(ToyBuilder.box(Vector3(w, lower - 0.55, d)), plaster, "leather", base * ToyBuilder.xf(Vector3(0, 0.55 + (lower - 0.55) / 2.0, 0)))
	_put(s, base, ToyBuilder.box(Vector3(w + 0.3, eave - lower, d + 0.3)), TIMBER, Vector3(0, (lower + eave) / 2.0, 0), DARK_TIMBER, 1.6)
	# Corner posts and a beam between the floors.
	_put(s, base, ToyBuilder.box(Vector3(w + 0.42, 0.22, d + 0.42)), TIMBER, Vector3(0, lower, 0), DARK_TIMBER.darkened(0.2), 1.0, 0.5)
	s.collider(base * Vector3(0, eave / 2.0, 0), Vector3(w + 0.3, eave, d + 0.3), base.basis)
	# The roof: ridge from front to back, overhanging all round.
	var pitch := deg_to_rad(ROOF_PITCH)
	var over := 1.1
	var half := w / 2.0 + 0.15 + over
	var ridge := eave + 0.12 + (w / 2.0 + 0.15) * tan(pitch)
	var length := d + 0.3 + over * 2.0
	for side: float in [-1.0, 1.0]:
		var slab_w := half / cos(pitch)
		var xf := base * Transform3D(Basis(Vector3.BACK, side * pitch), Vector3(-side * half / 2.0, ridge - half / 2.0 * tan(pitch) + 0.1, 0))
		s.b.textured(ToyBuilder.box(Vector3(slab_w, 0.22, length)), PLANKS, xf, 1.0, ROOF_PLANKS)
		s.b.textured(ToyBuilder.snow_sheet(Vector2(slab_w - 0.05, length - 0.05), 0.3, seed * 2 + int(side), 0.3), "snow_02",
				xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.11, 0)), 1.5, WinterProps.SNOW_TINT)
		# Icicles along the eave.
		var t := -length / 2.0 + 0.3
		var edge_y := ridge - half * tan(pitch)
		while t < length / 2.0 - 0.3:
			var drip := rng.randf_range(0.15, 0.6)
			s.b.finished(ToyBuilder.cylinder(0.0, rng.randf_range(0.03, 0.06), drip, 5), Color("cfe6f5"), "eye",
					base * ToyBuilder.xf(Vector3(-side * (half - 0.08), edge_y - drip / 2.0, t)))
			t += rng.randf_range(0.3, 0.8)
	# Gable ends of timber under the roof, front and back.
	for end: float in [-1.0, 1.0]:
		var gable := _gable(w + 0.3, ridge - eave, 0.2)
		s.b.textured(gable, TIMBER, base * Transform3D(Basis.IDENTITY, Vector3(0, eave, end * (d / 2.0 + 0.1))), 1.6, DARK_TIMBER)
	# Front: a door, two windows below, three above behind the balcony.
	var front := d / 2.0
	_put(s, base, ToyBuilder.box(Vector3(1.1, 2.1, 0.12)), PLANKS, Vector3(w * 0.22, 1.05 + 0.5, front + 0.03), Color("6b4a35"))
	_put(s, base, ToyBuilder.box(Vector3(1.4, 0.16, 0.6)), PLANKS, Vector3(w * 0.22, 2.75, front + 0.3), ROOF_PLANKS, 1.0, 0.8)
	for wx: float in [-w * 0.33, -w * 0.06]:
		_window(s, panes, base, Vector3(wx, 1.75, front), Vector3.BACK, shutter, true)
	for k in 3:
		_window(s, panes, base, Vector3((k - 1) * w * 0.3, 4.3, front + 0.15), Vector3.BACK, shutter, false)
	# The balcony: a deck on brackets, boarded railing with cut-out hearts.
	var depth := 0.95
	_put(s, base, ToyBuilder.box(Vector3(w + 0.6, 0.14, depth)), PLANKS, Vector3(0, lower + 0.2, front + 0.15 + depth / 2.0),
			Color("8a6a52"), 1.0, 0.7)
	var boards := int((w + 0.6) / 0.24)
	for k in boards:
		var bx := -(w + 0.6) / 2.0 + (k + 0.5) * (w + 0.6) / boards
		_put(s, base, ToyBuilder.box(Vector3(0.2, 0.85, 0.04)), PLANKS, Vector3(bx, lower + 0.7, front + 0.12 + depth), Color("8a6a52"))
	_put(s, base, ToyBuilder.box(Vector3(w + 0.66, 0.1, 0.12)), PLANKS, Vector3(0, lower + 1.15, front + 0.12 + depth), DARK_TIMBER, 1.0, 0.9)
	# Flower boxes under the ground-floor windows, full of snow.
	for wx: float in [-w * 0.33, -w * 0.06]:
		_put(s, base, ToyBuilder.box(Vector3(1.0, 0.22, 0.26)), PLANKS, Vector3(wx, 1.08, front + 0.16), Color("7d5c44"))
		WinterProps.add_snow_mound(s.b, base * Transform3D(Basis.IDENTITY.scaled(Vector3(0.5, 0.12, 0.13)), Vector3(wx, 1.2, front + 0.16)), seed)
	# Sides: two windows a floor.
	for side: float in [-1.0, 1.0]:
		var normal := Vector3(side, 0, 0)
		for k in 2:
			var wz := (k - 0.5) * d * 0.45
			_window(s, panes, base, Vector3(side * w / 2.0, 1.75, wz), normal, shutter, true)
			_window(s, panes, base, Vector3(side * (w / 2.0 + 0.15), 4.3, wz), normal, shutter, false)
	# A chimney through the snow.
	_put(s, base, ToyBuilder.box(Vector3(0.6, 1.6, 0.6)), STONE, Vector3(w * 0.22, ridge - 0.1, -d * 0.2), Color("b8b0a5"), 1.0, 0.6)


## A window on a wall: frame, sill, glass (a pane with curtains, glowing when
## the lights are on) and a pair of open shutters. `at` is the middle of the
## window on the wall's face, `normal` points out (both in chalet space).
## A textured part of something placed at `base`.
static func _put(s: SetBuilder, base: Transform3D, mesh: Mesh, texture: String, pos: Vector3, tint: Color,
		tile := 1.0, snow := 0.0, rot := Vector3.ZERO) -> void:
	s.b.textured(mesh, texture, base * ToyBuilder.xf(pos, rot), tile, tint, snow)


static func _window(s: SetBuilder, panes: MeshPieces, base: Transform3D, at: Vector3, normal: Vector3,
		shutter: Color, painted_frame: bool) -> void:
	var side := Vector3.UP.cross(normal)
	var frame_size := Vector3(0.95, 1.15, 0.1)
	var face := Basis(side, Vector3.UP, normal)
	var frame_color := Color("f0ebe0") if painted_frame else DARK_TIMBER.lightened(0.1)
	s.b.finished(ToyBuilder.box(frame_size), frame_color, "leather", base * Transform3D(face, at + normal * 0.03))
	s.b.textured(ToyBuilder.box(Vector3(1.05, 0.08, 0.2)), STONE if painted_frame else PLANKS,
			base * Transform3D(face, at + normal * 0.08 + Vector3(0, -0.6, 0)), 1.0, Color("cfc8bc"), 0.8)
	var glass_at := base * (at + normal * 0.085)
	panes.rect(glass_at, base.basis * normal, Vector3.UP, Vector2(0.76, 0.96))
	# Mullions over the glass.
	s.b.finished(ToyBuilder.box(Vector3(0.04, 0.96, 0.03)), frame_color, "leather", base * Transform3D(face, at + normal * 0.1))
	s.b.finished(ToyBuilder.box(Vector3(0.76, 0.04, 0.03)), frame_color, "leather", base * Transform3D(face, at + normal * 0.1 + Vector3(0, 0.12, 0)))
	for dir: float in [-1.0, 1.0]:
		s.b.finished(ToyBuilder.box(Vector3(0.46, 1.12, 0.04)), shutter, "leather",
				base * Transform3D(face, at + side * dir * 0.74 + normal * 0.06))


## A triangular gable `width` across and `height` tall at the peak, `depth`
## thick, its base at y = 0.
static func _gable(width: float, height: float, depth: float) -> ArrayMesh:
	var w := width / 2.0
	var d := depth / 2.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		for p: Vector3 in [a, b, c]:
			verts.append(p)
			normals.append(n)
	for z: float in [-d, d]:
		var a := Vector3(-w, 0, z)
		var b := Vector3(w, 0, z)
		var c := Vector3(0, height, z)
		if z > 0.0:
			tri.call(a, b, c)
		else:
			tri.call(b, a, c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A cast-iron street lamp with its lantern cage empty: the level puts the
## flame in, lit or not.
static func _lamp_post(s: SetBuilder, at: Vector3) -> void:
	s.b.finished(ToyBuilder.cylinder(0.15, 0.2, 0.12, 12), IRON, "metal", ToyBuilder.xf(at + Vector3(0, 0.06, 0)))
	s.b.finished(ToyBuilder.cylinder(0.1, 0.14, 0.35, 12), IRON, "metal", ToyBuilder.xf(at + Vector3(0, 0.29, 0)))
	s.b.finished(ToyBuilder.cylinder(0.045, 0.06, 2.4, 10), IRON, "metal", ToyBuilder.xf(at + Vector3(0, 1.6, 0)))
	for ring_y: float in [0.5, 1.0, 2.62]:
		s.b.finished(ToyBuilder.torus(0.06, 0.018, 14, 6), IRON, "metal", ToyBuilder.xf(at + Vector3(0, ring_y, 0)))
	s.b.finished(ToyBuilder.cylinder(0.13, 0.08, 0.1, 12), IRON, "metal", ToyBuilder.xf(at + Vector3(0, 2.76, 0)))
	var lantern := Vector3(0, 2.98, 0)
	for k in 6:
		var a := TAU * k / 6.0
		s.b.finished(ToyBuilder.box(Vector3(0.022, 0.4, 0.022)), IRON, "metal", ToyBuilder.xf(at + lantern + Vector3(cos(a) * 0.115, 0, sin(a) * 0.115)))
	s.b.finished(ToyBuilder.cylinder(0.14, 0.13, 0.03, 6), IRON, "metal", ToyBuilder.xf(at + lantern + Vector3(0, -0.2, 0), Vector3(0, 30, 0)))
	s.b.finished(ToyBuilder.cylinder(0.0, 0.21, 0.18, 6), IRON, "metal", ToyBuilder.xf(at + lantern + Vector3(0, 0.29, 0), Vector3(0, 30, 0)))
	s.b.textured(ToyBuilder.lumpy(ToyBuilder.cylinder(0.05, 0.22, 0.1, 12), 0.012, 9.0, 5), "snow_02",
			ToyBuilder.xf(at + lantern + Vector3(0, 0.27, 0)), 1.5, WinterProps.SNOW_TINT)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.16
	cylinder.height = 3.2
	s.add_shape(cylinder, Transform3D(Basis.IDENTITY, at + Vector3(0, 1.6, 0)))


static func _woodpile(s: SetBuilder, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	for row in 4:
		for k in 6 - row:
			var p := at + basis * Vector3((k - (5 - row) / 2.0) * 0.3 + rng.randf_range(-0.02, 0.02), 0.15 + row * 0.26, 0)
			s.log_beam(p, Vector3(90, yaw, 0), 0.14, 0.9 + rng.randf_range(-0.1, 0.1), false)
	s.collider(at + Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 1.0) if absf(yaw) < 45.0 else Vector3(1.0, 1.1, 2.0))


## A wooden hay sledge, its runners curled up at the front.
static func _sledge(s: SetBuilder, at: Vector3, yaw: float) -> void:
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	for side: float in [-1.0, 1.0]:
		s.b.textured(ToyBuilder.curve(PackedVector3Array([Vector3(side * 0.55, 0.06, -1.3), Vector3(side * 0.55, 0.05, 0.9),
				Vector3(side * 0.55, 0.3, 1.45), Vector3(side * 0.55, 0.7, 1.4)]), PackedFloat32Array([0.05, 0.05, 0.05, 0.04]), 6, 5),
				TIMBER, base, 1.0, DARK_TIMBER, 0.4)
		for z: float in [-1.0, 0.0, 0.9]:
			s.b.textured(ToyBuilder.box(Vector3(0.08, 0.4, 0.08)), TIMBER, base * ToyBuilder.xf(Vector3(side * 0.55, 0.26, z)), 1.0, DARK_TIMBER)
	s.b.textured(ToyBuilder.box(Vector3(1.3, 0.08, 2.4)), PLANKS, base * ToyBuilder.xf(Vector3(0, 0.48, -0.1)), 1.0, Color("8a6a52"), 0.8)
	s.b.textured(ToyBuilder.lumpy(ToyBuilder.box(Vector3(1.1, 0.5, 2.0)), 0.08, 2.0, 3), "snow_02",
			base * ToyBuilder.xf(Vector3(0, 0.75, -0.1)), 1.5, Color("d9c48a"))
	s.collider(at + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 2.6), Basis(Vector3.UP, deg_to_rad(yaw)))


# --- The square ---

static func _square() -> Node3D:
	var s := SetBuilder.new("Square")
	var panes := MeshPieces.new()
	# Cobbles under a dusting of snow.
	s.b.textured(ToyBuilder.cylinder(L.SQUARE_RADIUS, L.SQUARE_RADIUS, 0.06, 48), STONE,
			ToyBuilder.xf(L.SQUARE + Vector3(0, 0.0, -2.0)), 0.7, Color("aaa49b"), 0.55)
	s.b.textured(ToyBuilder.box(Vector3(14.0, 0.06, 4.0)), STONE, ToyBuilder.xf(Vector3(-22.0, 0.0, L.BRIDGE_Z)), 0.7, Color("aaa49b"), 0.6)
	for i in range(6, 10):
		_chalet(s, panes, L.CHALETS[i])
	for i in range(4, 8):
		_lamp_post(s, L.LAMPS[i])
	for spec: Array in L.STALLS:
		_stall(s, spec[0], spec[1])
	s.put(WinterProps.fir_tree(7.5, 9, true, 0.9, 0.6), L.CHRISTMAS_TREE)
	s.collider(L.CHRISTMAS_TREE + Vector3(0, 1.5, 0), Vector3(1.4, 3.0, 1.4))
	# Benches round the edge.
	for spec: Array in [[Vector3(-11.5, 0, -4.5), 90.0], [Vector3(11.8, 0, -1.0), -90.0]]:
		var base := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), spec[0])
		s.b.textured(ToyBuilder.box(Vector3(1.8, 0.08, 0.45)), PLANKS, base * ToyBuilder.xf(Vector3(0, 0.45, 0)), 1.0, Color("8a6a52"), 0.8)
		s.b.textured(ToyBuilder.box(Vector3(1.8, 0.4, 0.06)), PLANKS, base * ToyBuilder.xf(Vector3(0, 0.75, -0.22), Vector3(-10, 0, 0)), 1.0,
				Color("8a6a52"))
		for bx: float in [-0.75, 0.75]:
			s.b.finished(ToyBuilder.box(Vector3(0.06, 0.45, 0.42)), IRON, "metal", base * ToyBuilder.xf(Vector3(bx, 0.22, 0)))
		s.collider(base * Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.5), base.basis)
	var root := s.finish("Square")
	panes.add_to((root.get_node("Square") as MeshInstance3D).mesh, WinterProps.window_material())
	return root


## A Christmas-market stall, shuttered for the night: a counter, a gabled
## roof under snow, a pine garland along the front and gingerbread hearts.
static func _stall(s: SetBuilder, at: Vector3, yaw: float) -> void:
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	var w := 3.0
	var d := 1.8
	_put(s, base, ToyBuilder.box(Vector3(w, 1.0, 0.1)), PLANKS, Vector3(0, 0.5, d / 2.0), Color("8a6a52"))
	_put(s, base, ToyBuilder.box(Vector3(w + 0.2, 0.08, 0.5)), PLANKS, Vector3(0, 1.04, d / 2.0 + 0.1), Color("6f5240"), 1.0, 0.8)
	_put(s, base, ToyBuilder.box(Vector3(w, 2.4, 0.1)), PLANKS, Vector3(0, 1.2, -d / 2.0), Color("8a6a52"))
	for side: float in [-1.0, 1.0]:
		_put(s, base, ToyBuilder.box(Vector3(0.1, 2.4, d)), PLANKS, Vector3(side * w / 2.0, 1.2, 0), Color("8a6a52"))
		_put(s, base, ToyBuilder.box(Vector3(0.14, 2.6, 0.14)), PLANKS, Vector3(side * w / 2.0, 1.3, d / 2.0), DARK_TIMBER)
		var tilt := Vector3(0, 0, -side * 28.0)
		_put(s, base, ToyBuilder.box(Vector3(w / 2.0 / cos(deg_to_rad(28.0)) + 0.3, 0.1, d + 0.7)), PLANKS,
				Vector3(side * w / 4.0, 2.75, 0.1), ROOF_PLANKS, 1.0, 0.0, tilt)
		s.b.textured(ToyBuilder.snow_sheet(Vector2(w / 2.0 + 0.3, d + 0.6), 0.18, int(at.x) + int(side), 0.2), "snow_02",
				base * ToyBuilder.xf(Vector3(side * w / 4.0, 2.82, 0.1), tilt), 1.5, WinterProps.SNOW_TINT)
	# Shutters pulled down over the counter.
	_put(s, base, ToyBuilder.box(Vector3(w - 0.2, 1.3, 0.06)), PLANKS, Vector3(0, 1.75, d / 2.0 - 0.05), Color("9b7a60"))
	# A pine garland swagged along the front, with red bows.
	var pine := ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.15, 3.0, 4)
	for k in 24:
		var t := k / 23.0
		var p := Vector3(lerpf(-w / 2.0, w / 2.0, t), 2.45 - sin(t * PI * 2.0) * 0.0 - sin(fposmod(t * 2.0, 1.0) * PI) * 0.18, d / 2.0 + 0.12)
		s.b.finished(pine, Color("2c4a30"), "eye", base * ToyBuilder.xf(p, Vector3(k * 31, k * 47, 0), Vector3(0.11, 0.07, 0.08)))
	for bx: float in [-w / 2.0, 0.0, w / 2.0]:
		s.b.finished(ToyBuilder.torus(0.05, 0.02, 10, 6), Color("a51f24"), "velvet",
				base * ToyBuilder.xf(Vector3(bx, 2.47, d / 2.0 + 0.16), Vector3(90, 0, 0), Vector3(1.4, 1, 0.8)))
	# Gingerbread hearts hung from the eaves.
	for k in 4:
		var hx := -w / 2.0 + 0.45 + k * (w - 0.9) / 3.0
		s.b.finished(ToyBuilder.cylinder(0.12, 0.12, 0.03, 12), Color("8a5a2c"), "leather",
				base * ToyBuilder.xf(Vector3(hx, 2.15, d / 2.0 + 0.14), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.9)))
		s.b.finished(ToyBuilder.torus(0.09, 0.008, 14, 4), Color("f2ead8"), "leather",
				base * ToyBuilder.xf(Vector3(hx, 2.15, d / 2.0 + 0.16), Vector3(90, 0, 0)))
	s.collider(base * Vector3(0, 1.3, 0), Vector3(w + 0.2, 2.6, d + 0.2), base.basis)


# --- The church ---

static func _church() -> Node3D:
	var s := SetBuilder.new("Church")
	var t := L.TOWER
	var half := L.TOWER_HALF
	var top := L.TOWER_HEIGHT
	s.b.textured(ToyBuilder.box(Vector3(half * 2.0 + 0.5, 1.0, half * 2.0 + 0.5)), STONE, ToyBuilder.xf(t + Vector3(0, 0.5, 0)), 1.0,
			Color("bdb6ab"), 0.5)
	s.b.finished(ToyBuilder.box(Vector3(half * 2.0, top - 1.0, half * 2.0)), PLASTER, "leather", ToyBuilder.xf(t + Vector3(0, (top + 1.0) / 2.0, 0)))
	s.collider(t + Vector3(0, top / 2.0, 0), Vector3(half * 2.0 + 0.5, top, half * 2.0 + 0.5))
	# Stone quoins up the corners.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var y := 1.0
			var k := 0
			while y < top - 0.3:
				var long := k % 2 == 0
				var size := Vector3(0.75 if long else 0.45, 0.42, 0.45 if long else 0.75)
				var at := t + Vector3(cx * (half - size.x / 2.0 + 0.04), y + 0.21, cz * (half - size.z / 2.0 + 0.04))
				s.b.textured(ToyBuilder.box(size), STONE, ToyBuilder.xf(at), 0.8, Color("cfc8bc"))
				y += 0.46
				k += 1
	# String courses: under the clocks, the belfry ledge, the top.
	for y: float in [8.8, L.BELFRY_Y - 0.1, top]:
		s.b.textured(ToyBuilder.box(Vector3(half * 2.0 + 0.36, 0.22, half * 2.0 + 0.36)), STONE, ToyBuilder.xf(t + Vector3(0, y, 0)), 1.0,
				Color("d5cfc4"), 0.7)
	# The belfry ledge out front, where Krampus perches.
	s.b.textured(ToyBuilder.box(Vector3(half * 2.0 + 0.4, 0.25, 0.9)), STONE, ToyBuilder.xf(Vector3(t.x, L.BELFRY_Y - 0.12, t.z + half + 0.3)), 1.0,
			Color("d5cfc4"), 0.8)
	# On each face: a clock, and above it the arched belfry openings.
	for k in 4:
		var yaw := k * PI / 2.0
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var basis := Basis(Vector3.UP, yaw)
		var face := t + normal * (half + 0.02)
		var clock := face + Vector3(0, 10.3, 0)
		s.b.finished(ToyBuilder.cylinder(0.95, 0.95, 0.06, 32), Color("f0ead8"), "leather", Transform3D(basis * Basis(Vector3.RIGHT, PI / 2.0), clock))
		s.b.finished(ToyBuilder.torus(0.95, 0.06, 32, 6), GOLD, "metal", Transform3D(basis * Basis(Vector3.RIGHT, PI / 2.0), clock + normal * 0.04))
		for h in 12:
			var a := TAU * h / 12.0
			s.b.finished(ToyBuilder.box(Vector3(0.05, 0.16, 0.02)), Color("2a2620"), "leather",
					Transform3D(basis * Basis(Vector3.BACK, -a), clock + normal * 0.05 + basis * Vector3(sin(a) * 0.78, cos(a) * 0.78, 0)))
		# Hands stopped at a quarter to twelve.
		s.b.finished(ToyBuilder.box(Vector3(0.07, 0.62, 0.02)), Color("1d1a16"), "metal",
				Transform3D(basis, clock + normal * 0.07 + basis * Vector3(0, 0.28, 0)))
		s.b.finished(ToyBuilder.box(Vector3(0.08, 0.45, 0.02)), Color("1d1a16"), "metal",
				Transform3D(basis * Basis(Vector3.BACK, PI / 2.0), clock + normal * 0.08 + basis * Vector3(-0.2, 0, 0)))
		for opening in 2:
			var side := (opening - 0.5) * 2.0 * 1.1
			var arch := face + basis * Vector3(side, L.BELFRY_Y + 1.3, 0)
			s.b.add(ToyBuilder.box(Vector3(0.95, 2.1, 0.1)), Color("120f0d"), Transform3D(basis, arch + normal * 0.0))
			s.b.add(ToyBuilder.cylinder(0.475, 0.475, 0.1, 14), Color("120f0d"),
					Transform3D(basis * Basis(Vector3.RIGHT, PI / 2.0), arch + Vector3(0, 1.05, 0)))
			s.b.textured(ToyBuilder.torus(0.53, 0.07, 16, 6), STONE, Transform3D(basis * Basis(Vector3.RIGHT, PI / 2.0),
					arch + Vector3(0, 1.05, 0) + normal * 0.04), 0.8, Color("d5cfc4"))
			for jamb: float in [-1.0, 1.0]:
				s.b.textured(ToyBuilder.box(Vector3(0.14, 2.1, 0.14)), STONE, Transform3D(basis, arch + basis * Vector3(jamb * 0.54, 0, 0) + normal * 0.04),
						0.8, Color("d5cfc4"))
	# The door at the foot of the tower, under a little porch roof.
	var door := L.DOOR + Vector3(0, 0, -0.38)
	s.b.textured(ToyBuilder.box(Vector3(1.7, 2.6, 0.12)), PLANKS, ToyBuilder.xf(door + Vector3(0, 1.3, 0)), 1.0, Color("5e3f2c"))
	s.b.textured(ToyBuilder.cylinder(0.85, 0.85, 0.12, 16), PLANKS, ToyBuilder.xf(door + Vector3(0, 2.6, 0), Vector3(90, 0, 0)), 1.0, Color("5e3f2c"))
	s.b.textured(ToyBuilder.torus(0.95, 0.12, 20, 6), STONE, ToyBuilder.xf(door + Vector3(0, 2.6, 0.06), Vector3(90, 0, 0)), 0.8, Color("cfc8bc"))
	for jamb: float in [-1.0, 1.0]:
		s.b.textured(ToyBuilder.box(Vector3(0.24, 2.6, 0.24)), STONE, ToyBuilder.xf(door + Vector3(jamb * 0.95, 1.3, 0.06)), 0.8, Color("cfc8bc"))
	for k in 12:
		s.b.finished(ToyBuilder.sphere(0.03, 6), IRON, "metal", ToyBuilder.xf(door + Vector3((k % 4 - 1.5) * 0.36, 0.5 + floorf(k / 4.0) * 0.8, 0.07)))
	for side: float in [-1.0, 1.0]:
		var xf := ToyBuilder.xf(door + Vector3(side * 0.7, 3.95, 0.55), Vector3(0, 0, -side * 32))
		s.b.textured(ToyBuilder.box(Vector3(1.65, 0.1, 1.5)), PLANKS, xf, 1.0, ROOF_PLANKS)
		s.b.textured(ToyBuilder.snow_sheet(Vector2(1.6, 1.45), 0.18, 3 + int(side), 0.2), "snow_02",
				xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), 1.5, WinterProps.SNOW_TINT)
	# The onion dome: a copper bulb, a little lantern, a second bulb, the cross.
	var dome := ToyBuilder.lathe(PackedVector2Array([
		Vector2(half + 0.15, 0.0), Vector2(half + 0.15, 0.35), Vector2(half - 0.25, 0.6), Vector2(half - 0.05, 1.2),
		Vector2(half + 0.15, 1.9), Vector2(half - 0.1, 2.7), Vector2(1.3, 3.5), Vector2(0.55, 4.1), Vector2(0.38, 4.5),
		Vector2(0.55, 4.6), Vector2(0.55, 5.4), Vector2(0.3, 5.6), Vector2(0.5, 6.0), Vector2(0.42, 6.4), Vector2(0.14, 6.8),
		Vector2(0.06, 7.4), Vector2(0.0, 7.45),
	]), 16)
	s.b.finished(dome, COPPER, "leather", ToyBuilder.xf(t + Vector3(0, top + 0.1, 0)))
	s.b.textured(ToyBuilder.snow_ring(half + 0.05, 0.12, 16), "snow_02", ToyBuilder.xf(t + Vector3(0, top + 0.45, 0)), 1.5, WinterProps.SNOW_TINT)
	var cross := t + Vector3(0, top + 7.5, 0)
	s.b.finished(ToyBuilder.sphere(0.16, 12), GOLD, "metal", ToyBuilder.xf(cross))
	s.b.finished(ToyBuilder.box(Vector3(0.08, 1.2, 0.08)), GOLD, "metal", ToyBuilder.xf(cross + Vector3(0, 0.7, 0)))
	s.b.finished(ToyBuilder.box(Vector3(0.6, 0.08, 0.08)), GOLD, "metal", ToyBuilder.xf(cross + Vector3(0, 0.95, 0)))

	# The nave behind, with tall arched windows and a steep snowy roof.
	var n := L.NAVE
	var size := L.NAVE_SIZE
	s.b.textured(ToyBuilder.box(Vector3(size.x + 0.4, 0.8, size.z + 0.2)), STONE, ToyBuilder.xf(n + Vector3(0, 0.4, 0)), 1.0, Color("bdb6ab"), 0.5)
	s.b.finished(ToyBuilder.box(Vector3(size.x, size.y - 0.8, size.z)), PLASTER, "leather", ToyBuilder.xf(n + Vector3(0, (size.y + 0.8) / 2.0, 0)))
	s.collider(n + Vector3(0, size.y / 2.0, 0), size + Vector3(0.4, 0, 0))
	for spec: Array in L.church_windows():
		var at: Vector3 = spec[0]
		var normal: Vector3 = spec[1]
		var basis := Basis(Vector3.UP, atan2(normal.x, normal.z))
		s.b.textured(ToyBuilder.box(Vector3(1.5, 2.9, 0.14)), STONE, Transform3D(basis, at - normal * 0.02), 0.8, Color("d5cfc4"))
		s.b.textured(ToyBuilder.cylinder(0.75, 0.75, 0.14, 14), STONE,
				Transform3D(basis * Basis(Vector3.RIGHT, PI / 2.0), at + Vector3(0, 1.45, 0) - normal * 0.02), 0.8, Color("d5cfc4"))
	var pitch := deg_to_rad(52.0)
	var roof_half := size.x / 2.0 + 0.6
	var ridge := size.y + 0.1 + (size.x / 2.0) * tan(pitch)
	for side: float in [-1.0, 1.0]:
		var slab_w := roof_half / cos(pitch)
		var xf := Transform3D(Basis(Vector3.BACK, side * pitch), n + Vector3(-side * roof_half / 2.0, ridge - roof_half / 2.0 * tan(pitch) + 0.1, 0))
		s.b.textured(ToyBuilder.box(Vector3(slab_w, 0.24, size.z + 0.8)), PLANKS, xf, 1.0, Color("4a3a32"))
		s.b.textured(ToyBuilder.snow_sheet(Vector2(slab_w - 0.1, size.z + 0.7), 0.2, 40 + int(side), 0.3), "snow_02",
				xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), 1.5, WinterProps.SNOW_TINT)
	var back_gable := _gable(size.x, ridge - size.y, 0.3)
	s.b.finished(back_gable, PLASTER, "leather", Transform3D(Basis.IDENTITY, n + Vector3(0, size.y, -size.z / 2.0 + 0.15)))
	s.b.finished(back_gable, PLASTER, "leather", Transform3D(Basis.IDENTITY, n + Vector3(0, size.y, size.z / 2.0 - 0.15)))
	# The rounded apse at the back, with its own cone roof.
	var apse := n + Vector3(0, 0, -size.z / 2.0)
	s.b.finished(ToyBuilder.cylinder(3.4, 3.4, size.y - 1.4, 20), PLASTER, "leather", ToyBuilder.xf(apse + Vector3(0, (size.y - 1.4) / 2.0, 0)))
	s.b.textured(ToyBuilder.cylinder(0.2, 3.9, 2.8, 20), PLANKS, ToyBuilder.xf(apse + Vector3(0, size.y - 1.4 + 1.4, 0)), 1.0, Color("4a3a32"), 0.8)
	var apse_shape := CylinderShape3D.new()
	apse_shape.radius = 3.4
	apse_shape.height = size.y
	s.add_shape(apse_shape, Transform3D(Basis.IDENTITY, apse + Vector3(0, size.y / 2.0, 0)))
	# A few old gravestones in the snow beside the church.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1620
	for k in 7:
		var side := -1.0 if k % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(6.2, 8.5), 0, n.z + rng.randf_range(-6.0, 5.0))
		var basis := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.08))
		if k % 3 == 0:
			s.b.finished(ToyBuilder.box(Vector3(0.06, 1.1, 0.06)), IRON, "metal", Transform3D(basis, at + Vector3(0, 0.55, 0)))
			s.b.finished(ToyBuilder.box(Vector3(0.5, 0.06, 0.06)), IRON, "metal", Transform3D(basis, at + Vector3(0, 0.82, 0)))
		else:
			s.b.textured(ToyBuilder.box(Vector3(0.6, 0.85, 0.14)), STONE, Transform3D(basis, at + Vector3(0, 0.4, 0)), 0.6, Color("9e988f"), 0.6)
	return s.finish("Church")


# --- Further out ---

static func _outskirts() -> Node3D:
	var s := SetBuilder.new("Outskirts")
	var panes := MeshPieces.new()
	for i in range(10, L.CHALETS.size()):
		_chalet(s, panes, L.CHALETS[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	const VARIANTS := 4
	const VARIANT_HEIGHT := 6.0
	var placements: Array[Array] = []
	for v in VARIANTS:
		placements.append([] as Array[Transform3D])
	var noise := FastNoiseLite.new()
	noise.seed = 52
	noise.frequency = 0.02
	var count := 0
	var tries := 0
	while count < 260 and tries < 4000:
		tries += 1
		var at := Vector3(rng.randf_range(-120.0, 140.0), 0, rng.randf_range(-140.0, 200.0))
		if not _wooded(at):
			continue
		at.y = L.land_height(at.x, at.z, noise) - 0.2
		var size := rng.randf_range(4.5, 9.0) / VARIANT_HEIGHT
		placements[count % VARIANTS].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at))
		count += 1
	for v in VARIANTS:
		var tree := WinterProps.fir_tree(VARIANT_HEIGHT, 50 + v, false, 0.6, 0.65)
		var mesh: Mesh = (tree.get_node("Mesh") as MeshInstance3D).mesh
		tree.free()
		var forest := WinterProps.scatter(mesh, placements[v], false)
		forest.name = "Forest%d" % v
		forest.add_to_group(GraphicsQuality.SHADOWS_ON_HIGH)
		s.root.add_child(forest)
	var root := s.finish("Outskirts")
	panes.add_to((root.get_node("Outskirts") as MeshInstance3D).mesh, WinterProps.window_material())
	return root


## Where the forest grows: outside the village, off the gorge and the
## bridge, and clear of the flight's way in.
static func _wooded(at: Vector3) -> bool:
	var b := L.BOUNDS.grow(4.0)
	if b.has_point(Vector2(at.x, at.z)):
		return false
	if at.x > L.GORGE_WEST - 3.0 and at.x < L.GORGE_EAST + 3.0:
		return false
	if absf(at.z - L.BRIDGE_Z) < 7.0 and at.x < L.GORGE_WEST and at.x > L.GORGE_WEST - 18.0:
		return false
	# The landing approach, up the valley from the south.
	if at.z > 40.0 and absf(at.x) < 22.0:
		return false
	for spec: Array in L.CHALETS:
		if (spec[0] as Vector3).distance_to(at) < 7.0:
			return false
	return true


# --- The Alps ---

## Snowy peaks along both sides of the flight's way up the valley, and all
## round the village except where the valley comes in, in one mesh.
static func _alps() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1805
	var curve := L.flight_curve()
	var length := curve.get_baked_length()
	var samples := PackedVector3Array()
	var d := 0.0
	while d <= length:
		samples.append(curve.sample_baked(d))
		d += 20.0
	var peaks := []
	# Along the flight.
	d = 40.0
	while d < length - 160.0:
		var p := curve.sample_baked(d)
		var ahead := (curve.sample_baked(d + 5.0) - p).normalized()
		var side := Vector3(ahead.z, 0, -ahead.x).normalized()
		for dir: float in [-1.0, 1.0]:
			var height := rng.randf_range(90.0, 170.0)
			var radius := height * rng.randf_range(0.65, 0.85)
			var at := p + side * dir * (radius * 0.75 + rng.randf_range(30.0, 70.0))
			peaks.append([Vector3(at.x, 0, at.z), radius, height])
		d += rng.randf_range(70.0, 110.0)
	# Round the village.
	for k in 14:
		var angle := lerpf(-PI * 0.78, PI * 0.78, k / 13.0) + rng.randf_range(-0.06, 0.06)
		var dist := rng.randf_range(230.0, 330.0)
		var height := rng.randf_range(130.0, 210.0)
		peaks.append([Vector3(sin(angle + PI) * dist, 0, cos(angle + PI) * dist), height * 0.8, height])
	# Push any peak that would stand in the way of the flight aside.
	for peak: Array in peaks:
		for q in samples:
			var at: Vector3 = peak[0]
			var height: float = peak[2]
			if q.y >= height * 0.9:
				continue
			var reach: float = peak[1] * pow(1.0 - q.y / height, 1.15) * 1.25 + 14.0
			var flat := Vector2(at.x - q.x, at.z - q.z)
			if flat.length() < reach:
				var out := flat.normalized() if flat.length() > 0.1 else Vector2.RIGHT
				var moved := Vector2(q.x, q.z) + out * reach
				peak[0] = Vector3(moved.x, 0, moved.y)
	var mesh := _peaks_mesh(peaks)
	var instance := MeshInstance3D.new()
	instance.name = "Alps"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _peaks_mesh(peaks: Array) -> ArrayMesh:
	var ridges := FastNoiseLite.new()
	ridges.seed = 9
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 4
	ridges.frequency = 0.9
	const AROUND := 22
	const RINGS := 12
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for n in peaks.size():
		var peak: Array = peaks[n]
		var at: Vector3 = peak[0]
		var radius: float = peak[1]
		var height: float = peak[2]
		var base := verts.size()
		for j in RINGS:
			var t := float(j) / RINGS
			var ring := radius * pow(1.0 - t, 1.15)
			for i in AROUND:
				var a := TAU * i / AROUND
				var ridge := ridges.get_noise_3d(cos(a) * 1.4, t * 2.2, sin(a) * 1.4 + n * 7.3) * 0.5 + 0.5
				var r := ring * (0.7 + ridge * 0.6)
				verts.append(at + Vector3(cos(a) * r, height * t - 6.0 + ridge * height * 0.05 * (1.0 - t), sin(a) * r))
		verts.append(at + Vector3(0, height - 6.0, 0))
		var tip := verts.size() - 1
		for j in RINGS - 1:
			for i in AROUND:
				var a := base + j * AROUND + i
				var b := base + j * AROUND + (i + 1) % AROUND
				indices.append_array([a, b, a + AROUND, b, b + AROUND, a + AROUND])
		for i in AROUND:
			indices.append_array([base + (RINGS - 1) * AROUND + i, base + (RINGS - 1) * AROUND + (i + 1) % AROUND, tip])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, indices.size(), 3):
		var face := (verts[indices[t + 1]] - verts[indices[t]]).cross(verts[indices[t + 2]] - verts[indices[t]])
		for k in 3:
			normals[indices[t + k]] += face
	for k in normals.size():
		normals[k] = normals[k].normalized()
		if normals[k].y < 0.0:
			normals[k] = -normals[k]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rock := PbrLibrary.snowy(ROCK, 16.0, Color("c8cbd4"), 0.6, 40.0, 120.0).duplicate()
	rock.set_shader_parameter("detail_maps", false)
	mesh.surface_set_material(0, rock)
	return mesh


# --- Invisible walls ---

## Keeps Santa in the village and on the bridge (helpers are not stopped).
static func _bounds() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = PhysicsLayers.WALKER_BOUNDS
	body.collision_mask = 0
	var b := L.BOUNDS
	var walls := [
		[Vector3((b.position.x + b.end.x) / 2.0, 3.0, b.end.y), Vector3(b.size.x, 6.0, 0.4)],
		[Vector3((b.position.x + b.end.x) / 2.0, 3.0, b.position.y), Vector3(b.size.x, 6.0, 0.4)],
		[Vector3(b.end.x, 3.0, (b.position.y + b.end.y) / 2.0), Vector3(0.4, 6.0, b.size.y)],
		[Vector3(L.BRIDGE_END_X, 3.0, L.BRIDGE_Z), Vector3(0.4, 6.0, L.BRIDGE_HALF * 2.0 + 1.0)],
	]
	var gap_lo := L.BRIDGE_Z - L.BRIDGE_HALF - 0.2
	var gap_hi := L.BRIDGE_Z + L.BRIDGE_HALF + 0.2
	walls.append([Vector3(b.position.x, 3.0, (b.position.y + gap_lo) / 2.0), Vector3(0.4, 6.0, gap_lo - b.position.y)])
	walls.append([Vector3(b.position.x, 3.0, (gap_hi + b.end.y) / 2.0), Vector3(0.4, 6.0, b.end.y - gap_hi)])
	var bridge_len := b.position.x - L.BRIDGE_END_X
	for side: float in [-1.0, 1.0]:
		walls.append([Vector3(b.position.x - bridge_len / 2.0, 3.0, L.BRIDGE_Z + side * (L.BRIDGE_HALF + 0.2)), Vector3(bridge_len, 6.0, 0.3)])
	for wall: Array in walls:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		shape.position = wall[0]
		body.add_child(shape)
	return body
