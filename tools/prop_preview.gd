extends Node3D
## Close-up turntable for tuning a single prop under the game's night lighting.
## Run: godot --write-movie out.png --quit-after 2 res://tools/prop_preview.tscn -- --prop=fir

const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")


func _ready() -> void:
	var prop := "fir"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prop="):
			prop = arg.get_slice("=", 1)
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
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("c9d6ff")
	moon.light_energy = 1.6
	moon.shadow_enabled = true
	add_child(moon)
	moon.look_at_from_position(Vector3(-6, 10, 8), Vector3.ZERO)

	add_child(WinterProps.snow_ground(40.0, 40, 30.0))
	var node: Node3D
	var size := 2.0
	var distance := 0.0
	var face := false
	match prop:
		"fir":
			node = WinterProps.fir_tree(5.0, 21, false, 1.0)
			size = 5.0
		"forest":
			# A background tree seen from the game camera's distance and height.
			node = WinterProps.fir_tree(5.0, 21, false, 0.5)
			size = 5.0
			distance = 14.0
		"fir_decorated":
			node = WinterProps.fir_tree(4.2, 7, true)
			size = 4.2
		"santa":
			node = SantaToy.new()
			size = 1.9
		"santa_wave":
			node = SantaToy.new()
			node.ready.connect(node.wave)
			size = 1.9
		"santa_face":
			node = SantaToy.new()
			size = 1.9
			face = true
		"cabin":
			node = WinterProps.log_cabin()
			size = 5.0
		_:
			node = PbrLibrary.model(prop)
	add_child(node)
	var camera := Camera3D.new()
	camera.fov = 45
	add_child(camera)
	camera.position = Vector3(size * 0.6, size * 0.55, size * 1.5)
	if distance > 0.0:
		camera.position = Vector3(0, 1.9, distance)
	camera.look_at(Vector3(0, size * 0.42, 0))
	if prop.begins_with("santa") and not face:
		camera.position = Vector3(1.7, 1.45, 2.4)
		camera.look_at(Vector3(0, 0.95, 0))
	if face:
		camera.position = Vector3(0.22, 1.68, 0.62)
		camera.look_at(Vector3(0, 1.58, 0))
