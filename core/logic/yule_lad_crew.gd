class_name YuleLadCrew
extends RefCounted
## The thirteen Yule Lads of Level 4 and the treasures Grýla took from them
## "for the gold-man's security". Santa finds a treasure and shows it to its
## owner: the Lad takes it back and stops watching for him. Once three have
## their treasures back, the whole crew mutinies and stops working for her.
## Door-Slammer can also be shut in his own house.

enum Mood {HOSTILE, FRIENDLY, SHUT_IN}

const MUTINY_AT := 3

const LADS := [
	{"id": "sheep_clod", "name": "Stekkjastaur", "english": "Sheep-Cote Clod"},
	{"id": "gully_gawk", "name": "Giljagaur", "english": "Gully Gawk"},
	{"id": "stubby", "name": "Stúfur", "english": "Stubby"},
	{"id": "spoon_licker", "name": "Þvörusleikir", "english": "Spoon-Licker"},
	{"id": "pot_scraper", "name": "Pottaskefill", "english": "Pot-Scraper"},
	{"id": "bowl_licker", "name": "Askasleikir", "english": "Bowl-Licker"},
	{"id": "door_slammer", "name": "Hurðaskellir", "english": "Door-Slammer"},
	{"id": "skyr_gobbler", "name": "Skyrgámur", "english": "Skyr-Gobbler"},
	{"id": "sausage_swiper", "name": "Bjúgnakrækir", "english": "Sausage-Swiper"},
	{"id": "window_peeper", "name": "Gluggagægir", "english": "Window-Peeper"},
	{"id": "doorway_sniffer", "name": "Gáttaþefur", "english": "Doorway-Sniffer"},
	{"id": "meat_hook", "name": "Ketkrókur", "english": "Meat-Hook"},
	{"id": "candle_stealer", "name": "Kertasníkir", "english": "Candle-Stealer"},
]

const TREASURES := {
	"spoon": {"name": "a wooden spoon", "owner": "spoon_licker"},
	"skyr": {"name": "a tub of skyr", "owner": "skyr_gobbler"},
	"candle": {"name": "a tallow candle", "owner": "candle_stealer"},
	"pot": {"name": "a sooty pot", "owner": "pot_scraper"},
	"bowl": {"name": "a wooden bowl", "owner": "bowl_licker"},
	"sausage": {"name": "a string of sausages", "owner": "sausage_swiper"},
}

## Lad id -> Mood.
var moods := {}
## Treasures picked up and not yet given back.
var carried: Array[String] = []
## Every treasure picked up so far (given back or not).
var found: Array[String] = []
var returned := 0
var mutiny := false


func _init() -> void:
	for spec: Dictionary in LADS:
		moods[spec["id"]] = Mood.HOSTILE


static func lad_spec(id: String) -> Dictionary:
	for spec: Dictionary in LADS:
		if spec["id"] == id:
			return spec
	return {}


static func treasure_of(lad_id: String) -> String:
	for treasure: String in TREASURES:
		if TREASURES[treasure]["owner"] == lad_id:
			return treasure
	return ""


func is_watching(lad_id: String) -> bool:
	return moods.get(lad_id, Mood.FRIENDLY) == Mood.HOSTILE


func pick_up(treasure: String) -> bool:
	if not TREASURES.has(treasure) or treasure in found:
		return false
	found.append(treasure)
	carried.append(treasure)
	return true


## Santa has this Lad's treasure with him.
func carries_for(lad_id: String) -> bool:
	var treasure := treasure_of(lad_id)
	return not treasure.is_empty() and treasure in carried


## Gives the Lad his treasure back. Returns it, or "" if Santa hasn't got it.
func give_back(lad_id: String) -> String:
	if not carries_for(lad_id) or moods.get(lad_id) == Mood.SHUT_IN:
		return ""
	var treasure := treasure_of(lad_id)
	carried.erase(treasure)
	moods[lad_id] = Mood.FRIENDLY
	returned += 1
	if returned >= MUTINY_AT and not mutiny:
		mutiny = true
		for id: String in moods:
			moods[id] = Mood.FRIENDLY
	return treasure


func shut_in(lad_id: String) -> bool:
	if moods.get(lad_id) != Mood.HOSTILE:
		return false
	moods[lad_id] = Mood.SHUT_IN
	return true


func to_dict() -> Dictionary:
	return {"moods": moods.duplicate(), "carried": Array(carried), "found": Array(found), "returned": returned, "mutiny": mutiny}


static func from_dict(d: Dictionary) -> YuleLadCrew:
	var crew := YuleLadCrew.new()
	var saved: Dictionary = d.get("moods", {})
	for id: String in saved:
		if crew.moods.has(id):
			crew.moods[id] = int(saved[id])
	for t in d.get("carried", []):
		crew.carried.append(str(t))
	for t in d.get("found", []):
		crew.found.append(str(t))
	crew.returned = int(d.get("returned", 0))
	crew.mutiny = bool(d.get("mutiny", false))
	return crew
