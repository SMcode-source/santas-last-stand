extends LevelBase
## Level 2, "Krampusnacht" (5 December): a brawler.
##
## The sleigh flies in on rails up an Alpine valley (rings to steer through;
## Pepper stows away in the sack and pops out halfway). It lands below a
## village where every light is out. Santa fights his way up the main street
## past Krampus's helpers to the church square, where elves hang in sacks
## from the bell tower and Krampus watches from the belfry. His helpers cut
## the sacks down and carry them off over the bridge: knock a carrier down,
## open the sack, and the elf runs to the church for a bell rope. Three sacks
## over the bridge and the chapter is lost.
##
## Then Krampus drops into the square. In the dark nothing hurts him; ring
## the bells (the rope is inside the church door) and the lights come on.
## Even then fists only annoy him, and mashing earns a shove: parry his chain
## as it lashes, and while you hold it, attack to slam him. Three slams; the
## lights go out once in between. Santa can be knocked out (his health comes
## back slowly out of the fight).
##
## Checkpoints: "village" (landed), "square" (the sacks come down) and
## "boss". `-- --l2=<checkpoint>` starts from one, for testing.

const L := preload("res://levels/02_krampusnacht/village_layout.gd")
const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")
const SKY_DOME_SHADER := preload("res://core/visual/night_sky_dome.gdshader")
const WINDOW_SHADER := preload("res://core/visual/window_glass.gdshader")

const MAX_HEALTH := 6.0
## Out of harm's way this long, his health starts creeping back.
const REGEN_AFTER := 6.0
const REGEN_RATE := 0.3
const CLAW_DAMAGE := 1.0
const WHIP_DAMAGE := 1.5
const SHOVE_DAMAGE := 1.0
## Seconds before the first helper cuts a sack down, and between the next.
const FIRST_CARRIER := 3.0
const CARRY_EVERY := 6.5
const KRAMPUS_SPEED := 3.0
const LAMP_ENERGY := 1.7
const WINDOW_ENERGY := 1.25
const GLASS_GLOW := 2.4
const DARK_GLOW := 0.06
const STAINED := [Color(0.95, 0.35, 0.2), Color(0.3, 0.5, 1.0), Color(1.0, 0.82, 0.3), Color(0.4, 0.85, 0.45)]

var stage := "flight"
var santa: SantaController
var sleigh: SleighController
var course: FlightCourse
var guard: ParryGuard
var sacks_run: SackRun
var fight: KrampusFight
var krampus: Krampus
var sacks: Array[ElfSack] = []
var health := MAX_HEALTH
var lit := false
var moon: DirectionalLight3D
var env: Environment

var _max_health := MAX_HEALTH
var _since_hurt := 99.0
var _busy := false
var _lamp_lights: Array[OmniLight3D] = []
var _lamp_glow: ShaderMaterial
var _windows: ShaderMaterial
var _glass: ShaderMaterial
var _village_glow: ShaderMaterial
var _bells: Array[Node3D] = []
var _ringing := 0.0
var _sleigh_sack: Node3D
var _said := {}
var _taunt_at := 25.0
var _dark_hits := 0
var _last_state := -1
var _cut_camera: Camera3D
var _snowfall: MeshInstance3D
var _parry_ring: MeshInstance3D

var _health_bar: ProgressBar
var _goal: Label
var _tally: Label
var _prompt: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_state: Label
var _rings: Label
var _controls: Label
var _flash: ColorRect
var _fade: ColorRect


func _ready() -> void:
	super._ready()
	var started := Time.get_ticks_msec()
	var lights_on := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l2="):
			start_checkpoint = arg.get_slice("=", 1)
		elif arg == "--l2-lit":
			lights_on = true
	section = start_checkpoint if not start_checkpoint.is_empty() else "flight"
	_max_health = tuned(MAX_HEALTH, "health")
	health = _max_health
	guard = ParryGuard.new(tuned(1.0, "timer"))
	sacks_run = SackRun.new(L.SACKS.size())
	_build_environment()
	var village := Baked.node("village_set")
	add_child(village)
	_dim_windows(village)
	_add_lamps()
	_add_church_glass()
	_add_bells()
	_add_sacks()
	krampus = Krampus.new()
	add_child(krampus)
	krampus.global_position = L.PERCH
	krampus.struck.connect(_on_krampus_struck)
	course = FlightCourse.new()
	add_child(course)
	sleigh = SleighController.new()
	add_child(sleigh)
	_sleigh_sack = WinterProps.toy_sack(5)
	_sleigh_sack.position = Vector3(-0.3, 0.95, -0.95)
	sleigh.model.add_child(_sleigh_sack)
	_snowfall = WinterProps.snowfall(500, Vector3(-14, -5, -14), Vector3(28, 12, 28))
	_snowfall.mesh.custom_aabb = AABB(Vector3(-600, -60, -600), Vector3(1200, 300, 2000))
	add_child(_snowfall)
	_build_hud()
	match start_checkpoint:
		"village":
			_land(true)
		"square":
			_land(true)
			santa.place(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, L.SQUARE_ENTRY_Z - 1.0)))
			santa.camera.snap()
			_start_sack_run()
		"boss":
			_land(true)
			santa.place(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 3.0)))
			santa.camera.snap()
			for i in sacks.size():
				sacks_run.sacks[i] = SackRun.Sack.FREED
				sacks[i].vanish()
			_start_boss(true)
		_:
			_start_flight.call_deferred()
	if lights_on:
		_set_lights(true)
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - started)
	print("Krampusnacht built in %d ms" % Engine.get_meta("startup_ms"))


# --- The flight in ---

func _start_flight() -> void:
	stage = "flight"
	section = "flight"
	var start := course.path.curve.sample_baked_with_rotation(0.0, true, true)
	sleigh.place(Transform3D(Basis.looking_at(-start.basis.z, Vector3.UP, true), start.origin))
	sleigh.follow_rail(course.path, 0.0, false)
	sleigh.rail_finished.connect(_on_flight_done, CONNECT_ONE_SHOT)
	sleigh.camera.make_current()
	sleigh.camera.snap()
	sleigh.set_physics_process(false)
	_update_hud_mode()
	_busy = true
	await get_tree().create_timer(0.5).timeout
	await Dialogue.play(Dialogue.lines("l2", "flight_intro"))
	_busy = false
	sleigh.set_physics_process(true)
	sleigh.input_enabled = true


func _track_flight() -> void:
	course.track(sleigh)
	var p := course.progress_of(sleigh)
	if p > 0.12:
		_say_once("flight_rings")
	if p > 0.36 and not _said.has("sack_wriggle"):
		_say_once("sack_wriggle")
	if p > 0.45 and not _said.has("pepper"):
		_say_once("pepper")
		var pop := create_tween()
		pop.tween_property(_sleigh_sack, "scale", Vector3(1.4, 1.6, 1.4), 0.12)
		pop.tween_property(_sleigh_sack, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC)
	if p > 0.86:
		_say_once("village_dark")


func _on_flight_done() -> void:
	if stage != "flight":
		return
	stage = "landing"
	_busy = true
	sleigh.input_enabled = false
	await _fade_to(1.0, 0.7)
	_land(false)
	await _fade_to(0.0, 0.8)
	santa.input_enabled = false
	await Dialogue.play(Dialogue.lines("l2", "landed"))
	santa.input_enabled = true
	_busy = false


## Sets the scene on the landing field: the sleigh parked, Santa beside it,
## and the helpers waiting up the street.
func _land(instant: bool) -> void:
	course.visible = false
	sleigh.set_physics_process(false)
	sleigh.input_enabled = false
	sleigh.mode = SleighController.Mode.FREE
	sleigh.place(Transform3D(Basis(Vector3.UP, PI * 0.9), L.SLEIGH_PARK + Vector3(0, SleighController.HALF_SIZE.y, 0)))
	sleigh.camera.capture_mouse = false
	santa = SantaController.spawn(self, Transform3D(Basis(Vector3.UP, PI), L.SANTA_START), {"throw": false, "grab": false, "sneak": false})
	santa.camera.snap()
	_parry_ring = _make_parry_ring()
	santa.facing.add_child(_parry_ring)
	stage = "street"
	section = "village"
	if not instant:
		reach_checkpoint("village")
	if start_checkpoint in ["", "village"]:
		for at: Vector3 in L.STREET_GUARDS:
			_spawn_demon(at)
	_update_hud_mode()


# --- The street and the square ---

func _arrival() -> void:
	stage = "arrival"
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	_freeze_demons(true)
	_cut_to(Vector3(7.0, 2.4, -3.0), L.TOWER + Vector3(0, 8.5, 0))
	krampus.face(Vector3(7.0, 0, -3.0), true)
	await Dialogue.play(Dialogue.lines("l2", "arrival"))
	santa.camera.make_current()
	_freeze_demons(false)
	santa.input_enabled = true
	_busy = false
	reach_checkpoint("square")
	_start_sack_run()


## The helpers come for the sacks: one by one they cut a sack down and make
## for the bridge, while two more jump into the square.
func _start_sack_run() -> void:
	stage = "sacks"
	section = "square"
	for i in sacks.size():
		var demon := _spawn_demon(L.sack_ground(i) + (L.sack_ground(i) - Vector3(L.TOWER.x, 0, L.TOWER.z)).normalized() * 0.7)
		demon.fetch(sacks[i], tuned(FIRST_CARRIER + i * CARRY_EVERY, "timer"), L.sack_route(i))
	for at: Vector3 in L.SQUARE_GUARDS:
		_spawn_demon(at)
	_update_hud_mode()


func _spawn_demon(at: Vector3) -> Demon:
	var demon := Demon.new()
	add_child(demon)
	demon.global_position = at
	demon.rotation.y = randf() * TAU
	demon.santa = santa
	demon.gentleness = tuned(1.0, "timer")
	demon.chase_speed = tuned(demon.chase_speed, "enemy_speed")
	demon.carry_speed = tuned(demon.carry_speed, "enemy_speed")
	demon.swiped.connect(_on_claws)
	demon.took_sack.connect(func(_d: Demon, i: int) -> void: sacks_run.carry(i))
	demon.dropped_sack.connect(_on_sack_dropped)
	demon.escaped.connect(_on_sack_escaped)
	demon.beaten.connect(func(_d: Demon) -> void: _say_once("first_beaten"))
	return demon


func _on_claws(demon: Demon) -> void:
	if ended or _busy:
		return
	var gap := Vector2(demon.global_position.x - santa.global_position.x, demon.global_position.z - santa.global_position.z).length()
	if gap > Demon.REACH + 0.3:
		return
	if guard.is_up():
		guard.spend()
		demon.parried()
		_parried_fx(false)
		_say_once("first_parry")
		return
	_hurt(CLAW_DAMAGE, demon.global_position, 5.0)


func _on_sack_dropped(demon: Demon, i: int) -> void:
	var sack := sacks[i]
	match sack.state:
		ElfSack.State.HANGING:
			sack.cut_down()
		ElfSack.State.CARRIED:
			sack.drop_into(self, demon.global_position - demon.global_transform.basis.z * 0.6)
	sacks_run.drop(i)
	_say_once("first_drop")


func _on_sack_escaped(_demon: Demon, i: int) -> void:
	if i < 0:
		return
	var sack := sacks[i]
	sack.reparent(self)
	sack.vanish()
	sacks_run.escape(i)
	var lost := sacks_run.count(SackRun.Sack.LOST)
	if sacks_run.is_failed():
		fail("Krampus's helpers carried three sacks of elves over the bridge.")
		return
	_bark("lost_%d" % lost)
	_check_settled()


func _open_sack(sack: ElfSack) -> void:
	if not sacks_run.release(sack.index):
		return
	santa.santa.wave()
	var way := PackedVector3Array()
	if sack.global_position.x < -16.0:
		way.append(L.ESCAPE_ROUTE[0])
	way.append(L.DOOR + Vector3(0, 0, 1.4))
	way.append(L.DOOR + Vector3(0, 0, -0.3))
	sack.open(way)
	Audio.play_sfx("ring", 1.3, -6.0)
	var freed := sacks_run.ringers()
	_bark("freed_%d" % mini(freed, 3))
	_check_settled()


func _check_settled() -> void:
	if stage != "sacks" or not sacks_run.is_settled() or sacks_run.is_failed():
		return
	stage = "settled"
	await get_tree().create_timer(1.8).timeout
	if not ended:
		_start_boss(false)


# --- The boss ---

func _start_boss(restored: bool) -> void:
	stage = "boss"
	section = "boss"
	if not restored:
		reach_checkpoint("boss")
	for demon: Demon in get_tree().get_nodes_in_group("demons"):
		demon.banish()
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	fight = KrampusFight.new(guard, tuned(1.0, "timer"))
	fight.winding_up.connect(_on_winding_up)
	fight.whipped.connect(_on_whipped)
	fight.parried.connect(_on_parried)
	fight.yanked_free.connect(func() -> void:
		krampus.let_go()
		_bark_every("yanked", 2))
	fight.shrugged.connect(_on_shrugged)
	fight.countered.connect(_on_countered)
	fight.slammed.connect(_on_slammed)
	fight.lights_out.connect(_on_lights_out)
	fight.lit_up.connect(_on_lit_up)
	fight.defeated.connect(_on_krampus_defeated)
	_cut_to(Vector3(-6.5, 2.2, 1.0), L.ARENA_DROP + Vector3(0, 2.0, 0))
	await get_tree().create_timer(0.5).timeout
	await krampus.leap_to(L.ARENA_DROP, 1.1).finished
	krampus.face(santa.global_position, true)
	_update_hud_mode()
	await Dialogue.play(Dialogue.lines("l2", "boss_intro"))
	santa.camera.make_current()
	santa.input_enabled = true
	_busy = false


func _update_boss(delta: float) -> void:
	var gap := _gap_to_krampus()
	match fight.state:
		KrampusFight.State.STALK:
			if gap > KrampusFight.WHIP_RANGE - 0.5:
				krampus.stride_to(santa.global_position, tuned(KRAMPUS_SPEED, "enemy_speed"))
			krampus.face(santa.global_position)
		KrampusFight.State.WINDUP, KrampusFight.State.RECOVER, KrampusFight.State.COUNTER:
			krampus.face(santa.global_position)
		KrampusFight.State.CAUGHT:
			krampus.hold_chain(santa.global_position + Vector3.UP * 1.15 + santa.facing.global_transform.basis.z * 0.35)
	fight.update(delta, gap)
	if _last_state == KrampusFight.State.DOWN and fight.state != KrampusFight.State.DOWN and not fight.is_over():
		krampus.get_up()
	_last_state = fight.state


func _gap_to_krampus() -> float:
	var a := santa.global_position
	var b := krampus.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_krampus_struck(_hit: Dictionary) -> void:
	if stage == "boss" and fight and not _busy:
		fight.punch()


func _on_winding_up(_seconds: float) -> void:
	krampus.wind_up(fight.timer)
	_say_once("parry_hint")


func _on_whipped(hit: bool) -> void:
	krampus.lash(santa.global_position if hit else santa.global_position + santa.velocity.normalized() * 1.5)
	if hit:
		_hurt(WHIP_DAMAGE, krampus.global_position, 7.0)


func _on_parried(caught: bool) -> void:
	_parried_fx(caught)
	if caught:
		_say_once("caught_hint")
	else:
		_bark_every("dark_parry", 2)


func _on_shrugged(dark: bool) -> void:
	krampus.shrug(dark)
	_dark_hits += 1
	if dark:
		if _dark_hits % 3 == 1:
			_bark("dark_punch" if _dark_hits % 2 == 1 else "dark_punch_2")
	elif _dark_hits % 4 == 1:
		_bark("tickles")


func _on_countered() -> void:
	krampus.shove()
	_hurt(SHOVE_DAMAGE, krampus.global_position, 9.0)
	_bark_every("countered", 1)


func _on_slammed(left: int) -> void:
	krampus.slammed(santa.global_position)
	_shake(0.5)
	Audio.play_sfx("bell", 0.5, -2.0)
	match left:
		2:
			_bark("phase_1")
		1:
			_bark("phase_2")


func _on_lights_out() -> void:
	krampus.howl()
	_set_lights(false)
	_bark("lights_out")


func _on_lit_up() -> void:
	_ring_bells()
	_set_lights(true)
	_bark("bells" if not _said.has("bells") else "bells_again")
	_said["bells"] = true


func _on_krampus_defeated() -> void:
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	krampus.get_up()
	var leave := func(cue: String) -> void:
		if cue == "krampus_leaves":
			_krampus_leaves()
	Dialogue.cue.connect(leave)
	await Dialogue.play(Dialogue.lines("l2", "outro"))
	Dialogue.cue.disconnect(leave)
	if krampus.global_position.y < 1.0:
		# The scene was skipped before he left.
		krampus.visible = false
	complete()


## Over the rooftops and away into the mountains.
func _krampus_leaves() -> void:
	await krampus.leap_to(Vector3(19.0, 7.5, -20.0), 1.2).finished
	await krampus.leap_to(Vector3(40.0, 4.0, -40.0), 1.0).finished
	krampus.visible = false


# --- Every frame ---

func _physics_process(delta: float) -> void:
	if ended:
		return
	guard.update(delta)
	match stage:
		"flight":
			_track_flight()
		"street":
			if santa.global_position.z < L.SQUARE_ENTRY_Z:
				_arrival()
		"sacks":
			_taunt_at -= delta
			if _taunt_at <= 0.0:
				_taunt_at = 30.0
				_bark("taunt_%d" % (1 + randi() % 2))
		"boss":
			if not _busy and not fight.is_over():
				_update_boss(delta)
	if santa:
		if stage in ["sacks", "settled", "street"]:
			krampus.face(santa.global_position)
		if santa.global_position.y < L.FALL_Y:
			fail("Santa tumbled into the gorge.")
			return
		_since_hurt += delta
		if _since_hurt > REGEN_AFTER:
			health = minf(_max_health, health + REGEN_RATE * delta)


func _process(delta: float) -> void:
	super._process(delta)
	var view := get_viewport().get_camera_3d()
	if view and _snowfall:
		var mat := _snowfall.mesh.surface_get_material(0) as ShaderMaterial
		mat.set_shader_parameter("box_min", view.global_position - Vector3(14, 5, 14))
	if stage == "flight" and _sleigh_sack:
		var p := course.progress_of(sleigh)
		var fit := smoothstep(0.34, 0.37, p) * (1.0 - smoothstep(0.445, 0.45, p))
		_sleigh_sack.rotation.z = sin(play_time * 22.0) * 0.18 * fit
		_sleigh_sack.rotation.x = sin(play_time * 17.0) * 0.12 * fit
	if _ringing > 0.0:
		_ringing -= delta
		for k in _bells.size():
			_bells[k].rotation.x = sin(play_time * 2.6 + k * 1.3) * 0.7 * clampf(_ringing / 3.0, 0.0, 1.0)
	_update_hud()


func _input(event: InputEvent) -> void:
	if santa == null or ended or _busy or event.is_echo():
		return
	if event.is_action_pressed("parry"):
		if guard.press():
			_guard_fx()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack") and stage == "boss" and fight and fight.state == KrampusFight.State.CAUGHT:
		krampus.let_go()
		fight.slam()
	elif event.is_action_pressed("interact"):
		var use := _usable()
		if use.is_empty():
			return
		get_viewport().set_input_as_handled()
		match use[0]:
			"sack":
				_open_sack(use[1])
			"bells":
				if fight.ring(sacks_run.ringers()):
					santa.santa.wave()


## Something Santa can use where he stands: [kind, target], or [] if none.
func _usable() -> Array:
	if _busy or ended or santa == null:
		return []
	var at := santa.global_position
	if stage in ["sacks", "settled", "boss"]:
		for sack in sacks:
			if sack.can_open() and Vector2(sack.global_position.x - at.x, sack.global_position.z - at.z).length() < 1.7:
				return ["sack", sack]
	if stage == "boss" and fight and not fight.lit and Vector2(at.x - L.DOOR.x, at.z - L.DOOR.z).length() < 2.4:
		return ["bells"]
	return []


# --- Santa getting hurt ---

func _hurt(amount: float, from: Vector3, push: float) -> void:
	if ended or _busy:
		return
	health -= tuned(amount, "damage_taken")
	_since_hurt = 0.0
	var away := santa.global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	santa.velocity += away * push + Vector3.UP * 3.0
	Audio.play_sfx("click", 0.45, 0.0)
	_flash.color = Color(0.8, 0.05, 0.05, 0.35)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.45)
	_shake(0.2)
	if health <= 0.0:
		health = 0.0
		fail("Santa was knocked out cold.")


# --- Lights and bells ---

## Every window in the village goes dark, and so do the Christmas tree's
## lights (they share two materials, so the bells can light them all at once).
func _dim_windows(root: Node) -> void:
	_windows = WinterProps.window_material().duplicate() as ShaderMaterial
	_windows.set_shader_parameter("energy", 0.0)
	_village_glow = ShaderMaterial.new()
	_village_glow.shader = ToyBuilder.GLOW_SHADER
	_village_glow.set_shader_parameter("strength", DARK_GLOW * 2.0)
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as ShaderMaterial
			if mat and mat.shader == WINDOW_SHADER:
				mesh.set_surface_override_material(i, _windows)
			elif mat and mat.shader == ToyBuilder.GLOW_SHADER:
				mesh.set_surface_override_material(i, _village_glow)


## The street lamps' flames, all in one mesh, and a light at each (dark).
func _add_lamps() -> void:
	var b := ToyBuilder.new()
	var low: bool = Engine.get_meta("graphics_level", GraphicsQuality.Level.MEDIUM) == GraphicsQuality.Level.LOW
	for at: Vector3 in L.LAMPS:
		var flame := at + Vector3(0, 2.98, 0)
		b.part(ToyBuilder.sphere(0.05, 10), Color("fff0c8"), flame, Vector3.ZERO, Vector3(1, 1.4, 1), true)
		b.part(ToyBuilder.cylinder(0.115, 0.095, 0.34, 6), Color("e09a48"), flame, Vector3(0, 30, 0), Vector3.ONE, true)
		if low:
			continue
		var light := OmniLight3D.new()
		light.light_color = WinterProps.WARM_LIGHT
		light.light_energy = 0.0
		light.omni_range = 7.5
		light.visible = false
		light.position = flame
		add_child(light)
		_lamp_lights.append(light)
	var flames := b.build(0.0, "LampFlames")
	_lamp_glow = _dim_glow(flames, DARK_GLOW * 2.0)
	add_child(flames)


## The church's stained glass, dark until the bells ring.
func _add_church_glass() -> void:
	var pieces := MeshPieces.new()
	var k := 0
	for spec: Array in L.church_windows():
		var at: Vector3 = spec[0]
		var normal: Vector3 = spec[1]
		for row in 4:
			for col in 2:
				var colour: Color = STAINED[(k + row + col) % STAINED.size()]
				var side := Vector3.UP.cross(normal)
				pieces.rect(at + normal * 0.09 + Vector3(0, -0.98 + row * 0.65, 0) + side * (col - 0.5) * 0.56, normal, Vector3.UP,
						Vector2(0.54, 0.63), colour)
		pieces.disc(at + normal * 0.09 + Vector3(0, 1.45, 0), normal, Vector3.UP, 0.56, STAINED[k % STAINED.size()])
		k += 1
	_glass = ShaderMaterial.new()
	_glass.shader = ToyBuilder.GLOW_SHADER
	_glass.set_shader_parameter("strength", DARK_GLOW)
	var mesh := ArrayMesh.new()
	pieces.add_to(mesh, _glass)
	var glass := MeshInstance3D.new()
	glass.name = "StainedGlass"
	glass.mesh = mesh
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)


## Gives a built mesh's glowing parts their own dimmable material.
func _dim_glow(built: MeshInstance3D, strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ToyBuilder.GLOW_SHADER
	mat.set_shader_parameter("strength", strength)
	for i in built.mesh.get_surface_count():
		var surface := built.mesh.surface_get_material(i) as ShaderMaterial
		if surface and surface.shader == ToyBuilder.GLOW_SHADER:
			built.set_surface_override_material(i, mat)
	return mat


## Three bronze bells in the belfry, hung from a beam, free to swing.
func _add_bells() -> void:
	var beam := ToyBuilder.new()
	var top := L.TOWER + Vector3(0, L.BELFRY_Y + 2.55, 0)
	beam.textured(ToyBuilder.box(Vector3(L.TOWER_HALF * 2.0 - 0.2, 0.22, 0.26)), "wood_trunk_wall", ToyBuilder.xf(top), 1.0, Color("6f5240"))
	add_child(beam.build(0.0, "BellBeam"))
	for k in 3:
		var size: float = [0.3, 0.45, 0.32][k]
		var pivot := Node3D.new()
		pivot.name = "Bell%d" % k
		pivot.position = top + Vector3((k - 1) * 0.75, -0.12, 0)
		add_child(pivot)
		var b := ToyBuilder.new()
		var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.55, 0.05), Vector2(1.0, -0.02), Vector2(0.98, 0.08),
				Vector2(0.75, 0.3), Vector2(0.6, 0.65), Vector2(0.55, 0.95), Vector2(0.35, 1.05), Vector2(0.0, 1.07)])
		var scaled := PackedVector2Array()
		for p in profile:
			scaled.append(p * size)
		var bell := ToyBuilder.lathe(scaled, 18)
		b.finished(bell, Color("a07a3c"), "metal", ToyBuilder.xf(Vector3(0, -size * 1.1, 0)))
		b.finished(ToyBuilder.sphere(size * 0.18, 8), Color("5a4630"), "metal", ToyBuilder.xf(Vector3(0, -size * 1.05, 0)))
		b.finished(ToyBuilder.box(Vector3(0.12, size * 0.25, 0.12)), Color("3a3a3e"), "metal", ToyBuilder.xf(Vector3(0, -size * 0.05, 0)))
		pivot.add_child(b.build(0.0, "Bell"))
		_bells.append(pivot)


func _ring_bells() -> void:
	_ringing = 7.0
	for k in 6:
		get_tree().create_timer(k * 0.55).timeout.connect(func() -> void: Audio.play_sfx("bell", [0.7, 0.9, 0.8][k % 3], -3.0))


func _set_lights(on: bool) -> void:
	lit = on
	var seconds := 2.2 if on else 0.6
	var t := create_tween().set_parallel()
	t.tween_property(_windows, "shader_parameter/energy", WINDOW_ENERGY if on else 0.0, seconds)
	t.tween_property(_lamp_glow, "shader_parameter/strength", 3.0 if on else DARK_GLOW * 2.0, seconds)
	t.tween_property(_glass, "shader_parameter/strength", GLASS_GLOW if on else DARK_GLOW, seconds)
	t.tween_property(_village_glow, "shader_parameter/strength", 3.0 if on else DARK_GLOW * 2.0, seconds)
	t.tween_property(env, "ambient_light_energy", 0.7 if on else 0.42, seconds)
	for light in _lamp_lights:
		light.visible = true
		t.tween_property(light, "light_energy", LAMP_ENERGY if on else 0.0, seconds)
	krampus.set_dark(not on)


# --- Sacks ---

func _add_sacks() -> void:
	for i in L.SACKS.size():
		var sack := ElfSack.new(i)
		add_child(sack)
		sack.global_position = L.SACKS[i]
		sack.hang(L.BELFRY_Y)
		sacks.append(sack)


# --- Little effects ---

func _make_parry_ring() -> MeshInstance3D:
	var b := ToyBuilder.new()
	b.add(ToyBuilder.torus(0.55, 0.035, 32, 6), Color(1.0, 0.85, 0.45), ToyBuilder.xf(Vector3.ZERO, Vector3(90, 0, 0)), true)
	var ring := b.build(0.0, "ParryRing")
	ring.position = Vector3(0, 1.2, 0.55)
	ring.visible = false
	return ring


## Santa raises his guard: a brief golden ring in front of him.
func _guard_fx() -> void:
	_parry_ring.visible = true
	_parry_ring.scale = Vector3.ONE * 0.6
	var t := create_tween()
	t.tween_property(_parry_ring, "scale", Vector3.ONE, 0.08)
	t.tween_interval(ParryGuard.ACTIVE * guard.gentleness - 0.08)
	t.tween_callback(func() -> void: _parry_ring.visible = false)


## A blow turned aside: the ring flares and the chain or claws ring off it.
func _parried_fx(caught: bool) -> void:
	_parry_ring.visible = true
	_parry_ring.scale = Vector3.ONE * 1.6
	var t := create_tween()
	t.tween_property(_parry_ring, "scale", Vector3.ONE * 0.3, 0.3)
	t.tween_callback(func() -> void: _parry_ring.visible = false)
	Audio.play_sfx("ring", 1.6 if caught else 1.2, 0.0)
	_flash.color = Color(1.0, 0.9, 0.6, 0.25)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)


func _shake(amount: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var t := create_tween()
	for k in 6:
		var fade := amount * (1.0 - k / 6.0)
		t.tween_property(camera, "h_offset", randf_range(-fade, fade) * 0.3, 0.04)
		t.parallel().tween_property(camera, "v_offset", randf_range(-fade, fade) * 0.3, 0.04)
	t.tween_property(camera, "h_offset", 0.0, 0.05)
	t.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


func _cut_to(from: Vector3, look: Vector3) -> void:
	if _cut_camera == null:
		_cut_camera = Camera3D.new()
		_cut_camera.name = "CutCamera"
		_cut_camera.fov = 55.0
		add_child(_cut_camera)
	_cut_camera.global_position = from
	_cut_camera.look_at(look)
	_cut_camera.make_current()


func _freeze_demons(on: bool) -> void:
	for demon: Node in get_tree().get_nodes_in_group("demons"):
		demon.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _fade_to(alpha: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, seconds)
	await t.finished


# --- Barks and HUD ---

func _bark(key: String) -> void:
	if _busy and Dialogue.is_playing():
		return
	Dialogue.play(Dialogue.lines("l2", key), "bark")


func _say_once(key: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	_bark(key)


## Says `key` the first `times` times it comes up.
func _bark_every(key: String, times: int) -> void:
	var count: int = _said.get(key, 0)
	if count >= times:
		return
	_said[key] = count + 1
	_bark(key)


func _update_hud_mode() -> void:
	var flying := stage == "flight"
	_rings.visible = flying
	_controls.visible = flying
	_health_bar.get_parent().visible = not flying
	_boss_box.visible = stage == "boss"
	_tally.visible = stage in ["sacks", "settled"]
	_update_goal()


func _update_goal() -> void:
	match stage:
		"flight", "landing":
			_goal.text = "Fly to the village"
		"street", "arrival":
			_goal.text = "Fight your way up to the church square"
		"sacks", "settled":
			_goal.text = "Free the elves before they're carried over the bridge"
		"boss":
			_goal.text = "Ring the church bells" if not lit else "Block his chain, then slam him"
		_:
			_goal.text = ""


func _update_hud() -> void:
	if _goal == null:
		return
	if stage == "flight":
		_rings.text = "Rings: %d / %d" % [course.passed, FlightCourse.RINGS.size()]
		return
	_health_bar.max_value = _max_health
	_health_bar.value = health
	_tally.text = "Elves freed: %d    Sacks lost: %d / %d" % [sacks_run.ringers(), sacks_run.count(SackRun.Sack.LOST), SackRun.LOST_LIMIT]
	if fight and stage == "boss":
		_boss_bar.value = fight.health
		_boss_state.text = "Mortal: the bells are ringing!" if fight.lit else "In the dark, nothing hurts him"
		_update_goal()
	var use := _usable()
	var text := ""
	match "" if use.is_empty() else str(use[0]):
		"sack":
			text = "E: untie the sack"
		"bells":
			text = "E: ring the bells (%d elves at the ropes)" % sacks_run.ringers()
	if fight and fight.state == KrampusFight.State.CAUGHT:
		text = "You've got the chain!  Attack: SLAM HIM!"
	_prompt.text = text


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0, 0, 0, 0)
	layer.add_child(_flash)

	var box := VBoxContainer.new()
	box.position = Vector2(18, 14)
	layer.add_child(box)
	var health_box := VBoxContainer.new()
	box.add_child(health_box)
	var title := _label(18)
	title.text = "Santa"
	health_box.add_child(title)
	_health_bar = _bar(Color("e2493f"), Vector2(240, 16))
	health_box.add_child(_health_bar)
	_goal = _label(18)
	box.add_child(_goal)
	_tally = _label(18)
	box.add_child(_tally)
	_rings = _label(20)
	box.add_child(_rings)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position.y = 16
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_boss_box)
	var name_label := _label(20)
	name_label.text = "Krampus"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(name_label)
	_boss_bar = _bar(Color("b0302c"), Vector2(360, 18))
	_boss_bar.max_value = KrampusFight.SLAMS
	_boss_box.add_child(_boss_bar)
	_boss_state = _label(16)
	_boss_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_state)

	_controls = _label(16)
	_controls.text = "A / D and mouse: steer within the lane    W / S: speed    Shift: boost"
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.position = Vector2(18, -40)
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_controls)

	_prompt = _label(22)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 150
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_prompt)

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	layer.add_child(_fade)
	_update_hud_mode()


func _bar(fill_colour: Color, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = size
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.05, 0.06, 0.8)
	back.set_corner_radius_all(8)
	back.set_border_width_all(2)
	back.border_color = Color(1.0, 0.85, 0.7, 0.5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_colour
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


func debug_text() -> String:
	var extra := "  ·  stage %s  ·  health %.1f  ·  freed %d lost %d" % [stage, health, sacks_run.ringers(), sacks_run.count(SackRun.Sack.LOST)]
	if fight:
		extra += "  ·  krampus %d %s %s" % [fight.health, KrampusFight.State.keys()[fight.state], "lit" if fight.lit else "dark"]
	return super.debug_text() + extra


# --- Building ---

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a6aa8")
	env.ambient_light_energy = 0.42
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
	env.fog_light_color = Color("2c3466")
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 900.0
	dome_mesh.height = 1800.0
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
	moon.light_color = Color("c4d0ff")
	moon.light_energy = 1.3
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	moon.look_at_from_position(Vector3(8, 10, 6), Vector3.ZERO)
	add_child(GraphicsQuality.new(env, moon))
