class_name ToyPart
## Helpers for building chunky "toy figure" characters out of primitive meshes.


static func material(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


## Adds a primitive mesh to `parent` and returns it.
static func add(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material(color)
	part.position = pos
	part.rotation_degrees = rot_deg
	part.scale = scale
	parent.add_child(part)
	return part


static func sphere(radius: float, segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(4, segments >> 1)
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
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
