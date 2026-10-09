extends Node3D
## M0 "Hello Santa" scene: proves the web build and hosting pipeline, and
## previews the art direction. Click or press any key to make Santa hop and wave.

const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")

var _santa: SantaToy
var _camera: Camera3D
var _time := 0.0


func _ready() -> void:
	var start := Time.get_ticks_msec()
	_build_environment()
	_build_scene()
	_build_ui()
	add_child(DebugOverlay.new())
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - start)


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6f82bd")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
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
	moon.light_energy = 1.6
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 22.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)
	moon.look_at_from_position(Vector3(-6, 10, 8), Vector3.ZERO)

	add_child(GraphicsQuality.new(env, moon))

	_camera = Camera3D.new()
	_camera.fov = 45
	add_child(_camera)
	_update_camera()


func _build_scene() -> void:
	add_child(WinterProps.snow_ground())

	_santa = SantaToy.new()
	add_child(_santa)

	_place(WinterProps.log_cabin(), Vector3(-4.2, 0, -5.5), 22)
	_place(WinterProps.fir_tree(4.2, 7, true, 0.85), Vector3(3.6, 0, -3.8))
	_place(WinterProps.snowman(), Vector3(3.3, 0, 0.2), -40)
	_place(WinterProps.lamp_post(), Vector3(-2.3, 0, 1.2))
	_place(WinterProps.fence(5.0), Vector3(-7.5, 0, -2.0), 70)
	_place(WinterProps.fence(4.0), Vector3(7.5, 0, -4.5), -60)
	_place(WinterProps.present(Vector3(0.5, 0.45, 0.5), Color("2e86de")), Vector3(-0.95, 0, 0.6), 18)
	_place(WinterProps.present(Vector3(0.4, 0.32, 0.4), Color("27ae60"), Color("d4202f")), Vector3(0.95, 0, 0.75), -22)
	_place(WinterProps.present(Vector3(0.32, 0.55, 0.32), Color("8e44ad")), Vector3(1.25, 0, 0.1), 40)
	_place(WinterProps.present(Vector3(0.7, 0.4, 0.55), Color("d4202f"), Color("f7f4ee")), Vector3(3.0, 0, -2.2), 10)

	# Campfire with a bench, a woodcutter's corner, and the cabin's yard clutter
	_place(WinterProps.campfire(), Vector3(1.9, 0, -2.3))
	_place(PbrLibrary.model("painted_wooden_bench", 0.5), Vector3(2.0, 0, -3.5), 10)
	_place(PbrLibrary.model("tree_stump_01", 0.45), Vector3(-2.6, 0, -2.4), 40)
	var axe := PbrLibrary.model("wooden_axe", 0.2)
	_place(axe, Vector3(-2.55, 0.42, -2.35), 70)
	axe.rotation_degrees.z = 18
	_place(PbrLibrary.model("dry_branches_medium_01", 0.4), Vector3(-3.4, 0, -1.6), 120)
	_place(PbrLibrary.model("wooden_crate_01", 0.5), Vector3(-1.6, 0, -4.3), -15)
	_place(PbrLibrary.model("wine_barrel_01", 0.5), Vector3(-1.1, 0, -5.0), 0)
	_place(PbrLibrary.model("wooden_bucket_01", 0.4), Vector3(-0.6, 0, -4.5), 30)
	_place(PbrLibrary.model("dead_tree_trunk", 0.5), Vector3(-6.0, 0.05, 1.0), 35)

	# Boulders and mossy rocks half-buried in the snow
	_place(PbrLibrary.model("namaqualand_boulder_04", 0.55), Vector3(6.8, -0.5, -6.5), 30)
	_place(PbrLibrary.model("namaqualand_boulder_02", 0.55), Vector3(-7.5, -0.2, -6.0), 200)
	_place(PbrLibrary.model("rock_moss_set_01", 0.6), Vector3(8.5, -0.3, -1.5), 75)
	_place(PbrLibrary.model("namaqualand_boulder_04", 0.6), Vector3(-9.5, -0.6, 2.0), 120)

	# A forest of snowy pines behind, and mountains on the horizon.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	# Four tree designs, each drawn many times in one batch.
	const VARIANTS := 4
	const VARIANT_HEIGHT := 5.0
	var placements: Array[Array] = []
	for v in VARIANTS:
		placements.append([] as Array[Transform3D])
	for i in 26:
		var angle := PI * (1.05 + 0.9 * i / 25.0) + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(9.0, 20.0)
		var pos := Vector3(cos(angle) * dist * 1.4, 0, sin(angle) * dist - 1.0)
		var size := rng.randf_range(3.0, 6.5) / VARIANT_HEIGHT
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * size)
		placements[i % VARIANTS].append(Transform3D(basis, pos))
	for v in VARIANTS:
		var tree := WinterProps.fir_tree(VARIANT_HEIGHT, 20 + v, false, 0.5)
		var mesh: Mesh = (tree.get_node("Mesh") as MeshInstance3D).mesh
		tree.free()
		var forest_part := WinterProps.scatter(mesh, placements[v], false)
		forest_part.name = "Forest%d" % v
		add_child(forest_part)
	add_child(WinterProps.mountain_range())

	# Falling snow
	var snow := CPUParticles3D.new()
	snow.amount = 400
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.position = Vector3(0, 8, -4.5)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(14, 0.5, 8)
	snow.direction = Vector3(0.1, -1, 0)
	snow.spread = 15
	snow.initial_velocity_min = 0.8
	snow.initial_velocity_max = 1.3
	snow.gravity = Vector3(0, -0.2, 0)
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.4
	var flake := QuadMesh.new()
	flake.size = Vector2.ONE * 0.07
	var flake_mat := StandardMaterial3D.new()
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_mat.albedo_texture = WinterProps.soft_dot()
	flake_mat.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
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
