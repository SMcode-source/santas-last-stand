extends Node
## Renders the title backdrop with the old hand-built SantaToy beside the
## realistic SantaModel, for comparing looks with --write-movie.
##   -- --wave   makes the model wave
##   -- --clip=Walking   plays one of its animation clips
##   -- --gesture=rub_hands   starts one of the idle gestures
##   -- --close  frames the model alone, close up
##   -- --tight  frames his chest, beard and sleeve, for checking fabric detail

const BACKDROP := preload("res://hello/hello_santa.tscn")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var backdrop: Node3D = BACKDROP.instantiate()
	backdrop.show_ui = false
	backdrop.orbit_camera = false
	backdrop.santa_routine = false
	add_child(backdrop)
	await get_tree().process_frame
	var santa: SantaModel = backdrop.santa
	var camera: Camera3D = backdrop.camera
	if "--tight" in args:
		camera.position = Vector3(0.15, 1.3, 0.95)
		camera.look_at(Vector3(0.05, 1.2, 0))
	elif "--close" in args:
		camera.position = Vector3(0, 1.45, 2.2)
		camera.look_at(Vector3(0, 1.05, 0))
	else:
		santa.position.x = 0.55
		var toy := SantaToy.new()
		toy.position.x = -0.55
		backdrop.add_child(toy)
		camera.position = Vector3(0, 1.3, 3.6)
		camera.look_at(Vector3(0, 1.0, 0))
	for arg in args:
		if arg.begins_with("--clip="):
			santa.play(arg.get_slice("=", 1))
		if arg.begins_with("--gesture="):
			santa.perform(arg.get_slice("=", 1))
	if "--wave" in args:
		await get_tree().create_timer(0.3).timeout
		santa.wave()
