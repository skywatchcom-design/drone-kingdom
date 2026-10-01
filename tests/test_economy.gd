extends RefCounted


func _fresh_state() -> Node:
	var gs: Node = load("res://scripts/autoload/game_state.gd").new()
	gs.persist = false
	gs.new_player()
	return gs


func test_upgrade_costs_grow() -> bool:
	for type in ["hq", "generator", "laser", "birds"]:
		for lvl in range(1, Catalog.MAX_LEVEL):
			if Catalog.upgrade_cost(type, lvl + 1) <= Catalog.upgrade_cost(type, lvl):
				return false
	return true


func test_defense_stats_scale_with_level() -> bool:
	var l1 := Catalog.defense_stats("laser", 1)
	var l3 := Catalog.defense_stats("laser", 3)
	var n1 := Catalog.defense_stats("net", 1)
	var n3 := Catalog.defense_stats("net", 3)
	return l3["radius"] > l1["radius"] and l3["dps"] > l1["dps"] and n3["cooldown"] < n1["cooldown"]


func test_limits_follow_command_tower() -> bool:
	return Catalog.max_count("jammer", 1) == 0 and Catalog.max_count("jammer", 3) == 1 and Catalog.max_count("laser", 2) == 2


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
	gs.upgrade([3, 3])
	var allowed: bool = gs.build("generator", [0, 0])
	gs.free()
	return blocked and allowed


func test_buildings_cannot_outlevel_command_tower() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	var reason: String = gs.upgrade_block_reason([2, 3])
	gs.free()
	return reason == "Upgrade the Command Tower first"


func test_command_tower_cannot_be_removed() -> bool:
	var gs := _fresh_state()
	var removed: bool = gs.remove([3, 3])
	gs.free()
	return not removed


func test_building_costs_coins_and_occupies_roof() -> bool:
	var gs := _fresh_state()
	gs.coins = 1000
	gs.upgrade([3, 3])
	gs.coins = 1000
	var before: int = gs.coins
	var ok: bool = gs.build("net", [0, 0])
	var paid: bool = gs.coins == before - Catalog.build_cost("net")
	var twice: bool = gs.build("laser", [0, 0])
	gs.free()
	return ok and paid and not twice


func test_scout_needs_hangar_level_two() -> bool:
	var gs := _fresh_state()
	gs.coins = 5000
	var first: String = gs.drone_block_reason("scout")
	gs.upgrade([3, 3])
	gs.upgrade([4, 3])
	var unlocked: bool = gs.upgrade_drone("scout")
	gs.free()
	return first == "Needs Hangar Lv 2" and unlocked


func test_army_respects_hangar_space() -> bool:
	var gs := _fresh_state()
	var cap: int = gs.army_capacity()
	var fits: bool = gs.set_army_count("courier", cap / 2)
	var too_many: bool = gs.set_army_count("courier", cap / 2 + 1)
	var locked: bool = gs.set_army_count("scout", 1)
	gs.free()
	return fits and not too_many and not locked


func test_generator_collect_keeps_overflow() -> bool:
	var gs := _fresh_state()
	var gen: Dictionary = gs.structure_at([2, 3])
	gen["collected_at"] = Time.get_unix_time_from_system() - 100.0 * 60.0
	gs.coins = gs.coin_cap() - 50
	var got: int = gs.collect_generator([2, 3])
	var left: int = gs.generator_pending(gen)
	gs.free()
	return got == 50 and left > 400


func test_coins_are_capped() -> bool:
	var gs := _fresh_state()
	gs.add_coins(1_000_000)
	var capped: bool = gs.coins == gs.coin_cap()
	gs.free()
	return capped
