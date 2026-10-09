class_name UiTheme
extends RefCounted
## The game's menu look: deep night-blue panels edged in gold, berry-red
## buttons and warm cream text. Built in code and applied to the whole window.

const GOLD := Color("ffd86b")
const GOLD_DIM := Color("b8913c")
const CREAM := Color("f7f0e1")
const BERRY := Color("8f1424")
const BERRY_LIGHT := Color("b81d31")
const NIGHT := Color(0.06, 0.08, 0.17, 0.92)
const INK := Color("1a1022")


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 4)

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())

	var normal := _box(BERRY, GOLD_DIM, 2, 10)
	var hover := _box(BERRY_LIGHT, GOLD, 2, 10)
	var pressed := _box(BERRY.darkened(0.25), GOLD, 2, 10)
	var disabled := _box(Color(0.25, 0.22, 0.27, 0.85), Color(0.4, 0.38, 0.42), 2, 10)
	var focus := _box(Color(0, 0, 0, 0), GOLD, 3, 10)
	focus.draw_center = false
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, CREAM)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(0.65, 0.62, 0.66))
	# Toggle switches sit on a plain row, not a red button.
	var flat := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(state, "CheckButton", flat)

	var track := _box(Color(0.12, 0.13, 0.25), GOLD_DIM, 1, 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := _box(BERRY_LIGHT, GOLD_DIM, 1, 6)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(BERRY_LIGHT.lightened(0.15), GOLD, 1, 6))

	var popup := _box(Color(0.08, 0.09, 0.2, 0.98), GOLD_DIM, 2, 8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", _box(BERRY, BERRY, 0, 4))

	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "RichTextLabel", 3)
	return t


static func panel(radius := 14) -> StyleBoxFlat:
	var box := _box(NIGHT, GOLD_DIM, 2, radius)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 12
	return box


static func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.anti_aliasing = true
	return box


## A big gold heading with a dark-red outline, like the title.
static func heading(text: String, size := 44) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color("7a0f1c"))
	label.add_theme_constant_override("outline_size", maxi(6, size / 5))
	return label


static func button(text: String, on_pressed: Callable, min_width := 280) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 48)
	b.pressed.connect(func() -> void:
		Audio.play_sfx("click")
		on_pressed.call())
	return b


## A full-screen translucent dimmer, used behind menus.
static func dimmer(alpha := 0.55) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


## A panel centred on screen holding a vertical list.
static func centred_panel(min_width := 420) -> Array:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_node := PanelContainer.new()
	panel_node.custom_minimum_size.x = min_width
	centre.add_child(panel_node)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel_node.add_child(column)
	return [centre, column]
