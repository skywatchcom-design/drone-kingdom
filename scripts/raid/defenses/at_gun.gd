class_name AtGun
extends Defense
## Anti-tank gun: slow and heavy-hitting, against tanks. The barrel swings round, fires one
## shell with a flash and recoil, and the hit kicks up a blast. Lv1 a towed gun with wheels and
## a shield; Lv2 ammo crate; Lv3 longer barrel on a concrete base with sandbags; Lv4 a second
## crate; Lv5 an armored turret with a heavy gun and two missile tubes.

const TURN := 1.4

var _pivot: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _cooldown := 0.5
var _recoil := 0.0


func _build() -> void:
	var olive := MeshKit.mat(UnitModels.OLIVE, 0.7, 0.2)
	var metal := MeshKit.mat(UnitModels.METAL, 0.5, 0.5)
	if level >= 3:
		MeshKit.add(model, MeshKit.cyl(1.7, 1.9, 0.4, 20), MeshKit.mat(StructureModels.CONCRETE, 0.85), Vector3(0, 0.2, 0))
		StructureModels.sandbags(model, 2.2, 1)
	_pivot = Node3D.new()
	_pivot.position.y = 0.4 if level >= 3 else 0.0
	model.add_child(_pivot)
	_gun = Node3D.new()
	_pivot.add_child(_gun)
	if level < 5:
		for s in [-1.0, 1.0]:
			var trail := MeshKit.add(_pivot, MeshKit.box(Vector3(0.12, 0.12, 1.8)), olive, Vector3(s * 0.35, 0.3, -1.0))
			trail.rotation.y = s * 0.2
			MeshKit.add(_pivot, MeshKit.cyl(0.45, 0.45, 0.22, 16), MeshKit.mat(Color(0.13, 0.13, 0.13), 0.9), Vector3(s * 0.85, 0.45, 0.1)).rotation.z = PI / 2.0
		MeshKit.add(_pivot, MeshKit.box(Vector3(1.6, 0.9, 0.08)), olive, Vector3(0, 0.85, 0.35))
		MeshKit.add(_gun, MeshKit.box(Vector3(0.4, 0.35, 0.9)), MeshKit.mat(UnitModels.OLIVE_DARK, 0.7), Vector3(0, 0.75, 0))
		var length := 3.0 if level >= 3 else 2.4
		MeshKit.add(_gun, MeshKit.cyl(0.08, 0.1, length, 12), metal, Vector3(0, 0.8, length / 2.0 + 0.3)).rotation.x = PI / 2.0
		MeshKit.add(_gun, MeshKit.cyl(0.14, 0.12, 0.3, 12), metal, Vector3(0, 0.8, length + 0.3)).rotation.x = PI / 2.0
		_muzzle = Node3D.new()
		_muzzle.position = Vector3(0, 0.8, length + 0.45)
		_gun.add_child(_muzzle)
		if level >= 3:
			MeshKit.add(_pivot, MeshKit.box(Vector3(0.2, 0.12, 0.6)), MeshKit.mat(StructureModels.RUST, 0.6), Vector3(0.5, 0.5, -0.3))
	else:
		var sinai := MeshKit.mat(UnitModels.SINAI, 0.8, 0.1)
		MeshKit.add(_pivot, MeshKit.cyl(1.0, 1.2, 0.6, 16), sinai, Vector3(0, 0.3, 0))
		MeshKit.add(_pivot, MeshKit.box(Vector3(1.6, 0.8, 1.8)), sinai, Vector3(0, 0.95, 0))
		MeshKit.add(_pivot, MeshKit.box(Vector3(1.5, 0.15, 1.7)), MeshKit.mat(StructureModels.RUST, 0.6), Vector3(0, 1.42, 0))
		MeshKit.add(_gun, MeshKit.cyl(0.1, 0.12, 3.2, 12), metal, Vector3(0, 0.95, 2.4)).rotation.x = PI / 2.0
		_muzzle = Node3D.new()
		_muzzle.position = Vector3(0, 0.95, 4.05)
		_gun.add_child(_muzzle)
		for s in [-1.0, 1.0]:
			MeshKit.add(_pivot, MeshKit.cyl(0.18, 0.18, 1.4, 12), olive, Vector3(s * 0.55, 1.75, 0.3)).rotation.x = PI / 2.0
	if level >= 2:
		StructureModels.crate(model, -1.5, -1.2)
	if level >= 4:
		StructureModels.crate(model, 1.5, -1.2)


func _head_height() -> float:
	return _pivot.position.y + 1.0


func tick(delta: float, units: Array) -> void:
	_recoil = maxf(0.0, _recoil - delta * 2.5)
	_gun.position.z = -_recoil * 0.3
	var target := pick_target(units)
	if target == null:
		return
	var aim := Defense.aim_point(target)
	var lined_up := turn_toward(_pivot, aim, TURN, delta)
	_cooldown -= delta
	if not lined_up or _cooldown > 0.0:
		return
	_cooldown = float(stats["cooldown"])
	_recoil = 1.0
	var from := _muzzle.global_position
	var damage := float(stats["damage"]) * factor(target)
	var fx := _fx_parent()
	Fx.flash(fx, from, 0.7)
	Fx.tracer(fx, from, aim, Color(1.0, 0.76, 0.35), 0.1, 0.12)
	Audio.play("cannon", -4.0)
	Fx.shell(fx, from, aim, 0.18, func() -> void:
		Fx.boom(fx, aim, 0.9)
		if is_instance_valid(target):
			target.damage(damage))


func _ring_color() -> Color:
	return Color(1.0, 0.5, 0.25)
