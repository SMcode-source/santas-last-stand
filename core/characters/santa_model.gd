class_name SantaModel
extends Node3D
## The realistic Santa: a Meshy-generated, Mixamo-rigged model with walk, run,
## punch, combo, hit and fall animations. Standing still he has no clip, so the
## idle is posed in code: he breathes, shifts his weight from foot to foot,
## looks about, and every few seconds busies himself with something (rubbing
## his hands warm, patting his belly with a chuckle, stroking his beard).
## Task poses (chopping with an axe, picking up and carrying a present) are
## started with perform(), and held items follow his hands via hold().
## hop() and wave() match SantaToy so the two are interchangeable.

const SCENE := preload("res://assets/characters/santa.glb")
const FABRIC := preload("res://core/visual/santa_fabric.gdshader")
const FUR_SHELL := preload("res://core/visual/santa_fur_shell.gdshader")
## Layers of fluff on the fur trim and beard, per graphics level (Low, Medium, High).
const FUR_LAYERS := [0, 3, 5]
const LOOPING := ["Walking", "Running"]
## Idle gestures, picked at random every few seconds while `fidget` is on.
const GESTURES := ["rub_hands", "pat_belly", "stroke_beard", "look_around"]
## How long each gesture lasts. Idle gestures ease back to standing at the
## end; task poses hold their final pose until the next perform() or relax().
const GESTURE_SECONDS := {"rub_hands": 3.6, "pat_belly": 2.8, "stroke_beard": 4.0, "look_around": 4.5,
		"reach": 0.8, "chop": 1.5, "pick_up": 1.0, "carry": 0.6, "drop_in": 0.9}
## When the axe bites during a "chop", as a fraction of the swing.
const CHOP_IMPACT := 0.58
## Seconds to blend from one pose into the next.
const BLEND := 0.45

## How far the arms hang out from the body when idle (his belly needs room).
const ARM_SPREAD := deg_to_rad(14.0)
const ELBOW_BEND := deg_to_rad(18.0)

var skeleton: Skeleton3D
var animations: AnimationPlayer

var _time := 0.0
var _hop := 0.0
var _wave := 0.0
## Whether he fidgets with idle gestures when left standing.
var fidget := true
var _gesture := ""
var _gesture_time := 0.0
var _prev_gesture := ""
var _prev_time := 0.0
var _until_gesture := 2.5
# Something in his hands: "axe" (gripped by the handle) or "box" (between both hands).
var _held: Node3D
var _held_mode := ""
## Where a swung axe should land (global); the blade is aimed at it on the downswing.
var strike_point := Vector3.INF
var _aim := 0.0
var _rng := RandomNumberGenerator.new()
# Height of the hips above the feet, in skeleton units, for the weight shift.
var _hip_height := 1.0
var _hip_rest := Vector3.ZERO
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
	_hip_rest = skeleton.get_bone_rest(_bones["Hips"]).origin
	_hip_height = skeleton.get_bone_global_rest(_bones["Hips"]).origin.y
	_rng.randomize()
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
	# Only a 256-pixel copy is needed: take that mipmap straight out of the
	# (compressed) texture rather than unpacking the full-size image.
	var level := 0
	while albedo.has_mipmaps() and (albedo.get_width() >> level) > 256 and level < albedo.get_mipmap_count():
		level += 1
	if level > 0:
		var start := albedo.get_mipmap_offset(level)
		var end := albedo.get_mipmap_offset(level + 1) if level < albedo.get_mipmap_count() else albedo.get_data().size()
		albedo = Image.create_from_data(albedo.get_width() >> level, albedo.get_height() >> level, false,
				albedo.get_format(), albedo.get_data().slice(start, end))
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
	# Keep a triangle if most of its corners are fur. The vertices are shared
	# as they are (only the triangle list changes), which keeps this quick in
	# the web build; the graphics card only touches the vertices in use.
	var kept := PackedInt32Array()
	kept.resize(indices.size())
	var count := 0
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if is_fur[a] + is_fur[b] + is_fur[c] >= 2:
			kept[count] = a
			kept[count + 1] = b
			kept[count + 2] = c
			count += 3
	kept.resize(count)
	var result := arrays.duplicate()
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


## Starts a gesture or task pose now, blending from whatever he was doing.
func perform(gesture: String) -> void:
	_prev_gesture = _gesture
	_prev_time = _gesture_time
	_gesture = gesture
	_gesture_time = 0.0


## Drops any task pose and eases back to standing.
func relax() -> void:
	if not _gesture.is_empty():
		perform("")


## Puts `item` in his hands. "axe" grips it by the handle; "box" holds it
## between both hands. It follows his hands until let_go().
func hold(item: Node3D, mode: String) -> void:
	_held = item
	_held_mode = mode
	item.top_level = true
	_place_held()


func let_go() -> Node3D:
	var item := _held
	_held = null
	_held_mode = ""
	return item


## The time-based weight of the current gesture (0 to 1).
func _gesture_weight() -> float:
	if _gesture.is_empty():
		return 0.0
	var fade_in := smoothstep(0.0, BLEND, _gesture_time)
	if _gesture not in GESTURES:
		return fade_in
	var length: float = GESTURE_SECONDS[_gesture]
	return fade_in * smoothstep(length, length - 0.6, _gesture_time)


func _update_gesture(delta: float) -> void:
	_gesture_time += delta
	if _gesture.is_empty():
		_until_gesture -= delta
		if fidget and _until_gesture <= 0.0 and _wave <= 0.0:
			perform(GESTURES[_rng.randi() % GESTURES.size()])
		return
	if _gesture in GESTURES and _gesture_time >= GESTURE_SECONDS[_gesture]:
		_gesture = ""
		_prev_gesture = ""
		_until_gesture = _rng.randf_range(3.0, 7.0)


func _process(delta: float) -> void:
	_time += delta
	_hop = maxf(0.0, _hop - delta * 2.4)
	_wave = maxf(0.0, _wave - delta * 0.45)
	var hop_height := sin(_hop * PI) * 0.16 if _hop > 0.0 else 0.0
	_model.position.y = hop_height
	if animations.is_playing():
		_place_held()
		return

	_update_gesture(delta)
	var calm := 1.0 - smoothstep(0.0, 0.15, _wave)
	var w := _gesture_weight() * calm
	var w_prev := 0.0 if _prev_gesture.is_empty() else (1.0 - smoothstep(0.0, BLEND, _gesture_time)) * calm
	var cur := _pose(_gesture, _gesture_time)
	var prev := _pose(_prev_gesture, minf(_prev_time, GESTURE_SECONDS.get(_prev_gesture, 0.0)))

	# Breathing: a slow rise and fall of the chest and shoulders.
	var breath := sin(_time * 1.5)
	# Weight shifts from one foot to the other: the hips slide and tilt over
	# planted feet while the spine leans back to keep the head level.
	var sway := sin(_time * 0.42) + 0.3 * sin(_time * 1.1)
	var tilt := sway * 0.014
	skeleton.set_bone_pose_position(_bones["Hips"], _hip_rest + Vector3(-tilt * _hip_height, 0, 0))
	_turn("Hips", Vector3.BACK, tilt, Vector3.UP, sin(_time * 0.27) * 0.05)
	var bend := _mix(0.0, prev, cur, "bend", w_prev, w)
	var twist := _mix(0.0, prev, cur, "twist", w_prev, w)
	_turn("Spine", Vector3.BACK, -tilt * 1.3, Vector3.RIGHT, bend * 0.3)
	_turn("Spine1", Vector3.RIGHT, breath * 0.02 + bend * 0.35, Vector3.UP, twist * 0.5)
	_turn("Spine2", Vector3.RIGHT, breath * 0.03 + bend * 0.35, Vector3.UP, twist * 0.5)

	# The head drifts about on its own, and follows whatever he is doing.
	var look_yaw := _mix(sin(_time * 0.45) * 0.16 + sin(_time * 1.3) * 0.03, prev, cur, "yaw", w_prev, w)
	var look_pitch := _mix(sin(_time * 0.7) * 0.04, prev, cur, "pitch", w_prev, w)
	_aim = _mix(0.0, prev, cur, "aim", w_prev, w)
	_turn("Head", Vector3.UP, look_yaw, Vector3.RIGHT, look_pitch)

	var wave_amount := smoothstep(0.0, 0.15, _wave) * smoothstep(1.0, 0.85, _wave)
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var lift := hop_height * 1.2 + breath * 0.025
		var arm_dir := Vector3(side * sin(ARM_SPREAD + lift), -cos(ARM_SPREAD + lift), 0.06 + sway * side * 0.03)
		arm_dir = arm_dir.normalized()
		# Forearm hangs on from the upper arm, the elbow bent a little forward.
		var fore_dir := (arm_dir * cos(ELBOW_BEND) + Vector3.BACK * sin(ELBOW_BEND)).normalized()
		for layer: Array in [[prev, w_prev], [cur, w]]:
			var arm: Array = (layer[0] as Dictionary).get(prefix, [])
			if not arm.is_empty() and layer[1] > 0.0:
				arm_dir = arm_dir.slerp(arm[0], layer[1])
				fore_dir = fore_dir.slerp(arm[1], layer[1])
		if side < 0.0 and wave_amount > 0.0:
			# Elbow kept low and forward (raising it to the shoulder tears the
			# coat open under the arm), forearm up and swinging.
			var wave_arm := Vector3(-0.55, -0.6, 0.45).normalized()
			var wave_fore := Vector3(-0.05, 1.0, 0.3).normalized().rotated(Vector3.BACK, sin(_time * 9.0) * 0.35)
			arm_dir = arm_dir.slerp(wave_arm, wave_amount)
			fore_dir = fore_dir.slerp(wave_fore, wave_amount)
		_aim_arm(prefix, arm_dir, fore_dir)
	_place_held()


## Blends one value of a pose: the idle value, then the previous pose fading
## out, then the current pose fading in.
static func _mix(idle: float, prev: Dictionary, cur: Dictionary, key: String, w_prev: float, w: float) -> float:
	var value := idle
	if prev.has(key):
		value = lerpf(value, prev[key], w_prev)
	if cur.has(key):
		value = lerpf(value, cur[key], w)
	return value


## A direction in his front-to-back plane: 0 is straight ahead, PI/2 straight
## down, negative angles go up and back over his head. `inward` leans it
## sideways (+x is his left).
static func _arc(angle: float, inward := 0.0) -> Vector3:
	return Vector3(inward, -sin(angle), cos(angle)).normalized()


## A gesture's pose at time `t`. Arms are [upper arm, forearm] directions in
## his body space ("Left" is his left, +x); "bend" leans him forward, "twist"
## turns his shoulders, "yaw" and "pitch" aim his head (pitch down positive).
func _pose(gesture: String, t: float) -> Dictionary:
	match gesture:
		"rub_hands":
			# Hands together in front of his belly, sliding back and forth.
			var rub := sin(t * 11.0) * 0.22
			return {"pitch": 0.28, "yaw": 0.0,
				"Left": [Vector3(0.22, -0.78, 0.58).normalized(), Vector3(-0.72, 0.28, 0.62 + rub).normalized()],
				"Right": [Vector3(-0.22, -0.78, 0.58).normalized(), Vector3(0.72, 0.28, 0.62 - rub).normalized()]}
		"pat_belly":
			# Hands on the sides of his belly, patting in time with a chuckle.
			var chuckle := absf(sin(t * 9.0))
			var pat_l := maxf(0.0, sin(t * 9.0 + 1.0)) * 0.35
			var pat_r := maxf(0.0, sin(t * 9.0 - 1.0)) * 0.35
			return {"bend": -0.08 - chuckle * 0.08, "pitch": -0.14 - chuckle * 0.06,
				"Left": [Vector3(0.42, -0.86, 0.3).normalized(), Vector3(-0.38, -0.3 + pat_l, 0.88).normalized()],
				"Right": [Vector3(-0.42, -0.86, 0.3).normalized(), Vector3(0.38, -0.3 + pat_r, 0.88).normalized()]}
		"stroke_beard":
			# Right hand drawn slowly down his beard, again and again.
			var stroke := 0.5 + 0.5 * sin(t * 2.4)
			return {"pitch": 0.1, "yaw": -0.2 + sin(t * 0.8) * 0.08,
				"Right": [Vector3(-0.3, -0.75, 0.6).normalized(), Vector3(0.4, 0.45 - stroke * 0.45, 0.8).normalized()]}
		"look_around":
			return {"twist": sin(t * 1.4) * 0.16, "yaw": sin(t * 1.4) * 0.55, "pitch": -0.06}
		"reach":
			# Leaning over to take hold of something low in front (the axe).
			return {"bend": 0.55, "pitch": 0.35,
				"Right": [_arc(0.75, -0.2), _arc(1.0, -0.1)]}
		"chop":
			# Axe swung up over his head, brought down hard, and followed through.
			var p := t / float(GESTURE_SECONDS["chop"])
			var raise := smoothstep(0.0, 0.48, p)
			if p > CHOP_IMPACT - 0.1:
				raise = 1.0 - smoothstep(CHOP_IMPACT - 0.1, CHOP_IMPACT, p)
			# At the bottom the arms are out in front, so the axe lands on the log
			# rather than swinging down between his legs.
			var arm_angle := lerpf(0.45, -1.25, raise)
			var fore_angle := lerpf(0.25, -2.1, raise)
			return {"bend": lerpf(0.4, -0.15, raise), "pitch": lerpf(0.4, 0.0, raise), "aim": 1.0 - raise,
				"Left": [_arc(arm_angle, -0.14), _arc(fore_angle, -0.22)],
				"Right": [_arc(arm_angle, 0.14), _arc(fore_angle, 0.22)]}
		"pick_up":
			# Bent right over, both hands down at a present on the ground.
			return {"bend": 1.3, "pitch": 0.3,
				"Left": [_arc(1.1, 0.25), _arc(1.25, -0.25)],
				"Right": [_arc(1.1, -0.25), _arc(1.25, 0.25)]}
		"carry":
			# A present held in both hands against his belly.
			return {"bend": -0.05, "pitch": 0.15,
				"Left": [Vector3(0.25, -0.85, 0.45).normalized(), Vector3(-0.5, 0.1, 0.85).normalized()],
				"Right": [Vector3(-0.25, -0.85, 0.45).normalized(), Vector3(0.5, 0.1, 0.85).normalized()]}
		"drop_in":
			# Leaning over the sack, lowering the present in.
			return {"bend": 0.5, "pitch": 0.4,
				"Left": [_arc(0.65, 0.15), _arc(0.75, -0.4)],
				"Right": [_arc(0.65, -0.15), _arc(0.75, 0.4)]}
	return {}


## Moves whatever he is holding to his hands.
func _place_held() -> void:
	if _held == null:
		return
	var to_world := skeleton.global_transform
	var right := to_world * skeleton.get_bone_global_pose(_bones["RightHand"]).origin
	var left := to_world * skeleton.get_bone_global_pose(_bones["LeftHand"]).origin
	var body := global_basis.orthonormalized()
	if _held_mode == "box":
		_held.global_transform = Transform3D(body, (left + right) / 2.0 + body * Vector3(0, -0.06, 0.07))
		return
	# Axe: the handle carries on from the forearm, cocked a little further down
	# at the wrist, with the cutting edge leading the swing. In the model the
	# handle runs along +y with the head at the top and the edge facing +z.
	var fore := skeleton.get_bone_global_pose(_bones["RightHand"]).origin \
			- skeleton.get_bone_global_pose(_bones["RightForeArm"]).origin
	var along := (to_world.basis * fore).normalized()
	along = along.rotated(body.x, 0.45)
	var grip := (left + right) / 2.0
	if _aim > 0.0 and strike_point.is_finite():
		along = along.slerp((strike_point - grip).normalized(), _aim)
	var edge := along.rotated(body.x, PI / 2.0)
	var basis := Basis(along.cross(edge), along, edge).orthonormalized()
	_held.global_transform = Transform3D(basis, grip - basis * Vector3(0, -0.1, 0))


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
	if parent < 0:
		return Basis.IDENTITY
	return skeleton.get_bone_global_rest(parent).basis.orthonormalized()


func _bone_origin(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(_bones[bone]).origin
