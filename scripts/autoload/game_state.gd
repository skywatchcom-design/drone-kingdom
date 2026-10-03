extends Node
## The player's save: coins, fuel and gems, the structures on their base, their drone fleet
## and the army they take into the next attack. Every change goes through a method here so
## the rules live in one place.
## Building and upgrading take time and a free worker: the structure gets busy_until (unix
## seconds) and, for a fresh build, "fresh": true. finish_ready() completes whatever is done.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 4

## Turned off by unit tests so they never touch the real save file.
var persist := true

var coins := 0
var fuel := 0
var gems := 0
var workers := Catalog.START_WORKERS
## Each: {type, cell: [c, r], level}; generators and pumps also carry collected_at (unix
## seconds); structures being built or upgraded carry busy_until.
var structures: Array = []
## Unlocked drone types and their levels.
var drones := {}
## How many of each drone type go into the next attack.
var army := {}
var enemy_index := 0
var raid_target := "enemy"
var city_seed := 7
var best_stars := {}

const SETTINGS_PATH := "user://settings.json"
## Development only: coins, fuel and gems cost nothing. Forced off in release exports,
## where OS.is_debug_build() is false, so players can never get it.
var infinite_coins := false
var sound_on := true


func _ready() -> void:
	I18n.setup_font()
	load_settings()
	if not load_game():
		new_player()


func dev_tools_available() -> bool:
	return OS.is_debug_build()


func set_infinite_coins(on: bool) -> void:
	infinite_coins = on and dev_tools_available()
	save_settings()


func set_sound(on: bool) -> void:
	sound_on = on
	save_settings()


func set_language(lang: String) -> void:
	I18n.lang = lang
	save_settings()


func load_settings() -> void:
	if not persist or not FileAccess.file_exists(SETTINGS_PATH):
		infinite_coins = dev_tools_available()
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if data is Dictionary:
		I18n.lang = data.get("lang", I18n.lang)
		infinite_coins = bool(data.get("infinite_coins", true)) and dev_tools_available()
		sound_on = bool(data.get("sound", true))


func save_settings() -> void:
	if not persist:
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"lang": I18n.lang, "infinite_coins": infinite_coins, "sound": sound_on}))


## Pays for something. With infinite coins on, nothing is taken.
func _spend(cost: int) -> void:
	if not infinite_coins:
		coins -= cost


func _spend_fuel(cost: int) -> void:
	if not infinite_coins:
		fuel -= cost


func _spend_gems(cost: int) -> void:
	if not infinite_coins:
		gems -= cost


func now() -> float:
	return Time.get_unix_time_from_system()


func new_player() -> void:
	var t := now()
	coins = 400
	fuel = 300
	gems = Catalog.START_GEMS
	workers = Catalog.START_WORKERS
	structures = [
		{"type": "hq", "cell": [4, 4], "level": 1},
		# Start 20 minutes in, so there is something to collect right away.
		{"type": "generator", "cell": [3, 4], "level": 1, "collected_at": t - 20.0 * 60.0},
		{"type": "pump", "cell": [4, 5], "level": 1, "collected_at": t - 20.0 * 60.0},
		{"type": "hangar", "cell": [5, 4], "level": 1},
		{"type": "laser", "cell": [4, 3], "level": 1},
	]
	drones = {"courier": 1}
	army = {"courier": 4}
	enemy_index = 0
	raid_target = "enemy"
	best_stars = {}
	save_game()


# ---------------------------------------------------------------- queries

func hq_level() -> int:
	for s in structures:
		if s["type"] == "hq":
			return int(s["level"])
	return 1


func hangar_level() -> int:
	for s in structures:
		if s["type"] == "hangar":
			return int(s["level"])
	return 0


func structure_at(cell: Array) -> Dictionary:
	for s in structures:
		if int(s["cell"][0]) == int(cell[0]) and int(s["cell"][1]) == int(cell[1]):
			return s
	return {}


func count_of(type: String) -> int:
	var n := 0
	for s in structures:
		if s["type"] == type:
			n += 1
	return n


## Levels of the finished structures of one type (one still being built holds nothing).
func _working_levels(type: String) -> Array:
	var levels := []
	for s in structures:
		if s["type"] == type and not s.get("fresh", false):
			levels.append(int(s["level"]))
	return levels


func coin_cap() -> int:
	return Catalog.coin_cap(hq_level(), _working_levels("storage"))


func fuel_cap() -> int:
	return Catalog.fuel_cap(hq_level(), _working_levels("tank"))


static func is_producer(type: String) -> bool:
	return type == "generator" or type == "pump"


## Per-minute output of a generator (coins) or pump (fuel).
static func producer_rate(s: Dictionary) -> float:
	var lvl := int(s["level"])
	return Catalog.generator_rate(lvl) if s["type"] == "generator" else Catalog.pump_rate(lvl)


## Coins or fuel waiting in one generator or pump. Nothing while it is first being built.
func generator_pending(s: Dictionary) -> int:
	if s.get("fresh", false):
		return 0
	var minutes := (now() - float(s.get("collected_at", 0.0))) / 60.0
	minutes = clampf(minutes, 0.0, Catalog.GENERATOR_FILL_MINUTES)
	return int(producer_rate(s) * minutes)


func is_busy(s: Dictionary) -> bool:
	return s.has("busy_until")


func seconds_left(s: Dictionary) -> float:
	return maxf(0.0, float(s.get("busy_until", 0.0)) - now())


func workers_busy() -> int:
	var n := 0
	for s in structures:
		if is_busy(s):
			n += 1
	return n


func free_workers() -> int:
	return workers - workers_busy()


func army_capacity() -> int:
	return Catalog.army_capacity(hangar_level())


func army_used() -> int:
	var used := 0
	for type in army:
		used += int(army[type]) * int(Catalog.DRONES[type]["housing"])
	return used


func drone_stats_for(type: String) -> Dictionary:
	return Catalog.drone_stats(type, int(drones.get(type, 1)))


## Empty string when the player may build `type`; otherwise the reason they can't.
func build_block_reason(type: String) -> String:
	var allowed := Catalog.max_count(type, hq_level())
	if allowed == 0:
		var needed := hq_level() + 1
		while needed <= Catalog.MAX_LEVEL and Catalog.max_count(type, needed) == 0:
			needed += 1
		return I18n.t("Needs Command Tower Lv %d") % needed
	if count_of(type) >= allowed:
		return I18n.t("Limit reached (%d)") % allowed
	var money := _coins_reason(Catalog.build_cost(type))
	return money if money != "" else _worker_reason()


func _coins_reason(cost: int) -> String:
	return "" if infinite_coins or coins >= cost else I18n.t("Need %d more coins") % (cost - coins)


func _fuel_reason(cost: int) -> String:
	return "" if infinite_coins or fuel >= cost else I18n.t("Need %d more fuel") % (cost - fuel)


func _worker_reason() -> String:
	return "" if free_workers() > 0 else I18n.t("All workers are busy")


func upgrade_block_reason(cell: Array) -> String:
	var s := structure_at(cell)
	if s.is_empty():
		return I18n.t("Nothing here")
	if is_busy(s):
		return I18n.t("Under construction")
	var level := int(s["level"])
	if level >= Catalog.MAX_LEVEL:
		return I18n.t("Max level")
	if s["type"] != "hq" and level >= hq_level():
		return I18n.t("Upgrade the Command Tower first")
	var money := _coins_reason(Catalog.upgrade_cost(s["type"], level))
	return money if money != "" else _worker_reason()


func drone_block_reason(type: String) -> String:
	if hangar_level() < int(Catalog.DRONES[type]["hangar"]):
		return I18n.t("Needs Hangar Lv %d") % int(Catalog.DRONES[type]["hangar"])
	if drones.has(type):
		var level := int(drones[type])
		if level >= Catalog.MAX_LEVEL:
			return I18n.t("Max level")
		if level >= hangar_level():
			return I18n.t("Upgrade the Hangar first")
		return _fuel_reason(Catalog.drone_upgrade_cost(type, level))
	return _fuel_reason(int(Catalog.DRONES[type]["unlock"]))


## The player's own base in the same format as enemy bases, for the defense test.
func player_base() -> Dictionary:
	var pad := [City.GRID - 1, City.GRID - 1]
	for c in range(City.GRID - 1, -1, -1):
		if structure_at([c, City.GRID - 1]).is_empty():
			pad = [c, City.GRID - 1]
			break
	var built := structures.filter(func(s: Dictionary) -> bool: return not s.get("fresh", false))
	return {"name": I18n.t("Your Base (practice)"), "seed": city_seed, "pad": pad, "structures": built}


# ---------------------------------------------------------------- actions

func add_coins(amount: int) -> int:
	var before := coins
	coins = mini(coin_cap(), coins + amount)
	save_game()
	return coins - before


func add_fuel(amount: int) -> int:
	var before := fuel
	fuel = mini(fuel_cap(), fuel + amount)
	save_game()
	return fuel - before


## Moves a generator's coins (or a pump's fuel) into the bank. If the bank is nearly full,
## whatever doesn't fit stays in the producer, as in Clash.
func collect_generator(cell: Array) -> int:
	var s := structure_at(cell)
	if s.is_empty() or not is_producer(s["type"]):
		return 0
	var pending := generator_pending(s)
	var room := coin_cap() - coins if s["type"] == "generator" else fuel_cap() - fuel
	var taken := mini(pending, maxi(room, 0))
	var left_minutes := float(pending - taken) / producer_rate(s)
	s["collected_at"] = now() - left_minutes * 60.0
	return add_coins(taken) if s["type"] == "generator" else add_fuel(taken)


func build(type: String, cell: Array) -> bool:
	if build_block_reason(type) != "" or not structure_at(cell).is_empty():
		return false
	_spend(Catalog.build_cost(type))
	var s := {"type": type, "cell": [int(cell[0]), int(cell[1])], "level": 1, "fresh": true,
		"busy_until": now() + Catalog.build_seconds(type, 1)}
	structures.append(s)
	save_game()
	return true


## Starts an upgrade. The structure keeps working at its old level until it is done.
func upgrade(cell: Array) -> bool:
	if upgrade_block_reason(cell) != "":
		return false
	var s := structure_at(cell)
	var lvl := int(s["level"])
	_spend(Catalog.upgrade_cost(s["type"], lvl))
	s["busy_until"] = now() + Catalog.build_seconds(s["type"], lvl + 1)
	save_game()
	return true


## Completes every build or upgrade whose time is up. Returns the finished structures.
func finish_ready() -> Array:
	var done := []
	var t := now()
	for s in structures:
		if is_busy(s) and float(s["busy_until"]) <= t:
			_complete(s)
			done.append(s)
	if not done.is_empty():
		save_game()
	return done


func _complete(s: Dictionary) -> void:
	s.erase("busy_until")
	if s.get("fresh", false):
		s.erase("fresh")
		if is_producer(s["type"]):
			s["collected_at"] = now()
		return
	# Bank what a producer made at the old rate, so the new rate doesn't apply backwards.
	if is_producer(s["type"]):
		collect_generator(s["cell"])
	s["level"] = int(s["level"]) + 1


func speedup_cost(cell: Array) -> int:
	var s := structure_at(cell)
	return 0 if s.is_empty() or not is_busy(s) else Catalog.speedup_gems(seconds_left(s))


## Finishes a build or upgrade right away for gems.
func speed_up(cell: Array) -> bool:
	var s := structure_at(cell)
	if s.is_empty() or not is_busy(s):
		return false
	var cost := speedup_cost(cell)
	if not infinite_coins and gems < cost:
		return false
	_spend_gems(cost)
	_complete(s)
	save_game()
	return true


func hire_worker_reason() -> String:
	if workers >= Catalog.MAX_WORKERS:
		return I18n.t("All workers hired")
	if not infinite_coins and gems < Catalog.WORKER_GEMS:
		return I18n.t("Need %d more gems") % (Catalog.WORKER_GEMS - gems)
	return ""


func hire_worker() -> bool:
	if hire_worker_reason() != "":
		return false
	_spend_gems(Catalog.WORKER_GEMS)
	workers += 1
	save_game()
	return true


func remove(cell: Array) -> bool:
	var s := structure_at(cell)
	if s.is_empty() or s["type"] == "hq" or is_busy(s):
		return false
	structures.erase(s)
	if s["type"] == "hangar":
		army = {}
	save_game()
	return true


func upgrade_drone(type: String) -> bool:
	if drone_block_reason(type) != "":
		return false
	if drones.has(type):
		_spend_fuel(Catalog.drone_upgrade_cost(type, int(drones[type])))
		drones[type] = int(drones[type]) + 1
	else:
		_spend_fuel(int(Catalog.DRONES[type]["unlock"]))
		drones[type] = 1
	save_game()
	return true


## Sets how many drones of `type` join the next attack, if they fit in the hangar.
func set_army_count(type: String, count: int) -> bool:
	if not drones.has(type) or count < 0:
		return false
	var used := army_used() - int(army.get(type, 0)) * int(Catalog.DRONES[type]["housing"])
	if used + count * int(Catalog.DRONES[type]["housing"]) > army_capacity():
		return false
	army[type] = count
	save_game()
	return true


## Banks the loot of an attack on an enemy. Returns {coins, fuel} actually banked.
func record_raid(stars: int, loot: int, loot_fuel: int = 0) -> Dictionary:
	if raid_target != "enemy":
		return {"coins": 0, "fuel": 0}
	var key := str(enemy_index)
	best_stars[key] = maxi(int(best_stars.get(key, 0)), stars)
	if stars > 0:
		enemy_index += 1
	return {"coins": add_coins(loot), "fuel": add_fuel(loot_fuel)}


# ---------------------------------------------------------------- save

func save_game() -> void:
	if not persist:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file")
		return
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION, "coins": coins, "fuel": fuel, "gems": gems, "workers": workers,
		"structures": structures, "drones": drones,
		"army": army, "enemy_index": enemy_index, "city_seed": city_seed, "best_stars": best_stars,
	}))


func load_game() -> bool:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary) or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	coins = int(data["coins"])
	fuel = int(data.get("fuel", 0))
	gems = int(data.get("gems", 0))
	workers = int(data.get("workers", Catalog.START_WORKERS))
	structures = data["structures"]
	for s in structures:
		s["level"] = int(s["level"])
		s["cell"] = [int(s["cell"][0]), int(s["cell"][1])]
		for k: String in ["collected_at", "busy_until"]:
			if s.has(k):
				s[k] = float(s[k])
	drones = {}
	for k in data["drones"]:
		drones[k] = int(data["drones"][k])
	army = {}
	for k in data.get("army", {}):
		army[k] = int(data["army"][k])
	enemy_index = int(data.get("enemy_index", 0))
	city_seed = int(data.get("city_seed", 7))
	best_stars = data.get("best_stars", {})
	return true
