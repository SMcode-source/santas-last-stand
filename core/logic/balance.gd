class_name Balance
extends RefCounted
## Cocoa Mode (easier, for younger players): more health and slower timers.
## Puzzles stay the same. Levels pass every tunable number through `scaled`.

const COCOA := {
	"health": 1.5,
	"timer": 1.35,
	"damage_taken": 0.6,
	"enemy_speed": 0.85,
}


static func scaled(value: float, kind: String, cocoa_mode: bool) -> float:
	return value * COCOA.get(kind, 1.0) if cocoa_mode else value


## Pepper offers a hint after this many failures on the same section.
const HINT_AFTER_FAILS := 3


static func should_offer_hint(fails: int, hints_enabled: bool) -> bool:
	return hints_enabled and fails >= HINT_AFTER_FAILS
