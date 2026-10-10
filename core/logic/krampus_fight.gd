class_name KrampusFight
extends RefCounted
## The rules of the Krampus fight, apart from how it looks.
##
## Krampus feeds on fear. While the village is dark and silent nothing hurts
## him: blows just feed him. When enough freed elves are at the bell ropes,
## Santa can ring the church bells; the lights come on and Krampus is mortal.
## Even then fists do nothing but make him laugh, and three in quick
## succession earn a shove. The only way through is his chain whip: he winds
## it up, and a parry just as it lashes out catches the chain. While Santa
## holds it, an attack slams Krampus into the cobbles. Three slams win.
##
## After the first slam he howls and the lights go out again, so the bells
## must be rung a second time. After the second he is enraged: every wind-up
## brings two lashes, the second one quick.

signal winding_up(seconds: float)
## The chain lashed out: `hit` if it caught Santa unguarded.
signal whipped(hit: bool)
## Santa's guard met the chain. `caught` if he kept hold of it (only once
## the lights are on; in the dark it just glances off).
signal parried(caught: bool)
signal yanked_free
## A punch did nothing. `dark`: and he soaked it up to heal.
signal shrugged(dark: bool)
signal countered
signal slammed(health: int)
signal lights_out
signal lit_up
signal defeated

enum State {STALK, WINDUP, RECOVER, CAUGHT, DOWN, COUNTER}

const SLAMS := 3
## Elves needed at the bell ropes to ring the bells.
const RING_NEEDED := 4
## He starts winding up once Santa is this close...
const WHIP_RANGE := 4.5
## ...and the lash lands on him anywhere within this.
const WHIP_REACH := 5.4
## Seconds of wind-up before the lash, by slams taken (0, 1, 2).
const WINDUP := [1.1, 0.9, 0.8]
## Lashes per wind-up, by slams taken.
const VOLLEY := [1, 1, 2]
## Wind-up of the follow-up lash in a volley.
const FOLLOW_UP := 0.55
const RECOVER := 1.1
## Seconds Santa has to slam him once the chain is caught.
const CATCH_TIME := 1.6
const DOWN_TIME := 2.2
const COUNTER_TIME := 0.9
## Punches within this many seconds...
const MASH_WINDOW := 1.6
## ...up to this many, and he catches the fist and shoves.
const MASH_LIMIT := 3

var health := SLAMS
var lit := false
var state := State.STALK
## Seconds left in the current state (wind-up, recovery, hold...).
var timer := 0.0
## Above 1 is gentler: slower wind-ups, a longer hold (Cocoa Mode).
var gentleness := 1.0
var guard: ParryGuard

var _volley_left := 0
var _clock := 0.0
var _punches: Array[float] = []
var _dim_when_up := false


func _init(santa_guard: ParryGuard, gentle := 1.0) -> void:
	guard = santa_guard
	gentleness = gentle


## How many slams he has taken (0, 1 or 2 while fighting).
func phase() -> int:
	return SLAMS - health


func is_over() -> bool:
	return health <= 0


## The church bells: needs `ringers` elves at the ropes and the lights out.
func ring(ringers: int) -> bool:
	if lit or ringers < RING_NEEDED or is_over():
		return false
	lit = true
	lit_up.emit()
	return true


func update(delta: float, distance: float) -> void:
	if is_over():
		return
	_clock += delta
	match state:
		State.STALK:
			if distance <= WHIP_RANGE:
				_volley_left = VOLLEY[phase()]
				_wind_up(WINDUP[phase()])
		State.WINDUP:
			timer -= delta
			if timer <= 0.0:
				_lash(distance)
		State.CAUGHT:
			timer -= delta
			if timer <= 0.0:
				yanked_free.emit()
				_recover()
		State.RECOVER, State.COUNTER:
			timer -= delta
			if timer <= 0.0:
				state = State.STALK
		State.DOWN:
			timer -= delta
			if timer <= 0.0:
				state = State.STALK
				if _dim_when_up:
					_dim_when_up = false
					lit = false
					lights_out.emit()


## Santa's fist landed on him. Returns what came of it: "shrugged",
## "regenerated" (in the dark), "countered" (mashing) or "down" (he is
## already on the ground).
func punch() -> String:
	if is_over() or state == State.DOWN:
		return "down"
	_punches.append(_clock)
	while not _punches.is_empty() and _clock - _punches[0] > MASH_WINDOW:
		_punches.pop_front()
	if _punches.size() >= MASH_LIMIT and state != State.CAUGHT:
		_punches.clear()
		state = State.COUNTER
		timer = COUNTER_TIME
		countered.emit()
		return "countered"
	shrugged.emit(not lit)
	return "shrugged" if lit else "regenerated"


## Santa heaves on the caught chain. Returns whether it slammed him.
func slam() -> bool:
	if state != State.CAUGHT:
		return false
	health -= 1
	_punches.clear()
	slammed.emit(health)
	state = State.DOWN
	timer = DOWN_TIME
	if is_over():
		defeated.emit()
	else:
		_dim_when_up = health == SLAMS - 1
	return true


## Seconds until the lash, while winding up (else 0).
func windup_left() -> float:
	return timer if state == State.WINDUP else 0.0


func _wind_up(seconds: float) -> void:
	state = State.WINDUP
	timer = seconds * gentleness
	winding_up.emit(timer)


func _lash(distance: float) -> void:
	var reaches := distance <= WHIP_REACH
	if reaches and guard and guard.is_up():
		guard.spend()
		parried.emit(lit)
		if lit:
			state = State.CAUGHT
			timer = CATCH_TIME * gentleness
			return
		_recover()
		return
	whipped.emit(reaches)
	_volley_left -= 1
	if _volley_left > 0:
		_wind_up(FOLLOW_UP)
	else:
		_recover()


func _recover() -> void:
	state = State.RECOVER
	timer = RECOVER * gentleness
