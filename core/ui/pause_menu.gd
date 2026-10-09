class_name PauseMenu
extends CanvasLayer
## Esc or P (Start on a gamepad) pauses a chapter: resume, settings, restart
## from the last checkpoint, or go back to the Advent calendar.

## Off while the fail or level-complete screen is up.
var enabled := true
var _root: Control
var _menu: Control
var _settings: SettingsPanel


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_root.add_child(UiTheme.dimmer())
	var parts := UiTheme.centred_panel()
	_menu = parts[0]
	var column: VBoxContainer = parts[1]
	_root.add_child(_menu)
	column.add_child(UiTheme.heading("Paused", 40))
	var level := LevelCatalog.get_level(GameState.current_level)
	if not level.is_empty():
		var sub := Label.new()
		sub.text = "%s  ·  %s" % [level["date"], level["title"]]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(sub)
	column.add_child(UiTheme.button("Resume", close))
	column.add_child(UiTheme.button("Settings", _open_settings))
	column.add_child(UiTheme.button("Restart from checkpoint", Router.restart_from_checkpoint))
	column.add_child(UiTheme.button("Back to the Advent calendar", func() -> void:
		var level_node := get_parent() as LevelBase
		if level_node:
			GameState.data.add_play_time(level_node.level_id, level_node.play_time)
			GameState.save_game()
		Router.go_to(Router.CALENDAR)))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or not enabled:
		return
	get_viewport().set_input_as_handled()
	if not _root.visible:
		open()
	elif _settings:
		_close_settings()
	else:
		close()


func open() -> void:
	_root.visible = true
	_menu.visible = true
	get_tree().paused = true
	(_menu.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func close() -> void:
	_close_settings()
	_root.visible = false
	get_tree().paused = false


func _open_settings() -> void:
	_menu.visible = false
	_settings = SettingsPanel.new()
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
	_menu.visible = true
