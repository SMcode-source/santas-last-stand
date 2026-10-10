extends TestCase
## The rules behind Level 2: the parry, the sacked elves, and the Krampus
## fight that brute force can never win.


func test_parry_guard_is_brief_and_cannot_be_held_up_by_mashing() -> void:
	var guard := ParryGuard.new()
	check(guard.press(), "the first press raises the guard")
	check(guard.is_up(), "guard up")
	guard.update(ParryGuard.ACTIVE + 0.01)
	check(not guard.is_up(), "it drops after a moment")
	check(not guard.press(), "pressing again straight away does nothing")
	guard.update(ParryGuard.COOLDOWN)
	check(guard.press(), "after a breath it works again")
	guard.spend()
	check(not guard.is_up() and guard.press(), "a good parry lets him go again at once")
	var gentle := ParryGuard.new(1.5)
	gentle.press()
	gentle.update(ParryGuard.ACTIVE + 0.01)
	check(gentle.is_up(), "Cocoa Mode holds the guard longer")


func test_three_lost_sacks_fail_and_only_dropped_sacks_open() -> void:
	var run := SackRun.new(6)
	check(not run.release(0), "a hanging sack can't be opened")
	run.carry(0)
	check(not run.release(0), "nor one a helper is carrying")
	run.drop(0)
	check(run.release(0), "a dropped sack opens")
	check_eq(run.ringers(), 1, "one elf at the ropes")
	for i in [1, 2]:
		run.carry(i)
		run.escape(i)
	check(not run.is_failed(), "two lost is not yet a fail")
	run.escape(3)
	check(not run.is_failed(), "a sack nobody carried can't escape")
	run.carry(3)
	run.escape(3)
	check(run.is_failed(), "three lost fails the chapter")
	check(not run.is_settled(), "sacks 4 and 5 are still about")


func test_in_the_dark_nothing_hurts_krampus() -> void:
	var guard := ParryGuard.new()
	var fight := KrampusFight.new(guard)
	check_eq(fight.punch(), "regenerated", "a punch in the dark feeds him")
	# Parry a lash in the dark: it glances off, nothing is caught.
	_wait_for_windup(fight)
	_run(fight, fight.timer - 0.15, 2.0)
	guard.press()
	var caught := []
	fight.parried.connect(func(c: bool) -> void: caught.append(c))
	_run(fight, 2.0, 2.0)
	check_eq(caught, [false], "the chain glances off; no catch in the dark")
	check(not fight.slam(), "nothing to slam him with")
	check_eq(fight.health, KrampusFight.SLAMS, "unhurt")


func test_bells_need_enough_ringers() -> void:
	var fight := KrampusFight.new(ParryGuard.new())
	check(not fight.ring(KrampusFight.RING_NEEDED - 1), "too few elves at the ropes")
	check(fight.ring(KrampusFight.RING_NEEDED), "enough elves ring the bells")
	check(fight.lit, "the lights are on")
	check(not fight.ring(6), "they are already ringing")


func test_mashing_is_punished_even_in_the_light() -> void:
	var fight := KrampusFight.new(ParryGuard.new())
	fight.ring(6)
	check_eq(fight.punch(), "shrugged", "one punch: he laughs")
	fight.update(0.2, 9.0)
	check_eq(fight.punch(), "shrugged", "two")
	fight.update(0.2, 9.0)
	check_eq(fight.punch(), "countered", "three in a row: he shoves Santa off")
	check_eq(fight.health, KrampusFight.SLAMS, "and none of it hurt him")
	var patient := KrampusFight.new(ParryGuard.new())
	patient.ring(6)
	for i in 5:
		check_eq(patient.punch(), "shrugged", "spaced-out punch %d" % i)
		patient.update(KrampusFight.MASH_WINDOW / 2.0 + 0.05, 9.0)


func test_an_unguarded_lash_hits_and_running_off_dodges_it() -> void:
	var fight := KrampusFight.new(ParryGuard.new())
	var lashes := []
	fight.whipped.connect(func(hit: bool) -> void: lashes.append(hit))
	_wait_for_windup(fight)
	_run(fight, 2.0, 2.0)
	check_eq(lashes, [true], "standing still, the lash hits")
	_run(fight, KrampusFight.RECOVER + 0.1, 2.0)
	check_eq(fight.state, KrampusFight.State.WINDUP, "he winds up again")
	_run(fight, 2.0, KrampusFight.WHIP_REACH + 1.0)
	check_eq(lashes, [true, false], "backing out of reach dodges it")


func test_three_parry_slams_beat_him_with_the_lights_going_out_once() -> void:
	var guard := ParryGuard.new()
	var fight := KrampusFight.new(guard, 1.0)
	var outs := [0]
	fight.lights_out.connect(func() -> void: outs[0] += 1)
	var rings := 0
	for slam in KrampusFight.SLAMS:
		if not fight.lit:
			check(fight.ring(KrampusFight.RING_NEEDED), "slam %d: bells rung" % (slam + 1))
			rings += 1
		var tries := 0
		while fight.state != KrampusFight.State.CAUGHT and tries < 400:
			tries += 1
			# Raise the guard just before the lash, as a player watching the
			# wind-up would.
			var left := fight.windup_left()
			if fight.state == KrampusFight.State.WINDUP and left > 0.0 and left < 0.2:
				guard.press()
			guard.update(0.05)
			fight.update(0.05, 2.0)
		check_eq(fight.state, KrampusFight.State.CAUGHT, "slam %d: the chain is caught" % (slam + 1))
		check(fight.slam(), "slam %d lands" % (slam + 1))
		check_eq(fight.health, KrampusFight.SLAMS - slam - 1, "health after slam %d" % (slam + 1))
		_run(fight, KrampusFight.DOWN_TIME + 0.1, 9.0)
	check(fight.is_over(), "beaten after three slams")
	check_eq(outs[0], 1, "the lights went out once, after the first slam")
	check_eq(rings, 2, "so the bells were rung twice")


func test_the_enraged_phase_lashes_twice_and_cocoa_slows_him() -> void:
	var fight := KrampusFight.new(ParryGuard.new())
	fight.health = 1
	fight.lit = true
	var lashes := []
	fight.whipped.connect(func(hit: bool) -> void: lashes.append(hit))
	_wait_for_windup(fight)
	_run(fight, KrampusFight.WINDUP[2] + KrampusFight.FOLLOW_UP + 0.2, 2.0)
	check_eq(lashes.size(), 2, "two lashes per wind-up when enraged")
	var gentle := KrampusFight.new(ParryGuard.new(), 1.4)
	_wait_for_windup(gentle)
	check(gentle.timer > KrampusFight.WINDUP[0], "Cocoa Mode gives a longer wind-up")


func _wait_for_windup(fight: KrampusFight) -> void:
	var tries := 0
	while fight.state != KrampusFight.State.WINDUP and tries < 200:
		fight.update(0.05, 2.0)
		tries += 1


func _run(fight: KrampusFight, seconds: float, distance: float) -> void:
	var t := 0.0
	while t < seconds:
		if fight.guard:
			fight.guard.update(0.05)
		fight.update(0.05, distance)
		t += 0.05
