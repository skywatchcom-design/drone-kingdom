class_name MeshKit
extends RefCounted
## Small helpers for building geometry from primitive meshes in code, with the approved B+
## look (sketch 2CogN9cX5xuLj8cwdXBn67): every surface carries a subtle noise texture and
## bump, special surfaces (grass, dirt, concrete, camo, canvas) get their own textures, and
## models built while `grime_root` is set get dust and mud toward the ground.
## Textures are generated noise, projected (triplanar) so no mesh needs UVs.

## While set, meshes added under this node darken toward its origin height, up to
## `grime_top` above it.
static var grime_root: Node3D = null
static var grime_top := 1.2
const GRIME := Color(0.6, 0.52, 0.4)

static var _tex := {}


static func mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = _noise_texture("detail")
	m.normal_enabled = true
	m.normal_texture = _noise_texture("bump")
	m.normal_scale = 0.35
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.6
	return m


## A material with one of the textured surfaces: "grass", "dirt", "concrete", "camo",
## "canvas" or "metal", tinted by `color`. `world` projects in world space (for ground
## pieces that line up across meshes); otherwise per mesh, so moving units don't swim.
static func surface(kind: String, color: Color = Color.WHITE, rough: float = 0.9, metal: float = 0.0, world: bool = false) -> StandardMaterial3D:
	var m := mat(color, rough, metal)
	m.albedo_texture = _noise_texture(kind)
	m.uv1_world_triplanar = world
	match kind:
		"grass":
			m.uv1_scale = Vector3.ONE * 0.035
			m.detail_enabled = true
			m.detail_albedo = _noise_texture("grit")
			m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			m.uv2_triplanar = true
			m.uv2_world_triplanar = true
			m.uv2_scale = Vector3.ONE * 0.5
			m.normal_scale = 0.6
		"dirt":
			m.uv1_scale = Vector3.ONE * 0.12
			m.normal_scale = 0.8
		"concrete":
			m.uv1_scale = Vector3.ONE * 0.25
			m.normal_scale = 0.5
		"camo":
			m.uv1_scale = Vector3.ONE * 0.28
		"canvas":
			m.uv1_scale = Vector3.ONE * 1.4
			m.normal_scale = 0.9
		"metal":
			m.uv1_scale = Vector3.ONE * 0.8
		"net":
			# Camouflage netting: leafy scraps with gaps the light falls through.
			m.uv1_scale = Vector3.ONE * 0.14
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Generated textures, shared and cached. Albedo ones stay light so the material color sets
## the hue; the texture only adds patches, stains and grain.
static func _noise_texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = 4
	n.seed = kind.hash() & 0xffff
	var stops: Array = [[0.0, Color(0.82, 0.82, 0.82)], [1.0, Color.WHITE]]
	var size := 256
	var constant := false
	var as_normal := false
	match kind:
		"detail":
			n.frequency = 0.05
		"bump":
			n.frequency = 0.08
			as_normal = true
		"grit":
			n.frequency = 0.25
			n.fractal_octaves = 2
			stops = [[0.0, Color(0.72, 0.72, 0.72)], [0.5, Color(0.95, 0.95, 0.95)], [1.0, Color.WHITE]]
		"grass":
			size = 512
			n.frequency = 0.012
			stops = [[0.0, Color(0.62, 0.8, 0.52)], [0.35, Color(0.86, 0.98, 0.72)], [0.65, Color(1.0, 1.0, 0.85)], [1.0, Color(1.12, 1.06, 0.72)]]
		"dirt":
			n.frequency = 0.04
			stops = [[0.0, Color(0.74, 0.7, 0.64)], [0.6, Color(0.95, 0.92, 0.86)], [1.0, Color(1.05, 1.02, 0.95)]]
		"concrete":
			n.frequency = 0.03
			n.fractal_octaves = 5
			stops = [[0.0, Color(0.7, 0.68, 0.64)], [0.3, Color(0.9, 0.89, 0.86)], [1.0, Color.WHITE]]
		"camo":
			n.frequency = 0.022
			n.fractal_octaves = 2
			constant = true
			stops = [[0.0, Color(0.72, 0.7, 0.62)], [0.4, Color(0.86, 0.85, 0.78)], [0.62, Color.WHITE]]
		"canvas":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.06
			stops = [[0.0, Color(0.8, 0.78, 0.72)], [1.0, Color.WHITE]]
		"metal":
			n.frequency = 0.02
			stops = [[0.0, Color(0.85, 0.85, 0.85)], [1.0, Color.WHITE]]
		"net":
			n.frequency = 0.09
			n.fractal_octaves = 1
			constant = true
			stops = [[0.0, Color(0.8, 0.78, 0.66)], [0.18, Color(1, 1, 1, 0)], [0.62, Color.WHITE], [0.8, Color(0.86, 0.82, 0.66)]]
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	if as_normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	else:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
		g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
		if constant:
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		t.color_ramp = g
	_tex[kind] = t
	return t


## A soft dark disc on the ground under something, so it looks like it stands there.
static func blob(parent: Node3D, size: Vector2, pos: Vector3 = Vector3.ZERO, strength: float = 0.55) -> MeshInstance3D:
	if not _tex.has("blob"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex["blob"] = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _tex["blob"]
	m.albedo_color = Color(1, 1, 1, strength)
	m.render_priority = -1
	var q := PlaneMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.03, 0)
	parent.add_child(mi)
	return mi


## Adds vertex colors that darken toward the grime root's ground, so walls, hulls and boots
## look dusty at the bottom. `mesh` sits at `pos` under `parent`.
static func _grimed(mesh: Mesh, parent: Node3D, pos: Vector3) -> Mesh:
	if not (mesh is PrimitiveMesh):
		return mesh
	var xf := Transform3D(Basis(), pos)
	var n: Node = parent
	while n != null and n != grime_root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	if n == null:
		return mesh
	var arrays := (mesh as PrimitiveMesh).get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lowest := INF
	for v in verts:
		lowest = minf(lowest, (xf * v).y)
	if lowest > grime_top:
		return mesh
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var k := smoothstep(0.0, grime_top, (xf * verts[i]).y)
		colors[i] = GRIME.lerp(Color.WHITE, k)
	arrays[Mesh.ARRAY_COLOR] = colors
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


## Glossy clear-coated paint (pearl shells, industrial yellow).
static func coat(color: Color, rough: float = 0.3, metal: float = 0.1) -> StandardMaterial3D:
	var m := mat(color, rough, metal)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.1
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 24
	c.rings = 8
	return c


## Unshaded material for beams, rings and UI-like markers in the world.
static func glow(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if grime_root != null and material is StandardMaterial3D and (material as StandardMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		mi.mesh = _grimed(mesh, parent, pos)
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Many copies of one mesh in a single draw call (road dashes, trees, sidewalks).
## `colors`, if given, tints each instance (the material must use vertex color as albedo).
static func multi(parent: Node3D, mesh: Mesh, material: Material, transforms: Array, colors: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	# Instance colors are given in sRGB like every other color in the code.
	if material is StandardMaterial3D and mm.use_colors:
		(material as StandardMaterial3D).vertex_color_is_srgb = true
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(top: float, bottom: float, height: float, segments: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func sphere(radius: float, segments: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = maxi(4, int(segments / 2.0))
	return s


static func ring(radius: float, thickness: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness
	t.outer_radius = radius
	t.rings = 48
	t.ring_segments = 6
	return t
