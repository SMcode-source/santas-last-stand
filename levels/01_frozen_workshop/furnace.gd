class_name Furnace
extends Node3D
## A pot-bellied iron workshop furnace on a stone plinth, frozen over. Santa
## lights it from his lantern: the ice cracks away, the door swings open on a
## roaring fire, and heat goes up the flue into the pipe to the Clock Tower.
## It faces +z; its flue leaves the back at (0, 1.9, -1.1).

signal lit_up(id: String)

const FLUE_END := Vector3(0, 1.9, -1.1)
## Santa lights it from about here (in front of the door).
const STAND := Vector3(0, 0, 1.5)

var id := ""
var lit := false
var warmth: WarmSpot

var _door: Node3D
var _fire: Node3D
var _glow: MeshInstance3D
var _ice: MeshInstance3D


func _init(furnace_id := "") -> void:
	id = furnace_id
	name = "Furnace_" + furnace_id


func _ready() -> void:
	var b := ToyBuilder.new()
	var iron := Color("2a2b2f")
	b.textured(ToyBuilder.box(Vector3(2.0, 0.4, 1.7)), "old_stone_wall", ToyBuilder.xf(Vector3(0, 0.2, 0)), 1.0, Color("c8c1b6"))
	b.finished(ToyBuilder.box(Vector3(1.4, 0.95, 1.0)), iron, "metal", ToyBuilder.xf(Vector3(0, 0.9, 0)))
	b.finished(ToyBuilder.cylinder(0.5, 0.5, 1.4, 20), iron, "metal", ToyBuilder.xf(Vector3(0, 1.38, 0), Vector3(0, 0, 90)))
	# Feet, bands and rivets.
	for x: float in [-0.6, 0.6]:
		for z: float in [-0.4, 0.4]:
			b.finished(ToyBuilder.cylinder(0.07, 0.09, 0.2, 8), iron, "metal", ToyBuilder.xf(Vector3(x, 0.48, z)))
	for y: float in [0.62, 1.15]:
		b.finished(ToyBuilder.box(Vector3(1.46, 0.06, 1.06)), Color("6b5a3c"), "metal", ToyBuilder.xf(Vector3(0, y, 0)))
	# The flue: up out of the top, then back into the pipe.
	b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(0, 1.75, -0.35), Vector3(0, 1.9, -0.4), FLUE_END]),
			PackedFloat32Array([0.2, 0.2, 0.2]), 12), iron, "metal")
	# The door frame and the grate below it.
	b.finished(ToyBuilder.box(Vector3(0.78, 0.62, 0.06)), Color("6b5a3c"), "metal", ToyBuilder.xf(Vector3(0, 0.95, 0.5)))
	for k in 4:
		b.finished(ToyBuilder.box(Vector3(0.06, 0.18, 0.04)), iron, "metal", ToyBuilder.xf(Vector3(-0.2 + k * 0.13, 0.56, 0.51)))
	add_child(b.build(0.0, "Stove"))

	# The firebox glow, seen through the open door once lit.
	var glow_b := ToyBuilder.new()
	glow_b.add(ToyBuilder.box(Vector3(0.6, 0.45, 0.02)), Color(1.0, 0.45, 0.1), ToyBuilder.xf(Vector3(0, 0.95, 0.52)), true)
	_glow = glow_b.build(0.0, "Glow")
	_glow.visible = false
	add_child(_glow)
	var door_b := ToyBuilder.new()
	door_b.finished(ToyBuilder.box(Vector3(0.66, 0.5, 0.05)), iron, "metal", ToyBuilder.xf(Vector3(0.33, 0, 0)))
	door_b.finished(ToyBuilder.cylinder(0.04, 0.04, 0.12, 8), Color("8a7a55"), "metal", ToyBuilder.xf(Vector3(0.58, 0, 0.06), Vector3(90, 0, 0)))
	_door = door_b.build(0.0, "Door")
	_door.position = Vector3(-0.33, 0.95, 0.55)
	add_child(_door)

	_fire = WinterProps.fire(0.8)
	_fire.position = Vector3(0, 0.75, 0.3)
	_fire.visible = false
	add_child(_fire)
	for light in _fire.find_children("*", "OmniLight3D", true, false):
		var omni := light as OmniLight3D
		omni.position = Vector3(0, 0.6, 1.0)
		omni.omni_range = 7.0

	# Frost and ice over the whole stove.
	var chunks := [[WorkshopSet.ice_chunk(Vector3(1.6, 1.55, 1.2), hash(id) % 50, 0.07), ToyBuilder.xf(Vector3(0, 1.17, 0))]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for k in 9:
		var drip := rng.randf_range(0.15, 0.4)
		chunks.append([ToyBuilder.cylinder(0.0, 0.05, drip, 6), ToyBuilder.xf(Vector3(rng.randf_range(-0.7, 0.7), 1.95 - drip / 2.0, 0.62))])
	_ice = WorkshopSet.ice_mesh(chunks)
	add_child(_ice)

	warmth = WarmSpot.new(5.0, 1.0, false)
	warmth.position = Vector3(0, 1.0, 0.8)
	add_child(warmth)

	var solid := StaticBody3D.new()
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.9, 1.2)
	shape.shape = box
	shape.position.y = 0.95
	solid.add_child(shape)
	add_child(solid)


## Where Santa stands to light it.
func stand_point() -> Vector3:
	return global_transform * STAND


func light(instant := false) -> void:
	if lit:
		return
	lit = true
	warmth.enabled = true
	_fire.visible = true
	_glow.visible = true
	if instant:
		_ice.visible = false
		_door.rotation_degrees.y = -100.0
	else:
		var t := create_tween().set_parallel()
		t.tween_property(_ice, "scale", Vector3(1.05, 0.02, 1.05), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_door, "rotation_degrees:y", -100.0, 0.6).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func() -> void: _ice.visible = false)
		Audio.play_sfx("click", 0.6)
	lit_up.emit(id)
