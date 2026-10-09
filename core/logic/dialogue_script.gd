class_name DialogueScript
extends RefCounted
## Steps through one conversation from the dialogue data. Pure logic, so the
## UI only has to show whatever `current()` returns.
##
## A conversation is a list of steps:
##   {"who": "holly", "text": "..."}                      a spoken line
##   {"caption": "North Pole, 3:00 a.m."}                  a scene caption
##   {"cue": "office"}                                     a stage cue for the scene
##   {"choice": [{"text": "...", "tone": "jolly", "then": [steps]}, ...]}
##   {"by_tone": {"jolly": step, "stern": step, "sardonic": step}}
##                                                        a line that depends on Santa's tone

## Called with the tone of each choice the player makes.
signal tone_chosen(tone: String)

var _stack: Array[Array] = []
var _positions: Array[int] = []
var _tone_source: Callable


## `tone_source` returns Santa's current dominant tone, for "by_tone" steps.
func _init(steps: Array, tone_source := Callable()) -> void:
	_tone_source = tone_source
	_stack.append(steps)
	_positions.append(0)
	_settle()


func is_finished() -> bool:
	return _stack.is_empty()


## The step to show now: a line, a caption or a choice. Empty when finished.
func current() -> Dictionary:
	if _stack.is_empty():
		return {}
	return _stack[-1][_positions[-1]]


## Moves past a line or caption.
func advance() -> void:
	if _stack.is_empty() or current().has("choice"):
		return
	_positions[-1] += 1
	_settle()


## Picks option `index` of the current choice and continues into its lines.
func choose(index: int) -> void:
	var step := current()
	if not step.has("choice"):
		return
	var option: Dictionary = step["choice"][index]
	if option.has("tone"):
		tone_chosen.emit(option["tone"])
	_positions[-1] += 1
	var then: Array = option.get("then", [])
	if not then.is_empty():
		_stack.append(then)
		_positions.append(0)
	_settle()


## Skips straight to the end (cutscenes are always skippable). Choices still
## count: each skipped choice takes its first option.
func skip_to_end() -> void:
	while not is_finished():
		if current().has("choice"):
			choose(0)
		else:
			advance()


## Pops finished lists and resolves tone-dependent steps, so current() is
## always something displayable.
func _settle() -> void:
	while not _stack.is_empty():
		if _positions[-1] >= _stack[-1].size():
			_stack.pop_back()
			_positions.pop_back()
			continue
		var step: Dictionary = _stack[-1][_positions[-1]]
		if step.has("by_tone"):
			var tone: String = _tone_source.call() if _tone_source.is_valid() else "jolly"
			var options: Dictionary = step["by_tone"]
			_stack[-1] = _stack[-1].duplicate()
			_stack[-1][_positions[-1]] = options.get(tone, options.values()[0])
			continue
		return
