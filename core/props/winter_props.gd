class_name WinterProps
## Builders for detailed winter props, shared by the North Pole, Alpine and
## Icelandic levels. Each returns a Node3D ready to place in a scene.

const SNOW := Color("dfe7f2")
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


## A snow-laden pine. `decorated` adds baubles, fairy lights, a star and a glow.
static func pine_tree(height: float, seed := 1, decorated := false) -> Node3D:
	var root := Node3D.new()
	root.name = "PineTree"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := ToyBuilder.new()
	var trunk_h := height * 0.12
	b.part(ToyBuilder.cylinder(height * 0.035, height * 0.05, trunk_h, 8), BARK, Vector3(0, trunk_h / 2.0, 0))

	var tiers := 4
	var tier_tops := []
	for i in tiers:
		var base := trunk_h + i * height * 0.2
		var h := height * 0.36 * (1.0 - i * 0.07)
		var r := height * 0.3 * (1.0 - i * 0.2)
		var twist := Vector3(0, rng.randf_range(0, 360), 0)
		# Tier with a drooping skirt and a cap of snow on its shoulders
		var tier := ToyBuilder.lathe(PackedVector2Array([
			Vector2(0, h * 0.12), Vector2(r, 0), Vector2(r * 0.78, h * 0.12),
			Vector2(r * 0.42, h * 0.55), Vector2(0, h),
		]), 10)
		b.add(tier, PINE, ToyBuilder.xf(Vector3(0, base, 0), twist))
		var cap := ToyBuilder.lathe(PackedVector2Array([
			Vector2(0, h * 0.5), Vector2(r * 0.5, h * 0.5), Vector2(r * 0.44, h * 0.6),
			Vector2(r * 0.2, h * 0.86), Vector2(0, h * 1.02),
		]), 10)
		b.add(cap, SNOW, ToyBuilder.xf(Vector3(0, base, 0), twist))
		b.fluff_ring(Vector3(0, base + h * 0.04, 0), r * 0.92, r * 0.07, SNOW, 10, Vector3.ZERO, seed + i)
		tier_tops.append([base, h, r])

	if decorated:
		# Baubles hanging on each tier's edge
		for t in tier_tops:
			var count := int(t[2] * 9.0)
			for k in count:
				var angle := TAU * k / count + rng.randf_range(-0.2, 0.2)
				var pos := Vector3(cos(angle) * t[2] * 0.8, t[0] + t[1] * 0.08, sin(angle) * t[2] * 0.8)
				b.part(ToyBuilder.sphere(height * 0.022, 12), BAUBLES[rng.randi() % BAUBLES.size()], pos)
		# Fairy lights spiralling up the tree
		var turns := 4.0
		var steps := 46
		for k in steps:
			var t := float(k) / steps
			var y := trunk_h + t * height * 0.78
			var radius := height * 0.29 * (1.0 - t) + 0.05
			var angle := t * TAU * turns
			b.part(ToyBuilder.sphere(height * 0.012, 8), FAIRY[k % FAIRY.size()],
					Vector3(cos(angle) * radius, y, sin(angle) * radius), Vector3.ZERO, Vector3.ONE, true)
		# Star topper
		b.part(ToyBuilder.star(5, height * 0.08, height * 0.035, height * 0.025), Color("ffd84a"),
				Vector3(0, trunk_h + height * 0.93, 0), Vector3.ZERO, Vector3.ONE, true)
		var light := OmniLight3D.new()
		light.light_color = Color("ffc875")
		light.light_energy = 1.3
		light.omni_range = height * 1.6
		light.position = Vector3(0, height * 0.55, height * 0.4)
		root.add_child(light)

	root.add_child(b.build(0.012 * height / 3.0, "Mesh"))
	return root


## A classic snowman with coal face, carrot nose, scarf and top hat.
static func snowman(seed := 1) -> Node3D:
	var b := ToyBuilder.new()
	b.part(ToyBuilder.sphere(0.55, 22), SNOW, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 0.92, 1))
	b.part(ToyBuilder.sphere(0.4, 20), SNOW, Vector3(0, 1.18, 0))
	b.part(ToyBuilder.sphere(0.29, 20), SNOW, Vector3(0, 1.72, 0))
	b.fluff_ring(Vector3(0, 0.06, 0), 0.5, 0.12, SNOW, 12, Vector3.ZERO, seed)
	for side in [-1.0, 1.0]:
		b.part(ToyBuilder.sphere(0.035), COAL, Vector3(0.1 * side, 1.79, 0.25))
		# Twig arms with little fingers
		var arm := PackedVector3Array([
			Vector3(0.35 * side, 1.25, 0), Vector3(0.65 * side, 1.4, 0.05), Vector3(0.9 * side, 1.62, 0.02),
		])
		b.add(ToyBuilder.curve(arm, PackedFloat32Array([0.03, 0.025, 0.015]), 6), BARK)
		b.add(ToyBuilder.curve(PackedVector3Array([
			Vector3(0.8 * side, 1.52, 0.03), Vector3(0.9 * side, 1.5, 0.08), Vector3(0.98 * side, 1.52, 0.1),
		]), PackedFloat32Array([0.014, 0.01, 0.006]), 5), BARK)
	for k in 5:
		var a := lerpf(-0.5, 0.5, k / 4.0)
		b.part(ToyBuilder.sphere(0.022), COAL, Vector3(sin(a) * 0.13, 1.62 - cos(a * 1.2) * 0.04 + 0.03, 0.26))
	for k in 3:
		b.part(ToyBuilder.sphere(0.04), COAL, Vector3(0, 1.0 + k * 0.15, 0.39 - abs(k - 1) * 0.02))
	b.part(ToyBuilder.cylinder(0.0, 0.05, 0.3, 10), CARROT, Vector3(0, 1.72, 0.4), Vector3(90, 0, 0))
	# Scarf
	b.part(ToyBuilder.torus(0.25, 0.065, 20, 8), BERRY, Vector3(0, 1.47, 0))
	b.add(ToyBuilder.curve(PackedVector3Array([
		Vector3(0.15, 1.45, 0.2), Vector3(0.22, 1.25, 0.32), Vector3(0.2, 1.05, 0.38),
	]), PackedFloat32Array([0.06, 0.055, 0.05]), 8), BERRY)
	# Top hat
	b.part(ToyBuilder.cylinder(0.3, 0.3, 0.04, 20), COAL, Vector3(0, 1.97, 0), Vector3(0, 0, -6))
	b.part(ToyBuilder.cylinder(0.19, 0.18, 0.32, 20), COAL, Vector3(0.015, 2.14, 0), Vector3(0, 0, -6))
	b.part(ToyBuilder.cylinder(0.185, 0.185, 0.06, 20), BERRY, Vector3(0.01, 2.03, 0), Vector3(0, 0, -6))
	b.part(ToyBuilder.sphere(0.05), Color("2e8b57"), Vector3(0.12, 2.06, 0.14))
	var root := Node3D.new()
	root.name = "Snowman"
	root.add_child(b.build(0.012, "Mesh"))
	return root


## A log cabin with snowy roof, glowing windows, wreath, fairy lights and smoking chimney.
static func log_cabin(seed := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "LogCabin"
	var b := ToyBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var log_r := 0.14
	var rows := 7

	b.part(ToyBuilder.box(Vector3(4.4, 0.3, 3.4)), STONE, Vector3(0, 0.15, 0))
	for k in rows:
		var y := 0.42 + k * log_r * 1.9
		var tint := LOG if k % 2 == 0 else LOG_DARK
		for z in [-1.5, 1.5]:
			b.part(ToyBuilder.cylinder(log_r, log_r, 4.5, 10), tint, Vector3(0, y, z), Vector3(0, 0, 90))
		for x in [-2.0, 2.0]:
			b.part(ToyBuilder.cylinder(log_r, log_r, 3.5, 10), tint.darkened(0.06), Vector3(x, y + log_r * 0.95, 0), Vector3(90, 0, 0))
	# Gables
	var wall_top := 0.42 + rows * log_r * 1.9
	for k in 5:
		var length := 4.0 * (1.0 - (k + 1) / 6.0)
		for z in [-1.5, 1.5]:
			b.part(ToyBuilder.cylinder(log_r, log_r, length, 10), LOG, Vector3(0, wall_top + k * log_r * 1.8, z), Vector3(0, 0, 90))

	# Roof slabs with thick snow
	var ridge := wall_top + 1.25
	var eave := wall_top - 0.1
	var half := 1.95
	var angle := rad_to_deg(atan2(ridge - eave, half))
	var slope_len := sqrt(half * half + (ridge - eave) * (ridge - eave)) + 0.35
	for side in [-1.0, 1.0]:
		var centre := Vector3(0, (ridge + eave) / 2.0, half / 2.0 * side)
		var rot := Vector3(angle * side, 0, 0)
		var normal := Basis.from_euler(rot * PI / 180.0) * Vector3.UP
		b.part(ToyBuilder.box(Vector3(5.0, 0.16, slope_len)), Color("5a3a2a"), centre, rot)
		b.part(ToyBuilder.box(Vector3(5.05, 0.16, slope_len - 0.05)), SNOW, centre + normal * 0.15, rot)
		var eave_pos := Vector3(0, eave - 0.18, (half + 0.25) * side) + normal * 0.15
		for k in 22:
			var x := lerpf(-2.45, 2.45, k / 21.0)
			b.part(ToyBuilder.sphere(1.0, 8), SNOW, eave_pos + Vector3(x, 0, 0), Vector3.ZERO, Vector3.ONE * rng.randf_range(0.1, 0.15))
			if k % 2 == 0:
				var icicle := rng.randf_range(0.15, 0.4)
				b.part(ToyBuilder.cylinder(0.035, 0.0, icicle, 6), ICE, eave_pos + Vector3(x, -icicle / 2.0 - 0.05, 0), Vector3(180, 0, 0))
		# Fairy lights along the eaves
		if side > 0.0:
			for k in 18:
				var x := lerpf(-2.3, 2.3, k / 17.0)
				var sag := sin(k * PI / 2.0) * 0.04
				b.part(ToyBuilder.sphere(0.04, 8), FAIRY[k % FAIRY.size()], eave_pos + Vector3(x, -0.12 - abs(sag), 0.05),
						Vector3.ZERO, Vector3.ONE, true)

	# Chimney with snow cap and smoke
	var chimney := Vector3(1.2, ridge - 0.1, -0.6)
	b.part(ToyBuilder.box(Vector3(0.55, 1.6, 0.55)), STONE, chimney)
	b.part(ToyBuilder.box(Vector3(0.65, 0.12, 0.65)), STONE.darkened(0.15), chimney + Vector3(0, 0.8, 0))
	b.fluff_blob(chimney + Vector3(0, 0.88, 0), Vector3(0.25, 0.04, 0.25), 0.08, SNOW, 8, seed + 3)
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 4.0
	smoke.preprocess = 4.0
	smoke.position = chimney + Vector3(0, 0.95, 0)
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
	var puff := ToyBuilder.sphere(1.0, 8)
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.75, 0.78, 0.85, 0.55)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = puff_mat
	smoke.mesh = puff
	root.add_child(smoke)

	# Front door with wreath
	var front := 1.5 + log_r
	b.part(ToyBuilder.box(Vector3(0.95, 1.55, 0.08)), LOG_DARK.darkened(0.2), Vector3(0, 1.07, front + 0.02))
	b.part(ToyBuilder.box(Vector3(0.8, 1.42, 0.08)), Color("7a4524"), Vector3(0, 1.03, front + 0.06))
	for k in 3:
		b.part(ToyBuilder.box(Vector3(0.74, 0.03, 0.03)), LOG_DARK, Vector3(0, 0.55 + k * 0.45, front + 0.11))
	b.part(ToyBuilder.sphere(0.04), GOLD, Vector3(0.28, 0.95, front + 0.12))
	var wreath := Vector3(0, 1.42, front + 0.13)
	b.part(ToyBuilder.torus(0.2, 0.07, 20, 8), PINE, wreath, Vector3(90, 0, 0))
	for k in 8:
		var a := TAU * k / 8.0
		b.part(ToyBuilder.sphere(0.03), BERRY, wreath + Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.06))
	b.part(ToyBuilder.torus(0.06, 0.025, 12, 6), BERRY, wreath + Vector3(-0.07, -0.2, 0.07), Vector3(90, 0, 30))
	b.part(ToyBuilder.torus(0.06, 0.025, 12, 6), BERRY, wreath + Vector3(0.07, -0.2, 0.07), Vector3(90, 0, -30))

	# Glowing windows with frames, crossbars and snowy sills
	for x in [-1.25, 1.25]:
		var w := Vector3(x, 1.25, front + 0.02)
		b.part(ToyBuilder.box(Vector3(0.78, 0.68, 0.06)), LOG_DARK.darkened(0.3), w)
		b.part(ToyBuilder.box(Vector3(0.64, 0.54, 0.05)), WARM_LIGHT, w + Vector3(0, 0, 0.02), Vector3.ZERO, Vector3.ONE, true)
		b.part(ToyBuilder.box(Vector3(0.05, 0.56, 0.05)), LOG_DARK, w + Vector3(0, 0, 0.05))
		b.part(ToyBuilder.box(Vector3(0.66, 0.05, 0.05)), LOG_DARK, w + Vector3(0, 0, 0.05))
		b.part(ToyBuilder.box(Vector3(0.9, 0.07, 0.2)), LOG_DARK, w + Vector3(0, -0.38, 0.08))
		b.fluff_blob(w + Vector3(0, -0.32, 0.1), Vector3(0.38, 0.02, 0.06), 0.06, SNOW, 9, seed + int(x * 10))
		var glow := OmniLight3D.new()
		glow.light_color = WARM_LIGHT
		glow.light_energy = 1.4
		glow.omni_range = 4.5
		glow.position = w + Vector3(0, 0, 0.6)
		root.add_child(glow)

	# Snow drifts against the walls
	for k in 6:
		b.fluff_blob(Vector3(rng.randf_range(-2.2, 2.2), 0.1, front + 0.25), Vector3(0.4, 0.12, 0.2), 0.18, SNOW, 6, seed + 40 + k)

	root.add_child(b.build(0.014, "Mesh"))
	return root


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
		b.part(ToyBuilder.box(Vector3(0.1, 0.9, 0.08)), LOG, Vector3(x, 0.45, 0))
		b.part(ToyBuilder.cylinder(0.0, 0.07, 0.1, 4), LOG, Vector3(x, 0.95, 0), Vector3(0, 45, 0))
		b.part(ToyBuilder.sphere(1.0, 8), SNOW, Vector3(x, 0.96, 0), Vector3.ZERO, Vector3(0.07, 0.05, 0.07))
	for y in [0.3, 0.7]:
		b.part(ToyBuilder.box(Vector3(length + 0.1, 0.08, 0.05)), LOG_DARK, Vector3(0, y, -0.06))
		b.part(ToyBuilder.box(Vector3(length + 0.1, 0.04, 0.07)), SNOW, Vector3(0, y + 0.06, -0.06))
	var root := Node3D.new()
	root.name = "Fence"
	root.add_child(b.build(0.01, "Mesh"))
	return root


## A distant snow-capped mountain.
static func mountain(height: float, seed := 1) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := height * rng.randf_range(0.9, 1.3)
	var b := ToyBuilder.new()
	b.add(ToyBuilder.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(r, 0), Vector2(r * 0.6, height * 0.35), Vector2(r * 0.3, height * 0.75), Vector2(0, height),
	]), 7), Color("4b5878"))
	b.add(ToyBuilder.lathe(PackedVector2Array([
		Vector2(0, height * 0.55), Vector2(r * 0.42, height * 0.55), Vector2(r * 0.33, height * 0.72), Vector2(0, height * 1.01),
	]), 7), SNOW)
	var root := Node3D.new()
	root.name = "Mountain"
	root.add_child(b.build(0.0, "Mesh"))
	return root


## Gently rolling snowy ground, flat around the origin so characters stand level.
static func snow_ground(size := 120.0, resolution := 80, flat_radius := 7.0, seed := 1) -> Node3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.04
	var step := size / resolution
	var verts := PackedVector3Array()
	var heights := PackedFloat32Array()
	for zi in resolution + 1:
		for xi in resolution + 1:
			var x := -size / 2.0 + xi * step
			var z := -size / 2.0 + zi * step
			var dist := Vector2(x, z).length()
			var lift := smoothstep(flat_radius, flat_radius + 10.0, dist)
			var h := (noise.get_noise_2d(x, z) * 1.2 + 0.4) * lift + lift * lift * 1.5
			heights.append(h)
			verts.append(Vector3(x, h, z))
	var normals := PackedVector3Array()
	var row := resolution + 1
	for zi in row:
		for xi in row:
			var l := heights[zi * row + maxi(xi - 1, 0)]
			var r := heights[zi * row + mini(xi + 1, resolution)]
			var d := heights[maxi(zi - 1, 0) * row + xi]
			var u := heights[mini(zi + 1, resolution) * row + xi]
			normals.append(Vector3(l - r, 2.0 * step, d - u).normalized())
	var indices := PackedInt32Array()
	for zi in resolution:
		for xi in resolution:
			var a := zi * row + xi
			indices.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var grid := ArrayMesh.new()
	grid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var b := ToyBuilder.new()
	b.add(grid, SNOW)
	var root := Node3D.new()
	root.name = "SnowGround"
	root.add_child(b.build(0.0, "Mesh"))
	return root
