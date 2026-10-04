extends RefCounted


func _t(x: float, z: float, is_defense: bool, loot: int, destroyed: bool = false) -> Dictionary:
	return {"top": Vector3(x, 10, z), "is_defense": is_defense, "loot": loot, "destroyed": destroyed}


func test_no_stars_below_half() -> bool:
	return RaidRules.battle_stars(0.49, false) == 0


func test_half_destruction_gives_one_star() -> bool:
	return RaidRules.battle_stars(0.5, false) == 1


func test_command_tower_is_its_own_star() -> bool:
	return RaidRules.battle_stars(0.2, true) == 1 and RaidRules.battle_stars(0.6, true) == 2


func test_full_destruction_gives_three_stars() -> bool:
	return RaidRules.battle_stars(1.0, true) == 3


func test_scout_prefers_loot_over_closer_defense() -> bool:
	var targets := [_t(1, 0, true, 0), _t(10, 0, false, 80)]
	return RaidRules.pick_target("loot", Vector3.ZERO, targets) == 1


func test_heavy_prefers_defenses() -> bool:
	var targets := [_t(1, 0, false, 80), _t(10, 0, true, 0)]
	return RaidRules.pick_target("defense", Vector3.ZERO, targets) == 1


func test_courier_takes_nearest() -> bool:
	var targets := [_t(9, 0, true, 0), _t(2, 0, false, 80)]
	return RaidRules.pick_target("any", Vector3.ZERO, targets) == 1


func test_falls_back_when_no_preferred_target() -> bool:
	var targets := [_t(5, 0, false, 0), _t(3, 0, false, 0)]
	return RaidRules.pick_target("defense", Vector3.ZERO, targets) == 1


func test_skips_destroyed_and_reports_none_left() -> bool:
	var targets := [_t(1, 0, true, 0, true), _t(4, 0, true, 0)]
	var first := RaidRules.pick_target("any", Vector3.ZERO, targets)
	targets[1]["destroyed"] = true
	return first == 1 and RaidRules.pick_target("any", Vector3.ZERO, targets) == -1


func test_forward_acceleration_dips_the_nose() -> bool:
	return RaidRules.bank_angles(Vector3(0, 0, 6), Vector3(0, 0, 4), 0.0).x > 0.0


func test_turning_banks_toward_the_turn() -> bool:
	return RaidRules.bank_angles(Vector3(6, 0, 0), Vector3(0, 0, 8), 0.0).y < 0.0


func test_tilt_is_clamped() -> bool:
	var tilt := RaidRules.bank_angles(Vector3(500, 0, 500), Vector3(0, 0, 100), 0.0)
	return absf(tilt.x) <= 0.45 and absf(tilt.y) <= 0.5

