class_name StealthMeter
extends RefCounted
## Level 4's detection meter: the eye that fills while anyone can see Santa.
## Each watcher that sees him this frame adds a strength (closer is
## clearer, sneaking halves it, the Yule Cat counts double). Full means the
## alarm is raised and the Cat comes. Out of sight for a moment, it drains.

const SEE_RATE := 0.8
const DRAIN := 0.32
const DRAIN_DELAY := 1.0
## A clear look at the edge of sight, and right up close.
const FAR_STRENGTH := 0.35
const NEAR_STRENGTH := 1.6
const SNEAK_FACTOR := 0.55

## 0 (unseen) to 1 (found).
var level := 0.0
## Above 1 fills more slowly (Cocoa Mode).
var gentleness := 1.0
## Who added the most last time it rose (for the fail message).
var last_source := ""

var _quiet := 0.0


## How clearly a watcher sees Santa at `distance` (0 when out of range).
static func strength(distance: float, sight_range: float, sneaking: bool) -> float:
	if distance >= sight_range:
		return 0.0
	var clear := lerpf(FAR_STRENGTH, NEAR_STRENGTH, 1.0 - distance / sight_range)
	return clear * (SNEAK_FACTOR if sneaking else 1.0)


## Adds this frame's sightings ({who: strength}). True once it's full.
func update(delta: float, sightings: Dictionary) -> bool:
	var total := 0.0
	var most := 0.0
	for who: String in sightings:
		var s: float = sightings[who]
		total += s
		if s > most:
			most = s
			last_source = who
	if total > 0.0:
		_quiet = 0.0
		level = minf(1.0, level + total * SEE_RATE * delta / gentleness)
	else:
		_quiet += delta
		if _quiet > DRAIN_DELAY:
			level = maxf(0.0, level - DRAIN * delta)
	return is_full()


## A shout or a bang: adds `amount` at once.
func jolt(amount: float, who: String) -> bool:
	level = minf(1.0, level + amount / gentleness)
	_quiet = 0.0
	last_source = who
	return is_full()


func is_full() -> bool:
	return level >= 1.0


func reset() -> void:
	level = 0.0
	_quiet = 0.0
