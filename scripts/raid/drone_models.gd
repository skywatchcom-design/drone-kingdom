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
