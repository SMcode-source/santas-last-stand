extends Node
## Plays Level 3 by itself, to check the whole flow end to end without
## anyone at the keyboard. Always pair it with a throwaway save file:
##   godot --headless --fixed-fps 60 --path . res://tools/l3_drive.tscn
##       -- --save=user://l3_drive.json --l3=day5
## --l3=<checkpoint> starts there. By default it follows Pepper's advice (and
## reads the letter); --bid bids for every mill instead (should go bankrupt),
## --idle just ends each day (should lose the vote).

var level: Node
var _plan := "advice"
var _last := ""
var _frame := 0


func _ready() -> void:
	var checkpoint := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l3="):
			checkpoint = arg.get_slice("=", 1)
		elif arg == "--bid":
			_plan = "bid"
		elif arg == "--idle":
			_plan = "idle"
	GameState.new_game(false)
	Router.payload = {"level": "l3", "checkpoint": checkpoint}
	level = load("res://levels/03_paper_monopoly/paper_monopoly.tscn").instantiate()
	add_child(level)


func _physics_process(_delta: float) -> void:
	_frame += 1
	var m: PaperMarket = level.market
	var status := "%s day %d coins %d actions %d towns %d votes %s" % [level.stage, m.day, m.coins, m.actions, m.towns_won(), m.votes()]
	if status != _last:
		print("[%5.1fs] %s" % [_frame / 60.0, status])
		_last = status
	if level.ended:
		var outcome := "COMPLETE" if level.find_children("*", "LevelComplete", true, false).size() > 0 else "FAILED"
		print("Ended: %s at %.1fs, letters %d" % [outcome, _frame / 60.0, level.found["letters"]])
		get_tree().quit()
		return
	if _frame > 60 * 60 * 10:
		print("Timed out in stage ", level.stage)
		get_tree().quit()
		return
	if Dialogue.is_playing():
		Dialogue.skip()
		return
	if level._busy or level.stage != "play" or _frame % 10 != 0:
		return
	match _plan:
		"idle":
			level._end_day()
		"bid":
			for i in m.towns.size():
				if m.can_bid(i):
					level._do_bid(i)
					return
			level._end_day()
		_:
			if not level._letter_read:
				level._select(level.towns[0])
				level._read_letter()
				return
			var move := m.advice()
			match str(move.get("do", "")):
				"mill":
					level._do_build_mill(move["at"])
				"supplier":
					level._do_buy_supplier(move["at"])
				"give":
					level._do_give(move["at"], move["kind"])
				_:
					level._end_day()
