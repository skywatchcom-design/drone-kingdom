class_name Defense
extends Node3D
## Base for rooftop defenses. The node sits at street level under its building;
## its mast reaches from the roof up to flight altitude, where the danger ring is drawn.

var radius := 10.0
var roof_y := 0.0
var alt := 24.0
var stats := {}
var _ring: MeshInstance3D


func setup(p_stats: Dictionary, p_roof_y: float, p_alt: float) -> void:
	stats = p_stats
	radius = float(stats.get("radius", 10.0))
	roof_y = p_roof_y
	alt = p_alt
	_build_mast()
	_build()
	_ring = MeshKit.add(self, MeshKit.ring(radius, 0.25), MeshKit.glow(_ring_color(), 0.55), Vector3(0, alt, 0))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if stats.has("level"):
		StructureModels.level_label(self, int(stats["level"]), roof_y + 3.0).position.x = 2.0


func show_range(on: bool) -> void:
	_ring.visible = on


func flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func in_range(p: Vector3, margin: float = 0.0) -> bool:
	return flat_distance(p) <= radius + margin


## Called every frame. `drone` is null while the player is still planning.
func tick(_delta: float, _drone: Drone) -> void:
	pass


func _build_mast() -> void:
	var h := alt - 1.0 - roof_y
	MeshKit.add(self, MeshKit.cyl(0.35, 0.55, h, 10), MeshKit.mat(Color(0.35, 0.38, 0.42), 0.5, 0.5), Vector3(0, roof_y + h / 2.0, 0))


func _build() -> void:
	pass


func _ring_color() -> Color:
	return Color(1.0, 0.35, 0.3)
