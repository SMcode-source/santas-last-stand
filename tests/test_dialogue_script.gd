extends TestCase

const STEPS := [
	{"caption": "Somewhere"},
	{"who": "holly", "text": "A"},
	{"choice": [
		{"text": "Nice", "tone": "jolly", "then": [{"who": "holly", "text": "B1"}, {"who": "santa", "text": "B2"}]},
		{"text": "Nasty", "tone": "stern"},
	]},
	{"by_tone": {"jolly": {"who": "president", "text": "J"}, "stern": {"who": "president", "text": "S"}}},
	{"who": "santa", "text": "End"},
]


func test_walks_lines_and_branch() -> void:
	var tones: Array[String] = []
	var d := DialogueScript.new(STEPS, func() -> String: return tones[-1] if tones else "jolly")
	d.tone_chosen.connect(func(t: String) -> void: tones.append(t))
	check_eq(d.current().get("caption", ""), "Somewhere")
	d.advance()
	check_eq(d.current()["text"], "A")
	d.advance()
	check(d.current().has("choice"), "at the choice")
	d.advance()
	check(d.current().has("choice"), "advance does not skip a choice")
	d.choose(0)
	check_eq(tones, ["jolly"] as Array[String], "tone reported")
	check_eq(d.current()["text"], "B1")
	d.advance()
	check_eq(d.current()["text"], "B2")
	d.advance()
	check_eq(d.current()["text"], "J", "line picked by tone")
	d.advance()
	check_eq(d.current()["text"], "End")
	d.advance()
	check(d.is_finished(), "finished")
	check(d.current().is_empty(), "nothing after the end")


func test_choice_without_lines_continues() -> void:
	var d := DialogueScript.new(STEPS, func() -> String: return "stern")
	d.advance()
	d.advance()
	d.choose(1)
	check_eq(d.current()["text"], "S")


func test_skip_counts_first_choice() -> void:
	var tones: Array[String] = []
	var d := DialogueScript.new(STEPS)
	d.tone_chosen.connect(func(t: String) -> void: tones.append(t))
	d.skip_to_end()
	check(d.is_finished(), "finished")
	check_eq(tones, ["jolly"] as Array[String], "skipped choice takes the first option")


func test_by_tone_does_not_change_the_source_data() -> void:
	DialogueScript.new(STEPS).skip_to_end()
	check(STEPS[3].has("by_tone"), "original steps untouched")


func test_prologue_data_is_well_formed() -> void:
	var prologue: Dictionary = LevelCatalog.load_json("res://data/dialogue/prologue.json")
	var characters: Dictionary = LevelCatalog.load_json("res://data/characters.json")
	for key in prologue:
		_check_steps(prologue[key], characters)
	var calls: Dictionary = LevelCatalog.load_json("res://data/dialogue/calls.json")
	for key in calls:
		_check_steps(calls[key], characters)


func _check_steps(steps: Array, characters: Dictionary) -> void:
	for step: Dictionary in steps:
		if step.has("who"):
			check(characters.has(step["who"]), "unknown speaker %s" % step["who"])
			check(step.has("text"), "line without text")
		elif step.has("choice"):
			for option: Dictionary in step["choice"]:
				check(option.get("tone", "jolly") in SaveData.TONES, "unknown tone")
				_check_steps(option.get("then", []), characters)
		elif step.has("by_tone"):
			for t in SaveData.TONES:
				check(step["by_tone"].has(t), "by_tone missing %s" % t)
		else:
			check(step.has("caption") or step.has("cue"), "unknown step %s" % step)
