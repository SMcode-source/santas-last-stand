class_name SantaPose
extends SkeletonModifier3D
## Poses the model's clips do not have, laid over whatever SantaModel shows
## (a clip or its idle): a crouch for sneaking and for landing, the snowball
## throw, both arms round something he carries, a lean into his stride, and a
## short settle that blends smoothly out of the old pose whenever the clip
## changes. It runs after the clips each frame and the engine puts the bones
## back afterwards, so nothing here builds up from frame to frame.

## How long the settle takes to blend out of the old pose.
const SETTLE_SECONDS := 0.22
## How far each knee bends at a full crouch (radians).
const CROUCH_KNEE := 0.8
## The throw, as [phase, upper arm, forearm, shoulder twist] for his right
## arm. Directions are in his body space: +x his left, +y up, +z ahead.
const THROW_KEYS := [
	[0.12, Vector3(-0.55, 0.35, -0.75), Vector3(-0.15, 0.95, -0.25), -0.5],
	[0.38, Vector3(-0.6, 0.45, -0.65), Vector3(-0.1, 0.9, -0.4), -0.6],
	[0.5, Vector3(-0.3, 0.45, 0.85), Vector3(-0.05, 0.35, 0.95), 0.25],
	[0.72, Vector3(0.05, -0.35, 0.95), Vector3(0.3, -0.55, 0.8), 0.4],
]
## Arms round a present held against his belly: [upper arm, forearm], left side.
const CARRY_LEFT := [Vector3(0.25, -0.8, 0.5), Vector3(-0.5, 0.15, 0.85)]

## How far he crouches: 0 standing, 1 a full sneak.
var crouch := 0.0
## Where he is in a throw (0 to 1), or below 0 when not throwing.
var throw_phase := -1.0
## How much his arms hold something in front of him (0 to 1).
var carry := 0.0
## Forward lean of the upper body (radians).
var lean := 0.0

var _bones := {}
var _leg_length := 0.85
var _snapshot := []
var _snapshot_hips := Vector3.ZERO
var _settle := 0.0


func _ready() -> void:
	var skeleton := get_skeleton()
	for bone in ["Hips", "Spine", "Spine1", "Neck", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg",
			"RightFoot", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		_bones[bone] = skeleton.find_bone("mixamorig_" + bone)
	var hip := skeleton.get_bone_global_rest(_bones["LeftUpLeg"]).origin
	var knee := skeleton.get_bone_global_rest(_bones["LeftLeg"]).origin
	var ankle := skeleton.get_bone_global_rest(_bones["LeftFoot"]).origin
	_leg_length = hip.distance_to(knee) + knee.distance_to(ankle)


## Remembers the pose he is in now and blends out of it over the next moment.
## Call it just before switching clips (or back to the idle), so the change
## never pops.
func settle() -> void:
	var skeleton := get_skeleton()
	_snapshot.resize(skeleton.get_bone_count())
	for i in skeleton.get_bone_count():
		_snapshot[i] = skeleton.get_bone_pose_rotation(i)
	_snapshot_hips = skeleton.get_bone_pose_position(_bones["Hips"])
	_settle = 1.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _settle > 0.0:
		_apply_settle(skeleton, smoothstep(0.0, 1.0, _settle))
		_settle -= delta / SETTLE_SECONDS
	if crouch > 0.001:
		_apply_crouch(skeleton, crouch)
	if absf(lean) > 0.001:
		_rotate(skeleton, "Spine", Vector3.RIGHT, lean)
	if carry > 0.001:
		_apply_carry(skeleton, carry)
	if throw_phase >= 0.0:
		_apply_throw(skeleton, throw_phase)


func _apply_settle(skeleton: Skeleton3D, weight: float) -> void:
	for i in mini(_snapshot.size(), skeleton.get_bone_count()):
		var now := skeleton.get_bone_pose_rotation(i)
		skeleton.set_bone_pose_rotation(i, now.slerp(_snapshot[i], weight))
	var hips: int = _bones["Hips"]
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips).lerp(_snapshot_hips, weight))


## Knees bent and hips lowered so the feet stay put, the back leaning forward
## and the head lifted to look ahead.
func _apply_crouch(skeleton: Skeleton3D, amount: float) -> void:
	var knee := amount * CROUCH_KNEE
	var hips: int = _bones["Hips"]
	var parent := skeleton.get_bone_parent(hips)
	var down := Vector3.DOWN * _leg_length * (1.0 - cos(knee))
	if parent >= 0:
		down = skeleton.get_bone_global_pose(parent).basis.inverse() * down
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + down)
	for side in ["Left", "Right"]:
		_rotate(skeleton, side + "UpLeg", Vector3.RIGHT, -knee)
		_rotate(skeleton, side + "Leg", Vector3.RIGHT, knee * 2.0)
		_rotate(skeleton, side + "Foot", Vector3.RIGHT, -knee)
	_rotate(skeleton, "Spine", Vector3.RIGHT, amount * 0.4)
	_rotate(skeleton, "Neck", Vector3.RIGHT, -amount * 0.25)


func _apply_carry(skeleton: Skeleton3D, amount: float) -> void:
	var mirror := Vector3(-1, 1, 1)
	_aim(skeleton, "LeftArm", "LeftForeArm", CARRY_LEFT[0], amount)
	_aim(skeleton, "LeftForeArm", "LeftHand", CARRY_LEFT[1], amount)
	_aim(skeleton, "RightArm", "RightForeArm", CARRY_LEFT[0] * mirror, amount)
	_aim(skeleton, "RightForeArm", "RightHand", CARRY_LEFT[1] * mirror, amount)


## Right arm back over the shoulder, then whipped through; the shoulders turn
## with it and the left arm points where the snowball goes.
func _apply_throw(skeleton: Skeleton3D, phase: float) -> void:
	var weight := smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.75, 1.0, phase))
	var key := _throw_key(phase)
	_rotate(skeleton, "Spine1", Vector3.UP, key[2] * weight)
	_aim(skeleton, "RightArm", "RightForeArm", key[0], weight)
	_aim(skeleton, "RightForeArm", "RightHand", key[1], weight)
	_aim(skeleton, "LeftArm", "LeftForeArm", Vector3(0.45, 0.0, 0.9), weight * 0.6)
	_aim(skeleton, "LeftForeArm", "LeftHand", Vector3(0.2, 0.1, 1.0), weight * 0.6)


## The throw pose at `phase`: [upper arm, forearm, twist], between the keys.
static func _throw_key(phase: float) -> Array:
	var first: Array = THROW_KEYS[0]
	if phase <= first[0]:
		return [first[1], first[2], first[3]]
	for i in range(1, THROW_KEYS.size()):
		var b: Array = THROW_KEYS[i]
		if phase <= b[0]:
			var a: Array = THROW_KEYS[i - 1]
			var t := smoothstep(a[0], b[0], phase)
			return [(a[1] as Vector3).normalized().slerp((b[1] as Vector3).normalized(), t),
					(a[2] as Vector3).normalized().slerp((b[2] as Vector3).normalized(), t), lerpf(a[3], b[3], t)]
	var last: Array = THROW_KEYS[-1]
	return [last[1], last[2], last[3]]


## Turns a bone (and so everything below it) about a body-space axis.
func _rotate(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone: int = _bones[bone_name]
	_set_global_basis(skeleton, bone, Basis(axis, angle) * skeleton.get_bone_global_pose(bone).basis.orthonormalized())


## Swings `bone_name` so it points from its joint towards `child_name` along
## `direction`, by `weight` (0 leaves it, 1 points it exactly).
func _aim(skeleton: Skeleton3D, bone_name: String, child_name: String, direction: Vector3, weight: float) -> void:
	var bone: int = _bones[bone_name]
	var here := skeleton.get_bone_global_pose(bone)
	var points := (skeleton.get_bone_global_pose(_bones[child_name]).origin - here.origin).normalized()
	var wanted := points.slerp(direction.normalized(), weight)
	if points.is_equal_approx(wanted):
		return
	_set_global_basis(skeleton, bone, Basis(Quaternion(points, wanted)) * here.basis.orthonormalized())


func _set_global_basis(skeleton: Skeleton3D, bone: int, global_basis: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * global_basis).get_rotation_quaternion())
