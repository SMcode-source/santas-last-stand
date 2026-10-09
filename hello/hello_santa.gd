extends Node3D
## The winter camp outside Santa's cabin. On its own it is the M0 "Hello Santa"
## scene (click or press any key to make Santa hop and wave); the title screen,
## Advent calendar and Prologue use it as a backdrop with `show_ui` off.

const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")
const SKY_DOME_SHADER := preload("res://core/visual/night_sky_dome.gdshader")

## The title text, the hint line and click-to-wave.
var show_ui := true
## The slow camera orbit around Santa. Turn off to move the camera yourself.
var orbit_camera := true
## Santa going about his chores (chopping wood, packing his sack). Turn off
## to keep him standing still in the middle.
var santa_routine := true
var routine: Node
## Where the routine starts: "" (greeting), "chop" or "pack".
var routine_start := ""
var _look := Vector3(0.3, 1.2, 0)
var santa: SantaModel
var camera: Camera3D
var _time := 0.0


func _ready() -> void:
	var start := Time.get_ticks_msec()
	_build_environment()
	_build_scene()
	if show_ui:
		_build_ui()
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - start)
	# Shows up in the browser console, to keep an eye on loading in the web build.
	print("Title scene built in %d ms" % Engine.get_meta("startup_ms"))


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# The sky only lends reflections; it is still, so they are worked out once.
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

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
	# What the camera sees of the sky: twinkling stars and a drifting aurora.
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 800.0
	dome_mesh.height = 1600.0
	dome_mesh.radial_segments = 32
	dome_mesh.rings = 16
	var dome_mat := ShaderMaterial.new()
	dome_mat.shader = SKY_DOME_SHADER
	dome_mesh.material = dome_mat
	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	dome.mesh = dome_mesh
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)

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

	camera = Camera3D.new()
	camera.fov = 52
	add_child(camera)
	_update_camera()


func _build_scene() -> void:
	# Everything built from code that never moves. The web build loads it
	# ready-made (see Baked), which saves seconds of loading.
	add_child(Baked.node("title_camp"))

	santa = SantaModel.new()
	add_child(santa)

	# A bench by the campfire, a woodcutter's corner, and the cabin's yard clutter
	_place(PbrLibrary.model("painted_wooden_bench", 0.5), Vector3(2.0, 0, -3.5), 10)
	var stump := PbrLibrary.model("tree_stump_01", 0.45)
	_place(stump, Vector3(-2.6, 0, -2.4), 40)
	var axe := _axe_in_stump(stump.rotation.y)
	stump.add_child(axe)
	# A log stood on the stump ready to split, and Santa's sack with a little
	# pile of presents waiting to go in.
	var log_parts := WinterProps.log_round()
	for part in log_parts:
		_place(part, Vector3(-2.6, 0.33, -2.4), 15)
	var sack := WinterProps.toy_sack()
	_place(sack, Vector3(2.35, 0, -1.05), -60)
	var pile: Array[Node3D] = []
	for spec: Array in [[Vector3(0.3, 0.24, 0.3), Color("b3202c"), WinterProps.GOLD, GiftBox.Pattern.SNOWFLAKES, Vector3(1.0, 0, -1.55), 20],
			[Vector3(0.26, 0.2, 0.26), Color("e8e2d4"), Color("b3202c"), GiftBox.Pattern.STRIPES, Vector3(1.2, 0, -1.85), -15],
			[Vector3(0.2, 0.18, 0.2), Color("1d4f8c"), Color("e8e2d4"), GiftBox.Pattern.DOTS, Vector3(0.98, 0.24, -1.55), 40]]:
		var gift := WinterProps.present(spec[0], spec[1], spec[2], spec[3], pile.size() + 7)
		_place(gift, spec[4], spec[5])
		pile.append(gift)
	if santa_routine:
		routine = preload("res://hello/title_routine.gd").new()
		routine.santa = santa
		routine.axe = axe
		routine.log_whole = log_parts[0]
		routine.log_halves.assign(log_parts.slice(1))
		routine.sack = sack
		routine.pile = pile
		routine.start_at = routine_start
		add_child(routine)
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

	# Falling snow (moved by the graphics card, so it costs no CPU time)
	var snow := WinterProps.snowfall(400, Vector3(-14, 0, -12.5), Vector3(28, 8.5, 16))
	add_child(snow)


## The camp round Santa: snowy ground, cabin, trees, snowman, lamp post,
## fences, campfire, a few presents, the forest and the mountains. It is all
## static and built only from code, so tools/bake.gd can save it for the
## export (see Baked).
static func build_camp() -> Node3D:
	var camp := Node3D.new()
	camp.name = "Camp"
	# Boot prints from the cabin door, round the woodpile, to where Santa stands.
	var trail := PackedVector2Array([Vector2(-3.45, -3.5), Vector2(-2.5, -3.45), Vector2(-1.5, -3.0),
			Vector2(-0.8, -2.0), Vector2(-0.4, -1.0), Vector2(-0.12, -0.3)])
	camp.add_child(WinterProps.snow_ground(120.0, 80, 7.0, 1, 1, trail))

	_put(camp, WinterProps.log_cabin(), Vector3(-4.2, 0, -5.5), 22)
	_put(camp, WinterProps.fir_tree(4.2, 7, true, 0.85), Vector3(3.6, 0, -3.8))
	_put(camp, WinterProps.snowman(), Vector3(3.1, 0, -0.4), -35)
	_put(camp, WinterProps.lamp_post(), Vector3(-2.4, 0, 0.6))
	_put(camp, WinterProps.fence(5.0), Vector3(-7.5, 0, -2.0), 70)
	_put(camp, WinterProps.fence(4.0), Vector3(7.5, 0, -4.5), -60)
	# Presents that never move, merged so they draw in one go.
	var gifts: Array[Node3D] = []
	for spec: Array in [[Vector3(0.5, 0.45, 0.5), Color("1d4f8c"), WinterProps.GOLD, GiftBox.Pattern.SNOWFLAKES, Vector3(-1.15, 0, 0.0), 18],
			[Vector3(0.4, 0.32, 0.4), Color("1e6b3c"), Color("b3202c"), GiftBox.Pattern.TARTAN, Vector3(1.05, 0, 0.3), -22],
			[Vector3(0.32, 0.55, 0.32), Color("5b2a6e"), Color("e8e2d4"), GiftBox.Pattern.DOTS, Vector3(1.4, 0, -0.35), 40],
			[Vector3(0.7, 0.4, 0.55), Color("b3202c"), Color("f4efe6"), GiftBox.Pattern.STRIPES, Vector3(3.0, 0, -2.2), 10]]:
		var gift := WinterProps.present(spec[0], spec[1], spec[2], spec[3], gifts.size() + 1)
		gift.position = spec[4]
		gift.rotation_degrees.y = spec[5]
		gifts.append(gift)
	camp.add_child(GiftBox.merge(gifts))
	_put(camp, WinterProps.campfire(), Vector3(1.9, 0, -2.3))

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
		var tree := WinterProps.fir_tree(VARIANT_HEIGHT, 20 + v, false, 0.85, 0.6)
		var mesh: Mesh = (tree.get_node("Mesh") as MeshInstance3D).mesh
		tree.free()
		var forest_part := WinterProps.scatter(mesh, placements[v], false)
		forest_part.name = "Forest%d" % v
		forest_part.add_to_group(GraphicsQuality.SHADOWS_ON_HIGH)
		camp.add_child(forest_part)
	camp.add_child(_tree_shadows(placements, VARIANT_HEIGHT))
	camp.add_child(_saplings(placements, VARIANT_HEIGHT, rng))
	camp.add_child(_ground_details(placements, VARIANT_HEIGHT, rng))
	camp.add_child(WinterProps.mountain_range())
	return camp


## The woodcutter's axe, its blade bitten into the top of the stump and the
## handle rising out of it towards where Santa stands to chop. In the model the handle
## runs along +y with the head at the top and the cutting edge facing +z.
func _axe_in_stump(stump_yaw: float) -> Node3D:
	var axe := PbrLibrary.model("wooden_axe", 0.2)
	var out := Vector3(0.25, 0, -1).normalized().rotated(Vector3.UP, -stump_yaw)
	var lift := deg_to_rad(35.0)
	var head_dir := -(out * cos(lift) + Vector3.UP * sin(lift))
	var edge_dir := (Vector3.DOWN - head_dir * Vector3.DOWN.dot(head_dir)).normalized()
	var basis := Basis(head_dir.cross(edge_dir), head_dir, edge_dir)
	# The middle of the cutting edge, sunk a few centimetres into the stump top
	# near its edge, leaving room for a log in the middle.
	var edge := Vector3(0, 0.37, 0.17)
	axe.transform = Transform3D(basis, Vector3(-0.03, 0.27, 0.02) + out * 0.22 - basis * edge)
	return axe


## A few young firs growing between the background trees.
static func _saplings(placements: Array[Array], tree_height: float, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var spots: Array[Transform3D] = []
	for group: Array in placements:
		for i in range(0, group.size(), 2):
			var t: Transform3D = group[i]
			var away := rng.randf() * TAU
			var size := t.basis.get_scale().x * tree_height
			spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)),
					t.origin + Vector3(cos(away), 0, sin(away)) * size * rng.randf_range(0.6, 0.9)))
	var sapling := WinterProps.fir_tree(1.3, 31, false, 0.5, 0.7)
	var mesh: Mesh = (sapling.get_node("Mesh") as MeshInstance3D).mesh
	sapling.free()
	var saplings := WinterProps.scatter(mesh, spots, false)
	saplings.name = "Saplings"
	saplings.add_to_group(GraphicsQuality.DETAIL_ABOVE_LOW)
	return saplings


## Everything small on the ground, built into one mesh so it costs only a few
## draw calls: snow heaped round the trees and pine cones under them, stones,
## dry grass and twigs breaking up the open snow, and wood chips and halved
## logs round the chopping stump.
static func _ground_details(placements: Array[Array], tree_height: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	var b := ToyBuilder.new()
	for group: Array in placements:
		for t: Transform3D in group:
			var size := t.basis.get_scale().x * tree_height
			var spin := Basis(Vector3.UP, rng.randf() * TAU)
			WinterProps.add_snow_mound(b, Transform3D(spin.scaled(Vector3(size * 0.16, size * 0.12, size * 0.16)),
					t.origin + Vector3(0, -0.05, 0)), rng.randi())
			var a := rng.randf() * TAU
			WinterProps.add_pine_cone(b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
					t.origin + Vector3(cos(a), 0, sin(a)) * size * rng.randf_range(0.2, 0.45)))
	var counts := [22, 44, 14]
	for kind in counts.size():
		var placed := 0
		while placed < counts[kind]:
			var a := rng.randf_range(PI * 0.95, PI * 2.05)
			var r := rng.randf_range(2.0, 16.0)
			var at := Vector3(cos(a) * r * 1.3, 0, sin(a) * r * 0.9 + 1.5)
			# Keep clear of the cabin, the campfire, Santa's spot and the camera.
			if at.distance_to(Vector3(-4.2, 0, -5.5)) < 3.4 or at.distance_to(Vector3(1.9, 0, -2.3)) < 1.6 					or at.distance_to(Vector3.ZERO) < 1.6 or at.z > 0.8:
				continue
			var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.5)), at)
			match kind:
				0: WinterProps.add_buried_rock(b, spot, placed)
				1: WinterProps.add_dry_grass(b, spot, placed % 6)
				2: WinterProps.add_fallen_twig(b, spot, placed)
			placed += 1
	# Wood chips and halved logs round the chopping stump
	var stump := Vector3(-2.6, 0, -2.4)
	for k in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.75, 1.3)
		var size := Vector3(rng.randf_range(0.04, 0.09), 0.012, rng.randf_range(0.02, 0.04))
		b.textured(ToyBuilder.box(size), "wood_trunk_wall", ToyBuilder.xf(stump + Vector3(cos(a) * r, 0.01, sin(a) * r),
				Vector3(rng.randf_range(-15, 15), rng.randf() * 360.0, 0)), 0.3, Color("e0c49c"))
	for k in 2:
		b.textured(ToyBuilder.cylinder(0.11, 0.11, 0.4, 10), "bark_brown_02",
				ToyBuilder.xf(stump + Vector3(0.9 + k * 0.25, 0.07, 0.55 - k * 0.3), Vector3(90, 30 + k * 50, 0), Vector3(1, 1, 0.55)),
				0.4, Color.WHITE, 0.5)
	var details := b.build(0.0, "GroundDetails")
	details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return details


## Soft shadows on the snow under the background trees, cast away from the
## moon, so the forest sits on the ground even where it casts no real shadows.
static func _tree_shadows(placements: Array[Array], tree_height: float) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = WinterProps.soft_dot()
	mat.albedo_color = Color(0.05, 0.07, 0.16, 0.5)
	mat.render_priority = -1
	quad.material = mat
	var away := Vector3(0.42, 0, -0.56).normalized()
	var transforms: Array[Transform3D] = []
	for group: Array in placements:
		for t: Transform3D in group:
			var size := t.basis.get_scale().x * tree_height
			var spot := Basis.from_scale(Vector3(size * 0.75, 1, size * 1.1)).rotated(Vector3.UP, atan2(away.x, away.z))
			transforms.append(Transform3D(spot, t.origin + away * size * 0.18 + Vector3(0, 0.03, 0)))
	var shadows := WinterProps.scatter(quad, transforms, false)
	shadows.name = "ForestGroundShadows"
	return shadows


func _place(node: Node3D, pos: Vector3, yaw_deg := 0.0) -> void:
	_put(self, node, pos, yaw_deg)


static func _put(parent: Node, node: Node3D, pos: Vector3, yaw_deg := 0.0) -> void:
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)


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
	if orbit_camera:
		# Follow Santa round the camp, gently.
		var target := Vector3(santa.position.x * 0.65 + 0.2, 1.15, santa.position.z * 0.45)
		_look = _look.lerp(target, 1.0 - exp(-delta * 1.2))
		_update_camera()


func _update_camera() -> void:
	# Slow, gentle orbit around Santa, pulled back far enough that the lamp
	# post on the left and the snowman on the right stay in frame.
	var angle := sin(_time * 0.15) * 0.12
	camera.position = Vector3(sin(angle) * 4.9, 1.7, cos(angle) * 4.9)
	camera.look_at(_look)


func _unhandled_input(event: InputEvent) -> void:
	if not show_ui:
		return
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if pressed_key or clicked:
		if routine:
			routine.request_wave()
		else:
			santa.hop()
			santa.wave()
