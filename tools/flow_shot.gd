extends Node
## Walks one game flow automatically so it can be screenshotted with
## --write-movie. Always pair it with a throwaway save file:
##   godot --write-movie out.png --fixed-fps 30 --quit-after 240 res://tools/flow_shot.tscn
##       -- --save=user://flow_test.json --flow=calendar
## Flows: menu, settings, calendar, prologue, office, call, checkpoint, fail, hint, pause


func _ready() -> void:
	var flow := "menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--flow="):
			flow = arg.get_slice("=", 1)
	GameState.new_game(false)
	# Hand the "current scene" role to a placeholder so scene changes free it
	# instead of this driver.
	var placeholder := Node.new()
	get_tree().root.add_child.call_deferred(placeholder)
	await _frames(1)
	get_tree().current_scene = placeholder
	await _frames(1)
	match flow:
		"menu", "settings":
			GameState.data.record_completion("prologue", 200.0)
			GameState.has_save = true
			Router.go_to(Router.TITLE, {"menu": true})
			if flow == "settings":
				await _frames(30)
				get_tree().current_scene._settings()
		"calendar":
			GameState.data.record_completion("prologue", 222.0)
			GameState.data.record_completion("l1", 760.0, {"coins": 2, "letters": 1})
			GameState.has_save = true
			Router.go_to(Router.CALENDAR, {"just_finished": "prologue"})
			await _frames(30)
			get_tree().current_scene._select("prologue")
		"prologue", "office":
			Router.start_level("prologue")
			await _frames(40)
			var lines := 3 if flow == "prologue" else 18
			for i in lines:
				await _press_advance()
				await _press_advance()
		"call":
			Router.start_level("prologue")
			await _frames(30)
			Dialogue.skip()
			await _frames(60)
			_press_button("Answer")
			await _frames(40)
			for i in 2:
				await _press_advance()
				await _press_advance()
		"checkpoint", "fail", "hint", "pause":
			GameState.data.record_completion("prologue", 200.0)
			Router.start_level("l1")
			await _frames(30)
			var level := get_tree().current_scene as LevelBase
			if flow == "checkpoint":
				level._next_checkpoint()
			elif flow == "pause":
				level.pause_menu.open()
			else:
				var fails := 3 if flow == "hint" else 1
				for i in fails - 1:
					GameState.data.add_fail("l1", "start")
				level.fail("Santa slipped and fell into a snowdrift.")
				if flow == "hint":
					await _frames(20)
					_press_button("Pepper has a hint")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press_advance() -> void:
	var e := InputEventAction.new()
	e.action = "advance"
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(25)


func _press_button(starts_with: String) -> void:
	for b in get_tree().root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(starts_with) and b.is_visible_in_tree():
			(b as Button).pressed.emit()
			return
	push_warning("No button '%s'" % starts_with)
