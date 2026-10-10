class_name ClockArena
extends Node3D
## The top of the Clock Tower: the boss arena. Three great clock gears turn
## round the central column, each under the nozzle of a hot pipe. Santa
## turns the crank on the column to swing the clock's hand from pipe to pipe;
## a hot pipe the hand reaches vents steam onto its gear. Jack Frost hops
## from gear to gear: steam on his gear melts his armour for a moment, and
## that is when a punch hurts him (see FrostFight for the rules).

signal shard_hit(amount: float)
signal frost_spoke(key: String)
signal defeated

const L := preload("res://levels/01_frozen_workshop/workshop_layout.gd")
const CRANK_REACH := 2.2
const HAND_Y := 2.6
const HAND_LENGTH := 5.4
const NOZZLE_Y := 3.9
const GEAR_SPIN := [0.22, -0.22, 0.18]
const SHARD_EVERY := [3.0, 2.4, 1.8]
const SHARD_SPEED := 10.0
const SHARD_COLD := 0.1

var fight: FrostFight
var frost: JackFrost
var santa: SantaController
var active := false
var pipes: Array[HeatPipe] = []

var _gears: Array[AnimatableBody3D] = []
var _steam: Array[CPUParticles3D] = []
var _hand: Node3D
var _crank: Node3D
var _marker: MeshInstance3D
var _shards: Array = []
var _shard_mesh: Mesh
var _shard_wait := 2.0
var _hand_angle := 0.0
var _gentle := 1.0


func _init(gentleness := 1.0) -> void:
	name = "ClockArena"
	_gentle = gentleness


func _ready() -> void:
	var top := L.TOWER + Vector3(0, L.TOWER_TOP, 0)
	for i in FrostFight.GEARS:
		_add_gear(i)
		_add_pipe(i)
	_add_column(top)
	_marker = _make_marker()
	add_child(_marker)
	var shard_b := ToyBuilder.new()
	shard_b.finished(ToyBuilder.cylinder(0.0, 0.09, 0.55, 5), Color("bfe8ff"), "eye", ToyBuilder.xf(Vector3.ZERO, Vector3(90, 0, 0)))
	_shard_mesh = shard_b.build(0.0).mesh
	frost = JackFrost.new()
	add_child(frost)
	frost.global_position = _gear_spot(0)
	frost.struck.connect(_on_frost_struck)
	frost.visible = false
	_hand_angle = L.GEAR_ANGLES[0]
	_place_hand()


## Starts the fight (Frost drops in from the sky).
func begin(seed := 1) -> void:
	fight = FrostFight.new(seed, _gentle)
	fight.hopped.connect(_on_hopped)
	fight.vented.connect(_on_vented)
	fight.armour_lost.connect(func(_s: float) -> void:
		frost.set_armoured(false)
		frost_spoke.emit("exposed"))
	fight.armour_back.connect(func() -> void:
		frost.set_armoured(true))
	fight.phase_won.connect(_on_phase_won)
	fight.defeated.connect(_on_defeated)
	frost.visible = true
	frost.global_position = _gear_spot(fight.frost_gear) + Vector3.UP * 12.0
	frost.hop_to(_gear_spot(fight.frost_gear))
	active = true


## Whether Santa is close enough to the crank to turn it.
func can_crank(at: Vector3) -> bool:
	return active and _crank.global_position.distance_to(at + Vector3.UP) < CRANK_REACH


## Santa turns the crank: the hand swings on to the next pipe.
func turn_crank() -> bool:
	if not active or not fight.crank():
		return false
	Audio.play_sfx("click", 0.7)
	var t := create_tween()
	t.tween_property(_crank, "rotation:z", _crank.rotation.z - TAU, FrostFight.SWING_TIME)
	return true


## Where Santa stands at the crank.
func crank_spot() -> Vector3:
	return L.TOWER + Vector3(0, L.TOWER_TOP + 0.05, 1.7)


func _physics_process(delta: float) -> void:
	for i in _gears.size():
		_gears[i].rotation.y += GEAR_SPIN[i] * delta
	if not active:
		return
	fight.update(delta)
	_update_hand()
	_update_marker()
	_update_shards(delta)


func _update_hand() -> void:
	var from: float = L.GEAR_ANGLES[fight.hand]
	var to: float = L.GEAR_ANGLES[(fight.hand + 1) % FrostFight.GEARS]
	var frac := fight.hand_position() - fight.hand
	if frac < 0.0:
		frac += FrostFight.GEARS
	_hand_angle = from + clampf(frac, 0.0, 1.0) * fposmod(to - from, 360.0)
	_place_hand()


func _place_hand() -> void:
	_hand.rotation.y = -deg_to_rad(_hand_angle)


## A frosty ring glows on the gear Frost means to hop to next.
func _update_marker() -> void:
	var warn := fight.next_hop < 1.3 and not fight.is_exposed()
	_marker.visible = warn
	if warn:
		_marker.global_position = L.gear_centre(fight.next_gear) + Vector3.UP * 0.03
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012)
		_marker.scale = Vector3(pulse, 1, pulse)


func _update_shards(delta: float) -> void:
	if frost.armoured and santa:
		_shard_wait -= delta
		if _shard_wait <= 0.0:
			_shard_wait = SHARD_EVERY[mini(fight.phase, 2)] * _gentle
			_throw_shard()
	var chest := santa.global_position + Vector3.UP * 1.0 if santa else Vector3.INF
	for shard: Array in _shards.duplicate():
		var mesh: MeshInstance3D = shard[0]
		var velocity: Vector3 = shard[1]
		shard[2] -= delta
		mesh.global_position += velocity * delta
		if mesh.global_position.distance_to(chest) < 0.75:
			shard_hit.emit(SHARD_COLD)
			Audio.play_sfx("click", 1.8)
			shard[2] = 0.0
		if shard[2] <= 0.0:
			_shards.erase(shard)
			mesh.queue_free()


func _throw_shard() -> void:
	var from := frost.global_position + Vector3.UP * 1.4
	var target := santa.global_position + Vector3.UP * 1.0 + santa.velocity * 0.3
	var dir := (target - from).normalized()
	var mesh := MeshInstance3D.new()
	mesh.mesh = _shard_mesh
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.global_position = from
	mesh.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_shards.append([mesh, dir * SHARD_SPEED, 3.0])
	frost.face(santa.global_position)


func _on_hopped(gear: int) -> void:
	frost.hop_to(_gear_spot(gear))
	if randf() < 0.3:
		frost_spoke.emit("hop")


func _on_vented(pipe: int, hit_frost: bool) -> void:
	Audio.play_sfx("ring", 0.5, -6.0)
	var steam := _steam[pipe]
	steam.emitting = true
	get_tree().create_timer(FrostFight.VENT_TIME + 0.3).timeout.connect(func() -> void: steam.emitting = false)
	if not hit_frost:
		frost_spoke.emit("missed")


func _on_frost_struck(hit: Dictionary) -> void:
	if not active:
		return
	if fight.strike():
		frost.reel(hit.get("direction", Vector3.FORWARD))
		Audio.play_sfx("bell", 0.8)
	else:
		Audio.play_sfx("click", 2.4)
		frost_spoke.emit("armoured")


func _on_phase_won(phase: int) -> void:
	var spent := fight.hand
	pipes[spent].cool()
	frost.set_armoured(true)
	if phase < FrostFight.GEARS:
		frost_spoke.emit("phase_%d" % phase)


func _on_defeated() -> void:
	active = false
	_marker.visible = false
	for shard: Array in _shards:
		(shard[0] as Node).queue_free()
	_shards.clear()
	defeated.emit()


## Where Frost stands on gear `i` (on its hub).
func _gear_spot(i: int) -> Vector3:
	return L.gear_centre(i) + Vector3(0, 0.16, 0)


# --- Building ---

func _add_gear(i: int) -> void:
	var gear := AnimatableBody3D.new()
	gear.name = "Gear%d" % i
	gear.collision_layer = PhysicsLayers.WORLD
	gear.collision_mask = 0
	var centre := L.gear_centre(i)
	gear.position = centre - Vector3(0, 0.2, 0)
	var b := ToyBuilder.new()
	var brass := Color("d2a85a") if i != 1 else Color("c0944a")
	var r := L.GEAR_RADIUS
	# The face is worn matt by boots (and reads in the moonlight); the teeth stay polished.
	b.finished(ToyBuilder.cylinder(r - 0.18, r - 0.18, 0.4, 40), brass, "leather")
	var teeth := 30
	for k in teeth:
		var a := TAU * k / teeth
		b.finished(ToyBuilder.box(Vector3(0.36, 0.38, 0.4)), brass, "metal",
				Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * (r - 0.02), 0, sin(a) * (r - 0.02))))
	# Spokes and holes read from above as a proper clock wheel: dark recesses.
	for k in 6:
		var a := TAU * k / 6.0 + 0.5
		b.add(ToyBuilder.cylinder(0.55, 0.55, 0.02, 16), Color("15120e"),
				ToyBuilder.xf(Vector3(cos(a) * 1.75, 0.2, sin(a) * 1.75)))
	b.finished(ToyBuilder.cylinder(0.5, 0.6, 0.18, 20), Color("4a3a22"), "metal", ToyBuilder.xf(Vector3(0, 0.27, 0)))
	# Frost creeping over the rim.
	b.finished(ToyBuilder.lumpy(ToyBuilder.torus(r - 0.35, 0.09, 40, 6), 0.04, 5.0, i + 3), Color("d6ecf8"), "eye",
			ToyBuilder.xf(Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.4, 1)))
	gear.add_child(b.build(0.0, "Mesh"))
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = r + 0.1
	cylinder.height = 0.4
	shape.shape = cylinder
	gear.add_child(shape)
	add_child(gear)
	_gears.append(gear)
	# The iron arm holding it out from the tower, and its axle.
	var d := L.direction(L.GEAR_ANGLES[i])
	var sb := ToyBuilder.new()
	var wall := L.TOWER + d * (L.TOWER_HALF - 0.1) + Vector3(0, L.TOWER_TOP - 2.6, 0)
	var axle := centre - Vector3(0, 0.6, 0)
	sb.finished(ToyBuilder.tube(PackedVector3Array([wall, axle]), PackedFloat32Array([0.16, 0.14]), 8), Color("2b2c30"), "metal")
	sb.finished(ToyBuilder.cylinder(0.22, 0.22, 0.5, 12), Color("2b2c30"), "metal", ToyBuilder.xf(axle + Vector3(0, 0.1, 0)))
	add_child(sb.build(0.0, "GearArm%d" % i))


func _add_pipe(i: int) -> void:
	var d := L.direction(L.GEAR_ANGLES[i])
	var top := L.TOWER_TOP
	var points := [
		L.TOWER + d * (L.TOWER_HALF - 0.05) + Vector3(0, top - 1.6, 0),
		L.TOWER + d * L.PIPE_OUT + Vector3(0, top - 1.6, 0),
		L.TOWER + d * L.PIPE_OUT + Vector3(0, top + NOZZLE_Y + 0.7, 0),
		L.TOWER + d * L.GEAR_OUT + Vector3(0, top + NOZZLE_Y + 0.7, 0),
		L.TOWER + d * L.GEAR_OUT + Vector3(0, top + NOZZLE_Y, 0),
	]
	var pipe := HeatPipe.new(points, 0.24)
	pipe.name = "TopPipe%d" % i
	add_child(pipe)
	pipes.append(pipe)
	var nozzle := L.TOWER + d * L.GEAR_OUT + Vector3(0, top + NOZZLE_Y, 0)
	var b := ToyBuilder.new()
	b.finished(ToyBuilder.cylinder(0.24, 0.5, 0.45, 16), Color("3a332c"), "metal", ToyBuilder.xf(nozzle - Vector3(0, 0.2, 0)))
	add_child(b.build(0.0, "Nozzle%d" % i))
	var steam := _make_steam()
	steam.position = nozzle - Vector3(0, 0.45, 0)
	add_child(steam)
	_steam.append(steam)


func _add_column(top: Vector3) -> void:
	var b := ToyBuilder.new()
	b.textured(ToyBuilder.cylinder(0.75, 0.9, HAND_Y - 0.1, 18), "old_stone_wall", ToyBuilder.xf(top + Vector3(0, (HAND_Y - 0.1) / 2.0, 0)),
			1.0, Color("cfc8bd"), 0.4)
	b.finished(ToyBuilder.cylinder(0.85, 0.85, 0.12, 18), Color("6b5a3c"), "metal", ToyBuilder.xf(top + Vector3(0, HAND_Y - 0.1, 0)))
	# The clock face painted on the tower top: a ring and twelve hour marks.
	b.add(ToyBuilder.torus(3.1, 0.06, 48, 4), Color("2a2622"), ToyBuilder.xf(top + Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1, 0.2, 1)))
	for k in 12:
		var a := TAU * k / 12.0
		var long := 0.6 if k % 3 == 0 else 0.3
		b.add(ToyBuilder.box(Vector3(long, 0.02, 0.1)), Color("2a2622"),
				Transform3D(Basis(Vector3.UP, -a), top + Vector3(cos(a) * 2.6, 0.08, sin(a) * 2.6)))
	add_child(b.build(0.0, "Column"))
	var solid := StaticBody3D.new()
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.85
	cylinder.height = HAND_Y
	shape.shape = cylinder
	shape.position = top + Vector3(0, HAND_Y / 2.0, 0)
	solid.add_child(shape)
	add_child(solid)

	# The hand, pivoting on the column top: a long arrow of black iron.
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = top + Vector3(0, HAND_Y, 0)
	add_child(_hand)
	var hb := ToyBuilder.new()
	var iron := Color("1c1c20")
	hb.finished(ToyBuilder.box(Vector3(HAND_LENGTH, 0.12, 0.22)), iron, "metal", ToyBuilder.xf(Vector3(HAND_LENGTH / 2.0, 0, 0)))
	hb.finished(ToyBuilder.box(Vector3(0.7, 0.12, 0.7)), iron, "metal", ToyBuilder.xf(Vector3(HAND_LENGTH - 0.2, 0, 0), Vector3(0, 45, 0)))
	hb.finished(ToyBuilder.box(Vector3(1.4, 0.12, 0.3)), iron, "metal", ToyBuilder.xf(Vector3(-0.6, 0, 0)))
	hb.finished(ToyBuilder.cylinder(0.3, 0.3, 0.22, 16), Color("8a7a55"), "metal")
	_hand.add_child(hb.build(0.0, "Mesh"))

	# The crank: an iron wheel on the column's south side, with a handle.
	_crank = Node3D.new()
	_crank.name = "Crank"
	_crank.position = top + Vector3(0, 1.15, 0.92)
	add_child(_crank)
	var cb := ToyBuilder.new()
	cb.finished(ToyBuilder.torus(0.38, 0.04, 20, 6), Color("6e2a1e"), "metal", ToyBuilder.xf(Vector3.ZERO, Vector3(90, 0, 0)))
	for k in 4:
		cb.finished(ToyBuilder.box(Vector3(0.74, 0.04, 0.04)), Color("6e2a1e"), "metal", ToyBuilder.xf(Vector3.ZERO, Vector3(0, 0, 45 * k)))
	cb.finished(ToyBuilder.cylinder(0.035, 0.035, 0.25, 8), Color("8a7a55"), "metal", ToyBuilder.xf(Vector3(0.38, 0, 0.12), Vector3(90, 0, 0)))
	cb.finished(ToyBuilder.cylinder(0.08, 0.08, 0.2, 10), Color("2b2c30"), "metal", ToyBuilder.xf(Vector3(0, 0, -0.06), Vector3(90, 0, 0)))
	_crank.add_child(cb.build(0.0, "Wheel"))


func _make_marker() -> MeshInstance3D:
	var b := ToyBuilder.new()
	b.add(ToyBuilder.torus(1.1, 0.07, 36, 6), Color(0.35, 0.75, 1.0), ToyBuilder.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.3, 1)), true)
	var marker := b.build(0.0, "NextGear")
	marker.visible = false
	return marker


func _make_steam() -> CPUParticles3D:
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.emitting = false
	steam.amount = 40
	steam.lifetime = 1.3
	steam.direction = Vector3.DOWN
	steam.spread = 18.0
	steam.initial_velocity_min = 3.5
	steam.initial_velocity_max = 5.0
	steam.gravity = Vector3(0, 1.5, 0)
	steam.damping_min = 1.5
	steam.damping_max = 2.5
	steam.scale_amount_min = 0.8
	steam.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.2))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	steam.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = WinterProps.soft_dot()
	mat.albedo_color = Color(0.9, 0.93, 0.97)
	quad.material = mat
	steam.mesh = quad
	return steam
