extends RefCounted


func test_no_loot_gives_no_stars() -> bool:
	return RaidRules.stars(0, false, false, true) == 0


func test_crash_gives_no_stars_even_with_loot() -> bool:
	return RaidRules.stars(350, true, true, false) == 0


func test_crates_only_give_one_star() -> bool:
	return RaidRules.stars(100, false, true, true) == 1


func test_vault_gives_two_stars() -> bool:
	return RaidRules.stars(250, true, false, true) == 2


func test_vault_and_all_crates_give_three_stars() -> bool:
	return RaidRules.stars(350, true, true, true) == 3


func test_forward_acceleration_dips_the_nose() -> bool:
	var tilt := RaidRules.bank_angles(Vector3(0, 0, 6), Vector3(0, 0, 4), 0.0)
	return tilt.x > 0.0


func test_braking_lifts_the_nose() -> bool:
	var tilt := RaidRules.bank_angles(Vector3(0, 0, -12), Vector3.ZERO, 0.0)
	return tilt.x < 0.0


func test_turning_banks_toward_the_turn() -> bool:
	# Heading +Z, accelerating toward +X (local right): the +X side must drop (negative roll).
	var tilt := RaidRules.bank_angles(Vector3(6, 0, 0), Vector3(0, 0, 8), 0.0)
	return tilt.y < 0.0


func test_tilt_is_clamped() -> bool:
	var tilt := RaidRules.bank_angles(Vector3(500, 0, 500), Vector3(0, 0, 100), 0.0)
	return absf(tilt.x) <= 0.45 and absf(tilt.y) <= 0.5
