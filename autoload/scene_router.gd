extends CanvasLayer
## Moves between screens with a fade to black: title, Advent calendar,
## chapters and stingers. Also sets up the input actions and the menu theme.

const TITLE := "res://ui/title/title_screen.tscn"
const CALENDAR := "res://ui/calendar/advent_calendar.tscn"
const STINGER := "res://ui/stinger/stinger_player.tscn"
const CREDITS := "res://ui/credits/credits.tscn"
const LEVEL_STUB := "res://levels/level_stub.tscn"
const PLAYGROUND := "res://levels/playground/playground.tscn"
const FADE_SECONDS := 0.35

## Handed to the next scene, e.g. which stinger to play.
var payload := {}
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	# A window theme doesn't reach Controls under a CanvasLayer, and every menu
	# lives on one, so fold the look into Godot's default theme instead.
	ThemeDB.get_default_theme().merge_with(UiTheme.make())
	add_child(DebugOverlay.new())
	_add_actions()
	GameState.settings_changed.connect(_apply_window_settings)
	_apply_window_settings()


func go_to(path: String, next_payload := {}) -> void:
	if _busy:
		return
	_busy = true
	payload = next_payload
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await out.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Opens a chapter, from its last checkpoint if there is one.
func start_level(level_id: String) -> void:
	var level := LevelCatalog.get_level(level_id)
	GameState.current_level = level_id
	var scene: String = level.get("scene", "")
	if scene.is_empty() or not ResourceLoader.exists(scene):
		scene = LEVEL_STUB
	go_to(scene, {"level": level_id, "checkpoint": GameState.checkpoint_for(level_id)})


func restart_from_checkpoint() -> void:
	start_level(GameState.current_level)


## After the level-complete screen: the stinger if this chapter has one, then
## back to the calendar.
func finish_level(level_id: String) -> void:
	var stinger: String = LevelCatalog.get_level(level_id).get("stinger", "")
	if stinger.is_empty():
		go_to(CALENDAR, {"just_finished": level_id})
	else:
		go_to(STINGER, {"stinger": stinger, "then": CALENDAR, "just_finished": level_id})


func _apply_window_settings() -> void:
	# Browsers only allow fullscreen straight after a click, so this works
	# from the settings toggle but is ignored when a saved game loads.
	var full: bool = GameState.setting("fullscreen")
	var is_full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


func _add_actions() -> void:
	_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _pad(JOY_BUTTON_START)])
	_action("advance", [_key(KEY_SPACE), _key(KEY_ENTER), _key(KEY_KP_ENTER), _pad(JOY_BUTTON_A)])
	_action("skip", [_key(KEY_TAB), _pad(JOY_BUTTON_Y)])


func _action(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e: InputEvent in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e
