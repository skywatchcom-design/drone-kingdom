class_name Catalog
extends RefCounted
## Every number that shapes the game: costs, limits, stats per level.
## Tune here; behaviour code reads everything through these functions.

const MAX_LEVEL := 5

## Seconds in an attack once the first drone is deployed.
const BATTLE_SECONDS := 90.0
## Height of a defense's head above its roof.
const DEFENSE_HEAD := 4.5

## Hit points of every structure at level 1.
const HP := {
	"hq": 900.0, "generator": 300.0, "storage": 420.0, "hangar": 360.0,
	"laser": 480.0, "net": 440.0, "jammer": 340.0, "birds": 320.0,
}

const DEFENSES := {
	"laser": {"name": "Laser Tower", "cost": 200, "radius": 11.0, "dps": 35.0},
	"net": {"name": "Net Launcher", "cost": 250, "radius": 12.0, "speed": 16.0, "cooldown": 3.5},
	"jammer": {"name": "Jammer", "cost": 300, "radius": 8.0},
	"birds": {"name": "Gull Nest", "cost": 350, "radius": 8.0, "count": 6, "speed": 1.3, "damage": 15.0},
}

const BUILDINGS := {
	"hq": {"name": "Command Tower", "cost": 500},
	"generator": {"name": "Solar Generator", "cost": 150},
	"storage": {"name": "Coin Silo", "cost": 200},
	"hangar": {"name": "Drone Hangar", "cost": 250},
}

## Order of the build menu.
const BUILD_ORDER := ["generator", "storage", "hangar", "laser", "net", "jammer", "birds"]

## How many of each structure the Command Tower allows, by Command Tower level 1..5.
const LIMITS := {
	"hq": [1, 1, 1, 1, 1],
	"generator": [1, 2, 2, 3, 3],
	"storage": [1, 1, 2, 2, 3],
	"hangar": [1, 1, 1, 1, 1],
	"laser": [1, 2, 2, 3, 3],
	"net": [0, 1, 1, 2, 2],
	"jammer": [0, 0, 1, 1, 2],
	"birds": [0, 0, 1, 1, 2],
}

## prefers: which structures a drone goes for first ("any", "loot" or "defense").
## housing: how much hangar space one drone of this type takes in the army.
const DRONES := {
	"courier": {"name": "Courier", "role": "All-rounder. Goes for whatever is closest.",
		"health": 140.0, "speed": 9.0, "dps": 26.0, "housing": 2, "prefers": "any", "scale": 2.0,
		"color": Color(0.93, 0.94, 0.95), "hangar": 1, "unlock": 0},
	"scout": {"name": "Scout", "role": "Fast and fragile. Heads straight for generators, silos and the Command Tower.",
		"health": 80.0, "speed": 12.5, "dps": 16.0, "housing": 1, "prefers": "loot", "scale": 1.7,
		"color": Color(1.0, 0.55, 0.2), "hangar": 2, "unlock": 400},
	"heavy": {"name": "Heavy Lifter", "role": "Slow and tough. Takes out defenses first, so the others survive.",
		"health": 380.0, "speed": 6.5, "dps": 45.0, "housing": 4, "prefers": "defense", "scale": 2.5,
		"color": Color(0.3, 0.33, 0.37), "hangar": 3, "unlock": 900},
}
const DRONE_ORDER := ["courier", "scout", "heavy"]


static func is_defense(type: String) -> bool:
	return DEFENSES.has(type)


static func make_defense(type: String) -> Defense:
	match type:
		"laser":
			return LaserTower.new()
		"net":
			return NetLauncher.new()
		"jammer":
			return Jammer.new()
		"birds":
			return BirdFlock.new()
	push_error("Unknown defense type: %s" % type)
	return Defense.new()


static func display_name(type: String) -> String:
	if DEFENSES.has(type):
		return DEFENSES[type]["name"]
	if BUILDINGS.has(type):
		return BUILDINGS[type]["name"]
	return type


static func build_cost(type: String) -> int:
	return int((DEFENSES[type] if DEFENSES.has(type) else BUILDINGS[type])["cost"])


## Cost to go from `level` to `level + 1`.
static func upgrade_cost(type: String, level: int) -> int:
	return _round10(build_cost(type) * pow(1.8, level))


static func max_count(type: String, hq_level: int) -> int:
	return int(LIMITS[type][clampi(hq_level, 1, MAX_LEVEL) - 1])


## Defense stats grow with level: wider range, more damage, faster reload.
static func defense_stats(type: String, level: int) -> Dictionary:
	var s: Dictionary = DEFENSES[type].duplicate()
	var step := float(level - 1)
	s["level"] = level
	s["radius"] = float(s["radius"]) + 0.6 * step
	if s.has("dps"):
		s["dps"] = float(s["dps"]) * (1.0 + 0.25 * step)
	if s.has("cooldown"):
		s["cooldown"] = float(s["cooldown"]) * (1.0 - 0.08 * step)
	if s.has("damage"):
		s["damage"] = float(s["damage"]) * (1.0 + 0.25 * step)
	if s.has("count"):
		s["count"] = int(s["count"]) + int(step / 2.0)
	return s


## Coins per minute from one generator.
static func generator_rate(level: int) -> float:
	return 6.0 * level


## Generators stop filling after this many minutes until the player collects.
const GENERATOR_FILL_MINUTES := 240.0


static func coin_cap(hq_level: int, storage_levels: Array) -> int:
	var cap := 600 + 300 * hq_level
	for l in storage_levels:
		cap += 700 * int(l)
	return cap


## Loot an attacker grabs from an enemy building.
static func loot_value(type: String, level: int) -> int:
	match type:
		"hq":
			return 150 + 60 * level
		"storage":
			return 80 * level
		"generator":
			return 40 * level
	return 0


static func structure_hp(type: String, level: int) -> float:
	return float(HP[type]) * (1.0 + 0.35 * (level - 1))


static func drone_stats(type: String, level: int) -> Dictionary:
	var s: Dictionary = DRONES[type].duplicate()
	var step := float(level - 1)
	s["level"] = level
	s["health"] = float(s["health"]) * (1.0 + 0.2 * step)
	s["dps"] = float(s["dps"]) * (1.0 + 0.2 * step)
	s["speed"] = float(s["speed"]) * (1.0 + 0.04 * step)
	return s


## Total housing space for the attack army, from the hangar's level.
static func army_capacity(hangar_level: int) -> int:
	return 0 if hangar_level <= 0 else 8 + 4 * (hangar_level - 1)


static func drone_upgrade_cost(type: String, level: int) -> int:
	var base := maxi(int(DRONES[type]["unlock"]), 200)
	return _round10(base * 0.75 * pow(1.9, level))


static func _round10(value: float) -> int:
	return int(round(value / 10.0)) * 10
