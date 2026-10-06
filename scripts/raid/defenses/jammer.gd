class_name Jammer
extends Defense
## Drones inside the field lose their bearings: they drift and slow down. Military look:
## an olive equipment box with antenna masts. Lv1 one mast; Lv2 more antenna arms; Lv3 a
## second mast; Lv4 a taller field; Lv5 a third mast and a spinning dish.

var _field: MeshInstance3D
var _dish: Node3D
var _t := 0.0


func _build() -> void:
	var metal := MeshKit.surface("metal", UnitModels.METAL, 0.6, 0.4)
	MeshKit.add(model, MeshKit.box(Vector3(1.6, 1.1, 1.2)), MeshKit.surface("camo", UnitModels.OLIVE, 0.75), Vector3(0, 0.55, 0))
	MeshKit.add(model, MeshKit.box(Vector3(1.62, 0.12, 1.22)), MeshKit.mat(StructureModels.RUST, 0.6), Vector3(0, 0.95, 0))
	var masts := 3 if level >= 5 else (2 if level >= 3 else 1)
	var arms := 4 if level >= 2 else 3
	for i in masts:
		var x := (i - (masts - 1) / 2.0) * 0.6
		var h := 2.2 + (i % 2) * 0.6
		MeshKit.add(model, MeshKit.cyl(0.04, 0.06, h, 6), metal, Vector3(x, 1.1 + h / 2.0, 0))
		for k in arms:
			MeshKit.add(model, MeshKit.box(Vector3(0.5 - k * 0.1, 0.03, 0.03)), metal, Vector3(x, 1.3 + h * 0.75 - k * 0.28, 0))
	if level >= 5:
		_dish = Node3D.new()
		_dish.position = Vector3(0.9, 1.3, 0.5)
		model.add_child(_dish)
		MeshKit.add(_dish, MeshKit.cyl(0.5, 0.15, 0.2, 16), MeshKit.mat(Color(0.85, 0.84, 0.8), 0.5, 0.3)).rotation.x = -1.0
	_field = MeshKit.add(self, MeshKit.sphere(radius, 24), MeshKit.glow(Color(0.6, 0.42, 1.0), 0.07), Vector3(0, roof_y + 1.0, 0))
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _head_height() -> float:
	return 2.5


func tick(delta: float, units: Array) -> void:
	_t += delta
	var s := 1.0 + sin(_t * 3.0) * 0.03
	_field.scale = Vector3(s, 0.3 if level < 4 else 0.4, s)
	if _dish != null:
		_dish.rotation.y += delta * 1.5
	for u: Unit in units:
		if u.flying and not u.dead and in_range(u.global_position):
			u.jammed = true


func disable() -> void:
	super.disable()
	_field.visible = false


func _ring_color() -> Color:
	return Color(0.65, 0.4, 1.0)
