class_name LevelBase
extends Node
## The shared shape of every chapter: intro, play with checkpoints, finale,
## then the level-complete screen with the President's call and the stinger.
## A chapter script extends this and calls reach_checkpoint(), fail() and
## complete(); pausing, retries, hints and stats are handled here.

## The chapter's id in data/levels.json. Set from the router when it starts.
var level_id := ""
## The checkpoint this attempt started from ("" for the beginning).
var start_checkpoint := ""
## The part of the chapter being played, for counting failures and hints.
var section := "start"
var found := {"coins": 0, "letters": 0, "brick": false}
var play_time := 0.0
var ended := false
var pause_menu: PauseMenu


func _enter_tree() -> void:
	level_id = Router.payload.get("level", level_id)
	start_checkpoint = Router.payload.get("checkpoint", "")
	if not start_checkpoint.is_empty():
		section = start_checkpoint


func _ready() -> void:
	pause_menu = PauseMenu.new()
	add_child(pause_menu)


func _process(delta: float) -> void:
	if not ended:
		play_time += delta


func level_data() -> Dictionary:
	return LevelCatalog.get_level(level_id)


func cocoa_mode() -> bool:
	return GameState.data.cocoa_mode


## A tunable number, made gentler in Cocoa Mode ("health", "timer", ...).
func tuned(value: float, kind: String) -> float:
	return Balance.scaled(value, kind, cocoa_mode())


func reach_checkpoint(checkpoint_id: String) -> void:
	section = checkpoint_id
	GameState.set_checkpoint(level_id, checkpoint_id)
	Toast.show_on(self, "Checkpoint reached")


func collect(kind: String) -> void:
	if kind == "brick":
		found["brick"] = true
	else:
		found[kind] = found.get(kind, 0) + 1


## The player lost: show the fail screen, offering Pepper's hint after
## several failures on the same section.
func fail(reason: String) -> void:
	if ended:
		return
	ended = true
	pause_menu.enabled = false
	GameState.data.add_play_time(level_id, play_time)
	var fails := GameState.data.add_fail(level_id, section)
	GameState.save_game()
	Audio.fanfare(false)
	var hint := ""
	if Balance.should_offer_hint(fails, GameState.setting("hints")):
		hint = hint_for(section)
	add_child(FailScreen.new(reason, hint))


## The player finished the chapter.
func complete() -> void:
	if ended:
		return
	ended = true
	pause_menu.enabled = false
	GameState.data.add_play_time(level_id, play_time)
	GameState.complete_level(level_id, play_time, found)
	Audio.fanfare(true)
	add_child(LevelComplete.new(level_id, play_time, found))


## Pepper's hint for a section, from the "hints" in data/levels.json.
func hint_for(part: String) -> String:
	return level_data().get("hints", {}).get(part, "")


func debug_text() -> String:
	var stats: Dictionary = GameState.data.stats.get(level_id, {})
	return "%s  ·  section %s  ·  %s this attempt  ·  fails %s" % [
		level_id, section, LevelComplete.clock(play_time), stats.get("fails", {})]
