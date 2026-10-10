class_name SantaController
extends CharacterBody3D
## Santa on foot, seen from behind: the shared controller for the platformer,
## brawler, stealth, shooter and climbing chapters. It moves relative to the
## camera with acceleration, walks or runs (Shift) with the clip and its speed
## matched to his pace so his feet do not slide, jumps with coyote time, a
## jump buffer and a variable height, sticks to slopes, and turns smoothly to
## face where he is going. Punch, snowball, grab and sneak are abilities a
## chapter switches on or off (see set_abilities). Tunables live in
## data/balance/controllers.json ("santa").
##
## A chapter drops him in with:
##     var santa := SantaController.spawn(self, $Start.global_transform, {"punch": false})
## and drives him from a script by turning off `input_enabled` and setting
## `move_intent`, `run_intent` and `sneak_intent`, then calling jump(),
## punch(), throw_snowball() or interact().

signal jumped
signal landed(fall_speed: float)
signal punched
signal threw
## A punch or snowball connected with something that takes hits.
signal hit_landed(target: Node, kind: String)
signal grabbed(item: Node3D)
signal dropped(item: Node3D)

const ABILITIES := ["jump", "run", "punch", "throw", "grab", "sneak"]
## Where a carried present sits, in his body space.
const CARRY_OFFSET := Vector3(0.0, 1.0, 0.5)
## Where a snowball leaves his hand, in his body space.
const THROW_FROM := Vector3(-0.3, 1.6, 0.45)
## The moment in the Running clip held while he is in the air: legs apart in
## mid-stride, which reads as a leap.
const LEAP_FRAME := 0.45
const CAPSULE_RADIUS := 0.36
const CAPSULE_HEIGHT := 1.75

# --- Tunables: data/balance/controllers.json, "santa" ---
var walk_speed := 1.9
var run_speed := 5.4
var sneak_speed := 1.1
var acceleration := 16.0
var deceleration := 22.0
var air_acceleration := 8.0
var air_deceleration := 2.5
## How quickly he turns to face his direction (higher is snappier).
var turn_rate := 13.0
var jump_height := 1.3
## Seconds from take-off to the top of a full jump.
var jump_rise_time := 0.36
## Gravity on the way down, and after letting go of jump, as a multiple of the rise.
var fall_gravity_scale := 1.7
var max_fall_speed := 24.0
## Upward speed kept when jump is let go early (a short hop).
var jump_cut := 0.45
var coyote_time := 0.12
var jump_buffer := 0.14
var floor_snap := 0.5
var max_slope_degrees := 46.0
var walk_clip_speed := 1.05
var run_clip_speed := 3.9
var run_clip_above := 2.5
var idle_below := 0.25
var punch_clip_start := 0.4
var punch_rate := 1.7
var punch_hit_from := 0.9
var punch_hit_to := 1.15
var punch_clip_end := 1.65
var punch_move_factor := 0.15
var punch_lunge := 3.0
var punch_force := 7.0
var punch_damage := 2.0
var throw_time := 0.5
var throw_release := 0.42
var throw_speed := 18.0
var throw_lift_degrees := 8.0
var throw_cooldown := 0.15
var throw_move_factor := 0.7
var snowball_damage := 1.0
var grab_range := 1.8
var toss_speed := 7.0
var land_dip := 0.5

## Which abilities this chapter allows (see ABILITIES).
var abilities := {"jump": true, "run": true, "punch": true, "throw": true, "grab": true, "sneak": true}
## Read the player's keys, mouse and gamepad. Turn off to drive him from a
## script through the *_intent variables and the action methods.
var input_enabled := true
## Where he should go, flat in world space, up to length 1 (full speed).
var move_intent := Vector3.ZERO
var run_intent := false
var sneak_intent := false

var santa: SantaModel
var pose: SantaPose
var camera: SantaCamera
var snowballs: SnowballPool
## His drawn position and facing: smoothed between physics steps, so he moves
## evenly on screens faster than the physics rate. The camera follows this.
var facing: Node3D
var hitbox: Area3D
var carried: Node3D
## Which way he faces: 0 is +z.
var yaw := 0.0

var _gravity_up := 20.0
var _jump_speed := 7.0
var _coyote := 0.0
var _buffer := 0.0
var _jump_held := false
var _rising := false
var _air_time := 0.0
var _punch_t := -1.0
var _struck: Array[Node] = []
var _throw_t := -1.0
var _thrown := false
var _throw_dir := Vector3.FORWARD
var _cooldown := 0.0
var _dip := 0.0
var _crouch := 0.0
var _lean := 0.0
var _clip := ""
var _leaping := false
var _sneaking := false
var _prev_origin := Vector3.ZERO
var _origin := Vector3.ZERO
var _shadow: MeshInstance3D
var _blob_wanted := true


## Makes Santa (with his camera) at `at` in `parent`, with only the abilities
## listed in `flags` changed from the defaults (all on).
static func spawn(parent: Node, at: Transform3D, flags := {}) -> SantaController:
	var controller := SantaController.new()
	parent.add_child(controller)
	controller.set_abilities(flags)
	controller.place(at)
	controller.camera.make_current()
	return controller


func _init() -> void:
	name = "SantaController"
	Balance.apply(self, "controllers", "santa")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.WALKER_BOUNDS
	floor_snap_length = floor_snap
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_constant_speed = true
	floor_block_on_wall = true
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	_gravity_up = 2.0 * jump_height / (jump_rise_time * jump_rise_time)
	_jump_speed = 2.0 * jump_height / jump_rise_time
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position.y = CAPSULE_HEIGHT / 2.0
	add_child(shape)


func _ready() -> void:
	facing = Node3D.new()
	facing.name = "Facing"
	facing.top_level = true
	add_child(facing)
	santa = SantaModel.new()
	facing.add_child(santa)
	pose = SantaPose.new()
	pose.name = "Pose"
	santa.skeleton.add_child(pose)
	_add_hitbox()
	snowballs = SnowballPool.new()
	snowballs.exclude = [get_rid()]
	snowballs.damage = snowball_damage
	add_child(snowballs)
	_shadow = _blob_shadow()
	add_child(_shadow)
	add_to_group(GraphicsQuality.LISTENERS)
	apply_quality(Engine.get_meta("graphics_level", GraphicsQuality.Level.MEDIUM))
	camera = SantaCamera.new()
	camera.target = facing
	camera.body = self
	add_child(camera)
	place(global_transform)


## Puts him at `at`, facing its +z, standing still, with the camera behind.
func place(at: Transform3D) -> void:
	global_position = at.origin
	var ahead := at.basis.z
	yaw = atan2(ahead.x, ahead.z) if Vector2(ahead.x, ahead.z).length() > 0.01 else 0.0
	velocity = Vector3.ZERO
	_prev_origin = at.origin
	_origin = at.origin
	if facing:
		facing.global_transform = Transform3D(Basis(Vector3.UP, yaw), at.origin)
	if camera:
		camera.look_behind(yaw)


func set_ability(ability: String, on: bool) -> void:
	assert(ability in ABILITIES, "Unknown ability %s" % ability)
	abilities[ability] = on
	if not on:
		match ability:
			"grab":
				if carried:
					drop()
			"sneak":
				sneak_intent = false


## Changes the abilities named in `flags` ({"punch": false, ...}); others stay.
func set_abilities(flags: Dictionary) -> void:
	for ability: String in flags:
		set_ability(ability, flags[ability])


func has_ability(ability: String) -> bool:
	return abilities.get(ability, false)


func is_punching() -> bool:
	return _punch_t >= 0.0


func is_sneaking() -> bool:
	return _sneaking


# --- Actions (called by the player's input, or by a script) ---

## Asks for a jump. It happens as soon as he can: buffered for a moment if he
## is still in the air, and allowed for a moment after walking off an edge.
func jump() -> void:
	if has_ability("jump"):
		_buffer = jump_buffer
		_jump_held = true


## Lets go of jump: a jump still rising is cut short.
func release_jump() -> void:
	_jump_held = false


func punch() -> void:
	if not has_ability("punch") or _punch_t >= 0.0 or _throw_t >= 0.0 or carried:
		return
	_punch_t = punch_clip_start
	_struck.clear()
	_set_clip("Attack")
	santa.animations.seek(punch_clip_start, true)
	santa.animations.speed_scale = punch_rate
	punched.emit()


## Throws a snowball where the camera looks, or tosses whatever he carries.
func throw_snowball() -> void:
	if carried:
		_toss()
		return
	if not has_ability("throw") or _throw_t >= 0.0 or _punch_t >= 0.0 or _cooldown > 0.0:
		return
	_throw_t = 0.0
	_thrown = false
	_throw_dir = _aim()


## Picks up the nearest grabbable thing in front of him, or puts down what he
## carries. With nothing to grab, he waves.
func interact() -> void:
	if carried:
		drop()
		return
	var item := _grabbable() if has_ability("grab") else null
	if item:
		pick_up(item)
	elif _punch_t < 0.0 and _throw_t < 0.0:
		santa.wave()


func pick_up(item: Node3D) -> void:
	carried = item
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
		add_collision_exception_with(item)
	if item is CollisionObject3D:
		snowballs.exclude.append((item as CollisionObject3D).get_rid())
	grabbed.emit(item)


func drop() -> void:
	var item := carried
	if item == null:
		return
	_let_go(item, Vector3(velocity.x, 0.0, velocity.z))
	item.global_position = global_position + Basis(Vector3.UP, yaw) * Vector3(0, 0.35, 0.85)
	dropped.emit(item)


# --- Physics ---

func _physics_process(delta: float) -> void:
	if input_enabled:
		_read_input()
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)
	_move_flat(delta, on_floor)
	_fall(delta, on_floor)
	_try_jump()
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor:
		_land(fall_speed)
	_update_facing(delta)
	_update_punch(delta)
	_update_throw(delta)
	_prev_origin = _origin
	_origin = global_position


func _read_input() -> void:
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := camera.flat_forward() if camera else Vector3.BACK
	var right := camera.flat_right() if camera else Vector3.LEFT
	move_intent = right * stick.x - forward * stick.y
	run_intent = Input.is_action_pressed("run")
	sneak_intent = Input.is_action_pressed("sneak")
	if _jump_held and not Input.is_action_pressed("jump"):
		release_jump()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or event.is_echo():
		return
	if event.is_action_pressed("jump"):
		jump()
	elif event.is_action_pressed("attack"):
		punch()
	elif event.is_action_pressed("throw"):
		throw_snowball()
	elif event.is_action_pressed("interact"):
		interact()


func _update_timers(delta: float, on_floor: bool) -> void:
	_buffer = maxf(0.0, _buffer - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_dip = maxf(0.0, _dip - delta * 3.0)
	if on_floor:
		_coyote = coyote_time
		_air_time = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		_air_time += delta


func _target_speed() -> float:
	_sneaking = sneak_intent and has_ability("sneak") and is_on_floor()
	var speed := walk_speed
	if _sneaking:
		speed = sneak_speed
	elif run_intent and has_ability("run"):
		speed = run_speed
	if _punch_t >= 0.0:
		speed *= punch_move_factor
	elif _throw_t >= 0.0:
		speed *= throw_move_factor
	return speed


func _move_flat(delta: float, on_floor: bool) -> void:
	var wish := move_intent
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * _target_speed()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if on_floor:
		rate = acceleration if wish.length() > 0.05 else deceleration
		# Turning round is as quick as stopping and starting again.
		if target.dot(flat) < 0.0:
			rate += deceleration
	else:
		rate = air_acceleration if wish.length() > 0.05 else air_deceleration
	flat = flat.move_toward(target, rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z


func _fall(delta: float, on_floor: bool) -> void:
	if on_floor and velocity.y <= 0.0:
		_rising = false
		return
	if _rising and (not _jump_held or velocity.y <= 0.0):
		# Let go early: a short hop. At the top: start falling.
		if velocity.y > 0.0:
			velocity.y *= jump_cut
		_rising = false
	var gravity := _gravity_up if _rising else _gravity_up * fall_gravity_scale
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


func _try_jump() -> void:
	if _buffer <= 0.0 or _coyote <= 0.0 or _punch_t >= 0.0 or not has_ability("jump"):
		return
	_buffer = 0.0
	_coyote = 0.0
	velocity.y = _jump_speed
	_rising = _jump_held
	jumped.emit()


func _land(fall_speed: float) -> void:
	_dip = clampf(fall_speed / 14.0, 0.15, 1.0)
	landed.emit(fall_speed)


func _update_facing(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var goal := yaw
	if _throw_t >= 0.0:
		goal = atan2(_throw_dir.x, _throw_dir.z)
	elif _punch_t >= 0.0:
		pass
	elif flat.length() > 0.4:
		goal = atan2(flat.x, flat.z)
	elif move_intent.length() > 0.2:
		goal = atan2(move_intent.x, move_intent.z)
	var rate := turn_rate * (2.0 if _throw_t >= 0.0 else 1.0)
	yaw = lerp_angle(yaw, goal, 1.0 - exp(-rate * delta))
	hitbox.rotation.y = yaw


# --- Combat ---

func _add_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = PhysicsLayers.HURTBOX
	hitbox.monitorable = false
	hitbox.monitoring = false
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.7
	shape.shape = ball
	shape.position = Vector3(0.0, 1.0, 0.85)
	hitbox.add_child(shape)
	hitbox.area_entered.connect(_strike)
	hitbox.body_entered.connect(_strike)
	add_child(hitbox)


func _update_punch(delta: float) -> void:
	if _punch_t < 0.0:
		return
	var before := _punch_t
	_punch_t += delta * punch_rate
	var active := _punch_t >= punch_hit_from and _punch_t <= punch_hit_to
	if active != hitbox.monitoring:
		hitbox.monitoring = active
	if before < punch_hit_from and _punch_t >= punch_hit_from:
		# Throw his weight into the blow.
		velocity += Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, punch_lunge)
	if _punch_t >= punch_clip_end:
		_punch_t = -1.0
		hitbox.monitoring = false


func _strike(other: Node) -> void:
	var receiver := SnowballPool.hit_receiver(other)
	if receiver == null or receiver == self or receiver in _struck:
		return
	_struck.append(receiver)
	var ahead := Basis(Vector3.UP, yaw) * Vector3.BACK
	receiver.take_hit({"kind": "punch", "damage": punch_damage, "force": punch_force,
			"direction": ahead, "at": hitbox.global_position + ahead * 0.8 + Vector3.UP, "by": self})
	hit_landed.emit(receiver, "punch")


func _update_throw(delta: float) -> void:
	if _throw_t < 0.0:
		return
	_throw_t += delta / throw_time
	if not _thrown and _throw_t >= throw_release:
		_thrown = true
		var from := global_position + Basis(Vector3.UP, yaw) * THROW_FROM
		snowballs.launch(from, _throw_dir * throw_speed + Vector3(velocity.x, 0.0, velocity.z) * 0.5, self)
		threw.emit()
	if _throw_t >= 1.0:
		_throw_t = -1.0
		_cooldown = throw_cooldown


## Where a throw goes: along the camera's view, lifted a little for the arc.
func _aim() -> Vector3:
	var ahead := Basis(Vector3.UP, yaw) * Vector3.BACK
	var up_angle := 0.0
	if camera:
		var view := -camera.camera.global_basis.z
		ahead = Vector3(view.x, 0.0, view.z).normalized()
		up_angle = clampf(asin(clampf(view.y, -1.0, 1.0)) + 0.25, -0.3, 0.7)
	up_angle += deg_to_rad(throw_lift_degrees)
	return (ahead * cos(up_angle) + Vector3.UP * sin(up_angle)).normalized()


# --- Grabbing ---

func _grabbable() -> Node3D:
	var ahead := Basis(Vector3.UP, yaw) * Vector3.BACK
	var best: Node3D = null
	var best_distance := grab_range
	for node in get_tree().get_nodes_in_group("grabbable"):
		var item := node as Node3D
		var to := item.global_position - global_position
		to.y = 0.0
		if to.length() < best_distance and (to.length() < 0.5 or ahead.dot(to.normalized()) > 0.2):
			best = item
			best_distance = to.length()
	return best


func _toss() -> void:
	var item := carried
	var ahead := Basis(Vector3.UP, yaw) * Vector3.BACK
	_let_go(item, ahead * toss_speed + Vector3.UP * toss_speed * 0.45)
	dropped.emit(item)


func _let_go(item: Node3D, push: Vector3) -> void:
	carried = null
	if item is RigidBody3D:
		var rigid := item as RigidBody3D
		rigid.freeze = false
		rigid.linear_velocity = push
		remove_collision_exception_with.call_deferred(item)
	if item is CollisionObject3D:
		snowballs.exclude.erase((item as CollisionObject3D).get_rid())


# --- Drawing ---

func _process(delta: float) -> void:
	var at := _prev_origin.lerp(_origin, Engine.get_physics_interpolation_fraction())
	facing.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	if carried:
		carried.global_transform = facing.global_transform * Transform3D(Basis.IDENTITY, CARRY_OFFSET)
	_update_pose(delta)
	_update_clip()
	_update_shadow(at)


func _update_pose(delta: float) -> void:
	var settle := 1.0 - exp(-delta * 10.0)
	_crouch = lerpf(_crouch, 1.0 if _sneaking else 0.0, settle)
	var flat := Vector3(velocity.x, 0.0, velocity.z).length()
	var lean_goal := 0.0
	if is_on_floor() and _punch_t < 0.0:
		lean_goal = clampf(flat / run_speed, 0.0, 1.0) * 0.12
	_lean = lerpf(_lean, lean_goal, settle)
	pose.crouch = maxf(_crouch, sin(minf(_dip, 1.0) * PI * 0.5) * land_dip)
	pose.lean = _lean
	pose.throw_phase = _throw_t
	pose.carry = move_toward(pose.carry, 1.0 if carried else 0.0, delta * 5.0)


## Picks the clip for what he is doing, and plays it at the speed that keeps
## his feet planted.
func _update_clip() -> void:
	if _punch_t >= 0.0:
		return
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var clip := ""
	var rate := 1.0
	var in_air := _air_time > 0.1
	if in_air:
		# No jump clip: a running stride, nearly frozen, reads as a leap.
		clip = "Running"
		rate = 0.12
	elif speed > run_clip_above and not _sneaking:
		clip = "Running"
		rate = speed / run_clip_speed
	elif speed > idle_below:
		clip = "Walking"
		rate = speed / (walk_clip_speed * (0.75 if _sneaking else 1.0))
	_set_clip(clip)
	if in_air and not _leaping:
		santa.animations.seek(LEAP_FRAME, true)
	_leaping = in_air
	santa.animations.speed_scale = rate


func _set_clip(clip: String) -> void:
	if clip == _clip:
		return
	pose.settle()
	_clip = clip
	santa.play(clip)
	santa.fidget = clip.is_empty()
	santa.animations.speed_scale = 1.0


## A soft dark spot on the ground under him, so jumps read clearly even at
## the Low setting, where there are no real shadows.
func _blob_shadow() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.1
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = WinterProps.soft_dot()
	mat.albedo_color = Color(0.03, 0.04, 0.1, 0.45)
	mat.render_priority = -1
	quad.material = mat
	var spot := MeshInstance3D.new()
	spot.name = "BlobShadow"
	spot.mesh = quad
	spot.top_level = true
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return spot


## Called by GraphicsQuality: the blob stands in for his real shadow at Low.
func apply_quality(level: int) -> void:
	_blob_wanted = level == GraphicsQuality.Level.LOW


func _update_shadow(at: Vector3) -> void:
	if not _blob_wanted:
		_shadow.visible = false
		return
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 12.0,
			PhysicsLayers.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_shadow.visible = not hit.is_empty()
	if hit.is_empty():
		return
	var height := at.y - (hit["position"] as Vector3).y
	var size := clampf(1.0 - height * 0.12, 0.4, 1.0)
	_shadow.global_transform = Transform3D(Basis.from_scale(Vector3(size, 1.0, size)),
			(hit["position"] as Vector3) + Vector3.UP * 0.03)
