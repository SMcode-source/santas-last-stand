extends LevelBase
## Level 1, "The Frozen Workshop" (2 December): a 3D platformer.
##
## Jack Frost has frozen the North Pole. Santa, with a candle lantern, crosses
## the frozen workshop to relight its three furnaces (west, east and north,
## each at the end of its own run of jumps over thin ice), keeping warm at
## braziers on the way: the Cold meter drains in the open and he freezes if
## it empties. Each furnace sends heat up a pipe to the Clock Tower; with all
## three lit, the ice sealing the foot of the tower melts and he climbs the
## walkways round it to the roof, where Frost waits on the clock's gears.
##
## Checkpoints: "workshop" (with the furnaces lit so far, e.g.
## "workshop+west+north"), "clock_tower" and "boss".
##
## `-- --l1=<checkpoint>` starts straight from a checkpoint, for testing.

const L := preload("res://levels/01_frozen_workshop/workshop_layout.gd")
const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")
const SKY_DOME_SHADER := preload("res://core/visual/night_sky_dome.gdshader")

## The Cold meter empties in this many seconds in still cold air.
const DRAIN_SECONDS := 50.0
const NORTH_CHILL := 1.6
const ARENA_CHILL := 1.25
## Lanterns hung on the tower at these climb corners, to warm up at.
const TOWER_LANTERNS := [2, 4, 6, 8, 10]
const LIGHT_REACH := 2.4

var santa: SantaController
var cold: ColdMeter
var furnaces := {}
var pipes := {}
var arena: ClockArena
var lit: Array[String] = []
var stage := "workshop"
var moon: DirectionalLight3D

var _climb_ice: Node3D
var _climb_ice_body: StaticBody3D
var _pipe_warmth: Array[WarmSpot] = []
var _apex := 0.0
var _snowfall: MeshInstance3D
var _cold_bar: ProgressBar
var _cold_fill: StyleBoxFlat
var _frost_edge: TextureRect
var _prompt: Label
var _goal: Label
var _cold_nagged := -100.0
var _taunted := {}
var _armour_lines := 0
var _busy := false


func _ready() -> void:
	super._ready()
	var started := Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l1="):
			start_checkpoint = arg.get_slice("=", 1)
	section = start_checkpoint.get_slice("+", 0) if not start_checkpoint.is_empty() else "start"
	cold = ColdMeter.new(tuned(DRAIN_SECONDS, "timer"))
	_build_environment()
	add_child(Baked.node("workshop_set"))
	_add_fires()
	_add_furnaces()
	_add_moving_parts()
	_add_climb_ice()
	arena = ClockArena.new(tuned(1.0, "timer"))
	add_child(arena)
	arena.shard_hit.connect(func(amount: float) -> void: cold.hit(tuned(amount, "damage_taken")))
	arena.frost_spoke.connect(_on_frost_spoke)
	arena.defeated.connect(_on_frost_defeated)

	santa = SantaController.spawn(self, Transform3D(Basis(Vector3.UP, PI), L.START), {"throw": false, "grab": false, "sneak": false})
	santa.landed.connect(_on_landed)
	arena.santa = santa
	var lantern := WinterProps.lantern()
	santa.add_child(lantern)
	santa.santa.hold(lantern, "lantern")
	_build_hud()
	_restore(start_checkpoint)
	if start_checkpoint.is_empty():
		_intro.call_deferred()
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - started)
	print("Frozen Workshop built in %d ms" % Engine.get_meta("startup_ms"))


## Puts the level back as it was at `checkpoint`.
func _restore(checkpoint: String) -> void:
	var base := checkpoint.get_slice("+", 0)
	if base == "workshop" and checkpoint.split("+").size() > L.FURNACES.size():
		# Saved in the moment between the last furnace and the tower thawing.
		base = "clock_tower"
	if base == "workshop":
		for id in checkpoint.split("+").slice(1):
			_light(id, true)
	elif base in ["clock_tower", "boss"]:
		for id: String in L.FURNACES:
			_light(id, true)
		_melt_climb_ice(true)
	match base:
		"clock_tower":
			stage = "climb"
			santa.place(Transform3D(Basis(Vector3.UP, PI / 2.0), L.corner(0) + Vector3(-1.6, 0.05, 1.2)))
		"boss":
			stage = "boss"
			# On the roof by the top of the climb, facing the column.
			var spot := L.TOWER + Vector3(-2.6, L.TOWER_TOP + 0.1, -2.6)
			santa.place(Transform3D(Basis.looking_at(Vector3(1, 0, 1), Vector3.UP, true), spot))
			_start_boss.call_deferred()
	santa.camera.snap()
	_apex = santa.global_position.y
	_update_goal()


func _intro() -> void:
	_busy = true
	santa.input_enabled = false
	await get_tree().create_timer(0.6).timeout
	await Dialogue.play(Dialogue.lines("l1", "intro"))
	santa.input_enabled = true
	_busy = false
	_bark("start")


# --- Every frame ---

func _physics_process(delta: float) -> void:
	if ended:
		return
	var at := santa.global_position
	if santa.is_on_floor():
		_apex = at.y
	else:
		_apex = maxf(_apex, at.y)
	if at.y < L.FALL_Y:
		fail("Santa went through the thin ice. Brrr.")
		return
	if not _busy:
		var chill := 1.0
		if at.z < L.NORTH_WIND_Z and at.y < 6.0:
			chill = NORTH_CHILL
		elif stage == "boss":
			chill = ARENA_CHILL
		cold.update(delta, WarmSpot.heat_at(get_tree(), at + Vector3.UP), chill)
	if cold.is_frozen():
		fail("Santa froze solid. Keep warm by the fires!")
		return
	if cold.is_freezing() and play_time - _cold_nagged > 40.0:
		_cold_nagged = play_time
		_bark("cold" if _taunted.get("cold_once", false) == false else "cold_again")
		_taunted["cold_once"] = true
	_check_progress(at)


func _process(delta: float) -> void:
	super._process(delta)
	var view := get_viewport().get_camera_3d()
	if view and _snowfall:
		var mat := _snowfall.mesh.surface_get_material(0) as ShaderMaterial
		mat.set_shader_parameter("box_min", view.global_position - Vector3(14, 5, 14))
	_update_hud()


func _check_progress(at: Vector3) -> void:
	match stage:
		"climb":
			var rise := L.climb_rise()
			if at.y > rise * 3.5 and not _taunted.has("climb_low"):
				_taunted["climb_low"] = true
				_bark("climb_low")
			elif at.y > rise * 7.5 and not _taunted.has("climb_high"):
				_taunted["climb_high"] = true
				_bark("climb_high")
			var flat := Vector2(at.x - L.TOWER.x, at.z - L.TOWER.z)
			if at.y > L.TOWER_TOP - 0.3 and absf(flat.x) < L.TOWER_HALF + 0.3 and absf(flat.y) < L.TOWER_HALF + 0.3 and santa.is_on_floor():
				stage = "boss"
				reach_checkpoint("boss")
				_start_boss()


func _on_landed(fall_speed: float) -> void:
	var drop := _apex - santa.global_position.y
	_apex = santa.global_position.y
	if drop >= L.FATAL_DROP and fall_speed > 8.0:
		fail("That was a long way down. Mind the edges!")


# --- Furnaces, pipes and the tower ---

## Something Santa can use where he stands: [kind, target], or [] if none.
func _usable() -> Array:
	if _busy or ended:
		return []
	var at := santa.global_position
	for id: String in furnaces:
		var furnace: Furnace = furnaces[id]
		if not furnace.lit and furnace.stand_point().distance_to(at) < 1.5:
			return ["furnace", furnace]
	if stage == "boss" and arena.can_crank(at):
		return ["crank", arena]
	return []


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	var use := _usable()
	if use.is_empty():
		return
	get_viewport().set_input_as_handled()
	match use[0]:
		"furnace":
			var furnace: Furnace = use[1]
			santa.santa.wave()
			_light(furnace.id, false)
		"crank":
			arena.turn_crank()


func _light(id: String, instant: bool) -> void:
	if id in lit or not furnaces.has(id):
		return
	lit.append(id)
	(furnaces[id] as Furnace).light(instant)
	var pipe: HeatPipe = pipes[id]
	pipe.heat(instant, 0.8)
	var top: HeatPipe = arena.pipes[L.PIPE_ORDER.find(id)]
	top.heat(instant, 0.8 + pipe.length / HeatPipe.SPEED)
	_pipe_warmth[L.PIPE_ORDER.find(id)].enabled = true
	if instant:
		return
	var ordered: Array[String] = []
	for key: String in L.PIPE_ORDER:
		if key in lit:
			ordered.append(key)
	reach_checkpoint("workshop+" + "+".join(ordered))
	section = "workshop"
	match lit.size():
		1:
			_bark("first_furnace")
		2:
			_bark("second_furnace")
		3:
			_bark("all_lit")
			stage = "climb"
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				_melt_climb_ice(false)
				reach_checkpoint("clock_tower"))
	_update_goal()


func _melt_climb_ice(instant: bool) -> void:
	if _climb_ice_body:
		_climb_ice_body.queue_free()
		_climb_ice_body = null
	if instant:
		_climb_ice.visible = false
		return
	Audio.play_sfx("ring", 0.6, -4.0)
	var t := create_tween()
	t.tween_property(_climb_ice, "scale", Vector3(1.02, 0.01, 1.02), 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _climb_ice.visible = false)


# --- The boss ---

func _start_boss() -> void:
	stage = "boss"
	section = "boss"
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	arena.begin(randi())
	# Frost drops in and talks; the fight starts when he has had his say.
	arena.active = false
	await get_tree().create_timer(1.0).timeout
	await Dialogue.play(Dialogue.lines("l1", "boss_intro"))
	arena.active = true
	santa.input_enabled = true
	_busy = false
	_update_goal()


func _on_frost_spoke(key: String) -> void:
	match key:
		"armoured":
			_armour_lines += 1
			if _armour_lines % 2 == 1:
				_bark("frost_armoured" if _armour_lines % 4 == 1 else "frost_armoured_2")
		"missed":
			_bark("frost_missed")
		"exposed":
			_bark("frost_exposed")
		"phase_1", "phase_2":
			_bark(key)


func _on_frost_defeated() -> void:
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	await get_tree().create_timer(1.2).timeout
	var t := create_tween()
	t.tween_property(arena.frost, "position:y", arena.frost.position.y + 14.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(arena.frost, "scale", Vector3.ONE * 0.2, 1.6)
	await Dialogue.play(Dialogue.lines("l1", "outro"))
	complete()


# --- Barks and HUD ---

func _bark(key: String) -> void:
	if Dialogue.is_playing() and _busy:
		return
	Dialogue.play(Dialogue.lines("l1", key), "bark")


func _update_goal() -> void:
	if _goal == null:
		return
	match stage:
		"workshop":
			var left: Array[String] = []
			for id: String in L.PIPE_ORDER:
				if id not in lit:
					left.append(id)
			_goal.text = "Light the furnaces: %d / 3  (%s still out)" % [lit.size(), ", ".join(left)]
		"climb":
			_goal.text = "Climb the Clock Tower"
		"boss":
			_goal.text = "Stop Jack Frost"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	_frost_edge = TextureRect.new()
	_frost_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frost_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var edge := GradientTexture2D.new()
	edge.fill = GradientTexture2D.FILL_RADIAL
	edge.fill_from = Vector2(0.5, 0.5)
	edge.fill_to = Vector2(1.05, 1.05)
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.92, 1.0, 0.0))
	g.set_color(1, Color(0.85, 0.95, 1.0, 0.85))
	g.add_point(0.55, Color(0.8, 0.92, 1.0, 0.0))
	edge.gradient = g
	_frost_edge.texture = edge
	_frost_edge.modulate.a = 0.0
	layer.add_child(_frost_edge)

	var box := VBoxContainer.new()
	box.position = Vector2(18, 14)
	layer.add_child(box)
	var title := _label(18)
	title.text = "Warmth"
	box.add_child(title)
	_cold_bar = ProgressBar.new()
	_cold_bar.max_value = 1.0
	_cold_bar.show_percentage = false
	_cold_bar.custom_minimum_size = Vector2(240, 16)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.08, 0.16, 0.8)
	back.set_corner_radius_all(8)
	back.set_border_width_all(2)
	back.border_color = Color(0.7, 0.85, 1.0, 0.6)
	_cold_fill = StyleBoxFlat.new()
	_cold_fill.set_corner_radius_all(8)
	_cold_bar.add_theme_stylebox_override("background", back)
	_cold_bar.add_theme_stylebox_override("fill", _cold_fill)
	box.add_child(_cold_bar)
	_goal = _label(18)
	box.add_child(_goal)

	_prompt = _label(22)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 150
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_prompt)
	_update_goal()


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


func _update_hud() -> void:
	if _cold_bar == null:
		return
	_cold_bar.value = cold.value
	var warm := Color("ff8a3d").lerp(Color("ffd36b"), clampf(cold.value * 1.5 - 0.5, 0.0, 1.0))
	var colour := Color("7fc8ff").lerp(warm, smoothstep(0.15, 0.6, cold.value))
	if cold.is_freezing():
		colour = colour.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	_cold_fill.bg_color = colour
	_frost_edge.modulate.a = clampf(1.0 - cold.value / 0.45, 0.0, 1.0)
	var use := _usable()
	match "" if use.is_empty() else str(use[0]):
		"furnace":
			_prompt.text = "E: light the furnace with your lantern"
		"crank":
			_prompt.text = "E: turn the crank" if not arena.fight.swinging else ""
		_:
			_prompt.text = ""


func hint_for(part: String) -> String:
	return super.hint_for(part.get_slice("+", 0))


func debug_text() -> String:
	return super.debug_text() + "  ·  warmth %d%%  ·  stage %s" % [roundi(cold.value * 100.0), stage]


# --- Building ---

func _add_fires() -> void:
	for spec: Array in L.BRAZIERS:
		var brazier := Brazier.new(spec[1])
		brazier.position = spec[0]
		add_child(brazier)
	# Lanterns on the tower's corners, along the climb.
	for i: int in TOWER_LANTERNS:
		var corner := L.corner(i)
		var out := Vector3(corner.x - L.TOWER.x, 0, corner.z - L.TOWER.z).normalized()
		var lamp := WinterProps.lantern()
		lamp.position = L.TOWER + out * (L.TOWER_HALF * 1.414 + 0.1) + Vector3(0, corner.y + 2.3, 0)
		# Just the glow: real lights here would crowd the tower past the
		# renderer's per-mesh light limit.
		for light in lamp.find_children("*", "OmniLight3D", true, false):
			light.free()
		add_child(lamp)
		var b := ToyBuilder.new()
		b.finished(ToyBuilder.tube(PackedVector3Array([lamp.position - out * 0.5 + Vector3(0, 0.05, 0), lamp.position + Vector3(0, 0.05, 0)]),
				PackedFloat32Array([0.025, 0.02]), 6), Color("26262a"), "metal")
		add_child(b.build(0.0, "LanternArm"))
		var warmth := WarmSpot.new(LIGHT_REACH, 0.8)
		warmth.position = Vector3(corner.x, corner.y + 1.0, corner.z)
		add_child(warmth)
	# Each hot pipe on the roof warms whoever stands near it.
	for i in L.PIPE_ORDER.size():
		var warmth := WarmSpot.new(2.6, 0.9, false)
		warmth.position = L.TOWER + L.direction(L.GEAR_ANGLES[i]) * (L.PIPE_OUT - 0.4) + Vector3(0, L.TOWER_TOP + 1.0, 0)
		add_child(warmth)
		_pipe_warmth.append(warmth)


func _add_furnaces() -> void:
	for id: String in L.FURNACES:
		var spec: Array = L.FURNACES[id]
		var furnace := Furnace.new(id)
		furnace.position = spec[0]
		furnace.rotation_degrees.y = spec[1]
		add_child(furnace)
		furnaces[id] = furnace
		var pipe := HeatPipe.new(L.PIPE_RUNS[id])
		pipe.name = "Pipe_" + id
		add_child(pipe)
		pipes[id] = pipe


func _add_moving_parts() -> void:
	for spec: Array in WorkshopSet.climb_movers():
		add_child(MovingPlatform.make(Vector3(2.0, 0.3, 2.0), spec[0], spec[1], 3.2))
	# West: a shuttle from the end of the belt to the far pier.
	add_child(MovingPlatform.make(Vector3(2.0, 0.3, 2.0), Vector3(-41.0, 0.85, 2.0), Vector3(-6.2, 0, 0), 3.2))
	# East: a cart sliding to and fro past the end of the hall roof.
	add_child(MovingPlatform.make(Vector3(2.0, 0.3, 2.0), Vector3(45.4, 1.85, -2.0), Vector3(0, 0, 8.0), 2.8))
	# North: two ice floes drifting across the gaps in the bridge.
	add_child(_floe(Vector3(-3.5, -0.35, -40.0), Vector3(7.0, 0, 0), 4.0, 0.0))
	add_child(_floe(Vector3(3.5, -0.35, -47.6), Vector3(-7.0, 0, 0), 4.0, 2.0))
	_snowfall = WinterProps.snowfall(500, Vector3(-14, -5, -14), Vector3(28, 12, 28))
	_snowfall.mesh.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 200, 1000))
	add_child(_snowfall)


## A slab of floating ice drifting from `at` by `offset` and back, `delay`
## seconds into its cycle.
func _floe(at: Vector3, offset: Vector3, seconds: float, delay: float) -> MovingPlatform:
	var floe := MovingPlatform.new()
	floe.name = "Floe"
	floe.position = at
	floe.to = offset
	floe.travel_time = seconds
	var b := ToyBuilder.new()
	b.finished(ToyBuilder.lumpy(ToyBuilder.box(Vector3(2.2, 0.5, 2.2)), 0.06, 2.0, int(at.z)), Color("bcd9ea"), "eye")
	b.textured(ToyBuilder.snow_sheet(Vector2(2.0, 2.0), 0.06, int(-at.z), 0.15), "snow_02", ToyBuilder.xf(Vector3(0, 0.25, 0)),
			1.5, WinterProps.SNOW_TINT)
	floe.add_child(b.build(0.0, "Mesh"))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.56, 2.2)
	shape.shape = box
	shape.position.y = 0.03
	floe.add_child(shape)
	floe.phase = delay
	return floe


## Ice sealing the foot of the climb until all three furnaces are lit.
func _add_climb_ice() -> void:
	var centre := Vector3(-2.3, 1.7, -6.3)
	var size := Vector3(7.8, 3.4, 3.4)
	_climb_ice = Node3D.new()
	_climb_ice.name = "ClimbIce"
	_climb_ice.position = centre - Vector3(0, size.y / 2.0, 0)
	add_child(_climb_ice)
	var chunks := [[WorkshopSet.ice_chunk(size, 9, 0.22), ToyBuilder.xf(Vector3(0, size.y / 2.0, 0))]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 14:
		var spike := rng.randf_range(0.6, 1.6)
		chunks.append([ToyBuilder.cylinder(0.0, rng.randf_range(0.15, 0.3), spike, 6),
				ToyBuilder.xf(Vector3(rng.randf_range(-3.6, 3.6), size.y - 0.1 + spike / 2.0, rng.randf_range(-1.5, 1.5)),
						Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)))])
	_climb_ice.add_child(WorkshopSet.ice_mesh(chunks))
	_climb_ice_body = StaticBody3D.new()
	_climb_ice_body.collision_layer = PhysicsLayers.WORLD
	_climb_ice_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	_climb_ice_body.add_child(shape)
	add_child(_climb_ice_body)


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
	env.ambient_light_color = Color("6a80c4")
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
	env.fog_light_color = Color("38407a")
	env.fog_density = 0.007
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
	moon.light_energy = 1.5
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	moon.look_at_from_position(Vector3(-6, 10, 8), Vector3.ZERO)
	add_child(GraphicsQuality.new(env, moon))
