extends Node
## Music, sound effects and voice blips. Every sound is synthesised at startup
## (bells, blips, the phone ring), so there are no audio files to download yet.
## Browsers only start audio after the first click, which the title screen asks for.

const RATE := 22050
## Characters' voice blips: a short syllable per few letters, pitched per character.
const BLIP_EVERY := 3

## Jingle Bells (public domain), chorus: [semitones above C5, beats].
const JINGLE_BELLS := [
	[4, 1], [4, 1], [4, 2], [4, 1], [4, 1], [4, 2], [4, 1], [7, 1], [0, 1.5], [2, 0.5], [4, 4],
	[5, 1], [5, 1], [5, 1.5], [5, 0.5], [5, 1], [4, 1], [4, 1], [4, 0.5], [4, 0.5],
	[4, 1], [2, 1], [2, 1], [4, 1], [2, 2], [7, 2],
	[4, 1], [4, 1], [4, 2], [4, 1], [4, 1], [4, 2], [4, 1], [7, 1], [0, 1.5], [2, 0.5], [4, 4],
	[5, 1], [5, 1], [5, 1.5], [5, 0.5], [5, 1], [4, 1], [4, 1], [4, 0.5], [4, 0.5],
	[7, 1], [7, 1], [5, 1], [2, 1], [0, 4],
]

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _tune: Array = []
var _tune_index := 0
var _tune_clock := 0.0
var _beat := 0.5
var _tune_loop := false
var _tune_volume := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_sounds["bell"] = _bell()
	_sounds["blip"] = _blip()
	_sounds["click"] = _click()
	_sounds["ring"] = _ring()
	GameState.settings_changed.connect(_apply_volumes)
	_apply_volumes()


func play_sfx(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	_play(sound, "SFX", pitch, volume_db)


func stop_sfx(sound: String) -> void:
	for p in _players:
		if p.stream == _sounds[sound]:
			p.stop()


## One syllable of a character's voice.
func blip(pitch: float) -> void:
	_play("blip", "Voice", pitch * randf_range(0.94, 1.06), -6.0)


## A short rising bell arpeggio for a finished level, falling for a failure.
func fanfare(success: bool) -> void:
	var notes := [0, 4, 7, 12] if success else [7, 3, 0, -5]
	for i in notes.size():
		get_tree().create_timer(i * 0.14, true).timeout.connect(
				_play.bind("bell", "SFX", pow(2.0, notes[i] / 12.0), -2.0))


## Plays a tune on music-box bells in the Music bus.
func play_music_box(notes := JINGLE_BELLS, beat_seconds := 0.32, loop := true) -> void:
	_tune = notes
	_tune_index = 0
	_tune_clock = 0.4
	_beat = beat_seconds
	_tune_loop = loop
	_tune_volume = 1.0


func is_music_playing() -> bool:
	return not _tune.is_empty()


func stop_music(fade := 1.0) -> void:
	if _tune.is_empty():
		return
	var t := create_tween()
	t.tween_property(self, "_tune_volume", 0.0, fade)
	t.tween_callback(func() -> void: _tune = [])


func _process(delta: float) -> void:
	if _tune.is_empty():
		return
	_tune_clock -= delta
	while _tune_clock <= 0.0 and not _tune.is_empty():
		var note: Array = _tune[_tune_index]
		_play("bell", "Music", pow(2.0, note[0] / 12.0), linear_to_db(_tune_volume) - 4.0)
		_tune_clock += note[1] * _beat
		_tune_index += 1
		if _tune_index >= _tune.size():
			if _tune_loop:
				_tune_index = 0
				_tune_clock += _beat * 4.0
			else:
				_tune = []


func _play(sound: String, bus: String, pitch: float, volume_db: float) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sounds[sound]
	p.bus = bus
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _apply_volumes() -> void:
	for pair in [["Music", "music"], ["SFX", "sfx"], ["Voice", "voice"]]:
		var v: float = GameState.setting(pair[1])
		var bus := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(bus, v <= 0.001)


# --- Synthesis ---------------------------------------------------------------------

## A music-box bell at C5: a few inharmonic partials with a quick decay.
func _bell() -> AudioStreamWAV:
	var f := 523.25
	return _synth(1.6, func(t: float) -> float:
		var env := exp(-t * 3.2) * minf(t * 400.0, 1.0)
		return env * (0.6 * sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) * exp(-t * 4.0)
				+ 0.12 * sin(TAU * f * 3.01 * t) * exp(-t * 7.0)))


## A soft voice syllable: a rounded square wave with a quick swell and fade.
func _blip() -> AudioStreamWAV:
	var f := 330.0
	return _synth(0.07, func(t: float) -> float:
		var env := sin(PI * t / 0.07)
		var s := sin(TAU * f * t)
		return env * 0.35 * (s + 0.3 * sin(TAU * f * 3.0 * t) / 3.0))


func _click() -> AudioStreamWAV:
	return _synth(0.04, func(t: float) -> float:
		return exp(-t * 120.0) * 0.5 * sin(TAU * 1500.0 * t))


## An old phone's double ring: two close tones trilling, twice, then a pause.
func _ring() -> AudioStreamWAV:
	var wave := func(t: float) -> float:
		var on := fmod(t, 0.6) < 0.4 and t < 1.0
		if not on:
			return 0.0
		var trill := 0.5 + 0.5 * signf(sin(TAU * 20.0 * t))
		return 0.22 * trill * (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t))
	return _synth(2.6, wave, true)


func _synth(seconds: float, wave: Callable, loop := false) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		bytes.encode_s16(i * 2, int(clampf(wave.call(i / float(RATE)), -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = count
	return wav
