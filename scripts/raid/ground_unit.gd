class_name GroundUnit
extends Unit
## A soldier (infantry or engineer) or a tank. Moves with walk(), aims with aim_at(); the raid
## decides where to go and when to fire. Signature motions from the approved sketch:
##   infantry:  advances, stops in range, every other soldier kneels, short bursts with tracers
##   engineers: runs to the fence, kneels to plant a charge, runs back before it blows
##   tank:      turret swings to the target, muzzle flash, the gun recoils, dust while driving
## Casualties: a soldier vanishes and leaves a small helmet that rolls on the ground; a tank
## stays as a burnt-out hull with fire and smoke.
## With `showcase` on (Garage preview) it stays in place and loops its signature motion.

const ACCEL := 18.0
const TURN := 8.0

var max_speed := 4.5
var dps := 9.0
var fire_interval := 0.4
var attack_range := 6.0
var prefers := "any"
var model_scale := 2.2
var level := 1
var fire_cooldown := randf() * 0.4
## Whether this soldier kneels to fire (every other infantry soldier does).
var kneels := false
var showcase := false

# Engineers: "" until they set off for the fence, then "going", "planting", "clear", "done".
var breach_state := ""
var breach_point := Vector3.ZERO
var breach_timer := 0.0
## Where the unit is heading this frame, so it can be shown kneeling once it stops.
var firing := false

var _model: Node3D
var _parts: Dictionary
var _time := randf() * 10.0
var _phase := 0.0
var _kneel := 0.0
var _yaw := 0.0
var _turret_yaw := 0.0
var _recoil := 0.0
var _burn: Node3D
var _burn_timer := 0.0
var _dust_timer := 0.0


func configure(stats: Dictionary) -> void:
	kind = stats.get("kind", "infantry")
	flying = false
	max_speed = float(stats["speed"])
	max_health = float(stats["health"])
	health = max_health
	dps = float(stats["dps"])
	fire_interval = float(stats.get("fire", fire_interval))
	attack_range = float(stats.get("range", attack_range))
	prefers = stats.get("prefers", prefers)
	level = int(stats.get("level", 1))
	# Higher levels are visibly bigger.
	model_scale = (1.15 * (0.9 + 0.05 * level)) if kind == "armor" else (2.2 * (0.9 + 0.06 * level))


func _ready() -> void:
	_model = Node3D.new()
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	MeshKit.grime_root = _model
	MeshKit.grime_top = 0.7 if kind == "armor" else 0.32
	_parts = UnitModels.build(kind, _model, level)
	MeshKit.grime_root = null
	var r := body_radius()
	MeshKit.blob(self, Vector2(r, r) * 2.8, Vector3.ZERO, 0.45)
	# A ring in the level color underfoot (defenders wear a red one instead).
	if not has_meta("home") and not showcase:
		var ring := MeshKit.add(self, MeshKit.ring(body_radius() + 0.35, 0.1), MeshKit.glow(UnitModels.LEVEL_COLORS[clampi(level, 1, 5) - 1], 0.85), Vector3(0, 0.07, 0))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yaw = rotation.y
	rotation.y = 0.0


func is_tank() -> bool:
	return kind == "armor"


## Rough body radius, for spacing units apart.
func body_radius() -> float:
	return 2.4 if is_tank() else 0.9


## World position shots leave from.
func fire_origin() -> Vector3:
	return (_parts["muzzle"] as Node3D).global_position


## Moves toward `desired` velocity (meters per second on the ground plane).
func walk(desired: Vector3, delta: float) -> void:
	if dead:
		return
	desired.y = 0.0
	desired = desired.limit_length(max_speed)
	velocity = velocity.move_toward(desired, ACCEL * delta)
	position += velocity * delta
	position.y = 0.0
	var speed := velocity.length()
	if speed > 0.3:
		_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 1.0 - exp(-delta * TURN))
	firing = false


## Turns to face a point (soldiers turn their body, the tank swings its turret).
func aim_at(point: Vector3, delta: float) -> void:
	var to := point - global_position
	var want := atan2(to.x, to.z)
	if is_tank():
		_turret_yaw = lerp_angle(_turret_yaw, want - _yaw, 1.0 - exp(-delta * 2.5))
	else:
		_yaw = lerp_angle(_yaw, want, 1.0 - exp(-delta * TURN))
	firing = true


## True when the tank's turret has come round to `point` (soldiers are always ready).
func aimed_at(point: Vector3) -> bool:
	if not is_tank():
		return true
	var to := point - global_position
	return absf(angle_difference(_yaw + _turret_yaw, atan2(to.x, to.z))) < 0.15


func on_fire() -> void:
	_recoil = 1.0


func _process(delta: float) -> void:
	_time += delta
	net_timer = 0.0
	if dead:
		_animate_burning(delta)
		return
	if showcase:
		_showcase(delta)
	_model.rotation.y = _yaw
	if is_tank():
		_animate_tank(delta)
	else:
		_animate_soldier(delta)


func _animate_soldier(delta: float) -> void:
	var speed := velocity.length()
	var moving := speed > 0.4
	var want_kneel := 1.0 if (kneels or kind == "engineers") and firing and not moving else 0.0
	if kind == "engineers" and breach_state == "planting":
		want_kneel = 1.0
	_kneel = move_toward(_kneel, want_kneel, delta * 3.5)
	_phase += delta * speed * 2.6
	var amount := clampf(speed / maxf(max_speed, 0.1), 0.0, 1.0)
	var hips: Array = _parts["hips"]
	var k := _ease(_kneel)
	(hips[0] as Node3D).rotation.x = sin(_phase) * 0.6 * amount - 1.2 * k
	(hips[1] as Node3D).rotation.x = -sin(_phase) * 0.6 * amount + 0.4 * k
	var torso: Node3D = _parts["torso"]
	torso.position.y = 0.5 + absf(sin(_phase)) * 0.03 * amount - 0.2 * k
	torso.rotation.x = 0.05 * k + 0.12 * amount
	# A generated soldier walks on its leg skeleton: thighs swing, the knee of the leg going
	# back bends, and kneeling folds one leg forward and the other down.
	var sk: Skeleton3D = _parts.get("skeleton")
	if sk != null:
		# Full stride from a slow walk up: the step length should not depend on top speed.
		amount = clampf(speed / 0.9, 0.0, 1.0)
		var swing := sin(_phase) * 0.6 * amount
		_leg(sk, 1, -swing - 1.3 * k)
		_leg(sk, 2, swing + 0.35 * k)
		_leg(sk, 3, maxf(0.0, cos(_phase)) * 0.6 * amount + 1.3 * k)
		_leg(sk, 4, maxf(0.0, -cos(_phase)) * 0.6 * amount + 1.6 * k)
		torso.position.y = 0.5 + absf(sin(_phase)) * 0.03 * amount - 0.15 * k
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	torso.position.z = -0.03 * _recoil


func _leg(sk: Skeleton3D, bone: int, angle: float) -> void:
	sk.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, angle))


func _animate_tank(delta: float) -> void:
	var speed := velocity.length()
	for wheel: Node3D in _parts["wheels"]:
		wheel.rotation.x += speed * delta / 0.3
	(_parts["turret"] as Node3D).rotation.y = _turret_yaw
	_recoil = maxf(0.0, _recoil - delta * 2.2)
	(_parts["gun"] as Node3D).position.z = 1.0 - _recoil * 0.45
	_model.rotation.x = -_recoil * 0.03
	_model.position.y = sin(_time * 14.0) * 0.015 if speed > 0.3 else 0.0
	if speed > 0.5 and not showcase:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.12
			var back := global_position - Vector3(sin(_yaw), 0, cos(_yaw)) * 3.0
			_puff(back + Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)), Color(0.8, 0.75, 0.62), 0.9, 0.7)


## Garage preview: soldiers kneel and fire on a loop, the tank swings its turret and fires.
func _showcase(delta: float) -> void:
	var cycle := fmod(_time, 4.0)
	velocity = Vector3.ZERO
	firing = cycle > 1.0
	if is_tank():
		_turret_yaw = sin(_time * 0.6) * 0.8
		if fmod(_time, 3.0) < delta:
			on_fire()
	elif firing and fmod(_time, 0.5) < delta:
		on_fire()
	_yaw += delta * 0.4


## A soldier is down: the body disappears and the helmet tumbles off and rolls to a stop.
## A tank is knocked out: it goes dark and keeps burning.
func knock_out(parent: Node3D) -> void:
	if is_tank():
		for mi in _all_meshes(_model):
			var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.albedo_color = m.albedo_color.darkened(0.7)
			mi.material_override = m
		_burn = Node3D.new()
		add_child(_burn)
		var fire := MeshKit.add(_burn, MeshKit.sphere(0.8, 10), MeshKit.glow(Color(1.0, 0.5, 0.15), 0.85), Vector3(0, 2.0, -0.3))
		fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	var helmet_node: Node3D = _parts["helmet"]
	var start := helmet_node.global_position
	_model.visible = false
	var helmet := MeshKit.add(parent, MeshKit.sphere(0.135 * model_scale, 12), MeshKit.mat(UnitModels.OLIVE_DARK, 0.85), start)
	helmet.scale = Vector3(1, 0.72, 1.08)
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var rest := Vector3(start.x, 0.15, start.z) + dir * randf_range(1.2, 2.2)
	var tween := helmet.create_tween()
	tween.set_parallel(true)
	tween.tween_property(helmet, "position", Vector3(lerpf(start.x, rest.x, 0.4), start.y + 0.4, lerpf(start.z, rest.z, 0.4)), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(helmet, "rotation", Vector3(dir.z * 7.0, 0, -dir.x * 7.0), 0.9)
	tween.chain().tween_property(helmet, "position", rest, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _animate_burning(delta: float) -> void:
	if _burn == null:
		return
	var flicker := 1.0 + sin(_time * 23.0) * 0.15 + randf_range(-0.1, 0.1)
	(_burn.get_child(0) as Node3D).scale = Vector3.ONE * flicker
	_burn_timer -= delta
	if _burn_timer <= 0.0:
		_burn_timer = 0.25
		_puff(global_position + Vector3(randf_range(-0.6, 0.6), 2.4, randf_range(-0.8, 0.4)), Color(0.22, 0.22, 0.22), 1.4, 2.4)


## A puff of dust or smoke that rises, grows and fades.
func _puff(pos: Vector3, color: Color, size: float, life: float) -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var puff := MeshKit.add(parent, MeshKit.sphere(size * 0.5, 8), MeshKit.glow(color, 0.55), pos)
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "position:y", pos.y + life * 1.6, life)
	tween.tween_property(puff, "scale", Vector3.ONE * 2.5, life)
	tween.tween_property(puff.material_override, "albedo_color:a", 0.0, life)
	tween.chain().tween_callback(puff.queue_free)


static func _all_meshes(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_all_meshes(child))
	return out


static func _ease(k: float) -> float:
	return 4.0 * k * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 3.0) / 2.0
