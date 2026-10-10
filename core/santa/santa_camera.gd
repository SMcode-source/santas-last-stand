class_name SantaCamera
extends Node3D
## The third-person camera behind Santa. It orbits with the mouse (captured
## on the first click), the right stick or the arrow keys, zooms with the
## wheel or the d-pad, and rides on a spring arm that pulls in rather than
## clipping through walls. It follows him closely sideways but eases
## vertically, so jumps do not jerk the view, and leads a little ahead of
## where he is going. Tunables: data/balance/controllers.json, "santa_camera".

var distance := 4.6
var min_distance := 2.0
var max_distance := 8.0
var zoom_step := 0.6
## Height above his feet that the camera looks at.
var pivot_height := 1.45
var mouse_sensitivity := 0.0025
## Turn speed with the stick or arrow keys (radians a second).
var stick_speed := 2.8
var pitch_min_degrees := -65.0
var pitch_max_degrees := 30.0
var follow_rate := 18.0
## Vertical follow rate while he is in the air (on the ground it is follow_rate).
var vertical_rate := 5.0
## How far ahead of him the view leads at full running speed (metres).
var look_ahead := 0.8
var look_ahead_rate := 2.5
var fov := 62.0

## What it follows (usually SantaController.facing, his drawn position).
var target: Node3D
## The body it follows, for its velocity and whether it is on the ground.
var body: CharacterBody3D
## Read the player's mouse, stick and keys. Off for cutscenes and demos.
var input_enabled := true
## Capture the mouse on click so moving it turns the view.
var capture_mouse := true
## Swing round behind him as he runs (for demos and cutscenes).
var auto_follow := false
## Around the vertical axis; 0 looks along -z.
var yaw := 0.0
## Up and down: negative looks down on him from above.
var pitch := -0.3

var spring: SpringArm3D
var camera: Camera3D
var _pivot := Vector3.ZERO
var _lead := Vector3.ZERO


func _init() -> void:
	name = "SantaCamera"
	top_level = true
	Balance.apply(self, "controllers", "santa_camera")
	spring = SpringArm3D.new()
	spring.name = "Spring"
	spring.collision_mask = PhysicsLayers.WORLD
	var ball := SphereShape3D.new()
	ball.radius = 0.25
	spring.shape = ball
	spring.margin = 0.1
	spring.spring_length = distance
	add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = fov
	spring.add_child(camera)


func _ready() -> void:
	if body:
		spring.add_excluded_object(body.get_rid())
	snap()


## Puts the camera straight behind `facing_yaw` (the way Santa faces, as a
## yaw where 0 faces +z), with no easing.
func look_behind(facing_yaw: float) -> void:
	yaw = facing_yaw + PI
	snap()


## Jumps to where it should be this frame, skipping the easing.
func snap() -> void:
	if target:
		_pivot = target.global_position + Vector3.UP * pivot_height
	_lead = Vector3.ZERO
	_place()


func make_current() -> void:
	camera.make_current()


## The flat directions the player means by "forward" and "right".
func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func flat_right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _process(delta: float) -> void:
	if input_enabled:
		var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		yaw -= look.x * stick_speed * delta
		pitch -= look.y * stick_speed * 0.7 * delta
	if auto_follow and body:
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if flat.length() > 1.0:
			var behind := atan2(flat.x, flat.z) + PI
			yaw = lerp_angle(yaw, behind, 1.0 - exp(-delta * 1.5))
	pitch = clampf(pitch, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
	if target:
		_follow(delta)
	_place()


func _follow(delta: float) -> void:
	var goal := target.global_position + Vector3.UP * pivot_height
	var grounded := body == null or body.is_on_floor()
	var lead_goal := Vector3.ZERO
	if body:
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		lead_goal = flat / 5.4 * look_ahead
		if lead_goal.length() > look_ahead:
			lead_goal = lead_goal.normalized() * look_ahead
	_lead = _lead.lerp(lead_goal, 1.0 - exp(-delta * look_ahead_rate))
	goal += _lead
	var side := 1.0 - exp(-delta * follow_rate)
	var up := 1.0 - exp(-delta * (follow_rate if grounded else vertical_rate))
	# Never let him leave the frame vertically, however the easing lags.
	_pivot = Vector3(lerpf(_pivot.x, goal.x, side), lerpf(_pivot.y, goal.y, up), lerpf(_pivot.z, goal.z, side))
	_pivot.y = clampf(_pivot.y, goal.y - 1.2, goal.y + 1.2)


func _place() -> void:
	global_position = _pivot
	spring.rotation = Vector3(pitch, yaw, 0.0)
	spring.spring_length = distance
	camera.fov = fov


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not camera.current:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * mouse_sensitivity
		pitch -= motion.relative.y * mouse_sensitivity
	elif event is InputEventMouseButton and event.pressed and not captured and capture_mouse:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("camera_zoom_in"):
		distance = maxf(min_distance, distance - zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		distance = minf(max_distance, distance + zoom_step)


func _notification(what: int) -> void:
	# Let go of the mouse while paused (the menu needs it), and take it back after.
	if what == NOTIFICATION_PAUSED and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera.current:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_meta("recapture", true)
	elif what == NOTIFICATION_UNPAUSED and get_meta("recapture", false):
		set_meta("recapture", false)
		if capture_mouse and camera.current:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
