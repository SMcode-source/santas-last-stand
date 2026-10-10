extends Node
## Plays the playground by itself, for recordings and quick looks:
## `-- --demo=<name>` on the command line. Each demo is a short script of
## moves on a timer, using the controllers' own intents and actions, so it
## shows exactly what a player would see.
##
##   walk      walks, then runs, down the course
##   jump      runs and jumps up the crates and blocks
##   punch     punches a snowman till it bursts
##   throw     pelts the snowmen with snowballs
##   sneak     creeps along, then picks up a present and carries it
##   sleigh    takes off and flies the ring loop, boosting and drifting
##   rails     flies the rings on rails, steering within the rail box
##   overview  a slow high view over the whole playground

var playground: Node
var demo_name := "walk"
var _t := 0.0
var _fired := {}
var _high_camera: Camera3D


func _ready() -> void:
	if not has_method("_" + demo_name):
		push_warning("No demo called '%s'; showing 'walk'." % demo_name)
		demo_name = "walk"
	var santa: SantaController = playground.santa
	santa.input_enabled = false
	santa.camera.input_enabled = false
	santa.camera.capture_mouse = false
	santa.camera.auto_follow = true
	playground.sleigh.camera.capture_mouse = false
	match demo_name:
		"punch":
			santa.place(_facing(Vector3(-4.6, 0.05, 7.2), SnowmanSpot.FIRST))
		"throw":
			santa.place(_facing(Vector3(-1.5, 0.05, 9.0), SnowmanSpot.SECOND))
		"sneak":
			santa.place(_facing(Vector3(-2.2, 0.05, 15.5), Vector3(-2.2, 0, 12.5)))
		"sleigh", "rails":
			playground.set_flying(true)
			playground.sleigh.input_enabled = false
			if demo_name == "rails":
				var path: Path3D = playground.rings.path
				# Just before the first ring, so it counts.
				playground.sleigh.follow_rail(path, path.curve.get_baked_length() - 12.0)
			else:
				playground.sleigh.place(Transform3D(Basis.IDENTITY, Vector3(30, 11, -16)))
		"overview":
			_high_camera = Camera3D.new()
			_high_camera.fov = 55.0
			playground.add_child(_high_camera)
			_high_camera.make_current()
	santa.camera.look_behind(santa.yaw)
	santa.camera.snap()


enum SnowmanSpot { FIRST, SECOND }


## A transform at `from` turned to face `toward` (a point or a snowman).
func _facing(from: Vector3, toward: Variant) -> Transform3D:
	var at: Vector3 = toward if toward is Vector3 else playground.SNOWMEN[toward]
	var ahead := at - from
	return Transform3D(Basis(Vector3.UP, atan2(ahead.x, ahead.z)), from)


func _physics_process(delta: float) -> void:
	_t += delta
	call("_" + demo_name)


## True once, the first tick after `seconds`.
func _at(seconds: float, key: String) -> bool:
	if _t < seconds or _fired.has(key):
		return false
	_fired[key] = true
	return true


func _walk() -> void:
	var santa: SantaController = playground.santa
	# Past the right of the crates, then round behind them.
	var goal := Vector3(2.6, 0, 1.0) if santa.global_position.z > 1.5 else Vector3(2.0, 0, -14.0)
	santa.move_intent = _toward(santa, goal)
	santa.run_intent = _t > 1.6


func _jump() -> void:
	var santa: SantaController = playground.santa
	# Up the steps: the crate, the low block, then the high one.
	var goal := Vector3(0, 0, -3.0)
	santa.move_intent = _toward(santa, goal) if santa.global_position.z > -2.6 else Vector3.ZERO
	santa.run_intent = true
	for hop: Array in [[1.05, "a"], [1.75, "b"], [2.45, "c"]]:
		if _at(hop[0], hop[1]):
			santa.jump()
		if _at(hop[0] + 0.4, hop[1] + "up"):
			santa.release_jump()


func _punch() -> void:
	var santa: SantaController = playground.santa
	for i in 5:
		if _at(0.3 + i * 0.75, "p%d" % i):
			santa.punch()


func _throw() -> void:
	var santa: SantaController = playground.santa
	for i in 6:
		if _at(0.3 + i * 0.5, "t%d" % i):
			var target: Vector3 = playground.SNOWMEN[i % 2]
			santa.place(_facing(santa.global_position, target))
			santa.throw_snowball()


func _sneak() -> void:
	var santa: SantaController = playground.santa
	var present: Vector3 = playground.PRESENTS[1]
	santa.sneak_intent = _t < 2.3
	var near := Vector2(santa.global_position.x - present.x, santa.global_position.z - present.z).length() < 1.0
	santa.move_intent = _toward(santa, present) if _t < 2.3 and not near else Vector3.ZERO
	if _at(2.4, "grab"):
		santa.interact()
	if _t > 2.8:
		santa.move_intent = _toward(santa, Vector3(4, 0, 6))


func _sleigh() -> void:
	var sleigh: SleighController = playground.sleigh
	sleigh.throttle_intent = 1.0
	sleigh.boost_intent = _t > 0.8 and _t < 1.8
	sleigh.steer_intent = 0.0 if _t < 1.8 else 1.0
	sleigh.drift_intent = _t > 2.0
	sleigh.pitch_intent = 0.1


func _rails() -> void:
	var sleigh: SleighController = playground.sleigh
	sleigh.throttle_intent = 0.5
	sleigh.steer_intent = sin(_t * 1.5)
	sleigh.pitch_intent = cos(_t * 1.1) * 0.6
	sleigh.boost_intent = _t > 1.5


func _overview() -> void:
	var a := 0.6 + _t * 0.08
	_high_camera.global_position = Vector3(sin(a) * 34.0, 20.0, cos(a) * 34.0)
	_high_camera.look_at(Vector3(0, 1.0, -1.0))


## A flat push from Santa toward `point`, easing off as he arrives.
func _toward(santa: SantaController, point: Vector3) -> Vector3:
	var to := point - santa.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.3 else Vector3.ZERO
