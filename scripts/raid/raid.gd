extends Node3D
## A Clash-style attack. Pick a drone card, tap outside the base to release it, and the
## drones take it from there: each flies to the structure its role prefers and works it
## down with its beam while the defenses fight back. Stars for 50%, the Command Tower,
## and 100%. Loot comes out of every generator, silo and Command Tower you knock out.
## Run with `-- --autoplay` to deploy the whole army automatically (used for screenshots).

enum Phase { BATTLE, RESULT }

const HOME_SCENE := "res://scenes/home/home.tscn"
const VIEW_SIZE := 54.0
const TRAVEL_ALT := 20.0
const HOVER_ABOVE := 6.5
const WORK_RADIUS := 4.5
const DEPLOY_CLEARANCE := 6.5
const MAP_LIMIT := 46.0
const TAP_SLOP := 24.0
const PAN_LIMIT := 30.0
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
## One entry per structure: {type, level, cell, top, hp, max_hp, node, defense, is_defense, loot, destroyed}.
var targets: Array[Dictionary] = []
var drones: Array[Drone] = []
var army := {}
var drone_names := {}
var selected := ""
var started := false
var time_left := Catalog.BATTLE_SECONDS
var loot_gained := 0
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
	base = GameState.player_base() if GameState.raid_target == "self" else Bases.enemy(GameState.enemy_index, GameState.hq_level())
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
			"loot": Catalog.loot_value(type, lvl), "destroyed": false,
		})

	for type in Catalog.DRONE_ORDER:
		var n := int(GameState.army.get(type, 0))
		if n > 0 and GameState.drones.has(type):
			army[type] = n
			drone_names[type] = Catalog.display_name(type)
	selected = _first_available()
	hud.set_title(base["name"])
	hud.set_army(army, drone_names, selected)
	hud.set_timer(time_left)
	hud.set_loot(0)
	_update_progress()
	hud.set_status(I18n.t("Tap outside the base to release drones"))
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
		hud.set_status(I18n.t("No drones left to release"))
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
	var stats := GameState.drone_stats_for(type)
	var d := Drone.new()
	d.configure(stats)
	d.kind = type
	d.invulnerable = false
	level.add_child(d)
	d.position = p
	drones.append(d)
	started = true
	if int(army[type]) <= 0:
		selected = _first_available()
	hud.update_army(army, drone_names, selected)
	hud.set_status("")


func _autoplay_deploy() -> void:
	var spots := [Vector3(30, TRAVEL_ALT, 34), Vector3(36, TRAVEL_ALT, 24), Vector3(34, TRAVEL_ALT, 30)]
	var i := 0
	for type in army.keys():
		while int(army[type]) > 0:
			_deploy(type, spots[i % spots.size()] + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
			i += 1


# ---------------------------------------------------------------- battle loop

func _process(delta: float) -> void:
	var alive: Array = []
	for d in drones:
		d.jammed = false
		if not d.dead:
			alive.append(d)
	for t in targets:
		if t["destroyed"] or t["defense"] == null:
			continue
		(t["defense"] as Defense).tick(delta, alive if phase == Phase.BATTLE else [])
	if phase == Phase.BATTLE:
		if started:
			time_left -= delta
			hud.set_timer(time_left)
		for d: Drone in alive:
			_drone_ai(d, delta)
		_check_end(delta)
	else:
		for d: Drone in alive:
			d.steer(Vector3.ZERO, delta)
			d.set_zap(false)
	_update_bars()


func _drone_ai(d: Drone, delta: float) -> void:
	if d.target < 0 or targets[d.target]["destroyed"]:
		d.target = RaidRules.pick_target(d.prefers, d.position, targets)
	if d.target < 0:
		d.steer(Vector3.ZERO, delta)
		return
	var t := targets[d.target]
	var top: Vector3 = t["top"]
	var hover := top + Vector3(cos(d.orbit) * WORK_RADIUS, HOVER_ABOVE, sin(d.orbit) * WORK_RADIUS)
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
	if working:
		d.orbit += delta * 0.9
		d.fire_cooldown -= delta
		if d.fire_cooldown <= 0.0:
			d.fire_cooldown = d.fire_interval
			_fire(d, d.target)


## One shot: a glowing bolt flies to a random spot on the target; damage lands on impact
## with sparks, a flash and a little shake of the building. The drone kicks back.
func _fire(d: Drone, index: int) -> void:
	var t := targets[index]
	var top: Vector3 = t["top"]
	var hit := top + Vector3(randf_range(-1.2, 1.2), randf_range(0.6, 2.4), randf_range(-1.2, 1.2))
	var from := d.global_position + Vector3(0, -0.3 * d.body_scale, 0)
	var color: Color = BOLT_COLORS.get(d.kind, Color(0.4, 0.95, 1.0))
	var bolt := MeshKit.add(level, MeshKit.sphere(0.6 if d.kind == "heavy" else 0.42, 8), MeshKit.glow(color), from)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if from.distance_to(hit) > 0.1:
		bolt.look_at(hit, Vector3.UP if absf((hit - from).normalized().y) < 0.99 else Vector3.FORWARD)
	bolt.scale = Vector3(1, 1, 3.5)
	var damage := d.dps * d.fire_interval
	d.velocity += (from - hit).normalized() * 1.2
	_tracer(from, hit, color)
	var tween := create_tween()
	tween.tween_property(bolt, "global_position", hit, 0.18)
	tween.tween_callback(func() -> void:
		bolt.queue_free()
		_impact(hit, color)
		_shake(index)
		_damage_target(index, damage))


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
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(1.12, 0.9, 1.12), 0.05)
	tween.tween_property(node, "scale", Vector3.ONE, 0.08)
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
	var top: Vector3 = t["top"]
	if t["defense"] != null:
		(t["defense"] as Defense).disable()
	else:
		(t["node"] as Node3D).visible = false
	_rubble(top)
	var loot := int(t["loot"])
	if loot > 0:
		loot_gained += loot
		hud.set_loot(loot_gained)
		_float_text(top + Vector3(0, 3, 0), "+%d" % loot, Color(1.0, 0.85, 0.3))
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
	var gained := 0
	if not autoplay:
		gained = GameState.record_raid(stars, loot_gained)
	hud.show_result(stars, int(round(ratio * 100.0)), gained, GameState.coins, GameState.raid_target == "self")


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
