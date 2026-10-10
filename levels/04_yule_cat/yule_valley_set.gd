class_name YuleValleySet
extends RefCounted
## The static set of Level 4, "The Yule Cat Prowls": Grýla's valley in
## Iceland. Snow-buried turf houses with timber gable fronts along a trodden
## lane, the square with its frozen pond and fish racks, the Red Caps'
## palisaded barracks, the old sheep track behind its turf wall, and the
## basalt cliff at the head of the valley with Grýla's cave in it.
## Everything here stands still; the level adds what moves or lights up
## (lanterns, fires, the cage, the sheep gate, Door-Slammer's door).
##
## Each region is merged into its own mesh, so the renderer can skip regions
## out of view and each region only gathers the lights near it.

const L := preload("res://levels/04_yule_cat/yule_layout.gd")
const STONE := "old_stone_wall"
const TIMBER := "wood_trunk_wall"
const PLANKS := "brown_planks_04"
const ROCK := "rock_face_03"
const TURF := Color("857a60")
const BASALT := Color("5d5e64")
const CAVE_ROCK := Color("6a625a")
const TAR := Color("3a3431")
const BARN_RED := Color("8a3a2e")
const LIME := Color("e6e0d4")
const TRIM := Color("efe9dc")
const IRON := Color("25272b")
const WOOD := Color("8a6a52")
const DARK_WOOD := Color("5e4636")
const TRODDEN := Color("e6eaf0")
## Gable fronts: tarred, barn red or limewashed, house by house.
const FRONTS := [TAR, BARN_RED, LIME, TAR, BARN_RED, TAR, LIME, BARN_RED, TAR, LIME]
## The lane up the valley and the path to the barracks, trodden grey.
const PATHS := [
	[Vector3(5.0, 0, 46.0), Vector3(1.5, 0, 33.0), Vector3(1.0, 0, 20.0), Vector3(0.0, 0, 9.0)],
	[Vector3(0.0, 0, -9.0), Vector3(1.0, 0, -24.0), Vector3(0.0, 0, -36.0), Vector3(0.0, 0, -44.0)],
	[Vector3(2.0, 0, -15.0), Vector3(8.0, 0, -18.5), Vector3(13.5, 0, -20.0)],
]


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "YuleValleySet"
	root.add_child(_land())
	for region: Array in [["Lower", 10.0, 60.0], ["Square", -10.0, 10.0], ["Upper", -45.0, -10.0]]:
		root.add_child(_village(region[0], region[1], region[2]))
	root.add_child(_barracks())
	root.add_child(_sheep_track())
	root.add_child(_cliff())
	root.add_child(_cave())
	var fells := WinterProps.mountain_range(85.0, 210.0, 60.0, 412)
	fells.name = "Fells"
	root.add_child(fells)
	root.add_child(_bounds())
	return root


## Where a lantern hangs from the post at `at` (the post's arm reaches
## towards the lane).
static func lantern_hook(at: Vector3) -> Vector3:
	return at + Vector3(-signf(at.x) * 0.45, 2.2, 0.0)


# --- The land ---

## The valley floor and the fells rising round it, in tiles so each lantern
## only touches the tiles it reaches. Flat where anyone walks.
static func _land() -> Node3D:
	var root := Node3D.new()
	root.name = "Land"
	var noise := FastNoiseLite.new()
	noise.seed = 412
	noise.frequency = 0.03
	var xs: Array[float] = []
	var x := -120.0
	while x <= 120.01:
		xs.append(x)
		x += 3.0
	var zs: Array[float] = []
	var z := -150.0
	while z <= 150.01:
		zs.append(z)
		z += 3.0
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
	var solid := StaticBody3D.new()
	solid.name = "Ground"
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var b := L.BOUNDS.grow(2.0)
	box.size = Vector3(b.size.x, 2.0, b.size.y)
	shape.shape = box
	shape.position = Vector3(b.get_center().x, -1.0, b.get_center().y)
	solid.add_child(shape)
	root.add_child(solid)
	return root


# --- The village ---

## The houses, paths and clutter whose z lies in [z_min, z_max).
static func _village(region: String, z_min: float, z_max: float) -> Node3D:
	var s := SetBuilder.new(region)
	var panes := MeshPieces.new()
	var inside := func(at: Vector3) -> bool:
		return at.z >= z_min and at.z < z_max
	for i in L.HOUSES.size():
		if inside.call(L.HOUSES[i][0]):
			_house(s, panes, i)
	for path: Array in PATHS:
		for k in path.size() - 1:
			var a: Vector3 = path[k]
			var c: Vector3 = path[k + 1]
			if inside.call((a + c) / 2.0):
				_trodden(s, a, c, 2.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(z_min) + 400
	for at: Vector3 in L.LANTERNS:
		if inside.call(at):
			_lantern_post(s, at)
	for spec: Array in L.WOODPILES:
		if inside.call(spec[0]):
			VillageSet._woodpile(s, spec[0], spec[1], rng)
	for at: Vector3 in L.BARRELS:
		if inside.call(at):
			_barrel(s, at, rng)
	for spec: Array in L.CARTS:
		if inside.call(spec[0]):
			_cart(s, spec[0], spec[1])
	for at: Vector3 in L.BOULDERS:
		if inside.call(at) and at.x > L.TRACK_WALL_X:
			_boulder(s, at, rng)
	for at: Vector3 in L.RACKS:
		if inside.call(at):
			_fish_rack(s, at, rng)
	if region == "Square":
		_pond(s)
	# Drifts heaped against the houses.
	for spec: Array in L.HOUSES:
		var at: Vector3 = spec[0]
		if not inside.call(at):
			continue
		var base := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), at)
		for side: float in [-1.0, 1.0]:
			var p := base * Vector3(side * (float(spec[2]) / 2.0 + 0.5), 0, rng.randf_range(-1.0, 1.0))
			WinterProps.add_snow_mound(s.b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.2, 0.8, 0.9)), p),
					rng.randi_range(1, 9))
	var root := s.finish(region)
	panes.add_to((root.get_node(region) as MeshInstance3D).mesh, WinterProps.window_material())
	return root


## A turf house: a long mound of stacked turf and stone, its roof heaped
## with snow, and a timber gable front with a door and small glowing
## windows. The front faces local +z.
static func _house(s: SetBuilder, panes: MeshPieces, index: int) -> void:
	var spec: Array = L.HOUSES[index]
	var at: Vector3 = spec[0]
	var w: float = spec[2]
	var d: float = spec[3]
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), at)
	var ridge := L.ridge_height(w)
	var profile := _house_profile(w, ridge)
	var rings: Array[PackedVector3Array] = []
	# Rounded off at the back.
	for k in 4:
		var t := sin(k / 3.0 * PI / 2.0)
		rings.append(_ring(profile, -d / 2.0 - L.HOUSE_BACK * (1.0 - t), lerpf(0.3, 1.0, t), lerpf(0.45, 1.0, t)))
	var steps := maxi(2, int(d / 0.7))
	for k in range(1, steps + 1):
		rings.append(_ring(profile, -d / 2.0 + d * k / steps, 1.0, 1.0))
	s.b.textured(ToyBuilder.lumpy(ToyBuilder.loft(rings), 0.13, 0.7, index * 7 + 3), STONE, base, 1.2, TURF, 0.55)
	s.collider(base * Vector3(0, ridge / 2.0, -0.25), Vector3(w + 0.8, ridge, d + 1.1), base.basis)
	# The timber front, a little proud of the turf.
	var front_z := d / 2.0
	var outline := PackedVector2Array()
	for p in profile:
		if p.y >= 0.0:
			outline.append(Vector2(p.x * (w / 2.0 + 0.18) / (w / 2.0), p.y + 0.12 * p.y / ridge))
	outline.append(Vector2(-(w / 2.0 + 0.6), 0.0))
	outline.append(Vector2(w / 2.0 + 0.6, 0.0))
	var face: Color = FRONTS[index % FRONTS.size()]
	var trim := BARN_RED if face == LIME else TRIM
	s.b.textured(_slab(outline, 0.18), PLANKS, base * ToyBuilder.xf(Vector3(0, 0, front_z - 0.02)), 0.8, face, 0.3)
	var f := front_z + 0.16
	# Bargeboards up the gable edges.
	var eave := Vector2(w / 2.0 + 0.1, L.HOUSE_WALL + 0.05)
	var top := Vector2(0.0, ridge + 0.14)
	var board := (top - eave).length() + 0.3
	for side: float in [-1.0, 1.0]:
		var mid := Vector2(side * (eave.x + top.x) / 2.0, (eave.y + top.y) / 2.0)
		var tilt := atan2(top.y - eave.y, eave.x) * side
		s.b.textured(ToyBuilder.box(Vector3(board, 0.2, 0.1)), PLANKS,
				base * Transform3D(Basis(Vector3.BACK, tilt), Vector3(mid.x, mid.y, f + 0.04)), 0.8, trim, 0.6)
	# The door (Door-Slammer's is left open for the level to hang).
	s.b.textured(ToyBuilder.box(Vector3(1.25, 2.02, 0.08)), PLANKS, base * ToyBuilder.xf(Vector3(0, 1.0, f + 0.02)), 0.8, trim)
	if index == L.SLAMMER_HOUSE:
		s.b.add(ToyBuilder.box(Vector3(0.98, 1.86, 0.1)), Color("0c0a09"), base * ToyBuilder.xf(Vector3(0, 0.93, f + 0.03)))
	else:
		s.b.textured(ToyBuilder.box(Vector3(0.96, 1.85, 0.1)), PLANKS, base * ToyBuilder.xf(Vector3(0, 0.93, f + 0.05)), 0.6,
				DARK_WOOD)
		s.b.finished(ToyBuilder.sphere(0.04, 8), IRON, "metal", base * ToyBuilder.xf(Vector3(0.36, 0.95, f + 0.12)))
	s.b.textured(ToyBuilder.box(Vector3(1.4, 0.1, 0.4)), PLANKS, base * ToyBuilder.xf(Vector3(0, 2.1, f + 0.18)), 0.8, trim, 0.9)
	# Small four-pane windows either side, and one up in the gable.
	var windows: Array[Vector3] = [Vector3(-w * 0.3, 1.2, f), Vector3(w * 0.3, 1.2, f)]
	if ridge - L.HOUSE_WALL > 1.9:
		windows.append(Vector3(0, L.HOUSE_WALL + 0.85, f))
	for spot in windows:
		_window(s, panes, base, spot, trim)
	# A turf chimney stack on the ridge.
	s.b.textured(ToyBuilder.box(Vector3(0.5, 0.7, 0.5)), STONE, base * ToyBuilder.xf(Vector3(0, ridge - 0.05, -d * 0.25)), 1.0,
			Color("8d8478"), 0.6)


## Half-width `w`/2 cross-section of a turf house: sloping turf walls, then
## a straight roof up to the ridge. A closed loop (it runs under the ground).
static func _house_profile(w: float, ridge: float) -> PackedVector2Array:
	var half := w / 2.0
	var right: Array[Vector2] = [Vector2(half + 0.4, -0.35), Vector2(half + 0.32, 0.5), Vector2(half + 0.15, 1.25),
			Vector2(half - 0.05, L.HOUSE_WALL)]
	for k in range(1, 5):
		right.append(Vector2(half - 0.05, L.HOUSE_WALL).lerp(Vector2(0.35, ridge - 0.04), k / 4.0))
	var loop: Array[Vector2] = [Vector2(0, -0.4)]
	loop.append_array(right)
	loop.append(Vector2(0, ridge))
	for k in range(right.size() - 1, -1, -1):
		loop.append(Vector2(-right[k].x, right[k].y))
	# Fine enough for the lumps to show.
	var fine := PackedVector2Array()
	for k in loop.size():
		var a := loop[k]
		var c := loop[(k + 1) % loop.size()]
		var pieces := maxi(1, ceili(a.distance_to(c) / 0.45))
		for j in pieces:
			fine.append(a.lerp(c, float(j) / pieces))
	return fine


static func _ring(profile: PackedVector2Array, z: float, sx: float, sy: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for p in profile:
		ring.append(Vector3(p.x * sx, p.y * sy, z))
	return ring


## A flat outline extruded `thickness` deep (towards +z), e.g. a gable front.
static func _slab(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var tris := Geometry2D.triangulate_polygon(outline)
	for z: float in [0.0, thickness]:
		var n := Vector3(0, 0, 1.0 if z > 0.0 else -1.0)
		var start := verts.size()
		for p in outline:
			verts.append(Vector3(p.x, p.y, z))
			normals.append(n)
		for t in range(0, tris.size(), 3):
			_tri(verts, normals, indices, start + tris[t], start + tris[t + 1], start + tris[t + 2])
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= outline.size()
	for k in outline.size():
		var a := outline[k]
		var c := outline[(k + 1) % outline.size()]
		var edge := c - a
		var out := Vector2(edge.y, -edge.x).normalized()
		if out.dot((a + c) / 2.0 - centre) < 0.0:
			out = -out
		var n := Vector3(out.x, out.y, 0)
		var start := verts.size()
		for p: Vector3 in [Vector3(a.x, a.y, 0), Vector3(c.x, c.y, 0), Vector3(c.x, c.y, thickness), Vector3(a.x, a.y, thickness)]:
			verts.append(p)
			normals.append(n)
		_tri(verts, normals, indices, start, start + 1, start + 2)
		_tri(verts, normals, indices, start, start + 2, start + 3)
	var mesh := ArrayMesh.new()
	mesh.set_meta("toy_arrays", [verts, normals, indices])
	return mesh


static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, a: int, b: int, c: int) -> void:
	var face := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if face.dot(normals[a]) * ToyBuilder._engine_front_sign() < 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])


## A small four-pane window on a gable front (facing local +z).
static func _window(s: SetBuilder, panes: MeshPieces, base: Transform3D, at: Vector3, trim: Color) -> void:
	s.b.textured(ToyBuilder.box(Vector3(0.86, 0.9, 0.07)), PLANKS, base * ToyBuilder.xf(at + Vector3(0, 0, 0.02)), 0.8, trim)
	panes.rect(base * (at + Vector3(0, 0, 0.065)), base.basis * Vector3.BACK, Vector3.UP, Vector2(0.66, 0.7))
	s.b.textured(ToyBuilder.box(Vector3(0.05, 0.7, 0.04)), PLANKS, base * ToyBuilder.xf(at + Vector3(0, 0, 0.08)), 0.8, trim)
	s.b.textured(ToyBuilder.box(Vector3(0.66, 0.05, 0.04)), PLANKS, base * ToyBuilder.xf(at + Vector3(0, 0, 0.08)), 0.8, trim)
	s.b.textured(ToyBuilder.box(Vector3(0.96, 0.07, 0.16)), PLANKS, base * ToyBuilder.xf(at + Vector3(0, -0.47, 0.08)), 0.8, trim, 0.9)


## A strip of trodden, greyer snow from `a` to `c`.
static func _trodden(s: SetBuilder, a: Vector3, c: Vector3, width: float) -> void:
	var along := c - a
	var yaw := atan2(along.x, along.z)
	s.b.textured(ToyBuilder.box(Vector3(width, 0.02, along.length() + width * 0.6)), "snow_02",
			Transform3D(Basis(Vector3.UP, yaw), (a + c) / 2.0 + Vector3(0, 0.01, 0)), 1.5, TRODDEN)


## A wooden post with an arm for a lantern (the level hangs the lantern).
static func _lantern_post(s: SetBuilder, at: Vector3) -> void:
	var dir := -signf(at.x)
	s.b.textured(ToyBuilder.cylinder(0.07, 0.09, 2.5, 8), TIMBER, ToyBuilder.xf(at + Vector3(0, 1.25, 0)), 1.0, DARK_WOOD, 0.4)
	s.b.textured(ToyBuilder.box(Vector3(0.6, 0.08, 0.08)), TIMBER, ToyBuilder.xf(at + Vector3(dir * 0.25, 2.3, 0)), 1.0, DARK_WOOD, 0.6)
	s.b.textured(ToyBuilder.tube(PackedVector3Array([at + Vector3(0, 1.95, 0), at + Vector3(dir * 0.3, 2.28, 0)]),
			PackedFloat32Array([0.03, 0.03]), 5), TIMBER, Transform3D.IDENTITY, 1.0, DARK_WOOD)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.12
	cylinder.height = 2.5
	s.add_shape(cylinder, Transform3D(Basis.IDENTITY, at + Vector3(0, 1.25, 0)))


static func _barrel(s: SetBuilder, at: Vector3, rng: RandomNumberGenerator) -> void:
	var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.36, 0.25), Vector2(0.38, 0.45),
			Vector2(0.36, 0.65), Vector2(0.3, 0.9), Vector2(0.0, 0.9)])
	var xf := ToyBuilder.xf(at, Vector3(0, rng.randf() * 360.0, 0))
	s.b.textured(ToyBuilder.lathe(profile, 14), PLANKS, xf, 0.6, WOOD, 0.6)
	for y: float in [0.12, 0.78]:
		s.b.finished(ToyBuilder.torus(0.335, 0.015, 16, 4), IRON, "metal", xf * ToyBuilder.xf(Vector3(0, y, 0)))
	s.b.textured(ToyBuilder.snow_sheet(Vector2(0.5, 0.5), 0.06, rng.randi_range(1, 9), 0.08), "snow_02",
			xf * ToyBuilder.xf(Vector3(0, 0.9, 0)), 1.5, WinterProps.SNOW_TINT)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.38
	cylinder.height = 1.0
	s.add_shape(cylinder, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.5, 0)))


## A two-wheeled handcart left in the snow, its shafts resting on the ground.
static func _cart(s: SetBuilder, at: Vector3, yaw: float) -> void:
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	var tip := Basis(Vector3.RIGHT, deg_to_rad(-9.0))
	var bed := base * Transform3D(tip, Vector3(0, 0.75, 0))
	s.b.textured(ToyBuilder.box(Vector3(1.3, 0.08, 1.8)), PLANKS, bed, 0.8, WOOD, 0.8)
	for side: float in [-1.0, 1.0]:
		s.b.textured(ToyBuilder.box(Vector3(0.06, 0.35, 1.8)), PLANKS, bed * ToyBuilder.xf(Vector3(side * 0.62, 0.2, 0)), 0.8, WOOD)
		s.b.textured(ToyBuilder.box(Vector3(0.08, 0.08, 1.6)), TIMBER, bed * ToyBuilder.xf(Vector3(side * 0.45, -0.06, 1.5)), 1.0, DARK_WOOD)
		var wheel := base * ToyBuilder.xf(Vector3(side * 0.78, 0.5, -0.2), Vector3(0, 0, 90))
		s.b.textured(ToyBuilder.torus(0.45, 0.05, 18, 6), TIMBER, wheel, 1.0, DARK_WOOD, 0.4)
		for k in 6:
			s.b.textured(ToyBuilder.box(Vector3(0.04, 0.85, 0.04)), TIMBER, wheel * ToyBuilder.xf(Vector3.ZERO, Vector3(0, k * 30.0, 0)),
					1.0, DARK_WOOD)
	s.b.textured(ToyBuilder.box(Vector3(0.1, 0.1, 0.4)), TIMBER, bed * ToyBuilder.xf(Vector3(0, -0.06, -0.85)), 1.0, DARK_WOOD)
	s.b.textured(ToyBuilder.snow_sheet(Vector2(1.2, 1.7), 0.12, int(at.x * 3.0), 0.12), "snow_02", bed * ToyBuilder.xf(Vector3(0, 0.05, 0)),
			1.5, WinterProps.SNOW_TINT)
	s.collider(at + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 2.4), base.basis)


## A lava boulder with snow on its back: cover to crouch behind.
static func _boulder(s: SetBuilder, at: Vector3, rng: RandomNumberGenerator) -> void:
	var size := Vector3(rng.randf_range(1.1, 1.5), rng.randf_range(0.85, 1.05), rng.randf_range(1.0, 1.3))
	var xf := ToyBuilder.xf(at + Vector3(0, size.y * 0.55, 0), Vector3(0, rng.randf() * 360.0, rng.randf_range(-6, 6)), size)
	s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 14), 0.22, 1.3, rng.randi_range(1, 50)), ROCK, xf, 1.2, BASALT, 0.55)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = minf(size.x, size.z) * 0.9
	cylinder.height = size.y * 1.6
	s.add_shape(cylinder, Transform3D(Basis.IDENTITY, at + Vector3(0, size.y * 0.8, 0)))


## A fish-drying rack: two log trestles and a pole hung with stockfish.
static func _fish_rack(s: SetBuilder, at: Vector3, rng: RandomNumberGenerator) -> void:
	const LENGTH := 3.2
	const HEIGHT := 2.2
	for end: float in [-1.0, 1.0]:
		var x := at.x + end * LENGTH / 2.0
		for side: float in [-1.0, 1.0]:
			s.b.textured(ToyBuilder.tube(PackedVector3Array([Vector3(x, 0, at.z + side * 0.7), Vector3(x, HEIGHT + 0.15, at.z - side * 0.1)]),
					PackedFloat32Array([0.06, 0.05]), 6), TIMBER, Transform3D.IDENTITY, 1.0, DARK_WOOD, 0.4)
	s.b.textured(ToyBuilder.cylinder(0.05, 0.05, LENGTH + 0.6, 8), TIMBER, ToyBuilder.xf(at + Vector3(0, HEIGHT, 0), Vector3(0, 0, 90)),
			1.0, DARK_WOOD, 0.7)
	# Split cod hung in pairs over the pole.
	var fish := ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.12, 2.0, 5)
	var count := 9
	for k in count:
		var fx := at.x - LENGTH / 2.0 + 0.25 + k * (LENGTH - 0.5) / (count - 1)
		for side: float in [-1.0, 1.0]:
			var hang := rng.randf_range(0.42, 0.55)
			var tone := Color("a89a80").lerp(Color("7a6b55"), rng.randf())
			s.b.finished(fish, tone, "leather", ToyBuilder.xf(Vector3(fx, HEIGHT - hang, at.z + side * 0.07),
					Vector3(side * 8.0, rng.randf_range(-10, 10), 0), Vector3(0.09, hang, 0.025)))
	s.collider(at + Vector3(0, HEIGHT / 2.0 + 0.1, 0), Vector3(LENGTH + 0.3, HEIGHT + 0.2, 1.2))


## The frozen pond in the middle of the square, ringed with stones.
static func _pond(s: SetBuilder) -> void:
	var ice := MeshInstance3D.new()
	ice.name = "Pond"
	ice.mesh = ToyBuilder.cylinder(L.POND_RADIUS, L.POND_RADIUS, 0.08, 40)
	ice.material_override = WorkshopSet.thin_ice_material()
	ice.position = L.SQUARE + Vector3(0, 0.02, 0)
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.root.add_child(ice)
	s.b.textured(ToyBuilder.cylinder(L.SQUARE_RADIUS, L.SQUARE_RADIUS, 0.02, 48), "snow_02", ToyBuilder.xf(L.SQUARE + Vector3(0, 0.005, 0)),
			1.5, TRODDEN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var count := 30
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.05, 0.05)
		var r := L.POND_RADIUS + rng.randf_range(0.1, 0.3)
		var size := Vector3(rng.randf_range(0.25, 0.4), rng.randf_range(0.14, 0.24), rng.randf_range(0.2, 0.32))
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.25, 3.0, k), ROCK,
				ToyBuilder.xf(L.SQUARE + Vector3(cos(a) * r, size.y * 0.4, sin(a) * r), Vector3(0, rng.randf() * 360.0, 0), size), 0.8,
				BASALT, 0.7)


# --- The barracks ---

## The Red Caps' barracks: a pointed-log palisade round a yard with a fire
## pit, and an open-fronted shed of bunks along the east side.
static func _barracks() -> Node3D:
	var s := SetBuilder.new("Barracks")
	var y := L.YARD
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	var gate_lo := L.YARD_GATE.z - L.YARD_GATE_HALF
	var gate_hi := L.YARD_GATE.z + L.YARD_GATE_HALF
	var runs := [
		[Vector3(y.position.x, 0, y.position.y), Vector3(y.end.x, 0, y.position.y)],
		[Vector3(y.end.x, 0, y.position.y), Vector3(y.end.x, 0, y.end.y)],
		[Vector3(y.end.x, 0, y.end.y), Vector3(y.position.x, 0, y.end.y)],
		[Vector3(y.position.x, 0, y.end.y), Vector3(y.position.x, 0, gate_hi)],
		[Vector3(y.position.x, 0, gate_lo), Vector3(y.position.x, 0, y.position.y)],
	]
	var log_mesh := ToyBuilder.cylinder(0.15, 0.16, 1.0, 7)
	var point := ToyBuilder.cylinder(0.0, 0.15, 0.4, 7)
	for run: Array in runs:
		var a: Vector3 = run[0]
		var c: Vector3 = run[1]
		var length := a.distance_to(c)
		var count := int(length / 0.3)
		for k in count + 1:
			var p := a.lerp(c, float(k) / count) + Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04))
			var h := rng.randf_range(2.4, 2.8)
			s.b.textured(log_mesh, "bark_brown_02", ToyBuilder.xf(p + Vector3(0, h / 2.0, 0), Vector3.ZERO, Vector3(1, h, 1)), 0.5,
					Color("9a8a7a"), 0.3)
			s.b.textured(point, "bark_brown_02", ToyBuilder.xf(p + Vector3(0, h + 0.2, 0)), 0.5, Color("b0a090"), 0.6)
		# A rail along the inside, and the wall's collision.
		var inward := Vector3(L.YARD.get_center().x, 0, L.YARD.get_center().y) - (a + c) / 2.0
		var off := Vector3(signf(inward.x), 0, 0) if absf(a.z - c.z) > absf(a.x - c.x) else Vector3(0, 0, signf(inward.z))
		s.b.textured(ToyBuilder.tube(PackedVector3Array([a + off * 0.2 + Vector3(0, 1.9, 0), c + off * 0.2 + Vector3(0, 1.9, 0)]),
				PackedFloat32Array([0.06, 0.06]), 6), TIMBER, Transform3D.IDENTITY, 1.0, DARK_WOOD, 0.5)
		var size := Vector3(absf(c.x - a.x) + 0.35, 3.0, absf(c.z - a.z) + 0.35)
		s.collider((a + c) / 2.0 + Vector3(0, 1.5, 0), size)
	# Gateposts, taller, with a crossbeam and a painted shield.
	for gz: float in [gate_lo - 0.1, gate_hi + 0.1]:
		s.b.textured(ToyBuilder.cylinder(0.2, 0.22, 3.6, 8), "bark_brown_02", ToyBuilder.xf(Vector3(y.position.x, 1.8, gz)), 0.5,
				Color("9a8a7a"), 0.3)
	s.b.textured(ToyBuilder.box(Vector3(0.3, 0.3, L.YARD_GATE_HALF * 2.0 + 0.8)), TIMBER, ToyBuilder.xf(Vector3(y.position.x, 3.4, L.YARD_GATE.z)),
			1.0, DARK_WOOD, 0.7)
	s.b.finished(ToyBuilder.cylinder(0.45, 0.45, 0.08, 18), Color("8c2420"), "leather",
			ToyBuilder.xf(Vector3(y.position.x - 0.2, 2.8, L.YARD_GATE.z), Vector3(0, 0, 90)))
	s.b.finished(ToyBuilder.cylinder(0.12, 0.12, 0.1, 12), IRON, "metal", ToyBuilder.xf(Vector3(y.position.x - 0.25, 2.8, L.YARD_GATE.z), Vector3(0, 0, 90)))
	_shed(s)
	# A ring of stones for the yard fire (the level lights it).
	for k in 10:
		var a := TAU * k / 10.0
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.2, 3.0, k + 20), ROCK,
				ToyBuilder.xf(L.YARD_FIRE + Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75), Vector3(0, k * 40.0, 0), Vector3(0.2, 0.16, 0.16)),
				0.8, BASALT)
	for k in 3:
		s.log_beam(L.YARD_FIRE + Vector3(0, 0.12, 0), Vector3(90, k * 60.0, 0), 0.07, 1.0, false)
	# Weapons rack and a chopping block by the shed.
	s.b.textured(ToyBuilder.cylinder(0.3, 0.34, 0.6, 12), "bark_brown_02", ToyBuilder.xf(Vector3(17.5, 0.3, -30.5)), 0.5, Color("a08a70"), 0.5)
	s.collider(Vector3(17.5, 0.3, -30.5), Vector3(0.7, 0.6, 0.7))
	return s.finish("Barracks")


## The shed: back and end walls of planks, posts along the open front, a
## single-pitch roof heaped with snow, and six low bunks of straw.
static func _shed(s: SetBuilder) -> void:
	var r := L.SHED
	var front := r.position.x
	var back := r.end.x
	var mid_z := r.get_center().y
	s.block(Vector3(back - 0.1, 1.2, mid_z), Vector3(0.2, 2.4, r.size.y), PLANKS, WOOD, false)
	for end: float in [r.position.y, r.end.y]:
		s.block(Vector3((front + back) / 2.0, 1.4, end), Vector3(r.size.x, 2.8, 0.2), PLANKS, WOOD, false)
	var posts := 7
	for k in posts:
		var pz := r.position.y + k * r.size.y / (posts - 1)
		s.log_beam(Vector3(front, 1.45, pz), Vector3.ZERO, 0.1, 2.9)
	var pitch := atan2(0.6, r.size.x)
	var roof := Transform3D(Basis(Vector3.BACK, -pitch), Vector3((front + back) / 2.0, 2.75, mid_z))
	s.b.textured(ToyBuilder.box(Vector3(r.size.x + 0.8, 0.14, r.size.y + 0.6)), PLANKS, roof, 1.0, DARK_WOOD)
	s.b.textured(ToyBuilder.snow_sheet(Vector2(r.size.x + 0.7, r.size.y + 0.5), 0.3, 12, 0.25), "snow_02",
			roof * ToyBuilder.xf(Vector3(0, 0.07, 0)), 1.5, WinterProps.SNOW_TINT)
	# A floor of trodden straw under the roof.
	s.b.finished(ToyBuilder.box(Vector3(r.size.x - 0.2, 0.03, r.size.y - 0.3)), Color("b39b62"), "leather",
			ToyBuilder.xf(Vector3((front + back) / 2.0, 0.015, mid_z)))
	for at: Vector3 in L.BUNKS:
		var top := L.BUNK_TOP
		s.b.textured(ToyBuilder.box(Vector3(1.7, 0.12, 0.95)), PLANKS, ToyBuilder.xf(at + Vector3(0, top - 0.2, 0)), 0.8, WOOD)
		for cx: float in [-0.75, 0.75]:
			for cz: float in [-0.4, 0.4]:
				s.b.textured(ToyBuilder.box(Vector3(0.1, top - 0.2, 0.1)), PLANKS, ToyBuilder.xf(at + Vector3(cx, (top - 0.2) / 2.0, cz)),
						0.8, DARK_WOOD)
		s.b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(1.6, 0.14, 0.85)), 0.02, 6.0, int(at.z)), Color("c2a868"), "leather",
				ToyBuilder.xf(at + Vector3(0, top - 0.08, 0)))
		s.collider(at + Vector3(0, top / 2.0, 0), Vector3(1.7, top, 0.95))


# --- The sheep track ---

## A long turf wall up the west side, gateposts at its south end (the level
## hangs the gate) and boulders along the track behind it.
static func _sheep_track() -> Node3D:
	var s := SetBuilder.new("SheepTrack")
	var profile := PackedVector2Array()
	for p: Vector2 in [Vector2(0, -0.3), Vector2(0.85, -0.3), Vector2(0.7, 0.7), Vector2(0.48, 1.6), Vector2(0.2, 1.85),
			Vector2(-0.2, 1.85), Vector2(-0.48, 1.6), Vector2(-0.7, 0.7), Vector2(-0.85, -0.3)]:
		profile.append(p)
	var rings: Array[PackedVector3Array] = []
	var z := L.TRACK_SOUTH
	while z >= L.TRACK_NORTH - 0.01:
		var ring := PackedVector3Array()
		var taper := clampf(minf(L.TRACK_SOUTH - z, z - L.TRACK_NORTH) / 0.6, 0.4, 1.0)
		for p in profile:
			ring.append(Vector3(L.TRACK_WALL_X + p.x, p.y * taper, z))
		rings.append(ring)
		z -= 0.8
	s.b.textured(ToyBuilder.lumpy(ToyBuilder.loft(rings), 0.1, 0.8, 21), STONE, Transform3D.IDENTITY, 1.2, TURF, 0.6)
	s.collider(Vector3(L.TRACK_WALL_X, 1.5, (L.TRACK_SOUTH + L.TRACK_NORTH) / 2.0), Vector3(1.3, 3.0, L.TRACK_SOUTH - L.TRACK_NORTH))
	# Stone gateposts at the south end, from the wall to the valley side.
	var west := L.SHEEP_GATE.x - L.SHEEP_GATE_HALF - 0.45
	for gx: float in [west, L.TRACK_WALL_X]:
		s.block(Vector3(gx, 1.0, L.TRACK_SOUTH), Vector3(0.9, 2.0, 0.9), STONE, Color("a39d92"), true, int(gx))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2131
	for at: Vector3 in L.BOULDERS:
		if at.x < L.TRACK_WALL_X:
			_boulder(s, at, rng)
	# Tufts of dry grass along the track.
	for k in 40:
		var at := Vector3(rng.randf_range(-30.0, -22.0), 0, rng.randf_range(L.TRACK_NORTH, L.TRACK_SOUTH))
		WinterProps.add_dry_grass(s.b, Transform3D(Basis.IDENTITY, at), k)
	return s.finish("SheepTrack")


# --- The cliff ---

## The cliff at the head of the valley: basalt columns standing shoulder to
## shoulder, the cave mouth broken through them, scree along the foot and
## snow on top. Solid rock (plain boxes) fills in behind, round the chamber.
static func _cliff() -> Node3D:
	var s := SetBuilder.new("Cliff")
	var c := L.CHAMBER
	var face := L.CLIFF_Z + 0.4
	var top := L.CLIFF_HEIGHT
	var back := -78.0
	var boxes := [
		[Vector3(-46.0, 0, back), Vector3(c.position.x, top, face)],
		[Vector3(c.end.x, 0, back), Vector3(46.0, top, face)],
		[Vector3(c.position.x, 0, c.end.y), Vector3(-L.MOUTH_HALF, top, face)],
		[Vector3(L.MOUTH_HALF, 0, c.end.y), Vector3(c.end.x, top, face)],
		[Vector3(-L.MOUTH_HALF, L.MOUTH_HEIGHT, c.end.y), Vector3(L.MOUTH_HALF, top, face)],
		[Vector3(c.position.x, L.CHAMBER_HEIGHT, c.position.y), Vector3(c.end.x, top, c.end.y)],
		[Vector3(c.position.x, 0, back), Vector3(c.end.x, top, c.position.y)],
	]
	for box: Array in boxes:
		var lo: Vector3 = box[0]
		var hi: Vector3 = box[1]
		var size := hi - lo
		s.b.textured(ToyBuilder.box(size), ROCK, ToyBuilder.xf((lo + hi) / 2.0), 3.0, CAVE_ROCK)
		s.collider((lo + hi) / 2.0, size)
	s.b.textured(ToyBuilder.snow_sheet(Vector2(92.0, face - back), 0.5, 17, 1.2), "snow_02",
			ToyBuilder.xf(Vector3(0, top, (face + back) / 2.0)), 1.5, WinterProps.SNOW_TINT)
	# The columns stand along the lower two thirds, in stepped clusters like
	# organ pipes, jointed every metre or two; above them is the rough rock of
	# the cliff. The face bows in and out, and here and there a lower tier of
	# shorter columns stands out in front.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1712
	var column := ToyBuilder.cylinder(0.5, 0.5, 1.0, 6)
	var x := -46.0
	var cluster_top := 0.0
	var cluster_left := 0
	while x < 46.0:
		if cluster_left <= 0:
			cluster_left = rng.randi_range(3, 8)
			cluster_top = top * rng.randf_range(0.5, 0.78)
		cluster_left -= 1
		var over_mouth := absf(x) < L.MOUTH_HALF + 0.25
		var bottom := L.MOUTH_HEIGHT + rng.randf_range(-0.1, 0.5) if over_mouth else -0.5
		var col_top := cluster_top + rng.randf_range(-0.3, 0.3)
		if absf(x) < 5.0:
			col_top = maxf(col_top, L.MOUTH_HEIGHT + 4.0)
		var z := face + 0.5 + sin(x * 0.17) * 0.5 + rng.randf_range(-0.15, 0.2)
		if absf(x) < 5.0:
			z = face + rng.randf_range(0.0, 0.3)
		var tone := BASALT.darkened(rng.randf_range(0.0, 0.2)).lerp(Color("70747e"), rng.randf_range(0.0, 0.35))
		var spin := rng.randf() * 60.0
		var y := bottom
		while y < col_top - 0.3:
			var piece := minf(rng.randf_range(1.0, 2.6), col_top - y)
			s.b.textured(column, ROCK, ToyBuilder.xf(Vector3(x + rng.randf_range(-0.04, 0.04), y + piece / 2.0, z + rng.randf_range(-0.05, 0.05)),
					Vector3(0, spin + rng.randf_range(-4.0, 4.0), 0), Vector3(1, piece - 0.05, 1)), 1.4, tone.darkened(rng.randf_range(0.0, 0.1)), 0.45)
			y += piece
		# The lower tier.
		if not over_mouth and absf(x) > 6.0 and (sin(x * 0.31) > 0.35 or rng.randf() < 0.12):
			var stub := rng.randf_range(1.2, 2.2) + (sin(x * 0.31) - 0.35) * 5.0
			s.b.textured(column, ROCK, ToyBuilder.xf(Vector3(x + rng.randf_range(-0.15, 0.15), stub / 2.0 - 0.3, z + 0.85),
					Vector3(0, rng.randf() * 60.0, 0), Vector3(0.95, stub, 0.95)), 1.4, tone.lightened(0.05), 0.6)
		x += 0.86
	# Crags jutting from the rock above the columns, with snow on their ledges.
	for k in 40:
		var jx := rng.randf_range(-45.0, 45.0)
		var size := Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(0.8, 2.2), rng.randf_range(0.8, 1.6))
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(0.5, 10), 0.3, 2.5, k + 300), ROCK,
				ToyBuilder.xf(Vector3(jx, rng.randf_range(top * 0.68, top - 1.0), face + 0.1), Vector3(0, rng.randf_range(-20.0, 20.0), rng.randf_range(-15.0, 15.0)), size),
				1.4, BASALT.lerp(Color("70747e"), 0.3), 0.8)
	# Rough rock and a snow cornice along the top, so the skyline isn't a ruler.
	var cx := -46.0
	while cx < 46.0:
		var size := Vector3(rng.randf_range(2.5, 4.5), rng.randf_range(0.8, 1.8), rng.randf_range(2.0, 3.5))
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(0.5, 10), 0.25, 2.5, int(cx * 7.0) + 900), ROCK,
				ToyBuilder.xf(Vector3(cx, top + size.y * 0.2, face - 0.6 + rng.randf_range(-0.6, 0.4)), Vector3(0, rng.randf() * 360.0, 0), size),
				1.4, BASALT, 0.9)
		cx += rng.randf_range(2.0, 3.4)
	for side: float in [-1.0, 1.0]:
		s.collider(Vector3(side * (L.MOUTH_HALF + 6.0) / 2.0, top / 2.0, face + 0.6), Vector3(6.0 - L.MOUTH_HALF, top, 1.2))
		s.collider(Vector3(side * 26.0, top / 2.0, face + 1.2), Vector3(40.0, top, 2.4))
	# Scree at the foot, clear of the mouth and the path.
	for k in 34:
		var sx := rng.randf_range(-44.0, 44.0)
		if absf(sx) < L.MOUTH_HALF + 2.5:
			continue
		var size := Vector3(rng.randf_range(0.4, 1.1), rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 0.9))
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 10), 0.2, 2.0, k), ROCK,
				ToyBuilder.xf(Vector3(sx, size.y * 0.4, face + 1.1 + rng.randf_range(0.0, 0.8)), Vector3(0, rng.randf() * 360.0, 0), size),
				1.0, BASALT, 0.6)
	# Icicles along the lintel of the mouth.
	var ix := -L.MOUTH_HALF + 0.15
	while ix < L.MOUTH_HALF - 0.1:
		var drip := rng.randf_range(0.2, 0.9)
		s.b.finished(ToyBuilder.cylinder(0.0, rng.randf_range(0.04, 0.09), drip, 6), Color("cfe6f5"), "eye",
				ToyBuilder.xf(Vector3(ix, L.MOUTH_HEIGHT + rng.randf_range(0.0, 0.3) - drip / 2.0, face + rng.randf_range(0.1, 0.5))))
		ix += rng.randf_range(0.15, 0.45)
	return s.finish("Cliff")


# --- The cave ---

## Grýla's chamber: an earth floor, rough rock heaped round the walls, her
## cauldron on its hearthstones, her great chair, a bed of sheepskins,
## sacks of plunder, and a framed photograph on the wall.
static func _cave() -> Node3D:
	var s := SetBuilder.new("Cave")
	var c := L.CHAMBER
	var rng := RandomNumberGenerator.new()
	rng.seed = 1012
	s.b.textured(ToyBuilder.box(Vector3(c.size.x, 0.04, c.size.y + 2.4)), ROCK,
			ToyBuilder.xf(Vector3(c.get_center().x, 0.02, c.get_center().y + 1.2)), 2.0, Color("5a4e44"))
	# Rough rock along the walls, so it isn't a box.
	for k in 26:
		var t := rng.randf()
		var at: Vector3
		if k < 9:
			at = Vector3(lerpf(c.position.x, c.end.x, t), 0, c.position.y + 0.3)
		elif k < 17:
			at = Vector3(c.end.x - 0.3, 0, lerpf(c.position.y, c.end.y - 1.0, t))
		else:
			at = Vector3(c.position.x + 0.3, 0, lerpf(c.position.y, c.end.y - 1.0, t))
			if absf(at.z - L.HEADSHOT.z) < 1.4:
				continue
		var size := Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(1.2, 3.2), rng.randf_range(0.8, 1.6))
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 12), 0.25, 1.2, k + 60), ROCK,
				ToyBuilder.xf(at + Vector3(0, size.y * 0.35, 0), Vector3(0, rng.randf() * 360.0, 0), size), 1.4, CAVE_ROCK)
	# Rock hanging from the roof.
	for k in 14:
		var at := Vector3(rng.randf_range(c.position.x + 1.0, c.end.x - 1.0), L.CHAMBER_HEIGHT, rng.randf_range(c.position.y + 1.0, c.end.y - 1.0))
		var drop := rng.randf_range(0.6, 1.8)
		s.b.textured(ToyBuilder.cylinder(0.05, rng.randf_range(0.3, 0.6), drop, 7), ROCK, ToyBuilder.xf(at - Vector3(0, drop / 2.0, 0),
				Vector3(180, rng.randf() * 360.0, 0)), 1.0, CAVE_ROCK)
	_cauldron(s)
	_seat(s)
	_headshot(s)
	# A bed of sheepskins along the back wall.
	for k in 6:
		var at := Vector3(6.5 + rng.randf_range(-1.0, 1.4), 0.12, -59.0 + rng.randf_range(0.0, 1.5) + k * 0.3)
		s.b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 12), 0.2, 3.0, k), Color("d8cfbd").lerp(Color("8a7a66"), rng.randf() * 0.5),
				"fur", ToyBuilder.xf(at, Vector3(0, rng.randf() * 360.0, 0), Vector3(1.0, 0.18, 0.7)))
	# Sacks of plunder heaped by the west wall.
	for k in 8:
		var at := Vector3(-7.4 + rng.randf_range(-0.6, 0.8), 0.0, -45.8 - rng.randf_range(0.0, 1.6))
		var size := Vector3(0.45, 0.6, 0.4) * rng.randf_range(0.8, 1.2)
		s.b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 12), 0.15, 2.5, k + 5), Color("9b8460"), "leather",
				ToyBuilder.xf(at + Vector3(0, size.y * 0.8, 0), Vector3(rng.randf_range(-12, 12), rng.randf() * 360.0, 0), size))
	s.collider(Vector3(-7.2, 0.6, -46.6), Vector3(1.8, 1.2, 2.0))
	return s.finish("Cave")


static func _cauldron(s: SetBuilder) -> void:
	var at := L.CAULDRON
	for k in 3:
		var a := TAU * k / 3.0
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 10), 0.2, 2.0, k + 3), ROCK,
				ToyBuilder.xf(at + Vector3(cos(a) * 0.7, 0.2, sin(a) * 0.7), Vector3(0, k * 50.0, 0), Vector3(0.35, 0.3, 0.3)), 0.8, BASALT)
	var pot := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.45, 0.04), Vector2(0.78, 0.3), Vector2(0.9, 0.65),
			Vector2(0.86, 1.0), Vector2(0.8, 1.1), Vector2(0.86, 1.16), Vector2(0.78, 1.18), Vector2(0.72, 1.1)])
	s.b.finished(ToyBuilder.lathe(pot, 24), Color("1e1e20"), "metal", ToyBuilder.xf(at + Vector3(0, 0.42, 0)))
	s.b.add(ToyBuilder.cylinder(0.74, 0.74, 0.02, 24), Color("5a5a2c"), ToyBuilder.xf(at + Vector3(0, 1.38, 0)))
	for side: float in [-1.0, 1.0]:
		s.b.finished(ToyBuilder.torus(0.12, 0.025, 12, 5), IRON, "metal", ToyBuilder.xf(at + Vector3(side * 0.92, 1.35, 0), Vector3(90, 0, 0)))
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.95
	cylinder.height = 1.6
	s.add_shape(cylinder, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.8, 0)))


## Grýla's chair: rough-hewn timbers, sized for an ogress, with a sheepskin.
static func _seat(s: SetBuilder) -> void:
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(-20.0)), L.GRYLA_SEAT)
	var wood := Color("6d5644")
	s.b.textured(ToyBuilder.box(Vector3(1.8, 0.25, 1.3)), TIMBER, base * ToyBuilder.xf(Vector3(0, 0.95, 0)), 1.2, wood)
	for cx: float in [-0.8, 0.8]:
		for cz: float in [-0.55, 0.55]:
			s.b.textured(ToyBuilder.cylinder(0.11, 0.13, 0.9, 8), TIMBER, base * ToyBuilder.xf(Vector3(cx, 0.45, cz)), 1.0, wood)
		s.b.textured(ToyBuilder.cylinder(0.12, 0.14, 2.9, 8), TIMBER, base * ToyBuilder.xf(Vector3(cx, 1.45, -0.6), Vector3(-6, 0, 0)), 1.0, wood)
		s.b.textured(ToyBuilder.box(Vector3(0.18, 0.16, 1.2)), TIMBER, base * ToyBuilder.xf(Vector3(cx * 1.05, 1.55, 0)), 1.0, wood)
	for y: float in [1.6, 2.2, 2.8]:
		s.b.textured(ToyBuilder.box(Vector3(1.7, 0.22, 0.12)), TIMBER, base * ToyBuilder.xf(Vector3(0, y, -0.62 - (y - 1.6) * 0.1)), 1.0, wood)
	s.b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 14), 0.15, 3.0, 4), Color("ddd3c0"), "fur",
			base * ToyBuilder.xf(Vector3(0, 1.1, 0.05), Vector3(-10, 0, 0), Vector3(0.85, 0.1, 0.7)))
	s.collider(base * Vector3(0, 0.8, -0.1), Vector3(1.9, 1.6, 1.5), base.basis)


## A framed photograph on the west wall, the frame gilt, the picture too dim
## to make out much past a pale face over dark shoulders and a big signature.
static func _headshot(s: SetBuilder) -> void:
	var at := L.HEADSHOT
	var face := Basis(Vector3.UP, PI / 2.0)
	var base := Transform3D(face, at)
	s.b.finished(ToyBuilder.box(Vector3(0.95, 1.2, 0.07)), Color("c9a24a"), "metal", base * ToyBuilder.xf(Vector3(0, 0, 0.0)))
	s.b.add(ToyBuilder.box(Vector3(0.78, 1.02, 0.02)), Color("1b2130"), base * ToyBuilder.xf(Vector3(0, 0, 0.04)))
	s.b.add(ToyBuilder.sphere(0.5, 14), Color("1c1d24"), base * ToyBuilder.xf(Vector3(0, -0.42, 0.05), Vector3.ZERO, Vector3(0.62, 0.36, 0.02)))
	s.b.add(ToyBuilder.sphere(0.5, 14), Color("b78f72"), base * ToyBuilder.xf(Vector3(0, 0.1, 0.055), Vector3.ZERO, Vector3(0.3, 0.38, 0.02)))
	# The signature, a fat marker scrawl across the bottom.
	var scrawl := PackedVector3Array()
	var widths := PackedFloat32Array()
	for k in 14:
		widths.append(0.008)
		var t := k / 13.0
		scrawl.append(Vector3(lerpf(-0.3, 0.32, t), -0.33 + sin(t * 19.0) * 0.035 + t * 0.06, 0.07))
	s.b.add(ToyBuilder.tube(scrawl, widths, 4), Color("0a0a0a"), base)
	s.b.finished(ToyBuilder.cylinder(0.01, 0.01, 0.4, 4), IRON, "metal", base * ToyBuilder.xf(Vector3(0, 0.75, -0.02), Vector3(0, 0, 0)))


# --- Invisible walls ---

## Keeps Santa in the valley.
static func _bounds() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = PhysicsLayers.WALKER_BOUNDS
	body.collision_mask = 0
	var b := L.BOUNDS
	var walls := [
		[Vector3(b.get_center().x, 3.0, b.end.y), Vector3(b.size.x, 6.0, 0.4)],
		[Vector3(b.get_center().x, 3.0, b.position.y), Vector3(b.size.x, 6.0, 0.4)],
		[Vector3(b.position.x, 3.0, b.get_center().y), Vector3(0.4, 6.0, b.size.y)],
		[Vector3(b.end.x, 3.0, b.get_center().y), Vector3(0.4, 6.0, b.size.y)],
	]
	for wall: Array in walls:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		shape.position = wall[0]
		body.add_child(shape)
	return body
