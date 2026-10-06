class_name City
extends Node3D
## The world: a flat drone compound in the countryside. A 9x9 grid of stone pads on a
## trimmed lawn, with a dirt road leading in. Players fence it themselves with walls on the
## paths between pads (see Walls). Around it:
## meadows with trees, bushes and rocks, a winding stream, striped farm fields, wind
## turbines and low hills fading into the haze. Everything sits on the ground, so every
## structure and every defense range is visible at a glance.
## Repeated details use MultiMesh so the scene stays cheap enough for phones.

const GRID := 9
const SPACING := 7.5
const PAD := 5.4
const PAD_H := 0.12
const ALT := 12.0
## Half the width of the fenced compound.
const YARD := GRID * SPACING / 2.0 + 2.0
const TURBINES := 3

var heights := {}
var _rng := RandomNumberGenerator.new()
var _spinning: Array[Node3D] = []
var _trunks: Array = []
var _leaves: Array = []
var _leaf_colors: Array = []
var _pines: Array = []
var _pine_colors: Array = []
var _bushes: Array = []
var _rocks: Array = []
var _stream: Array = []
var _blobs: Array = []


static func cell_pos(cell: Array) -> Vector3:
	var half := (GRID - 1) / 2.0
	return Vector3((float(cell[0]) - half) * SPACING, 0.0, (float(cell[1]) - half) * SPACING)


## Height of the pad a structure stands on.
func roof_y(cell: Array) -> float:
	return float(heights.get(_key(cell), PAD_H))


func roof_top(cell: Array) -> Vector3:
	var p := cell_pos(cell)
	p.y = roof_y(cell)
	return p


## `pad_cells` lists the cells that get a stone pad: every slot at home (so the player sees
## where to build), only the occupied ones in a raid.
func build(seed_value: int, pad_cells: Array) -> void:
	_rng.seed = seed_value
	MeshKit.add(self, MeshKit.box(Vector3(800.0, 0.4, 800.0)), MeshKit.surface("grass", Color(0.36, 0.46, 0.24), 1.0, 0.0, true), Vector3(0, -0.2, 0))
	_add_compound(pad_cells)
	_add_stream()
	_add_fields()
	_add_road()
	_add_turbines()
	_add_hills()
	_scatter_nature()
	_flush_multimeshes()


func _process(delta: float) -> void:
	for rotor in _spinning:
		rotor.rotation.z += delta * float(rotor.get_meta("speed"))


# ---------------------------------------------------------------- compound

func _add_compound(pad_cells: Array) -> void:
	var lawn := YARD * 2.0
	MeshKit.add(self, MeshKit.box(Vector3(lawn, 0.06, lawn)), MeshKit.surface("grass", Color(0.4, 0.5, 0.26), 1.0, 0.0, true), Vector3(0, 0.03, 0))
	for c in GRID:
		for r in GRID:
			heights[_key([c, r])] = PAD_H + 0.06
	var pads := []
	for cell in pad_cells:
		pads.append(Transform3D(Basis(), cell_pos(cell) + Vector3(0, 0.06 + PAD_H / 2.0, 0)))
	MeshKit.multi(self, MeshKit.box(Vector3(PAD, PAD_H, PAD)), MeshKit.surface("concrete", Color(0.58, 0.56, 0.5), 0.95, 0.0, true), pads)
	var borders := []
	for t: Transform3D in pads:
		borders.append(Transform3D(Basis(), t.origin + Vector3(0, -0.02, 0)))
	MeshKit.multi(self, MeshKit.box(Vector3(PAD + 0.3, PAD_H - 0.02, PAD + 0.3)), MeshKit.surface("concrete", Color(0.47, 0.46, 0.4), 0.95, 0.0, true), borders)
	_add_tufts(pad_cells)


## Short grass tufts on the lawn between the pads, and wild ones outside.
func _add_tufts(pad_cells: Array) -> void:
	var blade := MeshKit.cyl(0.02, 0.1, 0.6, 4)
	var xfs := []
	var colors := []
	var shades := [Color(0.33, 0.47, 0.2), Color(0.39, 0.53, 0.23), Color(0.48, 0.56, 0.27), Color(0.3, 0.44, 0.19)]
	var tries := 0
	while xfs.size() < 3600 and tries < 12000:
		tries += 1
		var p := Vector3(_rng.randf_range(-YARD - 30.0, YARD + 30.0), 0, _rng.randf_range(-YARD - 30.0, YARD + 30.0))
		var on_pad := false
		for cell in pad_cells:
			var c := cell_pos(cell)
			if absf(p.x - c.x) < PAD / 2.0 + 0.2 and absf(p.z - c.z) < PAD / 2.0 + 0.2:
				on_pad = true
				break
		if on_pad or (absf(p.x) < 4.0 and p.z > YARD - 3.0):
			continue
		var h := _rng.randf_range(0.5, 1.3)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3)).scaled(Vector3(1, h, 1))
		xfs.append(Transform3D(b, p + Vector3(0, 0.06 + 0.4 * h, 0)))
		colors.append(shades[xfs.size() % shades.size()])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var mi := MeshKit.multi(self, blade, m, xfs, colors)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF



func _add_road() -> void:
	var dirt := MeshKit.surface("dirt", Color(0.66, 0.55, 0.4), 1.0, 0.0, true)
	MeshKit.add(self, MeshKit.box(Vector3(6.0, 0.05, 120.0)), dirt, Vector3(0, 0.025, YARD + 60.0))
	MeshKit.add(self, MeshKit.box(Vector3(7.0, 0.06, 4.0)), dirt, Vector3(0, 0.03, YARD - 1.0))


# ---------------------------------------------------------------- countryside

## A winding stream west of the compound, built from short overlapping segments.
func _add_stream() -> void:
	var water := MeshKit.mat(Color(0.25, 0.52, 0.72), 0.08, 0.2)
	var bank := MeshKit.mat(Color(0.78, 0.72, 0.55), 0.95)
	var z := -120.0
	while z < 120.0:
		var x := -YARD - 20.0 + sin(z * 0.045) * 7.0
		var next_x := -YARD - 20.0 + sin((z + 3.0) * 0.045) * 7.0
		var angle := atan2(next_x - x, 3.0)
		var b := Basis(Vector3.UP, angle)
		MeshKit.add(self, MeshKit.box(Vector3(9.5, 0.04, 3.4)), bank, Vector3(x, 0.02, z)).basis = b
		MeshKit.add(self, MeshKit.box(Vector3(6.0, 0.06, 3.4)), water, Vector3(x, 0.05, z)).basis = b
		_stream.append(Vector2(x, z))
		z += 3.0


## Striped farm fields east of the compound.
func _add_fields() -> void:
	var rows := []
	var colors := []
	var palettes := [[Color(0.86, 0.74, 0.35), Color(0.8, 0.67, 0.3)], [Color(0.42, 0.62, 0.25), Color(0.36, 0.55, 0.22)], [Color(0.55, 0.42, 0.28), Color(0.48, 0.36, 0.24)]]
	var fz := -YARD
	while fz < YARD + 30.0:
		var pal: Array = palettes[_rng.randi() % palettes.size()]
		var fx := YARD + 14.0 + _rng.randf_range(0.0, 4.0)
		var depth := _rng.randf_range(14.0, 20.0)
		var width := _rng.randf_range(22.0, 32.0)
		var stripe := 0.0
		var i := 0
		while stripe < depth:
			rows.append(Transform3D(Basis().scaled(Vector3(width, 1, 1)), Vector3(fx + width / 2.0, 0.06, fz + stripe)))
			colors.append(pal[i % 2])
			stripe += 1.2
			i += 1
		fz += depth + 3.0
	var paint := MeshKit.mat(Color.WHITE, 0.95)
	paint.vertex_color_use_as_albedo = true
	MeshKit.multi(self, MeshKit.box(Vector3(1.0, 0.12, 1.2)), paint, rows, colors)


func _add_turbines() -> void:
	var white := MeshKit.mat(Color(0.94, 0.95, 0.96), 0.4, 0.2)
	for i in TURBINES:
		var base := Vector3(YARD + 30.0 + i * 14.0, 0, -YARD - 18.0 - i * 9.0)
		MeshKit.add(self, MeshKit.cyl(0.35, 0.6, 18.0, 12), white, base + Vector3(0, 9.0, 0))
		var hub := Node3D.new()
		hub.position = base + Vector3(0, 18.2, 0.6)
		add_child(hub)
		MeshKit.add(hub, MeshKit.sphere(0.6, 12), white)
		for b in 3:
			var arm := Node3D.new()
			arm.rotation.z = TAU * b / 3.0
			hub.add_child(arm)
			MeshKit.add(arm, MeshKit.box(Vector3(0.5, 7.0, 0.12)), white, Vector3(0, 3.6, 0))
		hub.set_meta("speed", _rng.randf_range(0.6, 1.0))
		_spinning.append(hub)


func _add_hills() -> void:
	for i in 10:
		var a := TAU * i / 10.0 + _rng.randf_range(-0.2, 0.2)
		var d := _rng.randf_range(110.0, 150.0)
		var hill := MeshKit.add(self, MeshKit.sphere(1.0, 20), MeshKit.surface("grass", Color(0.42, 0.6, 0.3).lerp(Color(0.5, 0.64, 0.36), _rng.randf()), 1.0, 0.0, true), Vector3(cos(a) * d, -6.0, sin(a) * d))
		hill.scale = Vector3(_rng.randf_range(40.0, 70.0), _rng.randf_range(14.0, 24.0), _rng.randf_range(30.0, 50.0))


## Trees, pines, bushes and rocks everywhere outside the fence except the stream,
## the fields and the road.
func _scatter_nature() -> void:
	var placed := 0
	var tries := 0
	while placed < 260 and tries < 3000:
		tries += 1
		var p := Vector3(_rng.randf_range(-100.0, 100.0), 0, _rng.randf_range(-100.0, 100.0))
		if not _free_ground(p):
			continue
		placed += 1
		var roll := _rng.randf()
		var size := _rng.randf_range(0.8, 1.4)
		if roll < 0.4:
			_trunks.append(Transform3D(Basis().scaled(Vector3.ONE * size), p + Vector3(0, 0.75 * size, 0)))
			# A crown of several leafy clumps in slightly different greens.
			var base := Color(0.24, 0.48, 0.2).lerp(Color(0.42, 0.6, 0.24), _rng.randf())
			for k in 5:
				var off := Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.3, 0.7), _rng.randf_range(-0.7, 0.7)) * size
				var r := _rng.randf_range(0.6, 0.95) * size * 1.15
				if k == 0:
					off = Vector3.ZERO
					r = size * 1.2
				_leaves.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.0, 0.85, 1.0) * r), p + Vector3(0, 2.2 * size, 0) + off))
				_leaf_colors.append(base.lightened(_rng.randf_range(-0.08, 0.12)))
			_blobs.append(Transform3D(Basis().scaled(Vector3.ONE * size * 3.4), p + Vector3(0, 0.05, 0)))
		elif roll < 0.7:
			_pines.append(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.0) * size), p + Vector3(0, 2.4 * size, 0)))
			_blobs.append(Transform3D(Basis().scaled(Vector3.ONE * size * 2.8), p + Vector3(0, 0.05, 0)))
			_pine_colors.append(Color(0.14, 0.36, 0.2).lerp(Color(0.22, 0.45, 0.25), _rng.randf()))
			_trunks.append(Transform3D(Basis().scaled(Vector3(0.7, 0.6, 0.7) * size), p + Vector3(0, 0.45 * size, 0)))
		elif roll < 0.88:
			_bushes.append(Transform3D(Basis().scaled(Vector3(1.0, 0.7, 1.0) * size), p + Vector3(0, 0.4 * size, 0)))
		else:
			var r := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.2, 0.6, 0.9) * size)
			_rocks.append(Transform3D(r, p + Vector3(0, 0.25 * size, 0)))


func _free_ground(p: Vector3) -> bool:
	if absf(p.x) < YARD + 3.0 and absf(p.z) < YARD + 3.0:
		return false
	if absf(p.x) < 5.5 and p.z > YARD:
		return false
	if p.x > YARD + 12.0 and p.x < YARD + 54.0 and p.z > -YARD - 2.0 and p.z < YARD + 52.0:
		return false
	for s: Vector2 in _stream:
		if absf(s.y - p.z) < 3.0 and absf(s.x - p.x) < 6.5:
			return false
	return true


func _flush_multimeshes() -> void:
	var leaf_mat := MeshKit.mat(Color.WHITE, 0.9)
	leaf_mat.vertex_color_use_as_albedo = true
	MeshKit.multi(self, MeshKit.cyl(0.14, 0.2, 1.5, 8), MeshKit.mat(Color(0.42, 0.29, 0.18), 0.9), _trunks)
	MeshKit.multi(self, MeshKit.sphere(1.0, 12), leaf_mat, _leaves, _leaf_colors)
	# Soft shade under the trees: one blob quad per tree, in a single draw call.
	var shade := MeshKit.blob(self, Vector2.ONE, Vector3.ZERO, 0.45)
	var shades := MeshKit.multi(self, shade.mesh, shade.material_override, _blobs)
	shades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.queue_free()
	MeshKit.multi(self, MeshKit.cyl(0.0, 1.3, 3.6, 10), leaf_mat, _pines, _pine_colors)
	MeshKit.multi(self, MeshKit.sphere(0.9, 8), MeshKit.mat(Color(0.3, 0.5, 0.22), 0.9), _bushes)
	MeshKit.multi(self, MeshKit.sphere(0.8, 7), MeshKit.surface("concrete", Color(0.62, 0.6, 0.56), 0.95), _rocks)


func _key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]
