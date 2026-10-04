class_name MgNest
extends Defense
## Machine-gun nest: against infantry. Swings to the target and fires short bursts with
## yellow tracers. Lv1 one gun on a tripod in a ring of sandbags; Lv2 an ammo crate;
## Lv3 two rows of sandbags and a steel shield; Lv4 a second crate; Lv5 a concrete ring,
## twin guns and a camouflage net.

const TURN := 3.5

var _pivot: Node3D
var _muzzles: Array[Node3D] = []
var _cooldown := 0.0
var _shots := 0


func _build() -> void:
	if level >= 5:
		MeshKit.add(model, MeshKit.cyl(1.9, 2.0, 0.9, 24), MeshKit.mat(StructureModels.CONCRETE, 0.85), Vector3(0, 0.45, 0))
	StructureModels.sandbags(model, 1.7, 2 if level >= 3 else 1)
	var steel := MeshKit.mat(Color(0.18, 0.19, 0.2), 0.6, 0.4)
	for a in [0.0, 2.1, 4.2]:
		var leg := MeshKit.add(model, MeshKit.box(Vector3(0.05, 0.8, 0.05)), steel, Vector3(cos(a) * 0.3, 0.35, sin(a) * 0.3))
		leg.rotation.z = 0.3
	_pivot = Node3D.new()
	_pivot.position.y = 1.05 if level >= 5 else 0.75
	model.add_child(_pivot)
	MeshKit.add(_pivot, MeshKit.cyl(0.08, 0.08, 0.6, 8), steel)
	var gun_mat := MeshKit.mat(Color(0.11, 0.114, 0.12), 0.5, 0.4)
	var guns := 2 if level >= 5 else 1
	for i in guns:
		var x := 0.0 if guns == 1 else (0.22 if i == 1 else -0.22)
		MeshKit.add(_pivot, MeshKit.box(Vector3(0.18, 0.2, 1.1)), gun_mat, Vector3(x, 0.35, 0.25))
		MeshKit.add(_pivot, MeshKit.cyl(0.04, 0.04, 0.7, 8), gun_mat, Vector3(x, 0.38, 1.1)).rotation.x = PI / 2.0
		MeshKit.add(_pivot, MeshKit.box(Vector3(0.24, 0.22, 0.2)), MeshKit.mat(UnitModels.OLIVE_DARK, 0.8), Vector3(x - 0.18, 0.3, 0))
		var muzzle := Node3D.new()
		muzzle.position = Vector3(x, 0.38, 1.45)
		_pivot.add_child(muzzle)
		_muzzles.append(muzzle)
	if level >= 3:
		MeshKit.add(_pivot, MeshKit.box(Vector3(1.0, 0.6, 0.06)), MeshKit.mat(UnitModels.OLIVE, 0.7, 0.2), Vector3(0, 0.55, 0.65))
	if level >= 2:
		StructureModels.crate(model, 1.1, -0.9)
	if level >= 4:
		StructureModels.crate(model, -1.1, -0.9)
	if level >= 5:
		StructureModels.camo_net(model, 4.2, 4.2, 2.6)
	MeshKit.add(_pivot, MeshKit.box(Vector3(0.12, 0.05, 0.3)), MeshKit.mat(StructureModels.RUST, 0.6), Vector3(0, 0.15, -0.2))


func _head_height() -> float:
	return _pivot.position.y + 0.4


func tick(delta: float, units: Array) -> void:
	var target := pick_target(units)
	if target == null:
		_pivot.rotation.y += 0.3 * delta
		return
	var aim := Defense.aim_point(target)
	var lined_up := turn_toward(_pivot, aim, TURN, delta)
	_cooldown -= delta
	if not lined_up or _cooldown > 0.0:
		return
	var burst := 6 if level >= 3 else 4
	_shots += 1
	_cooldown = 0.9 if _shots % burst == 0 else 0.1
	var cycle := 0.1 * (burst - 1) + 0.9
	var damage := float(stats["dps"]) * cycle / burst * factor(target)
	var fx := _fx_parent()
	for muzzle in _muzzles:
		var from := muzzle.global_position
		var hit := aim + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
		Fx.flash(fx, from, 0.18)
		Fx.tracer(fx, from, hit, Color(1.0, 0.82, 0.29), 0.05, 0.06)
	Audio.play("rifle", -10.0, 0.05)
	target.damage(damage)


func _ring_color() -> Color:
	return Color(1.0, 0.7, 0.3)
