class_name ParryGuard
extends RefCounted
## Santa's parry: a press raises his guard for a moment, then he needs a
## breath before he can raise it again, so holding up a guard by mashing the
## button does not work. A blow that meets the guard is turned aside (the
## level decides what else happens), and a good parry lets him go again at
## once.

## Seconds the guard stays up after a press.
const ACTIVE := 0.4
## Seconds from one press until the next one counts.
const COOLDOWN := 0.75

## Above 1 is gentler: the guard stays up longer (Cocoa Mode).
var gentleness := 1.0

var _up := 0.0
var _cool := 0.0


func _init(gentle := 1.0) -> void:
	gentleness = gentle


## The parry button: returns false if it is too soon after the last press.
func press() -> bool:
	if _cool > 0.0:
		return false
	_up = ACTIVE * gentleness
	_cool = COOLDOWN
	return true


func update(delta: float) -> void:
	_up = maxf(0.0, _up - delta)
	_cool = maxf(0.0, _cool - delta)


func is_up() -> bool:
	return _up > 0.0


## A blow met the guard: it drops, and he can parry again straight away.
func spend() -> void:
	_up = 0.0
	_cool = 0.0
