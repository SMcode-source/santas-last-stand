class_name FrostFight
extends RefCounted
## The rules of the Jack Frost fight, apart from how it looks.
##
## Frost hops between three clock gears in his ice armour, which nothing can
## hurt. Round the gears stand three hot pipes, one above each gear, fed by
## the furnaces lit in the workshop. Santa cranks the clock's hand round from
## pipe to pipe; when it reaches a pipe that is still hot, the pipe vents
## steam onto its gear. If Frost is on that gear, his armour melts and for a
## few seconds one good blow knocks him back: that pipe is spent and the next
## phase begins, with Frost hopping faster. Three pipes, three phases.

signal hopped(gear: int)
signal vented(pipe: int, hit_frost: bool)
signal armour_lost(seconds: float)
signal armour_back
signal phase_won(phase: int)
signal defeated

const GEARS := 3
## Seconds between hops, for phases 1, 2 and 3.
const HOP_EVERY := [4.2, 3.2, 2.4]
## Seconds his armour stays off after a direct hit of steam, per phase.
const EXPOSED_FOR := [5.0, 4.2, 3.6]
## Seconds the hand takes to swing from one pipe to the next.
const SWING_TIME := 1.1
## Seconds the steam keeps venting once the hand reaches a pipe.
const VENT_TIME := 1.2

## 0, 1 or 2 while fighting; 3 once he is beaten.
var phase := 0
## The gear Frost stands on.
var frost_gear := 0
## The pipe the clock's hand points at (it moves 0 -> 1 -> 2 -> 0).
var hand := 0
var spent: Array[bool] = [false, false, false]
## True while the hand is swinging to the next pipe.
var swinging := false
var exposed := 0.0
var venting := 0.0
## Seconds until Frost's next hop; he also warns which gear he is aiming at.
var next_hop := 0.0
var next_gear := 1
## Scales the timings: above 1 is gentler (Cocoa Mode gives him slower hops
## and a longer window).
var gentleness := 1.0

var _swing := 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed := 1, gentle := 1.0) -> void:
	_rng.seed = seed
	gentleness = gentle
	next_hop = _hop_time()
	next_gear = _pick_gear()


func is_over() -> bool:
	return phase >= GEARS


func is_exposed() -> bool:
	return exposed > 0.0


## Santa turns the crank: the hand starts its swing to the next pipe.
## Returns false if it is already moving or the fight is over.
func crank() -> bool:
	if swinging or is_over():
		return false
	swinging = true
	_swing = 0.0
	venting = 0.0
	return true


## How far round the hand is, in pipes (0 to 3, fractional mid-swing).
func hand_position() -> float:
	return fmod(hand + (_swing / SWING_TIME if swinging else 0.0), GEARS)


## A blow lands on Frost. Only counts while his armour is off; returns
## whether it hurt him.
func strike() -> bool:
	if not is_exposed() or is_over():
		return false
	exposed = 0.0
	spent[hand] = true
	phase += 1
	phase_won.emit(phase)
	if is_over():
		defeated.emit()
	else:
		next_hop = _hop_time()
		next_gear = _pick_gear()
	return true


func update(delta: float) -> void:
	if is_over():
		return
	if swinging:
		_swing += delta
		if _swing >= SWING_TIME:
			swinging = false
			hand = (hand + 1) % GEARS
			if not spent[hand]:
				venting = VENT_TIME
				_check_vent()
	elif venting > 0.0:
		venting -= delta
	if exposed > 0.0:
		exposed -= delta
		if exposed <= 0.0:
			armour_back.emit()
		return
	next_hop -= delta
	if next_hop <= 0.0:
		frost_gear = next_gear
		hopped.emit(frost_gear)
		next_hop = _hop_time()
		next_gear = _pick_gear()
		if venting > 0.0:
			_check_vent()


## Steam is pouring from the pipe the hand points at.
func _check_vent() -> void:
	var hit := frost_gear == hand and not is_exposed()
	vented.emit(hand, hit)
	if hit:
		venting = 0.0
		exposed = EXPOSED_FOR[phase] * gentleness
		armour_lost.emit(exposed)


func _hop_time() -> float:
	return HOP_EVERY[mini(phase, GEARS - 1)] * gentleness


## Any gear but the one he is on.
func _pick_gear() -> int:
	return (frost_gear + 1 + _rng.randi_range(0, GEARS - 2)) % GEARS
