class_name Catalog
extends RefCounted
## Every number that shapes the game: costs, limits, stats per level.
## Tune here; behaviour code reads everything through these functions.

const MAX_LEVEL := 5

## Seconds in an attack once the first unit is deployed.
const BATTLE_SECONDS := 90.0
## Height of a defense's head above its roof.
const DEFENSE_HEAD := 4.5

## Hit points of every structure at level 1.
## Tuned so a squad of four Couriers drops a small building in about a second and the
## Command Tower in a few, while a lone drone loses a duel with a laser.
const HP := {
	"hq": 600.0, "generator": 180.0, "storage": 260.0, "pump": 180.0, "tank": 260.0, "hangar": 220.0,
	"camp": 260.0, "quarters": 220.0, "garage": 280.0, "support": 300.0,
	"mg": 460.0, "at": 500.0, "aa": 440.0, "mortar": 420.0, "jammer": 300.0,
}

## One line on what each structure is for, shown in its info sheet.
const INFO := {
	"hq": "The heart of your base. Its level caps every other building and unlocks new ones.",
	"generator": "Makes coins over time. Tap the coin above it to collect.",
	"storage": "Raises how many coins you can hold. Attackers loot it.",
	"pump": "Pumps fuel over time. Tap the drop above it to collect.",
	"tank": "Raises how much fuel you can hold. Attackers loot it.",
	"hangar": "Unlocks and upgrades your attack drones. Its level caps drone levels.",
	"wall": "Stands on the paths between pads. Soldiers and tanks can't pass; engineers blow holes in it.",
	"camp": "Trains your army: soldiers, tanks and drones, one after another. Higher levels train faster.",
	"quarters": "Where your trained army waits for the next attack. More quarters and levels fit a bigger army.",
	"garage": "Unlocks and upgrades infantry, engineers and tanks. Its level caps their levels.",
	"support": "Prepares air strikes and flares ahead of the attack, and upgrades them. More levels, more slots.",
	"mg": "Fires bursts at soldiers. Weak against tanks and drones.",
	"at": "Slow, heavy shells that crack tanks open. Weak against soldiers, can't hit drones well.",
	"aa": "Shoots drones out of the sky. Weak against anything on the ground.",
	"mortar": "Lobs rounds that burst among groups of soldiers. Can't hit anything close or in the air.",
	"jammer": "Scrambles drones inside its field so they drift and slow down.",
}

## One short line per structure for the build menu cards.
const SHORT := {
	"generator": "Makes coins over time.",
	"storage": "Holds more coins.",
	"pump": "Pumps fuel over time.",
	"tank": "Holds more fuel.",
	"camp": "Trains your army.",
	"quarters": "Your army waits here.",
	"garage": "Unlocks and upgrades soldiers and tanks.",
	"hangar": "Unlocks and upgrades drones.",
	"support": "Prepares air strikes and flares.",
	"wall": "Blocks soldiers and tanks.",
	"mg": "Fires bursts at soldiers.",
	"at": "Heavy shells against tanks.",
	"aa": "Shoots down drones.",
	"mortar": "Hits groups of soldiers from afar.",
	"jammer": "Scrambles drones in its field.",
}

## vs: damage multiplier against soldiers, tanks and drones. Each defense is best against one.
const DEFENSES := {
	"mg": {"name": "MG Nest", "cost": 200, "radius": 11.0, "dps": 65.0,
		"vs": {"soldier": 1.0, "tank": 0.2, "air": 0.3}},
	"at": {"name": "Anti-Tank Gun", "cost": 300, "radius": 13.0, "damage": 260.0, "cooldown": 2.2,
		"vs": {"soldier": 0.35, "tank": 1.0, "air": 0.15}},
	"aa": {"name": "AA Battery", "cost": 250, "radius": 12.0, "dps": 60.0,
		"vs": {"soldier": 0.25, "tank": 0.1, "air": 1.0}},
	"mortar": {"name": "Mortar", "cost": 350, "radius": 16.0, "min_radius": 5.0, "damage": 85.0, "cooldown": 3.2, "splash": 3.6,
		"vs": {"soldier": 1.0, "tank": 0.3}},
	"jammer": {"name": "Jammer", "cost": 300, "radius": 7.5},
}

const BUILDINGS := {
	"hq": {"name": "Command Tower", "cost": 500},
	"generator": {"name": "Solar Generator", "cost": 150},
	"storage": {"name": "Coin Silo", "cost": 200},
	"pump": {"name": "Fuel Pump", "cost": 150},
	"tank": {"name": "Fuel Tank", "cost": 200},
	"hangar": {"name": "Drone Hangar", "cost": 250},
	"camp": {"name": "Training Camp", "cost": 200},
	"quarters": {"name": "Quarters", "cost": 150},
	"garage": {"name": "Garage", "cost": 300},
	"support": {"name": "Support Base", "cost": 400},
}

## Order of the build menu.
const BUILD_ORDER := ["generator", "storage", "pump", "tank", "camp", "quarters", "garage", "hangar", "support",
	"mg", "at", "aa", "mortar", "jammer"]

## How many of each structure the Command Tower allows, by Command Tower level 1..5.
const LIMITS := {
	"hq": [1, 1, 1, 1, 1],
	"generator": [1, 2, 2, 3, 3],
	"storage": [1, 1, 2, 2, 3],
	"pump": [1, 2, 2, 3, 3],
	"tank": [1, 1, 2, 2, 3],
	"hangar": [1, 1, 1, 1, 1],
	"camp": [1, 1, 1, 1, 1],
	"quarters": [1, 1, 2, 2, 3],
	"garage": [1, 1, 1, 1, 1],
	"support": [1, 1, 1, 1, 1],
	"mg": [1, 2, 2, 3, 3],
	"at": [0, 1, 1, 2, 2],
	"aa": [1, 1, 2, 2, 3],
	"mortar": [0, 0, 1, 1, 2],
	"jammer": [0, 0, 1, 1, 2],
}

## prefers: which structures a unit goes for first ("any", "loot", "defense", or "fence"
## for engineers, who breach the fence first).
## housing: how much army space one unit of this type takes.
## train_fuel / train_seconds: the cost of training one, at Training Camp level 1.
## hangar (drones) / garage (ground units): the lab level that unlocks it; unlock: fuel to unlock.
const DRONES := {
	"courier": {"name": "Courier", "role": "All-rounder. Goes for whatever is closest.",
		"health": 140.0, "speed": 9.0, "dps": 42.0, "fire": 0.3, "burst": 1, "housing": 2, "prefers": "any", "scale": 1.6, "hover": [4.5, 6.5],
		"color": Color(0.31, 0.7, 1.0), "hangar": 1, "unlock": 0, "train_fuel": 30, "train_seconds": 20.0},
	"scout": {"name": "Scout", "role": "Fast and fragile. Heads straight for generators, silos and the Command Tower.",
		"health": 80.0, "speed": 12.5, "dps": 26.0, "fire": 0.55, "burst": 3, "housing": 1, "prefers": "loot", "scale": 1.5, "hover": [4.0, 5.5],
		"color": Color(1.0, 0.48, 0.1), "hangar": 2, "unlock": 400, "train_fuel": 25, "train_seconds": 15.0},
	"heavy": {"name": "Heavy Lifter", "role": "Slow and tough. Takes out defenses first, so the others survive.",
		"health": 380.0, "speed": 6.5, "dps": 72.0, "fire": 1.4, "burst": 1, "housing": 4, "prefers": "defense", "scale": 1.2, "hover": [1.0, 8.5],
		"color": Color(0.95, 0.72, 0.02), "hangar": 3, "unlock": 900, "train_fuel": 90, "train_seconds": 45.0},
}
const DRONE_ORDER := ["courier", "scout", "heavy"]

## Ground units walk, and the fence stops them: they go in through the gate or a breach.
## squad: soldiers released per card; health and dps are per soldier. range: firing distance
## from the edge of a building. fire: seconds between shots.
const GROUND := {
	"infantry": {"name": "Infantry Squad", "role": "Cheap and quick, they come in numbers. Each soldier attacks the closest building.",
		"squad": 4, "health": 70.0, "speed": 4.5, "dps": 9.0, "fire": 0.4, "range": 6.0, "housing": 3, "prefers": "any",
		"color": Color(0.61, 0.67, 0.42), "garage": 1, "unlock": 0, "train_fuel": 40, "train_seconds": 20.0},
	"engineers": {"name": "Combat Engineers", "role": "Blow a hole in the fence, then plant charges on buildings. They open the way for everyone else.",
		"squad": 2, "health": 80.0, "speed": 5.0, "dps": 22.0, "fire": 1.2, "range": 1.0, "housing": 2, "prefers": "fence",
		"color": Color(0.88, 0.64, 0.23), "garage": 2, "unlock": 300, "train_fuel": 50, "train_seconds": 25.0},
	"armor": {"name": "Heavy Tank", "role": "Slow and very tough, fires heavy shells. Soaks up fire and takes out defenses first.",
		"squad": 1, "health": 900.0, "speed": 3.2, "dps": 48.0, "fire": 2.5, "range": 12.0, "housing": 8, "prefers": "defense",
		"color": Color(0.79, 0.76, 0.64), "garage": 3, "unlock": 800, "train_fuel": 220, "train_seconds": 90.0},
}
const GROUND_ORDER := ["infantry", "engineers", "armor"]
## Every unit, in the order cards and menus show them.
const UNIT_ORDER := ["infantry", "engineers", "armor", "courier", "scout", "heavy"]


static func is_defense(type: String) -> bool:
	return DEFENSES.has(type)


static func make_defense(type: String) -> Defense:
	match type:
		"mg":
			return MgNest.new()
		"at":
			return AtGun.new()
		"aa":
			return AaBattery.new()
		"mortar":
			return MortarPit.new()
		"jammer":
			return Jammer.new()
	push_error("Unknown defense type: %s" % type)
	return Defense.new()


static func display_name(type: String) -> String:
	if type == "wall":
		return I18n.t("Wall")
	if ABILITIES.has(type):
		return I18n.t(ABILITIES[type]["name"])
	if DEFENSES.has(type):
		return I18n.t(DEFENSES[type]["name"])
	if BUILDINGS.has(type):
		return I18n.t(BUILDINGS[type]["name"])
	if DRONES.has(type):
		return I18n.t(DRONES[type]["name"])
	if GROUND.has(type):
		return I18n.t(GROUND[type]["name"])
	return type


static func is_ground(type: String) -> bool:
	return GROUND.has(type)


static func unit_def(type: String) -> Dictionary:
	return GROUND[type] if GROUND.has(type) else DRONES[type]


## The building that unlocks and upgrades this unit: "garage" or "hangar".
static func unit_lab(type: String) -> String:
	return "garage" if GROUND.has(type) else "hangar"


## The lab level needed to unlock this unit.
static func unit_lab_level(type: String) -> int:
	return int(unit_def(type)[unit_lab(type)])


static func unit_stats(type: String, level: int) -> Dictionary:
	if DRONES.has(type):
		return drone_stats(type, level)
	var s: Dictionary = GROUND[type].duplicate()
	var step := float(level - 1)
	s["level"] = level
	s["kind"] = type
	s["health"] = float(s["health"]) * (1.0 + 0.2 * step)
	s["dps"] = float(s["dps"]) * (1.0 + 0.2 * step)
	s["speed"] = float(s["speed"]) * (1.0 + 0.03 * step)
	return s


## Seconds to train one unit; each Training Camp level trains a quarter faster.
static func train_seconds(type: String, camp_level: int) -> float:
	return float(unit_def(type)["train_seconds"]) / (1.0 + 0.25 * maxi(camp_level - 1, 0))


static func train_fuel(type: String) -> int:
	return int(unit_def(type)["train_fuel"])


static func build_cost(type: String) -> int:
	return int((DEFENSES[type] if DEFENSES.has(type) else BUILDINGS[type])["cost"])


## Cost to go from `level` to `level + 1`.
static func upgrade_cost(type: String, level: int) -> int:
	return _round10(build_cost(type) * pow(1.8, level))


static func max_count(type: String, hq_level: int) -> int:
	return int(LIMITS[type][clampi(hq_level, 1, MAX_LEVEL) - 1])


## Defense stats grow with level: wider range, more damage, faster reload, bigger blasts.
static func defense_stats(type: String, level: int) -> Dictionary:
	var s: Dictionary = DEFENSES[type].duplicate()
	var step := float(level - 1)
	s["level"] = level
	s["radius"] = float(s["radius"]) + 0.6 * step
	for key in ["dps", "damage"]:
		if s.has(key):
			s[key] = float(s[key]) * (1.0 + 0.25 * step)
	if s.has("cooldown"):
		s["cooldown"] = float(s["cooldown"]) * (1.0 - 0.06 * step)
	if s.has("splash"):
		s["splash"] = float(s["splash"]) + 0.2 * step
	return s


## Coins per minute from one generator.
static func generator_rate(level: int) -> float:
	return 6.0 * level


## Generators stop filling after this many minutes until the player collects.
const GENERATOR_FILL_MINUTES := 240.0


## Fuel per minute from one pump.
static func pump_rate(level: int) -> float:
	return 4.0 * level


static func fuel_cap(hq_level: int, tank_levels: Array) -> int:
	var cap := 500 + 250 * hq_level
	for l in tank_levels:
		cap += 600 * int(l)
	return cap


static func coin_cap(hq_level: int, storage_levels: Array) -> int:
	var cap := 600 + 300 * hq_level
	for l in storage_levels:
		cap += 700 * int(l)
	return cap


## Coins an attacker grabs from an enemy building.
static func loot_value(type: String, level: int) -> int:
	match type:
		"hq":
			return 150 + 60 * level
		"storage":
			return 80 * level
		"generator":
			return 40 * level
	return 0


## Fuel an attacker grabs from an enemy building.
static func loot_fuel(type: String, level: int) -> int:
	match type:
		"hq":
			return 100 + 40 * level
		"tank":
			return 70 * level
		"pump":
			return 30 * level
	return 0


static func structure_hp(type: String, level: int) -> float:
	return float(HP[type]) * (1.0 + 0.35 * (level - 1))


static func drone_stats(type: String, level: int) -> Dictionary:
	var s: Dictionary = DRONES[type].duplicate()
	var step := float(level - 1)
	s["level"] = level
	s["kind"] = type
	s["health"] = float(s["health"]) * (1.0 + 0.2 * step)
	s["dps"] = float(s["dps"]) * (1.0 + 0.2 * step)
	s["speed"] = float(s["speed"]) * (1.0 + 0.04 * step)
	return s


# ---------------------------------------------------------------- walls

## Wall pieces stand on the paths between pads. They are built and upgraded at once, with
## no worker, like Clash walls. The Command Tower caps how many and how high their level.
const WALL_COST := 25
const WALL_LIMITS := [20, 35, 50, 65, 80]


static func wall_limit(hq_level: int) -> int:
	return int(WALL_LIMITS[clampi(hq_level, 1, MAX_LEVEL) - 1])


## Coins to raise one wall piece from `level` to `level + 1`.
static func wall_upgrade_cost(level: int) -> int:
	return _round10(WALL_COST * pow(3.0, level))


static func wall_hp(level: int) -> float:
	return 500.0 * (1.0 + 0.7 * (level - 1))


# ---------------------------------------------------------------- support abilities

## Prepared ahead in the Support Base, like training: fuel and time, one after another.
## slots: room each takes; support: Support Base level that unlocks it; unlock: fuel to unlock.
const ABILITIES := {
	"flare": {"name": "Flare", "slots": 1, "fuel": 40, "seconds": 20.0, "support": 1, "unlock": 0,
		"role": "Every attacking unit heads for the flare and attacks what is near it."},
	"strike": {"name": "Air Strike", "slots": 2, "fuel": 150, "seconds": 60.0, "support": 2, "unlock": 500,
		"role": "A plane drops a line of bombs on the spot you tap."},
}
const ABILITY_ORDER := ["flare", "strike"]


## Slots in a Support Base of this level (0 without one).
static func support_slots(level: int) -> int:
	return 0 if level <= 0 else level + 1


## What an ability does at a level. Air strike: bombs, damage per bomb, blast radius, spacing.
## Flare: how long it burns. Each level changes the plane or the flare visibly too.
static func ability_stats(kind: String, level: int) -> Dictionary:
	var l := clampi(level, 1, MAX_LEVEL)
	if kind == "strike":
		return {"level": l, "bombs": [2, 4, 3, 3, 5][l - 1], "damage": [220.0, 180.0, 340.0, 400.0, 380.0][l - 1],
			"radius": [4.0, 4.0, 4.5, 5.0, 5.5][l - 1], "spacing": 5.5}
	return {"level": l, "seconds": [5.0, 6.0, 7.0, 8.0, 9.0][l - 1], "flares": [1, 1, 1, 2, 3][l - 1]}


static func ability_upgrade_cost(kind: String, level: int) -> int:
	var base := maxi(int(ABILITIES[kind]["unlock"]), 300)
	return _round10(base * 0.8 * pow(1.9, level))


## Soldiers that run out of a Quarters building to defend it when attackers come close.
static func defender_count(quarters_level: int) -> int:
	return 2 + int((quarters_level - 1) / 2.0)


## How close an attacker has to come to a Quarters building to call out its defenders.
const DEFENDER_ALERT := 16.0
## How far defenders chase attackers from their Quarters.
const DEFENDER_LEASH := 24.0


## Army space from one Quarters building.
static func quarters_space(level: int) -> int:
	return 12 + 6 * (level - 1)


## Total army space from all Quarters.
static func army_capacity(quarters_levels: Array) -> int:
	var total := 0
	for l in quarters_levels:
		total += quarters_space(int(l))
	return total


## Fuel to upgrade a unit from `level` to `level + 1`.
static func unit_upgrade_cost(type: String, level: int) -> int:
	var base := maxi(int(unit_def(type)["unlock"]), 200)
	return _round10(base * 0.75 * pow(1.9, level))


# ---------------------------------------------------------------- time, workers, gems

## Players start with this many workers; one more can be hired with gems.
const START_WORKERS := 2
const MAX_WORKERS := 3
const WORKER_GEMS := 500
const START_GEMS := 250

## Seconds to build a structure (level 1) or upgrade it to `level`.
## Level 1 takes seconds so the first minutes feel fast; each level takes four times longer.
const BUILD_SECONDS := {"hq": 60.0}
const DEFAULT_BUILD_SECONDS := 15.0


static func build_seconds(type: String, level: int) -> float:
	var base := float(BUILD_SECONDS.get(type, DEFAULT_BUILD_SECONDS))
	return base * pow(4.0, level - 1)


## Gems to finish something now, Clash-style: about 1 gem a minute at first, getting
## cheaper per minute for long waits. Anything left at all costs at least 1 gem.
static func speedup_gems(seconds_left: float) -> int:
	if seconds_left <= 0.0:
		return 0
	var points := [[0.0, 0.0], [60.0, 1.0], [3600.0, 20.0], [86400.0, 260.0], [604800.0, 1000.0]]
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if seconds_left <= b[0] or i == points.size() - 1:
			var k: float = (seconds_left - a[0]) / (b[0] - a[0])
			return maxi(1, ceili(lerpf(float(a[1]), float(b[1]), k)))
	return 1


static func _round10(value: float) -> int:
	return int(round(value / 10.0)) * 10
