extends LevelBase
## Level 3, "The Paper Monopoly" (9 December): strategy on a tabletop map.
##
## Scrooge & Co. has bought every wrapping-paper mill on Earth. Santa sits at
## the far end of Scrooge's boardroom table, where the world is spread out as
## a parchment map, and has twelve days to win the paper back before the
## shipping deadline. Click a piece on the map to open its ledger; three
## actions a day, then end the day. Bidding for a mill never works (Golden
## Tower money is bottomless). Kindness does: wages, toys and warm meals
## fill a town's goodwill until it strikes and comes over to Santa. Elf mills
## on Santa's own land and the suppliers he buys pay for it all. Go bankrupt
## and the chapter is lost; at the deadline (or once every town is his) the
## shareholders vote, and he needs a majority.
##
## The rules live in PaperMarket (core/logic/paper_market.gd); this script is
## the table, the camera and the ledgers. Checkpoints "day5" and "day9" save
## the whole market with them. `-- --l3=<checkpoint>` starts from one for
## testing (playing Pepper's advice up to that day if there's no save), and
## `--l3-pick=<n>` opens the ledger of piece n (towns, suppliers, then mills).

const L := preload("res://levels/03_paper_monopoly/map_layout.gd")

const INK := Color("2b1d14")
const INK_RED := Color("8a1c1c")
const PAPER := Color("efe2c2")
const PAPER_EDGE := Color("8a6a3e")
const KINDNESS_LABELS := {"wages": "Raise their wages for good", "toys": "Toys for the children", "meals": "Warm meals"}
const KINDNESS_ADVICE := {"wages": "raise their wages", "toys": "bring toys for their children", "meals": "send them warm meals"}
## The made-up companies Scrooge buys the suppliers through.
const SHELLS := ["Tinsel Trust Ltd", "Humbug Holdings", "Farthing & Sons"]
const FIRST_DATE := 9
const CHECKPOINT_DAYS := {5: "day5", 9: "day9"}
const CAMERA_SMOOTH := 4.5
const PAN_SPEED := 1.1
const PICK_RADIUS := 0.085
## A focused piece sits left of centre, clear of the ledger.
const LEDGER_SHIFT := Vector3(0.17, 0.0, 0.0)
const LAMP_ENERGY := 1.9
const NEWS_LINES := 6
## Pixel nudges for name labels that would otherwise overlap their neighbours.
const LABEL_NUDGES := {"Town0": Vector2(-70, 0), "Town1": Vector2(55, 0), "Town2": Vector2(80, 0),
		"Town4": Vector2(50, 0), "Supplier2": Vector2(-40, 0)}

var market: PaperMarket
var towns: Array[MapPiece] = []
var suppliers: Array[MapPiece] = []
var mills: Array[MapPiece] = []
var selected: MapPiece
var scrooge: CastModel
var camera: Camera3D
var env: Environment
var lamp: FlickerLight
## "intro", "play", "day_end", "vote", "outro"
var stage := "intro"

var _busy := false
var _said := {}
var _letter_read := false
var _joined := 0
var _hovered: MapPiece
var _eye: Vector3 = L.OVERVIEW_EYE
var _look: Vector3 = L.OVERVIEW_LOOK
var _cam_look: Vector3 = L.OVERVIEW_LOOK
var _zoom := 1.0
var _pan := Vector3.ZERO
var _news: Array[String] = []
var _ballots: Array[Label3D] = []
var _fire: Node3D

var _day_label: Label
var _coins_label: Label
var _income_label: Label
var _actions_label: Label
var _votes_label: Label
var _ledger: PanelContainer
var _ledger_box: VBoxContainer
var _end_button: Button
var _advice_button: Button
var _news_label: Label
var _help: Label
var _banner: Label
var _tally: Label
var _fade: ColorRect
## The top bar, news and buttons: hidden during the story scenes.
var _hud_parts: Array[Control] = []


func _ready() -> void:
	super._ready()
	var started := Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l3="):
			start_checkpoint = arg.get_slice("=", 1)
	section = start_checkpoint if not start_checkpoint.is_empty() else "start"
	_build_environment()
	add_child(Baked.node("boardroom_set"))
	_add_lights()
	scrooge = Cast.make("scrooge")
	add_child(scrooge)
	scrooge.position = L.SCROOGE_SPOT
	_add_pieces()
	camera = Camera3D.new()
	camera.name = "TableCamera"
	camera.fov = 50.0
	camera.near = 0.02
	add_child(camera)
	camera.make_current()
	_build_hud()
	market = _restore()
	_refresh_all()
	if start_checkpoint.is_empty():
		_cut_to(Vector3(0.55, 1.6, -0.1), L.SCROOGE_SPOT + Vector3(0, 1.4, 0))
		_intro.call_deferred()
	else:
		_log("%s. The ledgers are open where you left them." % _date(market.day))
		_snap_camera()
		_start_play()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l3-pick="):
			_select.call_deferred(_all_pieces()[arg.get_slice("=", 1).to_int()])
	Engine.set_meta("startup_ms", Time.get_ticks_msec() - started)
	print("Paper Monopoly built in %d ms" % Engine.get_meta("startup_ms"))


func _new_market() -> PaperMarket:
	return PaperMarket.new(PaperMarket.DAYS, int(round(tuned(PaperMarket.START_COINS, "health"))))


## The market to start with: fresh, or as saved at the checkpoint.
func _restore() -> PaperMarket:
	if start_checkpoint.is_empty():
		return _new_market()
	var saved: Dictionary = GameState.data.checkpoint.get("state", {})
	if saved.get("checkpoint", "") == start_checkpoint:
		_letter_read = bool(saved.get("letter", false))
		if _letter_read:
			collect("letters")
		var restored := PaperMarket.from_dict(saved)
		_joined = restored.towns_won()
		return restored
	# Nothing saved (testing from the command line): play Pepper's advice up to that day.
	var m := _new_market()
	var target := 5 if start_checkpoint == "day5" else 9
	while m.day < target:
		while m.actions > 0:
			var move := m.advice()
			if move.is_empty() or not m.take(move):
				break
		var events := m.end_day()
		if events.any(func(e: Dictionary) -> bool: return e["kind"] in ["bankrupt", "deadline", "all_won"]):
			break
	_joined = m.towns_won()
	return m


# --- The story around the game ---

func _intro() -> void:
	_busy = true
	_set_ui_enabled(false)
	_show_hud(false)
	await Dialogue.play(Dialogue.lines("l3", "intro"))
	_show_hud(true)
	_log("9 December. Scrooge & Co. owns every paper mill on Earth.")
	_go_overview()
	_start_play()


func _start_play() -> void:
	_busy = false
	stage = "play"
	_set_ui_enabled(true)
	_update_hud()


func _read_letter() -> void:
	if _letter_read or _busy:
		return
	_busy = true
	_letter_read = true
	collect("letters")
	_set_ui_enabled(false)
	await Dialogue.play(Dialogue.lines("l3", "letter"))
	_log("Found a letter at Smogbury, from Ada (age 7).")
	_busy = false
	_set_ui_enabled(true)
	_show_ledger()


# --- What Santa does ---

func _do_give(i: int, kind: String) -> void:
	if _busy or not market.give(i, kind):
		return
	var town: Dictionary = market.towns[i]
	towns[i].show_goodwill(town["goodwill"])
	towns[i].bounce()
	Audio.play_sfx("ring", 1.0 + town["goodwill"] / 200.0, -4.0)
	_log("%s: %s." % [PaperMarket.TOWNS[i]["name"], KINDNESS_LABELS[kind].to_lower()])
	if not _said.has("first_kindness"):
		_say_once("first_kindness")
	elif kind == "wages":
		_say_once("wages_note")
	_after_action()


func _do_bid(i: int) -> void:
	if _busy:
		return
	var lost := market.bid(i)
	if lost == 0:
		return
	towns[i].bounce()
	_log("Bid for %s. Outbid by Golden Tower money! The %d coin deposit is lost." % [PaperMarket.TOWNS[i]["name"], lost])
	_show_banner("Outbid!  -%d coins" % lost, INK_RED.lightened(0.3))
	match market.bids:
		1:
			_bark("first_bid")
		2:
			_bark("bid_hint")
		_:
			_bark("bid_again")
	_after_action()


func _do_buy_supplier(i: int) -> void:
	if _busy or not market.buy_supplier(i):
		return
	suppliers[i].show_owner(PaperMarket.Owner.SANTA)
	suppliers[i].bounce()
	Audio.play_sfx("bell", 1.3, -6.0)
	_log("Bought %s. +%d coins a day." % [PaperMarket.SUPPLIERS[i]["name"], PaperMarket.SUPPLIERS[i]["income"]])
	_after_action()


func _do_build_mill(i: int) -> void:
	if _busy or not market.build_mill(i):
		return
	mills[i].show_mill(true)
	mills[i].bounce()
	Audio.play_sfx("bell", 1.1, -6.0)
	_log("Built an elf paper mill at %s. +%d coins a day." % [PaperMarket.MILL_SITES[i]["name"], PaperMarket.MILL_INCOME])
	_after_action()


func _after_action() -> void:
	_update_hud()
	_show_ledger()


## Pepper suggests a move, and the map turns to show where.
func _ask_pepper() -> void:
	if _busy:
		return
	var move := market.advice()
	var text := ""
	var piece: MapPiece
	match str(move.get("do", "")):
		"mill":
			piece = mills[move["at"]]
			text = "Let's build an elf mill at %s. It'll pay for itself in three days." % PaperMarket.MILL_SITES[move["at"]]["name"]
		"supplier":
			piece = suppliers[move["at"]]
			text = "Let's snap up %s before Scrooge's shell companies do!" % PaperMarket.SUPPLIERS[move["at"]]["name"]
		"give":
			piece = towns[move["at"]]
			text = "The workers at %s are warming to us. Let's %s." % [PaperMarket.TOWNS[move["at"]]["name"], KINDNESS_ADVICE[move["kind"]]]
		_:
			if market.actions == 0:
				text = "That's us done for today, Santa. Let's end the day."
			else:
				text = "Let's keep the coins we've got and end the day. The bills come in tonight."
	if piece:
		_select(piece)
	Dialogue.play([{"who": "pepper", "text": text}], "bark")


# --- The end of each day ---

func _end_day() -> void:
	if _busy or stage != "play":
		return
	_busy = true
	stage = "day_end"
	_select(null)
	_set_ui_enabled(false)
	var events := market.end_day()
	for e in events:
		await _show_event(e)
	_go_overview()
	_refresh_all()
	var last: String = events.back()["kind"] if not events.is_empty() else ""
	match last:
		"bankrupt":
			_log("The purse is empty. Santa & Elves is bankrupt.")
			await _wait(0.8)
			fail("Santa's purse ran dry, and the elves' paper bill bounced. Keep enough back to cover each night's costs.")
			return
		"all_won", "deadline":
			await _vote()
			return
	_new_day()
	_start_play()


func _show_event(e: Dictionary) -> void:
	match e["kind"]:
		"joined":
			var i: int = e["town"]
			_joined += 1
			_visit(towns[i])
			await _wait(0.8)
			towns[i].show_owner(PaperMarket.Owner.SANTA)
			towns[i].bounce()
			Audio.play_sfx("bell", 1.0, -3.0)
			_log("%s has come over to Santa! +%d coins a day." % [PaperMarket.TOWNS[i]["name"], PaperMarket.TOWN_INCOME])
			_update_hud()
			await _say("joined_%d" % mini(_joined, 5), {"town": PaperMarket.TOWNS[i]["name"]})
		"strike":
			var i: int = e["town"]
			_visit(towns[i])
			await _wait(0.8)
			towns[i].show_goodwill(PaperMarket.GOODWILL_TO_STRIKE)
			towns[i].show_owner(PaperMarket.Owner.STRIKE)
			towns[i].bounce()
			_log("%s is on strike!" % PaperMarket.TOWNS[i]["name"])
			await _say("strike", {"town": PaperMarket.TOWNS[i]["name"]})
		"bonus":
			var i: int = e["town"]
			_visit(towns[i])
			await _wait(0.6)
			towns[i].show_goodwill(market.towns[i]["goodwill"])
			towns[i].bounce()
			_log("Scrooge tossed %s a farthing bonus. Goodwill -%d." % [PaperMarket.TOWNS[i]["name"], int(PaperMarket.SCROOGE_BONUS)])
			var times: int = _said.get("bonus", 0)
			_said["bonus"] = times + 1
			if times < 2:
				await _say("bonus", {"town": PaperMarket.TOWNS[i]["name"]})
			else:
				await _wait(0.8)
		"shell":
			var i: int = e["supplier"]
			_visit(suppliers[i])
			await _wait(0.8)
			suppliers[i].show_owner(PaperMarket.Owner.SCROOGE)
			suppliers[i].bounce()
			_log("%s was bought by \"%s\". One more vote for Scrooge." % [PaperMarket.SUPPLIERS[i]["name"], SHELLS[i]])
			await _say("shell", {"supplier": PaperMarket.SUPPLIERS[i]["name"]})


func _new_day() -> void:
	_log("%s. Purse: %d coins." % [_date(market.day), market.coins])
	_show_banner("%s  ·  Day %d of %d" % [_date(market.day), market.day, market.days], UiTheme.GOLD)
	if CHECKPOINT_DAYS.has(market.day) and section != CHECKPOINT_DAYS[market.day]:
		_save_checkpoint(CHECKPOINT_DAYS[market.day])
	if market.coins + market.income() < 0 or market.coins < 12:
		_say_once("poor")
	elif market.days - market.day == 2:
		_say_once("deadline_near")


func _save_checkpoint(id: String) -> void:
	reach_checkpoint(id)
	var state := market.to_dict()
	state["checkpoint"] = id
	state["letter"] = _letter_read
	GameState.data.checkpoint["state"] = state
	GameState.save_game()


# --- The vote ---

func _vote() -> void:
	stage = "vote"
	section = "vote"
	_set_ui_enabled(false)
	_ledger.visible = false
	_eye = Vector3(0.0, 2.0, 1.75)
	_look = Vector3(0.0, L.TABLE_TOP, -0.35)
	await Dialogue.play(Dialogue.lines("l3", "vote_intro"))
	_tally.visible = true
	var tally := Vector2i.ZERO
	_update_tally(tally)
	await _wait(0.5)
	# Scrooge's own proxies first, then each town and supplier in turn.
	tally.y += PaperMarket.SCROOGE_PROXIES
	_ballot(L.SCROOGE_SPOT + Vector3(0, 2.0, 0), "NAY x%d" % PaperMarket.SCROOGE_PROXIES, false)
	_update_tally(tally)
	await _wait(1.0)
	for i in towns.size():
		var aye: bool = market.towns[i]["owner"] != PaperMarket.Owner.SCROOGE
		if aye:
			tally.x += PaperMarket.TOWN_VOTES
		else:
			tally.y += PaperMarket.TOWN_VOTES
		_ballot(towns[i].global_position + Vector3(0, 0.24, 0), ("AYE x%d" if aye else "NAY x%d") % PaperMarket.TOWN_VOTES, aye)
		towns[i].bounce()
		_update_tally(tally)
		await _wait(0.75)
	for i in suppliers.size():
		var owner: int = market.suppliers[i]
		if owner == PaperMarket.Owner.SANTA:
			tally.x += PaperMarket.SUPPLIER_VOTES
		elif owner == PaperMarket.Owner.SCROOGE:
			tally.y += PaperMarket.SUPPLIER_VOTES
		var text := "AYE" if owner == PaperMarket.Owner.SANTA else ("NAY" if owner == PaperMarket.Owner.SCROOGE else "abstains")
		_ballot(suppliers[i].global_position + Vector3(0, 0.2, 0), text, owner == PaperMarket.Owner.SANTA)
		suppliers[i].bounce()
		_update_tally(tally)
		await _wait(0.6)
	await _wait(0.8)
	if market.vote_won():
		await Dialogue.play(Dialogue.lines("l3", "vote_won"))
		_tally.visible = false
		await _outro()
	else:
		await Dialogue.play(Dialogue.lines("l3", "vote_lost"))
		fail("The shareholders voted with Scrooge, and the paper stays locked up. Win more of his towns over before the vote.")


func _ballot(at: Vector3, text: String, aye: bool) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.0009
	label.outline_size = 16
	label.modulate = Color("ffe08a") if aye else Color("ff8a7a")
	label.outline_modulate = Color(0.1, 0.05, 0.03)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.position = at
	label.scale = Vector3.ONE * 0.2
	add_child(label)
	_ballots.append(label)
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx("click", 1.4 if aye else 0.8)


func _update_tally(tally: Vector2i) -> void:
	_tally.text = "For Santa: %d     Against: %d     Needed: %d" % [tally.x, tally.y, market.votes_needed()]


# --- The ending ---

func _outro() -> void:
	stage = "outro"
	section = "outro"
	for ballot in _ballots:
		ballot.queue_free()
	_ballots.clear()
	var on_cue := func(cue_name: String) -> void:
		match cue_name:
			"black":
				_fade_to(1.0, 0.8)
			"back":
				_light_fire()
				scrooge.visible = false
				_cut_to(Vector3(1.3, 1.35, -1.6), L.FIREPLACE + Vector3(0, 0.55, 0))
				_fade_to(0.0, 1.4)
	_show_hud(false)
	Dialogue.cue.connect(on_cue)
	await Dialogue.play(Dialogue.lines("l3", "outro"))
	Dialogue.cue.disconnect(on_cue)
	complete()


## For the first time in years, a fire in the grate.
func _light_fire() -> void:
	if _fire:
		return
	_fire = WinterProps.fire(0.6)
	_fire.position = L.FIREPLACE + Vector3(0, 0.2, 0.15)
	add_child(_fire)
	env.ambient_light_color = Color("6a4a38")
	env.ambient_light_energy = 0.5


# --- The camera ---

func _process(delta: float) -> void:
	super._process(delta)
	if stage == "play" and not _busy:
		var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if move != Vector2.ZERO:
			_pan += Vector3(move.x, 0.0, move.y) * PAN_SPEED * delta * _zoom
			_pan.x = clampf(_pan.x, -L.MAP_SIZE.x * 0.5, L.MAP_SIZE.x * 0.5)
			_pan.z = clampf(_pan.z, -L.MAP_SIZE.y * 0.5, L.MAP_SIZE.y * 0.5)
	var look := _look + _pan
	var eye := look + (_eye - _look) * _zoom
	var k := 1.0 - exp(-CAMERA_SMOOTH * delta)
	_cam_look = _cam_look.lerp(look, k)
	camera.global_position = camera.global_position.lerp(eye, k)
	camera.look_at(_cam_look)


func _snap_camera() -> void:
	_cam_look = _look + _pan
	camera.global_position = _cam_look + (_eye - _look) * _zoom
	camera.look_at(_cam_look)


func _cut_to(eye: Vector3, look: Vector3) -> void:
	_eye = eye
	_look = look
	_pan = Vector3.ZERO
	_zoom = 1.0
	_snap_camera()


func _go_overview() -> void:
	_eye = L.OVERVIEW_EYE
	_look = L.OVERVIEW_LOOK
	_pan = Vector3.ZERO
	_zoom = 1.0


## The camera leans in on a piece while something happens there.
func _visit(piece: MapPiece) -> void:
	_look = piece.global_position
	_eye = piece.global_position + L.FOCUS_OFFSET * 1.25
	_pan = Vector3.ZERO
	_zoom = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if stage != "play" or _busy:
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick(event.position))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var piece := _pick(event.position)
				if piece:
					_select(piece)
			MOUSE_BUTTON_RIGHT:
				_select(null)
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = maxf(0.45, _zoom * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = minf(1.3, _zoom / 0.9)


## The piece under the mouse, testing a few heights so the tops of the
## buildings count as well as their bases.
func _pick(screen: Vector2) -> MapPiece:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return null
	var best: MapPiece = null
	var best_d := PICK_RADIUS
	for piece in _all_pieces():
		for h: float in [0.0, 0.04, 0.08]:
			var t := (piece.global_position.y + h - from.y) / dir.y
			if t <= 0.0:
				continue
			var hit := from + dir * t
			var d := Vector2(hit.x - piece.global_position.x, hit.z - piece.global_position.z).length()
			if d < best_d:
				best_d = d
				best = piece
	return best


func _set_hover(piece: MapPiece) -> void:
	if piece == _hovered:
		return
	if _hovered and _hovered != selected:
		_hovered.set_highlight(false)
	_hovered = piece
	if piece:
		piece.set_highlight(true)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if piece else Input.CURSOR_ARROW)


func _select(piece: MapPiece) -> void:
	if selected and selected != piece:
		selected.set_highlight(false)
	selected = piece
	if piece:
		piece.set_highlight(true)
		_look = piece.global_position + LEDGER_SHIFT
		_eye = _look + L.FOCUS_OFFSET
		_pan = Vector3.ZERO
		_zoom = 1.0
	else:
		_go_overview()
	_show_ledger()


func _all_pieces() -> Array[MapPiece]:
	var all: Array[MapPiece] = []
	all.append_array(towns)
	all.append_array(suppliers)
	all.append_array(mills)
	return all


# --- The ledgers ---

func _show_ledger() -> void:
	for child in _ledger_box.get_children():
		_ledger_box.remove_child(child)
		child.queue_free()
	_ledger.visible = selected != null and stage == "play"
	_help.visible = stage == "play" and not _busy and selected == null
	if not _ledger.visible:
		return
	match selected.kind:
		MapPiece.Kind.TOWN:
			_town_ledger(selected.index)
		MapPiece.Kind.SUPPLIER:
			_supplier_ledger(selected.index)
		MapPiece.Kind.MILL:
			_mill_ledger(selected.index)
	_ink(" ")
	_ink("Right-click to go back to the map", 14, PAPER_EDGE)


func _town_ledger(i: int) -> void:
	var spec: Dictionary = PaperMarket.TOWNS[i]
	var town: Dictionary = market.towns[i]
	_ink_title("%s Paper Mill" % spec["name"], spec["place"])
	match town["owner"]:
		PaperMarket.Owner.SANTA:
			_ink("Owner: Santa Claus. The workers came over to you.")
			_ink("Brings in %d coins a day, and %d votes at the meeting." % [PaperMarket.TOWN_INCOME, PaperMarket.TOWN_VOTES])
			return
		PaperMarket.Owner.STRIKE:
			_ink("ON STRIKE! The whole mill has walked out.", 18, INK_RED)
			_ink("They'll come over to you when the day ends.")
			return
	_ink("Owner: Scrooge & Co.")
	if town["wages"]:
		_ink("Wages: raised by you. +%d goodwill and -%d coins every day." % [int(PaperMarket.WAGES_DAILY_GOODWILL), PaperMarket.WAGES_DAILY_COST])
	else:
		_ink("Wages: at 1842 rates", 17, INK_RED)
	_ink("Goodwill to Santa: %d / %d" % [int(town["goodwill"]), int(PaperMarket.GOODWILL_TO_STRIKE)])
	_ledger_box.add_child(_goodwill_bar(town["goodwill"]))
	_ink("Asking price: %d coins" % town["price"])
	for kind: String in ["wages", "toys", "meals"]:
		if kind == "wages" and town["wages"]:
			continue
		var worth := market.kindness_worth(i, kind)
		var text := "%s: %d coins, +%d" % [KINDNESS_LABELS[kind], PaperMarket.KINDNESS[kind][0], int(worth)]
		if worth < float(PaperMarket.KINDNESS[kind][1]):
			text += " (again?)"
		_action(text, market.can_give(i, kind), int(PaperMarket.KINDNESS[kind][0]), _do_give.bind(i, kind))
	_action("Bid for the mill: %d coin deposit" % market.bid_deposit(i), market.can_bid(i), market.bid_deposit(i), _do_bid.bind(i))
	if spec["letter"] and not _letter_read:
		var read := UiTheme.button("Read the letter under the gate", _read_letter, 340)
		_ledger_box.add_child(read)


func _supplier_ledger(i: int) -> void:
	var spec: Dictionary = PaperMarket.SUPPLIERS[i]
	_ink_title(spec["name"], spec["place"])
	match market.suppliers[i]:
		PaperMarket.Owner.FREE:
			_ink("For sale: %d coins" % spec["price"])
			_ink("Pays +%d coins a day, and %d vote at the meeting." % [spec["income"], PaperMarket.SUPPLIER_VOTES])
			_ink("Scrooge's shell companies are buying them up. Don't wait too long!", 16, INK_RED)
			_action("Buy it: %d coins" % spec["price"], market.can_buy_supplier(i), int(spec["price"]), _do_buy_supplier.bind(i))
		PaperMarket.Owner.SANTA:
			_ink("Yours. +%d coins a day, and %d vote at the meeting." % [spec["income"], PaperMarket.SUPPLIER_VOTES])
		_:
			_ink("Sold to \"%s\", a company nobody's heard of." % SHELLS[i])
			_ink("One more vote for Scrooge.", 17, INK_RED)


func _mill_ledger(i: int) -> void:
	var spec: Dictionary = PaperMarket.MILL_SITES[i]
	_ink_title("%s: Santa's land" % spec["name"], spec["place"])
	if market.mills[i]:
		_ink("An elf paper mill, running day and night.")
		_ink("+%d coins a day." % PaperMarket.MILL_INCOME)
	else:
		_ink("Snowy ground, and plenty of elves to spare.")
		_ink("An elf paper mill brings in +%d coins a day." % PaperMarket.MILL_INCOME)
		_action("Build an elf mill: %d coins" % PaperMarket.MILL_COST, market.can_build_mill(i), PaperMarket.MILL_COST, _do_build_mill.bind(i))


func _ink_title(title: String, place: String) -> void:
	_ink(title, 24, INK)
	_ink(place, 15, PAPER_EDGE.darkened(0.2))
	var rule := ColorRect.new()
	rule.color = PAPER_EDGE
	rule.custom_minimum_size = Vector2(0, 2)
	_ledger_box.add_child(rule)


func _ink(text: String, size := 17, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 340
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	_ledger_box.add_child(label)
	return label


## A button for one of the day's actions, greyed out (with the reason) when it can't be done.
func _action(text: String, can: bool, cost: int, callback: Callable) -> void:
	var button := UiTheme.button(text, callback, 340)
	button.disabled = not can
	button.add_theme_font_size_override("font_size", 16)
	if not can:
		button.tooltip_text = "No actions left today" if market.actions == 0 \
				else ("Not enough coins" if market.coins < cost else "")
	_ledger_box.add_child(button)


func _goodwill_bar(amount: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(340, 14)
	bar.max_value = PaperMarket.GOODWILL_TO_STRIKE
	bar.value = amount
	var back := StyleBoxFlat.new()
	back.bg_color = PAPER.darkened(0.15)
	back.set_corner_radius_all(6)
	back.set_border_width_all(1)
	back.border_color = PAPER_EDGE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c8961e")
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# --- Barks, news and the HUD ---

func _bark(key: String) -> void:
	if _busy and Dialogue.is_playing():
		return
	Dialogue.play(Dialogue.lines("l3", key), "bark")


func _say_once(key: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	_bark(key)


## Plays a bark with {town}/{supplier} filled in, and waits for it.
func _say(key: String, fill: Dictionary) -> void:
	var steps: Array = Dialogue.lines("l3", key).duplicate(true)
	for step: Dictionary in steps:
		if step.has("text"):
			for k: String in fill:
				step["text"] = str(step["text"]).replace("{%s}" % k, fill[k])
	await Dialogue.play(steps, "bark")


func _log(text: String) -> void:
	_news.append(text)
	if _news_label:
		_news_label.text = "\n".join(_news.slice(-NEWS_LINES))


func _date(day: int) -> String:
	return "%d December" % (FIRST_DATE + day - 1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade_to(alpha: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, seconds)
	await t.finished


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	var t := _banner.create_tween()
	_banner.modulate.a = 0.0
	t.tween_property(_banner, "modulate:a", 1.0, 0.25)
	t.tween_interval(1.6)
	t.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _set_ui_enabled(on: bool) -> void:
	_end_button.disabled = not on
	_advice_button.disabled = not on
	_help.visible = on and selected == null
	if not on:
		_ledger.visible = false
		_set_hover(null)


func _refresh_all() -> void:
	for i in towns.size():
		towns[i].show_owner(market.towns[i]["owner"])
		towns[i].show_goodwill(market.towns[i]["goodwill"])
	for i in suppliers.size():
		suppliers[i].show_owner(market.suppliers[i])
	for i in mills.size():
		mills[i].show_mill(market.mills[i])
	_update_hud()
	_show_ledger()


func _update_hud() -> void:
	if _day_label == null or market == null:
		return
	_day_label.text = "%s  ·  Day %d of %d" % [_date(market.day), market.day, market.days]
	_coins_label.text = "Purse: %d coins" % market.coins
	var income := market.income()
	_income_label.text = "%+d tonight" % income
	_income_label.add_theme_color_override("font_color", INK_RED if market.coins + income < 0 else INK)
	_actions_label.text = "Actions left: %d of %d" % [market.actions, PaperMarket.ACTIONS]
	var votes := market.votes()
	_votes_label.text = "Votes: %d for, %d against (%d to win)" % [votes.x, votes.y, market.votes_needed()]
	_end_button.text = "End the day" if market.day < market.days else "End the day and vote"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _paper_box(0.94))
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 10
	layer.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	top.add_child(row)
	_day_label = _hud_label(row, 20)
	_coins_label = _hud_label(row, 20)
	_income_label = _hud_label(row, 18)
	_actions_label = _hud_label(row, 18)
	_votes_label = _hud_label(row, 18)

	_ledger = PanelContainer.new()
	_ledger.add_theme_stylebox_override("panel", _paper_box(0.97))
	_ledger.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ledger.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ledger.offset_top = 76
	_ledger.offset_right = -16
	_ledger.visible = false
	layer.add_child(_ledger)
	_ledger_box = VBoxContainer.new()
	_ledger_box.add_theme_constant_override("separation", 7)
	_ledger.add_child(_ledger_box)

	var news := PanelContainer.new()
	news.add_theme_stylebox_override("panel", _paper_box(0.82))
	news.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	news.grow_vertical = Control.GROW_DIRECTION_BEGIN
	news.offset_left = 16
	news.offset_bottom = -16
	news.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(news)
	var news_box := VBoxContainer.new()
	news.add_child(news_box)
	var heading := Label.new()
	heading.text = "THE CITY NEWS"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", PAPER_EDGE.darkened(0.2))
	heading.add_theme_constant_override("outline_size", 0)
	news_box.add_child(heading)
	_news_label = Label.new()
	_news_label.custom_minimum_size = Vector2(430, 0)
	_news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_label.add_theme_font_size_override("font_size", 15)
	_news_label.add_theme_color_override("font_color", INK)
	_news_label.add_theme_constant_override("outline_size", 0)
	_news_label.text = "\n".join(_news.slice(-NEWS_LINES))
	news_box.add_child(_news_label)

	var buttons := VBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_right = -16
	buttons.offset_bottom = -16
	buttons.add_theme_constant_override("separation", 8)
	layer.add_child(buttons)
	_advice_button = UiTheme.button("Ask Pepper", _ask_pepper, 240)
	buttons.add_child(_advice_button)
	_end_button = UiTheme.button("End the day", _end_day, 240)
	_end_button.custom_minimum_size.y = 58
	_end_button.add_theme_font_size_override("font_size", 22)
	buttons.add_child(_end_button)

	_help = Label.new()
	_help.text = "Click a piece on the map to open its ledger  ·  Wheel: zoom  ·  WASD: move"
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 5)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_right = -18
	_help.offset_bottom = -140
	_help.visible = false
	layer.add_child(_help)

	_banner = UiTheme.heading("", 40)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 150
	_banner.modulate.a = 0.0
	layer.add_child(_banner)

	_tally = UiTheme.heading("", 34)
	_tally.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tally.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tally.offset_top = 80
	_tally.visible = false
	layer.add_child(_tally)

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	layer.add_child(_fade)
	_hud_parts.assign([top, news, buttons])
	_set_ui_enabled(false)


func _show_hud(on: bool) -> void:
	for part in _hud_parts:
		part.visible = on


func _hud_label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_constant_override("outline_size", 0)
	parent.add_child(label)
	return label


func _paper_box(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PAPER, alpha)
	box.border_color = PAPER_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(14)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	return box


func debug_text() -> String:
	var votes := market.votes() if market else Vector2i.ZERO
	return super.debug_text() + "  ·  %s  ·  day %d/%d  ·  coins %d (%+d)  ·  actions %d  ·  towns %d  ·  votes %d-%d" % [
		stage, market.day, market.days, market.coins, market.income(), market.actions, market.towns_won(), votes.x, votes.y]


# --- Building ---

func _add_pieces() -> void:
	for i in PaperMarket.TOWNS.size():
		var piece := MapPiece.new(MapPiece.Kind.TOWN, i, PaperMarket.TOWNS[i]["name"])
		add_child(piece)
		piece.position = L.town_at(i)
		towns.append(piece)
	for i in PaperMarket.SUPPLIERS.size():
		var piece := MapPiece.new(MapPiece.Kind.SUPPLIER, i, PaperMarket.SUPPLIERS[i]["name"])
		add_child(piece)
		piece.position = L.supplier_at(i)
		suppliers.append(piece)
	for i in PaperMarket.MILL_SITES.size():
		var piece := MapPiece.new(MapPiece.Kind.MILL, i, PaperMarket.MILL_SITES[i]["name"])
		add_child(piece)
		piece.position = L.mill_at(i)
		mills.append(piece)
	for piece in _all_pieces():
		piece.label.offset = LABEL_NUDGES.get(str(piece.name), Vector2.ZERO)


func _add_lights() -> void:
	# The oil lamp over the table does most of the work.
	lamp = FlickerLight.new()
	lamp.name = "Lamp"
	lamp.base_energy = LAMP_ENERGY
	lamp.flicker = 0.06
	lamp.light_color = Color("ffc27c")
	lamp.omni_range = 7.5
	lamp.omni_attenuation = 1.1
	# Hung just under the brass font, so the lamp's own bowl doesn't shadow the map.
	lamp.position = L.LAMP + Vector3(0, -0.2, 0)
	add_child(lamp)
	# Cold winter light through the windows.
	for at: Vector3 in L.WINDOWS:
		var spot := SpotLight3D.new()
		spot.light_color = Color("8ea4d6")
		spot.light_energy = 1.4
		spot.spot_range = 5.5
		spot.spot_angle = 38.0
		spot.add_to_group(GraphicsQuality.LIGHTS_ABOVE_LOW)
		add_child(spot)
		spot.look_at_from_position(at + Vector3(0.2, 0.3, 0), at + Vector3(2.5, -1.75, 0))
	add_to_group(GraphicsQuality.LISTENERS)


## Called by GraphicsQuality: the lamp only casts shadows above Low.
func apply_quality(level: int) -> void:
	lamp.shadow_enabled = level != GraphicsQuality.Level.LOW


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a0807")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a4c5c")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 0.5
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# GraphicsQuality wants a sun; indoors there isn't one, so it gets a dark stand-in.
	var sun := DirectionalLight3D.new()
	sun.name = "NoSun"
	sun.visible = false
	add_child(sun)
	add_child(GraphicsQuality.new(env, sun))
