class_name WinterProps
## Builders for detailed winter props, shared by the North Pole, Alpine and
## Icelandic levels. Each returns a Node3D ready to place in a scene.

const SNOW := Color("e4ebf5")
const SNOW_TINT := Color("e8eef8")
const ICE := Color("bfe3f5")
const PINE := Color("2d6a3e")
const BARK := Color("5b3a1e")
const LOG := Color("8a5a33")
const LOG_DARK := Color("6b4226")
const STONE := Color("8a8f99")
const IRON := Color("2b3a35")
const WARM_LIGHT := Color("ffcf7a")
const COAL := Color("24211f")
const CARROT := Color("f08a24")
const BERRY := Color("d4202f")
const GOLD := Color("e5b638")
const BAUBLES := [Color("d4202f"), Color("e5b638"), Color("2e86de"), Color("c0c7d1"), Color("8e44ad")]
const FAIRY := [Color("ff5a5a"), Color("ffd84a"), Color("5ad1ff"), Color("7dff8a"), Color("ff8ae2")]

const FOLIAGE_SHADER := preload("res://core/visual/foliage.gdshader")
const SNOWFALL_SHADER := preload("res://core/visual/snowfall.gdshader")
const BRANCH_TEX := preload("res://assets/textures/generated/fir_branch.png")

## Render layer for meshes that their own built-in light should skip (each
## light a mesh receives costs a whole extra draw of it on the web renderer).
const SELF_LIT_LAYER := 1 << 1

static var _cache := {}


## A realistic snow-dusted fir: bark trunk, a dark inner core so you can't see
## through it, and whorls of drooping needle-branch cards. `detail` below 1
## thins it out for distant trees. `decorated` adds baubles, lights and a star.
static func fir_tree(height: float, seed := 1, decorated := false, detail := 1.0, snow := 0.45) -> Node3D:
	var root := Node3D.new()
	root.name = "FirTree"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := ToyBuilder.new()
	var trunk_r := height * 0.022
	var crown_base := height * 0.1
	b.textured(ToyBuilder.cylinder(trunk_r * 0.25, trunk_r, height * 0.95, 8), "bark_brown_02",
			ToyBuilder.xf(Vector3(0, height * 0.475, 0)), 0.8)
	# A slim dark core hides the gaps deep inside the crown.
	var core := ToyBuilder.lathe(PackedVector2Array([
		Vector2(0, crown_base), Vector2(height * 0.08, crown_base + height * 0.04),
		Vector2(height * 0.05, height * 0.5), Vector2(height * 0.015, height * 0.85), Vector2(0, height * 0.92),
	]), 8)
	b.add(core, Color("2a4632"))

	var foliage := _Foliage.new()
	var whorls := int(round(lerpf(10.0, 22.0, detail) * clampf(height / 5.0, 0.7, 1.3)))
	var tips := []
	for w in whorls:
		var t := float(w) / (whorls - 1)
		var y := lerpf(crown_base + height * 0.03, height * 0.93, pow(t, 0.92))
		var length := lerpf(height * 0.36, height * 0.07, t) * rng.randf_range(0.9, 1.1)
		var count := maxi(4, int(lerpf(11.0, 5.0, t) * lerpf(0.65, 1.0, detail)))
		var spin := rng.randf() * TAU
		for k in count:
			var angle := spin + TAU * k / count + rng.randf_range(-0.25, 0.25)
			var droop := deg_to_rad(lerpf(19.0, 5.0, t) + rng.randf_range(-6.0, 6.0))
			var tip := foliage.branch(Vector3(0, y + rng.randf_range(-0.03, 0.03) * height, 0), angle, droop, length, true)
			tips.append(tip)
			# Shorter inner shoots between the main branches fill out the crown.
			if detail >= 0.75 and k % 2 == 0:
				foliage.branch(Vector3(0, y + height * 0.025, 0), angle + PI / count, droop * 0.6, length * 0.6, false)
	# Leader shoot at the very top
	foliage.branch(Vector3(0, height * 0.9, 0), 0.0, -PI / 2.0 + 0.05, height * 0.12, true)

	if decorated:
		# Baubles hang on short threads from the branch tips: some mirror-bright
		# metal, some glossy glass, each with a gold cap and hanging loop.
		var bauble_r := height * 0.02
		for i in range(0, tips.size(), 2):
			var drop: float = rng.randf_range(0.02, 0.04) * height
			var at: Vector3 = tips[i] + Vector3(0, -drop - bauble_r, 0)
			var colour: Color = BAUBLES[rng.randi() % BAUBLES.size()]
			b.finished(ToyBuilder.sphere(bauble_r, 14), colour, "metal" if rng.randf() < 0.3 else "eye", ToyBuilder.xf(at))
			b.finished(ToyBuilder.cylinder(bauble_r * 0.28, bauble_r * 0.3, bauble_r * 0.25, 8), GOLD, "metal",
					ToyBuilder.xf(at + Vector3(0, bauble_r * 1.0, 0)))
			b.finished(ToyBuilder.torus(bauble_r * 0.14, bauble_r * 0.04, 8, 4), GOLD, "metal",
					ToyBuilder.xf(at + Vector3(0, bauble_r * 1.25, 0), Vector3(90, rng.randf() * 180.0, 0)))
			b.add(ToyBuilder.cylinder(height * 0.0012, height * 0.0012, drop, 3), Color("c9a64a"),
					ToyBuilder.xf(at + Vector3(0, bauble_r * 1.3 + drop / 2.0, 0)))
		# Fairy lights strung on a dark wire.
		var turns := 4.5
		var steps := 60
		var wire := PackedVector3Array()
		for k in steps + 1:
			var t := float(k) / steps
			var y := crown_base + t * height * 0.8
			var radius := lerpf(height * 0.3, height * 0.05, t)
			var angle := t * TAU * turns
			var point := Vector3(cos(angle) * radius, y, sin(angle) * radius)
			wire.append(point * Vector3(0.97, 1, 0.97))
			if k < steps:
				b.part(ToyBuilder.sphere(height * 0.009, 8), FAIRY[k % FAIRY.size()], point, Vector3.ZERO, Vector3.ONE, true)
		var thin := PackedFloat32Array()
		for k in steps + 1:
			thin.append(height * 0.0018)
		b.add(ToyBuilder.tube(wire, thin, 4), Color("1f2a22"))
		# A chain of gold beads swagged from branch to branch.
		var beads := 220
		var bead := ToyBuilder.sphere(height * 0.0045, 6)
		for k in beads:
			var t := float(k) / beads
			var radius := lerpf(height * 0.31, height * 0.06, t)
			var angle := t * TAU * 3.5 + PI
			var swag := sin(fmod(t * 3.5 * 7.0, 1.0) * PI) * height * 0.03
			var at := Vector3(cos(angle) * radius, crown_base + height * 0.05 + t * height * 0.75 - swag, sin(angle) * radius)
			b.finished(bead, GOLD, "eye", ToyBuilder.xf(at))
		b.part(ToyBuilder.star(5, height * 0.07, height * 0.03, height * 0.022), Color("ffd84a"),
				Vector3(0, height * 1.0, 0), Vector3.ZERO, Vector3.ONE, true)
		var light := OmniLight3D.new()
		light.light_color = Color("ffc875")
		light.light_energy = 1.3
		light.omni_range = height * 1.6
		light.light_cull_mask = ~SELF_LIT_LAYER
		light.position = Vector3(0, height * 0.55, height * 0.4)
		light.add_to_group(GraphicsQuality.LIGHTS_ABOVE_LOW)
		root.add_child(light)

	# Baubles, beads and fairy lights cast no shadow worth their triangles.
	b.shadowless("fin|")
	var mesh_instance := b.build(0.0, "Mesh")
	var mesh: ArrayMesh = mesh_instance.mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, foliage.arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, foliage_material(snow * (0.6 if decorated else 1.0)))
	if decorated:
		mesh_instance.layers = SELF_LIT_LAYER
		for child in mesh_instance.get_children():
			(child as MeshInstance3D).layers = SELF_LIT_LAYER
	root.add_child(mesh_instance)
	return root


## Shared needle material, one per snow amount.
static func foliage_material(snow: float) -> ShaderMaterial:
	var key := "foliage|%.2f" % snow
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = FOLIAGE_SHADER
		mat.set_shader_parameter("branch_tex", BRANCH_TEX)
		mat.set_shader_parameter("snow_amount", snow)
		mat.set_shader_parameter("snow_albedo", load("res://assets/textures/snow_02/albedo.jpg"))
		_cache[key] = mat
	return _cache[key]


## Collects needle-branch cards for a fir tree.
class _Foliage:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	## Adds one drooping branch from `origin`; returns where its tip ends up.
	func branch(origin: Vector3, angle: float, droop: float, length: float, crossed: bool) -> Vector3:
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-sin(angle), 0.0, cos(angle))
		var points := PackedVector3Array([origin])
		var segments := 3
		for i in segments:
			var pitch := droop * (0.4 + 1.2 * float(i) / segments)
			points.append(points[i] + (out * cos(pitch) - Vector3.UP * sin(pitch)) * length / segments)
		var width := length * 0.7
		# Lit as if part of a rounded crown: normals point outward and upward.
		var normal := (out * 0.75 + Vector3.UP * 0.65).normalized()
		_card(points, side * width * 0.5, normal, side)
		if crossed:
			var across := (points[segments] - origin).normalized().cross(side).normalized()
			_card(points, across * width * 0.45, normal, Vector3.ZERO)
		return points[segments]

	func _card(points: PackedVector3Array, half: Vector3, normal: Vector3, side: Vector3) -> void:
		var base := verts.size()
		for i in points.size():
			var f := float(i) / (points.size() - 1)
			verts.append_array([points[i] - half, points[i] + half])
			normals.append_array([(normal - side * 0.25).normalized(), (normal + side * 0.25).normalized()])
			uvs.append_array([Vector2(f, 0.0), Vector2(f, 1.0)])
		for i in points.size() - 1:
			var a := base + i * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])

	func arrays() -> Array:
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = verts
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TEX_UV] = uvs
		result[Mesh.ARRAY_INDEX] = indices
		return result


## A hand-rolled snowman: lumpy packed-snow balls, coal eyes and buttons, a
## carrot nose, twig arms, a knitted scarf and an old top hat.
static func snowman(seed := 1) -> Node3D:
	var b := ToyBuilder.new()
	var balls := [[0.55, 0.48, 0.92], [0.4, 1.16, 0.95], [0.29, 1.7, 1.0]]
	for i in balls.size():
		var ball: Array = balls[i]
		var shape := ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 24), 0.05, 2.5, seed + i)
		b.textured(shape, "snow_02", ToyBuilder.xf(Vector3(0, ball[1], 0), Vector3(0, i * 40, 0),
				Vector3(ball[0], ball[0] * ball[2], ball[0])), 1.6, Color("f4f7fc"))
	b.textured(ToyBuilder.lumpy(ToyBuilder.snow_ring(0.46, 0.09, 20), 0.03, 5.0, seed), "snow_02",
			ToyBuilder.xf(Vector3.ZERO), 1.5, SNOW_TINT)
	var coal := ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.3, 3.0, seed + 5)
	for side: float in [-1.0, 1.0]:
		b.part(coal, COAL, Vector3(0.1 * side, 1.78, 0.25), Vector3(0, side * 30, 0), Vector3.ONE * 0.035)
		# Twig arms with little forked fingers
		b.textured(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.33 * side, 1.25, 0), Vector3(0.62 * side, 1.38, 0.05), Vector3(0.88 * side, 1.6, 0.02),
		]), PackedFloat32Array([0.028, 0.022, 0.012]), 6), "bark_brown_02", Transform3D.IDENTITY, 0.3, Color.WHITE, 0.4)
		b.textured(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.78 * side, 1.5, 0.03), Vector3(0.88 * side, 1.48, 0.09), Vector3(0.97 * side, 1.51, 0.11),
		]), PackedFloat32Array([0.012, 0.009, 0.005]), 5), "bark_brown_02", Transform3D.IDENTITY, 0.3)
	for k in 5:
		var a := lerpf(-0.5, 0.5, k / 4.0)
		b.part(coal, COAL, Vector3(sin(a) * 0.13, 1.61 - cos(a * 1.2) * 0.04 + 0.03, 0.265), Vector3(k * 50, k * 30, 0), Vector3.ONE * 0.02)
	for k in 3:
		b.part(coal, COAL, Vector3(0, 0.98 + k * 0.15, 0.385 - absf(k - 1) * 0.02), Vector3(k * 70, 0, k * 20), Vector3.ONE * 0.04)
	# A slightly crooked carrot with grooves
	b.add(ToyBuilder.lumpy(ToyBuilder.cylinder(0.0, 0.045, 0.3, 10), 0.006, 30.0, seed), CARROT,
			ToyBuilder.xf(Vector3(0.0, 1.71, 0.4), Vector3(84, 0, 6)))
	# Knitted scarf with a hanging tail
	var knit := ToyBuilder.lumpy(ToyBuilder.torus(0.25, 0.06, 28, 10), 0.012, 22.0, seed)
	b.finished(knit, BERRY.darkened(0.15), "velvet", ToyBuilder.xf(Vector3(0, 1.46, 0)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.curve(PackedVector3Array([
		Vector3(0.15, 1.44, 0.2), Vector3(0.23, 1.25, 0.32), Vector3(0.21, 1.03, 0.38),
	]), PackedFloat32Array([0.055, 0.05, 0.045]), 10), 0.01, 22.0, seed + 2), BERRY.darkened(0.15), "velvet")
	# Tassels on the scarf end
	for k in 5:
		b.finished(ToyBuilder.cylinder(0.006, 0.004, 0.07, 4), BERRY.darkened(0.25), "velvet",
				ToyBuilder.xf(Vector3(0.19 + k * 0.012, 0.98, 0.38 + k * 0.004), Vector3(0, 0, k * 4 - 8)))
	# Battered top hat
	var felt := Color("1d1b1c")
	b.finished(ToyBuilder.cylinder(0.3, 0.3, 0.03, 28), felt, "velvet", ToyBuilder.xf(Vector3(0, 1.96, 0), Vector3(0, 0, -6)))
	b.finished(ToyBuilder.cylinder(0.19, 0.18, 0.32, 28), felt, "velvet", ToyBuilder.xf(Vector3(0.015, 2.13, 0), Vector3(0, 0, -6)))
	b.finished(ToyBuilder.cylinder(0.185, 0.185, 0.06, 28), BERRY.darkened(0.3), "velvet", ToyBuilder.xf(Vector3(0.01, 2.02, 0), Vector3(0, 0, -6)))
	# A sprig of holly tucked in the hat band
	for k in 3:
		b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.15, 3.0, k), PINE.darkened(0.35), "eye",
				ToyBuilder.xf(Vector3(-0.1 + k * 0.03, 2.05, 0.195), Vector3(70, k * 50 - 50, 0), Vector3(0.05, 0.012, 0.022)))
		b.finished(ToyBuilder.sphere(0.014, 8), BERRY, "eye", ToyBuilder.xf(Vector3(-0.07 + k * 0.015, 2.04 + (k % 2) * 0.02, 0.21)))
	b.textured(ToyBuilder.snow_sheet(Vector2(0.3, 0.3), 0.05, seed + 7, 0.04), "snow_02",
			ToyBuilder.xf(Vector3(0.03, 2.29, 0), Vector3(0, 0, -6)), 1.5, SNOW_TINT)
	var root := Node3D.new()
	root.name = "Snowman"
	root.add_child(b.build(0.0, "Mesh"))
	return root


## A candle lantern: an iron frame with glass sides round a lit candle, and
## a ring handle. Its origin is the top of the handle, to hang it by.
static func lantern() -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern"
	var b := ToyBuilder.new()
	var iron := Color("26262a")
	b.finished(ToyBuilder.torus(0.045, 0.008, 12, 4), iron, "metal", ToyBuilder.xf(Vector3(0, -0.045, 0), Vector3(90, 0, 0)))
	b.finished(ToyBuilder.cylinder(0.05, 0.075, 0.05, 10), iron, "metal", ToyBuilder.xf(Vector3(0, -0.11, 0)))
	b.finished(ToyBuilder.cylinder(0.08, 0.08, 0.015, 10), iron, "metal", ToyBuilder.xf(Vector3(0, -0.14, 0)))
	b.finished(ToyBuilder.cylinder(0.085, 0.085, 0.02, 10), iron, "metal", ToyBuilder.xf(Vector3(0, -0.33, 0)))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		b.finished(ToyBuilder.box(Vector3(0.012, 0.19, 0.012)), iron, "metal",
				ToyBuilder.xf(Vector3(cos(a) * 0.075, -0.235, sin(a) * 0.075)))
	b.finished(ToyBuilder.cylinder(0.018, 0.018, 0.07, 8), Color("f2e8d0"), "skin", ToyBuilder.xf(Vector3(0, -0.285, 0)))
	b.add(ToyBuilder.sphere(0.014, 6), Color(1.0, 0.75, 0.35), ToyBuilder.xf(Vector3(0, -0.237, 0), Vector3.ZERO, Vector3(1, 1.8, 1)), true)
	root.add_child(b.build(0.0, "Frame"))
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = ToyBuilder.cylinder(0.07, 0.07, 0.18, 4)
	glass.rotation.y = PI / 4.0
	glass.position.y = -0.235
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.6, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.25)
	mat.emission_energy_multiplier = 0.5
	mat.roughness = 0.1
	glass.material_override = mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	var light := FlickerLight.new()
	light.light_color = Color("ffb35c")
	light.base_energy = 1.1
	light.flicker = 0.18
	light.omni_range = 4.5
	light.position = Vector3(0, -0.2, 0.15)
	root.add_child(light)
	return root


## A crackling campfire in a stone ring: crossed logs, flames, rising embers
## and a flickering warm light.
static func campfire() -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	root.add_child(PbrLibrary.model("stone_fire_pit", 0.35))
	var b := ToyBuilder.new()
	for k in 4:
		var a := k * 90.0 + 20.0
		b.textured(ToyBuilder.cylinder(0.06, 0.07, 0.7, 9), "bark_brown_02",
				ToyBuilder.xf(Vector3(0, 0.18, 0), Vector3(0, a, 62)), 0.4, Color("8a8a8a"))
	b.part(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 10), 0.3, 4.0, 3), Color("ff7a1a"), Vector3(0, 0.1, 0),
			Vector3.ZERO, Vector3(0.22, 0.06, 0.22), true)
	root.add_child(b.build(0.0, "Logs"))

	root.add_child(fire())
	return root


## Flames, rising embers and a flickering warm light: the fire of a campfire,
## brazier or stove. `size` 1 is a campfire.
static func fire(size := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 28
	flames.lifetime = 0.8
	flames.position = Vector3(0, 0.2, 0) * size
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.12 * size
	flames.direction = Vector3.UP
	flames.spread = 8
	flames.initial_velocity_min = 0.5 * size
	flames.initial_velocity_max = 0.9 * size
	flames.gravity = Vector3(0, 0.6, 0)
	flames.scale_amount_min = 0.25 * size
	flames.scale_amount_max = 0.4 * size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(1, 0.1))
	flames.scale_amount_curve = shrink
	var heat := Gradient.new()
	heat.set_color(0, Color(1.0, 0.75, 0.35, 0.8))
	heat.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
	heat.add_point(0.4, Color(1.0, 0.45, 0.08, 0.6))
	flames.color_ramp = heat
	flames.mesh = _glow_quad(0.5)
	root.add_child(flames)

	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 14
	embers.lifetime = 2.2
	embers.position = Vector3(0, 0.35, 0) * size
	embers.direction = Vector3.UP
	embers.spread = 25
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.2
	embers.gravity = Vector3(0.1, 0.2, 0)
	embers.scale_amount_min = 0.03
	embers.scale_amount_max = 0.06
	var cool := Gradient.new()
	cool.set_color(0, Color(1.0, 0.7, 0.3, 1.0))
	cool.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	embers.color_ramp = cool
	embers.mesh = _glow_quad(1.0)
	root.add_child(embers)

	var light := FlickerLight.new()
	light.light_color = Color("ff9a45")
	light.base_energy = 2.2
	light.omni_range = 6.0 * size
	light.position = Vector3(0, 0.6, 0) * size
	root.add_child(light)
	return root


## A camera-facing additive glow sprite for flames and sparks.
static func _glow_quad(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft_dot()
	mat.albedo_color = Color(0.65, 0.65, 0.65)
	quad.material = mat
	return quad


## A log cabin: notched logs with snow along their tops, a plank roof under a
## soft blanket of snow, glowing windows, wreath, fairy lights, a smoking stone
## chimney, a firewood stack and a lantern by the door.
static func log_cabin(seed := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "LogCabin"
	var b := ToyBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var log_r := 0.14
	var rows := 7
	var log_snow := 0.32
	# Sawn log ends and the lit window panes need UVs, so they get their own surfaces.
	var ends := MeshPieces.new()
	var panes := MeshPieces.new()
	var chinking := Color("b9b2a6")

	b.textured(ToyBuilder.box(Vector3(4.4, 0.3, 3.4)), "old_stone_wall", ToyBuilder.xf(Vector3(0, 0.15, 0)), 1.2, Color.WHITE, 0.4)
	# Walls: logs cross at the corners and stick out past them, as real notched logs do.
	for k in rows:
		var y := 0.42 + k * log_r * 1.9
		var tint := Color.WHITE if k % 2 == 0 else Color("d8d0c8")
		for z in [-1.5, 1.5]:
			var lean := rng.randf_range(-1.0, 1.0)
			var shift := rng.randf_range(-0.05, 0.05)
			b.textured(ToyBuilder.cylinder(log_r, log_r * 1.05, 4.6, 12), "wood_trunk_wall",
					ToyBuilder.xf(Vector3(shift, y, z), Vector3(lean, 0, 90)), 1.6, tint, log_snow)
			for end: float in [-1.0, 1.0]:
				var r := log_r * (1.05 if end < 0.0 else 1.0)
				ends.disc(Vector3(shift + end * 2.302, y, z), Vector3(end, 0, 0), Vector3.UP, r, Color(rng.randf(), 0, 0))
			# Mortar chinking packed into the groove above each log.
			if k < rows - 1:
				b.add(ToyBuilder.box(Vector3(3.9, 0.075, 0.17)), chinking, ToyBuilder.xf(Vector3(0, y + log_r * 0.95, z)))
		for x in [-2.0, 2.0]:
			var shift := rng.randf_range(-0.05, 0.05)
			b.textured(ToyBuilder.cylinder(log_r * 1.05, log_r, 3.6, 12), "wood_trunk_wall",
					ToyBuilder.xf(Vector3(x, y + log_r * 0.95, shift), Vector3(90, 0, 0)), 1.6, tint, log_snow)
			for end: float in [-1.0, 1.0]:
				ends.disc(Vector3(x, y + log_r * 0.95, shift + end * 1.802), Vector3(0, 0, end), Vector3.UP, log_r * 1.03, Color(rng.randf(), 0, 0))
			if k < rows - 1:
				b.add(ToyBuilder.box(Vector3(0.17, 0.075, 2.9)), chinking, ToyBuilder.xf(Vector3(x, y + log_r * 1.9, 0)))
	var wall_top := 0.42 + rows * log_r * 1.9
	# Gables on the side walls, stepping in under the roof slopes.
	for k in 5:
		var length := 3.0 * (1.0 - (k + 1) / 6.0)
		for x in [-2.0, 2.0]:
			b.textured(ToyBuilder.cylinder(log_r, log_r, length, 12), "wood_trunk_wall",
					ToyBuilder.xf(Vector3(x, wall_top + k * log_r * 1.8, 0), Vector3(90, 0, 0)), 1.6, Color.WHITE, log_snow)
			for end: float in [-1.0, 1.0]:
				ends.disc(Vector3(x, wall_top + k * log_r * 1.8, end * (length / 2.0 + 0.002)), Vector3(0, 0, end), Vector3.UP,
						log_r, Color(rng.randf(), 0, 0))

	# Roof: plank slabs under a thick, soft blanket of snow that droops over the eaves.
	var ridge := wall_top + 1.25
	var eave := wall_top - 0.1
	var half := 1.95
	var angle := rad_to_deg(atan2(ridge - eave, half))
	var slope_len := sqrt(half * half + (ridge - eave) * (ridge - eave)) + 0.35
	for side: float in [-1.0, 1.0]:
		var centre := Vector3(0, (ridge + eave) / 2.0, half / 2.0 * side)
		var rot := Vector3(angle * side, 0, 0)
		var basis := Basis.from_euler(rot * PI / 180.0)
		var normal := basis * Vector3.UP
		b.textured(ToyBuilder.box(Vector3(5.0, 0.16, slope_len)), "brown_planks_04", ToyBuilder.xf(centre, rot), 1.5, Color("b08a70"))
		var sheet := ToyBuilder.snow_sheet(Vector2(4.9, slope_len - 0.1), 0.2, seed + int(side * 7))
		b.textured(sheet, "snow_02", Transform3D(basis, centre + normal * 0.08), 1.5, SNOW_TINT)
		var eave_pos := centre + basis * Vector3(0, 0, slope_len / 2.0 * side) + normal * 0.02
		# A soft, uneven lip of snow curling over the eave.
		var lip := PackedVector3Array()
		var lip_r := PackedFloat32Array()
		for k in 25:
			var x := lerpf(-2.5, 2.5, k / 24.0)
			lip.append(eave_pos + Vector3(x, 0.03 + rng.randf_range(-0.015, 0.015), side * 0.02))
			lip_r.append(rng.randf_range(0.07, 0.1) * (0.6 if k == 0 or k == 24 else 1.0))
		b.textured(ToyBuilder.tube(lip, lip_r, 8), "snow_02", Transform3D.IDENTITY, 1.5, SNOW_TINT)
		# Icicles: mostly short, a few long ones, thicker at the root.
		for k in 34:
			if rng.randf() < 0.7:
				var x := lerpf(-2.4, 2.4, k / 33.0) + rng.randf_range(-0.03, 0.03)
				var icicle := rng.randf_range(0.08, 0.3) if rng.randf() < 0.8 else rng.randf_range(0.32, 0.48)
				var thick := 0.014 + icicle * 0.04
				b.part(ToyBuilder.cylinder(thick, 0.0, icicle, 6), ICE, eave_pos + Vector3(x, -icicle / 2.0 - 0.1, side * 0.03), Vector3(180, 0, 0))
		if side > 0.0:
			for k in 20:
				var x := lerpf(-2.35, 2.35, k / 19.0)
				var sag := absf(sin(k * PI / 2.5)) * 0.05
				b.part(ToyBuilder.sphere(0.035, 8), FAIRY[k % FAIRY.size()], eave_pos + Vector3(x, -0.16 - sag, 0.0),
						Vector3.ZERO, Vector3.ONE, true)

	# Stone chimney with a snow cap and smoke
	var chimney := Vector3(1.2, ridge - 0.1, -0.6)
	b.textured(ToyBuilder.box(Vector3(0.55, 1.6, 0.55)), "old_stone_wall", ToyBuilder.xf(chimney), 1.0, Color.WHITE, 0.4)
	b.textured(ToyBuilder.box(Vector3(0.65, 0.12, 0.65)), "old_stone_wall", ToyBuilder.xf(chimney + Vector3(0, 0.8, 0)), 1.0, Color("aaaaaa"), 0.4)
	b.textured(ToyBuilder.snow_sheet(Vector2(0.55, 0.55), 0.07, seed + 3, 0.05), "snow_02",
			ToyBuilder.xf(chimney + Vector3(0, 0.86, 0)), 1.5, SNOW_TINT)
	root.add_child(_chimney_smoke(chimney + Vector3(0, 0.95, 0)))

	# Front door with wreath and a stone step
	var front := 1.5 + log_r
	b.textured(ToyBuilder.box(Vector3(0.98, 1.6, 0.1)), "wood_trunk_wall", ToyBuilder.xf(Vector3(0, 1.07, front + 0.02)), 0.6, Color("6b5040"))
	b.textured(ToyBuilder.box(Vector3(0.8, 1.42, 0.08)), "brown_planks_04", ToyBuilder.xf(Vector3(0, 1.03, front + 0.07)), 1.0, Color("c88a5a"))
	for k in 3:
		b.textured(ToyBuilder.box(Vector3(0.74, 0.05, 0.03)), "brown_planks_04", ToyBuilder.xf(Vector3(0, 0.55 + k * 0.45, front + 0.12)), 0.6, Color("7a5238"))
	# Door frame, strap hinges with nail heads, and a ring pull on a back plate.
	var trim := Color("5a4232")
	for x in [-0.53, 0.53]:
		b.textured(ToyBuilder.box(Vector3(0.1, 1.72, 0.07)), "wood_trunk_wall", ToyBuilder.xf(Vector3(x, 1.1, front + 0.08)), 0.6, trim)
	b.textured(ToyBuilder.box(Vector3(1.22, 0.12, 0.09)), "wood_trunk_wall", ToyBuilder.xf(Vector3(0, 1.97, front + 0.08)), 0.6, trim, 0.6)
	var hinge := Color("2a2522")
	for hy in [0.62, 1.48]:
		b.finished(ToyBuilder.box(Vector3(0.5, 0.045, 0.012)), hinge, "metal", ToyBuilder.xf(Vector3(-0.15, hy, front + 0.117)))
		b.finished(ToyBuilder.sphere(0.03, 10), hinge, "metal", ToyBuilder.xf(Vector3(0.1, hy, front + 0.117), Vector3.ZERO, Vector3(1, 1, 0.4)))
		for n in 4:
			b.finished(ToyBuilder.sphere(0.009, 6), hinge.darkened(0.3), "metal", ToyBuilder.xf(Vector3(-0.36 + n * 0.13, hy, front + 0.124)))
	b.finished(ToyBuilder.box(Vector3(0.08, 0.13, 0.01)), hinge, "metal", ToyBuilder.xf(Vector3(0.28, 0.98, front + 0.115)))
	b.finished(ToyBuilder.torus(0.04, 0.008, 14, 6), Color("3a3330"), "metal", ToyBuilder.xf(Vector3(0.28, 0.92, front + 0.128), Vector3(90, 0, 0)))
	var sprigs := _Foliage.new()
	add_wreath(b, sprigs, ToyBuilder.xf(Vector3(0, 1.42, front + 0.13)), seed)
	b.textured(ToyBuilder.box(Vector3(1.3, 0.12, 0.5)), "old_stone_wall", ToyBuilder.xf(Vector3(0, 0.06, front + 0.3)), 0.8, Color.WHITE, 0.5)

	# Windows: timber frames, warm glass with crossbars, and sills that catch snow
	for x in [-1.25, 1.25]:
		var w := Vector3(x, 1.25, front + 0.02)
		b.textured(ToyBuilder.box(Vector3(0.82, 0.72, 0.08)), "wood_trunk_wall", ToyBuilder.xf(w), 0.6, Color("6b5040"))
		panes.rect(w + Vector3(0, 0, 0.042), Vector3.BACK, Vector3.UP, Vector2(0.64, 0.54))
		# Casing round the glass, standing proud of the wall.
		for e: Array in [[Vector3(0, 0.3, 0), Vector3(0.74, 0.06, 0.06)], [Vector3(0, -0.3, 0), Vector3(0.74, 0.06, 0.06)],
				[Vector3(-0.34, 0, 0), Vector3(0.06, 0.66, 0.06)], [Vector3(0.34, 0, 0), Vector3(0.06, 0.66, 0.06)]]:
			b.textured(ToyBuilder.box(e[1]), "wood_trunk_wall", ToyBuilder.xf(w + (e[0] as Vector3) + Vector3(0, 0, 0.06)), 0.6, Color("5a4232"))
		b.part(ToyBuilder.box(Vector3(0.035, 0.56, 0.04)), LOG_DARK.darkened(0.3), w + Vector3(0, 0, 0.065))
		b.part(ToyBuilder.box(Vector3(0.66, 0.035, 0.04)), LOG_DARK.darkened(0.3), w + Vector3(0, 0, 0.065))
		# Painted plank shutters, folded back against the logs.
		for sx: float in [-1.0, 1.0]:
			var shutter := w + Vector3(sx * 0.6, 0, 0.03)
			for plank in 3:
				b.textured(ToyBuilder.box(Vector3(0.105, 0.74, 0.04)), "brown_planks_04",
						ToyBuilder.xf(shutter + Vector3((plank - 1) * 0.11, 0, 0)), 0.5, Color("4d7a58"))
			for by in [0.24, -0.24]:
				b.textured(ToyBuilder.box(Vector3(0.32, 0.06, 0.02)), "brown_planks_04", ToyBuilder.xf(shutter + Vector3(0, by, 0.028)), 0.5, Color("3f6b4a"))
		b.textured(ToyBuilder.box(Vector3(0.95, 0.07, 0.22)), "brown_planks_04", ToyBuilder.xf(w + Vector3(0, -0.4, 0.09)), 0.6, Color("9a7058"), 0.6)
		b.textured(ToyBuilder.snow_sheet(Vector2(0.9, 0.18), 0.05, seed + int(x * 10), 0.04), "snow_02",
				ToyBuilder.xf(w + Vector3(0, -0.36, 0.09)), 1.5, SNOW_TINT)

	# Firewood stacked against the right-hand wall
	for row_i in 5:
		for k in 7 - row_i % 2:
			var pos := Vector3(2.45, 0.12 + row_i * 0.2, -1.05 + k * 0.3 + (row_i % 2) * 0.15)
			var nudge := rng.randf_range(-0.04, 0.04)
			b.textured(ToyBuilder.cylinder(0.1, 0.1, 0.6, 9), "bark_brown_02",
					ToyBuilder.xf(pos + Vector3(nudge, 0, 0), Vector3(0, 0, 90)), 0.5, Color.WHITE, 0.45)
			ends.disc(pos + Vector3(nudge + 0.302, 0, 0), Vector3.RIGHT, Vector3.UP, 0.1, Color(rng.randf(), 0, 0), 10)
	b.textured(ToyBuilder.snow_sheet(Vector2(0.6, 2.0), 0.08, seed + 9, 0.06), "snow_02", ToyBuilder.xf(Vector3(2.45, 1.05, -0.1)), 1.5, SNOW_TINT)

	# One warm light spilling out of both windows
	var glow := OmniLight3D.new()
	glow.light_color = WARM_LIGHT
	glow.light_energy = 2.0
	glow.omni_range = 5.0
	glow.position = Vector3(0, 1.3, front + 0.8)
	root.add_child(glow)

	# Snow drifted up against the walls, leaving the doorway clear
	for k in 7:
		var drift := ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 16), 0.15, 1.6, seed + 40 + k)
		var dx := rng.randf_range(-2.2, 2.2)
		if absf(dx) < 0.8:
			dx = 0.9 if dx >= 0.0 else -0.9
		b.textured(drift, "snow_02", ToyBuilder.xf(Vector3(dx, 0.0, front + 0.2),
				Vector3(0, rng.randf_range(0, 360), 0), Vector3(rng.randf_range(0.4, 0.7), 0.22, 0.3)), 1.5, SNOW_TINT)

	var cabin_mesh := b.build(0.0, "Mesh")
	ends.add_to(cabin_mesh.mesh, end_grain_material())
	panes.add_to(cabin_mesh.mesh, window_material())
	cabin_mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sprigs.arrays())
	cabin_mesh.mesh.surface_set_material(cabin_mesh.mesh.get_surface_count() - 1, wreath_material())
	root.add_child(cabin_mesh)

	var lantern := PbrLibrary.model("wooden_lantern_01", 0.0)
	lantern.position = Vector3(0.7, 1.55, front + 0.16)
	lantern.scale = Vector3.ONE * 0.9
	root.add_child(lantern)
	return root


## Sawn log ends: rings, cracks and a bark rim. COLOR.r seeds each log.
static func end_grain_material() -> ShaderMaterial:
	if not _cache.has("end_grain"):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://core/visual/end_grain.gdshader")
		mat.set_shader_parameter("noise_tex", CharacterFinish.noise())
		_cache["end_grain"] = mat
	return _cache["end_grain"]


## Lit window panes with curtains, a pelmet and frost round the edges.
static func window_material() -> ShaderMaterial:
	if not _cache.has("window"):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://core/visual/window_glass.gdshader")
		mat.set_shader_parameter("noise_tex", CharacterFinish.noise())
		mat.set_shader_parameter("cell_tex", CharacterFinish.cells())
		_cache["window"] = mat
	return _cache["window"]


static func _chimney_smoke(at: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 4.0
	smoke.preprocess = 4.0
	smoke.position = at
	smoke.direction = Vector3(0.3, 1, 0)
	smoke.spread = 12
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3(0.15, 0.05, 0)
	smoke.scale_amount_min = 0.25
	smoke.scale_amount_max = 0.45
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * 1.4
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.72, 0.75, 0.82)
	puff_mat.vertex_color_use_as_albedo = true
	puff_mat.albedo_texture = soft_dot()
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = puff_mat
	smoke.mesh = puff
	return smoke


## A soft round blob texture for smoke and other particles.
## Gently falling snow filling a box (`origin` is its low corner): `amount`
## flakes, all animated by the snowfall shader, drawn in one go.
static func snowfall(amount: int, origin: Vector3, size: Vector3) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in amount:
		var seed := Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
		var base := verts.size()
		for c: Vector2 in corners:
			verts.append(Vector3.ZERO)
			uvs.append(c)
			colors.append(seed)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The flakes are placed by the shader, so tell the engine where they can be.
	mesh.custom_aabb = AABB(origin - Vector3.ONE, size + Vector3.ONE * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = SNOWFALL_SHADER
	mat.set_shader_parameter("dot_tex", soft_dot())
	mat.set_shader_parameter("box_min", origin)
	mat.set_shader_parameter("box_size", size)
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.name = "Snowfall"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func soft_dot() -> GradientTexture2D:
	if not _cache.has("soft_dot"):
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		_cache["soft_dot"] = tex
	return _cache["soft_dot"]


## A wrought-iron street lamp with a warm glowing lantern.
static func lamp_post() -> Node3D:
	var root := Node3D.new()
	root.name = "LampPost"
	var b := ToyBuilder.new()
	# Cast-iron post: a stepped, fluted base, a ringed shaft and a decorative collar.
	var iron := Color("23282a")
	b.finished(ToyBuilder.cylinder(0.15, 0.2, 0.1, 16), iron, "metal", ToyBuilder.xf(Vector3(0, 0.05, 0)))
	b.finished(ToyBuilder.cylinder(0.1, 0.14, 0.3, 16), iron, "metal", ToyBuilder.xf(Vector3(0, 0.25, 0)))
	for k in 8:
		var a := TAU * k / 8.0
		b.finished(ToyBuilder.box(Vector3(0.025, 0.28, 0.025)), iron, "metal",
				ToyBuilder.xf(Vector3(cos(a) * 0.115, 0.25, sin(a) * 0.115), Vector3(0, -rad_to_deg(a), 0)))
	b.finished(ToyBuilder.cylinder(0.045, 0.06, 2.4, 12), iron, "metal", ToyBuilder.xf(Vector3(0, 1.6, 0)))
	for ring_y in [0.45, 0.9, 2.62]:
		b.finished(ToyBuilder.torus(0.06, 0.018, 16, 6), iron, "metal", ToyBuilder.xf(Vector3(0, ring_y, 0)))
	b.finished(ToyBuilder.sphere(0.075, 14), iron, "metal", ToyBuilder.xf(Vector3(0, 0.9, 0)))
	b.finished(ToyBuilder.cylinder(0.13, 0.08, 0.1, 12), iron, "metal", ToyBuilder.xf(Vector3(0, 2.76, 0)))
	# Lantern: a glowing mantle behind six warm, slightly frosted glass panes.
	var lantern := Vector3(0, 2.98, 0)
	b.part(ToyBuilder.sphere(0.05, 10), Color("fff0c8"), lantern, Vector3.ZERO, Vector3(1, 1.4, 1), true)
	b.part(ToyBuilder.cylinder(0.115, 0.095, 0.34, 6), Color("e09a48"), lantern, Vector3(0, 30, 0), Vector3.ONE, true)
	for k in 6:
		var a := TAU * k / 6.0
		b.finished(ToyBuilder.box(Vector3(0.022, 0.4, 0.022)), iron, "metal",
				ToyBuilder.xf(lantern + Vector3(cos(a) * 0.115, 0, sin(a) * 0.115)))
	b.finished(ToyBuilder.cylinder(0.14, 0.13, 0.03, 6), iron, "metal", ToyBuilder.xf(lantern + Vector3(0, -0.2, 0), Vector3(0, 30, 0)))
	b.finished(ToyBuilder.cylinder(0.0, 0.21, 0.18, 6), iron, "metal", ToyBuilder.xf(lantern + Vector3(0, 0.29, 0), Vector3(0, 30, 0)))
	b.finished(ToyBuilder.sphere(0.035, 10), iron, "metal", ToyBuilder.xf(lantern + Vector3(0, 0.4, 0)))
	b.textured(ToyBuilder.lumpy(ToyBuilder.cylinder(0.05, 0.22, 0.1, 12), 0.012, 9.0, 5), "snow_02",
			ToyBuilder.xf(lantern + Vector3(0, 0.27, 0)), 1.5, SNOW_TINT)
	# A holly garland wound round the post, with berries and a velvet bow.
	var holly := ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.15, 3.0, 4)
	for k in 26:
		var t := k / 25.0
		var a := t * TAU * 2.0
		var at := Vector3(cos(a) * 0.07, 1.75 + t * 0.6, sin(a) * 0.07)
		b.finished(holly, PINE.darkened(0.35), "eye",
				ToyBuilder.xf(at, Vector3(k * 37 % 90, -rad_to_deg(a) + k * 23, 30), Vector3(0.05, 0.012, 0.025)))
		if k % 3 == 0:
			b.finished(ToyBuilder.sphere(0.014, 8), BERRY, "eye", ToyBuilder.xf(at + Vector3(cos(a) * 0.03, 0.01, sin(a) * 0.03)))
	for sx: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.torus(0.026, 0.016, 12, 6), BERRY, "velvet",
				ToyBuilder.xf(Vector3(sx * 0.035, 2.38, 0.07), Vector3(90, 0, sx * 12), Vector3(1.4, 0.8, 0.8)))
		b.finished(ToyBuilder.box(Vector3(0.025, 0.1, 0.006)), BERRY, "velvet",
				ToyBuilder.xf(Vector3(sx * 0.018, 2.33, 0.075), Vector3(0, 0, sx * 14)))
	b.finished(ToyBuilder.sphere(0.017, 10), BERRY.darkened(0.1), "velvet", ToyBuilder.xf(Vector3(0, 2.38, 0.08)))
	root.add_child(b.build(0.01, "Mesh"))
	var light := OmniLight3D.new()
	light.light_color = WARM_LIGHT
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = lantern
	light.add_to_group(GraphicsQuality.LIGHTS_ABOVE_LOW)
	root.add_child(light)
	return root


## A wrapped present with ribbon and bow.
static func present(size: Vector3, color: Color, ribbon := GOLD, pattern := -1, seed := 1) -> Node3D:
	return GiftBox.build(size, color, ribbon, pattern, seed)


## A red-and-white striped candy cane.
static func candy_cane(height := 1.2) -> Node3D:
	var path := ToyBuilder.smooth_path(PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, height * 0.7, 0), Vector3(0, height * 0.9, 0),
		Vector3(height * 0.08, height, 0), Vector3(height * 0.18, height * 0.94, 0), Vector3(height * 0.2, height * 0.82, 0),
	]), 8)
	var b := ToyBuilder.new()
	var radius := height * 0.045
	var chunk := 4
	var stripe := 0
	var i := 0
	while i < path.size() - 1:
		var piece := path.slice(i, mini(i + chunk + 1, path.size()))
		var radii := PackedFloat32Array()
		radii.resize(piece.size())
		radii.fill(radius)
		b.add(ToyBuilder.tube(piece, radii, 10), BERRY if stripe % 2 == 0 else Color.WHITE)
		stripe += 1
		i += chunk
	var root := Node3D.new()
	root.name = "CandyCane"
	root.add_child(b.build(0.01, "Mesh"))
	return root


## A short run of snowy picket fence along +X.
static func fence(length := 4.0) -> Node3D:
	var b := ToyBuilder.new()
	var posts := int(length / 0.5) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 100.0)
	for k in posts:
		var x := k * 0.5 - length / 2.0
		# Weathered pickets, each a little different in height and lean.
		var h := rng.randf_range(0.84, 0.95)
		var lean := Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.5, 2.5))
		var grey := Color("e4dfd8")
		b.textured(ToyBuilder.box(Vector3(0.1, h, 0.035)), "brown_planks_04", ToyBuilder.xf(Vector3(x, h / 2.0, 0), lean), 0.8, grey)
		var tip := Basis.from_euler(lean * PI / 180.0) * Vector3(0, h, 0)
		b.textured(ToyBuilder.cylinder(0.0, 0.071, 0.09, 4), "brown_planks_04",
				ToyBuilder.xf(Vector3(x, 0, 0) + tip + Vector3(0, 0.04, 0), lean + Vector3(0, 45, 0), Vector3(1, 1, 0.35)), 0.8, grey)
		b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.2, 3.0, k), "snow_02",
				ToyBuilder.xf(Vector3(x, 0, 0) + tip + Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(0.06, 0.035, 0.035)), 1.0, SNOW_TINT)
		for ny in [0.3, 0.7]:
			b.finished(ToyBuilder.sphere(0.008, 6), Color("3a3330"), "metal", ToyBuilder.xf(Vector3(x, ny, 0.02)))
		# Snow banked against the foot of each post.
		b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.25, 2.0, k + 50), "snow_02",
				ToyBuilder.xf(Vector3(x, 0, 0.02), Vector3(0, k * 40, 0), Vector3(0.16, 0.09, 0.12)), 1.5, SNOW_TINT)
	for y in [0.3, 0.7]:
		b.textured(ToyBuilder.box(Vector3(length + 0.1, 0.08, 0.04)), "brown_planks_04", ToyBuilder.xf(Vector3(0, y, -0.04)), 0.8, Color("9a7a60"))
		# A soft, uneven ridge of snow along the top of each rail.
		var ridge := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 17:
			ridge.append(Vector3(lerpf(-length / 2.0 - 0.04, length / 2.0 + 0.04, k / 16.0), y + 0.045, -0.04))
			radii.append(rng.randf_range(0.022, 0.034) * (0.4 if k == 0 or k == 16 else 1.0))
		b.textured(ToyBuilder.tube(ridge, radii, 6), "snow_02", ToyBuilder.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.7, 1)), 1.0, SNOW_TINT)
	var root := Node3D.new()
	root.name = "Fence"
	root.add_child(b.build(0.01, "Mesh"))
	return root


## A ring of rocky, snow-capped mountains around the scene. Steep faces show
## bare rock; ledges, gentle slopes and the high peaks hold snow.
static func mountain_range(inner := 80.0, outer := 160.0, peak := 24.0, seed := 1) -> MeshInstance3D:
	var ridges := FastNoiseLite.new()
	ridges.seed = seed
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 5
	ridges.frequency = 0.012
	var around := 200
	var rows := 18
	var points := PackedVector3Array()
	for j in rows + 1:
		var r := lerpf(inner, outer, float(j) / rows)
		var rise := smoothstep(inner, inner + (outer - inner) * 0.45, r)
		for i in around:
			var angle := TAU * i / around
			var flat := Vector2(cos(angle), sin(angle)) * r
			var ridge := ridges.get_noise_2dv(flat) * 0.5 + 0.5
			points.append(Vector3(flat.x, rise * peak * (0.25 + ridge * ridge * 1.3) - 1.0, flat.y))
	var normals := PackedVector3Array()
	normals.resize(points.size())
	var indices := PackedInt32Array()
	for j in rows:
		for i in around:
			var a := j * around + i
			var b := j * around + (i + 1) % around
			var c := (j + 1) * around + i
			var d := (j + 1) * around + (i + 1) % around
			indices.append_array([a, c, b, b, c, d])
	# Smooth normals: accumulate each triangle's face normal on its corners.
	for t in range(0, indices.size(), 3):
		var face := (points[indices[t + 1]] - points[indices[t]]).cross(points[indices[t + 2]] - points[indices[t]])
		for k in 3:
			normals[indices[t + k]] += face
	for k in normals.size():
		normals[k] = normals[k].normalized()
		if normals[k].y < 0.0:
			normals[k] = -normals[k]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rock := PbrLibrary.snowy("rock_face_03", 9.0, Color("c8cbd4"), 0.55, peak * 0.35, peak * 0.9).duplicate()
	rock.set_shader_parameter("detail_maps", false)
	mesh.surface_set_material(0, rock)
	var instance := MeshInstance3D.new()
	instance.name = "MountainRange"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Gently rolling snowy ground, flat around the origin so characters stand level.
## Split into tiles so a lamp only makes the renderer redraw the tiles it reaches.
## `trail` is an optional walked path (x, z points) pressed with boot prints.
static func snow_ground(size := 120.0, resolution := 80, flat_radius := 7.0, seed := 1, tiles := 4,
		trail := PackedVector2Array()) -> Node3D:
	var material := PbrLibrary.snow_ground()
	if not trail.is_empty():
		material = material.duplicate()
		var points := trail.duplicate()
		points.resize(12)
		material.set_shader_parameter("trail", points)
		material.set_shader_parameter("trail_count", mini(trail.size(), 12))
		var lo := trail[0]
		var hi := trail[0]
		for point in trail:
			lo = lo.min(point)
			hi = hi.max(point)
		material.set_shader_parameter("trail_bounds", Vector4(lo.x - 0.4, lo.y - 0.4, hi.x + 0.4, hi.y + 0.4))
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.04
	var step := size / resolution
	var row := resolution + 1
	var points := PackedVector3Array()
	for zi in row:
		for xi in row:
			var x := -size / 2.0 + xi * step
			var z := -size / 2.0 + zi * step
			var lift := smoothstep(flat_radius, flat_radius + 10.0, Vector2(x, z).length())
			points.append(Vector3(x, (noise.get_noise_2d(x, z) * 1.2 + 0.4) * lift + lift * lift * 1.5, z))
	var normals := PackedVector3Array()
	for zi in row:
		for xi in row:
			var l := points[zi * row + maxi(xi - 1, 0)].y
			var r := points[zi * row + mini(xi + 1, resolution)].y
			var d := points[maxi(zi - 1, 0) * row + xi].y
			var u := points[mini(zi + 1, resolution) * row + xi].y
			normals.append(Vector3(l - r, 2.0 * step, d - u).normalized())

	var root := Node3D.new()
	root.name = "SnowGround"
	var cells := resolution / tiles
	for tz in tiles:
		for tx in tiles:
			var verts := PackedVector3Array()
			var tile_normals := PackedVector3Array()
			for zi in range(tz * cells, (tz + 1) * cells + 1):
				for xi in range(tx * cells, (tx + 1) * cells + 1):
					verts.append(points[zi * row + xi])
					tile_normals.append(normals[zi * row + xi])
			var indices := PackedInt32Array()
			var tile_row := cells + 1
			for zi in cells:
				for xi in cells:
					var a := zi * tile_row + xi
					indices.append_array([a, a + 1, a + tile_row, a + 1, a + tile_row + 1, a + tile_row])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = tile_normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var grid := ArrayMesh.new()
			grid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			grid.surface_set_material(0, material)
			var tile := MeshInstance3D.new()
			tile.name = "Tile%d_%d" % [tx, tz]
			tile.mesh = grid
			# The ground only receives shadows; it has nothing to cast them on.
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(tile)
	return root


## Santa's toy sack: soft red velvet, bulging and lumpy, gathered at the neck
## with a gold cord, a few presents peeking out of the open top. The cloth is
## in a child named "Body" so it can swell as more presents go in.
static func toy_sack(seed := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "ToySack"
	var b := ToyBuilder.new()
	var velvet := Color("8e1b1f")
	var body := ToyBuilder.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.26, 0.03), Vector2(0.36, 0.16), Vector2(0.38, 0.34),
		Vector2(0.33, 0.5), Vector2(0.21, 0.62), Vector2(0.14, 0.68), Vector2(0.15, 0.72),
		Vector2(0.22, 0.8), Vector2(0.25, 0.83),
	]), 28)
	b.finished(ToyBuilder.lumpy(body, 0.035, 5.0, seed), velvet, "velvet")
	# Dark inside of the open mouth
	b.add(ToyBuilder.cylinder(0.2, 0.2, 0.01, 20), Color("2a0b0c"), ToyBuilder.xf(Vector3(0, 0.77, 0)))
	# Gold cord round the neck, its ends hanging down with tassels
	var cord := Color("c9a14a")
	b.finished(ToyBuilder.torus(0.15, 0.016, 24, 6), cord, "velvet", ToyBuilder.xf(Vector3(0, 0.69, 0), Vector3(4, 0, 0)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.05 * side, 0.68, 0.15), Vector3(0.09 * side, 0.6, 0.24), Vector3(0.1 * side, 0.48, 0.3),
		]), PackedFloat32Array([0.014, 0.013, 0.012]), 6, 4), cord, "velvet")
		b.finished(ToyBuilder.cylinder(0.006, 0.026, 0.07, 10), cord, "velvet", ToyBuilder.xf(Vector3(0.1 * side, 0.44, 0.31)))
	var sack := b.build(0.0, "Body")
	root.add_child(sack)
	# A couple of presents poking out of the top
	var peek := present(Vector3(0.2, 0.18, 0.2), Color("1e6b3c"), GOLD, GiftBox.Pattern.DOTS, seed + 3)
	peek.position = Vector3(-0.05, 0.7, 0.02)
	peek.rotation_degrees = Vector3(14, 25, -10)
	var peek2 := present(Vector3(0.16, 0.22, 0.16), Color("2e86de"), Color("f4efe6"), GiftBox.Pattern.STRIPES, seed + 4)
	peek2.position = Vector3(0.07, 0.68, -0.05)
	peek2.rotation_degrees = Vector3(-12, -30, 16)
	sack.add_child(GiftBox.merge([peek, peek2] as Array[Node3D]))
	return root


## A round of log stood on end, ready to split, and the two halves it splits
## into (hidden until split). Returns [whole, left_half, right_half].
static func log_round(radius := 0.14, height := 0.32) -> Array[Node3D]:
	var whole := ToyBuilder.new()
	whole.textured(ToyBuilder.cylinder(radius, radius * 1.04, height, 14), "bark_brown_02",
			ToyBuilder.xf(Vector3(0, height / 2.0, 0)), 0.5, Color.WHITE, 0.35)
	var top := MeshPieces.new()
	top.disc(Vector3(0, height + 0.002, 0), Vector3.UP, Vector3.FORWARD, radius, Color(0.37, 0, 0))
	var whole_mesh := whole.build(0.0, "LogRound")
	top.add_to(whole_mesh.mesh, end_grain_material())
	var parts: Array[Node3D] = [whole_mesh]
	for side: float in [-1.0, 1.0]:
		var half := ToyBuilder.new()
		half.textured(ToyBuilder.cylinder(radius, radius * 1.04, height, 14), "bark_brown_02",
				ToyBuilder.xf(Vector3(side * radius * 0.5, height / 2.0, 0), Vector3.ZERO, Vector3(0.5, 1, 1)), 0.5)
		# The fresh pale face of the split
		half.textured(ToyBuilder.box(Vector3(0.012, height, radius * 1.95)), "wood_trunk_wall",
				ToyBuilder.xf(Vector3(side * 0.006, height / 2.0, 0)), 0.3, Color("f0d8b0"))
		var node := half.build(0.0, "LogHalf")
		node.visible = false
		parts.append(node)
	return parts


## Small ground details, added straight into a shared builder so a whole
## field of them costs only a handful of draw calls.

## A stone half-buried in snow, with a cap of snow on top.
static func add_buried_rock(b: ToyBuilder, at: Transform3D, seed := 1) -> void:
	b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.3, 1.6, seed % 4), "rock_face_03",
			at * ToyBuilder.xf(Vector3(0, 0.02, 0), Vector3(0, seed * 47, 8), Vector3(0.22, 0.12, 0.17)), 0.6, Color("b4b2ad"), 0.6)
	b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 8), 0.3, 2.0, seed % 4 + 9), "snow_02",
			at * ToyBuilder.xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.3, 0.06, 0.25)), 1.5, SNOW_TINT)


## A tuft of dry winter grass poking up through the snow.
static func add_dry_grass(b: ToyBuilder, at: Transform3D, seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in 9:
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(8.0, 30.0)
		var h := rng.randf_range(0.12, 0.3)
		var straw := Color("a08a5c").lerp(Color("6b5a3e"), rng.randf())
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.04)
		var rot := Vector3(sin(a) * tilt, 0, -cos(a) * tilt)
		b.add(ToyBuilder.cylinder(0.0, 0.006, h, 3), straw,
				at * Transform3D(Basis.from_euler(rot * PI / 180.0), base) * ToyBuilder.xf(Vector3(0, h / 2.0, 0)))
	b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 6), 0.3, 2.0, 3), "snow_02",
			at * ToyBuilder.xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.09, 0.03, 0.08)), 1.5, SNOW_TINT)


## A fallen twig with a side shoot, half sunk in the snow.
static func add_fallen_twig(b: ToyBuilder, at: Transform3D, seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var length := rng.randf_range(0.35, 0.6)
	var bend := rng.randf_range(-0.06, 0.06)
	b.textured(ToyBuilder.curve(PackedVector3Array([
		Vector3(-length / 2.0, 0.0, 0), Vector3(0, 0.015, bend), Vector3(length / 2.0, 0.005, 0),
	]), PackedFloat32Array([0.012, 0.009, 0.004]), 5, 3), "bark_brown_02", at, 0.3)
	b.textured(ToyBuilder.curve(PackedVector3Array([
		Vector3(0.02, 0.012, bend), Vector3(0.08, 0.02, bend + 0.06), Vector3(0.13, 0.015, bend + 0.09),
	]), PackedFloat32Array([0.006, 0.004, 0.002]), 4, 3), "bark_brown_02", at, 0.3)


## A pine cone lying in the snow, scales spiralling round a core.
static func add_pine_cone(b: ToyBuilder, at: Transform3D, tint := Color.WHITE) -> void:
	b.textured(ToyBuilder.sphere(1.0, 6), "bark_brown_02",
			at * ToyBuilder.xf(Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(0.026, 0.026, 0.048)), 0.3, tint)
	for k in 8:
		var a := k * 2.4
		var z := lerpf(-0.036, 0.036, k / 7.0)
		var r := 0.026 * sqrt(1.0 - pow(z / 0.05, 2.0))
		b.textured(ToyBuilder.box(Vector3(0.016, 0.004, 0.014)), "bark_brown_02",
				at * ToyBuilder.xf(Vector3(cos(a) * r, 0.02 + sin(a) * r, z), Vector3(0, 0, rad_to_deg(a) + 90)), 0.3, tint)


## A fir wreath hung on a door, facing +z at `at` (about 0.55 m across):
## fir sprigs (needle cards, added to `sprigs`) wired round a dark core, pine
## cones, holly with glossy berries, and a velvet bow on a hanging ribbon.
static func add_wreath(b: ToyBuilder, sprigs: _Foliage, at: Transform3D, seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var ring := 0.2
	b.add(ToyBuilder.lumpy(ToyBuilder.torus(ring, 0.04, 24, 8), 0.012, 14.0, seed), Color("16281c"),
			at * ToyBuilder.xf(Vector3(0, 0, -0.035), Vector3(90, 0, 0)))
	# Sprigs in rings (inner, outer, then a top layer), all lying round the
	# wreath the same way, as they are wired onto a frame.
	for layer: Array in [[0.16, 0.0, 13], [0.25, -0.01, 16], [0.2, 0.02, 15], [0.185, 0.045, 13], [0.225, 0.06, 11]]:
		var r: float = layer[0]
		for k in int(layer[2]):
			var a := TAU * (k + rng.randf() * 0.5) / float(layer[2]) + r * 9.0
			var length := rng.randf_range(0.13, 0.17)
			var flare := rng.randf_range(-0.02, 0.025)
			var points := PackedVector3Array()
			for i in 4:
				var f := i / 3.0
				var turn := a + f * length / r
				points.append(at * (Vector3(cos(turn), sin(turn), 0) * (r + flare * f) + Vector3(0, 0, float(layer[1]) + f * 0.02)))
			var mid := a + 0.5 * length / r
			var radial := at.basis * Vector3(cos(mid), sin(mid), 0)
			var face := at.basis * Vector3.BACK
			var normal := (face * 0.8 + radial * 0.45).normalized()
			var width := length * 0.75
			sprigs._card(points, radial * width * 0.5, normal, radial)
			sprigs._card(points, face * width * 0.32, normal, Vector3.ZERO)
	# Pine cones lying on the face of the wreath.
	for deg: float in [25.0, 155.0, 205.0]:
		var a := deg_to_rad(deg)
		var pos := Vector3(cos(a), sin(a), 0) * ring + Vector3(0, 0, 0.085)
		var lie := Basis(Vector3.BACK, a + rng.randf_range(-0.4, 0.4)) * Basis(Vector3.UP, PI / 2.0)
		add_pine_cone(b, at * Transform3D(lie.scaled(Vector3.ONE * 1.1), pos), Color("8a6448"))
	# Holly: two dark glossy leaves under a cluster of berries.
	for deg: float in [72.0, 112.0, 330.0, 240.0]:
		var a := deg_to_rad(deg)
		var pos := Vector3(cos(a), sin(a), 0) * ring + Vector3(0, 0, 0.085)
		for side: float in [-1.0, 1.0]:
			b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 10), 0.12, 6.0, seed), Color("2e6b3b"), "leather",
					at * ToyBuilder.xf(pos + Vector3(side * 0.032, -0.01, -0.006), Vector3(-15, side * 20, rad_to_deg(a) + side * 50),
					Vector3(0.05, 0.02, 0.004)))
		for n in 5:
			var off := Vector3(rng.randf_range(-0.017, 0.017), rng.randf_range(-0.014, 0.014), rng.randf_range(0.0, 0.01))
			b.finished(ToyBuilder.sphere(rng.randf_range(0.011, 0.014), 10), BERRY.darkened(rng.randf_range(0.0, 0.2)), "hair",
					at * ToyBuilder.xf(pos + off + Vector3(0, 0, 0.012)))
	# Velvet bow at the bottom: two loops, a knot and forked tails.
	var velvet := Color("a8101c")
	var bow := Vector3(0, -ring - 0.01, 0.09)
	# A loop is a wide, soft band of ribbon folded round on itself.
	var loop := ToyBuilder.lathe(PackedVector2Array([Vector2(0.036, -0.021), Vector2(0.043, -0.023),
			Vector2(0.047, 0.0), Vector2(0.043, 0.023), Vector2(0.036, 0.021), Vector2(0.034, 0.0), Vector2(0.036, -0.021)]), 20)
	for side: float in [-1.0, 1.0]:
		b.finished(loop, velvet, "velvet",
				at * ToyBuilder.xf(bow + Vector3(side * 0.058, 0.014, -0.006), Vector3(90, 0, side * -14), Vector3(1.45, 1, 0.9)))
		var tail_top := bow + Vector3(side * 0.012, -0.015, -0.004)
		var tail := Basis(Vector3.BACK, deg_to_rad(side * 16.0))
		b.finished(ToyBuilder.box(Vector3(0.042, 0.12, 0.006)), velvet.darkened(0.08), "velvet",
				at * Transform3D(tail, tail_top + tail * Vector3(0, -0.065, 0)))
		var tip := tail_top + tail * Vector3(0, -0.12, 0)
		for fork: float in [-1.0, 1.0]:
			var cut := tail * Basis(Vector3.BACK, deg_to_rad(fork * 18.0))
			b.finished(ToyBuilder.box(Vector3(0.021, 0.035, 0.006)), velvet.darkened(0.08), "velvet",
					at * Transform3D(cut, tip + tail * Vector3(fork * 0.0105, -0.012, 0) + cut * Vector3(0, -0.012, 0)))
	b.finished(ToyBuilder.sphere(0.024, 10), velvet.darkened(0.15), "velvet",
			at * ToyBuilder.xf(bow + Vector3(0, 0.008, 0.014), Vector3.ZERO, Vector3(1.1, 1.0, 0.8)))
	# It hangs from a brass nail on a ribbon behind the top.
	b.finished(ToyBuilder.box(Vector3(0.028, 0.2, 0.004)), velvet.darkened(0.2), "velvet",
			at * ToyBuilder.xf(Vector3(0, ring + 0.08, -0.02)))
	b.finished(ToyBuilder.sphere(0.011, 8), GOLD.darkened(0.25), "metal",
			at * ToyBuilder.xf(Vector3(0, ring + 0.17, -0.012), Vector3.ZERO, Vector3(1, 1, 0.5)))


## Needle material for wreaths and garlands: still, with a little snow, and
## none of the trees' painted crown shading.
static func wreath_material() -> ShaderMaterial:
	if not _cache.has("wreath"):
		var mat: ShaderMaterial = foliage_material(0.3).duplicate()
		mat.set_shader_parameter("wind", 0.0)
		mat.set_shader_parameter("self_shadow", 0.0)
		_cache["wreath"] = mat
	return _cache["wreath"]


## A soft mound of snow heaped round the foot of a tree.
static func add_snow_mound(b: ToyBuilder, at: Transform3D, seed := 1) -> void:
	b.textured(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 12), 0.18, 1.8, seed % 3), "snow_02",
			at * ToyBuilder.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.25, 1.0)), 1.5, SNOW_TINT)


## Draws many copies of one mesh in a single batch (forests, rocks, fence posts).
static func scatter(mesh: Mesh, transforms: Array[Transform3D], shadows := true) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	# Kept so Baked can save the scatter (headless, the renderer forgets them).
	instance.set_meta("transforms", transforms)
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
