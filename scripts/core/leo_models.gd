class_name LeoModels
extends RefCounted
## Base Wars buildings in the approved "leo" look (owner, 15.10.2026, after his Leonardo picture,
## sketch AaiZwV3Jjo92kGX1rZEgZY): khaki and concrete walls with soft edges, olive ribbed metal
## roofs, framed blue windows on the faces the camera sees (+x and +z), red only on fuel. Each model
## fits its pad (about 4.8 m) and changes with every level: it grows, adds a part at 2-5 and wears
## the level color (silver, blue, red, gold) on a trim band from level 2.
## build() returns the height, for the level label.

const WALL := Color(0.84, 0.78, 0.62)
const WALL2 := Color(0.72, 0.73, 0.72)
const ROOF := Color(0.33, 0.43, 0.24)
const GLASS := Color(0.25, 0.42, 0.5)
const FRAME := Color(0.92, 0.9, 0.85)
const METAL := Color(0.6, 0.61, 0.62)
const RED := Color(0.85, 0.2, 0.15)
const STRIPE := Color(0.95, 0.78, 0.1)
const DARK := Color(0.2, 0.2, 0.21)
const PANEL := Color(0.18, 0.26, 0.42)

const TYPES := ["hq", "generator", "storage", "pump", "tank", "camp", "quarters", "garage", "hangar", "support", "planning"]


static func has(type: String) -> bool:
	return MeshKit.look == "leo" and type in TYPES


static func build(root: Node3D, type: String, level: int) -> float:
	match type:
		"hq":
			return _hq(root, level)
		"generator":
			return _generator(root, level)
		"storage":
			return _storage(root, level)
		"pump":
			return _pump(root, level)
		"tank":
			return _fuel_tanks(root, level)
		"camp":
			return _camp(root, level)
		"quarters":
			return _quarters(root, level)
		"garage":
			return _garage(root, level)
		"hangar":
			return _hangar(root, level)
		"support":
			return _support(root, level)
		"planning":
			return _planning(root, level)
	return 3.0


# ---------------------------------------------------------------- kit

static func m(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	return MeshKit.mat(c, rough)


## A box with chamfered edges (three overlapping boxes): a soft toy edge from afar.
static func rbox(parent: Node3D, size: Vector3, at: Vector3, mat: Material, b: float = 0.08) -> void:
	MeshKit.add(parent, MeshKit.box(size - Vector3(0, 2 * b, 2 * b)), mat, at)
	MeshKit.add(parent, MeshKit.box(size - Vector3(2 * b, 0, 2 * b)), mat, at)
	MeshKit.add(parent, MeshKit.box(size - Vector3(2 * b, 2 * b, 0)), mat, at)


## A ribbed metal gable roof over w (x) by d (z) whose ridge runs along z, or along x.
static func gable(parent: Node3D, w: float, d: float, h: float, at: Vector3, color: Color = ROOF, along_z := true) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(w if along_z else d, h, d if along_z else w)
	var r := MeshKit.add(parent, prism, m(color, 0.6), at + Vector3(0, h / 2.0, 0))
	r.rotation.y = 0.0 if along_z else PI / 2.0
	var span := (w if along_z else d) / 2.0
	var length := d if along_z else w
	var slope := Vector2(span, h).length()
	var tilt := atan2(h, span)
	var rib := m(color.lightened(0.15), 0.6)
	var k := -length / 2.0 + 0.3
	while k < length / 2.0 - 0.15:
		for side in [-1.0, 1.0]:
			var piece := MeshKit.add(parent, MeshKit.box(Vector3(slope, 0.05, 0.06)), rib)
			var xf := Transform3D(Basis(Vector3(0, 0, 1), -side * tilt), Vector3(side * span / 2.0, h / 2.0 + 0.03, k))
			if not along_z:
				xf = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO) * xf
			piece.transform = Transform3D(Basis(), at) * xf
		k += 0.45


## Framed windows on the +x and +z faces of a box of `size` whose base centre is `at`.
static func windows(parent: Node3D, size: Vector3, at: Vector3, rows: int, cols_x: int, cols_z: int, y0: float, step: float = 1.0) -> void:
	var glass := m(GLASS, 0.3)
	var frame := m(FRAME, 0.6)
	for row in rows:
		var y := at.y + y0 + row * step
		for i in cols_z:
			var x := at.x - size.x / 2.0 + size.x * (i + 0.5) / cols_z
			MeshKit.add(parent, MeshKit.box(Vector3(0.48, 0.56, 0.05)), frame, Vector3(x, y, at.z + size.z / 2.0 + 0.02))
			MeshKit.add(parent, MeshKit.box(Vector3(0.36, 0.44, 0.06)), glass, Vector3(x, y, at.z + size.z / 2.0 + 0.03))
		for i in cols_x:
			var z := at.z - size.z / 2.0 + size.z * (i + 0.5) / cols_x
			MeshKit.add(parent, MeshKit.box(Vector3(0.05, 0.56, 0.48)), frame, Vector3(at.x + size.x / 2.0 + 0.02, y, z))
			MeshKit.add(parent, MeshKit.box(Vector3(0.06, 0.44, 0.36)), glass, Vector3(at.x + size.x / 2.0 + 0.03, y, z))


## A flat roof with a low parapet on a box of `size` whose base centre is `at`.
static func flat_roof(parent: Node3D, size: Vector3, at: Vector3, color: Color = WALL2) -> void:
	var top := at.y + size.y
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var edge := Vector3(0.14, 0.25, size.z) if side.x != 0 else Vector3(size.x, 0.25, 0.14)
		MeshKit.add(parent, MeshKit.box(edge), m(color, 0.7), Vector3(at.x + side.x * (size.x / 2.0 - 0.07), top + 0.12, at.z + side.z * (size.z / 2.0 - 0.07)))
	MeshKit.add(parent, MeshKit.box(Vector3(size.x - 0.3, 0.03, size.z - 0.3)), m(METAL, 0.85), Vector3(at.x, top + 0.02, at.z))


## The level band: a thin trim in the level color round a box, from level 2.
static func trim(parent: Node3D, size: Vector3, at: Vector3, y: float, level: int) -> void:
	if level < 2:
		return
	MeshKit.add(parent, MeshKit.box(Vector3(size.x + 0.04, 0.14, size.z + 0.04)), UnitModels.level_material(level), at + Vector3(0, y, 0))


static func door(parent: Node3D, at: Vector3, w: float, h: float, on_x: bool, color: Color = DARK) -> void:
	MeshKit.add(parent, MeshKit.box(Vector3(0.05, h, w) if on_x else Vector3(w, h, 0.05)), m(color, 0.6), at + Vector3(0, h / 2.0, 0))


static func flag(parent: Node3D, at: Vector3, height: float, level: int) -> void:
	MeshKit.add(parent, MeshKit.cyl(0.03, 0.04, height, 6), m(METAL, 0.4), at + Vector3(0, height / 2.0, 0))
	MeshKit.add(parent, MeshKit.box(Vector3(0.03, 0.4, 0.65)), UnitModels.level_material(level) if level >= 3 else m(Color(0.2, 0.32, 0.55), 0.7), at + Vector3(0, height - 0.25, 0.33))


static func crates(parent: Node3D, at: Vector3, n: int) -> void:
	for i in n:
		rbox(parent, Vector3.ONE * 0.5, at + Vector3((i % 2) * 0.55, 0.25 + (i / 2) * 0.5, 0.0), m(Color(0.62, 0.48, 0.3), 0.8), 0.04)


# ---------------------------------------------------------------- buildings

## Command Tower: Leonardo's control tower. A plinth, a shaft with slit windows that grows each
## level, a glass cab, a deck with a rail from Lv3, a pointed cap (gold at Lv5), a flag from Lv2
## and a dish at Lv4+.
static func _hq(root: Node3D, level: int) -> float:
	# Command Tower skins (StructureModels.skin): the walls, the roof and the glass take the
	# skin's colours; snow adds white caps.
	var skin: Dictionary = StructureModels.HQ_SKINS.get(StructureModels.skin.get("hq", ""), {})
	var wall: Color = skin.get("wall", WALL)
	var roof: Color = skin.get("cap", ROOF)
	var glass: Color = (skin["glow"] as Color).darkened(0.35) if skin.has("glow") else GLASS
	rbox(root, Vector3(4.6, 0.5, 4.6), Vector3(0, 0.25, 0), m(WALL2), 0.1)
	for i in 2:
		MeshKit.add(root, MeshKit.box(Vector3(1.4, 0.12, 0.4)), m(WALL2, 0.9), Vector3(0, 0.06 + i * 0.12, 2.5 - i * 0.2))
	var shaft := 2.4 + 0.6 * level
	rbox(root, Vector3(2.6, shaft, 2.6), Vector3(0, 0.5 + shaft / 2.0, 0), m(wall), 0.12)
	for k in int(shaft / 1.0):
		for side: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			MeshKit.add(root, MeshKit.box(Vector3(0.05, 0.6, 0.3) if side.x > 0 else Vector3(0.3, 0.6, 0.05)), m(glass, 0.3), side * 1.31 + Vector3(0, 1.2 + k * 1.0, 0))
	trim(root, Vector3(2.6, 0, 2.6), Vector3(0, 0.5, 0), shaft * 0.5, level)
	var cab := 0.5 + shaft
	if level >= 3:
		rbox(root, Vector3(3.8, 0.2, 3.8), Vector3(0, cab + 0.1, 0), m(WALL2), 0.05)
		for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			MeshKit.add(root, MeshKit.box(Vector3(0.04, 0.04, 3.7) if side.x != 0 else Vector3(3.7, 0.04, 0.04)), m(FRAME, 0.6), side * 1.85 + Vector3(0, cab + 0.6, 0))
		cab += 0.2
	rbox(root, Vector3(3.0, 1.3, 3.0), Vector3(0, cab + 0.65, 0), m(wall), 0.06)
	MeshKit.add(root, MeshKit.box(Vector3(3.04, 0.85, 3.04)), m(glass, 0.25), Vector3(0, cab + 0.7, 0))
	for k in 3:
		for side: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			var off := Vector3(side.z, 0, side.x) * (-0.75 + k * 0.75)
			MeshKit.add(root, MeshKit.box(Vector3(0.05, 0.9, 0.08) if side.x > 0 else Vector3(0.08, 0.9, 0.05)), m(FRAME, 0.6), side * 1.53 + off + Vector3(0, cab + 0.7, 0))
	rbox(root, Vector3(3.4, 0.25, 3.4), Vector3(0, cab + 1.42, 0), m(roof, 0.6), 0.05)
	var cap := MeshKit.add(root, MeshKit.cyl(0.0, 1.6, 1.2, 4), UnitModels.level_material(5) if level >= 5 else m(roof, 0.6), Vector3(0, cab + 2.15, 0))
	if skin.get("snow", false):
		rbox(root, Vector3(3.5, 0.12, 3.5), Vector3(0, cab + 1.6, 0), m(Color(0.97, 0.98, 1.0), 0.9), 0.04)
		rbox(root, Vector3(4.7, 0.1, 4.7), Vector3(0, 0.55, 0), m(Color(0.97, 0.98, 1.0), 0.9), 0.04)
	cap.rotation.y = PI / 4.0
	var top := cab + 2.75
	MeshKit.add(root, MeshKit.cyl(0.03, 0.04, 1.2, 6), m(METAL, 0.4), Vector3(0, top + 0.6, 0))
	MeshKit.add(root, MeshKit.sphere(0.07, 6), MeshKit.glow(Color(1.0, 0.3, 0.2)), Vector3(0, top + 1.2, 0))
	if level >= 2:
		flag(root, Vector3(1.8, 0.5, 1.8), 2.2, level)
	if level >= 4:
		var dish := MeshKit.add(root, MeshKit.sphere(0.5, 12), m(FRAME, 0.4), Vector3(-1.2, cab + 1.9, -1.2))
		dish.scale = Vector3(1, 0.35, 1)
		dish.rotation.x = -0.6
	return top + 1.2


## Solar Generator (coins): a concrete apron with rows of tilted panels (one more row per level up
## to four) and an inverter hut; Lv5 gold panel frames.
static func _generator(root: Node3D, level: int) -> float:
	rbox(root, Vector3(4.7, 0.2, 4.7), Vector3(0, 0.1, 0), m(WALL2), 0.05)
	rbox(root, Vector3(1.6, 1.8, 1.6), Vector3(-1.4, 1.1, -1.4), m(WALL), 0.06)
	windows(root, Vector3(1.6, 1.8, 1.6), Vector3(-1.4, 0.2, -1.4), 1, 1, 1, 1.0)
	gable(root, 1.8, 1.8, 0.6, Vector3(-1.4, 2.0, -1.4))
	trim(root, Vector3(1.6, 0, 1.6), Vector3(-1.4, 0.2, -1.4), 1.5, level)
	var rows := mini(1 + level, 4)
	var frame := UnitModels.level_material(5) if level >= 5 else m(METAL, 0.5)
	for r in rows:
		var z := -0.6 + r * 0.95
		for c in 2:
			var x := 0.1 + c * 1.3
			var p := MeshKit.add(root, MeshKit.box(Vector3(1.2, 0.05, 0.8)), m(PANEL, 0.25), Vector3(x, 1.05, z))
			p.rotation.x = -0.5
			MeshKit.add(root, MeshKit.box(Vector3(1.26, 0.04, 0.86)), frame, Vector3(x, 1.02, z)).rotation.x = -0.5
			MeshKit.add(root, MeshKit.box(Vector3(0.08, 0.85, 0.08)), m(METAL), Vector3(x, 0.6, z))
	return 3.0


## Coin Silo: a warehouse with a ribbed gable roof, a yellow-red striped band and a roller door;
## grows each level, an annex at Lv3, crates at Lv2+, a gold roof ridge at Lv5.
static func _storage(root: Node3D, level: int) -> float:
	var h := 1.8 + 0.15 * level
	var size := Vector3(3.2, h, 3.8)
	var at := Vector3(-0.4, 0, -0.3)
	rbox(root, size, at + Vector3(0, h / 2.0, 0), m(WALL2), 0.08)
	for i in 6:
		MeshKit.add(root, MeshKit.box(Vector3(0.53, 0.25, 0.04)), m(STRIPE if i % 2 == 0 else RED, 0.6), at + Vector3(-1.33 + i * 0.53, h - 0.3, size.z / 2.0 + 0.02))
	door(root, at + Vector3(0, 0, size.z / 2.0 + 0.03), 1.4, 1.1, false, METAL)
	windows(root, size, at, 1, 2, 0, h * 0.55)
	gable(root, 3.4, 4.0, 0.9, at + Vector3(0, h, 0), ROOF, true)
	if level >= 5:
		MeshKit.add(root, MeshKit.box(Vector3(0.12, 0.1, 4.0)), UnitModels.level_material(5), at + Vector3(0, h + 0.92, 0))
	trim(root, size, at, 0.3, level)
	if level >= 3:
		rbox(root, Vector3(1.2, 1.2, 1.6), Vector3(1.8, 0.6, 1.2), m(WALL), 0.06)
		gable(root, 1.4, 1.8, 0.45, Vector3(1.8, 1.2, 1.2))
	if level >= 2:
		crates(root, Vector3(1.4, 0, -1.6), 3 if level >= 4 else 2)
	return h + 1.2


## Fuel Pump: a refinery column (taller each level) with pipes, a pump hut with a red band and
## a pumpjack walking beam from Lv3; Lv5 a second column.
static func _pump(root: Node3D, level: int) -> float:
	rbox(root, Vector3(4.6, 0.2, 4.6), Vector3(0, 0.1, 0), m(WALL2), 0.05)
	var col := 2.6 + 0.4 * level
	MeshKit.add(root, MeshKit.cyl(0.5, 0.55, col, 16), m(FRAME, 0.5), Vector3(-1.2, col / 2.0 + 0.2, -1.0))
	MeshKit.add(root, MeshKit.cyl(0.52, 0.52, 0.25, 16), m(RED, 0.5), Vector3(-1.2, col * 0.7, -1.0))
	MeshKit.add(root, MeshKit.cyl(0.2, 0.5, 0.4, 16), m(METAL), Vector3(-1.2, col + 0.4, -1.0))
	if level >= 5:
		MeshKit.add(root, MeshKit.cyl(0.4, 0.45, col * 0.8, 16), m(FRAME, 0.5), Vector3(-1.9, col * 0.4 + 0.2, 0.3))
	for i in 2:
		var pipe := MeshKit.add(root, MeshKit.cyl(0.08, 0.08, 2.0, 8), m(METAL, 0.5), Vector3(0.0, 0.5 + i * 0.3, -1.0))
		pipe.rotation.z = PI / 2.0
	rbox(root, Vector3(1.8, 1.2, 1.6), Vector3(1.1, 0.8, 1.0), m(WALL), 0.06)
	MeshKit.add(root, MeshKit.box(Vector3(1.84, 0.2, 1.64)), m(RED, 0.6), Vector3(1.1, 1.2, 1.0))
	gable(root, 2.0, 1.8, 0.5, Vector3(1.1, 1.4, 1.0), ROOF, false)
	windows(root, Vector3(1.8, 1.2, 1.6), Vector3(1.1, 0.2, 1.0), 1, 1, 1, 0.65)
	trim(root, Vector3(1.0, 0, 1.0), Vector3(-1.2, 0.2, -1.0), 0.6, level)
	if level >= 3:
		var beam := MeshKit.add(root, MeshKit.box(Vector3(0.16, 0.16, 1.8)), m(DARK, 0.6), Vector3(1.3, 2.4, -1.2))
		beam.rotation.x = 0.25
		MeshKit.add(root, MeshKit.box(Vector3(0.12, 1.6, 0.12)), m(DARK, 0.6), Vector3(1.3, 1.4, -1.2))
		MeshKit.add(root, MeshKit.box(Vector3(0.3, 0.5, 0.3)), m(RED, 0.6), Vector3(1.3, 2.2, -0.35))
	return col + 0.8


## Fuel Tank: tall white tanks with a red band; one at Lv1-2, two at Lv3-4, three at Lv5, taller
## each level, with a ladder and a rail on top.
static func _fuel_tanks(root: Node3D, level: int) -> float:
	rbox(root, Vector3(4.6, 0.2, 4.6), Vector3(0, 0.1, 0), m(WALL2), 0.05)
	var h := 2.6 + 0.35 * level
	var spots := [Vector3(0, 0, 0)]
	if level >= 3:
		spots = [Vector3(-1.0, 0, -0.8), Vector3(1.0, 0, 0.9)]
	if level >= 5:
		spots = [Vector3(-1.2, 0, -1.1), Vector3(1.2, 0, -0.6), Vector3(-0.3, 0, 1.3)]
	var r := 1.3 if spots.size() == 1 else (1.0 if spots.size() == 2 else 0.85)
	for p: Vector3 in spots:
		MeshKit.add(root, MeshKit.cyl(r, r, h, 20), m(FRAME, 0.5), p + Vector3(0, 0.2 + h / 2.0, 0))
		MeshKit.add(root, MeshKit.cyl(r + 0.02, r + 0.02, 0.35, 20), m(RED, 0.5), p + Vector3(0, 0.2 + h * 0.62, 0))
		MeshKit.add(root, MeshKit.cyl(r * 0.3, r, 0.35, 20), m(METAL, 0.5), p + Vector3(0, 0.38 + h, 0))
		MeshKit.add(root, MeshKit.box(Vector3(0.06, h, 0.3)), m(METAL, 0.5), p + Vector3(r + 0.03, 0.2 + h / 2.0, 0))
		if level >= 2:
			MeshKit.add(root, MeshKit.ring(r * 0.95, 0.04), UnitModels.level_material(level), p + Vector3(0, 0.2 + h + 0.05, 0))
	return h + 1.0


## Training Camp: a long low barracks with a ribbed roof and an exercise yard; Lv2 a flag, Lv3 a
## climbing wall, Lv4 targets, Lv5 a second barracks.
static func _camp(root: Node3D, level: int) -> float:
	var size := Vector3(1.9, 1.5, 4.2)
	var at := Vector3(-1.3, 0, 0)
	rbox(root, size, at + Vector3(0, 0.75, 0), m(WALL), 0.06)
	windows(root, size, at, 1, 3, 1, 0.85)
	gable(root, 2.1, 4.4, 0.7, at + Vector3(0, 1.5, 0))
	trim(root, size, at, 0.2, level)
	MeshKit.add(root, MeshKit.box(Vector3(2.3, 0.04, 4.2)), m(Color(0.75, 0.66, 0.48), 0.95), Vector3(1.1, 0.02, 0))
	if level >= 2:
		flag(root, Vector3(2.0, 0, -1.8), 2.6, level)
	if level >= 3:
		rbox(root, Vector3(0.2, 1.1, 1.4), Vector3(1.0, 0.55, -0.6), m(Color(0.55, 0.42, 0.28), 0.8), 0.03)
	if level >= 4:
		for z in [0.6, 1.4]:
			MeshKit.add(root, MeshKit.cyl(0.3, 0.3, 0.05, 12), m(RED, 0.6), Vector3(2.1, 0.7, z)).rotation.z = PI / 2.0
	if level >= 5:
		rbox(root, Vector3(1.4, 1.2, 1.4), Vector3(1.0, 0.6, 1.4), m(WALL), 0.06)
		gable(root, 1.6, 1.6, 0.5, Vector3(1.0, 1.2, 1.4))
	return 2.6


## Quarters: Leonardo's barracks, a khaki house with a big olive ribbed roof and a garage door on
## the street side; a second floor of windows at Lv3, a chimney at Lv4, roof panels at Lv5.
static func _quarters(root: Node3D, level: int) -> float:
	var h := 1.8 + (0.9 if level >= 3 else 0.0)
	var size := Vector3(3.4, h, 4.2)
	var at := Vector3(-0.3, 0, -0.2)
	rbox(root, size, at + Vector3(0, h / 2.0, 0), m(WALL), 0.08)
	windows(root, size, at, 2 if level >= 3 else 1, 2, 2, 1.0, 0.9)
	door(root, at + Vector3(size.x / 2.0 + 0.03, 0, -1.0), 1.3, 1.1, true, WALL2)
	for k in 4:
		MeshKit.add(root, MeshKit.box(Vector3(0.06, 0.04, 1.3)), m(METAL, 0.6), at + Vector3(size.x / 2.0 + 0.06, 0.2 + k * 0.25, -1.0))
	gable(root, 3.7, 4.5, 1.1, at + Vector3(0, h, 0))
	trim(root, size, at, 0.25, level)
	if level >= 2:
		crates(root, Vector3(1.8, 0, 1.5), 2)
	if level >= 4:
		MeshKit.add(root, MeshKit.box(Vector3(0.35, 0.8, 0.35)), m(WALL2), at + Vector3(-0.9, h + 0.9, -1.2))
	if level >= 5:
		var p := MeshKit.add(root, MeshKit.box(Vector3(1.2, 0.05, 1.6)), m(PANEL, 0.25), at + Vector3(0.95, h + 0.6, 0.6))
		p.rotation.z = -0.5
	return h + 1.6


## Garage (tanks): a hangar with a curved olive roof and a yellow-black striped door on the
## street side; longer each level, a tank parked out front from Lv3, a gold door frame at Lv5.
static func _garage(root: Node3D, level: int) -> float:
	var length := 3.4 + 0.2 * level
	var at := Vector3(-0.5, 0, 0)
	rbox(root, Vector3(3.2, 1.5, length), at + Vector3(0, 0.75, 0), m(WALL), 0.06)
	var roof := MeshKit.add(root, MeshKit.cyl(1.65, 1.65, length + 0.2, 20), m(ROOF, 0.6), at + Vector3(0, 1.5, 0))
	roof.rotation.x = PI / 2.0
	roof.scale = Vector3(1, 1, 0.75)
	var door_at := at + Vector3(1.62, 0, 0)
	MeshKit.add(root, MeshKit.box(Vector3(0.06, 1.4, 2.2)), m(DARK, 0.6), door_at + Vector3(0, 0.7, 0))
	for i in 5:
		MeshKit.add(root, MeshKit.box(Vector3(0.07, 0.12, 2.2)), m(STRIPE, 0.6), door_at + Vector3(0.01, 0.2 + i * 0.27, 0))
	if level >= 5:
		MeshKit.add(root, MeshKit.box(Vector3(0.08, 1.6, 2.5)), UnitModels.level_material(5), door_at + Vector3(-0.02, 0.8, 0))
	windows(root, Vector3(3.2, 1.5, length), at, 1, 0, 2, 0.9)
	trim(root, Vector3(3.2, 0, length), at, 0.15, level)
	if level >= 3:
		var tank := Node3D.new()
		tank.position = Vector3(2.0, 0, 1.6)
		root.add_child(tank)
		rbox(tank, Vector3(0.9, 0.35, 1.3), Vector3(0, 0.25, 0), m(Color(0.38, 0.47, 0.27), 0.7), 0.05)
		rbox(tank, Vector3(0.55, 0.25, 0.6), Vector3(0, 0.55, 0), m(Color(0.38, 0.47, 0.27), 0.7), 0.04)
		MeshKit.add(tank, MeshKit.cyl(0.05, 0.05, 0.8, 6), m(Color(0.38, 0.47, 0.27)), Vector3(0, 0.56, 0.6)).rotation.x = PI / 2.0
	return 3.4


## Drone Hangar: a flat-roofed hall with a wide door and a landing pad with an H on the roof;
## an antenna at Lv3, a drone parked on the pad at Lv4, gold H at Lv5.
static func _hangar(root: Node3D, level: int) -> float:
	var h := 1.9 + 0.12 * level
	var size := Vector3(4.0, h, 4.0)
	var at := Vector3(-0.2, 0, -0.2)
	rbox(root, size, at + Vector3(0, h / 2.0, 0), m(WALL2), 0.08)
	door(root, at + Vector3(0, 0, size.z / 2.0 + 0.03), 2.4, 1.4, false, METAL)
	for k in 4:
		MeshKit.add(root, MeshKit.box(Vector3(2.4, 0.04, 0.06)), m(DARK, 0.6), at + Vector3(0, 0.25 + k * 0.33, size.z / 2.0 + 0.06))
	windows(root, size, at, 1, 3, 0, h * 0.6)
	flat_roof(root, size, at)
	MeshKit.add(root, MeshKit.cyl(1.3, 1.3, 0.05, 24), m(DARK, 0.7), at + Vector3(0, h + 0.06, 0))
	var hmat := UnitModels.level_material(5) if level >= 5 else m(STRIPE, 0.6)
	MeshKit.add(root, MeshKit.ring(1.15, 0.08), hmat, at + Vector3(0, h + 0.1, 0))
	for x in [-0.35, 0.35]:
		MeshKit.add(root, MeshKit.box(Vector3(0.14, 0.03, 0.9)), hmat, at + Vector3(x, h + 0.1, 0))
	MeshKit.add(root, MeshKit.box(Vector3(0.7, 0.03, 0.14)), hmat, at + Vector3(0, h + 0.1, 0))
	trim(root, size, at, 0.2, level)
	if level >= 3:
		MeshKit.add(root, MeshKit.cyl(0.03, 0.04, 1.6, 6), m(METAL, 0.4), at + Vector3(1.7, h + 0.8, -1.7))
	if level >= 4:
		var drone := Node3D.new()
		drone.position = at + Vector3(0.3, h + 0.2, 0.2)
		drone.scale = Vector3.ONE * 0.9
		root.add_child(drone)
		DroneModels.build("courier", drone)
	return h + 1.4


## Support Base: a command hut with a large dish on a mast and a flag; more antennas each level,
## a second dish at Lv5.
static func _support(root: Node3D, level: int) -> float:
	var size := Vector3(2.6, 1.7, 2.6)
	var at := Vector3(0.6, 0, 0.6)
	rbox(root, size, at + Vector3(0, 0.85, 0), m(WALL), 0.07)
	windows(root, size, at, 1, 2, 2, 1.0)
	flat_roof(root, size, at, WALL)
	trim(root, size, at, 0.2, level)
	MeshKit.add(root, MeshKit.cyl(0.1, 0.12, 2.6, 8), m(METAL, 0.5), Vector3(-1.4, 1.3, -1.4))
	var dish := MeshKit.add(root, MeshKit.sphere(1.0, 16), m(FRAME, 0.4), Vector3(-1.4, 2.8, -1.4))
	dish.scale = Vector3(1, 0.35, 1)
	dish.rotation = Vector3(-0.7, 0.8, 0)
	for i in mini(level, 4):
		MeshKit.add(root, MeshKit.cyl(0.02, 0.03, 0.9 + 0.2 * i, 6), m(METAL, 0.4), at + Vector3(-0.8 + i * 0.5, 1.8 + 0.45 + 0.1 * i, -0.8))
	if level >= 5:
		var d2 := MeshKit.add(root, MeshKit.sphere(0.6, 12), UnitModels.level_material(5), at + Vector3(0.6, 2.3, 0.6))
		d2.scale = Vector3(1, 0.35, 1)
		d2.rotation.x = -0.6
	return 3.6


## Planning HQ: Leonardo's lab, an L of two flat-roofed blocks with parapets, roof units, a dish
## and a green awning; grows a floor at Lv3, a dish at Lv4, a gold parapet at Lv5.
static func _planning(root: Node3D, level: int) -> float:
	var h := 1.6 + (0.8 if level >= 3 else 0.0)
	var parts := [[Vector3(4.2, h, 2.0), Vector3(-0.2, 0, -1.2)], [Vector3(2.0, h - 0.4, 2.2), Vector3(0.9, 0, 0.9)]]
	for part: Array in parts:
		var size: Vector3 = part[0]
		var at: Vector3 = part[1]
		rbox(root, size, at + Vector3(0, size.y / 2.0, 0), m(WALL2, 0.7), 0.06)
		windows(root, size, at, 2 if level >= 3 else 1, 1, 2, 0.9, 0.8)
		flat_roof(root, size, at, Color(0.95, 0.75, 0.23) if level >= 5 else WALL2)
		trim(root, size, at, 0.2, level)
	MeshKit.add(root, MeshKit.box(Vector3(0.6, 0.35, 0.5)), m(METAL, 0.6), Vector3(-1.4, h + 0.2, -1.4))
	var awning := MeshKit.add(root, MeshKit.box(Vector3(0.05, 0.3, 1.2)), m(Color(0.25, 0.6, 0.4), 0.7), Vector3(2.05, 1.1, 0.9))
	awning.rotation.z = -0.5
	door(root, Vector3(1.93, 0, 0.9), 0.7, 0.9, true)
	if level >= 4:
		var dish := MeshKit.add(root, MeshKit.sphere(0.55, 12), m(FRAME, 0.4), Vector3(0.6, h + 0.35, -1.2))
		dish.scale = Vector3(1, 0.35, 1)
		dish.rotation.x = -0.6
	return h + 1.2
