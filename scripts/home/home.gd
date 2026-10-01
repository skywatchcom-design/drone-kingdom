extends Node3D
## The player's rooftop base. Tap a roof to build or upgrade; Attack raids the next target;
## Test raids your own base so you can see how your defenses hold up.
## Run with `-- --screenshot-panel` to open the build sheet on start (used for screenshots).

const RAID_SCENE := "res://scenes/raid/raid.tscn"
const VIEW_SIZE := 56.0
const TAP_SLOP := 24.0
const PICK_RADIUS := 90.0

var cam: Camera3D
var hud: HomeHud
var level: Node3D
var city: City
var defenses: Array[Defense] = []
var marker: MeshInstance3D
var press_pos := Vector2.ZERO
var header_timer := 0.0
var focus := Vector3(0, 10, 0)
const PAN_LIMIT := 30.0


func _ready() -> void:
	Engine.time_scale = 1.0
	cam = WorldSetup.create(self, VIEW_SIZE)
	hud = HomeHud.new()
	add_child(hud)
	hud.attack_pressed.connect(func() -> void: _go_raid("enemy"))
	hud.test_pressed.connect(func() -> void: _go_raid("self"))
	hud.hangar_pressed.connect(_open_hangar)
	hud.collect_pressed.connect(_on_collect)
	_rebuild()
	var args := OS.get_cmdline_user_args()
	if args.has("--screenshot-panel"):
		_open_cell([1, 3])
	elif args.has("--screenshot-hangar"):
		_open_hangar()


func _rebuild() -> void:
	if level != null:
		level.queue_free()
	level = Node3D.new()
	add_child(level)
	defenses.clear()
	var all_cells := []
	for c in City.GRID:
		for r in City.GRID:
			all_cells.append([c, r])
	city = City.new()
	level.add_child(city)
	city.build(GameState.city_seed, all_cells)
	for s in GameState.structures:
		_spawn(s)
	marker = MeshKit.add(level, MeshKit.ring(4.2, 0.35), MeshKit.glow(Color(1, 1, 1), 0.9))
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	_refresh_header()


func _spawn(s: Dictionary) -> void:
	var type: String = s["type"]
	var lvl := int(s["level"])
	if Catalog.is_defense(type):
		var defense := Catalog.make_defense(type)
		level.add_child(defense)
		defense.position = City.cell_pos(s["cell"])
		defense.setup(Catalog.defense_stats(type, lvl), city.roof_y(s["cell"]), City.ALT)
		defenses.append(defense)
	else:
		StructureModels.build(level, type, lvl, city.roof_top(s["cell"]))


func _process(delta: float) -> void:
	for defense in defenses:
		defense.tick(delta, null)
	header_timer -= delta
	if header_timer <= 0.0:
		header_timer = 1.0
		_refresh_header()


func _refresh_header() -> void:
	var target := Bases.enemy(GameState.enemy_index, GameState.hq_level())
	hud.set_header(GameState.hq_level(), GameState.coins, GameState.coin_cap(), GameState.pending_income(), target["name"])


# ---------------------------------------------------------------- input

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
	var cell := _pick_cell(touch.position)
	if cell.is_empty():
		hud.hide_panel()
		marker.visible = false
	else:
		_open_cell(cell)


## Drag to look around the base. Screen motion maps onto the ground plane under the camera.
func _pan(relative: Vector2) -> void:
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var forward := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var units_per_px := cam.size / get_viewport().get_visible_rect().size.x
	focus -= (right * relative.x - forward * relative.y * 1.4) * units_per_px
	focus.x = clampf(focus.x, -PAN_LIMIT, PAN_LIMIT)
	focus.z = clampf(focus.z, -PAN_LIMIT, PAN_LIMIT)
	WorldSetup.place_camera(cam, focus)


## The roof whose center appears closest to the tap on screen.
func _pick_cell(screen_pos: Vector2) -> Array:
	var best := []
	var best_d := PICK_RADIUS
	for c in City.GRID:
		for r in City.GRID:
			var d := cam.unproject_position(city.roof_top([c, r])).distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = [c, r]
	return best


# ---------------------------------------------------------------- panels

func _open_cell(cell: Array) -> void:
	marker.visible = true
	marker.position = city.roof_top(cell) + Vector3(0, 0.5, 0)
	var s := GameState.structure_at(cell)
	var actions := []
	if s.is_empty():
		for option in Catalog.BUILD_ORDER:
			var why := GameState.build_block_reason(option)
			var text := "%s  ·  %d" % [Catalog.display_name(option), Catalog.build_cost(option)]
			if why != "":
				text += "\n" + why
			actions.append({"text": text, "enabled": why == "", "call": func() -> void: _do_build(option, cell)})
		hud.show_panel("Empty roof", "Pick what to build here.", actions)
		return

	var type: String = s["type"]
	var lvl := int(s["level"])
	var reason := GameState.upgrade_block_reason(cell)
	var up_text := "Max level"
	if lvl < Catalog.MAX_LEVEL:
		up_text = "Upgrade to Lv %d  ·  %d" % [lvl + 1, Catalog.upgrade_cost(type, lvl)]
		if reason != "":
			up_text += "\n" + reason
	actions.append({"text": up_text, "enabled": reason == "", "call": func() -> void: _do_upgrade(cell)})
	if type == "hangar":
		actions.append({"text": "Open hangar", "enabled": true, "call": _open_hangar})
	if type != "hq":
		actions.append({"text": "Remove (no refund)", "enabled": true, "call": func() -> void: _do_remove(cell)})
	hud.show_panel("%s  ·  Lv %d" % [Catalog.display_name(type), lvl], _describe(type, lvl), actions)


func _describe(type: String, lvl: int) -> String:
	match type:
		"hq":
			return "Everything else can be upgraded up to this level. Higher levels unlock more defenses and buildings."
		"generator":
			return "Makes %d coins per minute. Tap Collect at the top." % int(Catalog.generator_rate(lvl))
		"storage":
			return "Raises your coin cap by %d. Attackers can loot it." % (700 * lvl)
		"hangar":
			return "Unlocks new drones and lets them be upgraded up to Lv %d." % lvl
		"laser":
			var st := Catalog.defense_stats(type, lvl)
			return "Sweeping beam. Range %.1f m, %d damage per second in the beam." % [st["radius"], int(st["dps"])]
		"net":
			var st := Catalog.defense_stats(type, lvl)
			return "Fires a net where the drone is heading. Range %.1f m, reload %.1f s." % [st["radius"], st["cooldown"]]
		"jammer":
			var st := Catalog.defense_stats(type, lvl)
			return "Reverses the attacker's controls inside %.1f m." % st["radius"]
		"birds":
			var st := Catalog.defense_stats(type, lvl)
			return "%d gulls circling the nest, %d damage per bump." % [int(st["count"]), int(st["damage"])]
	return ""


func _open_hangar() -> void:
	var lines := []
	var actions := []
	for type in Catalog.DRONE_ORDER:
		var def: Dictionary = Catalog.DRONES[type]
		var reason := GameState.drone_block_reason(type)
		if GameState.drones.has(type):
			var lvl := int(GameState.drones[type])
			var st := Catalog.drone_stats(type, lvl)
			var flying: bool = GameState.selected_drone == type
			lines.append("%s Lv %d%s: health %d, speed %.1f, loot x%.1f" % [def["name"], lvl, " (flying)" if flying else "", int(st["health"]), st["speed"], st["carry"]])
			actions.append({"text": "Flying" if flying else "Fly %s" % def["name"], "enabled": not flying,
				"call": func() -> void: _select_drone(type)})
			var up := "Max level" if lvl >= Catalog.MAX_LEVEL else "Upgrade  ·  %d" % Catalog.drone_upgrade_cost(type, lvl)
			if reason != "" and lvl < Catalog.MAX_LEVEL:
				up += "\n" + reason
			actions.append({"text": up, "enabled": reason == "", "call": func() -> void: _do_drone(type)})
		else:
			lines.append("%s: locked" % def["name"])
			actions.append({"text": "%s (locked)" % def["name"], "enabled": false, "call": func() -> void: pass})
			var unlock := "Unlock  ·  %d" % int(def["unlock"])
			if reason != "":
				unlock += "\n" + reason
			actions.append({"text": unlock, "enabled": reason == "", "call": func() -> void: _do_drone(type)})
	hud.show_panel("Drone Hangar", "\n".join(lines), actions)


# ---------------------------------------------------------------- actions

func _do_build(type: String, cell: Array) -> void:
	if GameState.build(type, cell):
		hud.toast("%s built" % Catalog.display_name(type))
		_rebuild()
		_open_cell(cell)


func _do_upgrade(cell: Array) -> void:
	if GameState.upgrade(cell):
		hud.toast("Upgraded")
		_rebuild()
		_open_cell(cell)


func _do_remove(cell: Array) -> void:
	if GameState.remove(cell):
		_rebuild()
		hud.hide_panel()


func _do_drone(type: String) -> void:
	if GameState.upgrade_drone(type):
		hud.toast("%s Lv %d" % [Catalog.DRONES[type]["name"], int(GameState.drones[type])])
		_refresh_header()
		_open_hangar()


func _select_drone(type: String) -> void:
	GameState.select_drone(type)
	_open_hangar()


func _on_collect() -> void:
	var got := GameState.collect()
	hud.toast("+%d coins" % got if got > 0 else "Coin silo is full")
	_refresh_header()


func _go_raid(target: String) -> void:
	GameState.raid_target = target
	get_tree().change_scene_to_file(RAID_SCENE)
