extends Node3D
## M0 "Hello Santa" scene: proves the web build and hosting pipeline, and
## previews the art direction. Click or press any key to make Santa hop and wave.

const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")

var _santa: SantaToy
var _camera: Camera3D
var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_scene()
	_build_ui()


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7d8fc4")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color("3b3a6e")
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Cool moonlight from front-left, so faces read clearly.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("c9d6ff")
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)
	moon.look_at_from_position(Vector3(-6, 10, 8), Vector3.ZERO)

	_camera = Camera3D.new()
	_camera.fov = 45
	add_child(_camera)
	_update_camera()


func _build_scene() -> void:
	add_child(WinterProps.snow_ground())

	_santa = SantaToy.new()
	add_child(_santa)

	_place(WinterProps.log_cabin(), Vector3(-4.2, 0, -5.5), 22)
	_place(WinterProps.pine_tree(4.2, 7, true), Vector3(3.4, 0, -3.6))
	_place(WinterProps.snowman(), Vector3(2.6, 0, 1.0), -35)
	_place(WinterProps.lamp_post(), Vector3(-2.3, 0, 1.2))
	_place(WinterProps.lamp_post(), Vector3(5.8, 0, -0.5))
	_place(WinterProps.fence(5.0), Vector3(-7.5, 0, -2.0), 70)
	_place(WinterProps.fence(4.0), Vector3(7.5, 0, -4.5), -60)
	_place(WinterProps.candy_cane(1.1), Vector3(-1.2, 0, 2.6), 160)
	_place(WinterProps.candy_cane(1.1), Vector3(1.3, 0, 2.7), 20)
	_place(WinterProps.present(Vector3(0.5, 0.45, 0.5), Color("2e86de")), Vector3(-0.95, 0, 0.6), 18)
	_place(WinterProps.present(Vector3(0.4, 0.32, 0.4), Color("27ae60"), Color("d4202f")), Vector3(0.95, 0, 0.75), -22)
	_place(WinterProps.present(Vector3(0.32, 0.55, 0.32), Color("8e44ad")), Vector3(1.25, 0, 0.1), 40)
	_place(WinterProps.present(Vector3(0.7, 0.4, 0.55), Color("d4202f"), Color("f7f4ee")), Vector3(3.0, 0, -2.0), 10)

	# A forest of snowy pines behind, and mountains on the horizon.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	for i in 26:
		var angle := PI * (1.05 + 0.9 * i / 25.0) + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(9.0, 20.0)
		var pos := Vector3(cos(angle) * dist * 1.4, 0, sin(angle) * dist - 1.0)
		_place(WinterProps.pine_tree(rng.randf_range(3.0, 6.5), i + 20), pos, rng.randf_range(0, 360))
	for i in 6:
		var angle := PI * (1.1 + 0.8 * i / 5.0)
		var pos := Vector3(cos(angle) * 75.0, 0, sin(angle) * 55.0 - 10.0)
		_place(WinterProps.mountain(rng.randf_range(18.0, 30.0), i + 3), pos, rng.randf_range(0, 360))

	# Falling snow
	var snow := CPUParticles3D.new()
	snow.amount = 600
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.position = Vector3(0, 8, -2)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(14, 0.5, 10)
	snow.direction = Vector3(0.1, -1, 0)
	snow.spread = 15
	snow.initial_velocity_min = 0.8
	snow.initial_velocity_max = 1.3
	snow.gravity = Vector3(0, -0.2, 0)
	var flake := ToyBuilder.sphere(0.035, 4)
	var flake_mat := StandardMaterial3D.new()
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = flake_mat
	snow.mesh = flake
	add_child(snow)


func _place(node: Node3D, pos: Vector3, yaw_deg := 0.0) -> void:
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)


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
	title.offset_top = 24
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "Coming this Christmas  ·  Click or press any key to make Santa wave"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hint.offset_bottom = -24
	layer.add_child(hint)


func _process(delta: float) -> void:
	_time += delta
	_update_camera()


func _update_camera() -> void:
	# Slow, gentle orbit around Santa.
	var angle := sin(_time * 0.15) * 0.35
	_camera.position = Vector3(sin(angle) * 5.2, 1.9, cos(angle) * 5.2)
	_camera.look_at(Vector3(0, 1.15, 0))


func _unhandled_input(event: InputEvent) -> void:
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if pressed_key or clicked:
		_santa.hop()
		_santa.wave()
