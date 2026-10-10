extends Node
## Looks at a cast member in the playground, for checking poses with
## --write-movie.  -- --who=ScroogePacing --cam=x,y,z --look=x,y,z
## Without --cam the camera follows the character from in front (--off=x,y,z
## in its frame, aimed at --aim=height).

const PLAYGROUND := preload("res://levels/playground/playground.tscn")

var _camera := Camera3D.new()
var _who: Node3D
var _offset := Vector3(0, 1.3, 2.6)
var _fixed := false
var _aim := 1.05


func _ready() -> void:
	var who := "ScroogePacing"
	var playground: Node = PLAYGROUND.instantiate()
	add_child(playground)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--who="):
			who = arg.get_slice("=", 1)
	_who = playground.get_node(who)
	add_child(_camera)
	_camera.make_current.call_deferred()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			var v := arg.get_slice("=", 1).split_floats(",")
			_camera.position = Vector3(v[0], v[1], v[2])
			_fixed = true
		if arg.begins_with("--off="):
			var v := arg.get_slice("=", 1).split_floats(",")
			_offset = Vector3(v[0], v[1], v[2])
		if arg.begins_with("--aim="):
			_aim = arg.get_slice("=", 1).to_float()
		if arg.begins_with("--look="):
			var v := arg.get_slice("=", 1).split_floats(",")
			_camera.look_at.call_deferred(Vector3(v[0], v[1], v[2]))


func _process(_delta: float) -> void:
	_camera.make_current()
	if _fixed:
		return
	var at := _who.global_position
	_camera.global_position = at + _who.global_basis * _offset
	_camera.look_at(at + Vector3.UP * _aim)
