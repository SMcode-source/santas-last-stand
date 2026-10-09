extends Node
## The title screen over the winter camp. Browsers only allow sound after a
## click, so it first asks for one, then starts the music box and shows the menu.

const BACKDROP := preload("res://hello/hello_santa.tscn")

var _backdrop: Node3D
var _prompt: Label
var _menu: VBoxContainer
var _overlay: Control


func _ready() -> void:
	_backdrop = BACKDROP.instantiate()
	_backdrop.show_ui = false
	add_child(_backdrop)

	var layer := CanvasLayer.new()
	add_child(layer)
	var title := UiTheme.heading("SANTA'S LAST STAND", 64)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 28
	layer.add_child(title)
	var tagline := Label.new()
	tagline.text = "Christmas is being stolen. Only Santa can get it back."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 112
	layer.add_child(tagline)

	_prompt = UiTheme.heading("Click or press any key to begin", 26)
	_prompt.add_theme_color_override("font_color", UiTheme.CREAM)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -80
	_prompt.offset_bottom = -40
	layer.add_child(_prompt)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_prompt, "modulate:a", 0.35, 0.9)
	pulse.tween_property(_prompt, "modulate:a", 1.0, 0.9)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_menu.offset_left = 70
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.visible = false
	layer.add_child(_menu)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	# Coming back from the credits or a chapter: skip the click-to-begin step.
	if Router.payload.get("menu", false) or Audio.is_music_playing():
		_begin()


func _unhandled_input(event: InputEvent) -> void:
	if not _prompt.visible:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if key or click or pad:
		get_viewport().set_input_as_handled()
		_begin()


func _begin() -> void:
	_prompt.visible = false
	if not Audio.is_music_playing():
		Audio.play_music_box()
	_backdrop.santa.wave()
	_show_menu()


func _show_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	if GameState.has_save:
		var next := LevelCatalog.get_level(LevelCatalog.next_to_play(GameState.data))
		var cont := UiTheme.button("Continue", Router.go_to.bind(Router.CALENDAR))
		cont.tooltip_text = "Next: %s, %s" % [next.get("date", ""), next.get("title", "")]
		_menu.add_child(cont)
	_menu.add_child(UiTheme.button("New story", _new_story))
	if GameState.has_save:
		_menu.add_child(UiTheme.button("Advent calendar", Router.go_to.bind(Router.CALENDAR)))
	_menu.add_child(UiTheme.button("Settings", _settings))
	_menu.add_child(UiTheme.button("Credits", Router.go_to.bind(Router.CREDITS)))
	_menu.visible = true
	_menu.modulate.a = 0.0
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.5)
	(_menu.get_child(0) as Button).grab_focus.call_deferred()


func _new_story() -> void:
	if GameState.has_save:
		_ask("Start a new story?", "This replaces your saved progress.", [
			["Start a new story", _pick_mode],
			["Cancel", _close_overlay],
		])
	else:
		_pick_mode()


func _pick_mode() -> void:
	_ask("How would you like to play?", "You can switch any time in Settings.", [
		["Story", _start.bind(false), "The full challenge, as intended."],
		["Cocoa Mode", _start.bind(true), "More health and slower timers. Great for younger players."],
		["Back", _close_overlay],
	])


func _start(cocoa_mode: bool) -> void:
	GameState.new_game(cocoa_mode)
	Audio.stop_music()
	Router.start_level("prologue")


func _settings() -> void:
	_close_overlay()
	_menu.visible = false
	var dim := UiTheme.dimmer(0.4)
	_overlay.add_child(dim)
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void:
		_close_overlay()
		_menu.visible = true
		(_menu.get_child(0) as Button).grab_focus())
	_overlay.add_child(panel)


## A small centred question with a row of answers: [label, action, tooltip].
func _ask(question: String, detail: String, answers: Array) -> void:
	_close_overlay()
	_menu.visible = false
	_overlay.add_child(UiTheme.dimmer(0.4))
	var parts := UiTheme.centred_panel(480)
	_overlay.add_child(parts[0])
	var column: VBoxContainer = parts[1]
	column.add_child(UiTheme.heading(question, 32))
	var sub := Label.new()
	sub.text = detail
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	for a: Array in answers:
		var b := UiTheme.button(a[0], a[1])
		if a.size() > 2:
			b.tooltip_text = a[2]
			b.text = "%s:  %s" % [a[0], a[2]]
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = 460
		column.add_child(b)
	(column.get_child(2) as Button).grab_focus.call_deferred()


func _close_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	if not _prompt.visible:
		_menu.visible = true
