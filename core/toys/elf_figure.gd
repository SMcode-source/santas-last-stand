class_name ElfFigure
extends Node3D
## A small stand-in elf (until the elves come from Meshy): a tunic with a
## jagged hem and a belt, striped stockings, pointed ears, and either a long
## hat with a bobble or a pointed red cap. Built facing +z, feet at y = 0,
## about a metre tall. Call stride() each frame to swing the legs.
##
## Also dressed as the Red Caps (Level 4): sallow skin, a dark tunic and the
## blood-red cap they're named for.

const SKIN := Color("f1c7a5")
const TUNIC := Color("2f7a3c")
const RED_CAP := Color("9c1c1f")

## The long elf hat, and the red cap (only one shows at a time).
var hat: Node3D
var cap: Node3D
## Swings with the stride; lean the whole figure with `body.rotation`.
var body: Node3D

var _legs: Array[Node3D] = []
var _phase := 0.0


func _init(tunic := TUNIC, skin := SKIN, red_cap := false, stockings := Color("c8352e")) -> void:
	name = "Elf"
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var b := ToyBuilder.new()
	b.finished(ToyBuilder.lathe(PackedVector2Array([Vector2(0.0, 0.3), Vector2(0.19, 0.3), Vector2(0.15, 0.45),
			Vector2(0.12, 0.6), Vector2(0.08, 0.66), Vector2(0.0, 0.67)]), 12), tunic, "velvet")
	# A jagged hem.
	for k in 8:
		var a := TAU * k / 8.0
		b.finished(ToyBuilder.cylinder(0.0, 0.05, 0.08, 4), tunic, "velvet",
				ToyBuilder.xf(Vector3(cos(a) * 0.16, 0.27, sin(a) * 0.16), Vector3(180, 0, 0)))
	b.finished(ToyBuilder.torus(0.135, 0.018, 14, 5), Color("2b1d14"), "leather", ToyBuilder.xf(Vector3(0, 0.42, 0)))
	b.finished(ToyBuilder.box(Vector3(0.05, 0.04, 0.02)), Color("d8b25a"), "metal", ToyBuilder.xf(Vector3(0, 0.42, 0.15)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.tube(PackedVector3Array([Vector3(side * 0.13, 0.6, 0), Vector3(side * 0.2, 0.47, 0.05),
				Vector3(side * 0.22, 0.38, 0.1)]), PackedFloat32Array([0.035, 0.03, 0.028]), 6), tunic, "velvet")
		b.finished(ToyBuilder.sphere(0.03, 6), skin, "skin", ToyBuilder.xf(Vector3(side * 0.22, 0.36, 0.11)))
		b.finished(ToyBuilder.cylinder(0.0, 0.03, 0.09, 5), skin, "skin",
				ToyBuilder.xf(Vector3(side * 0.1, 0.77, -0.01), Vector3(0, 0, -side * 75)))
	b.finished(ToyBuilder.sphere(0.1, 12), skin, "skin", ToyBuilder.xf(Vector3(0, 0.76, 0.0), Vector3.ZERO, Vector3(1, 1.05, 1)))
	b.finished(ToyBuilder.sphere(0.022, 6), skin.lerp(Color("e5786a"), 0.45), "skin", ToyBuilder.xf(Vector3(0, 0.75, 0.1)))
	for side: float in [-1.0, 1.0]:
		b.finished(ToyBuilder.sphere(0.012, 6), Color("1b1410"), "eye", ToyBuilder.xf(Vector3(side * 0.035, 0.79, 0.09)))
	body.add_child(b.build(0.0, "Figure"))
	# The long hat.
	var hb := ToyBuilder.new()
	hb.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 0.82, 0), Vector3(0, 0.98, -0.04), Vector3(0.0, 1.06, -0.16),
			Vector3(0.0, 1.02, -0.27)]), PackedFloat32Array([0.105, 0.06, 0.03, 0.012]), 10, 5), tunic, "velvet")
	hb.finished(ToyBuilder.torus(0.1, 0.022, 14, 5), Color("f2ede2"), "fur", ToyBuilder.xf(Vector3(0, 0.83, 0)))
	hb.finished(ToyBuilder.sphere(0.035, 8), Color("f2ede2"), "fur", ToyBuilder.xf(Vector3(0, 1.0, -0.28)))
	hat = hb.build(0.0, "Hat")
	body.add_child(hat)
	# The red cap: felt, pointed and a little slumped.
	var cb := ToyBuilder.new()
	cb.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, 0.8, 0), Vector3(0, 0.92, -0.01), Vector3(0.01, 1.01, -0.05),
			Vector3(0.03, 1.06, -0.11)]), PackedFloat32Array([0.112, 0.085, 0.045, 0.01]), 12, 5), RED_CAP, "velvet")
	cb.finished(ToyBuilder.torus(0.108, 0.014, 16, 5), RED_CAP.darkened(0.3), "velvet", ToyBuilder.xf(Vector3(0, 0.81, 0)))
	cap = cb.build(0.0, "RedCap")
	body.add_child(cap)
	wear_red_cap(red_cap)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.07, 0.32, 0)
		body.add_child(leg)
		var lb := ToyBuilder.new()
		for k in 4:
			lb.finished(ToyBuilder.cylinder(0.032, 0.032, 0.07, 6), stockings if k % 2 == 0 else Color("f2ede2"), "velvet",
					ToyBuilder.xf(Vector3(0, -0.035 - k * 0.07, 0)))
		lb.finished(ToyBuilder.curve(PackedVector3Array([Vector3(0, -0.3, -0.02), Vector3(0, -0.31, 0.08), Vector3(0, -0.27, 0.13)]),
				PackedFloat32Array([0.04, 0.035, 0.015]), 6, 4), Color("3b2a1e"), "leather")
		leg.add_child(lb.build(0.0, "Leg"))
		_legs.append(leg)


## The Red Caps' look: a sallow goblin in a dark tunic and iron-grey hose.
static func red_cap() -> ElfFigure:
	return ElfFigure.new(Color("3d3328"), Color("b9b08a"), true, Color("4a4a4f"))


func wear_red_cap(on: bool) -> void:
	cap.visible = on
	hat.visible = not on


## Swings the legs and bobs the body for a pace of `speed` m/s this frame
## (0 stands still).
func stride(delta: float, speed: float) -> void:
	if speed < 0.05:
		_phase = 0.0
		body.position.y = lerpf(body.position.y, 0.0, minf(1.0, delta * 10.0))
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, minf(1.0, delta * 10.0))
		return
	_phase += delta * (6.0 + speed * 2.3)
	var swing := sin(_phase)
	body.position.y = absf(swing) * minf(0.05, speed * 0.012)
	var reach := clampf(speed * 0.18, 0.25, 0.75)
	_legs[0].rotation.x = swing * reach
	_legs[1].rotation.x = -swing * reach
