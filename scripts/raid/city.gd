class_name City
extends Node3D
## A 7x7 block of rooftops built from primitives: plaster walls, window bands,
## and the clutter of a real roof (solar water heaters, AC units, tanks, antennas).

const GRID := 7
const SPACING := 9.0
const FOOTPRINT := 6.4
const ALT := 24.0

const WALL_COLORS := [
	Color(0.86, 0.83, 0.77), Color(0.78, 0.76, 0.72), Color(0.9, 0.88, 0.84),
	Color(0.74, 0.7, 0.64), Color(0.82, 0.78, 0.7),
]

var heights := {}
var _rng := RandomNumberGenerator.new()
var _glass := MeshKit.mat(Color(0.2, 0.26, 0.32), 0.15, 0.3)
var _roof := MeshKit.mat(Color(0.6, 0.58, 0.55), 0.92)
var _white_metal := MeshKit.mat(Color(0.93, 0.93, 0.9), 0.4, 0.3)
var _panel := MeshKit.mat(Color(0.1, 0.16, 0.28), 0.2, 0.4)
var _ac := MeshKit.mat(Color(0.84, 0.84, 0.82), 0.6)
var _dark := MeshKit.mat(Color(0.2, 0.21, 0.23), 0.5, 0.6)


static func cell_pos(cell: Array) -> Vector3:
	var half := (GRID - 1) / 2.0
	return Vector3((float(cell[0]) - half) * SPACING, 0.0, (float(cell[1]) - half) * SPACING)


func roof_y(cell: Array) -> float:
	return float(heights.get(_key(cell), 0.0))


func roof_top(cell: Array) -> Vector3:
	var p := cell_pos(cell)
	p.y = roof_y(cell)
	return p


## `keep_clear` lists cells that get no rooftop clutter (home pad, loot, defenses).
func build(seed_value: int, keep_clear: Array) -> void:
	_rng.seed = seed_value
	var clear := {}
	for c in keep_clear:
		clear[_key(c)] = true
	MeshKit.add(self, MeshKit.box(Vector3(600.0, 0.4, 600.0)), MeshKit.mat(Color(0.33, 0.35, 0.38), 0.95), Vector3(0, -0.2, 0))
	_add_skyline()
	for c in GRID:
		for r in GRID:
			var cell := [c, r]
			var h := _rng.randf_range(6.0, 16.0)
			heights[_key(cell)] = h + 0.3
			var base := cell_pos(cell)
			var wall := MeshKit.mat(WALL_COLORS[_rng.randi() % WALL_COLORS.size()], 0.85)
			MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT, h, FOOTPRINT)), wall, base + Vector3(0, h / 2.0, 0))
			for f in int((h - 1.5) / 3.0):
				MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.06, 0.9, FOOTPRINT + 0.06)), _glass, base + Vector3(0, 1.6 + f * 3.0, 0))
			MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.3, 0.3, FOOTPRINT + 0.3)), _roof, base + Vector3(0, h + 0.15, 0))
			if not clear.has(_key(cell)):
				_add_props(base + Vector3(0, h + 0.3, 0))


## Plain blocks around the playable grid so the city doesn't end at a cliff.
func _add_skyline() -> void:
	var ring := 4
	for c in range(-ring, GRID + ring):
		for r in range(-ring, GRID + ring):
			if c >= 0 and c < GRID and r >= 0 and r < GRID:
				continue
			var h := _rng.randf_range(4.0, 13.0)
			var base := cell_pos([c, r])
			var wall := MeshKit.mat(WALL_COLORS[_rng.randi() % WALL_COLORS.size()].darkened(0.08), 0.9)
			MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT, h, FOOTPRINT)), wall, base + Vector3(0, h / 2.0, 0))
			MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.06, 0.9, FOOTPRINT + 0.06)), _glass, base + Vector3(0, h - 1.4, 0))


func _add_props(top: Vector3) -> void:
	if _rng.randf() < 0.55:
		var tank := MeshKit.add(self, MeshKit.cyl(0.45, 0.45, 1.6, 14), _white_metal, top + Vector3(-1.2, 1.3, -1.6))
		tank.rotation.z = PI / 2.0
		var panel := MeshKit.add(self, MeshKit.box(Vector3(1.8, 0.08, 1.2)), _panel, top + Vector3(-1.2, 0.6, -0.4))
		panel.rotation.x = -0.6
	if _rng.randf() < 0.6:
		MeshKit.add(self, MeshKit.box(Vector3(0.9, 0.6, 0.7)), _ac, top + Vector3(1.6, 0.3, 1.4))
	if _rng.randf() < 0.35:
		MeshKit.add(self, MeshKit.cyl(0.05, 0.05, 3.0, 6), _dark, top + Vector3(2.2, 1.5, -2.2))
	if _rng.randf() < 0.25:
		MeshKit.add(self, MeshKit.cyl(0.8, 0.8, 1.4, 16), _dark, top + Vector3(1.6, 0.7, -1.4))


func _key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]
