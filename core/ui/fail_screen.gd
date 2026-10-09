class_name FailScreen
extends CanvasLayer
## Shown when the player fails: what went wrong, a retry from the last
## checkpoint, and, after a few tries at the same part, Pepper's hint.

var _reason: String
var _hint: String


func _init(reason: String, hint := "") -> void:
	_reason = reason
	_hint = hint
	layer = 70


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UiTheme.dimmer(0.65))
	var parts := UiTheme.centred_panel(520)
	root.add_child(parts[0])
	var column: VBoxContainer = parts[1]
	column.add_child(UiTheme.heading("Not this time", 42))
	var reason := Label.new()
	reason.text = _reason
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reason)

	if not _hint.is_empty():
		var hint_text := Label.new()
		hint_text.text = "Pepper: \"%s\"" % _hint
		hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_text.add_theme_color_override("font_color", Color(Dialogue.character("pepper")["color"]))
		hint_text.visible = false
		var ask := UiTheme.button("Pepper has a hint. Hear it?", func() -> void: pass)
		ask.pressed.connect(func() -> void:
			ask.visible = false
			hint_text.visible = true)
		column.add_child(ask)
		column.add_child(hint_text)

	var retry := UiTheme.button("Try again from the checkpoint", Router.restart_from_checkpoint)
	column.add_child(retry)
	column.add_child(UiTheme.button("Back to the Advent calendar", Router.go_to.bind(Router.CALENDAR)))
	retry.grab_focus.call_deferred()
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.4)
