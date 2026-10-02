class_name City
extends Node3D
## A city block: a 7x7 playable grid of buildings inside a wider ring of streets.
## Every building stands on its own sidewalk plot; asphalt roads with dashed lines and
## crosswalks run between plots; trees, street lamps, parks, parked and moving cars fill
## the streets. Rooftops carry the clutter of a real roof (solar water heaters, AC, tanks).
## Repeated details use MultiMesh so the whole city stays cheap enough for phones.

const GRID := 7
const SPACING := 13.0
const FOOTPRINT := 6.4
const PLOT := 7.8
const PLOT_H := 0.22
const ALT := 24.0
const RING := 4
const MOVING_CARS := 14

const WALL_COLORS := [
	Color(0.88, 0.85, 0.79), Color(0.8, 0.78, 0.74), Color(0.92, 0.9, 0.86),
	Color(0.76, 0.72, 0.66), Color(0.84, 0.8, 0.72), Color(0.86, 0.8, 0.78), Color(0.78, 0.8, 0.82),
]
const CAR_COLORS := [
	Color(0.85, 0.15, 0.12), Color(0.95, 0.95, 0.95), Color(0.12, 0.13, 0.15), Color(0.2, 0.35, 0.7),
	Color(0.7, 0.72, 0.75), Color(0.95, 0.75, 0.1), Color(0.25, 0.5, 0.3),
]

var heights := {}
var _rng := RandomNumberGenerator.new()
var _glass := MeshKit.mat(Color(0.2, 0.26, 0.32), 0.15, 0.3)
var _roof := MeshKit.mat(Color(0.83, 0.64, 0.45), 0.92)
var _white_metal := MeshKit.mat(Color(0.93, 0.93, 0.9), 0.4, 0.3)
var _panel := MeshKit.mat(Color(0.1, 0.16, 0.28), 0.2, 0.4)
var _ac := MeshKit.mat(Color(0.84, 0.84, 0.82), 0.6)
var _dark := MeshKit.mat(Color(0.2, 0.21, 0.23), 0.5, 0.6)
var _cars: Array[Node3D] = []
# Collected while building, then turned into MultiMeshes in one go.
var _balconies: Array = []
var _rails: Array = []
var _trunks: Array = []
var _leaves: Array = []
var _leaf_colors: Array = []
var _poles: Array = []
var _lamps: Array = []


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
	MeshKit.add(self, MeshKit.box(Vector3(600.0, 0.4, 600.0)), MeshKit.mat(Color(0.2, 0.21, 0.23), 0.95), Vector3(0, -0.2, 0))
	_add_streets()
	for c in range(-RING, GRID + RING):
		for r in range(-RING, GRID + RING):
			var cell := [c, r]
			var playable := c >= 0 and c < GRID and r >= 0 and r < GRID
			if playable:
				_add_building(cell, clear.has(_key(cell)))
			elif _rng.randf() < 0.16:
				_add_park(cell)
			else:
				_add_skyline_building(cell)
			_add_corner_details(cell)
	_flush_multimeshes()
	_add_traffic()


func _process(delta: float) -> void:
	var edge := (RING + GRID / 2.0) * SPACING
	for car in _cars:
		var dir: Vector3 = car.get_meta("dir")
		car.position += dir * float(car.get_meta("speed")) * delta
		if absf(car.position.x) > edge:
			car.position.x = -signf(car.position.x) * edge
		if absf(car.position.z) > edge:
			car.position.z = -signf(car.position.z) * edge


# ---------------------------------------------------------------- streets

## Sidewalk plots under every building, dashed center lines, and crosswalks.
func _add_streets() -> void:
	var plots := []
	for c in range(-RING, GRID + RING):
		for r in range(-RING, GRID + RING):
			plots.append(Transform3D(Basis(), cell_pos([c, r]) + Vector3(0, PLOT_H / 2.0, 0)))
	MeshKit.multi(self, MeshKit.box(Vector3(PLOT, PLOT_H, PLOT)), MeshKit.mat(Color(0.7, 0.68, 0.64), 0.9), plots)
	var curbs := []
	for t: Transform3D in plots:
		curbs.append(Transform3D(Basis(), t.origin + Vector3(0, -0.03, 0)))
	MeshKit.multi(self, MeshKit.box(Vector3(PLOT + 0.2, PLOT_H - 0.04, PLOT + 0.2)), MeshKit.mat(Color(0.5, 0.5, 0.5), 0.9), curbs)

	# Road center lines sit halfway between plots, in both directions.
	var lines := []
	for k in range(-RING - 1, GRID + RING):
		lines.append(cell_pos([k, 0]).x + SPACING / 2.0)
	var extent := (RING + GRID / 2.0) * SPACING
	var dashes := []
	for line in lines:
		var p := -extent
		while p < extent:
			var near_crossing := false
			for other in lines:
				if absf(p - other) < 4.2:
					near_crossing = true
					break
			if not near_crossing:
				dashes.append(Transform3D(Basis(), Vector3(line, 0.02, p)))
				dashes.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(p, 0.02, line)))
			p += 2.6
	MeshKit.multi(self, MeshKit.box(Vector3(0.14, 0.02, 1.2)), MeshKit.mat(Color(0.95, 0.85, 0.4), 0.7), dashes)

	# Zebra crossings on all four sides of each intersection inside the playable area.
	var stripes := []
	for i in range(0, GRID + 1):
		for j in range(0, GRID + 1):
			var center := Vector3(lines[RING + i], 0.02, lines[RING + j])
			for s in range(-3, 4):
				var o := s * 0.65
				stripes.append(Transform3D(Basis(), center + Vector3(o, 0, 3.6)))
				stripes.append(Transform3D(Basis(), center + Vector3(o, 0, -3.6)))
				stripes.append(Transform3D(Basis(Vector3.UP, PI / 2.0), center + Vector3(3.6, 0, o)))
				stripes.append(Transform3D(Basis(Vector3.UP, PI / 2.0), center + Vector3(-3.6, 0, o)))
	MeshKit.multi(self, MeshKit.box(Vector3(0.32, 0.02, 1.3)), MeshKit.mat(Color(0.93, 0.93, 0.9), 0.7), stripes)


## Trees and street lamps on the corners of a plot.
func _add_corner_details(cell: Array) -> void:
	var base := cell_pos(cell)
	var inset := PLOT / 2.0 - 0.45
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var spot := base + Vector3(corner.x * inset, PLOT_H, corner.y * inset)
		var roll := _rng.randf()
		if roll < 0.32:
			_tree(spot, _rng.randf_range(0.8, 1.2))
		elif roll < 0.5:
			_poles.append(Transform3D(Basis(), spot + Vector3(0, 1.6, 0)))
			_lamps.append(Transform3D(Basis(), spot + Vector3(0, 3.25, 0)))


func _tree(spot: Vector3, size: float) -> void:
	_trunks.append(Transform3D(Basis().scaled(Vector3.ONE * size), spot + Vector3(0, 0.75 * size, 0)))
	_leaves.append(Transform3D(Basis().scaled(Vector3(1.0, 0.9, 1.0) * size), spot + Vector3(0, 2.0 * size, 0)))
	_leaf_colors.append(Color(0.24, 0.5, 0.22).lerp(Color(0.42, 0.62, 0.25), _rng.randf()))


func _add_park(cell: Array) -> void:
	var base := cell_pos(cell)
	MeshKit.add(self, MeshKit.box(Vector3(PLOT - 0.5, 0.3, PLOT - 0.5)), MeshKit.mat(Color(0.33, 0.55, 0.26), 0.95), base + Vector3(0, PLOT_H + 0.05, 0))
	MeshKit.add(self, MeshKit.box(Vector3(1.0, 0.32, PLOT - 0.5)), MeshKit.mat(Color(0.78, 0.72, 0.6), 0.95), base + Vector3(0, PLOT_H + 0.07, 0))
	for i in _rng.randi_range(3, 6):
		_tree(base + Vector3(_rng.randf_range(-2.8, 2.8), PLOT_H + 0.2, _rng.randf_range(-2.8, 2.8)), _rng.randf_range(0.9, 1.5))


func _add_traffic() -> void:
	var lines := []
	for k in range(-RING - 1, GRID + RING):
		lines.append(cell_pos([k, 0]).x + SPACING / 2.0)
	var extent := (RING + GRID / 2.0) * SPACING
	# Parked cars along the curbs.
	var parked := []
	var parked_colors := []
	for i in 70:
		var line: float = lines[_rng.randi() % lines.size()]
		var along := _rng.randf_range(-extent, extent)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		if _rng.randf() < 0.5:
			parked.append(Transform3D(Basis(), Vector3(line + side * 2.0, 0.3, along)))
		else:
			parked.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(along, 0.3, line + side * 2.0)))
		parked_colors.append(CAR_COLORS[_rng.randi() % CAR_COLORS.size()])
	var paint := MeshKit.mat(Color.WHITE, 0.35, 0.4)
	paint.vertex_color_use_as_albedo = true
	MeshKit.multi(self, MeshKit.box(Vector3(0.95, 0.5, 2.0)), paint, parked, parked_colors)
	var cabins := []
	for t: Transform3D in parked:
		cabins.append(Transform3D(t.basis, t.origin + Vector3(0, 0.38, 0) + t.basis.z * -0.1))
	MeshKit.multi(self, MeshKit.box(Vector3(0.85, 0.32, 1.05)), MeshKit.mat(Color(0.12, 0.15, 0.2), 0.15, 0.4), cabins)
	# A few cars driving in their lanes; they wrap around at the edge of the city.
	for i in MOVING_CARS:
		var car := Node3D.new()
		add_child(car)
		var color: Color = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
		MeshKit.add(car, MeshKit.box(Vector3(0.95, 0.5, 2.0)), MeshKit.mat(color, 0.35, 0.4), Vector3(0, 0.3, 0))
		MeshKit.add(car, MeshKit.box(Vector3(0.85, 0.32, 1.05)), MeshKit.mat(Color(0.12, 0.15, 0.2), 0.15, 0.4), Vector3(0, 0.68, -0.1))
		for x in [-0.3, 0.3]:
			MeshKit.add(car, MeshKit.box(Vector3(0.18, 0.1, 0.04)), MeshKit.glow(Color(1.0, 0.97, 0.85)), Vector3(x, 0.35, 1.01))
			MeshKit.add(car, MeshKit.box(Vector3(0.18, 0.1, 0.04)), MeshKit.glow(Color(0.9, 0.1, 0.1)), Vector3(x, 0.35, -1.01))
		var line: float = lines[_rng.randi() % lines.size()]
		var forward := _rng.randf() < 0.5
		var along_z := _rng.randf() < 0.5
		var lane := 1.0 if forward else -1.0
		if along_z:
			car.position = Vector3(line + lane, 0, _rng.randf_range(-extent, extent))
			car.set_meta("dir", Vector3(0, 0, 1 if forward else -1))
			car.rotation.y = 0.0 if forward else PI
		else:
			car.position = Vector3(_rng.randf_range(-extent, extent), 0, line - lane)
			car.set_meta("dir", Vector3(1 if forward else -1, 0, 0))
			car.rotation.y = PI / 2.0 if forward else -PI / 2.0
		car.set_meta("speed", _rng.randf_range(4.0, 7.0))
		_cars.append(car)


func _flush_multimeshes() -> void:
	var leaf_mat := MeshKit.mat(Color.WHITE, 0.9)
	leaf_mat.vertex_color_use_as_albedo = true
	MeshKit.multi(self, MeshKit.cyl(0.12, 0.16, 1.5, 8), MeshKit.mat(Color(0.4, 0.28, 0.18), 0.9), _trunks)
	MeshKit.multi(self, MeshKit.sphere(1.0, 10), leaf_mat, _leaves, _leaf_colors)
	MeshKit.multi(self, MeshKit.cyl(0.05, 0.07, 3.2, 8), MeshKit.mat(Color(0.25, 0.27, 0.3), 0.4, 0.7), _poles)
	MeshKit.multi(self, MeshKit.sphere(0.18, 8), MeshKit.glow(Color(1.0, 0.92, 0.7)), _lamps)
	MeshKit.multi(self, MeshKit.box(Vector3(FOOTPRINT * 0.7, 0.12, 0.9)), MeshKit.mat(Color(0.9, 0.89, 0.86), 0.8), _balconies)
	var rail := MeshKit.mat(Color(0.75, 0.85, 0.9), 0.2, 0.3)
	rail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rail.albedo_color.a = 0.55
	MeshKit.multi(self, MeshKit.box(Vector3(FOOTPRINT * 0.7, 0.55, 0.04)), rail, _rails)


# ---------------------------------------------------------------- buildings

## A playable building. Styles: plain tower with window bands, balcony block (balconies on
## the two sides the camera sees), or a tower with a set-back top floor.
func _add_building(cell: Array, keep_roof_clear: bool) -> void:
	var h := _rng.randf_range(5.0, 13.0)
	var base := cell_pos(cell) + Vector3(0, PLOT_H, 0)
	heights[_key(cell)] = PLOT_H + h + 0.3
	var wall := MeshKit.mat(WALL_COLORS[_rng.randi() % WALL_COLORS.size()], 0.85)
	MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT, h, FOOTPRINT)), wall, base + Vector3(0, h / 2.0, 0))
	var floors := int((h - 1.5) / 3.0)
	for f in floors:
		MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.06, 0.9, FOOTPRINT + 0.06)), _glass, base + Vector3(0, 1.6 + f * 3.0, 0))
	MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.3, 0.3, FOOTPRINT + 0.3)), _roof, base + Vector3(0, h + 0.15, 0))
	var style := _rng.randf()
	if style < 0.4:
		for f in range(0, floors):
			var y := 1.05 + f * 3.0
			for face in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
				var b := Basis(Vector3.UP, PI / 2.0) if face.x > 0.0 else Basis()
				var out: Vector3 = face * (FOOTPRINT / 2.0 + 0.45)
				_balconies.append(Transform3D(b, base + out + Vector3(0, y, 0)))
				_rails.append(Transform3D(b, base + face * (FOOTPRINT / 2.0 + 0.88) + Vector3(0, y + 0.33, 0)))
	elif style > 0.8 and not keep_roof_clear:
		MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT * 0.55, 2.4, FOOTPRINT * 0.55)), wall, base + Vector3(-0.6, h + 1.5, -0.6))
		MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT * 0.55 + 0.06, 0.8, FOOTPRINT * 0.55 + 0.06)), _glass, base + Vector3(-0.6, h + 1.6, -0.6))
		MeshKit.add(self, MeshKit.box(Vector3(0.9, 0.6, 0.7)), _ac, base + Vector3(1.8, h + 0.6, 1.6))
		return
	if not keep_roof_clear:
		_add_props(base + Vector3(0, h + 0.3, 0))


## Background buildings around the playable grid: darker and simpler, so the play area stands out.
func _add_skyline_building(cell: Array) -> void:
	var h := _rng.randf_range(4.0, 10.0)
	var base := cell_pos(cell) + Vector3(0, PLOT_H, 0)
	var wall := MeshKit.mat(WALL_COLORS[_rng.randi() % WALL_COLORS.size()].darkened(0.3).lerp(Color(0.45, 0.5, 0.58), 0.3), 0.9)
	MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT, h, FOOTPRINT)), wall, base + Vector3(0, h / 2.0, 0))
	MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.06, 0.9, FOOTPRINT + 0.06)), _glass, base + Vector3(0, h - 1.4, 0))
	if _rng.randf() < 0.5:
		MeshKit.add(self, MeshKit.box(Vector3(FOOTPRINT + 0.06, 0.9, FOOTPRINT + 0.06)), _glass, base + Vector3(0, h * 0.5, 0))


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
