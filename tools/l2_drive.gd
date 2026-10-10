extends Node
## Plays Level 2 by itself, to check the whole flow end to end without
## anyone at the keyboard. Always pair it with a throwaway save file:
##   godot --headless --fixed-fps 60 --path . res://tools/l2_drive.tscn
##       -- --save=user://l2_drive.json --l2=square --let=1
## --l2=<checkpoint> starts there; --let=N lets N sacks get away first (3
## should fail the level); --mash punches Krampus wildly at first.

var level: Node
var _let := 0
var _mash := false
var _last := ""
var _frame := 0
var _mashed := 0
var _spared: Array[Demon] = []


func _ready() -> void:
	var checkpoint := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l2="):
			checkpoint = arg.get_slice("=", 1)
		elif arg.begins_with("--let="):
			_let = arg.get_slice("=", 1).to_int()
		elif arg == "--mash":
			_mash = true
	GameState.new_game(false)
	Router.payload = {"level": "l2", "checkpoint": checkpoint}
	level = load("res://levels/02_krampusnacht/krampusnacht.tscn").instantiate()
	add_child(level)


func _physics_process(_delta: float) -> void:
	_frame += 1
	var status := "%s %s" % [level.stage, level.sacks_run.sacks]
	if level.fight:
		status += " krampus %d %s %s" % [level.fight.health, KrampusFight.State.keys()[level.fight.state], "lit" if level.fight.lit else "dark"]
	if status != _last:
		print("[%5.1fs] %s  health %.1f" % [_frame / 60.0, status, level.health])
		_last = status
	if _frame % 120 == 0:
		for demon in _spared:
			if is_instance_valid(demon):
				print("    spared ", demon.global_position, " mode ", Demon.Mode.keys()[demon.mode], " step ", demon._route_i, "/", demon.route.size())
	if level.ended:
		var outcome := "COMPLETE" if level.find_children("*", "LevelComplete", true, false).size() > 0 else "FAILED"
		print("Ended: %s at %.1fs, Santa at %s" % [outcome, _frame / 60.0, level.santa.global_position if level.santa else Vector3.ZERO])
		get_tree().quit()
		return
	if _frame > 60 * 60 * 6:
		print("Timed out in stage ", level.stage)
		get_tree().quit()
		return
	if Dialogue.is_playing() and level._busy:
		Dialogue.skip()
		return
	if level._busy or level.santa == null:
		return
	var santa: SantaController = level.santa
	match level.stage:
		"street":
			for demon: Demon in get_tree().get_nodes_in_group("demons"):
				if not demon.is_gone() and _frame % 20 == 0:
					_beat(demon)
					return
			santa.global_position = Vector3(0, 0.1, level.L.SQUARE_ENTRY_Z - 1.0)
		"sacks", "settled":
			# Open anything lying about first, then go after carriers.
			for sack: ElfSack in level.sacks:
				if sack.can_open():
					santa.global_position = sack.global_position + Vector3(0.8, 0.1, 0)
					_press("interact")
					return
			if _frame % 20 != 0:
				return
			if _let > 0:
				for demon: Demon in get_tree().get_nodes_in_group("demons"):
					if demon.mode == Demon.Mode.CARRY and not demon in _spared:
						_spared.append(demon)
						_let -= 1
						return
			# Whoever is swinging at Santa first, then the carriers.
			for demon: Demon in get_tree().get_nodes_in_group("demons"):
				if not demon.is_gone() and demon.mode in [Demon.Mode.FIGHT, Demon.Mode.WINDUP] \
						and demon.global_position.distance_to(santa.global_position) < 4.0:
					_beat(demon)
					return
			for demon: Demon in get_tree().get_nodes_in_group("demons"):
				if demon.is_gone() or demon.sack == null or demon.mode != Demon.Mode.CARRY or demon in _spared:
					continue
				_beat(demon)
				return
		"boss":
			_fight(santa)


func _fight(santa: SantaController) -> void:
	var fight: KrampusFight = level.fight
	var krampus: Krampus = level.krampus
	if fight.is_over():
		return
	if not fight.lit and fight.state == KrampusFight.State.STALK:
		santa.global_position = level.L.DOOR + Vector3(0, 0.1, 1.2)
		if _frame % 30 == 0:
			_press("interact")
		return
	if _mash and _mashed < 4 and fight.lit and _frame % 6 == 0:
		_mashed += 1
		krampus.take_hit({"kind": "punch", "damage": 2, "force": 7, "direction": Vector3.FORWARD, "at": krampus.global_position, "by": santa})
		return
	var away := santa.global_position - krampus.global_position
	away.y = 0.0
	if away.length() > 4.0 or away.length() < 2.0:
		santa.global_position = krampus.global_position + (away.normalized() if away.length() > 0.1 else Vector3.BACK) * 3.2 + Vector3(0, 0.1, 0)
	match fight.state:
		KrampusFight.State.WINDUP:
			if fight.timer < 0.2 and not level.guard.is_up():
				_press("parry")
		KrampusFight.State.CAUGHT:
			if _frame % 15 == 0:
				_press("attack")


func _beat(demon: Demon) -> void:
	var santa: SantaController = level.santa
	var to := demon.global_position - santa.global_position
	to.y = 0.0
	santa.global_position = demon.global_position + Vector3(1.2, 0.1, 0)
	demon.take_hit({"kind": "punch", "damage": 2, "force": 7, "direction": -to.normalized(), "at": demon.global_position, "by": santa})


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)
