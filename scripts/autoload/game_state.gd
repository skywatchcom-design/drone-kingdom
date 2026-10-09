extends Node
## The player's save: coins, fuel and gems, the structures on their base, their unit levels,
## the trained army and the training queue. Every change goes through a method here so the
## rules live in one place.
## Building and upgrading take time and a free worker: the structure gets busy_until (unix
## seconds) and, for a fresh build, "fresh": true. finish_ready() completes whatever is done.
## Training, as in Clash: the Training Camp works through its queue one unit at a time, for
## fuel and time; trained units wait in the Quarters, and an attack uses up what it deploys.
## process_training() moves whatever has finished into the army.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 11
## Defenses that left the game, and what replaces them in older saves.
const RETIRED := {"laser": "aa", "net": "at", "birds": "mg"}

## Turned off by unit tests so they never touch the real save file.
var persist := true

var coins := 0
var fuel := 0
var gems := 0
var workers := Catalog.START_WORKERS
## Each: {type, cell: [c, r], level}; generators and pumps also carry collected_at (unix
## seconds); structures being built or upgraded carry busy_until.
var structures: Array = []
## Unlocked unit types (ground units and drones) and their levels.
var units := {}
## Trained units ready for the next attack, by type.
var army := {}
## Unit types waiting to be trained, in order. The first one started at train_started.
var training: Array = []
var train_started := 0.0
## Wall pieces: each {edge: [c, r, d], level} (see Walls).
var walls: Array = []
## Unlocked support abilities and their levels; prepared ones ready for the next attack;
## and the Support Base's queue, the first started at support_started.
var abilities := {}
var support_ready := {}
var support_queue: Array = []
var support_started := 0.0
var enemy_index := 0
var raid_target := "enemy"
var city_seed := 7
var best_stars := {}
## Syndicate campaign: best stars per mission (by index as a string) and which mission the
## next attack is on. A mission opens once the one before it has at least one star.
var syndicate_stars := {}
var syndicate_mission := 0
## Noa's tutorial: the index of the current step in TutorialSteps.STEPS, or -1 once it is done.
var tutorial := -1
## True while the tutorial is replayed from Settings: every step is just a tap, nothing is
## forced, there is no gift, and the save keeps it finished.
var tutorial_replay := false
## Gems just handed out for finishing the tutorial, for the base screen to announce once.
var tutorial_gift := 0
signal tutorial_changed
## Running totals for missions: coins_collected, fuel_collected, train, train_<unit>, build,
## upgrade, win, three_stars, raid_win.
var stats := {}
## Indexes of the starter missions already claimed.
var starter_claimed: Array = []
## Today's missions: {date, keys, base (stats at the start of the day), claimed, bonus}.
var daily := {}
## Login gift: {day (gifts taken so far), last (date of the last one)}.
var login := {"day": 0, "last": ""}
signal missions_changed
## Cosmetics (see Store): which are owned, which is worn in each slot, and whether the one-time
## starter pack was bought.
var cosmetics_owned: Array = []
var cosmetics_worn := {}
var starter_bought := false

const SETTINGS_PATH := "user://settings.json"
## Development only: coins, fuel and gems cost nothing. Forced off in release exports,
## where OS.is_debug_build() is false, so players can never get it.
var infinite_coins := false
var sound_on := true
var music_on := true


func _ready() -> void:
	I18n.setup_font()
	load_settings()
	# Dev: `-- --fresh` shows a brand-new player's base without touching the real save.
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--fresh"):
		persist = false
		infinite_coins = false
		new_player()
		# Dev: `--tutorial N` jumps to step N of Noa's tutorial.
		var args := OS.get_cmdline_user_args()
		if args.has("--tutorial"):
			tutorial = int(args[args.find("--tutorial") + 1])
	elif not load_game():
		new_player()


func dev_tools_available() -> bool:
	return OS.is_debug_build()


func set_infinite_coins(on: bool) -> void:
	infinite_coins = on and dev_tools_available()
	save_settings()


func set_sound(on: bool) -> void:
	sound_on = on
	save_settings()


func set_music(on: bool) -> void:
	music_on = on
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
		music_on = bool(data.get("music", true))


func save_settings() -> void:
	if not persist:
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"lang": I18n.lang, "infinite_coins": infinite_coins, "sound": sound_on, "music": music_on}))


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
		{"type": "aa", "cell": [3, 3], "level": 1},
		{"type": "camp", "cell": [3, 5], "level": 1},
		{"type": "quarters", "cell": [5, 5], "level": 1},
	]
	units = {"infantry": 1, "courier": 1}
	walls = []
	abilities = {"flare": 1}
	support_ready = {}
	support_queue = []
	# Room for one more squad, which Noa has the player train.
	army = {"infantry": 1, "courier": 2}
	training = []
	train_started = 0.0
	enemy_index = 0
	raid_target = "enemy"
	best_stars = {}
	syndicate_stars = {}
	syndicate_mission = 0
	tutorial = 0
	tutorial_replay = false
	stats = {}
	starter_claimed = []
	daily = {}
	login = {"day": 0, "last": ""}
	cosmetics_owned = []
	cosmetics_worn = {}
	starter_bought = false
	save_game()


# ---------------------------------------------------------------- missions

func add_stat(key: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	stats[key] = int(stats.get(key, 0)) + amount
	missions_changed.emit()


func today() -> String:
	return Time.get_date_string_from_system()


## [done so far, needed] for a mission check (see Missions). Daily counters count from `base`.
func mission_progress(check: Array, base: Dictionary = {}) -> Array:
	match str(check[0]):
		"hq":
			return [mini(hq_level(), int(check[1])), int(check[1])]
		"count":
			var built := structures.filter(func(s: Dictionary) -> bool: return s["type"] == check[1] and not s.get("fresh", false)).size()
			return [mini(built, int(check[2])), int(check[2])]
		"level":
			var best := 0
			for l in _working_levels(check[1]):
				best = maxi(best, int(l))
			return [mini(best, int(check[2])), int(check[2])]
		"walls":
			return [mini(walls.size(), int(check[1])), int(check[1])]
		"unit":
			return [1 if units.has(check[1]) else 0, 1]
		"mission":
			return [1 if int(syndicate_stars.get(str(check[1]), 0)) > 0 else 0, 1]
		"stars":
			return [mini(syndicate_total_stars(), int(check[1])), int(check[1])]
		"stat":
			var n := int(stats.get(check[1], 0)) - int(base.get(check[1], 0))
			return [clampi(n, 0, int(check[2])), int(check[2])]
	return [0, 1]


static func _complete_progress(p: Array) -> bool:
	return int(p[0]) >= int(p[1])


## "claimed", "claim" (done, reward waiting), "open" (in progress) or "locked" (its day has not
## opened: the day before is not all claimed yet).
func starter_state(i: int) -> String:
	if starter_claimed.has(i):
		return "claimed"
	var day := int(Missions.STARTER[i]["day"])
	for j in Missions.STARTER.size():
		if int(Missions.STARTER[j]["day"]) < day and not starter_claimed.has(j):
			return "locked"
	return "claim" if _complete_progress(mission_progress(Missions.STARTER[i]["check"])) else "open"


func starter_done() -> bool:
	return starter_claimed.size() >= Missions.STARTER.size()


func claim_starter(i: int) -> bool:
	if starter_state(i) != "claim":
		return false
	starter_claimed.append(i)
	_give(Missions.STARTER[i]["reward"])
	return true


## Starts a new set of daily missions when the date has changed.
func refresh_daily() -> void:
	if str(daily.get("date", "")) == today():
		return
	daily = {"date": today(), "keys": Missions.daily_keys(today()), "base": stats.duplicate(), "claimed": [], "bonus": false}
	save_game()


func daily_progress(key: String) -> Array:
	return mission_progress(Missions.DAILY[key]["check"], daily.get("base", {}))


func daily_state(key: String) -> String:
	if daily.get("claimed", []).has(key):
		return "claimed"
	return "claim" if _complete_progress(daily_progress(key)) else "open"


## Pays a daily mission, and the bonus once all of the missions of the day are paid.
func claim_daily(key: String) -> bool:
	refresh_daily()
	if not daily["keys"].has(key) or daily_state(key) != "claim":
		return false
	daily["claimed"].append(key)
	if daily["claimed"].size() >= daily["keys"].size() and not daily["bonus"]:
		daily["bonus"] = true
		gems += Missions.DAILY_BONUS
	_give(Missions.DAILY[key]["reward"])
	return true


func login_ready() -> bool:
	return str(login.get("last", "")) != today()


## The login gift waiting today (a missed day does not reset the week, it just waits).
func login_gift() -> Dictionary:
	return Missions.LOGIN[int(login.get("day", 0)) % Missions.LOGIN.size()]


func claim_login() -> bool:
	if not login_ready():
		return false
	var gift := login_gift()
	login = {"day": int(login.get("day", 0)) + 1, "last": today()}
	_give(gift)
	return true


## How many rewards are waiting: the red badge on the Missions button.
func missions_ready() -> int:
	refresh_daily()
	var n := 1 if login_ready() else 0
	for i in Missions.STARTER.size():
		if starter_state(i) == "claim":
			n += 1
	for key in daily["keys"]:
		if daily_state(key) == "claim":
			n += 1
	return n


func _give(reward: Dictionary) -> void:
	add_coins(int(reward.get("coins", 0)))
	add_fuel(int(reward.get("fuel", 0)))
	gems += int(reward.get("gems", 0))
	save_game()
	missions_changed.emit()


# ---------------------------------------------------------------- store

## Empty when the cosmetic can be bought with gems now; otherwise why not.
func cosmetic_block_reason(id: String) -> String:
	if cosmetics_owned.has(id):
		return I18n.t("Owned")
	var cost := int(Store.COSMETICS[id]["gems"])
	if cost <= 0:
		return I18n.t("Comes in the starter pack")
	return "" if infinite_coins or gems >= cost else I18n.t("Need %d more gems") % (cost - gems)


func buy_cosmetic(id: String) -> bool:
	if cosmetic_block_reason(id) != "":
		return false
	_spend_gems(int(Store.COSMETICS[id]["gems"]))
	cosmetics_owned.append(id)
	wear_cosmetic(id)
	return true


## Puts on an owned cosmetic (or takes it off, when it is already worn).
func wear_cosmetic(id: String) -> void:
	if not cosmetics_owned.has(id):
		return
	var slot: String = Store.COSMETICS[id]["slot"]
	if cosmetics_worn.get(slot, "") == id:
		cosmetics_worn.erase(slot)
	else:
		cosmetics_worn[slot] = id
	save_game()


## Back to the classic look in a slot.
func wear_default(slot: String) -> void:
	cosmetics_worn.erase(slot)
	save_game()


## Gives what a real-money purchase pays for (called once the store confirms the payment).
func grant_purchase(product: String) -> void:
	if product == Store.STARTER["id"]:
		starter_bought = true
		add_coins(int(Store.STARTER["coins"]))
		add_fuel(int(Store.STARTER["fuel"]))
		gems += int(Store.STARTER["gems"])
		var flag: String = Store.STARTER["cosmetic"]
		if not cosmetics_owned.has(flag):
			cosmetics_owned.append(flag)
			cosmetics_worn[Store.COSMETICS[flag]["slot"]] = flag
	else:
		for p: Dictionary in Store.PACKS:
			if p["id"] == product:
				gems += int(p["gems"])
	save_game()


# ---------------------------------------------------------------- tutorial

func tutorial_key() -> String:
	return TutorialSteps.STEPS[tutorial]["key"] if tutorial >= 0 else ""


## Something the player did; it ends the current step if that step waits for it.
func tutorial_event(name: String) -> void:
	if tutorial < 0 or tutorial_replay or TutorialSteps.STEPS[tutorial].get("done", "") != name:
		return
	tutorial_next()


func tutorial_next() -> void:
	if tutorial < 0:
		return
	tutorial += 1
	if tutorial >= TutorialSteps.STEPS.size():
		tutorial = -1
		if not tutorial_replay:
			gems += TutorialSteps.GIFT_GEMS
			tutorial_gift = TutorialSteps.GIFT_GEMS
		tutorial_replay = false
	elif tutorial_key() == "upgrade" and not tutorial_replay:
		# The upgrade must be affordable even after a poor first battle.
		coins = maxi(coins, mini(Catalog.upgrade_cost("hq", hq_level()), coin_cap()))
	save_game()
	tutorial_changed.emit()


func skip_tutorial() -> void:
	tutorial = -1
	tutorial_replay = false
	save_game()
	tutorial_changed.emit()


func replay_tutorial() -> void:
	tutorial = 0
	tutorial_replay = true
	tutorial_changed.emit()


# ---------------------------------------------------------------- queries

func hq_level() -> int:
	for s in structures:
		if s["type"] == "hq":
			return int(s["level"])
	return 1


## Level of the first finished structure of this type, or 0 if there is none.
func level_of(type: String) -> int:
	var levels := _working_levels(type)
	return 0 if levels.is_empty() else int(levels[0])


func hangar_level() -> int:
	return level_of("hangar")


func camp_level() -> int:
	return level_of("camp")


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
	return Catalog.army_capacity(_working_levels("quarters"))


static func _space(counts: Dictionary) -> int:
	var used := 0
	for type in counts:
		used += int(counts[type]) * int(Catalog.unit_def(type)["housing"])
	return used


## Space taken by the trained army.
func army_used() -> int:
	return _space(army)


## Space the training queue will take once it is done.
func queued_space() -> int:
	var n := 0
	for type in training:
		n += int(Catalog.unit_def(type)["housing"])
	return n


func unit_stats_for(type: String) -> Dictionary:
	return Catalog.unit_stats(type, int(units.get(type, 1)))


## Seconds until the first unit in the queue is done (0 when the queue is empty).
func train_head_left() -> float:
	if training.is_empty():
		return 0.0
	return maxf(0.0, train_started + Catalog.train_seconds(training[0], camp_level()) - now())


## Seconds until the whole queue is done.
func train_total_left() -> float:
	if training.is_empty():
		return 0.0
	var total := train_head_left()
	for i in range(1, training.size()):
		total += Catalog.train_seconds(training[i], camp_level())
	return total


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
	# Traps go in at once and need no worker.
	return money if money != "" or Catalog.is_trap(type) else _worker_reason()


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
	if level >= Catalog.MAX_LEVEL or Catalog.is_trap(s["type"]):
		return I18n.t("Max level")
	if s["type"] != "hq" and level >= hq_level():
		return I18n.t("Upgrade the Command Tower first")
	var money := _coins_reason(Catalog.upgrade_cost(s["type"], level))
	return money if money != "" else _worker_reason()


## Why `type` can't be unlocked or upgraded right now ("" if it can). The Garage caps
## ground units and the Hangar caps drones.
func unit_block_reason(type: String) -> String:
	var ground := Catalog.is_ground(type)
	var lab := level_of(Catalog.unit_lab(type))
	var needed := Catalog.unit_lab_level(type)
	if lab < needed:
		return (I18n.t("Needs Garage Lv %d") if ground else I18n.t("Needs Hangar Lv %d")) % needed
	if units.has(type):
		var level := int(units[type])
		if level >= Catalog.MAX_LEVEL:
			return I18n.t("Max level")
		if level >= lab:
			return I18n.t("Upgrade the Garage first") if ground else I18n.t("Upgrade the Hangar first")
		return _fuel_reason(Catalog.unit_upgrade_cost(type, level))
	return _fuel_reason(int(Catalog.unit_def(type)["unlock"]))


## Why one more `type` can't be queued for training ("" if it can).
func train_block_reason(type: String) -> String:
	if camp_level() <= 0:
		return I18n.t("Build a Training Camp first")
	if not units.has(type):
		return I18n.t("Locked")
	if army_capacity() <= 0:
		return I18n.t("Build Quarters first")
	if army_used() + queued_space() + int(Catalog.unit_def(type)["housing"]) > army_capacity():
		return I18n.t("Not enough army space")
	return _fuel_reason(Catalog.train_fuel(type))


## The player's own base in the same format as enemy bases, for the defense test.
func player_base() -> Dictionary:
	var pad := [City.GRID - 1, City.GRID - 1]
	for c in range(City.GRID - 1, -1, -1):
		if structure_at([c, City.GRID - 1]).is_empty():
			pad = [c, City.GRID - 1]
			break
	var built := structures.filter(func(s: Dictionary) -> bool: return not s.get("fresh", false))
	return {"name": I18n.t("Your Base (practice)"), "seed": city_seed, "pad": pad, "structures": built, "walls": walls}


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
	var got := add_coins(taken) if s["type"] == "generator" else add_fuel(taken)
	add_stat("coins_collected" if s["type"] == "generator" else "fuel_collected", got)
	return got


func build(type: String, cell: Array) -> bool:
	if build_block_reason(type) != "" or not structure_at(cell).is_empty():
		return false
	_spend(Catalog.build_cost(type))
	var s := {"type": type, "cell": [int(cell[0]), int(cell[1])], "level": 1}
	if not Catalog.is_trap(type):
		s["fresh"] = true
		s["busy_until"] = now() + Catalog.build_seconds(type, 1)
	structures.append(s)
	add_stat("build")
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
	add_stat("upgrade")
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
	if s.is_empty() or not is_busy(s) or tutorial_key() == "speed":
		return 0
	return Catalog.speedup_gems(seconds_left(s))


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


## Moves a structure to a free pad, for free (base layout is part of the strategy).
func move(from: Array, to: Array) -> bool:
	var s := structure_at(from)
	if s.is_empty() or not structure_at(to).is_empty():
		return false
	if int(to[0]) < 0 or int(to[1]) < 0 or int(to[0]) >= City.GRID or int(to[1]) >= City.GRID:
		return false
	s["cell"] = [int(to[0]), int(to[1])]
	save_game()
	return true


func remove(cell: Array) -> bool:
	var s := structure_at(cell)
	if s.is_empty() or s["type"] == "hq" or is_busy(s):
		return false
	structures.erase(s)
	save_game()
	return true


# ---------------------------------------------------------------- support base

func support_slots() -> int:
	return Catalog.support_slots(level_of("support"))


static func _slots_of(kind: String) -> int:
	return int(Catalog.ABILITIES[kind]["slots"])


## Slots taken by what is ready plus what is being prepared.
func support_used() -> int:
	var n := 0
	for kind in support_ready:
		n += int(support_ready[kind]) * _slots_of(kind)
	for kind in support_queue:
		n += _slots_of(kind)
	return n


func prepare_block_reason(kind: String) -> String:
	if level_of("support") <= 0:
		return I18n.t("Build a Support Base first")
	if not abilities.has(kind):
		return I18n.t("Locked")
	if support_used() + _slots_of(kind) > support_slots():
		return I18n.t("No free slots")
	return _fuel_reason(int(Catalog.ABILITIES[kind]["fuel"]))


func prepare(kind: String) -> bool:
	if prepare_block_reason(kind) != "":
		return false
	process_support()
	_spend_fuel(int(Catalog.ABILITIES[kind]["fuel"]))
	if support_queue.is_empty():
		support_started = now()
	support_queue.append(kind)
	save_game()
	return true


func cancel_prepare(kind: String) -> bool:
	var index := support_queue.rfind(kind)
	if index < 0:
		return false
	support_queue.remove_at(index)
	if not infinite_coins:
		fuel = mini(fuel_cap(), fuel + int(Catalog.ABILITIES[kind]["fuel"]))
	if index == 0:
		support_started = now()
	save_game()
	return true


## Moves every finished ability from the queue to ready. Returns how many finished.
func process_support() -> int:
	if level_of("support") <= 0:
		return 0
	var done := 0
	while not support_queue.is_empty():
		var kind: String = support_queue[0]
		var ready_at := support_started + float(Catalog.ABILITIES[kind]["seconds"])
		if ready_at > now():
			break
		support_queue.remove_at(0)
		support_ready[kind] = int(support_ready.get(kind, 0)) + 1
		support_started = ready_at
		done += 1
	if done > 0:
		save_game()
	return done


func support_head_left() -> float:
	if support_queue.is_empty():
		return 0.0
	return maxf(0.0, support_started + float(Catalog.ABILITIES[support_queue[0]]["seconds"]) - now())


func support_total_left() -> float:
	var total := support_head_left()
	for i in range(1, support_queue.size()):
		total += float(Catalog.ABILITIES[support_queue[i]]["seconds"])
	return total


func speed_up_support() -> bool:
	if support_queue.is_empty():
		return false
	var cost := Catalog.speedup_gems(support_total_left())
	if not infinite_coins and gems < cost:
		return false
	_spend_gems(cost)
	for kind in support_queue:
		support_ready[kind] = int(support_ready.get(kind, 0)) + 1
	support_queue = []
	save_game()
	return true


## Removes the abilities an attack used.
func use_support(used: Dictionary) -> void:
	for kind in used:
		support_ready[kind] = maxi(0, int(support_ready.get(kind, 0)) - int(used[kind]))
		if support_ready[kind] == 0:
			support_ready.erase(kind)
	save_game()


## Why an ability can't be unlocked or upgraded ("" if it can). The Support Base caps it.
func ability_block_reason(kind: String) -> String:
	var base := level_of("support")
	var needed := int(Catalog.ABILITIES[kind]["support"])
	if base < needed:
		return I18n.t("Needs Support Base Lv %d") % needed
	if abilities.has(kind):
		var lvl := int(abilities[kind])
		if lvl >= Catalog.MAX_LEVEL:
			return I18n.t("Max level")
		if lvl >= base:
			return I18n.t("Upgrade the Support Base first")
		return _fuel_reason(Catalog.ability_upgrade_cost(kind, lvl))
	return _fuel_reason(int(Catalog.ABILITIES[kind]["unlock"]))


func upgrade_ability(kind: String) -> bool:
	if ability_block_reason(kind) != "":
		return false
	if abilities.has(kind):
		_spend_fuel(Catalog.ability_upgrade_cost(kind, int(abilities[kind])))
		abilities[kind] = int(abilities[kind]) + 1
	else:
		_spend_fuel(int(Catalog.ABILITIES[kind]["unlock"]))
		abilities[kind] = 1
	save_game()
	return true


# ---------------------------------------------------------------- walls

func wall_at(edge: Array) -> Dictionary:
	var k := Walls.key(edge)
	for w in walls:
		if Walls.key(w["edge"]) == k:
			return w
	return {}


func wall_block_reason() -> String:
	if walls.size() >= Catalog.wall_limit(hq_level()):
		return I18n.t("Wall limit reached (%d)") % Catalog.wall_limit(hq_level())
	return _coins_reason(Catalog.WALL_COST)


## Puts a level 1 wall piece on an empty path. Instant, no worker.
func build_wall(edge: Array) -> bool:
	if not Walls.valid(edge) or not wall_at(edge).is_empty() or wall_block_reason() != "":
		return false
	_spend(Catalog.WALL_COST)
	walls.append({"edge": [int(edge[0]), int(edge[1]), int(edge[2])], "level": 1})
	save_game()
	return true


func wall_upgrade_reason(edge: Array) -> String:
	var w := wall_at(edge)
	if w.is_empty():
		return I18n.t("Nothing here")
	var level := int(w["level"])
	if level >= Catalog.MAX_LEVEL:
		return I18n.t("Max level")
	if level >= hq_level():
		return I18n.t("Upgrade the Command Tower first")
	return _coins_reason(Catalog.wall_upgrade_cost(level))


func upgrade_wall(edge: Array) -> bool:
	if wall_upgrade_reason(edge) != "":
		return false
	var w := wall_at(edge)
	_spend(Catalog.wall_upgrade_cost(int(w["level"])))
	w["level"] = int(w["level"]) + 1
	save_game()
	return true


## Upgrades every wall piece at `level`, as far as the coins go. Returns how many.
func upgrade_walls_at_level(level: int) -> int:
	var done := 0
	for w in walls:
		if int(w["level"]) == level and wall_upgrade_reason(w["edge"]) == "":
			_spend(Catalog.wall_upgrade_cost(level))
			w["level"] = level + 1
			done += 1
	if done > 0:
		save_game()
	return done


func remove_wall(edge: Array) -> bool:
	var w := wall_at(edge)
	if w.is_empty():
		return false
	walls.erase(w)
	save_game()
	return true


func upgrade_unit(type: String) -> bool:
	if unit_block_reason(type) != "":
		return false
	if units.has(type):
		_spend_fuel(Catalog.unit_upgrade_cost(type, int(units[type])))
		units[type] = int(units[type]) + 1
	else:
		_spend_fuel(int(Catalog.unit_def(type)["unlock"]))
		units[type] = 1
	save_game()
	return true


# ---------------------------------------------------------------- training

## Adds one unit to the end of the training queue and pays its fuel.
func train(type: String) -> bool:
	if train_block_reason(type) != "":
		return false
	process_training()
	_spend_fuel(Catalog.train_fuel(type))
	if training.is_empty():
		train_started = now()
	training.append(type)
	add_stat("train")
	add_stat("train_" + type)
	save_game()
	return true


## Takes the last queued unit of `type` out of the queue and refunds its fuel.
func cancel_training(type: String) -> bool:
	var index := training.rfind(type)
	if index < 0:
		return false
	training.remove_at(index)
	if not infinite_coins:
		fuel = mini(fuel_cap(), fuel + Catalog.train_fuel(type))
	if index == 0:
		train_started = now()
	save_game()
	return true


## Moves every finished unit from the queue into the army. A unit that is done but has no
## room waits at the head of the queue. Returns how many units finished.
func process_training() -> int:
	var done := 0
	var camp := camp_level()
	if camp <= 0:
		return 0
	while not training.is_empty():
		var type: String = training[0]
		var ready_at := train_started + Catalog.train_seconds(type, camp)
		if ready_at > now():
			break
		if army_used() + int(Catalog.unit_def(type)["housing"]) > army_capacity():
			train_started = now() - Catalog.train_seconds(type, camp)
			break
		training.remove_at(0)
		army[type] = int(army.get(type, 0)) + 1
		train_started = ready_at
		done += 1
	if done > 0:
		save_game()
	return done


func training_speedup_cost() -> int:
	return Catalog.speedup_gems(train_total_left())


## Finishes the whole queue right away for gems.
func speed_up_training() -> bool:
	if training.is_empty():
		return false
	var cost := training_speedup_cost()
	if not infinite_coins and gems < cost:
		return false
	_spend_gems(cost)
	for type in training:
		army[type] = int(army.get(type, 0)) + 1
	training = []
	save_game()
	return true


## Removes the units an attack deployed from the army.
func use_army(deployed: Dictionary) -> void:
	for type in deployed:
		army[type] = maxi(0, int(army.get(type, 0)) - int(deployed[type]))
		if army[type] == 0:
			army.erase(type)
	process_training()
	save_game()


## How many Syndicate missions are open to attack (the first is always open).
func syndicate_open() -> int:
	var n := 1
	while n < Syndicate.COUNT and int(syndicate_stars.get(str(n - 1), 0)) > 0:
		n += 1
	return n


func syndicate_total_stars() -> int:
	var total := 0
	for k in syndicate_stars:
		total += int(syndicate_stars[k])
	return total


## Records a Syndicate battle. The first win of a mission pays its reward on top of the loot.
## Returns {coins, fuel, gems, first} actually banked.
func record_syndicate(index: int, stars: int, loot: int, loot_fuel: int) -> Dictionary:
	var key := str(index)
	var first := stars > 0 and int(syndicate_stars.get(key, 0)) == 0
	syndicate_stars[key] = maxi(int(syndicate_stars.get(key, 0)), stars)
	var reward: Dictionary = Syndicate.MISSIONS[index]["reward"] if first else {}
	_count_win(stars)
	var got := {"coins": add_coins(loot + int(reward.get("coins", 0))), "fuel": add_fuel(loot_fuel + int(reward.get("fuel", 0))),
		"gems": int(reward.get("gems", 0)), "first": first}
	gems += int(got["gems"])
	save_game()
	return got


func _count_win(stars: int) -> void:
	if stars > 0:
		add_stat("win")
	if stars >= 3:
		add_stat("three_stars")


## Banks the loot of an attack on an enemy. Returns {coins, fuel} actually banked.
func record_raid(stars: int, loot: int, loot_fuel: int = 0) -> Dictionary:
	if raid_target == "syndicate":
		return record_syndicate(syndicate_mission, stars, loot, loot_fuel)
	if raid_target != "enemy":
		return {"coins": 0, "fuel": 0}
	var key := str(enemy_index)
	best_stars[key] = maxi(int(best_stars.get(key, 0)), stars)
	if stars > 0:
		enemy_index += 1
		add_stat("raid_win")
	_count_win(stars)
	return {"coins": add_coins(loot), "fuel": add_fuel(loot_fuel)}


# ---------------------------------------------------------------- save

## Saves from before ground units have no Training Camp or Quarters: put one of each on
## the free pads closest to the middle.
func _add_army_buildings() -> void:
	for type in ["camp", "quarters"]:
		if count_of(type) > 0:
			continue
		var best := []
		var best_d := INF
		for c in City.GRID:
			for r in City.GRID:
				var d := Vector2(c - 4, r - 4).length()
				if d < best_d and structure_at([c, r]).is_empty():
					best_d = d
					best = [c, r]
		if not best.is_empty():
			structures.append({"type": type, "cell": best, "level": 1})


func save_game() -> void:
	if not persist:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file")
		return
	file.store_string(JSON.stringify(save_data()))
	file.close()
	# A signed-in player's base also goes to the cloud (a few seconds later, in one go).
	var cloud := get_node_or_null("/root/Cloud") if is_inside_tree() else null
	if cloud != null:
		cloud.queue_push()


## Everything the save holds, as plain data (the save file and the cloud copy).
func save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION, "coins": coins, "fuel": fuel, "gems": gems, "workers": workers,
		"structures": structures, "units": units, "army": army, "training": training, "walls": walls,
		"abilities": abilities, "support_ready": support_ready, "support_queue": support_queue, "support_started": support_started,
		"train_started": train_started, "enemy_index": enemy_index, "city_seed": city_seed, "best_stars": best_stars,
		"syndicate_stars": syndicate_stars, "syndicate_mission": syndicate_mission,
		"tutorial": -1 if tutorial_replay else tutorial,
		"stats": stats, "starter_claimed": starter_claimed, "daily": daily, "login": login,
		"cosmetics_owned": cosmetics_owned, "cosmetics_worn": cosmetics_worn, "starter_bought": starter_bought,
	}


func load_game() -> bool:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return false
	return apply_save(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)))


## Loads a save (from the file or the cloud). False, and nothing changed, when it isn't one.
func apply_save(data: Variant) -> bool:
	# Version 4 saves (before ground units) load too: their drones become units.
	if not (data is Dictionary) or int(data.get("version", 0)) not in [4, 5, 6, 7, 8, 9, 10, SAVE_VERSION]:
		return false
	coins = int(data["coins"])
	fuel = int(data.get("fuel", 0))
	gems = int(data.get("gems", 0))
	workers = int(data.get("workers", Catalog.START_WORKERS))
	structures = data["structures"]
	for s in structures:
		s["level"] = int(s["level"])
		s["cell"] = [int(s["cell"][0]), int(s["cell"][1])]
		s["type"] = RETIRED.get(s["type"], s["type"])
		for k: String in ["collected_at", "busy_until"]:
			if s.has(k):
				s[k] = float(s[k])
	units = {"infantry": 1}
	var saved_units: Dictionary = data.get("units", data.get("drones", {}))
	for k in saved_units:
		units[k] = int(saved_units[k])
	army = {}
	for k in data.get("army", {}):
		if int(data["army"][k]) > 0:
			army[k] = int(data["army"][k])
	training = []
	for k in data.get("training", []):
		training.append(str(k))
	train_started = float(data.get("train_started", now()))
	abilities = {"flare": 1}
	for k in data.get("abilities", {}):
		abilities[k] = int(data["abilities"][k])
	support_ready = {}
	for k in data.get("support_ready", {}):
		if int(data["support_ready"][k]) > 0:
			support_ready[k] = int(data["support_ready"][k])
	support_queue = []
	for k in data.get("support_queue", []):
		support_queue.append(str(k))
	support_started = float(data.get("support_started", now()))
	walls = []
	for w in data.get("walls", []):
		walls.append({"edge": [int(w["edge"][0]), int(w["edge"][1]), int(w["edge"][2])], "level": int(w["level"])})
	if int(data["version"]) == 4:
		_add_army_buildings()
	enemy_index = int(data.get("enemy_index", 0))
	city_seed = int(data.get("city_seed", 7))
	best_stars = data.get("best_stars", {})
	syndicate_stars = {}
	for k in data.get("syndicate_stars", {}):
		syndicate_stars[str(k)] = int(data["syndicate_stars"][k])
	syndicate_mission = int(data.get("syndicate_mission", 0))
	# Players from before the tutorial (save 8 and older) already know the game.
	tutorial = int(data.get("tutorial", -1))
	tutorial_replay = false
	# Missions arrived in save 10; older saves start them now.
	stats = {}
	for k in data.get("stats", {}):
		stats[str(k)] = int(data["stats"][k])
	starter_claimed = []
	for i in data.get("starter_claimed", []):
		starter_claimed.append(int(i))
	daily = data.get("daily", {})
	if not daily.is_empty():
		daily["claimed"] = Array(daily.get("claimed", []))
		daily["keys"] = Array(daily.get("keys", []))
	var saved_login: Dictionary = data.get("login", {})
	login = {"day": int(saved_login.get("day", 0)), "last": str(saved_login.get("last", ""))}
	# Cosmetics arrived in save 11.
	cosmetics_owned = []
	for id in data.get("cosmetics_owned", []):
		if Store.COSMETICS.has(str(id)):
			cosmetics_owned.append(str(id))
	cosmetics_worn = {}
	var worn: Dictionary = data.get("cosmetics_worn", {})
	for slot in worn:
		if cosmetics_owned.has(str(worn[slot])):
			cosmetics_worn[str(slot)] = str(worn[slot])
	starter_bought = bool(data.get("starter_bought", false))
	return true
