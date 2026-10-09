extends TestCase


func test_round_trip_through_json() -> void:
	var s := SaveData.new()
	s.cocoa_mode = true
	s.add_tone("stern", 2)
	s.record_completion("prologue", 95.5, {"coins": 2})
	s.checkpoint = {"level": "l1", "id": "clock_tower"}
	s.add_fail("l1", "boss")
	s.settings["music"] = 0.25
	var restored := SaveData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check_eq(restored.cocoa_mode, true, "cocoa mode")
	check_eq(restored.tone["stern"], 2, "tone")
	check(restored.is_completed("prologue"), "prologue completed")
	check_eq(restored.checkpoint["id"], "clock_tower", "checkpoint")
	check_eq(int(restored.stats["l1"]["fails"]["boss"]), 1, "fails")
	check_eq(restored.settings["music"], 0.25, "music volume")


func test_damaged_save_falls_back_to_defaults() -> void:
	var s := SaveData.from_dict({"tone": "oops", "settings": {"music": "loud", "hints": false}, "completed": 5})
	check_eq(s.tone["jolly"], 0, "tone")
	check_eq(s.settings["music"], SaveData.DEFAULT_SETTINGS["music"], "bad music value ignored")
	check_eq(s.settings["hints"], false, "good hints value kept")
	check(s.completed.is_empty(), "completed")


func test_best_time_and_collectibles_are_kept() -> void:
	var s := SaveData.new()
	s.record_completion("l1", 600.0, {"coins": 3, "letters": 1})
	s.record_completion("l1", 500.0, {"coins": 1, "brick": true})
	var r: Dictionary = s.completed["l1"]
	check_eq(r["best_time"], 500.0, "best time")
	check_eq(r["coins"], 3, "most coins")
	check_eq(r["letters"], 1, "letters")
	check_eq(r["brick"], true, "brick")


func test_completing_a_level_clears_its_checkpoint() -> void:
	var s := SaveData.new()
	s.checkpoint = {"level": "l1", "id": "boss"}
	s.record_completion("l2", 10.0)
	check_eq(s.checkpoint.get("id", ""), "boss", "other level keeps checkpoint")
	s.record_completion("l1", 10.0)
	check(s.checkpoint.is_empty(), "own checkpoint cleared")


func test_dominant_tone() -> void:
	var s := SaveData.new()
	check_eq(s.dominant_tone(), "jolly", "tie goes to jolly")
	s.add_tone("sardonic")
	check_eq(s.dominant_tone(), "sardonic")
	s.add_tone("stern", 2)
	check_eq(s.dominant_tone(), "stern")


func test_fail_counts_per_section() -> void:
	var s := SaveData.new()
	s.add_fail("l1", "boss")
	s.add_fail("l1", "boss")
	check_eq(s.add_fail("l1", "boss"), 3, "third boss fail")
	check_eq(s.add_fail("l1", "start"), 1, "other section counted separately")
