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
## `pad_cells` get a pad. When `used_cells` is given (the player's own base), only those pads are
## concrete; the free ones are faint gravel plots with white corner stakes, and the base gets
## worn ground under its buildings and a camp around it (lamps, crates, a gate booth...).
func build(seed_value: int, pad_cells: Array, used_cells: Array = []) -> void:
	_rng.seed = seed_value
	MeshKit.add(self, MeshKit.box(Vector3(800.0, 0.4, 800.0)), MeshKit.surface("grass", Color(0.36, 0.46, 0.24), 1.0, 0.0, true), Vector3(0, -0.2, 0))
	_add_compound(pad_cells, used_cells)
	_add_patches(used_cells)
	if not used_cells.is_empty():
		_add_camp()
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

func _add_compound(pad_cells: Array, used_cells: Array = []) -> void:
	var lawn := YARD * 2.0
	MeshKit.add(self, MeshKit.box(Vector3(lawn, 0.06, lawn)), MeshKit.surface("grass", Color(0.4, 0.5, 0.26), 1.0, 0.0, true), Vector3(0, 0.03, 0))
	for c in GRID:
		for r in GRID:
			heights[_key([c, r])] = PAD_H + 0.06
	var pads := []
	var plots := []
	for cell in pad_cells:
		if used_cells.is_empty() or used_cells.has([int(cell[0]), int(cell[1])]):
			pads.append(Transform3D(Basis(), cell_pos(cell) + Vector3(0, 0.06 + PAD_H / 2.0, 0)))
		else:
			plots.append(cell_pos(cell))
	_add_plots(plots)
	# The Compatibility renderer (web) lights flat pale ground much brighter: darker pads there.
	var web := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var pad_colors := []
	pad_colors.resize(pads.size())
	pad_colors.fill(Color(0.45, 0.44, 0.4) if web else Color(0.6, 0.58, 0.54))
	MeshKit.multi(self, MeshKit.box(Vector3(PAD, PAD_H, PAD)), MeshKit.surface("concrete", Color.WHITE, 0.95), pads, pad_colors)
	var borders := []
	for t: Transform3D in pads:
		borders.append(Transform3D(Basis(), t.origin + Vector3(0, -0.02, 0)))
	var border_colors := []
	border_colors.resize(borders.size())
	border_colors.fill(Color(0.33, 0.32, 0.29) if web else Color(0.46, 0.45, 0.41))
	MeshKit.multi(self, MeshKit.box(Vector3(PAD + 0.3, PAD_H - 0.02, PAD + 0.3)), MeshKit.surface("concrete", Color.WHITE, 0.95), borders, border_colors)
	_add_tufts(pad_cells)


## Free building plots: a faint gravel square with a small white stake at each corner, so the
## grid stays readable without looking like a car park.
func _add_plots(centers: Array) -> void:
	if centers.is_empty():
		return
	var gravel := []
	var stakes := []
	for c: Vector3 in centers:
		gravel.append(Transform3D(Basis(), c + Vector3(0, 0.075, 0)))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				stakes.append(Transform3D(Basis(), c + Vector3(sx * (PAD / 2.0 - 0.15), 0.3, sz * (PAD / 2.0 - 0.15))))
	var g := MeshKit.multi(self, MeshKit.box(Vector3(PAD, 0.03, PAD)), MeshKit.surface("concrete", Color(0.5, 0.52, 0.4) if RenderingServer.get_current_rendering_method() != "gl_compatibility" else Color(0.4, 0.43, 0.32), 1.0, 0.0, true), gravel)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.multi(self, MeshKit.box(Vector3(0.14, 0.5, 0.14)), MeshKit.mat(Color(0.93, 0.92, 0.88), 0.6), stakes)


## Soft patches on the ground: worn dirt under the buildings, and lighter and darker grass
## around, so the field isn't one flat green.
func _add_patches(used_cells: Array) -> void:
	for cell in used_cells:
		_patch(cell_pos(cell), PAD + 3.4, Color(0.5, 0.42, 0.3), 0.75)
	for i in 70:
		var p := Vector3(_rng.randf_range(-90.0, 90.0), 0, _rng.randf_range(-90.0, 90.0))
		var light := _rng.randf() < 0.5
		_patch(p, _rng.randf_range(8.0, 20.0), Color(0.52, 0.6, 0.3) if light else Color(0.22, 0.34, 0.14), 0.32)
	for i in 14:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(YARD + 6.0, YARD + 30.0)
		_patch(Vector3(cos(a) * d, 0, sin(a) * d), _rng.randf_range(4.0, 9.0), Color(0.55, 0.46, 0.33), 0.6)


func _patch(pos: Vector3, size: float, color: Color, alpha: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _soft_patch()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = 1.0
	var mi := MeshKit.add(self, quad, m, Vector3(pos.x, 0.07 + _rng.randf() * 0.01, pos.z))
	mi.rotation = Vector3(-PI / 2.0, _rng.randf() * TAU, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _patch_tex: ImageTexture


## A soft, slightly lumpy round mask for ground patches.
static func _soft_patch() -> ImageTexture:
	if _patch_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var p := Vector2(x, y) - Vector2(n, n) / 2.0
				var r := p.length() / (n * 0.5)
				var wobble := 0.08 * sin(atan2(p.y, p.x) * 5.0) + 0.05 * sin(atan2(p.y, p.x) * 11.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - r - wobble) * 1.6, 0.0, 1.0)))
		_patch_tex = ImageTexture.create_from_image(img)
	return _patch_tex


## The camp around the player's base, just outside the jeep's lap: lamp posts, crates and
## barrels, sandbags, a water tower, a camouflaged store and a guard booth with a barrier at the
## gate. Lamp bulbs carry the "blink"-free "lamp" meta so BaseLife can make them flicker.
func _add_camp() -> void:
	var edge := YARD + 6.0
	var wood := MeshKit.surface("wood", Color(0.62, 0.48, 0.3), 0.9) if MeshKit.PHOTO_SCALE.has("wood") else MeshKit.mat(Color(0.62, 0.48, 0.3), 0.9)
	var olive := MeshKit.mat(Color(0.33, 0.37, 0.22), 0.8, 0.1)
	var steel := MeshKit.surface("metal", Color(0.42, 0.44, 0.45), 0.5, 0.6)
	var sand := MeshKit.mat(Color(0.74, 0.66, 0.48), 0.95)
	# Lamp posts on the corners and the middle of each side.
	for k in 8:
		var a := k * TAU / 8.0 + PI / 4.0
		var r := edge + 1.5 if k % 2 == 0 else edge
		var p := Vector3(cos(a), 0, sin(a)) * r
		if absf(p.x) < 6.0 and p.z > 0.0:
			continue
		MeshKit.add(self, MeshKit.cyl(0.09, 0.12, 4.6, 8), steel, p + Vector3(0, 2.3, 0))
		MeshKit.add(self, MeshKit.box(Vector3(0.9, 0.08, 0.12)), steel, p + Vector3(0, 4.55, 0))
		var bulb := MeshKit.add(self, MeshKit.box(Vector3(0.36, 0.14, 0.3)), MeshKit.glow(Color(1.0, 0.86, 0.55)), p + Vector3(0.36, 4.45, 0))
		bulb.set_meta("lamp", true)
		_patch(p, 5.0, Color(1.0, 0.85, 0.55), 0.18)
	# Crates and barrels in little stacks.
	for spot: Vector3 in [Vector3(-edge, 0, -14), Vector3(edge, 0, 12), Vector3(-12, 0, -edge), Vector3(16, 0, -edge), Vector3(-edge, 0, 18)]:
		for i in 4:
			var off := Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, 1.6))
			var s := _rng.randf_range(0.8, 1.2)
			var crate := MeshKit.add(self, MeshKit.box(Vector3.ONE * s), wood, spot + off + Vector3(0, s / 2.0, 0))
			crate.rotation.y = _rng.randf() * TAU
		for i in 3:
			var b := spot + Vector3(_rng.randf_range(-2.6, 2.6), 0.55, _rng.randf_range(-2.6, 2.6))
			MeshKit.add(self, MeshKit.cyl(0.38, 0.38, 1.1, 12), olive if i % 2 == 0 else MeshKit.mat(Color(0.62, 0.2, 0.14), 0.7, 0.2), b)
	# Sandbag walls guarding the corners.
	for k in 4:
		var c := Vector3(signf(cos(k * PI / 2.0 + PI / 4.0)), 0, signf(sin(k * PI / 2.0 + PI / 4.0))) * (edge + 4.5)
		for i in 7:
			for layer in 2:
				var bag := MeshKit.add(self, MeshKit.sphere(0.5, 8), sand, c + Vector3((i - 3) * 0.85 + layer * 0.4, 0.3 + layer * 0.45, 0))
				bag.scale = Vector3(1.0, 0.55, 0.7)
	# A water tower behind the base.
	var wt := Vector3(edge + 4.0, 0, -edge - 2.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MeshKit.add(self, MeshKit.cyl(0.12, 0.12, 6.0, 6), steel, wt + Vector3(sx * 1.2, 3.0, sz * 1.2))
	MeshKit.add(self, MeshKit.cyl(1.9, 1.9, 2.6, 16), MeshKit.mat(Color(0.86, 0.85, 0.8), 0.6, 0.2), wt + Vector3(0, 7.3, 0))
	MeshKit.add(self, MeshKit.cyl(0.2, 2.0, 0.7, 16), MeshKit.mat(Color(0.6, 0.22, 0.16), 0.6), wt + Vector3(0, 8.95, 0))
	# A camouflaged store with crates under the net.
	var store := Node3D.new()
	store.position = Vector3(-edge - 3.0, 0, 6.0)
	add_child(store)
	StructureModels.camo_net(store, 7.0, 5.0, 2.6)
	for i in 3:
		MeshKit.add(store, MeshKit.box(Vector3(1.2, 1.0, 1.0)), wood, Vector3(-1.8 + i * 1.6, 0.5, 0))
	# Gate: a guard booth with a lit window and a striped barrier across the road.
	var gz := YARD + 5.0
	MeshKit.add(self, MeshKit.box(Vector3(2.2, 2.4, 2.2)), MeshKit.mat(Color(0.84, 0.82, 0.74), 0.8), Vector3(5.6, 1.2, gz))
	MeshKit.add(self, MeshKit.box(Vector3(2.6, 0.2, 2.6)), olive, Vector3(5.6, 2.5, gz))
	MeshKit.add(self, MeshKit.box(Vector3(1.2, 0.6, 0.05)), MeshKit.glow(Color(1.0, 0.86, 0.55)), Vector3(5.6, 1.6, gz - 1.12))
	MeshKit.add(self, MeshKit.box(Vector3(0.3, 1.1, 0.3)), steel, Vector3(3.6, 0.55, gz))
	for i in 6:
		var stripe := MeshKit.add(self, MeshKit.box(Vector3(1.1, 0.16, 0.16)), MeshKit.mat(Color(0.85, 0.2, 0.16) if i % 2 == 0 else Color(0.95, 0.95, 0.92), 0.6), Vector3(3.0 - i * 1.1, 1.05, gz))
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Short grass tufts on the lawn between the pads, and wild ones outside.
func _add_tufts(pad_cells: Array) -> void:
	var blade := MeshKit.cyl(0.02, 0.1, 0.6, 4)
	var xfs := []
	var colors := []
	var shades := [Color(0.2, 0.32, 0.12), Color(0.25, 0.37, 0.14), Color(0.3, 0.4, 0.16), Color(0.18, 0.28, 0.1)]
	var tries := 0
	while xfs.size() < 2200 and tries < 12000:
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
