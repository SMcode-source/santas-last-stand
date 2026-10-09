class_name GraphicsQuality
extends Node
## Picks a graphics level for the machine, then steps it down automatically if
## the frame rate struggles. The Graphics setting can fix a level instead, and
## `-- --quality=low|medium|high` on the command line overrides both.

enum Level { LOW, MEDIUM, HIGH }

## Tallest 3D render (in pixels) per level. Browsers on high-DPI laptops can
## ask for 2-3x more pixels than this; the 3D is upscaled, the HUD stays sharp.
## Low saves its time elsewhere: below 720 the logs and roof edges turn into
## visible stair-steps once stretched to the screen.
const MAX_RENDER_HEIGHT := {Level.LOW: 720, Level.MEDIUM: 810, Level.HIGH: 1080}
## Last resort when even Low runs under about 30 fps.
const SQUEEZED_RENDER_HEIGHT := 576
const VERY_SLOW_FRAME_MS := 33.0

## Nodes in this group cast shadows only at the High level.
const SHADOWS_ON_HIGH := "shadows_on_high"
## Decorative lights switched off at Low. The Compatibility renderer draws
## everything an omni light touches once more, so each one is costly.
const LIGHTS_ABOVE_LOW := "lights_above_low"
## Extra set dressing (saplings and the like) hidden at Low.
const DETAIL_ABOVE_LOW := "detail_above_low"
## Nodes in this group get apply_quality(level) whenever the level changes.
const LISTENERS := "graphics_quality_listeners"

## Glow blur passes in use per level (Godot's defaults are levels 3 and 5).
const GLOW_LEVELS := {
	Level.LOW: [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0],
	Level.MEDIUM: [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0],
	Level.HIGH: [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0],
}
## Average frame time (ms) above which we drop a level: about 45 fps.
const SLOW_FRAME_MS := 22.0
const SAMPLE_SECONDS := 2.0

var level := Level.HIGH
var _environment: Environment
var _sun: DirectionalLight3D
var _auto := true
var _squeezed := false
var _settle := 2.0
var _elapsed := 0.0
var _frames := 0


func _init(environment: Environment, sun: DirectionalLight3D) -> void:
	name = "GraphicsQuality"
	_environment = environment
	_sun = sun
	_read_setting()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			level = Level.get(arg.get_slice("=", 1).to_upper(), level)
			_auto = false


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_resolution)
	GameState.settings_changed.connect(func() -> void:
		if not _forced_on_command_line():
			_read_setting()
			apply())
	# Deferred so the scene's shadow-casting forest exists by then.
	apply.call_deferred()


func _read_setting() -> void:
	_squeezed = false
	var chosen: String = GameState.setting("quality")
	_auto = chosen == "auto"
	if _auto:
		level = Level.MEDIUM if OS.has_feature("web") else Level.HIGH
	else:
		level = Level.get(chosen.to_upper(), Level.MEDIUM)


func _forced_on_command_line() -> bool:
	return Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--quality="))


func apply() -> void:
	_environment.ssao_enabled = level == Level.HIGH
	# Glow stays on at every level: without it the windows and fairy lights look
	# painted on, and it is cheap next to shadows.
	_environment.glow_enabled = true
	# Low blurs the glow over fewer passes and skips the costlier texture work
	# in the snow, rock and log shaders.
	for i in 7:
		_environment.set_glow_level(i, GLOW_LEVELS[level][i])
	RenderingServer.global_shader_parameter_set("lite_shading", level == Level.LOW)
	_sun.shadow_enabled = level != Level.LOW
	for node in get_tree().get_nodes_in_group(LIGHTS_ABOVE_LOW):
		(node as Light3D).visible = level != Level.LOW
	for node in get_tree().get_nodes_in_group(DETAIL_ABOVE_LOW):
		(node as Node3D).visible = level != Level.LOW
	# Real shadows from the background forest only on High; lower levels rely
	# on the shading painted into the foliage shader.
	var casting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level == Level.HIGH \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in get_tree().get_nodes_in_group(SHADOWS_ON_HIGH):
		(node as GeometryInstance3D).cast_shadow = casting
	# Medium covers just the camp with one shadow map instead of two.
	_sun.directional_shadow_max_distance = 32.0 if level == Level.HIGH else 14.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if level == Level.HIGH 			else DirectionalLight3D.SHADOW_ORTHOGONAL
	var viewport := get_viewport()
	# MSAA is the only anti-aliasing the Compatibility renderer has (no FXAA);
	# Low goes without it to save its cost (about 2 ms on a laptop GPU).
	viewport.msaa_3d = Viewport.MSAA_DISABLED if level == Level.LOW else Viewport.MSAA_2X
	_fit_resolution()
	Engine.set_meta("graphics_quality", Level.keys()[level].capitalize())
	Engine.set_meta("graphics_level", level)
	get_tree().call_group(LISTENERS, "apply_quality", level)


func _fit_resolution() -> void:
	# The window's real pixel height, not the stretched canvas size.
	var height := float(get_window().size.y)
	var target: float = SQUEEZED_RENDER_HEIGHT if _squeezed else MAX_RENDER_HEIGHT[level]
	get_viewport().scaling_3d_scale = clampf(target / maxf(height, 1.0), 0.25, 1.0)


func _process(delta: float) -> void:
	if not _auto or _squeezed:
		return
	_settle -= delta
	if _settle > 0.0:
		return
	_elapsed += delta
	_frames += 1
	if _elapsed < SAMPLE_SECONDS:
		return
	var frame_ms := _elapsed / _frames * 1000.0
	if level > Level.LOW and frame_ms > SLOW_FRAME_MS:
		level = (level - 1) as Level
		apply()
		_settle = 1.0
	elif level == Level.LOW and frame_ms > VERY_SLOW_FRAME_MS:
		_squeezed = true
		_fit_resolution()
	_elapsed = 0.0
	_frames = 0
