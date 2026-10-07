extends RefCounted


const HQ := [4, 4]
const GENERATOR := [3, 4]
const PUMP := [4, 5]
const HANGAR := [5, 4]
const CAMP := [3, 5]
const QUARTERS := [5, 5]


func _fresh_state() -> Node:
	var gs: Node = load("res://scripts/autoload/game_state.gd").new()
	gs.persist = false
	gs.new_player()
	return gs


## Pretends every running build or upgrade has finished.
func _skip_time(gs: Node) -> void:
	for s in gs.structures:
		if s.has("busy_until"):
			s["busy_until"] = 0.0
	gs.finish_ready()


func test_upgrade_costs_grow() -> bool:
	for type in ["hq", "generator", "mg", "mortar"]:
		for lvl in range(1, Catalog.MAX_LEVEL):
			if Catalog.upgrade_cost(type, lvl + 1) <= Catalog.upgrade_cost(type, lvl):
				return false
	return true


func test_defense_stats_scale_with_level() -> bool:
	var l1 := Catalog.defense_stats("mg", 1)
	var l3 := Catalog.defense_stats("mg", 3)
	var n1 := Catalog.defense_stats("at", 1)
	var n3 := Catalog.defense_stats("at", 3)
	return l3["radius"] > l1["radius"] and l3["dps"] > l1["dps"] and n3["cooldown"] < n1["cooldown"]


func test_limits_follow_command_tower() -> bool:
	return Catalog.max_count("jammer", 1) == 0 and Catalog.max_count("jammer", 3) == 1 and Catalog.max_count("mg", 2) == 2


func test_generated_bases_are_valid() -> bool:
	for seed_value in range(1000, 1040):
		for hq in range(1, Catalog.MAX_LEVEL + 1):
			var b := Bases.generate(seed_value, hq)
			var seen := {"%d,%d" % b["pad"]: true}
			var counts := {}
			for s in b["structures"]:
				var key := "%d,%d" % s["cell"]
				if seen.has(key):
					return false
				seen[key] = true
				counts[s["type"]] = int(counts.get(s["type"], 0)) + 1
				if int(s["level"]) < 1 or int(s["level"]) > hq:
					return false
			if int(counts.get("hq", 0)) != 1:
				return false
			for type in counts:
				if counts[type] > Catalog.max_count(type, hq):
					return false
	return true


func test_new_player_can_build_one_more_generator_only_after_upgrade() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	var blocked: bool = gs.build("generator", [0, 0]) == false
	gs.upgrade(HQ)
	_skip_time(gs)
	var allowed: bool = gs.build("generator", [0, 0])
	gs.free()
	return blocked and allowed


func test_buildings_cannot_outlevel_command_tower() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	var reason: String = gs.upgrade_block_reason(GENERATOR)
	gs.free()
	return reason == "Upgrade the Command Tower first"


func test_command_tower_cannot_be_removed() -> bool:
	var gs := _fresh_state()
	var removed: bool = gs.remove(HQ)
	gs.free()
	return not removed


func test_building_costs_coins_and_occupies_roof() -> bool:
	var gs := _fresh_state()
	gs.coins = 1000
	gs.upgrade(HQ)
	_skip_time(gs)
	gs.coins = 1000
	var before: int = gs.coins
	var ok: bool = gs.build("at", [0, 0])
	var paid: bool = gs.coins == before - Catalog.build_cost("at")
	var twice: bool = gs.build("mg", [0, 0])
	gs.free()
	return ok and paid and not twice


func test_scout_needs_hangar_level_two() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.fuel = 2000
	var first_reason: String = gs.unit_block_reason("scout")
	gs.upgrade(HQ)
	_skip_time(gs)
	gs.upgrade(HANGAR)
	_skip_time(gs)
	var unlocked: bool = gs.upgrade_unit("scout")
	var first: String = first_reason
	gs.free()
	return first == "Needs Hangar Lv 2" and unlocked


func test_training_respects_army_space() -> bool:
	var gs := _fresh_state()
	gs.fuel = 5000
	gs.army = {}
	var cap: int = gs.army_capacity()
	var queued := 0
	while gs.train("infantry"):
		queued += 1
	var locked: bool = gs.train("scout") == false
	gs.free()
	return queued == cap / 3 and locked


func test_generator_collect_keeps_overflow() -> bool:
	var gs := _fresh_state()
	var gen: Dictionary = gs.structure_at(GENERATOR)
	gen["collected_at"] = Time.get_unix_time_from_system() - 100.0 * 60.0
	gs.coins = gs.coin_cap() - 50
	var got: int = gs.collect_generator(GENERATOR)
	var left: int = gs.generator_pending(gen)
	gs.free()
	return got == 50 and left > 400


func test_infinite_coins_make_everything_free() -> bool:
	var gs := _fresh_state()
	gs.coins = 0
	gs.infinite_coins = true
	var upgraded: bool = gs.upgrade(HQ)
	_skip_time(gs)
	var built: bool = gs.build("at", [0, 0])
	var unchanged: bool = gs.coins == 0
	gs.free()
	return upgraded and built and unchanged


func test_coins_are_capped() -> bool:
	var gs := _fresh_state()
	gs.add_coins(1_000_000)
	var capped: bool = gs.coins == gs.coin_cap()
	gs.free()
	return capped


func test_upgrade_takes_time_and_a_worker() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.upgrade(HQ)
	var still_one: bool = gs.hq_level() == 1 and gs.free_workers() == 1
	_skip_time(gs)
	var done: bool = gs.hq_level() == 2 and gs.free_workers() == 2
	gs.free()
	return still_one and done


func test_workers_limit_parallel_builds() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.upgrade(HQ)
	_skip_time(gs)
	var a: bool = gs.build("generator", [0, 0])
	var b: bool = gs.build("storage", [1, 0])
	var reason: String = gs.build_block_reason("pump")
	var c: bool = gs.build("pump", [2, 0])
	gs.free()
	return a and b and not c and reason == "All workers are busy"


func test_fresh_build_produces_nothing_until_done() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.upgrade(HQ)
	_skip_time(gs)
	gs.build("pump", [0, 0])
	var p: Dictionary = gs.structure_at([0, 0])
	var idle: bool = gs.generator_pending(p) == 0 and gs.collect_generator([0, 0]) == 0
	var cant_upgrade: bool = gs.upgrade_block_reason([0, 0]) == "Under construction"
	var cant_remove: bool = gs.remove([0, 0]) == false
	gs.free()
	return idle and cant_upgrade and cant_remove


func test_speed_up_costs_gems_and_finishes() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.upgrade(HQ)
	var cost: int = gs.speedup_cost(HQ)
	var gems_before: int = gs.gems
	var ok: bool = gs.speed_up(HQ)
	var result: bool = ok and cost > 0 and gs.gems == gems_before - cost and gs.hq_level() == 2
	gs.free()
	return result


func test_speedup_gems_grow_with_time() -> bool:
	return Catalog.speedup_gems(0.0) == 0 and Catalog.speedup_gems(5.0) == 1 \
		and Catalog.speedup_gems(3600.0) == 20 and Catalog.speedup_gems(86400.0) == 260 \
		and Catalog.speedup_gems(7200.0) > Catalog.speedup_gems(3600.0)


func test_build_times_grow_with_level() -> bool:
	for lvl in range(1, Catalog.MAX_LEVEL):
		if Catalog.build_seconds("mg", lvl + 1) <= Catalog.build_seconds("mg", lvl):
			return false
	return Catalog.build_seconds("hq", 2) > Catalog.build_seconds("mg", 2)


func test_hire_worker_costs_gems() -> bool:
	var gs := _fresh_state()
	gs.gems = Catalog.WORKER_GEMS - 1
	var too_poor: bool = gs.hire_worker() == false
	gs.gems = Catalog.WORKER_GEMS
	var hired: bool = gs.hire_worker() and gs.workers == 3 and gs.gems == 0
	gs.gems = 5000
	var capped: bool = gs.hire_worker() == false
	gs.free()
	return too_poor and hired and capped


func test_pump_fills_fuel_and_respects_cap() -> bool:
	var gs := _fresh_state()
	var pump: Dictionary = gs.structure_at(PUMP)
	pump["collected_at"] = Time.get_unix_time_from_system() - 30.0 * 60.0
	gs.fuel = 0
	var got: int = gs.collect_generator(PUMP)
	var right: bool = got == int(Catalog.pump_rate(1) * 30.0) and gs.fuel == got
	gs.add_fuel(1_000_000)
	var capped: bool = gs.fuel == gs.fuel_cap()
	gs.free()
	return right and capped


func test_drones_cost_fuel_not_coins() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.fuel = 0
	gs.upgrade(HQ)
	_skip_time(gs)
	gs.upgrade(HANGAR)
	_skip_time(gs)
	var reason: String = gs.unit_block_reason("scout")
	gs.fuel = 400
	var unlocked: bool = gs.upgrade_unit("scout") and gs.fuel == 0
	gs.free()
	return reason == "Need 400 more fuel" and unlocked


func test_upgrading_producer_banks_old_rate() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	gs.upgrade(HQ)
	_skip_time(gs)
	var gen: Dictionary = gs.structure_at(GENERATOR)
	gen["collected_at"] = Time.get_unix_time_from_system() - 10.0 * 60.0
	gs.upgrade(GENERATOR)
	gs.coins = 0
	_skip_time(gs)
	var banked: bool = gs.coins >= int(Catalog.generator_rate(1) * 10.0) - 1
	var reset: bool = gs.generator_pending(gen) <= 1
	gs.free()
	return banked and reset and int(gen["level"]) == 2


func test_raid_loot_banks_coins_and_fuel() -> bool:
	var gs := _fresh_state()
	gs.coins = 0
	gs.fuel = 0
	var got: Dictionary = gs.record_raid(1, 100, 80)
	gs.raid_target = "self"
	var practice: Dictionary = gs.record_raid(3, 100, 80)
	gs.free()
	return got["coins"] == 100 and got["fuel"] == 80 and practice["coins"] == 0


## Pretends the training queue started long ago.
func _skip_training(gs: Node) -> void:
	gs.train_started -= 100000.0
	gs.process_training()


func test_training_takes_fuel_and_time() -> bool:
	var gs := _fresh_state()
	gs.army = {}
	gs.fuel = 100
	var ok: bool = gs.train("infantry")
	var paid: bool = gs.fuel == 100 - Catalog.train_fuel("infantry")
	var not_yet: bool = gs.process_training() == 0 and gs.army.is_empty()
	_skip_training(gs)
	var done: bool = int(gs.army.get("infantry", 0)) == 1 and gs.training.is_empty()
	gs.free()
	return ok and paid and not_yet and done


func test_training_queue_runs_in_order() -> bool:
	var gs := _fresh_state()
	gs.army = {}
	gs.fuel = 1000
	gs.train("infantry")
	gs.train("courier")
	# Just enough time for the infantry squad, not the courier after it.
	gs.train_started = gs.now() - Catalog.train_seconds("infantry", 1) - 1.0
	gs.process_training()
	var first: bool = int(gs.army.get("infantry", 0)) == 1 and not gs.army.has("courier")
	_skip_training(gs)
	var second: bool = int(gs.army.get("courier", 0)) == 1
	gs.free()
	return first and second


func test_cancel_training_refunds_fuel() -> bool:
	var gs := _fresh_state()
	gs.army = {}
	gs.fuel = 100
	gs.train("infantry")
	var cancelled: bool = gs.cancel_training("infantry") and gs.fuel == 100 and gs.training.is_empty()
	gs.free()
	return cancelled


func test_full_quarters_hold_the_queue() -> bool:
	var gs := _fresh_state()
	gs.army = {}
	# Room for one more squad: the first finished squad moves in, the second waits.
	gs.army = {"infantry": 3}
	gs.training = ["infantry", "infantry"]
	gs.train_started = gs.now() - 1000.0
	gs.process_training()
	var held: bool = int(gs.army["infantry"]) == 4 and gs.training.size() == 1
	gs.use_army({"infantry": 2})
	var moved: bool = int(gs.army["infantry"]) == 3 and gs.training.is_empty()
	gs.free()
	return held and moved


func test_no_training_without_camp() -> bool:
	var gs := _fresh_state()
	gs.fuel = 1000
	gs.army = {}
	gs.remove(CAMP)
	var reason: String = gs.train_block_reason("infantry")
	gs.free()
	return reason == "Build a Training Camp first"


func test_speed_up_training_finishes_queue() -> bool:
	var gs := _fresh_state()
	gs.army = {}
	gs.fuel = 1000
	gs.train("infantry")
	gs.train("courier")
	var cost: int = gs.training_speedup_cost()
	var before: int = gs.gems
	var ok: bool = gs.speed_up_training()
	var result: bool = ok and cost > 0 and gs.gems == before - cost \
		and int(gs.army.get("infantry", 0)) == 1 and int(gs.army.get("courier", 0)) == 1
	gs.free()
	return result


func test_attack_uses_deployed_units() -> bool:
	var gs := _fresh_state()
	gs.army = {"infantry": 3, "courier": 1}
	gs.use_army({"infantry": 2, "courier": 1})
	var left: bool = int(gs.army.get("infantry", 0)) == 1 and not gs.army.has("courier")
	gs.free()
	return left


func test_garage_unlocks_ground_units() -> bool:
	var gs := _fresh_state()
	gs.coins = 99999
	gs.fuel = 99999
	var no_garage: String = gs.unit_block_reason("engineers")
	gs.build("garage", [0, 0])
	_skip_time(gs)
	var too_low: String = gs.unit_block_reason("engineers")
	gs.upgrade(HQ)
	_skip_time(gs)
	gs.upgrade([0, 0])
	_skip_time(gs)
	var unlocked: bool = gs.upgrade_unit("engineers")
	gs.free()
	return no_garage == "Needs Garage Lv 2" and too_low == "Needs Garage Lv 2" and unlocked


func test_quarters_add_army_space() -> bool:
	var gs := _fresh_state()
	var one: int = gs.army_capacity()
	gs.coins = 99999
	gs.upgrade(HQ)
	_skip_time(gs)
	gs.upgrade(QUARTERS)
	var during: int = gs.army_capacity()
	_skip_time(gs)
	var after: int = gs.army_capacity()
	gs.free()
	return one == Catalog.quarters_space(1) and during == one and after == Catalog.quarters_space(2)


func test_old_defenses_migrate() -> bool:
	var retired: Dictionary = load("res://scripts/autoload/game_state.gd").RETIRED
	for old in retired:
		if Catalog.DEFENSES.has(old) or not Catalog.DEFENSES.has(retired[old]):
			return false
	return retired.size() == 3


func _with_support(gs: Node, lvl: int) -> void:
	gs.structures.append({"type": "support", "cell": [0, 0], "level": lvl})


func test_support_needs_a_base_and_slots() -> bool:
	var gs := _fresh_state()
	gs.fuel = 5000
	var no_base: String = gs.prepare_block_reason("flare")
	_with_support(gs, 1)
	var a: bool = gs.prepare("flare")
	var b: bool = gs.prepare("flare")
	var full: String = gs.prepare_block_reason("flare")
	var locked: String = gs.prepare_block_reason("strike")
	gs.free()
	return no_base == "Build a Support Base first" and a and b and full == "No free slots" and locked == "Locked"


func test_support_prepares_over_time_and_is_used_up() -> bool:
	var gs := _fresh_state()
	gs.fuel = 5000
	_with_support(gs, 1)
	gs.prepare("flare")
	var not_yet: bool = gs.process_support() == 0
	gs.support_started -= 1000.0
	gs.process_support()
	var ready: bool = int(gs.support_ready.get("flare", 0)) == 1
	gs.use_support({"flare": 1})
	var gone: bool = not gs.support_ready.has("flare")
	gs.free()
	return not_yet and ready and gone


func test_strike_unlocks_at_support_level_two() -> bool:
	var gs := _fresh_state()
	gs.fuel = 5000
	_with_support(gs, 1)
	var early: String = gs.ability_block_reason("strike")
	gs.structure_at([0, 0])["level"] = 2
	var unlocked: bool = gs.upgrade_ability("strike")
	var slots_ok: bool = gs.support_slots() == 3
	gs.free()
	return early == "Needs Support Base Lv 2" and unlocked and slots_ok


func test_ability_levels_get_stronger() -> bool:
	var total := []
	for l in range(1, Catalog.MAX_LEVEL + 1):
		var st := Catalog.ability_stats("strike", l)
		total.append(float(st["bombs"]) * float(st["damage"]))
	for i in range(1, total.size()):
		if total[i] <= total[i - 1]:
			return false
	return Catalog.ability_stats("flare", 5)["seconds"] > Catalog.ability_stats("flare", 1)["seconds"]


func test_syndicate_missions_open_in_order() -> bool:
	var gs := _fresh_state()
	var first: bool = gs.syndicate_open() == 1
	gs.syndicate_mission = 0
	gs.raid_target = "syndicate"
	var lost: Dictionary = gs.record_raid(0, 0, 0)
	var still: bool = gs.syndicate_open() == 1 and not lost["first"]
	gs.coins = 0
	var won: Dictionary = gs.record_raid(2, 50, 0)
	var opened: bool = gs.syndicate_open() == 2
	var paid: bool = won["first"] and won["coins"] == 50 + int(Syndicate.MISSIONS[0]["reward"]["coins"])
	var again: Dictionary = gs.record_raid(3, 0, 0)
	var stars: bool = gs.syndicate_total_stars() == 3 and not again["first"]
	gs.free()
	return first and still and opened and paid and stars


func test_syndicate_bases_are_valid() -> bool:
	for i in Syndicate.COUNT:
		var b := Syndicate.base(i)
		var seen := {}
		var hq := 0
		for st in b["structures"]:
			var key := "%d,%d" % st["cell"]
			if seen.has(key) or int(st["cell"][0]) < 0 or int(st["cell"][0]) >= City.GRID or int(st["cell"][1]) < 0 or int(st["cell"][1]) >= City.GRID:
				return false
			seen[key] = true
			if st["type"] == "hq":
				hq += 1
		for w in b["walls"]:
			if not Walls.valid(w["edge"]):
				return false
		if hq != 1:
			return false
	return Syndicate.base(Syndicate.BOSS)["boss"] and Syndicate.base(9)["walls"].size() > Syndicate.base(2)["walls"].size()


func test_tutorial_starts_for_new_players_and_follows_events() -> bool:
	var gs := _fresh_state()
	var starts: bool = gs.tutorial == 0 and gs.tutorial_key() == "intro"
	gs.tutorial_next()
	gs.tutorial_event("collect_fuel")
	var ignored: bool = gs.tutorial_key() == "coins"
	gs.tutorial_event("collect_coins")
	var moved: bool = gs.tutorial_key() == "fuel"
	gs.free()
	return starts and ignored and moved


func test_tutorial_new_base_leaves_room_to_build_and_train() -> bool:
	var gs := _fresh_state()
	var mg_free: bool = gs.build_block_reason("mg") == ""
	var can_train: bool = gs.train_block_reason("infantry") == ""
	gs.free()
	return mg_free and can_train


func test_tutorial_speed_up_is_free_only_in_its_step() -> bool:
	var gs := _fresh_state()
	gs.build("mg", [4, 3])
	var paid: bool = gs.speedup_cost([4, 3]) > 0
	while gs.tutorial_key() != "speed":
		gs.tutorial_next()
	var free: bool = gs.speedup_cost([4, 3]) == 0
	gs.free()
	return paid and free


func test_tutorial_upgrade_is_affordable_and_ends_with_gems() -> bool:
	var gs := _fresh_state()
	gs.coins = 0
	while gs.tutorial_key() != "upgrade":
		gs.tutorial_next()
	var afford: bool = gs.coins >= Catalog.upgrade_cost("hq", 1)
	var gems: int = gs.gems
	gs.tutorial_next()
	gs.tutorial_next()
	var done: bool = gs.tutorial == -1 and gs.gems == gems + TutorialSteps.GIFT_GEMS
	gs.free()
	return afford and done


func test_tutorial_skip_and_replay_give_no_gems() -> bool:
	var gs := _fresh_state()
	var gems: int = gs.gems
	gs.skip_tutorial()
	var skipped: bool = gs.tutorial == -1
	gs.replay_tutorial()
	for i in TutorialSteps.STEPS.size():
		gs.tutorial_next()
	var replayed: bool = gs.tutorial == -1 and not gs.tutorial_replay
	var no_gift: bool = gs.gems == gems
	gs.free()
	return skipped and replayed and no_gift
