extends Node
## The player's save: coins, the structures on their rooftop base, their drone fleet and
## the army they take into the next attack. Every change goes through a method here so
## the rules live in one place.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3

## Turned off by unit tests so they never touch the real save file.
var persist := true

var coins := 0
## Each: {type, cell: [c, r], level}; generators also carry collected_at (unix seconds).
var structures: Array = []
## Unlocked drone types and their levels.
var drones := {}
## How many of each drone type go into the next attack.
var army := {}
var enemy_index := 0
var raid_target := "enemy"
var city_seed := 7
var best_stars := {}


func _ready() -> void:
	if not load_game():
		new_player()


func new_player() -> void:
	var now := Time.get_unix_time_from_system()
	coins = 400
	structures = [
		{"type": "hq", "cell": [3, 3], "level": 1},
		# Starts 20 minutes in, so there is a coin to collect right away.
		{"type": "generator", "cell": [2, 3], "level": 1, "collected_at": now - 20.0 * 60.0},
		{"type": "hangar", "cell": [4, 3], "level": 1},
		{"type": "laser", "cell": [3, 2], "level": 1},
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


func coin_cap() -> int:
	var storage_levels := []
	for s in structures:
		if s["type"] == "storage":
			storage_levels.append(int(s["level"]))
	return Catalog.coin_cap(hq_level(), storage_levels)


## Coins waiting in one generator.
func generator_pending(s: Dictionary) -> int:
	var minutes := (Time.get_unix_time_from_system() - float(s.get("collected_at", 0.0))) / 60.0
	minutes = clampf(minutes, 0.0, Catalog.GENERATOR_FILL_MINUTES)
	return int(Catalog.generator_rate(int(s["level"])) * minutes)


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
		return "Needs Command Tower Lv %d" % needed
	if count_of(type) >= allowed:
		return "Limit reached (%d)" % allowed
	if coins < Catalog.build_cost(type):
		return "Not enough coins"
	return ""


func upgrade_block_reason(cell: Array) -> String:
	var s := structure_at(cell)
	if s.is_empty():
		return "Nothing here"
	var level := int(s["level"])
	if level >= Catalog.MAX_LEVEL:
		return "Max level"
	if s["type"] != "hq" and level >= hq_level():
		return "Upgrade the Command Tower first"
	if coins < Catalog.upgrade_cost(s["type"], level):
		return "Not enough coins"
	return ""


func drone_block_reason(type: String) -> String:
	if hangar_level() < int(Catalog.DRONES[type]["hangar"]):
		return "Needs Hangar Lv %d" % int(Catalog.DRONES[type]["hangar"])
	if drones.has(type):
		var level := int(drones[type])
		if level >= Catalog.MAX_LEVEL:
			return "Max level"
		if level >= hangar_level():
			return "Upgrade the Hangar first"
		if coins < Catalog.drone_upgrade_cost(type, level):
			return "Not enough coins"
	elif coins < int(Catalog.DRONES[type]["unlock"]):
		return "Not enough coins"
	return ""


## The player's own base in the same format as enemy bases, for the defense test.
func player_base() -> Dictionary:
	var pad := [City.GRID - 1, City.GRID - 1]
	for c in range(City.GRID - 1, -1, -1):
		if structure_at([c, City.GRID - 1]).is_empty():
			pad = [c, City.GRID - 1]
			break
	return {"name": "Your Base (practice)", "seed": city_seed, "pad": pad, "structures": structures}


# ---------------------------------------------------------------- actions

func add_coins(amount: int) -> int:
	var before := coins
	coins = mini(coin_cap(), coins + amount)
	save_game()
	return coins - before


## Moves a generator's coins into the bank. If the bank is nearly full, whatever doesn't
## fit stays in the generator, as in Clash.
func collect_generator(cell: Array) -> int:
	var s := structure_at(cell)
	if s.is_empty() or s["type"] != "generator":
		return 0
	var pending := generator_pending(s)
	var taken := mini(pending, coin_cap() - coins)
	var rate := Catalog.generator_rate(int(s["level"]))
	var left_minutes := float(pending - taken) / rate
	s["collected_at"] = Time.get_unix_time_from_system() - left_minutes * 60.0
	return add_coins(taken)


func build(type: String, cell: Array) -> bool:
	if build_block_reason(type) != "" or not structure_at(cell).is_empty():
		return false
	coins -= Catalog.build_cost(type)
	var s := {"type": type, "cell": [int(cell[0]), int(cell[1])], "level": 1}
	if type == "generator":
		s["collected_at"] = Time.get_unix_time_from_system()
	structures.append(s)
	save_game()
	return true


func upgrade(cell: Array) -> bool:
	if upgrade_block_reason(cell) != "":
		return false
	var s := structure_at(cell)
	coins -= Catalog.upgrade_cost(s["type"], int(s["level"]))
	s["level"] = int(s["level"]) + 1
	save_game()
	return true


func remove(cell: Array) -> bool:
	var s := structure_at(cell)
	if s.is_empty() or s["type"] == "hq":
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
		coins -= Catalog.drone_upgrade_cost(type, int(drones[type]))
		drones[type] = int(drones[type]) + 1
	else:
		coins -= int(Catalog.DRONES[type]["unlock"])
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


func record_raid(stars: int, loot: int) -> int:
	if raid_target != "enemy":
		return 0
	var key := str(enemy_index)
	best_stars[key] = maxi(int(best_stars.get(key, 0)), stars)
	if stars > 0:
		enemy_index += 1
	return add_coins(loot)


# ---------------------------------------------------------------- save

func save_game() -> void:
	if not persist:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file")
		return
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION, "coins": coins, "structures": structures, "drones": drones,
		"army": army, "enemy_index": enemy_index, "city_seed": city_seed, "best_stars": best_stars,
	}))


func load_game() -> bool:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary) or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	coins = int(data["coins"])
	structures = data["structures"]
	for s in structures:
		s["level"] = int(s["level"])
		s["cell"] = [int(s["cell"][0]), int(s["cell"][1])]
		if s.has("collected_at"):
			s["collected_at"] = float(s["collected_at"])
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
