class_name DebugOverlay
extends CanvasLayer
## F3 toggles a small readout: FPS, frame time, draw calls and triangles, plus
## the chapter's play time and failures per section while a chapter is running.
## Running with `-- --bench` prints the average frame time after a few seconds and quits.
## Add `--hide=Name1,Name2` to hide matching nodes (or `--hide=lights`) and see what they cost,
## and `--off=glow,fog,msaa,sky,tonemap` to switch off whole-screen effects.

const BENCH_WARMUP := 60
const BENCH_FRAMES := 300

var _label: Label
var _frames := 0
var _bench_usec := 0
var _last_usec := 0
var _bench := false
var _cpu_ms := 0.0
var _gpu_ms := 0.0
var _script_ms := 0.0
var _process_start := 0


func _ready() -> void:
	layer = 100
	_bench = "--bench" in OS.get_cmdline_user_args()
	if _bench:
		# Measure the real cost of a frame, not the wait for the screen refresh.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("refresh rate %.0f Hz" % DisplayServer.screen_get_refresh_rate())
		# Times every script's _process this frame: a helper runs first, this last.
		process_priority = 1000000
		var first := Node.new()
		first.process_priority = -1000000
		first.set_script(_FirstMarker)
		first.set_meta("overlay", self)
		add_child(first)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hide="):
			_hide.call_deferred(arg.get_slice("=", 1).split(","))
		if arg.begins_with("--still="):
			_still.call_deferred(arg.get_slice("=", 1).split(","))
		if arg.begins_with("--off="):
			_switch_off.call_deferred(arg.get_slice("=", 1).split(","))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
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
		_label.text = "%d fps  ·  %.1f ms  ·  %s quality\n%d draw calls  ·  %dk triangles" % [
			Engine.get_frames_per_second(),
			1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
			Engine.get_meta("graphics_quality", "?"),
			_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		]
		var level := get_tree().current_scene as LevelBase
		if level:
			_label.text += "
" + level.debug_text()
	if _bench:
		_bench_step()


func _bench_step() -> void:
	_frames += 1
	var now := Time.get_ticks_usec()
	if _frames > BENCH_WARMUP:
		_bench_usec += now - _last_usec
		var rid := get_viewport().get_viewport_rid()
		_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_script_ms += (now - _process_start) / 1000.0
	_last_usec = now
	if _frames == BENCH_WARMUP + BENCH_FRAMES:
		print("BENCH avg %.2f ms (scripts %.2f, render cpu %.2f, gpu %.2f)  draw calls %d  triangles %d  startup %d ms" % [
			_bench_usec / 1000.0 / BENCH_FRAMES,
			_script_ms / BENCH_FRAMES,
			_cpu_ms / BENCH_FRAMES,
			_gpu_ms / BENCH_FRAMES,
			_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			Engine.get_meta("startup_ms", -1),
		])
		get_tree().quit()


func _hide(names: PackedStringArray) -> void:
	for node in get_tree().current_scene.find_children("*", "", true, false):
		for n in names:
			var match_lights: bool = n == "lights" and node is OmniLight3D
			if (match_lights or node.name.contains(n)) and "visible" in node:
				node.visible = false


## Stops matching nodes' _process, to see what their scripts cost.
func _still(names: PackedStringArray) -> void:
	for node in get_tree().current_scene.find_children("*", "", true, false):
		for n in names:
			if node.name.contains(n) or (node.get_script() and (node.get_script() as Script).resource_path.contains(n)):
				node.set_process(false)
				node.set_physics_process(false)


func _switch_off(effects: PackedStringArray) -> void:
	# Wait for GraphicsQuality to have applied its settings first.
	await get_tree().process_frame
	await get_tree().process_frame
	var env := get_viewport().find_world_3d().environment
	for node in get_tree().current_scene.find_children("*", "WorldEnvironment", true, false):
		env = (node as WorldEnvironment).environment
	for effect in effects:
		match effect:
			"glow": env.glow_enabled = false
			"fog": env.fog_enabled = false
			"msaa": get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			"sky": env.background_mode = Environment.BG_COLOR
			"tonemap": env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			"reflect": env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			"shadow":
				for light in get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false):
					(light as Light3D).shadow_enabled = false
			"fxaa":
				get_viewport().msaa_3d = Viewport.MSAA_DISABLED
				get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			"glowlite":
				for i in 7:
					env.set_glow_level(i, 0.0)
				env.set_glow_level(2, 1.0)
				env.set_glow_level(4, 1.0)


class _FirstMarker extends Node:
	func _process(_delta: float) -> void:
		get_meta("overlay")._process_start = Time.get_ticks_usec()


func _info(kind: RenderingServer.RenderingInfo) -> int:
	return RenderingServer.get_rendering_info(kind)
