extends Node
## Plays Level 4 by itself, to check the whole flow end to end without
## anyone at the keyboard. Always pair it with a throwaway save file:
##   godot --headless --fixed-fps 60 --path . res://tools/l4_drive.tscn
##       -- --save=user://l4_drive.json --l4=barracks --caps=6
## --l4=<checkpoint> starts there; --caps=N lifts N red caps (fewer than 4
## should lose elves in the chase); --no-mutiny skips giving the treasures
## back; --spotted walks out in front of the Cat (should fail).

const L := preload("res://levels/04_yule_cat/yule_layout.gd")
## Santa's way out of the cave to the sleigh, clear of the pond and the props.
const RUN := [Vector3(-2.0, 0, -50.0), Vector3(0.0, 0, -45.0), Vector3(0.0, 0, -38.0), Vector3(0.3, 0, -30.0),
		Vector3(0.0, 0, -20.0), Vector3(1.5, 0, -12.0), Vector3(5.2, 0, -5.0), Vector3(5.2, 0, 3.0), Vector3(2.0, 0, 11.0),
		Vector3(1.3, 0, 20.0), Vector3(1.5, 0, 30.0), Vector3(4.0, 0, 40.0), Vector3(5.5, 0, 43.5)]

var level: Node
var _caps := 6
var _mutiny := true
var _spotted := false
var _last := ""
var _frame := 0
var _wait := 0
## The jobs still to do while sneaking: [kind, what].
var _jobs: Array = []
var _run_i := 0


func _ready() -> void:
	var checkpoint := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l4="):
			checkpoint = arg.get_slice("=", 1)
		elif arg.begins_with("--caps="):
			_caps = arg.get_slice("=", 1).to_int()
		elif arg == "--no-mutiny":
			_mutiny = false
		elif arg == "--spotted":
			_spotted = true
	GameState.new_game(false)
	Router.payload = {"level": "l4", "checkpoint": checkpoint}
	level = load("res://levels/04_yule_cat/yule_cat_prowls.tscn").instantiate()
	add_child(level)
	if _spotted:
		_jobs.append(["spotted", null])
	if _mutiny and checkpoint.is_empty():
		for treasure: String in ["spoon", "skyr", "candle"]:
			_jobs.append(["pick", treasure])
			_jobs.append(["give", YuleLadCrew.TREASURES[treasure]["owner"]])
	if checkpoint != "cave":
		for i in _caps:
			_jobs.append(["cap", i])
	_jobs.append(["cave", null])


func _physics_process(_delta: float) -> void:
	_frame += 1
	var status := "%s caps %d returned %d" % [level.stage, level.taken_caps.size(), level.crew.returned]
	if level.crew.mutiny:
		status += " MUTINY"
	if level.chase:
		status += " lost %d cat %s" % [level.chase.lost_count(), "on" if level.chase.cat_on else "off"]
	if status != _last:
		print("[%5.1fs] %s  seen %.2f (%s)" % [_frame / 60.0, status, level.meter.level, level.meter.last_source])
		_last = status
	if level.ended:
		var outcome := "COMPLETE" if level.find_children("*", "LevelComplete", true, false).size() > 0 else "FAILED"
		print("Ended: %s at %.1fs, Santa at %s" % [outcome, _frame / 60.0, level.santa.global_position if level.santa else Vector3.ZERO])
		get_tree().quit()
		return
	if _frame > 60 * 60 * 5:
		print("Timed out in stage %s, Santa at %s" % [level.stage, level.santa.global_position])
		get_tree().quit()
		return
	if Dialogue.is_playing() and level._busy:
		Dialogue.skip()
		return
	if level._busy or level.santa == null:
		return
	var santa: SantaController = level.santa
	match level.stage:
		"sneak":
			santa.input_enabled = false
			santa.move_intent = Vector3.ZERO
			santa.sneak_intent = true
			_sneak(santa)
		"cave":
			santa.input_enabled = false
			_put(santa, L.CAGE + Vector3(0, 0, 1.9))
			if _frame % 20 == 0:
				_press("interact")
		"chase":
			santa.input_enabled = false
			santa.sneak_intent = false
			santa.run_intent = true
			var goal: Vector3 = RUN[_run_i]
			var to := goal - santa.global_position
			to.y = 0.0
			if to.length() < 1.2 and _run_i < RUN.size() - 1:
				_run_i += 1
			santa.move_intent = to.normalized()


func _sneak(santa: SantaController) -> void:
	_wait -= 1
	if _wait > 0 or _jobs.is_empty():
		return
	_wait = 25
	var job: Array = _jobs[0]
	match str(job[0]):
		"spotted":
			_put(santa, level.cat.global_position + Vector3(sin(level.cat.yaw), 0, cos(level.cat.yaw)) * 5.0)
			santa.sneak_intent = false
			_wait = 10
			return
		"pick":
			if not level._pickups.has(job[1]):
				_jobs.pop_front()
				return
			_put(santa, (level._pickups[job[1]] as Node3D).global_position + Vector3(0.6, 0, 0))
			_press("interact")
			print("    picking up ", job[1])
			return
		"give":
			if level.crew.moods[job[1]] != YuleLadCrew.Mood.HOSTILE:
				_jobs.pop_front()
				return
			var lad: YuleLad = level.lads[job[1]]
			_put(santa, lad.global_position + Vector3(0.9, 0, 0.6))
			_press("interact")
			print("    giving back to ", job[1])
			return
		"cap":
			var sleeper: RedCapSleeper = level.sleepers[job[1]]
			if sleeper.cap_taken:
				_jobs.pop_front()
				return
			_put(santa, sleeper.global_position + Vector3(-1.5, 0, 0))
			if sleeper.awake <= 0.0:
				_press("interact")
			return
		"cave":
			_put(santa, Vector3(0, 0, L.CAVE_ENTRY_Z - 1.0))
			return


func _put(santa: SantaController, at: Vector3) -> void:
	santa.global_position = Vector3(at.x, maxf(at.y, 0.0) + 0.1, at.z)
	santa.velocity = Vector3.ZERO


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)
