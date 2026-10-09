class_name DialogueBox
extends CanvasLayer
## Shows a DialogueScript: a name tag and typed-out text at the bottom of the
## screen with voice blips, scene captions, and choice buttons for Santa.

signal done

const CHARS_PER_SECOND := {"slow": 25.0, "normal": 45.0, "fast": 90.0, "instant": 100000.0}
const TONE_LABELS := {"jolly": "Jolly", "stern": "Stern", "sardonic": "Sardonic"}

var _script: DialogueScript
var _mode: String
var _panel: PanelContainer
var _name_tag: Label
var _text: RichTextLabel
var _more: Label
var _caption: Label
var _choices: VBoxContainer
var _typing := 0.0
var _last_blip := 0
var _pitch := 1.0
var _bark_wait := 0.0


func _init(script: DialogueScript, mode := "scene") -> void:
	_script = script
	_mode = mode
	layer = 80


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE if _mode == "bark" else Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_click)
	add_child(root)

	_caption = UiTheme.heading("", 30)
	_caption.add_theme_color_override("font_color", UiTheme.CREAM)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size.x = 900
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_caption)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120
	_panel.offset_right = -120
	_panel.offset_top = -200
	_panel.offset_bottom = -28
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_name_tag = Label.new()
	_name_tag.add_theme_font_size_override("font_size", 22)
	column.add_child(_name_tag)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("italics_font_size", 22)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	_more = Label.new()
	_more.text = "»"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(_more)

	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choices.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.offset_bottom = -230
	_choices.add_theme_constant_override("separation", 10)
	root.add_child(_choices)

	if _mode != "bark":
		var skip_button := UiTheme.button("Skip  »»", skip, 120)
		skip_button.tooltip_text = "Skip this scene (Tab)"
		skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		skip_button.offset_left = -150
		skip_button.offset_top = 20
		skip_button.offset_right = -20
		skip_button.focus_mode = Control.FOCUS_NONE
		root.add_child(skip_button)
	_show_step()


func skip() -> void:
	_script.skip_to_end()
	_finish()


func _process(delta: float) -> void:
	if _text.visible_ratio < 1.0 and _panel.visible:
		_typing += delta * CHARS_PER_SECOND[GameState.setting("text_speed")]
		_text.visible_characters = int(_typing)
		if _text.visible_characters - _last_blip >= Audio.BLIP_EVERY and _text.visible_ratio < 1.0:
			_last_blip = _text.visible_characters
			Audio.blip(_pitch)
	_more.modulate.a = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)) if _line_shown() else 0.0
	if _mode == "bark" and _line_shown():
		_bark_wait -= delta
		if _bark_wait <= 0.0:
			_next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") and _mode != "bark":
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("advance") and _choices.get_child_count() == 0 and _mode != "bark":
		_next()
		get_viewport().set_input_as_handled()


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _choices.get_child_count() == 0:
			_next()


## Finishes typing the current line, or moves to the next step.
func _next() -> void:
	if _panel.visible and _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
		return
	_script.advance()
	_show_step()


func _line_shown() -> bool:
	return (_panel.visible and _text.visible_ratio >= 1.0) or _caption.visible


func _show_step() -> void:
	for c in _choices.get_children():
		c.queue_free()
	if _script.is_finished():
		_finish()
		return
	var step := _script.current()
	if step.has("cue"):
		# Stage cues (cut to another set, start music...) run instantly.
		Dialogue.cue.emit(step["cue"])
		_script.advance()
		_show_step()
		return
	_caption.visible = step.has("caption")
	if step.has("caption"):
		_panel.visible = false
		_caption.text = step["caption"]
		_caption.modulate.a = 0.0
		create_tween().tween_property(_caption, "modulate:a", 1.0, 0.5)
		_bark_wait = 2.5
	elif step.has("choice"):
		_panel.visible = false
		var options: Array = step["choice"]
		for i in options.size():
			var option: Dictionary = options[i]
			var label: String = option["text"]
			if option.has("tone"):
				label += "    (%s)" % TONE_LABELS.get(option["tone"], option["tone"])
			var b := UiTheme.button(label, _script_choose.bind(i), 640)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_choices.add_child(b)
		(_choices.get_child(0) as Button).grab_focus.call_deferred()
	else:
		_panel.visible = true
		var who := Dialogue.character(step.get("who", ""))
		_name_tag.text = who["name"] + ("  ·  on the phone" if _mode == "phone" else "")
		_name_tag.add_theme_color_override("font_color", Color(who["color"]))
		_pitch = who.get("pitch", 1.0)
		var line: String = step["text"]
		# Stage directions in *asterisks* show in italics.
		_text.text = _italics(line)
		_text.visible_characters = 0
		_typing = 0.0
		_last_blip = 0
		_bark_wait = 1.6 + line.length() * 0.045


func _script_choose(index: int) -> void:
	_script.choose(index)
	_show_step()


func _finish() -> void:
	set_process(false)
	done.emit()
	queue_free()


static func _italics(line: String) -> String:
	var regex := RegEx.create_from_string("\\*([^*]+)\\*")
	return regex.sub(line.replace("[", "[lb]"), "[i]$1[/i]", true)
