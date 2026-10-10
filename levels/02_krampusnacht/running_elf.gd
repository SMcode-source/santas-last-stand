class_name RunningElf
extends Node3D
## A freed elf scampering off to the church (an ElfFigure stand-in until the
## elves come from Meshy). Runs along a path of points, then slips in
## through the door.

const SPEED := 4.2

var _figure: ElfFigure


func _ready() -> void:
	name = "RunningElf"
	_figure = ElfFigure.new()
	_figure.body.rotation.x = 0.18
	add_child(_figure)


## Runs through `way` and disappears at the end.
func run(way: PackedVector3Array) -> void:
	var t := create_tween()
	# A startled hop out of the sack first.
	t.tween_property(self, "position:y", position.y + 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var from := Vector3(position.x, 0.0, position.z)
	for point in way:
		var seconds := from.distance_to(point) / SPEED
		var heading := atan2(point.x - from.x, point.z - from.z)
		t.tween_callback(func() -> void: rotation.y = heading)
		t.tween_property(self, "position", point, seconds)
		from = point
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	_figure.stride(delta, SPEED)
