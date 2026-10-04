class_name Fx
extends RefCounted
## Short-lived battle effects that clean up after themselves: tracers, muzzle flashes,
## explosions and shells in flight. Each one is added under `parent` (the battle level).


static func flash(parent: Node3D, pos: Vector3, size: float, color: Color = Color(1.0, 0.9, 0.55)) -> void:
	var m := MeshKit.add(parent, MeshKit.sphere(size, 8), MeshKit.glow(color, 0.95), pos)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## Fireball, smoke puffs and a dust ring.
static func boom(parent: Node3D, pos: Vector3, power: float) -> void:
	flash(parent, pos + Vector3(0, 0.3, 0), 0.7 * power, Color(1, 1, 1))
	var fire := MeshKit.add(parent, MeshKit.sphere(0.6 * power, 12), MeshKit.glow(Color(1.0, 0.54, 0.16), 0.95), pos + Vector3(0, 0.5 * power, 0))
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ft := fire.create_tween()
	ft.set_parallel(true)
	ft.tween_property(fire, "scale", Vector3.ONE * 2.2, 0.4)
	ft.tween_property(fire.material_override, "albedo_color:a", 0.0, 0.4)
	ft.chain().tween_callback(fire.queue_free)
	for i in 3:
		var smoke := MeshKit.add(parent, MeshKit.sphere(0.6 * power, 8), MeshKit.glow(Color(0.3, 0.3, 0.29), 0.7),
			pos + Vector3(randf_range(-1, 1) * power, 0.6, randf_range(-1, 1) * power))
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var st := smoke.create_tween()
		st.set_parallel(true)
		st.tween_property(smoke, "position:y", smoke.position.y + 3.0 * power, 1.3)
		st.tween_property(smoke, "scale", Vector3.ONE * 3.0, 1.3)
		st.tween_property(smoke.material_override, "albedo_color:a", 0.0, 1.3)
		st.chain().tween_callback(smoke.queue_free)
	var ring := MeshKit.add(parent, MeshKit.ring(1.0, 0.18), MeshKit.glow(Color(0.85, 0.79, 0.63), 0.5), Vector3(pos.x, 0.08, pos.z))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3.ONE * 0.3
	var rt := ring.create_tween()
	rt.set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(3.5, 1, 3.5) * power, 0.8)
	rt.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.8)
	rt.chain().tween_callback(ring.queue_free)


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
