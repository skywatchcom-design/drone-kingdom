class_name UnitModels
extends RefCounted
## The approved ground-forces designs (sketch BD7VJUbaPSCevXsmgRoS2o), built from primitives.
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


static func build(kind: String, root: Node3D) -> Dictionary:
	match kind:
		"armor":
			return _tank(root)
		"engineers":
			return _soldier(root, Color(0.77, 0.54, 0.17), Color(0.42, 0.35, 0.2), true)
	return _soldier(root, Color(0.333, 0.376, 0.235), Color(0.3, 0.325, 0.22), false)


static func _soldier(root: Node3D, vest_color: Color, gear_color: Color, engineer: bool) -> Dictionary:
	var uni := MeshKit.mat(OLIVE, 0.85)
	var dark := MeshKit.mat(OLIVE_DARK, 0.85)
	var boots := MeshKit.mat(Color(0.16, 0.15, 0.12), 0.8)
	var hips := []
	for x in [-0.09, 0.09]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.48, 0)
		root.add_child(hip)
		MeshKit.add(hip, MeshKit.box(Vector3(0.13, 0.46, 0.14)), uni, Vector3(0, -0.23, 0))
		MeshKit.add(hip, MeshKit.box(Vector3(0.14, 0.1, 0.22)), boots, Vector3(0, -0.47, 0.04))
		hips.append(hip)
	var torso := Node3D.new()
	torso.position.y = 0.5
	root.add_child(torso)
	MeshKit.add(torso, MeshKit.box(Vector3(0.34, 0.42, 0.2)), uni, Vector3(0, 0.22, 0))
	MeshKit.add(torso, MeshKit.box(Vector3(0.37, 0.3, 0.24)), MeshKit.mat(vest_color, 0.85), Vector3(0, 0.24, 0))
	for i in [-1, 0, 1]:
		MeshKit.add(torso, MeshKit.box(Vector3(0.08, 0.09, 0.05)), dark, Vector3(i * 0.11, 0.17, 0.13))
	MeshKit.add(torso, MeshKit.box(Vector3(0.28, 0.34, 0.14)), MeshKit.mat(gear_color, 0.85), Vector3(0, 0.26, -0.17))
	if engineer:
		# Shovel strapped to the pack.
		var handle := MeshKit.add(torso, MeshKit.box(Vector3(0.03, 0.5, 0.03)), MeshKit.mat(Color(0.45, 0.32, 0.2), 0.9), Vector3(0.1, 0.3, -0.26))
		handle.rotation.z = 0.3
		MeshKit.add(torso, MeshKit.box(Vector3(0.12, 0.14, 0.02)), MeshKit.mat(Color(0.35, 0.36, 0.38), 0.5, 0.6), Vector3(0.18, 0.55, -0.26))
	MeshKit.add(torso, MeshKit.sphere(0.11, 12), MeshKit.mat(SKIN, 0.7), Vector3(0, 0.54, 0))
	var helmet := MeshKit.add(torso, MeshKit.sphere(0.135, 14), dark, Vector3(0, 0.6, 0))
	helmet.scale = Vector3(1, 0.72, 1.08)
	var patch := MeshKit.add(torso, MeshKit.box(Vector3(0.07, 0.03, 0.02)), MeshKit.mat(BLUE, 0.4), Vector3(0.19, 0.38, 0))
	patch.rotation.z = 0.2
	var stripe := MeshKit.add(torso, MeshKit.box(Vector3(0.07, 0.03, 0.021)), MeshKit.mat(WHITE, 0.4), Vector3(0.19, 0.355, 0))
	stripe.rotation.z = 0.2
	var arms := Node3D.new()
	arms.position = Vector3(0, 0.36, 0.05)
	torso.add_child(arms)
	MeshKit.add(arms, MeshKit.box(Vector3(0.09, 0.09, 0.32)), uni, Vector3(-0.15, -0.02, 0.12)).rotation.y = 0.35
	MeshKit.add(arms, MeshKit.box(Vector3(0.09, 0.09, 0.32)), uni, Vector3(0.14, -0.02, 0.12)).rotation.y = -0.25
	var rifle := Node3D.new()
	rifle.position = Vector3(0.04, 0, 0.24)
	arms.add_child(rifle)
	var steel := MeshKit.mat(Color(0.11, 0.114, 0.12), 0.5, 0.4)
	MeshKit.add(rifle, MeshKit.box(Vector3(0.05, 0.08, 0.6)), steel, Vector3(0, 0, 0.05))
	MeshKit.add(rifle, MeshKit.box(Vector3(0.04, 0.12, 0.06)), steel, Vector3(0, -0.08, 0.02))
	MeshKit.add(rifle, MeshKit.box(Vector3(0.03, 0.03, 0.16)), steel, Vector3(0, 0.02, 0.4))
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0.02, 0.5)
	rifle.add_child(muzzle)
	return {"hips": hips, "torso": torso, "helmet": helmet, "muzzle": muzzle, "wheels": [], "turret": null, "gun": null}


static func _tank(root: Node3D) -> Dictionary:
	var sinai := MeshKit.mat(SINAI, 0.85, 0.1)
	var sinai_dark := MeshKit.mat(SINAI_DARK, 0.85, 0.1)
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
		MeshKit.add(root, MeshKit.box(Vector3(0.55, 0.62, 4.7)), MeshKit.mat(Color(0.15, 0.15, 0.15), 0.9), Vector3(sx * 1.0, 0.33, 0))
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
	# Fictional shield emblem on both sides of the hull.
	for sx in [-1.0, 1.0]:
		MeshKit.add(root, MeshKit.box(Vector3(0.02, 0.22, 0.36)), MeshKit.mat(BLUE, 0.4), Vector3(sx * 1.17, 0.85, 1.0))
		MeshKit.add(root, MeshKit.box(Vector3(0.021, 0.1, 0.36)), MeshKit.mat(WHITE, 0.4), Vector3(sx * 1.17, 0.85, 1.0))
	return {"hips": [], "torso": null, "helmet": null, "muzzle": muzzle, "wheels": wheels, "turret": turret, "gun": gun}
