class_name WarmSpot
extends Node3D
## A source of warmth (a fire, a brazier, a lit furnace, a cloud of steam).
## Standing within `radius` warms Santa up, most strongly close in.

const GROUP := "warm_spots"

@export var radius := 3.0
@export var strength := 1.0
@export var enabled := true


func _init(reach := 3.0, power := 1.0, on := true) -> void:
	radius = reach
	strength = power
	enabled = on


func _enter_tree() -> void:
	add_to_group(GROUP)


## How warm it is at `at`: 0 out of reach of every fire, up to 1 beside one.
static func heat_at(tree: SceneTree, at: Vector3) -> float:
	var best := 0.0
	for node in tree.get_nodes_in_group(GROUP):
		var spot := node as WarmSpot
		if spot == null or not spot.enabled or not spot.is_inside_tree():
			continue
		var d := spot.global_position.distance_to(at)
		if d < spot.radius:
			best = maxf(best, spot.strength * (1.0 - smoothstep(spot.radius * 0.45, spot.radius, d)))
	return best
