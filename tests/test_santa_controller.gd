extends TestCase
## Plays Santa for a few seconds with simulated input on a flat test floor:
## he walks, runs, stops, jumps and lands, hops short, and punches and throws
## at a target.


## Something that counts the hits it takes, like a snowman.
class _Target extends StaticBody3D:
	var hits: Array[String] = []

	func take_hit(hit: Dictionary) -> void:
		hits.append(hit["kind"])


func test_walks_runs_jumps_and_lands() -> void:
	var world := _world()
	var santa := SantaController.spawn(world, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await _ticks(10)
	check(santa.is_on_floor(), "standing on the floor")

	# Forward is away from the camera, which starts behind him (he faces +z).
	Input.action_press("move_forward")
	await _ticks(60)
	check(santa.global_position.z > 1.4, "walked forward (z = %.2f)" % santa.global_position.z)
	check(absf(_flat_speed(santa) - santa.walk_speed) < 0.1, "at walking pace (%.2f)" % _flat_speed(santa))
	check_eq(String(santa.santa.animations.current_animation), "Walking", "walk clip")
	Input.action_press("run")
	await _ticks(40)
	check(absf(_flat_speed(santa) - santa.run_speed) < 0.1, "at running pace (%.2f)" % _flat_speed(santa))
	check_eq(String(santa.santa.animations.current_animation), "Running", "run clip")
	var feet := santa.santa.animations.speed_scale * santa.run_clip_speed
	check(absf(feet - _flat_speed(santa)) < 0.2, "clip speed matches his pace (feet %.2f)" % feet)
	Input.action_release("run")
	Input.action_release("move_forward")
	await _ticks(30)
	check(_flat_speed(santa) < 0.05, "stopped")
	check(not santa.santa.animations.is_playing(), "back to the idle")

	var landings: Array[float] = []
	santa.landed.connect(func(speed: float) -> void: landings.append(speed))
	var ground := santa.global_position.y
	_action("jump", true)
	var top := await _highest(santa, 45)
	_action("jump", false)
	await _ticks(40)
	check(top - ground > santa.jump_height * 0.85 and top - ground < santa.jump_height * 1.1,
			"full jump height (%.2f)" % (top - ground))
	check_eq(landings.size(), 1, "landed once")
	check(santa.is_on_floor(), "on the floor again")

	# A tap gives a short hop.
	_action("jump", true)
	await _ticks(4)
	_action("jump", false)
	var hop := await _highest(santa, 40)
	check(hop - ground < (top - ground) * 0.7, "a tap hops lower (%.2f)" % (hop - ground))
	await _ticks(20)
	check_eq(landings.size(), 2, "landed after the hop")

	# Jump pressed just before landing still counts.
	_action("jump", true)
	await _ticks(12)
	_action("jump", false)
	while santa.velocity.y > 0.0 or santa.global_position.y - ground > 0.25:
		await _ticks(1)
	_action("jump", true)
	await _ticks(10)
	_action("jump", false)
	check(santa.global_position.y - ground > 0.3, "buffered jump on landing")
	await _ticks(40)
	world.free()


func test_punch_and_snowball_hit_a_target() -> void:
	var world := _world()
	var santa := SantaController.spawn(world, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var target := _target(world, Vector3(0, 0, 1.4))
	await _ticks(10)
	_action("attack", true)
	_action("attack", false)
	await _ticks(50)
	check_eq(target.hits, ["punch"] as Array[String], "one punch lands once")

	target.position = Vector3(0, 0, 7)
	await _ticks(30)
	_action("throw", true)
	_action("throw", false)
	await _ticks(60)
	check_eq(target.hits.count("snowball"), 1, "the snowball hits the target 7 m away")
	check_eq(santa.snowballs.in_flight(), 0, "the snowball is back in the pool")

	santa.set_abilities({"punch": false, "throw": false})
	_action("attack", true)
	_action("attack", false)
	_action("throw", true)
	_action("throw", false)
	await _ticks(50)
	check_eq(target.hits.size(), 2, "switched-off abilities do nothing")
	world.free()


func _world() -> Node3D:
	var world := Node3D.new()
	world.name = "TestWorld"
	var floor := StaticBody3D.new()
	floor.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position.y = -0.5
	floor.add_child(shape)
	world.add_child(floor)
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	return world


func _target(world: Node3D, at: Vector3) -> _Target:
	var target := _Target.new()
	target.position = at
	target.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.5
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = 1.0
	target.add_child(shape)
	var hurt := Area3D.new()
	hurt.collision_layer = PhysicsLayers.HURTBOX
	hurt.collision_mask = 0
	hurt.add_child(shape.duplicate())
	target.add_child(hurt)
	world.add_child(target)
	return target


func _action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _ticks(count: int) -> void:
	for i in count:
		await (Engine.get_main_loop() as SceneTree).physics_frame


func _highest(santa: SantaController, ticks: int) -> float:
	var top := santa.global_position.y
	for i in ticks:
		await _ticks(1)
		top = maxf(top, santa.global_position.y)
	return top


static func _flat_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()
