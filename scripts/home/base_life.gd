class_name BaseLife
extends Node3D
## Life in the home base (approved sketch Wh6JXRFwid3cJxTbP8DZsG): two soldiers patrol side by
## side round the inner edge of the compound, a jeep laps the outside kicking up dust, a worker
## hammers at every building site, smoke rises from the campfire and the workshop pipe,
## antenna lights blink, a patrol drone circles and a flock of birds wheels overhead.
## Cheap on purpose: a handful of nodes moved in _process, no physics.

const PATROL_EDGE := 34.0
const JEEP_EDGE := 37.2
const SMOKE_EVERY := 0.4

var _soldiers: Array[GroundUnit] = []
var _jeep: Node3D
var _jeep_wheels: Array[Node3D] = []
var _workers: Array[Node3D] = []
var _smoke: Array[Node3D] = []
## Camp lamp bulbs, which flicker now and then.
var _lamps: Array = []
var _blinkers: Array[Node3D] = []
var _drone: Node3D
var _birds: Node3D
var _wings: Array = []
var _time := 0.0
var _smoke_timer := 0.0
var _dust_timer := 0.0


## `world` holds the built base (scanned for smoke and blink markers); `sites` are the tops of
## pads being built.
func setup(world: Node, sites: Array) -> void:
	_scan(world)
	for i in 2:
		var u := GroundUnit.new()
		u.configure(Catalog.unit_stats("infantry", 1))
		u.set_meta("home", Vector3.ZERO)
		u.position = _patrol_point(0.0, i)
		add_child(u)
		_soldiers.append(u)
	_jeep = _make_jeep()
	add_child(_jeep)
	for top: Vector3 in sites:
		var w := _make_worker()
		w.position = top + Vector3(2.0, -top.y, 2.9)
		w.rotation.y = PI * 1.15
		add_child(w)
		_workers.append(w)
	_drone = _make_drone()
	add_child(_drone)
	_birds = _make_birds()
	add_child(_birds)


func _scan(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("smoke"):
			_smoke.append(child)
		if child.has_meta("blink"):
			_blinkers.append(child)
		if child.has_meta("lamp"):
			_lamps.append(child)
		_scan(child)


func _process(delta: float) -> void:
	_time += delta
	# Patrol: the two soldiers walk side by side, each in its own lane, chasing a point just
	# ahead so they turn the corners smoothly.
	for i in _soldiers.size():
		var u := _soldiers[i]
		var goal := _patrol_point(_time * 0.0045 + 0.005, i)
		u.walk((goal - u.position).limit_length(1.0) * 1.3, delta)
	# Jeep: laps a rounded square outside the lawn.
	var a := _jeep_point(fposmod(_time * 0.022, 1.0))
	var b := _jeep_point(fposmod(_time * 0.022 + 0.004, 1.0))
	_jeep.position = a
	_jeep.rotation.y = atan2(b.x - a.x, b.z - a.z)
	for w in _jeep_wheels:
		w.rotation.x += delta * 9.0
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = 0.15
		Fx.smoke(self, _jeep.position - _jeep.basis.z * 2.2 + Vector3(0, 0.4, 0), 0.7, 0.0, Color(0.74, 0.66, 0.5))
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = SMOKE_EVERY
		for s in _smoke:
			if is_instance_valid(s):
				Fx.smoke(self, (s as Node3D).global_position, 0.45, 0.0, Color(0.6, 0.59, 0.57))
	for i in _blinkers.size():
		if is_instance_valid(_blinkers[i]):
			_blinkers[i].visible = sin(_time * 4.0 + i * 1.3) > 0.2
	for i in _lamps.size():
		if is_instance_valid(_lamps[i]):
			_lamps[i].visible = sin(_time * 23.0 + i * 5.0) > -0.97 or fmod(_time + i * 3.7, 9.0) > 0.3
	for w in _workers:
		(w.get_meta("arm") as Node3D).rotation.x = -1.4 + absf(sin(_time * 5.0)) * 1.2
	_drone.position = Vector3(cos(_time * 0.25) * 22.0, 13.0 + sin(_time * 1.1) * 0.3, sin(_time * 0.25) * 22.0)
	_drone.rotation.y = -_time * 0.25
	(_drone.get_meta("light") as Node3D).visible = fmod(_time, 1.0) < 0.15
	_birds.position = Vector3(cos(_time * 0.09) * 46.0, 24.0 + sin(_time * 0.4) * 2.0, sin(_time * 0.09) * 46.0)
	_birds.rotation.y = -_time * 0.09
	for i in _wings.size():
		var flap := sin(_time * 9.0 + i * 0.7) * 0.6
		(_wings[i][0] as Node3D).rotation.z = flap
		(_wings[i][1] as Node3D).rotation.z = -flap


## Lane 0 runs on the inside, lane 1 a little over a meter further out.
func _patrol_point(t: float, lane: int) -> Vector3:
	return _square(fposmod(t, 1.0), PATROL_EDGE + lane * 1.3, 3.0 + lane * 1.3)


func _jeep_point(t: float) -> Vector3:
	return _square(t, JEEP_EDGE, 6.0)


## A point `t` of the way round a square of half-side `edge`, corners rounded by `round`.
func _square(t: float, edge: float, round: float) -> Vector3:
	var straight := 2.0 * (edge - round)
	var arc := PI / 2.0 * round
	var side := straight + arc
	var d := t * side * 4.0
	var k := int(d / side) % 4
	var s := d - k * side
	var p: Vector2
	if s < straight:
		p = Vector2(-edge + round + s, -edge)
	else:
		var ang := -PI / 2.0 + (s - straight) / maxf(round, 0.001)
		p = Vector2(edge - round + cos(ang) * round, -edge + round + sin(ang) * round)
	p = p.rotated(k * PI / 2.0)
	return Vector3(p.x, 0, p.y)


func _puff(pos: Vector3, color: Color, size: float, life: float, rise: float) -> void:
	var puff := MeshKit.add(self, MeshKit.sphere(size * 0.5, 8), MeshKit.glow(color, 0.3), pos)
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "position", pos + Vector3(life * 0.4, life * rise * 1.4, 0), life)
	tween.tween_property(puff, "scale", Vector3.ONE * 3.0, life)
	tween.tween_property(puff.material_override, "albedo_color:a", 0.0, life)
	tween.chain().tween_callback(puff.queue_free)


func _make_jeep() -> Node3D:
	var j := Node3D.new()
	var body := MeshKit.surface("camo", UnitModels.SINAI, 0.8, 0.1)
	var dark := MeshKit.mat(Color(0.11, 0.11, 0.12), 0.8, 0.2)
	MeshKit.add(j, MeshKit.box(Vector3(1.7, 0.5, 3.4)), body, Vector3(0, 0.75, 0))
	MeshKit.add(j, MeshKit.box(Vector3(1.68, 0.35, 1.1)), body, Vector3(0, 1.12, 1.0))
	var glass := MeshKit.add(j, MeshKit.box(Vector3(1.5, 0.5, 0.04)), MeshKit.mat(Color(0.2, 0.32, 0.37), 0.1, 0.6), Vector3(0, 1.45, 0.4))
	glass.rotation.x = -0.2
	MeshKit.add(j, MeshKit.box(Vector3(1.6, 0.06, 1.5)), MeshKit.surface("canvas", UnitModels.OLIVE, 0.9), Vector3(0, 1.75, -0.6))
	for sx in [-1.0, 1.0]:
		MeshKit.add(j, MeshKit.box(Vector3(0.06, 0.6, 1.3)), dark, Vector3(sx * 0.8, 1.35, -0.6))
		MeshKit.add(j, MeshKit.sphere(0.09, 8), MeshKit.glow(Color(1.0, 0.95, 0.8)), Vector3(sx * 0.6, 0.85, 1.72))
	for p in [Vector3(-0.85, 0.38, 1.1), Vector3(0.85, 0.38, 1.1), Vector3(-0.85, 0.38, -1.1), Vector3(0.85, 0.38, -1.1)]:
		var w := Node3D.new()
		w.position = p
		j.add_child(w)
		MeshKit.add(w, MeshKit.cyl(0.38, 0.38, 0.3, 14), dark).rotation.z = PI / 2.0
		_jeep_wheels.append(w)
	MeshKit.add(j, MeshKit.cyl(0.36, 0.36, 0.25, 14), dark, Vector3(0, 1.0, -1.82)).rotation.x = PI / 2.0
	MeshKit.add(j, MeshKit.cyl(0.012, 0.012, 1.8, 4), dark, Vector3(0.7, 2.0, -1.4))
	MeshKit.blob(j, Vector2(2.6, 4.2), Vector3.ZERO, 0.5)
	return j


## A builder in an orange vest and a yellow hard hat, swinging a hammer (meta "arm").
func _make_worker() -> Node3D:
	var w := Node3D.new()
	w.scale = Vector3.ONE * 2.0
	var cloth := MeshKit.surface("canvas", Color(0.32, 0.36, 0.42), 0.9)
	for x in [-0.09, 0.09]:
		MeshKit.add(w, MeshKit.cyl(0.07, 0.06, 0.5, 8), cloth, Vector3(x, 0.25, 0))
		MeshKit.add(w, MeshKit.box(Vector3(0.12, 0.08, 0.2)), MeshKit.mat(Color(0.2, 0.17, 0.13), 0.8), Vector3(x, 0.04, 0.04))
	MeshKit.add(w, MeshKit.capsule(0.15, 0.5), MeshKit.surface("canvas", Color(0.98, 0.45, 0.12), 0.8), Vector3(0, 0.75, 0)).scale = Vector3(1, 1, 0.7)
	MeshKit.add(w, MeshKit.sphere(0.1, 12), MeshKit.mat(UnitModels.SKIN, 0.7), Vector3(0, 1.1, 0))
	var hat := MeshKit.add(w, MeshKit.sphere(0.12, 12), MeshKit.mat(Color(0.98, 0.8, 0.15), 0.4, 0.1), Vector3(0, 1.16, 0))
	hat.scale = Vector3(1.05, 0.7, 1.1)
	var arm := Node3D.new()
	arm.position = Vector3(0.2, 0.95, 0)
	w.add_child(arm)
	MeshKit.add(arm, MeshKit.cyl(0.05, 0.045, 0.45, 8), cloth, Vector3(0, -0.2, 0))
	MeshKit.add(arm, MeshKit.box(Vector3(0.04, 0.04, 0.32)), MeshKit.surface("wood", StructureModels.WOOD, 0.9), Vector3(0, -0.42, 0.12))
	MeshKit.add(arm, MeshKit.box(Vector3(0.1, 0.08, 0.12)), MeshKit.mat(Color(0.3, 0.3, 0.32), 0.4, 0.7), Vector3(0, -0.42, 0.3))
	w.set_meta("arm", arm)
	MeshKit.blob(w, Vector2(0.7, 0.7), Vector3.ZERO, 0.45)
	return w


func _make_drone() -> Node3D:
	var d := Node3D.new()
	MeshKit.add(d, MeshKit.box(Vector3(0.7, 0.2, 0.9)), MeshKit.mat(Color(0.9, 0.9, 0.88), 0.4, 0.3))
	for i in 4:
		var ang := i * PI / 2.0 + PI / 4.0
		var arm := MeshKit.add(d, MeshKit.box(Vector3(0.9, 0.05, 0.07)), MeshKit.mat(Color(0.15, 0.15, 0.16), 0.5), Vector3(cos(ang), 0, sin(ang)) * 0.4)
		arm.rotation.y = -ang
		MeshKit.add(d, MeshKit.cyl(0.32, 0.32, 0.01, 16), MeshKit.glow(Color(0.1, 0.1, 0.1), 0.2), Vector3(cos(ang), 0.1, sin(ang)) * 0.8)
	var light := MeshKit.add(d, MeshKit.sphere(0.06, 6), MeshKit.glow(Color(1.0, 0.2, 0.2)), Vector3(0, -0.14, 0.45))
	d.set_meta("light", light)
	return d


func _make_birds() -> Node3D:
	var flock := Node3D.new()
	var m := MeshKit.glow(Color(0.12, 0.12, 0.12))
	for i in 7:
		var b := Node3D.new()
		b.position = Vector3((i % 3 - 1) * 1.6, (i % 2) * 0.6, -int(i / 3.0) * 1.3 - absi(i % 3 - 1) * 0.8)
		flock.add_child(b)
		var pair := []
		for sx in [-1.0, 1.0]:
			var pivot := Node3D.new()
			b.add_child(pivot)
			MeshKit.add(pivot, MeshKit.box(Vector3(0.7, 0.02, 0.2)), m, Vector3(sx * 0.35, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pair.append(pivot)
		_wings.append(pair)
	return flock
