extends TestCase
## The rules behind Level 1: the Cold meter, and the Jack Frost fight that
## can only be won with steam from the pipes, never by brute force.


func test_cold_meter_drains_in_the_cold_and_refills_by_a_fire() -> void:
	var cold := ColdMeter.new(40.0, 0.5)
	for i in 200:
		cold.update(0.1, 0.0)
	check(is_equal_approx(cold.value, 0.5), "20 s of a 40 s meter leaves half")
	cold.update(1.0, 1.0)
	check(is_equal_approx(cold.value, 1.0), "a second by the fire fills it")
	cold.update(10.0, 0.0, 2.0)
	check(is_equal_approx(cold.value, 0.5), "a blizzard drains twice as fast")
	cold.hit(0.3)
	check(cold.is_freezing() and not cold.is_frozen(), "an ice shard leaves him freezing")
	cold.update(100.0, 0.0)
	check(cold.is_frozen(), "out in the cold long enough, he freezes")


func test_frost_shrugs_off_blows_in_his_armour() -> void:
	var fight := FrostFight.new(3)
	for i in 10:
		check(not fight.strike(), "blow %d bounces off" % i)
		fight.update(0.5)
	check_eq(fight.phase, 0, "no phase won by punching")


func test_steam_on_the_wrong_gear_does_nothing() -> void:
	var fight := FrostFight.new(3)
	fight.frost_gear = 0
	fight.next_hop = 99.0
	fight.crank()
	_run(fight, FrostFight.SWING_TIME + 0.1)
	check_eq(fight.hand, 1, "the hand reached pipe 1")
	check(not fight.is_exposed(), "Frost on gear 0 is untouched")


func test_three_phases_of_steam_and_a_blow_beat_him() -> void:
	var fight := FrostFight.new(5)
	var spent_pipes := []
	for phase in 3:
		# Wait for the hand to point at a hot pipe with Frost on its gear.
		var tries := 0
		while not fight.is_exposed() and tries < 400:
			tries += 1
			if not fight.swinging:
				# Crank only when the next pipe is the gear he is on or about
				# to land on: reading his warning, as a player would.
				var target := (fight.hand + 1) % FrostFight.GEARS
				if not fight.spent[target] and (fight.frost_gear == target or fight.next_gear == target):
					fight.crank()
				elif fight.spent[target] or (fight.frost_gear != target and fight.next_gear != target):
					fight.crank()
			fight.update(0.1)
		check(fight.is_exposed(), "phase %d: steam strips his armour" % (phase + 1))
		spent_pipes.append(fight.hand)
		check(fight.strike(), "phase %d: the blow lands" % (phase + 1))
		check(not fight.strike(), "his armour is back after the blow")
	check(fight.is_over(), "beaten after three phases")
	spent_pipes.sort()
	check_eq(spent_pipes, [0, 1, 2], "each pipe used once")


func test_he_hops_faster_each_phase() -> void:
	var fight := FrostFight.new(2)
	var first := fight.next_hop
	fight.exposed = 1.0
	fight.strike()
	check(fight.next_hop < first, "phase 2 hops come quicker")
	var gentle := FrostFight.new(2, 1.4)
	check(gentle.next_hop > first, "Cocoa Mode slows him down")


func _run(fight: FrostFight, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		fight.update(0.05)
		t += 0.05


func test_each_furnace_flue_meets_its_pipe() -> void:
	var layout := preload("res://levels/01_frozen_workshop/workshop_layout.gd")
	for id: String in layout.FURNACES:
		var spec: Array = layout.FURNACES[id]
		var pose := Transform3D(Basis(Vector3.UP, deg_to_rad(spec[1])), spec[0])
		var flue := pose * Furnace.FLUE_END
		var pipe_start: Vector3 = layout.PIPE_RUNS[id][0]
		check(flue.distance_to(pipe_start) < 0.05, "%s flue %s meets its pipe at %s" % [id, flue, pipe_start])
		var front := pose.basis * Vector3.BACK
		var to_terrace := (Vector3(0, spec[0].y, 0) - (spec[0] as Vector3)).normalized()
		check(front.dot(to_terrace) > 0.9, "%s furnace faces back towards the workshop" % id)


func test_clock_gears_are_apart_and_the_hand_turns_once_round() -> void:
	var layout := preload("res://levels/01_frozen_workshop/workshop_layout.gd")
	var turn := 0.0
	for i in FrostFight.GEARS:
		var next := (i + 1) % FrostFight.GEARS
		var gap := layout.gear_centre(i).distance_to(layout.gear_centre(next)) - layout.GEAR_RADIUS * 2.0
		check(gap > 0.3, "gears %d and %d don't overlap (gap %.2f)" % [i, next, gap])
		turn += fposmod(layout.GEAR_ANGLES[next] - layout.GEAR_ANGLES[i], 360.0)
	check(is_equal_approx(turn, 360.0), "pipe to pipe, the hand goes once round, clockwise")


func test_climb_movers_link_their_stubs() -> void:
	var movers: Array = WorkshopSet.climb_movers()
	check_eq(movers.size(), 2, "two moving platforms on the climb")
	for spec: Array in movers:
		var offset: Vector3 = spec[1]
		check(Vector2(offset.x, offset.z).length() > 2.0, "each one travels between its stubs")
