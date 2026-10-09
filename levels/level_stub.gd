extends LevelBase
## Stands in for chapters that are built in later milestones, so the whole
## loop can be tested now: checkpoints, failing and retrying, Pepper's hints,
## pausing, the level-complete screen, the phone call and the stinger.

const BACKDROP := preload("res://hello/hello_santa.tscn")

var _status: Label


func _ready() -> void:
	super._ready()
	var backdrop: Node3D = BACKDROP.instantiate()
	backdrop.show_ui = false
	add_child(backdrop)

	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 40)
	panel.custom_minimum_size.x = 460
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var level := level_data()
	var date := Label.new()
	date.text = level.get("date", "")
	column.add_child(date)
	var title := UiTheme.heading(level.get("title", level_id), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(title)
	var about := Label.new()
	about.text = "%s  ·  difficulty %d/10\n\nThis chapter is built in a later milestone. Meanwhile you can try the systems around it:" % [
		level.get("genre", ""), level.get("difficulty", 0)]
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(about)
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(_status)

	column.add_child(UiTheme.button("Reach the next checkpoint", _next_checkpoint, 420))
	column.add_child(UiTheme.button("Pick up a gold T coin", func() -> void:
		collect("coins")
		Toast.show_on(self, "Gold T coin  %d / 3" % found["coins"])
		_refresh(), 420))
	column.add_child(UiTheme.button("Fail (fall into the snow)", fail.bind("Santa slipped and fell into a snowdrift."), 420))
	column.add_child(UiTheme.button("Finish the chapter", complete, 420))
	var keys := Label.new()
	keys.text = "Esc or P pauses.  F3 shows play time and failures."
	keys.add_theme_font_size_override("font_size", 16)
	column.add_child(keys)
	_refresh()


func hint_for(part: String) -> String:
	var hint := super.hint_for(part)
	return hint if not hint.is_empty() else "This is where my hint for the %s will go, once this chapter is built." % part.capitalize()


func _next_checkpoint() -> void:
	var checkpoints: Array = level_data().get("checkpoints", [])
	if checkpoints.is_empty():
		checkpoints = ["midpoint", "finale"]
	var i := checkpoints.find(section)
	if i + 1 < checkpoints.size():
		reach_checkpoint(checkpoints[i + 1])
	else:
		Toast.show_on(self, "No more checkpoints")
	_refresh()


func _refresh() -> void:
	_status.text = "Section: %s   ·   coins %d / 3" % [section.capitalize(), found["coins"]]
