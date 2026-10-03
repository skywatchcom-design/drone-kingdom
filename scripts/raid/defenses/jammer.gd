class_name Jammer
extends Defense
## Drones inside the field lose their bearings: they drift and slow down.

var _field: MeshInstance3D
var _t := 0.0


func _build() -> void:
	MeshKit.add(self, MeshKit.cyl(0.6, 0.9, 1.2, 8), MeshKit.mat(Color(0.35, 0.2, 0.5), 0.4, 0.5), Vector3(0, head_y, 0))
	_field = MeshKit.add(self, MeshKit.sphere(radius, 24), MeshKit.glow(Color(0.6, 0.3, 1.0), 0.08), Vector3(0, head_y, 0))
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func tick(delta: float, drones: Array) -> void:
	_t += delta
	var s := 1.0 + sin(_t * 3.0) * 0.03
	_field.scale = Vector3(s, 0.35, s)
	for d: Unit in drones:
		if not d.dead and in_range(d.global_position):
			d.jammed = true


func _ring_color() -> Color:
	return Color(0.65, 0.4, 1.0)
