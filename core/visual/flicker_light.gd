class_name FlickerLight
extends OmniLight3D
## A warm light that flickers like a fire or candle.

@export var base_energy := 1.6
@export var flicker := 0.35

var _time := randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	var wobble := sin(_time * 9.0) * 0.5 + sin(_time * 23.0 + 1.7) * 0.3 + sin(_time * 4.1) * 0.2
	light_energy = base_energy * (1.0 + wobble * flicker * 0.5)
