extends Node
## Looks at a level from a fixed camera, for checking sets with --write-movie.
##   -- --scene=res://levels/01_frozen_workshop/frozen_workshop.tscn --cam=x,y,z --look=x,y,z
## Other arguments reach the level too (e.g. --l1=boss to start at a checkpoint).
## Without --cam, the level's own camera is used.

var _camera := Camera3D.new()
var _fixed := false


func _ready() -> void:
	var path := "res://levels/01_frozen_workshop/frozen_workshop.tscn"
	var look := Vector3.INF
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--scene="):
			path = value
		elif arg.begins_with("--cam="):
			var v := value.split_floats(",")
			_camera.position = Vector3(v[0], v[1], v[2])
			_fixed = true
		elif arg.begins_with("--look="):
			var v := value.split_floats(",")
			look = Vector3(v[0], v[1], v[2])
		elif arg.begins_with("--fov="):
			_camera.fov = value.to_float()
	add_child((load(path) as PackedScene).instantiate())
	if _fixed:
		_camera.far = 900.0
		add_child(_camera)
		if look != Vector3.INF:
			_camera.look_at(look)


func _process(_delta: float) -> void:
	if _fixed:
		_camera.make_current()
