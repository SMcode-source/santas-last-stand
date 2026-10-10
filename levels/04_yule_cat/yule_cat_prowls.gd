extends LevelBase
## Level 4, "The Yule Cat Prowls" (12 December): stealth.
##
## Grýla's valley in Iceland. The elves are caged in her cave at the top of
## the valley, and the thirteen Yule Lads keep watch for her, with the Yule
## Cat prowling the square. Santa sneaks up from the sleigh: Ctrl or C to
## creep (silent, and much harder to see), running is loud, and a snowball
## thump draws the Lads (and the Cat) away to look. Anyone seeing him fills
## the eye; full, the Cat comes and it's over.
##
## Grýla took a treasure from each of six Lads. Carry one where its owner
## can see it and he comes for it and stops watching; three back and the
## whole crew mutinies, and the old sheep track up the west side opens.
## Door-Slammer can be barred into his house while he's inside.
##
## The trick is in Grýla's first line: the Cat eats anyone except the ones
## in red caps. The Red Caps sleep in the barracks; sneak up and lift their
## caps. In the cave, the elves put on whatever caps Santa brought, Grýla
## wakes, and it's a run for the sleigh with six elves trotting behind and
## the Cat after them. It walks past capped elves; lose more than two and
## the chapter is lost. A snowball in its face holds it up for a moment.
##
## Checkpoints: "barracks" (first into the yard) and "cave". Testing:
## `-- --l4=<checkpoint>`, `--caps=N` (caps already taken), `--mutiny`.

const L := preload("res://levels/04_yule_cat/yule_layout.gd")
const SKY_SHADER := preload("res://core/visual/night_sky.gdshader")
const SKY_DOME_SHADER := preload("res://core/visual/night_sky_dome.gdshader")

## How far footsteps carry: running and walking (sneaking is silent).
const RUN_NOISE := 7.0
const WALK_NOISE := 2.5
const STEP_EVERY := 0.45
## A snowball bursting on something.
const THUMP_NOISE := 9.0
## How near something has to be to use it.
const REACH := 1.7
## A Red Cap sitting up with a shout.
const WAKE_JOLT := 0.5
const ELF_NAMES := ["Tinsel", "Nutmeg", "Sprocket", "Clove", "Bramble", "Figgy"]
const AURORA := 1.1

var stage := "intro"
var santa: SantaController
var meter := StealthMeter.new()
var crew: YuleLadCrew
var chase: CatChase
## Lad id -> YuleLad.
var lads := {}
var cat: YuleCat
var gryla: Gryla
var sleepers: Array[RedCapSleeper] = []
## Bunks whose caps Santa has.
var taken_caps: Array[int] = []
var elves: Array[ElfFigure] = []
var barred := false
var env: Environment
var moon: DirectionalLight3D

var _busy := false
var _said := {}
## Treasure name -> its pickup.
var _pickups := {}
var _step := 0.0
var _yard_reached := false
var _gate_leaves: Array[Node3D] = []
var _gate_body: StaticBody3D
var _slam_door: Node3D
var _bar: Node3D
var _cage_door: Node3D
var _cage_gap: CollisionShape3D
var _cut_camera: Camera3D
var _snowfall: MeshInstance3D
var _sleigh: Node3D
var _passed := {}

var _eye_bar: ProgressBar
var _goal: Label
var _tally: Label
var _carry: Label
var _prompt: Label
var _help: Label
var _fade: ColorRect
var _hud: Control


func _ready() -> void:
	super._ready()
	var started := Time.get_ticks_msec()
	var force_caps := -1
	var force_mutiny := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l4="):
			start_checkpoint = arg.get_slice("=", 1)
		elif arg.begins_with("--caps="):
			force_caps = arg.get_slice("=", 1).to_int()
		elif arg == "--mutiny":
			force_mutiny = true
	section = start_checkpoint if not start_checkpoint.is_empty() else "start"
	meter.gentleness = tuned(1.0, "timer")
	_restore(force_caps, force_mutiny)
	_build_environment()
	add_child(Baked.node("yule_valley_set"))
	_add_lanterns()
	_add_fires()
	_add_pickups()
	_add_sheep_gate()
	_add_slammer_door()
	_add_cage()
	_add_sleepers()
	_add_lads()
	cat = YuleCat.new(L.CAT_ROUTE, L.CAT_SITS)
	add_child(cat)
	cat.struck.connect(_on_cat_struck)
	gryla = Gryla.new()
	add_child(gryla)
	_sleigh = SleighPlaceholder.build()
	_sleigh.position = L.SLEIGH_PARK
	_sleigh.rotation.y = PI * 0.92
	add_child(_sleigh)
	_snowfall = WinterProps.snowfall(420, Vector3(-14, -5, -14), Vector3(28, 12, 28))
	_snowfall.mesh.custom_aabb = AABB(Vector3(-300, -60, -300), Vector3(600, 300, 600))
	add_child(_snowfall)
	_build_hud()
	match start_checkpoint:
		"barracks":
			_spawn_santa(Transform3D(Basis(Vector3.UP, PI * 0.5), L.YARD_GATE + Vector3(-1.6, 0, 0)))
			_yard_reached = true
			_start_sneak()
		"cave":
			_spawn_santa(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, L.CAVE_ENTRY_Z - 0.5)))
			_set_cave_scene()
			stage = "cave"
		_:
			_spawn_santa(Transform3D(Basis(Vector3.UP, PI), L.SANTA_START))
			_intro.call_deferred()
	_update_hud_mode()
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - started)
	print("Yule Cat Prowls built in %d ms" % Engine.get_meta("startup_ms"))


## The crew and the caps: fresh, or as saved at the checkpoint.
func _restore(force_caps: int, force_mutiny: bool) -> void:
	crew = YuleLadCrew.new()
	if not start_checkpoint.is_empty():
		var saved: Dictionary = GameState.data.checkpoint.get("state", {})
		if saved.get("checkpoint", "") == start_checkpoint:
			crew = YuleLadCrew.from_dict(saved.get("crew", {}))
			for i in saved.get("caps", []):
				taken_caps.append(int(i))
			barred = bool(saved.get("barred", false))
	if force_mutiny and not crew.mutiny:
		for treasure: String in ["spoon", "pot", "candle"]:
			crew.pick_up(treasure)
			crew.give_back(YuleLadCrew.TREASURES[treasure]["owner"])
	if force_caps >= 0:
		taken_caps.clear()
		for i in mini(force_caps, L.BUNKS.size()):
			taken_caps.append(i)


func _save_checkpoint(id: String) -> void:
	reach_checkpoint(id)
	GameState.data.checkpoint["state"] = {"checkpoint": id, "crew": crew.to_dict(), "caps": Array(taken_caps), "barred": barred}
	GameState.save_game()


func _spawn_santa(at: Transform3D) -> void:
	santa = SantaController.spawn(self, at, {"punch": false, "grab": false})
	santa.camera.snap()
	santa.snowballs.splashed.connect(_on_splash)


# --- The way in ---

func _intro() -> void:
	stage = "intro"
	_busy = true
	santa.input_enabled = false
	_show_hud(false)
	gryla.global_position = L.CLIFF_TOP
	gryla.rotation.y = 0.0
	cat.perch(L.CLIFF_TOP + Vector3(-3.0, 0, 0.3), 0.3)
	_cut_to(L.CLIFF_TOP + Vector3(2.8, 0.9, 8.5), L.CLIFF_TOP + Vector3(-1.3, 1.9, 0))
	await get_tree().create_timer(0.4).timeout
	await Dialogue.play(Dialogue.lines("l4", "intro"))
	# Grýla and the Cat go back down into the cave and the square.
	gryla.visible = false
	cat.position = L.CAT_ROUTE[0]
	cat.mode = YuleCat.Mode.PROWL
	santa.camera.make_current()
	santa.camera.snap()
	_show_hud(true)
	santa.input_enabled = true
	_busy = false
	_start_sneak()
	_bark("intro_help")


func _start_sneak() -> void:
	stage = "sneak"
	section = start_checkpoint if not start_checkpoint.is_empty() else "start"
	gryla.visible = false
	if cat.mode == YuleCat.Mode.PERCH:
		cat.position = L.CAT_ROUTE[0]
		cat.mode = YuleCat.Mode.PROWL
	if crew.mutiny:
		_open_gate(true)
	_update_hud_mode()


# --- Sneaking ---

func _physics_process(delta: float) -> void:
	if ended or santa == null:
		return
	match stage:
		"sneak":
			_update_sneak(delta)
		"cave":
			if santa.global_position.z > L.CLIFF_Z + 2.0:
				# Back out of the cave: carry on sneaking.
				stage = "sneak"
				_update_hud_mode()
		"chase":
			_update_chase(delta)


func _update_sneak(delta: float) -> void:
	var at := santa.global_position
	var sneaking := santa.is_sneaking()
	var sightings := {}
	if not _busy:
		for id: String in lads:
			var lad: YuleLad = lads[id]
			var seen := lad.watch(at, sneaking, crew.carries_for(id))
			if seen > 0.0:
				sightings[id] = seen
		var by_cat := cat.watch(at, sneaking)
		if by_cat > 0.0:
			sightings["cat"] = by_cat
	if meter.update(delta, sightings):
		_found()
		return
	if meter.level > 0.45:
		_say_once("cat_spot" if meter.last_source == "cat" else "lad_spot")
	if cat.global_position.distance_to(at) < 13.0:
		_say_once("cat_near")
	# Footsteps.
	var speed := Vector2(santa.velocity.x, santa.velocity.z).length()
	_step -= delta
	if speed > 0.3 and _step <= 0.0 and santa.is_on_floor():
		_step = STEP_EVERY
		if not sneaking:
			_noise(at, RUN_NOISE if speed > 3.0 else WALK_NOISE, speed > 3.0)
	# The sleepers.
	for sleeper in sleepers:
		var d := Vector2(sleeper.global_position.x - at.x, sleeper.global_position.z - at.z).length()
		sleeper.disturb(delta, d, speed > 3.0, sneaking or speed < 0.3)
	if not _yard_reached and L.in_yard(at):
		_yard_reached = true
		_save_checkpoint("barracks")
		_bark("barracks")
	if at.z < L.CAVE_ENTRY_Z:
		_enter_cave()


## Anyone in earshot turns to look. Only loud noises carry to the Cat.
func _noise(at: Vector3, radius: float, loud: bool) -> void:
	for lad: YuleLad in lads.values():
		lad.hear(at, radius)
	if loud:
		cat.hear(at, radius)


func _on_splash(at: Vector3) -> void:
	if stage == "sneak":
		_noise(at, THUMP_NOISE, true)


func _on_cat_struck() -> void:
	match stage:
		"chase":
			if chase.stun():
				cat.stagger()
				_bark_every("cat_stunned", 2)
		"sneak":
			cat.stagger()
			if meter.jolt(0.35, "cat"):
				_found()


func _on_sleeper_woke(_sleeper: RedCapSleeper) -> void:
	if stage != "sneak":
		return
	_bark("redcap_stir")
	if meter.jolt(WAKE_JOLT, "redcap"):
		_found()


## The eye is full: the Cat comes.
func _found() -> void:
	if stage != "sneak":
		return
	stage = "caught"
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	var at := santa.global_position
	var source := meter.last_source
	var reason := "The Yule Cat saw Santa, and pounced."
	if source == "redcap":
		reason = "A Red Cap woke up and yelled, and the Yule Cat came running."
	elif source != "cat":
		reason = "%s yelled, and the Yule Cat came running." % YuleLadCrew.lad_spec(source).get("english", "A Yule Lad")
	if cat.global_position.distance_to(at) > 9.0:
		var behind := -santa.facing.global_basis.z
		cat.position = at + Vector3(behind.x, 0, behind.z).normalized() * 6.0
	cat.pounce(at)
	await get_tree().create_timer(0.9).timeout
	fail(reason)


# --- Treasures, Lads and doors ---

func _on_lad_fetched(lad: YuleLad) -> void:
	if stage != "sneak":
		lad.resume()
		return
	var near := Vector2(lad.position.x - santa.global_position.x, lad.position.z - santa.global_position.z).length() < 2.2
	if not near or not crew.carries_for(lad.id):
		lad.resume()
		return
	_give_back(lad)


func _give_back(lad: YuleLad) -> void:
	var treasure := crew.give_back(lad.id)
	if treasure.is_empty():
		return
	lad.befriend()
	var english: String = YuleLadCrew.lad_spec(lad.id)["english"]
	if crew.mutiny:
		_mutiny()
	else:
		_bark_lines("returned_%d" % crew.returned, {"lad": english, "thing": YuleLadCrew.TREASURES[treasure]["name"]})
	_update_hud_mode()


func _mutiny() -> void:
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	meter.reset()
	for lad: YuleLad in lads.values():
		lad.befriend()
	await Dialogue.play(Dialogue.lines("l4", "mutiny"))
	_open_gate(false)
	santa.input_enabled = true
	_busy = false
	_update_hud_mode()


func _pick_up(treasure: String) -> void:
	if not crew.pick_up(treasure):
		return
	var pickup: Node3D = _pickups[treasure]
	var t := create_tween()
	t.tween_property(pickup, "scale", Vector3.ONE * 0.01, 0.25)
	t.tween_callback(pickup.queue_free)
	_pickups.erase(treasure)
	var owner := YuleLadCrew.lad_spec(YuleLadCrew.TREASURES[treasure]["owner"])
	_bark_lines("first_treasure" if crew.found.size() == 1 else "treasure", {"lad": owner["english"],
			"thing": YuleLadCrew.TREASURES[treasure]["name"]})
	_update_hud_mode()


func _on_slammer_in(_lad: YuleLad) -> void:
	_swing_door(true)


func _on_slammer_out(_lad: YuleLad) -> void:
	_swing_door(false)


func _bar_door() -> void:
	var lad: YuleLad = lads["door_slammer"]
	if not crew.shut_in("door_slammer"):
		return
	lad.shut_in()
	barred = true
	_bar.visible = true
	Audio.play_sfx("click", 0.7, 0.0)
	_bark("door_barred")


## Something Santa can use where he stands: [kind, target], or [] if none.
func _usable() -> Array:
	if _busy or ended or santa == null:
		return []
	var at := santa.global_position
	var near := func(p: Vector3, reach: float) -> bool:
		return Vector2(p.x - at.x, p.z - at.z).length() < reach and absf(p.y - at.y) < 2.5
	match stage:
		"sneak":
			for treasure: String in _pickups:
				if near.call((_pickups[treasure] as Node3D).global_position, REACH):
					return ["treasure", treasure]
			for i in sleepers.size():
				if not sleepers[i].cap_taken and near.call(sleepers[i].global_position + Vector3(-0.5, 0, 0), REACH + 0.2):
					return ["cap", i]
			for lad: YuleLad in lads.values():
				if crew.carries_for(lad.id) and lad.visible and near.call(lad.global_position, 2.0):
					return ["give", lad]
			var slammer: YuleLad = lads["door_slammer"]
			if slammer.is_indoors() and not barred and near.call(L.SLAMMER_DOOR, 2.0):
				return ["bar"]
		"cave":
			if near.call(L.HEADSHOT, 2.2):
				return ["headshot"]
			if near.call(L.CAGE + Vector3(0, 0, 1.4), 1.8):
				return ["cage"]
	return []


func _input(event: InputEvent) -> void:
	if santa == null or ended or _busy or event.is_echo():
		return
	if event.is_action_pressed("interact"):
		var use := _usable()
		if use.is_empty():
			return
		get_viewport().set_input_as_handled()
		match str(use[0]):
			"treasure":
				_pick_up(use[1])
			"cap":
				_take_cap(use[1])
			"give":
				_give_back(use[1])
			"bar":
				_bar_door()
			"headshot":
				_read_headshot()
			"cage":
				_free_elves()


func _take_cap(i: int) -> void:
	if not sleepers[i].take_cap():
		return
	taken_caps.append(i)
	santa.santa.wave()
	if taken_caps.size() == 1:
		_bark("cap_wont_fit")
	elif taken_caps.size() == L.BUNKS.size():
		_bark("caps_all")
	else:
		_bark_every("cap_taken", 2)
	_update_hud_mode()


# --- The cave ---

func _enter_cave() -> void:
	stage = "cave"
	_save_checkpoint("cave")
	_set_cave_scene()
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	await Dialogue.play(Dialogue.lines("l4", "cave_enter"))
	santa.input_enabled = true
	_busy = false
	_update_hud_mode()


## Grýla asleep in her chair, the Cat gone up to the clifftop.
func _set_cave_scene() -> void:
	section = "cave"
	meter.reset()
	gryla.visible = true
	gryla.sleep_in_chair(Transform3D(Basis(Vector3.UP, deg_to_rad(-20.0)), L.GRYLA_SEAT + Vector3(0, 0, 0.25)))
	cat.perch(L.CAT_LEAP, 0.0)


func _read_headshot() -> void:
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	await Dialogue.play(Dialogue.lines("l4", "headshot"))
	santa.input_enabled = true
	_busy = false


func _free_elves() -> void:
	stage = "freeing"
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	var swing := create_tween()
	swing.tween_property(_cage_door, "rotation:y", -1.9, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cage_gap.set_deferred("disabled", true)
	Audio.play_sfx("click", 0.5, 0.0)
	var caps := taken_caps.size()
	await Dialogue.play(_with(Dialogue.lines("l4", "free"), {"caps": str(caps)}))
	for i in elves.size():
		elves[i].wear_red_cap(i < caps)
	var key := "free_no_caps" if caps == 0 else ("free_few_caps" if caps < 4 else "free_caps")
	await Dialogue.play(_with(Dialogue.lines("l4", key), {"caps": str(caps)}))
	gryla.wake()
	_cut_to(L.GRYLA_SEAT + Vector3(-1.5, 2.6, 5.0), L.GRYLA_SEAT + Vector3(0, 2.4, 0))
	await Dialogue.play(Dialogue.lines("l4", "chase"))
	santa.camera.make_current()
	_start_chase()


func _start_chase() -> void:
	stage = "chase"
	section = "cave"
	chase = CatChase.new(taken_caps.size(), santa.global_position)
	for elf in elves:
		elf.top_level = true
	santa.input_enabled = true
	_busy = false
	_update_hud_mode()


func _update_chase(delta: float) -> void:
	chase.record(santa.global_position)
	if not chase.cat_on and chase.position_at(chase.last_elf_s()).z > L.CLIFF_Z + 1.0:
		chase.release_cat()
		cat.leap_down(chase.position_at(chase.cat_s))
		_bark("cat_leaps")
	for event in chase.update(delta):
		match str(event["kind"]):
			"snatched":
				_snatch(int(event["elf"]))
			"caught":
				_caught_in_chase()
				return
	if chase.failed():
		fail("The Yule Cat carried off %d of the elves." % chase.lost_count())
		return
	for i in elves.size():
		if chase.lost[i]:
			continue
		var s := chase.elf_s[i]
		var goal := chase.position_at(s)
		var elf := elves[i]
		var before := elf.global_position
		elf.global_position = before.lerp(goal, minf(1.0, delta * 12.0))
		var heading := chase.heading_at(s)
		elf.rotation.y = atan2(heading.x, heading.z)
		elf.stride(delta, before.distance_to(elf.global_position) / maxf(delta, 0.001))
		if chase.capped[i] and chase.cat_on and chase.cat_s > s and not _passed.has(i):
			_passed[i] = true
			_say_once("capped_pass")
	if chase.cat_on and cat.mode == YuleCat.Mode.CHASE:
		cat.follow(chase.position_at(chase.cat_s), chase.heading_at(chase.cat_s), chase.cat_speed)
	var at := santa.global_position
	if Vector2(at.x - L.SLEIGH_PARK.x, at.z - L.SLEIGH_PARK.z).length() < L.SLEIGH_REACH:
		_escape()


func _snatch(i: int) -> void:
	var elf := elves[i]
	var t := create_tween()
	t.tween_property(elf, "position:y", 1.4, 0.2)
	t.tween_property(elf, "scale", Vector3.ONE * 0.01, 0.25)
	t.tween_callback(func() -> void: elf.visible = false)
	_bark_lines("snatched", {"elf": ELF_NAMES[i]})


func _caught_in_chase() -> void:
	stage = "caught"
	santa.input_enabled = false
	cat.pounce(santa.global_position)
	await get_tree().create_timer(0.9).timeout
	fail("The Yule Cat caught up with Santa.")


## Santa's at the sleigh: Blitzen shakes his bells and the Cat bolts.
func _escape() -> void:
	stage = "outro"
	_busy = true
	santa.input_enabled = false
	santa.move_intent = Vector3.ZERO
	_show_hud(false)
	var saved := ElfFigure.new()
	saved.free()
	for i in elves.size():
		if not chase.lost[i]:
			var hop := create_tween()
			hop.tween_property(elves[i], "global_position", L.SLEIGH_PARK + Vector3(-0.6 + (i % 3) * 0.6, 0.9, -0.5 + (i / 3) * 0.7), 0.8)
	Audio.play_music_box(Audio.JINGLE_BELLS, 0.16, false)
	cat.bolt(Vector3(-4.0, 0, -36.0))
	_cut_to(L.SLEIGH_PARK + Vector3(5.0, 3.0, 6.0), L.SLEIGH_PARK + Vector3(-2.0, 1.0, -8.0))
	await get_tree().create_timer(0.8).timeout
	var kept := CatChase.ELVES - chase.lost_count()
	await Dialogue.play(_with(Dialogue.lines("l4", "outro"), {"kept": str(kept)}))
	complete()


# --- Barks ---

func _bark(key: String) -> void:
	_bark_lines(key, {})


## Plays conversation `key` as a bark, with {words} filled in.
func _bark_lines(key: String, words: Dictionary) -> void:
	if _busy and Dialogue.is_playing():
		return
	Dialogue.play(_with(Dialogue.lines("l4", key), words), "bark")


func _say_once(key: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	_bark(key)


func _bark_every(key: String, times: int) -> void:
	var count: int = _said.get(key, 0)
	if count >= times:
		return
	_said[key] = count + 1
	_bark(key)


## The steps with {word}s in their text replaced.
static func _with(steps: Array, words: Dictionary) -> Array:
	if words.is_empty():
		return steps
	var out := []
	for step: Dictionary in steps:
		var copy := step.duplicate(true)
		if copy.has("text"):
			copy["text"] = (copy["text"] as String).format(words)
		out.append(copy)
	return out


# --- Building the moving parts ---

func _add_lanterns() -> void:
	for at: Vector3 in L.LANTERNS:
		var lantern := WinterProps.lantern()
		lantern.position = YuleValleySet.lantern_hook(at)
		add_child(lantern)
		for light: Light3D in lantern.find_children("*", "Light3D", true, false):
			light.add_to_group(GraphicsQuality.LIGHTS_ABOVE_LOW)


func _add_fires() -> void:
	var yard := WinterProps.fire(0.9)
	yard.position = L.YARD_FIRE + Vector3(0, 0.05, 0)
	add_child(yard)
	var hearth := WinterProps.fire(0.8)
	hearth.position = L.CAULDRON + Vector3(0, 0.05, 0)
	add_child(hearth)
	# The hearth's glow filling the chamber, so the cave isn't pitch black.
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff9a52")
	glow.light_energy = 2.2
	glow.omni_range = 16.0
	glow.omni_attenuation = 0.8
	glow.position = L.CAULDRON + Vector3(-2.0, 3.5, 2.0)
	add_child(glow)
	for at: Vector3 in L.TORCHES:
		var torch := WinterProps.fire(0.35)
		torch.position = at
		add_child(torch)
		var b := ToyBuilder.new()
		b.finished(ToyBuilder.cylinder(0.05, 0.035, 0.6, 8), Color("4a3a2c"), "leather",
				ToyBuilder.xf(Vector3(0, -0.28, 0), Vector3(0, 0, 25.0 * signf(at.x))))
		b.finished(ToyBuilder.torus(0.06, 0.015, 10, 4), Color("2a2a2e"), "metal", ToyBuilder.xf(Vector3(0, -0.4, 0)))
		var stick := b.build(0.0, "Torch")
		stick.position = at
		add_child(stick)


## The six treasures Grýla took, each with a faint twinkle so they can be spotted.
func _add_pickups() -> void:
	for treasure: String in L.TREASURES:
		if treasure in crew.found:
			continue
		var node := Node3D.new()
		node.name = "Treasure_" + treasure
		node.position = L.TREASURES[treasure]
		node.add_child(_treasure_model(treasure))
		var glint := MeshInstance3D.new()
		glint.mesh = ToyBuilder.sphere(0.05, 8)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.92, 0.6)
		glint.material_override = glow
		glint.position = Vector3(0, 0.45, 0)
		node.add_child(glint)
		var t := glint.create_tween().set_loops()
		t.tween_property(glint, "scale", Vector3.ONE * 1.8, 0.5)
		t.tween_property(glint, "scale", Vector3.ONE * 0.4, 0.7)
		add_child(node)
		_pickups[treasure] = node


static func _treasure_model(treasure: String) -> MeshInstance3D:
	var b := ToyBuilder.new()
	var wood := Color("a07a52")
	match treasure:
		"spoon":
			b.finished(ToyBuilder.cylinder(0.012, 0.016, 0.42, 6), wood, "leather", ToyBuilder.xf(Vector3(0, 0.03, 0), Vector3(90, 30, 0)))
			b.finished(ToyBuilder.sphere(0.05, 10), wood, "leather", ToyBuilder.xf(Vector3(0.11, 0.03, 0.19), Vector3(0, 30, 0), Vector3(0.8, 0.3, 1.1)))
		"skyr":
			b.finished(ToyBuilder.cylinder(0.12, 0.1, 0.16, 14), wood, "leather", ToyBuilder.xf(Vector3(0, 0.08, 0)))
			b.finished(ToyBuilder.cylinder(0.11, 0.11, 0.01, 14), Color("f4f1ea"), "skin", ToyBuilder.xf(Vector3(0, 0.155, 0)))
		"candle":
			b.finished(ToyBuilder.cylinder(0.03, 0.03, 0.24, 8), Color("f2e8d0"), "skin", ToyBuilder.xf(Vector3(0, 0.12, 0)))
			b.finished(ToyBuilder.cylinder(0.07, 0.08, 0.03, 10), Color("8a6a3a"), "metal", ToyBuilder.xf(Vector3(0, 0.015, 0)))
		"pot":
			b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.14, 0.01), Vector2(0.17, 0.1), Vector2(0.15, 0.2),
					Vector2(0.13, 0.21)]), 14), Color("2a2a2c"), "metal")
		"bowl":
			b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.08, 0.0), Vector2(0.15, 0.06), Vector2(0.17, 0.12),
					Vector2(0.15, 0.12)]), 16), wood, "leather")
		"sausage":
			for k in 4:
				b.finished(ToyBuilder.capsule(0.035, 0.18, 8), Color("8a3a2a"), "skin",
						ToyBuilder.xf(Vector3(-0.2 + k * 0.13, 0.035, sin(k * 1.7) * 0.04), Vector3(0, 0, 90 + k * 8)))
	return b.build(0.0, "Model")


## The gate on the sheep track: two hurdles of planks, barred until the mutiny.
func _add_sheep_gate() -> void:
	var west := L.SHEEP_GATE.x - L.SHEEP_GATE_HALF + 0.3
	var east := L.SHEEP_GATE.x + L.SHEEP_GATE_HALF - 0.4
	var half := (east - west) / 2.0
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(west if side < 0.0 else east, 0, L.TRACK_SOUTH)
		var b := ToyBuilder.new()
		var dir := -side
		for y: float in [0.35, 0.8, 1.25]:
			b.textured(ToyBuilder.box(Vector3(half, 0.12, 0.05)), "brown_planks_04", ToyBuilder.xf(Vector3(dir * half / 2.0, y, 0)), 0.8,
					Color("8a6a52"), 0.6)
		for x: float in [0.1, half - 0.1]:
			b.textured(ToyBuilder.box(Vector3(0.1, 1.45, 0.06)), "brown_planks_04", ToyBuilder.xf(Vector3(dir * x, 0.75, 0)), 0.8, Color("6a5040"))
		var brace := atan2(0.9, half - 0.2)
		b.textured(ToyBuilder.box(Vector3(sqrt(0.81 + pow(half - 0.2, 2.0)), 0.1, 0.05)), "brown_planks_04",
				Transform3D(Basis(Vector3.BACK, brace * dir), Vector3(dir * half / 2.0, 0.8, 0.03)), 0.8, Color("6a5040"))
		hinge.add_child(b.build(0.0, "Leaf"))
		add_child(hinge)
		_gate_leaves.append(hinge)
	_gate_body = StaticBody3D.new()
	_gate_body.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(east - west, 2.5, 0.4)
	shape.shape = box
	_gate_body.add_child(shape)
	_gate_body.position = Vector3((west + east) / 2.0, 1.25, L.TRACK_SOUTH)
	add_child(_gate_body)
	# A chain and padlock on the latch.
	var lock := ToyBuilder.new()
	lock.finished(ToyBuilder.torus(0.08, 0.015, 12, 5), Color("2a2a2e"), "metal", ToyBuilder.xf(Vector3(0, 0.9, 0.06), Vector3(90, 0, 0)))
	lock.finished(ToyBuilder.box(Vector3(0.1, 0.12, 0.05)), Color("6a5a3a"), "metal", ToyBuilder.xf(Vector3(0, 0.8, 0.08)))
	var padlock := lock.build(0.0, "Padlock")
	padlock.name = "Padlock"
	padlock.position = Vector3((west + east) / 2.0, 0, L.TRACK_SOUTH)
	_gate_body.add_child(padlock)
	padlock.position = Vector3(0, -1.25, 0)


func _open_gate(instant: bool) -> void:
	if _gate_body == null or _gate_body.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	_gate_body.process_mode = Node.PROCESS_MODE_DISABLED
	_gate_body.visible = false
	for k in _gate_leaves.size():
		var angle := 1.8 * (1.0 if k == 0 else -1.0)
		if instant:
			_gate_leaves[k].rotation.y = angle
		else:
			create_tween().tween_property(_gate_leaves[k], "rotation:y", angle, 1.4).set_trans(Tween.TRANS_SINE)


## Door-Slammer's front door, hinged on its left, and the bar for it.
func _add_slammer_door() -> void:
	var spec: Array = L.HOUSES[L.SLAMMER_HOUSE]
	var base := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), spec[0])
	var front := float(spec[3]) / 2.0 + 0.16
	_slam_door = Node3D.new()
	_slam_door.name = "SlammerDoor"
	_slam_door.transform = base * Transform3D(Basis.IDENTITY, Vector3(-0.48, 0, front + 0.05))
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.box(Vector3(0.96, 1.85, 0.1)), "brown_planks_04", ToyBuilder.xf(Vector3(0.48, 0.93, 0)), 0.6, Color("4a2e24"))
	b.finished(ToyBuilder.sphere(0.04, 8), Color("25272b"), "metal", ToyBuilder.xf(Vector3(0.84, 0.95, 0.07)))
	for y: float in [0.4, 1.5]:
		b.finished(ToyBuilder.box(Vector3(0.8, 0.05, 0.02)), Color("25272b"), "metal", ToyBuilder.xf(Vector3(0.42, y, 0.06)))
	_slam_door.add_child(b.build(0.0, "Leaf"))
	add_child(_slam_door)
	var bar := ToyBuilder.new()
	bar.textured(ToyBuilder.box(Vector3(1.5, 0.14, 0.1)), "wood_trunk_wall", ToyBuilder.xf(Vector3(0, 1.0, 0.0), Vector3(0, 0, 8)), 1.0, Color("6a5040"))
	for x: float in [-0.68, 0.68]:
		bar.finished(ToyBuilder.box(Vector3(0.06, 0.24, 0.06)), Color("25272b"), "metal", ToyBuilder.xf(Vector3(x, 1.0 + x * 0.14, -0.02)))
	_bar = bar.build(0.0, "Bar")
	_bar.transform = base * Transform3D(Basis.IDENTITY, Vector3(0, 0, front + 0.22))
	_bar.visible = barred
	add_child(_bar)


## Swings the door open and bangs it shut (Door-Slammer, going in or out).
func _swing_door(going_in: bool) -> void:
	var t := create_tween()
	t.tween_property(_slam_door, "rotation:y", _slam_door.rotation.y + 1.6, 0.25)
	t.tween_interval(0.5 if going_in else 0.3)
	t.tween_property(_slam_door, "rotation:y", _slam_door.rotation.y, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		var near := santa != null and santa.global_position.distance_to(L.SLAMMER_DOOR) < 14.0
		Audio.play_sfx("click", 0.35, 0.0 if near else -10.0))


## The iron cage in the cave, with the six elves in it.
func _add_cage() -> void:
	var at := L.CAGE
	const W := 2.6
	const D := 2.2
	const H := 2.3
	var iron := Color("2a2a2e")
	var b := ToyBuilder.new()
	var bar := ToyBuilder.cylinder(0.025, 0.025, H, 6)
	var door_w := 1.2
	for side: Array in [[Vector3(-W / 2.0, 0, -D / 2.0), Vector3(W / 2.0, 0, -D / 2.0)], [Vector3(-W / 2.0, 0, -D / 2.0), Vector3(-W / 2.0, 0, D / 2.0)],
			[Vector3(W / 2.0, 0, -D / 2.0), Vector3(W / 2.0, 0, D / 2.0)], [Vector3(-W / 2.0, 0, D / 2.0), Vector3(-door_w / 2.0, 0, D / 2.0)],
			[Vector3(door_w / 2.0, 0, D / 2.0), Vector3(W / 2.0, 0, D / 2.0)]]:
		var a: Vector3 = side[0]
		var c: Vector3 = side[1]
		var count := maxi(1, int(a.distance_to(c) / 0.2))
		for k in count + 1:
			b.finished(bar, iron, "metal", ToyBuilder.xf(at + a.lerp(c, float(k) / count) + Vector3(0, H / 2.0, 0)))
		for y: float in [0.1, H - 0.05]:
			b.finished(ToyBuilder.box(Vector3(maxf(0.06, absf(c.x - a.x)), 0.06, maxf(0.06, absf(c.z - a.z)))), iron, "metal",
					ToyBuilder.xf(at + (a + c) / 2.0 + Vector3(0, y, 0)))
	for k in 7:
		b.finished(ToyBuilder.box(Vector3(W, 0.05, 0.05)), iron, "metal", ToyBuilder.xf(at + Vector3(0, H, -D / 2.0 + k * D / 6.0)))
	b.finished(ToyBuilder.box(Vector3(0.12, 0.2, 0.1)), Color("6a5a3a"), "metal", ToyBuilder.xf(at + Vector3(door_w / 2.0, 1.1, D / 2.0 + 0.06)))
	add_child(b.build(0.0, "Cage"))
	_cage_door = Node3D.new()
	_cage_door.name = "CageDoor"
	_cage_door.position = at + Vector3(-door_w / 2.0, 0, D / 2.0)
	var db := ToyBuilder.new()
	for k in 6:
		db.finished(bar, iron, "metal", ToyBuilder.xf(Vector3(0.1 + k * 0.2, H / 2.0, 0)))
	for y: float in [0.15, H / 2.0, H - 0.1]:
		db.finished(ToyBuilder.box(Vector3(door_w, 0.05, 0.05)), iron, "metal", ToyBuilder.xf(Vector3(door_w / 2.0, y, 0)))
	_cage_door.add_child(db.build(0.0, "Door"))
	add_child(_cage_door)
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.position = at
	for wall: Array in [[Vector3(0, H / 2.0, -D / 2.0), Vector3(W, H, 0.1)], [Vector3(-W / 2.0, H / 2.0, 0), Vector3(0.1, H, D)],
			[Vector3(W / 2.0, H / 2.0, 0), Vector3(0.1, H, D)], [Vector3(0, H / 2.0, D / 2.0), Vector3(W, H, 0.1)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		shape.position = wall[0]
		body.add_child(shape)
		_cage_gap = shape
	add_child(body)
	# The elves, huddled inside.
	for i in CatChase.ELVES:
		var elf := ElfFigure.new()
		elf.position = at + Vector3(-0.8 + (i % 3) * 0.8, 0, -0.45 + (i / 3) * 0.75)
		elf.rotation.y = randf_range(-0.4, 0.4)
		add_child(elf)
		elves.append(elf)


func _add_sleepers() -> void:
	for i in L.BUNKS.size():
		var sleeper := RedCapSleeper.new()
		sleeper.position = (L.BUNKS[i] as Vector3) + Vector3(0, L.BUNK_TOP, 0)
		add_child(sleeper)
		sleeper.restore(i in taken_caps)
		sleeper.woke.connect(_on_sleeper_woke)
		sleepers.append(sleeper)


func _add_lads() -> void:
	for spec: Dictionary in YuleLadCrew.LADS:
		var id: String = spec["id"]
		if not L.LADS.has(id):
			continue
		var lad := YuleLad.new(id, L.LADS[id], crew)
		lad.fetched.connect(_on_lad_fetched)
		if id == "door_slammer":
			lad.door = L.SLAMMER_DOOR
			lad.went_in.connect(_on_slammer_in)
			lad.came_out.connect(_on_slammer_out)
		add_child(lad)
		lads[id] = lad


# --- Camera, HUD ---

func _cut_to(from: Vector3, look: Vector3) -> void:
	if _cut_camera == null:
		_cut_camera = Camera3D.new()
		_cut_camera.name = "CutCamera"
		_cut_camera.fov = 55.0
		_cut_camera.far = 900.0
		add_child(_cut_camera)
	_cut_camera.global_position = from
	_cut_camera.look_at(look)
	_cut_camera.make_current()


func _process(delta: float) -> void:
	super._process(delta)
	var view := get_viewport().get_camera_3d()
	if view and _snowfall:
		var mat := _snowfall.mesh.surface_get_material(0) as ShaderMaterial
		mat.set_shader_parameter("box_min", view.global_position - Vector3(14, 5, 14))
		# No snow falls in the cave.
		var p := view.global_position
		_snowfall.visible = not (p.z < L.CLIFF_Z + 0.5 and absf(p.x) < L.CHAMBER.end.x and p.y < L.CHAMBER_HEIGHT)
	_update_hud()


func _show_hud(on: bool) -> void:
	if _hud:
		_hud.visible = on


func _update_hud_mode() -> void:
	if _goal == null:
		return
	var chasing := stage == "chase"
	_eye_bar.get_parent().visible = stage in ["sneak", "caught"]
	match stage:
		"intro", "sneak", "caught":
			if crew.mutiny:
				_goal.text = "The Lads are with you. Get to Grýla's cave at the head of the valley"
			elif taken_caps.is_empty():
				_goal.text = "Sneak up the valley to Grýla's cave"
			else:
				_goal.text = "Sneak up the valley to Grýla's cave"
		"cave", "freeing":
			_goal.text = "Open the cage"
		"chase", "outro":
			_goal.text = "Run for the sleigh!"
	_carry.visible = not chasing and not crew.carried.is_empty()
	var carrying := []
	for t: String in crew.carried:
		carrying.append(YuleLadCrew.TREASURES[t]["name"])
	_carry.text = "Carrying: " + ", ".join(carrying)


func _update_hud() -> void:
	if _goal == null:
		return
	_eye_bar.value = meter.level
	var fill := _eye_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color("f2d36b").lerp(Color("e2493f"), meter.level)
	if stage == "chase":
		var following := CatChase.ELVES - chase.lost_count()
		_tally.text = "Elves following: %d    Lost: %d (more than %d and it's over)" % [following, chase.lost_count(), CatChase.LOST_LIMIT]
	else:
		_tally.text = "Red caps: %d / %d    Treasures returned: %d / %d" % [taken_caps.size(), L.BUNKS.size(),
				crew.returned, YuleLadCrew.MUTINY_AT]
	var use := _usable()
	var text := ""
	match "" if use.is_empty() else str(use[0]):
		"treasure":
			text = "E: pick up %s" % YuleLadCrew.TREASURES[use[1]]["name"]
		"cap":
			text = "E: lift his red cap"
		"give":
			text = "E: give it back"
		"bar":
			text = "E: bar the door"
		"headshot":
			text = "E: look at the photograph"
		"cage":
			text = "E: open the cage"
	_prompt.text = text


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var box := VBoxContainer.new()
	box.position = Vector2(18, 14)
	_hud.add_child(box)
	var eye_box := HBoxContainer.new()
	box.add_child(eye_box)
	var eye := _label(18)
	eye.text = "Seen"
	eye_box.add_child(eye)
	_eye_bar = ProgressBar.new()
	_eye_bar.show_percentage = false
	_eye_bar.max_value = 1.0
	_eye_bar.custom_minimum_size = Vector2(240, 16)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.06, 0.1, 0.8)
	back.set_corner_radius_all(8)
	back.set_border_width_all(2)
	back.border_color = Color(1.0, 0.95, 0.8, 0.5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f2d36b")
	fill.set_corner_radius_all(8)
	_eye_bar.add_theme_stylebox_override("background", back)
	_eye_bar.add_theme_stylebox_override("fill", fill)
	eye_box.add_child(_eye_bar)
	_goal = _label(18)
	box.add_child(_goal)
	_tally = _label(18)
	box.add_child(_tally)
	_carry = _label(16)
	box.add_child(_carry)

	_help = _label(15)
	_help.text = "Ctrl / C: sneak    Shift: run (loud)    E: use    Click: throw a snowball (a thump they'll go and look at)"
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_top = -36
	_help.offset_left = 18
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_help)

	_prompt = _label(22)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 150
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud.add_child(_prompt)

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	layer.add_child(_fade)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


func debug_text() -> String:
	var extra := "  ·  stage %s  ·  seen %.2f (%s)  ·  caps %d  ·  returned %d%s" % [stage, meter.level, meter.last_source,
			taken_caps.size(), crew.returned, "  ·  MUTINY" if crew.mutiny else ""]
	if chase:
		extra += "  ·  lost %d  ·  cat %.1f m behind" % [chase.lost_count(), chase.santa_s - chase.cat_s]
	return super.debug_text() + extra


# --- The night ---

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("aurora_strength", AURORA)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a7aa8")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("26405a")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.12
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
	dome_mat.set_shader_parameter("aurora_strength", AURORA)
	dome_mat.set_shader_parameter("aurora_color", Color(0.2, 1.0, 0.55))
	dome_mesh.material = dome_mat
	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	dome.mesh = dome_mesh
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("bcd4ff")
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	moon.look_at_from_position(Vector3(-6, 10, 8), Vector3.ZERO)
	add_child(GraphicsQuality.new(env, moon))
