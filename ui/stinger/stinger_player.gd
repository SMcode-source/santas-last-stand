extends Node
## Plays a shadow stinger: 15–20 seconds, one image and one line, in a
## gold-lit dark room. Any key skips it after the first second.
## data/stingers.json: {"id": {"shot": "what we see", "who": "president", "text": "the line"}}

const PATH := "res://data/stingers.json"
const LENGTH := 16.0

var _then := Router.CALENDAR
var _elapsed := 0.0
var _leaving := false


func _ready() -> void:
	_then = Router.payload.get("then", Router.CALENDAR)
	var all: Variant = LevelCatalog.load_json(PATH)
	var stinger: Dictionary = all.get(Router.payload.get("stinger", ""), {}) if all is Dictionary else {}
	if stinger.is_empty():
		_leave.call_deferred()
		return

	var layer := CanvasLayer.new()
	add_child(layer)
	var dark := ColorRect.new()
	dark.color = Color("07050a")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dark)
	# A pool of gold lamplight in the middle of the dark.
	var glow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.78, 0.35, 0.55))
	gradient.set_color(1, Color(1.0, 0.7, 0.3, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	glow.texture = texture
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.modulate.a = 0.0
	layer.add_child(glow)

	var shot := Label.new()
	shot.text = stinger.get("shot", "")
	shot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shot.custom_minimum_size.x = 820
	shot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shot.grow_vertical = Control.GROW_DIRECTION_BOTH
	shot.add_theme_font_size_override("font_size", 26)
	shot.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	shot.modulate.a = 0.0
	layer.add_child(shot)

	var line := UiTheme.heading(stinger.get("text", ""), 30)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -170
	line.offset_bottom = -90
	line.visible_ratio = 0.0
	layer.add_child(line)

	var t := create_tween()
	t.tween_property(glow, "modulate:a", 1.0, 2.0)
	t.parallel().tween_property(shot, "modulate:a", 1.0, 2.0)
	t.tween_interval(2.5)
	t.tween_property(line, "visible_ratio", 1.0, 2.5)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > LENGTH:
		_leave()


func _unhandled_input(event: InputEvent) -> void:
	if _elapsed > 1.0 and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Router.go_to(_then, {"just_finished": Router.payload.get("just_finished", "")})
