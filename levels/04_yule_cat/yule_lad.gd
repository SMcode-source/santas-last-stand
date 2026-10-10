class_name YuleLad
extends Node3D
## One of the thirteen Yule Lads keeping watch for Grýla (a stand-in troll
## built from shapes until the Lads come from Meshy). Each keeps to his
## habit from the layout: standing at a post, walking a round, glancing up
## from his mischief now and then, sniffing at doorways, up on a roof.
##
## He sees in a cone (drawn on the snow, clipped by walls, and reddening as
## he notices Santa) and hears footsteps and thumps, and goes to look. The
## level asks watch() each frame how clearly he sees Santa. A Lad who sees
## Santa holding his own treasure doesn't raise the alarm: he comes over
## for it. Friendly Lads (treasure back, or after the mutiny) stop watching.

signal fetched(lad: YuleLad)
## Door-Slammer has gone into his house (the door bangs shut) or come out.
signal went_in(lad: YuleLad)
signal came_out(lad: YuleLad)

enum State {WATCH, BUSY, WALK, PAUSE, INVESTIGATE, LOOK_ROUND, FETCH, FRIENDLY, INDOORS, SHUT_IN}

const WALK_SPEED := 1.3
const TURN_RATE := 3.5
## The eye sits this high on a full-sized Lad.
const EYE := 1.42
const CONE_RAYS := 14
const INVESTIGATE_LOOK := 3.5
const INDOORS_TIME := 7.0
const OUTSIDE_TIME := 13.0
## Calm, curious and alarmed cone colours.
const CONE_CALM := Color(1.0, 0.78, 0.3, 0.36)
const CONE_SEEN := Color(1.0, 0.2, 0.1, 0.55)

var id := ""
var spec := {}
var crew: YuleLadCrew
var state := State.WATCH
var yaw := 0.0
## How strongly he saw Santa last frame (0 = not at all), for the cone.
var seeing := 0.0
var sight_range := 8.0
var half_angle := 45.0
## The door he comes and goes by (Door-Slammer).
var door := Vector3.INF

var _route: PackedVector3Array
var _loop := false
var _leg := 0
var _dir := 1
var _timer := 0.0
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _look := 0.0
var _glance := []
var _sweep := 0.0
var _time := 0.0
var _speed := WALK_SPEED
var _figure: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _cone: MeshInstance3D
var _cone_mesh: ImmediateMesh
var _cone_mat: StandardMaterial3D
var _cone_frame := 0
var _after_investigate := State.WATCH
var _door_timer := 0.0
var _candle_light: OmniLight3D


func _init(lad_id: String, lad_spec: Dictionary, lad_crew: YuleLadCrew) -> void:
	id = lad_id
	spec = lad_spec
	crew = lad_crew
	name = "Lad_" + lad_id
	sight_range = spec.get("range", 8.0)
	half_angle = spec.get("angle", 45.0)
	_look = deg_to_rad(spec.get("look", 0.0))
	_glance = spec.get("glance", [])
	_sweep = deg_to_rad(spec.get("sweep", 0.0))
	_speed = spec.get("speed", WALK_SPEED)
	if spec.has("route"):
		_route = PackedVector3Array(spec["route"])
		_loop = _route.size() > 2
		_home = _route[0]
		state = State.WALK
		_leg = 1
	else:
		_home = spec["post"]
	position = _home
	yaw = _look
	if _route.size() > 1:
		var ahead := _route[1] - _route[0]
		yaw = atan2(ahead.x, ahead.z)
	rotation.y = yaw
	_build_figure()
	scale = Vector3.ONE * float(spec.get("scale", 1.0))
	_build_cone()
	if spec.get("door", false):
		_door_timer = OUTSIDE_TIME


func _ready() -> void:
	if not crew.is_watching(id):
		_settle(crew.moods.get(id) == YuleLadCrew.Mood.SHUT_IN)


## Where his eyes are.
func eye_position() -> Vector3:
	if spec.has("height"):
		return Vector3(position.x, spec["height"], position.z)
	return position + Vector3.UP * EYE * scale.y


func is_watching() -> bool:
	return crew.is_watching(id) and state not in [State.BUSY, State.INDOORS, State.FRIENDLY, State.SHUT_IN]


func is_indoors() -> bool:
	return state == State.INDOORS


## How clearly he sees Santa at `santa_pos` (StealthMeter strength, 0 if
## not at all). `holding_mine`: Santa has his treasure, so he comes for it
## instead of shouting.
func watch(santa_pos: Vector3, sneaking: bool, holding_mine: bool) -> float:
	seeing = 0.0
	if not is_watching() and not (state == State.FETCH):
		return 0.0
	var target := santa_pos + Vector3.UP * (0.75 if sneaking else 1.25)
	var eye := eye_position()
	var distance := eye.distance_to(target)
	var flat := Vector2(santa_pos.x - position.x, santa_pos.z - position.z)
	var smelt := spec.has("smell") and flat.length() < float(spec["smell"])
	if not smelt:
		if distance > sight_range:
			return 0.0
		if flat.length() > 0.4:
			var facing := Vector2(sin(yaw), cos(yaw))
			if absf(rad_to_deg(facing.angle_to(flat))) > half_angle:
				return 0.0
		if not _clear(eye, target):
			return 0.0
	if holding_mine:
		if state != State.FETCH:
			state = State.FETCH
			_say_hm()
		_target = santa_pos
		return 0.0
	seeing = StealthMeter.strength(minf(distance, sight_range - 0.01), sight_range, sneaking)
	if smelt:
		seeing = maxf(seeing, StealthMeter.strength(flat.length(), float(spec["smell"]) * 2.0, sneaking))
	return seeing


## A noise of `radius` at `at`: footsteps or a snowball's thump. True if he
## heard it and turned to look.
func hear(at: Vector3, radius: float) -> bool:
	if not is_watching() or state == State.INVESTIGATE:
		return false
	var reach := radius * float(spec.get("hear", 9.0)) / 9.0
	if Vector2(at.x - position.x, at.z - position.z).length() > reach:
		return false
	_after_investigate = state
	state = State.INVESTIGATE
	_target = Vector3(at.x, position.y, at.z)
	# He only goes over if he can walk straight there; otherwise he stares.
	if spec.has("height") or not _clear(position + Vector3.UP * 0.8, _target + Vector3.UP * 0.8):
		_target = position
	else:
		_target = _target + (position - _target).normalized() * 1.2
	_timer = INVESTIGATE_LOOK
	_look_at_point(at)
	_say_hm()
	return true


## Back to his post or round (after looking into a noise, or when Santa
## wasn't where he went to fetch his treasure).
func resume() -> void:
	state = State.LOOK_ROUND
	_after_investigate = State.WATCH
	if not spec.has("route"):
		_target = _home
		return
	var best := 0
	for k in _route.size():
		if _route[k].distance_to(position) < _route[best].distance_to(position):
			best = k
	_leg = best
	_target = _route[best]


func _go_in() -> void:
	state = State.INDOORS
	_after_investigate = State.WATCH
	_timer = INDOORS_TIME
	visible = false
	went_in.emit(self)


## He has his treasure back, or the crew has mutinied: no more watching.
func befriend() -> void:
	if state == State.SHUT_IN:
		return
	if state == State.INDOORS:
		visible = true
		came_out.emit(self)
	_settle(false)
	var hop := create_tween()
	hop.tween_property(_figure, "position:y", 0.35, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(_figure, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Door-Slammer, barred in his own house.
func shut_in() -> void:
	_settle(true)


func _settle(locked_in: bool) -> void:
	state = State.SHUT_IN if locked_in else State.FRIENDLY
	_cone.visible = false
	seeing = 0.0
	if locked_in:
		visible = false
	elif spec.has("route") and not spec.has("height"):
		_target = position


func _physics_process(delta: float) -> void:
	_time += delta
	var moving := 0.0
	match state:
		State.WATCH:
			_turn_to(_look + sin(_time * 0.9) * _sweep, delta)
			_cycle_glance(delta, true)
		State.BUSY:
			_turn_to(deg_to_rad(spec.get("back", rad_to_deg(_look) + 180.0)), delta)
			_cycle_glance(delta, false)
		State.WALK:
			moving = _walk_route(delta)
		State.PAUSE:
			_timer -= delta
			_turn_to(yaw + sin(_time * 2.0) * 0.02, delta)
			if _timer <= 0.0:
				state = State.WALK
		State.INVESTIGATE:
			moving = _walk_to(_target, delta, _speed * (1.4 if spec.get("eager", false) else 1.0))
			if moving == 0.0:
				_timer -= delta
				_turn_to(yaw + sin(_time * 1.6) * 0.04, delta)
				if _timer <= 0.0:
					resume()
		State.LOOK_ROUND:
			moving = _walk_to(_target, delta, _speed)
			if moving == 0.0:
				if _after_investigate == State.INDOORS:
					_go_in()
				else:
					state = State.WALK if spec.has("route") else State.WATCH
					if spec.has("post"):
						position = Vector3(_home.x, position.y, _home.z)
		State.FETCH:
			moving = _walk_to(_target, delta, _speed * 1.3, 1.1)
			if moving == 0.0:
				fetched.emit(self)
		State.FRIENDLY:
			_turn_to(yaw, delta)
		State.INDOORS:
			_timer -= delta
			if _timer <= 0.0 and crew.is_watching(id):
				visible = true
				state = State.WALK
				_door_timer = OUTSIDE_TIME
				came_out.emit(self)
	if spec.get("door", false) and state in [State.WALK, State.PAUSE] and door != Vector3.INF:
		_door_timer -= delta
		if _door_timer <= 0.0:
			_target = door
			state = State.LOOK_ROUND
			_after_investigate = State.INDOORS
	rotation.y = yaw
	_animate(delta, moving)
	_cone_frame += 1
	if _cone.visible and _cone_frame % 3 == 0:
		_update_cone()


func _cycle_glance(delta: float, watching: bool) -> void:
	if _glance.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		state = State.BUSY if watching else State.WATCH
		_timer = float(_glance[1] if watching else _glance[0])


func _walk_route(delta: float) -> float:
	var goal := _route[_leg]
	var moved := _walk_to(goal, delta, _speed)
	if moved == 0.0:
		if _loop:
			_leg = (_leg + 1) % _route.size()
		else:
			if _leg + _dir >= _route.size() or _leg + _dir < 0:
				_dir = -_dir
			_leg += _dir
		state = State.PAUSE
		_timer = float(spec.get("turn", 1.0))
		var ahead := _route[_leg] - position
		yaw = _approach_angle(yaw, atan2(ahead.x, ahead.z), 0.6)
	return moved


## Steps towards `goal`; returns the speed moved (0 once there).
func _walk_to(goal: Vector3, delta: float, speed: float, stop := 0.08) -> float:
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	if to.length() <= stop:
		return 0.0
	var heading := atan2(to.x, to.z)
	_turn_to(heading, delta)
	# Turn most of the way before setting off.
	if absf(angle_difference(yaw, heading)) > 0.9:
		return 0.0001
	var step := minf(speed * delta, to.length() - stop * 0.5)
	position += to.normalized() * step
	return speed


func _turn_to(heading: float, delta: float) -> void:
	yaw = _approach_angle(yaw, heading, TURN_RATE * delta)


static func _approach_angle(from: float, to: float, step: float) -> float:
	var diff := angle_difference(from, to)
	return from + clampf(diff, -step, step)


func _look_at_point(at: Vector3) -> void:
	var to := at - position
	if Vector2(to.x, to.z).length() > 0.1:
		_look_target(atan2(to.x, to.z))


func _look_target(heading: float) -> void:
	yaw = _approach_angle(yaw, heading, 0.5)


func _clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _say_hm() -> void:
	var hop := create_tween()
	hop.tween_property(_figure, "position:y", 0.12, 0.08)
	hop.tween_property(_figure, "position:y", 0.0, 0.12)


# --- Looks ---

func _animate(delta: float, moving: float) -> void:
	var busy := state == State.BUSY
	if moving > 0.01:
		var swing := sin(_time * (5.0 + moving * 2.5))
		_figure.position.y = absf(swing) * 0.04
		_legs[0].rotation.x = swing * 0.5
		_legs[1].rotation.x = -swing * 0.5
		_arms[0].rotation.x = -swing * 0.4
		_arms[1].rotation.x = swing * 0.4
	else:
		for limb in _legs:
			limb.rotation.x = lerpf(limb.rotation.x, 0.0, minf(1.0, delta * 8.0))
		var reach := -1.1 if busy else 0.0
		if state == State.FRIENDLY:
			reach = -2.6 if fmod(_time, 6.0) < 1.2 else 0.0
		_arms[0].rotation.x = lerpf(_arms[0].rotation.x, reach + sin(_time * 9.0) * 0.25 * float(busy), minf(1.0, delta * 6.0))
		_arms[1].rotation.x = lerpf(_arms[1].rotation.x, reach * 0.8 if busy else 0.0, minf(1.0, delta * 6.0))
		if not _figure.position.y > 0.05:
			_figure.position.y = lerpf(_figure.position.y, 0.0, minf(1.0, delta * 8.0))
	# Bowl-Licker ducks down behind the barrels when he isn't looking.
	var duck := 0.55 if busy and spec.get("hide", false) else 1.0
	_figure.scale.y = lerpf(_figure.scale.y, duck, minf(1.0, delta * 6.0))
	if _cone_mat:
		var want := CONE_CALM.lerp(CONE_SEEN, clampf(seeing * 1.5, 0.0, 1.0))
		_cone_mat.albedo_color = _cone_mat.albedo_color.lerp(want, minf(1.0, delta * 8.0))
		_cone.visible = is_watching() or state == State.FETCH
	if _candle_light:
		_candle_light.light_energy = 0.9 + sin(_time * 13.0) * 0.08 + sin(_time * 7.3) * 0.06


## A shaggy troll in a wool jumper and sheepskin shoes, with a big nose and
## a beard like a haystack. Each Lad gets his own colours.
func _build_figure() -> void:
	_figure = Node3D.new()
	_figure.name = "Figure"
	add_child(_figure)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var wool: Color = [Color("8a8580"), Color("6b5544"), Color("b8a888"), Color("4f4a46"), Color("7a6a58"), Color("5b5f66")][rng.randi() % 6]
	var yoke: Color = [Color("e8e0d0"), Color("3a3532"), Color("a8402e"), Color("d8c8a0")][rng.randi() % 4]
	var skin := Color("d4a088").lerp(Color("b98a72"), rng.randf())
	var hair := [Color("6e6258"), Color("8a7a66"), Color("a59a8c"), Color("4a3e34")][rng.randi() % 4] as Color
	var b := ToyBuilder.new()
	# A lumpy jumper with a patterned yoke, and patched breeches.
	b.finished(ToyBuilder.lumpy(ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.68), Vector2(0.26, 0.7), Vector2(0.3, 0.85),
			Vector2(0.31, 1.05), Vector2(0.27, 1.25), Vector2(0.17, 1.33), Vector2(0.0, 1.35)]), 14), 0.02, 6.0, rng.randi_range(1, 9)),
			wool, "velvet")
	b.finished(ToyBuilder.torus(0.21, 0.05, 16, 6), yoke, "velvet", ToyBuilder.xf(Vector3(0, 1.27, 0), Vector3.ZERO, Vector3(1, 0.7, 1)))
	b.finished(ToyBuilder.torus(0.27, 0.02, 16, 5), yoke, "velvet", ToyBuilder.xf(Vector3(0, 0.74, 0)))
	b.finished(ToyBuilder.cylinder(0.25, 0.27, 0.12, 14), Color("3a3430"), "velvet", ToyBuilder.xf(Vector3(0, 0.66, 0)))
	# The head: ruddy, a big nose, little eyes under heavy brows.
	var nose := 0.075 if id != "doorway_sniffer" else 0.11
	b.finished(ToyBuilder.sphere(0.15, 14), skin, "skin", ToyBuilder.xf(Vector3(0, 1.5, 0.02), Vector3.ZERO, Vector3(1, 1.08, 1)))
	b.finished(ToyBuilder.sphere(nose, 10), skin.lerp(Color("c86a5a"), 0.35), "skin",
			ToyBuilder.xf(Vector3(0, 1.48, 0.17 + nose * 0.4), Vector3(-15, 0, 0), Vector3(0.9, 0.9, 1.3)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.sphere(0.018, 6), Color("1a1410"), "eye", ToyBuilder.xf(Vector3(side * 0.055, 1.54, 0.14)))
		b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.04, 8), 0.3, 30.0, 2), hair, "hair",
				ToyBuilder.xf(Vector3(side * 0.06, 1.585, 0.135), Vector3(0, 0, side * 12), Vector3(1.3, 0.5, 0.7)))
		b.finished(ToyBuilder.sphere(0.05, 8), skin, "skin", ToyBuilder.xf(Vector3(side * 0.15, 1.5, 0.0), Vector3.ZERO, Vector3(0.5, 1.0, 0.8)))
	# Beard and hair like a haystack.
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.17, 12), 0.25, 12.0, rng.randi_range(1, 30)), hair, "hair",
			ToyBuilder.xf(Vector3(0, 1.36, 0.1), Vector3(20, 0, 0), Vector3(0.95, 1.1, 0.7)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.165, 12), 0.2, 10.0, rng.randi_range(1, 30)), hair, "hair",
			ToyBuilder.xf(Vector3(0, 1.57, -0.03), Vector3.ZERO, Vector3(1.05, 0.85, 1.05)))
	# A knitted cap on some.
	if rng.randf() < 0.6:
		b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 1.6, -0.01), Vector3(0, 1.72, -0.03), Vector3(0, 1.79, -0.1)]),
				PackedFloat32Array([0.155, 0.1, 0.02]), 12, 4), yoke if rng.randf() < 0.5 else wool.darkened(0.3), "velvet")
	if id == "candle_stealer":
		_candle_light = OmniLight3D.new()
		_candle_light.light_color = Color("ffb35c")
		_candle_light.omni_range = 4.0
		_candle_light.position = Vector3(0.3, 1.25, 0.35)
		_figure.add_child(_candle_light)
	_figure.add_child(b.build(0.0, "Body"))
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, 0.66, 0)
		_figure.add_child(leg)
		var lb := ToyBuilder.new()
		lb.finished(ToyBuilder.cylinder(0.075, 0.085, 0.58, 10), Color("3e3833"), "velvet", ToyBuilder.xf(Vector3(0, -0.3, 0)))
		lb.finished(ToyBuilder.lumpy(ToyBuilder.sphere(0.1, 10), 0.1, 8.0, 3), Color("c9b48e"), "leather",
				ToyBuilder.xf(Vector3(0, -0.6, 0.05), Vector3.ZERO, Vector3(0.9, 0.55, 1.5)))
		leg.add_child(lb.build(0.0, "Leg"))
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.3, 1.27, 0)
		_figure.add_child(arm)
		var ab := ToyBuilder.new()
		ab.finished(ToyBuilder.tube(PackedVector3Array([Vector3.ZERO, Vector3(side * 0.06, -0.28, 0.02), Vector3(side * 0.07, -0.55, 0.06)]),
				PackedFloat32Array([0.07, 0.06, 0.055]), 8), wool, "velvet")
		ab.finished(ToyBuilder.sphere(0.06, 8), skin, "skin", ToyBuilder.xf(Vector3(side * 0.07, -0.62, 0.07)))
		if side > 0.0 and id == "candle_stealer":
			ab.finished(ToyBuilder.cylinder(0.02, 0.02, 0.18, 8), Color("f2e8d0"), "skin", ToyBuilder.xf(Vector3(0.07, -0.53, 0.14)))
			ab.add(ToyBuilder.sphere(0.018, 6), Color(1.0, 0.75, 0.35), ToyBuilder.xf(Vector3(0.07, -0.41, 0.14), Vector3.ZERO, Vector3(1, 1.8, 1)), true)
		if side > 0.0 and id == "meat_hook":
			ab.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0.07, -0.62, 0.1), Vector3(0.07, -0.8, 0.12), Vector3(0.07, -0.88, 0.04),
					Vector3(0.07, -0.82, -0.04)]), PackedFloat32Array([0.014, 0.012, 0.01, 0.006]), 6, 4), Color("6a6d72"), "metal")
		arm.add_child(ab.build(0.0, "Arm"))
		_arms.append(arm)


# --- The vision cone ---

func _build_cone() -> void:
	_cone_mesh = ImmediateMesh.new()
	_cone = MeshInstance3D.new()
	_cone.name = "Cone"
	_cone.mesh = _cone_mesh
	_cone.top_level = true
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.vertex_color_use_as_albedo = true
	_cone_mat.albedo_color = CONE_CALM
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.no_depth_test = false
	_cone.material_override = _cone_mat
	add_child(_cone)


## Redraws the fan on the snow, each ray cut short where a wall blocks it.
func _update_cone() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var origin := Vector3(position.x, 0.06, position.z)
	var eye := eye_position()
	var reach := sight_range
	if spec.has("height"):
		reach = sqrt(maxf(0.0, sight_range * sight_range - eye.y * eye.y))
	var ends := PackedVector3Array()
	for k in CONE_RAYS + 1:
		var a := yaw + deg_to_rad(lerpf(-half_angle, half_angle, float(k) / CONE_RAYS))
		var dir := Vector3(sin(a), 0, cos(a))
		var far := origin + dir * reach
		var probe := Vector3(far.x, 0.9, far.z)
		var query := PhysicsRayQueryParameters3D.create(Vector3(eye.x, minf(eye.y, 1.2) if not spec.has("height") else eye.y, eye.z), probe,
				PhysicsLayers.WORLD)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var p: Vector3 = hit["position"]
			far = Vector3(p.x, 0.06, p.z)
		ends.append(far)
	_cone_mesh.clear_surfaces()
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in CONE_RAYS:
		_cone_mesh.surface_set_color(Color(1, 1, 1, 0.9))
		_cone_mesh.surface_add_vertex(origin)
		_cone_mesh.surface_set_color(Color(1, 1, 1, 0.15))
		_cone_mesh.surface_add_vertex(ends[k])
		_cone_mesh.surface_add_vertex(ends[k + 1])
	_cone_mesh.surface_end()
