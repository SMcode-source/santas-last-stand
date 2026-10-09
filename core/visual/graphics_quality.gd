class_name GraphicsQuality
extends Node
## Picks a graphics level for the machine, then steps it down automatically if
## the frame rate struggles. Run with `-- --quality=low|medium|high` to force one.

enum Level { LOW, MEDIUM, HIGH }

## Tallest 3D render (in pixels) per level. Browsers on high-DPI laptops can
## ask for 2-3x more pixels than this; the 3D is upscaled, the HUD stays sharp.
const MAX_RENDER_HEIGHT := {Level.LOW: 540, Level.MEDIUM: 720, Level.HIGH: 1080}

## Average frame time (ms) above which we drop a level: about 45 fps.
const SLOW_FRAME_MS := 22.0
const SAMPLE_SECONDS := 2.0

var level := Level.HIGH
var _environment: Environment
var _sun: DirectionalLight3D
var _auto := true
var _settle := 2.0
var _elapsed := 0.0
var _frames := 0


func _init(environment: Environment, sun: DirectionalLight3D) -> void:
	name = "GraphicsQuality"
	_environment = environment
	_sun = sun
	level = Level.MEDIUM if OS.has_feature("web") else Level.HIGH
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			level = Level.get(arg.get_slice("=", 1).to_upper(), level)
			_auto = false


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_resolution)
	apply()


func apply() -> void:
	_environment.ssao_enabled = level == Level.HIGH
	_environment.glow_enabled = level != Level.LOW
	_sun.shadow_enabled = level != Level.LOW
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_DISABLED if level == Level.LOW else Viewport.MSAA_2X
	_fit_resolution()
	Engine.set_meta("graphics_quality", Level.keys()[level].capitalize())


func _fit_resolution() -> void:
	# The window's real pixel height, not the stretched canvas size.
	var height := float(get_window().size.y)
	get_viewport().scaling_3d_scale = clampf(MAX_RENDER_HEIGHT[level] / maxf(height, 1.0), 0.25, 1.0)


func _process(delta: float) -> void:
	if not _auto or level == Level.LOW:
		return
	_settle -= delta
	if _settle > 0.0:
		return
	_elapsed += delta
	_frames += 1
	if _elapsed < SAMPLE_SECONDS:
		return
	if _elapsed / _frames * 1000.0 > SLOW_FRAME_MS:
		level = (level - 1) as Level
		apply()
		_settle = 1.0
	_elapsed = 0.0
	_frames = 0
