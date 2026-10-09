extends Node
## Runs conversations from data/dialogue/*.json through the dialogue box:
## cutscenes, in-game lines, phone calls and Sleigh Talks.
##   await Dialogue.play(Dialogue.lines("prologue", "summons"))

signal finished
## A stage cue from the conversation, e.g. {"cue": "office"} to cut to another set.
signal cue(name: String)

const CHARACTERS := "res://data/characters.json"

var characters := {}
var _files := {}
var _box: DialogueBox


func _ready() -> void:
	characters = LevelCatalog.load_json(CHARACTERS)


## The steps of conversation `key` in data/dialogue/<file>.json.
func lines(file: String, key: String) -> Array:
	if not _files.has(file):
		_files[file] = LevelCatalog.load_json("res://data/dialogue/%s.json" % file)
	var conversations: Dictionary = _files[file] if _files[file] is Dictionary else {}
	if not conversations.has(key):
		push_error("No conversation '%s' in %s.json" % [key, file])
		return []
	return conversations[key]


func character(id: String) -> Dictionary:
	return characters.get(id, {"name": id.capitalize(), "color": "#cccccc", "pitch": 1.0})


func is_playing() -> bool:
	return is_instance_valid(_box)


## Shows a conversation and returns when it ends. `mode` is "scene" (the player
## clicks through), "phone" (the same, styled as a call) or "bark" (lines play
## by themselves during gameplay).
func play(steps: Array, mode := "scene") -> void:
	if is_playing():
		_box.queue_free()
	var script := DialogueScript.new(steps, GameState.data.dominant_tone)
	script.tone_chosen.connect(func(tone: String) -> void:
		GameState.data.add_tone(tone)
		GameState.save_game())
	_box = DialogueBox.new(script, mode)
	get_tree().current_scene.add_child(_box)
	await _box.done
	_box = null
	finished.emit()


func skip() -> void:
	if is_playing():
		_box.skip()
