class_name SantaModel
extends Node3D
## The realistic Santa: a Meshy-generated, Mixamo-rigged model with walk, run,
## punch, combo, hit and fall animations. Standing still he has no clip, so the
## idle is posed in code: arms lowered from the A-pose, breathing, looking
## around. hop() and wave() match SantaToy so the two are interchangeable.

const SCENE := preload("res://assets/characters/santa.glb")
const FABRIC := preload("res://core/visual/santa_fabric.gdshader")
const FUR_SHELL := preload("res://core/visual/santa_fur_shell.gdshader")
## Layers of fluff on the fur trim and beard, per graphics level (Low, Medium, High).
const FUR_LAYERS := [0, 3, 5]
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
var _fabric: ShaderMaterial
# Just the fur trim, beard and bobble, cut out of the body mesh so the layers of
# fluff only redraw those few triangles.
var _fur: MeshInstance3D
static var _fur_mesh: ArrayMesh
var _bones := {}
# Rest orientations in skeleton space, captured once.
var _rest_global := {}


func _ready() -> void:
	name = "Santa"
	_model = SCENE.instantiate()
	add_child(_model)
	_dress()
	add_to_group(GraphicsQuality.LISTENERS)
	apply_quality(Engine.get_meta("graphics_level", GraphicsQuality.Level.MEDIUM))
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


## Swaps the model's plain material for velvet and fur, keeping its textures.
func _dress() -> void:
	var mesh: MeshInstance3D = _model.find_children("*", "MeshInstance3D", true, false)[0]
	var plain := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_fabric = ShaderMaterial.new()
	_fabric.shader = FABRIC
	_fabric.set_shader_parameter("albedo_tex", plain.albedo_texture)
	_fabric.set_shader_parameter("orm_tex", plain.roughness_texture)
	_fabric.set_shader_parameter("normal_tex", plain.normal_texture)
	_fabric.set_shader_parameter("noise_tex", CharacterFinish.noise())
	_fabric.set_shader_parameter("cell_tex", CharacterFinish.cells())
	mesh.set_surface_override_material(0, _fabric)

	if _fur_mesh == null:
		_fur_mesh = _cut_fur(mesh.mesh as ArrayMesh, plain.albedo_texture.get_image())
	_fur = MeshInstance3D.new()
	_fur.name = "Fur"
	_fur.mesh = _fur_mesh
	_fur.skin = mesh.skin
	_fur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_sibling(_fur)
	_fur.transform = mesh.transform
	_fur.skeleton = _fur.get_path_to(mesh.get_node(mesh.skeleton))


## Called by GraphicsQuality: more layers of fluff on faster machines.
func apply_quality(level: int) -> void:
	var count: int = FUR_LAYERS[level]
	_fur.visible = count > 0
	var first: ShaderMaterial = null
	var previous: ShaderMaterial = null
	for i in count:
		var shell := ShaderMaterial.new()
		shell.shader = FUR_SHELL
		shell.set_shader_parameter("albedo_tex", _fabric.get_shader_parameter("albedo_tex"))
		shell.set_shader_parameter("noise_tex", CharacterFinish.noise())
		shell.set_shader_parameter("cell_tex", CharacterFinish.cells())
		shell.set_shader_parameter("layer", float(i + 1) / count)
		if previous:
			previous.next_pass = shell
		else:
			first = shell
		previous = shell
	_fur.material_override = first


## The triangles of `source` whose texture is white or pale grey (fur, beard,
## bobble), with their skinning, as a mesh of their own.
static func _cut_fur(source: ArrayMesh, albedo: Image) -> ArrayMesh:
	if albedo.is_compressed():
		albedo.decompress()
	albedo.resize(256, 256, Image.INTERPOLATE_BILINEAR)
	albedo.convert(Image.FORMAT_RGB8)
	var pixels := albedo.get_data()
	var arrays := source.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var is_fur := PackedByteArray()
	is_fur.resize(uvs.size())
	for v in uvs.size():
		var x := clampi(int(fposmod(uvs[v].x, 1.0) * 256.0), 0, 255)
		var y := clampi(int(fposmod(uvs[v].y, 1.0) * 256.0), 0, 255)
		var at := (y * 256 + x) * 3
		var top := maxi(pixels[at], maxi(pixels[at + 1], pixels[at + 2]))
		var low := mini(pixels[at], mini(pixels[at + 1], pixels[at + 2]))
		is_fur[v] = 1 if top > 140 and top - low < top * 0.25 else 0
	# Keep a triangle if most of its corners are fur; renumber the vertices it uses.
	var remap := PackedInt32Array()
	remap.resize(uvs.size())
	remap.fill(-1)
	var kept := PackedInt32Array()
	var used := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if is_fur[indices[t]] + is_fur[indices[t + 1]] + is_fur[indices[t + 2]] < 2:
			continue
		for k in 3:
			var old := indices[t + k]
			if remap[old] < 0:
				remap[old] = used.size()
				used.append(old)
			kept.append(remap[old])
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	for slot in Mesh.ARRAY_MAX:
		var data = arrays[slot]
		if data == null or slot == Mesh.ARRAY_INDEX:
			continue
		var stride: int = data.size() / uvs.size()
		var picked = data.duplicate()
		picked.resize(used.size() * stride)
		for i in used.size():
			for c in stride:
				picked[i * stride + c] = data[used[i] * stride + c]
		result[slot] = picked
	result[Mesh.ARRAY_INDEX] = kept
	var flags := source.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result, [], {}, flags)
	return mesh


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
			# Elbow kept low and forward (raising it to the shoulder tears the
			# coat open under the arm), forearm up and swinging.
			var wave_arm := Vector3(-0.55, -0.6, 0.45).normalized()
			var wave_fore := Vector3(-0.05, 1.0, 0.3).normalized().rotated(Vector3.BACK, sin(_time * 9.0) * 0.35)
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
