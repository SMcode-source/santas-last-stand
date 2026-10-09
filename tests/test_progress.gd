extends TestCase


func test_chapters_unlock_in_order() -> void:
	var s := SaveData.new()
	check(LevelCatalog.is_unlocked(s, "prologue"), "prologue open from the start")
	check(not LevelCatalog.is_unlocked(s, "l1"), "l1 locked")
	s.record_completion("prologue", 100.0)
	check(LevelCatalog.is_unlocked(s, "l1"), "l1 opens after the prologue")
	check(not LevelCatalog.is_unlocked(s, "l2"), "l2 still locked")
	check(not LevelCatalog.is_unlocked(s, "nonsense"), "unknown level locked")


func test_next_to_play() -> void:
	var s := SaveData.new()
	check_eq(LevelCatalog.next_to_play(s), "prologue")
	s.record_completion("prologue", 1.0)
	s.record_completion("l1", 1.0)
	check_eq(LevelCatalog.next_to_play(s), "l2")


func test_catalog_is_well_formed() -> void:
	var days := {}
	for level: Dictionary in LevelCatalog.all():
		for key in ["id", "day", "date", "title", "genre", "difficulty", "scene", "call", "stinger"]:
			check(level.has(key), "%s missing %s" % [level.get("id", "?"), key])
		var day := int(level["day"])
		check(day >= 1 and day <= 25, "day in range")
		check(not days.has(day), "one chapter per door")
		days[day] = true
		var scene: String = level["scene"]
		check(scene.is_empty() or ResourceLoader.exists(scene), "scene exists: %s" % scene)
		var call: String = level["call"]
		if not call.is_empty():
			var file: Dictionary = LevelCatalog.load_json("res://data/dialogue/%s.json" % call.get_slice("/", 0))
			check(file.has(call.get_slice("/", 1)), "call exists: %s" % call)
	check_eq(LevelCatalog.all().size(), 11, "prologue plus 10 levels")
	check_eq(LevelCatalog.next_after("l10"), "", "nothing after the last chapter")


func test_cocoa_mode_scaling() -> void:
	check_eq(Balance.scaled(100.0, "health", false), 100.0, "normal health")
	check_eq(Balance.scaled(100.0, "health", true), 150.0, "cocoa health")
	check(Balance.scaled(60.0, "timer", true) > 60.0, "cocoa timers are longer")
	check_eq(Balance.scaled(7.0, "unknown", true), 7.0, "unknown kinds unchanged")


func test_hints_after_three_fails() -> void:
	check(not Balance.should_offer_hint(2, true), "not yet")
	check(Balance.should_offer_hint(3, true), "third fail")
	check(not Balance.should_offer_hint(5, false), "hints switched off")
