class_name Defense
extends Node3D
## Base for defenses (approved sketch MTz3BL4Yz9u3mj78fV3NZr). Each stands on its pad and
## builds its model for its level: big steps at levels 3 and 5, a bit bigger every level, and
## one chevron per level on its plate. Stats["vs"] says how hard it hits soldiers, tanks and
## drones; it aims at what it is best against, then whatever is closest.

const MODEL_SCALE := 1.6

var radius := 10.0
var roof_y := 0.0
## Height of the weapon above the ground, where shots leave from.
var head_y := 1.5
var stats := {}
var level := 1
var disabled := false
const GROUND_RING := Color(0.45, 0.95, 0.35)
const AIR_RING := Color(0.4, 0.75, 1.0)
const DEAD_ZONE := Color(1.0, 0.3, 0.25)

var _ring: Node3D
## Everything visible, scaled; subclasses build into it.
var model: Node3D


func setup(p_stats: Dictionary, p_roof_y: float) -> void:
	stats = p_stats
	radius = float(stats.get("radius", 10.0))
	level = int(stats.get("level", 1))
	roof_y = p_roof_y
	model = Node3D.new()
	model.position.y = roof_y
	model.scale = Vector3.ONE * MODEL_SCALE * (1.0 + 0.03 * (level - 1))
	add_child(model)
	MeshKit.blob(self, Vector2(6.4, 6.4), Vector3(0, roof_y, 0), 0.5)
	MeshKit.grime_root = model
	MeshKit.grime_top = 0.8
	_build()
	MeshKit.grime_root = null
	head_y = roof_y + _head_height() * model.scale.y
	StructureModels.chevrons(model, level, Vector3(1.85, 0, 1.85))
	# The range shows what the defense hits (approved sketch FXGoTcv7xRzZbR5GDqE6S3): green for
	# the ground, blue for the air, with the mortar's dead zone in red.
	_ring = Node3D.new()
	_ring.position.y = roof_y + 0.15
	add_child(_ring)
	var color := _ring_color()
	MeshKit.add(_ring, MeshKit.ring(radius, 0.3), MeshKit.glow(color, 0.7))
	MeshKit.add(_ring, MeshKit.cyl(radius, radius, 0.02, 48), MeshKit.glow(color, 0.12), Vector3(0, -0.1, 0))
	var min_r := float(stats.get("min_radius", 0.0))
	if min_r > 0.0:
		MeshKit.add(_ring, MeshKit.ring(min_r, 0.25), MeshKit.glow(DEAD_ZONE, 0.8))
		MeshKit.add(_ring, MeshKit.cyl(min_r, min_r, 0.02, 32), MeshKit.glow(DEAD_ZONE, 0.25), Vector3(0, -0.05, 0))
	for m in _ring.get_children():
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Hidden until the player taps this defense (owner feedback: rings everywhere are noise).
	_ring.visible = false
	StructureModels.level_label(self, level, head_y + 2.6)


func show_range(on: bool) -> void:
	_ring.visible = on


## True when this defense is meant for drones (AA, jammer) rather than soldiers and tanks.
func hits_air() -> bool:
	var vs: Dictionary = stats.get("vs", {})
	return float(vs.get("air", 1.0 if vs.is_empty() else 0.0)) >= 0.9


func flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func in_range(p: Vector3, margin: float = 0.0) -> bool:
	return flat_distance(p) <= radius + margin


func head_position() -> Vector3:
	return global_position + Vector3(0, head_y, 0)


## Damage multiplier against this unit: soldiers, tanks and drones each have their own.
func factor(u: Unit) -> float:
	var vs: Dictionary = stats.get("vs", {})
	if u.flying:
		return float(vs.get("air", 0.0))
	if u is GroundUnit and (u as GroundUnit).is_tank():
		return float(vs.get("tank", 0.0))
	return float(vs.get("soldier", 0.0))


## The unit to shoot: in range (and beyond the minimum range, for the mortar), the kind this
## defense is best against first, then the closest. Null if there is none.
func pick_target(units: Array) -> Unit:
	var best: Unit = null
	var best_f := 0.0
	var best_d := INF
	var min_r := float(stats.get("min_radius", 0.0))
	for u: Unit in units:
		if u.dead:
			continue
		var f := factor(u)
		if f <= 0.0:
			continue
		var d := flat_distance(u.global_position)
		if d > radius or d < min_r:
			continue
		if f > best_f + 0.01 or (absf(f - best_f) <= 0.01 and d < best_d):
			best = u
			best_f = f
			best_d = d
	return best


## Turns `pivot` toward `point` at `speed` radians a second. True once it is lined up.
func turn_toward(pivot: Node3D, point: Vector3, speed: float, delta: float) -> bool:
	var to := point - global_position
	var want := atan2(to.x, to.z)
	pivot.rotation.y = rotate_toward(pivot.rotation.y, want, speed * delta)
	return absf(angle_difference(pivot.rotation.y, want)) < 0.12


## Where a shot at `u` lands: its body, not its feet.
static func aim_point(u: Unit) -> Vector3:
	if u.flying:
		return u.global_position
	return u.global_position + Vector3(0, 2.0 if (u is GroundUnit and (u as GroundUnit).is_tank()) else 1.4, 0)


## Called every frame with every unit in the battle (empty at home).
func tick(_delta: float, _units: Array) -> void:
	pass


## Knocked out in battle: the model disappears (the raid leaves rubble).
func disable() -> void:
	disabled = true
	model.visible = false
	_ring.visible = false


func _build() -> void:
	pass


func _head_height() -> float:
	return 1.0


func _ring_color() -> Color:
	return AIR_RING if hits_air() else GROUND_RING


## Battle effects go into the level, beside the defense.
func _fx_parent() -> Node3D:
	var p := get_parent() as Node3D
	return p if p != null else self
