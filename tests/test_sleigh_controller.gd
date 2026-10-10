extends TestCase
## Flies the sleigh with simulated input: speeding up, boosting on the meter,
## drifting round a turn, and following a rail.


func test_flies_boosts_and_drifts() -> void:
	var world := Node3D.new()
	_tree().root.add_child(world)
	var sleigh := SleighController.new()
	world.add_child(sleigh)
	sleigh.place(Transform3D(Basis.IDENTITY, Vector3(0, 20, 0)))
	sleigh.camera.make_current()
	await _ticks(5)
	check(sleigh.global_position.z > 1.0, "cruises forward on its own")

	Input.action_press("move_forward")
	await _ticks(90)
	check(absf(sleigh.speed - sleigh.max_speed) < 0.5, "full throttle reaches top speed (%.1f)" % sleigh.speed)
	Input.action_press("run")
	await _ticks(30)
	check(sleigh.boosting and sleigh.speed > sleigh.max_speed + 5.0, "boost is faster (%.1f)" % sleigh.speed)
	check(sleigh.boost_meter < 0.9, "boost uses the meter (%.2f)" % sleigh.boost_meter)
	Input.action_release("run")
	Input.action_release("move_forward")

	# A plain turn, then the same turn drifting: tighter, sliding, and refilling the meter.
	var turned := await _turn(sleigh, false)
	var meter := sleigh.boost_meter
	var drifted := await _turn(sleigh, true)
	check(drifted > turned * 1.3, "drifting turns tighter (%.2f vs %.2f rad)" % [drifted, turned])
	check(sleigh.boost_meter > meter + 0.05, "drifting charges the boost meter")
	var slide := sleigh.heading().angle_to(sleigh.travel_direction())
	check(slide > 0.1, "a drift slides wide of the nose (%.2f rad)" % slide)
	world.free()


func test_follows_a_rail() -> void:
	var world := Node3D.new()
	_tree().root.add_child(world)
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0, 10, 0))
	path.curve.add_point(Vector3(200, 10, 0))
	world.add_child(path)
	var sleigh := SleighController.new()
	world.add_child(sleigh)
	sleigh.follow_rail(path, 0.0, false)
	await _ticks(30)
	check(sleigh.global_position.x > 5.0, "moves along the rail (x = %.1f)" % sleigh.global_position.x)
	check(sleigh.heading().dot(Vector3.RIGHT) > 0.95, "faces along the rail")
	Input.action_press("move_right")
	await _ticks(90)
	Input.action_release("move_right")
	check(absf(sleigh.rail_offset.x - sleigh.rail_half_width) < 0.01, "steering stops at the edge of the rail box")
	# Steering right moves it to the right of the line: +x ahead, so right is +z.
	check(sleigh.global_position.z > sleigh.rail_half_width - 0.1, "steered to its right (z = %.1f)" % sleigh.global_position.z)
	world.free()


## Steers right for a second; returns how far the heading turned.
func _turn(sleigh: SleighController, drift: bool) -> float:
	var before := sleigh.yaw
	Input.action_press("move_right")
	if drift:
		Input.action_press("jump")
	await _ticks(60)
	var turned := absf(angle_difference(before, sleigh.yaw))
	Input.action_release("move_right")
	Input.action_release("jump")
	return turned


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _ticks(count: int) -> void:
	for i in count:
		await _tree().physics_frame
