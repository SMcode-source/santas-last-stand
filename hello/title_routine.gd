extends Node
## Keeps Santa busy around the camp on the title screen: he says hello to the
## camera, walks over and splits a log at the chopping stump, comes back, then
## loads presents from a little pile into his sack, and round again.
## request_wave() makes him stop what he is doing, face the camera and wave.

const WALK_SPEED := 1.1
const TURN_SPEED := 3.2

var santa: SantaModel
## The axe resting in the stump, and where it rests (global).
var axe: Node3D
var axe_rest: Transform3D
## The log round on the stump and its two halves.
var log_whole: Node3D
var log_halves: Array[Node3D] = []
var sack: Node3D
var pile: Array[Node3D] = []
## Start with "chop" or "pack" instead of the greeting (for previews).
var start_at := ""

var _pile_rest: Array[Transform3D] = []
var _half_rest: Array[Transform3D] = []
var _sack_body: Node3D
var _wave_requested := false

const HOME := Vector3.ZERO
# Behind the stump, so he chops facing the camera, close enough to reach.
const CHOP_SPOT := Vector3(-2.46, 0, -3.06)
const PACK_SPOT := Vector3(1.65, 0, -1.2)


func _ready() -> void:
	await get_tree().process_frame
	axe_rest = axe.global_transform
	axe.top_level = true
	axe.global_transform = axe_rest
	for item in pile:
		_pile_rest.append(item.transform)
	for half in log_halves:
		_half_rest.append(half.transform)
	_sack_body = sack.get_node("Body")
	_run()


func request_wave() -> void:
	_wave_requested = true


func _run() -> void:
	if start_at == "chop":
		santa.position = CHOP_SPOT
		await _chop()
	elif start_at == "pack":
		santa.position = PACK_SPOT
		await _pack()
		_reset_log()
	while is_inside_tree():
		await _greet(7.0)
		await _walk([Vector3(-0.8, 0, -1.1), Vector3(-1.55, 0, -3.05), CHOP_SPOT])
		await _chop()
		_reset_pile()
		await _walk([Vector3(-1.55, 0, -3.05), Vector3(-0.7, 0, -1.0), HOME])
		await _greet(6.0)
		await _walk([Vector3(0.7, 0, -0.95), PACK_SPOT])
		await _pack()
		_reset_log()
		await _walk([Vector3(0.7, 0, -0.85), HOME])


## Stands facing the camera, fidgeting, for `seconds` (or until asked to wave).
func _greet(seconds: float) -> void:
	await _face(Vector3(santa.position.x, 0, 8.0))
	santa.fidget = true
	var left := seconds
	while left > 0.0:
		if _wave_requested:
			await _wave_now()
		left -= await _frame()
	santa.fidget = false
	santa.relax()


func _wave_now() -> void:
	_wave_requested = false
	santa.relax()
	await _face(Vector3(santa.position.x, 0, 8.0))
	santa.hop()
	santa.wave()
	await _wait(2.4)


## Walks through each point in turn, turning as he goes.
func _walk(points: Array) -> void:
	santa.fidget = false
	santa.relax()
	santa.play("Walking")
	for target: Vector3 in points:
		while true:
			if _wave_requested:
				santa.play("")
				await _wave_now()
				santa.play("Walking")
			var delta := await _frame()
			var to := target - santa.position
			to.y = 0.0
			if to.length() < 0.04:
				break
			_turn_toward(to, delta)
			var facing := Vector3(sin(santa.rotation.y), 0, cos(santa.rotation.y))
			var speed := WALK_SPEED * clampf(facing.dot(to.normalized()) * 1.5 - 0.5, 0.0, 1.0)
			santa.position += to.normalized() * minf(speed * delta, to.length())
	santa.play("")


## Turns on the spot to face `point`. While his hands are free he shuffles
## round with a few steps; with something in them he just pivots.
func _face(point: Vector3, stepping := true) -> void:
	var to := point - santa.position
	to.y = 0.0
	var goal := atan2(to.x, to.z)
	var stepped := false
	while absf(angle_difference(santa.rotation.y, goal)) > 0.03:
		if stepping and not stepped and absf(angle_difference(santa.rotation.y, goal)) > 0.5:
			santa.play("Walking")
			stepped = true
		_turn_toward(to, await _frame())
	if stepped:
		santa.play("")


func _turn_toward(direction: Vector3, delta: float) -> void:
	var goal := atan2(direction.x, direction.z)
	var diff := angle_difference(santa.rotation.y, goal)
	santa.rotation.y += clampf(diff, -TURN_SPEED * delta, TURN_SPEED * delta)


## Pulls the axe out of the stump, splits the log in three blows, and sets
## the axe back.
func _chop() -> void:
	var target := log_whole.global_position
	await _face(target)
	santa.axe_rest = axe_rest
	santa.perform("reach")
	await _wait(0.75)
	santa.hold(axe, "axe")
	santa.strike_point = target + Vector3(0, 0.36, 0)
	var swing: float = SantaModel.GESTURE_SECONDS["chop"]
	for blow in 3:
		santa.perform("chop")
		await _wait(swing * SantaModel.CHOP_IMPACT)
		_chips(target + Vector3(0, 0.34, 0))
		if blow == 2:
			_split_log()
		await _wait(swing * (1.0 - SantaModel.CHOP_IMPACT))
	santa.perform("reach")
	await _wait(0.6)
	santa.let_go()
	santa.strike_point = Vector3.INF
	santa.axe_rest = null
	axe.global_transform = axe_rest
	santa.relax()
	await _wait(0.5)


## Picks the presents up one at a time, from the top of the pile down, turns
## and drops each into the sack.
func _pack() -> void:
	var top_down := pile.duplicate()
	top_down.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y > b.global_position.y)
	for item: Node3D in top_down:
		if not item.visible:
			continue
		await _face(item.global_position)
		santa.perform("pick_up")
		await _wait(0.85)
		santa.hold(item, "box")
		santa.perform("carry")
		await _wait(0.4)
		await _face(sack.global_position, false)
		santa.perform("drop_in")
		await _wait(0.7)
		santa.let_go()
		var mouth := sack.global_position + Vector3(0, 0.8, 0)
		var drop := create_tween()
		drop.tween_property(item, "global_position", mouth, 0.25)
		drop.tween_property(item, "global_position", mouth + Vector3(0, -0.35, 0), 0.25)
		drop.parallel().tween_property(item, "scale", Vector3.ONE * 0.6, 0.25)
		drop.tween_callback(item.hide)
		var bulge := create_tween()
		bulge.tween_interval(0.4)
		bulge.tween_property(_sack_body, "scale", _sack_body.scale * Vector3(1.05, 1.04, 1.05), 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		santa.perform("carry")
		await _wait(0.5)
	santa.relax()
	await _wait(0.6)


func _split_log() -> void:
	log_whole.hide()
	for i in log_halves.size():
		var half := log_halves[i]
		var side := -1.0 if i == 0 else 1.0
		half.transform = _half_rest[i]
		half.show()
		var fall := create_tween().set_parallel()
		var basis := half.transform.basis
		var out := basis.x * side
		fall.tween_property(half, "position", half.position + out * 0.32 + Vector3(0, -0.3, 0), 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(half, "rotation", half.rotation + Vector3(0, 0, -side * PI / 2.0), 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _reset_log() -> void:
	log_whole.show()
	for i in log_halves.size():
		log_halves[i].hide()
		log_halves[i].transform = _half_rest[i]


func _reset_pile() -> void:
	for i in pile.size():
		pile[i].top_level = false
		pile[i].transform = _pile_rest[i]
		pile[i].scale = Vector3.ONE
		pile[i].show()
	_sack_body.scale = Vector3.ONE


## A burst of wood chips where the axe bites.
func _chips(at: Vector3) -> void:
	var chips := CPUParticles3D.new()
	chips.one_shot = true
	chips.amount = 14
	chips.lifetime = 0.9
	chips.explosiveness = 1.0
	chips.direction = Vector3.UP
	chips.spread = 70.0
	chips.initial_velocity_min = 1.2
	chips.initial_velocity_max = 2.4
	chips.gravity = Vector3(0, -9.8, 0)
	chips.angular_velocity_min = -600.0
	chips.angular_velocity_max = 600.0
	chips.scale_amount_min = 0.6
	chips.scale_amount_max = 1.2
	var chip := BoxMesh.new()
	chip.size = Vector3(0.035, 0.008, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d9b98c")
	mat.roughness = 0.9
	chip.material = mat
	chips.mesh = chip
	add_child(chips)
	chips.global_position = at
	chips.emitting = true
	get_tree().create_timer(1.5).timeout.connect(chips.queue_free)


## Waits one frame and returns how long it took.
func _frame() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
