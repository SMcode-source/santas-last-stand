class_name SaveData
extends RefCounted
## Everything that survives between visits: progress, Santa's tone, Cocoa Mode,
## collectibles, play-time stats and settings. Plain data with no engine
## dependencies, so it can be unit-tested and stored as JSON.

const VERSION := 1
const TONES: Array[String] = ["jolly", "stern", "sardonic"]
const DEFAULT_SETTINGS := {
	"music": 0.8,
	"sfx": 0.9,
	"voice": 0.8,
	"text_speed": "normal",
	"quality": "auto",
	"hints": true,
	"fullscreen": false,
}

## level id -> {"best_time": float, "coins": int, "letters": int, "brick": bool}
var completed := {}
## How often the player picked each tone for Santa in dialogue.
var tone := {"jolly": 0, "stern": 0, "sardonic": 0}
var cocoa_mode := false
## The checkpoint to resume from: {"level": id, "id": checkpoint id}, or empty.
var checkpoint := {}
## level id -> {"play_time": float, "fails": {section: count}}
var stats := {}
var settings := DEFAULT_SETTINGS.duplicate()


func add_tone(which: String, amount := 1) -> void:
	if tone.has(which):
		tone[which] += amount


## The tone picked most often, with ties going to the earlier one in TONES.
func dominant_tone() -> String:
	var best := TONES[0]
	for t in TONES:
		if tone[t] > tone[best]:
			best = t
	return best


func is_completed(level_id: String) -> bool:
	return completed.has(level_id)


## Records a finished level, keeping the best time and the most collectibles found.
func record_completion(level_id: String, time: float, found := {}) -> void:
	var old: Dictionary = completed.get(level_id, {})
	completed[level_id] = {
		"best_time": minf(time, old.get("best_time", INF)),
		"coins": maxi(found.get("coins", 0), old.get("coins", 0)),
		"letters": maxi(found.get("letters", 0), old.get("letters", 0)),
		"brick": found.get("brick", false) or old.get("brick", false),
	}
	if checkpoint.get("level", "") == level_id:
		checkpoint = {}


func add_play_time(level_id: String, seconds: float) -> void:
	var s := _stats_for(level_id)
	s["play_time"] += seconds


func add_fail(level_id: String, section: String) -> int:
	var fails: Dictionary = _stats_for(level_id)["fails"]
	fails[section] = fails.get(section, 0) + 1
	return fails[section]


func _stats_for(level_id: String) -> Dictionary:
	if not stats.has(level_id):
		stats[level_id] = {"play_time": 0.0, "fails": {}}
	return stats[level_id]


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"completed": completed,
		"tone": tone,
		"cocoa_mode": cocoa_mode,
		"checkpoint": checkpoint,
		"stats": stats,
		"settings": settings,
	}


## Builds save data from a stored dictionary. Missing or malformed fields fall
## back to defaults, so older or damaged saves still load.
static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	if d.get("completed") is Dictionary:
		s.completed = d["completed"]
	if d.get("tone") is Dictionary:
		for t in TONES:
			s.tone[t] = int(d["tone"].get(t, 0))
	s.cocoa_mode = bool(d.get("cocoa_mode", false))
	if d.get("checkpoint") is Dictionary:
		s.checkpoint = d["checkpoint"]
	if d.get("stats") is Dictionary:
		s.stats = d["stats"]
	if d.get("settings") is Dictionary:
		for key in DEFAULT_SETTINGS:
			if d["settings"].has(key) and typeof(d["settings"][key]) == typeof(DEFAULT_SETTINGS[key]):
				s.settings[key] = d["settings"][key]
	return s
