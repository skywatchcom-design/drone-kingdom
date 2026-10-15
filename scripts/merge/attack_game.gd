class_name AttackGame
extends MergeGame
## Attack sketch "reverse Bloons" (owner, 15.10.2026; an experiment, not yet a decision): the
## same board as the merge defense, but this time the base belongs to Iron Fang. Its defenses
## stand along the street; the player taps unit cards to send soldiers, tanks and drones down
## the street in any order. Defenses shoot them; tanks shoot back at defenses in reach; every
## unit that reaches the Command Tower hits it and grabs loot. Destroying the tower wins.

const ENEMY_HQ := 2000.0
const SEND_ORDER := ["soldier", "tank", "drone"]
const ARMY := {"soldier": 18, "tank": 5, "drone": 8}
## The player's units: hit points, speed in plots a second, damage to the tower on arrival.
const UNITS := {
	"soldier": {"hp": 240.0, "speed": 0.9, "hit": 80.0},
	"tank": {"hp": 1800.0, "speed": 0.5, "hit": 400.0, "armor": 0.4, "gun": 60.0},
	"drone": {"hp": 300.0, "speed": 1.4, "hit": 200.0, "air": true},
}
## Iron Fang's defenses for this sketch: cell, type, level.
const DEFENSE := [[7, 5, "mg", 2], [4, 5, "mg", 1], [3, 7, "mortar", 1], [3, 3, "aa", 1], [5, 3, "mg", 2],
	[7, 2, "mortar", 1], [1, 5, "mg", 1], [4, 7, "aa", 1]]

var army := {}
var loot := 0
var knocked := 0


func _ready() -> void:
	MeshKit.look = "leo"
	MeshKit.toy = true
	StructureModels.show_levels = false
	_rng.randomize()
	cam = WorldSetup.create(self, 100.0)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 94.0
	WorldSetup.place_camera(cam, Vector3(0, -3.0, 0))
	_mark_road()
	_build_board()
	_hq = StructureModels.build(self, "hq", 4, cell_pos(0.5, 0.5) + Vector3(0, 0.25, 0))
	_hq.scale *= 1.6
	Syndicate.paint(_hq)
	for d: Array in DEFENSE:
		var t := _place(d[2], d[3], [d[0], d[1]])
		t["hp"] = 350.0 * float(d[3])
		t["max"] = t["hp"]
		Syndicate.paint(t["node"])
	army = ARMY.duplicate()
	hq_hp = ENEMY_HQ
	coins = 0
	state = State.WAVE
	hud = AttackHud.new()
	hud.game = self
	add_child(hud)
	hud.refresh()
	hud.banner(I18n.t("Attack!"))
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--merge-bot"):
		_send_bot()


## Dev, for recordings: sends a mixed stream of units by itself.
func _send_bot() -> void:
	var order := ["soldier", "soldier", "tank", "soldier", "drone", "soldier", "drone", "tank"]
	var i := [0]
	var timer := Timer.new()
	timer.wait_time = 1.1
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func() -> void:
		for k in order.size():
			var kind: String = order[(i[0] + k) % order.size()]
			if army.get(kind, 0) > 0:
				send(kind)
				i[0] += k + 1
				return)


func send(kind: String) -> void:
	if state != State.WAVE or army.get(kind, 0) <= 0:
		Audio.play("click", -12.0)
		return
	army[kind] -= 1
	_spawn_foe(kind)
	Audio.play("deploy", -6.0)
	hud.refresh()


func _spawn_foe(kind: String) -> void:
	var e: Dictionary = UNITS[kind]
	var root := Node3D.new()
	add_child(root)
	var model := Node3D.new()
	root.add_child(model)
	var parts: Dictionary
	match kind:
		"tank":
			parts = UnitModels.build("armor", model, 2)
			model.scale = Vector3.ONE * 2.5
		"drone":
			parts = DroneModels.build("courier", model)
			model.scale = Vector3.ONE * 3.4
			model.position.y = 8.0
		_:
			parts = UnitModels.build("infantry", model, 2)
			model.scale = Vector3.ONE * 4.2
	MeshKit.blob(root, Vector2(4.6, 4.6) * (2.0 if kind == "tank" else 1.0), Vector3(0, 0.25, 0), 0.4)
	root.position = cell_pos(PATH[0].x, PATH[0].y)
	foes.append({"kind": kind, "e": e, "hp": e["hp"], "max": e["hp"], "node": root, "model": model, "parts": parts,
		"seg": 0, "prog": 0.0, "air": e.has("air"), "t": _rng.randf() * 6.0, "cd": 0.0})
	_pop(root, 0.2)


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _process(delta: float) -> void:
	if state == State.WAVE:
		_move_foes(delta)
		_fire(delta)
		_tank_guns(delta)
		var left := 0
		for k in army:
			left += int(army[k])
		if hq_hp <= 0.0:
			hq_hp = 0.0
			_finish(true)
		elif left == 0 and foes.is_empty():
			_finish(false)
	hud.queue_redraw_overlay()


## Tanks stop for nothing but fire at the nearest defense in reach; a defense that runs out of
## hit points blows up and leaves its plot.
func _tank_guns(delta: float) -> void:
	for f: Dictionary in foes:
		if f["kind"] != "tank" or f.get("gone", false):
			continue
		f["cd"] -= delta
		if f["cd"] > 0.0:
			continue
		var at: Vector3 = (f["node"] as Node3D).position
		var best = null
		for t: Dictionary in towers.values():
			var d := (t["node"] as Node3D).position.distance_to(at)
			if d <= 2.5 * CELL and (best == null or d < (best["node"] as Node3D).position.distance_to(at)):
				best = t
		if best == null:
			continue
		f["cd"] = 1.2
		var target: Vector3 = (best["node"] as Node3D).position + Vector3(0, 2.0, 0)
		var from := at + Vector3(0, 2.6, 0)
		Fx.flash(self, from, 0.6)
		Audio.play("cannon", -10.0, 0.1)
		var hit: Dictionary = best
		Fx.shell(self, from, target, 0.25, func() -> void:
			if not towers.values().has(hit):
				return
			Fx.boom(self, target, 0.5)
			hit["hp"] -= float(UNITS["tank"]["gun"]) * 1.2
			if hit["hp"] <= 0.0:
				_knock_out(hit))


func _knock_out(t: Dictionary) -> void:
	towers.erase("%d,%d" % [t["cell"][0], t["cell"][1]])
	var at := (t["node"] as Node3D).position
	(t["node"] as Node3D).queue_free()
	Fx.boom(self, at + Vector3(0, 1.5, 0), 1.6)
	Fx.smoke(self, at + Vector3(0, 1.5, 0), 3.0)
	Audio.play("collapse", -4.0)
	knocked += 1
	loot += 40
	hud.float_text(at + Vector3(0, 6, 0), "+40", Color(1.0, 0.84, 0.3), true)
	hud.refresh()


func _leak(f: Dictionary) -> void:
	f["gone"] = true
	hq_hp -= float(f["e"]["hit"])
	loot += 20
	var at := (f["node"] as Node3D).position
	(f["node"] as Node3D).queue_free()
	Fx.boom(self, at + Vector3(0, 2, 0), 1.0)
	Fx.shake(self, 0.8)
	Audio.play("impact", -2.0)
	_pop(_hq, 0.92)
	hud.float_text(at + Vector3(0, 8, 0), "+20", Color(1.0, 0.84, 0.3), false)
	if hq_hp <= 0.0:
		Fx.boom(self, _hq.position + Vector3(0, 6, 0), 3.0)
	hud.refresh()


func _hurt(f: Dictionary, dmg: float) -> void:
	if f["hp"] <= 0.0 or f.get("gone", false):
		return
	f["hp"] -= dmg * (1.0 - float(f["e"].get("armor", 0.0)))
	if f["hp"] > 0.0:
		return
	f["gone"] = true
	var node: Node3D = f["node"]
	var at := node.position + Vector3(0, 8.0 if f["air"] else 2.0, 0)
	if f["kind"] == "soldier":
		Fx.flash(self, at, 0.8, Color(1.0, 0.6, 0.3))
		Fx.smoke(self, at, 1.5)
		Audio.play("soldier_down", -10.0, 0.05)
	else:
		Fx.boom(self, at, 0.8)
		Audio.play("drone_down" if f["air"] else "tank_down", -6.0)
	node.queue_free()
	hud.refresh()


func _finish(won: bool) -> void:
	state = State.WON if won else State.LOST
	Engine.time_scale = 1.0
	var left := 0
	var total := 0
	for k in army:
		left += int(army[k])
		total += int(ARMY[k])
	var stars := 0
	if won:
		stars = 1 + (1 if knocked >= DEFENSE.size() / 2 else 0) + (1 if left * 3 >= total else 0)
	elif hq_hp <= ENEMY_HQ * 0.5:
		stars = 1
	hud.show_end(won, stars)
	Audio.play("star" if won else "collapse")
