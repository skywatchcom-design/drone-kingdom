class_name MortarPit
extends Defense
## Mortar: lobs a round in a high arc that bursts on the ground and hurts every soldier near
## it. Can't fire at anything too close. Lv1 one tube in sandbags; Lv2 a crate; Lv3 two
## tubes and two rows of sandbags; Lv4 a second crate; Lv5 three tubes and a camouflage net.

const FLIGHT := 1.3

var _muzzles: Array[Node3D] = []
var _cooldown := 1.0
var _next := 0


func _build() -> void:
	StructureModels.sandbags(model, 1.9, 2 if level >= 3 else 1)
	var tubes := 3 if level >= 5 else (2 if level >= 3 else 1)
	for i in tubes:
		var x := (i - (tubes - 1) / 2.0) * 0.8
		MeshKit.add(model, MeshKit.cyl(0.35, 0.35, 0.08, 12), MeshKit.mat(UnitModels.METAL, 0.6, 0.4), Vector3(x, 0.05, 0))
		var tube := MeshKit.add(model, MeshKit.cyl(0.11, 0.13, 1.4, 12), MeshKit.mat(UnitModels.OLIVE_DARK, 0.6, 0.3), Vector3(x, 0.65, 0.2))
		tube.rotation.x = 0.5
		var muzzle := Node3D.new()
		muzzle.position = Vector3(x, 1.25, 0.55)
		model.add_child(muzzle)
		_muzzles.append(muzzle)
	if level >= 2:
		StructureModels.crate(model, 1.0, -1.1, 0.9)
	if level >= 4:
		StructureModels.crate(model, -1.0, -1.1, 0.9)
	if level >= 5:
		StructureModels.camo_net(model, 4.4, 4.4, 2.4)


func _head_height() -> float:
	return 1.3


func tick(delta: float, units: Array) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := pick_target(units)
	if target == null:
		return
	_cooldown = float(stats["cooldown"])
	# Aim where the target will be when the round comes down.
	var land := target.global_position + target.velocity * FLIGHT
	land.y = 0.1
	var from := _muzzles[_next % _muzzles.size()].global_position
	_next += 1
	var fx := _fx_parent()
	var splash := float(stats["splash"])
	var damage := float(stats["damage"])
	Fx.flash(fx, from, 0.4)
	Audio.play("release", -6.0)
	Fx.lob(fx, from, land, FLIGHT, func() -> void:
		Fx.boom(fx, land, 1.1)
		Audio.play("thud", -2.0)
		for u: Unit in units:
			if is_instance_valid(u) and not u.dead and Vector2(u.global_position.x - land.x, u.global_position.z - land.z).length() <= splash:
				u.damage(damage * factor(u)))


func _ring_color() -> Color:
	return Color(1.0, 0.85, 0.4)
