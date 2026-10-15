class_name MergeGame
extends Node3D
## Base Wars prototype (owner, 15.10.2026: change the game to tower defense + merge, portrait,
## in the "town on a floating block" look B, sketch AgekkKZLSYRZCdFepdTztT). Enemies of Iron Fang
## walk a winding street to the Command Tower in waves. The player drags towers from the bottom
## bar onto free plots; dragging a tower onto an identical one merges them into the next level
## (up to 5). Towers fire by themselves. Ten waves win the stage; losing the tower loses it.
## Numbers follow docs/base-wars (owner's GDD): coins 500 to start, +5 a kill, +100 a wave.

const GRID := 9
const CELL := 7.5
const HQ_CELLS := [[0, 0], [1, 0], [0, 1], [1, 1]]
## The street, as grid points from the entry (off the near corner) to the tower.
const PATH := [Vector2(8, 9.4), Vector2(8, 6), Vector2(5, 6), Vector2(5, 8), Vector2(2, 8), Vector2(2, 4),
	Vector2(6, 4), Vector2(6, 1), Vector2(2.4, 1)]
const WAVES := 10
const HQ_HP := 1000.0
const START_COINS := 500

## Tower stats per level (1..5). Ranges and splash are in plots.
const TOWERS := {
	"mg": {"cost": 50, "dmg": [10, 25, 60, 150, 400], "rate": [0.5, 0.4, 0.3, 0.25, 0.2], "range": [2.0, 2.5, 3.0, 3.5, 4.0], "air": false},
	"mortar": {"cost": 100, "dmg": [50, 120, 300, 750, 2000], "rate": [2.5, 2.3, 2.0, 1.8, 1.5], "range": [3.0, 3.5, 4.0, 4.5, 5.0], "air": false, "splash": [1.0, 1.5, 2.0, 2.5, 3.0]},
	"aa": {"cost": 150, "dmg": [80, 200, 500, 1250, 3500], "rate": [1.5, 1.3, 1.1, 0.9, 0.7], "range": [4.0, 4.5, 5.0, 5.5, 6.0], "air": true},
}
const TOWER_ORDER := ["mg", "mortar", "aa"]
## Enemies: hit points, speed in plots a second, damage to the tower when they reach it.
const ENEMIES := {
	"soldier": {"hp": 100.0, "speed": 0.9, "hit": 50.0},
	"engineer": {"hp": 200.0, "speed": 0.65, "hit": 60.0, "heals": true},
	"tank": {"hp": 800.0, "speed": 0.5, "hit": 150.0, "armor": 0.5},
	"drone": {"hp": 150.0, "speed": 1.4, "hit": 80.0, "air": true},
	"boss": {"hp": 5000.0, "speed": 0.3, "hit": 1000.0, "armor": 0.5},
}

enum State { READY, WAVE, BREAK, WON, LOST }

var cam: Camera3D
var hud: MergeHud
var state := State.READY
var wave := 0
var coins := START_COINS
var hq_hp := HQ_HP
var towers := {}  # "c,r" -> {type, level, node}
var foes: Array = []
var road := {}
var _spawn: Array = []
var _clock := 0.0
var _break := 0.0
var _hq: Node3D
var _drag := {}
var _marker: MeshInstance3D
var _ring: MeshInstance3D
var _rng := RandomNumberGenerator.new()


static func cell_pos(c: float, r: float) -> Vector3:
	var half := (GRID - 1) / 2.0
	return Vector3((c - half) * CELL, 0.0, (r - half) * CELL)


func _ready() -> void:
	MeshKit.look = "town"
	MeshKit.toy = true
	StructureModels.show_levels = false
	_rng.randomize()
	cam = WorldSetup.create(self, 100.0)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 94.0
	WorldSetup.place_camera(cam, Vector3(0, -3.0, 0))
	_mark_road()
	_build_board()
	_hq = StructureModels.build(self, "hq", 3, cell_pos(0.5, 0.5) + Vector3(0, 0.25, 0))
	_hq.scale *= 1.6
	hud = MergeHud.new()
	hud.game = self
	add_child(hud)
	_marker = MeshKit.add(self, MeshKit.box(Vector3(CELL - 0.6, 0.08, CELL - 0.6)), MeshKit.glow(Color.WHITE, 0.45))
	_marker.visible = false
	_ring = MeshKit.add(self, MeshKit.ring(1.0, 0.04), MeshKit.glow(Color(0.5, 1.0, 0.45), 0.8))
	_ring.visible = false
	hud.refresh()
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--merge-bot"):
		_bot()


## Dev, for recordings: `-- --merge-bot` plays by itself: buys towers next to the street,
## merges pairs, and starts the waves.
func _bot() -> void:
	var spots := [[7, 5], [3, 7], [4, 5], [3, 3], [5, 3], [7, 7], [1, 5], [4, 7], [7, 2], [3, 5], [6, 7], [1, 7], [5, 0], [7, 0], [3, 0]]
	var timer := Timer.new()
	timer.wait_time = 0.9
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func() -> void:
		if state in [State.WON, State.LOST]:
			return
		if state == State.READY and towers.size() >= 4:
			start_wave()
			return
		for t: Dictionary in towers.values():
			for o: Dictionary in towers.values():
				if o != t and o["type"] == t["type"] and o["level"] == t["level"] and t["level"] < 5:
					towers.erase("%d,%d" % [t["cell"][0], t["cell"][1]])
					(t["node"] as Node3D).queue_free()
					_merge(o)
					return
		var type := "aa" if wave >= 4 and towers.values().filter(func(x: Dictionary) -> bool: return x["type"] == "aa").size() < 2 else ("mortar" if towers.size() % 3 == 2 else "mg")
		if coins < TOWERS[type]["cost"]:
			return
		for cell: Array in spots:
			if free_plot(cell):
				coins -= TOWERS[type]["cost"]
				_pop(_place(type, 1, cell)["node"], 0.5)
				Audio.play("build", -6.0)
				hud.refresh()
				return)


# ---------------------------------------------------------------- board

func _mark_road() -> void:
	for i in range(1, PATH.size()):
		var a: Vector2 = PATH[i - 1]
		var b: Vector2 = PATH[i]
		var steps := int(ceil(a.distance_to(b) * 2.0))
		for k in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			var c := clampi(int(round(p.x)), 0, GRID - 1)
			var r := clampi(int(round(p.y)), 0, GRID - 1)
			road["%d,%d" % [c, r]] = true


## The floating block: grass on top, earth and rock on its sides, a curb around the plots,
## grey streets with white dashes, light plots to build on, and trees around the edge.
func _build_board() -> void:
	var half := GRID * CELL / 2.0
	var edge := half + 5.0
	var w := edge * 2.0
	MeshKit.add(self, MeshKit.box(Vector3(w, 0.4, w)), MeshKit.surface("grass", Color(0.36, 0.46, 0.24)), Vector3(0, -0.2, 0))
	MeshKit.add(self, MeshKit.box(Vector3(w, 3.2, w)), MeshKit.mat(Color(0.56, 0.4, 0.26), 0.95), Vector3(0, -2.0, 0))
	MeshKit.add(self, MeshKit.box(Vector3(w - 0.6, 2.4, w - 0.6)), MeshKit.mat(Color(0.42, 0.3, 0.2), 0.95), Vector3(0, -4.8, 0))
	MeshKit.add(self, MeshKit.box(Vector3(w - 1.2, 0.6, w - 1.2)), MeshKit.mat(Color(0.62, 0.6, 0.56), 0.95), Vector3(0, -6.3, 0))
	MeshKit.add(self, MeshKit.box(Vector3(half * 2.0 + 1.2, 0.16, half * 2.0 + 1.2)), MeshKit.mat(Color(0.88, 0.87, 0.82), 0.9), Vector3(0, 0.08, 0))
	var asphalt := MeshKit.surface("asphalt", Color(0.42, 0.44, 0.48))
	var plot_mat := MeshKit.mat(Color(0.7, 0.71, 0.66), 0.9)
	var grass := MeshKit.surface("grass", Color(0.4, 0.5, 0.26))
	var plots := []
	var lawns := []
	for c in GRID:
		for r in GRID:
			var p := cell_pos(c, r)
			if road.has("%d,%d" % [c, r]):
				MeshKit.add(self, MeshKit.box(Vector3(CELL, 0.06, CELL)), asphalt, p + Vector3(0, 0.19, 0))
			elif not _is_hq([c, r]):
				lawns.append(Transform3D(Basis(), p + Vector3(0, 0.19, 0)))
				plots.append(Transform3D(Basis(), p + Vector3(0, 0.24, 0)))
	MeshKit.multi(self, MeshKit.box(Vector3(CELL, 0.06, CELL)), grass, lawns)
	MeshKit.multi(self, MeshKit.box(Vector3(CELL - 1.4, 0.06, CELL - 1.4)), plot_mat, plots)
	# White dashes down the middle of the street.
	var dashes := []
	for i in range(1, PATH.size()):
		var a := cell_pos(PATH[i - 1].x, PATH[i - 1].y)
		var b := cell_pos(PATH[i].x, PATH[i].y)
		var dir := (b - a).normalized()
		var t := 1.0
		while t < a.distance_to(b) - 0.5:
			dashes.append(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), a + dir * t + Vector3(0, 0.235, 0)))
			t += 2.2
	MeshKit.multi(self, MeshKit.box(Vector3(0.22, 0.02, 1.0)), MeshKit.mat(Color(0.97, 0.97, 0.94), 0.8), dashes)
	# HQ yard.
	MeshKit.add(self, MeshKit.box(Vector3(CELL * 2.0 - 0.6, 0.1, CELL * 2.0 - 0.6)), MeshKit.mat(Color(0.74, 0.74, 0.7), 0.9), cell_pos(0.5, 0.5) + Vector3(0, 0.2, 0))
	_trees(half, edge)


func _trees(half: float, edge: float) -> void:
	var trunks := []
	var crowns := []
	var crown_colors := []
	var pines := []
	var pine_colors := []
	var placed := 0
	while placed < 60:
		var p := Vector3(_rng.randf_range(-edge + 1.5, edge - 1.5), 0, _rng.randf_range(-edge + 1.5, edge - 1.5))
		if absf(p.x) < half + 1.5 and absf(p.z) < half + 1.5:
			continue
		var entry := cell_pos(8, 9.4)
		if Vector2(p.x - entry.x, p.z - entry.z).length() < 5.0:
			continue
		placed += 1
		var s := _rng.randf_range(1.1, 1.7)
		if _rng.randf() < 0.55:
			trunks.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 0.75 * s, 0)))
			crowns.append(Transform3D(Basis().scaled(Vector3(1.0, 0.9, 1.0) * 1.3 * s), p + Vector3(0, 2.3 * s, 0)))
			crown_colors.append(Color(0.36, 0.62, 0.26).lerp(Color(0.5, 0.72, 0.3), _rng.randf()))
		else:
			pines.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 2.0 * s, 0)))
			pine_colors.append(Color(0.2, 0.46, 0.3).lerp(Color(0.28, 0.55, 0.32), _rng.randf()))
			trunks.append(Transform3D(Basis().scaled(Vector3(0.7, 0.5, 0.7) * s), p + Vector3(0, 0.4 * s, 0)))
	MeshKit.multi(self, MeshKit.cyl(0.16, 0.22, 1.5, 8), MeshKit.mat(Color(0.48, 0.33, 0.2), 0.9), trunks)
	MeshKit.multi(self, MeshKit.sphere(1.0, 10), MeshKit.mat(Color.WHITE, 0.9), crowns, crown_colors)
	MeshKit.multi(self, MeshKit.cyl(0.0, 1.3, 3.4, 8), MeshKit.mat(Color.WHITE, 0.9), pines, pine_colors)


func _is_hq(cell: Array) -> bool:
	return HQ_CELLS.has([int(cell[0]), int(cell[1])])


func free_plot(cell: Array) -> bool:
	var c := int(cell[0])
	var r := int(cell[1])
	return c >= 0 and r >= 0 and c < GRID and r < GRID and not road.has("%d,%d" % [c, r]) and not _is_hq(cell) and not towers.has("%d,%d" % [c, r])


# ---------------------------------------------------------------- towers

func _make_tower(type: String, level: int) -> Defense:
	var d: Defense
	match type:
		"mortar":
			d = MortarPit.new()
		"aa":
			d = AaBattery.new()
		_:
			d = MgNest.new()
	add_child(d)
	var vs := {"air": 1.0} if TOWERS[type]["air"] else {"soldier": 1.0, "tank": 1.0}
	d.setup({"radius": TOWERS[type]["range"][level - 1] * CELL, "level": level, "vs": vs}, 0.27)
	d.scale = Vector3.ONE * 2.1
	return d


func _place(type: String, level: int, cell: Array) -> Dictionary:
	var t := {"type": type, "level": level, "node": _make_tower(type, level), "cell": cell, "cd": 0.0}
	(t["node"] as Node3D).position = cell_pos(cell[0], cell[1])
	towers["%d,%d" % [cell[0], cell[1]]] = t
	return t


func _pop(node: Node3D, from: float) -> void:
	var s := node.scale
	node.scale = s * from
	var tw := node.create_tween()
	tw.tween_property(node, "scale", s * 1.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", s, 0.12)


func cell_at(screen: Vector2) -> Array:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return [-1, -1]
	var p := from + dir * (-from.y / dir.y)
	var half := (GRID - 1) / 2.0
	return [int(round(p.x / CELL + half)), int(round(p.z / CELL + half))]


func ground_at(screen: Vector2) -> Vector3:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	return from + dir * (-from.y / dir.y)


## Drag from the bar: a new level-1 tower follows the finger.
func begin_new(type: String, screen: Vector2) -> void:
	if coins < TOWERS[type]["cost"] or state in [State.WON, State.LOST]:
		Audio.play("click", -12.0)
		return
	var node := _make_tower(type, 1)
	_drag = {"type": type, "level": 1, "node": node, "from": null}
	_drag_move(screen)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and _drag.is_empty() and state not in [State.WON, State.LOST]:
		var cell := cell_at(event.position)
		var key := "%d,%d" % [cell[0], cell[1]]
		if towers.has(key):
			var t: Dictionary = towers[key]
			_drag = {"type": t["type"], "level": t["level"], "node": t["node"], "from": t}
			_drag_move(event.position)


func _input(event: InputEvent) -> void:
	if _drag.is_empty():
		return
	if event is InputEventScreenDrag:
		_drag_move(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_drop(event.position)
		get_viewport().set_input_as_handled()


func _drag_move(screen: Vector2) -> void:
	var node: Node3D = _drag["node"]
	var p := ground_at(screen)
	node.position = p + Vector3(0, 2.0, 0)
	var cell := cell_at(screen)
	var target := _merge_target(cell)
	var ok := not target.is_empty() or free_plot(cell)
	_marker.visible = cell[0] >= 0 and cell[0] < GRID and cell[1] >= 0 and cell[1] < GRID
	_marker.position = cell_pos(cell[0], cell[1]) + Vector3(0, 0.3, 0)
	(_marker.material_override as StandardMaterial3D).albedo_color = (Color(1.0, 0.84, 0.25, 0.6) if not target.is_empty() else (Color(0.5, 1.0, 0.45, 0.45) if ok else Color(1.0, 0.3, 0.25, 0.45)))
	var lv: int = _drag["level"] + (1 if not target.is_empty() else 0)
	var r: float = TOWERS[_drag["type"]]["range"][mini(lv, 5) - 1] * CELL
	_ring.visible = _marker.visible
	_ring.scale = Vector3(r, 1, r)
	_ring.position = _marker.position
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(0.45, 0.75, 1.0, 0.85) if TOWERS[_drag["type"]]["air"] else Color(0.5, 1.0, 0.45, 0.85)


func _merge_target(cell: Array) -> Dictionary:
	var key := "%d,%d" % [cell[0], cell[1]]
	if not towers.has(key):
		return {}
	var t: Dictionary = towers[key]
	if t == _drag.get("from") or t["type"] != _drag["type"] or t["level"] != _drag["level"] or t["level"] >= 5:
		return {}
	return t


func _drop(screen: Vector2) -> void:
	var d := _drag
	_drag = {}
	_marker.visible = false
	_ring.visible = false
	var cell := cell_at(screen)
	var target := _merge_target_for(d, cell)
	var node: Node3D = d["node"]
	var from = d["from"]
	if not target.is_empty():
		node.queue_free()
		if from != null:
			towers.erase("%d,%d" % [from["cell"][0], from["cell"][1]])
		else:
			coins -= TOWERS[d["type"]]["cost"]
		_merge(target)
	elif free_plot(cell):
		if from != null:
			towers.erase("%d,%d" % [from["cell"][0], from["cell"][1]])
			from["cell"] = cell
			towers["%d,%d" % [cell[0], cell[1]]] = from
			node.position = cell_pos(cell[0], cell[1])
		else:
			node.queue_free()
			coins -= TOWERS[d["type"]]["cost"]
			var t := _place(d["type"], 1, cell)
			_pop(t["node"], 0.5)
			Audio.play("build", -6.0)
	else:
		if from != null:
			node.position = cell_pos(from["cell"][0], from["cell"][1])
		else:
			node.queue_free()
	hud.refresh()


func _merge_target_for(d: Dictionary, cell: Array) -> Dictionary:
	var keep := _drag
	_drag = d
	var t := _merge_target(cell)
	_drag = keep
	return t


func _merge(t: Dictionary) -> void:
	var cell: Array = t["cell"]
	(t["node"] as Node3D).queue_free()
	t["level"] += 1
	t["node"] = _make_tower(t["type"], t["level"])
	var node: Node3D = t["node"]
	node.position = cell_pos(cell[0], cell[1])
	_pop(node, 0.3)
	var at := node.position + Vector3(0, 2.5, 0)
	Fx.flash(self, at, 3.0, Color(1.0, 0.85, 0.3))
	for i in 14:
		var a := TAU * i / 14.0
		var spark := MeshKit.add(self, MeshKit.sphere(0.25, 6), MeshKit.glow(Color(1.0, 0.82, 0.3)), at)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tw := spark.create_tween().set_parallel()
		tw.tween_property(spark, "position", at + Vector3(cos(a), 0.4, sin(a)) * 5.0, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "scale", Vector3.ONE * 0.1, 0.45)
		tw.chain().tween_callback(spark.queue_free)
	hud.float_text(at + Vector3(0, 3, 0), "LEVEL UP!", Color(1.0, 0.84, 0.3), true)
	Audio.play("star", -2.0)
	Audio.buzz(30)


# ---------------------------------------------------------------- waves

static func wave_list(n: int) -> Array:
	if n == WAVES:
		return [["boss", 1], ["soldier", 14], ["drone", 5]]
	var l := [["soldier", 5 + 3 * n]]
	if n >= 3:
		l.append(["engineer", (n - 2) * 2])
	if n >= 4:
		l.append(["tank", n - 3])
	if n >= 5:
		l.append(["drone", n - 2])
	return l


func start_wave() -> void:
	if state != State.READY and state != State.BREAK:
		return
	wave += 1
	state = State.WAVE
	_clock = 0.0
	_spawn.clear()
	var t := 0.0
	for pair: Array in wave_list(wave):
		for i in int(pair[1]):
			t += 1.6 if pair[0] == "boss" else 0.6
			_spawn.append({"kind": pair[0], "at": t})
	_spawn.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	hud.banner(I18n.t("Wave %d!") % wave)
	Audio.play("deploy", -4.0)
	hud.refresh()


func _spawn_foe(kind: String) -> void:
	var e: Dictionary = ENEMIES[kind]
	var hp: float = e["hp"] * (1.0 + 0.15 * (wave - 1))
	var root := Node3D.new()
	add_child(root)
	var model := Node3D.new()
	root.add_child(model)
	var parts: Dictionary
	match kind:
		"tank", "boss":
			parts = UnitModels.build("armor", model, 5 if kind == "boss" else 1)
			model.scale = Vector3.ONE * (3.6 if kind == "boss" else 2.5)
		"drone":
			parts = DroneModels.build("scout", model)
			model.scale = Vector3.ONE * 3.4
			model.position.y = 8.0
		_:
			parts = UnitModels.build("robot", model, 3 if kind == "engineer" else 1)
			model.scale = Vector3.ONE * 5.6
	Syndicate.paint(model)
	MeshKit.blob(root, Vector2(4.6, 4.6) * (2.0 if kind in ["tank", "boss"] else 1.0), Vector3(0, 0.25, 0), 0.4)
	var start := cell_pos(PATH[0].x, PATH[0].y)
	root.position = start
	foes.append({"kind": kind, "e": e, "hp": hp, "max": hp, "node": root, "model": model, "parts": parts,
		"seg": 0, "prog": 0.0, "air": e.has("air"), "t": _rng.randf() * 6.0})
	_pop(root, 0.2)


func _process(delta: float) -> void:
	if state == State.WAVE:
		_clock += delta
		while not _spawn.is_empty() and _spawn[0]["at"] <= _clock:
			_spawn_foe(_spawn.pop_front()["kind"])
		if _spawn.is_empty() and foes.is_empty():
			coins += 100
			hud.banner(I18n.t("Wave %d cleared! +100") % wave)
			Audio.play("star", -4.0)
			if wave >= WAVES:
				_finish(true)
			else:
				state = State.BREAK
				_break = 5.0
			hud.refresh()
	elif state == State.BREAK:
		_break -= delta
		if _break <= 0.0:
			start_wave()
	if state in [State.WAVE, State.BREAK]:
		_move_foes(delta)
		_fire(delta)
	hud.queue_redraw_overlay()


func _move_foes(delta: float) -> void:
	var goal := cell_pos(0.5, 0.5)
	foes = foes.filter(func(f: Dictionary) -> bool: return not f.get("gone", false))
	for f: Dictionary in foes:
		var e: Dictionary = f["e"]
		var node: Node3D = f["node"]
		var step: float = float(e["speed"]) * CELL * delta
		f["t"] += delta
		var from := node.position
		if f["air"]:
			var to := goal - node.position
			to.y = 0
			if to.length() < 3.0:
				_leak(f)
				continue
			node.position += to.normalized() * step
			f["prog"] += step * 1.4
			for prop in f["parts"].get("props", []):
				(prop as Node3D).rotation.y += delta * 40.0
			(f["model"] as Node3D).position.y = 8.0 + sin(f["t"] * 3.0) * 0.3
		else:
			var left := step
			while left > 0.0:
				if f["seg"] + 1 >= PATH.size():
					_leak(f)
					break
				var target := cell_pos(PATH[f["seg"] + 1].x, PATH[f["seg"] + 1].y)
				var d := node.position.distance_to(target)
				if d <= left:
					node.position = target
					f["seg"] += 1
					left -= d
					f["prog"] += d
				else:
					node.position += (target - node.position).normalized() * left
					f["prog"] += left
					left = 0.0
			var hips: Array = f["parts"].get("hips", [])
			for i in hips.size():
				(hips[i] as Node3D).rotation.x = sin(f["t"] * 9.0 + PI * i) * 0.5
			if e.has("heals"):
				for o: Dictionary in foes:
					if o != f and not o["air"] and not o.get("gone", false) and (o["node"] as Node3D).position.distance_to(node.position) < CELL:
						o["hp"] = minf(o["max"], o["hp"] + 8.0 * delta)
		var move := node.position - from
		if move.length() > 0.001:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(move.x, move.z), 0.25)
	foes = foes.filter(func(f: Dictionary) -> bool: return not f.get("gone", false))


func _leak(f: Dictionary) -> void:
	f["gone"] = true
	hq_hp -= float(f["e"]["hit"])
	var at := (f["node"] as Node3D).position
	(f["node"] as Node3D).queue_free()
	Fx.boom(self, at + Vector3(0, 1, 0), 1.0)
	Fx.shake(self, 0.8)
	Audio.play("impact", -2.0)
	_pop(_hq, 0.92)
	if hq_hp <= 0.0:
		hq_hp = 0.0
		Fx.boom(self, _hq.position + Vector3(0, 4, 0), 3.0)
		_finish(false)
	hud.refresh()


func _fire(delta: float) -> void:
	for t: Dictionary in towers.values():
		var d: Defense = t["node"]
		var spec: Dictionary = TOWERS[t["type"]]
		var lv: int = t["level"] - 1
		var range_m: float = spec["range"][lv] * CELL
		var best = null
		for f: Dictionary in foes:
			if f["hp"] <= 0.0 or f.get("gone", false) or f["air"] != spec["air"]:
				continue
			var p: Vector3 = (f["node"] as Node3D).position
			if Vector2(p.x - d.position.x, p.z - d.position.z).length() <= range_m and (best == null or f["prog"] > best["prog"]):
				best = f
		var pivot = d.get("_pivot")
		if best == null:
			continue
		var aim: Vector3 = (best["node"] as Node3D).position + Vector3(0, 8.0 if best["air"] else 2.6, 0)
		if pivot is Node3D:
			var to := aim - d.position
			(pivot as Node3D).rotation.y = rotate_toward((pivot as Node3D).rotation.y, atan2(to.x, to.z), 8.0 * delta)
		t["cd"] -= delta
		if t["cd"] > 0.0:
			continue
		t["cd"] = spec["rate"][lv]
		var dmg: float = spec["dmg"][lv]
		var head := d.position + Vector3(0, 4.6, 0)
		match t["type"]:
			"mg":
				Fx.flash(self, head, 0.3)
				Fx.tracer(self, head, aim, Color(1.0, 0.82, 0.29), 0.08, 0.07)
				Audio.play("rifle", -14.0, 0.06)
				_hurt(best, dmg)
			"mortar":
				var ground := Vector3(aim.x, 0.3, aim.z)
				var splash: float = spec["splash"][lv] * CELL * 0.6
				Fx.flash(self, head, 0.6)
				Audio.play("cannon", -10.0, 0.1)
				Fx.lob(self, head, ground, 0.7, func() -> void:
					Fx.boom(self, ground, 0.5 + 0.12 * lv)
					for o: Dictionary in foes:
						if not o["air"] and o["hp"] > 0.0 and not o.get("gone", false) and (o["node"] as Node3D).position.distance_to(ground) <= splash:
							_hurt(o, dmg))
			"aa":
				var target: Dictionary = best
				Fx.flash(self, head + Vector3(0, 0.5, 0), 0.5, Color(0.7, 0.9, 1.0))
				Audio.play("impact", -14.0, 0.1)
				Fx.shell(self, head + Vector3(0, 0.5, 0), aim, 0.25, func() -> void:
					if is_instance_valid(target["node"]):
						Fx.flash(self, (target["node"] as Node3D).position + Vector3(0, 8, 0), 1.8)
					_hurt(target, dmg))


func _hurt(f: Dictionary, dmg: float) -> void:
	if f["hp"] <= 0.0 or f.get("gone", false):
		return
	f["hp"] -= dmg * (1.0 - float(f["e"].get("armor", 0.0)))
	if f["hp"] > 0.0:
		return
	f["gone"] = true
	var node: Node3D = f["node"]
	var at := node.position + Vector3(0, 8.0 if f["air"] else 2.0, 0)
	if f["kind"] in ["tank", "boss", "drone"]:
		Fx.boom(self, at, 0.8 if f["kind"] != "boss" else 2.0)
		Audio.play("drone_down" if f["air"] else "tank_down", -6.0)
	else:
		Fx.flash(self, at, 0.8, Color(1.0, 0.6, 0.3))
		Fx.smoke(self, at, 1.5)
		Audio.play("soldier_down", -10.0, 0.05)
	node.queue_free()
	coins += 5
	hud.float_text(at + Vector3(0, 2, 0), "+5", Color(1.0, 0.84, 0.3), false)
	hud.refresh()


func _finish(won: bool) -> void:
	state = State.WON if won else State.LOST
	Engine.time_scale = 1.0
	var stars := 0
	if won:
		stars = 1 + (1 if hq_hp >= HQ_HP else 0) + (1 if hq_hp > HQ_HP * 0.8 else 0)
	hud.show_end(won, stars)
	Audio.play("star" if won else "collapse")


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
