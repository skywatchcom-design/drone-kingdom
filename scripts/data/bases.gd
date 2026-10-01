class_name Bases
extends RefCounted
## Handcrafted bases for the prototype. Cells are [column, row] on the 7x7 rooftop grid.
## Later these become snapshots of real players' bases.

const LIST := [
	{
		"name": "Quiet Block",
		"seed": 11,
		"home": [5, 6],
		"target": [1, 1],
		"loot": [[4, 3], [1, 4], [3, 1]],
		"defenses": [
			{"type": "laser", "cell": [3, 3]},
			{"type": "birds", "cell": [2, 2]},
		],
	},
	{
		"name": "Antenna Row",
		"seed": 27,
		"home": [6, 5],
		"target": [0, 1],
		"loot": [[5, 2], [2, 5], [1, 3]],
		"defenses": [
			{"type": "laser", "cell": [4, 4]},
			{"type": "net", "cell": [2, 3]},
			{"type": "jammer", "cell": [3, 1]},
		],
	},
	{
		"name": "Fortress Roof",
		"seed": 42,
		"home": [5, 6],
		"target": [1, 0],
		"loot": [[6, 2], [0, 4], [3, 3]],
		"defenses": [
			{"type": "laser", "cell": [2, 1]},
			{"type": "laser", "cell": [4, 3]},
			{"type": "net", "cell": [1, 3]},
			{"type": "jammer", "cell": [2, 4]},
			{"type": "birds", "cell": [4, 1]},
		],
	},
]
