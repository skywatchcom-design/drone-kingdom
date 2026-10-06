class_name UnitModels
extends RefCounted
## The approved ground-forces designs (sketch BD7VJUbaPSCevXsmgRoS2o), built from primitives,
## with a distinct look for every level (sketch Th5mNJUuSD5d77XEMeRnqE).
## Each build returns the moving parts GroundUnit animates. Forward is local +Z.
##   soldier:  olive uniform, covered helmet, vest with pouches, backpack, carbine, and a small
##             blue-and-white shoulder patch. Engineers wear a sand-orange vest and carry a shovel.
##   tank:     long low hull and flat wedge turret in Sinai grey, ball-chain curtain at the back,
##             skirts over the tracks, fictional shield emblem.

const OLIVE := Color(0.365, 0.4, 0.251)
const OLIVE_DARK := Color(0.275, 0.302, 0.188)
const SKIN := Color(0.79, 0.6, 0.45)
const SINAI := Color(0.663, 0.643, 0.533)
const SINAI_DARK := Color(0.549, 0.529, 0.424)
const METAL := Color(0.176, 0.188, 0.2)
const BLUE := Color(0.18, 0.44, 0.88)
const WHITE := Color(0.95, 0.95, 0.95)


## Every level is readable from across the base: the unit grows (GroundUnit), its
## silhouette changes, and it wears its level color on the shoulders or hull.
static func build(kind: String, root: Node3D, level: int = 1) -> Dictionary:
	var p: Dictionary
	match kind:
		"armor":
			p = _tank(root)
			_tank_level(root, p, level)
		"engineers":
			p = _soldier(root, Color(0.77, 0.54, 0.17), Color(0.42, 0.35, 0.2), true)
			_engineer_level(root, p, level)
		"robot":
			p = _robot(root, level)
		_:
			p = _soldier(root, Color(0.333, 0.376, 0.235), Color(0.3, 0.325, 0.22), false)
			_infantry_level(root, p, level)
	return p


## Swaps one exact color for another on every mesh under `node` (each mesh has its own material).
static func recolor(node: Node, from: Color, to: Color) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m != null and absf(m.albedo_color.r - from.r) < 0.01 and absf(m.albedo_color.g - from.g) < 0.01 and absf(m.albedo_color.b - from.b) < 0.01:
			var copy := m.duplicate() as StandardMaterial3D
			copy.albedo_color = Color(to, m.albedo_color.a)
			(mi as MeshInstance3D).material_override = copy


static func _shoulder_patches(torso: Node3D, level: int) -> void:
	for sx in [-1.0, 1.0]:
		MeshKit.add(torso, MeshKit.box(Vector3(0.09, 0.04, 0.14)), level_material(level), Vector3(sx * 0.21, 0.42, 0))


## Infantry by level: Lv2 level patches; Lv3 a heavy plate vest, shoulder pads, goggles and a
## light machine gun with a drum; Lv4 dark armor and a tall radio antenna; Lv5 full armor, a
## closed helmet with a glowing visor and a multi-barrel gun.
static func _infantry_level(root: Node3D, p: Dictionary, level: int) -> void:
	var torso: Node3D = p["torso"]
	var rifle: Node3D = (p["muzzle"] as Node3D).get_parent()
	var dark := MeshKit.mat(Color(0.17, 0.18, 0.16), 0.6)
	_shoulder_patches(torso, level)
	if level >= 3:
		MeshKit.add(torso, MeshKit.box(Vector3(0.44, 0.33, 0.31)), MeshKit.mat(OLIVE_DARK, 0.8), Vector3(0, 0.24, 0))
		for sx in [-1.0, 1.0]:
			MeshKit.add(torso, MeshKit.box(Vector3(0.15, 0.1, 0.21)), MeshKit.mat(OLIVE_DARK, 0.7), Vector3(sx * 0.26, 0.43, 0))
		MeshKit.add(torso, MeshKit.box(Vector3(0.21, 0.05, 0.06)), dark, Vector3(0, 0.58, 0.12))
		MeshKit.add(rifle, MeshKit.cyl(0.075, 0.075, 0.08, 14), dark, Vector3(0, -0.1, 0.12)).rotation.z = PI / 2.0
		MeshKit.add(rifle, MeshKit.box(Vector3(0.06, 0.07, 0.3)), dark, Vector3(0, 0.0, 0.45))
		(p["muzzle"] as Node3D).position.z = 0.62
	if level >= 4:
		recolor(root, OLIVE, Color(0.25, 0.27, 0.23))
		recolor(root, OLIVE_DARK, Color(0.17, 0.18, 0.16))
		MeshKit.add(torso, MeshKit.cyl(0.01, 0.01, 0.85, 4), dark, Vector3(-0.1, 0.72, -0.22))
	if level >= 5:
		var helm := MeshKit.add(torso, MeshKit.sphere(0.165, 14), MeshKit.mat(Color(0.12, 0.13, 0.14), 0.4, 0.4), Vector3(0, 0.58, 0))
		helm.scale = Vector3(1, 0.95, 1.08)
		var visor := MeshKit.add(torso, MeshKit.box(Vector3(0.21, 0.06, 0.04)), MeshKit.glow(Color(0.37, 0.88, 1.0)), Vector3(0, 0.57, 0.16))
		visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 4:
			var a := i * PI / 2.0
			MeshKit.add(rifle, MeshKit.cyl(0.016, 0.016, 0.42, 6), dark, Vector3(cos(a) * 0.035, sin(a) * 0.035, 0.7)).rotation.x = PI / 2.0
		(p["muzzle"] as Node3D).position.z = 0.9
		MeshKit.add(torso, MeshKit.box(Vector3(0.45, 0.05, 0.32)), level_material(5), Vector3(0, 0.38, 0))


## Engineers by level: Lv2 a tool belt; Lv3 a bulky protective suit and goggles; Lv4 a mine
## detector and a satchel of charges; Lv5 a full bomb suit with an amber visor and a small
## tracked robot at their side.
static func _engineer_level(root: Node3D, p: Dictionary, level: int) -> void:
	var torso: Node3D = p["torso"]
	var dark := MeshKit.mat(Color(0.2, 0.2, 0.18), 0.7)
	_shoulder_patches(torso, level)
	if level >= 2:
		MeshKit.add(torso, MeshKit.box(Vector3(0.42, 0.07, 0.25)), MeshKit.mat(Color(0.25, 0.2, 0.14), 0.8), Vector3(0, 0.02, 0))
		for sx in [-0.14, 0.0, 0.14]:
			MeshKit.add(torso, MeshKit.box(Vector3(0.06, 0.08, 0.05)), dark, Vector3(sx, 0.0, 0.14))
	if level >= 3:
		torso.scale = Vector3(1.2, 1.0, 1.2)
		for hip: Node3D in p["hips"]:
			hip.scale = Vector3(1.25, 1.0, 1.25)
		MeshKit.add(torso, MeshKit.box(Vector3(0.21, 0.05, 0.06)), dark, Vector3(0, 0.58, 0.12))
	if level >= 4:
		var stick := MeshKit.add(torso, MeshKit.cyl(0.012, 0.012, 0.7, 4), dark, Vector3(-0.22, 0.05, 0.25))
		stick.rotation.x = 0.9
		MeshKit.add(torso, MeshKit.cyl(0.1, 0.1, 0.02, 12), MeshKit.mat(Color(0.3, 0.3, 0.3), 0.5), Vector3(-0.22, -0.2, 0.5))
		MeshKit.add(torso, MeshKit.box(Vector3(0.3, 0.22, 0.18)), MeshKit.mat(Color(0.23, 0.23, 0.18), 0.7), Vector3(-0.2, 0.1, -0.24))
	if level >= 5:
		var suit := MeshKit.add(torso, MeshKit.sphere(0.3, 14), MeshKit.mat(Color(0.85, 0.53, 0.17), 0.8), Vector3(0, 0.22, 0))
		suit.scale = Vector3(1, 0.9, 0.85)
		var helm := MeshKit.add(torso, MeshKit.sphere(0.17, 14), MeshKit.mat(Color(0.8, 0.5, 0.16), 0.7), Vector3(0, 0.58, 0))
		helm.scale = Vector3(1, 1, 1.05)
		var visor := MeshKit.add(torso, MeshKit.box(Vector3(0.2, 0.08, 0.04)), MeshKit.glow(Color(1.0, 0.75, 0.29)), Vector3(0, 0.58, 0.16))
		visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bot := Node3D.new()
		bot.position = Vector3(0.55, 0, 0.3)
		root.add_child(bot)
		MeshKit.add(bot, MeshKit.box(Vector3(0.3, 0.1, 0.4)), MeshKit.mat(Color(0.13, 0.13, 0.13), 0.6), Vector3(0, 0.06, 0))
		MeshKit.add(bot, MeshKit.box(Vector3(0.2, 0.12, 0.22)), MeshKit.mat(Color(0.85, 0.53, 0.17), 0.6), Vector3(0, 0.17, 0))
		MeshKit.add(bot, MeshKit.cyl(0.012, 0.012, 0.25, 4), MeshKit.mat(METAL, 0.5, 0.6), Vector3(0, 0.32, 0.05))
		MeshKit.add(torso, MeshKit.box(Vector3(0.45, 0.05, 0.32)), level_material(5), Vector3(0, 0.0, 0))


## The tank by level: Lv2 level-color stripes down the hull and an antenna; Lv3 reactive armor
## tiles, a longer gun with a muzzle brake and a roof machine gun; Lv4 dark camouflage and smoke
## launchers; Lv5 a bigger turret with twin barrels and a glowing active protection system.
static func _tank_level(root: Node3D, p: Dictionary, level: int) -> void:
	var turret: Node3D = p["turret"]
	var gun: Node3D = p["gun"]
	var metal := MeshKit.mat(METAL, 0.6, 0.5)
	var tile := MeshKit.mat(Color(0.6, 0.58, 0.47), 0.8)
	if level >= 2:
		for sx in [-1.0, 1.0]:
			MeshKit.add(root, MeshKit.box(Vector3(0.2, 0.12, 4.3)), level_material(level), Vector3(sx * 1.35, 0.95, 0))
		MeshKit.add(turret, MeshKit.cyl(0.02, 0.02, 1.4, 6), metal, Vector3(0.7, 1.0, -0.9))
	MeshKit.add(turret, MeshKit.box(Vector3(1.92, 0.08, 0.6)), level_material(level), Vector3(0, 0.42, -0.5))
	if level >= 3:
		for sx in [-1.0, 1.0]:
			for i in 6:
				MeshKit.add(root, MeshKit.box(Vector3(0.1, 0.32, 0.55)), tile, Vector3(sx * 1.4, 0.72, -1.6 + i * 0.66))
		for i in 4:
			MeshKit.add(turret, MeshKit.box(Vector3(0.4, 0.2, 0.08)), tile, Vector3(-0.7 + i * 0.45, 0.25, 1.85))
		MeshKit.add(gun, MeshKit.cyl(0.09, 0.09, 0.7, 12), metal, Vector3(0, 0, 3.35)).rotation.x = PI / 2.0
		MeshKit.add(gun, MeshKit.cyl(0.14, 0.14, 0.3, 12), metal, Vector3(0, 0, 3.75)).rotation.x = PI / 2.0
		(p["muzzle"] as Node3D).position.z = 3.95
		MeshKit.add(turret, MeshKit.box(Vector3(0.08, 0.25, 0.6)), metal, Vector3(0.55, 0.62, 0.2))
		MeshKit.add(turret, MeshKit.cyl(0.03, 0.03, 0.5, 8), metal, Vector3(0.55, 0.68, 0.5)).rotation.x = PI / 2.0
	if level >= 4:
		recolor(root, SINAI, Color(0.49, 0.48, 0.38))
		recolor(root, SINAI_DARK, Color(0.36, 0.36, 0.29))
		for i in 5:
			MeshKit.add(root, MeshKit.box(Vector3(2.32, 0.04, 0.35)), MeshKit.mat(Color(0.24, 0.25, 0.2), 0.8), Vector3(0, 1.03, -1.8 + i * 0.9))
		for sx in [-1.0, 1.0]:
			for k in 3:
				MeshKit.add(turret, MeshKit.cyl(0.06, 0.06, 0.25, 8), metal, Vector3(sx * 0.9, 0.45, 0.6 + k * 0.15)).rotation.z = sx * 0.9
	if level >= 5:
		turret.scale = Vector3.ONE * 1.2
		MeshKit.add(gun, MeshKit.cyl(0.08, 0.1, 3.4, 12), metal, Vector3(0.32, 0, 1.9)).rotation.x = PI / 2.0
		for sx in [-1.0, 1.0]:
			MeshKit.add(turret, MeshKit.box(Vector3(0.35, 0.4, 0.35)), MeshKit.mat(Color(0.23, 0.25, 0.21), 0.6, 0.3), Vector3(sx * 1.15, 0.6, -0.3))
			var aps := MeshKit.add(turret, MeshKit.box(Vector3(0.25, 0.28, 0.05)), MeshKit.glow(Color(0.37, 0.88, 1.0), 0.9), Vector3(sx * 1.15, 0.62, -0.11))
			aps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A Syndicate robot guard (approved sketch G1Y41QRsCwW8TVG8wyP9NB): graphite body with a
## violet band, a boxy head with one glowing violet eye, an antenna with a red tip and a gun
## arm. Higher levels add violet shoulder plates. Same moving parts as a soldier.
static func _robot(root: Node3D, level: int) -> Dictionary:
	var dark := MeshKit.mat(Color(0.17, 0.18, 0.2), 0.5, 0.5)
	var shell := MeshKit.mat(Color(0.23, 0.24, 0.27), 0.4, 0.6)
	var violet := MeshKit.mat(Color(0.54, 0.24, 1.0), 0.4, 0.3)
	var hips := []
	for x in [-0.13, 0.13]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.48, 0)
		root.add_child(hip)
		MeshKit.add(hip, MeshKit.box(Vector3(0.11, 0.44, 0.13)), dark, Vector3(0, -0.22, 0))
		MeshKit.add(hip, MeshKit.box(Vector3(0.16, 0.07, 0.22)), dark, Vector3(0, -0.45, 0.04))
		hips.append(hip)
	var torso := Node3D.new()
	torso.position.y = 0.5
	root.add_child(torso)
	MeshKit.add(torso, MeshKit.box(Vector3(0.45, 0.36, 0.3)), shell, Vector3(0, 0.2, 0))
	MeshKit.add(torso, MeshKit.box(Vector3(0.46, 0.06, 0.31)), violet, Vector3(0, 0.29, 0))
	var head := MeshKit.add(torso, MeshKit.box(Vector3(0.3, 0.22, 0.27)), shell, Vector3(0, 0.55, 0))
	var eye := MeshKit.add(torso, MeshKit.box(Vector3(0.2, 0.06, 0.03)), MeshKit.glow(Color(0.75, 0.55, 1.0)), Vector3(0, 0.56, 0.14))
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.add(torso, MeshKit.cyl(0.01, 0.01, 0.24, 4), dark, Vector3(-0.09, 0.78, 0))
	MeshKit.add(torso, MeshKit.sphere(0.03, 6), MeshKit.glow(Color(0.9, 0.33, 0.24)), Vector3(-0.09, 0.9, 0))
	if level >= 3:
		for sx in [-1.0, 1.0]:
			MeshKit.add(torso, MeshKit.box(Vector3(0.15, 0.12, 0.36)), violet, Vector3(sx * 0.33, 0.37, 0))
	var arms := Node3D.new()
	arms.position = Vector3(0, 0.3, 0.05)
	torso.add_child(arms)
	MeshKit.add(arms, MeshKit.box(Vector3(0.1, 0.1, 0.3)), dark, Vector3(-0.28, -0.04, 0.1))
	var rifle := Node3D.new()
	rifle.position = Vector3(0.28, -0.04, 0.12)
	arms.add_child(rifle)
	MeshKit.add(rifle, MeshKit.box(Vector3(0.1, 0.1, 0.42)), dark)
	MeshKit.add(rifle, MeshKit.cyl(0.03, 0.03, 0.2, 8), MeshKit.mat(Color(0.1, 0.1, 0.11), 0.5, 0.4), Vector3(0, 0, 0.3)).rotation.x = PI / 2.0
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0, 0.42)
	rifle.add_child(muzzle)
	return {"hips": hips, "torso": torso, "helmet": head, "muzzle": muzzle, "wheels": [], "turret": null, "gun": null}


static func _soldier(root: Node3D, vest_color: Color, gear_color: Color, engineer: bool) -> Dictionary:
	# B+ look: real proportions, rounded limbs, camo uniform, canvas vest and pack.
	var uni := MeshKit.surface("camo", OLIVE, 0.95)
	var dark := MeshKit.surface("camo", OLIVE_DARK, 0.9)
	var boots := MeshKit.mat(Color(0.16, 0.15, 0.12), 0.8)
	var pads := MeshKit.mat(Color(0.2, 0.21, 0.17), 0.85)
	var hips := []
	for x in [-0.085, 0.085]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.5, 0)
		root.add_child(hip)
		MeshKit.add(hip, MeshKit.cyl(0.07, 0.062, 0.25, 10), uni, Vector3(0, -0.125, 0))
		MeshKit.add(hip, MeshKit.cyl(0.06, 0.05, 0.22, 10), uni, Vector3(0, -0.34, 0))
		MeshKit.add(hip, MeshKit.box(Vector3(0.1, 0.08, 0.07)), pads, Vector3(0, -0.24, 0.055))
		MeshKit.add(hip, MeshKit.box(Vector3(0.11, 0.08, 0.2)), boots, Vector3(0, -0.46, 0.035))
		hips.append(hip)
	var torso := Node3D.new()
	torso.position.y = 0.5
	root.add_child(torso)
	var chest := MeshKit.add(torso, MeshKit.capsule(0.15, 0.48), uni, Vector3(0, 0.22, 0))
	chest.scale = Vector3(1.05, 1.0, 0.68)
	var vest := MeshKit.add(torso, MeshKit.capsule(0.165, 0.36), MeshKit.surface("canvas", vest_color, 0.95), Vector3(0, 0.25, 0))
	vest.scale = Vector3(1.05, 1.0, 0.78)
	for i in [-1, 0, 1]:
		MeshKit.add(torso, MeshKit.box(Vector3(0.075, 0.09, 0.05)), MeshKit.surface("canvas", OLIVE_DARK, 0.95), Vector3(i * 0.095, 0.17, 0.12))
	MeshKit.add(torso, MeshKit.cyl(0.13, 0.15, 0.06, 12), boots, Vector3(0, 0.02, 0))
	var pack := MeshKit.add(torso, MeshKit.capsule(0.12, 0.34), MeshKit.surface("canvas", gear_color, 0.95), Vector3(0, 0.27, -0.16))
	pack.scale = Vector3(1.1, 1.0, 0.7)
	MeshKit.add(torso, MeshKit.cyl(0.055, 0.055, 0.26, 10), MeshKit.surface("canvas", OLIVE_DARK, 0.95), Vector3(0, 0.46, -0.17)).rotation.z = PI / 2.0
	if engineer:
		# Shovel strapped to the pack.
		var handle := MeshKit.add(torso, MeshKit.cyl(0.014, 0.014, 0.5, 6), MeshKit.mat(Color(0.45, 0.32, 0.2), 0.9), Vector3(0.1, 0.3, -0.26))
		handle.rotation.z = 0.3
		MeshKit.add(torso, MeshKit.box(Vector3(0.12, 0.14, 0.02)), MeshKit.mat(Color(0.35, 0.36, 0.38), 0.5, 0.6), Vector3(0.18, 0.55, -0.26))
	MeshKit.add(torso, MeshKit.cyl(0.04, 0.045, 0.06, 8), MeshKit.mat(SKIN, 0.7), Vector3(0, 0.47, 0))
	MeshKit.add(torso, MeshKit.sphere(0.092, 14), MeshKit.mat(SKIN, 0.7), Vector3(0, 0.55, 0.005)).scale = Vector3(0.95, 1.08, 1.0)
	var helmet := MeshKit.add(torso, MeshKit.sphere(0.118, 16), dark, Vector3(0, 0.6, -0.005))
	helmet.scale = Vector3(1, 0.78, 1.1)
	MeshKit.add(torso, MeshKit.cyl(0.13, 0.13, 0.015, 16), pads, Vector3(0, 0.565, 0))
	MeshKit.add(torso, MeshKit.box(Vector3(0.17, 0.03, 0.03)), MeshKit.mat(Color(0.08, 0.08, 0.08), 0.3, 0.4), Vector3(0, 0.625, 0.1))
	var patch := MeshKit.add(torso, MeshKit.box(Vector3(0.06, 0.03, 0.02)), MeshKit.mat(BLUE, 0.4), Vector3(0.17, 0.38, 0))
	patch.rotation.z = 0.2
	var stripe := MeshKit.add(torso, MeshKit.box(Vector3(0.06, 0.03, 0.021)), MeshKit.mat(WHITE, 0.4), Vector3(0.17, 0.355, 0))
	stripe.rotation.z = 0.2
	var arms := Node3D.new()
	arms.position = Vector3(0, 0.36, 0.05)
	torso.add_child(arms)
	for side in [[-0.15, 0.35], [0.14, -0.25]]:
		var arm := MeshKit.add(arms, MeshKit.capsule(0.045, 0.34), uni, Vector3(side[0], -0.02, 0.12))
		arm.rotation = Vector3(PI / 2.0, side[1], 0)
		MeshKit.add(arms, MeshKit.sphere(0.04, 8), boots, Vector3(side[0] * 0.5, -0.03, 0.28))
	var rifle := Node3D.new()
	rifle.position = Vector3(0.04, 0, 0.24)
	arms.add_child(rifle)
	var steel := MeshKit.mat(Color(0.11, 0.114, 0.12), 0.45, 0.5)
	MeshKit.add(rifle, MeshKit.box(Vector3(0.045, 0.075, 0.42)), steel, Vector3(0, 0, 0.0))
	MeshKit.add(rifle, MeshKit.box(Vector3(0.04, 0.09, 0.16)), steel, Vector3(0, -0.01, -0.24))
	MeshKit.add(rifle, MeshKit.box(Vector3(0.035, 0.12, 0.05)), steel, Vector3(0, -0.08, 0.06))
	MeshKit.add(rifle, MeshKit.box(Vector3(0.03, 0.04, 0.08)), MeshKit.mat(Color(0.05, 0.05, 0.05), 0.3, 0.5), Vector3(0, 0.06, 0.02))
	MeshKit.add(rifle, MeshKit.cyl(0.013, 0.013, 0.22, 6), steel, Vector3(0, 0.01, 0.32)).rotation.x = PI / 2.0
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0.02, 0.45)
	rifle.add_child(muzzle)
	return {"hips": hips, "torso": torso, "helmet": helmet, "muzzle": muzzle, "wheels": [], "turret": null, "gun": null}


static func _tank(root: Node3D) -> Dictionary:
	var sinai := MeshKit.surface("camo", SINAI, 0.85, 0.1)
	var sinai_dark := MeshKit.surface("camo", SINAI_DARK, 0.85, 0.1)
	var metal := MeshKit.mat(METAL, 0.6, 0.5)
	MeshKit.add(root, MeshKit.box(Vector3(2.3, 0.55, 4.6)), sinai, Vector3(0, 0.75, 0))
	MeshKit.add(root, MeshKit.box(Vector3(2.25, 0.5, 1.2)), sinai, Vector3(0, 0.82, 2.45)).rotation.x = 0.55
	MeshKit.add(root, MeshKit.box(Vector3(2.6, 0.06, 4.4)), sinai_dark, Vector3(0, 1.04, 0))
	var wheels := []
	for sx in [-1.0, 1.0]:
		MeshKit.add(root, MeshKit.box(Vector3(0.18, 0.5, 4.3)), sinai_dark, Vector3(sx * 1.25, 0.72, 0))
		for i in 6:
			var wheel := Node3D.new()
			wheel.position = Vector3(sx * 1.02, 0.36, -1.7 + i * 0.68)
			root.add_child(wheel)
			MeshKit.add(wheel, MeshKit.cyl(0.3, 0.3, 0.3, 12), metal).rotation.z = PI / 2.0
			MeshKit.add(wheel, MeshKit.box(Vector3(0.32, 0.5, 0.08)), MeshKit.mat(Color(0.12, 0.12, 0.12), 0.7))
			wheels.append(wheel)
		MeshKit.add(root, MeshKit.box(Vector3(0.55, 0.62, 4.7)), MeshKit.surface("canvas", Color(0.17, 0.16, 0.14), 0.9, 0.3), Vector3(sx * 1.0, 0.33, 0))
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.05, -0.4)
	root.add_child(turret)
	MeshKit.add(turret, MeshKit.box(Vector3(1.9, 0.42, 2.3)), sinai, Vector3(0, 0.21, 0))
	var wedge := MeshKit.add(turret, MeshKit.box(Vector3(1.8, 0.4, 1.0)), sinai, Vector3(0, 0.22, 1.35))
	wedge.rotation.x = 0.38
	wedge.scale.z = 0.9
	MeshKit.add(turret, MeshKit.box(Vector3(1.7, 0.3, 0.9)), sinai_dark, Vector3(0, 0.2, -1.45))
	for i in 9:
		MeshKit.add(turret, MeshKit.sphere(0.06, 6), metal, Vector3(-0.8 + i * 0.2, -0.05, -1.92)).scale.y = 1.8
	MeshKit.add(turret, MeshKit.cyl(0.18, 0.18, 0.25, 12), sinai_dark, Vector3(0.55, 0.52, -0.2))
	MeshKit.add(turret, MeshKit.box(Vector3(0.06, 0.5, 0.06)), metal, Vector3(-0.6, 0.7, -0.6))
	var gun := Node3D.new()
	gun.position = Vector3(0, 0.28, 1.0)
	turret.add_child(gun)
	MeshKit.add(gun, MeshKit.cyl(0.08, 0.1, 3.0, 12), metal, Vector3(0, 0, 1.5)).rotation.x = PI / 2.0
	MeshKit.add(gun, MeshKit.cyl(0.13, 0.13, 0.5, 12), metal, Vector3(0, 0, 0.9)).rotation.x = PI / 2.0
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0, 3.05)
	gun.add_child(muzzle)
	# B+ details: engine grille, exhausts, headlights, stowage and a tarp roll on the bustle.
	var black := MeshKit.mat(Color(0.12, 0.12, 0.11), 0.8, 0.3)
	for i in 6:
		MeshKit.add(root, MeshKit.box(Vector3(1.8, 0.03, 0.07)), black, Vector3(0, 1.08, -1.4 - i * 0.15))
	for sx in [-1.0, 1.0]:
		MeshKit.add(root, MeshKit.cyl(0.08, 0.08, 0.3, 8), black, Vector3(sx * 0.7, 0.85, -2.35)).rotation.x = PI / 2.0
		MeshKit.add(root, MeshKit.cyl(0.08, 0.06, 0.08, 10), MeshKit.glow(Color(1.0, 0.96, 0.8)), Vector3(sx * 0.95, 1.0, 3.0)).rotation.x = PI / 2.0
	var olive := MeshKit.surface("canvas", OLIVE, 0.9)
	for i in 2:
		MeshKit.add(root, MeshKit.box(Vector3(0.28, 0.4, 0.15)), olive, Vector3(0.55 + i * 0.32, 1.27, -2.05))
	MeshKit.add(root, MeshKit.box(Vector3(0.6, 0.32, 0.45)), MeshKit.mat(Color(0.48, 0.36, 0.22), 0.85), Vector3(-0.65, 1.23, -1.95))
	MeshKit.add(turret, MeshKit.cyl(0.2, 0.2, 1.4, 12), MeshKit.surface("canvas", Color(0.44, 0.42, 0.3), 0.95), Vector3(0, 0.55, -1.75)).rotation.z = PI / 2.0
	MeshKit.add(turret, MeshKit.cyl(0.006, 0.006, 1.6, 4), black, Vector3(0.7, 1.2, -1.1))
	# Fictional shield emblem on both sides of the hull.
	for sx in [-1.0, 1.0]:
		MeshKit.add(root, MeshKit.box(Vector3(0.02, 0.22, 0.36)), MeshKit.mat(BLUE, 0.4), Vector3(sx * 1.17, 0.85, 1.0))
		MeshKit.add(root, MeshKit.box(Vector3(0.021, 0.1, 0.36)), MeshKit.mat(WHITE, 0.4), Vector3(sx * 1.17, 0.85, 1.0))
	return {"hips": [], "torso": null, "helmet": null, "muzzle": muzzle, "wheels": wheels, "turret": turret, "gun": gun}


## The air strike plane, by level (approved sketch): Lv1 a light propeller plane with two
## bombs, Lv2 four bombs; Lv3 the approved jet with three heavy bombs, Lv4 extra missiles;
## Lv5 a stealth flying-wing bomber with five bombs and glowing engines. A band in the level
## color sits on top. Forward is +Z.
static func aircraft(root: Node3D, level: int) -> void:
	var grey := MeshKit.mat(Color(0.12, 0.13, 0.15) if level >= 5 else Color(0.55, 0.59, 0.62), 0.45, 0.4)
	var bomb_mat := MeshKit.mat(Color(0.24, 0.26, 0.28), 0.5, 0.5)
	if level <= 2:
		var khaki := MeshKit.mat(Color(0.49, 0.54, 0.42), 0.6)
		MeshKit.add(root, MeshKit.cyl(0.25, 0.25, 3.2, 12), khaki).rotation.x = PI / 2.0
		MeshKit.add(root, MeshKit.box(Vector3(5.0, 0.08, 0.9)), khaki, Vector3(0, 0.1, 0.3))
		MeshKit.add(root, MeshKit.box(Vector3(1.6, 0.06, 0.5)), khaki, Vector3(0, 0, -1.5))
		MeshKit.add(root, MeshKit.box(Vector3(0.06, 0.7, 0.6)), khaki, Vector3(0, 0.35, -1.5))
		var prop := Node3D.new()
		prop.position = Vector3(0, 0, 1.7)
		root.add_child(prop)
		MeshKit.add(prop, MeshKit.box(Vector3(1.4, 0.1, 0.04)), MeshKit.mat(Color(0.13, 0.13, 0.13), 0.5))
		var spin := prop.create_tween().set_loops()
		spin.tween_property(prop, "rotation:z", TAU, 0.12).as_relative()
		var bombs := 4 if level == 2 else 2
		for i in bombs:
			MeshKit.add(root, MeshKit.cyl(0.1, 0.1, 0.6, 8), bomb_mat, Vector3((-1.0 if i < bombs / 2 else 1.0) * (0.9 + (i % 2) * 0.5), -0.18, 0.3)).rotation.x = PI / 2.0
	elif level <= 4:
		MeshKit.add(root, MeshKit.cyl(0.22, 0.32, 4.2, 14), grey).rotation.x = PI / 2.0
		MeshKit.add(root, MeshKit.cyl(0.0, 0.22, 1.1, 14), grey, Vector3(0, 0, 2.6)).rotation.x = PI / 2.0
		MeshKit.add(root, MeshKit.sphere(0.24, 12), MeshKit.mat(Color(0.17, 0.23, 0.27), 0.1, 0.6), Vector3(0, 0.22, 1.3)).scale = Vector3(0.8, 0.7, 1.8)
		MeshKit.add(root, MeshKit.box(Vector3(5.2, 0.06, 1.5)), grey, Vector3(0, -0.03, -0.3))
		MeshKit.add(root, MeshKit.box(Vector3(0.06, 1.0, 0.9)), grey, Vector3(0, 0.55, -1.7)).rotation.x = -0.3
		for s in [-1.0, 1.0]:
			MeshKit.add(root, MeshKit.box(Vector3(1.0, 0.05, 0.6)), grey, Vector3(s * 0.6, 0, -1.8))
			MeshKit.add(root, MeshKit.cyl(0.18, 0.18, 0.02, 20), MeshKit.mat(BLUE, 0.4), Vector3(s * 1.6, 0.06, -0.4))
			MeshKit.add(root, MeshKit.cyl(0.1, 0.1, 0.025, 20), MeshKit.mat(WHITE, 0.4), Vector3(s * 1.6, 0.065, -0.4))
			for k in (2 if level == 4 else 1):
				var m := MeshKit.mat(Color(0.93, 0.93, 0.93), 0.4) if level == 4 else bomb_mat
				MeshKit.add(root, MeshKit.cyl(0.1, 0.1, 0.8, 8), m, Vector3(s * (1.0 + k * 0.6), -0.2, -0.2)).rotation.x = PI / 2.0
		MeshKit.add(root, MeshKit.cyl(0.12, 0.12, 0.8, 8), bomb_mat, Vector3(0, -0.35, 0)).rotation.x = PI / 2.0
		var burner := MeshKit.add(root, MeshKit.sphere(0.17, 10), MeshKit.glow(Color(1.0, 0.64, 0.29), 0.85), Vector3(0, 0, -2.4))
		burner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var wing := PackedVector2Array([Vector2(0, 2.2), Vector2(3.6, -1.0), Vector2(2.6, -1.4), Vector2(1.6, -0.9), Vector2(0.6, -1.4),
			Vector2(0, -1.0), Vector2(-0.6, -1.4), Vector2(-1.6, -0.9), Vector2(-2.6, -1.4), Vector2(-3.6, -1.0)])
		var body := CSGPolygon3D.new()
		body.polygon = wing
		body.depth = 0.3
		body.material = grey
		body.rotation.x = PI / 2.0
		root.add_child(body)
		MeshKit.add(root, MeshKit.sphere(0.4, 12), MeshKit.mat(Color(0.17, 0.23, 0.27), 0.1, 0.6), Vector3(0, 0.15, 1.0)).scale = Vector3(1, 0.5, 1.6)
		for s in [-1.0, 1.0]:
			var glow := MeshKit.add(root, MeshKit.sphere(0.18, 10), MeshKit.glow(Color(0.37, 0.88, 1.0), 0.9), Vector3(s * 0.8, 0, -1.0))
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 5:
			MeshKit.add(root, MeshKit.cyl(0.12, 0.12, 0.7, 8), bomb_mat, Vector3(-1.0 + i * 0.5, -0.35, 0)).rotation.x = PI / 2.0
	MeshKit.add(root, MeshKit.box(Vector3(0.8, 0.04, 0.3)), level_material(level), Vector3(0, 0.3, -0.8))


## The level color every unit, drone and plane wears: none, silver, blue, red, gold.
const LEVEL_COLORS := [Color(0.55, 0.56, 0.58), Color(0.78, 0.8, 0.82), Color(0.18, 0.44, 0.88), Color(0.84, 0.24, 0.18), Color(0.95, 0.75, 0.23)]


static func level_material(level: int) -> StandardMaterial3D:
	var gold := level >= 5
	return MeshKit.mat(LEVEL_COLORS[clampi(level, 1, 5) - 1], 0.25 if gold else 0.4, 0.85 if gold else 0.3)
