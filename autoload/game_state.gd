extends Node
## Holds the save data for the whole game and writes it to the browser's
## storage (user:// maps to IndexedDB on the web).

signal settings_changed

## `-- --save=user://other.json` on the command line uses another save file,
## so automated runs never touch the player's progress.
var save_path := "user://save.json"
var data := SaveData.new()
var has_save := false
## The chapter being played right now, or "".
var current_level := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.get_slice("=", 1)
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		data = SaveData.from_dict(parsed)
		has_save = not data.completed.is_empty() or not data.checkpoint.is_empty()


func save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the game: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()


## Starts a fresh story, keeping the player's settings.
func new_game(cocoa_mode: bool) -> void:
	var settings := data.settings
	data = SaveData.new()
	data.settings = settings
	data.cocoa_mode = cocoa_mode
	has_save = false
	save_game()


func setting(key: String) -> Variant:
	return data.settings.get(key, SaveData.DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	save_game()
	settings_changed.emit()


func set_cocoa_mode(on: bool) -> void:
	data.cocoa_mode = on
	save_game()
	settings_changed.emit()


func complete_level(level_id: String, time: float, found := {}) -> void:
	data.record_completion(level_id, time, found)
	has_save = true
	save_game()


func set_checkpoint(level_id: String, checkpoint_id: String) -> void:
	data.checkpoint = {"level": level_id, "id": checkpoint_id}
	has_save = true
	save_game()


## The checkpoint to start `level_id` from, or "" to start at the beginning.
func checkpoint_for(level_id: String) -> String:
	return data.checkpoint.get("id", "") if data.checkpoint.get("level", "") == level_id else ""
