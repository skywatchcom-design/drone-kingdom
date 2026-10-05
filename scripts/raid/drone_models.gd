class_name DroneModels
extends RefCounted
## The three approved drone designs, built from primitives. Each build returns the moving
## parts the Drone animates. Forward is local +Z. Sizes are in model units; the drone scales them.
##   courier: foldable camera drone (pearl white, graphite, blue light strip, gimbal camera)
##   scout:   FPV racer (black carbon X frame, bright orange plates, teal underglow)
##   heavy:   industrial cargo drone (yellow, gunmetal, coaxial rotors, cargo box with winch)


static func build(kind: String, body: Node3D) -> Dictionary:
	match kind:
		"scout":
			return _scout(body)
		"heavy":
			return _heavy(body)
	return _courier(body)


static func _parts() -> Dictionary:
	return {"props": [], "discs": [], "blinkers": [], "arms": [], "gimbal": null, "lens": null,
		"cable": null, "weight": null, "glow": null, "fire_point": Vector3.ZERO, "bottom": 0.4}


## Propeller on a hub: `blades` thin blades plus a transparent disc that shows motion blur.
static func _propeller(parent: Node3D, pos: Vector3, radius: float, blades: int, blade_mat: Material, p: Dictionary) -> void:
	var hub := Node3D.new()
	hub.position = pos
	parent.add_child(hub)
	for b in blades:
		var holder := Node3D.new()
		holder.rotation.y = TAU * b / blades
		hub.add_child(holder)
		var blade := MeshKit.add(holder, MeshKit.box(Vector3(radius, 0.02, radius * 0.2)), blade_mat, Vector3(radius / 2.0, 0, 0))
		blade.rotation.x = 0.18
	MeshKit.add(hub, MeshKit.cyl(0.04, 0.04, 0.06, 12), MeshKit.mat(Color(0.6, 0.63, 0.66), 0.3, 0.9))
	var disc := MeshKit.add(hub, MeshKit.cyl(radius, radius, 0.004, 32), MeshKit.glow(Color(0.05, 0.06, 0.08), 0.0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p["props"].append(hub)
	p["discs"].append(disc)


static func _courier(body: Node3D) -> Dictionary:
	var p := _parts()
	var white := MeshKit.coat(Color(0.95, 0.96, 0.97), 0.25)
	var graphite := MeshKit.mat(Color(0.23, 0.25, 0.28), 0.4, 0.5)
	var blue := MeshKit.glow(Color(0.18, 0.6, 1.0))
	var shell := MeshKit.add(body, MeshKit.capsule(0.28, 1.08), white)
	shell.rotation.x = PI / 2.0
	shell.scale = Vector3(1.0, 1.0, 0.55)
	MeshKit.add(body, MeshKit.box(Vector3(0.4, 0.06, 0.5)), MeshKit.mat(Color(0.12, 0.14, 0.17), 0.2, 0.3), Vector3(0, 0.15, -0.05))
	MeshKit.add(body, MeshKit.box(Vector3(0.46, 0.035, 0.02)), blue, Vector3(0, 0.0, 0.54))
	for sx in [-1.0, 1.0]:
		MeshKit.add(body, MeshKit.box(Vector3(0.02, 0.03, 0.46)), blue, Vector3(sx * 0.282, 0.0, 0.16))
	var blade := MeshKit.mat(Color(0.6, 0.63, 0.66), 0.45, 0.2)
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var hinge := Node3D.new()
		hinge.position = Vector3(corner.x * 0.24, 0.05 if corner.y > 0 else -0.03, corner.y * 0.36)
		hinge.set_meta("sx", corner.x)
		hinge.set_meta("sz", corner.y)
		body.add_child(hinge)
		var arm_len := 0.62
		MeshKit.add(hinge, MeshKit.box(Vector3(0.08, 0.06, arm_len)), graphite, Vector3(0, 0, corner.y * arm_len / 2.0))
		MeshKit.add(hinge, MeshKit.cyl(0.07, 0.08, 0.1, 20), MeshKit.mat(Color(0.31, 0.34, 0.37), 0.3, 0.8), Vector3(0, 0.05, corner.y * arm_len))
		_propeller(hinge, Vector3(0, 0.13, corner.y * arm_len), 0.3, 2, blade, p)
		if corner.y > 0:
			MeshKit.add(hinge, MeshKit.cyl(0.018, 0.024, 0.36, 10), graphite, Vector3(0, -0.19, corner.y * arm_len))
		p["arms"].append(hinge)
	var gimbal := Node3D.new()
	gimbal.position = Vector3(0, -0.17, 0.43)
	body.add_child(gimbal)
	MeshKit.add(gimbal, MeshKit.box(Vector3(0.12, 0.06, 0.08)), graphite, Vector3(0, 0.05, 0))
	MeshKit.add(gimbal, MeshKit.sphere(0.11, 24), MeshKit.mat(Color(0.08, 0.09, 0.11), 0.25, 0.4), Vector3(0, -0.05, 0.02))
	var lens := MeshKit.add(gimbal, MeshKit.cyl(0.055, 0.055, 0.05, 24), MeshKit.mat(Color(0.02, 0.03, 0.04), 0.05, 0.9), Vector3(0, -0.05, 0.12))
	lens.rotation.x = PI / 2.0
	var lens_glow := MeshKit.add(gimbal, MeshKit.sphere(0.045, 12), MeshKit.glow(Color(0.6, 0.85, 1.0), 0.0), Vector3(0, -0.05, 0.15))
	lens_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p["gimbal"] = gimbal
	p["lens"] = lens_glow
	p["bottom"] = 0.45
	return p


static func _scout(body: Node3D) -> Dictionary:
	var p := _parts()
	var carbon := MeshKit.mat(Color(0.07, 0.075, 0.09), 0.55, 0.35)
	var orange := MeshKit.mat(Color(1.0, 0.42, 0.0), 0.28, 0.75)
	for s in [1.0, -1.0]:
		var plate := MeshKit.add(body, MeshKit.box(Vector3(0.16, 0.04, 2.05)), carbon)
		plate.rotation.y = s * 0.74
	MeshKit.add(body, MeshKit.box(Vector3(0.46, 0.04, 0.95)), carbon)
	MeshKit.add(body, MeshKit.box(Vector3(0.46, 0.04, 0.95)), carbon, Vector3(0, 0.3, 0))
	for sx in [-1.0, 1.0]:
		MeshKit.add(body, MeshKit.box(Vector3(0.035, 0.24, 0.88)), orange, Vector3(sx * 0.22, 0.15, 0))
		for z in [-0.36, 0.36]:
			MeshKit.add(body, MeshKit.cyl(0.022, 0.022, 0.26, 10), orange, Vector3(sx * 0.16, 0.15, z))
	MeshKit.add(body, MeshKit.box(Vector3(0.28, 0.1, 0.46)), MeshKit.mat(Color(0.09, 0.3, 0.17), 0.5, 0.2), Vector3(0, 0.15, 0))
	MeshKit.add(body, MeshKit.box(Vector3(0.04, 0.03, 0.4)), MeshKit.glow(Color(1.0, 0.2, 0.13)), Vector3(0.08, 0.215, 0))
	var fpv := Node3D.new()
	fpv.position = Vector3(0, 0.16, 0.5)
	fpv.rotation.x = -0.45
	body.add_child(fpv)
	MeshKit.add(fpv, MeshKit.box(Vector3(0.17, 0.15, 0.13)), MeshKit.mat(Color(0.12, 0.13, 0.15), 0.3, 0.5))
	var fpv_lens := MeshKit.add(fpv, MeshKit.cyl(0.045, 0.045, 0.04, 20), MeshKit.mat(Color(0.02, 0.03, 0.04), 0.05, 0.9), Vector3(0, 0.02, 0.08))
	fpv_lens.rotation.x = PI / 2.0
	MeshKit.add(body, MeshKit.box(Vector3(0.22, 0.16, 0.26)), MeshKit.mat(Color(0.14, 0.15, 0.17), 0.3, 0.5), Vector3(0, 0.4, 0.16))
	var cam_lens := MeshKit.add(body, MeshKit.cyl(0.055, 0.055, 0.04, 20), MeshKit.mat(Color(0.02, 0.03, 0.04), 0.05, 0.9), Vector3(0, 0.4, 0.3))
	cam_lens.rotation.x = PI / 2.0
	MeshKit.add(body, MeshKit.box(Vector3(0.2, 0.006, 0.2)), MeshKit.glow(Color(1.0, 0.82, 0.23)), Vector3(0, 0.322, -0.26))
	for sx in [-1.0, 1.0]:
		MeshKit.add(body, MeshKit.cyl(0.02, 0.02, 0.34, 8), carbon, Vector3(sx * 0.13, 0.48, -0.38))
		MeshKit.add(body, MeshKit.cyl(0.045, 0.045, 0.07, 12), orange, Vector3(sx * 0.13, 0.66, -0.38))
	var under := MeshKit.add(body, MeshKit.box(Vector3(0.4, 0.012, 0.8)), MeshKit.glow(Color(0.0, 1.0, 0.82), 0.55), Vector3(0, -0.03, 0))
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p["glow"] = under
	var blade := MeshKit.mat(Color(1.0, 0.48, 0.1), 0.3, 0.1)
	blade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blade.albedo_color.a = 0.8
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var m := Vector3(corner.x * 0.7, 0, corner.y * 0.7)
		MeshKit.add(body, MeshKit.cyl(0.1, 0.1, 0.12, 20), orange, m + Vector3(0, 0.08, 0))
		MeshKit.add(body, MeshKit.cyl(0.07, 0.07, 0.02, 20), carbon, m + Vector3(0, 0.15, 0))
		_propeller(body, m + Vector3(0, 0.17, 0), 0.34, 3, blade, p)
	p["fire_point"] = Vector3(0, 0.16, 0.6)
	p["bottom"] = 0.1
	return p


static func _heavy(body: Node3D) -> Dictionary:
	var p := _parts()
	var yellow := MeshKit.coat(Color(0.95, 0.72, 0.02), 0.35, 0.15)
	var gun := MeshKit.mat(Color(0.17, 0.19, 0.22), 0.35, 0.75)
	var carbon := MeshKit.mat(Color(0.09, 0.1, 0.11), 0.5, 0.4)
	MeshKit.add(body, MeshKit.box(Vector3(1.05, 0.5, 1.25)), yellow)
	MeshKit.add(body, MeshKit.box(Vector3(0.8, 0.18, 0.95)), gun, Vector3(0, 0.3, 0))
	for i in 5:
		var stripe := MeshKit.add(body, MeshKit.box(Vector3(0.12, 0.2, 0.02)), MeshKit.mat(Color(0.07, 0.07, 0.07) if i % 2 else Color(0.95, 0.72, 0.02), 0.5), Vector3(-0.36 + i * 0.18, -0.02, 0.63))
		stripe.rotation.z = 0.5
	for x in [-0.32, 0.32]:
		var light := MeshKit.add(body, MeshKit.cyl(0.06, 0.06, 0.03, 16), MeshKit.glow(Color(1.0, 0.96, 0.85)), Vector3(x, 0.12, 0.635))
		light.rotation.x = PI / 2.0
	var blade := MeshKit.mat(Color(0.13, 0.14, 0.17), 0.4, 0.2)
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var tip := Vector3(sin(a) * 1.85, 0.12, cos(a) * 1.85)
		var arm := MeshKit.add(body, MeshKit.cyl(0.07, 0.07, 1.5, 14), carbon, Vector3(tip.x * 0.55, 0.12, tip.z * 0.55))
		# Lay the cylinder flat (Z) then turn it to point from the body toward the tip (Y).
		arm.rotation = Vector3(0, a - PI / 2.0, PI / 2.0)
		MeshKit.add(body, MeshKit.box(Vector3(0.2, 0.14, 0.2)), gun, Vector3(tip.x * 0.3, 0.12, tip.z * 0.3))
		MeshKit.add(body, MeshKit.cyl(0.17, 0.17, 0.5, 24), gun, tip)
		MeshKit.add(body, MeshKit.cyl(0.19, 0.19, 0.06, 24), yellow, tip)
		_propeller(body, tip + Vector3(0, 0.3, 0), 0.78, 2, blade, p)
		_propeller(body, tip + Vector3(0, -0.3, 0), 0.78, 2, blade, p)
		var nav := MeshKit.add(body, MeshKit.sphere(0.05, 8), MeshKit.glow(Color(1.0, 0.3, 0.2)), tip + Vector3(0, -0.02, 0))
		p["blinkers"].append(nav)
	for sx in [-1.0, 1.0]:
		var skid := MeshKit.add(body, MeshKit.cyl(0.04, 0.04, 1.5, 12), carbon, Vector3(sx * 0.62, -1.05, 0))
		skid.rotation.x = PI / 2.0
		for z in [-0.42, 0.42]:
			var leg := MeshKit.add(body, MeshKit.cyl(0.035, 0.035, 0.84, 10), carbon, Vector3(sx * 0.56, -0.63, z))
			leg.rotation.z = sx * -0.16
	MeshKit.add(body, MeshKit.box(Vector3(0.86, 0.5, 0.95)), MeshKit.mat(Color(0.19, 0.21, 0.24), 0.6, 0.3), Vector3(0, -0.55, 0))
	for z in [-0.25, 0.25]:
		MeshKit.add(body, MeshKit.box(Vector3(0.88, 0.52, 0.06)), yellow, Vector3(0, -0.55, z))
	var cable := MeshKit.add(body, MeshKit.cyl(0.012, 0.012, 1.0, 6), MeshKit.mat(Color(0.05, 0.05, 0.05), 0.6), Vector3(0, -0.8, 0))
	var weight := Node3D.new()
	body.add_child(weight)
	MeshKit.add(weight, MeshKit.box(Vector3(0.36, 0.3, 0.36)), MeshKit.mat(Color(0.35, 0.39, 0.43), 0.35, 0.8))
	MeshKit.add(weight, MeshKit.box(Vector3(0.38, 0.06, 0.38)), yellow, Vector3(0, 0.1, 0))
	p["cable"] = cable
	p["weight"] = weight
	p["bottom"] = 1.1
	return p


# ---------------------------------------------------------------- levels

## Adds what each level looks like on top of the approved model (sketch Th5mNJUuSD5d77XEMeRnqE),
## so an enemy can read the level at a glance. The Drone also grows with level.
##   courier: Lv2 a battery pack; Lv3 prop guards and a second camera; Lv4 a graphite shell and
##            armor pods; Lv5 two extra rotors, a third camera, a red laser and a gold band.
##   scout:   Lv2 tall antennas; Lv3 red plates, prop guards and a black canopy; Lv4 an extra
##            battery and a brighter glow; Lv5 a black stealth wing with glowing ducted fans.
##   heavy:   Lv2 a bigger weight; Lv3 two more rotor pods and an orange cargo box; Lv4 armor
##            plates; Lv5 black and gold with a second winch.
static func add_level(kind: String, body: Node3D, level: int, p: Dictionary) -> void:
	var band := UnitModels.level_material(level)
	match kind:
		"courier":
			_courier_level(body, level, p, band)
		"scout":
			_scout_level(body, level, p, band)
		"heavy":
			_heavy_level(body, level, p, band)


static func _guard(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> void:
	var ring := MeshKit.add(parent, MeshKit.ring(radius, 0.04), mat, pos)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _courier_level(body: Node3D, level: int, p: Dictionary, band: Material) -> void:
	var graphite := MeshKit.mat(Color(0.23, 0.25, 0.28), 0.4, 0.5)
	MeshKit.add(body, MeshKit.box(Vector3(0.42, 0.04, 0.6)), band, Vector3(0, 0.2, -0.05))
	if level >= 2:
		MeshKit.add(body, MeshKit.box(Vector3(0.34, 0.12, 0.3)), graphite, Vector3(0, 0.24, -0.25))
	if level >= 3:
		for hinge: Node3D in p["arms"]:
			var sz: float = hinge.get_meta("sz")
			_guard(hinge, Vector3(0, 0.13, sz * 0.62), 0.34, graphite)
		var gimbal: Node3D = p["gimbal"]
		MeshKit.add(gimbal, MeshKit.sphere(0.08, 16), MeshKit.mat(Color(0.08, 0.09, 0.11), 0.25, 0.4), Vector3(0.14, -0.05, 0.02))
	if level >= 4:
		UnitModels.recolor(body, Color(0.95, 0.96, 0.97), Color(0.2, 0.21, 0.24))
		for sx in [-1.0, 1.0]:
			MeshKit.add(body, MeshKit.box(Vector3(0.1, 0.16, 0.5)), graphite, Vector3(sx * 0.32, -0.02, 0.05))
	if level >= 5:
		var blade := MeshKit.mat(Color(0.6, 0.63, 0.66), 0.45, 0.2)
		for sx in [-1.0, 1.0]:
			MeshKit.add(body, MeshKit.box(Vector3(0.55, 0.05, 0.08)), graphite, Vector3(sx * 0.5, 0.05, 0))
			_propeller(body, Vector3(sx * 0.8, 0.15, 0), 0.26, 2, blade, p)
			_guard(body, Vector3(sx * 0.8, 0.15, 0), 0.3, band)
		var gimbal: Node3D = p["gimbal"]
		MeshKit.add(gimbal, MeshKit.sphere(0.08, 16), MeshKit.mat(Color(0.08, 0.09, 0.11), 0.25, 0.4), Vector3(-0.14, -0.05, 0.02))
		var laser := MeshKit.add(gimbal, MeshKit.sphere(0.035, 8), MeshKit.glow(Color(1.0, 0.15, 0.15)), Vector3(0, -0.13, 0.12))
		laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		MeshKit.add(body, MeshKit.box(Vector3(0.58, 0.04, 1.0)), band, Vector3(0, -0.05, 0))


static func _scout_level(body: Node3D, level: int, p: Dictionary, band: Material) -> void:
	var carbon := MeshKit.mat(Color(0.07, 0.075, 0.09), 0.55, 0.35)
	MeshKit.add(body, MeshKit.box(Vector3(0.5, 0.04, 0.3)), band, Vector3(0, 0.33, -0.05))
	if level >= 2:
		for sx in [-1.0, 1.0]:
			MeshKit.add(body, MeshKit.cyl(0.012, 0.012, 0.6, 6), carbon, Vector3(sx * 0.18, 0.62, -0.4))
	if level >= 3:
		UnitModels.recolor(body, Color(1.0, 0.42, 0.0), Color(0.84, 0.15, 0.12))
		for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			_guard(body, Vector3(corner.x * 0.7, 0.17, corner.y * 0.7), 0.4, carbon)
		var canopy := MeshKit.add(body, MeshKit.sphere(0.2, 14), MeshKit.mat(Color(0.05, 0.05, 0.06), 0.15, 0.6), Vector3(0, 0.3, 0.3))
		canopy.scale = Vector3(1, 0.6, 1.4)
	if level >= 4:
		MeshKit.add(body, MeshKit.box(Vector3(0.26, 0.12, 0.34)), MeshKit.mat(Color(0.2, 0.2, 0.22), 0.4), Vector3(0, -0.08, -0.2))
		var glow: MeshInstance3D = p["glow"]
		glow.scale = Vector3(1.5, 1, 1.4)
	if level >= 5:
		UnitModels.recolor(body, Color(0.84, 0.15, 0.12), Color(0.08, 0.08, 0.09))
		var wing := CSGPolygon3D.new()
		wing.polygon = PackedVector2Array([Vector2(0, 1.2), Vector2(1.1, -0.7), Vector2(0, -0.4), Vector2(-1.1, -0.7)])
		wing.depth = 0.06
		wing.material = MeshKit.mat(Color(0.06, 0.06, 0.07), 0.3, 0.5)
		wing.rotation.x = PI / 2.0
		wing.position.y = 0.05
		body.add_child(wing)
		for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			_guard(body, Vector3(corner.x * 0.7, 0.17, corner.y * 0.7), 0.42, MeshKit.glow(Color(0.0, 1.0, 0.82), 0.9))


static func _heavy_level(body: Node3D, level: int, p: Dictionary, band: Material) -> void:
	var gun := MeshKit.mat(Color(0.17, 0.19, 0.22), 0.35, 0.75)
	MeshKit.add(body, MeshKit.box(Vector3(0.82, 0.06, 0.97)), band, Vector3(0, 0.42, 0))
	var weight: Node3D = p["weight"]
	weight.scale = Vector3.ONE * [1.0, 1.35, 1.5, 1.6, 1.7][clampi(level, 1, 5) - 1]
	if level >= 3:
		var blade := MeshKit.mat(Color(0.13, 0.14, 0.17), 0.4, 0.2)
		for a in [0.0, PI]:
			var tip := Vector3(sin(a) * 1.7, 0.12, cos(a) * 1.7)
			MeshKit.add(body, MeshKit.cyl(0.07, 0.07, 1.2, 12), gun, tip * 0.6).rotation = Vector3(0, a - PI / 2.0, PI / 2.0)
			MeshKit.add(body, MeshKit.cyl(0.15, 0.15, 0.4, 20), gun, tip)
			_propeller(body, tip + Vector3(0, 0.25, 0), 0.6, 2, blade, p)
		UnitModels.recolor(body, Color(0.19, 0.21, 0.24), Color(0.55, 0.35, 0.16))
	if level >= 4:
		for sx in [-1.0, 1.0]:
			MeshKit.add(body, MeshKit.box(Vector3(0.08, 0.42, 1.1)), gun, Vector3(sx * 0.56, 0.0, 0))
	if level >= 5:
		UnitModels.recolor(body, Color(0.95, 0.72, 0.02), Color(0.1, 0.1, 0.11))
		for z in [-0.3, 0.3]:
			MeshKit.add(body, MeshKit.box(Vector3(1.08, 0.05, 0.05)), UnitModels.level_material(5), Vector3(0, 0.26, z))
		MeshKit.add(body, MeshKit.cyl(0.012, 0.012, 0.9, 6), MeshKit.mat(Color(0.05, 0.05, 0.05), 0.6), Vector3(0.3, -1.25, 0))
		MeshKit.add(body, MeshKit.box(Vector3(0.4, 0.35, 0.4)), MeshKit.mat(Color(0.35, 0.39, 0.43), 0.35, 0.8), Vector3(0.3, -1.85, 0))
