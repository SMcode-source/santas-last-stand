extends TestCase
## The rules behind Level 3: Scrooge can't be outbid, but he can be out-kinded.


func test_bidding_is_always_outbid_and_the_deposit_is_lost() -> void:
	var m := PaperMarket.new()
	var deposit := m.bid_deposit(0)
	var price: int = m.towns[0]["price"]
	check_eq(m.bid(0), deposit, "the deposit goes")
	check_eq(m.coins, PaperMarket.START_COINS - deposit, "out of Santa's purse")
	check_eq(m.towns[0]["owner"], PaperMarket.Owner.SCROOGE, "and Scrooge keeps the factory")
	check(m.towns[0]["price"] > price, "at a higher price")


func test_a_bidding_war_goes_bankrupt() -> void:
	var m := PaperMarket.new()
	var events := _play(m, _bid_everything)
	check(m.is_bankrupt(), "bidding against Golden Tower money ruins him")
	check(m.day <= 3, "and quickly (day %d)" % m.day)
	check_eq(events[-1]["kind"], "bankrupt", "the chapter ends there")


func test_doing_nothing_loses_the_vote() -> void:
	var m := PaperMarket.new()
	var events := _play(m, func(_m: PaperMarket) -> void: pass)
	check(not m.is_bankrupt(), "standing still doesn't ruin him (coins %d)" % m.coins)
	check_eq(events[-1]["kind"], "deadline", "the deadline comes")
	check(not m.vote_won(), "and the shareholders side with Scrooge")


func test_generosity_wins_the_towns_and_the_vote() -> void:
	var m := PaperMarket.new()
	var events := _play(m, _be_generous)
	check(not m.is_bankrupt(), "kindness stays solvent (coins %d)" % m.coins)
	check(m.vote_won(), "the vote is carried (%s of %d needed, %d towns)" % [m.votes(), m.votes_needed(), m.towns_won()])
	check(events[-1]["kind"] in ["all_won", "deadline"], "it ends at the vote")
	# It shouldn't be a walkover: some days to spare, not half the month.
	check(m.day >= 8, "takes most of the fortnight (won on day %d)" % m.day)


func test_kindness_strikes_then_joins_and_repeats_are_weaker() -> void:
	var m := PaperMarket.new()
	m.give(2, "meals")
	var after_one: float = m.towns[2]["goodwill"]
	m.give(2, "meals")
	check_eq(m.towns[2]["goodwill"] - after_one, PaperMarket.KINDNESS["meals"][1] * PaperMarket.REPEAT, "soup twice running is less welcome")
	m.towns[2]["goodwill"] = PaperMarket.GOODWILL_TO_STRIKE
	var events := m.end_day()
	check_eq(m.towns[2]["owner"], PaperMarket.Owner.STRIKE, "a warm enough town strikes")
	check(events.any(func(e: Dictionary) -> bool: return e["kind"] == "strike"), "the strike is news")
	m.end_day()
	check_eq(m.towns[2]["owner"], PaperMarket.Owner.SANTA, "and comes over the next day")


func test_scrooge_cools_the_warmest_town_and_shells_take_suppliers() -> void:
	var m := PaperMarket.new()
	m.towns[1]["goodwill"] = 60.0
	m.towns[3]["goodwill"] = 50.0
	m.end_day()
	check_eq(m.towns[1]["goodwill"], 60.0 - PaperMarket.SCROOGE_BONUS, "his pittance goes to the warmest town")
	check_eq(m.towns[3]["goodwill"], 50.0, "only that one")
	m.end_day()
	m.end_day()
	check_eq(m.suppliers.count(PaperMarket.Owner.SCROOGE), 1, "on day 3 a shell company takes a supplier")
	check_eq(m.suppliers[0], PaperMarket.Owner.SCROOGE, "the dearest one left")


func test_checkpoint_round_trip_and_cocoa() -> void:
	var m := PaperMarket.new()
	m.give(0, "wages")
	m.build_mill(1)
	m.end_day()
	var copy := PaperMarket.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check_eq(copy.to_dict(), m.to_dict(), "a saved market comes back the same")
	var cocoa := PaperMarket.new(int(Balance.scaled(PaperMarket.DAYS, "timer", true)), int(Balance.scaled(PaperMarket.START_COINS, "health", true)))
	check(cocoa.days > PaperMarket.DAYS and cocoa.coins > PaperMarket.START_COINS, "Cocoa Mode gives more days and coins")


# --- Strategies ---

static func _play(m: PaperMarket, strategy: Callable) -> Array[Dictionary]:
	for guard in 40:
		strategy.call(m)
		var events := m.end_day()
		for e in events:
			if e["kind"] in ["bankrupt", "deadline", "all_won"]:
				return events
	return []


static func _bid_everything(m: PaperMarket) -> void:
	for i in m.towns.size():
		while m.can_bid(i):
			m.bid(i)


## Pepper's advice: builds mills and buys suppliers early, then showers
## kindness on one town at a time, keeping enough back to pay the day's bills.
static func _be_generous(m: PaperMarket) -> void:
	while m.actions > 0:
		var move := m.advice()
		if move.is_empty() or not m.take(move):
			return
