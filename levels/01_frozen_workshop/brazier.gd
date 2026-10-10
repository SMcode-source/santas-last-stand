class_name Brazier
extends Node3D
## An iron fire basket on three legs, burning: somewhere to warm up.

var warmth: WarmSpot


func _init(reach := 3.0) -> void:
	name = "Brazier"
	var b := ToyBuilder.new()
	var iron := Color("26272b")
	for k in 3:
		var a := TAU * k / 3.0
		var foot := Vector3(cos(a) * 0.42, 0, sin(a) * 0.42)
		var top := Vector3(cos(a) * 0.3, 0.85, sin(a) * 0.3)
		b.finished(ToyBuilder.tube(PackedVector3Array([foot, top]), PackedFloat32Array([0.035, 0.03]), 6), iron, "metal")
	var bowl := ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.72), Vector2(0.18, 0.74), Vector2(0.36, 0.86),
			Vector2(0.44, 1.02), Vector2(0.46, 1.06), Vector2(0.42, 1.04), Vector2(0.34, 0.9), Vector2(0.0, 0.84)]), 18)
	b.finished(bowl, iron, "metal")
	# Glowing coals heaped in the bowl.
	b.part(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 10), 0.25, 5.0, 7), Color("ff6a1a"), Vector3(0, 0.95, 0),
			Vector3.ZERO, Vector3(0.34, 0.1, 0.34), true)
	add_child(b.build(0.0, "Basket"))
	var flames := WinterProps.fire(0.9)
	flames.position.y = 0.92
	add_child(flames)
	warmth = WarmSpot.new(reach, 1.0)
	warmth.position.y = 1.0
	add_child(warmth)
	var shape := CollisionShape3D.new()
	var solid := StaticBody3D.new()
	solid.collision_layer = PhysicsLayers.WORLD
	solid.collision_mask = 0
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.45
	cylinder.height = 1.1
	shape.shape = cylinder
	shape.position.y = 0.55
	solid.add_child(shape)
	add_child(solid)
