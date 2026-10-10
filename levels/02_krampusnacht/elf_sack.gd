class_name ElfSack
extends Node3D
## A burlap sack with an elf tied up inside: it hangs from the bell tower on a
## rope, is cut down and carried off by one of Krampus's helpers, and is
## dropped when the helper is knocked down. Santa opens it, the elf tumbles
## out and runs for the church, where the bell ropes are. The sack wriggles
## the whole time, and the tip of a green hat pokes out of the neck.
## (The elf is a small stand-in until the elves come from Meshy.)

enum State {HANGING, FALLING, GROUND, CARRIED, OPEN, GONE}

const HEIGHT := 0.95
## A touch larger than life, so the sacks read from the square below.
const SIZE := 1.2

var index := 0
var state := State.HANGING

var _body: Node3D
var _rope: MeshInstance3D
var _head: MeshInstance3D
var _wriggle := randf() * 10.0
var _fright := 1.0


func _init(sack_index := 0) -> void:
	index = sack_index
	name = "ElfSack%d" % sack_index


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	var b := ToyBuilder.new()
	var burlap := Color("c4aa80").darkened(0.05 * (index % 3))
	var sack := ToyBuilder.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.24, 0.03), Vector2(0.33, 0.16), Vector2(0.35, 0.36), Vector2(0.31, 0.56),
		Vector2(0.2, 0.72), Vector2(0.1, 0.8), Vector2(0.11, 0.84), Vector2(0.17, 0.92), Vector2(0.18, 0.95),
	]), 20)
	b.finished(ToyBuilder.lumpy(sack, 0.03, 6.0, index + 3), burlap, "leather")
	# Coarse stitching up one side and a patch.
	for k in 7:
		b.finished(ToyBuilder.box(Vector3(0.05, 0.012, 0.012)), burlap.darkened(0.45), "leather",
				ToyBuilder.xf(Vector3(0.335, 0.12 + k * 0.07, 0.0), Vector3(0, 0, 70)))
	b.finished(ToyBuilder.box(Vector3(0.16, 0.14, 0.02)), burlap.lightened(0.15), "leather",
			ToyBuilder.xf(Vector3(-0.12, 0.38, 0.32), Vector3(0, -20, 6)))
	# The rope tied round the neck.
	b.finished(ToyBuilder.torus(0.11, 0.022, 16, 6), Color("b9a16e"), "leather", ToyBuilder.xf(Vector3(0, 0.82, 0)))
	b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0.1, 0.82, 0.04), Vector3(0.16, 0.72, 0.1), Vector3(0.15, 0.6, 0.12)]),
			PackedFloat32Array([0.016, 0.015, 0.012]), 5, 4), Color("b9a16e"), "leather")
	_body.add_child(b.build(0.0, "Sack"))
	# The elf's head poking out of the neck: worried eyes, pointed ears and
	# a green hat with a bobble.
	b = ToyBuilder.new()
	var skin := Color("f1c7a5")
	b.finished(ToyBuilder.sphere(0.1, 14), skin, "skin", ToyBuilder.xf(Vector3(0, 1.0, 0.02), Vector3.ZERO, Vector3(1, 1.05, 1)))
	b.finished(ToyBuilder.sphere(0.024, 8), Color("e59a83"), "skin", ToyBuilder.xf(Vector3(0, 0.99, 0.12)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.sphere(0.016, 8), Color("1b1410"), "eye", ToyBuilder.xf(Vector3(side * 0.038, 1.03, 0.105)))
		b.finished(ToyBuilder.box(Vector3(0.035, 0.008, 0.008)), Color("6b4a32"), "hair",
				ToyBuilder.xf(Vector3(side * 0.04, 1.06, 0.1), Vector3(0, 0, side * 20)))
		b.finished(ToyBuilder.cylinder(0.0, 0.032, 0.1, 5), skin, "skin",
				ToyBuilder.xf(Vector3(side * 0.11, 1.02, 0.0), Vector3(0, 0, -side * 70)))
	b.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 1.06, 0.0), Vector3(0.02, 1.2, -0.02), Vector3(0.1, 1.3, -0.06),
			Vector3(0.17, 1.27, -0.08)]), PackedFloat32Array([0.105, 0.06, 0.025, 0.01]), 10, 5), Color("2f7a3c"), "velvet")
	b.finished(ToyBuilder.torus(0.1, 0.022, 14, 5), Color("f2ede2"), "fur", ToyBuilder.xf(Vector3(0, 1.07, 0.0)))
	b.finished(ToyBuilder.sphere(0.035, 10), Color("f2ede2"), "fur", ToyBuilder.xf(Vector3(0.18, 1.26, -0.08)))
	_head = b.build(0.0, "Head")
	_body.add_child(_head)


## Hangs the sack on a rope from `anchor_y` (in world height) above it.
func hang(anchor_y: float) -> void:
	state = State.HANGING
	if _rope:
		_rope.queue_free()
	# Tied round the neck, and up past the back of the elf's head.
	var knot := Vector3(0.1, 0.84, -0.06) * SIZE
	var top := Vector3(0.05, anchor_y - global_position.y, -0.08)
	var b := ToyBuilder.new()
	b.finished(ToyBuilder.tube(PackedVector3Array([knot, knot + Vector3(0.04, 0.3, -0.1), top]),
			PackedFloat32Array([0.018, 0.018, 0.018]), 5), Color("b9a16e"), "leather")
	_rope = b.build(0.0, "Rope")
	add_child(_rope)


## The rope is cut: it drops to the ground at its feet (y = 0).
func cut_down() -> void:
	if state != State.HANGING:
		return
	state = State.FALLING
	if _rope:
		_rope.queue_free()
		_rope = null
	var from := global_position
	var to := Vector3(from.x, 0.0, from.z)
	var t := create_tween()
	var fall := sqrt(2.0 * maxf(from.y, 0.1) / 9.8)
	t.tween_property(self, "global_position", to, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_body, "scale", Vector3(1.25, 0.7, 1.25) * SIZE, 0.08)
	t.tween_property(_body, "scale", Vector3.ONE * SIZE, 0.25).set_trans(Tween.TRANS_BACK)
	t.tween_callback(func() -> void:
		if state == State.FALLING:
			state = State.GROUND)


## A helper slings it over his shoulder: it rides on `carrier` from now on.
func carry_on(carrier: Node3D) -> void:
	state = State.CARRIED
	reparent(carrier, false)
	position = Vector3.ZERO
	rotation = Vector3(0.0, 0.0, deg_to_rad(-20.0))


## Dropped where it is, onto the ground under `parent`.
func drop_into(parent: Node, at: Vector3) -> void:
	state = State.FALLING
	reparent(parent, true)
	rotation = Vector3.ZERO
	var t := create_tween()
	t.tween_property(self, "global_position", Vector3(at.x, 0.0, at.z), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_body, "scale", Vector3(1.2, 0.75, 1.2) * SIZE, 0.08)
	t.tween_property(_body, "scale", Vector3.ONE * SIZE, 0.25).set_trans(Tween.TRANS_BACK)
	t.tween_callback(func() -> void: state = State.GROUND)


func can_open() -> bool:
	return state == State.GROUND


## Santa unties it: the elf tumbles out and runs along `way` (to the church
## door), and the empty sack slumps and fades.
func open(way: PackedVector3Array) -> void:
	state = State.OPEN
	_head.visible = false
	var slump := create_tween()
	slump.tween_property(_body, "scale", Vector3(1.35, 0.25, 1.35) * SIZE, 0.35).set_trans(Tween.TRANS_BACK)
	slump.tween_interval(3.0)
	slump.tween_property(_body, "scale", Vector3(1.4, 0.01, 1.4) * SIZE, 1.0)
	slump.tween_callback(func() -> void:
		state = State.GONE
		visible = false)
	var elf := RunningElf.new()
	get_parent().add_child(elf)
	elf.global_position = global_position + Vector3(0, 0.1, 0)
	elf.run(way)


## Gone for good (carried over the bridge).
func vanish() -> void:
	state = State.GONE
	visible = false


func _process(delta: float) -> void:
	if state == State.GONE or state == State.OPEN:
		return
	_wriggle += delta
	# Struggling: fits of wriggling between quieter spells.
	var fit := 0.4 + 0.6 * maxf(0.0, sin(_wriggle * 0.9 + index))
	_body.rotation.z = sin(_wriggle * 9.0) * 0.08 * fit * _fright
	_body.rotation.x = sin(_wriggle * 7.0 + 1.3) * 0.06 * fit * _fright
	if state == State.HANGING:
		rotation.y = sin(_wriggle * 0.7 + index) * 0.4
