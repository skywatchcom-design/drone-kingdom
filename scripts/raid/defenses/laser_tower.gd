class_name LaserTower
extends Defense
## A beam sweeps in a full circle. Staying in the beam drains the drone fast.

const HIT_CONE_DEG := 8.0

var _pivot: Node3D
var _angle := 0.0


func _build() -> void:
	MeshKit.add(self, MeshKit.sphere(0.9, 16), MeshKit.mat(Color(0.3, 0.32, 0.36), 0.3, 0.7), Vector3(0, alt, 0))
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, alt, 0)
	add_child(_pivot)
	var beam := MeshKit.add(_pivot, MeshKit.box(Vector3(radius, 0.18, 0.18)), MeshKit.glow(Color(1.0, 0.15, 0.15), 0.85), Vector3(radius / 2.0, 0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_angle = randf() * TAU


func tick(delta: float, drone: Drone) -> void:
	_angle = wrapf(_angle + float(stats.get("sweep", 1.0)) * delta, 0.0, TAU)
	_pivot.rotation.y = _angle
	if drone == null or drone.dead or not in_range(drone.global_position):
		return
	# The pivot's local +X points along (cos a, -sin a) on the ground plane.
	var beam_dir := Vector2(cos(_angle), -sin(_angle))
	var to_drone := Vector2(drone.global_position.x - global_position.x, drone.global_position.z - global_position.z).normalized()
	if beam_dir.dot(to_drone) > cos(deg_to_rad(HIT_CONE_DEG)):
		drone.damage(float(stats.get("dps", 40.0)) * delta)
