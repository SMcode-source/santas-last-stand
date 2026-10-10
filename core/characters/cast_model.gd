class_name CastModel
extends Node3D
## A rigged character from Meshy (Mixamo skeleton, facing +z) brought to life:
## standing, it breathes, shifts its weight and glances about with its arms
## lowered from the A-pose it was made in; moving, it plays the model's own
## Walking or Running clip. One script serves the whole cast; each character
## only sets its model and a few numbers for its build and bearing.

## How far the arms hang out from the body (radians); wider for stout builds.
@export var arm_spread := deg_to_rad(8.0)
## How bent the elbows are when the arms hang.
@export var elbow_bend := deg_to_rad(14.0)
## A forward stoop through the back, the head lifted to keep looking ahead.
@export var stoop := 0.0
## How much the head looks about (1 = alert, 0.3 = fixed on something).
@export var restless := 1.0
## Joints the auto-rig put in the wrong place: bone name (without the
## "mixamorig_" prefix) -> where it belongs, in the model's rest space.
var joint_fixes := {}

var skeleton: Skeleton3D
var animations: AnimationPlayer

var _scene: PackedScene
var _model: Node3D
var _time := 0.0
var _bones := {}
var _rest_global := {}
var _hip_rest := Vector3.ZERO
var _hip_height := 1.0
var _clip := ""


## A model for `scene` (an imported Meshy .glb). `seed` staggers its idle so
## two of the same character never move in step.
func _init(scene: PackedScene = null, seed := 0) -> void:
	_scene = scene
	_time = seed * 7.3


func _ready() -> void:
	_model = _scene.instantiate()
	add_child(_model)
	skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	animations = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for bone: String in joint_fixes:
		_move_joint(skeleton.find_bone("mixamorig_" + bone), joint_fixes[bone])
	for clip in ["Walking", "Running"]:
		if animations.has_animation(clip):
			animations.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for bone in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
			"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		var index := skeleton.find_bone("mixamorig_" + bone)
		_bones[bone] = index
		_rest_global[bone] = skeleton.get_bone_global_rest(index).basis.orthonormalized()
	_hip_rest = skeleton.get_bone_rest(_bones["Hips"]).origin
	_hip_height = skeleton.get_bone_global_rest(_bones["Hips"]).origin.y
	_process(0.0)


## Plays a clip ("Walking", "Running"), or stands idle for "".
func play(clip: String, speed := 1.0) -> void:
	if clip == _clip:
		animations.speed_scale = speed
		return
	_clip = clip
	if clip.is_empty() or not animations.has_animation(clip):
		animations.stop()
		skeleton.reset_bone_poses()
	else:
		animations.play(clip, 0.25)
		animations.speed_scale = speed


func _process(delta: float) -> void:
	_time += delta
	if animations.is_playing():
		return
	var breath := sin(_time * 1.4)
	# Weight shifts from foot to foot: the hips slide and tilt, the spine
	# leans back the other way so the head stays level.
	var sway := sin(_time * 0.4) + 0.3 * sin(_time * 1.07)
	var tilt := sway * 0.012
	skeleton.set_bone_pose_position(_bones["Hips"], _hip_rest + Vector3(-tilt * _hip_height, 0, 0))
	_turn("Hips", Vector3.BACK, tilt, Vector3.UP, sin(_time * 0.27) * 0.04)
	_turn("Spine", Vector3.BACK, -tilt * 1.3, Vector3.RIGHT, stoop * 0.25)
	_turn("Spine1", Vector3.RIGHT, breath * 0.02 + stoop * 0.3)
	_turn("Spine2", Vector3.RIGHT, breath * 0.03 + stoop * 0.3)
	_turn("Neck", Vector3.RIGHT, -stoop * 0.35)
	var yaw := (sin(_time * 0.45) * 0.16 + sin(_time * 1.3) * 0.03) * restless
	_turn("Head", Vector3.UP, yaw, Vector3.RIGHT, sin(_time * 0.7) * 0.04 - stoop * 0.35)
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var spread := arm_spread + breath * 0.02
		var arm_dir := Vector3(side * sin(spread), -cos(spread), 0.05 + sway * side * 0.03).normalized()
		var fore_dir := (arm_dir * cos(elbow_bend) + Vector3.BACK * sin(elbow_bend)).normalized()
		_aim_arm(prefix, arm_dir, fore_dir)


## Moves a joint's pivot without moving the mesh at rest: the bone's rest
## position changes, its children keep where they were, and the skin's bind
## for it is adjusted to match. The clips only turn bones, so they play the
## same, just pivoting about the right place.
func _move_joint(bone: int, to: Vector3) -> void:
	var old_global := skeleton.get_bone_global_rest(bone)
	var new_global := Transform3D(old_global.basis, to)
	var parent_global := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone))
	var rest := skeleton.get_bone_rest(bone)
	rest.origin = parent_global.affine_inverse() * to
	skeleton.set_bone_rest(bone, rest)
	skeleton.set_bone_pose_position(bone, rest.origin)
	for child in skeleton.get_bone_children(bone):
		var child_rest := skeleton.get_bone_rest(child)
		child_rest.origin = new_global.affine_inverse() * (old_global * child_rest.origin)
		skeleton.set_bone_rest(child, child_rest)
		skeleton.set_bone_pose_position(child, child_rest.origin)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		mesh.skin = mesh.skin.duplicate()
		for bind in mesh.skin.get_bind_count():
			if mesh.skin.get_bind_bone(bind) == bone or mesh.skin.get_bind_name(bind) == skeleton.get_bone_name(bone):
				mesh.skin.set_bind_pose(bind, new_global.affine_inverse() * old_global * mesh.skin.get_bind_pose(bind))


## Rotates a bone from its rest pose about up to two skeleton-space axes.
func _turn(bone: String, axis: Vector3, angle: float, axis2 := Vector3.ZERO, angle2 := 0.0) -> void:
	var turn := Basis(axis, angle)
	if axis2 != Vector3.ZERO:
		turn = turn * Basis(axis2, angle2)
	_set_global(bone, turn * _rest_global[bone], _parent_rest(bone))


## Points the upper arm and forearm along skeleton-space directions.
func _aim_arm(prefix: String, arm_dir: Vector3, fore_dir: Vector3) -> void:
	var arm := prefix + "Arm"
	var fore := prefix + "ForeArm"
	var arm_points := (_bone_origin(fore) - _bone_origin(arm)).normalized()
	var arm_global: Basis = Basis(Quaternion(arm_points, arm_dir)) * _rest_global[arm]
	_set_global(arm, arm_global, _parent_rest(arm))
	var fore_points := (_bone_origin(prefix + "Hand") - _bone_origin(fore)).normalized()
	var fore_global: Basis = Basis(Quaternion(fore_points, fore_dir)) * _rest_global[fore]
	_set_global(fore, fore_global, arm_global)


func _set_global(bone: String, global_basis: Basis, parent_global: Basis) -> void:
	skeleton.set_bone_pose_rotation(_bones[bone], (parent_global.inverse() * global_basis).get_rotation_quaternion())


func _parent_rest(bone: String) -> Basis:
	var parent := skeleton.get_bone_parent(_bones[bone])
	if parent < 0:
		return Basis.IDENTITY
	return skeleton.get_bone_global_rest(parent).basis.orthonormalized()


func _bone_origin(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(_bones[bone]).origin
