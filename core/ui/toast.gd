class_name Toast
extends CanvasLayer
## A short message that slides in at the top of the screen and fades away.


static func show_on(owner_node: Node, text: String, seconds := 2.2) -> void:
	var toast := Toast.new()
	toast.layer = 40
	owner_node.add_child(toast)
	var label := UiTheme.heading(text, 28)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 90
	label.modulate.a = 0.0
	toast.add_child(label)
	var t := toast.create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.25)
	t.tween_interval(seconds)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(toast.queue_free)
