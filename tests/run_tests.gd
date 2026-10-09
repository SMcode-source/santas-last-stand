extends SceneTree
## Runs every test_*.gd in this folder and exits with code 1 if any fail.
##   godot --headless --script res://tests/run_tests.gd
## Each test file extends TestCase; every method starting with "test_" is a test.


func _init() -> void:
	var passed := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.call(name)
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f in case.failures:
					printerr("FAIL %s :: %s  %s" % [file, name, f])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
