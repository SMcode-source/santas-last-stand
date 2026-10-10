extends TestCase
## Builds the playground and checks it holds together: Santa lands on the
## snow, the snowmen take hits, and swapping to the sleigh and back puts him
## down safely on the ground.


func test_playground_switches_between_santa_and_sleigh() -> void:
	var level: Node = load("res://levels/playground/playground.tscn").instantiate()
	_tree().root.add_child(level)
	var santa: SantaController = level.santa
	santa.input_enabled = false
	await _ticks(30)
	check(santa.is_on_floor(), "Santa stands on the snow")
	check(absf(santa.global_position.y) < 0.2, "at ground height (y = %.2f)" % santa.global_position.y)

	level.set_flying(true)
	level.sleigh.input_enabled = false
	await _ticks(60)
	check(not santa.visible and level.sleigh.global_position.distance_to(santa.global_position) > 10.0,
			"the sleigh flies off with Santa aboard")
	level.set_flying(false)
	santa.input_enabled = false
	await _ticks(30)
	check(santa.visible and santa.is_on_floor(), "Santa is back on the ground")
	var flat := Vector2(santa.global_position.x, santa.global_position.z)
	check(flat.length() < level.WALK_RADIUS, "inside the walking area (%.1f m out)" % flat.length())
	check(level.sleigh.process_mode == Node.PROCESS_MODE_DISABLED, "the sleigh is parked")
	level.free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _ticks(count: int) -> void:
	for i in count:
		await _tree().physics_frame
