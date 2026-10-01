extends Node3D
## One attack: plan a route over the target's rooftops, launch, and take manual control
## (in slow motion) whenever the drone enters a defense's range. Loot sits in the
## target's generators, silos and Command Tower (the gold vault).
## Run with `-- --autoplay` to draw a route and fly it automatically (used for screenshots).

enum Phase { PLAN, TAKEOFF, FLY, LANDING, RESULT }

const HOME_SCENE := "res://scenes/home/home.tscn"
const ALT := City.ALT
const CRUISE_SPEED := 9.0
const PLAN_SIZE := 78.0
const FLY_SIZE := 42.0
const POINT_SPACING := 1.5
const LOOT_REACH := 2.6
const STICK_PIXELS := 90.0
const CALM_TO_RESUME := 0.8

var phase: Phase = Phase.PLAN
var base: Dictionary
var level: Node3D
var city: City
var drone: Drone
var drone_stats: Dictionary
var cam: Camera3D
var hud: RaidHud
var defenses: Array[Defense] = []
var loot: Array[Dictionary] = []
var path := PackedVector3Array()
var path_index := 0
var returning := false
var manual := false
var calm := 0.0
var manual_since_ms := 0
var drawing := false
var touching := false
var stick_origin := Vector2.ZERO
var stick := Vector2.ZERO
var carried := 0
var pad_top := Vector3.ZERO
var pad_above := Vector3.ZERO
var path_im: ImmediateMesh
var cam_focus := Vector3(0, 10, 0)
var crash_timer := -1.0
var last_health := 100.0
var autoplay := false


func _ready() -> void:
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	cam = WorldSetup.create(self, PLAN_SIZE)
	hud = RaidHud.new()
	add_child(hud)
	hud.launch_pressed.connect(_on_launch)
	hud.clear_pressed.connect(_on_clear)
	hud.retry_pressed.connect(_start)
	hud.home_pressed.connect(func() -> void: get_tree().change_scene_to_file(HOME_SCENE))
	_start()


func _target_base() -> Dictionary:
	if GameState.raid_target == "self":
		return GameState.player_base()
	return Bases.enemy(GameState.enemy_index, GameState.hq_level())


func _start() -> void:
	base = _target_base()
	if level != null:
		level.queue_free()
	level = Node3D.new()
	add_child(level)
	defenses.clear()
	loot.clear()

	var reserved: Array = [base["pad"]]
	for s in base["structures"]:
		reserved.append(s["cell"])
	city = City.new()
	level.add_child(city)
	city.build(int(base["seed"]), reserved)

	pad_top = city.roof_top(base["pad"])
	pad_above = Vector3(pad_top.x, ALT, pad_top.z)
	_add_pad(pad_top)
	for s in base["structures"]:
		var type: String = s["type"]
		var lvl := int(s["level"])
		if Catalog.is_defense(type):
			var defense := Catalog.make_defense(type)
			level.add_child(defense)
			defense.position = City.cell_pos(s["cell"])
			defense.setup(Catalog.defense_stats(type, lvl), city.roof_y(s["cell"]), ALT)
			defenses.append(defense)
		else:
			StructureModels.build(level, type, lvl, city.roof_top(s["cell"]))
			var value := Catalog.loot_value(type, lvl)
			if value > 0:
				_add_loot(s["cell"], value, type == "hq")

	drone_stats = GameState.current_drone_stats()
	drone = Drone.new()
	drone.configure(drone_stats)
	drone.invulnerable = autoplay
	level.add_child(drone)
	drone.position = pad_top + Vector3(0, drone.gear_height, 0)
	drone.crashed.connect(_on_crash)

	path_im = ImmediateMesh.new()
	var path_mesh := MeshInstance3D.new()
	path_mesh.mesh = path_im
	var path_mat := MeshKit.glow(Color(1.0, 0.85, 0.2), 0.9)
	path_mat.no_depth_test = true
	path_mat.render_priority = 10
	path_mesh.material_override = path_mat
	path_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(path_mesh)

	path = PackedVector3Array()
	path_index = 0
	returning = false
	manual = false
	drawing = false
	touching = false
	carried = 0
	crash_timer = -1.0
	last_health = drone.max_health
	Engine.time_scale = 1.0
	phase = Phase.PLAN
	hud.hide_result()
	hud.set_title("%s  ·  %s Lv %d" % [base["name"], drone_stats["name"], int(drone_stats["level"])])
	hud.set_health(100.0)
	hud.set_loot(0)
	hud.set_manual(false, false)
	hud.set_status("Draw a route from your drone to the gold Command Tower")
	hud.set_plan_buttons(true, false)
	if autoplay:
		_auto_route()
		_on_launch()


func _add_pad(top: Vector3) -> void:
	var white := MeshKit.mat(Color(0.95, 0.95, 0.95), 0.6)
	MeshKit.add(level, MeshKit.cyl(2.4, 2.4, 0.15, 32), MeshKit.mat(Color(0.95, 0.72, 0.18), 0.6), top + Vector3(0, 0.08, 0))
	MeshKit.add(level, MeshKit.box(Vector3(0.3, 0.05, 1.6)), white, top + Vector3(-0.45, 0.18, 0))
	MeshKit.add(level, MeshKit.box(Vector3(0.3, 0.05, 1.6)), white, top + Vector3(0.45, 0.18, 0))
	MeshKit.add(level, MeshKit.box(Vector3(0.9, 0.05, 0.3)), white, top + Vector3(0, 0.18, 0))


## A loot marker on a building: a crate (or the gold vault on the Command Tower) and a light beam.
func _add_loot(cell: Array, value: int, vault: bool) -> void:
	var top := city.roof_top(cell)
	var node := Node3D.new()
	level.add_child(node)
	node.position = top
	var beacon_h := ALT - top.y
	if vault:
		MeshKit.add(node, MeshKit.box(Vector3(1.4, 1.0, 1.4)), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.25, 0.8), Vector3(2.0, 0.5, 2.0))
		var beam := MeshKit.add(node, MeshKit.cyl(0.18, 0.18, beacon_h, 8), MeshKit.glow(Color(1.0, 0.85, 0.3), 0.35), Vector3(0, beacon_h / 2.0, 0))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		MeshKit.add(node, MeshKit.box(Vector3(1.0, 0.8, 1.0)), MeshKit.mat(Color(0.62, 0.45, 0.28), 0.9), Vector3(2.2, 0.4, 2.2))
		var beam := MeshKit.add(node, MeshKit.cyl(0.1, 0.1, beacon_h, 6), MeshKit.glow(Color(0.5, 1.0, 0.6), 0.25), Vector3(0, beacon_h / 2.0, 0))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	loot.append({"node": node, "value": value, "vault": vault, "taken": false})


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if hud.blocks(touch.position):
				return
			if phase == Phase.PLAN:
				drawing = true
				path = PackedVector3Array([pad_above])
				_try_add_point(touch.position)
			elif phase == Phase.FLY:
				touching = true
				stick_origin = touch.position
				stick = Vector2.ZERO
		else:
			if drawing:
				drawing = false
				hud.set_plan_buttons(true, path.size() > 3)
			touching = false
			stick = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drawing:
			_try_add_point(drag.position)
		elif touching:
			stick = ((drag.position - stick_origin) / STICK_PIXELS).limit_length(1.0)


func _try_add_point(screen_pos: Vector2) -> void:
	var hit = Plane(Vector3.UP, ALT).intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	if hit == null:
		return
	var p: Vector3 = hit
	if PathUtils.flat_distance(p, path[path.size() - 1]) >= POINT_SPACING:
		path.append(p)
		_redraw_path()


func _on_clear() -> void:
	path = PackedVector3Array()
	_redraw_path()
	hud.set_plan_buttons(true, false)


func _on_launch() -> void:
	if phase != Phase.PLAN or path.size() < 2:
		return
	path = PathUtils.resample(path, POINT_SPACING)
	phase = Phase.TAKEOFF
	hud.set_plan_buttons(false, false)
	hud.set_status("Taking off")


func _auto_route() -> void:
	var points := PackedVector3Array([pad_above])
	var vault := Vector3.ZERO
	for item in loot:
		var p: Vector3 = (item["node"] as Node3D).position
		if item["vault"]:
			vault = p
		elif points.size() < 2:
			points.append(Vector3(p.x, ALT, p.z))
	points.append(Vector3(vault.x, ALT, vault.z))
	path = PathUtils.resample(points, POINT_SPACING)


# ---------------------------------------------------------------- frame loop

func _process(delta: float) -> void:
	match phase:
		Phase.TAKEOFF:
			_takeoff(delta)
		Phase.FLY:
			_fly(delta)
		Phase.LANDING:
			_landing(delta)
	var flying := phase in [Phase.TAKEOFF, Phase.FLY, Phase.LANDING]
	drone.jammed = false
	for defense in defenses:
		defense.tick(delta, drone if flying else null)
	if crash_timer >= 0.0:
		crash_timer -= delta
		if crash_timer < 0.0:
			_finish(false)
	_update_hud()
	_update_camera(delta)


func _takeoff(delta: float) -> void:
	var to := Vector3(drone.position.x, ALT, drone.position.z) - drone.position
	drone.steer((to * 2.0).limit_length(7.0) + Vector3(0, 0.6, 0), delta)
	if drone.position.y >= ALT - 0.3:
		phase = Phase.FLY
		path_index = 1
		hud.set_status("Autopilot")


func _fly(delta: float) -> void:
	var target := pad_above
	if not returning:
		while path_index < path.size() and PathUtils.flat_distance(path[path_index], drone.position) < 2.0:
			path_index += 1
		if path_index >= path.size():
			returning = true
		else:
			target = path[path_index]

	var danger := _in_danger()
	if danger and not manual:
		_enter_manual()
	elif manual:
		if danger:
			calm = 0.0
		else:
			calm += delta / maxf(Engine.time_scale, 0.01)
			if calm > CALM_TO_RESUME:
				_exit_manual()
	if manual:
		Engine.time_scale = 0.3 if Time.get_ticks_msec() - manual_since_ms < 700 else 0.7

	var desired: Vector3
	if manual and not autoplay:
		desired = _stick_to_world() * drone.max_speed
		if drone.jammed:
			desired = -desired
	else:
		desired = (target - drone.position).normalized() * minf(CRUISE_SPEED, drone.max_speed)
		if drone.jammed:
			desired = desired.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.004) * 0.9)
	desired.y = clampf((ALT - drone.position.y) * 2.0, -4.0, 4.0)
	drone.steer(desired, delta)
	_check_loot()
	_redraw_path()
	if returning and PathUtils.flat_distance(pad_above, drone.position) < 1.2:
		_exit_manual()
		phase = Phase.LANDING
		hud.set_status("Landing")


func _landing(delta: float) -> void:
	var target := pad_top + Vector3(0, drone.gear_height, 0)
	var to := target - drone.position
	drone.steer(Vector3(to.x * 3.0, clampf(to.y * 1.5, -6.0, -0.6), to.z * 3.0), delta)
	if drone.position.y <= target.y + 0.05:
		drone.position = target
		drone.velocity = Vector3.ZERO
		_finish(true)


func _in_danger() -> bool:
	for defense in defenses:
		if defense.in_range(drone.position, 2.0):
			return true
	return false


func _enter_manual() -> void:
	manual = true
	calm = 0.0
	manual_since_ms = Time.get_ticks_msec()


func _exit_manual() -> void:
	Engine.time_scale = 1.0
	if not manual:
		return
	manual = false
	calm = 0.0
	touching = false
	stick = Vector2.ZERO
	if not returning and path_index < path.size():
		path_index = mini(PathUtils.nearest_index(path, drone.position, path_index) + 1, path.size())


func _stick_to_world() -> Vector3:
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var forward := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	return right * stick.x + forward * -stick.y


func _check_loot() -> void:
	for item in loot:
		if item["taken"]:
			continue
		var node: Node3D = item["node"]
		if PathUtils.flat_distance(node.position, drone.position) > LOOT_REACH + 1.0:
			continue
		item["taken"] = true
		carried += int(round(int(item["value"]) * float(drone_stats["carry"])))
		drone.set_carrying(true)
		hud.set_loot(carried)
		var tween := create_tween()
		tween.tween_property(node, "position", drone.position, 0.35)
		tween.tween_callback(node.hide)


func _on_crash() -> void:
	_exit_manual()
	phase = Phase.RESULT
	crash_timer = 1.6
	hud.set_status("Drone down!")


func _finish(success: bool) -> void:
	crash_timer = -1.0
	phase = Phase.RESULT
	Engine.time_scale = 1.0
	var vault_taken := false
	var all_crates := true
	for item in loot:
		if item["vault"]:
			vault_taken = item["taken"]
		elif not item["taken"]:
			all_crates = false
	var banked := carried if success else 0
	var stars := RaidRules.stars(banked, vault_taken, all_crates, success)
	var gained := 0
	if not autoplay:
		gained = GameState.record_raid(stars, banked)
	var practice := GameState.raid_target == "self"
	hud.set_manual(false, false)
	hud.set_status("Raid complete" if success else "Drone down")
	hud.show_result(success, stars, gained, GameState.coins, practice)
	if success:
		drone.set_carrying(false)


# ---------------------------------------------------------------- presentation

func _update_hud() -> void:
	hud.set_health(100.0 * drone.health / drone.max_health)
	if drone.health < last_health - 0.5:
		hud.flash_hit()
		last_health = drone.health
	if phase != Phase.FLY:
		return
	hud.set_manual(manual, drone.jammed)
	if drone.net_timer > 0.0:
		hud.set_status("Caught in a net!")
	elif manual and drone.jammed:
		hud.set_status("JAMMED: controls reversed")
	elif manual:
		hud.set_status("MANUAL: drag to steer")
	else:
		hud.set_status("Returning home" if returning else "Autopilot")


func _update_camera(delta: float) -> void:
	var target_focus := Vector3(0, 10, 0)
	var target_size := PLAN_SIZE
	if phase != Phase.PLAN:
		target_focus = drone.position
		target_size = FLY_SIZE
	cam_focus = cam_focus.lerp(target_focus, 1.0 - exp(-delta * 3.0))
	cam.size = lerpf(cam.size, target_size, 1.0 - exp(-delta * 2.0))
	WorldSetup.place_camera(cam, cam_focus)


func _redraw_path() -> void:
	path_im.clear_surfaces()
	var points := path
	if phase == Phase.FLY:
		points = PackedVector3Array([drone.position]) + path.slice(path_index) if not returning else PackedVector3Array()
	if points.size() < 2:
		return
	path_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var tangent := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		tangent.y = 0.0
		if tangent.length() < 0.001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x) * 0.5
		path_im.surface_add_vertex(points[i] + side)
		path_im.surface_add_vertex(points[i] - side)
	path_im.surface_end()
