class_name WorkshopSet
extends RefCounted
## The static set of Level 1, "The Frozen Workshop": the frozen bay and its
## shore, the stone terrace with its workshop halls, the Clock Tower and the
## walkways climbing it, and the three wings out over the ice. Everything
## here stands still; the level script adds what moves or changes (moving
## platforms, furnaces, pipes, fires, the ice on the tower door, the arena).
##
## Each region is merged into its own mesh, so the renderer can skip regions
## out of view and each region only gathers the lights near it.

const L := preload("res://levels/01_frozen_workshop/workshop_layout.gd")
const STONE := "old_stone_wall"
const TIMBER := "wood_trunk_wall"
const PLANKS := "brown_planks_04"
const ROCK := "rock_face_03"
const PLANK_TINT := Color("a88468")
const DARK_PLANKS := Color("6e5444")
const IRON := Color("2b2c30")

## How far to the side the posts stand where a pipe runs above the way across.
const SUPPORT_ASIDE := 3.2
## Where moving platforms sweep (x, z), kept clear of posts.
const KEEP_CLEAR := [Rect2(43.6, -3.6, 3.6, 11.2), Rect2(-48.6, 0.6, 9.0, 2.8)]

static var _ice_cache: Array[StandardMaterial3D] = []


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "WorkshopSet"
	root.add_child(_bay())
	root.add_child(_terrace())
	root.add_child(_tower())
	root.add_child(_west_wing())
	root.add_child(_east_wing())
	root.add_child(_north_wing())
	root.add_child(_pipe_supports())
	return root


# --- The bay and the far shore ---

static func _bay() -> Node3D:
	var s := SetBuilder.new("Bay")
	var ice := MeshInstance3D.new()
	ice.name = "ThinIce"
	var disc := CylinderMesh.new()
	disc.top_radius = 92.0
	disc.bottom_radius = 92.0
	disc.height = 0.2
	disc.radial_segments = 64
	disc.rings = 1
	ice.mesh = disc
	ice.material_override = thin_ice_material()
	ice.position.y = L.ICE_Y - 0.1
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.root.add_child(ice)
	# The snowy shore rising out of the ice, then mountains on the horizon.
	var shore := WinterProps.snow_ground(300.0, 60, 86.0, 11, 2)
	shore.position.y = L.ICE_Y - 0.6
	s.root.add_child(shore)
	s.root.add_child(WinterProps.mountain_range(120.0, 230.0, 34.0, 7))
	# Broken floes and snow drifts lying on the ice.
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	for i in 70:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(26.0, 84.0)
		var at := Vector3(cos(angle) * dist, L.ICE_Y, sin(angle) * dist)
		if _near_a_route(at):
			continue
		var size := Vector3(rng.randf_range(1.0, 4.5), rng.randf_range(0.15, 0.5), rng.randf_range(1.0, 3.5))
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3.UP * size.y * 0.3)
		s.b.textured(ToyBuilder.lumpy(ToyBuilder.box(size), 0.12, 2.0, i), "snow_02", xf, 1.5, WinterProps.SNOW_TINT)
	# Fir trees along the shore.
	var trees: Array[Transform3D] = []
	for i in 90:
		var angle := TAU * i / 90.0 + rng.randf_range(-0.03, 0.03)
		var dist := rng.randf_range(96.0, 125.0)
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.6)),
				Vector3(cos(angle) * dist, L.ICE_Y + 1.2, sin(angle) * dist)))
	var tree := WinterProps.fir_tree(6.5, 31, false, 0.55, 0.65)
	var forest := WinterProps.scatter((tree.get_node("Mesh") as MeshInstance3D).mesh, trees, false)
	tree.free()
	forest.name = "ShoreForest"
	s.root.add_child(forest)
	return s.finish("Floes")


static func _near_a_route(at: Vector3) -> bool:
	if at.x > L.TERRACE_MIN.x - 4.0 and at.x < L.TERRACE_MAX.x + 4.0 and at.z > L.TERRACE_MIN.y - 4.0 and at.z < L.TERRACE_MAX.y + 4.0:
		return true
	if absf(at.z - 2.0) < 6.0 and absf(at.x) < 64.0:
		return true
	return absf(at.x) < 6.0 and at.z < -18.0 and at.z > -68.0


## Dark, glassy ice over black water, catching the moon.
static func thin_ice_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("1d2c3a")
	m.roughness = 0.12
	m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.6
	return m


## Clear blue ice for frozen things (presents, the furnaces, the foot of the
## tower): see-through, so what is frozen inside shows.
static func ice_material() -> StandardMaterial3D:
	if _ice_cache.is_empty():
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.7, 0.85, 0.95, 0.66)
		m.roughness = 0.06
		m.metallic_specular = 0.9
		m.rim_enabled = true
		m.rim = 0.9
		m.rim_tint = 0.2
		m.emission_enabled = true
		m.emission = Color("2a4a66")
		m.emission_energy_multiplier = 0.3
		_ice_cache.append(m)
	return _ice_cache[0]


## A rough block of ice: a box subdivided enough to be lumpy all over.
static func ice_chunk(size: Vector3, seed: int, lumps := 0.06) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	box.subdivide_width = clampi(int(size.x * 3.0), 2, 24)
	box.subdivide_height = clampi(int(size.y * 3.0), 2, 12)
	box.subdivide_depth = clampi(int(size.z * 3.0), 2, 12)
	return ToyBuilder.lumpy(box, lumps, 1.6, seed)


## A see-through ice mesh of `chunks` ([mesh, transform] pairs).
static func ice_mesh(chunks: Array, node_name := "Ice") -> MeshInstance3D:
	var b := ToyBuilder.new()
	for chunk: Array in chunks:
		b.add(chunk[0], Color.WHITE, chunk[1])
	var ice := b.build(0.0, node_name)
	ice.material_override = ice_material()
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ice


# --- The terrace and its halls ---

static func _terrace() -> Node3D:
	var s := SetBuilder.new("Terrace")
	var size := L.TERRACE_MAX - L.TERRACE_MIN
	var middle := (L.TERRACE_MIN + L.TERRACE_MAX) / 2.0
	# The stone platform, its top just under the snow.
	var depth := -L.ICE_Y + 0.4
	s.b.textured(ToyBuilder.box(Vector3(size.x, depth, size.y)), STONE,
			ToyBuilder.xf(Vector3(middle.x, -0.05 - depth / 2.0, middle.y)), 1.6, Color("cfcac2"))
	s.collider(Vector3(middle.x, -0.5, middle.y), Vector3(size.x, 1.0, size.y))
	var snow := WinterProps.snow_ground(size.x, 40, 999.0, 4, 2)
	snow.position = Vector3(middle.x, 0, middle.y)
	snow.scale.z = size.y / size.x
	s.root.add_child(snow)
	# Parapets round the edge, open at the three gates.
	var lo := L.TERRACE_MIN
	var hi := L.TERRACE_MAX
	_parapet(s, Vector3(lo.x + 0.25, 0, lo.y), Vector3(lo.x + 0.25, 0, -1.0))
	_parapet(s, Vector3(lo.x + 0.25, 0, 5.0), Vector3(lo.x + 0.25, 0, hi.y))
	_parapet(s, Vector3(hi.x - 0.25, 0, lo.y), Vector3(hi.x - 0.25, 0, -1.0))
	_parapet(s, Vector3(hi.x - 0.25, 0, 5.0), Vector3(hi.x - 0.25, 0, hi.y))
	_parapet(s, Vector3(lo.x, 0, lo.y + 0.25), Vector3(-3.0, 0, lo.y + 0.25))
	_parapet(s, Vector3(3.0, 0, lo.y + 0.25), Vector3(hi.x, 0, lo.y + 0.25))
	_parapet(s, Vector3(lo.x, 0, hi.y - 0.25), Vector3(hi.x, 0, hi.y - 0.25))
	# Gate posts with stone balls on top, either side of each opening.
	for post: Vector3 in [Vector3(lo.x + 0.25, 0, -1.0), Vector3(lo.x + 0.25, 0, 5.0), Vector3(hi.x - 0.25, 0, -1.0),
			Vector3(hi.x - 0.25, 0, 5.0), Vector3(-3.0, 0, lo.y + 0.25), Vector3(3.0, 0, lo.y + 0.25)]:
		s.block(post + Vector3(0, 0.75, 0), Vector3(0.75, 1.5, 0.75), STONE, Color("d8d2c8"), true, 9)
		s.b.textured(ToyBuilder.sphere(0.3), STONE, ToyBuilder.xf(post + Vector3(0, 1.75, 0)), 0.6, Color("d8d2c8"), 0.6)
	for hall: Array in L.HALLS:
		_hall(s, hall[0], hall[1])
	_plaza_details(s)
	return s.finish("TerraceMesh")


## A low stone wall along the terrace edge, with an invisible wall above it
## so Santa can't jump off.
static func _parapet(s: SetBuilder, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var centre := (from + to) / 2.0
	var x_wise := absf(along.x) > absf(along.z)
	var size := Vector3(absf(along.x) if x_wise else 0.5, 0.9, absf(along.z) if not x_wise else 0.5)
	s.block(centre + Vector3(0, 0.45, 0), size, STONE, Color("d8d2c8"), true, int(centre.x + centre.z))
	s.collider(centre + Vector3(0, 2.0, 0), Vector3(size.x, 2.4, size.z))


## A workshop hall: stone ground floor, timber upper floor, a steep snowy
## roof with icicles along the eaves, and frosted windows facing the plaza.
static func _hall(s: SetBuilder, at: Vector3, size: Vector3) -> void:
	var stone_h := 3.0
	var timber_h := size.y - stone_h
	s.b.textured(ToyBuilder.box(Vector3(size.x, stone_h, size.z)), STONE, ToyBuilder.xf(at + Vector3(0, stone_h / 2.0, 0)),
			1.4, Color("c9c3ba"))
	s.b.textured(ToyBuilder.box(Vector3(size.x - 0.2, timber_h, size.z - 0.2)), TIMBER,
			ToyBuilder.xf(at + Vector3(0, stone_h + timber_h / 2.0, 0)), 1.6, Color("b7a089"))
	# A string course between the floors, and corner posts.
	s.b.textured(ToyBuilder.box(Vector3(size.x + 0.15, 0.25, size.z + 0.15)), STONE,
			ToyBuilder.xf(at + Vector3(0, stone_h, 0)), 1.0, Color("e0dbd2"), 0.5)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			s.b.textured(ToyBuilder.box(Vector3(0.3, timber_h, 0.3)), PLANKS,
					ToyBuilder.xf(at + Vector3(cx * (size.x / 2.0 - 0.1), stone_h + timber_h / 2.0, cz * (size.z / 2.0 - 0.1))),
					1.0, DARK_PLANKS)
	s.collider(at + Vector3(0, size.y / 2.0, 0), size)
	# The roof, its ridge along the longer side.
	var long_x := size.x >= size.z
	var span := size.z if long_x else size.x
	var length := (size.x if long_x else size.z) + 0.8
	var pitch := deg_to_rad(38.0)
	var half := span / 2.0 + 0.45
	var slab_w := half / cos(pitch)
	var rise := half * tan(pitch)
	var eave := at.y + size.y
	for side: float in [-1.0, 1.0]:
		var tilt := Basis(Vector3.RIGHT, side * pitch) if long_x else Basis(Vector3.BACK, side * pitch)
		var offset := Vector3(0, eave + rise / 2.0 + 0.1, 0)
		if long_x:
			offset.z = side * half / 2.0
		else:
			offset.x = -side * half / 2.0
		var slab_size := Vector3(length, 0.2, slab_w) if long_x else Vector3(slab_w, 0.2, length)
		var xf := Transform3D(tilt, at + offset)
		s.b.textured(ToyBuilder.box(slab_size), PLANKS, xf, 1.0, DARK_PLANKS)
		s.b.textured(ToyBuilder.snow_sheet(Vector2(slab_size.x - 0.05, slab_size.z - 0.05), 0.14, int(at.x * 3.0 + side), 0.25),
				"snow_02", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), 1.5, WinterProps.SNOW_TINT)
	# Gable ends, filled with timber.
	for end: float in [-1.0, 1.0]:
		var gable := _prism(span, rise, 0.3)
		# The prism spans x; turn it to span z when the ridge runs along x.
		var basis := Basis(Vector3.UP, PI / 2.0) if long_x else Basis.IDENTITY
		var pos := at + Vector3(0, eave, 0)
		pos += Vector3(end * (size.x / 2.0 - 0.15), 0, 0) if long_x else Vector3(0, 0, end * (size.z / 2.0 - 0.15))
		s.b.textured(gable, TIMBER, Transform3D(basis, pos), 1.6, Color("a38c75"))
	# Icicles along both eaves.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 7.0 + at.z * 13.0)
	for side: float in [-1.0, 1.0]:
		var t := -length / 2.0 + 0.3
		while t < length / 2.0 - 0.3:
			var drip := rng.randf_range(0.2, 0.75)
			var pos := Vector3(t, eave + 0.02, side * (half - 0.05)) if long_x else Vector3(-side * (half - 0.05), eave + 0.02, t)
			s.b.finished(ToyBuilder.cylinder(0.0, rng.randf_range(0.04, 0.08), drip, 6), Color("cfe6f5"), "eye",
					ToyBuilder.xf(at + pos - Vector3(0, drip / 2.0, 0)))
			t += rng.randf_range(0.25, 0.6)
	_hall_windows(s, at, size, stone_h)


## Frosted windows and a door on the side facing the middle of the plaza.
static func _hall_windows(s: SetBuilder, at: Vector3, size: Vector3, stone_h: float) -> void:
	var to_middle := Vector3(-at.x, 0, -3.0 - at.z)
	var along_x := size.x >= size.z
	var normal := Vector3(0, 0, signf(to_middle.z)) if along_x else Vector3(signf(to_middle.x), 0, 0)
	var face := at + normal * ((size.z if along_x else size.x) / 2.0 + 0.02)
	var side := Vector3.UP.cross(normal)
	var width := size.x if along_x else size.z
	var count := int(width / 3.0)
	for i in count:
		var t := (i + 0.5) / count - 0.5
		var centre := face + side * t * width
		# Upper floor windows in the timber, a door in the middle below.
		s.b.textured(ToyBuilder.box(Vector3(1.1, 1.3, 0.12) if along_x else Vector3(0.12, 1.3, 1.1)), PLANKS,
				ToyBuilder.xf(centre + Vector3(0, stone_h + 2.0, 0)), 1.0, DARK_PLANKS)
		s.b.finished(ToyBuilder.box(Vector3(0.85, 1.05, 0.06) if along_x else Vector3(0.06, 1.05, 0.85)), Color("8fb2c8"), "eye",
				ToyBuilder.xf(centre + Vector3(0, stone_h + 2.0, 0) + normal * 0.05))
	var door := face + Vector3(0, 1.15, 0)
	s.b.textured(ToyBuilder.box(Vector3(1.6, 2.3, 0.14) if along_x else Vector3(0.14, 2.3, 1.6)), PLANKS,
			ToyBuilder.xf(door), 1.0, Color("7b5a44"))
	# Ice glazing the door shut.
	s.b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(1.75, 1.6, 0.18) if along_x else Vector3(0.18, 1.6, 1.75)), 0.05, 3.0, 2),
			Color("b9d8ea"), "eye", ToyBuilder.xf(door + normal * 0.08 + Vector3(0, -0.35, 0)))


## A triangular prism: a gable end `width` across and `height` tall at the
## peak, `depth` thick, base at y = 0.
static func _prism(width: float, height: float, depth: float) -> ArrayMesh:
	var w := width / 2.0
	var d := depth / 2.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		for p: Vector3 in [a, b, c]:
			verts.append(p)
			normals.append(n)
			uvs.append(Vector2(p.x + p.z, p.y))
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
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Things standing about the plaza, frozen where the elves left them.
static func _plaza_details(s: SetBuilder) -> void:
	s.put(WinterProps.fir_tree(6.0, 5, true, 0.85, 0.7), Vector3(-7.5, 0, 3.5))
	s.collider(Vector3(-7.5, 1.5, 3.5), Vector3(1.2, 3.0, 1.2))
	for spot: Vector3 in [Vector3(-5.5, 0, 9.5), Vector3(5.5, 0, 9.5), Vector3(-7.0, 0, -4.0), Vector3(7.0, 0, -4.0)]:
		var lamp := s.put(WinterProps.lamp_post(), spot)
		for light in lamp.find_children("*", "OmniLight3D", true, false):
			light.free()
		s.collider(spot + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))
	s.put(WinterProps.snowman(4), Vector3(10.0, 0, 7.5), -30.0)
	s.collider(Vector3(10.0, 0.8, 7.5), Vector3(1.0, 1.6, 1.0))
	s.put(WinterProps.toy_sack(3), Vector3(-11.5, 0, -15.5), 40.0)
	# Crates stacked by the halls.
	for spec: Array in [[Vector3(-13.6, 0.5, -5.0), 1.0, 10.0], [Vector3(-13.4, 1.4, -5.1), 0.8, -15.0],
			[Vector3(12.5, 0.5, -16.0), 1.0, 5.0], [Vector3(13.6, 0.45, -14.9), 0.9, 30.0], [Vector3(-14.0, 0.45, 7.6), 0.9, 0.0]]:
		var size: float = spec[1]
		s.block(spec[0], Vector3.ONE * size, PLANKS, PLANK_TINT, true, int(spec[2]), Basis(Vector3.UP, deg_to_rad(spec[2])))
	# Presents frozen into blocks of ice.
	var gifts: Array[Node3D] = []
	var ice: Array = []
	for spec: Array in [[Vector3(3.6, 0, -1.5), Color("b3202c"), GiftBox.Pattern.STRIPES, 20.0],
			[Vector3(-3.4, 0, 6.8), Color("1d4f8c"), GiftBox.Pattern.SNOWFLAKES, -30.0],
			[Vector3(11.0, 0, -6.5), Color("1e6b3c"), GiftBox.Pattern.TARTAN, 45.0]]:
		var gift := WinterProps.present(Vector3(0.6, 0.5, 0.6), spec[1], WinterProps.GOLD, spec[2], gifts.size() + 5)
		gift.position = spec[0]
		gift.rotation_degrees.y = spec[3]
		gifts.append(gift)
		ice.append([ice_chunk(Vector3(0.95, 0.85, 0.95), gifts.size(), 0.05),
				ToyBuilder.xf(spec[0] + Vector3(0, 0.42, 0), Vector3(0, spec[3] + 10.0, 0))])
		s.collider(spec[0] + Vector3(0, 0.42, 0), Vector3(0.95, 0.85, 0.95), Basis(Vector3.UP, deg_to_rad(spec[3] + 10.0)))
	s.root.add_child(GiftBox.merge(gifts))
	s.root.add_child(ice_mesh(ice, "PresentIce"))
	# Snow mounds against the walls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 18:
		var at := Vector3(rng.randf_range(-18.0, 18.0), 0, rng.randf_range(-22.0, 16.0))
		if absf(at.x) < 13.0 and at.z > -18.0 and at.z < 12.0:
			continue
		WinterProps.add_snow_mound(s.b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 2.2)), at), i)


# --- The Clock Tower ---

static func _tower() -> Node3D:
	var s := SetBuilder.new("Tower")
	var c := L.TOWER
	var h := L.TOWER_TOP
	var w := L.TOWER_HALF * 2.0
	s.b.textured(ToyBuilder.box(Vector3(w, h, w)), STONE, ToyBuilder.xf(c + Vector3(0, h / 2.0, 0)), 1.5, Color("bdb6ab"))
	s.collider(c + Vector3(0, h / 2.0, 0), Vector3(w, h, w))
	# Corner quoins and string courses.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			s.b.textured(ToyBuilder.box(Vector3(0.7, h, 0.7)), STONE,
					ToyBuilder.xf(c + Vector3(cx * (L.TOWER_HALF - 0.2), h / 2.0, cz * (L.TOWER_HALF - 0.2))), 1.0, Color("d6cfc4"))
	for band: float in [10.0, 18.6, h - 0.25]:
		s.b.textured(ToyBuilder.box(Vector3(w + 0.4, 0.5, w + 0.4)), STONE, ToyBuilder.xf(c + Vector3(0, band, 0)),
				1.0, Color("dcd5ca"), 0.5)
	# The top: a stone floor, frosted.
	s.b.textured(ToyBuilder.snow_sheet(Vector2(w + 0.3, w + 0.3), 0.06, 77, 0.2), "snow_02",
			ToyBuilder.xf(c + Vector3(0, h, 0)), 1.5, WinterProps.SNOW_TINT)
	# Slit windows up the faces.
	for level: float in [4.0, 7.5, 13.0, 16.0]:
		for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var side := Vector3.UP.cross(dir)
			s.b.add(ToyBuilder.box(Vector3(0.35, 1.1, 0.35)), Color("101318"),
					ToyBuilder.xf(c + dir * (L.TOWER_HALF - 0.12) + side * 1.4 + Vector3(0, level, 0)))
	# A great door on the south face, under the ice until the furnaces are lit.
	s.b.textured(ToyBuilder.box(Vector3(2.2, 3.4, 0.3)), PLANKS, ToyBuilder.xf(c + Vector3(0, 1.7, L.TOWER_HALF + 0.05)),
			1.0, Color("6d4c38"))
	_climb(s)
	return s.finish("TowerMesh")


## The walkways spiralling up the outside of the tower: corner landings on
## iron brackets, and between them ramps, jumps, stepping beams or (built by
## the level) moving platforms.
static func _climb(s: SetBuilder) -> void:
	for i in range(1, L.CLIMB_FACES + 1):
		var at := L.corner(i)
		var size := 2.5 if i == L.CLIMB_FACES else L.WALK_WIDTH
		var centre := at
		if i == L.CLIMB_FACES:
			centre = L.TOWER + (at - L.TOWER) * ((L.CLIMB_OUT - 0.25) / L.CLIMB_OUT)
			centre.y = at.y
		s.block(centre - Vector3(0, 0.15, 0), Vector3(size, 0.3, size), PLANKS, PLANK_TINT, true, i)
		_bracket(s, centre)
	for i in L.CLIMB_FACES:
		var ends := face_ends(i)
		var start: Vector3 = ends[0]
		var finish: Vector3 = ends[1]
		var flat: Vector3 = ends[2]
		var along := L.corner(i + 1) - L.corner(i)
		match L.FACE_KINDS[i]:
			"ramp":
				s.ramp(start, finish, L.WALK_WIDTH, PLANKS, PLANK_TINT, 0.18, i)
			"gap":
				var gap := 1.2 if i < 5 else 1.45
				var mid := (start + finish) / 2.0
				var half_gap := flat * gap / 2.0
				s.ramp(start, mid - half_gap - Vector3(0, along.y * gap / 2.0 / along.length(), 0), L.WALK_WIDTH, PLANKS, PLANK_TINT, 0.18, i)
				s.ramp(mid + half_gap + Vector3(0, along.y * gap / 2.0 / along.length(), 0), finish, L.WALK_WIDTH, PLANKS, PLANK_TINT, 0.18, i + 20)
			"beams":
				for k in 3:
					var t := (k + 0.5) / 3.0
					var p := start.lerp(finish, t)
					s.block(p - Vector3(0, 0.12, 0), Vector3(1.3, 0.24, L.WALK_WIDTH) if absf(flat.x) > 0.5 else Vector3(L.WALK_WIDTH, 0.24, 1.3),
							PLANKS, PLANK_TINT, true, i * 3 + k)
					_bracket(s, p)
			"mover":
				var stub := 0.9
				s.ramp(start, start + flat * stub + Vector3(0, 0.0, 0), L.WALK_WIDTH, PLANKS, PLANK_TINT, 0.18, i)
				s.ramp(finish - flat * stub, finish, L.WALK_WIDTH, PLANKS, PLANK_TINT, 0.18, i + 40)
	# Little iron railings on the outside of the corner landings.
	for i in range(1, L.CLIMB_FACES):
		var at := L.corner(i)
		var out := (at - L.TOWER)
		out.y = 0.0
		var corner_dir := out.normalized()
		s.b.finished(ToyBuilder.cylinder(0.035, 0.035, 0.9, 6), IRON, "metal",
				ToyBuilder.xf(at + corner_dir * 1.25 + Vector3(0, 0.45, 0)))


## An iron bracket under a walkway, back to the tower wall.
static func _bracket(s: SetBuilder, at: Vector3) -> void:
	var to_wall := L.TOWER - at
	to_wall.y = 0.0
	var reach := maxf(absf(to_wall.x), absf(to_wall.z)) - L.TOWER_HALF
	var dir := Vector3(signf(to_wall.x), 0, 0) if absf(to_wall.x) > absf(to_wall.z) else Vector3(0, 0, signf(to_wall.z))
	var from := at + Vector3(0, -0.35, 0)
	var to := from + dir * reach + Vector3(0, -0.9, 0)
	s.b.finished(ToyBuilder.tube(PackedVector3Array([from, to]), PackedFloat32Array([0.06, 0.06]), 6), IRON, "metal")


## The moving platforms on the "mover" faces of the climb: start, offset.
static func climb_movers() -> Array:
	var movers := []
	for i in L.CLIMB_FACES:
		if L.FACE_KINDS[i] != "mover":
			continue
		var ends := face_ends(i)
		var flat: Vector3 = ends[2]
		# Level with the stubs at each end, 1 m past them (the platform is 2 m).
		var from: Vector3 = ends[0] + flat * 1.9
		var to: Vector3 = ends[1] - flat * 1.9
		movers.append([from - Vector3(0, 0.15, 0), to - from, flat])
	return movers


## Where walkway `i` starts and ends (the edges of its corner landings, on
## the walking surface), and its flat direction.
static func face_ends(i: int) -> Array:
	var a := L.corner(i)
	var b := L.corner(i + 1)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	# Flush with each landing, so the walkway climbs between them.
	var start := a + flat * L.WALK_WIDTH / 2.0
	var finish := b - flat * L.WALK_WIDTH / 2.0
	if i == 0:
		start = a
	return [start, finish, flat]


# --- The wings ---

## West: the Toy Line. Crates standing in the ice, a frozen conveyor belt and
## a shuttling platform out to the west furnace.
static func _west_wing() -> Node3D:
	var s := SetBuilder.new("WestWing")
	var y0 := L.ICE_Y - 0.5
	s.pier(Vector2(-22, 2), 0.0, Vector2(4, 4), y0, STONE, Color("cfc9c0"), 1)
	s.pier(Vector2(-26.3, 2), 0.0, Vector2(2.2, 2.2), y0, PLANKS, PLANK_TINT, 2)
	s.pier(Vector2(-29.6, 2.6), 0.5, Vector2(2.2, 2.2), y0, PLANKS, PLANK_TINT, 3)
	# The conveyor belt: a long frozen deck on iron legs, rollers at the ends.
	var belt_top := 1.0
	s.block(Vector3(-35.5, belt_top - 0.2, 2), Vector3(8, 0.4, 1.6), PLANKS, Color("54463d"), true, 4)
	for x: float in [-39.5, -31.5]:
		s.b.finished(ToyBuilder.cylinder(0.24, 0.24, 1.7, 14), IRON, "metal",
				ToyBuilder.xf(Vector3(x, belt_top - 0.22, 2), Vector3(90, 0, 0)))
	for x: float in [-38.5, -35.5, -32.5]:
		for z: float in [1.4, 2.6]:
			s.b.finished(ToyBuilder.box(Vector3(0.18, belt_top - 0.4 - y0, 0.18)), IRON, "metal",
					ToyBuilder.xf(Vector3(x, (belt_top - 0.4 + y0) / 2.0, z)))
	# Toys frozen on the belt.
	for spec: Array in [[Vector3(-37.2, belt_top + 0.2, 2.2), Color("c0392b")], [Vector3(-33.6, belt_top + 0.2, 1.8), Color("2e86c1")]]:
		s.b.finished(ToyBuilder.box(Vector3(0.4, 0.4, 0.4)), spec[1], "leather", ToyBuilder.xf(spec[0], Vector3(0, 25, 0)))
		s.collider(spec[0], Vector3(0.4, 0.4, 0.4))
	s.pier(Vector2(-35.5, 4.0), belt_top, Vector2(2.2, 2.2), y0, STONE, Color("cfc9c0"), 5)
	s.pier(Vector2(-50.2, 2), 1.0, Vector2(3, 3), y0, PLANKS, PLANK_TINT, 6)
	s.pier(Vector2(-55.8, 2), 1.5, Vector2(6, 6), y0, STONE, Color("cfc9c0"), 7)
	_ice_drifts(s, Vector3(-38, L.ICE_Y, 2), 16.0, 1)
	return s.finish("WestMesh")


## East: the Wrapping Hall. Giant presents stepping up out of the ice to the
## roof of a half-sunk hall, then a platform sliding across to the furnace.
static func _east_wing() -> Node3D:
	var s := SetBuilder.new("EastWing")
	var y0 := L.ICE_Y - 0.5
	s.pier(Vector2(22, 2), 0.0, Vector2(4, 4), y0, STONE, Color("cfc9c0"), 11)
	var gifts: Array[Node3D] = []
	for spec: Array in [[Vector2(26.3, 2.0), 0.5, Color("b3202c"), GiftBox.Pattern.SNOWFLAKES],
			[Vector2(29.6, 1.2), 1.2, Color("1d4f8c"), GiftBox.Pattern.STRIPES],
			[Vector2(33.0, 2.4), 1.9, Color("5b2a6e"), GiftBox.Pattern.DOTS]]:
		var at: Vector2 = spec[0]
		var top: float = spec[1]
		# A stone footing in the ice with a giant present on it.
		s.pier(at, top - 1.6, Vector2(2.0, 2.0), y0, STONE, Color("bfb9b0"), gifts.size() + 12)
		var gift := WinterProps.present(Vector3(2.2, 1.6, 2.2), spec[2], WinterProps.GOLD, spec[3], gifts.size() + 20)
		gift.position = Vector3(at.x, top - 1.6, at.y)
		gifts.append(gift)
		s.collider(Vector3(at.x, top - 0.8, at.y), Vector3(2.2, 1.6, 2.2))
	s.root.add_child(GiftBox.merge(gifts))
	# The half-sunk wrapping hall: its flat roof is the way across.
	var roof_top := 2.6
	var hall := Vector3(39.6, 0, 2)
	s.b.textured(ToyBuilder.box(Vector3(7, roof_top - 0.3 - y0, 6)), TIMBER,
			ToyBuilder.xf(Vector3(hall.x, (roof_top - 0.3 + y0) / 2.0, hall.z)), 1.6, Color("b7a089"))
	s.block(Vector3(hall.x, roof_top - 0.15, hall.z), Vector3(7.4, 0.3, 6.4), PLANKS, DARK_PLANKS, true, 13)
	s.collider(Vector3(hall.x, (roof_top - 0.3 + y0) / 2.0, hall.z), Vector3(7, roof_top - 0.3 - y0, 6))
	# A chimney stack to walk round.
	s.block(Vector3(41.6, roof_top + 0.8, 3.6), Vector3(1.1, 1.6, 1.1), STONE, Color("c4bdb3"), true, 14)
	s.pier(Vector2(50.5, 2), 1.5, Vector2(6, 6), y0, STONE, Color("cfc9c0"), 15)
	_ice_drifts(s, Vector3(38, L.ICE_Y, 2), 16.0, 2)
	return s.finish("EastMesh")


## North: the Stable Bridge, out in the wind. A broken plank bridge, ice
## floes (the level adds the drifting ones), then stone steps up to the
## north furnace.
static func _north_wing() -> Node3D:
	var s := SetBuilder.new("NorthWing")
	var y0 := L.ICE_Y - 0.5
	s.pier(Vector2(0, -25), 0.0, Vector2(4, 4), y0, STONE, Color("cfc9c0"), 21)
	for spec: Array in [[-30.2, 4.0], [-35.4, 4.0]]:
		var z: float = spec[0]
		var length: float = spec[1]
		s.block(Vector3(0, -0.15, z), Vector3(2.0, 0.3, length), PLANKS, PLANK_TINT, true, int(-z))
		for dz: float in [-length / 2.0 + 0.3, length / 2.0 - 0.3]:
			for dx: float in [-0.85, 0.85]:
				s.log_beam(Vector3(dx, (-0.3 + y0) / 2.0, z + dz), Vector3.ZERO, 0.16, -0.3 - y0, false)
				s.log_beam(Vector3(dx, 0.45, z + dz), Vector3.ZERO, 0.08, 0.9, false)
	# The static floe between the two drifting ones.
	s.b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(2.6, 0.5, 2.6)), 0.06, 2.0, 3), Color("bcd9ea"), "eye",
			ToyBuilder.xf(Vector3(0, -0.35, -43.8)))
	s.b.textured(ToyBuilder.snow_sheet(Vector2(2.4, 2.4), 0.06, 4, 0.15), "snow_02", ToyBuilder.xf(Vector3(0, -0.1, -43.8)),
			1.5, WinterProps.SNOW_TINT)
	s.collider(Vector3(0, -0.35, -43.8), Vector3(2.6, 0.5, 2.6))
	s.pier(Vector2(0, -51.4), 0.8, Vector2(2.4, 2.4), y0, STONE, Color("bfb9b0"), 22)
	s.pier(Vector2(0, -54.4), 1.6, Vector2(2.2, 2.2), y0, STONE, Color("bfb9b0"), 23)
	s.pier(Vector2(0, -59.6), 1.5, Vector2(6, 6), y0, STONE, Color("cfc9c0"), 24)
	# The ruined stable wall behind the furnace.
	s.block(Vector3(0, 3.0, -62.9), Vector3(6, 3.0, 0.6), STONE, Color("b8b1a6"), true, 25)
	_ice_drifts(s, Vector3(0, L.ICE_Y, -42), 14.0, 3)
	return s.finish("NorthMesh")


## Snow drifted against the piers on the ice.
static func _ice_drifts(s: SetBuilder, around: Vector3, spread: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 97
	for i in 10:
		var at := around + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread * 0.5, spread * 0.5))
		WinterProps.add_snow_mound(s.b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 2.6)), at), i + seed * 10)


# --- Pipe supports ---

## Iron posts holding up the pipe runs, standing on the terrace or the ice.
## Out over the ice the west and east pipes run straight above the way
## across, so there the posts stand to one side and reach over on an arm.
## No post stands in a hall or in a moving platform's way.
static func _pipe_supports() -> Node3D:
	var s := SetBuilder.new("PipeSupports")
	for key: String in L.PIPE_RUNS:
		var run: Array = L.PIPE_RUNS[key]
		for k in run.size() - 1:
			var a: Vector3 = run[k]
			var b: Vector3 = run[k + 1]
			if absf(a.y - b.y) > 0.5:
				continue
			var dir := (b - a).normalized()
			var length := a.distance_to(b)
			var count := int(length / 8.0)
			for j in range(1, count + 1):
				var p := a.lerp(b, float(j) / (count + 1))
				if p.distance_to(L.TOWER) < 7.0:
					continue
				var on_terrace := _on_terrace(p)
				var aside := Vector3.ZERO
				if not on_terrace and absf(dir.x) > 0.9:
					aside = Vector3(0, 0, -SUPPORT_ASIDE)
				var foot := p + aside
				if _in_hall(foot) or _kept_clear(foot):
					continue
				var ground := 0.0 if on_terrace else L.ICE_Y
				var top := p.y - 0.4
				s.b.finished(ToyBuilder.cylinder(0.11, 0.14, top - ground, 8), IRON, "metal",
						ToyBuilder.xf(Vector3(foot.x, (top + ground) / 2.0, foot.z)))
				s.collider(Vector3(foot.x, (top + ground) / 2.0, foot.z), Vector3(0.26, top - ground, 0.26))
				s.b.finished(ToyBuilder.box(Vector3(0.7, 0.12, 0.7)), IRON, "metal", ToyBuilder.xf(Vector3(p.x, top, p.z)))
				if aside != Vector3.ZERO:
					# The arm out to the pipe, and a brace under it.
					s.b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(foot.x, top, foot.z), Vector3(p.x, top, p.z)]),
							PackedFloat32Array([0.08, 0.08]), 6), IRON, "metal")
					s.b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(foot.x, top - 1.4, foot.z),
							Vector3(p.x, top, p.z).lerp(Vector3(foot.x, top, foot.z), 0.35)]), PackedFloat32Array([0.06, 0.06]), 6),
							IRON, "metal")
	return s.finish("SupportMesh")


static func _in_hall(p: Vector3) -> bool:
	for hall: Array in L.HALLS:
		var at: Vector3 = hall[0]
		var size: Vector3 = hall[1]
		if absf(p.x - at.x) < size.x / 2.0 + 0.4 and absf(p.z - at.z) < size.z / 2.0 + 0.4:
			return true
	return false


## Places a moving platform sweeps through.
static func _kept_clear(p: Vector3) -> bool:
	for area: Rect2 in KEEP_CLEAR:
		if area.has_point(Vector2(p.x, p.z)):
			return true
	return false


static func _on_terrace(p: Vector3) -> bool:
	return p.x > L.TERRACE_MIN.x and p.x < L.TERRACE_MAX.x and p.z > L.TERRACE_MIN.y and p.z < L.TERRACE_MAX.y
