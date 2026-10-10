class_name CatChase
extends RefCounted
## Level 4's finale: Santa runs for the sleigh with six freed elves trotting
## behind him in single file, and the Yule Cat behind them. Everyone follows
## the trail Santa leaves (so nobody walks through a wall). Santa outruns the
## Cat; the elves can't. The Cat snatches any elf it reaches, unless the elf
## wears a red cap, then it walks straight past. Lose more than two and it's
## over; let the Cat reach Santa and it's over too. A snowball in its face
## stops it for a moment.

const ELVES := 6
const LOST_LIMIT := 2
const ELF_SPEED := 4.4
const CAT_SPEED := 5.25
## Where each elf trots behind Santa (metres along the trail).
const FIRST_GAP := 0.8
const SPACING := 0.9
## How far behind the last elf the Cat lands.
const CAT_GAP := 2.5
## The Cat stops this long to carry an elf off.
const SNATCH_PAUSE := 0.5
const SNATCH_REACH := 0.4
const CATCH_SANTA := 1.0
const STUN := 0.7
const STUN_COOLDOWN := 3.0
const MIN_STEP := 0.25

var trail := PackedVector3Array()
## Distance along the trail to each point.
var lengths := PackedFloat32Array()
var santa_s := 0.0
var elf_s := PackedFloat32Array()
var lost: Array[bool] = []
var capped: Array[bool] = []
var cat_on := false
var cat_s := 0.0
var cat_speed := CAT_SPEED
var santa_caught := false

var _pause := 0.0
var _stun_ready := 0.0


## `caps` elves (the front of the line) wear red caps.
func _init(caps: int, start: Vector3) -> void:
	trail.append(start)
	lengths.append(0.0)
	for i in ELVES:
		elf_s.append(0.0)
		lost.append(false)
		capped.append(i < caps)


## Santa's position this frame: extends the trail once he's moved far enough.
func record(santa_pos: Vector3) -> void:
	var last := trail[trail.size() - 1]
	var step := last.distance_to(santa_pos)
	if step < MIN_STEP:
		return
	trail.append(santa_pos)
	lengths.append(lengths[lengths.size() - 1] + step)
	santa_s = lengths[lengths.size() - 1]


## The Cat lands on the trail behind the last elf.
func release_cat() -> void:
	if cat_on:
		return
	cat_on = true
	cat_s = maxf(0.0, last_elf_s() - CAT_GAP)


## Moves the elves and the Cat on. Returns what happened:
## {"kind": "snatched", "elf": i} or {"kind": "caught"}.
func update(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ELVES:
		if lost[i]:
			continue
		var target := santa_s - (FIRST_GAP + i * SPACING)
		if target > elf_s[i]:
			elf_s[i] = minf(target, elf_s[i] + ELF_SPEED * delta)
	_stun_ready = maxf(0.0, _stun_ready - delta)
	if not cat_on or santa_caught:
		return events
	if _pause > 0.0:
		_pause -= delta
		return events
	cat_s = minf(santa_s, cat_s + cat_speed * delta)
	for i in ELVES:
		if not lost[i] and not capped[i] and cat_s >= elf_s[i] - SNATCH_REACH:
			lost[i] = true
			_pause = SNATCH_PAUSE
			events.append({"kind": "snatched", "elf": i})
			return events
	if santa_s - cat_s <= CATCH_SANTA:
		santa_caught = true
		events.append({"kind": "caught"})
	return events


## A snowball in the Cat's face. False if it's still blinking from the last.
func stun() -> bool:
	if not cat_on or _stun_ready > 0.0:
		return false
	_pause = maxf(_pause, STUN)
	_stun_ready = STUN_COOLDOWN
	return true


func last_elf_s() -> float:
	var least := santa_s
	for i in ELVES:
		if not lost[i]:
			least = minf(least, elf_s[i])
	return least


func lost_count() -> int:
	return lost.count(true)


func failed() -> bool:
	return santa_caught or lost_count() > LOST_LIMIT


## The point `s` metres along the trail.
func position_at(s: float) -> Vector3:
	if s <= 0.0 or trail.size() == 1:
		return trail[0]
	var lo := 0
	var hi := lengths.size() - 1
	if s >= lengths[hi]:
		return trail[hi]
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if lengths[mid] <= s:
			lo = mid
		else:
			hi = mid
	var span := lengths[hi] - lengths[lo]
	return trail[lo].lerp(trail[hi], (s - lengths[lo]) / maxf(span, 0.0001))


## Which way the trail runs at `s` (flat).
func heading_at(s: float) -> Vector3:
	var ahead := position_at(s + 0.6) - position_at(s - 0.6)
	ahead.y = 0.0
	return ahead.normalized() if ahead.length() > 0.01 else Vector3.BACK
