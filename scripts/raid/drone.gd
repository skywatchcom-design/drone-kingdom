class_name Drone
extends Unit
## An attack drone. Movement comes from steer(); the body tilts from its own acceleration.
## Each kind has its own model (DroneModels) and signature motion:
##   courier: unfolds its arms on release; the gimbal camera stays level; the lens flashes per shot
##   scout:   flies nose-down, leaves a teal trail, does a 360 degree flip when it picks a new target
##   heavy:   lowers a weight on its winch and drops it; reels the cable back in
## With `showcase` on (hangar preview) it hovers on a turntable and loops its signature moves.

const ACCEL := 14.0
const SPIN := {"courier": 48.0, "scout": 85.0, "heavy": 24.0}
const TRAIL_POINTS := 18

var max_speed := 10.0
var body_scale := 1.6
var level := 1
var gear_height := 1.0
## Hangar preview: no flight, signature moves on a loop.
var showcase := false

# Battle state, driven by the raid.
var dps := 20.0
var prefers := "any"
var orbit := randf() * TAU
var hover_radius := 4.5
var hover_height := 6.5
## A burst of `burst` shots `burst_gap` apart, then `fire_interval` until the next burst.
var fire_interval := 0.3
var burst := 1
var burst_gap := 0.1
var fire_cooldown := randf() * 0.3
var shots_left := 0
var dust_cooldown := 0.0

var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _rpm := 0.0
var _time := 0.0
var _fall_speed := 0.0
var _accel := Vector3.ZERO
var _body: Node3D
var _parts: Dictionary
var _net: MeshInstance3D
var _unfold := 0.0
var _flip := -1.0
var _flash := 0.0
var _since_drop := 10.0
var _showcase_y := 0.0
var _trail_im: ImmediateMesh
var _trail_mesh: MeshInstance3D
var _trail_points := PackedVector3Array()


## Apply a drone type's stats (from Catalog.drone_stats). Call before adding to the tree.
func configure(stats: Dictionary) -> void:
	kind = stats.get("kind", "courier")
	max_speed = float(stats["speed"])
	max_health = float(stats["health"])
	health = max_health
	level = int(stats.get("level", 1))
	# Higher levels are visibly bigger.
	body_scale = float(stats["scale"]) * (0.85 + 0.1 * level)
	dps = float(stats.get("dps", dps))
	prefers = stats.get("prefers", prefers)
	fire_interval = float(stats.get("fire", fire_interval))
	burst = int(stats.get("burst", 1))
	var hover: Array = stats.get("hover", [hover_radius, hover_height])
	hover_radius = float(hover[0])
	hover_height = float(hover[1])


func _ready() -> void:
	_body = Node3D.new()
	_body.scale = Vector3.ONE * body_scale
	add_child(_body)
	_parts = DroneModels.build(kind, _body)
	DroneModels.add_level(kind, _body, level, _parts)
	# A ring in the level color around the drone.
	var ring := MeshKit.add(_body, MeshKit.ring(0.95 if kind != "heavy" else 1.4, 0.05), MeshKit.glow(UnitModels.LEVEL_COLORS[clampi(level, 1, 5) - 1], 0.85), Vector3(0, -0.12, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gear_height = float(_parts["bottom"]) * body_scale
	_net = MeshKit.add(_body, MeshKit.sphere(1.0, 12), MeshKit.glow(Color(0.92, 0.96, 1.0), 0.35))
	_net.visible = false
	_showcase_y = position.y
	if kind == "scout":
		_trail_im = ImmediateMesh.new()
		_trail_mesh = MeshInstance3D.new()
		_trail_mesh.mesh = _trail_im
		_trail_mesh.material_override = MeshKit.glow(Color(0.0, 1.0, 0.82), 0.55)
		_trail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail_mesh.top_level = true
		add_child(_trail_mesh)
	if showcase:
		_unfold = 1.0
		_rpm = 1.0


# ---------------------------------------------------------------- battle API

func steer(target_velocity: Vector3, delta: float) -> void:
	if dead:
		return
	var limit := max_speed * (0.3 if net_timer > 0.0 else 1.0)
	target_velocity = target_velocity.limit_length(limit)
	var previous := velocity
	velocity = velocity.move_toward(target_velocity, ACCEL * delta)
	position += velocity * delta
	var accel := (velocity - previous) / maxf(delta, 0.0001)
	_accel = _accel.lerp(accel, 1.0 - exp(-delta * 6.0))


## True once the drone is ready to attack (the courier waits until its arms are open).
func can_fire() -> bool:
	return not dead and (kind != "courier" or _unfold > 0.95)


## Where shots (or the dropped weight) leave the drone, in world space.
func fire_origin() -> Vector3:
	match kind:
		"courier":
			return (_parts["lens"] as Node3D).global_position
		"heavy":
			return (_parts["weight"] as Node3D).global_position
	return _body.to_global(_parts["fire_point"])


## Visual reaction to firing: lens flash, or the winch letting go of its weight.
func on_fire() -> void:
	match kind:
		"courier":
			_flash = 1.0
		"heavy":
			_since_drop = 0.0


func on_new_target() -> void:
	if kind == "scout" and _flip < 0.0:
		_flip = 0.0


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	_time += delta
	net_timer = maxf(0.0, net_timer - delta)
	_net.visible = net_timer > 0.0
	if dead:
		_crash_fall(delta)
		_animate_parts(delta)
		return
	if showcase:
		_showcase(delta)
	else:
		_fly_pose(delta)
	_animate_parts(delta)


func _fly_pose(delta: float) -> void:
	_unfold = move_toward(_unfold, 1.0, delta / 0.8)
	_rpm = lerpf(_rpm, _unfold if kind == "courier" else 1.0, 1.0 - exp(-delta * 3.0))
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.4:
		_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 1.0 - exp(-delta * 4.0))
	var tilt := RaidRules.bank_angles(_accel, velocity, _yaw)
	_pitch = lerpf(_pitch, tilt.x + (0.25 if kind == "scout" else 0.0), 1.0 - exp(-delta * 5.0))
	_roll = lerpf(_roll, tilt.y, 1.0 - exp(-delta * 5.0))
	var shake := 0.08 if jammed else 0.0
	rotation = Vector3(_pitch + randf_range(-shake, shake), _yaw, _roll + _flip_roll(delta) + randf_range(-shake, shake))
	var bob := 0.07 if kind == "heavy" else 0.04
	_body.position = Vector3(sin(_time * 1.7), sin(_time * (1.2 if kind == "heavy" else 2.3)) * 2.0, cos(_time * 1.3)) * bob


## Hangar turntable: the drone hovers in place and loops its signature move.
func _showcase(delta: float) -> void:
	rotation.y += delta * 0.5
	position.y = _showcase_y + sin(_time * 1.5) * 0.08
	match kind:
		"courier":
			var cycle := fmod(_time, 9.0)
			var open := 1.0
			if cycle > 6.0 and cycle < 7.6:
				open = 1.0 - _ease(clampf((cycle - 6.0) / 0.8, 0.0, 1.0))
			elif cycle >= 7.6:
				open = _ease(clampf((cycle - 7.8) / 0.8, 0.0, 1.0))
			_unfold = open
			_rpm = lerpf(_rpm, open, 1.0 - exp(-delta * 6.0))
			rotation.x = 0.05
			fire_cooldown -= delta
			if fire_cooldown <= 0.0 and open > 0.99:
				fire_cooldown = 1.2
				on_fire()
		"scout":
			if fmod(_time, 4.0) < delta:
				on_new_target()
			rotation.x = 0.3
			rotation.z = _flip_roll(delta)
		"heavy":
			fire_cooldown -= delta
			if fire_cooldown <= 0.0:
				fire_cooldown = 2.4
				on_fire()


func _flip_roll(delta: float) -> float:
	if _flip < 0.0:
		return 0.0
	_flip += delta / 0.6
	if _flip >= 1.0:
		_flip = -1.0
		return 0.0
	return _ease(_flip) * TAU


func _animate_parts(delta: float) -> void:
	var speed: float = SPIN.get(kind, 40.0)
	var props: Array = _parts["props"]
	for i in props.size():
		(props[i] as Node3D).rotation.y += (1.0 if i % 2 == 0 else -1.0) * _rpm * speed * delta
	for disc: MeshInstance3D in _parts["discs"]:
		(disc.material_override as StandardMaterial3D).albedo_color.a = clampf((_rpm - 0.3) * 0.3, 0.0, 0.2)
	var blink := int(_time * 1.4) % 2 == 0
	for light: Node3D in _parts["blinkers"]:
		light.visible = blink
	match kind:
		"courier":
			_animate_courier(delta)
		"scout":
			_animate_scout()
		"heavy":
			_animate_heavy(delta)


## Arms fold back along the body when closed and swing out to 35 degrees when open.
func _animate_courier(delta: float) -> void:
	var k := _ease(_unfold)
	for hinge: Node3D in _parts["arms"]:
		var sx: float = hinge.get_meta("sx")
		var sz: float = hinge.get_meta("sz")
		var side := sx if sz > 0.0 else -sx
		hinge.rotation.y = side * (0.62 + (1.0 - k) * (PI - 0.87))
	var gimbal: Node3D = _parts["gimbal"]
	gimbal.rotation = Vector3(-rotation.x, sin(_time * 0.8) * 0.5 if showcase else 0.0, -rotation.z)
	_flash = maxf(0.0, _flash - delta * 4.0)
	((_parts["lens"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = _flash


func _animate_scout() -> void:
	var under: MeshInstance3D = _parts["glow"]
	(under.material_override as StandardMaterial3D).albedo_color.a = 0.4 + sin(_time * 6.0) * 0.15
	if _trail_im == null or showcase:
		return
	_trail_points.insert(0, global_position + Vector3(0, -0.1, 0))
	if _trail_points.size() > TRAIL_POINTS:
		_trail_points.resize(TRAIL_POINTS)
	_trail_im.clear_surfaces()
	if dead or _trail_points.size() < 2 or Vector2(velocity.x, velocity.z).length() < 4.0:
		return
	_trail_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_points.size():
		var width := 0.35 * (1.0 - float(i) / TRAIL_POINTS)
		_trail_im.surface_add_vertex(_trail_points[i] + Vector3(0, width, 0))
		_trail_im.surface_add_vertex(_trail_points[i] - Vector3(0, width, 0))
	_trail_im.surface_end()


## Winch: after a drop the cable reels in, then pays out again as the next drop comes up.
func _animate_heavy(delta: float) -> void:
	_since_drop += delta
	var lower := 0.0
	if _since_drop < 0.9:
		lower = 1.05 * (1.0 - _since_drop / 0.9)
	else:
		var span := 2.4 if showcase else fire_interval
		lower = 1.05 * _ease(clampf(1.0 - fire_cooldown / maxf(span * 0.6, 0.1), 0.0, 1.0))
	var cable: MeshInstance3D = _parts["cable"]
	cable.scale.y = 0.1 + lower
	cable.position.y = -0.8 - lower / 2.0
	var weight: Node3D = _parts["weight"]
	weight.visible = _since_drop > 0.9
	weight.position = Vector3(0, -0.95 - lower, 0)
	weight.rotation = Vector3(-rotation.x * 0.6, sin(_time * 1.3) * 0.3, -rotation.z * 0.6)


func _crash_fall(delta: float) -> void:
	_rpm = lerpf(_rpm, 0.0, 1.0 - exp(-delta * 3.0))
	if position.y <= 0.6:
		return
	_fall_speed += 20.0 * delta
	position.y = maxf(0.6, position.y - _fall_speed * delta)
	rotation.z += delta * 4.0
	rotation.x += delta * 2.0


static func _ease(k: float) -> float:
	return 4.0 * k * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 3.0) / 2.0
