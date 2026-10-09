extends Node
## The Advent calendar hub: 24 doors and a Midnight door. Chapter doors open
## in order as the story goes on; picking one shows its card, with a recap
## once it has been played.

const BACKDROP := preload("res://hello/hello_santa.tscn")
const LOCKED := Color(0.22, 0.2, 0.26, 0.92)
const OPEN := Color("1f5a3a")
const PLAIN := Color("4a2e1f")

var _doors := {}
var _card: VBoxContainer
var _selected := ""


func _ready() -> void:
	var backdrop: Node3D = BACKDROP.instantiate()
	backdrop.show_ui = false
	add_child(backdrop)
	if not Audio.is_music_playing():
		Audio.play_music_box()

	var layer := CanvasLayer.new()
	add_child(layer)
	var dim := UiTheme.dimmer(0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 40
	row.offset_right = -40
	row.offset_top = 30
	row.offset_bottom = -30
	row.add_theme_constant_override("separation", 28)
	layer.add_child(row)

	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(board)
	var board_column := VBoxContainer.new()
	board_column.add_theme_constant_override("separation", 12)
	board.add_child(board_column)
	board_column.add_child(UiTheme.heading("Advent Calendar", 40))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	board_column.add_child(grid)

	var by_day := {}
	for level: Dictionary in LevelCatalog.all():
		by_day[int(level["day"])] = level
	for day in range(1, 25):
		grid.add_child(_door(day, by_day.get(day, {})))
	var midnight := _door(25, by_day.get(25, {}))
	midnight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_column.add_child(midnight)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 420
	side.add_theme_constant_override("separation", 12)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var card_panel := PanelContainer.new()
	side.add_child(card_panel)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 10)
	card_panel.add_child(_card)
	var mode := Label.new()
	mode.text = "Cocoa Mode is on" if GameState.data.cocoa_mode else ""
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(mode)
	side.add_child(UiTheme.button("Back to the title screen", Router.go_to.bind(Router.TITLE, {"menu": true})))

	var finished: String = Router.payload.get("just_finished", "")
	var first := LevelCatalog.next_to_play(GameState.data)
	if not finished.is_empty() and LevelCatalog.next_after(finished).is_empty():
		first = finished
	_select(first)


func _door(day: int, level: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 70)
	b.text = "Midnight" if day == 25 else str(day)
	b.add_theme_font_size_override("font_size", 30 if day < 25 else 26)
	if level.is_empty():
		# An ordinary day: a closed wooden door.
		b.disabled = true
		b.add_theme_stylebox_override("disabled", UiTheme._box(PLAIN, PLAIN.lightened(0.15), 1, 8))
		b.add_theme_color_override("font_disabled_color", Color(0.85, 0.7, 0.55, 0.55))
		b.focus_mode = Control.FOCUS_NONE
		return b
	var id: String = level["id"]
	_doors[id] = b
	if GameState.data.is_completed(id):
		_style(b, OPEN, UiTheme.GOLD)
	elif not LevelCatalog.is_unlocked(GameState.data, id):
		_style(b, LOCKED, Color(0.45, 0.42, 0.5))
		b.add_theme_color_override("font_color", Color(0.6, 0.58, 0.64))
	b.tooltip_text = "%s: %s" % [level["date"], level["title"]]
	b.pressed.connect(func() -> void:
		Audio.play_sfx("click")
		_select(id))
	return b


func _style(b: Button, fill: Color, border: Color) -> void:
	b.add_theme_stylebox_override("normal", UiTheme._box(fill, border, 2, 10))
	b.add_theme_stylebox_override("hover", UiTheme._box(fill.lightened(0.12), UiTheme.GOLD, 2, 10))
	b.add_theme_stylebox_override("pressed", UiTheme._box(fill.darkened(0.2), UiTheme.GOLD, 2, 10))


func _select(id: String) -> void:
	_selected = id
	if _doors.has(id):
		(_doors[id] as Button).grab_focus()
	for c in _card.get_children():
		c.queue_free()
	var level := LevelCatalog.get_level(id)
	var unlocked := LevelCatalog.is_unlocked(GameState.data, id)
	var done := GameState.data.is_completed(id)

	var date := Label.new()
	date.text = level["date"]
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(date)
	var title := UiTheme.heading(level["title"], 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(title)
	var facts := Label.new()
	var parts: Array[String] = [level["genre"]]
	if level.get("finale", "") != "":
		parts.append(level["finale"])
	parts.append("about %d min" % level.get("minutes", 10))
	facts.text = "  ·  ".join(parts)
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(facts)
	if int(level["difficulty"]) > 0:
		_card.add_child(_difficulty(int(level["difficulty"])))

	if done:
		var record: Dictionary = GameState.data.completed[id]
		if level.get("recap", "") != "":
			_paragraph(level["recap"])
		var best := Label.new()
		best.text = "Best time %s" % LevelComplete.clock(record.get("best_time", 0.0))
		if level.get("collectibles", true):
			best.text += "  ·  coins %d/3  ·  letter %s  ·  Brick %s" % [
				record.get("coins", 0), "yes" if record.get("letters", 0) > 0 else "no",
				"yes" if record.get("brick", false) else "no"]
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_color_override("font_color", UiTheme.GOLD)
		_card.add_child(best)

	if not unlocked:
		var previous: Dictionary = LevelCatalog.all()[LevelCatalog.index_of(id) - 1]
		_paragraph("This door opens after \"%s\"." % previous["title"])
		return
	var checkpoint := GameState.checkpoint_for(id)
	if not checkpoint.is_empty():
		_card.add_child(UiTheme.button("Continue from checkpoint", _play.bind(id)))
		_card.add_child(UiTheme.button("Start from the beginning", func() -> void:
			GameState.data.checkpoint = {}
			GameState.save_game()
			_play(id)))
	else:
		_card.add_child(UiTheme.button("Play again" if done else "Play", _play.bind(id)))


func _play(id: String) -> void:
	Audio.stop_music()
	Router.start_level(id)


func _paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 360
	_card.add_child(label)


## Ten little pips, filled up to the chapter's difficulty.
func _difficulty(value: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = "Difficulty  "
	row.add_child(label)
	for i in 10:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(16, 16)
		var filled := i < value
		pip.add_theme_stylebox_override("panel", UiTheme._box(
				UiTheme.BERRY_LIGHT if filled else Color(0.15, 0.15, 0.25), UiTheme.GOLD_DIM, 1, 8))
		row.add_child(pip)
	return row
