class_name ColdMeter
extends RefCounted
## How warm Santa is, from 1 (toasty) down to 0 (frozen solid). It drains
## out in the cold, faster in a blizzard, and fills back up near a fire or
## lantern. Frost's ice can knock a chunk off at once.

## Warmth lost per second in the open cold (the whole meter in 1 / drain s).
var drain := 1.0 / 45.0
## Warmth gained per second right beside a fire.
var refill := 0.35
var value := 1.0
## Below this he shivers and the meter flashes.
var warning := 0.25


func _init(drain_seconds := 45.0, refill_per_second := 0.35) -> void:
	drain = 1.0 / drain_seconds
	refill = refill_per_second


## Moves the meter on by `delta` seconds. `heat` is how close he is to a fire
## (0 out in the cold, 1 right beside it); `chill` multiplies the drain
## (1 normally, more in a blizzard).
func update(delta: float, heat: float, chill := 1.0) -> void:
	if heat > 0.0:
		value += refill * heat * delta
	else:
		value -= drain * chill * delta
	value = clampf(value, 0.0, 1.0)


## A sudden blast of cold (an ice shard, a gust of Frost's breath).
func hit(amount: float) -> void:
	value = clampf(value - amount, 0.0, 1.0)


func is_frozen() -> bool:
	return value <= 0.0


func is_freezing() -> bool:
	return value < warning
