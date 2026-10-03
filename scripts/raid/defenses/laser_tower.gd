class_name LaserTower
extends Defense
## Turret that turns toward the nearest drone and burns it while the beam is on target.
## Until the anti-tank gun and machine-gun nest arrive, it also burns soldiers and tanks.

const TURN_SPEED := 2.6
const AIM_TOLERANCE_DEG := 10.0

var _pivot: Node3D
var _beam: Node3D
var _angle := 0.0


func _build() -> void:
	hits_ground = true
	MeshKit.add(self, MeshKit.sphere(0.9, 16), MeshKit.mat(Color(0.3, 0.32, 0.36), 0.3, 0.7), Vector3(0, head_y, 0))
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, head_y, 0)
	add_child(_pivot)
	MeshKit.add(_pivot, MeshKit.box(Vector3(1.6, 0.35, 0.35)), MeshKit.mat(Color(0.22, 0.24, 0.27), 0.3, 0.7), Vector3(0.8, 0, 0))
	# A unit-length beam along +X, stretched to the target distance each frame.
	_beam = Node3D.new()
	_pivot.add_child(_beam)
	var beam := MeshKit.add(_beam, MeshKit.box(Vector3(1.0, 0.16, 0.16)), MeshKit.glow(Color(1.0, 0.15, 0.15), 0.9), Vector3(0.5, 0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	_angle = randf() * TAU


func tick(delta: float, drones: Array) -> void:
	var target := nearest_drone(drones)
	if target == null:
		_beam.visible = false
		_angle += 0.4 * delta
		_pivot.rotation = Vector3(0, _angle, 0)
		return
	var to := target.global_position - head_position()
	# The pivot's local +X points along (cos a, -sin a) on the ground plane.
	var want := atan2(-to.z, to.x)
	_angle = rotate_toward(_angle, want, TURN_SPEED * delta)
	var flat := Vector2(to.x, to.z).length()
	_pivot.rotation = Vector3(0, _angle, atan2(to.y, flat))
	var aimed := absf(angle_difference(_angle, want)) < deg_to_rad(AIM_TOLERANCE_DEG)
	_beam.visible = aimed
	if aimed:
		_beam.scale.x = to.length()
		target.damage(float(stats.get("dps", 35.0)) * delta)
