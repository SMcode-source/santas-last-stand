class_name SantaToy
extends Node3D
## Toy-figure Santa built from primitives, with a procedural idle bob.

const RED := Color("c8102e")
const WHITE := Color("f4f1ea")
const SKIN := Color("f2c4a0")
const BLACK := Color("1d1d1f")
const GOLD := Color("e8b923")

var _body: Node3D
var _time := 0.0
var _hop := 0.0


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)

	# Boots and body
	ToyPart.add(_body, ToyPart.box(Vector3(0.24, 0.2, 0.34)), BLACK, Vector3(-0.17, 0.1, 0.04))
	ToyPart.add(_body, ToyPart.box(Vector3(0.24, 0.2, 0.34)), BLACK, Vector3(0.17, 0.1, 0.04))
	ToyPart.add(_body, ToyPart.capsule(0.46, 1.3), RED, Vector3(0, 0.82, 0))
	ToyPart.add(_body, ToyPart.cylinder(0.12, 0.12, 0.62), WHITE, Vector3(0, 0.82, 0.42), Vector3(90, 0, 0), Vector3(1, 1, 0.12))
	ToyPart.add(_body, ToyPart.cylinder(0.475, 0.475, 0.14), BLACK, Vector3(0, 0.72, 0))
	ToyPart.add(_body, ToyPart.box(Vector3(0.2, 0.17, 0.06)), GOLD, Vector3(0, 0.72, 0.47))

	# Arms and mittens
	for side in [-1, 1]:
		ToyPart.add(_body, ToyPart.capsule(0.13, 0.62), RED, Vector3(0.52 * side, 0.98, 0), Vector3(0, 0, -22 * side))
		ToyPart.add(_body, ToyPart.sphere(0.12), BLACK, Vector3(0.64 * side, 0.68, 0.02))

	# Head, beard, face
	ToyPart.add(_body, ToyPart.sphere(0.3), SKIN, Vector3(0, 1.62, 0))
	ToyPart.add(_body, ToyPart.sphere(0.3), WHITE, Vector3(0, 1.46, 0.12), Vector3.ZERO, Vector3(1.0, 0.9, 0.8))
	ToyPart.add(_body, ToyPart.sphere(0.07), Color("e98a7a"), Vector3(0, 1.6, 0.3))
	for side in [-1, 1]:
		ToyPart.add(_body, ToyPart.sphere(0.04), BLACK, Vector3(0.11 * side, 1.7, 0.26))

	# Hat
	ToyPart.add(_body, ToyPart.cylinder(0.33, 0.33, 0.1), WHITE, Vector3(0, 1.82, 0))
	ToyPart.add(_body, ToyPart.cylinder(0.0, 0.29, 0.55, 10), RED, Vector3(0.06, 2.1, -0.02), Vector3(0, 0, -14))
	ToyPart.add(_body, ToyPart.sphere(0.09), WHITE, Vector3(0.14, 2.38, -0.04))


func _process(delta: float) -> void:
	_time += delta
	_hop = max(0.0, _hop - delta * 2.5)
	var hop_height := sin(_hop * PI) * 0.8 if _hop > 0.0 else 0.0
	var bob := sin(_time * 3.0) * 0.03
	_body.position.y = bob + hop_height
	# Squash and stretch: stretch while hopping, gentle breathing otherwise.
	var stretch := 1.0 + sin(_time * 3.0) * 0.02 + hop_height * 0.15
	_body.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))


## Makes Santa do a little hop.
func hop() -> void:
	if _hop <= 0.0:
		_hop = 1.0
