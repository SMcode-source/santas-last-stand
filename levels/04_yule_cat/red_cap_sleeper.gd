class_name RedCapSleeper
extends Node3D
## A Red Cap asleep on his bunk in the barracks (an ElfFigure dressed as a
## Red Cap until they come from Meshy), cap still on. Footsteps close by
## make him stir; too close for too long and he sits up with a shout, then
## mutters and goes back to sleep. Sneak up and his cap can be lifted.

signal woke(sleeper: RedCapSleeper)

## How near footsteps disturb him, and how fast (walking; running is worse).
const NEAR := 3.5
const STIR_RATE := 0.45
const RUN_FACTOR := 2.5
const SETTLE := 0.25
const AWAKE_TIME := 2.5

var stir := 0.0
var cap_taken := false
var awake := 0.0

var _figure: ElfFigure
var _time := 0.0
var _zs: Label3D


func _init() -> void:
	name = "RedCap"
	_figure = ElfFigure.red_cap()
	# Lying on his back along the bunk, head to the open front (west).
	_figure.rotation = Vector3(-PI / 2.0, PI / 2.0, 0.0)
	_figure.position = Vector3(0.55, 0.18, 0.0)
	add_child(_figure)
	_zs = Label3D.new()
	_zs.text = "z z"
	_zs.font_size = 48
	_zs.pixel_size = 0.005
	_zs.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zs.outline_size = 6
	_zs.modulate = Color(0.9, 0.95, 1.0)
	add_child(_zs)


func restore(taken: bool) -> void:
	cap_taken = taken
	_figure.cap.visible = not taken


## Footsteps `distance` away this frame. Returns true when he wakes.
func disturb(delta: float, distance: float, running: bool, sneaking: bool) -> bool:
	if awake > 0.0:
		return false
	if distance < NEAR and not sneaking:
		stir += STIR_RATE * delta * (RUN_FACTOR if running else 1.0) * (1.0 + (NEAR - distance) / NEAR)
	else:
		stir = maxf(0.0, stir - SETTLE * delta)
	if stir >= 1.0:
		awake = AWAKE_TIME
		stir = 0.4
		var sit := create_tween()
		sit.tween_property(_figure, "rotation:x", -0.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		woke.emit(self)
		return true
	return false


## Lifts his cap. False if he's awake or it's gone.
func take_cap() -> bool:
	if cap_taken or awake > 0.0:
		return false
	cap_taken = true
	_figure.cap.visible = false
	stir = minf(0.9, stir + 0.25)
	return true


func _process(delta: float) -> void:
	_time += delta
	if awake > 0.0:
		awake -= delta
		_zs.visible = false
		if awake <= 0.0:
			var lie := create_tween()
			lie.tween_property(_figure, "rotation:x", -PI / 2.0, 0.6)
		return
	_zs.visible = true
	var rise := fmod(_time * 0.5 + position.z * 0.13, 1.0)
	_zs.position = Vector3(-0.3, 0.55 + rise * 0.5, 0.1)
	_zs.modulate.a = 1.0 - rise
	# Breathing, and twitching as he stirs.
	_figure.body.scale = Vector3(1.0 + sin(_time * 1.6) * 0.03, 1.0, 1.0 + sin(_time * 1.6) * 0.03)
	_figure.position.z = sin(_time * 31.0) * 0.015 * stir
