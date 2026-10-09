class_name DebugOverlay
extends CanvasLayer
## F3 toggles a small performance readout: FPS, frame time, draw calls and triangles.
## Running with `-- --bench` prints the average frame time after a few seconds and quits.

const BENCH_WARMUP := 60
const BENCH_FRAMES := 300

var _label: Label
var _frames := 0
var _bench_usec := 0
var _last_usec := 0
var _bench := false


func _ready() -> void:
	layer = 100
	_bench = "--bench" in OS.get_cmdline_user_args()
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.visible = false
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_label.visible = not _label.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _label.visible:
		_label.text = "%d fps  ·  %.1f ms\n%d draw calls  ·  %dk triangles" % [
			Engine.get_frames_per_second(),
			1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
			_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		]
	if _bench:
		_bench_step()


func _bench_step() -> void:
	_frames += 1
	var now := Time.get_ticks_usec()
	if _frames > BENCH_WARMUP:
		_bench_usec += now - _last_usec
	_last_usec = now
	if _frames == BENCH_WARMUP + BENCH_FRAMES:
		print("BENCH avg %.2f ms  draw calls %d  triangles %d  startup %d ms" % [
			_bench_usec / 1000.0 / BENCH_FRAMES,
			_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			Engine.get_meta("startup_ms", -1),
		])
		get_tree().quit()


func _info(kind: RenderingServer.RenderingInfo) -> int:
	return RenderingServer.get_rendering_info(kind)
