extends Node3D
## The player's base. Tap a pad to build or upgrade (or press Build, pick, then tap a free pad),
## tap a floating coin or fuel drop to collect, train an army (Army button or the Training
## Camp), unlock and upgrade units in the Garage and the Hangar, then Attack. Settings holds
## language, sound, practice on your own base and dev tools.
## Run with `-- --screenshot-panel` / `--screenshot-hq` / `--screenshot-army` /
## `--screenshot-hangar` / `--screenshot-garage` / `--screenshot-build` / `--screenshot-settings` to open a
## sheet on start.

const RAID_SCENE := "res://scenes/raid/raid.tscn"
## Height of the view in meters (the screen is held sideways).
const VIEW_SIZE := 52.0
const TAP_SLOP := 24.0
const PICK_RADIUS := 90.0
const COIN_PICK_RADIUS := 70.0
const PAN_LIMIT := 30.0
const GOLD := Color(1.0, 0.85, 0.35)
const SOFT := Color(0.8, 0.84, 0.9)
const GOOD := Color(0.45, 0.95, 0.55)
const BAD := Color(1.0, 0.45, 0.4)

var cam: Camera3D
var hud: HomeHud
var level: Node3D
var city: City
var defenses: Array[Defense] = []
var coins: Array[CoinBubble] = []
## Countdown labels over structures being built or upgraded, by cell key.
var timers := {}
var open_cell: Array = []
## Which sheet is open besides a structure's ("army", "hangar", "garage" or ""), so it can
## be refreshed as training moves on.
var open_sheet := ""
## Structure type picked from the Build menu, waiting for a free pad to be tapped.
var placing := ""
## Wall mode: tapping or dragging along the paths between pads builds wall pieces.
var wall_mode := false
## Small markers on the empty paths, shown in wall mode.
var edge_markers: MultiMeshInstance3D
## Instance index of each empty path's marker, so building a wall can hide just that one.
var edge_marker_index := {}
const EDGE_PICK := 60.0
var marker: MeshInstance3D
var press_pos := Vector2.ZERO
var header_timer := 0.0
var focus := Vector3(0, 10, 0)


func _ready() -> void:
	Engine.time_scale = 1.0
	Audio.hum(0.0)
	cam = WorldSetup.create(self, VIEW_SIZE)
	hud = HomeHud.new()
	add_child(hud)
	hud.attack_pressed.connect(func() -> void: _go_raid("enemy"))
	hud.army_pressed.connect(_open_army)
	hud.build_pressed.connect(func() -> void: _open_build([]))
	hud.settings_pressed.connect(_open_settings)
	hud.workers_pressed.connect(_open_workers)
	hud.gems_pressed.connect(func() -> void: hud.toast(I18n.t("The gem shop is coming soon")))
	hud.mode_done.connect(_end_wall_mode)
	GameState.finish_ready()
	GameState.process_training()
	_rebuild()
	var args := OS.get_cmdline_user_args()
	if args.has("--screenshot-panel"):
		_open_cell([1, 3])
	elif args.has("--screenshot-hq"):
		_open_cell([4, 4])
	elif args.has("--screenshot-army"):
		_open_army()
	elif args.has("--screenshot-hangar"):
		_open_lab("hangar")
	elif args.has("--screenshot-garage"):
		_open_lab("garage")
	elif args.has("--screenshot-build"):
		_open_build([])
	elif args.has("--screenshot-settings"):
		_open_settings()


func _rebuild() -> void:
	if level != null:
		level.queue_free()
	level = Node3D.new()
	add_child(level)
	defenses.clear()
	coins.clear()
	timers.clear()
	var all_cells := []
	for c in City.GRID:
		for r in City.GRID:
			all_cells.append([c, r])
	city = City.new()
	level.add_child(city)
	city.build(GameState.city_seed, all_cells)
	for s in GameState.structures:
		_spawn(s)
	for w in GameState.walls:
		StructureModels.wall(level, w["edge"], int(w["level"]))
	var free_edges := []
	edge_marker_index.clear()
	for e in _all_edges():
		if GameState.wall_at(e).is_empty():
			edge_marker_index[Walls.key(e)] = free_edges.size()
			free_edges.append(Transform3D(Basis(Vector3.UP, PI / 2.0 if int(e[2]) == 0 else 0.0), Walls.center(e) + Vector3(0, 0.15, 0)))
	edge_markers = MeshKit.multi(level, MeshKit.box(Vector3(5.6, 0.12, 0.5)), MeshKit.glow(Color(1.0, 0.85, 0.35), 0.45), free_edges)
	edge_markers.visible = wall_mode
	marker = MeshKit.add(level, MeshKit.ring(3.4, 0.3), MeshKit.glow(Color(1, 1, 1), 0.9))
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	_refresh_header()


func _spawn(s: Dictionary) -> void:
	var type: String = s["type"]
	var lvl := int(s["level"])
	if GameState.is_busy(s):
		_construction(s)
		if s.get("fresh", false):
			return
	if Catalog.is_defense(type):
		var defense := Catalog.make_defense(type)
		level.add_child(defense)
		defense.position = City.cell_pos(s["cell"])
		defense.setup(Catalog.defense_stats(type, lvl), city.roof_y(s["cell"]))
		defenses.append(defense)
		return
	StructureModels.build(level, type, lvl, city.roof_top(s["cell"]))
	if GameState.is_producer(type):
		var bubble := CoinBubble.new()
		bubble.cell = s["cell"]
		bubble.fuel = type == "pump"
		bubble.position = city.roof_top(s["cell"]) + Vector3(0, 4.2, 0)
		level.add_child(bubble)
		coins.append(bubble)


## Scaffolding around a pad that is being built or upgraded, with a countdown over it.
func _construction(s: Dictionary) -> void:
	var top := city.roof_top(s["cell"])
	var frame := Node3D.new()
	frame.position = top
	level.add_child(frame)
	var pole := MeshKit.mat(Color(0.95, 0.72, 0.15), 0.6, 0.3)
	for x in [-2.3, 2.3]:
		for z in [-2.3, 2.3]:
			MeshKit.add(frame, MeshKit.box(Vector3(0.18, 3.2, 0.18)), pole, Vector3(x, 1.6, z))
	for y in [1.0, 3.1]:
		for side in [Vector3(0, y, -2.3), Vector3(0, y, 2.3)]:
			MeshKit.add(frame, MeshKit.box(Vector3(4.8, 0.14, 0.14)), pole, side)
		for side in [Vector3(-2.3, y, 0), Vector3(2.3, y, 0)]:
			MeshKit.add(frame, MeshKit.box(Vector3(0.14, 0.14, 4.8)), pole, side)
	if s.get("fresh", false):
		# A pile of crates until the real model appears.
		MeshKit.add(frame, MeshKit.box(Vector3(1.6, 1.0, 1.6)), MeshKit.mat(Color(0.6, 0.45, 0.28), 0.9), Vector3(-0.6, 0.5, 0.4))
		MeshKit.add(frame, MeshKit.box(Vector3(1.1, 0.8, 1.1)), MeshKit.mat(Color(0.55, 0.42, 0.26), 0.9), Vector3(0.9, 0.4, -0.5))
	var label := StructureModels.level_label(frame, 0, 6.5)
	label.modulate = Color(1.0, 0.85, 0.35)
	label.font_size = 64
	timers[_key(s["cell"])] = {"label": label, "cell": s["cell"]}
	_update_timers()


func _update_timers() -> void:
	for key in timers:
		var s := GameState.structure_at(timers[key]["cell"])
		(timers[key]["label"] as Label3D).text = HomeHud.clock(GameState.seconds_left(s))


func _key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]


func _process(delta: float) -> void:
	for defense in defenses:
		defense.tick(delta, [])
	header_timer -= delta
	if header_timer <= 0.0:
		header_timer = 1.0
		_tick_second()


func _tick_second() -> void:
	var done := GameState.finish_ready()
	if not done.is_empty():
		Audio.play("build")
		hud.toast(I18n.t("%s is ready") % Catalog.display_name(done[0]["type"]))
		_rebuild()
		_reopen()
		return
	if GameState.process_support() > 0:
		hud.toast(I18n.t("Support done"))
		if open_sheet == "support" and hud.panel_open():
			_open_support()
	var trained := GameState.process_training()
	if trained > 0:
		hud.toast(I18n.t("Training done") if GameState.training.is_empty() else I18n.t("+%d trained") % trained)
	_update_timers()
	_refresh_header()
	if not open_cell.is_empty() and GameState.is_busy(GameState.structure_at(open_cell)):
		_open_cell(open_cell)
	elif open_sheet == "army" and hud.panel_open() and (trained > 0 or not GameState.training.is_empty()):
		_open_army()
	elif open_sheet == "support" and hud.panel_open() and not GameState.support_queue.is_empty():
		_open_support()


func _refresh_header() -> void:
	var target := Bases.enemy(GameState.enemy_index, GameState.hq_level())
	hud.set_header(GameState.hq_level(), target["name"], GameState.infinite_coins)
	for bubble in coins:
		if bubble.scale.x > 0.99:
			bubble.set_amount(GameState.generator_pending(GameState.structure_at(bubble.cell)))


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if wall_mode and not hud.blocks(drag.position):
			_paint_wall(drag.position)
		else:
			_pan(drag.relative)
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
	if wall_mode:
		_paint_wall(touch.position)
		return
	if _try_collect(touch.position):
		return
	var cell := _pick_cell(touch.position)
	var edge := _pick_edge(touch.position, EDGE_PICK * 0.6)
	if not edge.is_empty() and not GameState.wall_at(edge).is_empty() and (cell.is_empty() \
			or cam.unproject_position(Walls.center(edge)).distance_to(touch.position) < cam.unproject_position(city.roof_top(cell)).distance_to(touch.position)):
		_open_wall(edge)
		return
	if placing != "" and not cell.is_empty() and GameState.structure_at(cell).is_empty():
		var type := placing
		placing = ""
		_do_build(type, cell)
		return
	placing = ""
	if cell.is_empty():
		hud.hide_panel()
		open_cell = []
		marker.visible = false
	else:
		_open_cell(cell)


## Tapping near a visible coin collects that generator.
func _try_collect(screen_pos: Vector2) -> bool:
	for bubble in coins:
		if not bubble.visible:
			continue
		if cam.unproject_position(bubble.global_position).distance_to(screen_pos) > COIN_PICK_RADIUS:
			continue
		var got := GameState.collect_generator(bubble.cell)
		if got > 0:
			hud.toast(I18n.t("+%d fuel") % got if bubble.fuel else I18n.t("+%d coins") % got)
			bubble.pop()
			Audio.play("coin")
			Audio.buzz(20)
		elif bubble.fuel:
			hud.toast(I18n.t("Fuel tanks are full. Build or upgrade a Fuel Tank."))
		else:
			hud.toast(I18n.t("Coin silos are full. Build or upgrade a Coin Silo."))
		_refresh_header()
		return true
	return false


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


func _reopen() -> void:
	if not open_cell.is_empty() and hud.panel_open():
		_open_cell(open_cell)


# ---------------------------------------------------------------- build menu

func _open_cell(cell: Array) -> void:
	open_cell = cell
	open_sheet = ""
	marker.visible = true
	marker.position = city.roof_top(cell) + Vector3(0, 0.5, 0)
	var s := GameState.structure_at(cell)
	if s.is_empty():
		hud.show_content(I18n.t("Build here"), _build_menu(cell))
	else:
		var title := "%s  ·  %s" % [Catalog.display_name(s["type"]), I18n.t("Lv %d") % int(s["level"])]
		hud.show_content(title, _structure_sheet(cell, s))


func _build_menu(cell: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for option in ["wall"] + Catalog.BUILD_ORDER:
		grid.add_child(_build_card(option, cell))
	return grid


## A build menu card: a picture of the structure, its name, one short line on what it does,
## and the price and time (or why it can't be built yet, in which case the card is faded).
func _build_card(type: String, cell: Array) -> Control:
	var wall := type == "wall"
	var why := GameState.wall_block_reason() if wall else GameState.build_block_reason(type)
	var card := _card(why == "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if why != "":
		card.modulate = Color(1, 1, 1, 0.6)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(_thumbnail(type))
	HomeHud.make_label(box, Catalog.display_name(type), 22)
	var line := _wrap(HomeHud.make_label(box, I18n.t(Catalog.SHORT[type]), 16, SOFT))
	line.custom_minimum_size.y = 42
	var price := I18n.t("Build  ·  %d") % (Catalog.WALL_COST if wall else Catalog.build_cost(type))
	if not wall:
		price += "  ·  " + HomeHud.clock(Catalog.build_seconds(type, 1))
	var b := HomeHud.make_button(box, price if why == "" else why, 16, 52)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = why != ""
	_gold(b, why == "")
	b.pressed.connect(func() -> void:
		if wall:
			_start_wall_mode()
		elif cell.is_empty():
			_start_placing(type)
		else:
			_do_build(type, cell))
	return card


## A picture of a structure at level 1, rendered once into a small 3D stage.
func _thumbnail(type: String) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(0, 118)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	frame.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.48, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 28, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	vp.add_child(light)
	var stage := Node3D.new()
	vp.add_child(stage)
	MeshKit.add(stage, MeshKit.box(Vector3(5.4, 0.12, 5.4)), MeshKit.mat(Color(0.6, 0.67, 0.48), 0.9), Vector3(0, 0.06, 0))
	if type == "wall":
		StructureModels.wall(stage, [0, 0, 1], 1).position = Vector3.ZERO
	elif Catalog.is_defense(type):
		var d := Catalog.make_defense(type)
		stage.add_child(d)
		d.setup(Catalog.defense_stats(type, 1), 0.12)
		d.show_range(false)
	else:
		StructureModels.build(stage, type, 1, Vector3(0, 0.12, 0))
	for label in stage.find_children("*", "Label3D", true, false):
		(label as Node3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(5.6, 6.4, 7.4), Vector3(0, 1.1, 0))
	return frame


# ---------------------------------------------------------------- walls

static func _all_edges() -> Array:
	var out := []
	for c in range(-1, City.GRID):
		for r in range(-1, City.GRID):
			for d in 2:
				if Walls.valid([c, r, d]):
					out.append([c, r, d])
	return out


## The path closest to a screen point, within `reach` pixels, or [].
func _pick_edge(screen_pos: Vector2, reach: float) -> Array:
	var best := []
	var best_d := reach
	for e in _all_edges():
		var d := cam.unproject_position(Walls.center(e)).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _start_wall_mode() -> void:
	wall_mode = true
	placing = ""
	hud.hide_panel()
	edge_markers.visible = true
	_update_wall_banner()


func _update_wall_banner() -> void:
	var text := I18n.t("Tap or drag along the paths to build walls  ·  %d / %d") % [GameState.walls.size(), Catalog.wall_limit(GameState.hq_level())]
	hud.show_mode(text)


func _end_wall_mode() -> void:
	wall_mode = false
	edge_markers.visible = false
	hud.show_mode("")


## Wall mode: builds a wall piece on the path under the finger, if there is room for one.
func _paint_wall(screen_pos: Vector2) -> void:
	var edge := _pick_edge(screen_pos, EDGE_PICK)
	if edge.is_empty() or not GameState.wall_at(edge).is_empty():
		return
	var why := GameState.wall_block_reason()
	if why != "":
		hud.toast(why)
		return
	if GameState.build_wall(edge):
		Audio.play("click", -4.0)
		StructureModels.wall(level, edge, 1)
		var i: int = edge_marker_index.get(Walls.key(edge), -1)
		if i >= 0:
			edge_markers.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, -5, 0)))
		_update_wall_banner()


## A wall piece's sheet: its health, upgrade it alone or every piece of its level, or remove it.
func _open_wall(edge: Array) -> void:
	open_cell = []
	open_sheet = ""
	marker.visible = false
	var w := GameState.wall_at(edge)
	var lvl := int(w["level"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_wrap(HomeHud.make_label(box, I18n.t(Catalog.INFO["wall"]), 22, SOFT))
	var hp := Catalog.wall_hp(lvl)
	HomeHud.stat_bar(box, I18n.t("Health %d") % int(hp), hp, Catalog.wall_hp(Catalog.MAX_LEVEL), Color(0.35, 0.85, 0.45))
	if lvl >= Catalog.MAX_LEVEL:
		HomeHud.make_label(box, I18n.t("Max level reached"), 26, GOLD)
	else:
		var reason := GameState.wall_upgrade_reason(edge)
		var cost := Catalog.wall_upgrade_cost(lvl)
		var up := HomeHud.make_button(box, I18n.t("Upgrade to Lv %d  ·  %d coins") % [lvl + 1, cost], 26, 84)
		up.disabled = reason != ""
		_gold(up, reason == "")
		up.pressed.connect(func() -> void:
			if GameState.upgrade_wall(edge):
				Audio.play("build")
				_rebuild()
				_open_wall(edge))
		var same := GameState.walls.filter(func(o: Dictionary) -> bool: return int(o["level"]) == lvl).size()
		if same > 1:
			var all := HomeHud.make_button(box, I18n.t("Upgrade all %d Lv %d walls  ·  %d coins") % [same, lvl, cost * same], 22, 72)
			all.disabled = reason != ""
			all.pressed.connect(func() -> void:
				var n := GameState.upgrade_walls_at_level(lvl)
				if n > 0:
					Audio.play("build")
					hud.toast(I18n.t("%d walls upgraded") % n)
					_rebuild()
					_open_wall(edge))
		if reason != "":
			_wrap(HomeHud.make_label(box, reason, 22, BAD))
	HomeHud.make_button(box, I18n.t("Remove (no refund)"), 22, 64).pressed.connect(func() -> void:
		GameState.remove_wall(edge)
		_rebuild()
		hud.hide_panel())
	hud.show_content("%s  ·  %s" % [Catalog.display_name("wall"), I18n.t("Lv %d") % lvl], box)


## The Build button: pick something, then tap a free pad for it.
func _open_build(cell: Array) -> void:
	open_cell = []
	open_sheet = ""
	marker.visible = false
	hud.show_content(I18n.t("Build"), _build_menu(cell))


func _start_placing(type: String) -> void:
	placing = type
	hud.hide_panel()
	hud.toast(I18n.t("Tap a free pad for the %s") % Catalog.display_name(type))


func _open_settings() -> void:
	open_cell = []
	open_sheet = ""
	marker.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	# The language button always names the *other* language, in that language.
	HomeHud.make_button(grid, "English" if I18n.rtl() else "עברית", 24, 80).pressed.connect(_toggle_language)
	var sound := HomeHud.make_button(grid, I18n.t("Sound on") if GameState.sound_on else I18n.t("Sound off"), 24, 80)
	sound.pressed.connect(func() -> void:
		GameState.set_sound(not GameState.sound_on)
		Audio.set_enabled(GameState.sound_on)
		sound.text = I18n.t("Sound on") if GameState.sound_on else I18n.t("Sound off"))
	HomeHud.make_button(grid, I18n.t("Practice on my base"), 24, 80).pressed.connect(func() -> void: _go_raid("self"))
	if GameState.dev_tools_available():
		var dev := HomeHud.make_button(grid, I18n.t("DEV: free ON") if GameState.infinite_coins else I18n.t("DEV: free OFF"), 24, 80)
		dev.add_theme_color_override("font_color", GOOD if GameState.infinite_coins else SOFT)
		dev.pressed.connect(_toggle_infinite)
	hud.show_content(I18n.t("Settings"), box)


# ---------------------------------------------------------------- structure sheet

## What a structure does, its health, a "now vs next level" table, and the upgrade button.
func _structure_sheet(cell: Array, s: Dictionary) -> Control:
	var type: String = s["type"]
	var lvl := int(s["level"])
	var maxed := lvl >= Catalog.MAX_LEVEL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_wrap(HomeHud.make_label(box, I18n.t(Catalog.INFO[type]), 23, SOFT))
	var hp := Catalog.structure_hp(type, lvl)
	HomeHud.stat_bar(box, I18n.t("Health %d") % int(hp), hp, hp, Color(0.35, 0.85, 0.45))

	var now := _stat_lines(type, lvl)
	var next := [] if maxed else _stat_lines(type, lvl + 1)
	var table := GridContainer.new()
	table.columns = 2 if maxed else 3
	table.add_theme_constant_override("h_separation", 24)
	table.add_theme_constant_override("v_separation", 8)
	box.add_child(table)
	HomeHud.make_label(table, "", 20)
	HomeHud.make_label(table, I18n.t("Now"), 20, SOFT)
	if not maxed:
		HomeHud.make_label(table, I18n.t("Lv %d") % (lvl + 1), 20, GOOD)
	for i in now.size():
		var name_label := HomeHud.make_label(table, now[i][0], 23, SOFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		HomeHud.make_label(table, now[i][1], 25)
		if not maxed:
			var changed: bool = next[i][1] != now[i][1]
			HomeHud.make_label(table, next[i][1], 25, GOOD if changed else SOFT)

	if type == "hq" and not maxed:
		var unlocks := _hq_unlocks(lvl)
		if unlocks != "":
			_wrap(HomeHud.make_label(box, I18n.t("Upgrading unlocks: %s") % unlocks, 22, GOLD))

	var reason := GameState.upgrade_block_reason(cell)
	if GameState.is_busy(s):
		var what := I18n.t("Building") if s.get("fresh", false) else I18n.t("Upgrading to Lv %d") % (lvl + 1)
		var line := HomeHud.make_label(box, "%s  ·  %s" % [what, HomeHud.clock(GameState.seconds_left(s))], 28, GOLD)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var gems := GameState.speedup_cost(cell)
		var fast := HomeHud.make_button(box, I18n.t("Finish now  ·  %d gems") % gems, 28, 100)
		var can := GameState.infinite_coins or GameState.gems >= gems
		fast.disabled = not can
		_gold(fast, can)
		fast.pressed.connect(func() -> void: _do_speed_up(cell))
	elif maxed:
		HomeHud.make_label(box, I18n.t("Max level reached"), 26, GOLD)
	else:
		var up := HomeHud.make_button(box, I18n.t("Upgrade to Lv %d  ·  %d coins  ·  %s") % [lvl + 1, Catalog.upgrade_cost(type, lvl), HomeHud.clock(Catalog.build_seconds(type, lvl + 1))], 26, 100)
		up.disabled = reason != ""
		_gold(up, reason == "")
		up.pressed.connect(func() -> void: _do_upgrade(cell))
		if reason != "":
			var why := HomeHud.make_label(box, reason, 23, BAD)
			why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 12)
	box.add_child(extra)
	if type == "hangar" or type == "garage":
		HomeHud.make_button(extra, I18n.t("Unlock and upgrade units"), 22, 72).pressed.connect(func() -> void: _open_lab(type))
	if type == "support":
		HomeHud.make_button(extra, I18n.t("Prepare and upgrade"), 22, 72).pressed.connect(_open_support)
	if type == "camp" or type == "quarters":
		HomeHud.make_button(extra, I18n.t("Train army"), 22, 72).pressed.connect(_open_army)
	if type != "hq" and not GameState.is_busy(s):
		HomeHud.make_button(extra, I18n.t("Remove (no refund)"), 22, 72).pressed.connect(func() -> void: _do_remove(cell))
	return box


## [label, value] pairs describing a structure at a level, in the same order for every level.
func _stat_lines(type: String, lvl: int) -> Array:
	match type:
		"hq":
			return [[I18n.t("Max level for others"), str(lvl)]]
		"generator":
			var rate := Catalog.generator_rate(lvl)
			return [[I18n.t("Coins per minute"), str(int(rate))],
				[I18n.t("Holds up to"), str(int(rate * Catalog.GENERATOR_FILL_MINUTES))]]
		"storage":
			return [[I18n.t("Coin cap bonus"), "+%d" % (700 * lvl)]]
		"pump":
			var rate := Catalog.pump_rate(lvl)
			return [[I18n.t("Fuel per minute"), str(int(rate))],
				[I18n.t("Holds up to"), str(int(rate * Catalog.GENERATOR_FILL_MINUTES))]]
		"tank":
			return [[I18n.t("Fuel cap bonus"), "+%d" % (600 * lvl)]]
		"hangar":
			return [[I18n.t("Drone max level"), str(lvl)]]
		"garage":
			return [[I18n.t("Soldier and tank max level"), str(lvl)]]
		"quarters":
			return [[I18n.t("Army space"), str(Catalog.quarters_space(lvl))]]
		"camp":
			return [[I18n.t("Training speed"), "x%.2f" % (1.0 + 0.25 * (lvl - 1))]]
		"support":
			return [[I18n.t("Slots"), str(Catalog.support_slots(lvl))]]
	var st := Catalog.defense_stats(type, lvl)
	var lines := [[I18n.t("Range"), I18n.t("%.1f m") % st["radius"]]]
	if st.has("dps"):
		lines.append([I18n.t("Damage per second"), str(int(st["dps"]))])
	if st.has("damage"):
		lines.append([I18n.t("Damage per shot"), str(int(st["damage"]))])
	if st.has("cooldown"):
		lines.append([I18n.t("Reload"), I18n.t("%.1f s") % st["cooldown"]])
	if st.has("splash"):
		lines.append([I18n.t("Blast radius"), I18n.t("%.1f m") % st["splash"]])
	return lines


## What the next Command Tower level allows that this one doesn't, e.g. "Net Launcher +1".
func _hq_unlocks(lvl: int) -> String:
	var parts := []
	for type in Catalog.LIMITS:
		var more := Catalog.max_count(type, lvl + 1) - Catalog.max_count(type, lvl)
		if more > 0:
			parts.append("%s +%d" % [Catalog.display_name(type), more])
	return ", ".join(parts)


# ---------------------------------------------------------------- army and training

## The Army sheet: what is trained and waiting, the training queue, and a card per unit to
## train more. Opens from the Army button, the Training Camp and the Quarters.
func _open_army() -> void:
	open_cell = []
	open_sheet = "army"
	marker.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var space := HomeHud.make_label(head, I18n.t("Army %d / %d space") % [GameState.army_used(), GameState.army_capacity()], 28, GOLD)
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if GameState.queued_space() > 0:
		HomeHud.make_label(head, I18n.t("+%d in training") % GameState.queued_space(), 24, SOFT)
	_wrap(HomeHud.make_label(box, _army_summary(), 22))

	if not GameState.training.is_empty():
		var queue := _card(true)
		box.add_child(queue)
		var qbox := VBoxContainer.new()
		qbox.add_theme_constant_override("separation", 10)
		queue.add_child(qbox)
		var now_type: String = GameState.training[0]
		var line := I18n.t("Training %s  ·  %s") % [Catalog.display_name(now_type), HomeHud.clock(GameState.train_head_left())]
		if GameState.training.size() > 1:
			line += "  ·  " + I18n.t("%d more after it") % (GameState.training.size() - 1)
		_wrap(HomeHud.make_label(qbox, line, 24))
		var gems := GameState.training_speedup_cost()
		var fast := HomeHud.make_button(qbox, I18n.t("Finish training now  ·  %d gems") % gems, 24, 72)
		var can := GameState.infinite_coins or GameState.gems >= gems
		fast.disabled = not can
		_gold(fast, can)
		fast.pressed.connect(func() -> void:
			if GameState.speed_up_training():
				Audio.play("build")
				_refresh_header()
				_open_army())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for type in Catalog.UNIT_ORDER:
		grid.add_child(_train_card(type))
	hud.show_content(I18n.t("Army"), box)


## "Infantry Squad x2  ·  Courier x2", or a hint when the army is empty.
func _army_summary() -> String:
	var parts := []
	for type in Catalog.UNIT_ORDER:
		if int(GameState.army.get(type, 0)) > 0:
			parts.append("%s x%d" % [Catalog.display_name(type), int(GameState.army[type])])
	if parts.is_empty():
		return I18n.t("No army yet. Train units below; they wait in the Quarters for the next attack.")
	return I18n.t("Ready: %s") % "  ·  ".join(parts)


func _train_card(type: String) -> Control:
	var def := Catalog.unit_def(type)
	var owned: bool = GameState.units.has(type)
	var card := _card(owned)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	HomeHud.make_label(box, Catalog.display_name(type), 26, def["color"] if owned else Color(0.6, 0.62, 0.66))
	if not owned:
		var where := I18n.t("Unlock it in the Garage") if Catalog.is_ground(type) else I18n.t("Unlock it in the Hangar")
		_wrap(HomeHud.make_label(box, where, 20, SOFT))
		return card
	HomeHud.make_label(box, I18n.t("%d space  ·  %d fuel  ·  %s") % [int(def["housing"]), Catalog.train_fuel(type), HomeHud.clock(Catalog.train_seconds(type, GameState.camp_level()))], 20, SOFT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var queued := GameState.training.count(type)
	var minus := HomeHud.make_button(row, "-", 30, 64)
	minus.custom_minimum_size.x = 64
	minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	minus.disabled = queued <= 0
	minus.pressed.connect(func() -> void:
		GameState.cancel_training(type)
		_refresh_header()
		_open_army())
	var count := HomeHud.make_label(row, I18n.t("Queued %d") % queued, 22)
	count.custom_minimum_size.x = 110
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_FILL
	var reason := GameState.train_block_reason(type)
	var plus := HomeHud.make_button(row, I18n.t("Train"), 24, 64)
	plus.disabled = reason != ""
	_gold(plus, reason == "")
	plus.pressed.connect(func() -> void:
		if GameState.train(type):
			Audio.play("click")
			_refresh_header()
			_open_army())
	if reason != "":
		_wrap(HomeHud.make_label(box, reason, 19, BAD))
	return card


# ---------------------------------------------------------------- support base

## The Support Base sheet: slots used, what is ready and being prepared, and a card per
## ability to prepare more, unlock it or upgrade it.
func _open_support() -> void:
	open_cell = []
	open_sheet = "support"
	marker.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	HomeHud.make_label(box, I18n.t("Slots %d / %d") % [GameState.support_used(), GameState.support_slots()], 28, GOLD)
	var ready := []
	for kind in Catalog.ABILITY_ORDER:
		if int(GameState.support_ready.get(kind, 0)) > 0:
			ready.append("%s x%d" % [Catalog.display_name(kind), int(GameState.support_ready[kind])])
	_wrap(HomeHud.make_label(box, I18n.t("Ready: %s") % "  ·  ".join(ready) if not ready.is_empty() else I18n.t("Nothing prepared yet. Prepare below; you take what is ready into the next attack."), 22))
	if not GameState.support_queue.is_empty():
		var line := I18n.t("Preparing %s  ·  %s") % [Catalog.display_name(GameState.support_queue[0]), HomeHud.clock(GameState.support_head_left())]
		_wrap(HomeHud.make_label(box, line, 24))
		var gems := Catalog.speedup_gems(GameState.support_total_left())
		var fast := HomeHud.make_button(box, I18n.t("Finish now  ·  %d gems") % gems, 24, 72)
		var can := GameState.infinite_coins or GameState.gems >= gems
		fast.disabled = not can
		_gold(fast, can)
		fast.pressed.connect(func() -> void:
			if GameState.speed_up_support():
				Audio.play("build")
				_refresh_header()
				_open_support())
	for kind in Catalog.ABILITY_ORDER:
		box.add_child(_ability_card(kind))
	hud.show_content(Catalog.display_name("support"), box)


func _ability_card(kind: String) -> Control:
	var def: Dictionary = Catalog.ABILITIES[kind]
	var owned: bool = GameState.abilities.has(kind)
	var lvl := int(GameState.abilities.get(kind, 1))
	var st := Catalog.ability_stats(kind, lvl)
	var card := _card(owned)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var preview := _ability_preview(kind, lvl, owned)
	preview.custom_minimum_size = Vector2(220, 170)
	row.add_child(preview)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := HomeHud.make_label(head, Catalog.display_name(kind), 28, UnitModels.LEVEL_COLORS[lvl - 1].lightened(0.3) if owned else Color(0.6, 0.62, 0.66))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HomeHud.make_label(head, I18n.t("Lv %d") % lvl if owned else I18n.t("Locked"), 24, SOFT)
	_wrap(HomeHud.make_label(box, I18n.t(def["role"]), 20, SOFT))
	var facts := I18n.t("Bombs %d  ·  %d damage each") % [int(st["bombs"]), int(st["damage"])] if kind == "strike" else I18n.t("Burns %d s") % int(st["seconds"])
	HomeHud.make_label(box, facts, 20)
	HomeHud.make_label(box, I18n.t("%d slots  ·  %d fuel  ·  %s") % [int(def["slots"]), int(def["fuel"]), HomeHud.clock(float(def["seconds"]))], 20, SOFT)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	if owned:
		var queued := GameState.support_queue.count(kind)
		var minus := HomeHud.make_button(buttons, "-", 28, 60)
		minus.custom_minimum_size.x = 60
		minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		minus.disabled = queued <= 0
		minus.pressed.connect(func() -> void:
			GameState.cancel_prepare(kind)
			_refresh_header()
			_open_support())
		var why := GameState.prepare_block_reason(kind)
		var prep := HomeHud.make_button(buttons, I18n.t("Prepare") + ("  (%d)" % queued if queued > 0 else ""), 22, 60)
		prep.disabled = why != ""
		_gold(prep, why == "")
		prep.pressed.connect(func() -> void:
			if GameState.prepare(kind):
				Audio.play("click")
				_refresh_header()
				_open_support())
		if why != "":
			_wrap(HomeHud.make_label(box, why, 19, BAD))
	var reason := GameState.ability_block_reason(kind)
	var up_text := I18n.t("Unlock  ·  %d fuel") % int(def["unlock"])
	if owned:
		up_text = I18n.t("Max level") if lvl >= Catalog.MAX_LEVEL else I18n.t("Upgrade  ·  %d fuel") % Catalog.ability_upgrade_cost(kind, lvl)
	var up := HomeHud.make_button(buttons, up_text, 20, 60)
	up.disabled = reason != ""
	_gold(up, reason == "" and not owned)
	up.pressed.connect(func() -> void:
		if GameState.upgrade_ability(kind):
			Audio.play("build")
			_refresh_header()
			_open_support())
	if reason != "" and not (owned and lvl >= Catalog.MAX_LEVEL):
		_wrap(HomeHud.make_label(box, reason, 19, BAD))
	return card


## A small 3D stage with the plane (air strike) or the flare at this level.
func _ability_preview(kind: String, lvl: int, owned: bool) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	frame.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.6
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.5, 11.0), Vector3(0, 0.5, 0))
	var holder := Node3D.new()
	vp.add_child(holder)
	var spin := holder.create_tween().set_loops()
	spin.tween_property(holder, "rotation:y", TAU, 8.0).as_relative()
	if kind == "strike":
		UnitModels.aircraft(holder, lvl)
	else:
		var st := Catalog.ability_stats("flare", lvl)
		var count := int(st["flares"])
		for i in count:
			var f := Node3D.new()
			f.position = Vector3((i - (count - 1) / 2.0) * 1.8, 0.5 + (i % 2) * 0.6, 0)
			holder.add_child(f)
			MeshKit.add(f, MeshKit.sphere(0.3 + 0.05 * lvl, 10), MeshKit.glow(Color(1.0, 0.95, 0.75)))
			MeshKit.add(f, MeshKit.sphere(0.9 + 0.12 * lvl, 12), MeshKit.glow(Color(1.0, 0.3, 0.12) if lvl >= 3 else Color(1.0, 0.45, 0.2), 0.45))
			if lvl >= 3:
				MeshKit.add(f, MeshKit.sphere(1.0, 12), MeshKit.mat(Color(0.9, 0.88, 0.8), 0.8), Vector3(0, 1.7, 0)).scale = Vector3(1, 0.45, 1)
	if not owned:
		frame.modulate = Color(0.55, 0.55, 0.6)
	return frame


# ---------------------------------------------------------------- hangar and garage

## The Hangar (drones) or the Garage (infantry, engineers, tanks): unlock and upgrade units.
func _open_lab(lab: String) -> void:
	open_cell = []
	open_sheet = lab
	marker.visible = false
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	var lab_level := GameState.level_of(lab)
	var hint := I18n.t("Unlock and upgrade drones here. The Hangar's level caps their level.") if lab == "hangar" \
		else I18n.t("Unlock and upgrade soldiers and tanks here. The Garage's level caps their level.")
	_wrap(HomeHud.make_label(content, hint, 21, SOFT))
	if lab_level <= 0:
		_wrap(HomeHud.make_label(content, I18n.t("Build it first: tap a free pad or press Build."), 22, BAD))
	var order: Array = Catalog.DRONE_ORDER if lab == "hangar" else Catalog.GROUND_ORDER
	for type in order:
		content.add_child(_unit_card(type, order))
	hud.show_content(Catalog.display_name(lab), content)


func _unit_card(type: String, order: Array) -> Control:
	var def := Catalog.unit_def(type)
	var owned: bool = GameState.units.has(type)
	var lvl := int(GameState.units.get(type, 1))
	var st := Catalog.unit_stats(type, lvl)
	var ground := Catalog.is_ground(type)
	# Bars are scaled to the strongest unit in this lab at max level, so they compare fairly.
	var top_health := 1.0
	var top_dps := 1.0
	for other in order:
		var o := Catalog.unit_stats(other, Catalog.MAX_LEVEL)
		top_health = maxf(top_health, float(o["health"]) * float(o.get("squad", 1)))
		top_dps = maxf(top_dps, float(o["dps"]) * float(o.get("squad", 1)))
	var squad := float(st.get("squad", 1))

	var card := _card(owned)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var preview := _unit_preview(type, st, owned)
	preview.custom_minimum_size = Vector2(240, 220)
	row.add_child(preview)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := HomeHud.make_label(head, Catalog.display_name(type), 30, def["color"] if owned else Color(0.6, 0.62, 0.66))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HomeHud.make_label(head, I18n.t("Lv %d") % lvl if owned else I18n.t("Locked"), 24, SOFT)
	_wrap(HomeHud.make_label(box, I18n.t(def["role"]), 20, SOFT))
	HomeHud.stat_bar(box, I18n.t("Health %d") % int(float(st["health"]) * squad), float(st["health"]) * squad, top_health, Color(0.35, 0.85, 0.45))
	HomeHud.stat_bar(box, I18n.t("Speed %.1f") % st["speed"], st["speed"], 14.0 if not ground else 6.0, Color(0.35, 0.75, 1.0))
	HomeHud.stat_bar(box, I18n.t("Damage %d/s") % int(float(st["dps"]) * squad), float(st["dps"]) * squad, top_dps, Color(1.0, 0.55, 0.3))
	var facts := I18n.t("Takes %d space") % int(def["housing"])
	if ground and int(st.get("squad", 1)) > 1:
		facts += "  ·  " + I18n.t("%d soldiers") % int(st["squad"])
	HomeHud.make_label(box, facts, 20, SOFT)

	var reason := GameState.unit_block_reason(type)
	if owned:
		var up_text := I18n.t("Max level")
		if lvl < Catalog.MAX_LEVEL:
			up_text = I18n.t("Upgrade  ·  %d fuel") % Catalog.unit_upgrade_cost(type, lvl)
		var up := HomeHud.make_button(box, up_text, 22, 64)
		up.disabled = reason != ""
		_gold(up, reason == "")
		up.pressed.connect(func() -> void: _do_unit(type))
	else:
		var unlock := HomeHud.make_button(box, I18n.t("Unlock  ·  %d fuel") % int(def["unlock"]), 22, 64)
		unlock.disabled = reason != ""
		_gold(unlock, reason == "")
		unlock.pressed.connect(func() -> void: _do_unit(type))
	if reason != "" and not (owned and lvl >= Catalog.MAX_LEVEL):
		_wrap(HomeHud.make_label(box, reason, 20, BAD))
	return card


## A small 3D stage with the unit on a turntable looping its signature move. Drones share one
## camera distance and ground units another, so sizes compare honestly within each lab.
func _unit_preview(type: String, stats: Dictionary, owned: bool) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	frame.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	vp.add_child(light)
	var stage := Node3D.new()
	vp.add_child(stage)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	if Catalog.is_ground(type):
		MeshKit.add(stage, MeshKit.cyl(4.2, 4.2, 0.05, 48), MeshKit.mat(Color(0.2, 0.24, 0.16), 0.95))
		cam.look_at_from_position(Vector3(0, 6.0, 15.0), Vector3(0, 1.2, 0))
		var count := int(stats.get("squad", 1))
		for i in count:
			var u := GroundUnit.new()
			u.configure(stats)
			u.showcase = true
			u.kneels = i % 2 == 0
			u.position = Vector3((i - (count - 1) / 2.0) * 1.6, 0, (i % 2) * -1.0)
			vp.add_child(u)
	else:
		MeshKit.add(stage, MeshKit.cyl(3.4, 3.4, 0.05, 48), MeshKit.mat(Color(0.12, 0.14, 0.17), 0.95))
		cam.look_at_from_position(Vector3(0, 2.4, 7.6), Vector3(0, 1.3, 0))
		var drone := Drone.new()
		drone.configure(stats)
		drone.showcase = true
		drone.position = Vector3(0, 1.6, 0)
		vp.add_child(drone)
	if not owned:
		frame.modulate = Color(0.55, 0.55, 0.6)
	return frame


# ---------------------------------------------------------------- small UI helpers

func _card(active: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HomeHud.flat(Color(1, 1, 1, 0.07) if active else Color(1, 1, 1, 0.03)))
	return card


func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Gold styling for the main action button when it can be pressed.
func _gold(button: Button, enabled: bool) -> void:
	if not enabled:
		return
	button.add_theme_stylebox_override("normal", HomeHud.flat(Color(0.95, 0.7, 0.15)))
	button.add_theme_stylebox_override("hover", HomeHud.flat(Color(1.0, 0.78, 0.25)))
	button.add_theme_stylebox_override("pressed", HomeHud.flat(Color(0.82, 0.58, 0.1)))
	button.add_theme_color_override("font_color", Color(0.15, 0.1, 0.02))
	button.add_theme_color_override("font_hover_color", Color(0.15, 0.1, 0.02))
	button.add_theme_color_override("font_pressed_color", Color(0.15, 0.1, 0.02))


# ---------------------------------------------------------------- actions

func _do_build(type: String, cell: Array) -> void:
	if GameState.build(type, cell):
		Audio.play("build")
		hud.toast(I18n.t("%s built") % Catalog.display_name(type))
		_rebuild()
		_open_cell(cell)


func _do_upgrade(cell: Array) -> void:
	if GameState.upgrade(cell):
		Audio.play("build")
		hud.toast(I18n.t("Upgrade started"))
		_rebuild()
		_open_cell(cell)


func _do_speed_up(cell: Array) -> void:
	if GameState.speed_up(cell):
		Audio.play("build")
		hud.toast(I18n.t("Done!"))
		_rebuild()
		_open_cell(cell)


## Who is working on what, and the button to hire one more worker for gems.
func _open_workers() -> void:
	open_cell = []
	open_sheet = ""
	marker.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	HomeHud.make_label(box, I18n.t("Free workers: %d / %d") % [GameState.free_workers(), GameState.workers], 28, GOLD)
	_wrap(HomeHud.make_label(box, I18n.t("Every build or upgrade needs a free worker until it is done."), 21, SOFT))
	for s in GameState.structures:
		if GameState.is_busy(s):
			HomeHud.make_label(box, "%s  ·  %s" % [Catalog.display_name(s["type"]), HomeHud.clock(GameState.seconds_left(s))], 24)
	var why := GameState.hire_worker_reason()
	if GameState.workers < Catalog.MAX_WORKERS:
		var hire := HomeHud.make_button(box, I18n.t("Hire a worker  ·  %d gems") % Catalog.WORKER_GEMS, 26, 90)
		hire.disabled = why != ""
		_gold(hire, why == "")
		hire.pressed.connect(func() -> void:
			if GameState.hire_worker():
				Audio.play("build")
				_refresh_header()
				_open_workers())
	if why != "":
		_wrap(HomeHud.make_label(box, why, 21, BAD))
	hud.show_content(I18n.t("Workers"), box)


func _do_remove(cell: Array) -> void:
	if GameState.remove(cell):
		_rebuild()
		hud.hide_panel()


func _do_unit(type: String) -> void:
	if GameState.upgrade_unit(type):
		Audio.play("build")
		hud.toast(I18n.t("%s Lv %d") % [Catalog.display_name(type), int(GameState.units[type])])
		_refresh_header()
		_open_lab(Catalog.unit_lab(type))


## Switches every text in the game between Hebrew and English; the scene reloads to redraw.
func _toggle_language() -> void:
	GameState.set_language("en" if I18n.rtl() else "he")
	get_tree().reload_current_scene()


func _toggle_infinite() -> void:
	GameState.set_infinite_coins(not GameState.infinite_coins)
	_refresh_header()
	_open_settings()


func _go_raid(target: String) -> void:
	if GameState.army_used() <= 0:
		hud.toast(I18n.t("Train an army first"))
		_open_army()
		return
	GameState.raid_target = target
	get_tree().change_scene_to_file(RAID_SCENE)
