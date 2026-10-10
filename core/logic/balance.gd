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


static var _tables := {}


## The tunables in data/balance/<table_name>.json (read once, then cached).
static func table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		var parsed: Variant = LevelCatalog.load_json("res://data/balance/%s.json" % table_name)
		_tables[table_name] = parsed if parsed is Dictionary else {}
	return _tables[table_name]


## Copies the numbers in one section of a balance table onto the matching
## properties of `target` (a controller's tunables). Keys starting with "_"
## are notes and are skipped.
static func apply(target: Object, table_name: String, section: String) -> void:
	var values: Dictionary = table(table_name).get(section, {})
	for key: String in values:
		if not key.begins_with("_") and key in target:
			target.set(key, values[key])
