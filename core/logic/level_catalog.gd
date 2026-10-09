class_name LevelCatalog
extends RefCounted
## The chapters of the Advent calendar, read from data/levels.json, and the
## rule for which ones are open: each chapter unlocks when the one before it
## is finished.

const PATH := "res://data/levels.json"

static var _levels: Array = []


static func all() -> Array:
	if _levels.is_empty():
		_levels = load_json(PATH)
	return _levels


static func get_level(id: String) -> Dictionary:
	for level: Dictionary in all():
		if level["id"] == id:
			return level
	return {}


static func index_of(id: String) -> int:
	for i in all().size():
		if all()[i]["id"] == id:
			return i
	return -1


static func is_unlocked(save: SaveData, id: String) -> bool:
	var i := index_of(id)
	return i == 0 or (i > 0 and save.is_completed(all()[i - 1]["id"]))


## The next chapter after `id`, or "" after the last one.
static func next_after(id: String) -> String:
	var i := index_of(id)
	return all()[i + 1]["id"] if i >= 0 and i + 1 < all().size() else ""


## The first unlocked chapter that isn't finished: where "Continue" goes.
static func next_to_play(save: SaveData) -> String:
	for level: Dictionary in all():
		if not save.is_completed(level["id"]):
			return level["id"]
	return all()[-1]["id"]


static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Could not read %s" % path)
	return parsed
