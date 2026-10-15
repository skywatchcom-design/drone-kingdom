class_name Pvp
extends RefCounted
## Attacks between players (owner's picks, 15.10.2026, sketch NW7rzSLQsYyZ2g54BgcdTx): search with
## "Next", Noa's welcome-back with a defense log and a damage map, and the soft rules below.
## The server side is supabase/migrations/20261015_pvp.sql; trophy_change mirrors pvp_trophies().
## No autoload names here (the tests run without them); Cloud.next_base does the search.

const _State := preload("res://scripts/autoload/game_state.gd")

## What an attacker can take: this share of the defender's bank, plus this share of what waits
## uncollected in their generators and pumps.
const BANK_SHARE := 0.1
const PENDING_SHARE := 0.5
const SHIELD_HOURS := 8
## Bases below this Command Tower level are never attacked.
const PROTECTED_BELOW := 2
## Coins for skipping to another base before the first unit goes in.
const NEXT_COST := 20
## Leagues by trophies, lowest first: [name, trophies needed, badge color].
const LEAGUES := [
	["Recruit", 0, Color(0.55, 0.58, 0.52)],
	["Bronze", 100, Color(0.72, 0.45, 0.22)],
	["Silver", 300, Color(0.7, 0.74, 0.8)],
	["Gold", 600, Color(0.95, 0.72, 0.15)],
	["Platinum", 1000, Color(0.45, 0.8, 0.85)],
	["Diamond", 1500, Color(0.55, 0.6, 1.0)],
]


## The attacker's trophy change for `stars` (positive for a win). Same as pvp_trophies() on the server.
static func trophy_change(stars: int, mine: int, theirs: int) -> int:
	var edge := clampi(floori((theirs - mine) / 20.0), -8, 8)
	if stars > 0:
		return clampi(16 + 4 * stars + edge, 10, 40)
	return -clampi(12 - edge, 5, 20)


## The defender's side of the same attack.
static func defender_change(attacker_change: int) -> int:
	return -roundi(attacker_change * 0.6) if attacker_change > 0 else -attacker_change


static func league(trophies: int) -> Array:
	var best: Array = LEAGUES[0]
	for l: Array in LEAGUES:
		if trophies >= int(l[1]):
			best = l
	return best


## "Bronze League", in the player's language.
static func league_name(trophies: int) -> String:
	return I18n.t("%s League") % I18n.t(league(trophies)[0])


## Coins or fuel waiting in a base's generators (`fuel` false) or pumps, at unix time `now`.
static func pending(structures: Array, fuel: bool, now: float) -> int:
	var total := 0
	for s in structures:
		if s.get("fresh", false) or s.get("type") != ("pump" if fuel else "generator"):
			continue
		var minutes := clampf((now - float(s.get("collected_at", now))) / 60.0, 0.0, Catalog.GENERATOR_FILL_MINUTES)
		total += int(_State.producer_rate(s) * minutes)
	return total


## {coins, fuel} an attacker could take from a base with this bank, at unix time `now`.
static func loot_pool(structures: Array, bank_coins: int, bank_fuel: int, now: float) -> Dictionary:
	return {
		"coins": int(bank_coins * BANK_SHARE) + int(pending(structures, false, now) * PENDING_SHARE),
		"fuel": int(bank_fuel * BANK_SHARE) + int(pending(structures, true, now) * PENDING_SHARE),
	}


## Splits a loot pool over the buildings that hold it, in proportion to what each would give in a
## normal raid (coins: Command Tower, generators, silos; fuel: Command Tower, pumps, tanks).
## `targets` are {type, level}; returns [coins, fuel] per target, in the same order.
static func share_loot(targets: Array, pool: Dictionary) -> Array:
	var weights := [0.0, 0.0]
	for t in targets:
		weights[0] += Catalog.loot_value(t["type"], int(t["level"]))
		weights[1] += Catalog.loot_fuel(t["type"], int(t["level"]))
	var out := []
	for t in targets:
		var c := 0
		var f := 0
		if weights[0] > 0.0:
			c = int(int(pool["coins"]) * Catalog.loot_value(t["type"], int(t["level"])) / weights[0])
		if weights[1] > 0.0:
			f = int(int(pool["fuel"]) * Catalog.loot_fuel(t["type"], int(t["level"])) / weights[1])
		out.append([c, f])
	return out


## A server opponent row (find_opponent) as a base for the battle, in the Bases format, plus
## {player_id, trophies, hq_level, loot_pool}. Structures still being built for the first time are left out.
static func base_from_row(row: Dictionary, now: float) -> Dictionary:
	var structures := []
	for s in row.get("structures", []):
		if not (s is Dictionary) or s.get("fresh", false) or not s.has("type") or not s.has("cell"):
			continue
		var clean := {"type": str(s["type"]), "cell": [int(s["cell"][0]), int(s["cell"][1])], "level": int(s.get("level", 1))}
		clean["type"] = _State.RETIRED.get(clean["type"], clean["type"])
		if s.has("collected_at"):
			clean["collected_at"] = float(s["collected_at"])
		structures.append(clean)
	var walls := []
	for w in row.get("walls", []):
		walls.append({"edge": [int(w["edge"][0]), int(w["edge"][1]), int(w["edge"][2])], "level": int(w["level"])})
	return {
		"name": str(row.get("name", "")),
		"seed": int(row.get("city_seed", 7)),
		"pad": [City.GRID - 1, City.GRID - 1],
		"structures": structures,
		"walls": walls,
		"player_id": str(row.get("id", "")),
		"trophies": int(row.get("trophies", 0)),
		"hq_level": int(row.get("hq_level", 1)),
		"loot_pool": loot_pool(structures, int(row.get("coins", 0)), int(row.get("fuel", 0)), now),
	}


## An Iron Fang outpost for when no player is free to attack: a generated base at the player's level.
static func outpost(seed_value: int, hq: int) -> Dictionary:
	var b := Bases.generate(seed_value, clampi(hq, 1, Catalog.MAX_LEVEL))
	b["name"] = I18n.t("Iron Fang outpost")
	b["outpost"] = true
	return b


## Noa's advice under the damage map, from an attack's report.
static func tip(attack: Dictionary) -> String:
	var report: Dictionary = attack.get("report", {})
	var hits := 0
	for t in report.get("traps", []):
		hits += int(t.get("hits", 0))
	if hits > 0:
		return I18n.t("Noa: \"Our trap caught %d of them. More traps on that side!\"") % hits
	if int(attack.get("stars", 0)) == 0:
		return I18n.t("Noa: \"They didn't get a single star. The defenses held!\"")
	if (report.get("destroyed", []) as Array).size() > 0 and (report.get("walls", []) as Array).is_empty():
		return I18n.t("Noa: \"They walked right in where the arrow starts. Walls there would slow them down.\"")
	return I18n.t("Noa: \"Upgrade the defenses near the arrow. That's where they broke through.\"")
