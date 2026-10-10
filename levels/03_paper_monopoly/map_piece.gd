class_name MapPiece
extends Node3D
## One playing piece on Scrooge's map, made like a tabletop wargame model on
## a round wooden base:
## - a factory town: a soot-black brick paper mill with a sawtooth roof and a
##   smoking chimney, workers' terraces, and peg-doll workers who carry
##   placards when they strike. A pennant on a pin shows whose it is.
## - a supplier: a pulp forest, an ink works or a ribbon spool.
## - a mill site: a dashed ring waiting for one of Santa's elf paper mills,
##   a red timber mill with a turning water wheel once built.
## A ring round the base fills as the town warms to Santa.

enum Kind {TOWN, SUPPLIER, MILL}

const SCROOGE_FLAG := Color("1d1b1e")
const SANTA_FLAG := Color("b0202a")
const STRIKE_FLAG := Color("e8e0c8")
const BASE_RADIUS := 0.048
const BRICK := Color("5c3a2e")
const SOOT := Color("2a2624")

var kind := Kind.TOWN
var index := 0
var label: Label3D

var _flag: MeshInstance3D
var _flag_mat: StandardMaterial3D
var _flag_holder: Node3D
var _ring_mat: ShaderMaterial
var _smoke: CPUParticles3D
var _placards: Node3D
var _workers: Node3D
var _mill: Node3D
var _wheel: Node3D
var _site: Node3D
var _highlight: MeshInstance3D
var _goodwill := 0.0
var _shown_goodwill := 0.0
var _time := randf() * 10.0


func _init(piece_kind := Kind.TOWN, piece_index := 0, title := "") -> void:
	kind = piece_kind
	index = piece_index
	name = "%s%d" % [Kind.keys()[kind].capitalize(), piece_index]
	label = Label3D.new()
	label.text = title
	label.font_size = 48
	label.pixel_size = 0.0008
	label.outline_size = 10
	label.modulate = Color("f4ead2")
	label.outline_modulate = Color(0.12, 0.07, 0.04, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.position = Vector3(0, 0.15, 0.0)
	label.render_priority = 2
	add_child(label)


func _ready() -> void:
	_base()
	match kind:
		Kind.TOWN:
			_town()
		Kind.SUPPLIER:
			_supplier()
		Kind.MILL:
			_mill_site()


# --- What it shows ---

## Who owns it: 0 Scrooge, 1 on strike, 2 Santa, 3 nobody (PaperMarket.Owner).
func show_owner(owner: int) -> void:
	if _flag:
		_flag.visible = owner != PaperMarket.Owner.FREE
		_flag_mat.albedo_color = [SCROOGE_FLAG, STRIKE_FLAG, SANTA_FLAG, STRIKE_FLAG][owner]
	if _smoke:
		_smoke.emitting = owner != PaperMarket.Owner.STRIKE
		_smoke.color = Color(0.22, 0.2, 0.2, 0.55) if owner == PaperMarket.Owner.SCROOGE else Color(0.92, 0.92, 0.95, 0.5)
	if _placards:
		_placards.visible = owner == PaperMarket.Owner.STRIKE
	if _workers:
		_workers.visible = true


func show_goodwill(amount: float) -> void:
	_goodwill = amount


func show_mill(built: bool) -> void:
	if _mill:
		_mill.visible = built
		_site.visible = not built


func set_highlight(on: bool) -> void:
	if _highlight:
		_highlight.visible = on


## A little hop and a puff, when something happens here.
func bounce() -> void:
	var t := create_tween()
	t.tween_property(self, "position:y", position.y + 0.03, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _ring_mat:
		_shown_goodwill = move_toward(_shown_goodwill, _goodwill, delta * 60.0)
		_ring_mat.set_shader_parameter("fill", _shown_goodwill / PaperMarket.GOODWILL_TO_STRIKE)
	if _flag_holder and _flag.visible:
		_flag_holder.rotation.y = sin(_time * 2.3) * 0.25
	if _placards and _placards.visible:
		for k in _placards.get_child_count():
			_placards.get_child(k).position.y = absf(sin(_time * 5.0 + k * 1.7)) * 0.006
	if _wheel and _mill and _mill.visible:
		_wheel.rotation.z -= delta * 1.6


# --- Building ---

func _base() -> void:
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.cylinder(BASE_RADIUS, BASE_RADIUS + 0.003, 0.008, 28), "brown_planks_04",
			ToyBuilder.xf(Vector3(0, 0.004, 0)), 0.2, Color("8a6448"))
	b.finished(ToyBuilder.cylinder(BASE_RADIUS - 0.004, BASE_RADIUS - 0.004, 0.0015, 28), Color("6d8a5a"), "velvet",
			ToyBuilder.xf(Vector3(0, 0.0085, 0)))
	add_child(b.build(0.0, "Base"))
	if kind == Kind.TOWN:
		var ring := MeshInstance3D.new()
		ring.name = "Goodwill"
		var disc := PlaneMesh.new()
		disc.size = Vector2.ONE * (BASE_RADIUS * 2.0 + 0.026)
		ring.mesh = disc
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = preload("res://levels/03_paper_monopoly/goodwill_ring.gdshader")
		ring.material_override = _ring_mat
		ring.position.y = 0.001
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	var hb := ToyBuilder.new()
	hb.add(ToyBuilder.torus(BASE_RADIUS + 0.012, 0.0025, 40, 6), Color(1.0, 0.85, 0.45), ToyBuilder.xf(Vector3(0, 0.004, 0)), true)
	_highlight = hb.build(0.0, "Highlight")
	_highlight.visible = false
	add_child(_highlight)


func _pennant(at: Vector3, height: float) -> void:
	var b := ToyBuilder.new()
	b.finished(ToyBuilder.cylinder(0.0012, 0.0012, height, 6), Color("c9c2b2"), "metal", ToyBuilder.xf(at + Vector3(0, height / 2.0, 0)))
	b.finished(ToyBuilder.sphere(0.003, 8), Color("d8b25a"), "metal", ToyBuilder.xf(at + Vector3(0, height, 0)))
	add_child(b.build(0.0, "Pin"))
	# A pennant: a triangle of cloth, its base along the pin.
	_flag = MeshInstance3D.new()
	_flag.name = "Flag"
	var cloth := PrismMesh.new()
	cloth.size = Vector3(0.016, 0.028, 0.0015)
	cloth.left_to_right = 0.5
	_flag.mesh = cloth
	_flag_mat = StandardMaterial3D.new()
	_flag_mat.roughness = 0.9
	_flag.material_override = _flag_mat
	_flag_holder = Node3D.new()
	_flag_holder.position = at + Vector3(0, height - 0.011, 0)
	add_child(_flag_holder)
	_flag.position = Vector3(0.014, 0, 0)
	_flag.rotation.z = -PI / 2.0
	_flag_holder.add_child(_flag)


func _town() -> void:
	var b := ToyBuilder.new()
	# The mill: a long brick shed with a sawtooth roof and a tall chimney.
	var mill := Vector3(-0.006, 0.009, -0.006)
	b.textured(ToyBuilder.box(Vector3(0.05, 0.022, 0.03)), "old_stone_wall", ToyBuilder.xf(mill + Vector3(0, 0.011, 0)), 0.05, BRICK)
	for k in 3:
		var tooth := mill + Vector3(-0.0167 + k * 0.0167, 0.022, 0)
		b.add(_tooth(), SOOT.lightened(0.15), ToyBuilder.xf(tooth))
	# Rows of grimy windows.
	for k in 5:
		b.add(ToyBuilder.box(Vector3(0.005, 0.007, 0.0008)), Color("e0b066") if k % 2 == 0 else Color("4a3a2c"),
				ToyBuilder.xf(mill + Vector3(-0.02 + k * 0.01, 0.012, 0.0152)), k % 2 == 0)
	b.textured(ToyBuilder.cylinder(0.0035, 0.005, 0.07, 10), "old_stone_wall", ToyBuilder.xf(mill + Vector3(0.019, 0.035, -0.009)), 0.05, BRICK.darkened(0.2))
	b.add(ToyBuilder.torus(0.0042, 0.0012, 10, 4), SOOT, ToyBuilder.xf(mill + Vector3(0.019, 0.069, -0.009)))
	# Workers' terraces behind.
	for k in 3:
		var house := Vector3(-0.03 + k * 0.016, 0.009, 0.026)
		b.textured(ToyBuilder.box(Vector3(0.014, 0.014, 0.012)), "old_stone_wall", ToyBuilder.xf(house + Vector3(0, 0.007, 0)), 0.05, BRICK.lightened(0.08 * k))
		b.add(_roof(0.016, 0.014, 0.007), Color("3c3a3e"), ToyBuilder.xf(house + Vector3(0, 0.014, 0)))
		b.add(ToyBuilder.box(Vector3(0.003, 0.004, 0.0008)), Color("e8b866"), ToyBuilder.xf(house + Vector3(0.003, 0.007, 0.0062)), true)
	add_child(b.build(0.0, "Mill"))
	_pennant(Vector3(0.034, 0.009, -0.026), 0.075)
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.position = mill + Vector3(0.019, 0.072, -0.009)
	_smoke.amount = 14
	_smoke.lifetime = 2.6
	_smoke.direction = Vector3(0.3, 1, 0)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.018
	_smoke.initial_velocity_max = 0.028
	_smoke.gravity = Vector3(0.006, 0.004, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = curve
	var puff := SphereMesh.new()
	puff.radius = 0.005
	puff.height = 0.01
	puff.radial_segments = 6
	puff.rings = 3
	var puff_mat := StandardMaterial3D.new()
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.vertex_color_use_as_albedo = true
	puff.material = puff_mat
	_smoke.mesh = puff
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.8))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	_smoke.color_ramp = ramp
	add_child(_smoke)
	# Peg-doll workers in the yard, and their placards for a strike.
	_workers = Node3D.new()
	_workers.name = "Workers"
	add_child(_workers)
	_placards = Node3D.new()
	_placards.name = "Placards"
	add_child(_placards)
	var coats := [Color("3a3a48"), Color("4a3a2a"), Color("2e3e36"), Color("5a3030")]
	for k in 4:
		var a := -0.3 + k * 0.55
		var at := Vector3(cos(a) * 0.035, 0.009, sin(a) * 0.035 + 0.004)
		var wb := ToyBuilder.new()
		wb.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.0042, 0), Vector2(0.0036, 0.009),
				Vector2(0.0026, 0.012), Vector2(0, 0.0125)]), 10), coats[k], "velvet", ToyBuilder.xf(at))
		wb.finished(ToyBuilder.sphere(0.0028, 8), Color("e9c4a2"), "skin", ToyBuilder.xf(at + Vector3(0, 0.0148, 0)))
		wb.finished(ToyBuilder.cylinder(0.0024, 0.003, 0.0018, 8), Color("2a2622"), "velvet", ToyBuilder.xf(at + Vector3(0, 0.0172, 0)))
		var worker := wb.build(0.0, "Worker")
		_workers.add_child(worker)
		var sign := Node3D.new()
		sign.position = Vector3.ZERO
		var pb := ToyBuilder.new()
		pb.finished(ToyBuilder.cylinder(0.0005, 0.0005, 0.024, 4), Color("8a6a4a"), "leather", ToyBuilder.xf(at + Vector3(0.004, 0.02, 0)))
		pb.add(ToyBuilder.box(Vector3(0.014, 0.009, 0.0006)), Color("f2ecdc"), ToyBuilder.xf(at + Vector3(0.004, 0.032, 0)))
		pb.add(ToyBuilder.box(Vector3(0.010, 0.0012, 0.0007)), Color("8a1a1a"), ToyBuilder.xf(at + Vector3(0.004, 0.034, 0)))
		pb.add(ToyBuilder.box(Vector3(0.008, 0.0012, 0.0007)), Color("2a2a2a"), ToyBuilder.xf(at + Vector3(0.004, 0.031, 0)))
		sign.add_child(pb.build(0.0, "Placard"))
		_placards.add_child(sign)
	_placards.visible = false


static func _tooth() -> ArrayMesh:
	# One bay of a sawtooth roof: a steep glazed face and a long sloping back.
	return _roof(0.0167, 0.03, 0.008)


## A simple gabled roof `width` along x, `depth` along z, `height` tall.
static func _roof(width: float, depth: float, height: float) -> ArrayMesh:
	var prism := PrismMesh.new()
	prism.size = Vector3(depth, height, width)
	var arrays := prism.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := Basis(Vector3.UP, PI / 2.0)
	for i in verts.size():
		verts[i] = turn * verts[i] + Vector3(0, height / 2.0, 0)
		normals[i] = turn * normals[i]
	var mesh := ArrayMesh.new()
	mesh.set_meta("toy_arrays", [verts, normals, arrays[Mesh.ARRAY_INDEX]])
	return mesh


func _supplier() -> void:
	var b := ToyBuilder.new()
	match index:
		0:
			# A stand of pulpwood pines and a stack of cut logs.
			for k in 5:
				var a := TAU * k / 5.0 + 0.4
				var at := Vector3(cos(a) * 0.026, 0.009, sin(a) * 0.026)
				var tall := 0.03 + (k % 3) * 0.008
				b.finished(ToyBuilder.cylinder(0.0, 0.011, tall, 8), Color("2c4a34"), "velvet", ToyBuilder.xf(at + Vector3(0, tall / 2.0 + 0.006, 0)))
				b.finished(ToyBuilder.cylinder(0.0018, 0.0018, 0.008, 6), Color("5a4030"), "leather", ToyBuilder.xf(at + Vector3(0, 0.004, 0)))
			for k in 3:
				b.textured(ToyBuilder.cylinder(0.0035, 0.0035, 0.024, 8), "bark_brown_02", ToyBuilder.xf(Vector3(-0.004 + k * 0.0072, 0.0125, 0.004), Vector3(90, 0, 0)), 0.05)
			b.textured(ToyBuilder.cylinder(0.0035, 0.0035, 0.024, 8), "bark_brown_02", ToyBuilder.xf(Vector3(0.0, 0.019, 0.004), Vector3(90, 0, 0)), 0.05)
		1:
			# A great ink bottle with a quill in it.
			b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.022, 0), Vector2(0.025, 0.02), Vector2(0.016, 0.034),
					Vector2(0.008, 0.036), Vector2(0.009, 0.042), Vector2(0, 0.042)]), 18), Color("1c2a5a"), "metal", ToyBuilder.xf(Vector3(0, 0.009, 0)))
			b.add(ToyBuilder.cylinder(0.023, 0.023, 0.012, 18), Color("e8dcc0"), ToyBuilder.xf(Vector3(0, 0.025, 0)))
			b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 0.045, 0), Vector3(0.008, 0.07, -0.004), Vector3(0.018, 0.1, -0.01)]),
					PackedFloat32Array([0.0012, 0.006, 0.001]), 6, 4), Color("f0ebe0"), "fur")
		2:
			# A spool of red ribbon, unwinding.
			b.textured(ToyBuilder.cylinder(0.022, 0.022, 0.006, 20), "brown_planks_04", ToyBuilder.xf(Vector3(0, 0.012, 0)), 0.1, Color("a07850"))
			b.textured(ToyBuilder.cylinder(0.022, 0.022, 0.006, 20), "brown_planks_04", ToyBuilder.xf(Vector3(0, 0.042, 0)), 0.1, Color("a07850"))
			b.finished(ToyBuilder.cylinder(0.017, 0.017, 0.024, 20), Color("b81d31"), "velvet", ToyBuilder.xf(Vector3(0, 0.027, 0)))
			b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(0.017, 0.03, 0), Vector3(0.03, 0.012, 0.01), Vector3(0.04, 0.01, 0.025)]),
					PackedFloat32Array([0.003, 0.003, 0.003]), 4), Color("b81d31"), "velvet")
	add_child(b.build(0.0, "Supply"))
	_pennant(Vector3(-0.034, 0.009, -0.02), 0.07)


func _mill_site() -> void:
	_site = Node3D.new()
	_site.name = "Site"
	add_child(_site)
	var sb := ToyBuilder.new()
	for k in 14:
		var a := TAU * k / 14.0
		sb.add(ToyBuilder.box(Vector3(0.008, 0.001, 0.002)), Color("b0202a"), ToyBuilder.xf(Vector3(cos(a) * 0.032, 0.0095, sin(a) * 0.032),
				Vector3(0, -rad_to_deg(a) + 90.0, 0)))
	sb.finished(ToyBuilder.cylinder(0.0012, 0.0012, 0.03, 6), Color("8a6a4a"), "leather", ToyBuilder.xf(Vector3(0, 0.024, 0)))
	sb.add(ToyBuilder.box(Vector3(0.02, 0.012, 0.001)), Color("f2ecdc"), ToyBuilder.xf(Vector3(0, 0.036, 0.0008)))
	_site.add_child(sb.build(0.0, "Stake"))
	_mill = Node3D.new()
	_mill.name = "ElfMill"
	_mill.visible = false
	add_child(_mill)
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.box(Vector3(0.036, 0.026, 0.028)), "wood_trunk_wall", ToyBuilder.xf(Vector3(0, 0.022, 0)), 0.04, Color("b03a30"))
	b.add(_roof(0.04, 0.032, 0.016), Color("e8eef4"), ToyBuilder.xf(Vector3(0, 0.035, 0)))
	b.add(ToyBuilder.box(Vector3(0.008, 0.012, 0.001)), Color("6a4a30"), ToyBuilder.xf(Vector3(0, 0.015, 0.0145)))
	for side: float in [-1.0, 1.0]:
		b.add(ToyBuilder.box(Vector3(0.006, 0.006, 0.001)), Color("ffd27a"), ToyBuilder.xf(Vector3(side * 0.011, 0.025, 0.0145)), true)
	b.add(ToyBuilder.box(Vector3(0.012, 0.002, 0.03)), Color("6a8aa8"), ToyBuilder.xf(Vector3(0.026, 0.0095, 0)))
	_mill.add_child(b.build(0.0, "Mill"))
	_wheel = Node3D.new()
	_wheel.position = Vector3(0.021, 0.02, 0.0)
	_wheel.rotation.y = PI / 2.0
	_mill.add_child(_wheel)
	var wb := ToyBuilder.new()
	wb.textured(ToyBuilder.torus(0.012, 0.0015, 18, 4), "brown_planks_04", ToyBuilder.xf(Vector3.ZERO, Vector3(90, 0, 0)), 0.05, Color("7a5a3a"))
	for k in 8:
		var a := TAU * k / 8.0
		wb.textured(ToyBuilder.box(Vector3(0.0015, 0.024, 0.004)), "brown_planks_04", ToyBuilder.xf(Vector3.ZERO, Vector3(0, 0, rad_to_deg(a))), 0.05, Color("8a6a4a"))
	_wheel.add_child(wb.build(0.0, "Wheel"))
	_pennant(Vector3(-0.03, 0.009, -0.022), 0.07)
	show_owner(PaperMarket.Owner.SANTA)
