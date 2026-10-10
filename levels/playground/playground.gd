extends LevelBase
## A small winter test area for trying the shared controllers: Santa runs,
## jumps, punches, throws snowballs, grabs presents and sneaks round a little
## course of snowy crates, logs, a ramp and a moving platform; the sleigh flies
## a loop of rings. Tab swaps between them; R puts the sleigh on rails along
## the rings and back.
##
## `-- --demo=<name>` drives it by itself for recordings and checks (see
## playground_demo.gd): walk, jump, punch, throw, sneak, sleigh, rails, overview.

const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")
const SKY_DOME_SHADER := preload("res://core/visual/night_sky_dome.gdshader")
const SnowmanTargets := preload("res://levels/playground/snowman_targets.gd")
const RingCourse := preload("res://levels/playground/ring_course.gd")
const PlaygroundDemo := preload("res://levels/playground/playground_demo.gd")

## Santa keeps inside this circle (the sleigh flies anywhere).
const WALK_RADIUS := 40.0
const SANTA_START := Vector3(0, 0.05, 10)
const SNOWMEN := [Vector3(-6, 0, 6), Vector3(-8.5, 0, 2.5), Vector3(-6.5, 0, -0.5)]
const PRESENTS := [Vector3(2.5, 0.3, 11.5), Vector3(-2.2, 0.3, 12.5)]

var santa: SantaController
var sleigh: SleighController
var rings: Node3D
var targets: Node3D
## True while the sleigh is being flown.
var flying := false
var moon: DirectionalLight3D
var _snowfall: MeshInstance3D
var _hint: Label
var _status: Label
var _boost_bar: ProgressBar


func _ready() -> void:
	super._ready()
	var start := Time.get_ticks_msec()
	_build_environment()
	add_child(build_set())
	_add_moving_parts()
	santa = SantaController.spawn(self, Transform3D(Basis(Vector3.UP, PI), SANTA_START))
	sleigh = SleighController.new()
	add_child(sleigh)
	sleigh.bounds_radius = 70.0
	sleigh.input_enabled = false
	_park_sleigh(Vector3(4.5, 0, 12), PI * 0.5)
	santa.camera.make_current()
	_build_hud()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo"):
			var demo := PlaygroundDemo.new()
			demo.playground = self
			demo.demo_name = arg.get_slice("=", 1) if "=" in arg else "walk"
			add_child(demo)
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - start)
	print("Playground built in %d ms" % Engine.get_meta("startup_ms"))


## Swaps between Santa on foot and the sleigh. The sleigh takes off from just
## above Santa; leaving it drops him on the ground below, with the sleigh
## parked beside him.
func set_flying(on: bool) -> void:
	if on == flying:
		return
	flying = on
	santa.input_enabled = not on
	santa.camera.input_enabled = not on
	santa.move_intent = Vector3.ZERO
	sleigh.input_enabled = on
	if on:
		if santa.carried:
			santa.drop()
		sleigh.process_mode = Node.PROCESS_MODE_INHERIT
		sleigh.place(Transform3D(Basis(Vector3.UP, santa.yaw), santa.global_position + Vector3.UP * 2.5))
		sleigh.camera.make_current()
		santa.process_mode = Node.PROCESS_MODE_DISABLED
		santa.visible = false
		rings.lose_track()
	else:
		var below := _ground_below(sleigh.global_position)
		var flat := Vector2(below.x, below.z).limit_length(WALK_RADIUS - 4.0)
		var spot := Vector3(flat.x, _ground_below(Vector3(flat.x, 60.0, flat.y)).y, flat.y)
		santa.process_mode = Node.PROCESS_MODE_INHERIT
		santa.visible = true
		santa.place(Transform3D(Basis(Vector3.UP, sleigh.yaw), spot + Vector3.UP * 0.05))
		santa.camera.snap()
		santa.camera.make_current()
		sleigh.fly_free()
		var aside := Vector3(cos(sleigh.yaw), 0, -sin(sleigh.yaw)) * 2.4
		_park_sleigh(Vector3(spot.x, 0, spot.z) + aside, sleigh.yaw)


## Sets the sleigh down on the snow at `at`, still and switched off.
func _park_sleigh(at: Vector3, heading: float) -> void:
	sleigh.process_mode = Node.PROCESS_MODE_INHERIT
	sleigh.place(Transform3D(Basis(Vector3.UP, heading), Vector3(at.x, SleighController.HALF_SIZE.y + 0.02, at.z)))
	sleigh.speed = 0.0
	sleigh.process_mode = Node.PROCESS_MODE_DISABLED


func _ground_below(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 200.0, PhysicsLayers.WORLD)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(at.x, 0.0, at.z)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_vehicle"):
		set_flying(not flying)
		get_viewport().set_input_as_handled()
	elif flying and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_R:
		if sleigh.mode == SleighController.Mode.RAILS:
			sleigh.fly_free()
		else:
			sleigh.follow_rail(rings.path, _nearest_on_path(sleigh.global_position))
			rings.lose_track()


func _nearest_on_path(at: Vector3) -> float:
	var curve: Curve3D = rings.path.curve
	return curve.get_closest_offset(rings.path.to_local(at))


func _physics_process(delta: float) -> void:
	if flying:
		rings.track(sleigh, delta)


func _process(delta: float) -> void:
	super._process(delta)
	var view := get_viewport().get_camera_3d()
	if view and _snowfall:
		# The falling snow follows the camera, so it is always snowing round you.
		var mat := _snowfall.mesh.surface_get_material(0) as ShaderMaterial
		mat.set_shader_parameter("box_min", view.global_position - Vector3(14, 5, 14))
	_update_hud()


# --- Building ---

## Everything that never moves: ground, forest, mountains, the cabin, fences,
## rocks, the jumping course, and their collision. Built only from code, so
## it could be baked like the title camp (see Baked) if loading gets slow.
static func build_set() -> Node3D:
	var root := Node3D.new()
	root.name = "Set"
	root.add_child(WinterProps.snow_ground(250.0, 72, 46.0, 3, 2))
	root.add_child(WinterProps.mountain_range(110.0, 200.0, 30.0, 5))
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	root.add_child(solid)
	_add_shape(solid, BoxShape3D.new(), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0)), Vector3(400, 2, 400))
	root.add_child(_walker_bounds())
	var b := ToyBuilder.new()
	var ends := MeshPieces.new()
	_build_course(b, ends, solid)
	_build_ground_details(b)
	var course := b.build(0.0, "Course")
	ends.add_to(course.mesh, WinterProps.end_grain_material())
	root.add_child(course)
	_build_trees(root, solid)
	_build_cabin(root, solid)
	_build_fences(root, solid)
	_build_rocks(root, solid)
	return root


## Crates and stone blocks stepping up to a log bridge, a ramp to a deck, logs
## to hop over, and a tall block reached from the moving platform.
static func _build_course(b: ToyBuilder, ends: MeshPieces, solid: StaticBody3D) -> void:
	_snowy_box(b, solid, Vector3(0, 0.35, 3.0), Vector3(2.0, 0.7, 2.0), "brown_planks_04", Color("c8a07c"), 1)
	_snowy_box(b, solid, Vector3(0, 0.7, 0.0), Vector3(2.0, 1.4, 2.0), "old_stone_wall", Color.WHITE, 2)
	_snowy_box(b, solid, Vector3(0, 1.05, -3.0), Vector3(2.0, 2.1, 2.0), "old_stone_wall", Color("d8d4cc"), 3)
	_snowy_box(b, solid, Vector3(0, 1.05, -11.0), Vector3(3.0, 2.1, 3.0), "old_stone_wall", Color.WHITE, 4)
	# Log bridge from the third block to the far one, on two short posts.
	_log(b, ends, solid, Vector3(0, 1.9, -7.0), Vector3(90, 0, 0), 0.32, 5.2)
	for z in [-5.5, -8.5]:
		_log(b, ends, solid, Vector3(0, 0.82, z), Vector3.ZERO, 0.22, 1.64)
	# High block reached from the moving platform (which runs west from the far block).
	_snowy_box(b, solid, Vector3(-12.5, 1.5, -11.0), Vector3(3.0, 3.0, 3.0), "old_stone_wall", Color("d8d4cc"), 6)
	# A ramp up to a plank deck.
	var rise := deg_to_rad(22.0)
	var length := 4.2
	var ramp_at := Vector3(6.0, sin(rise) * length / 2.0, 2.0 + cos(rise) * length / 2.0)
	var ramp := Transform3D(Basis(Vector3.RIGHT, rise), ramp_at)
	b.textured(ToyBuilder.box(Vector3(2.0, 0.12, length)), "brown_planks_04", ramp, 1.0, Color("b08a70"))
	b.textured(ToyBuilder.snow_sheet(Vector2(1.9, length - 0.1), 0.05, 8, 0.12), "snow_02",
			ramp * Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)), 1.5, WinterProps.SNOW_TINT)
	_add_shape(solid, BoxShape3D.new(), ramp, Vector3(2.0, 0.12, length))
	var deck_top := sin(rise) * length
	_snowy_box(b, solid, Vector3(6.0, deck_top / 2.0, 0.5), Vector3(3.0, deck_top, 3.0), "brown_planks_04", Color("c8a07c"), 7)
	# Logs lying in the snow to hop over.
	_log(b, ends, solid, Vector3(3.5, 0.24, 7.5), Vector3(0, 0, 90), 0.24, 2.6)
	_log(b, ends, solid, Vector3(-3.0, 0.2, 7.0), Vector3(0, 25, 90), 0.2, 2.2)


static func _snowy_box(b: ToyBuilder, solid: StaticBody3D, centre: Vector3, size: Vector3,
		texture: String, tint: Color, seed: int) -> void:
	b.textured(ToyBuilder.box(size), texture, ToyBuilder.xf(centre), 1.0, tint, 0.35)
	b.textured(ToyBuilder.snow_sheet(Vector2(size.x, size.z), 0.08, seed, 0.12), "snow_02",
			ToyBuilder.xf(centre + Vector3(0, size.y / 2.0, 0)), 1.5, WinterProps.SNOW_TINT)
	_add_shape(solid, BoxShape3D.new(), Transform3D(Basis.IDENTITY, centre + Vector3(0, 0.04, 0)), size + Vector3(0, 0.08, 0))


## A log of `radius` and `length`; with no rotation it stands upright.
static func _log(b: ToyBuilder, ends: MeshPieces, solid: StaticBody3D, centre: Vector3, rot_deg: Vector3,
		radius: float, length: float) -> void:
	var xf := ToyBuilder.xf(centre, rot_deg)
	b.textured(ToyBuilder.cylinder(radius, radius * 1.04, length, 14), "bark_brown_02", xf, 0.5, Color.WHITE, 0.45)
	for end: float in [-1.0, 1.0]:
		var axis := xf.basis * Vector3.UP * end
		ends.disc(centre + axis * (length / 2.0 + 0.003), axis, Vector3.UP if absf(axis.y) < 0.9 else Vector3.FORWARD,
				radius, Color(randf(), 0, 0))
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = length
	_add_shape(solid, cylinder, xf)


static func _add_shape(solid: StaticBody3D, shape: Shape3D, at: Transform3D, box_size := Vector3.ZERO) -> void:
	if shape is BoxShape3D:
		(shape as BoxShape3D).size = box_size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = at
	solid.add_child(node)


## A wall round the walking area that only Santa bumps into.
static func _walker_bounds() -> StaticBody3D:
	var faces := PackedVector3Array()
	var sides := 48
	for i in sides:
		var a := Vector3(cos(TAU * i / sides), 0, sin(TAU * i / sides)) * WALK_RADIUS
		var c := Vector3(cos(TAU * (i + 1) / sides), 0, sin(TAU * (i + 1) / sides)) * WALK_RADIUS
		var up := Vector3.UP * 10.0
		faces.append_array([a, c, c + up, a, c + up, a + up])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var wall := StaticBody3D.new()
	wall.name = "WalkerBounds"
	wall.collision_layer = PhysicsLayers.WALKER_BOUNDS
	wall.collision_mask = 0
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position.y = -2.0
	wall.add_child(node)
	return wall


## Fir trees: a few in the play area that cast shadows and block the way,
## and a forest round the edge, each kind one tree drawn many times.
static func _build_trees(root: Node3D, solid: StaticBody3D) -> void:
	var near: Array[Transform3D] = []
	for spot: Vector3 in [Vector3(10, 0, -7), Vector3(13, 0, 7), Vector3(-11, 0, 13), Vector3(15, 0, -15),
			Vector3(-21, 0, 9), Vector3(5, 0, -19), Vector3(-6, 0, -21), Vector3(22, 0, 2)]:
		var size := 0.85 + fposmod(spot.x * 0.37 + spot.z * 0.13, 0.4)
		near.append(Transform3D(Basis(Vector3.UP, spot.x + spot.z).scaled(Vector3.ONE * size), spot))
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.4 * size
		trunk.height = 5.0
		_add_shape(solid, trunk, Transform3D(Basis.IDENTITY, spot + Vector3.UP * 2.5))
	var tree := WinterProps.fir_tree(5.5, 11, false, 0.85, 0.55)
	var near_trees := WinterProps.scatter((tree.get_node("Mesh") as MeshInstance3D).mesh, near, true)
	tree.free()
	near_trees.name = "NearTrees"
	near_trees.add_to_group(GraphicsQuality.SHADOWS_ON_HIGH)
	root.add_child(near_trees)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2512
	var far: Array[Transform3D] = []
	var count := 64
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.04, 0.04)
		var dist := rng.randf_range(45.0, 70.0)
		var scale := rng.randf_range(0.8, 1.5)
		far.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale),
				Vector3(cos(angle) * dist, 0, sin(angle) * dist)))
	var forest_tree := WinterProps.fir_tree(6.0, 23, false, 0.6, 0.6)
	var forest := WinterProps.scatter((forest_tree.get_node("Mesh") as MeshInstance3D).mesh, far, false)
	forest_tree.free()
	forest.name = "Forest"
	forest.add_to_group(GraphicsQuality.SHADOWS_ON_HIGH)
	root.add_child(forest)


## The log cabin, its door facing the middle, without its window light (the
## moon is the only light here).
static func _build_cabin(root: Node3D, solid: StaticBody3D) -> void:
	var cabin := WinterProps.log_cabin(2)
	var at := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-17.0, 0, -4.0))
	cabin.transform = at
	for light in cabin.find_children("*", "OmniLight3D", true, false):
		light.free()
	root.add_child(cabin)
	_add_shape(solid, BoxShape3D.new(), at * Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0)), Vector3(4.8, 4.4, 3.8))


## Picket fences round the cabin yard and along the edges: one fence drawn
## many times.
static func _build_fences(root: Node3D, solid: StaticBody3D) -> void:
	var runs: Array[Transform3D] = []
	for spec: Array in [[Vector3(-14.5, 0, -10.5), 0.0], [Vector3(-10.5, 0, -10.5), 0.0], [Vector3(-14.5, 0, 2.5), 0.0],
			[Vector3(-10.5, 0, 2.5), 0.0], [Vector3(18, 0, 14), -40.0], [Vector3(21, 0, 10.8), -60.0],
			[Vector3(-2, 0, 18), 8.0], [Vector3(2, 0, 18.3), -4.0]]:
		var at := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), spec[0])
		runs.append(at)
		_add_shape(solid, BoxShape3D.new(), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(4.1, 1.0, 0.15))
	var fence := WinterProps.fence(4.0)
	var fences := WinterProps.scatter((fence.get_node("Mesh") as MeshInstance3D).mesh, runs, true)
	fence.free()
	fences.name = "Fences"
	root.add_child(fences)


static func _build_rocks(root: Node3D, solid: StaticBody3D) -> void:
	for spec: Array in [["namaqualand_boulder_04", Vector3(10, -0.3, 13), 30.0, 1.2],
			["namaqualand_boulder_02", Vector3(-13, -0.2, -19), 200.0, 1.1], ["rock_moss_set_01", Vector3(17, -0.2, -2), 75.0, 1.0]]:
		var rock := PbrLibrary.model(spec[0], 0.55)
		rock.position = spec[1]
		rock.rotation_degrees.y = spec[2]
		rock.scale = Vector3.ONE * spec[3]
		root.add_child(rock)
		var ball := SphereShape3D.new()
		ball.radius = 0.9 * spec[3]
		_add_shape(solid, ball, Transform3D(Basis.IDENTITY, (spec[1] as Vector3) + Vector3.UP * 0.3))


## Stones, dry grass and twigs scattered over the open snow.
static func _build_ground_details(b: ToyBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var counts := [18, 40, 12]
	for kind in counts.size():
		var placed := 0
		while placed < counts[kind]:
			var a := rng.randf() * TAU
			var r := rng.randf_range(4.0, 38.0)
			var at := Vector3(cos(a) * r, 0, sin(a) * r)
			# Keep the paths of the course clear.
			if absf(at.x) < 3.0 and at.z < 14.0 and at.z > -14.0:
				continue
			var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), at)
			match kind:
				0: WinterProps.add_buried_rock(b, spot, placed)
				1: WinterProps.add_dry_grass(b, spot, placed % 6)
				2: WinterProps.add_fallen_twig(b, spot, placed)
			placed += 1


## Things that move or can be hit: the moving platform, the snowmen, the
## presents to carry, the rings, and the falling snow.
func _add_moving_parts() -> void:
	add_child(MovingPlatform.make(Vector3(2.2, 0.25, 2.2), Vector3(-3.0, 1.95, -11.0), Vector3(-6.0, 0, 0), 2.6))
	var spots: Array[Transform3D] = []
	for spot: Vector3 in SNOWMEN:
		spots.append(Transform3D(Basis(Vector3.UP, atan2(-spot.x, SANTA_START.z - spot.z)), spot))
	targets = SnowmanTargets.new(spots)
	add_child(targets)
	var colours := [[Color("b3202c"), WinterProps.GOLD, GiftBox.Pattern.SNOWFLAKES], [Color("1d4f8c"), Color("e8e2d4"), GiftBox.Pattern.DOTS]]
	for i in PRESENTS.size():
		add_child(_present(PRESENTS[i], colours[i], i))
	rings = RingCourse.new(_ring_points())
	add_child(rings)
	_snowfall = WinterProps.snowfall(500, Vector3(-14, -5, -14), Vector3(28, 12, 28))
	_snowfall.mesh.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 200, 1000))
	add_child(_snowfall)


## A present Santa can pick up, carry and toss.
func _present(at: Vector3, look: Array, seed: int) -> RigidBody3D:
	var size := Vector3(0.45, 0.4, 0.45)
	var gift := RigidBody3D.new()
	gift.name = "Present%d" % seed
	gift.position = at
	gift.mass = 3.0
	gift.collision_layer = PhysicsLayers.WORLD
	gift.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER
	gift.add_to_group("grabbable")
	var box := WinterProps.present(size, look[0], look[1], look[2], seed + 3)
	box.position.y = -size.y / 2.0
	gift.add_child(box)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	gift.add_child(shape)
	return gift


## A loop of rings round the playground, rising and falling.
static func _ring_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var count := 10
	for i in count:
		var a := TAU * i / count
		var r := 30.0 + sin(a * 3.0) * 6.0
		points.append(Vector3(cos(a) * r, 9.0 + sin(a * 2.0 + 0.6) * 4.5, sin(a) * r))
	return points


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6f82bd")
	env.ambient_light_energy = 0.75
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
	env.fog_density = 0.008
	env.fog_sky_affect = 0.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
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
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("c9d6ff")
	moon.light_energy = 1.6
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	add_child(moon)
	moon.look_at_from_position(Vector3(-6, 10, 8), Vector3.ZERO)
	add_child(GraphicsQuality.new(env, moon))


# --- Heads-up display ---

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	_hint = _label(16)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, -60)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_hint)
	_status = _label(20)
	_status.position = Vector2(16, 12)
	layer.add_child(_status)
	_boost_bar = ProgressBar.new()
	_boost_bar.max_value = 1.0
	_boost_bar.show_percentage = false
	_boost_bar.custom_minimum_size = Vector2(220, 14)
	_boost_bar.position = Vector2(18, 44)
	layer.add_child(_boost_bar)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


func _update_hud() -> void:
	if _hint == null:
		return
	_boost_bar.visible = flying
	if flying:
		_hint.text = "W/S speed  ·  A/D steer  ·  mouse or arrows: nose up/down  ·  Shift boost  ·  Space (in a turn) drift\nR rails %s  ·  Tab back to Santa" % ("off" if sleigh.mode == SleighController.Mode.RAILS else "on")
		var best := "  ·  best lap %.1f s" % rings.best_lap if rings.best_lap > 0.0 else ""
		_status.text = "Ring %d / %d  ·  lap %d  ·  %.0f km/h%s" % [rings.next + 1, rings.centres.size(), rings.lap,
				sleigh.speed * 3.6, best]
		_boost_bar.value = sleigh.boost_meter
	else:
		_hint.text = "WASD move  ·  Shift run  ·  Space jump  ·  Ctrl sneak  ·  click/F punch  ·  right-click/Q snowball\nE grab, drop or wave  ·  mouse or arrows: camera  ·  wheel zoom  ·  Tab sleigh  ·  Esc pause"
		_status.text = "" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Click to look around with the mouse"
