extends SceneTree
## Times how long each piece of the title scene takes to build, slowest first:
## `godot --headless --path . --script res://tools/startup_profile.gd`

var _times := []


func _time(label: String, make: Callable) -> Variant:
	var start := Time.get_ticks_usec()
	var result: Variant = make.call()
	_times.append([(Time.get_ticks_usec() - start) / 1000.0, label])
	return result


func _initialize() -> void:
	var total := Time.get_ticks_usec()
	var trail := PackedVector2Array([Vector2(-3.45, -3.5), Vector2(-0.12, -0.3)])
	_time("snow_ground", func(): return WinterProps.snow_ground(120.0, 80, 7.0, 1, 1, trail))
	_time("santa", func(): var s := SantaModel.new(); root.add_child(s); return s)
	_time("log_cabin", WinterProps.log_cabin)
	_time("fir_tree decorated", func(): return WinterProps.fir_tree(4.2, 7, true, 0.85))
	_time("snowman", WinterProps.snowman)
	_time("lamp_post", WinterProps.lamp_post)
	_time("fence x2", func(): WinterProps.fence(5.0); return WinterProps.fence(4.0))
	_time("presents x4", func():
		for i in 4:
			WinterProps.present(Vector3(0.5, 0.45, 0.5), Color("1d4f8c"), WinterProps.GOLD, i % 4, i)
		return null)
	_time("campfire", WinterProps.campfire)
	_time("pbr models x12", func():
		for m in ["painted_wooden_bench", "tree_stump_01", "wooden_axe", "dry_branches_medium_01", "wooden_crate_01", "wine_barrel_01",
				"wooden_bucket_01", "dead_tree_trunk", "namaqualand_boulder_04", "namaqualand_boulder_02", "rock_moss_set_01", "namaqualand_boulder_04"]:
			PbrLibrary.model(m, 0.5)
		return null)
	_time("log_round + sack", func(): WinterProps.log_round(); return WinterProps.toy_sack())
	_time("forest trees x4", func():
		for v in 4:
			WinterProps.fir_tree(5.0, 20 + v, false, 0.85, 0.6)
		return null)
	_time("saplings tree", func(): return WinterProps.fir_tree(1.3, 31, false, 0.5, 0.7))
	_time("mountain_range", WinterProps.mountain_range)
	var scene: Node = load("res://hello/hello_santa.tscn").instantiate()
	_time("whole hello scene (warm caches)", func(): root.add_child(scene); return null)
	_times.sort_custom(func(a, b): return a[0] > b[0])
	for t in _times:
		print("%8.1f ms  %s" % t)
	print("total %.0f ms" % ((Time.get_ticks_usec() - total) / 1000.0))
	quit()
