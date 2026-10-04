class_name AaBattery
extends Defense
## Anti-air battery: against drones (it replaces the laser tower). The barrels swing and
## lift toward the drone and fire bursts; the radar spins. Lv1 twin barrels on a concrete
## base; Lv2 ammo crate; Lv3 a spinning radar; Lv4 a second crate; Lv5 four barrels, a bigger
## radar and missile pods on the sides.

const TURN := 4.0

var _pivot: Node3D
var _cradle: Node3D
var _radar: Node3D
var _muzzles: Array[Node3D] = []
var _cooldown := 0.0
var _shots := 0


func _build() -> void:
	var olive := MeshKit.mat(UnitModels.OLIVE, 0.7)
	var metal := MeshKit.mat(UnitModels.METAL, 0.5, 0.5)
	MeshKit.add(model, MeshKit.cyl(1.3, 1.5, 0.5, 20), MeshKit.mat(StructureModels.CONCRETE, 0.85), Vector3(0, 0.25, 0))
	_pivot = Node3D.new()
	_pivot.position.y = 0.5
	model.add_child(_pivot)
	MeshKit.add(_pivot, MeshKit.cyl(0.9, 0.9, 0.35, 16), olive, Vector3(0, 0.2, 0))
	MeshKit.add(_pivot, MeshKit.box(Vector3(1.3, 0.9, 1.0)), olive, Vector3(0, 0.75, 0))
	MeshKit.add(_pivot, MeshKit.box(Vector3(1.32, 0.12, 1.02)), MeshKit.mat(StructureModels.RUST, 0.6), Vector3(0, 1.2, 0))
	_cradle = Node3D.new()
	_cradle.position = Vector3(0, 1.0, 0.2)
	_cradle.rotation.x = -0.7
	_pivot.add_child(_cradle)
	var barrels := 4 if level >= 5 else 2
	for i in barrels:
		var x := (i - (barrels - 1) / 2.0) * 0.32
		MeshKit.add(_cradle, MeshKit.cyl(0.06, 0.07, 2.2, 10), metal, Vector3(x, 0, 1.2)).rotation.x = PI / 2.0
		var muzzle := Node3D.new()
		muzzle.position = Vector3(x, 0, 2.35)
		_cradle.add_child(muzzle)
		_muzzles.append(muzzle)
	if level >= 3:
		MeshKit.add(model, MeshKit.cyl(0.06, 0.06, 2.2, 8), metal, Vector3(-1.6, 1.1, -1.4))
		_radar = Node3D.new()
		_radar.position = Vector3(-1.6, 2.3, -1.4)
		model.add_child(_radar)
		var dish := MeshKit.add(_radar, MeshKit.box(Vector3(1.2 * (1.4 if level >= 5 else 1.0), 0.5, 0.08)), MeshKit.mat(Color(0.85, 0.84, 0.8), 0.5, 0.3))
		dish.rotation.x = -0.3
	if level >= 5:
		for s in [-1.0, 1.0]:
			MeshKit.add(_pivot, MeshKit.box(Vector3(0.45, 0.45, 1.2)), MeshKit.mat(UnitModels.SINAI_DARK, 0.7), Vector3(s * 1.0, 1.0, 0))
	if level >= 2:
		StructureModels.crate(model, 1.5, -1.3)
	if level >= 4:
		StructureModels.crate(model, 1.5, 1.3)


func _head_height() -> float:
	return 1.5


func tick(delta: float, units: Array) -> void:
	if _radar != null:
		_radar.rotation.y += delta * 2.0
	var target := pick_target(units)
	if target == null:
		_cradle.rotation.x = move_toward(_cradle.rotation.x, -0.7, delta)
		return
	var aim := Defense.aim_point(target)
	var lined_up := turn_toward(_pivot, aim, TURN, delta)
	var head := head_position()
	var flat := Vector2(aim.x - head.x, aim.z - head.z).length()
	_cradle.rotation.x = move_toward(_cradle.rotation.x, -atan2(aim.y - head.y, flat), delta * 3.0)
	_cooldown -= delta
	if not lined_up or _cooldown > 0.0:
		return
	_shots += 1
	_cooldown = 0.7 if _shots % 8 == 0 else (0.09 if level >= 5 else 0.13)
	var cycle := 7 * (0.09 if level >= 5 else 0.13) + 0.7
	var damage := float(stats["dps"]) * cycle / 8.0 * factor(target)
	var fx := _fx_parent()
	var muzzle := _muzzles[_shots % _muzzles.size()]
	var from := muzzle.global_position
	var hit := aim + Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.5), randf_range(-0.8, 0.8))
	Fx.flash(fx, from, 0.22, Color(1.0, 0.95, 0.7))
	Fx.tracer(fx, from, hit, Color(1.0, 0.94, 0.6), 0.06, 0.07)
	if randf() < 0.3:
		Fx.flash(fx, hit, 0.5, Color(1, 1, 1))
	Audio.play("shot_scout", -12.0, 0.05)
	target.damage(damage)


func _ring_color() -> Color:
	return Color(0.4, 0.8, 1.0)
