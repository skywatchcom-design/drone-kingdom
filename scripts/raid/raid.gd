extends Node3D
## A Clash-style attack. Pick a unit card, tap outside the base to send it in, and the units
## take it from there: each goes for the structure its role prefers while the defenses
## fight back. Drones fly over everything; soldiers and tanks walk, and the fence stops them:
## they come in through the gate or through a hole the engineers blow. Stars for 50%, the
## Command Tower, and 100%. Loot comes out of every generator, pump, store and Command Tower.
## Deployed units are used up (practice runs on your own base are free).
## Each Quarters sends out an infantry squad to defend when attackers come close; attacking
## soldiers and tanks fight them when they are in range.
## Run with `-- --autoplay` to deploy a full army automatically (used for screenshots), and
## `--enemy N` to pick which enemy base, `--army infantry:2,courier:2` to pick the army.

enum Phase { BATTLE, RESULT }

const HOME_SCENE := "res://scenes/home/home.tscn"
const VIEW_SIZE := 50.0
const TRAVEL_ALT := 11.0
const DEPLOY_CLEARANCE := 6.5
const MAP_LIMIT := 46.0
const TAP_SLOP := 24.0
const PAN_LIMIT := 30.0
## Half the footprint of a structure, for ground units' firing range and avoidance.
const STRUCTURE_RADIUS := 2.7
## How wide a hole the engineers' charge blows in the fence.
const BREACH_WIDTH := 6.0
const BOLT_COLORS := {
	"courier": Color(0.4, 0.95, 1.0),
	"scout": Color(1.0, 0.75, 0.25),
	"heavy": Color(1.0, 0.4, 0.3),
}

var phase: Phase = Phase.BATTLE
var base: Dictionary
var level: Node3D
var city: City
var cam: Camera3D
var hud: RaidHud
## One entry per structure: {type, level, cell, top, hp, max_hp, node, defense, is_defense,
## loot, loot_fuel, destroyed}. `loot` counts coins plus fuel, so drones that go for loot
## treat fuel buildings as loot too.
var targets: Array[Dictionary] = []
var drones: Array[Drone] = []
var ground: Array[GroundUnit] = []
## The base's own soldiers, out of its Quarters.
var defenders: Array[GroundUnit] = []
## Target indexes of Quarters that have already sent out their squad.
var quarters_called := {}
var army := {}
## Units sent in, by type; they are used up when the battle ends.
var deployed := {}
var drone_names := {}
## Points on the fence line where ground units can cross: the gate, then any breaches.
var openings: Array = [City.gate_point()]
## Breaches an engineer is on the way to blow, so the other engineers don't double up.
var pending_breaches: Array = []
var selected := ""
var started := false
var time_left := Catalog.BATTLE_SECONDS
var loot_gained := 0
var fuel_gained := 0
var end_timer := -1.0
var focus := Vector3(0, 10, 0)
var press_pos := Vector2.ZERO
var autoplay := false


func _ready() -> void:
	Engine.time_scale = 1.0
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	cam = WorldSetup.create(self, VIEW_SIZE)
	hud = RaidHud.new()
	add_child(hud)
	hud.unit_selected.connect(_on_unit_selected)
	hud.end_pressed.connect(_finish)
	hud.retry_pressed.connect(func() -> void: get_tree().reload_current_scene())
	hud.home_pressed.connect(func() -> void: get_tree().change_scene_to_file(HOME_SCENE))
	_start()


func _start() -> void:
	var enemy_index := GameState.enemy_index
	var args := OS.get_cmdline_user_args()
	if args.has("--enemy"):
		enemy_index = int(args[args.find("--enemy") + 1])
	base = GameState.player_base() if GameState.raid_target == "self" else Bases.enemy(enemy_index, GameState.hq_level())
	level = Node3D.new()
	add_child(level)
	var reserved: Array = []
	for s in base["structures"]:
		reserved.append(s["cell"])
	city = City.new()
	level.add_child(city)
	city.build(int(base["seed"]), reserved)

	for s in base["structures"]:
		var type: String = s["type"]
		var lvl := int(s["level"])
		var top := city.roof_top(s["cell"])
		var node: Node3D
		var defense: Defense = null
		if Catalog.is_defense(type):
			defense = Catalog.make_defense(type)
			level.add_child(defense)
			defense.position = City.cell_pos(s["cell"])
			defense.setup(Catalog.defense_stats(type, lvl), city.roof_y(s["cell"]))
			node = defense
		else:
			node = StructureModels.build(level, type, lvl, top)
		var hp := Catalog.structure_hp(type, lvl)
		targets.append({
			"type": type, "level": lvl, "cell": s["cell"], "top": top, "hp": hp, "max_hp": hp,
			"node": node, "defense": defense, "is_defense": defense != null,
			"loot": Catalog.loot_value(type, lvl) + Catalog.loot_fuel(type, lvl),
			"loot_coins": Catalog.loot_value(type, lvl), "loot_fuel": Catalog.loot_fuel(type, lvl), "destroyed": false,
		})

	var plan: Dictionary = GameState.army
	if autoplay:
		plan = {"infantry": 3, "engineers": 1, "armor": 1, "courier": 2, "scout": 2, "heavy": 1}
		if args.has("--army"):
			plan = {}
			for part: String in args[args.find("--army") + 1].split(","):
				plan[part.get_slice(":", 0)] = int(part.get_slice(":", 1))
	for type in Catalog.UNIT_ORDER:
		var n := int(plan.get(type, 0))
		if n > 0:
			army[type] = n
			drone_names[type] = Catalog.display_name(type)
	selected = _first_available()
	hud.set_title(base["name"])
	hud.set_army(army, drone_names, selected)
	hud.set_timer(time_left)
	hud.set_loot(0, 0)
	_update_progress()
	hud.set_status(I18n.t("Tap outside the fence to send in your army"))
	if autoplay:
		_autoplay_deploy()


# ---------------------------------------------------------------- deploying

func _on_unit_selected(type: String) -> void:
	selected = type
	hud.update_army(army, drone_names, selected)


func _first_available() -> String:
	for type in army:
		if int(army[type]) > 0:
			return type
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_pan((event as InputEventScreenDrag).relative)
		return
	if event is InputEventMouseButton and event.pressed:
		var wheel := event as InputEventMouseButton
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.size = maxf(36.0, cam.size - 4.0)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.size = minf(90.0, cam.size + 4.0)
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		press_pos = touch.position
		return
	if hud.blocks(touch.position) or touch.position.distance_to(press_pos) > TAP_SLOP:
		return
	_try_deploy(touch.position)


func _try_deploy(screen_pos: Vector2) -> void:
	if phase != Phase.BATTLE:
		return
	if selected == "" or int(army.get(selected, 0)) <= 0:
		hud.set_status(I18n.t("No units left to send"))
		return
	if Catalog.is_ground(selected):
		var ground_hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
		if ground_hit == null:
			return
		var g: Vector3 = ground_hit
		if absf(g.x) > MAP_LIMIT or absf(g.z) > MAP_LIMIT:
			return
		if absf(g.x) < City.YARD + 1.5 and absf(g.z) < City.YARD + 1.5:
			hud.set_status(I18n.t("Ground units start outside the fence."))
			return
		_deploy_ground(selected, g)
		return
	var hit = Plane(Vector3.UP, TRAVEL_ALT).intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	if hit == null:
		return
	var p: Vector3 = hit
	if absf(p.x) > MAP_LIMIT or absf(p.z) > MAP_LIMIT:
		return
	for t in targets:
		if PathUtils.flat_distance(t["top"], p) < DEPLOY_CLEARANCE:
			hud.set_status(I18n.t("Too close to a building. Release drones outside the base."))
			return
	_deploy(selected, p)


func _deploy(type: String, p: Vector3) -> void:
	army[type] = int(army[type]) - 1
	deployed[type] = int(deployed.get(type, 0)) + 1
	var stats := GameState.unit_stats_for(type)
	var d := Drone.new()
	d.configure(stats)
	d.kind = type
	d.invulnerable = false
	level.add_child(d)
	d.position = p
	drones.append(d)
	d.crashed.connect(func() -> void: Audio.play("drone_down", -4.0))
	Audio.play("deploy", -3.0)
	Audio.buzz(15)
	started = true
	if int(army[type]) <= 0:
		selected = _first_available()
	hud.update_army(army, drone_names, selected)
	hud.set_status("")


## A card's worth of ground units: an infantry squad of four, two engineers, or one tank,
## lined up facing the base.
func _deploy_ground(type: String, p: Vector3) -> void:
	army[type] = int(army[type]) - 1
	deployed[type] = int(deployed.get(type, 0)) + 1
	var stats := GameState.unit_stats_for(type)
	var count := int(stats.get("squad", 1))
	var facing := atan2(-p.x, -p.z)
	var right := Vector3(cos(facing), 0, -sin(facing))
	var back := -Vector3(sin(facing), 0, cos(facing))
	var offsets := [Vector3.ZERO]
	if count == 4:
		offsets = [Vector3.ZERO, right * -1.4 + back * 1.2, right * 1.4 + back * 1.2, back * 2.4]
	elif count == 2:
		offsets = [right * -0.9, right * 0.9]
	for i in count:
		var u := GroundUnit.new()
		u.configure(stats)
		u.kneels = i % 2 == 0
		u.invulnerable = false
		u.rotation.y = facing
		u.position = p + offsets[i]
		level.add_child(u)
		ground.append(u)
		u.crashed.connect(func() -> void:
			Audio.play("tank_down" if u.is_tank() else "soldier_down", -4.0)
			u.knock_out(level))
	Audio.play("deploy", -3.0)
	Audio.buzz(15)
	started = true
	if int(army[type]) <= 0:
		selected = _first_available()
	hud.update_army(army, drone_names, selected)
	hud.set_status("")


func _autoplay_deploy() -> void:
	var spots := [Vector3(30, TRAVEL_ALT, 34), Vector3(36, TRAVEL_ALT, 24), Vector3(34, TRAVEL_ALT, 30)]
	var ground_spots := [Vector3(12, 0, 44), Vector3(-22, 0, 42), Vector3(26, 0, 42), Vector3(-6, 0, 45)]
	var i := 0
	for type in army.keys():
		while int(army[type]) > 0:
			if Catalog.is_ground(type):
				var spot: Vector3 = Vector3(-44, 0, 4) if type == "engineers" else ground_spots[i % ground_spots.size()]
				_deploy_ground(type, spot)
			else:
				_deploy(type, spots[i % spots.size()] + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
			i += 1


# ---------------------------------------------------------------- battle loop

func _process(delta: float) -> void:
	var alive: Array = []
	for d in drones:
		d.jammed = false
		if not d.dead:
			alive.append(d)
	var alive_ground: Array = []
	for u in ground:
		if not u.dead:
			alive_ground.append(u)
	var everyone := alive + alive_ground
	var alive_defenders: Array = []
	for u in defenders:
		if not u.dead:
			alive_defenders.append(u)
	for t in targets:
		if t["destroyed"] or t["defense"] == null:
			continue
		(t["defense"] as Defense).tick(delta, everyone if phase == Phase.BATTLE else [])
	if phase == Phase.BATTLE:
		if started:
			time_left -= delta
			hud.set_timer(time_left)
		Audio.hum(minf(1.0, alive.size() / 5.0))
		for d: Drone in alive:
			_drone_ai(d, delta)
		for u: GroundUnit in alive_ground:
			_ground_ai(u, delta, alive_ground, alive_defenders)
		_call_defenders(everyone)
		for u: GroundUnit in alive_defenders:
			_defender_ai(u, delta, everyone, alive_defenders)
		_check_end(delta)
	else:
		for d: Drone in alive:
			d.steer(Vector3.ZERO, delta)
		for u: GroundUnit in alive_ground + alive_defenders:
			u.walk(Vector3.ZERO, delta)
	_update_bars()


# ---------------------------------------------------------------- defenders

## Each standing Quarters sends out its squad the first time an attacker comes close.
func _call_defenders(attackers: Array) -> void:
	for i in targets.size():
		var t := targets[i]
		if t["type"] != "quarters" or t["destroyed"] or quarters_called.has(i):
			continue
		var top: Vector3 = t["top"]
		if _nearest(top, attackers, Catalog.DEFENDER_ALERT) == null:
			continue
		quarters_called[i] = true
		var stats := Catalog.unit_stats("infantry", int(t["level"]))
		var count := Catalog.defender_count(int(t["level"]))
		for k in count:
			var u := GroundUnit.new()
			u.configure(stats)
			u.kneels = k % 2 == 0
			u.position = top + Vector3(cos(k * 1.7) * 2.0, 0, sin(k * 1.7) * 2.0)
			u.position.y = 0.0
			u.set_meta("home", top)
			level.add_child(u)
			# A red ring underfoot marks the base's own soldiers.
			var ring := MeshKit.add(u, MeshKit.ring(0.9, 0.12), MeshKit.glow(Color(1.0, 0.3, 0.25), 0.8), Vector3(0, 0.08, 0))
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			defenders.append(u)
			u.crashed.connect(func() -> void:
				Audio.play("soldier_down", -4.0)
				ring.visible = false
				u.knock_out(level))
		Audio.play("deploy", -8.0, 0.0)


## Defenders go for the closest attacker near their Quarters (soldiers and tanks before
## drones), and walk back home when there is none.
func _defender_ai(u: GroundUnit, delta: float, attackers: Array, alive_defenders: Array) -> void:
	var home: Vector3 = u.get_meta("home")
	var best: Unit = null
	var best_d := INF
	for a: Unit in attackers:
		if a.dead or PathUtils.flat_distance(a.position, home) > Catalog.DEFENDER_LEASH:
			continue
		var d := PathUtils.flat_distance(a.position, u.position) * (2.5 if a.flying else 1.0)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		if PathUtils.flat_distance(u.position, home) > 3.0:
			_move_ground(u, home, delta, alive_defenders)
		else:
			u.walk(Vector3.ZERO, delta)
		return
	if PathUtils.flat_distance(u.position, best.position) <= u.attack_range + 0.5:
		_shoot_unit(u, best, delta)
	else:
		_move_ground(u, best.position, delta, alive_defenders)


## The closest living unit to `p` within `reach`, or null.
func _nearest(p: Vector3, units: Array, reach: float) -> Unit:
	var best: Unit = null
	var best_d := reach
	for u: Unit in units:
		if u.dead:
			continue
		var d := PathUtils.flat_distance(p, u.position)
		if d <= best_d:
			best_d = d
			best = u
	return best


## A soldier or tank firing at another unit: rifle tracers, or a tank shell.
func _shoot_unit(u: GroundUnit, victim: Unit, delta: float) -> void:
	u.walk(Vector3.ZERO, delta)
	var aim := Defense.aim_point(victim)
	u.aim_at(aim, delta)
	u.fire_cooldown -= delta
	if u.fire_cooldown > 0.0 or not u.aimed_at(aim):
		return
	u.fire_cooldown = u.fire_interval * randf_range(0.85, 1.15)
	u.on_fire()
	var damage := u.dps * u.fire_interval * (0.5 if victim.flying else 1.0)
	var from := u.fire_origin()
	if u.is_tank():
		Audio.play("cannon", -4.0)
		_muzzle_flash(from, 0.9)
		Fx.shell(level, from, aim, 0.15, func() -> void:
			Fx.boom(level, aim, 0.8)
			if is_instance_valid(victim):
				victim.damage(damage))
	else:
		Audio.play("rifle", -12.0, 0.04)
		_muzzle_flash(from, 0.25)
		_thin_tracer(from, aim + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4)))
		victim.damage(damage)


# ---------------------------------------------------------------- ground units

func _ground_ai(u: GroundUnit, delta: float, alive_ground: Array, alive_defenders: Array) -> void:
	if u.kind == "engineers" and u.breach_state != "done":
		_engineer_breach(u, delta, alive_ground)
		return
	# Enemy soldiers in range come first (engineers keep to their charges).
	if u.kind != "engineers":
		var foe := _nearest(u.position, alive_defenders, u.attack_range + 1.0)
		if foe != null:
			_shoot_unit(u, foe, delta)
			return
	if u.target < 0 or targets[u.target]["destroyed"]:
		var prefers := "any" if u.prefers == "fence" else u.prefers
		u.target = RaidRules.pick_target(prefers, u.position, targets)
	if u.target < 0:
		u.walk(Vector3.ZERO, delta)
		return
	var t := targets[u.target]
	var top: Vector3 = t["top"]
	var reach := STRUCTURE_RADIUS + u.attack_range
	# Soldiers outside the fence can shoot over it; engineers have to get right up to a building.
	if PathUtils.flat_distance(u.position, top) <= reach:
		u.walk(Vector3.ZERO, delta)
		u.aim_at(top, delta)
		u.fire_cooldown -= delta
		if u.fire_cooldown <= 0.0 and u.aimed_at(top):
			u.fire_cooldown = u.fire_interval * randf_range(0.85, 1.15)
			_ground_fire(u, u.target)
		return
	var waypoint := RaidRules.ground_waypoint(u.position, top, City.YARD, openings)
	_move_ground(u, waypoint, delta, alive_ground)


## Walks toward `goal`, steering around standing buildings and other units, and never
## through the fence except at an opening.
func _move_ground(u: GroundUnit, goal: Vector3, delta: float, alive_ground: Array) -> void:
	var to := goal - u.position
	to.y = 0.0
	var desired := to.normalized() * u.max_speed * clampf(to.length() / 1.5, 0.0, 1.0)
	var r := u.body_radius()
	for t in targets:
		if t["destroyed"]:
			continue
		var away: Vector3 = u.position - (t["top"] as Vector3)
		away.y = 0.0
		var d := away.length()
		var keep := STRUCTURE_RADIUS + r + 0.4
		if d < keep and d > 0.01:
			desired += away / d * (keep - d) * 4.0
	for other: GroundUnit in alive_ground:
		if other == u:
			continue
		var away := u.position - other.position
		away.y = 0.0
		var d := away.length()
		var keep := r + other.body_radius()
		if d < keep and d > 0.01:
			desired += away / d * (keep - d) * 3.0
	var before := u.position
	u.walk(desired, delta)
	if City.inside_yard(before) != City.inside_yard(u.position) and not _near_opening(u.position):
		u.position = before
		u.velocity = Vector3.ZERO


func _near_opening(p: Vector3) -> bool:
	for o: Vector3 in openings:
		if PathUtils.flat_distance(p, o) < BREACH_WIDTH / 2.0 - 0.6:
			return true
	return false


## Engineers: run to the nearest stretch of fence, kneel and plant a charge, fall back, and
## blow a hole in it. If another engineer is already on it, wait for the hole.
func _engineer_breach(u: GroundUnit, delta: float, alive_ground: Array) -> void:
	match u.breach_state:
		"":
			var spot := City.fence_point(u.position)
			if City.inside_yard(u.position) or _opening_near(spot, openings):
				u.breach_state = "done"
				return
			if _opening_near(spot, pending_breaches):
				u.breach_state = "waiting"
				return
			u.breach_point = spot
			pending_breaches.append(spot)
			u.breach_state = "going"
		"waiting":
			u.walk(Vector3.ZERO, delta)
			if _opening_near(City.fence_point(u.position), openings):
				u.breach_state = "done"
		"going":
			var stand := u.breach_point + RaidRules.fence_normal(u.breach_point) * 1.0
			if PathUtils.flat_distance(u.position, stand) < 0.5:
				u.breach_state = "planting"
				u.breach_timer = 2.0
				u.walk(Vector3.ZERO, delta)
				_plant_charge(u)
			else:
				_move_ground(u, stand, delta, alive_ground)
		"planting":
			u.walk(Vector3.ZERO, delta)
			u.aim_at(u.breach_point, delta)
			u.breach_timer -= delta
			if u.breach_timer <= 0.0:
				u.breach_state = "clear"
				u.breach_timer = 1.6
		"clear":
			_move_ground(u, u.breach_point + RaidRules.fence_normal(u.breach_point) * 6.0, delta, alive_ground)
			u.breach_timer -= delta
			if u.breach_timer <= 0.0:
				_blow_breach(u.breach_point)
				u.breach_state = "done"


func _opening_near(p: Vector3, list: Array) -> bool:
	for o: Vector3 in list:
		if PathUtils.flat_distance(p, o) < BREACH_WIDTH:
			return true
	return false


## A satchel on the fence with a blinking red light, until it goes off.
func _plant_charge(u: GroundUnit) -> void:
	var charge := Node3D.new()
	level.add_child(charge)
	charge.position = u.breach_point + Vector3(0, 0.6, 0)
	MeshKit.add(charge, MeshKit.box(Vector3(0.6, 0.45, 0.35)), MeshKit.mat(Color(0.23, 0.23, 0.18), 0.7))
	var lamp := MeshKit.add(charge, MeshKit.sphere(0.12, 8), MeshKit.glow(Color(1.0, 0.16, 0.16)), Vector3(0, 0.32, 0))
	var tween := create_tween().set_loops(12)
	tween.tween_callback(func() -> void:
		lamp.visible = not lamp.visible
		Audio.play("charge", -14.0))
	tween.tween_interval(0.15)
	charge.set_meta("point", u.breach_point)
	charge.add_to_group("charges")


func _blow_breach(point: Vector3) -> void:
	for charge in get_tree().get_nodes_in_group("charges"):
		if (charge.get_meta("point") as Vector3).is_equal_approx(point):
			charge.queue_free()
	Audio.play("breach")
	Audio.buzz(80)
	var pieces := city.breach(point, BREACH_WIDTH)
	openings.append(point)
	pending_breaches.erase(point)
	_impact(point + Vector3(0, 1.0, 0), Color(1.0, 0.6, 0.2))
	_impact(point + Vector3(0, 1.6, 0), Color(1.0, 1.0, 0.9))
	_dust_ring(point + Vector3(0, 0.1, 0), 7.0, 1.0)
	var smoke := MeshKit.add(level, MeshKit.sphere(1.2, 10), MeshKit.glow(Color(0.35, 0.33, 0.3), 0.7), point + Vector3(0, 1.5, 0))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var st := create_tween()
	st.set_parallel(true)
	st.tween_property(smoke, "scale", Vector3.ONE * 4.0, 1.4)
	st.tween_property(smoke, "position:y", point.y + 5.0, 1.4)
	st.tween_property(smoke.material_override, "albedo_color:a", 0.0, 1.4)
	st.chain().tween_callback(smoke.queue_free)
	# Bits of fence fly off and land inside.
	var wood := MeshKit.mat(Color(0.5, 0.36, 0.22), 0.9)
	var n := RaidRules.fence_normal(point)
	for p: Vector3 in pieces:
		var bit := MeshKit.add(level, MeshKit.box(Vector3(randf_range(0.5, 1.6), 0.12, 0.12)), wood, p + Vector3(0, 0.7, 0))
		var land := p - n * randf_range(2.0, 5.0) + Vector3(randf_range(-1.5, 1.5), 0.08, randf_range(-1.5, 1.5))
		var bt := create_tween()
		bt.set_parallel(true)
		bt.tween_property(bit, "position", Vector3(land.x, 0.08, land.z), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bt.tween_property(bit, "rotation", Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0), 0.7)


## One shot from a soldier or the tank, or an engineer's demolition charge.
func _ground_fire(u: GroundUnit, index: int) -> void:
	var t := targets[index]
	var top: Vector3 = t["top"]
	var damage := u.dps * u.fire_interval
	u.on_fire()
	match u.kind:
		"armor":
			var from := u.fire_origin()
			var hit := top + Vector3(randf_range(-1.0, 1.0), randf_range(1.0, 2.2), randf_range(-1.0, 1.0))
			Audio.play("cannon", -2.0)
			Audio.buzz(30)
			_muzzle_flash(from, 0.9)
			_dust_ring(Vector3(from.x, 0.1, from.z), 3.0, 0.6)
			var shell := MeshKit.add(level, MeshKit.sphere(0.3, 8), MeshKit.glow(Color(1.0, 0.8, 0.4)), from)
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_tracer(from, hit, Color(1.0, 0.76, 0.35))
			var tween := create_tween()
			tween.tween_property(shell, "global_position", hit, 0.15)
			tween.tween_callback(func() -> void:
				shell.queue_free()
				_impact(hit, Color(1.0, 0.55, 0.2))
				_dust_ring(Vector3(hit.x, top.y + 0.1, hit.z), 5.0, 0.8)
				_shake(index)
				_damage_target(index, damage))
		"engineers":
			var spot := top + (u.position - top).normalized() * STRUCTURE_RADIUS * 0.8
			spot.y = top.y + 0.6
			Audio.play("impact", -6.0)
			_impact(spot, Color(1.0, 0.65, 0.25))
			_shake(index)
			_damage_target(index, damage)
		_:
			var from := u.fire_origin()
			var hit := top + Vector3(randf_range(-1.4, 1.4), randf_range(0.5, 2.6), randf_range(-1.4, 1.4))
			Audio.play("rifle", -12.0, 0.04)
			_muzzle_flash(from, 0.25)
			_thin_tracer(from, hit)
			_damage_target(index, damage)


func _muzzle_flash(pos: Vector3, size: float) -> void:
	var flash := MeshKit.add(level, MeshKit.sphere(size, 8), MeshKit.glow(Color(1.0, 0.9, 0.55), 0.95), pos)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.08)
	tween.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.08)
	tween.chain().tween_callback(flash.queue_free)


## A rifle tracer: a thin yellow streak that fades fast, with a tiny spark where it hits.
func _thin_tracer(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	if dir.length() < 0.1:
		return
	var streak := MeshKit.add(level, MeshKit.cyl(0.05, 0.05, 1.0, 5), MeshKit.glow(Color(1.0, 0.85, 0.3), 0.9))
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
	streak.global_transform = Transform3D(b, from + dir * 0.5)
	var spark := MeshKit.add(level, MeshKit.sphere(0.25, 6), MeshKit.glow(Color(1, 1, 0.9), 0.9), to)
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(streak.material_override, "albedo_color:a", 0.0, 0.1)
	tween.tween_property(spark.material_override, "albedo_color:a", 0.0, 0.12)
	tween.chain().tween_callback(func() -> void:
		streak.queue_free()
		spark.queue_free())


func _drone_ai(d: Drone, delta: float) -> void:
	if d.target < 0 or targets[d.target]["destroyed"]:
		var before := d.target
		d.target = RaidRules.pick_target(d.prefers, d.position, targets)
		if d.target >= 0 and d.target != before:
			d.on_new_target()
	if d.target < 0:
		d.steer(Vector3.ZERO, delta)
		return
	var t := targets[d.target]
	var top: Vector3 = t["top"]
	# Each kind works from its own distance: the heavy lifter hangs right above the roof to drop.
	var hover := top + Vector3(cos(d.orbit) * d.hover_radius, d.hover_height, sin(d.orbit) * d.hover_radius)
	var flat := PathUtils.flat_distance(hover, d.position)
	var goal := hover
	if flat > 6.0:
		goal.y = TRAVEL_ALT
	var to := goal - d.position
	var speed := d.max_speed * (0.55 if d.jammed else 1.0)
	var desired := to.normalized() * speed * clampf(to.length() / 3.0, 0.0, 1.0)
	if d.jammed:
		desired = desired.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.005 + d.orbit) * 1.2)
	d.steer(desired, delta)
	var working := flat < 1.6 and absf(d.position.y - hover.y) < 1.5
	if d.kind == "heavy" and (working or flat < 4.0):
		d.dust_cooldown -= delta
		if d.dust_cooldown <= 0.0:
			d.dust_cooldown = 0.5
			_dust_ring(Vector3(d.position.x, top.y + 0.1, d.position.z), 3.5, 1.0)
	if working and d.can_fire():
		d.orbit += delta * (0.25 if d.kind == "heavy" else 0.9)
		d.fire_cooldown -= delta
		if d.fire_cooldown <= 0.0:
			if d.shots_left <= 0:
				d.shots_left = d.burst
			d.shots_left -= 1
			d.fire_cooldown = d.burst_gap if d.shots_left > 0 else d.fire_interval
			if d.kind == "heavy":
				_drop_weight(d, d.target)
			else:
				_fire(d, d.target)


## Damage of one shot, so a full burst cycle deals the drone's damage per second.
func _shot_damage(d: Drone) -> float:
	var cycle := d.fire_interval + d.burst_gap * (d.burst - 1)
	return d.dps * cycle / d.burst


## One shot: a glowing bolt flies to a random spot on the target; damage lands on impact
## with sparks, a flash and a little shake of the building. The drone kicks back.
func _fire(d: Drone, index: int) -> void:
	var t := targets[index]
	var top: Vector3 = t["top"]
	var hit := top + Vector3(randf_range(-1.2, 1.2), randf_range(0.6, 2.4), randf_range(-1.2, 1.2))
	var from := d.fire_origin()
	var color: Color = BOLT_COLORS.get(d.kind, Color(0.4, 0.95, 1.0))
	var bolt := MeshKit.add(level, MeshKit.sphere(0.3 if d.kind == "scout" else 0.42, 8), MeshKit.glow(color), from)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if from.distance_to(hit) > 0.1:
		bolt.look_at(hit, Vector3.UP if absf((hit - from).normalized().y) < 0.99 else Vector3.FORWARD)
	bolt.scale = Vector3(1, 1, 3.5)
	var damage := _shot_damage(d)
	d.on_fire()
	Audio.play("shot_" + d.kind, -6.0, 0.08)
	d.velocity += (from - hit).normalized() * 1.2
	_tracer(from, hit, color)
	var tween := create_tween()
	tween.tween_property(bolt, "global_position", hit, 0.18)
	tween.tween_callback(func() -> void:
		bolt.queue_free()
		_impact(hit, color)
		_shake(index)
		_damage_target(index, damage))


## The heavy lifter lets go of its winch weight. It falls under gravity onto the roof and
## lands with a big hit, a dust ring and a hard jolt of the building.
func _drop_weight(d: Drone, index: int) -> void:
	var t := targets[index]
	var top: Vector3 = t["top"]
	var start := d.fire_origin()
	var land := Vector3(lerpf(start.x, top.x, 0.5), top.y + 0.4, lerpf(start.z, top.z, 0.5))
	var weight := Node3D.new()
	level.add_child(weight)
	weight.global_position = start
	weight.scale = Vector3.ONE * d.body_scale
	MeshKit.add(weight, MeshKit.box(Vector3(0.36, 0.3, 0.36)), MeshKit.mat(Color(0.35, 0.39, 0.43), 0.35, 0.8))
	MeshKit.add(weight, MeshKit.box(Vector3(0.38, 0.06, 0.38)), MeshKit.coat(Color(0.95, 0.72, 0.02)), Vector3(0, 0.1, 0))
	var damage := _shot_damage(d)
	d.on_fire()
	Audio.play("release", -6.0)
	d.velocity.y += 2.5
	var fall := sqrt(2.0 * maxf(start.y - land.y, 0.5) / 22.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(weight, "global_position", land, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(weight, "rotation:x", 1.2, fall)
	tween.chain().tween_callback(func() -> void:
		weight.queue_free()
		Audio.play("thud")
		Audio.buzz(35)
		_impact(land, Color(1.0, 0.8, 0.2))
		_impact(land + Vector3(0, 0.5, 0), Color(1.0, 1.0, 1.0))
		_dust_ring(Vector3(land.x, top.y + 0.1, land.z), 6.0, 0.9)
		_shake(index)
		_damage_target(index, damage))


## A flat ring of dust spreading over a roof (rotor downwash, weight impacts).
func _dust_ring(pos: Vector3, max_scale: float, life: float) -> void:
	var ring := MeshKit.add(level, MeshKit.ring(1.0, 0.18), MeshKit.glow(Color(0.85, 0.79, 0.63), 0.5), pos)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(max_scale, 1.0, max_scale), life)
	tween.tween_property(ring.material_override, "albedo_color:a", 0.0, life)
	tween.chain().tween_callback(ring.queue_free)


## A short-lived streak of light along the shot, so every shot reads even on a small screen.
func _tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var dir := to - from
	if dir.length() < 0.1:
		return
	var streak := MeshKit.add(level, MeshKit.cyl(0.14, 0.14, 1.0, 6), MeshKit.glow(color, 0.8))
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
	streak.global_transform = Transform3D(b, from + dir * 0.5)
	var tween := create_tween()
	tween.tween_property(streak.material_override, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(streak.queue_free)


func _impact(pos: Vector3, color: Color) -> void:
	Audio.play("impact", -14.0, 0.12)
	var flash := MeshKit.add(level, MeshKit.sphere(1.1, 12), MeshKit.glow(Color(1, 1, 1), 0.9), pos)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.6, 0.18)
	tween.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.18)
	tween.chain().tween_callback(flash.queue_free)
	for i in 9:
		var spark := MeshKit.add(level, MeshKit.sphere(0.26, 6), MeshKit.glow(color.lerp(Color(1, 0.8, 0.3), randf())), pos)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
		var st := create_tween()
		st.set_parallel(true)
		st.tween_property(spark, "position", pos + dir * randf_range(2.0, 3.5), 0.35)
		st.tween_property(spark, "scale", Vector3.ONE * 0.05, 0.35)
		st.chain().tween_callback(spark.queue_free)


## Buildings jolt when hit. Defenses are rooted at street level, so they only get sparks.
func _shake(index: int) -> void:
	var t := targets[index]
	if t["destroyed"] or t["defense"] != null:
		return
	var node: Node3D = t["node"]
	if node.has_meta("shaking"):
		return
	node.set_meta("shaking", true)
	var rest := node.scale
	var tween := create_tween()
	tween.tween_property(node, "scale", rest * Vector3(1.12, 0.9, 1.12), 0.05)
	tween.tween_property(node, "scale", rest, 0.08)
	tween.tween_callback(func() -> void: node.remove_meta("shaking"))


func _damage_target(index: int, amount: float) -> void:
	var t := targets[index]
	if t["destroyed"]:
		return
	t["hp"] = maxf(0.0, float(t["hp"]) - amount)
	if t["hp"] <= 0.0:
		_destroy(index)


func _destroy(index: int) -> void:
	var t := targets[index]
	t["destroyed"] = true
	Audio.play("collapse")
	Audio.buzz(60)
	var top: Vector3 = t["top"]
	if t["defense"] != null:
		(t["defense"] as Defense).disable()
	else:
		(t["node"] as Node3D).visible = false
	_rubble(top)
	var loot := int(t["loot_coins"])
	var loot_fuel := int(t["loot_fuel"])
	if loot > 0 or loot_fuel > 0:
		loot_gained += loot
		fuel_gained += loot_fuel
		hud.set_loot(loot_gained, fuel_gained)
	if loot > 0:
		_float_text(top + Vector3(0, 3, 0), "+%d" % loot, Color(1.0, 0.85, 0.3))
	if loot_fuel > 0:
		_float_text(top + Vector3(0, 4.6, 0), "+%d" % loot_fuel, Color(1.0, 0.55, 0.75))
	_update_progress()


func _check_end(delta: float) -> void:
	var standing := false
	for t in targets:
		if not t["destroyed"]:
			standing = true
			break
	var flying := false
	for d in drones:
		if not d.dead:
			flying = true
			break
	for u in ground:
		if not u.dead:
			flying = true
			break
	var reserves := _first_available() != ""
	var over := not standing or (started and time_left <= 0.0) or (started and not flying and not reserves)
	if over and end_timer < 0.0:
		end_timer = 1.5
	if end_timer >= 0.0:
		end_timer -= delta
		if end_timer < 0.0:
			_finish()


func _finish() -> void:
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	var ratio := _destroyed_ratio()
	var hq_down := false
	for t in targets:
		if t["type"] == "hq" and t["destroyed"]:
			hq_down = true
	var stars := RaidRules.battle_stars(ratio, hq_down)
	var gained := {"coins": 0, "fuel": 0}
	if not autoplay:
		gained = GameState.record_raid(stars, loot_gained, fuel_gained)
		if GameState.raid_target == "enemy":
			GameState.use_army(deployed)
	Audio.hum(0.0)
	for i in stars:
		get_tree().create_timer(0.35 * i + 0.2).timeout.connect(func() -> void: Audio.play("star"))
	hud.show_result(stars, int(round(ratio * 100.0)), gained, GameState.raid_target == "self")


func _destroyed_ratio() -> float:
	if targets.is_empty():
		return 0.0
	var n := 0
	for t in targets:
		if t["destroyed"]:
			n += 1
	return float(n) / targets.size()


func _update_progress() -> void:
	var ratio := _destroyed_ratio()
	var hq_down := false
	for t in targets:
		if t["type"] == "hq" and t["destroyed"]:
			hq_down = true
	hud.set_progress(int(round(ratio * 100.0)), RaidRules.battle_stars(ratio, hq_down))


# ---------------------------------------------------------------- effects

func _update_bars() -> void:
	var entries := []
	for i in targets.size():
		var t := targets[i]
		if t["destroyed"] or float(t["hp"]) >= float(t["max_hp"]):
			continue
		entries.append({"key": "t%d" % i, "friendly": false, "ratio": float(t["hp"]) / float(t["max_hp"]),
			"pos": cam.unproject_position((t["top"] as Vector3) + Vector3(0, 5.5, 0))})
	for i in drones.size():
		var d := drones[i]
		if d.dead or d.health >= d.max_health:
			continue
		entries.append({"key": "d%d" % i, "friendly": true, "ratio": d.health / d.max_health,
			"pos": cam.unproject_position(d.global_position + Vector3(0, 2.2, 0))})
	for i in ground.size():
		var u := ground[i]
		if u.dead or u.health >= u.max_health:
			continue
		entries.append({"key": "g%d" % i, "friendly": true, "ratio": u.health / u.max_health,
			"pos": cam.unproject_position(u.global_position + Vector3(0, 4.2 if u.is_tank() else 3.4, 0))})
	for i in defenders.size():
		var u := defenders[i]
		if u.dead or u.health >= u.max_health:
			continue
		entries.append({"key": "e%d" % i, "friendly": false, "ratio": u.health / u.max_health,
			"pos": cam.unproject_position(u.global_position + Vector3(0, 3.4, 0))})
	hud.update_bars(entries)


func _rubble(top: Vector3) -> void:
	var dark := MeshKit.mat(Color(0.25, 0.24, 0.23), 0.95)
	for i in 6:
		var chunk := MeshKit.add(level, MeshKit.box(Vector3(randf_range(0.6, 1.4), randf_range(0.3, 0.8), randf_range(0.6, 1.4))), dark,
			top + Vector3(randf_range(-2.0, 2.0), 0.3, randf_range(-2.0, 2.0)))
		chunk.rotation = Vector3(randf() * 0.5, randf() * TAU, randf() * 0.5)
	var smoke := MeshKit.add(level, MeshKit.sphere(1.0, 12), MeshKit.glow(Color(0.35, 0.35, 0.36), 0.6), top + Vector3(0, 1.5, 0))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(smoke, "scale", Vector3.ONE * 4.0, 1.2)
	tween.tween_property(smoke, "position:y", smoke.position.y + 3.0, 1.2)
	tween.tween_property(smoke.material_override, "albedo_color:a", 0.0, 1.2)
	tween.chain().tween_callback(smoke.queue_free)


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 72
	label.pixel_size = 0.025
	label.outline_size = 18
	label.modulate = color
	label.position = pos
	level.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y + 4.0, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


func _pan(relative: Vector2) -> void:
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var forward := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var units_per_px := cam.size / get_viewport().get_visible_rect().size.x
	focus -= (right * relative.x - forward * relative.y * 1.4) * units_per_px
	focus.x = clampf(focus.x, -PAN_LIMIT, PAN_LIMIT)
	focus.z = clampf(focus.z, -PAN_LIMIT, PAN_LIMIT)
	WorldSetup.place_camera(cam, focus)
