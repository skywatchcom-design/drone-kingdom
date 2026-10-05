class_name Syndicate
extends RefCounted
## The Syndicate campaign (approved sketch G1Y41QRsCwW8TVG8wyP9NB): ten fixed bases that get
## harder, the last one Razor's fortress. Each has a first-win reward and Razor's lines.
## Bases are laid out from a short spec: buildings fill cells outward from the Command Tower,
## and walls ring it.

const COUNT := 10
const BOSS := 9

## name, Command Tower level, building level, buildings (besides the tower, filled in order),
## wall rings [radius, level, gaps], reward {coins, fuel, gems}, Razor's taunt.
const MISSIONS := [
	{"name": "Scrap Depot", "hq": 1, "level": 1, "build": ["generator", "storage", "mg", "pump"], "walls": [],
		"reward": {"coins": 300}, "taunt": "You walked into my yard. I'll send you home in pieces."},
	{"name": "Abandoned Fuel Station", "hq": 1, "level": 1, "build": ["pump", "tank", "mg", "aa", "pump"], "walls": [],
		"reward": {"fuel": 300}, "taunt": "My fuel, my rules. Touch it and you burn."},
	{"name": "Antenna Farm", "hq": 2, "level": 2, "build": ["mg", "aa", "at", "generator", "storage", "jammer"], "walls": [[0, 1, []]],
		"reward": {"coins": 500}, "taunt": "I can hear every order you give. Every one."},
	{"name": "Bolt Harbor", "hq": 2, "level": 2, "build": ["quarters", "mg", "mg", "at", "tank", "pump"], "walls": [[0, 2, []], [1, 1, [2, 9]]],
		"reward": {"fuel": 400}, "taunt": "My robots don't sleep. Neither will you."},
	{"name": "Robot Factory", "hq": 3, "level": 2, "build": ["quarters", "mortar", "mg", "aa", "at", "generator", "storage"], "walls": [[1, 2, [5]]],
		"reward": {"coins": 800, "gems": 20}, "taunt": "Every scrap you leave behind, I build into something worse."},
	{"name": "Copper Mine", "hq": 3, "level": 3, "build": ["generator", "storage", "mg", "mg", "mortar", "jammer", "quarters", "pump"], "walls": [[0, 3, []], [1, 2, [3, 11]]],
		"reward": {"coins": 600, "fuel": 400}, "taunt": "Dig all you want. You'll only find your own grave."},
	{"name": "Canyon Pass", "hq": 4, "level": 3, "build": ["at", "at", "mg", "mg", "mortar", "quarters", "tank", "storage"], "walls": [[1, 3, [0]], [2, 3, [8]]],
		"reward": {"fuel": 1000}, "taunt": "One road in. No road out."},
	{"name": "Airfield", "hq": 4, "level": 4, "build": ["aa", "aa", "aa", "jammer", "mg", "mg", "quarters", "support", "storage"], "walls": [[1, 3, [4]]],
		"reward": {"coins": 1200, "gems": 30}, "taunt": "Send your little drones. I collect them."},
	{"name": "Broadcast Tower", "hq": 5, "level": 4, "build": ["mg", "mg", "at", "aa", "mortar", "jammer", "quarters", "quarters", "storage", "tank"],
		"walls": [[0, 4, []], [1, 4, [6]], [2, 3, [1, 13]]], "reward": {"coins": 1500, "fuel": 1000}, "taunt": "The whole region hears you lose tonight."},
	{"name": "Syndicate Fortress", "hq": 5, "level": 5, "build": ["mg", "mg", "at", "at", "aa", "aa", "mortar", "mortar", "jammer", "quarters", "quarters", "storage", "tank"],
		"walls": [[0, 5, []], [1, 5, []], [2, 4, [10]]], "reward": {"coins": 3000, "fuel": 2000, "gems": 100},
		"taunt": "You got this far because I let you. Now the game ends."},
]

## What Razor says when the player beats one of his bases.
const LOSE_LINES := [
	"Enjoy it. Next time I come to you.",
	"A lucky shot. Remember the face that's coming for you.",
	"You broke a toy. I have a factory.",
	"Fine. Now it's personal.",
]
## What he says when the player fails to win.
const WIN_LINES := [
	"Go home, little commander.",
	"That was it? I've had scarier breakfasts.",
	"Leave the rest of your army at the gate. I'll keep it.",
]


static func mission_name(index: int) -> String:
	return I18n.t(MISSIONS[index]["name"])


## Cells filled outward from the middle, nearest first, in a fixed order.
static func _ring_cells() -> Array:
	var cells := []
	for c in City.GRID:
		for r in City.GRID:
			if c == 4 and r == 4:
				continue
			cells.append([c, r])
	cells.sort_custom(func(a: Array, b: Array) -> bool:
		var da := absi(a[0] - 4) + absi(a[1] - 4)
		var db := absi(b[0] - 4) + absi(b[1] - 4)
		if da != db:
			return da < db
		return a[0] * 9 + a[1] < b[0] * 9 + b[1])
	return cells


## Mission `index` as a base, in the same format as enemy bases, with syndicate: true.
static func base(index: int) -> Dictionary:
	var m: Dictionary = MISSIONS[clampi(index, 0, COUNT - 1)]
	var lvl := int(m["level"])
	var structures := [{"type": "hq", "cell": [4, 4], "level": int(m["hq"])}]
	var cells := _ring_cells()
	# Spread buildings out: take every other cell so walls have room between them.
	var step := 0
	for type in m["build"]:
		structures.append({"type": type, "cell": cells[step], "level": lvl})
		step += 2 if step + 2 < cells.size() else 1
	var walls := []
	for ring: Array in m["walls"]:
		var radius := int(ring[0])
		for e in Walls.ring(4 - radius, 4 - radius, 4 + radius, 4 + radius, ring[2]):
			walls.append({"edge": e, "level": int(ring[1])})
	return {"name": mission_name(index), "seed": 500 + index, "pad": [8, 8], "structures": structures,
		"walls": walls, "syndicate": true, "boss": index == BOSS, "mission": index}


# ---------------------------------------------------------------- the Syndicate look

## Their paint job over our models: olive and sand to graphite, rust bands to purple, blue
## trims to hazard yellow, glowing cyan to violet.
const SWAPS := [
	[Color(0.365, 0.4, 0.251), Color(0.2, 0.21, 0.24)],
	[Color(0.275, 0.302, 0.188), Color(0.15, 0.16, 0.18)],
	[Color(0.663, 0.643, 0.533), Color(0.27, 0.28, 0.31)],
	[Color(0.549, 0.529, 0.424), Color(0.2, 0.21, 0.24)],
	[Color(0.75, 0.38, 0.23), Color(0.54, 0.24, 1.0)],
	[Color(0.18, 0.44, 0.88), Color(0.95, 0.76, 0.18)],
	[Color(0.2, 0.23, 0.28), Color(0.14, 0.13, 0.17)],
	[Color(0.5, 0.9, 1.0), Color(0.75, 0.55, 1.0)],
	[Color(0.72, 0.65, 0.48), Color(0.33, 0.34, 0.37)],
	[Color(0.65, 0.64, 0.6), Color(0.42, 0.43, 0.46)],
	[Color(0.33, 0.38, 0.23), Color(0.16, 0.15, 0.2)],
]


static func paint(node: Node) -> void:
	for pair: Array in SWAPS:
		UnitModels.recolor(node, pair[0], pair[1])


## Razor's fortress gets a violet dome over its tower and a Syndicate flag.
static func boss_dressing(parent: Node3D, top: Vector3) -> void:
	var dome := MeshKit.add(parent, MeshKit.sphere(2.2, 20), MeshKit.glow(Color(0.54, 0.24, 1.0), 0.35), top + Vector3(0, 9.0, 0))
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pole := top + Vector3(3.0, 0, 3.0)
	MeshKit.add(parent, MeshKit.cyl(0.07, 0.07, 6.0, 6), MeshKit.mat(Color(0.6, 0.6, 0.62), 0.4, 0.6), pole + Vector3(0, 3.0, 0))
	MeshKit.add(parent, MeshKit.box(Vector3(0.05, 1.3, 2.0)), MeshKit.mat(Color(0.17, 0.18, 0.2), 0.6), pole + Vector3(0, 5.3, 1.0))
	MeshKit.add(parent, MeshKit.box(Vector3(0.06, 0.36, 2.0)), MeshKit.mat(Color(0.54, 0.24, 1.0), 0.6), pole + Vector3(0, 5.3, 1.0))
