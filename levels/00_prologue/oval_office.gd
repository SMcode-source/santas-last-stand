class_name OvalOffice
extends Node3D
## A simple Oval Office set for the Prologue: curved cream walls, tall night
## windows with gold drapes, a deep-blue carpet with a gold ring, the desk and
## a high-backed chair. The camera looks past the chair, so the President is
## never seen, only heard.

const WALL := Color("e9e0cc")
const CARPET := Color("1d2a5c")
const GOLD := Color("c9a046")
const DRAPE := Color("b8862f")

var camera_spot := Transform3D.IDENTITY
var santa_spot := Vector3.ZERO


func _ready() -> void:
	# Floor and ceiling
	_box(Vector3(12, 0.1, 10), Vector3(0, -0.05, 0), _plain(CARPET, 1.0))
	_cylinder(2.2, 0.012, Vector3(0, 0.006, 0.2), _plain(GOLD, 0.5, 0.6))
	_cylinder(2.05, 0.014, Vector3(0, 0.007, 0.2), _plain(CARPET.lightened(0.08), 1.0))
	_box(Vector3(12, 0.1, 10), Vector3(0, 3.6, 0), _plain(WALL.darkened(0.1), 0.9))

	# Curved walls: panels around an oval, with three tall windows behind the desk
	var panels := 28
	for i in panels:
		var a := TAU * i / panels
		var pos := Vector3(sin(a) * 4.6, 1.8, cos(a) * 3.8)
		var width := 4.6 * TAU / panels * 1.08
		var panel := _box(Vector3(width, 3.6, 0.12), pos, _plain(WALL, 0.8))
		panel.rotation.y = a
		var is_window := absf(wrapf(a - PI, -PI, PI)) < 0.55 and i % 2 == 0
		if is_window:
			var glass := _box(Vector3(width * 0.8, 2.3, 0.02), pos * 0.985 + Vector3(0, -0.1, 0), _glow(Color("27355f")))
			glass.rotation.y = a
			for side: float in [-1.0, 1.0]:
				var drape := _box(Vector3(0.28, 2.9, 0.1), pos * 0.97 + Vector3(0, -0.1, 0), _plain(DRAPE, 0.7))
				drape.rotation.y = a
				drape.position += drape.basis.x * side * width * 0.5
		# A dado rail all the way round
		var rail := _box(Vector3(width, 0.06, 0.06), Vector3(pos.x, 0.95, pos.z) * Vector3(0.985, 1, 0.985), _plain(Color.WHITE, 0.5))
		rail.rotation.y = a

	# The desk, the President's chair (seen from behind) and the gold dossier
	var wood := PbrLibrary.material("brown_planks_04", 0.6, Color("6b4128"))
	_box(Vector3(1.9, 0.08, 0.95), Vector3(0, 0.78, -1.6), wood)
	_box(Vector3(1.85, 0.72, 0.85), Vector3(0, 0.38, -1.6), wood)
	_box(Vector3(0.36, 0.05, 0.27), Vector3(0.1, 0.845, -1.35), _plain(GOLD, 0.35, 1.0))
	var leather := _plain(Color("2a1a14"), 0.45)
	_box(Vector3(0.7, 0.12, 0.65), Vector3(0, 0.5, -2.45), leather)
	_box(Vector3(0.72, 1.05, 0.16), Vector3(0, 1.05, -2.78), leather).rotation.x = deg_to_rad(-8)

	# A flag stand beside the windows
	_cylinder(0.025, 2.4, Vector3(-1.6, 1.2, -3.0), _plain(GOLD, 0.4, 1.0))
	var flag := _box(Vector3(0.9, 0.6, 0.02), Vector3(-1.13, 1.95, -3.0), _flag_material())
	flag.rotation.y = deg_to_rad(10)

	# Warm lamplight, plus cool moonlight through the windows
	_light(Vector3(0, 3.0, 0.6), Color("ffd7a0"), 2.2, 7.0)
	_light(Vector3(-1.8, 1.6, -2.2), Color("ffc98a"), 1.2, 3.5)
	_light(Vector3(1.6, 2.0, -3.2), Color("8fa8ff"), 0.7, 4.0)

	santa_spot = Vector3(0, 0, 0.1)
	# Over the President's shoulder, past the back of his chair, at Santa.
	camera_spot = Transform3D(Basis(), Vector3(0.35, 1.5, -3.25)).looking_at(Vector3(0, 1.3, 0.1))


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, pos, mat)


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	return _add(mesh, pos, mat)


func _add(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node


func _light(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)


static func _plain(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


static func _glow(color: Color) -> StandardMaterial3D:
	var mat := _plain(color, 0.1)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	return mat


## Thirteen stripes and a blue canton, drawn into a small texture.
static func _flag_material() -> StandardMaterial3D:
	var image := Image.create(78, 52, false, Image.FORMAT_RGB8)
	for stripe in 13:
		image.fill_rect(Rect2i(0, stripe * 4, 78, 4), Color("b22234") if stripe % 2 == 0 else Color.WHITE)
	image.fill_rect(Rect2i(0, 0, 32, 28), Color("3c3b6e"))
	for y in 5:
		for x in 6:
			image.set_pixel(3 + x * 5 + (y % 2) * 2, 3 + y * 5, Color.WHITE)
	var mat := _plain(Color.WHITE, 0.85)
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat
