class_name Bases
extends RefCounted
## Enemy bases. The first few are handcrafted as a gentle start; after that they are
## generated to match the player's Command Tower level, so there is always a next target.
## Format: {name, seed, pad: [c, r] attacker launch pad, structures: [{type, cell, level}]}.
## Later these become snapshots of real players' bases.

const STARTERS := [
	{
		"name": "Quiet Block",
		"seed": 11,
		"pad": [6, 7],
		"structures": [
			{"type": "hq", "cell": [2, 2], "level": 1},
			{"type": "generator", "cell": [5, 4], "level": 1},
			{"type": "storage", "cell": [2, 5], "level": 1},
			{"type": "generator", "cell": [4, 2], "level": 1},
			{"type": "pump", "cell": [6, 2], "level": 1},
			{"type": "tank", "cell": [3, 6], "level": 1},
			{"type": "laser", "cell": [4, 4], "level": 1},
			{"type": "birds", "cell": [3, 3], "level": 1},
		],
	},
	{
		"name": "Antenna Row",
		"seed": 27,
		"pad": [7, 6],
		"structures": [
			{"type": "hq", "cell": [1, 2], "level": 2},
			{"type": "generator", "cell": [6, 3], "level": 2},
			{"type": "storage", "cell": [3, 6], "level": 1},
			{"type": "generator", "cell": [2, 4], "level": 1},
			{"type": "pump", "cell": [7, 4], "level": 1},
			{"type": "tank", "cell": [5, 7], "level": 1},
			{"type": "laser", "cell": [5, 5], "level": 1},
			{"type": "net", "cell": [3, 4], "level": 1},
			{"type": "jammer", "cell": [4, 2], "level": 1},
		],
	},
	{
		"name": "Fortress Roof",
		"seed": 42,
		"pad": [6, 7],
		"structures": [
			{"type": "hq", "cell": [2, 1], "level": 3},
			{"type": "generator", "cell": [7, 3], "level": 2},
			{"type": "storage", "cell": [1, 5], "level": 2},
			{"type": "generator", "cell": [4, 4], "level": 2},
			{"type": "pump", "cell": [6, 5], "level": 2},
			{"type": "tank", "cell": [1, 3], "level": 2},
			{"type": "laser", "cell": [3, 2], "level": 2},
			{"type": "laser", "cell": [5, 4], "level": 1},
			{"type": "net", "cell": [2, 4], "level": 1},
			{"type": "jammer", "cell": [3, 5], "level": 1},
			{"type": "birds", "cell": [5, 2], "level": 1},
		],
	},
]

const NAMES := ["Rust Alley", "Pigeon Heights", "Neon Corner", "Old Port", "Satellite Row",
	"Chimney Hill", "Blue Tanks", "Market Roofs", "Night Shift", "Cable Street"]


static func enemy(index: int, player_hq: int) -> Dictionary:
	if index < STARTERS.size():
		return STARTERS[index]
	return generate(1000 + index, clampi(player_hq, 1, Catalog.MAX_LEVEL))


## A random base an HQ-level-`hq` player could have built. The attacker launches from
## the near corner; the Command Tower sits on the far half of the grid.
static func generate(seed_value: int, hq: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var last := City.GRID - 1
	var pad := [last, last - rng.randi_range(0, 2)] if rng.randf() < 0.5 else [last - rng.randi_range(0, 2), last]
	var taken := {"%d,%d" % pad: true}
	var structures := []
	var hq_cell := [rng.randi_range(0, 2), rng.randi_range(0, 2)]
	taken["%d,%d" % hq_cell] = true
	structures.append({"type": "hq", "cell": hq_cell, "level": hq})
	for type in ["generator", "storage", "pump", "tank", "laser", "net", "jammer", "birds"]:
		for i in Catalog.max_count(type, hq):
			var cell := _free_cell(rng, taken)
			if cell.is_empty():
				break
			structures.append({"type": type, "cell": cell, "level": rng.randi_range(maxi(1, hq - 1), hq)})
	return {
		"name": NAMES[seed_value % NAMES.size()],
		"seed": seed_value,
		"pad": pad,
		"structures": structures,
	}


static func _free_cell(rng: RandomNumberGenerator, taken: Dictionary) -> Array:
	for attempt in 60:
		var cell := [rng.randi_range(0, City.GRID - 1), rng.randi_range(0, City.GRID - 2)]
		var key := "%d,%d" % cell
		if not taken.has(key):
			taken[key] = true
			return cell
	return []
