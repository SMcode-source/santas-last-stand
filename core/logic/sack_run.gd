class_name SackRun
extends RefCounted
## The tally of the sacked elves in Level 2. Krampus's helpers carry the
## sacks off towards the bridge; knock a helper down and he drops his sack,
## then open it to free the elf, who runs to the church and takes a bell
## rope. A sack carried over the bridge is lost, and losing three loses the
## chapter.

signal freed(index: int)
signal escaped(index: int)

## How many lost sacks fail the chapter.
const LOST_LIMIT := 3

enum Sack {WAITING, CARRIED, DROPPED, FREED, LOST}

var sacks: Array[Sack] = []


func _init(count: int) -> void:
	for i in count:
		sacks.append(Sack.WAITING)


## A helper has picked up sack `i`.
func carry(i: int) -> void:
	if sacks[i] in [Sack.WAITING, Sack.DROPPED]:
		sacks[i] = Sack.CARRIED


## Its carrier was knocked down (or beaten before he cut it down): the sack
## lies on the ground.
func drop(i: int) -> void:
	if sacks[i] in [Sack.WAITING, Sack.CARRIED]:
		sacks[i] = Sack.DROPPED


## Santa opened sack `i`. Only a sack on the ground can be opened.
func release(i: int) -> bool:
	if sacks[i] != Sack.DROPPED:
		return false
	sacks[i] = Sack.FREED
	freed.emit(i)
	return true


## Sack `i` was carried over the bridge.
func escape(i: int) -> void:
	if sacks[i] != Sack.CARRIED:
		return
	sacks[i] = Sack.LOST
	escaped.emit(i)


func count(state: Sack) -> int:
	return sacks.count(state)


## Elves at the bell ropes.
func ringers() -> int:
	return count(Sack.FREED)


func is_failed() -> bool:
	return count(Sack.LOST) >= LOST_LIMIT


## Every sack is either freed or gone.
func is_settled() -> bool:
	return count(Sack.FREED) + count(Sack.LOST) == sacks.size()
