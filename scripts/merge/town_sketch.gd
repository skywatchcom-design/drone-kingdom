class_name TownSketch
extends Node3D
## Style experiment (owner, 15.10.2026; not part of the product): a 9x9 military base laid out
## like the owner's isometric toy-city reference, on a floating block, portrait. Built in code:
## blocks of light pavement between grey streets with crosswalks, a central plaza with the
## Command Tower, and military buildings with gable, curved and flat roofs, windows on the faces
## the camera sees, lamps, trees, jeeps, tanks and tiny soldiers. `-- --tone happy|serious`
## swaps the palette: bright toy colors, or a muted military one.

const GRID := 9
const CELL := 7.5
const STREETS := [2, 6]

var tone := "happy"
var P := {}
var _rng := RandomNumberGenerator.new()

const PALETTES := {
	"happy": {"bg": Color(0.96, 0.96, 0.97), "grass": Color(0.5, 0.78, 0.36), "pave": Color(0.9, 0.88, 0.83),
		"road": Color(0.47, 0.5, 0.56), "line": Color(0.98, 0.98, 0.96), "earth": Color(0.62, 0.44, 0.28), "earth2": Color(0.48, 0.34, 0.22),
		"wall": Color(0.95, 0.91, 0.82), "wall2": Color(0.86, 0.9, 0.95), "wall3": Color(0.96, 0.86, 0.72),
		"roof": Color(0.92, 0.47, 0.3), "roof2": Color(0.32, 0.55, 0.85), "roof3": Color(0.36, 0.68, 0.5), "roof4": Color(0.95, 0.75, 0.3),
		"glass": Color(0.35, 0.6, 0.9), "frame": Color(1, 1, 1), "metal": Color(0.75, 0.78, 0.82), "accent": Color(0.95, 0.3, 0.3),
		"stripe": Color(0.98, 0.8, 0.2), "tree": Color(0.36, 0.7, 0.32), "tree2": Color(0.24, 0.55, 0.32), "trunk": Color(0.55, 0.38, 0.22),
		"uniform": Color(0.4, 0.6, 0.35), "skin": Color(0.95, 0.76, 0.6), "jeep": Color(0.98, 0.78, 0.25), "tank": Color(0.45, 0.66, 0.4),
		"sand": Color(0.93, 0.83, 0.6), "flag": Color(0.25, 0.5, 0.95), "water": Color(0.45, 0.78, 0.95)},
	"serious": {"bg": Color(0.84, 0.86, 0.85), "grass": Color(0.42, 0.52, 0.3), "pave": Color(0.72, 0.7, 0.64),
		"road": Color(0.3, 0.31, 0.32), "line": Color(0.9, 0.86, 0.6), "earth": Color(0.47, 0.37, 0.27), "earth2": Color(0.36, 0.29, 0.22),
		"wall": Color(0.76, 0.7, 0.57), "wall2": Color(0.6, 0.62, 0.6), "wall3": Color(0.66, 0.6, 0.47),
		"roof": Color(0.33, 0.37, 0.25), "roof2": Color(0.3, 0.32, 0.34), "roof3": Color(0.42, 0.44, 0.3), "roof4": Color(0.5, 0.45, 0.32),
		"glass": Color(0.2, 0.28, 0.34), "frame": Color(0.55, 0.53, 0.48), "metal": Color(0.45, 0.47, 0.48), "accent": Color(0.75, 0.3, 0.18),
		"stripe": Color(0.85, 0.7, 0.2), "tree": Color(0.3, 0.45, 0.24), "tree2": Color(0.22, 0.36, 0.22), "trunk": Color(0.4, 0.3, 0.2),
		"uniform": Color(0.36, 0.4, 0.25), "skin": Color(0.8, 0.62, 0.48), "jeep": Color(0.42, 0.45, 0.3), "tank": Color(0.5, 0.48, 0.38),
		"sand": Color(0.72, 0.64, 0.46), "flag": Color(0.2, 0.32, 0.55), "water": Color(0.35, 0.5, 0.55)},
}


static func pos(c: float, r: float) -> Vector3:
	var half := (GRID - 1) / 2.0
	return Vector3((c - half) * CELL, 0.0, (r - half) * CELL)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--tone"):
		tone = args[args.find("--tone") + 1]
	P = PALETTES.get(tone, PALETTES["happy"])
	MeshKit.look = "town"
	MeshKit.toy = true
	_rng.seed = 7
	var cam := WorldSetup.create(self, 100.0)
	for n in get_children():
		if n is WorldEnvironment:
			(n as WorldEnvironment).environment.background_color = P["bg"]
			if tone == "serious":
				(n as WorldEnvironment).environment.ambient_light_energy *= 0.9
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 96.0 / (float(args[args.find("--zoom") + 1]) if args.has("--zoom") else 1.0)
	# A lower view than the game's, like the reference: buildings show more of their walls.
	var focus := Vector3(0, -6, 0) if not args.has("--zoom") else Vector3(4, 0, 4)
	cam.position = focus + Vector3(1.0, 0.85, 1.0).normalized() * 150.0
	cam.look_at(focus, Vector3.UP)
	_ground()
	_streets()
	_plaza()
	_helipad(Vector2(0.5, 0.5))
	_barracks(Vector2(4, 0.5))
	_fuel_depot(Vector2(7.5, 0.5))
	_tank_factory(Vector2(0.5, 4))
	_power_plant(Vector2(7.5, 4))
	_warehouse(Vector2(0.5, 7.5))
	_lab(Vector2(4, 7.5))
	_defense_corner(Vector2(7.5, 7.5))
	_border()
	_traffic()


# ---------------------------------------------------------------- helpers

func m(key: String, rough: float = 0.85) -> StandardMaterial3D:
	return MeshKit.mat(P[key] if P.has(key) else Color.MAGENTA, rough)


## A box with chamfered edges (three overlapping boxes), which reads as a soft toy edge from afar.
func rbox(parent: Node3D, size: Vector3, at: Vector3, mat: Material, b: float = 0.18) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	MeshKit.add(n, MeshKit.box(size - Vector3(0, 2 * b, 2 * b)), mat)
	MeshKit.add(n, MeshKit.box(size - Vector3(2 * b, 0, 2 * b)), mat)
	MeshKit.add(n, MeshKit.box(size - Vector3(2 * b, 2 * b, 0)), mat)
	return n


## A gable roof over a w x d footprint whose ridge runs along x (or z when `along_z`).
func gable(parent: Node3D, w: float, d: float, h: float, at: Vector3, mat: Material, along_z := false) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(d if not along_z else w, h, w if not along_z else d)
	var r := MeshKit.add(parent, prism, mat, at + Vector3(0, h / 2.0, 0))
	r.rotation.y = 0.0 if along_z else PI / 2.0
	if along_z:
		r.rotation.y = 0.0
	else:
		r.rotation.y = PI / 2.0


## Windows on the two faces the camera sees (+x and +z) of a box of `size` standing at `at`.
func windows(parent: Node3D, size: Vector3, at: Vector3, rows: int, cols_x: int, cols_z: int, y0: float = 1.0) -> void:
	var glass := m("glass", 0.3)
	var frame := m("frame", 0.6)
	for row in rows:
		var y := at.y + y0 + row * 2.0
		for i in cols_z:
			var x := at.x - size.x / 2.0 + size.x * (i + 0.5) / cols_z
			MeshKit.add(parent, MeshKit.box(Vector3(1.0, 1.2, 0.08)), frame, Vector3(x, y, at.z + size.z / 2.0 + 0.03))
			MeshKit.add(parent, MeshKit.box(Vector3(0.78, 0.98, 0.1)), glass, Vector3(x, y, at.z + size.z / 2.0 + 0.05))
		for i in cols_x:
			var z := at.z - size.z / 2.0 + size.z * (i + 0.5) / cols_x
			MeshKit.add(parent, MeshKit.box(Vector3(0.08, 1.2, 1.0)), frame, Vector3(at.x + size.x / 2.0 + 0.03, y, z))
			MeshKit.add(parent, MeshKit.box(Vector3(0.1, 0.98, 0.78)), glass, Vector3(at.x + size.x / 2.0 + 0.05, y, z))


func shade(parent: Node3D, at: Vector3, size: Vector2, strength: float = 0.45) -> void:
	MeshKit.blob(parent, size, at + Vector3(0, 0.02, 0), strength)


# ---------------------------------------------------------------- ground and streets

func _is_street(c: int, r: int) -> bool:
	return c in STREETS or r in STREETS


func _ground() -> void:
	var half := GRID * CELL / 2.0
	var edge := half + 4.5
	var w := edge * 2.0
	rbox(self, Vector3(w, 0.6, w), Vector3(0, -0.3, 0), m("grass", 1.0), 0.5)
	MeshKit.add(self, MeshKit.box(Vector3(w - 0.4, 3.4, w - 0.4)), m("earth", 0.95), Vector3(0, -2.3, 0))
	MeshKit.add(self, MeshKit.box(Vector3(w - 0.8, 2.2, w - 0.8)), m("earth2", 0.95), Vector3(0, -5.1, 0))
	MeshKit.add(self, MeshKit.box(Vector3(half * 2.0, 0.1, half * 2.0)), m("road", 0.95), Vector3(0, 0.05, 0))
	# Blocks: raised pavement with a curb, everywhere that is not a street.
	var blocks := [[0, 1], [3, 5], [7, 8]]
	for bx: Array in blocks:
		for bz: Array in blocks:
			var c0: float = bx[0] - 0.5
			var c1: float = bx[1] + 0.5
			var r0: float = bz[0] - 0.5
			var r1: float = bz[1] + 0.5
			var a := pos(c0, r0)
			var b := pos(c1, r1)
			var size := Vector3(b.x - a.x - 0.6, 0.35, b.z - a.z - 0.6)
			rbox(self, size, (a + b) / 2.0 + Vector3(0, 0.17, 0), m("pave", 0.9), 0.12)


func _streets() -> void:
	var line := m("line", 0.7)
	var half := GRID * CELL / 2.0
	for s in STREETS:
		var k := pos(s, s)
		# Dashes along each street, broken at the crossings.
		var t := -half + 1.0
		while t < half - 1.0:
			var near_cross := false
			for o in STREETS:
				if absf(t - pos(o, o).x) < CELL * 0.75:
					near_cross = true
			if not near_cross:
				MeshKit.add(self, MeshKit.box(Vector3(0.25, 0.03, 1.4)), line, Vector3(k.x, 0.11, t))
				MeshKit.add(self, MeshKit.box(Vector3(1.4, 0.03, 0.25)), line, Vector3(t, 0.11, k.z))
			t += 3.0
	# Zebra crossings on every side of both crossings.
	for sx in STREETS:
		for sz in STREETS:
			var cpos := pos(sx, sz)
			for dir: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				var base := cpos + dir * (CELL * 0.62)
				var side := Vector3(dir.z, 0, dir.x)
				for i in 5:
					var off := side * ((i - 2) * 1.2)
					MeshKit.add(self, MeshKit.box(Vector3(0.55, 0.03, 1.6) if dir.x == 0 else Vector3(1.6, 0.03, 0.55)), line, base + off + Vector3(0, 0.11, 0))
	# Lamp posts on the block corners.
	var post := m("metal", 0.5)
	for c in [1.4, 2.6, 5.4, 6.6]:
		for r in [1.4, 2.6, 5.4, 6.6]:
			if (c in [2.6, 5.4]) == (r in [2.6, 5.4]):
				continue
			var p := pos(c, r)
			MeshKit.add(self, MeshKit.cyl(0.1, 0.12, 3.6, 8), post, p + Vector3(0, 2.15, 0))
			MeshKit.add(self, MeshKit.sphere(0.32, 10), MeshKit.glow(Color(1.0, 0.95, 0.8)), p + Vector3(0, 4.05, 0))


func _border() -> void:
	var half := GRID * CELL / 2.0
	var placed := 0
	while placed < 46:
		var p := Vector3(_rng.randf_range(-half - 3.5, half + 3.5), 0, _rng.randf_range(-half - 3.5, half + 3.5))
		if absf(p.x) < half + 0.5 and absf(p.z) < half + 0.5:
			continue
		placed += 1
		_tree(p, _rng.randf_range(0.9, 1.3), _rng.randf() < 0.4)
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1)]:
		_watchtower(corner * (half + 2.2))


func _tree(p: Vector3, s: float, pine: bool) -> void:
	MeshKit.add(self, MeshKit.cyl(0.18 * s, 0.24 * s, 1.4 * s, 8), m("trunk"), p + Vector3(0, 0.7 * s, 0))
	if pine:
		MeshKit.add(self, MeshKit.cyl(0.0, 1.3 * s, 3.2 * s, 8), m("tree2"), p + Vector3(0, 2.6 * s, 0))
	else:
		MeshKit.add(self, MeshKit.sphere(1.25 * s, 12), m("tree"), p + Vector3(0, 2.3 * s, 0))
	shade(self, p, Vector2(2.6, 2.6) * s, 0.35)


# ---------------------------------------------------------------- the plaza

func _plaza() -> void:
	var c := pos(4, 4)
	# Round plaza with lawn quarters and flag poles around the tower.
	MeshKit.add(self, MeshKit.cyl(9.0, 9.0, 0.1, 40), m("wall3", 0.9), c + Vector3(0, 0.4, 0))
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		var lawn := MeshKit.add(self, MeshKit.cyl(2.2, 2.2, 0.2, 20), m("grass"), c + Vector3(cos(a), 0, sin(a)) * 7.4 + Vector3(0, 0.45, 0))
		lawn.scale = Vector3(1, 1, 1)
		_tree(c + Vector3(cos(a), 0, sin(a)) * 7.4 + Vector3(0, 0.4, 0), 0.7, false)
	for k in 6:
		var a := k * TAU / 6.0
		var fp := c + Vector3(cos(a), 0, sin(a)) * 5.4
		MeshKit.add(self, MeshKit.cyl(0.06, 0.08, 5.0, 6), m("metal", 0.4), fp + Vector3(0, 2.9, 0))
		var flag := MeshKit.add(self, MeshKit.box(Vector3(0.05, 0.9, 1.4)), m("flag" if k % 2 == 0 else "accent", 0.7), fp + Vector3(0, 4.9, 0.7))
		flag.rotation.y = a
	# Command Tower: a wide base with columns, a tower on top with a green cap and an antenna.
	shade(self, c + Vector3(0, 0.45, 0), Vector2(11, 11), 0.5)
	rbox(self, Vector3(8.0, 3.2, 8.0), c + Vector3(0, 2.05, 0), m("wall"), 0.25)
	for i in 4:
		for side: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			var col := c + side * 4.2 + Vector3(side.z, 0, side.x) * (-2.7 + i * 1.8) + Vector3(0, 2.05, 0)
			MeshKit.add(self, MeshKit.cyl(0.28, 0.32, 3.2, 10), m("frame", 0.6), col)
	rbox(self, Vector3(8.8, 0.5, 8.8), c + Vector3(0, 3.9, 0), m("wall3"), 0.2)
	rbox(self, Vector3(4.6, 6.0, 4.6), c + Vector3(0, 7.1, 0), m("wall"), 0.25)
	windows(self, Vector3(4.6, 6.0, 4.6), c + Vector3(0, 4.1, 0), 3, 2, 2, 1.0)
	MeshKit.add(self, MeshKit.cyl(0.9, 0.9, 0.12, 20), m("frame", 0.5), c + Vector3(0, 9.0, 2.34)).rotation.x = PI / 2.0
	MeshKit.add(self, MeshKit.cyl(0.75, 0.75, 0.14, 20), m("glass", 0.4), c + Vector3(0, 9.0, 2.36)).rotation.x = PI / 2.0
	var cap := MeshKit.add(self, MeshKit.cyl(0.0, 3.4, 3.4, 4), m("roof3", 0.7), c + Vector3(0, 11.8, 0))
	cap.rotation.y = PI / 4.0
	MeshKit.add(self, MeshKit.cyl(0.06, 0.08, 3.0, 6), m("metal", 0.4), c + Vector3(0, 14.8, 0))
	MeshKit.add(self, MeshKit.box(Vector3(0.05, 0.9, 1.5)), m("flag", 0.7), c + Vector3(0, 15.8, 0.75))
	# The entrance steps on the side facing the viewer.
	for i in 3:
		MeshKit.add(self, MeshKit.box(Vector3(3.0, 0.18, 0.6)), m("pave", 0.9), c + Vector3(0, 0.5 + i * 0.18, 4.6 - i * 0.5))
	_soldiers(c + Vector3(3.5, 0.45, 6.0), 3)


# ---------------------------------------------------------------- buildings

func _block_center(b: Vector2) -> Vector3:
	return pos(b.x, b.y) + Vector3(0, 0.35, 0)


func _helipad(b: Vector2) -> void:
	var c := _block_center(b)
	MeshKit.add(self, MeshKit.cyl(5.2, 5.2, 0.12, 36), m("road", 0.9), c + Vector3(0, 0.06, 0))
	MeshKit.add(self, MeshKit.cyl(4.6, 4.6, 0.13, 36), m("stripe", 0.7), c + Vector3(0, 0.07, 0))
	MeshKit.add(self, MeshKit.cyl(4.2, 4.2, 0.14, 36), m("road", 0.9), c + Vector3(0, 0.08, 0))
	var line := m("line", 0.7)
	for x in [-1.1, 1.1]:
		MeshKit.add(self, MeshKit.box(Vector3(0.55, 0.05, 3.6)), line, c + Vector3(x, 0.17, 0))
	MeshKit.add(self, MeshKit.box(Vector3(2.2, 0.05, 0.55)), line, c + Vector3(0, 0.17, 0))
	# A chunky helicopter parked on the pad.
	var heli := Node3D.new()
	heli.position = c + Vector3(0.8, 0.2, 0.6)
	heli.rotation.y = 0.6
	add_child(heli)
	shade(heli, Vector3.ZERO, Vector2(5, 3.5), 0.45)
	rbox(heli, Vector3(1.9, 1.6, 3.0), Vector3(0, 1.4, 0), m("tank"), 0.35)
	MeshKit.add(heli, MeshKit.box(Vector3(1.5, 0.9, 0.2)), m("glass", 0.3), Vector3(0, 1.6, 1.45))
	MeshKit.add(heli, MeshKit.box(Vector3(0.4, 0.4, 3.2)), m("tank"), Vector3(0, 1.6, -2.9))
	MeshKit.add(heli, MeshKit.box(Vector3(0.1, 1.0, 0.6)), m("tank"), Vector3(0.25, 2.0, -4.4))
	MeshKit.add(heli, MeshKit.cyl(0.08, 0.08, 0.5, 6), m("metal"), Vector3(0, 2.45, 0))
	for a in [0.3, 0.3 + PI / 2.0]:
		MeshKit.add(heli, MeshKit.box(Vector3(0.25, 0.05, 7.0)), m("metal", 0.5), Vector3(0, 2.72, 0)).rotation.y = a
	for x in [-0.9, 0.9]:
		MeshKit.add(heli, MeshKit.box(Vector3(0.12, 0.12, 3.2)), m("metal", 0.5), Vector3(x, 0.3, 0))


func _barracks(b: Vector2) -> void:
	var c := _block_center(b)
	for i in 2:
		var at := c + Vector3(-3.6 + i * 7.6, 0, -1.4 + i * 2.0)
		var size := Vector3(6.4, 3.4, 9.0)
		shade(self, at, Vector2(8, 11))
		rbox(self, size, at + Vector3(0, 1.7, 0), m("wall2" if i == 0 else "wall"), 0.2)
		windows(self, size, at, 1, 3, 2, 1.8)
		gable(self, 7.0, 9.6, 2.2, at + Vector3(0, 3.4, 0), m("roof2" if i == 0 else "roof"), true)
		MeshKit.add(self, MeshKit.box(Vector3(1.4, 2.0, 0.1)), m("trunk", 0.7), at + Vector3(0, 1.0, 4.52))
	_soldiers(c + Vector3(2.0, 0, 5.2), 4)


func _fuel_depot(b: Vector2) -> void:
	var c := _block_center(b)
	for i in 3:
		var at := c + Vector3(-3.6 + i * 3.6, 0, -2.0 + (i % 2) * 3.6)
		shade(self, at, Vector2(5, 5))
		MeshKit.add(self, MeshKit.cyl(1.7, 1.7, 4.2, 20), m("frame" if tone == "happy" else "wall2", 0.5), at + Vector3(0, 2.1, 0))
		MeshKit.add(self, MeshKit.cyl(1.72, 1.72, 0.5, 20), m("accent", 0.5), at + Vector3(0, 3.0, 0))
		MeshKit.add(self, MeshKit.cyl(0.6, 1.7, 0.6, 20), m("metal", 0.5), at + Vector3(0, 4.5, 0))
		MeshKit.add(self, MeshKit.cyl(0.18, 0.18, 2.5, 8), m("metal", 0.5), at + Vector3(1.2, 1.0, 1.2)).rotation.z = PI / 2.0
	# Hazard stripes on the ground and a fuel truck.
	for i in 6:
		MeshKit.add(self, MeshKit.box(Vector3(0.8, 0.04, 0.3)), m("stripe" if i % 2 == 0 else "road"), c + Vector3(-3 + i * 1.0, 0.03, 5.0))
	_truck(c + Vector3(3.5, 0, 4.8), PI / 2.0)


func _tank_factory(b: Vector2) -> void:
	var c := _block_center(b)
	var size := Vector3(10.0, 4.0, 14.0)
	shade(self, c, Vector2(12, 16))
	rbox(self, size, c + Vector3(0, 2.0, 0), m("wall3"), 0.25)
	var roof := MeshKit.add(self, MeshKit.cyl(5.1, 5.1, 14.2, 24), m("roof3" if tone == "happy" else "roof"), c + Vector3(0, 4.0, 0))
	roof.rotation.x = PI / 2.0
	roof.scale = Vector3(1, 1, 0.55)
	# Big striped door facing the street (+x).
	MeshKit.add(self, MeshKit.box(Vector3(0.12, 3.4, 7.0)), m("metal", 0.5), c + Vector3(5.06, 1.7, 0))
	for i in 6:
		MeshKit.add(self, MeshKit.box(Vector3(0.14, 0.12, 7.0)), m("stripe" if i % 2 == 0 else "road"), c + Vector3(5.1, 0.4 + i * 0.5, 0))
	windows(self, size, c, 1, 0, 3, 2.4)
	_tank(c + Vector3(7.8, 0, -3.2), PI / 2.0)
	_tank(c + Vector3(7.8, 0, 3.6), PI / 2.0)


func _power_plant(b: Vector2) -> void:
	var c := _block_center(b)
	var tower := c + Vector3(-2.2, 0, -2.6)
	shade(self, tower, Vector2(8, 8))
	MeshKit.add(self, MeshKit.cyl(2.4, 3.4, 7.0, 24), m("wall2" if tone == "happy" else "wall3", 0.7), tower + Vector3(0, 3.5, 0))
	MeshKit.add(self, MeshKit.cyl(2.5, 2.4, 0.5, 24), m("accent", 0.6), tower + Vector3(0, 6.6, 0))
	Fx.smoke(self, tower + Vector3(0, 8.0, 0), 3.0, 0.0, Color(0.95, 0.95, 0.97))
	var hall := c + Vector3(2.4, 0, 2.2)
	shade(self, hall, Vector2(7, 7))
	rbox(self, Vector3(5.6, 3.6, 5.6), hall + Vector3(0, 1.8, 0), m("wall"), 0.2)
	windows(self, Vector3(5.6, 3.6, 5.6), hall, 1, 2, 2, 1.9)
	rbox(self, Vector3(6.0, 0.4, 6.0), hall + Vector3(0, 3.8, 0), m("roof4"), 0.15)
	MeshKit.add(self, MeshKit.cyl(0.45, 0.55, 6.0, 12), m("metal", 0.5), hall + Vector3(-1.6, 6.8, -1.6))
	MeshKit.add(self, MeshKit.cyl(0.47, 0.47, 0.5, 12), m("accent", 0.5), hall + Vector3(-1.6, 9.2, -1.6))
	# A bolt sign on the roof.
	MeshKit.add(self, MeshKit.box(Vector3(0.3, 1.2, 1.2)), m("stripe", 0.6), hall + Vector3(2.0, 4.6, 1.2))


func _warehouse(b: Vector2) -> void:
	var c := _block_center(b)
	var size := Vector3(9.0, 3.6, 8.0)
	var at := c + Vector3(-0.6, 0, -1.0)
	shade(self, at, Vector2(11, 10))
	rbox(self, size, at + Vector3(0, 1.8, 0), m("wall2"), 0.2)
	for i in 8:
		MeshKit.add(self, MeshKit.box(Vector3(0.9, 0.5, 0.06)), m("stripe" if i % 2 == 0 else "accent", 0.6), at + Vector3(-3.9 + i * 1.1, 3.2, 4.04))
	MeshKit.add(self, MeshKit.box(Vector3(3.6, 2.4, 0.08)), m("metal", 0.5), at + Vector3(-1.5, 1.2, 4.04))
	gable(self, 9.6, 8.6, 1.6, at + Vector3(0, 3.6, 0), m("roof4" if tone == "happy" else "roof2"))
	for i in 5:
		var crate := rbox(self, Vector3.ONE * 1.2, c + Vector3(3.2 + (i % 2) * 1.3, 0.6 + (i / 3) * 1.2, 3.0 - (i % 3) * 1.3), m("wall3" if i % 2 == 0 else "trunk", 0.8), 0.1)
		crate.rotation.y = _rng.randf_range(-0.2, 0.2)


func _lab(b: Vector2) -> void:
	var c := _block_center(b)
	var size := Vector3(10.0, 5.6, 6.0)
	var at := c + Vector3(-1.0, 0, -1.6)
	shade(self, at, Vector2(12, 8))
	rbox(self, size, at + Vector3(0, 2.8, 0), m("frame" if tone == "happy" else "wall2", 0.6), 0.25)
	windows(self, size, at, 2, 2, 4, 1.4)
	rbox(self, Vector3(10.4, 0.4, 6.4), at + Vector3(0, 5.8, 0), m("roof2"), 0.15)
	# Satellite dish on the roof.
	var dish := MeshKit.add(self, MeshKit.sphere(1.5, 16), m("frame", 0.4), at + Vector3(2.8, 7.4, 0))
	dish.scale = Vector3(1, 0.35, 1)
	dish.rotation.x = -0.6
	MeshKit.add(self, MeshKit.cyl(0.12, 0.12, 1.4, 6), m("metal"), at + Vector3(2.8, 6.6, 0))
	# Parking with two jeeps.
	for i in 3:
		MeshKit.add(self, MeshKit.box(Vector3(0.18, 0.04, 2.6)), m("line"), c + Vector3(-4.0 + i * 3.0, 0.03, 4.6))
	_jeep(c + Vector3(-2.5, 0, 4.6), 0.0)
	_jeep(c + Vector3(0.5, 0, 4.6), 0.0)


func _defense_corner(b: Vector2) -> void:
	var c := _block_center(b)
	# Sandbag ring with a gun, a flag and a training dummy row.
	var nest := c + Vector3(-2.0, 0, -2.0)
	for k in 14:
		var a := k * TAU / 14.0
		var bag := MeshKit.add(self, MeshKit.sphere(0.55, 8), m("sand"), nest + Vector3(cos(a) * 2.4, 0.4, sin(a) * 2.4))
		bag.scale = Vector3(1.2, 0.6, 0.8)
		bag.rotation.y = -a
	MeshKit.add(self, MeshKit.box(Vector3(0.25, 0.25, 2.4)), m("metal", 0.4), nest + Vector3(0.5, 1.2, 0.6)).rotation.y = 0.8
	MeshKit.add(self, MeshKit.cyl(0.08, 0.1, 1.0, 6), m("metal"), nest + Vector3(0, 0.7, 0))
	_soldiers(nest + Vector3(-0.6, 0, 0.6), 1)
	_watchtower(c + Vector3(3.0, 0, 3.0))
	_soldiers(c + Vector3(-3.0, 0, 3.5), 3)


func _watchtower(at: Vector3) -> void:
	shade(self, at, Vector2(4, 4))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			MeshKit.add(self, MeshKit.box(Vector3(0.22, 5.0, 0.22)), m("trunk", 0.8), at + Vector3(x, 2.5, z))
	rbox(self, Vector3(2.8, 1.0, 2.8), at + Vector3(0, 5.4, 0), m("wall3"), 0.12)
	var roof := MeshKit.add(self, MeshKit.cyl(0.0, 2.4, 1.4, 4), m("roof"), at + Vector3(0, 7.2, 0))
	roof.rotation.y = PI / 4.0
	for y in [6.0, 6.5]:
		MeshKit.add(self, MeshKit.box(Vector3(0.12, 0.6, 0.12)), m("trunk"), at + Vector3(1.3, y, 1.3))


# ---------------------------------------------------------------- vehicles and people

func _jeep(at: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	add_child(n)
	shade(n, Vector3.ZERO, Vector2(2.6, 4.0), 0.5)
	rbox(n, Vector3(1.7, 0.8, 3.2), Vector3(0, 0.9, 0), m("jeep", 0.6), 0.2)
	rbox(n, Vector3(1.5, 0.7, 1.4), Vector3(0, 1.6, -0.3), m("jeep", 0.6), 0.15)
	MeshKit.add(n, MeshKit.box(Vector3(1.3, 0.5, 0.06)), m("glass", 0.3), Vector3(0, 1.6, 0.42))
	for x in [-0.85, 0.85]:
		for z in [-1.0, 1.0]:
			MeshKit.add(n, MeshKit.cyl(0.38, 0.38, 0.3, 12), MeshKit.mat(Color(0.15, 0.15, 0.16), 0.8), Vector3(x, 0.4, z)).rotation.z = PI / 2.0


func _truck(at: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	add_child(n)
	shade(n, Vector3.ZERO, Vector2(3, 6), 0.5)
	rbox(n, Vector3(2.0, 1.6, 1.6), Vector3(0, 1.3, 2.0), m("jeep", 0.6), 0.2)
	MeshKit.add(n, MeshKit.box(Vector3(1.7, 0.6, 0.06)), m("glass", 0.3), Vector3(0, 1.6, 2.82))
	var tank := MeshKit.add(n, MeshKit.cyl(0.95, 0.95, 3.4, 16), m("frame" if tone == "happy" else "wall2", 0.5), Vector3(0, 1.4, -0.6))
	tank.rotation.x = PI / 2.0
	for z in [-1.6, 0.4, 2.0]:
		for x in [-0.95, 0.95]:
			MeshKit.add(n, MeshKit.cyl(0.42, 0.42, 0.3, 12), MeshKit.mat(Color(0.15, 0.15, 0.16), 0.8), Vector3(x, 0.42, z)).rotation.z = PI / 2.0


func _tank(at: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	add_child(n)
	shade(n, Vector3.ZERO, Vector2(4, 6), 0.5)
	for x in [-1.3, 1.3]:
		rbox(n, Vector3(0.8, 0.9, 5.0), Vector3(x, 0.45, 0), MeshKit.mat(Color(0.2, 0.2, 0.2), 0.8), 0.25)
	rbox(n, Vector3(2.6, 0.9, 4.4), Vector3(0, 1.1, 0), m("tank", 0.7), 0.2)
	rbox(n, Vector3(1.8, 0.8, 2.0), Vector3(0, 1.9, -0.2), m("tank", 0.7), 0.25)
	MeshKit.add(n, MeshKit.cyl(0.14, 0.16, 2.8, 8), m("tank", 0.7), Vector3(0, 1.95, 2.0)).rotation.x = PI / 2.0


## A few tiny soldiers in a loose group: boots, uniform, a round head and a helmet.
func _soldiers(at: Vector3, count: int) -> void:
	for i in count:
		var n := Node3D.new()
		n.position = at + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
		n.rotation.y = _rng.randf() * TAU
		n.scale = Vector3.ONE * 1.4
		add_child(n)
		for x in [-0.12, 0.12]:
			MeshKit.add(n, MeshKit.box(Vector3(0.16, 0.5, 0.18)), MeshKit.mat(Color(0.2, 0.2, 0.18), 0.8), Vector3(x, 0.25, 0))
		MeshKit.add(n, MeshKit.capsule(0.22, 0.75), m("uniform", 0.8), Vector3(0, 0.82, 0))
		MeshKit.add(n, MeshKit.sphere(0.2, 10), m("skin", 0.7), Vector3(0, 1.38, 0))
		var helmet := MeshKit.add(n, MeshKit.sphere(0.23, 10), m("uniform", 0.6), Vector3(0, 1.45, 0))
		helmet.scale = Vector3(1, 0.65, 1)
		shade(n, Vector3.ZERO, Vector2(0.9, 0.9), 0.35)


func _traffic() -> void:
	_jeep(pos(2, 4.6) + Vector3(-1.4, 0.05, 0), PI)
	_jeep(pos(5.2, 6) + Vector3(0, 0.05, 1.4), PI / 2.0)
	_truck(pos(6, 2.2) + Vector3(1.4, 0.05, 0), 0.0)
	_soldiers(pos(2, 6) + Vector3(2.8, 0.35, 2.8), 2)
