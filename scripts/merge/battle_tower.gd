class_name BattleTower
extends Defense
## A tower in the defense battle (owner, 16.10.2026: "every level of a weapon must be clearly
## different, and every upgrade path must look different in the battle, like Bloons TD").
## The merge level builds the emplacement and sizes the weapon; the upgrade path swaps the
## weapon itself, in its own color: path A amber, path B steel blue, with a pennant that shows
## the path and one white bar per step.
##
## MG:     1 tripod in sandbags · 2 wooden deck · 3 concrete pillbox · 4 guard tower · 5 bunker turret
##         A rapid fire: twin barrels → cooled barrel + drum → six-barrel rotary gun
##         B armor piercing: long barrel → scope and plates → anti-materiel cannon on a bipod
## Mortar: 1 tube in a pit · 2 sandbag ring · 3 concrete pit, two tubes · 4 heavy mortar on wheels ·
##         5 battery of three tubes with a bunker
##         A wide blast: flared mouths → fat tubes and big shells → one giant striped bombard
##         B long range: longer tubes → rangefinder mast → very long barrels and a spotter drone
## AA:     1 open twin gun in sandbags · 2 shielded twin on concrete · 3 quad turret with a radar ·
##         4 armored turret on a tower · 5 fortress with six barrels
##         A twin missiles: one pod → two pods → a missile rack instead of the guns
##         B radar: dish on the turret → spinning radar mast → big radar dome

const AMBER := Color(0.96, 0.6, 0.14)
const BLUE := Color(0.3, 0.62, 0.92)
const BRASS := Color(0.85, 0.66, 0.3)

var kind := "mg"
var path := ""
var tier := 0
## Turns toward the target (MergeGame._fire reads it).
var _pivot: Node3D

var _olive: Material
var _dark: Material
var _steel: Material
var _concrete: Material
var _wood: Material
var _accent: Material


func _build() -> void:
	kind = String(stats.get("kind", "mg"))
	path = String(stats.get("path", ""))
	tier = int(stats.get("tier", 0)) if path != "" else 0
	_olive = MeshKit.mat(UnitModels.OLIVE, 0.8)
	_dark = MeshKit.mat(UnitModels.OLIVE_DARK, 0.8)
	_steel = MeshKit.mat(Color(0.2, 0.21, 0.22), 0.45, 0.5)
	_concrete = MeshKit.mat(StructureModels.CONCRETE, 0.9)
	_wood = MeshKit.mat(StructureModels.WOOD, 0.9)
	_accent = MeshKit.mat(AMBER if path == "a" else BLUE, 0.45, 0.2)
	match kind:
		"mortar":
			_mortar()
		"aa":
			_aa()
		_:
			_mg()
	if tier > 0:
		_pennant()


func _head_height() -> float:
	return _pivot.position.y + 0.5


# ---------------------------------------------------------------- parts

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	return MeshKit.add(parent, MeshKit.box(size), m, pos)


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, seg := 14, top := -1.0) -> MeshInstance3D:
	return MeshKit.add(parent, MeshKit.cyl(r if top < 0.0 else top, r, h, seg), m, pos)


## A barrel along +Z from `pos`.
func _barrel(parent: Node3D, r: float, length: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var b := MeshKit.add(parent, MeshKit.cyl(r, r, length, 10), m, pos + Vector3(0, 0, length / 2.0))
	b.rotation.x = PI / 2.0
	return b


## A node at `pos` leaning its +Y axis toward +Z by `tilt` radians.
func _lean(parent: Node3D, pos: Vector3, tilt: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.x = tilt
	parent.add_child(n)
	return n


func _spin(node: Node3D, period: float) -> void:
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "rotation:y", node.rotation.y + TAU, period).from(node.rotation.y)


func _sub(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## The path pennant at the back corner: path color, one white bar per step.
func _pennant() -> void:
	var at := Vector3(-1.5, 0, -1.5)
	_cyl(model, 0.04, 2.6, at + Vector3(0, 1.3, 0), _steel, 6)
	_box(model, Vector3(0.05, 0.6, 0.9), at + Vector3(0, 2.3, 0.45), _accent)
	var white := MeshKit.mat(Color(0.96, 0.95, 0.9), 0.6)
	for i in tier:
		_box(model, Vector3(0.07, 0.08, 0.6), at + Vector3(0, 2.45 - i * 0.15, 0.5), white)


func _shell_pile(parent: Node3D, pos: Vector3, n: int, r: float, m: Material) -> void:
	for i in n:
		var p := pos + Vector3((i % 3) * r * 2.2, (i / 3) * r * 1.9, 0)
		var s := _cyl(parent, r, r * 3.0, p + Vector3(0, r, 0), m, 8)
		s.rotation.z = PI / 2.0
		_cyl(parent, r * 0.5, r * 0.8, p + Vector3(r * 1.8, r, 0), m, 8, 0.02).rotation.z = -PI / 2.0


# ---------------------------------------------------------------- machine gun

func _mg() -> void:
	var y := 0.0
	match level:
		1:
			StructureModels.sandbags(model, 1.0, 1)
			var legs := _sub(model, Vector3.ZERO)
			for a in [0.0, 2.1, 4.2]:
				_box(legs, Vector3(0.05, 0.7, 0.05), Vector3(cos(a) * 0.25, 0.32, sin(a) * 0.25), _steel).rotation.z = 0.3
			y = 0.65
		2:
			_box(model, Vector3(2.6, 0.3, 2.6), Vector3(0, 0.15, 0), _wood)
			for i in 5:
				_box(model, Vector3(2.62, 0.04, 0.06), Vector3(0, 0.31, -1.0 + i * 0.5), MeshKit.mat(StructureModels.WOOD.darkened(0.3), 0.9))
			var bags := _sub(model, Vector3(0, 0.3, 0))
			StructureModels.sandbags(bags, 1.35, 2)
			StructureModels.crate(bags, 0.7, -0.75)
			StructureModels.crate(bags, -0.75, -0.65, 0.8)
			_cyl(model, 0.12, 0.6, Vector3(0, 0.6, 0), _steel, 8)
			y = 0.9
		3:
			_cyl(model, 1.45, 0.9, Vector3(0, 0.45, 0), _concrete, 6, 1.3)
			_cyl(model, 1.47, 0.16, Vector3(0, 0.62, 0), _dark, 6)
			_cyl(model, 1.05, 0.08, Vector3(0, 0.94, 0), MeshKit.mat(StructureModels.CONCRETE.darkened(0.25), 0.9), 6)
			StructureModels.sandbags(model, 1.7, 1)
			y = 1.0
		4:
			# A guard tower: four legs, braces, a deck with a sandbag parapet.
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_box(model, Vector3(0.16, 2.0, 0.16), Vector3(sx * 0.95, 1.0, sz * 0.95), _wood)
			for side in 4:
				var brace := _box(model, Vector3(2.4, 0.08, 0.08), Vector3.ZERO, _wood)
				var a := side * PI / 2.0
				brace.position = Vector3(sin(a) * 0.95, 1.0, cos(a) * 0.95)
				brace.rotation = Vector3(0, a + PI / 2.0, 0.7)
			_box(model, Vector3(2.4, 0.18, 2.4), Vector3(0, 2.05, 0), _wood)
			var deck := _sub(model, Vector3(0, 2.0, 0))
			StructureModels.sandbags(deck, 1.05, 1)
			# A ladder up the side.
			for side in [-0.22, 0.22]:
				_box(model, Vector3(0.06, 2.1, 0.06), Vector3(1.25, 1.05, side), _wood)
			for k in 6:
				_box(model, Vector3(0.05, 0.05, 0.5), Vector3(1.25, 0.3 + k * 0.3, 0), _wood)
			y = 2.55
		_:
			# A round concrete bunker with a slit, a domed turret on top, an antenna.
			_cyl(model, 1.6, 1.2, Vector3(0, 0.6, 0), _concrete, 20, 1.45)
			_cyl(model, 1.62, 0.18, Vector3(0, 0.7, 0), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.9), 20)
			_cyl(model, 1.52, 0.12, Vector3(0, 1.0, 0), UnitModels.level_material(5), 20)
			_cyl(model, 0.03, 2.2, Vector3(-1.0, 2.2, 0.6), _steel, 6)
			y = 1.3
	_pivot = _sub(model, Vector3(0, y, 0))
	var s: float = [0.9, 1.0, 1.15, 1.2, 1.35][level - 1]
	if level >= 5:
		var dome := MeshKit.add(_pivot, MeshKit.sphere(0.75, 16), _olive, Vector3(0, 0.05, 0))
		dome.scale = Vector3(1.0, 0.6, 1.0)
	elif level >= 3:
		_box(_pivot, Vector3(1.0, 0.55, 0.07) * s, Vector3(0, 0.25 * s, 0.5 * s), _olive)
	var guns := 2 if level >= 5 else 1
	for i in guns:
		var x := 0.0 if guns == 1 else (i - 0.5) * 0.55
		_mg_gun(_sub(_pivot, Vector3(x, 0.25 * s, 0)), s)


func _mg_gun(g: Node3D, s: float) -> void:
	var gun := MeshKit.mat(Color(0.12, 0.125, 0.13), 0.5, 0.4)
	if path == "a" and tier >= 3:
		# Six-barrel rotary gun with a motor, a glowing muzzle ring and a brass belt.
		_box(g, Vector3(0.36, 0.34, 0.6) * s, Vector3(0, 0, -0.1) * s, _accent)
		_cyl(g, 0.2 * s, 0.3 * s, Vector3(0, 0, 0.3) * s, gun, 12).rotation.x = PI / 2.0
		var drum := _sub(g, Vector3(0, 0, 0.35) * s)
		for k in 6:
			var a := TAU * k / 6.0
			_barrel(drum, 0.035 * s, 1.15 * s, Vector3(cos(a), sin(a), 0) * 0.11 * s, gun)
		_cyl(drum, 0.17 * s, 0.06 * s, Vector3(0, 0, 1.15) * s, MeshKit.glow(AMBER), 12).rotation.x = PI / 2.0
		_cyl(drum, 0.17 * s, 0.06 * s, Vector3(0, 0, 0.6) * s, gun, 12).rotation.x = PI / 2.0
		_cyl(g, 0.28 * s, 0.3 * s, Vector3(0.42, -0.05, -0.1) * s, MeshKit.mat(BRASS, 0.4, 0.6), 14).rotation.z = PI / 2.0
		return
	if path == "b" and tier >= 3:
		# Anti-materiel cannon: a long thick barrel, a big muzzle brake, a bipod, a scope.
		_box(g, Vector3(0.34, 0.32, 0.9) * s, Vector3(0, 0, -0.1) * s, _accent)
		_barrel(g, 0.075 * s, 1.9 * s, Vector3(0, 0.02, 0.35) * s, gun)
		_box(g, Vector3(0.26, 0.16, 0.3) * s, Vector3(0, 0.02, 2.25) * s, gun)
		_barrel(g, 0.07 * s, 0.6 * s, Vector3(0, 0.3, -0.2) * s, gun)
		_cyl(g, 0.075 * s, 0.04 * s, Vector3(0, 0.3, 0.42) * s, MeshKit.glow(BLUE), 10).rotation.x = PI / 2.0
		for side in [-1.0, 1.0]:
			_box(g, Vector3(0.04, 0.6, 0.04) * s, Vector3(side * 0.18, -0.22, 1.3) * s, gun).rotation.z = side * 0.4
		return
	_box(g, Vector3(0.2, 0.22, 0.75) * s, Vector3(0, 0, 0), gun)
	_box(g, Vector3(0.12, 0.16, 0.35) * s, Vector3(0, -0.02, -0.5) * s, MeshKit.mat(StructureModels.WOOD, 0.8))
	var long := 1.0
	if path == "b":
		long = 1.6
	var br := 0.045 * s
	if path == "a" and tier >= 2:
		# Water-cooled barrel jacket and a big drum magazine.
		_barrel(g, 0.1 * s, 0.8 * s, Vector3(0, 0, 0.35) * s, gun)
		for k in 4:
			_cyl(g, 0.12 * s, 0.04 * s, Vector3(0, 0, 0.45 + k * 0.18) * s, _accent, 12).rotation.x = PI / 2.0
		_barrel(g, br, 1.2 * s, Vector3(0, 0, 0.35) * s, gun)
		_cyl(g, 0.24 * s, 0.18 * s, Vector3(0.28, 0, 0.05) * s, _accent, 16).rotation.z = PI / 2.0
	else:
		_barrel(g, br * (1.4 if path == "b" else 1.0), 0.75 * long * s, Vector3(0, 0, 0.35) * s, gun)
	if path == "a" and tier == 1:
		_barrel(g, br, 0.75 * s, Vector3(0.12, 0, 0.35) * s, gun)
		_box(g, Vector3(0.28, 0.26, 0.32) * s, Vector3(0.3, -0.04, 0.0), _accent)
	if path == "b":
		# Muzzle brake and a blue band; then a scope and blue armor plates.
		_box(g, Vector3(0.16, 0.12, 0.2) * s, Vector3(0, 0, 0.35 + 0.75 * long) * s, gun)
		_cyl(g, br * 1.9, 0.12 * s, Vector3(0, 0, 0.5) * s, _accent, 10).rotation.x = PI / 2.0
		if tier >= 2:
			_barrel(g, 0.06 * s, 0.5 * s, Vector3(0, 0.2, -0.2) * s, gun)
			_cyl(g, 0.06 * s, 0.03 * s, Vector3(0, 0.2, 0.31) * s, MeshKit.glow(BLUE), 10).rotation.x = PI / 2.0
			for side in [-1.0, 1.0]:
				_box(g, Vector3(0.06, 0.4, 0.6) * s, Vector3(side * 0.28, 0.05, 0.1) * s, _accent)


# ---------------------------------------------------------------- mortar

func _mortar() -> void:
	var y := 0.05
	match level:
		1:
			_cyl(model, 1.25, 0.06, Vector3(0, 0.03, 0), MeshKit.mat(Color(0.42, 0.34, 0.24), 1.0), 16)
			var arc := _sub(model, Vector3(0, 0, 0))
			StructureModels.sandbags(arc, 1.15, 1)
		2:
			StructureModels.sandbags(model, 1.55, 2)
			_shell_pile(model, Vector3(-0.9, 0.0, -0.9), 4, 0.1, MeshKit.mat(UnitModels.OLIVE_DARK, 0.6))
		3:
			for side in 4:
				var a := side * PI / 2.0
				var w := _box(model, Vector3(3.1, 0.7, 0.28), Vector3(sin(a) * 1.45, 0.35, cos(a) * 1.45), _concrete)
				w.rotation.y = a
			_box(model, Vector3(0.9, 0.5, 0.45), Vector3(-0.85, 0.25, -0.95), _wood)
			_shell_pile(model, Vector3(-1.2, 0.5, -0.95), 4, 0.09, MeshKit.mat(UnitModels.OLIVE_DARK, 0.6))
		4:
			for side in 4:
				var a := side * PI / 2.0
				var w := _box(model, Vector3(3.2, 0.55, 0.3), Vector3(sin(a) * 1.5, 0.27, cos(a) * 1.5), _concrete)
				w.rotation.y = a
			var bags := _sub(model, Vector3(0, 0.45, 0))
			StructureModels.sandbags(bags, 1.65, 1)
			# A small ammo bunker in the back corner.
			_box(model, Vector3(0.9, 0.7, 0.9), Vector3(-1.0, 0.35, -1.0), _concrete)
			_box(model, Vector3(1.05, 0.12, 1.05), Vector3(-1.0, 0.76, -1.0), MeshKit.mat(LeoModels.ROOF, 0.7))
			y = 0.1
		_:
			_box(model, Vector3(3.3, 0.45, 3.3), Vector3(0, 0.22, 0), _concrete)
			_box(model, Vector3(3.34, 0.1, 3.34), Vector3(0, 0.25, 0), UnitModels.level_material(5))
			_box(model, Vector3(1.4, 0.9, 0.8), Vector3(0, 0.9, -1.15), _concrete)
			_box(model, Vector3(1.55, 0.12, 0.95), Vector3(0, 1.4, -1.15), MeshKit.mat(LeoModels.ROOF, 0.7))
			_box(model, Vector3(0.4, 0.55, 0.05), Vector3(0, 0.72, -0.73), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.9))
			_cyl(model, 0.03, 1.8, Vector3(0.55, 2.2, -1.25), _steel, 6)
			_cyl(model, 0.07, 0.1, Vector3(0.55, 3.15, -1.25), MeshKit.glow(LeoModels.RED), 8)
			y = 0.45
	_pivot = _sub(model, Vector3(0, y, 0))
	var tubes: int = [1, 1, 2, 1, 3][level - 1]
	var r: float = [0.11, 0.13, 0.14, 0.22, 0.17][level - 1]
	var length: float = [1.0, 1.2, 1.3, 1.7, 1.5][level - 1]
	if level == 4:
		# Wheeled carriage.
		_box(_pivot, Vector3(0.8, 0.25, 1.4), Vector3(0, 0.45, -0.1), _dark)
		for side in [-1.0, 1.0]:
			_cyl(_pivot, 0.42, 0.18, Vector3(side * 0.55, 0.42, -0.1), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.9), 14).rotation.z = PI / 2.0
			_cyl(_pivot, 0.2, 0.2, Vector3(side * 0.55, 0.42, -0.1), _olive, 10).rotation.z = PI / 2.0
	if path == "a" and tier >= 3:
		# One giant bombard with hazard stripes and a huge shell on a cradle.
		var tilt := _lean(_pivot, Vector3(0, 0.3, -0.1), 0.45)
		_cyl(tilt, 0.65, 0.2, Vector3(0, 0.1, 0), _steel, 16)
		_cyl(tilt, 0.48, 1.4, Vector3(0, 0.85, 0), _dark, 16, 0.55)
		for k in 3:
			_cyl(tilt, 0.5 + k * 0.02, 0.12, Vector3(0, 0.55 + k * 0.38, 0), _accent if k % 2 == 0 else MeshKit.mat(Color(0.1, 0.1, 0.1), 0.6), 16)
		_cyl(tilt, 0.4, 0.05, Vector3(0, 1.56, 0), MeshKit.mat(Color(0.05, 0.05, 0.05), 1.0), 16)
		var big := _cyl(_pivot, 0.22, 0.8, Vector3(0.95, 0.35, -0.4), _accent, 12)
		big.rotation.x = PI / 2.0
		_cyl(_pivot, 0.12, 0.3, Vector3(0.95, 0.35, 0.12), MeshKit.mat(Color(0.1, 0.1, 0.1), 0.6), 12, 0.02).rotation.x = PI / 2.0
		_shell_pile(model, Vector3(-1.25, 0.05 + y, 0.95), 5, 0.14, _accent)
		return
	if path == "a":
		r *= 1.5 if tier >= 2 else 1.15
	if path == "b":
		length *= 1.35 if tier < 3 else 1.9
		r *= 0.9 if tier < 3 else 0.75
	var steep := 0.5 if path != "b" else (0.65 if tier >= 3 else 0.55)
	for i in tubes:
		var x := (i - (tubes - 1) / 2.0) * 0.8
		var base_y := 0.55 if level == 4 else 0.0
		_cyl(_pivot, r * 2.6, 0.08, Vector3(x, base_y + 0.04, 0), _steel, 12)
		var t := _lean(_pivot, Vector3(x, base_y + 0.05, -0.1), steep)
		_cyl(t, r, length, Vector3(0, length / 2.0, 0), MeshKit.mat(UnitModels.OLIVE_DARK, 0.6, 0.3), 12, r * 0.92)
		if path == "a":
			# Flared, amber-banded mouth.
			_cyl(t, r * 1.9, 0.3, Vector3(0, length + 0.1, 0), _accent, 12, r * 1.05)
			_cyl(t, r * 1.08, 0.1, Vector3(0, length * 0.6, 0), _accent, 12)
		elif path == "b":
			_cyl(t, r * 1.12, 0.1, Vector3(0, length * 0.75, 0), _accent, 12)
			_cyl(t, r * 1.12, 0.1, Vector3(0, length * 0.45, 0), _accent, 12)
		if level >= 2 and level != 4:
			# Bipod.
			for side in [-1.0, 1.0]:
				var leg := _box(_pivot, Vector3(0.04, 0.75, 0.04), Vector3(x + side * 0.2, base_y + 0.3, 0.42), _steel)
				leg.rotation.z = side * 0.35
	if path == "a" and tier >= 2:
		_shell_pile(model, Vector3(1.0, 0.05 + y, 0.95), 5, 0.13, _accent)
	if path == "b" and tier >= 2:
		# Rangefinder mast: a pole, blue optics, an antenna.
		var at := Vector3(1.2, y, -1.2)
		_cyl(model, 0.05, 2.4, at + Vector3(0, 1.2, 0), _steel, 8)
		_box(model, Vector3(0.8, 0.22, 0.25), at + Vector3(0, 2.45, 0), _dark)
		for side in [-1.0, 1.0]:
			_cyl(model, 0.09, 0.1, at + Vector3(side * 0.32, 2.45, 0.15), MeshKit.glow(BLUE), 10).rotation.x = PI / 2.0
		_cyl(model, 0.015, 1.0, at + Vector3(0.2, 3.0, 0), _steel, 4)
	if path == "b" and tier >= 3:
		# Spotter drone hovering over the pit.
		var drone := _sub(model, Vector3(0.6, 2.8, 0.6))
		_box(drone, Vector3(0.45, 0.14, 0.45), Vector3.ZERO, _dark)
		_cyl(drone, 0.07, 0.06, Vector3(0, -0.1, 0.15), MeshKit.glow(BLUE), 8)
		for k in 4:
			var a := PI / 4.0 + k * PI / 2.0
			_box(drone, Vector3(0.5, 0.04, 0.05), Vector3(cos(a), 0, sin(a)) * 0.25, _steel).rotation.y = -a
			_cyl(drone, 0.17, 0.02, Vector3(cos(a), 0.08, sin(a)) * 0.45 + Vector3(0, 0.08, 0), MeshKit.mat(Color(0.1, 0.1, 0.1), 0.5), 12)
		var tw := drone.create_tween().set_loops()
		tw.tween_property(drone, "position:y", 3.05, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(drone, "position:y", 2.8, 0.8).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- anti-air

func _aa() -> void:
	var y := 0.0
	match level:
		1:
			StructureModels.sandbags(model, 1.2, 1)
			_cyl(model, 0.18, 0.5, Vector3(0, 0.25, 0), _steel, 8)
			y = 0.5
		2:
			_cyl(model, 1.4, 0.45, Vector3(0, 0.22, 0), _concrete, 20, 1.3)
			y = 0.45
		3:
			_cyl(model, 1.55, 0.55, Vector3(0, 0.27, 0), _concrete, 20, 1.4)
			StructureModels.crate(model, 1.3, -1.2)
			StructureModels.sandbags(model, 1.8, 1)
			y = 0.55
		4:
			# A raised concrete gun tower.
			_cyl(model, 1.6, 0.35, Vector3(0, 0.17, 0), _concrete, 20)
			_cyl(model, 1.15, 1.3, Vector3(0, 1.0, 0), _concrete, 16, 1.0)
			_cyl(model, 1.17, 0.12, Vector3(0, 1.5, 0), _dark, 16)
			_box(model, Vector3(0.5, 0.7, 0.05), Vector3(0, 0.6, 1.09), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.9))
			y = 1.65
		_:
			_cyl(model, 1.75, 0.8, Vector3(0, 0.4, 0), _concrete, 6, 1.6)
			_cyl(model, 1.71, 0.12, Vector3(0, 0.35, 0), UnitModels.level_material(5), 6)
			_cyl(model, 1.25, 0.5, Vector3(0, 1.05, 0), _concrete, 20, 1.15)
			y = 1.3
	_pivot = _sub(model, Vector3(0, y, 0))
	var s: float = [0.8, 0.95, 1.05, 1.1, 1.25][level - 1]
	# Turret body: an open mount at Lv1, a shielded box, a round turret, a sloped armored turret.
	match level:
		1:
			_box(_pivot, Vector3(0.6, 0.2, 0.6), Vector3(0, 0.1, 0), _steel)
			_box(_pivot, Vector3(0.3, 0.06, 0.3), Vector3(0, 0.4, -0.45), _dark)
		2:
			_cyl(_pivot, 0.75, 0.25, Vector3(0, 0.12, 0), _olive, 16)
			_box(_pivot, Vector3(1.1, 0.6, 0.08), Vector3(0, 0.55, 0.45), _olive)
		3:
			_cyl(_pivot, 0.85, 0.75, Vector3(0, 0.38, 0), _olive, 16, 0.75)
		_:
			_box(_pivot, Vector3(1.4, 0.8, 1.3) * (s / 1.1), Vector3(0, 0.4, 0), _olive)
			var slope := _box(_pivot, Vector3(1.4, 0.12, 0.8) * (s / 1.1), Vector3(0, 0.62, 0.72) * (s / 1.1), _olive)
			slope.rotation.x = 0.6
	var top: float = [0.25, 0.45, 0.6, 0.6, 0.65][level - 1] * (1.0 if level < 4 else s / 1.1)
	if not (path == "a" and tier >= 3):
		var cradle := _lean(_pivot, Vector3(0, top, 0.2), 0.0)
		cradle.rotation.x = -0.75
		var count: int = [2, 2, 4, 4, 6][level - 1]
		for i in count:
			var row := i / 2 if count > 2 else 0
			var rows := count / 2 if count > 2 else 1
			var x := (-0.17 if i % 2 == 0 else 0.17) * s * (1.0 if count > 2 else 1.4)
			var yy := (row - (rows - 1) / 2.0) * 0.2 * s
			_barrel(cradle, 0.055 * s, 2.0 * s, Vector3(x, yy, 0.2), _steel)
			_cyl(cradle, 0.08 * s, 0.25 * s, Vector3(x, yy, 0.2 + 2.0 * s), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.6), 8).rotation.x = PI / 2.0
	if path == "a":
		if tier >= 3:
			# A missile rack replaces the guns: eight missiles with red tips.
			var rack := _lean(_pivot, Vector3(0, top + 0.3, 0), 0.0)
			rack.rotation.x = -0.6
			_box(rack, Vector3(1.3, 0.75, 1.5) * s, Vector3(0, 0, 0.3), _dark)
			_box(rack, Vector3(1.32, 0.12, 1.52) * s, Vector3(0, 0.2, 0.3), _accent)
			_box(rack, Vector3(1.32, 0.12, 1.52) * s, Vector3(0, -0.2, 0.3), _accent)
			for i in 8:
				var p := Vector3(((i % 4) - 1.5) * 0.3, (0.17 if i < 4 else -0.17), 0) * s
				_barrel(rack, 0.1 * s, 0.6 * s, p + Vector3(0, 0, 0.3 + 0.75 * s), MeshKit.mat(Color(0.92, 0.92, 0.88), 0.5))
				_cyl(rack, 0.1 * s, 0.22 * s, p + Vector3(0, 0, 0.3 + 1.46 * s), MeshKit.mat(LeoModels.RED, 0.5), 10, 0.01).rotation.x = PI / 2.0
		else:
			for side in ([1.0] if tier == 1 else [-1.0, 1.0]):
				_missile_pod(_pivot, Vector3(side * 0.85 * s, top + 0.15, 0.1), s)
	if path == "b":
		# A dish on the turret; then a spinning radar mast; then a big dome.
		var dish := _sub(_pivot, Vector3(0, top + 0.5, -0.45 * s))
		_cyl(dish, 0.04, 0.5, Vector3(0, -0.2, 0), _steel, 6)
		var d := MeshKit.add(dish, MeshKit.cyl(0.45 * s, 0.1, 0.15, 14), _accent, Vector3(0, 0.15, 0))
		d.rotation.x = -0.9
		if tier >= 2:
			var at := Vector3(1.35, 0, -1.35)
			var h := (2.6 if tier == 2 else 1.7) + y
			_cyl(model, 0.07, h, at + Vector3(0, h / 2.0, 0), _steel, 8)
			if tier == 2:
				var bar := _sub(model, at + Vector3(0, h, 0))
				_box(bar, Vector3(1.6, 0.4, 0.1), Vector3(0, 0.2, 0), _accent)
				_cyl(bar, 0.08, 0.1, Vector3(0, 0.5, 0), MeshKit.glow(BLUE), 8)
				_spin(bar, 2.4)
			else:
				_cyl(model, 0.5, 0.4, at + Vector3(0, h + 0.1, 0), _concrete, 14)
				var dome := MeshKit.add(model, MeshKit.sphere(0.8, 18), MeshKit.mat(Color(0.94, 0.94, 0.9), 0.5), at + Vector3(0, h + 0.65, 0))
				dome.scale = Vector3(1.0, 0.85, 1.0)
				_cyl(model, 0.82, 0.1, at + Vector3(0, h + 0.55, 0), MeshKit.glow(BLUE), 20)
				var bar2 := _sub(model, at + Vector3(0, h + 1.45, 0))
				_box(bar2, Vector3(1.2, 0.08, 0.08), Vector3.ZERO, _accent)
				_spin(bar2, 1.6)


func _missile_pod(parent: Node3D, pos: Vector3, s: float) -> void:
	var pod := _lean(parent, pos, 0.0)
	pod.rotation.x = -0.5
	_box(pod, Vector3(0.45, 0.45, 1.0) * s, Vector3.ZERO, _dark)
	_box(pod, Vector3(0.47, 0.1, 1.02) * s, Vector3(0, 0.1, 0) * s, _accent)
	for k in 4:
		var p := Vector3((k % 2 - 0.5) * 0.2, (k / 2 - 0.5) * 0.2, 0.5) * s
		_cyl(pod, 0.08 * s, 0.18 * s, p + Vector3(0, 0, 0.08 * s), MeshKit.mat(LeoModels.RED, 0.5), 8, 0.01).rotation.x = PI / 2.0
