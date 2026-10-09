extends Node
## Credits and licences, scrolling slowly over the winter camp.

const BACKDROP := preload("res://hello/hello_santa.tscn")

var _scroll: ScrollContainer
var _elapsed := 0.0
var _offset := 0.0


func _ready() -> void:
	var backdrop: Node3D = BACKDROP.instantiate()
	backdrop.show_ui = false
	add_child(backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(UiTheme.dimmer(0.6))

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 180
	panel.offset_right = -180
	panel.offset_top = 40
	panel.offset_bottom = -100
	layer.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	_scroll.add_child(column)

	column.add_child(UiTheme.heading("SANTA'S LAST STAND", 44))
	_section(column, "Created by", "SMcode-source\nBuilt with Claude Code")
	_section(column, "Made with", "Godot Engine (godotengine.org)")
	_section(column, "Textures and 3D models",
			"Poly Haven (polyhaven.com), CC0. See assets/LICENSES.md for every file.")
	_section(column, "Characters", "3D character models generated with Meshy AI (meshy.ai), CC BY 4.0.")
	_section(column, "Music", "\"Jingle Bells\" by James Lord Pierpont (1857), public domain,\nplayed on a music box synthesised in the game.")
	_section(column, "Sound", "All sound effects and voices are synthesised in the game.")
	_section(column, "Godot Engine licence", Engine.get_license_text())

	var back := UiTheme.button("Back", Router.go_to.bind(Router.TITLE, {"menu": true}))
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back.offset_top = -80
	back.offset_bottom = -32
	back.offset_left = -140
	back.offset_right = 140
	layer.add_child(back)
	back.grab_focus.call_deferred()


func _section(column: VBoxContainer, heading: String, body: String) -> void:
	var h := UiTheme.heading(heading, 26)
	column.add_child(h)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.x = 600
	column.add_child(text)


func _process(delta: float) -> void:
	# Drifts down slowly after a short pause; the reader can still scroll back.
	_elapsed += delta
	if _elapsed > 3.0:
		_offset = maxf(_offset, _scroll.scroll_vertical) + delta * 24.0
		_scroll.scroll_vertical = int(_offset)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Router.go_to(Router.TITLE, {"menu": true})
