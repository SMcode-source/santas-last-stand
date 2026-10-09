class_name LevelComplete
extends CanvasLayer
## The end-of-chapter screen: time and collectibles, then the gold phone rings
## and the President's call plays over it, then on to the stinger and calendar.

var _level_id: String
var _time: float
var _found: Dictionary
var _column: VBoxContainer
var _continue: Button


func _init(level_id: String, time: float, found: Dictionary) -> void:
	_level_id = level_id
	_time = time
	_found = found
	layer = 70


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UiTheme.dimmer(0.5))
	var parts := UiTheme.centred_panel(560)
	var centre: CenterContainer = parts[0]
	# Sit high enough to leave room for the call's dialogue box underneath.
	centre.offset_bottom = -170
	root.add_child(centre)
	_column = parts[1]
	var level := LevelCatalog.get_level(_level_id)
	var date := Label.new()
	date.text = level.get("date", "")
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(date)
	_column.add_child(UiTheme.heading("Chapter complete", 42))
	_column.add_child(UiTheme.heading(level.get("title", ""), 28))

	var best: float = GameState.data.completed.get(_level_id, {}).get("best_time", _time)
	_row("Time", clock(_time) + ("" if best >= _time else "   (best %s)" % clock(best)))
	if level.get("collectibles", true):
		_row("Gold T coins", "%d / 3" % _found.get("coins", 0))
		_row("Lost letter", "found" if _found.get("letters", 0) > 0 else "not found")
		_row("Agent Brick", "spotted" if _found.get("brick", false) else "not spotted")

	_continue = UiTheme.button("Continue", Router.finish_level.bind(_level_id))
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_continue)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.4)

	var call: String = level.get("call", "")
	if call.is_empty():
		_continue.grab_focus.call_deferred()
	else:
		_continue.visible = false
		_ring.call_deferred(call)


func _row(label_text: String, value: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(label)
	row.add_child(value_label)
	_column.add_child(row)


## The gold phone rings until the player answers it.
func _ring(call: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var ringing := Label.new()
	ringing.text = "The gold phone is ringing..."
	ringing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ringing.add_theme_color_override("font_color", UiTheme.GOLD)
	_column.add_child(ringing)
	var answer := UiTheme.button("Answer", func() -> void: pass)
	answer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(answer)
	answer.grab_focus()
	var shake := create_tween().set_loops()
	shake.tween_property(ringing, "rotation", 0.03, 0.05)
	shake.tween_property(ringing, "rotation", -0.03, 0.05)
	ringing.resized.connect(func() -> void: ringing.pivot_offset = ringing.size / 2.0)
	Audio.play_sfx("ring", 1.0, -4.0)
	await answer.pressed
	shake.kill()
	Audio.play_sfx("click")
	Audio.stop_sfx("ring")
	ringing.queue_free()
	answer.queue_free()
	var call_file: String = call.get_slice("/", 0)
	var call_key: String = call.get_slice("/", 1)
	await Dialogue.play(Dialogue.lines(call_file, call_key), "phone")
	_continue.visible = true
	_continue.grab_focus()


static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
