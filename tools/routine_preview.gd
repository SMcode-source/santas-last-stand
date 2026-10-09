extends Node
## Close-up of Santa's title-screen chores, for checking the poses with
## --write-movie.  -- --at=chop  or  -- --at=pack

const BACKDROP := preload("res://hello/hello_santa.tscn")


func _ready() -> void:
	var at := "chop"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			at = arg.get_slice("=", 1)
	var backdrop: Node3D = BACKDROP.instantiate()
	backdrop.show_ui = false
	backdrop.orbit_camera = false
	backdrop.routine_start = at
	add_child(backdrop)
	var camera: Camera3D = backdrop.camera
	if at == "chop":
		camera.position = Vector3(-1.9, 1.4, 0.2)
		camera.look_at(Vector3(-2.5, 0.9, -2.8))
	else:
		camera.position = Vector3(1.4, 1.5, 1.4)
		camera.look_at(Vector3(1.6, 0.7, -1.25))
	# Optional camera override: --cam=x,y,z --look=x,y,z
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			var v := arg.get_slice("=", 1).split_floats(",")
			camera.position = Vector3(v[0], v[1], v[2])
		if arg.begins_with("--look="):
			var v := arg.get_slice("=", 1).split_floats(",")
			camera.look_at(Vector3(v[0], v[1], v[2]))
