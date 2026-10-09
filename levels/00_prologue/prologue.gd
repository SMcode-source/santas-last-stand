extends LevelBase
## Prologue, "The Summons" (1 December): a dialogue chapter. A night at the
## North Pole, a gold phone that shouldn't exist, then the Oval Office. The
## player's answers set Santa's tone for the rest of the story.

const BACKDROP := preload("res://hello/hello_santa.tscn")
const OFFICE_AT := Vector3(200, 0, 0)

var _camp: Node3D
var _office: OvalOffice
var _camera: Camera3D
var _office_santa: SantaModel
var _black: ColorRect
var _drift: Tween


func _ready() -> void:
	super._ready()
	_camp = BACKDROP.instantiate()
	_camp.show_ui = false
	_camp.orbit_camera = false
	_camp.santa_routine = false
	add_child(_camp)
	_camp.santa.visible = false
	_camera = _camp.camera

	_office = OvalOffice.new()
	_office.position = OFFICE_AT
	add_child(_office)
	_office_santa = SantaModel.new()
	_office_santa.position = OFFICE_AT + _office.santa_spot
	_office_santa.rotation.y = PI
	add_child(_office_santa)

	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)

	Dialogue.cue.connect(_on_cue)
	_run.call_deferred()


func _run() -> void:
	_on_cue("workshop")
	await get_tree().create_timer(0.4).timeout
	await Dialogue.play(Dialogue.lines("prologue", "summons"))
	complete()


func _on_cue(cue: String) -> void:
	match cue:
		"workshop":
			# Outside the cabin at 3 a.m., drifting slowly towards the lit window.
			_cut(func() -> void:
				_camera.position = Vector3(-0.6, 1.5, 1.0)
				_camera.look_at(Vector3(-3.6, 1.3, -5.0))
				_drift_to(Vector3(-2.0, 1.45, -1.6), Vector3(-3.8, 1.3, -5.0), 40.0))
		"office":
			_cut(func() -> void:
				_camera.global_transform = _office.global_transform * _office.camera_spot
				var target := OFFICE_AT + Vector3(0, 1.35, 0.1)
				_drift_to(_camera.position + Vector3(0.12, -0.04, 0.35), target, 30.0))


## Dips to black, changes the shot, and fades back in.
func _cut(change: Callable) -> void:
	var t := create_tween()
	t.tween_property(_black, "color:a", 1.0, 0.35 if _black.color.a < 1.0 else 0.0)
	t.tween_callback(change)
	t.tween_property(_black, "color:a", 0.0, 0.8)


func _drift_to(pos: Vector3, look: Vector3, seconds: float) -> void:
	if _drift:
		_drift.kill()
	var start := _camera.position
	_drift = create_tween()
	_drift.tween_method(func(f: float) -> void:
		_camera.position = start.lerp(pos, f)
		_camera.look_at(look), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
