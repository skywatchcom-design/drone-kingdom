class_name Defense
extends Node3D
## Base for rooftop defenses. The node sits at street level under its building; its mast
## rises a few meters above the roof to the head, where the range ring is drawn.

var radius := 10.0
var roof_y := 0.0
var head_y := 0.0
var stats := {}
var disabled := false
## Whether this defense can hit soldiers and tanks; most only hit drones.
var hits_ground := false
var _ring: MeshInstance3D
var _mast: MeshInstance3D


func setup(p_stats: Dictionary, p_roof_y: float) -> void:
	stats = p_stats
	radius = float(stats.get("radius", 10.0))
	roof_y = p_roof_y
	head_y = roof_y + Catalog.DEFENSE_HEAD
	_build_mast()
	_build()
	_ring = MeshKit.add(self, MeshKit.ring(radius, 0.25), MeshKit.glow(_ring_color(), 0.5), Vector3(0, head_y, 0))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if stats.has("level"):
		StructureModels.level_label(self, int(stats["level"]), head_y + 1.6).position.x = 1.6


func show_range(on: bool) -> void:
	_ring.visible = on


func flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func in_range(p: Vector3, margin: float = 0.0) -> bool:
	return flat_distance(p) <= radius + margin


func head_position() -> Vector3:
	return global_position + Vector3(0, head_y, 0)


## Closest living unit in range, or null.
func nearest_drone(drones: Array) -> Unit:
	var best: Unit = null
	var best_d := INF
	for d: Unit in drones:
		if d.dead:
			continue
		var dist := flat_distance(d.global_position)
		if dist <= radius and dist < best_d:
			best_d = dist
			best = d
	return best


## Called every frame with the units it can hit (empty at home): drones in the air, plus
## ground units when hits_ground is on.
func tick(_delta: float, _drones: Array) -> void:
	pass


## Knocked out in battle: everything but a leaning mast disappears.
func disable() -> void:
	disabled = true
	for child in get_children():
		if child is Node3D and child != _mast:
			child.visible = false
	if _mast != null:
		_mast.rotation.z = 0.35


func _build_mast() -> void:
	var h := head_y - 0.5 - roof_y
	_mast = MeshKit.add(self, MeshKit.cyl(0.3, 0.5, h, 10), MeshKit.mat(Color(0.35, 0.38, 0.42), 0.5, 0.5), Vector3(0, roof_y + h / 2.0, 0))


func _build() -> void:
	pass


func _ring_color() -> Color:
	return Color(1.0, 0.35, 0.3)
