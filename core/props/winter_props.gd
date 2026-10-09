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
	if decorated:
		b.textured(ToyBuilder.cylinder(trunk_r * 0.25, trunk_r, height * 0.95, 8), "bark_brown_02",
				ToyBuilder.xf(Vector3(0, height * 0.475, 0)), 0.8)
		# Up close, a slim dark core hides the gaps deep inside the crown.
		var core := ToyBuilder.lathe(PackedVector2Array([
			Vector2(0, crown_base), Vector2(height * 0.08, crown_base + height * 0.04),
			Vector2(height * 0.05, height * 0.5), Vector2(height * 0.015, height * 0.85), Vector2(0, height * 0.92),
		]), 8)
		b.add(core, Color("2a4632"))
	else:
		# From a distance a solid core shows through as a dark cone, so the
		# trunk tapers away and the crown is filled with extra shoots instead.
		b.textured(ToyBuilder.cylinder(trunk_r * 0.1, trunk_r, height * 0.6, 6), "bark_brown_02",
				ToyBuilder.xf(Vector3(0, height * 0.3, 0)), 0.8)

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
			if (detail >= 0.75 or not decorated) and k % 2 == 0:
				foliage.branch(Vector3(0, y + height * 0.025, 0), angle + PI / count, droop * 0.6, length * 0.6, false)
	# Leader shoot at the very top
	foliage.branch(Vector3(0, height * 0.9, 0), 0.0, -PI / 2.0 + 0.05, height * 0.12, true)

	if decorated:
		for i in range(0, tips.size(), 2):
			b.part(ToyBuilder.sphere(height * 0.02, 12), BAUBLES[rng.randi() % BAUBLES.size()], tips[i] + Vector3(0, -height * 0.025, 0))
		var turns := 4.5
		var steps := 60
		for k in steps:
			var t := float(k) / steps
			var y := crown_base + t * height * 0.8
			var radius := lerpf(height * 0.3, height * 0.05, t)
			var angle := t * TAU * turns
			b.part(ToyBuilder.sphere(height * 0.009, 8), FAIRY[k % FAIRY.size()],
					Vector3(cos(angle) * radius, y, sin(angle) * radius), Vector3.ZERO, Vector3.ONE, true)
		b.part(ToyBuilder.star(5, height * 0.07, height * 0.03, height * 0.022), Color("ffd84a"),
				Vector3(0, height * 1.0, 0), Vector3.ZERO, Vector3.ONE, true)
		var light := OmniLight3D.new()
		light.light_color = Color("ffc875")
		light.light_energy = 1.3
		light.omni_range = height * 1.6
		light.light_cull_mask = ~SELF_LIT_LAYER
		light.position = Vector3(0, height * 0.55, height * 0.4)
		root.add_child(light)

	var mesh_instance := b.build(0.0, "Mesh")
	var mesh: ArrayMesh = mesh_instance.mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, foliage.arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, foliage_material(snow * (0.6 if decorated else 1.0)))
	if decorated:
		mesh_instance.layers = SELF_LIT_LAYER
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
	b.add(knit, BERRY.darkened(0.15), ToyBuilder.xf(Vector3(0, 1.46, 0)))
	b.add(ToyBuilder.lumpy(ToyBuilder.curve(PackedVector3Array([
		Vector3(0.15, 1.44, 0.2), Vector3(0.23, 1.25, 0.32), Vector3(0.21, 1.03, 0.38),
	]), PackedFloat32Array([0.055, 0.05, 0.045]), 10), 0.01, 22.0, seed + 2), BERRY.darkened(0.15))
	# Battered top hat
	var felt := Color("1d1b1c")
	b.part(ToyBuilder.cylinder(0.3, 0.3, 0.03, 28), felt, Vector3(0, 1.96, 0), Vector3(0, 0, -6))
	b.part(ToyBuilder.cylinder(0.19, 0.18, 0.32, 28), felt, Vector3(0.015, 2.13, 0), Vector3(0, 0, -6))
	b.part(ToyBuilder.cylinder(0.185, 0.185, 0.06, 28), BERRY.darkened(0.3), Vector3(0.01, 2.02, 0), Vector3(0, 0, -6))
	b.textured(ToyBuilder.snow_sheet(Vector2(0.3, 0.3), 0.05, seed + 7, 0.04), "snow_02",
			ToyBuilder.xf(Vector3(0.03, 2.29, 0), Vector3(0, 0, -6)), 1.5, SNOW_TINT)
	var root := Node3D.new()
	root.name = "Snowman"
	root.add_child(b.build(0.0, "Mesh"))
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

	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 28
	flames.lifetime = 0.8
	flames.position = Vector3(0, 0.2, 0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.12
	flames.direction = Vector3.UP
	flames.spread = 8
	flames.initial_velocity_min = 0.5
	flames.initial_velocity_max = 0.9
	flames.gravity = Vector3(0, 0.6, 0)
	flames.scale_amount_min = 0.25
	flames.scale_amount_max = 0.4
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
	embers.position = Vector3(0, 0.35, 0)
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
	light.omni_range = 6.0
	light.position = Vector3(0, 0.6, 0)
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

	b.textured(ToyBuilder.box(Vector3(4.4, 0.3, 3.4)), "old_stone_wall", ToyBuilder.xf(Vector3(0, 0.15, 0)), 1.2, Color.WHITE, 0.4)
	# Walls: logs cross at the corners and stick out past them, as real notched logs do.
	for k in rows:
		var y := 0.42 + k * log_r * 1.9
		var tint := Color.WHITE if k % 2 == 0 else Color("d8d0c8")
		for z in [-1.5, 1.5]:
			var lean := rng.randf_range(-1.0, 1.0)
			b.textured(ToyBuilder.cylinder(log_r, log_r * 1.05, 4.6, 12), "wood_trunk_wall",
					ToyBuilder.xf(Vector3(rng.randf_range(-0.05, 0.05), y, z), Vector3(lean, 0, 90)), 1.6, tint, log_snow)
		for x in [-2.0, 2.0]:
			b.textured(ToyBuilder.cylinder(log_r * 1.05, log_r, 3.6, 12), "wood_trunk_wall",
					ToyBuilder.xf(Vector3(x, y + log_r * 0.95, rng.randf_range(-0.05, 0.05)), Vector3(90, 0, 0)), 1.6, tint, log_snow)
	var wall_top := 0.42 + rows * log_r * 1.9
	# Gables on the side walls, stepping in under the roof slopes.
	for k in 5:
		var length := 3.0 * (1.0 - (k + 1) / 6.0)
		for x in [-2.0, 2.0]:
			b.textured(ToyBuilder.cylinder(log_r, log_r, length, 12), "wood_trunk_wall",
					ToyBuilder.xf(Vector3(x, wall_top + k * log_r * 1.8, 0), Vector3(90, 0, 0)), 1.6, Color.WHITE, log_snow)

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
		for k in 24:
			if rng.randf() < 0.65:
				var x := lerpf(-2.4, 2.4, k / 23.0)
				var icicle := rng.randf_range(0.12, 0.45)
				b.part(ToyBuilder.cylinder(0.025, 0.0, icicle, 6), ICE, eave_pos + Vector3(x, -icicle / 2.0 - 0.12, 0), Vector3(180, 0, 0))
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
	b.part(ToyBuilder.sphere(0.035), IRON, Vector3(0.28, 0.95, front + 0.13))
	var wreath := Vector3(0, 1.42, front + 0.14)
	b.add(ToyBuilder.lumpy(ToyBuilder.torus(0.2, 0.07, 24, 10), 0.03, 14.0, seed), PINE.darkened(0.3), ToyBuilder.xf(wreath, Vector3(90, 0, 0)))
	for k in 9:
		var a := TAU * k / 9.0 + 0.3
		b.part(ToyBuilder.sphere(0.025), BERRY, wreath + Vector3(cos(a) * 0.21, sin(a) * 0.21, 0.07))
	b.part(ToyBuilder.torus(0.06, 0.022, 12, 6), BERRY, wreath + Vector3(-0.07, -0.2, 0.08), Vector3(90, 0, 30))
	b.part(ToyBuilder.torus(0.06, 0.022, 12, 6), BERRY, wreath + Vector3(0.07, -0.2, 0.08), Vector3(90, 0, -30))
	b.textured(ToyBuilder.box(Vector3(1.3, 0.12, 0.5)), "old_stone_wall", ToyBuilder.xf(Vector3(0, 0.06, front + 0.3)), 0.8, Color.WHITE, 0.5)

	# Windows: timber frames, warm glass with crossbars, and sills that catch snow
	for x in [-1.25, 1.25]:
		var w := Vector3(x, 1.25, front + 0.02)
		b.textured(ToyBuilder.box(Vector3(0.82, 0.72, 0.08)), "wood_trunk_wall", ToyBuilder.xf(w), 0.6, Color("6b5040"))
		b.part(ToyBuilder.box(Vector3(0.64, 0.54, 0.05)), WARM_LIGHT, w + Vector3(0, 0, 0.03), Vector3.ZERO, Vector3.ONE, true)
		b.part(ToyBuilder.box(Vector3(0.04, 0.56, 0.05)), LOG_DARK.darkened(0.3), w + Vector3(0, 0, 0.06))
		b.part(ToyBuilder.box(Vector3(0.66, 0.04, 0.05)), LOG_DARK.darkened(0.3), w + Vector3(0, 0, 0.06))
		b.textured(ToyBuilder.box(Vector3(0.95, 0.07, 0.22)), "brown_planks_04", ToyBuilder.xf(w + Vector3(0, -0.4, 0.09)), 0.6, Color("9a7058"), 0.6)
		b.textured(ToyBuilder.snow_sheet(Vector2(0.9, 0.18), 0.05, seed + int(x * 10), 0.04), "snow_02",
				ToyBuilder.xf(w + Vector3(0, -0.36, 0.09)), 1.5, SNOW_TINT)

	# Firewood stacked against the right-hand wall
	for row_i in 5:
		for k in 7 - row_i % 2:
			var pos := Vector3(2.45, 0.12 + row_i * 0.2, -1.05 + k * 0.3 + (row_i % 2) * 0.15)
			b.textured(ToyBuilder.cylinder(0.1, 0.1, 0.6, 9), "bark_brown_02",
					ToyBuilder.xf(pos + Vector3(rng.randf_range(-0.04, 0.04), 0, 0), Vector3(0, 0, 90)), 0.5, Color.WHITE, 0.45)
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

	root.add_child(b.build(0.0, "Mesh"))

	var lantern := PbrLibrary.model("wooden_lantern_01", 0.0)
	lantern.position = Vector3(0.7, 1.55, front + 0.16)
	lantern.scale = Vector3.ONE * 0.9
	root.add_child(lantern)
	return root


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
	b.part(ToyBuilder.cylinder(0.12, 0.18, 0.25, 12), IRON, Vector3(0, 0.12, 0))
	b.part(ToyBuilder.cylinder(0.05, 0.06, 2.6, 10), IRON, Vector3(0, 1.4, 0))
	b.part(ToyBuilder.sphere(0.08), IRON, Vector3(0, 0.9, 0))
	b.part(ToyBuilder.cylinder(0.12, 0.09, 0.08, 10), IRON, Vector3(0, 2.72, 0))
	var lantern := Vector3(0, 2.98, 0)
	b.part(ToyBuilder.cylinder(0.12, 0.1, 0.36, 6), WARM_LIGHT, lantern, Vector3.ZERO, Vector3.ONE, true)
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		b.part(ToyBuilder.box(Vector3(0.025, 0.4, 0.025)), IRON, lantern + Vector3(cos(a) * 0.12, 0, sin(a) * 0.12))
	b.part(ToyBuilder.cylinder(0.0, 0.2, 0.18, 6), IRON, lantern + Vector3(0, 0.27, 0))
	b.part(ToyBuilder.sphere(0.035), IRON, lantern + Vector3(0, 0.38, 0))
	b.fluff_blob(lantern + Vector3(0, 0.27, 0), Vector3(0.12, 0.03, 0.12), 0.05, SNOW, 6, 9)
	# Holly ribbon around the post
	b.part(ToyBuilder.torus(0.075, 0.03, 14, 6), PINE, Vector3(0, 2.3, 0))
	b.part(ToyBuilder.sphere(0.035), BERRY, Vector3(0, 2.3, 0.1))
	root.add_child(b.build(0.01, "Mesh"))
	var light := OmniLight3D.new()
	light.light_color = WARM_LIGHT
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = lantern
	root.add_child(light)
	return root


## A wrapped present with ribbon and bow.
static func present(size: Vector3, color: Color, ribbon := GOLD) -> Node3D:
	var b := ToyBuilder.new()
	b.part(ToyBuilder.box(size), color, Vector3(0, size.y / 2.0, 0))
	b.part(ToyBuilder.box(Vector3(size.x * 0.18, size.y + 0.01, size.z + 0.01)), ribbon, Vector3(0, size.y / 2.0, 0))
	b.part(ToyBuilder.box(Vector3(size.x + 0.01, size.y + 0.01, size.z * 0.18)), ribbon, Vector3(0, size.y / 2.0, 0))
	var top := Vector3(0, size.y + 0.02, 0)
	var loop := minf(size.x, size.z) * 0.22
	b.part(ToyBuilder.torus(loop, loop * 0.3, 14, 6), ribbon, top + Vector3(-loop * 0.8, loop * 0.5, 0), Vector3(90, 0, 35), Vector3(1, 1, 0.7))
	b.part(ToyBuilder.torus(loop, loop * 0.3, 14, 6), ribbon, top + Vector3(loop * 0.8, loop * 0.5, 0), Vector3(90, 0, -35), Vector3(1, 1, 0.7))
	b.part(ToyBuilder.sphere(loop * 0.45), ribbon, top + Vector3(0, loop * 0.2, 0))
	var root := Node3D.new()
	root.name = "Present"
	root.add_child(b.build(0.01, "Mesh"))
	return root


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
	for k in posts:
		var x := k * 0.5 - length / 2.0
		b.textured(ToyBuilder.box(Vector3(0.1, 0.9, 0.08)), "brown_planks_04", ToyBuilder.xf(Vector3(x, 0.45, 0)), 0.8)
		b.part(ToyBuilder.cylinder(0.0, 0.07, 0.1, 4), LOG, Vector3(x, 0.95, 0), Vector3(0, 45, 0))
		b.part(ToyBuilder.sphere(1.0, 8), SNOW, Vector3(x, 0.96, 0), Vector3.ZERO, Vector3(0.07, 0.05, 0.07))
	for y in [0.3, 0.7]:
		b.textured(ToyBuilder.box(Vector3(length + 0.1, 0.08, 0.05)), "brown_planks_04", ToyBuilder.xf(Vector3(0, y, -0.06)), 0.8, Color("9a7a60"))
		b.textured(ToyBuilder.box(Vector3(length + 0.1, 0.04, 0.07)), "snow_02", ToyBuilder.xf(Vector3(0, y + 0.06, -0.06)), 1.0, SNOW_TINT)
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
static func snow_ground(size := 120.0, resolution := 80, flat_radius := 7.0, seed := 1, tiles := 4) -> Node3D:
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
			grid.surface_set_material(0, PbrLibrary.snow_ground())
			var tile := MeshInstance3D.new()
			tile.name = "Tile%d_%d" % [tx, tz]
			tile.mesh = grid
			root.add_child(tile)
	return root


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
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
