class_name Fx
extends RefCounted
## Short-lived battle effects that clean up after themselves: tracers, muzzle flashes,
## explosions, smoke, fire and shells in flight. Each one is added under `parent` (the battle
## level). Fire and smoke are camera-facing soft puffs (textures made in code, no assets), so
## they read as clouds rather than balls; they work on the web (Compatibility) renderer too.

static var _soft: ImageTexture
static var _cloud: ImageTexture
static var _scorch: ImageTexture


static func flash(parent: Node3D, pos: Vector3, size: float, color: Color = Color(1.0, 0.9, 0.55)) -> void:
	var m := _puff(parent, pos, size * 3.0, color, true, _soft_tex())
	var tween := m.create_tween()
	tween.set_parallel(true)
	tween.tween_property(m, "scale", Vector3.ONE * 1.8, 0.09)
	tween.tween_property(m.material_override, "albedo_color:a", 0.0, 0.09)
	tween.chain().tween_callback(m.queue_free)


## A thin streak of light from `from` to `to` that fades fast.
static func tracer(parent: Node3D, from: Vector3, to: Vector3, color: Color, width: float = 0.06, life: float = 0.08) -> void:
	var dir := to - from
	if dir.length() < 0.1:
		return
	var m := MeshKit.add(parent, MeshKit.cyl(width, width, 1.0, 5), MeshKit.glow(color, 0.9))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1)), from + dir * 0.5)
	var tween := m.create_tween()
	tween.tween_property(m.material_override, "albedo_color:a", 0.0, life)
	tween.tween_callback(m.queue_free)


## An explosion: a white flash, a rolling fireball of soft puffs, sparks, debris that flies up
## and falls, a dust ring, dark smoke that rises and spreads, a scorch mark that stays a while,
## and (for big ones) a short camera shake.
static func boom(parent: Node3D, pos: Vector3, power: float) -> void:
	var ground := Vector3(pos.x, 0.0, pos.z)
	flash(parent, pos + Vector3(0, 0.6, 0), 1.6 * power, Color(1.0, 0.97, 0.85))
	# Fireball: hot puffs that swell, drift up and cool from yellow to deep red.
	for i in 9:
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.8), randf_range(-1.0, 1.0)) * power
		var p := _puff(parent, pos + Vector3(0, 0.6 * power, 0) + off * 0.6, randf_range(2.8, 4.0) * power,
			Color(1.0, 0.86, 0.4), i == 0, _cloud_tex())
		var life := randf_range(0.35, 0.6)
		var t := p.create_tween()
		t.set_parallel(true)
		t.tween_property(p, "scale", Vector3.ONE * randf_range(1.6, 2.3), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(p, "position", p.position + off, life)
		t.tween_property(p.material_override, "albedo_color", Color(0.75, 0.16, 0.04, 0.0), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(p.queue_free)
	# Sparks and debris on short arcs.
	for i in int(6 + 4 * power):
		var spark := MeshKit.add(parent, MeshKit.box(Vector3(0.06, 0.06, 0.32)), MeshKit.glow(Color(1.0, 0.75, 0.3)), pos + Vector3(0, 0.4, 0))
		_fly(spark, randf_range(4.0, 7.0) * power, randf_range(0.35, 0.6), true)
	for i in int(4 + 3 * power):
		var chunk := MeshKit.add(parent, MeshKit.box(Vector3.ONE * randf_range(0.15, 0.32) * power),
			MeshKit.mat(Color(0.25, 0.23, 0.2).lerp(Color(0.45, 0.4, 0.33), randf()), 0.9), pos + Vector3(0, 0.4, 0))
		_fly(chunk, randf_range(2.5, 4.5) * power, randf_range(0.7, 1.0), false)
	# Dust ring along the ground.
	var ring := MeshKit.add(parent, MeshKit.ring(1.0, 0.25), MeshKit.glow(Color(0.82, 0.76, 0.62), 0.45), ground + Vector3(0, 0.08, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3.ONE * 0.3
	var rt := ring.create_tween()
	rt.set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(4.0, 1, 4.0) * power, 0.7).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.7)
	rt.chain().tween_callback(ring.queue_free)
	# Smoke that rises, spreads and thins out after the fire.
	for i in int(7 + 4 * power):
		smoke(parent, pos + Vector3(randf_range(-1.2, 1.2) * power, 0.8 * power, randf_range(-1.2, 1.2) * power),
			power * randf_range(1.8, 2.6), randf_range(0.15, 0.45), Color(0.16, 0.15, 0.14))
	scorch(parent, ground, 1.6 * power)
	if power >= 1.0:
		shake(parent, 0.18 * power)


## One soft smoke puff that rises and spreads; `delay` holds it back a little.
static func smoke(parent: Node3D, pos: Vector3, size: float, delay: float = 0.0, color: Color = Color(0.32, 0.31, 0.3)) -> void:
	var p := _puff(parent, pos, size * 1.6, Color(color.r, color.g, color.b, 0.0), false, _cloud_tex())
	p.rotation.z = randf() * TAU
	var life := randf_range(2.0, 3.0)
	var drift := Vector3(randf_range(-0.6, 0.6), randf_range(3.0, 4.6), randf_range(-0.6, 0.6)) * clampf(size, 0.6, 1.8)
	var t := p.create_tween()
	t.tween_interval(delay)
	t.tween_property(p.material_override, "albedo_color:a", 0.8, 0.2)
	t.tween_property(p, "scale", Vector3.ONE * 2.6, life).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p, "position", p.position + drift, life).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p.material_override, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(p.queue_free)


## A lick of flame that flickers up and fades (called again and again on burning buildings).
static func flame(parent: Node3D, pos: Vector3, size: float) -> void:
	var p := _puff(parent, pos, size, Color(1.0, 0.78, 0.3), false, _cloud_tex())
	var t := p.create_tween()
	t.set_parallel(true)
	t.tween_property(p, "position:y", pos.y + size * 1.3, 0.5)
	t.tween_property(p, "scale", Vector3(0.45, 0.8, 0.45), 0.5)
	t.tween_property(p.material_override, "albedo_color", Color(0.85, 0.18, 0.04, 0.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(p.queue_free)


## A dark burn mark on the ground that fades away slowly.
static func scorch(parent: Node3D, ground: Vector3, size: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _scorch_tex()
	mat.albedo_color = Color(0.08, 0.06, 0.05, 0.85)
	var m := MeshKit.add(parent, quad, mat, ground + Vector3(0, 0.06 + randf() * 0.02, 0))
	m.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t := m.create_tween()
	t.tween_interval(14.0)
	t.tween_property(mat, "albedo_color:a", 0.0, 6.0)
	t.tween_callback(m.queue_free)


## Shakes the camera a little (by its offsets, so it never fights the panning).
static func shake(parent: Node3D, strength: float) -> void:
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam == null or cam.has_meta("shaking"):
		return
	cam.set_meta("shaking", true)
	var t := cam.create_tween()
	for i in 6:
		var k := 1.0 - i / 6.0
		t.tween_property(cam, "h_offset", randf_range(-1, 1) * strength * k, 0.035)
		t.parallel().tween_property(cam, "v_offset", randf_range(-1, 1) * strength * k, 0.035)
	t.tween_property(cam, "h_offset", 0.0, 0.04)
	t.parallel().tween_property(cam, "v_offset", 0.0, 0.04)
	t.tween_callback(func() -> void: cam.remove_meta("shaking"))


## A glowing shell that flies straight to `to` in `time` seconds, then calls `on_hit`.
static func shell(parent: Node3D, from: Vector3, to: Vector3, time: float, on_hit: Callable) -> void:
	var m := MeshKit.add(parent, MeshKit.sphere(0.28, 8), MeshKit.glow(Color(1.0, 0.8, 0.4)), from)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := m.create_tween()
	tween.tween_property(m, "global_position", to, time)
	tween.tween_callback(func() -> void:
		m.queue_free()
		on_hit.call())


## A mortar round: rises in a high arc and lands at `to` after `time` seconds.
static func lob(parent: Node3D, from: Vector3, to: Vector3, time: float, on_hit: Callable) -> void:
	var m := MeshKit.add(parent, MeshKit.sphere(0.22, 8), MeshKit.glow(Color(1.0, 0.82, 0.55)), from)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := m.create_tween()
	tween.tween_method(func(k: float) -> void:
		var p := from.lerp(to, k)
		p.y += sin(k * PI) * 14.0
		m.global_position = p, 0.0, 1.0, time)
	tween.tween_callback(func() -> void:
		m.queue_free()
		on_hit.call())


# ---------------------------------------------------------------- pieces

## A camera-facing quad with a soft texture; `add` makes it glow (fire), otherwise it shades
## like smoke.
static func _puff(parent: Node3D, pos: Vector3, size: float, color: Color, add: bool, tex: Texture2D) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = color
	var m := MeshKit.add(parent, quad, mat, pos)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Throws a piece up and out on an arc that falls under gravity, spinning, then removes it.
static func _fly(m: MeshInstance3D, speed: float, life: float, glow: bool) -> void:
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var start := m.position
	var a := randf() * TAU
	var vel := Vector3(cos(a), randf_range(0.8, 1.6), sin(a)) * speed
	var spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	var t := m.create_tween()
	t.tween_method(func(k: float) -> void:
		var s := k * life
		var p := start + vel * s + Vector3(0, -9.8, 0) * s * s * 0.5
		p.y = maxf(p.y, 0.05)
		m.position = p
		m.rotation = spin * s, 0.0, 1.0, life)
	if glow:
		t.parallel().tween_property(m.material_override, "albedo_color:a", 0.0, life)
	else:
		t.tween_interval(1.5)
		t.tween_property(m, "scale", Vector3.ONE * 0.01, 0.4)
	t.tween_callback(m.queue_free)


static func _soft_tex() -> ImageTexture:
	if _soft == null:
		_soft = _radial(64, 1.6)
	return _soft


## A lumpy round cloud: a few soft blobs added together, so puffs aren't perfect circles.
static func _cloud_tex() -> ImageTexture:
	if _cloud == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var blobs := []
		for i in 6:
			blobs.append([Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7)) * n, rng.randf_range(0.22, 0.34) * n])
		for y in n:
			for x in n:
				var a := 0.0
				for b: Array in blobs:
					var d := Vector2(x, y).distance_to(b[0]) / float(b[1])
					a += maxf(0.0, 1.0 - d * d)
				var edge := clampf(1.0 - Vector2(x, y).distance_to(Vector2(n, n) / 2.0) / (n * 0.5), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 1.1, 0.0, 1.0) * edge))
		_cloud = ImageTexture.create_from_image(img)
	return _cloud


static func _scorch_tex() -> ImageTexture:
	if _scorch == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for y in n:
			for x in n:
				var p := Vector2(x, y) - Vector2(n, n) / 2.0
				var r := p.length() / (n * 0.5)
				var wobble := 0.12 * sin(atan2(p.y, p.x) * 7.0) + rng.randf_range(-0.05, 0.05)
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - r - wobble) * 2.2, 0.0, 1.0)))
		_scorch = ImageTexture.create_from_image(img)
	return _scorch


static func _radial(n: int, power: float) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x, y).distance_to(Vector2(n, n) / 2.0) / (n * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - r, 0.0, 1.0), power)))
	return ImageTexture.create_from_image(img)
