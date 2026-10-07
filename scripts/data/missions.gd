class_name Missions
extends RefCounted
## Missions after Noa's tutorial (approved sketch Tnvwhfaq4KMqSS85z45tfx): twelve starter missions
## in three days (a day opens once the one before is all claimed), three daily missions picked
## from a pool each day, and a seven-day login gift. GameState keeps the progress.
##
## A mission's "check" says how progress is measured:
##   ["hq", n]              Command Tower level
##   ["count", type, n]     how many of a structure are built
##   ["level", type, n]     the best level of a structure
##   ["walls", n]           wall pieces
##   ["unit", type]         a unit unlocked
##   ["mission", index]     an Iron Fang mission won
##   ["stars", n]           Iron Fang stars in total
##   ["stat", key, n]       a counter in GameState.stats (daily ones count from the day's start)

const STARTER := [
	{"day": 1, "pic": ["hq", 2], "text": "Upgrade the Command Tower to Lv 2", "check": ["hq", 2], "reward": {"gems": 30}},
	{"day": 1, "pic": ["generator", 1], "text": "Build a second Solar Generator", "check": ["count", "generator", 2], "reward": {"coins": 300}},
	{"day": 1, "pic": ["storage", 1], "text": "Build a Coin Silo", "check": ["count", "storage", 1], "reward": {"gems": 20}},
	{"day": 1, "pic": ["infantry", 1], "text": "Train 3 Infantry Squads", "check": ["stat", "train_infantry", 3], "reward": {"fuel": 200}},
	{"day": 2, "pic": ["pump", 1], "text": "Win Iron Fang mission 2", "check": ["mission", 1], "reward": {"fuel": 300}},
	{"day": 2, "pic": ["at", 1], "text": "Build an Anti-Tank Gun", "check": ["count", "at", 1], "reward": {"coins": 300}},
	{"day": 2, "pic": ["mg", 2], "text": "Upgrade the MG Nest to Lv 2", "check": ["level", "mg", 2], "reward": {"gems": 20}},
	{"day": 2, "pic": ["wall", 2], "text": "Build 10 wall pieces", "check": ["walls", 10], "reward": {"coins": 300}},
	{"day": 3, "pic": ["infantry", 2], "text": "Win a raid on another base", "check": ["stat", "raid_win", 1], "reward": {"gems": 30}},
	{"day": 3, "pic": ["engineers", 1], "text": "Unlock Combat Engineers in the Garage", "check": ["unit", "engineers"], "reward": {"fuel": 300}},
	{"day": 3, "pic": ["hq", 3], "text": "Upgrade the Command Tower to Lv 3", "check": ["hq", 3], "reward": {"gems": 50}},
	{"day": 3, "pic": ["hq", 3], "text": "Earn 10 stars in the Iron Fang campaign", "check": ["stars", 10], "reward": {"gems": 100, "coins": 1000}},
]

## Three of these are picked each day.
const DAILY := {
	"collect_coins": {"pic": ["generator", 1], "text": "Collect 1,000 coins", "check": ["stat", "coins_collected", 1000], "reward": {"coins": 150}},
	"collect_fuel": {"pic": ["pump", 1], "text": "Collect 500 fuel", "check": ["stat", "fuel_collected", 500], "reward": {"fuel": 150}},
	"win": {"pic": ["infantry", 1], "text": "Win a battle", "check": ["stat", "win", 1], "reward": {"fuel": 150}},
	"three_stars": {"pic": ["hq", 1], "text": "Win a battle with 3 stars", "check": ["stat", "three_stars", 1], "reward": {"gems": 10}},
	"train": {"pic": ["courier", 1], "text": "Train 5 units", "check": ["stat", "train", 5], "reward": {"coins": 150}},
	"upgrade": {"pic": ["mg", 2], "text": "Upgrade any building", "check": ["stat", "upgrade", 1], "reward": {"gems": 5}},
	"build": {"pic": ["generator", 1], "text": "Build a new building", "check": ["stat", "build", 1], "reward": {"coins": 150}},
}
const DAILY_PICKS := 3
## Gems for finishing all of the day's missions.
const DAILY_BONUS := 10

## The login gift for each day of the week; after day 7 it starts over.
const LOGIN := [{"coins": 200}, {"fuel": 200}, {"gems": 10}, {"coins": 400}, {"fuel": 400}, {"gems": 20}, {"gems": 50}]


## The daily missions for a date string ("2026-10-07"): the same three all day for everyone.
static func daily_keys(date: String) -> Array:
	var keys: Array = DAILY.keys()
	keys.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var picked := []
	while picked.size() < DAILY_PICKS:
		var k: String = keys[rng.randi_range(0, keys.size() - 1)]
		if not picked.has(k):
			picked.append(k)
	return picked
