class_name SetBuilder
extends RefCounted
## Builds a level's static set: textured shapes merged into one mesh per
## material, plus one static body holding every collision shape. Levels call
## the helpers (snowy blocks, piers, ramps, logs), then finish() to get the
## nodes.

var root := Node3D.new()
var solid := StaticBody3D.new()
var b := ToyBuilder.new()
## Sawn log ends, drawn with the end-grain material.
var ends := MeshPieces.new()


func _init(root_name := "Set") -> void:
	root.name = root_name
	solid.name = "Solid"
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	root.add_child(solid)


## Adds the merged meshes to the root and returns it.
func finish(mesh_name := "Built") -> Node3D:
	var mesh := b.build(0.0, mesh_name)
	if not ends.is_empty():
		ends.add_to(mesh.mesh, WinterProps.end_grain_material())
	root.add_child(mesh)
	return root


func add_shape(shape: Shape3D, at: Transform3D, box_size := Vector3.ZERO) -> void:
	if shape is BoxShape3D:
		(shape as BoxShape3D).size = box_size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = at
	solid.add_child(node)


## A solid box with no mesh (an invisible wall or a floor under a mesh).
func collider(centre: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	add_shape(BoxShape3D.new(), Transform3D(basis, centre), size)


## A textured block, solid, with snow on top when `snow` is set.
func block(centre: Vector3, size: Vector3, texture: String, tint := Color.WHITE, snow := true,
		seed := 1, basis := Basis.IDENTITY, tile := 1.0) -> void:
	var at := Transform3D(basis, centre)
	b.textured(ToyBuilder.box(size), texture, at, tile, tint, 0.35 if snow else 0.0)
	if snow:
		b.textured(ToyBuilder.snow_sheet(Vector2(size.x, size.z), 0.08, seed, maxf(0.12, minf(size.x, size.z) / 14.0)), "snow_02",
				at * Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0, 0)), 1.5, WinterProps.SNOW_TINT)
	add_shape(BoxShape3D.new(), Transform3D(basis, centre + basis * Vector3(0, 0.04 if snow else 0.0, 0)),
			size + Vector3(0, 0.08 if snow else 0.0, 0))


## A pillar rising from `bottom` to a snowy top at `top`, centred on `at`
## (x, z), `size` across: a stepping stone standing out of ice or water.
func pier(at: Vector2, top: float, size: Vector2, bottom: float, texture := "old_stone_wall",
		tint := Color.WHITE, seed := 1) -> void:
	var height := top - bottom
	block(Vector3(at.x, bottom + height / 2.0, at.y), Vector3(size.x, height, size.y), texture, tint, true, seed)


## A walkable sloping deck of planks from `from` to `to` (the middle of each
## end, on its top surface), `width` wide.
func ramp(from: Vector3, to: Vector3, width: float, texture := "brown_planks_04", tint := Color("b08a70"),
		thickness := 0.18, seed := 1) -> void:
	var along := to - from
	var flat := Vector3(along.x, 0, along.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var up := along.normalized().cross(side).normalized()
	if up.y < 0.0:
		side = -side
		up = -up
	var basis := Basis(side, up, along.normalized())
	var centre := (from + to) / 2.0 - up * thickness / 2.0
	var size := Vector3(width, thickness, along.length())
	var at := Transform3D(basis, centre)
	b.textured(ToyBuilder.box(size), texture, at, 1.0, tint, 0.3)
	b.textured(ToyBuilder.snow_sheet(Vector2(width - 0.06, size.z - 0.06), 0.05, seed, 0.15), "snow_02",
			at * Transform3D(Basis.IDENTITY, Vector3(0, thickness / 2.0, 0)), 1.5, WinterProps.SNOW_TINT)
	add_shape(BoxShape3D.new(), at, size)


## A log of `radius` and `length`; with no rotation it stands upright.
func log_beam(centre: Vector3, rot_deg: Vector3, radius: float, length: float, solid_log := true) -> void:
	var xf := ToyBuilder.xf(centre, rot_deg)
	b.textured(ToyBuilder.cylinder(radius, radius * 1.04, length, 14), "bark_brown_02", xf, 0.5, Color.WHITE, 0.45)
	for end: float in [-1.0, 1.0]:
		var axis := xf.basis * Vector3.UP * end
		ends.disc(centre + axis * (length / 2.0 + 0.003), axis, Vector3.UP if absf(axis.y) < 0.9 else Vector3.FORWARD,
				radius, Color(fposmod(centre.x * 0.37 + centre.z * 0.71 + end, 1.0), 0, 0))
	if solid_log:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = length
		add_shape(cylinder, xf)


## Places a ready-made prop (a WinterProps scene) under the root.
func put(node: Node3D, at: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	node.position = at
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	root.add_child(node)
	return node
