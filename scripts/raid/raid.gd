extends Node3D
## One raid: plan a route over the rooftops, launch, and take manual control
## (in slow motion) whenever the drone enters a defense's range.
## Run with `-- --autoplay` to draw a route and fly it automatically (used for screenshots).

enum Phase { PLAN, TAKEOFF, FLY, LANDING, RESULT }

const ALT := City.ALT
const CRUISE_SPEED := 9.0
const PLAN_SIZE := 78.0
const FLY_SIZE := 42.0
const CAM_DIR := Vector3(1.0, 1.15, 1.0)
const CAM_DISTANCE := 150.0
const POINT_SPACING := 1.5
const LOOT_REACH := 2.6
const STICK_PIXELS := 90.0
const CALM_TO_RESUME := 0.8

var phase: Phase = Phase.PLAN
var base_index := 0
var base: Dictionary
var level: Node3D
var city: City
var drone: Drone
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
var home_top := Vector3.ZERO
var home_above := Vector3.ZERO
var path_im: ImmediateMesh
var cam_focus := Vector3(0, 10, 0)
var crash_timer := -1.0
var last_health := 100.0
var autoplay := false


func _ready() -> void:
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	_setup_world()
	hud = RaidHud.new()
	add_child(hud)
	hud.launch_pressed.connect(_on_launch)
	hud.clear_pressed.connect(_on_clear)
	hud.retry_pressed.connect(func() -> void: _load_base(base_index))
	hud.next_pressed.connect(func() -> void: _load_base((base_index + 1) % Bases.LIST.size()))
	_load_base(GameState.base_index % Bases.LIST.size())


func _setup_world() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.62, 0.82)
	sky_mat.sky_horizon_color = Color(0.78, 0.84, 0.9)
	sky_mat.ground_horizon_color = Color(0.72, 0.74, 0.76)
	sky_mat.ground_bottom_color = Color(0.32, 0.34, 0.37)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Haze that only starts behind the focus point, so distant blocks fade into the sky.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.81, 0.88)
	env.fog_depth_begin = CAM_DISTANCE + 20.0
	env.fog_depth_end = CAM_DISTANCE + 110.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.95, 0.87)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	add_child(sun)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = PLAN_SIZE
	cam.near = 0.1
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	_place_camera()


func _load_base(index: int) -> void:
	base_index = index
	GameState.base_index = index
	base = Bases.LIST[index]
	if level != null:
		level.queue_free()
	level = Node3D.new()
	add_child(level)
	defenses.clear()
	loot.clear()

	var reserved: Array = [base["home"], base["target"]]
	for d in base["defenses"]:
		reserved.append(d["cell"])
	for cell in base["loot"]:
		reserved.append(cell)
	city = City.new()
	level.add_child(city)
	city.build(int(base["seed"]), reserved)

	home_top = city.roof_top(base["home"])
	home_above = Vector3(home_top.x, ALT, home_top.z)
	_add_pad(home_top)
	for d in base["defenses"]:
		var defense := Catalog.make_defense(d["type"])
		level.add_child(defense)
		defense.position = City.cell_pos(d["cell"])
		defense.setup(Catalog.DEFENSES[d["type"]], city.roof_y(d["cell"]), ALT)
		defenses.append(defense)
	for cell in base["loot"]:
		_add_loot(cell, 50, false)
	_add_loot(base["target"], 200, true)

	drone = Drone.new()
	drone.invulnerable = autoplay
	level.add_child(drone)
	drone.position = home_top + Vector3(0, Drone.GEAR_HEIGHT, 0)
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
	last_health = 100.0
	Engine.time_scale = 1.0
	phase = Phase.PLAN
	hud.hide_result()
	hud.set_title(base["name"])
	hud.set_health(100.0)
	hud.set_loot(0)
	hud.set_manual(false, false)
	hud.set_status("Draw a route from your drone to the gold vault")
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


func _add_loot(cell: Array, value: int, vault: bool) -> void:
	var top := city.roof_top(cell)
	var node := Node3D.new()
	level.add_child(node)
	node.position = top
	var beacon_h := ALT - top.y
	if vault:
		MeshKit.add(node, MeshKit.box(Vector3(2.2, 1.6, 2.2)), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.25, 0.8), Vector3(0, 0.8, 0))
		var beam := MeshKit.add(node, MeshKit.cyl(0.18, 0.18, beacon_h, 8), MeshKit.glow(Color(1.0, 0.85, 0.3), 0.35), Vector3(0, beacon_h / 2.0, 0))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		MeshKit.add(node, MeshKit.box(Vector3(1.2, 0.9, 1.2)), MeshKit.mat(Color(0.62, 0.45, 0.28), 0.9), Vector3(0, 0.45, 0))
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
				path = PackedVector3Array([home_above])
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
	var first_crate := city.roof_top(base["loot"][0])
	var target := city.roof_top(base["target"])
	path = PackedVector3Array([home_above, Vector3(first_crate.x, ALT, first_crate.z), Vector3(target.x, ALT, target.z)])
	path = PathUtils.resample(path, POINT_SPACING)


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
	var target := home_above
	if not returning:
		while path_index < path.size() and PathUtils.flat_distance(path[path_index], drone.position) < 2.0:
			path_index += 1
		if path_index >= path.size():
			returning = true
			hud.set_status("Returning home")
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
		desired = _stick_to_world() * Drone.MAX_SPEED
		if drone.jammed:
			desired = -desired
	else:
		desired = (target - drone.position).normalized() * CRUISE_SPEED
		if drone.jammed:
			desired = desired.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.004) * 0.9)
	desired.y = clampf((ALT - drone.position.y) * 2.0, -4.0, 4.0)
	drone.steer(desired, delta)
	_check_loot()
	_redraw_path()
	if returning and PathUtils.flat_distance(home_above, drone.position) < 1.2:
		_exit_manual()
		phase = Phase.LANDING
		hud.set_status("Landing")


func _landing(delta: float) -> void:
	var target := home_top + Vector3(0, Drone.GEAR_HEIGHT, 0)
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
		if PathUtils.flat_distance(node.position, drone.position) > LOOT_REACH:
			continue
		item["taken"] = true
		carried += int(item["value"])
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
	if not autoplay:
		GameState.record_raid(base_index, stars, banked)
	hud.set_manual(false, false)
	hud.set_status("Raid complete" if success else "Drone down")
	hud.show_result(success, stars, banked, GameState.coins)
	if success:
		drone.set_carrying(false)


# ---------------------------------------------------------------- presentation

func _update_hud() -> void:
	hud.set_health(drone.health)
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
	_place_camera()


func _place_camera() -> void:
	cam.position = cam_focus + CAM_DIR.normalized() * CAM_DISTANCE
	cam.look_at(cam_focus, Vector3.UP)


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
