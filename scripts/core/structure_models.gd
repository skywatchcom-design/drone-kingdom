class_name StructureModels
extends RefCounted
## Models for non-defense buildings. Every level changes something visible: the approved
## sketch's buildings (pump, fuel tank, camp, quarters, garage) step up at levels 3 and 5 and
## add a detail at 2 and 4; every building carries one gold chevron per level.

## The older models are drawn in a small unit size and scaled up to fill their pad.
const SCALE := 1.35
## Sketch-based models are drawn at pad size.
## Every model is drawn at pad size now; the 1.35 scale only remains for safety.
const PAD_SIZED := ["hq", "generator", "storage", "hangar", "pump", "tank", "camp", "quarters", "garage", "support"]
const FUEL := Color(0.93, 0.35, 0.55)


static func build(parent: Node3D, type: String, level: int, top: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = top
	root.scale = Vector3.ONE * (1.0 if type in PAD_SIZED else SCALE)
	var height := 3.0
	MeshKit.grime_root = root
	MeshKit.grime_top = 1.3
	MeshKit.blob(root, Vector2(6.6, 6.6), Vector3.ZERO, 0.5)
	match type:
		"hq":
			height = _hq(root, level)
		"generator":
			height = _generator(root, level)
		"storage":
			height = _storage(root, level)
		"pump":
			height = _pump(root, level)
		"tank":
			height = _tank(root, level)
		"camp":
			height = _camp(root, level)
		"quarters":
			height = _quarters(root, level)
		"garage":
			height = _garage(root, level)
		"support":
			height = _support(root, level)
		"hangar":
			height = _hangar(root, level)
	MeshKit.grime_root = null
	if type not in PAD_SIZED:
		chevrons(root, level, Vector3(1.7, 0, 1.7))
	level_label(root, level, height + 1.2)
	return root


static func level_label(parent: Node3D, level: int, y: float) -> Label3D:
	var label := Label3D.new()
	label.text = I18n.t("Lv %d") % level
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.02
	label.outline_size = 14
	label.position = Vector3(0, y, 0)
	parent.add_child(label)
	return label


## Command Tower (sketch Th5mNJUuSD5d77XEMeRnqE): navy block, glowing band, gold roof, red-tipped
## antenna. Lv2 a flag; Lv3 taller and wider with three antennas; Lv4 a satellite dish; Lv5 a
## radar dome and a gold band.
static func _hq(root: Node3D, level: int) -> float:
	var h: float = [2.6, 3.2, 4.2, 4.8, 5.8][clampi(level, 1, 5) - 1]
	var w := 4.0 if level >= 3 else 3.6
	var metal := MeshKit.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6)
	MeshKit.add(root, MeshKit.box(Vector3(w, h, w)), MeshKit.mat(Color(0.2, 0.23, 0.28), 0.4, 0.5), Vector3(0, h / 2.0, 0))
	MeshKit.add(root, MeshKit.box(Vector3(w + 0.06, 0.3, w + 0.06)), MeshKit.glow(Color(0.5, 0.9, 1.0)), Vector3(0, h * 0.62, 0))
	MeshKit.add(root, MeshKit.box(Vector3(w + 0.3, 0.38, w + 0.3)), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.3, 0.8), Vector3(0, h + 0.19, 0))
	if level >= 2:
		MeshKit.add(root, MeshKit.cyl(0.04, 0.04, 3.0, 6), MeshKit.mat(Color(0.75, 0.75, 0.77), 0.4, 0.6), Vector3(w / 2.0 + 0.5, 1.5, w / 2.0 + 0.5))
		MeshKit.add(root, MeshKit.box(Vector3(0.03, 0.55, 0.95)), MeshKit.mat(UnitModels.BLUE, 0.6), Vector3(w / 2.0 + 0.5, 2.7, w / 2.0 + 1.0))
		MeshKit.add(root, MeshKit.box(Vector3(0.031, 0.2, 0.95)), MeshKit.mat(UnitModels.WHITE, 0.6), Vector3(w / 2.0 + 0.5, 2.7, w / 2.0 + 1.0))
	var antennas := 3 if level >= 3 else 1
	for i in antennas:
		var ah := 2.2 + i * 0.5
		MeshKit.add(root, MeshKit.cyl(0.06, 0.06, ah, 6), metal, Vector3(-0.8 + i * 0.8, h + 0.38 + ah / 2.0, -0.5))
	MeshKit.add(root, MeshKit.sphere(0.16, 8), MeshKit.glow(Color(1.0, 0.25, 0.2)), Vector3(-0.8, h + 2.7, -0.5))
	if level >= 4:
		MeshKit.add(root, MeshKit.cyl(0.6, 0.15, 0.25, 16), MeshKit.mat(Color(0.85, 0.84, 0.8), 0.5, 0.3), Vector3(0.9, h + 0.75, 0.8)).rotation.x = -0.9
	if level >= 5:
		MeshKit.add(root, MeshKit.sphere(0.95, 16), MeshKit.mat(Color(0.91, 0.9, 0.87), 0.5, 0.2), Vector3(0, h + 1.3, 0.5))
		MeshKit.add(root, MeshKit.box(Vector3(w + 0.5, 0.2, 0.4)), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.3, 0.8), Vector3(0, h * 0.3, w / 2.0 + 0.12))
	chevrons(root, level, Vector3(2.3, 0, 2.3))
	return h + 2.9


## Solar generator: more panels with level. Lv1 two; Lv2 three; Lv3 four and a battery bank;
## Lv4 a small wind turbine; Lv5 six tilted panels.
static func _generator(root: Node3D, level: int) -> float:
	var panel := MeshKit.mat(Color(0.1, 0.16, 0.3), 0.2, 0.4)
	var frame := MeshKit.mat(Color(0.75, 0.77, 0.8), 0.4, 0.7)
	var count: int = [2, 3, 4, 4, 6][clampi(level, 1, 5) - 1]
	for i in count:
		var x := -1.6 + (i % 3) * 1.6
		var z := -1.2 + int(i / 3.0) * 2.2
		MeshKit.add(root, MeshKit.box(Vector3(0.1, 0.8, 0.1)), frame, Vector3(x, 0.4, z))
		var p := MeshKit.add(root, MeshKit.box(Vector3(1.4, 0.07, 1.0)), panel, Vector3(x, 0.85, z))
		p.rotation.x = -0.7 if level >= 5 else -0.5
	MeshKit.add(root, MeshKit.box(Vector3(0.6, 0.7, 0.5)), MeshKit.mat(Color(0.9, 0.9, 0.88), 0.6), Vector3(1.9, 0.35, 1.9))
	if level >= 3:
		for k in 3:
			MeshKit.add(root, MeshKit.box(Vector3(0.35, 0.6, 0.5)), MeshKit.mat(Color(0.18, 0.44, 0.25), 0.6), Vector3(-2.0 + k * 0.4, 0.3, 2.0))
	if level >= 4:
		MeshKit.add(root, MeshKit.cyl(0.05, 0.07, 2.6, 6), MeshKit.mat(Color(0.93, 0.93, 0.93), 0.4), Vector3(2.2, 1.3, -2.1))
		var hub := Node3D.new()
		hub.position = Vector3(2.2, 2.6, -1.95)
		root.add_child(hub)
		for b in 3:
			var arm := Node3D.new()
			arm.rotation.z = b * TAU / 3.0
			hub.add_child(arm)
			MeshKit.add(arm, MeshKit.box(Vector3(0.12, 1.0, 0.03)), MeshKit.mat(Color(0.93, 0.93, 0.93), 0.4), Vector3(0, 0.5, 0))
		var spin := hub.create_tween().set_loops()
		spin.tween_property(hub, "rotation:z", TAU, 2.0).as_relative()
	chevrons(root, level, Vector3(2.3, 0, 0.4))
	return 1.8


## Coin silo: taller, then doubled. Lv1 a short silo; Lv2 a ladder; Lv3 tall with a second gold
## band; Lv4 a coin chute; Lv5 twin silos with a bridge.
static func _storage(root: Node3D, level: int) -> float:
	var shell := MeshKit.mat(Color(0.87, 0.89, 0.91), 0.35, 0.5)
	var gold := MeshKit.mat(Color(0.95, 0.75, 0.2), 0.3, 0.8)
	var count := 2 if level >= 5 else 1
	var h: float = [1.9, 2.3, 3.0, 3.4, 3.4][clampi(level, 1, 5) - 1]
	for i in count:
		var x := 0.0 if count == 1 else (1.2 if i else -1.2)
		var r := 1.05 if count == 2 else 1.5
		MeshKit.add(root, MeshKit.cyl(r, r, h, 24), shell, Vector3(x, h / 2.0 + 0.1, 0))
		MeshKit.add(root, MeshKit.cyl(r * 1.03, r * 1.03, 0.28, 24), gold, Vector3(x, h * 0.7, 0))
		if level >= 3:
			MeshKit.add(root, MeshKit.cyl(r * 1.03, r * 1.03, 0.16, 24), gold, Vector3(x, h * 0.35, 0))
		MeshKit.add(root, MeshKit.sphere(r, 20), shell, Vector3(x, h + 0.1, 0)).scale = Vector3(1, 0.5, 1)
		MeshKit.add(root, MeshKit.cyl(0.35, 0.35, 0.12, 16), gold, Vector3(x, h + 0.1 + r * 0.5, 0))
	if level >= 2:
		MeshKit.add(root, MeshKit.box(Vector3(0.28, h, 0.05)), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3((-1.2 if count == 2 else 0.0) + 1.0, h / 2.0 + 0.1, 1.0)).rotation.y = -0.8
	if level >= 4:
		MeshKit.add(root, MeshKit.box(Vector3(0.5, 0.3, 1.8)), gold, Vector3(1.9, 0.6, 1.4)).rotation.x = 0.4
	if level >= 5:
		MeshKit.add(root, MeshKit.box(Vector3(1.4, 0.2, 0.4)), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3(0, h - 0.2, 0))
	chevrons(root, level, Vector3(2.3, 0, -1.8))
	return h + 1.2


## Drone hangar: an arched shed with a landing pad. Lv1 small; Lv2 a windsock; Lv3 longer, with
## an H pad; Lv4 lights round the pad; Lv5 wider, an antenna and a drone parked on the pad.
static func _hangar(root: Node3D, level: int) -> float:
	var w: float = [3.2, 3.5, 3.9, 4.2, 4.8][clampi(level, 1, 5) - 1]
	var d := 3.2 if level >= 3 else 2.6
	MeshKit.add(root, MeshKit.box(Vector3(w, 1.4, d)), MeshKit.mat(Color(0.78, 0.8, 0.82), 0.5, 0.4), Vector3(0, 0.7, -0.6))
	var roof := MeshKit.add(root, MeshKit.cyl(w / 2.0, w / 2.0, d, 16), MeshKit.mat(Color(0.35, 0.45, 0.55), 0.4, 0.5), Vector3(0, 1.4, -0.6))
	roof.rotation.x = PI / 2.0
	roof.scale = Vector3(1, 1, 0.42)
	MeshKit.add(root, MeshKit.box(Vector3(w * 0.6, 1.1, 0.05)), MeshKit.mat(Color(0.12, 0.13, 0.15), 0.6), Vector3(0, 0.55, d / 2.0 - 0.58))
	if level >= 2:
		MeshKit.add(root, MeshKit.cyl(0.03, 0.03, 2.0, 6), MeshKit.mat(Color(0.75, 0.75, 0.77), 0.4, 0.6), Vector3(-2.2, 1.0, 2.2))
		MeshKit.add(root, MeshKit.cyl(0.1, 0.17, 0.6, 10), MeshKit.mat(Color(1.0, 0.48, 0.16), 0.6), Vector3(-2.2, 1.9, 2.5)).rotation.x = PI / 2.0
	if level >= 3:
		MeshKit.add(root, MeshKit.cyl(0.9, 0.9, 0.04, 24), MeshKit.mat(Color(0.23, 0.24, 0.25), 0.7), Vector3(1.6, 0.1, 1.8))
		var yellow := MeshKit.mat(Color(0.95, 0.76, 0.2), 0.6)
		MeshKit.add(root, MeshKit.box(Vector3(0.12, 0.02, 0.9)), yellow, Vector3(1.4, 0.13, 1.8))
		MeshKit.add(root, MeshKit.box(Vector3(0.12, 0.02, 0.9)), yellow, Vector3(1.8, 0.13, 1.8))
		MeshKit.add(root, MeshKit.box(Vector3(0.4, 0.02, 0.12)), yellow, Vector3(1.6, 0.13, 1.8))
	if level >= 4:
		for k in 6:
			MeshKit.add(root, MeshKit.sphere(0.07, 6), MeshKit.glow(Color(0.5, 0.9, 1.0) if k % 2 else Color(1, 1, 1)), Vector3(1.6 + cos(k) * 0.95, 0.14, 1.8 + sin(k) * 0.95))
	if level >= 5:
		MeshKit.add(root, MeshKit.cyl(0.04, 0.04, 1.5, 6), MeshKit.mat(UnitModels.METAL, 0.5, 0.6), Vector3(-w / 2.0 + 0.4, 2.2, -0.6))
		MeshKit.add(root, MeshKit.box(Vector3(0.5, 0.15, 0.5)), MeshKit.mat(Color(0.93, 0.93, 0.93), 0.4), Vector3(1.6, 0.4, 1.8))
	chevrons(root, level, Vector3(-2.3, 0, 1.0))
	return 2.4


## Fuel pump (approved sketch): a pumpjack whose head nods. Lv1 one pumpjack; Lv2 a fence of
## barrels; Lv3 bigger, with a pipe to a collection drum; Lv4 a second drum; Lv5 two pumpjacks.
static func _pump(root: Node3D, level: int) -> float:
	var metal := MeshKit.mat(UnitModels.METAL, 0.6, 0.4)
	var fuel := MeshKit.mat(FUEL, 0.5, 0.2)
	var count := 2 if level >= 5 else 1
	var size := 1.25 if level >= 3 else 1.0
	for i in count:
		var jack := Node3D.new()
		jack.position = Vector3(0, 0, 0) if count == 1 else Vector3(1.2 if i else -1.2, 0, 0.8 if i else -0.8)
		jack.scale = Vector3.ONE * size * (0.8 if count == 2 else 1.0)
		root.add_child(jack)
		MeshKit.add(jack, MeshKit.box(Vector3(3.0, 0.25, 1.4)), metal, Vector3(0, 0.12, 0))
		for k in [-1.0, 1.0]:
			MeshKit.add(jack, MeshKit.box(Vector3(0.12, 1.9, 0.12)), metal, Vector3(0, 1.0, k * 0.35)).rotation.x = -k * 0.18
		var beam := Node3D.new()
		beam.position = Vector3(0, 1.9, 0)
		jack.add_child(beam)
		MeshKit.add(beam, MeshKit.box(Vector3(2.8, 0.28, 0.32)), fuel)
		MeshKit.add(beam, MeshKit.box(Vector3(0.5, 0.7, 0.4)), fuel, Vector3(-1.45, -0.3, 0))
		MeshKit.add(jack, MeshKit.box(Vector3(0.6, 0.7, 0.6)), MeshKit.mat(Color(0.43, 0.43, 0.4), 0.7), Vector3(1.1, 0.45, 0))
		_loop_rotate(beam, "rotation:z", 0.28, 1.6 + i * 0.3)
	if level >= 2:
		for k in 3:
			MeshKit.add(root, MeshKit.cyl(0.25, 0.25, 0.7, 12), MeshKit.mat(Color(0.3, 0.32, 0.3), 0.6, 0.3), Vector3(-2.0 + k * 0.55, 0.35, -2.0))
	if level >= 3:
		MeshKit.add(root, MeshKit.cyl(0.12, 0.12, 4.5, 10), MeshKit.mat(Color(0.54, 0.54, 0.5), 0.5, 0.4), Vector3(0, 0.2, 2.2)).rotation.z = PI / 2.0
		MeshKit.add(root, MeshKit.cyl(0.45, 0.45, 0.9, 16), fuel, Vector3(2.1, 0.45, 2.2))
	if level >= 4:
		MeshKit.add(root, MeshKit.cyl(0.45, 0.45, 0.9, 16), fuel, Vector3(-2.1, 0.45, 2.2))
	chevrons(root, level, Vector3(2.3, 0, -2.3))
	return 2.6 * size


## Fuel tank (approved sketch): white tanks with a fuel-pink band. Lv1 a low tank; Lv2 a valve
## wheel; Lv3 a tall tank with a ladder; Lv4 a second band; Lv5 two tanks joined by a catwalk.
static func _tank(root: Node3D, level: int) -> float:
	var shell := MeshKit.mat(Color(0.89, 0.88, 0.85), 0.45, 0.3)
	var band := MeshKit.mat(FUEL, 0.5, 0.2)
	var metal := MeshKit.mat(UnitModels.METAL, 0.6, 0.4)
	var count := 2 if level >= 5 else 1
	var h := 2.4 if level >= 3 else 1.6
	for i in count:
		var x := 0.0 if count == 1 else (1.3 if i else -1.3)
		var r := 1.15 if count == 2 else 1.5
		MeshKit.add(root, MeshKit.cyl(r, r, h, 24), shell, Vector3(x, 0.3 + h / 2.0, 0))
		MeshKit.add(root, MeshKit.cyl(r * 1.02, r * 1.02, 0.25, 24), band, Vector3(x, 0.3 + h * 0.65, 0))
		if level >= 4:
			MeshKit.add(root, MeshKit.cyl(r * 1.02, r * 1.02, 0.12, 24), band, Vector3(x, 0.3 + h * 0.3, 0))
		MeshKit.add(root, MeshKit.sphere(r, 20), shell, Vector3(x, 0.3 + h, 0)).scale.y = 0.25
		for k in 4:
			var a := k / 4.0 * TAU + 0.6
			MeshKit.add(root, MeshKit.box(Vector3(0.16, 0.35, 0.16)), metal, Vector3(x + cos(a) * r * 0.8, 0.18, sin(a) * r * 0.8))
		if level >= 3:
			MeshKit.add(root, MeshKit.box(Vector3(0.3, h, 0.05)), metal, Vector3(x + r * 0.7, 0.3 + h / 2.0, r * 0.72)).rotation.y = -0.8
	if level >= 2:
		MeshKit.add(root, MeshKit.cyl(0.25, 0.25, 0.06, 12), MeshKit.mat(Color(0.8, 0.2, 0.2), 0.5), Vector3(0.0 if count == 2 else 1.55, 0.6, 1.3)).rotation.x = PI / 2.0
	if level >= 5:
		MeshKit.add(root, MeshKit.box(Vector3(1.2, 0.08, 0.6)), metal, Vector3(0, h + 0.35, 0))
	chevrons(root, level, Vector3(2.3, 0, -2.3))
	return h + 0.8


## Training camp (approved sketch): a sandy yard and a flag. Lv1 a shed and a pull-up bar;
## Lv2 a sign board; Lv3 an obstacle course (wall, tires, rope frame); Lv4 a bench of weights;
## Lv5 a brick barracks and a watchtower.
static func _camp(root: Node3D, level: int) -> float:
	var wood := MeshKit.mat(WOOD, 0.9)
	MeshKit.add(root, MeshKit.box(Vector3(5.2, 0.1, 5.2)), MeshKit.mat(Color(0.79, 0.73, 0.56), 0.95), Vector3(0, 0.05, 0))
	MeshKit.add(root, MeshKit.cyl(0.04, 0.04, 3.2, 6), MeshKit.mat(Color(0.75, 0.75, 0.77), 0.4, 0.6), Vector3(1.9, 1.6, -1.9))
	var flag := Node3D.new()
	flag.position = Vector3(1.9, 2.9, -1.9)
	root.add_child(flag)
	MeshKit.add(flag, MeshKit.box(Vector3(0.02, 0.45, 0.8)), MeshKit.mat(UnitModels.BLUE, 0.6), Vector3(0, 0, 0.42))
	MeshKit.add(flag, MeshKit.box(Vector3(0.021, 0.16, 0.8)), MeshKit.mat(UnitModels.WHITE, 0.6), Vector3(0, 0, 0.42))
	_loop_rotate(flag, "rotation:y", 0.3, 1.3)
	if level < 5:
		MeshKit.add(root, MeshKit.box(Vector3(1.8, 1.1, 1.3)), MeshKit.mat(UnitModels.OLIVE, 0.8), Vector3(-1.3, 0.6, -1.5))
		MeshKit.add(root, MeshKit.box(Vector3(1.9, 0.1, 1.4)), MeshKit.mat(UnitModels.OLIVE_DARK, 0.8), Vector3(-1.3, 1.2, -1.5))
	else:
		MeshKit.add(root, MeshKit.box(Vector3(2.6, 1.8, 1.6)), MeshKit.mat(Color(0.73, 0.64, 0.48), 0.85), Vector3(-1.0, 0.95, -1.6))
		MeshKit.add(root, MeshKit.box(Vector3(2.7, 0.15, 1.7)), MeshKit.mat(Color(0.48, 0.29, 0.2), 0.8), Vector3(-1.0, 1.9, -1.6))
		for i in 4:
			MeshKit.add(root, MeshKit.box(Vector3(0.35, 0.4, 0.03)), MeshKit.mat(Color(0.19, 0.22, 0.25), 0.3, 0.4), Vector3(-2.0 + i * 0.65, 1.1, -0.79))
		var tower := Node3D.new()
		tower.position = Vector3(2.0, 0, 1.8)
		root.add_child(tower)
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				MeshKit.add(tower, MeshKit.box(Vector3(0.1, 2.6, 0.1)), wood, Vector3(a * 0.4, 1.3, b * 0.4))
		MeshKit.add(tower, MeshKit.box(Vector3(1.1, 0.1, 1.1)), wood, Vector3(0, 2.6, 0))
		MeshKit.add(tower, MeshKit.cyl(0.0, 0.8, 0.6, 4), MeshKit.mat(UnitModels.OLIVE_DARK, 0.8), Vector3(0, 3.2, 0)).rotation.y = PI / 4.0
	var posts := 3 if level >= 3 else 2
	for i in posts:
		MeshKit.add(root, MeshKit.box(Vector3(0.12, 0.8, 0.12)), wood, Vector3(-0.2 + i * 0.6, 0.4, 1.4))
	MeshKit.add(root, MeshKit.box(Vector3(0.6 * (posts - 1) + 0.12, 0.08, 0.08)), wood, Vector3(-0.2 + 0.3 * (posts - 1), 0.8, 1.4))
	if level >= 2:
		MeshKit.add(root, MeshKit.box(Vector3(0.9, 0.55, 0.05)), MeshKit.mat(Color(0.2, 0.24, 0.18), 0.8), Vector3(0.6, 0.8, -2.3))
	if level >= 3:
		MeshKit.add(root, MeshKit.box(Vector3(1.6, 0.9, 0.2)), wood, Vector3(-1.6, 0.45, 0.6))
		for i in 4:
			var tire := MeshKit.add(root, _torus(0.28, 0.1), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.9), Vector3(0.8 + (i % 2) * 0.6, 0.1, -0.2 + int(i / 2.0) * 0.6))
			tire.rotation.x = PI / 2.0
	if level >= 4:
		MeshKit.add(root, MeshKit.box(Vector3(1.0, 0.3, 0.35)), wood, Vector3(-1.8, 0.15, 2.0))
		for k in [-1.0, 1.0]:
			MeshKit.add(root, MeshKit.cyl(0.18, 0.18, 0.08, 12), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3(-1.8 + k * 0.45, 0.45, 2.0)).rotation.z = PI / 2.0
	chevrons(root, level, Vector3(2.3, 0, 0.6))
	return 3.4


## Quarters (approved sketch): Lv1 two tents; Lv2 a campfire ring; Lv3 four tents and a crate;
## Lv4 a water tank; Lv5 two prefab barracks with windows.
static func _quarters(root: Node3D, level: int) -> float:
	MeshKit.add(root, MeshKit.box(Vector3(5.2, 0.1, 5.2)), MeshKit.mat(Color(0.56, 0.6, 0.46), 0.9), Vector3(0, 0.05, 0))
	if level < 5:
		var tents := 4 if level >= 3 else 2
		for i in tents:
			var x := -1.2 + (i % 2) * 2.4
			var z := -1.1 + int(i / 2.0) * 2.2
			var tent := MeshKit.add(root, MeshKit.cyl(0.0, 1.1, 1.3, 4), MeshKit.mat(UnitModels.OLIVE, 0.9), Vector3(x, 0.65, z))
			tent.rotation.y = PI / 4.0
			tent.scale.z = 0.75
			MeshKit.add(root, MeshKit.box(Vector3(0.4, 0.5, 0.02)), MeshKit.mat(Color(0.13, 0.15, 0.1), 0.9), Vector3(x, 0.3, z + 0.8))
		if level >= 3:
			crate(root, 0.0, 0.0, 0.8)
	else:
		for i in 2:
			var z := -1.2 + i * 2.4
			MeshKit.add(root, MeshKit.box(Vector3(4.2, 1.3, 1.6)), MeshKit.mat(Color(0.84, 0.81, 0.74), 0.85), Vector3(0, 0.7, z))
			MeshKit.add(root, MeshKit.box(Vector3(4.3, 0.12, 1.7)), MeshKit.mat(UnitModels.OLIVE_DARK, 0.8), Vector3(0, 1.4, z))
			for k in 4:
				MeshKit.add(root, MeshKit.box(Vector3(0.45, 0.35, 0.03)), MeshKit.mat(Color(0.19, 0.22, 0.25), 0.3, 0.4), Vector3(-1.5 + k, 0.85, z + 0.81))
			MeshKit.add(root, MeshKit.box(Vector3(0.5, 0.9, 0.03)), MeshKit.mat(UnitModels.OLIVE, 0.7), Vector3(1.85, 0.5, z + 0.81))
	if level >= 2:
		for k in 6:
			var a := k / 6.0 * TAU
			MeshKit.add(root, MeshKit.sphere(0.12, 6), MeshKit.mat(Color(0.5, 0.5, 0.48), 0.9), Vector3(2.0 + cos(a) * 0.35, 0.12, 2.0 + sin(a) * 0.35))
		MeshKit.add(root, MeshKit.sphere(0.15, 8), MeshKit.glow(Color(1.0, 0.55, 0.15), 0.9), Vector3(2.0, 0.2, 2.0))
	if level >= 4:
		MeshKit.add(root, MeshKit.cyl(0.45, 0.45, 1.2, 16), MeshKit.mat(Color(0.3, 0.45, 0.6), 0.5, 0.2), Vector3(-2.1, 0.7, 2.0))
	chevrons(root, level, Vector3(2.3, 0, -2.3))
	return 1.8


## Garage (approved sketch): a workshop in Sinai grey with roll-up doors. Lv1 small; Lv2 a tool
## rack; Lv3 bigger, with a yellow crane whose hook goes up and down; Lv4 a fuel cart; Lv5 a
## hangar with two doors and tank parts in the yard.
static func _garage(root: Node3D, level: int) -> float:
	MeshKit.add(root, MeshKit.box(Vector3(5.2, 0.1, 5.2)), MeshKit.mat(Color(0.5, 0.5, 0.47), 0.9), Vector3(0, 0.05, 0))
	var w := 4.6 if level >= 5 else (3.8 if level >= 3 else 3.0)
	var h := 2.6 if level >= 5 else (2.1 if level >= 3 else 1.7)
	MeshKit.add(root, MeshKit.box(Vector3(w, h, 2.8)), MeshKit.mat(UnitModels.SINAI_DARK, 0.8), Vector3(0, h / 2.0, -0.6))
	var roof := MeshKit.add(root, MeshKit.cyl(w / 2.0, w / 2.0, 2.9, 16), MeshKit.mat(Color(0.37, 0.42, 0.35), 0.7, 0.2), Vector3(0, h, -0.6))
	roof.rotation.x = PI / 2.0
	roof.scale = Vector3(1, 1, 0.35)
	var doors := 2 if level >= 5 else 1
	for i in doors:
		var x := 0.0 if doors == 1 else (1.1 if i else -1.1)
		MeshKit.add(root, MeshKit.box(Vector3(1.7, h * 0.8, 0.05)), MeshKit.mat(Color(0.23, 0.24, 0.22), 0.6, 0.4), Vector3(x, h * 0.4, 0.81))
		for k in 5:
			MeshKit.add(root, MeshKit.box(Vector3(1.7, 0.03, 0.07)), MeshKit.mat(Color(0.31, 0.33, 0.3), 0.6, 0.4), Vector3(x, 0.2 + k * h * 0.15, 0.84))
	if level >= 2:
		MeshKit.add(root, MeshKit.box(Vector3(0.9, 0.9, 0.12)), MeshKit.mat(Color(0.6, 0.18, 0.15), 0.6), Vector3(-w / 2.0 - 0.1, 0.5, 0.2)).rotation.y = PI / 2.0
	if level >= 3:
		var crane := Node3D.new()
		crane.position = Vector3(w / 2.0 + 0.3, 0, 1.4)
		root.add_child(crane)
		var yellow := MeshKit.mat(Color(0.88, 0.64, 0.23), 0.6, 0.2)
		MeshKit.add(crane, MeshKit.box(Vector3(0.15, 2.6, 0.15)), yellow, Vector3(0, 1.3, 0))
		MeshKit.add(crane, MeshKit.box(Vector3(1.8, 0.15, 0.15)), yellow, Vector3(-0.8, 2.6, 0))
		var hook := MeshKit.add(crane, MeshKit.box(Vector3(0.06, 0.9, 0.06)), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3(-1.5, 2.1, 0))
		_loop_rotate(hook, "position:y", 0.45, 2.4)
	if level >= 4:
		MeshKit.add(root, MeshKit.cyl(0.35, 0.35, 0.9, 12), MeshKit.mat(FUEL, 0.5, 0.2), Vector3(-2.2, 0.55, 2.2)).rotation.z = PI / 2.0
	if level >= 5:
		MeshKit.add(root, MeshKit.box(Vector3(1.2, 0.5, 0.9)), MeshKit.mat(UnitModels.SINAI, 0.8), Vector3(-1.4, 0.3, 1.8))
		MeshKit.add(root, MeshKit.box(Vector3(0.9, 0.35, 0.7)), MeshKit.mat(UnitModels.SINAI, 0.8), Vector3(-1.4, 0.7, 1.75))
	crate(root, 1.9, 2.0, 0.8)
	chevrons(root, level, Vector3(-2.3, 0, 2.3))
	return h + 0.9


## Support Base (approved sketch): a small strip with a windsock and a flare rack. Lv2 fuel
## drums; Lv3 a spinning radar and a parked jet; Lv4 a second flare rack; Lv5 a control tower
## and a concrete shelter over the jet.
static func _support(root: Node3D, level: int) -> float:
	MeshKit.add(root, MeshKit.box(Vector3(5.2, 0.08, 5.2)), MeshKit.mat(Color(0.25, 0.26, 0.26), 0.9), Vector3(0, 0.04, 0))
	for i in 5:
		MeshKit.add(root, MeshKit.box(Vector3(0.5, 0.02, 0.12)), MeshKit.mat(Color(0.95, 0.76, 0.2), 0.6), Vector3(-2.0 + i * 1.0, 0.09, 1.9))
	var sinai := MeshKit.mat(UnitModels.SINAI, 0.8)
	if level < 5:
		MeshKit.add(root, MeshKit.box(Vector3(1.4, 1.1, 1.2)), sinai, Vector3(-1.7, 0.6, -1.8))
		MeshKit.add(root, MeshKit.box(Vector3(1.5, 0.12, 1.3)), MeshKit.mat(RUST, 0.6), Vector3(-1.7, 1.2, -1.8))
	else:
		MeshKit.add(root, MeshKit.box(Vector3(1.2, 2.6, 1.2)), sinai, Vector3(-2.0, 1.3, -2.0))
		MeshKit.add(root, MeshKit.box(Vector3(1.5, 0.7, 1.5)), MeshKit.mat(Color(0.19, 0.22, 0.25), 0.3, 0.4), Vector3(-2.0, 2.9, -2.0))
		MeshKit.add(root, MeshKit.box(Vector3(1.6, 0.1, 1.6)), MeshKit.mat(RUST, 0.6), Vector3(-2.0, 3.3, -2.0))
	MeshKit.add(root, MeshKit.cyl(0.03, 0.03, 2.2, 6), MeshKit.mat(Color(0.75, 0.75, 0.77), 0.4, 0.6), Vector3(2.3, 1.1, -2.2))
	var sock := MeshKit.add(root, MeshKit.cyl(0.12, 0.2, 0.8, 10), MeshKit.mat(Color(1.0, 0.48, 0.16), 0.6), Vector3(2.3, 2.1, -1.8))
	sock.rotation.x = PI / 2.0
	for r in (2 if level >= 4 else 1):
		for k in 3:
			MeshKit.add(root, MeshKit.cyl(0.08, 0.08, 0.8, 8), MeshKit.mat(UnitModels.OLIVE_DARK, 0.6, 0.3), Vector3(1.4 + r * 0.7, 0.45, 0.2 + k * 0.25)).rotation.z = -0.7
		MeshKit.add(root, MeshKit.box(Vector3(0.7, 0.25, 0.9)), MeshKit.mat(UnitModels.OLIVE, 0.7), Vector3(1.6 + r * 0.7, 0.15, 0.45))
	if level >= 2:
		for k in 3:
			MeshKit.add(root, MeshKit.cyl(0.22, 0.22, 0.6, 10), MeshKit.mat(FUEL, 0.5, 0.2), Vector3(-2.2 + k * 0.5, 0.3, 2.2))
	if level >= 3:
		MeshKit.add(root, MeshKit.cyl(0.05, 0.05, 2.0, 6), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3(2.3, 1.0, 1.9))
		var radar := Node3D.new()
		radar.position = Vector3(2.3, 2.1, 1.9)
		root.add_child(radar)
		MeshKit.add(radar, MeshKit.box(Vector3(1.0, 0.4, 0.06)), MeshKit.mat(Color(0.85, 0.84, 0.8), 0.5, 0.3)).rotation.x = -0.3
		var spin := radar.create_tween().set_loops()
		spin.tween_property(radar, "rotation:y", TAU, 3.0).as_relative()
		var jet := Node3D.new()
		jet.position = Vector3(0.3, 0.45, -0.4 if level < 5 else 0.9)
		jet.rotation.y = PI * 0.15 if level < 5 else 0.0
		jet.scale = Vector3.ONE * 0.42
		root.add_child(jet)
		UnitModels.aircraft(jet, 3)
	if level >= 5:
		var shelter := MeshKit.add(root, MeshKit.cyl(1.7, 1.7, 3.4, 20), MeshKit.surface("concrete", CONCRETE, 0.9), Vector3(0.4, 0, -0.6))
		shelter.rotation.x = PI / 2.0
		shelter.scale = Vector3(1, 1, 0.9)
	chevrons(root, level, Vector3(2.3, 0, 2.6))
	return 3.4 if level >= 5 else 2.4


## Sways a property back and forth around its current value, forever (flags, pumpjacks, hooks).
static func _loop_rotate(node: Node3D, property: String, amount: float, period: float) -> void:
	var start: float = node.get_indexed(property)
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, property, start + amount, period / 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, property, start - amount, period).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, property, start, period / 2.0).set_trans(Tween.TRANS_SINE)


static func _torus(radius: float, thickness: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness
	t.outer_radius = radius + thickness
	t.rings = 16
	t.ring_segments = 8
	return t


# ---------------------------------------------------------------- shared parts

const BAG := Color(0.72, 0.65, 0.48)
const CONCRETE := Color(0.65, 0.64, 0.6)
const RUST := Color(0.75, 0.38, 0.23)
const WOOD := Color(0.48, 0.35, 0.22)


## A ring of sandbags, `rows` high.
static func sandbags(parent: Node3D, r: float, rows: int) -> void:
	var transforms := []
	for row in rows:
		var n := roundi(r * 5.2)
		for i in n:
			var a := (i + (row % 2) * 0.5) / n * TAU
			var b := Basis(Vector3.UP, -a).scaled(Vector3(1.25, 0.55, 0.8))
			transforms.append(Transform3D(b, Vector3(cos(a) * r, 0.2 + row * 0.3, sin(a) * r)))
	MeshKit.multi(parent, MeshKit.sphere(0.32, 8), MeshKit.surface("canvas", BAG, 0.95), transforms)


## An olive ammo crate with a yellow band.
static func crate(parent: Node3D, x: float, z: float, s: float = 1.0) -> void:
	MeshKit.add(parent, MeshKit.box(Vector3(0.7, 0.5, 0.5) * s), MeshKit.mat(UnitModels.OLIVE_DARK, 0.8), Vector3(x, 0.25 * s, z))
	MeshKit.add(parent, MeshKit.box(Vector3(0.72, 0.06, 0.52) * s), MeshKit.mat(Color(0.85, 0.76, 0.48), 0.6), Vector3(x, 0.35 * s, z))


## A camouflage net on four poles.
static func camo_net(parent: Node3D, w: float, d: float, y: float) -> void:
	var net := PlaneMesh.new()
	net.size = Vector2(w, d)
	net.subdivide_width = 6
	net.subdivide_depth = 6
	MeshKit.add(parent, net, MeshKit.surface("net", Color(0.33, 0.38, 0.23), 1.0), Vector3(0, y, 0))
	for i in 4:
		MeshKit.add(parent, MeshKit.cyl(0.05, 0.05, y, 6), MeshKit.mat(WOOD, 0.9), Vector3((-1 if i < 2 else 1) * w * 0.45, y / 2.0, (-1 if i % 2 else 1) * d * 0.45))


## A small plate on the pad with one gold chevron per level, so every level looks different.
static func chevrons(parent: Node3D, level: int, pos: Vector3) -> void:
	MeshKit.add(parent, MeshKit.box(Vector3(0.5, 0.06, 0.2 + level * 0.14)), MeshKit.mat(UnitModels.OLIVE_DARK, 0.8), pos + Vector3(0, 0.15, -level * 0.07))
	for i in level:
		var c := Node3D.new()
		c.position = pos + Vector3(0, 0.2, -i * 0.14)
		parent.add_child(c)
		for side in [-1.0, 1.0]:
			var bar := MeshKit.add(c, MeshKit.box(Vector3(0.24, 0.04, 0.06)), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.3, 0.8), Vector3(side * 0.09, 0, 0))
			bar.rotation.y = side * 0.6


# ---------------------------------------------------------------- walls

## Model units per meter for walls (the sketch's wall is drawn 1.4 times smaller).
const WALL_SCALE := 1.4


## One wall piece on a path between pads (approved sketch): Lv1 a wooden fence; Lv2 barbed
## wire on top; Lv3 two rows of sandbags; Lv4 three rows with a post and wire; Lv5 tall
## concrete blast panels with a rust band and wire. Built along X, turned for paths along Z.
static func wall(parent: Node3D, edge: Array, level: int) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = Walls.center(edge)
	root.scale = Vector3.ONE * WALL_SCALE
	if int(edge[2]) == 0:
		root.rotation.y = PI / 2.0
	var length := City.SPACING / WALL_SCALE
	var segs := 3
	var seg := length / segs
	var wood := MeshKit.mat(WOOD, 0.9)
	var wire := MeshKit.mat(Color(0.6, 0.6, 0.6), 0.4, 0.7)
	for i in segs:
		var x := (i - (segs - 1) / 2.0) * seg
		if level <= 2:
			for dx in [-seg / 2.0 + 0.07, seg / 2.0 - 0.07]:
				MeshKit.add(root, MeshKit.box(Vector3(0.14, 1.0, 0.14)), wood, Vector3(x + dx, 0.5, 0))
			for h in [0.35, 0.75]:
				MeshKit.add(root, MeshKit.box(Vector3(seg, 0.1, 0.08)), wood, Vector3(x, h, 0))
			for k in 5:
				MeshKit.add(root, MeshKit.box(Vector3(0.12, 0.85, 0.05)), MeshKit.mat(Color(0.54, 0.42, 0.27), 0.9), Vector3(x - seg * 0.38 + k * seg * 0.19, 0.45, 0.06))
			if level == 2:
				_wire_coil(root, wire, x, 1.15, seg)
		elif level <= 4:
			var rows := 2 if level == 3 else 3
			for r in rows:
				for k in 3:
					MeshKit.add(root, MeshKit.box(Vector3(seg / 3.0 - 0.02, 0.28, 0.42)), MeshKit.surface("canvas", BAG, 0.95), Vector3(x - seg / 3.0 + k * seg / 3.0 + (r % 2) * 0.12, 0.15 + r * 0.27, 0))
			if level == 4:
				MeshKit.add(root, MeshKit.box(Vector3(0.08, 1.4, 0.08)), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3(x - seg / 2.0 + 0.05, 0.7, 0))
				_wire_coil(root, wire, x, 1.05, seg)
		else:
			MeshKit.add(root, MeshKit.box(Vector3(seg - 0.06, 0.3, 1.0)), MeshKit.surface("concrete", CONCRETE, 0.9), Vector3(x, 0.15, 0))
			MeshKit.add(root, MeshKit.box(Vector3(seg - 0.06, 1.9, 0.3)), MeshKit.mat(Color(0.72, 0.71, 0.68), 0.85), Vector3(x, 1.25, 0))
			MeshKit.add(root, MeshKit.box(Vector3(seg - 0.06, 0.12, 0.31)), MeshKit.mat(RUST, 0.6), Vector3(x, 1.7, 0))
			_wire_coil(root, wire, x, 2.35, seg)
	return root


## A coil of barbed wire along a wall segment.
static func _wire_coil(parent: Node3D, mat: Material, x: float, y: float, seg: float) -> void:
	var coil := MeshKit.add(parent, _torus(0.18, 0.025), mat, Vector3(x, y, 0))
	coil.rotation.z = PI / 2.0
	coil.scale = Vector3(1, seg / 0.4, 1)
