class_name StreetRaid
extends MergeGame
## Base Wars attacks, "reverse Bloons" (owner, 15.10.2026, sketch 7nbqfinTw2uAC1eV2iE7h9): the
## enemy base stands on the same 9x9 board as the merge defense, with a street winding to its
## Command Tower. Its defenses line the street (the strongest nearest the tower), its other
## buildings fill the plots behind. The player taps unit cards to send the army they trained:
## soldiers and engineers walk the street, tanks too, drones fly straight for the tower.
## Defenses shoot by their own stats (Catalog.DEFENSES, "vs" per soldier / tank / air). While
## they move, units fire at the nearest defense in reach (tanks and Heavy Lifters hardest,
## engineers plant charges on defenses right next to the street). A unit that reaches the tower
## hits it. Stars and loot follow the raid rules: the share destroyed (half the tower's health,
## half the defenses) and whether the tower fell.

const HOME_SCENE := "res://scenes/home/home.tscn"
const MAP_SCENE := "res://scenes/syndicate/map.tscn"
## Seconds of fire a unit pours into the tower when it gets there.
const HQ_HIT_SECONDS := 8.0

var base := {}
var army := {}
var unit_levels := {}
var deployed := {}
var force_level := 0
var hq_max := 1.0
var loot_coins := 0
var loot_fuel := 0
var knocked := 0
var defense_count := 0
var autoplay := false
var _loot_total := Vector2i.ZERO


func _ready() -> void:
	MeshKit.look = "leo"
	MeshKit.toy = true
	StructureModels.show_levels = false
	_rng.randomize()
	cam = WorldSetup.create(self, 100.0)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 94.0
	WorldSetup.place_camera(cam, Vector3(0, -3.0, 0))
	# Dev: `--close X,Z` zooms in on a spot of the board (close-up pictures).
	var args := OS.get_cmdline_user_args()
	if OS.is_debug_build() and args.has("--close"):
		var xz := args[args.find("--close") + 1].split(",")
		cam.size = 34.0
		WorldSetup.place_camera(cam, Vector3(float(xz[0]), 0, float(xz[1])))
	_mark_road()
	_build_board()
	_load_base()
	hud = StreetHud.new()
	hud.game = self
	add_child(hud)
	state = State.WAVE
	hud.refresh()
	hud.banner(I18n.t("Attack!"))
	if autoplay:
		_autoplay()
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--no-hud"):
		hud.visible = false


# ---------------------------------------------------------------- the enemy base

func _load_base() -> void:
	var args := OS.get_cmdline_user_args()
	autoplay = OS.is_debug_build() and args.has("--autoplay")
	var enemy_index := GameState.enemy_index
	if args.has("--enemy"):
		enemy_index = int(args[args.find("--enemy") + 1])
	if args.has("--syndicate"):
		GameState.raid_target = "syndicate"
		GameState.syndicate_mission = int(args[args.find("--syndicate") + 1])
	if GameState.raid_target == "syndicate":
		base = Syndicate.base(GameState.syndicate_mission)
	else:
		GameState.raid_target = "enemy"
		base = Bases.enemy(enemy_index, GameState.hq_level())
	var defenses: Array = []
	var others: Array = []
	var hq_level := 1
	for s: Dictionary in base["structures"]:
		var type: String = s["type"]
		if type == "hq":
			hq_level = int(s["level"])
		elif Catalog.is_defense(type):
			defenses.append(s)
		elif not Catalog.is_trap(type) and type != "wall":
			others.append(s)
	_hq = StructureModels.build(self, "hq", hq_level, cell_pos(0.5, 0.5) + Vector3(0, 0.25, 0))
	_hq.scale *= 1.6
	hq_max = Catalog.structure_hp("hq", hq_level) * 2.0
	hq_hp = hq_max
	var syndicate: bool = base.get("syndicate", false)
	if syndicate:
		Syndicate.paint(_hq)
	# Defenses take the plots along the street, the strongest nearest the tower.
	defenses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) > int(b["level"]))
	# Spread them evenly along the street (the list runs from the tower to the entry).
	var spots := _street_plots()
	var picks := []
	var n := mini(defenses.size(), spots.size())
	for i in n:
		picks.append(spots[int(floor(i * spots.size() / float(n)))])
	for i in n:
		var s: Dictionary = defenses[i]
		var cell: Array = picks[i]
		var t := _place_defense(s["type"], int(s["level"]), cell)
		if syndicate:
			Syndicate.paint(t["node"])
	defense_count = towers.size()
	# Everything else fills the plots behind; their loot is what the attack can win.
	var back := _back_plots()
	for s: Dictionary in others:
		var type: String = s["type"]
		var lvl := int(s["level"])
		_loot_total += Vector2i(Catalog.loot_value(type, lvl), Catalog.loot_fuel(type, lvl))
		if back.is_empty():
			continue
		var cell: Array = back.pop_front()
		StructureModels.build(self, type, lvl, cell_pos(cell[0], cell[1]) + Vector3(0, 0.27, 0)).scale *= 1.15
	_load_army(args, syndicate)


## Free plots that touch the street, ordered from the tower back to the entry.
func _street_plots() -> Array:
	var best := {}
	var progress := 0.0
	for i in range(1, PATH.size()):
		var a: Vector2 = PATH[i - 1]
		var b: Vector2 = PATH[i]
		var steps := int(ceil(a.distance_to(b) * 2.0))
		for k in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			for dc in [-1, 0, 1]:
				for dr in [-1, 0, 1]:
					var cell := [int(round(p.x)) + dc, int(round(p.y)) + dr]
					var key := "%d,%d" % cell
					if free_plot(cell) and not best.has(key):
						best[key] = [progress + float(k) / steps, cell]
		progress += 1.0
	var list: Array = best.values()
	list.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	return list.map(func(x: Array) -> Array: return x[1])


func _back_plots() -> Array:
	var list := []
	for c in GRID:
		for r in GRID:
			if free_plot([c, r]):
				list.append([c, r])
	return list


func _place_defense(type: String, lvl: int, cell: Array) -> Dictionary:
	var d := Catalog.make_defense(type)
	add_child(d)
	var stats := Catalog.defense_stats(type, lvl)
	d.setup(stats, 0.27)
	d.scale = Vector3.ONE * 1.5
	d.position = cell_pos(cell[0], cell[1])
	var hp := Catalog.structure_hp(type, lvl)
	var t := {"type": type, "level": lvl, "node": d, "cell": cell, "cd": 0.0, "stats": stats, "hp": hp, "max": hp}
	towers["%d,%d" % cell] = t
	return t


# ---------------------------------------------------------------- the army

func _load_army(args: PackedStringArray, syndicate: bool) -> void:
	var plan: Dictionary = GameState.army
	if syndicate:
		var force := Syndicate.force(int(base["mission"]))
		plan = force["army"]
		force_level = int(force["level"])
	if autoplay and (not syndicate or args.has("--army")):
		plan = {"infantry": 4, "engineers": 2, "armor": 2, "courier": 2, "scout": 2, "heavy": 1}
		if args.has("--army"):
			plan = {}
			for part: String in args[args.find("--army") + 1].split(","):
				plan[part.get_slice(":", 0)] = int(part.get_slice(":", 1))
	for type in Catalog.UNIT_ORDER:
		var n := int(plan.get(type, 0))
		if n > 0:
			army[type] = n
			unit_levels[type] = force_level if force_level > 0 else int(GameState.units.get(type, 1))


func _stats(type: String) -> Dictionary:
	return Catalog.unit_stats(type, force_level) if force_level > 0 else GameState.unit_stats_for(type)


func send(type: String) -> void:
	if state != State.WAVE or int(army.get(type, 0)) <= 0:
		Audio.play("click", -12.0)
		return
	army[type] = int(army[type]) - 1
	deployed[type] = int(deployed.get(type, 0)) + 1
	_spawn_unit(type)
	Audio.play("deploy", -6.0)
	hud.refresh()


func _spawn_unit(type: String) -> void:
	var stats := _stats(type)
	var lvl: int = unit_levels.get(type, 1)
	var air := Catalog.DRONES.has(type)
	var squad := int(stats.get("squad", 1))
	var hp := float(stats["health"]) * squad
	var e := {"hp": hp, "speed": float(stats["speed"]) / CELL, "hit": float(stats["dps"]) * squad * HQ_HIT_SECONDS,
		"dps": float(stats["dps"]) * squad, "range": float(stats.get("range", 8.0)), "kind": type}
	e["base_speed"] = e["speed"]
	if air:
		e["air"] = true
	var root := Node3D.new()
	add_child(root)
	var model := Node3D.new()
	root.add_child(model)
	var parts := {}
	var men: Array = []
	match type:
		"armor":
			parts = UnitModels.build("armor", model, lvl)
			model.scale = Vector3.ONE * 2.5
		"infantry", "engineers":
			# A squad walks as a little group of soldiers.
			for i in mini(squad, 3):
				var man := Node3D.new()
				man.position = Vector3((i - 1) * 1.6, 0, (i % 2) * 1.4 - 0.7)
				model.add_child(man)
				var p := UnitModels.build(type, man, lvl)
				men.append(p)
				if i == 0:
					parts = p
			model.scale = Vector3.ONE * 3.4
		_:
			parts = DroneModels.build(type, model)
			model.scale = Vector3.ONE * 3.0
			model.position.y = 8.0
	# Each unit keeps its own lane across the street, so they don't stand inside one another.
	if not air:
		model.position.x = _rng.randf_range(-2.0, 2.0)
	MeshKit.blob(model, Vector2(5.0, 5.0) / model.scale.x * (1.6 if type == "armor" else 1.0), Vector3(0, 0.25 / model.scale.x, 0), 0.4)
	root.position = cell_pos(PATH[0].x, PATH[0].y)
	foes.append({"kind": type, "e": e, "hp": hp, "max": hp, "node": root, "model": model, "parts": parts,
		"seg": 0, "prog": 0.0, "air": air, "t": _rng.randf() * 6.0, "cd": 0.0, "men": men, "phase": _rng.randf() * TAU,
		"aim": 0.0, "recoil": 0.0})
	_pop(root, 0.2)


## Dev, for recordings: `-- --autoplay` sends the army by itself, a unit every second.
func _autoplay() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	add_child(timer)
	var order := ["armor", "infantry", "engineers", "infantry", "courier", "heavy", "scout", "infantry"]
	var i := [0]
	timer.timeout.connect(func() -> void:
		for k in order.size():
			var type: String = order[(i[0] + k) % order.size()]
			if int(army.get(type, 0)) > 0:
				send(type)
				i[0] += k + 1
				return)


# ---------------------------------------------------------------- battle

## Holding a finger on the board shows every defense's reach (green ground, blue air) until it
## lets go (plan sketch SQhYwaeWJpKTv5HjygjboU).
var _ranges_hold := -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_ranges_hold = Time.get_ticks_msec()
		else:
			_ranges_hold = -1
			_show_ranges(false)


func _show_ranges(on: bool) -> void:
	for t: Dictionary in towers.values():
		var d: Defense = t["node"]
		if is_instance_valid(d):
			var ring = d.get("_ring")
			if ring is Node3D:
				# The battle reaches 1.8x the stat radius; the defense node is scaled 1.5.
				(ring as Node3D).scale = Vector3.ONE * 1.2
			d.show_range(on)


func _process(delta: float) -> void:
	if _ranges_hold > 0 and Time.get_ticks_msec() - _ranges_hold > 420:
		_ranges_hold = -1
		_show_ranges(true)
		Audio.buzz(15)
	if state == State.WAVE:
		_jam(delta)
		_move_foes(delta)
		_fire(delta)
		_units_fire(delta)
		var left := 0
		for k in army:
			left += int(army[k])
		if hq_hp <= 0.0:
			hq_hp = 0.0
			_finish(true)
		elif left == 0 and foes.filter(func(f: Dictionary) -> bool: return not f.get("gone", false)).is_empty():
			_finish(false)
	hud.queue_redraw_overlay()


## Jammers slow drones in their circle to half speed.
func _jam(_delta: float) -> void:
	for f: Dictionary in foes:
		if f["air"]:
			f["e"]["speed"] = f["e"]["base_speed"]
	for t: Dictionary in towers.values():
		if t["type"] != "jammer":
			continue
		var r: float = float(t["stats"]["radius"]) * 1.8
		for f: Dictionary in foes:
			if f["air"] and not f.get("gone", false) and (f["node"] as Node3D).position.distance_to((t["node"] as Node3D).position) < r:
				f["e"]["speed"] = f["e"]["base_speed"] * 0.5


func _move_foes(delta: float) -> void:
	super._move_foes(delta)
	for f: Dictionary in foes:
		if f.get("gone", false):
			continue
		f["recoil"] = maxf(0.0, float(f["recoil"]) - delta * 3.0)
		var speed: float = float(f["e"]["speed"]) * CELL
		if f["kind"] in ["infantry", "engineers"]:
			# The soldiers walk on their leg skeletons, like in the old raid (GroundUnit).
			f["phase"] = float(f["phase"]) + delta * speed * 2.6 / 2.2
			for i in (f["men"] as Array).size():
				var p: Dictionary = f["men"][i]
				var ph: float = float(f["phase"]) + i * 1.7
				var swing := sin(ph) * 0.6
				var sk: Skeleton3D = p.get("skeleton")
				if sk != null:
					sk.set_bone_pose_rotation(1, Quaternion(Vector3.RIGHT, -swing))
					sk.set_bone_pose_rotation(2, Quaternion(Vector3.RIGHT, swing))
					sk.set_bone_pose_rotation(3, Quaternion(Vector3.RIGHT, maxf(0.0, cos(ph)) * 0.6))
					sk.set_bone_pose_rotation(4, Quaternion(Vector3.RIGHT, maxf(0.0, -cos(ph)) * 0.6))
				else:
					var hips: Array = p.get("hips", [])
					if hips.size() == 2:
						(hips[0] as Node3D).rotation.x = swing
						(hips[1] as Node3D).rotation.x = -swing
				var torso = p.get("torso")
				if torso is Node3D:
					(torso as Node3D).position.y = 0.5 + absf(sin(ph)) * 0.03
					(torso as Node3D).position.z = -0.04 * float(f["recoil"])
		elif f["kind"] == "armor":
			var parts: Dictionary = f["parts"]
			for wheel in parts.get("wheels", []):
				(wheel as Node3D).rotation.x += speed * delta / 0.3
			var turret = parts.get("turret")
			if turret is Node3D:
				(turret as Node3D).rotation.y = lerp_angle((turret as Node3D).rotation.y, float(f["aim"]), delta * 4.0)
			var gun = parts.get("gun")
			if gun is Node3D:
				(gun as Node3D).position.z = 1.0 - float(f["recoil"]) * 0.45


## Defenses fire by their own stats: steady fire (dps) or single heavy shots (damage, cooldown),
## times how well they hit this kind of unit; mortars splash and cannot hit what is too close.
func _fire(delta: float) -> void:
	for t: Dictionary in towers.values():
		var s: Dictionary = t["stats"]
		if t["type"] == "jammer":
			continue
		var d: Defense = t["node"]
		var reach: float = float(s["radius"]) * 1.8
		var near: float = float(s.get("min_radius", 0.0)) * 1.8
		var best = null
		var best_f := 0.0
		for f: Dictionary in foes:
			if f["hp"] <= 0.0 or f.get("gone", false):
				continue
			var factor := _factor(s, f)
			if factor <= 0.0:
				continue
			var p: Vector3 = (f["node"] as Node3D).position
			var dist := Vector2(p.x - d.position.x, p.z - d.position.z).length()
			if dist > reach or dist < near:
				continue
			if best == null or f["prog"] > best["prog"]:
				best = f
				best_f = factor
		if best == null:
			continue
		var aim: Vector3 = (best["node"] as Node3D).position + Vector3(0, 8.0 if best["air"] else 2.4, 0)
		var pivot = d.get("_pivot")
		if pivot is Node3D:
			var to := aim - d.position
			(pivot as Node3D).rotation.y = rotate_toward((pivot as Node3D).rotation.y, atan2(to.x, to.z), 8.0 * delta)
		t["cd"] -= delta
		if t["cd"] > 0.0:
			continue
		var head := d.position + Vector3(0, 4.6, 0)
		var target: Dictionary = best
		if s.has("dps"):
			t["cd"] = 0.3
			var dmg: float = float(s["dps"]) * 0.3 * best_f
			Fx.flash(self, head, 0.3)
			Fx.tracer(self, head, aim, Color(1.0, 0.82, 0.29) if not best["air"] else Color(0.6, 0.85, 1.0), 0.08, 0.07)
			Audio.play("rifle", -16.0, 0.08)
			_hurt(target, dmg)
		elif t["type"] == "mortar":
			t["cd"] = float(s["cooldown"])
			var ground := Vector3(aim.x, 0.3, aim.z)
			var splash: float = float(s.get("splash", 3.0)) * 1.8
			var dmg: float = float(s["damage"])
			Fx.flash(self, head, 0.6)
			Audio.play("cannon", -10.0, 0.1)
			Fx.lob(self, head, ground, 0.8, func() -> void:
				Fx.boom(self, ground, 0.7)
				for o: Dictionary in foes:
					if not o["air"] and o["hp"] > 0.0 and not o.get("gone", false) and (o["node"] as Node3D).position.distance_to(ground) <= splash:
						_hurt(o, dmg * _factor(s, o)))
		else:
			t["cd"] = float(s["cooldown"])
			var dmg: float = float(s["damage"]) * best_f
			Fx.flash(self, head, 0.6)
			Audio.play("cannon", -10.0, 0.1)
			Fx.shell(self, head, aim, 0.25, func() -> void:
				if is_instance_valid(target["node"]):
					Fx.boom(self, (target["node"] as Node3D).position + Vector3(0, 2, 0), 0.5)
				_hurt(target, dmg))


func _factor(stats: Dictionary, f: Dictionary) -> float:
	var vs: Dictionary = stats.get("vs", {})
	if f["air"]:
		return float(vs.get("air", 0.0))
	if f["kind"] == "armor":
		return float(vs.get("tank", 0.0))
	return float(vs.get("soldier", 0.0))


## Units fire on the move at the nearest defense in reach. Tanks and Heavy Lifters fire shells;
## the others small arms; engineers plant charges on defenses right next to the street.
func _units_fire(delta: float) -> void:
	for f: Dictionary in foes:
		if f.get("gone", false) or towers.is_empty():
			continue
		f["cd"] -= delta
		if f["cd"] > 0.0:
			continue
		var e: Dictionary = f["e"]
		var at: Vector3 = (f["node"] as Node3D).position
		var reach: float = (CELL * 1.3) if e["kind"] == "engineers" else maxf(float(e["range"]) * 1.8, CELL * 2.2)
		var best = null
		var best_d := INF
		for t: Dictionary in towers.values():
			var dist := Vector2((t["node"] as Node3D).position.x - at.x, (t["node"] as Node3D).position.z - at.z).length()
			if dist <= reach and dist < best_d:
				best = t
				best_d = dist
		if best == null:
			continue
		var heavy: bool = e["kind"] in ["armor", "heavy"]
		var every := 1.5 if heavy else 0.45
		f["cd"] = every
		var dmg: float = float(e["dps"]) * every * (2.0 if e["kind"] == "engineers" else 1.0)
		var hit: Dictionary = best
		var from := at + Vector3(0, 8.0 if f["air"] else 2.6, 0)
		var to: Vector3 = (hit["node"] as Node3D).position + Vector3(0, 2.0, 0)
		f["recoil"] = 1.0
		if e["kind"] == "armor":
			# The turret swings to the target and the shell leaves its muzzle.
			var model: Node3D = f["model"]
			var local := model.global_transform.basis.inverse() * (to - model.global_position)
			f["aim"] = atan2(local.x, local.z)
			var muzzle = (f["parts"] as Dictionary).get("muzzle")
			if muzzle is Node3D:
				from = (muzzle as Node3D).global_position
		if heavy:
			Fx.flash(self, from, 0.9)
			Audio.play("cannon", -8.0, 0.1)
			Fx.shell(self, from, to, 0.3, func() -> void:
				Fx.boom(self, to, 0.5)
				_damage_tower(hit, dmg))
		elif e["kind"] == "engineers":
			Fx.flash(self, to, 1.0, Color(1.0, 0.7, 0.3))
			Audio.play("breach", -10.0, 0.2)
			_damage_tower(hit, dmg)
		else:
			# Every soldier of the squad (or the drone) fires: a muzzle flash and a tracer each.
			var guns: Array = []
			for p: Dictionary in f["men"]:
				if p.get("muzzle") is Node3D:
					guns.append((p["muzzle"] as Node3D).global_position)
			if guns.is_empty():
				guns.append(from)
			for g: Vector3 in guns:
				Fx.flash(self, g, 0.35)
				Fx.tracer(self, g, to + Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.8), randf_range(-0.8, 0.8)), Color(1.0, 0.86, 0.45), 0.12, 0.14)
			Audio.play("rifle", -12.0, 0.06)
			_damage_tower(hit, dmg)


func _damage_tower(t: Dictionary, dmg: float) -> void:
	if not towers.values().has(t):
		return
	t["hp"] -= dmg
	if t["hp"] > 0.0:
		return
	towers.erase("%d,%d" % [t["cell"][0], t["cell"][1]])
	var at := (t["node"] as Node3D).position
	(t["node"] as Node3D).queue_free()
	Fx.boom(self, at + Vector3(0, 1.5, 0), 1.6)
	Fx.smoke(self, at + Vector3(0, 1.5, 0), 3.0)
	Audio.play("collapse", -4.0)
	knocked += 1
	hud.refresh()


func _leak(f: Dictionary) -> void:
	f["gone"] = true
	hq_hp -= float(f["e"]["hit"]) * clampf(f["hp"] / f["max"] + 0.25, 0.25, 1.0)
	var at := (f["node"] as Node3D).position
	(f["node"] as Node3D).queue_free()
	Fx.boom(self, at + Vector3(0, 2, 0), 1.0)
	Fx.shake(self, 0.8)
	Audio.play("impact", -2.0)
	_pop(_hq, 0.92)
	if hq_hp <= 0.0:
		Fx.boom(self, _hq.position + Vector3(0, 6, 0), 3.0)
	hud.refresh()


func _hurt(f: Dictionary, dmg: float) -> void:
	if f["hp"] <= 0.0 or f.get("gone", false):
		return
	f["hp"] -= dmg
	if f["hp"] > 0.0:
		return
	f["gone"] = true
	var node: Node3D = f["node"]
	var at := node.position + Vector3(0, 8.0 if f["air"] else 2.0, 0)
	if f["kind"] in ["infantry", "engineers"]:
		Fx.flash(self, at, 0.8, Color(1.0, 0.6, 0.3))
		Fx.smoke(self, at, 1.5)
		Audio.play("soldier_down", -8.0, 0.05)
	else:
		Fx.boom(self, at, 0.8)
		Audio.play("drone_down" if f["air"] else "tank_down", -6.0)
	node.queue_free()
	hud.refresh()


# ---------------------------------------------------------------- result

## The share of the base destroyed: half the tower's health, half the defenses.
func destroyed_ratio() -> float:
	var tower := 1.0 - clampf(hq_hp / hq_max, 0.0, 1.0)
	var guns := float(knocked) / float(defense_count) if defense_count > 0 else tower
	return 0.5 * tower + 0.5 * guns


func _finish(won: bool) -> void:
	if state in [State.WON, State.LOST]:
		return
	state = State.WON if won else State.LOST
	Engine.time_scale = 1.0
	var ratio := 1.0 if won and knocked >= defense_count else destroyed_ratio()
	var stars := RaidRules.battle_stars(ratio, won)
	loot_coins = int(round(_loot_total.x * ratio))
	loot_fuel = int(round(_loot_total.y * ratio))
	var gained := {"coins": loot_coins, "fuel": loot_fuel}
	if not autoplay:
		gained = GameState.record_raid(stars, loot_coins, loot_fuel)
		if GameState.raid_target == "enemy":
			GameState.use_army(deployed)
	var extra := ""
	if base.get("syndicate", false):
		var lines: Array = Syndicate.LOSE_LINES if stars > 0 else Syndicate.WIN_LINES
		extra = I18n.t("Razor: \"%s\"") % I18n.t(lines[randi() % lines.size()])
	(hud as StreetHud).show_result(stars, int(round(ratio * 100.0)), gained, extra)
	Audio.play("star" if stars > 0 else "collapse")


## True when the army has units left for another attack on this target.
func can_attack_again() -> bool:
	if autoplay:
		return true
	if GameState.raid_target == "syndicate":
		return true
	for k in GameState.army:
		if int(GameState.army[k]) > 0:
			return true
	return false


func go_home() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAP_SCENE if GameState.raid_target == "syndicate" else HOME_SCENE)
