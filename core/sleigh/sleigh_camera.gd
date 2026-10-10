class_name SleighCamera
extends Camera3D
## Chase camera for the sleigh: it swings round behind the direction of
## travel (so a drift shows the sleigh sliding sideways), leans a little into
## the bank, and widens its view on boost for a rush of speed.
## Tunables: data/balance/controllers.json, "sleigh_camera".

var distance := 8.0
var height := 2.6
## How far ahead of the sleigh it looks.
var look_ahead := 8.0
var follow_rate := 7.0
var turn_rate := 5.0
## Field of view at cruising speed and at full boost.
var boost_fov := 84.0
var fov_rate := 4.0
## How much of the sleigh's bank the camera leans with.
var roll_follow := 0.3

var target: SleighController
## Capture the mouse on click so it can steer.
var capture_mouse := true

var _base_fov := 68.0
var _yaw := 0.0
var _pitch := 0.0
var _offset := Vector3.ZERO


func _init() -> void:
	name = "SleighCamera"
	top_level = true
	Balance.apply(self, "controllers", "sleigh_camera")
	_base_fov = fov
	near = 0.1
	far = 1500.0


## Jumps straight behind the sleigh, skipping the easing.
func snap() -> void:
	if target == null:
		return
	var travel := target.travel_direction()
	_yaw = atan2(travel.x, travel.z)
	_pitch = target.pitch * 0.5
	_offset = _wanted_offset()
	_place()


func _process(delta: float) -> void:
	if target == null:
		return
	var travel := target.travel_direction()
	_yaw = lerp_angle(_yaw, atan2(travel.x, travel.z), 1.0 - exp(-delta * turn_rate))
	_pitch = lerpf(_pitch, target.pitch * 0.5, 1.0 - exp(-delta * turn_rate))
	_offset = _offset.lerp(_wanted_offset(), 1.0 - exp(-delta * follow_rate))
	var over := clampf((target.speed - target.cruise_speed) / maxf(target.boost_speed - target.cruise_speed, 1.0), 0.0, 1.0)
	var fov_goal := lerpf(_base_fov, boost_fov, over)
	fov = lerpf(fov, fov_goal, 1.0 - exp(-delta * fov_rate))
	_place()


func _wanted_offset() -> Vector3:
	var back := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	return -back * distance + Vector3.UP * height


func _place() -> void:
	var centre := target.visual_root.global_position
	global_position = centre + _offset
	var ahead := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var up := Vector3.UP.rotated(ahead, target.bank * roll_follow)
	look_at(centre + ahead * look_ahead + Vector3.UP * 0.6, up)


func _unhandled_input(event: InputEvent) -> void:
	if not current or not capture_mouse or not target.input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and current:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_meta("recapture", true)
	elif what == NOTIFICATION_UNPAUSED and get_meta("recapture", false):
		set_meta("recapture", false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
