class_name PaperMarket
extends RefCounted
## Level 3's economy: twelve days to win the world's wrapping paper back from
## Scrooge & Co. before the shipping deadline.
##
## Santa has a purse of coins and three actions a day. Scrooge owns the five
## factory towns, and Golden Tower money behind him is bottomless: bid for a
## factory and he always outbids you, and the deposit is gone. What he
## doesn't do is pay his workers (wages "at 1842 rates"). Kindness wins them:
## top up their wages, bring toys for their children, feed them warm meals.
## When a town's goodwill reaches 100 it strikes, and the day after it comes
## over to Santa. Scrooge fights back by tossing a few coins to whichever
## town is warmest to Santa, and his shell companies snap up any supplier
## left unclaimed.
##
## Santa pays for it all with elf paper mills (built on his own land) and the
## suppliers he buys before Scrooge does. Coins below zero at the end of a day
## and he's bankrupt. At the deadline (or as soon as every town is his) the
## shareholders vote: towns are 2 votes, suppliers 1, and Scrooge holds 2
## proxies of his own.

enum Owner {SCROOGE, STRIKE, SANTA, FREE}

const DAYS := 12
const ACTIONS := 3
const START_COINS := 60
## North Pole donations each day, and the elves' keep.
const BASE_INCOME := 4
const UPKEEP := 9
const TOWN_INCOME := 6
const MILL_INCOME := 7
const MILL_COST := 20
const GOODWILL_TO_STRIKE := 100.0
## Kindnesses: [coins, goodwill]. Wages are raised once for good (then they
## warm the town every day, and cost a little every day).
const KINDNESS := {"wages": [14, 25.0], "toys": [9, 20.0], "meals": [5, 12.0]}
const WAGES_DAILY_GOODWILL := 6.0
const WAGES_DAILY_COST := 2
## The same kindness twice running in one town only does this much.
const REPEAT := 0.5
## A bid forfeits this share of the asking price, and Scrooge's counter-bid
## raises the price this much.
const BID_DEPOSIT := 0.3
const BID_RAISE := 1.6
## Scrooge's daily coin-toss to the town warmest to Santa (once it's this warm).
const SCROOGE_BONUS := 10.0
const BONUS_FROM := 35.0
## Days his shell companies buy up the best supplier still on the market.
const SHELL_DAYS := [3, 6, 9]
const TOWN_VOTES := 2
const SUPPLIER_VOTES := 1
const SCROOGE_PROXIES := 2

const TOWNS := [
	{"id": "smogbury", "name": "Smogbury", "place": "England", "price": 80, "letter": true},
	{"id": "grimsdale", "name": "Grimsdale", "place": "Pennsylvania", "price": 90, "letter": false},
	{"id": "kaltenbach", "name": "Kaltenbach", "place": "Germany", "price": 70, "letter": false},
	{"id": "papelopolis", "name": "Papelópolis", "place": "Brazil", "price": 75, "letter": false},
	{"id": "sumi", "name": "Sumi Harbour", "place": "Japan", "price": 85, "letter": false},
]
const SUPPLIERS := [
	{"id": "pulp", "name": "Northwoods Pulp", "place": "Canada", "price": 16, "income": 4},
	{"id": "ink", "name": "Indigo Ink Works", "place": "India", "price": 13, "income": 3},
	{"id": "ribbon", "name": "Silk Road Ribbons", "place": "China", "price": 10, "income": 3},
]
const MILL_SITES := [
	{"id": "lapland", "name": "Lapland", "place": "Finland"},
	{"id": "iceland", "name": "Reykjavík", "place": "Iceland"},
	{"id": "alaska", "name": "Nome", "place": "Alaska"},
]

var days := DAYS
var day := 1
var coins := START_COINS
var actions := ACTIONS
## Per town: {"owner", "goodwill", "price", "wages", "last", "bids"}
var towns: Array[Dictionary] = []
var suppliers: Array[int] = []
var mills: Array[bool] = []
## How many times Santa has bid for a factory (for Pepper's hint).
var bids := 0


func _init(day_count := DAYS, purse := START_COINS) -> void:
	days = day_count
	coins = purse
	for spec: Dictionary in TOWNS:
		towns.append({"owner": Owner.SCROOGE, "goodwill": 0.0, "price": int(spec["price"]), "wages": false,
				"last": "", "bids": 0})
	for spec in SUPPLIERS:
		suppliers.append(Owner.FREE)
	for spec in MILL_SITES:
		mills.append(false)


# --- What Santa can do ---

## What a kindness costs in town `i` (0 if it can't be done there).
func kindness_cost(i: int, kind: String) -> int:
	var town := towns[i]
	if town["owner"] != Owner.SCROOGE or (kind == "wages" and town["wages"]):
		return 0
	return KINDNESS[kind][0]


## How much goodwill a kindness would earn in town `i` now.
func kindness_worth(i: int, kind: String) -> float:
	var worth: float = KINDNESS[kind][1]
	return worth * REPEAT if towns[i]["last"] == kind else worth


func can_give(i: int, kind: String) -> bool:
	var cost := kindness_cost(i, kind)
	return cost > 0 and actions > 0 and coins >= cost


func give(i: int, kind: String) -> bool:
	if not can_give(i, kind):
		return false
	var town := towns[i]
	coins -= kindness_cost(i, kind)
	town["goodwill"] = minf(GOODWILL_TO_STRIKE, town["goodwill"] + kindness_worth(i, kind))
	town["last"] = kind
	if kind == "wages":
		town["wages"] = true
	actions -= 1
	return true


func bid_deposit(i: int) -> int:
	return int(ceil(towns[i]["price"] * BID_DEPOSIT))


func can_bid(i: int) -> bool:
	return towns[i]["owner"] == Owner.SCROOGE and actions > 0 and coins >= bid_deposit(i)


## Santa bids the asking price for a factory. Golden Tower Holdings always
## outbids him: the deposit is forfeit and the price goes up. Returns the
## coins lost (0 if he couldn't bid).
func bid(i: int) -> int:
	if not can_bid(i):
		return 0
	var lost := bid_deposit(i)
	coins -= lost
	towns[i]["price"] = int(towns[i]["price"] * BID_RAISE)
	towns[i]["bids"] += 1
	bids += 1
	actions -= 1
	return lost


func can_buy_supplier(i: int) -> bool:
	return suppliers[i] == Owner.FREE and actions > 0 and coins >= SUPPLIERS[i]["price"]


func buy_supplier(i: int) -> bool:
	if not can_buy_supplier(i):
		return false
	coins -= SUPPLIERS[i]["price"]
	suppliers[i] = Owner.SANTA
	actions -= 1
	return true


func can_build_mill(i: int) -> bool:
	return not mills[i] and actions > 0 and coins >= MILL_COST


func build_mill(i: int) -> bool:
	if not can_build_mill(i):
		return false
	coins -= MILL_COST
	mills[i] = true
	actions -= 1
	return true


# --- Pepper's advice ---

## A sensible next move: build the elf mills and buy suppliers in the first
## days, then shower kindness on the warmest town, keeping enough back to pay
## the day's bills. {"do": "mill"/"supplier"/"give", "at": index, "kind": ...},
## or {} when it's time to end the day.
func advice() -> Dictionary:
	if actions <= 0:
		return {}
	var reserve := maxi(0, -income())
	if day <= 3:
		var site := mills.find(false)
		if site >= 0 and can_build_mill(site) and coins - MILL_COST >= reserve:
			return {"do": "mill", "at": site}
		for i in suppliers.size():
			if can_buy_supplier(i) and coins - int(SUPPLIERS[i]["price"]) >= reserve:
				return {"do": "supplier", "at": i}
	var target := -1
	for i in towns.size():
		if towns[i]["owner"] == Owner.SCROOGE and (target < 0 or towns[i]["goodwill"] > towns[target]["goodwill"]):
			target = i
	if target < 0:
		return {}
	for kind: String in ["wages", "toys", "meals"]:
		var cost := kindness_cost(target, kind)
		var keep := reserve + (WAGES_DAILY_COST if kind == "wages" else 0)
		if cost > 0 and towns[target]["last"] != kind and coins - cost >= keep and can_give(target, kind):
			return {"do": "give", "at": target, "kind": kind}
	return {}


## Makes a move as advice() describes it (or "bid"). False if it can't be done.
func take(move: Dictionary) -> bool:
	match str(move.get("do", "")):
		"mill":
			return build_mill(int(move["at"]))
		"supplier":
			return buy_supplier(int(move["at"]))
		"give":
			return give(int(move["at"]), str(move["kind"]))
		"bid":
			return bid(int(move["at"])) > 0
	return false


# --- The end of each day ---

## Coins coming in (and going out) at the end of today, as things stand.
func income() -> int:
	var total := BASE_INCOME - UPKEEP
	for town in towns:
		if town["owner"] == Owner.SANTA:
			total += TOWN_INCOME
		elif town["owner"] == Owner.SCROOGE and town["wages"]:
			total -= WAGES_DAILY_COST
	for i in suppliers.size():
		if suppliers[i] == Owner.SANTA:
			total += SUPPLIERS[i]["income"]
	for built in mills:
		if built:
			total += MILL_INCOME
	return total


## Ends the day: towns on strike come over, warm towns strike, Scrooge makes
## his moves, and the books are settled. Returns what happened, in order, as
## {"kind": ..., "town"/"supplier": index, ...} (kinds: "joined", "strike",
## "bonus", "shell", "bankrupt", "deadline", "all_won").
func end_day() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in towns.size():
		if towns[i]["owner"] == Owner.STRIKE:
			towns[i]["owner"] = Owner.SANTA
			events.append({"kind": "joined", "town": i})
	for i in towns.size():
		var town := towns[i]
		if town["owner"] != Owner.SCROOGE:
			continue
		if town["wages"]:
			town["goodwill"] = minf(GOODWILL_TO_STRIKE, town["goodwill"] + WAGES_DAILY_GOODWILL)
		if town["goodwill"] >= GOODWILL_TO_STRIKE:
			town["owner"] = Owner.STRIKE
			events.append({"kind": "strike", "town": i})
	# Scrooge tosses a few coins to the town warmest to Santa.
	var warmest := -1
	for i in towns.size():
		if towns[i]["owner"] == Owner.SCROOGE and towns[i]["goodwill"] >= BONUS_FROM \
				and (warmest < 0 or towns[i]["goodwill"] > towns[warmest]["goodwill"]):
			warmest = i
	if warmest >= 0:
		towns[warmest]["goodwill"] = maxf(0.0, towns[warmest]["goodwill"] - SCROOGE_BONUS)
		events.append({"kind": "bonus", "town": warmest})
	if day in SHELL_DAYS:
		var best := -1
		for i in suppliers.size():
			if suppliers[i] == Owner.FREE and (best < 0 or SUPPLIERS[i]["price"] > SUPPLIERS[best]["price"]):
				best = i
		if best >= 0:
			suppliers[best] = Owner.SCROOGE
			events.append({"kind": "shell", "supplier": best})
	coins += income()
	if coins < 0:
		events.append({"kind": "bankrupt"})
		return events
	if all_won():
		events.append({"kind": "all_won"})
		return events
	if day >= days:
		events.append({"kind": "deadline"})
		return events
	day += 1
	actions = ACTIONS
	return events


# --- Standing ---

func is_bankrupt() -> bool:
	return coins < 0


func towns_won() -> int:
	var won := 0
	for town in towns:
		if town["owner"] != Owner.SCROOGE:
			won += 1
	return won


func all_won() -> bool:
	return towns_won() == towns.size()


## The shareholder vote as things stand: Vector2i(for Santa, for Scrooge).
## Towns on strike vote with Santa; suppliers no one bought abstain.
func votes() -> Vector2i:
	var result := Vector2i(0, SCROOGE_PROXIES)
	for town in towns:
		if town["owner"] == Owner.SCROOGE:
			result.y += TOWN_VOTES
		else:
			result.x += TOWN_VOTES
	for owner in suppliers:
		if owner == Owner.SANTA:
			result.x += SUPPLIER_VOTES
		elif owner == Owner.SCROOGE:
			result.y += SUPPLIER_VOTES
	return result


## Votes Santa needs to carry the vote: more than half of all there are.
func votes_needed() -> int:
	var total := SCROOGE_PROXIES + TOWNS.size() * TOWN_VOTES + SUPPLIERS.size() * SUPPLIER_VOTES
	return total / 2 + 1


func vote_won() -> bool:
	return votes().x >= votes_needed()


# --- Saving at a checkpoint ---

func to_dict() -> Dictionary:
	return {"days": days, "day": day, "coins": coins, "actions": actions, "towns": towns.duplicate(true),
			"suppliers": Array(suppliers), "mills": Array(mills), "bids": bids}


static func from_dict(d: Dictionary) -> PaperMarket:
	var market := PaperMarket.new(int(d.get("days", DAYS)), int(d.get("coins", START_COINS)))
	market.day = int(d.get("day", 1))
	market.actions = int(d.get("actions", ACTIONS))
	market.bids = int(d.get("bids", 0))
	var saved_towns: Array = d.get("towns", [])
	for i in mini(saved_towns.size(), market.towns.size()):
		var t: Dictionary = saved_towns[i]
		market.towns[i] = {"owner": int(t.get("owner", Owner.SCROOGE)), "goodwill": float(t.get("goodwill", 0.0)),
				"price": int(t.get("price", TOWNS[i]["price"])), "wages": bool(t.get("wages", false)),
				"last": str(t.get("last", "")), "bids": int(t.get("bids", 0))}
	var saved_suppliers: Array = d.get("suppliers", [])
	for i in mini(saved_suppliers.size(), market.suppliers.size()):
		market.suppliers[i] = int(saved_suppliers[i])
	var saved_mills: Array = d.get("mills", [])
	for i in mini(saved_mills.size(), market.mills.size()):
		market.mills[i] = bool(saved_mills[i])
	return market
