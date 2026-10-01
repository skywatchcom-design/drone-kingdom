class_name Drone
extends Node3D
## Civilian delivery quadcopter. Movement comes from steer(); the body tilts
## from its own acceleration so autopilot and manual flight look the same.

signal crashed

const MAX_SPEED := 10.0
const ACCEL := 14.0
const BODY_SCALE := 2.0
const GEAR_HEIGHT := 0.6 * BODY_SCALE

var velocity := Vector3.ZERO
var health := 100.0
var jammed := false
var dead := false
## Demo/autoplay only: hits still show effects but never kill the drone.
var invulnerable := false
var net_timer := 0.0

var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _rpm := 0.0
var _time := 0.0
var _fall_speed := 0.0
var _accel := Vector3.ZERO
var _body: Node3D
var _rotors: Array[Node3D] = []
var _discs: Array[MeshInstance3D] = []
var _blinkers: Array[MeshInstance3D] = []
var _cargo: MeshInstance3D
var _net: MeshInstance3D


func _ready() -> void:
	_body = Node3D.new()
	_body.scale = Vector3.ONE * BODY_SCALE
	add_child(_body)
	_build_model()


func steer(target_velocity: Vector3, delta: float) -> void:
	if dead:
		return
	var limit := MAX_SPEED * (0.3 if net_timer > 0.0 else 1.0)
	target_velocity = target_velocity.limit_length(limit)
	var previous := velocity
	velocity = velocity.move_toward(target_velocity, ACCEL * delta)
	position += velocity * delta
	var accel := (velocity - previous) / maxf(delta, 0.0001)
	_accel = _accel.lerp(accel, 1.0 - exp(-delta * 6.0))


func damage(amount: float) -> void:
	if dead:
		return
	health = maxf(1.0 if invulnerable else 0.0, health - amount)
	if health <= 0.0:
		dead = true
		crashed.emit()


func hit_net() -> void:
	net_timer = 2.0
	damage(8.0)


func set_carrying(on: bool) -> void:
	_cargo.visible = on


func _process(delta: float) -> void:
	_time += delta
	net_timer = maxf(0.0, net_timer - delta)
	_net.visible = net_timer > 0.0
	if dead:
		_crash_fall(delta)
		return
	_rpm = lerpf(_rpm, 1.0, 1.0 - exp(-delta * 2.0))
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.4:
		_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 1.0 - exp(-delta * 4.0))
	var tilt := RaidRules.bank_angles(_accel, velocity, _yaw)
	_pitch = lerpf(_pitch, tilt.x, 1.0 - exp(-delta * 5.0))
	_roll = lerpf(_roll, tilt.y, 1.0 - exp(-delta * 5.0))
	var shake := 0.08 if jammed else 0.0
	rotation = Vector3(_pitch + randf_range(-shake, shake), _yaw, _roll + randf_range(-shake, shake))
	_body.position = Vector3(sin(_time * 1.7), sin(_time * 2.3) * 2.0, cos(_time * 1.3)) * 0.04
	_spin(delta)


func _crash_fall(delta: float) -> void:
	_rpm = lerpf(_rpm, 0.0, 1.0 - exp(-delta * 3.0))
	_spin(delta)
	if position.y <= 0.6:
		return
	_fall_speed += 20.0 * delta
	position.y = maxf(0.6, position.y - _fall_speed * delta)
	rotation.z += delta * 4.0
	rotation.x += delta * 2.0


func _spin(delta: float) -> void:
	for i in _rotors.size():
		_rotors[i].rotation.y += (1.0 if i % 2 == 0 else -1.0) * _rpm * 55.0 * delta
	for disc in _discs:
		var m := disc.material_override as StandardMaterial3D
		m.albedo_color.a = clampf((_rpm - 0.35) * 0.35, 0.0, 0.22)
	var on := int(_time * 1.4) % 2 == 0
	for light in _blinkers:
		light.visible = on


func _build_model() -> void:
	var white := MeshKit.mat(Color(0.93, 0.94, 0.95), 0.35)
	var carbon := MeshKit.mat(Color(0.13, 0.14, 0.16), 0.45, 0.3)
	var metal := MeshKit.mat(Color(0.6, 0.63, 0.66), 0.3, 0.85)
	var blade_mat := MeshKit.mat(Color(0.08, 0.09, 0.1), 0.5)

	var shell := MeshKit.add(_body, MeshKit.sphere(0.5, 24), white)
	shell.scale = Vector3(1.0, 0.42, 1.35)
	var canopy := MeshKit.add(_body, MeshKit.sphere(0.36, 20), MeshKit.mat(Color(0.18, 0.2, 0.24), 0.2, 0.1), Vector3(0, 0.08, -0.05))
	canopy.scale = Vector3(1.0, 0.45, 1.2)
	MeshKit.add(_body, MeshKit.box(Vector3(0.36, 0.04, 0.06)), MeshKit.mat(Color(0.95, 0.69, 0.2), 0.4), Vector3(0, 0.04, 0.66))

	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var arm := MeshKit.add(_body, MeshKit.box(Vector3(0.09, 0.07, 1.05)), carbon, Vector3(corner.x * 0.38, 0.02, corner.y * 0.42))
		arm.rotation.y = atan2(corner.x, corner.y)
		var motor := Vector3(corner.x * 0.74, 0.0, corner.y * 0.8)
		MeshKit.add(_body, MeshKit.cyl(0.1, 0.11, 0.16), metal, motor + Vector3(0, 0.08, 0))
		var prop := Node3D.new()
		prop.position = motor + Vector3(0, 0.22, 0)
		_body.add_child(prop)
		MeshKit.add(prop, MeshKit.box(Vector3(0.62, 0.012, 0.07)), blade_mat, Vector3(0.31, 0, 0))
		MeshKit.add(prop, MeshKit.box(Vector3(0.62, 0.012, 0.07)), blade_mat, Vector3(-0.31, 0, 0))
		var disc := MeshKit.add(prop, MeshKit.cyl(0.62, 0.62, 0.005, 32), MeshKit.glow(Color(0.1, 0.1, 0.12), 0.0))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rotors.append(prop)
		_discs.append(disc)
		# Navigation lights: green front-right, red front-left, blinking white at the back.
		var nav_color := Color(1, 1, 1)
		if corner.y > 0:
			nav_color = Color(0.2, 1.0, 0.4) if corner.x > 0 else Color(1.0, 0.2, 0.27)
		var nav := MeshKit.add(_body, MeshKit.sphere(0.035, 8), MeshKit.glow(nav_color), motor + Vector3(0, -0.02, 0))
		if corner.y < 0:
			_blinkers.append(nav)

	for sx in [-1.0, 1.0]:
		var skid := MeshKit.add(_body, MeshKit.cyl(0.03, 0.03, 0.8, 8), carbon, Vector3(sx * 0.31, -0.47, 0))
		skid.rotation.x = PI / 2.0
		for sz in [-0.18, 0.18]:
			var leg := MeshKit.add(_body, MeshKit.cyl(0.025, 0.025, 0.36, 8), carbon, Vector3(sx * 0.26, -0.3, sz))
			leg.rotation.z = sx * 0.25

	_cargo = MeshKit.add(_body, MeshKit.box(Vector3(0.34, 0.26, 0.34)), MeshKit.mat(Color(0.77, 0.6, 0.42), 0.9), Vector3(0, -0.36, 0))
	_cargo.visible = false
	_net = MeshKit.add(_body, MeshKit.sphere(0.9, 12), MeshKit.glow(Color(0.92, 0.96, 1.0), 0.35))
	_net.visible = false
