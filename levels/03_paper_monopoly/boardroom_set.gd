class_name BoardroomSet
extends RefCounted
## The static set of Level 3, "The Paper Monopoly": the boardroom of Scrooge
## & Co. in the City of London, gone shabby. Dark panelled walls, a cold
## fireplace (he won't pay for coal), sash windows onto a snowy night, shelves
## of ledgers, and the long mahogany table with the parchment world map on
## it, its continents cut from coloured card. The level adds the lights and
## everything that moves.

const L := preload("res://levels/03_paper_monopoly/map_layout.gd")
const PARCHMENT_SHADER := preload("res://levels/03_paper_monopoly/parchment.gdshader")
const LAND_SHADER := preload("res://levels/03_paper_monopoly/paper_land.gdshader")
const PLANKS := "brown_planks_04"
const STONE := "old_stone_wall"
const MAHOGANY := Color("7a4632")
const DARK_OAK := Color("4a3226")
const PANEL := Color("5b3d2c")
const WALL_GREEN := Color("2c3a31")
const CEILING := Color("3a3430")
const BRASS := Color("b48c4a")
const IRON := Color("232326")
const VELVET := Color("6e1820")
const GILT := Color("a9873e")
const LAND_TINTS := [Color("b9c49a"), Color("d6b59b"), Color("dcc48e"), Color("b3bfbf"), Color("c8b0c4"), Color("c9cf9f")]


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BoardroomSet"
	root.add_child(_room())
	root.add_child(_fireplace())
	root.add_child(_furniture())
	root.add_child(_table())
	root.add_child(_map())
	return root


# --- The room ---

static func _room() -> Node3D:
	var s := SetBuilder.new("Room")
	var half := Vector2(L.ROOM.x / 2.0, L.ROOM.z / 2.0)
	var h: float = L.ROOM.y
	s.b.textured(ToyBuilder.box(Vector3(L.ROOM.x, 0.1, L.ROOM.z)), PLANKS, ToyBuilder.xf(Vector3(0, -0.05, 0)), 1.4, Color("8a6a52"))
	s.collider(Vector3(0, -0.05, 0), Vector3(L.ROOM.x, 0.1, L.ROOM.z))
	# A worn Turkey rug under the table.
	s.b.add(ToyBuilder.box(Vector3(5.6, 0.012, 3.6)), Color("5a1e22"), ToyBuilder.xf(Vector3(0, 0.006, 0)))
	s.b.add(ToyBuilder.box(Vector3(5.2, 0.014, 3.2)), Color("7a3a2c"), ToyBuilder.xf(Vector3(0, 0.007, 0)))
	s.b.add(ToyBuilder.box(Vector3(4.6, 0.016, 2.6)), Color("3c2a3a"), ToyBuilder.xf(Vector3(0, 0.008, 0)))
	s.b.add(ToyBuilder.box(Vector3(1.2, 0.017, 1.2)), Color("8a6a3a"),
			ToyBuilder.xf(Vector3(0, 0.009, 0), Vector3(0, 45, 0)))
	s.b.add(ToyBuilder.box(Vector3(L.ROOM.x, 0.1, L.ROOM.z)), CEILING, ToyBuilder.xf(Vector3(0, h + 0.05, 0)))
	for k in 5:
		s.b.textured(ToyBuilder.box(Vector3(0.22, 0.24, L.ROOM.z)), PLANKS, ToyBuilder.xf(Vector3(-3.6 + k * 1.8, h - 0.12, 0)), 1.0, DARK_OAK)
	# The four walls: panelled wainscot below a dado rail, green paint above,
	# a cornice at the top. Openings are left for the door, windows and hearth.
	var walls := [
		[Vector3(0, 0, -half.y), Vector3(0, 0, 1), L.ROOM.x],
		[Vector3(0, 0, half.y), Vector3(0, 0, -1), L.ROOM.x],
		[Vector3(-half.x, 0, 0), Vector3(1, 0, 0), L.ROOM.z],
		[Vector3(half.x, 0, 0), Vector3(-1, 0, 0), L.ROOM.z],
	]
	for spec: Array in walls:
		var at: Vector3 = spec[0]
		var inward: Vector3 = spec[1]
		var length: float = spec[2]
		var along := Vector3.UP.cross(inward)
		var basis := Basis(along, Vector3.UP, inward)
		s.b.add(ToyBuilder.box(Vector3(length, h, 0.1)), WALL_GREEN, Transform3D(basis, at - inward * 0.05 + Vector3(0, h / 2.0, 0)))
		s.b.textured(ToyBuilder.box(Vector3(length, 1.15, 0.05)), PLANKS, Transform3D(basis, at + inward * 0.025 + Vector3(0, 0.575, 0)),
				0.8, PANEL)
		s.b.textured(ToyBuilder.box(Vector3(length, 0.07, 0.07)), PLANKS, Transform3D(basis, at + inward * 0.06 + Vector3(0, 1.17, 0)),
				0.8, DARK_OAK)
		s.b.textured(ToyBuilder.box(Vector3(length, 0.16, 0.06)), PLANKS, Transform3D(basis, at + inward * 0.05 + Vector3(0, 0.08, 0)),
				0.8, DARK_OAK)
		s.b.add(ToyBuilder.box(Vector3(length, 0.14, 0.14)), Color("3d3530"), Transform3D(basis, at + inward * 0.05 + Vector3(0, h - 0.07, 0)))
		# Raised panels along the wainscot.
		var count := int(length / 0.9)
		for k in count:
			var x := -length / 2.0 + (k + 0.5) * length / count
			var centre := at + along * x + inward * 0.055 + Vector3(0, 0.6, 0)
			s.b.textured(ToyBuilder.box(Vector3(length / count - 0.16, 0.78, 0.02)), PLANKS, Transform3D(basis, centre), 0.6, PANEL.lightened(0.06))
			for side: float in [-1.0, 1.0]:
				s.b.textured(ToyBuilder.box(Vector3(length / count - 0.12, 0.03, 0.03)), PLANKS,
						Transform3D(basis, centre + Vector3(0, side * 0.41, 0)), 0.6, DARK_OAK)
				s.b.textured(ToyBuilder.box(Vector3(0.03, 0.85, 0.03)), PLANKS,
						Transform3D(basis, centre + along * side * (length / count - 0.12) / 2.0), 0.6, DARK_OAK)
	# Sash windows on the west wall, with heavy curtains.
	for at: Vector3 in L.WINDOWS:
		_window(s.b, at)
	# The door on the east wall, with "SCROOGE & CO." on its glass.
	_door(s, L.DOOR)
	# Framed engravings on the south wall.
	for x: float in [-2.6, 2.6]:
		_frame(s.b, Vector3(x, 1.85, half.y - 0.06), Vector3(0, 0, -1), Vector2(0.7, 0.55), Color("6a6052"))
	_lamp(s.b, L.LAMP)
	return s.finish("Room")


## The oil lamp hung over the table: the one light he pays for.
static func _lamp(b: ToyBuilder, at: Vector3) -> void:
	var top: float = L.ROOM.y
	var ring := at + Vector3(0, 0.42, 0)
	b.finished(ToyBuilder.cylinder(0.07, 0.1, 0.03, 18), BRASS, "metal", ToyBuilder.xf(Vector3(at.x, top - 0.015, at.z)))
	b.finished(ToyBuilder.cylinder(0.008, 0.008, top - ring.y, 8), BRASS, "metal", ToyBuilder.xf(Vector3(at.x, (top + ring.y) / 2.0, at.z)))
	b.finished(ToyBuilder.torus(0.03, 0.006, 14, 5), BRASS, "metal", ToyBuilder.xf(ring))
	for k in 3:
		var a := TAU * k / 3.0
		var rim := at + Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
		b.finished(ToyBuilder.curve(PackedVector3Array([ring, rim]), PackedFloat32Array([0.004, 0.004]), 5, 1), IRON, "metal")
	# A cream glass shade over a brass font, and the glowing chimney.
	b.add(ToyBuilder.lathe(PackedVector2Array([Vector2(0.07, 0.12), Vector2(0.28, -0.02), Vector2(0.27, -0.03), Vector2(0.065, 0.11)]), 24),
			Color("e8dcc0"), ToyBuilder.xf(at))
	b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, -0.13), Vector2(0.07, -0.11), Vector2(0.1, -0.05), Vector2(0.075, 0.0),
			Vector2(0.03, 0.02), Vector2(0, 0.02)]), 18), BRASS, "metal", ToyBuilder.xf(at))
	b.add(ToyBuilder.cylinder(0.03, 0.042, 0.16, 14), Color("ffcf86"), ToyBuilder.xf(at + Vector3(0, 0.1, 0)), true)


static func _window(b: ToyBuilder, at: Vector3) -> void:
	var inward := Vector3(1, 0, 0)
	var size := Vector2(1.1, 1.9)
	var basis := Basis(Vector3(0, 0, -1), Vector3.UP, inward)
	# Night outside: deep blue glass, a little lighter at the top.
	b.add(ToyBuilder.box(Vector3(size.x, size.y, 0.02)), Color(0.06, 0.09, 0.2), Transform3D(basis, at), true)
	b.add(ToyBuilder.box(Vector3(size.x, size.y * 0.35, 0.021)), Color(0.12, 0.16, 0.3), Transform3D(basis, at + Vector3(0, size.y * 0.32, 0)), true)
	# Frame, sash bars and a snowy sill outside.
	for side: float in [-1.0, 1.0]:
		b.textured(ToyBuilder.box(Vector3(0.09, size.y + 0.18, 0.14)), PLANKS, Transform3D(basis, at + basis.x * side * (size.x / 2.0 + 0.04)), 0.6, DARK_OAK)
		b.textured(ToyBuilder.box(Vector3(size.x + 0.18, 0.09, 0.14)), PLANKS, Transform3D(basis, at + Vector3(0, side * (size.y / 2.0 + 0.04), 0)), 0.6, DARK_OAK)
	b.textured(ToyBuilder.box(Vector3(size.x, 0.05, 0.06)), PLANKS, Transform3D(basis, at + inward * 0.02), 0.6, DARK_OAK)
	for k in [-1, 1]:
		b.textured(ToyBuilder.box(Vector3(0.025, size.y, 0.04)), PLANKS, Transform3D(basis, at + inward * 0.02 + basis.x * k * size.x / 6.0), 0.6, DARK_OAK)
		b.textured(ToyBuilder.box(Vector3(size.x, 0.025, 0.04)), PLANKS, Transform3D(basis, at + inward * 0.02 + Vector3(0, k * size.y / 4.0, 0)), 0.6, DARK_OAK)
	b.textured(ToyBuilder.box(Vector3(size.x + 0.3, 0.06, 0.24)), PLANKS, Transform3D(basis, at + inward * 0.08 + Vector3(0, -size.y / 2.0 - 0.1, 0)), 0.6, DARK_OAK)
	b.add(ToyBuilder.lumpy(ToyBuilder.box(Vector3(size.x - 0.05, 0.08, 0.06)), 0.015, 8.0, 3), Color(0.75, 0.8, 0.95),
			Transform3D(basis, at - inward * 0.03 + Vector3(0, -size.y / 2.0 + 0.04, 0)), true)
	# Curtains: velvet folds gathered by tie-backs, and a pelmet.
	for side: float in [-1.0, 1.0]:
		var hang := at + inward * 0.16 + basis.x * side * (size.x / 2.0 + 0.18)
		for f in 5:
			var off := basis.x * side * (f - 2) * 0.06
			var pts := PackedVector3Array([hang + off + Vector3(0, size.y / 2.0 + 0.32, 0), hang + off * 0.4 + Vector3(0, 0.05, 0),
					hang + off * 0.5 + basis.x * -side * 0.05 + Vector3(0, -0.15, 0), hang + off * 1.2 + Vector3(0, -size.y / 2.0 - 0.6, 0)])
			b.finished(ToyBuilder.curve(pts, PackedFloat32Array([0.045, 0.03, 0.03, 0.05]), 8, 5), VELVET.darkened(0.05 * (f % 2)), "velvet")
		b.finished(ToyBuilder.torus(0.07, 0.012, 12, 5), GILT, "metal", Transform3D(basis, hang + Vector3(0, -0.12, 0.0)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(size.x + 0.9, 0.3, 0.14)), 0.02, 6.0, 5), VELVET, "velvet",
			Transform3D(basis, at + inward * 0.18 + Vector3(0, size.y / 2.0 + 0.32, 0)))


static func _door(s: SetBuilder, at: Vector3) -> void:
	var basis := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	var inward := Vector3(-1, 0, 0)
	var c := at + inward * 0.06 + Vector3(0, 1.1, 0)
	s.b.textured(ToyBuilder.box(Vector3(1.05, 2.2, 0.06)), PLANKS, Transform3D(basis, c), 0.6, DARK_OAK)
	s.b.textured(ToyBuilder.box(Vector3(0.75, 0.75, 0.02)), PLANKS, Transform3D(basis, c + inward * 0.035 + Vector3(0, -0.5, 0)), 0.6, PANEL)
	# Frosted glass in the top half.
	s.b.add(ToyBuilder.box(Vector3(0.7, 0.7, 0.03)), Color("8d9aa0"), Transform3D(basis, c + Vector3(0, 0.45, 0)))
	for side: float in [-1.0, 1.0]:
		s.b.textured(ToyBuilder.box(Vector3(0.12, 2.35, 0.1)), PLANKS, Transform3D(basis, at + inward * 0.05 + basis.x * side * 0.6 + Vector3(0, 1.17, 0)), 0.6, DARK_OAK)
	s.b.textured(ToyBuilder.box(Vector3(1.32, 0.14, 0.1)), PLANKS, Transform3D(basis, at + inward * 0.05 + Vector3(0, 2.3, 0)), 0.6, DARK_OAK)
	s.b.finished(ToyBuilder.sphere(0.035, 10), BRASS, "metal", ToyBuilder.xf(c + inward * 0.07 + basis.x * 0.4 + Vector3(0, -0.05, 0)))
	var sign := Label3D.new()
	sign.name = "DoorSign"
	sign.text = "SCROOGE & CO.\nCOUNTING-HOUSE"
	sign.font_size = 64
	sign.pixel_size = 0.0012
	sign.modulate = Color("c9a24e")
	sign.outline_size = 0
	sign.shaded = true
	sign.position = c + inward * 0.02 + Vector3(0, 0.5, 0)
	sign.rotation.y = -PI / 2.0
	s.root.add_child(sign)


static func _frame(b: ToyBuilder, at: Vector3, normal: Vector3, size: Vector2, canvas: Color) -> void:
	var basis := Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
	b.add(ToyBuilder.box(Vector3(size.x, size.y, 0.015)), canvas, Transform3D(basis, at))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.box(Vector3(0.06, size.y + 0.12, 0.04)), GILT, "metal", Transform3D(basis, at + basis.x * side * (size.x / 2.0 + 0.03)))
		b.finished(ToyBuilder.box(Vector3(size.x + 0.12, 0.06, 0.04)), GILT, "metal", Transform3D(basis, at + Vector3(0, side * (size.y / 2.0 + 0.03), 0)))


# --- The cold fireplace ---

static func _fireplace() -> Node3D:
	var s := SetBuilder.new("Fireplace")
	var at: Vector3 = L.FIREPLACE + Vector3(0, 0, 0.12)
	# Stone surround and a carved mantel shelf.
	for side: float in [-1.0, 1.0]:
		s.b.textured(ToyBuilder.box(Vector3(0.38, 1.2, 0.3)), STONE, ToyBuilder.xf(at + Vector3(side * 0.82, 0.6, 0)), 0.7, Color("8d877c"))
	s.b.textured(ToyBuilder.box(Vector3(2.0, 0.3, 0.3)), STONE, ToyBuilder.xf(at + Vector3(0, 1.32, 0)), 0.7, Color("8d877c"))
	s.b.textured(ToyBuilder.box(Vector3(2.3, 0.08, 0.42)), STONE, ToyBuilder.xf(at + Vector3(0, 1.51, 0.04)), 0.7, Color("a39b8e"))
	s.b.textured(ToyBuilder.box(Vector3(2.1, 0.06, 0.6)), STONE, ToyBuilder.xf(at + Vector3(0, 0.03, 0.2)), 0.7, Color("6f6a62"))
	# The firebox, black with old soot, and an empty iron grate with a few dead coals.
	s.b.add(ToyBuilder.box(Vector3(1.26, 1.18, 0.05)), Color("141212"), ToyBuilder.xf(at + Vector3(0, 0.6, -0.12)))
	for side: float in [-1.0, 1.0]:
		s.b.add(ToyBuilder.box(Vector3(0.04, 1.18, 0.3)), Color("1d1b1a"), ToyBuilder.xf(at + Vector3(side * 0.62, 0.6, 0)))
	s.b.add(ToyBuilder.box(Vector3(1.26, 0.04, 0.3)), Color("1d1b1a"), ToyBuilder.xf(at + Vector3(0, 1.17, 0)))
	var grate := at + Vector3(0, 0.0, 0.02)
	s.b.finished(ToyBuilder.box(Vector3(0.7, 0.03, 0.26)), IRON, "metal", ToyBuilder.xf(grate + Vector3(0, 0.16, 0)))
	for k in 6:
		s.b.finished(ToyBuilder.cylinder(0.008, 0.008, 0.2, 6), IRON, "metal", ToyBuilder.xf(grate + Vector3(-0.3 + k * 0.12, 0.27, 0.13)))
	s.b.finished(ToyBuilder.box(Vector3(0.72, 0.02, 0.02)), IRON, "metal", ToyBuilder.xf(grate + Vector3(0, 0.37, 0.13)))
	for side: float in [-1.0, 1.0]:
		s.b.finished(ToyBuilder.cylinder(0.015, 0.02, 0.16, 8), IRON, "metal", ToyBuilder.xf(grate + Vector3(side * 0.33, 0.08, 0.1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for k in 7:
		s.b.add(ToyBuilder.lumpy(ToyBuilder.sphere(0.035, 6), 0.012, 9.0, k), Color("1a1a1c"),
				ToyBuilder.xf(grate + Vector3(rng.randf_range(-0.22, 0.22), 0.2, rng.randf_range(-0.05, 0.06))))
	s.b.add(ToyBuilder.lumpy(ToyBuilder.box(Vector3(0.8, 0.03, 0.25)), 0.01, 7.0, 2), Color("5c5853"), ToyBuilder.xf(at + Vector3(0, 0.07, -0.02)))
	# An empty coal scuttle beside it.
	var scuttle := at + Vector3(1.3, 0, 0.35)
	s.b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.14, 0), Vector2(0.16, 0.2), Vector2(0.12, 0.32),
			Vector2(0.11, 0.33), Vector2(0.0, 0.33)]), 16), Color("3a3633"), "metal", ToyBuilder.xf(scuttle))
	s.b.finished(ToyBuilder.torus(0.11, 0.008, 16, 5), BRASS, "metal", ToyBuilder.xf(scuttle + Vector3(0, 0.36, 0), Vector3(90, 0, 0)))
	# On the mantel: a clock that has stopped, and two cold candlesticks.
	var shelf := at + Vector3(0, 1.55, 0.05)
	s.b.textured(ToyBuilder.box(Vector3(0.32, 0.36, 0.14)), PLANKS, ToyBuilder.xf(shelf + Vector3(0, 0.18, 0)), 0.4, DARK_OAK)
	s.b.add(ToyBuilder.cylinder(0.1, 0.1, 0.01, 24), Color("e8e0cc"), ToyBuilder.xf(shelf + Vector3(0, 0.22, 0.072), Vector3(90, 0, 0)))
	s.b.add(ToyBuilder.box(Vector3(0.006, 0.075, 0.004)), IRON, ToyBuilder.xf(shelf + Vector3(0, 0.25, 0.08)))
	s.b.add(ToyBuilder.box(Vector3(0.05, 0.006, 0.004)), IRON, ToyBuilder.xf(shelf + Vector3(0.02, 0.22, 0.08)))
	for side: float in [-1.0, 1.0]:
		var stick := shelf + Vector3(side * 0.7, 0, 0)
		s.b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.06, 0.015), Vector2(0.02, 0.03),
				Vector2(0.015, 0.2), Vector2(0.035, 0.22), Vector2(0.02, 0.23), Vector2(0, 0.23)]), 14), BRASS, "metal", ToyBuilder.xf(stick))
		s.b.add(ToyBuilder.cylinder(0.014, 0.015, 0.09, 10), Color("e9e2cf"), ToyBuilder.xf(stick + Vector3(0, 0.27, 0)))
	# His portrait above, gloomy and well varnished.
	_frame(s.b, at + Vector3(0, 2.45, -0.04), Vector3(0, 0, 1), Vector2(0.8, 0.95), Color("2a2420"))
	s.b.add(ToyBuilder.sphere(0.13, 12), Color("8a7462"), ToyBuilder.xf(at + Vector3(0, 2.58, -0.02), Vector3.ZERO, Vector3(0.85, 1.05, 0.15)))
	s.b.add(ToyBuilder.sphere(0.25, 12), Color("1c1a1c"), ToyBuilder.xf(at + Vector3(0, 2.2, -0.02), Vector3.ZERO, Vector3(1.0, 0.8, 0.1)))
	return s.finish("Fireplace")


# --- Furniture ---

static func _furniture() -> Node3D:
	var s := SetBuilder.new("Furniture")
	# A tall bookcase of ledgers on the east wall, either side of the door.
	for z: float in [-1.6, -3.0]:
		_bookcase(s.b, Vector3(L.ROOM.x / 2.0 - 0.25, 0, z), int(absf(z) * 10.0))
	# Scrooge's high-backed chair at the head of the table, and plain ones down the sides.
	_chair(s.b, L.SCROOGE_SPOT + Vector3(0, 0, -0.75), 0.0, true)
	for k in 3:
		for side: float in [-1.0, 1.0]:
			_chair(s.b, Vector3(-1.3 + k * 1.3, 0, side * (L.TABLE_SIZE.y / 2.0 + 0.45)), 0.0 if side > 0 else 180.0, false)
	# A clerk's high desk by the window with a ledger open on it and a stool.
	var desk := Vector3(-3.6, 0, 2.6)
	s.b.textured(ToyBuilder.box(Vector3(1.0, 0.06, 0.6)), PLANKS, ToyBuilder.xf(desk + Vector3(0, 1.1, 0), Vector3(-12, 0, 0)), 0.5, DARK_OAK)
	for x: float in [-0.45, 0.45]:
		for z: float in [-0.25, 0.25]:
			s.b.textured(ToyBuilder.box(Vector3(0.05, 1.08, 0.05)), PLANKS, ToyBuilder.xf(desk + Vector3(x, 0.54, z)), 0.5, DARK_OAK)
	s.b.add(ToyBuilder.box(Vector3(0.6, 0.02, 0.4)), Color("e6dcc2"), ToyBuilder.xf(desk + Vector3(0, 1.15, 0), Vector3(-12, 0, 0)))
	s.b.add(ToyBuilder.box(Vector3(0.012, 0.025, 0.4)), Color("8a2a24"), ToyBuilder.xf(desk + Vector3(0, 1.16, 0), Vector3(-12, 0, 0)))
	var stool := desk + Vector3(0, 0, 0.7)
	s.b.textured(ToyBuilder.cylinder(0.18, 0.18, 0.05, 16), PLANKS, ToyBuilder.xf(stool + Vector3(0, 0.78, 0)), 0.5, DARK_OAK)
	for k in 3:
		var a := TAU * k / 3.0
		s.b.textured(ToyBuilder.box(Vector3(0.035, 0.8, 0.035)), PLANKS, ToyBuilder.xf(stool + Vector3(cos(a) * 0.13, 0.39, sin(a) * 0.13),
				Vector3(sin(a) * 6.0, 0, -cos(a) * 6.0)), 0.5, DARK_OAK)
	# A grandfather clock in the corner, stopped at a quarter to midnight.
	var clock := Vector3(3.9, 0, -3.45)
	s.b.textured(ToyBuilder.box(Vector3(0.5, 2.1, 0.32)), PLANKS, ToyBuilder.xf(clock + Vector3(0, 1.05, 0)), 0.5, MAHOGANY.darkened(0.2))
	s.b.textured(ToyBuilder.box(Vector3(0.6, 0.12, 0.38)), PLANKS, ToyBuilder.xf(clock + Vector3(0, 2.16, 0)), 0.5, MAHOGANY.darkened(0.3))
	s.b.add(ToyBuilder.cylinder(0.16, 0.16, 0.01, 24), Color("ece4d0"), ToyBuilder.xf(clock + Vector3(0, 1.8, 0.165), Vector3(90, 0, 0)))
	s.b.add(ToyBuilder.box(Vector3(0.006, 0.12, 0.004)), IRON, ToyBuilder.xf(clock + Vector3(0, 1.85, 0.172)))
	s.b.add(ToyBuilder.box(Vector3(0.1, 0.006, 0.004)), IRON, ToyBuilder.xf(clock + Vector3(-0.04, 1.8, 0.172)))
	s.b.finished(ToyBuilder.cylinder(0.07, 0.07, 0.01, 18), BRASS, "metal", ToyBuilder.xf(clock + Vector3(0, 1.0, 0.165), Vector3(90, 0, 0)))
	# A safe, firmly shut.
	var safe := Vector3(-3.9, 0, -3.3)
	s.b.finished(ToyBuilder.box(Vector3(0.8, 1.0, 0.7)), Color("2e3a33"), "metal", ToyBuilder.xf(safe + Vector3(0, 0.5, 0)))
	s.b.finished(ToyBuilder.cylinder(0.08, 0.08, 0.03, 18), BRASS, "metal", ToyBuilder.xf(safe + Vector3(0.1, 0.55, 0.36), Vector3(90, 0, 0)))
	s.b.finished(ToyBuilder.box(Vector3(0.04, 0.2, 0.04)), BRASS, "metal", ToyBuilder.xf(safe + Vector3(-0.22, 0.55, 0.36)))
	return s.finish("Furniture")


static func _bookcase(b: ToyBuilder, at: Vector3, seed: int) -> void:
	var basis := Basis(Vector3.UP, -PI / 2.0)
	var w := 1.1
	b.textured(ToyBuilder.box(Vector3(w, 2.5, 0.05)), PLANKS, Transform3D(basis, at + Vector3(0.18, 1.25, 0)), 0.5, DARK_OAK)
	for side: float in [-1.0, 1.0]:
		b.textured(ToyBuilder.box(Vector3(0.05, 2.5, 0.4)), PLANKS, Transform3D(basis, at + basis.x * side * w / 2.0 + Vector3(0, 1.25, 0)), 0.5, DARK_OAK)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var spines := [Color("5a1e1e"), Color("23382c"), Color("3a2a1c"), Color("6b5a3a"), Color("1e2a3a")]
	for shelf in 6:
		var y := 0.06 + shelf * 0.44
		b.textured(ToyBuilder.box(Vector3(w, 0.035, 0.38)), PLANKS, Transform3D(basis, at + Vector3(0, y, 0)), 0.5, DARK_OAK)
		if shelf == 5:
			continue
		var x := -w / 2.0 + 0.04
		while x < w / 2.0 - 0.08:
			var thick := rng.randf_range(0.04, 0.08)
			var tall := rng.randf_range(0.28, 0.38)
			var col: Color = spines[rng.randi() % spines.size()]
			b.finished(ToyBuilder.box(Vector3(thick, tall, 0.26)), col.darkened(rng.randf() * 0.2), "leather",
					Transform3D(basis, at + basis.x * (x + thick / 2.0) + Vector3(0, y + 0.02 + tall / 2.0, 0.0)))
			b.finished(ToyBuilder.box(Vector3(thick * 0.9, 0.012, 0.005)), GILT, "metal",
					Transform3D(basis, at + basis.x * (x + thick / 2.0) + basis.z * 0.131 + Vector3(0, y + 0.02 + tall * 0.75, 0)))
			x += thick + 0.004
	b.textured(ToyBuilder.box(Vector3(w + 0.1, 0.1, 0.44)), PLANKS, Transform3D(basis, at + Vector3(0, 2.52, 0)), 0.5, DARK_OAK)


static func _chair(b: ToyBuilder, at: Vector3, yaw: float, grand: bool) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var seat := 0.47
	b.textured(ToyBuilder.box(Vector3(0.5, 0.05, 0.48)), PLANKS, Transform3D(basis, at + Vector3(0, seat, 0)), 0.4, MAHOGANY)
	b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(0.44, 0.05, 0.42)), 0.01, 5.0, 2), Color("4a1a1e"), "leather",
			Transform3D(basis, at + Vector3(0, seat + 0.045, 0)))
	for x: float in [-0.21, 0.21]:
		for z: float in [-0.2, 0.2]:
			b.textured(ToyBuilder.cylinder(0.022, 0.018, seat, 8), PLANKS, Transform3D(basis, at + basis * Vector3(x, seat / 2.0, z)), 0.4, MAHOGANY)
	var back := 1.35 if grand else 0.6
	for x: float in [-0.21, 0.21]:
		b.textured(ToyBuilder.box(Vector3(0.04, back, 0.04)), PLANKS, Transform3D(basis, at + basis * Vector3(x, seat + back / 2.0, 0.22)), 0.4, MAHOGANY)
	if grand:
		b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(0.42, back - 0.15, 0.06)), 0.012, 5.0, 4), Color("4a1a1e"), "leather",
				Transform3D(basis, at + basis * Vector3(0, seat + back / 2.0, 0.22)))
		b.textured(ToyBuilder.box(Vector3(0.56, 0.1, 0.07)), PLANKS, Transform3D(basis, at + basis * Vector3(0, seat + back, 0.22)), 0.4, MAHOGANY)
	else:
		for k in 3:
			b.textured(ToyBuilder.box(Vector3(0.4, 0.05, 0.025)), PLANKS, Transform3D(basis, at + basis * Vector3(0, seat + 0.2 + k * 0.17, 0.22)), 0.4, MAHOGANY)


# --- The table ---

static func _table() -> Node3D:
	var s := SetBuilder.new("Table")
	var top: float = L.TABLE_TOP
	var size: Vector2 = L.TABLE_SIZE
	s.b.textured(ToyBuilder.box(Vector3(size.x, 0.05, size.y)), PLANKS, ToyBuilder.xf(Vector3(0, top - 0.025, 0)), 0.9, MAHOGANY)
	# A moulded edge and a deep apron.
	for side: float in [-1.0, 1.0]:
		s.b.textured(ToyBuilder.cylinder(0.03, 0.03, size.x + 0.02, 10), PLANKS, ToyBuilder.xf(Vector3(0, top - 0.03, side * size.y / 2.0), Vector3(0, 0, 90)),
				0.9, MAHOGANY.darkened(0.1))
		s.b.textured(ToyBuilder.cylinder(0.03, 0.03, size.y + 0.02, 10), PLANKS, ToyBuilder.xf(Vector3(side * size.x / 2.0, top - 0.03, 0), Vector3(90, 0, 0)),
				0.9, MAHOGANY.darkened(0.1))
		s.b.textured(ToyBuilder.box(Vector3(size.x - 0.3, 0.14, 0.04)), PLANKS, ToyBuilder.xf(Vector3(0, top - 0.12, side * (size.y / 2.0 - 0.15))), 0.9, MAHOGANY.darkened(0.15))
		s.b.textured(ToyBuilder.box(Vector3(0.04, 0.14, size.y - 0.3)), PLANKS, ToyBuilder.xf(Vector3(side * (size.x / 2.0 - 0.15), top - 0.12, 0)), 0.9, MAHOGANY.darkened(0.15))
	# Six turned legs.
	var leg := ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.045, 0.03), Vector2(0.035, 0.06),
			Vector2(0.03, 0.25), Vector2(0.055, 0.38), Vector2(0.06, 0.45), Vector2(0.045, 0.52), Vector2(0.035, 0.6),
			Vector2(0.045, 0.65), Vector2(0.05, top - 0.05), Vector2(0.0, top - 0.05)]), 14)
	for x: float in [-size.x / 2.0 + 0.2, 0.0, size.x / 2.0 - 0.2]:
		for z: float in [-size.y / 2.0 + 0.2, size.y / 2.0 - 0.2]:
			s.b.textured(leg, PLANKS, ToyBuilder.xf(Vector3(x, 0, z)), 0.5, MAHOGANY.darkened(0.1))
	s.collider(Vector3(0, top / 2.0, 0), Vector3(size.x, top, size.y))
	# Scrooge's end: ledgers, inkwell and quill, a cash box and a counted pile of coins.
	var head := Vector3(0, top, -size.y / 2.0 + 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 4:
		var col: Color = [Color("4a1c1c"), Color("1e3326"), Color("3a2a1a"), Color("4a1c1c")][k]
		s.b.finished(ToyBuilder.box(Vector3(0.3, 0.05, 0.22)), col, "leather",
				ToyBuilder.xf(head + Vector3(-0.75, 0.025 + k * 0.05, 0.02), Vector3(0, rng.randf_range(-8, 8), 0)))
		s.b.add(ToyBuilder.box(Vector3(0.28, 0.04, 0.2)), Color("e3d8bd"),
				ToyBuilder.xf(head + Vector3(-0.74, 0.025 + k * 0.05, 0.02), Vector3(0, rng.randf_range(-8, 8), 0)))
	var ink := head + Vector3(0.55, 0, 0.05)
	s.b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.045, 0), Vector2(0.05, 0.03), Vector2(0.035, 0.06),
			Vector2(0.015, 0.065), Vector2(0.018, 0.075), Vector2(0, 0.075)]), 14), Color("1a2230"), "metal", ToyBuilder.xf(ink))
	s.b.finished(ToyBuilder.curve(PackedVector3Array([ink + Vector3(0, 0.06, 0), ink + Vector3(0.03, 0.15, -0.03), ink + Vector3(0.07, 0.26, -0.05)]),
			PackedFloat32Array([0.003, 0.012, 0.002]), 6, 4), Color("e9e3d4"), "fur")
	var box_at := head + Vector3(0.95, 0, 0.0)
	s.b.finished(ToyBuilder.box(Vector3(0.28, 0.12, 0.18)), Color("2c2a2a"), "metal", ToyBuilder.xf(box_at + Vector3(0, 0.06, 0)))
	s.b.finished(ToyBuilder.box(Vector3(0.05, 0.04, 0.01)), BRASS, "metal", ToyBuilder.xf(box_at + Vector3(0, 0.08, 0.095)))
	for k in 5:
		var stack := head + Vector3(0.2 + k * 0.07, 0, 0.12 + (k % 2) * 0.05)
		for c in 3 + k % 4:
			s.b.finished(ToyBuilder.cylinder(0.018, 0.018, 0.005, 14), Color("d8b25a"), "metal",
					ToyBuilder.xf(stack + Vector3(rng.randf_range(-0.002, 0.002), 0.003 + c * 0.0055, rng.randf_range(-0.002, 0.002))))
	# Santa's end: a pewter mug of cocoa Scrooge didn't offer, and Santa's own little notebook.
	var foot := Vector3(0, top, size.y / 2.0 - 0.18)
	s.b.finished(ToyBuilder.box(Vector3(0.15, 0.02, 0.2)), Color("7a1c1c"), "leather", ToyBuilder.xf(foot + Vector3(-0.9, 0.01, 0), Vector3(0, 12, 0)))
	return s.finish("Table")


# --- The map ---

static func _map() -> Node3D:
	var root := Node3D.new()
	root.name = "Map"
	var sheet := PlaneMesh.new()
	sheet.size = L.MAP_SIZE
	var parchment := ShaderMaterial.new()
	parchment.shader = PARCHMENT_SHADER
	parchment.set_shader_parameter("noise_tex", CharacterFinish.noise())
	parchment.set_shader_parameter("map_size", L.MAP_SIZE)
	parchment.set_shader_parameter("lat_top", L.LAT_TOP)
	parchment.set_shader_parameter("lat_bottom", L.LAT_BOTTOM)
	sheet.material = parchment
	var paper := MeshInstance3D.new()
	paper.name = "Parchment"
	paper.mesh = sheet
	paper.position = Vector3(0, L.TABLE_TOP + 0.002, 0)
	root.add_child(paper)
	var pieces := MeshPieces.new()
	var k := 0
	for name: String in L.CONTINENTS:
		_continent(pieces, L.CONTINENTS[name], LAND_TINTS[k % LAND_TINTS.size()])
		k += 1
	var land_mat := ShaderMaterial.new()
	land_mat.shader = LAND_SHADER
	land_mat.set_shader_parameter("noise_tex", CharacterFinish.noise())
	var mesh := ArrayMesh.new()
	pieces.add_to(mesh, land_mat)
	var land := MeshInstance3D.new()
	land.name = "Continents"
	land.mesh = mesh
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(land)
	# Brass pins at the map's corners holding it down.
	var b := ToyBuilder.new()
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var corner := Vector3(x * (L.MAP_SIZE.x / 2.0 - 0.03), L.TABLE_TOP + 0.004, z * (L.MAP_SIZE.y / 2.0 - 0.03))
			b.finished(ToyBuilder.cylinder(0.012, 0.014, 0.006, 14), BRASS, "metal", ToyBuilder.xf(corner))
	root.add_child(b.build(0.0, "Pins"))
	return root


## A continent cut from card: a flat top (with an inked rim along the coast)
## and short cut edges down to the parchment.
static func _continent(pieces: MeshPieces, outline: Array, tint: Color) -> void:
	var pts := PackedVector2Array()
	for ll: Vector2 in outline:
		var p := L.at(ll)
		pts.append(Vector2(p.x, p.z))
	var top: float = L.TABLE_TOP + 0.002 + L.LAND_HEIGHT
	var base: float = L.TABLE_TOP + 0.002
	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		push_warning("Couldn't cut a continent (%d points)" % pts.size())
		return
	var first := pieces.verts.size()
	for p in pts:
		pieces.vertex(Vector3(p.x, top, p.y), Vector3.UP, p, Color(tint, 1.0))
	for t in range(0, tris.size(), 3):
		pieces.tri(first + tris[t], first + tris[t + 1], first + tris[t + 2])
	# Which way is inland, from the outline's winding.
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var c := pts[(i + 1) % pts.size()]
		area += a.x * c.y - c.x * a.y
	var turn := 1.0 if area > 0.0 else -1.0
	var n := pts.size()
	var inland := PackedVector2Array()
	for i in n:
		var prev := (pts[i] - pts[(i - 1 + n) % n]).normalized()
		var next := (pts[(i + 1) % n] - pts[i]).normalized()
		var normal := (Vector2(-prev.y, prev.x) + Vector2(-next.y, next.x)).normalized() * turn
		inland.append(normal)
	# Ink along the coast: a thin strip just inside the edge.
	var rim := 0.0028
	for i in n:
		var j := (i + 1) % n
		var a := pieces.vertex(Vector3(pts[i].x, top + 0.0002, pts[i].y), Vector3.UP, pts[i], Color(tint, 0.0))
		var b := pieces.vertex(Vector3(pts[j].x, top + 0.0002, pts[j].y), Vector3.UP, pts[j], Color(tint, 0.0))
		var ci := pts[j] + inland[j] * rim
		var di := pts[i] + inland[i] * rim
		var c := pieces.vertex(Vector3(ci.x, top + 0.0002, ci.y), Vector3.UP, ci, Color(tint, 0.0))
		var d := pieces.vertex(Vector3(di.x, top + 0.0002, di.y), Vector3.UP, di, Color(tint, 0.0))
		pieces.quad(a, b, c, d)
		# The cut edge.
		var out := -(inland[i] + inland[j]).normalized()
		var normal := Vector3(out.x, 0, out.y)
		var e := pieces.vertex(Vector3(pts[i].x, top, pts[i].y), normal, pts[i], Color(tint, 1.0))
		var f := pieces.vertex(Vector3(pts[j].x, top, pts[j].y), normal, pts[j], Color(tint, 1.0))
		var g := pieces.vertex(Vector3(pts[j].x, base, pts[j].y), normal, pts[j], Color(tint, 1.0))
		var h := pieces.vertex(Vector3(pts[i].x, base, pts[i].y), normal, pts[i], Color(tint, 1.0))
		pieces.quad(e, f, g, h)
