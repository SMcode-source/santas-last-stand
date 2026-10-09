class_name SantaModel
extends Node3D
## The realistic Santa: a Meshy-generated, Mixamo-rigged model with walk, run,
## punch, combo, hit and fall animations. Standing still he has no clip, so the
## idle is posed in code: arms lowered from the A-pose, breathing, looking
## around. hop() and wave() match SantaToy so the two are interchangeable.

const SCENE := preload("res://assets/characters/santa.glb")
const LOOPING := ["Walking", "Running"]

## How far the arms hang out from the body when idle (his belly needs room).
const ARM_SPREAD := deg_to_rad(14.0)
const ELBOW_BEND := deg_to_rad(18.0)

var skeleton: Skeleton3D
var animations: AnimationPlayer

var _time := 0.0
var _hop := 0.0
var _wave := 0.0
var _model: Node3D
var _bones := {}
# Rest orientations in skeleton space, captured once.
var _rest_global := {}


func _ready() -> void:
	name = "Santa"
	_model = SCENE.instantiate()
	add_child(_model)
	skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	animations = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in LOOPING:
		if animations.has_animation(clip):
			animations.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for bone in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
			"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		var index := skeleton.find_bone("mixamorig_" + bone)
		_bones[bone] = index
		_rest_global[bone] = skeleton.get_bone_global_rest(index).basis.orthonormalized()
	_process(0.0)


## Plays one of the model's clips ("Walking", "Running", "Attack", ...), or
## returns to the code-driven idle with an empty name.
func play(clip: String) -> void:
	if clip.is_empty():
		animations.stop()
		skeleton.reset_bone_poses()
	else:
		animations.play(clip, 0.2)


func hop() -> void:
	if _hop <= 0.0:
		_hop = 1.0


func wave() -> void:
	if _wave <= 0.1:
		_wave = 1.0


func _process(delta: float) -> void:
	_time += delta
	_hop = maxf(0.0, _hop - delta * 2.4)
	_wave = maxf(0.0, _wave - delta * 0.45)
	var hop_height := sin(_hop * PI) * 0.16 if _hop > 0.0 else 0.0
	_model.position.y = hop_height
	if animations.is_playing():
		return

	var breath := sin(_time * 1.6)
	_turn("Spine1", Vector3.RIGHT, breath * 0.012)
	_turn("Spine2", Vector3.RIGHT, breath * 0.018)
	_turn("Head", Vector3.UP, sin(_time * 0.45) * 0.16, Vector3.RIGHT, sin(_time * 0.7) * 0.04)

	var wave_amount := smoothstep(0.0, 0.15, _wave) * smoothstep(1.0, 0.85, _wave)
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var lift := hop_height * 1.2 + breath * 0.015
		var arm_dir := Vector3(side * sin(ARM_SPREAD + lift), -cos(ARM_SPREAD + lift), 0.06)
		arm_dir = arm_dir.normalized()
		# Forearm hangs on from the upper arm, the elbow bent a little forward.
		var fore_dir := (arm_dir * cos(ELBOW_BEND) + Vector3.BACK * sin(ELBOW_BEND)).normalized()
		if side < 0.0 and wave_amount > 0.0:
			# Right upper arm out to the side, forearm up beside the head, swinging.
			var wave_arm := Vector3(-0.9, 0.12, 0.25).normalized()
			var wave_fore := Vector3(-0.2, 1.0, 0.2).normalized().rotated(Vector3.BACK, sin(_time * 9.0) * 0.4)
			arm_dir = arm_dir.slerp(wave_arm, wave_amount)
			fore_dir = fore_dir.slerp(wave_fore, wave_amount)
		_aim_arm(prefix, arm_dir, fore_dir)


## Rotates a bone from its rest pose about up to two skeleton-space axes.
func _turn(bone: String, axis: Vector3, angle: float, axis2 := Vector3.ZERO, angle2 := 0.0) -> void:
	var turn := Basis(axis, angle)
	if axis2 != Vector3.ZERO:
		turn = turn * Basis(axis2, angle2)
	_set_global(bone, turn * _rest_global[bone], _parent_rest(bone))


## Points the upper arm and forearm along the given skeleton-space directions.
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
	return skeleton.get_bone_global_rest(parent).basis.orthonormalized()


func _bone_origin(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(_bones[bone]).origin
