class_name SettingsPanel
extends CenterContainer
## Volume, text speed, graphics, Cocoa Mode, Pepper's hints and fullscreen.
## Every change is saved straight away.

signal closed

const TEXT_SPEEDS := ["slow", "normal", "fast", "instant"]
const QUALITIES := ["auto", "low", "medium", "high"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiTheme.heading("Settings", 38))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	_slider(grid, "Music", "music")
	_slider(grid, "Sound effects", "sfx")
	_slider(grid, "Voices", "voice")
	_choice(grid, "Text speed", "text_speed", TEXT_SPEEDS)
	_choice(grid, "Graphics", "quality", QUALITIES)
	_toggle(grid, "Cocoa Mode", "More health and slower timers, for younger players. Puzzles stay the same.",
			GameState.data.cocoa_mode, GameState.set_cocoa_mode)
	_toggle(grid, "Pepper's hints", "After three tries at the same part, Pepper offers a hint.",
			GameState.setting("hints"), func(on: bool) -> void: GameState.set_setting("hints", on))
	_toggle(grid, "Fullscreen", "", GameState.setting("fullscreen"),
			func(on: bool) -> void: GameState.set_setting("fullscreen", on))

	var back := UiTheme.button("Back", func() -> void: closed.emit())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(back)
	back.grab_focus.call_deferred()


func _label(grid: GridContainer, text: String, tooltip := "") -> void:
	var label := Label.new()
	label.text = text
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(label)


func _slider(grid: GridContainer, text: String, key: String) -> void:
	_label(grid, text)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = GameState.setting(key)
	slider.custom_minimum_size = Vector2(240, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void:
		GameState.set_setting(key, v)
		if key == "voice":
			Audio.blip(1.0)
		elif key == "sfx":
			Audio.play_sfx("click"))
	grid.add_child(slider)


func _choice(grid: GridContainer, text: String, key: String, options: Array) -> void:
	_label(grid, text)
	var pick := OptionButton.new()
	for o: String in options:
		pick.add_item(o.capitalize())
	pick.selected = maxi(options.find(GameState.setting(key)), 0)
	pick.item_selected.connect(func(i: int) -> void: GameState.set_setting(key, options[i]))
	grid.add_child(pick)


func _toggle(grid: GridContainer, text: String, tooltip: String, on: bool, apply: Callable) -> void:
	_label(grid, text, tooltip)
	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.tooltip_text = tooltip
	toggle.toggled.connect(func(value: bool) -> void:
		Audio.play_sfx("click")
		apply.call(value))
	grid.add_child(toggle)
