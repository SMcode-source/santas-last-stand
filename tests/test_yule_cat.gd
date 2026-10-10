extends TestCase
## The rules behind Level 4: stay unseen, win the Yule Lads over, and put red
## caps on the elves before the run past the Yule Cat.

const ROUTE := 98.0
const RUN := 5.4


func test_a_glimpse_does_not_raise_the_alarm() -> void:
	var meter := StealthMeter.new()
	var far := StealthMeter.strength(8.0, 9.0, false)
	for k in 30:
		meter.update(1.0 / 60.0, {"stubby": far})
	check(not meter.is_full(), "half a second at the edge of sight is fine (%.2f)" % meter.level)
	for k in 120:
		meter.update(1.0 / 60.0, {})
	check_eq(meter.level, 0.0, "and it drains away out of sight")


func test_staying_in_view_raises_the_alarm() -> void:
	var meter := StealthMeter.new()
	var near := StealthMeter.strength(2.0, 9.0, false)
	var seconds := 0.0
	while not meter.update(1.0 / 60.0, {"stubby": near}) and seconds < 10.0:
		seconds += 1.0 / 60.0
	check(seconds < 1.2, "close up he's found in about a second (%.2f s)" % seconds)
	check_eq(meter.last_source, "stubby", "and we know who spotted him")


func test_sneaking_buys_time() -> void:
	var walking := StealthMeter.strength(5.0, 9.0, false)
	var sneaking := StealthMeter.strength(5.0, 9.0, true)
	check(sneaking < walking * 0.6, "sneaking is much harder to see")
	check_eq(StealthMeter.strength(9.5, 9.0, false), 0.0, "out of range is unseen")


func test_three_treasures_start_a_mutiny() -> void:
	var crew := YuleLadCrew.new()
	check(crew.is_watching("spoon_licker"), "the Lads start out watching")
	check_eq(crew.give_back("spoon_licker"), "", "nothing to give back yet")
	check(crew.pick_up("spoon"), "a treasure is picked up")
	check(not crew.pick_up("spoon"), "only once")
	check(crew.carries_for("spoon_licker"), "Santa has Spoon-Licker's spoon")
	check(not crew.carries_for("pot_scraper"), "but not Pot-Scraper's pot")
	check_eq(crew.give_back("spoon_licker"), "spoon", "and gives it back")
	check(not crew.is_watching("spoon_licker"), "Spoon-Licker stops watching")
	check(crew.is_watching("stubby"), "the others still watch")
	for t: String in ["pot", "candle"]:
		crew.pick_up(t)
	crew.give_back("pot_scraper")
	check(not crew.mutiny, "two isn't enough")
	crew.give_back("candle_stealer")
	check(crew.mutiny, "three starts the mutiny")
	for spec: Dictionary in YuleLadCrew.LADS:
		check(not crew.is_watching(spec["id"]), "%s has downed tools" % spec["english"])


func test_every_treasure_has_an_owner() -> void:
	for treasure: String in YuleLadCrew.TREASURES:
		var owner: String = YuleLadCrew.TREASURES[treasure]["owner"]
		check(not YuleLadCrew.lad_spec(owner).is_empty(), "%s belongs to a real Lad" % treasure)
		check_eq(YuleLadCrew.treasure_of(owner), treasure, "and back again")
	check(YuleLadCrew.TREASURES.size() >= YuleLadCrew.MUTINY_AT + 2, "spare treasures to choose from")


func test_door_slammer_can_be_shut_in() -> void:
	var crew := YuleLadCrew.new()
	check(crew.shut_in("door_slammer"), "the door is barred")
	check(not crew.is_watching("door_slammer"), "and he sees nothing")
	var saved := YuleLadCrew.from_dict(crew.to_dict())
	check_eq(saved.moods["door_slammer"], YuleLadCrew.Mood.SHUT_IN, "a checkpoint remembers it")


func test_without_caps_the_cat_takes_too_many_elves() -> void:
	for caps in 4:
		var chase := _run(caps, ROUTE, 0.0)
		check(chase.failed(), "%d caps: %d elves lost" % [caps, chase.lost_count()])
		check(not chase.santa_caught, "Santa himself outruns it")


func test_with_four_caps_the_run_can_be_won() -> void:
	var four := _run(4, ROUTE, 0.0)
	check(not four.failed(), "4 caps: %d elves lost" % four.lost_count())
	var six := _run(6, ROUTE, 0.0)
	check_eq(six.lost_count(), 0, "6 caps: nobody lost")
	check(not six.santa_caught, "and Santa gets away")


func test_stopping_lets_the_cat_catch_santa() -> void:
	var chase := _run(6, ROUTE, 30.0)
	check(chase.santa_caught, "standing still for long is fatal")


func test_a_snowball_stuns_the_cat() -> void:
	var chase := CatChase.new(0, Vector3.ZERO)
	check(not chase.stun(), "nothing to stun before it lands")
	chase.release_cat()
	check(chase.stun(), "a snowball stops it")
	check(not chase.stun(), "but not again straight away")


func test_the_trail_is_followed() -> void:
	var chase := CatChase.new(0, Vector3.ZERO)
	chase.record(Vector3(0, 0, 4))
	chase.record(Vector3(3, 0, 4))
	check(chase.position_at(2.0).is_equal_approx(Vector3(0, 0, 2)), "halfway up the first leg")
	check(chase.position_at(5.5).is_equal_approx(Vector3(1.5, 0, 4)), "round the corner")
	check(chase.position_at(99.0).is_equal_approx(Vector3(3, 0, 4)), "never past Santa")


## Santa runs straight along `route` metres (standing still for `stop`
## seconds halfway); the Cat lands once the last elf is 12 m out (the cave
## mouth).
static func _run(caps: int, route: float, stop: float) -> CatChase:
	var chase := CatChase.new(caps, Vector3.ZERO)
	var dt := 1.0 / 60.0
	var z := 0.0
	var paused := 0.0
	for frame in 60 * 60:
		if z >= route * 0.5 and paused < stop:
			paused += dt
		else:
			z = minf(route, z + RUN * dt)
		chase.record(Vector3(0, 0, z))
		if not chase.cat_on and chase.last_elf_s() >= 12.0:
			chase.release_cat()
		chase.update(dt)
		if chase.santa_caught or z >= route:
			break
	return chase
