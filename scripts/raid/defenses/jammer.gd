class_name Jammer
extends Defense
## Inside the field, manual controls are reversed and the autopilot wanders.

var _field: MeshInstance3D
var _t := 0.0


func _build() -> void:
	MeshKit.add(self, MeshKit.cyl(0.6, 0.9, 1.2, 8), MeshKit.mat(Color(0.35, 0.2, 0.5), 0.4, 0.5), Vector3(0, alt, 0))
	_field = MeshKit.add(self, MeshKit.sphere(radius, 24), MeshKit.glow(Color(0.6, 0.3, 1.0), 0.08), Vector3(0, alt, 0))
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func tick(delta: float, drone: Drone) -> void:
	_t += delta
	var s := 1.0 + sin(_t * 3.0) * 0.03
	_field.scale = Vector3(s, 0.25, s)
	if drone != null and not drone.dead and in_range(drone.global_position):
		drone.jammed = true


func _ring_color() -> Color:
	return Color(0.65, 0.4, 1.0)
