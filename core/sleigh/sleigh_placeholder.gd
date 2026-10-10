class_name SleighPlaceholder
extends RefCounted
## A stand-in sleigh until the real model arrives: a red box body with a curled
## front, a padded seat, a sack in the back and gold runners. It faces +z and
## sits with its runners on y = 0. Swap it with SleighController.set_visual().

const BODY := Color("a3161f")
const TRIM := Color("e5b638")


static func build() -> Node3D:
	var b := ToyBuilder.new()
	# Body: a tub with a raised back, rounded off at the front.
	b.add(ToyBuilder.box(Vector3(1.5, 0.55, 2.4)), BODY, ToyBuilder.xf(Vector3(0, 0.62, -0.1)))
	b.add(ToyBuilder.box(Vector3(1.5, 0.75, 0.25)), BODY, ToyBuilder.xf(Vector3(0, 1.0, -1.2), Vector3(-12, 0, 0)))
	b.add(ToyBuilder.cylinder(0.28, 0.28, 1.5, 16), BODY, ToyBuilder.xf(Vector3(0, 0.72, 1.12), Vector3(0, 0, 90)))
	# Gold trim round the rim.
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.box(Vector3(0.06, 0.06, 2.5)), TRIM, "metal", ToyBuilder.xf(Vector3(0.76 * side, 0.92, -0.1)))
	b.finished(ToyBuilder.box(Vector3(1.56, 0.06, 0.06)), TRIM, "metal", ToyBuilder.xf(Vector3(0, 1.37, -1.27), Vector3(-12, 0, 0)))
	# Seat cushion and the sack behind it.
	b.finished(ToyBuilder.box(Vector3(1.3, 0.18, 0.7)), Color("2e5b3a"), "velvet", ToyBuilder.xf(Vector3(0, 0.95, -0.55)))
	b.finished(ToyBuilder.lumpy(ToyBuilder.sphere(1.0, 14), 0.08, 3.0, 2), Color("8e1b1f"), "velvet",
			ToyBuilder.xf(Vector3(0.1, 1.2, -1.0), Vector3.ZERO, Vector3(0.45, 0.4, 0.35)))
	# Runners: curled up at the front, joined to the body by struts.
	for side: float in [-1.0, 1.0]:
		var x := 0.62 * side
		b.finished(ToyBuilder.curve(PackedVector3Array([
			Vector3(x, 0.05, -1.4), Vector3(x, 0.03, 0.6), Vector3(x, 0.15, 1.45), Vector3(x, 0.55, 1.65), Vector3(x, 0.7, 1.4),
		]), PackedFloat32Array([0.045, 0.045, 0.045, 0.04, 0.035]), 8, 6), TRIM, "metal")
		for z in [-0.9, 0.0, 0.8]:
			b.finished(ToyBuilder.cylinder(0.025, 0.025, 0.36, 6), TRIM, "metal", ToyBuilder.xf(Vector3(x, 0.22, z)))
	var root := Node3D.new()
	root.name = "SleighPlaceholder"
	root.add_child(b.build(0.0, "Mesh"))
	return root
