class_name SleighController
extends CharacterBody3D
## The flying sleigh, for the on-rails intro, the race and the free-flight
## deliveries. Arcade handling: it cruises on its own, W and S (or the left
## stick) speed it up and slow it down, A and D turn it with a bank, the
## arrow keys, mouse or right stick pitch the nose, Shift boosts while the
## meter lasts, and Space held in a turn drifts: the sleigh slides wide, turns
## tighter and charges the boost meter.
##
## In rails mode (follow_rail) it runs along a Path3D on its own and the
## controls only shift it within a box round the line.
## The model is a placeholder until the real one arrives: set_visual(node).
## Tunables: data/balance/controllers.json, "sleigh".

signal boost_started
## It hit something, at this speed (it slows down).
signal bumped(at_speed: float)
## Rails mode reached the end of a path that does not loop.
signal rail_finished

enum Mode { FREE, RAILS }

## Half the size of the collision box (the sleigh's centre is its origin).
const HALF_SIZE := Vector3(0.8, 0.6, 1.6)

# --- Tunables: data/balance/controllers.json, "sleigh" ---
var cruise_speed := 20.0
var max_speed := 30.0
var min_speed := 8.0
var boost_speed := 44.0
var acceleration := 10.0
var braking := 16.0
var boost_acceleration := 30.0
## Meter used per second of boost (the meter runs from 0 to 1).
var boost_drain := 0.4
var boost_refill := 0.06
## Meter gained per second of drifting at full lock.
var drift_refill := 0.3
## Turn speed (radians a second), normally and while drifting.
var yaw_rate := 1.5
var drift_yaw_rate := 2.5
var pitch_rate := 2.5
var max_pitch_degrees := 40.0
var bank_degrees := 35.0
var drift_bank_degrees := 50.0
var bank_rate := 5.0
## How quickly the direction of travel follows the nose (low slides more).
var grip := 5.0
var drift_grip := 1.0
## Steering per pixel of mouse movement.
var mouse_steer := 0.004
var min_altitude := 1.8
var max_altitude := 70.0
## Keeps free flight within this distance of the origin (0 for no limit).
var bounds_radius := 0.0
## Speed kept after hitting something.
var bump_slowdown := 0.55
var rail_half_width := 7.0
var rail_half_height := 4.0
var rail_strafe_speed := 12.0

## Read the player's controls. Turn off to fly it from a script with the
## *_intent variables.
var input_enabled := true
## Left -1 to right 1.
var steer_intent := 0.0
## Down -1 to up 1.
var pitch_intent := 0.0
## Slow -1 to fast 1 (0 cruises).
var throttle_intent := 0.0
var boost_intent := false
var drift_intent := false

var mode := Mode.FREE
var speed := 0.0
## From 0 (empty) to 1 (full).
var boost_meter := 1.0
var boosting := false
var drifting := false
## Heading: 0 faces +z. Pitch: positive is nose up. Bank: positive rolls right.
var yaw := 0.0
var pitch := 0.0
var bank := 0.0
var rail: Path3D
var rail_progress := 0.0
var rail_loop := true
## Sideways and up from the rail line, in metres.
var rail_offset := Vector2.ZERO

## Banks and pitches with the flight; holds the model. Drawn smoothly between
## physics steps (the camera follows it).
var visual_root: Node3D
var model: Node3D
var camera: SleighCamera

var _travel := Vector3.BACK
var _rail_velocity := Vector2.ZERO
var _mouse_stick := Vector2.ZERO
var _bumping := false
var _prev_origin := Vector3.ZERO
var _origin := Vector3.ZERO
var _shape: CollisionShape3D


func _init() -> void:
	name = "Sleigh"
	Balance.apply(self, "controllers", "sleigh")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.SLEIGH
	collision_mask = PhysicsLayers.WORLD
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = HALF_SIZE * 2.0
	_shape.shape = box
	add_child(_shape)
	speed = cruise_speed


func _ready() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	visual_root.top_level = true
	add_child(visual_root)
	set_visual(SleighPlaceholder.build())
	camera = SleighCamera.new()
	camera.target = self
	add_child(camera)
	place(global_transform)


## Swaps the sleigh's model. `node` faces +z with its runners at y = 0.
func set_visual(node: Node3D) -> void:
	if model:
		model.queue_free()
	model = node
	node.position = Vector3(0.0, -HALF_SIZE.y, 0.0)
	visual_root.add_child(node)


## Puts the sleigh at `at` (its centre), level, facing its +z, at cruising speed.
func place(at: Transform3D) -> void:
	global_position = at.origin
	var ahead := at.basis.z
	yaw = atan2(ahead.x, ahead.z)
	pitch = 0.0
	bank = 0.0
	_travel = heading()
	speed = cruise_speed
	velocity = Vector3.ZERO
	_prev_origin = at.origin
	_origin = at.origin
	if visual_root:
		visual_root.global_transform = Transform3D(_attitude(), at.origin)
	if camera:
		camera.snap()


## Flies along `path` from `progress` metres in, offset within its box.
func follow_rail(path: Path3D, progress := 0.0, loop := true) -> void:
	rail = path
	rail_progress = progress
	rail_loop = loop
	rail_offset = Vector2.ZERO
	_rail_velocity = Vector2.ZERO
	mode = Mode.RAILS


## Back to free flight, carrying on from where it is.
func fly_free() -> void:
	mode = Mode.FREE


## Where the nose points.
func heading() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## Which way it is actually moving (lags the nose in a drift).
func travel_direction() -> Vector3:
	return _travel


func _physics_process(delta: float) -> void:
	if input_enabled:
		_read_input(delta)
	_update_speed(delta)
	if mode == Mode.RAILS and rail:
		_fly_rail(delta)
	else:
		_fly_free(delta)
	_update_bank(delta)
	_shape.rotation = Vector3(-pitch, yaw, 0.0)
	_prev_origin = _origin
	_origin = global_position


func _read_input(delta: float) -> void:
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_mouse_stick = _mouse_stick.lerp(Vector2.ZERO, 1.0 - exp(-delta * 5.0))
	steer_intent = clampf(stick.x + _mouse_stick.x, -1.0, 1.0)
	throttle_intent = -stick.y
	pitch_intent = clampf(Input.get_axis("camera_down", "camera_up") - _mouse_stick.y, -1.0, 1.0)
	boost_intent = Input.is_action_pressed("run")
	drift_intent = Input.is_action_pressed("jump")


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_stick += (event as InputEventMouseMotion).relative * mouse_steer
		_mouse_stick = _mouse_stick.clamp(-Vector2.ONE, Vector2.ONE)


func _update_speed(delta: float) -> void:
	var target := cruise_speed
	if throttle_intent > 0.0:
		target = lerpf(cruise_speed, max_speed, throttle_intent)
	elif throttle_intent < 0.0:
		target = lerpf(cruise_speed, min_speed, -throttle_intent)
	var was_boosting := boosting
	boosting = boost_intent and boost_meter > 0.0
	drifting = drift_intent and absf(steer_intent) > 0.2 and mode == Mode.FREE
	if boosting:
		target = boost_speed
		boost_meter -= boost_drain * delta
	else:
		boost_meter += boost_refill * delta
	if drifting:
		boost_meter += drift_refill * absf(steer_intent) * delta
		target *= 0.9
	boost_meter = clampf(boost_meter, 0.0, 1.0)
	if boosting and not was_boosting:
		boost_started.emit()
	var rate := boost_acceleration if boosting else (acceleration if target > speed else braking)
	speed = move_toward(speed, target, rate * delta)


func _fly_free(delta: float) -> void:
	yaw -= steer_intent * (drift_yaw_rate if drifting else yaw_rate) * delta
	var max_pitch := deg_to_rad(max_pitch_degrees)
	var pitch_goal := pitch_intent * max_pitch
	# Pull up near the ground and level off at the ceiling.
	var height := global_position.y
	if height < min_altitude + 3.0:
		pitch_goal = maxf(pitch_goal, lerpf(0.35, 0.0, (height - min_altitude) / 3.0))
	if height > max_altitude:
		pitch_goal = minf(pitch_goal, 0.0)
	pitch = move_toward(pitch, pitch_goal, pitch_rate * delta)
	_steer_home(delta)
	var nose := heading()
	_travel = _travel.slerp(nose, 1.0 - exp(-(drift_grip if drifting else grip) * delta)).normalized()
	velocity = _travel * speed
	move_and_slide()
	var hit := get_slide_collision_count() > 0
	if hit and not _bumping:
		bumped.emit(speed)
		speed *= bump_slowdown
	_bumping = hit
	global_position.y = maxf(global_position.y, min_altitude)


## Outside the bounds, turns gently back towards the middle.
func _steer_home(delta: float) -> void:
	if bounds_radius <= 0.0:
		return
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() < bounds_radius:
		return
	var home := atan2(-flat.x, -flat.y)
	yaw = lerp_angle(yaw, home, 1.0 - exp(-delta * 1.2))


func _fly_rail(delta: float) -> void:
	var curve := rail.curve
	var length := curve.get_baked_length()
	rail_progress += speed * delta
	if rail_loop:
		rail_progress = fposmod(rail_progress, length)
	elif rail_progress >= length:
		rail_progress = length
		rail_finished.emit()
		fly_free()
	var frame := rail.global_transform * curve.sample_baked_with_rotation(rail_progress, true, true)
	var ahead := -frame.basis.z.normalized()
	var right := frame.basis.x.normalized()
	var up := frame.basis.y.normalized()
	var wanted := Vector2(steer_intent, pitch_intent) * rail_strafe_speed
	_rail_velocity = _rail_velocity.lerp(wanted, 1.0 - exp(-delta * 6.0))
	rail_offset += _rail_velocity * delta
	rail_offset = rail_offset.clamp(Vector2(-rail_half_width, -rail_half_height), Vector2(rail_half_width, rail_half_height))
	global_position = frame.origin + right * rail_offset.x + up * rail_offset.y
	yaw = atan2(ahead.x, ahead.z)
	pitch = asin(clampf(ahead.y, -1.0, 1.0)) + _rail_velocity.y / rail_strafe_speed * 0.2
	_travel = ahead
	velocity = ahead * speed


func _update_bank(delta: float) -> void:
	var lean := steer_intent
	if mode == Mode.RAILS:
		lean = _rail_velocity.x / rail_strafe_speed
	var goal := lean * deg_to_rad(drift_bank_degrees if drifting else bank_degrees)
	bank = lerpf(bank, goal, 1.0 - exp(-bank_rate * delta))


## The sleigh's orientation: heading, then pitch, then roll.
func _attitude() -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, bank)


func _process(_delta: float) -> void:
	var at := _prev_origin.lerp(_origin, Engine.get_physics_interpolation_fraction())
	visual_root.global_transform = Transform3D(_attitude(), at)
