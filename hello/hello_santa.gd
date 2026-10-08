extends Node3D
## M0 "Hello Santa" scene: proves the web build and hosting pipeline.
## A toy Santa on a snowy turntable. Click or press any key to make him hop.

const SNOW := Color("eef3f8")
const PINE := Color("2f6b3a")
const NIGHT := Color("1b2a4a")

var _santa: SantaToy
var _turntable: Node3D


func _ready() -> void:
	_build_environment()
	_build_scene()
	_build_ui()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8fa6c8")
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = NIGHT
	env.fog_density = 0.02
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.6, 6.2)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	camera.fov = 50
	add_child(camera)


func _build_scene() -> void:
	ToyPart.add(self, ToyPart.cylinder(14, 14, 0.2, 24), SNOW, Vector3(0, -0.1, 0))

	_turntable = Node3D.new()
	add_child(_turntable)
	ToyPart.add(_turntable, ToyPart.cylinder(1.4, 1.5, 0.25, 16), Color("8b5a2b"), Vector3(0, 0.12, 0))
	_santa = SantaToy.new()
	_santa.position = Vector3(0, 0.25, 0)
	_turntable.add_child(_santa)

	# Low-poly pines ringing the scene
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	for i in 14:
		# Spread across the back half of the circle so nothing blocks the camera.
		var angle := PI * (1.0 + (i + 0.5) / 14.0) + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(4.0, 9.0)
		var height := rng.randf_range(1.8, 3.2)
		var tree := Node3D.new()
		tree.position = Vector3(cos(angle) * dist * 1.3, 0, sin(angle) * dist + 1.0)
		ToyPart.add(tree, ToyPart.cylinder(0.12, 0.15, 0.5, 6), Color("5b3a1e"), Vector3(0, 0.25, 0))
		ToyPart.add(tree, ToyPart.cylinder(0.0, height * 0.38, height, 6), PINE, Vector3(0, 0.5 + height / 2.0, 0))
		add_child(tree)

	# A couple of presents
	ToyPart.add(self, ToyPart.box(Vector3(0.5, 0.5, 0.5)), Color("2e86de"), Vector3(-1.9, 0.25, 0.6), Vector3(0, 20, 0))
	ToyPart.add(self, ToyPart.box(Vector3(0.4, 0.35, 0.4)), Color("27ae60"), Vector3(1.9, 0.18, 0.8), Vector3(0, -15, 0))
	ToyPart.add(self, ToyPart.box(Vector3(0.32, 0.6, 0.32)), Color("e8b923"), Vector3(2.3, 0.3, -0.2), Vector3(0, 40, 0))

	# Falling snow
	var snow := CPUParticles3D.new()
	snow.amount = 400
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.position = Vector3(0, 7, 0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(10, 0.5, 8)
	snow.direction = Vector3(0, -1, 0)
	snow.spread = 15
	snow.initial_velocity_min = 0.8
	snow.initial_velocity_max = 1.4
	snow.gravity = Vector3(0, -0.3, 0)
	var flake := ToyPart.sphere(0.04, 4)
	flake.material = ToyPart.material(Color.WHITE)
	snow.mesh = flake
	add_child(snow)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "SANTA'S LAST STAND"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("ffd86b"))
	title.add_theme_color_override("font_outline_color", Color("7a0f1c"))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 28
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "Coming this Christmas  ·  Click or press any key to make Santa hop"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hint.offset_bottom = -24
	layer.add_child(hint)


func _process(delta: float) -> void:
	_turntable.rotation.y += delta * 0.6


func _unhandled_input(event: InputEvent) -> void:
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if pressed_key or clicked:
		_santa.hop()
