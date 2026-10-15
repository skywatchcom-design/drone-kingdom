extends RefCounted
## Attacks between players: trophies, loot and what the defender loses (scripts/data/pvp.gd).


func _fresh_state() -> Node:
	var gs: Node = load("res://scripts/autoload/game_state.gd").new()
	gs.persist = false
	gs.new_player()
	return gs


func test_trophies_reward_stars_and_stronger_opponents() -> bool:
	var even := [Pvp.trophy_change(1, 300, 300), Pvp.trophy_change(2, 300, 300), Pvp.trophy_change(3, 300, 300)]
	var lost := Pvp.trophy_change(0, 300, 300)
	var harder: bool = Pvp.trophy_change(1, 300, 500) > int(even[0])
	var easier: bool = Pvp.trophy_change(1, 300, 100) < int(even[0])
	var cheaper_loss := Pvp.trophy_change(0, 300, 500) > lost
	return even == [20, 24, 28] and lost == -12 and harder and easier and cheaper_loss


func test_defender_change_mirrors_the_attack() -> bool:
	# A win costs the defender 60% of what the attacker earned; a held base wins what the attacker lost.
	return Pvp.defender_change(20) == -12 and Pvp.defender_change(28) == -17 and Pvp.defender_change(-12) == 12


func test_leagues_follow_trophies() -> bool:
	return Pvp.league(0)[0] == "Recruit" and Pvp.league(99)[0] == "Recruit" and Pvp.league(100)[0] == "Bronze" \
		and Pvp.league(650)[0] == "Gold" and Pvp.league(5000)[0] == "Diamond"


func test_loot_pool_is_a_tenth_of_the_bank_and_half_of_what_waits() -> bool:
	var now := 1_000_000.0
	# One level-1 generator full for 100 minutes (6 a minute = 600 waiting), one pump for 50 (4 a minute = 200).
	var structures := [
		{"type": "generator", "cell": [1, 1], "level": 1, "collected_at": now - 100.0 * 60.0},
		{"type": "pump", "cell": [2, 1], "level": 1, "collected_at": now - 50.0 * 60.0},
		{"type": "generator", "cell": [3, 1], "level": 1, "fresh": true},
	]
	var pool := Pvp.loot_pool(structures, 3000, 1000, now)
	return pool["coins"] == 300 + 300 and pool["fuel"] == 100 + 100


func test_shared_loot_never_exceeds_the_pool() -> bool:
	var targets := [{"type": "hq", "level": 3}, {"type": "generator", "level": 2}, {"type": "storage", "level": 1},
		{"type": "pump", "level": 1}, {"type": "tank", "level": 2}, {"type": "mg", "level": 3}]
	var pool := {"coins": 1001, "fuel": 499}
	var shares := Pvp.share_loot(targets, pool)
	var coins := 0
	var fuel := 0
	for s in shares:
		coins += int(s[0])
		fuel += int(s[1])
	# Rounding down may lose a coin or two per building, never more.
	var defense_gives_nothing: bool = shares[5] == [0, 0]
	return coins <= 1001 and coins >= 1001 - targets.size() and fuel <= 499 and fuel >= 499 - targets.size() and defense_gives_nothing


func test_opponent_row_becomes_a_clean_battle_base() -> bool:
	var row := {"id": "abc", "name": "KOBI_77", "hq_level": 3, "trophies": 312, "coins": 2000, "fuel": 900, "city_seed": 9,
		"structures": [{"type": "hq", "cell": [4.0, 4.0], "level": 3.0}, {"type": "laser", "cell": [2, 2], "level": 1},
			{"type": "mg", "cell": [5, 5], "level": 1, "fresh": true}],
		"walls": [{"edge": [1.0, 1.0, 0.0], "level": 2.0}]}
	var b := Pvp.base_from_row(row, 1_000_000.0)
	var types := []
	for s in b["structures"]:
		types.append(s["type"])
	return b["name"] == "KOBI_77" and b["player_id"] == "abc" and b["seed"] == 9 and types == ["hq", "aa"] \
		and b["structures"][0]["cell"] == [4, 4] and b["walls"][0]["edge"] == [1, 1, 0] and b["loot_pool"]["coins"] == 200


func test_losing_loot_takes_the_bank_first_then_the_generators() -> bool:
	var gs := _fresh_state()
	gs.coins = 100
	gs.fuel = 50
	# A new player's generator and pump have 20 minutes waiting: 120 coins and 80 fuel.
	var coins_waiting: int = gs.generator_pending(gs.structure_at([3, 4]))
	var fuel_waiting: int = gs.generator_pending(gs.structure_at([4, 5]))
	var taken: Dictionary = gs.lose_loot(130, 500)
	var bank_first: bool = gs.coins == 0 and gs.fuel == 0
	var from_generator: bool = absi(gs.generator_pending(gs.structure_at([3, 4])) - (coins_waiting - 30)) <= 1
	# Nobody loses more than they have.
	var capped: bool = taken["coins"] == 130 and taken["fuel"] == 50 + fuel_waiting and gs.generator_pending(gs.structure_at([4, 5])) <= 1
	gs.free()
	return coins_waiting >= 100 and bank_first and from_generator and capped
