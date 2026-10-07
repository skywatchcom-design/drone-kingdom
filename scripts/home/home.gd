extends Node3D
## The player's base. Tap a pad to build or upgrade (or press Build, pick, then tap a free pad),
## tap a floating coin or fuel drop to collect, train an army (Army button or the Training
## Camp), unlock and upgrade units in the Garage and the Hangar, then Attack. Settings holds
## language, sound, practice on your own base and dev tools.
## Run with `-- --screenshot-panel` / `--screenshot-hq` / `--screenshot-army` / `--screenshot-place` / `--screenshot-shop` /
## `--screenshot-upgrade` / `--screenshot-info` /
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
## The wall piece tapped last, or [].
var open_wall: Array = []
## The Shop tab opened last.
var shop_tab := "army"
## The Missions tab opened last.
var missions_tab := ""
## The open Army window, so its queue timer can tick.
var army_box: Control
## Which sheet is open besides a structure's ("army", "hangar", "garage" or ""), so it can
## be refreshed as training moves on.
var open_sheet := ""
## Structure type picked from the Build menu, waiting for a free pad to be tapped.
var placing := "":
	set(value):
		placing = value
		_show_free_pads(value != "")
## Glowing squares on every free pad while a building waits to be placed.
var _free_pads: MultiMeshInstance3D
var _free_pad_mat: StandardMaterial3D
var _blink := 0.0
var _pinch := Pinch.new()
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
	Audio.music(true)
	cam = WorldSetup.create(self, VIEW_SIZE)
	hud = HomeHud.new()
	add_child(hud)
	hud.attack_pressed.connect(_open_attack_choice)
	hud.army_pressed.connect(_open_army)
	hud.build_pressed.connect(func() -> void: _open_shop())
	hud.actions_closed.connect(func() -> void:
		open_cell = []
		open_wall = []
		marker.visible = false)
	hud.settings_pressed.connect(_open_settings)
	hud.workers_pressed.connect(_open_workers)
	hud.gems_pressed.connect(func() -> void: hud.toast(I18n.t("The gem shop is coming soon")))
	hud.mode_done.connect(_end_wall_mode)
	hud.missions_pressed.connect(func() -> void: _open_missions())
	hud.profile_pressed.connect(_open_profile)
	GameState.missions_changed.connect(_refresh_header)
	Cloud.account_changed.connect(_refresh_header)
	GameState.finish_ready()
	GameState.process_training()
	_rebuild()
	GameState.tutorial_event("home")
	Tutorial.attach(self)
	# Each new tutorial step starts from a clear base, so its target is in view.
	GameState.tutorial_changed.connect(func() -> void:
		if GameState.tutorial >= 0 and not GameState.tutorial_replay:
			hud.hide_modal()
			hud.hide_panel()
			_deselect()
		if GameState.tutorial_gift > 0:
			hud.toast(I18n.t("+%d gems") % GameState.tutorial_gift)
			Audio.play("star")
			GameState.tutorial_gift = 0
			_refresh_header()
		# Once Noa is done (finished or skipped): sign up, then the missions take over.
		if GameState.tutorial < 0:
			get_tree().create_timer(1.6).timeout.connect(func() -> void:
				if Cloud.signed_in():
					_open_missions("starter")
				else:
					_open_account("signup")))
	var args := OS.get_cmdline_user_args()
	if args.has("--screenshot-panel"):
		_open_cell([1, 3])
	elif args.has("--screenshot-hq"):
		_open_cell([4, 4])
	elif args.has("--screenshot-army"):
		_open_army()
	elif args.has("--screenshot-place"):
		_start_placing("generator")
	elif args.has("--screenshot-hangar"):
		_open_lab("hangar")
	elif args.has("--screenshot-garage"):
		_open_lab("garage")
	elif args.has("--screenshot-build") or args.has("--screenshot-shop"):
		_open_shop("defenses")
	elif args.has("--screenshot-upgrade"):
		_open_upgrade([4, 4])
	elif args.has("--screenshot-info"):
		_open_info("mg", 1, [4, 3])
	elif args.has("--screenshot-settings"):
		_open_settings()
	elif args.has("--screenshot-missions"):
		_open_missions("starter")
	elif args.has("--screenshot-daily"):
		_open_missions("daily")
	elif args.has("--screenshot-signup"):
		_open_account("signup")
	elif args.has("--screenshot-signin"):
		_open_account("signin")
	elif args.has("--screenshot-profile"):
		_open_profile()
	elif GameState.tutorial < 0 and not Cloud.signed_in():
		# Playing on needs an account.
		_open_account("signup")
	elif GameState.tutorial < 0 and GameState.login_ready():
		# The day's first visit opens the login gift.
		_open_missions("daily")


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
	var sites := []
	for s in GameState.structures:
		if GameState.is_busy(s):
			sites.append(city.roof_top(s["cell"]))
	var life := BaseLife.new()
	level.add_child(life)
	life.setup(level, sites)
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
		bubble.position = city.roof_top(s["cell"]) + Vector3(0, 3.4, 0)
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
	if _free_pads != null and _free_pads.visible:
		_blink += delta
		_free_pad_mat.albedo_color.a = 0.25 + 0.3 * (0.5 + 0.5 * sin(_blink * 6.0))
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
	if not open_cell.is_empty() and hud.actions_open() and GameState.is_busy(GameState.structure_at(open_cell)):
		_open_cell(open_cell)
	elif open_sheet == "army" and hud.modal_open() and army_box != null and is_instance_valid(army_box):
		if trained > 0:
			_open_army()
		else:
			ShopUI.update_army_timer(army_box)
	elif open_sheet == "support" and hud.panel_open() and not GameState.support_queue.is_empty():
		_open_support()


func _refresh_header() -> void:
	var target := Bases.enemy(GameState.enemy_index, GameState.hq_level())
	hud.set_header(GameState.hq_level(), target["name"], GameState.infinite_coins)
	hud.set_shop_badge(ShopUI.new_count())
	hud.set_commander(Cloud.commander)
	hud.set_missions(GameState.missions_ready(), GameState.tutorial < 0 or GameState.tutorial_replay)
	for bubble in coins:
		if bubble.scale.x > 0.99:
			bubble.set_amount(GameState.generator_pending(GameState.structure_at(bubble.cell)))


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var zoom := _pinch.handle(event)
	if zoom != 1.0:
		cam.size = clampf(cam.size / zoom, 36.0, 90.0)
		return
	if event is InputEventScreenDrag:
		if _pinch.gesture:
			return
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
	if _pinch.gesture or hud.blocks(touch.position) or touch.position.distance_to(press_pos) > TAP_SLOP:
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
		_select_wall(edge)
		return
	if placing != "" and not cell.is_empty() and GameState.structure_at(cell).is_empty():
		var type := placing
		placing = ""
		_do_build(type, cell)
		return
	placing = ""
	hud.hide_panel()
	if cell.is_empty():
		_deselect()
	else:
		_open_cell(cell)


## Where Noa's tutorial points on the base (see Tutorial): a coin or fuel drop, a free pad
## while placing, or a building to tap. Rect2() when it isn't on screen.
func tutorial_target(key: String) -> Rect2:
	if key == "coin_generator" or key == "coin_pump":
		for bubble in coins:
			if bubble.visible and bubble.fuel == (key == "coin_pump"):
				return _screen_box(bubble.global_position, Vector2(110, 110))
		return Rect2()
	if hud.modal_open() or hud.actions_open() or hud.panel_open():
		return Rect2()
	if key == "free_pad":
		if placing == "":
			return Rect2()
		var best := []
		var best_d := INF
		for c in City.GRID:
			for r in City.GRID:
				var d := Vector2(c - 4, r - 3.2).length()
				if d < best_d and GameState.structure_at([c, r]).is_empty():
					best_d = d
					best = [c, r]
		return _screen_box(city.roof_top(best), Vector2(130, 100)) if not best.is_empty() else Rect2()
	if key.begins_with("cell_") and placing == "":
		var type := key.trim_prefix("cell_")
		for s in GameState.structures:
			if s["type"] == type:
				return _screen_box(city.roof_top(s["cell"]) + Vector3(0, 1.5, 0), Vector2(120, 120))
	return Rect2()


func _screen_box(world: Vector3, size: Vector2) -> Rect2:
	return Rect2(cam.unproject_position(world) - size / 2.0, size)


## Tapping near a visible coin collects that generator.
func _try_collect(screen_pos: Vector2) -> bool:
	for bubble in coins:
		if not bubble.visible:
			continue
		if cam.unproject_position(bubble.global_position).distance_to(screen_pos) > COIN_PICK_RADIUS:
			continue
		var got := GameState.collect_generator(bubble.cell)
		if got > 0:
			GameState.tutorial_event("collect_fuel" if bubble.fuel else "collect_coins")
			hud.toast(I18n.t("+%d fuel") % got if bubble.fuel else I18n.t("+%d coins") % got)
			bubble.pop()
			Audio.play("coin", -8.0)
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
	if not open_cell.is_empty() and hud.actions_open():
		_open_cell(open_cell)


# ---------------------------------------------------------------- selection, shop and windows

## Tapping a building: its name and level over round actions: Info, Upgrade (or Finish now
## while it is busy), and its own action (train, prepare, units, collect).
func _open_cell(cell: Array) -> void:
	var s := GameState.structure_at(cell)
	if s.is_empty():
		_deselect()
		return
	open_cell = cell
	open_wall = []
	open_sheet = ""
	marker.visible = true
	_show_range(cell)
	marker.position = city.roof_top(cell) + Vector3(0, 0.5, 0)
	var type: String = s["type"]
	var lvl := int(s["level"])
	var actions := [{"icon": "info", "label": I18n.t("Info"), "call": func() -> void: _open_info(type, lvl, cell)}]
	if GameState.is_busy(s):
		var gems := GameState.speedup_cost(cell)
		actions.append({"icon": "clock", "label": I18n.t("Finish now"), "cost": str(gems), "cost_icon": "gem",
			"disabled": not (GameState.infinite_coins or GameState.gems >= gems), "call": func() -> void: _do_speed_up(cell)})
	elif lvl < Catalog.MAX_LEVEL:
		actions.append({"icon": "up", "label": I18n.t("Upgrade"), "cost": HomeHud._thousands(Catalog.upgrade_cost(type, lvl)),
			"cost_icon": "coin", "call": func() -> void: _open_upgrade(cell)})
	var own := _own_action(type, cell)
	if not own.is_empty():
		actions.append(own)
	var title := "%s  (%s)" % [Catalog.display_name(type), I18n.t("Lv %d") % lvl]
	if GameState.is_busy(s):
		title += "  ·  " + HomeHud.clock(GameState.seconds_left(s))
	hud.show_actions(title, actions)


func _own_action(type: String, cell: Array) -> Dictionary:
	match type:
		"camp", "quarters":
			return {"icon": "train", "label": I18n.t("Train"), "call": _open_army}
		"hangar":
			return {"icon": "drone", "label": I18n.t("Drones"), "call": func() -> void: _open_lab("hangar")}
		"garage":
			return {"icon": "army", "label": I18n.t("Units"), "call": func() -> void: _open_lab("garage")}
		"support":
			return {"icon": "plane", "label": I18n.t("Prepare"), "call": _open_support}
		"generator", "pump":
			return {"icon": "coin" if type == "generator" else "fuel", "label": I18n.t("Collect"), "call": func() -> void: _collect(cell)}
	return {}


func _collect(cell: Array) -> void:
	for bubble in coins:
		if bubble.cell == cell and bubble.visible:
			_try_collect(cam.unproject_position(bubble.global_position))
			return
	hud.toast(I18n.t("Nothing to collect yet"))


func _deselect() -> void:
	open_cell = []
	open_wall = []
	marker.visible = false
	_show_range([])
	hud.hide_actions()


## Shows the range ring of the defense on `cell` only (none for an empty cell).
func _show_range(cell: Array) -> void:
	var at := City.cell_pos(cell) if not cell.is_empty() else Vector3(INF, 0, INF)
	for d in defenses:
		d.show_range(Vector2(d.position.x - at.x, d.position.z - at.z).length() < 1.0)


## Blinks every free pad while a building waits to be placed, so it is clear where it can go.
func _show_free_pads(on: bool) -> void:
	if _free_pads != null:
		_free_pads.queue_free()
		_free_pads = null
	if not on or city == null:
		return
	var xfs := []
	for c in City.GRID:
		for r in City.GRID:
			if GameState.structure_at([c, r]).is_empty():
				xfs.append(Transform3D(Basis(), city.roof_top([c, r]) + Vector3(0, 0.05, 0)))
	_free_pad_mat = MeshKit.glow(Color(0.45, 1.0, 0.45), 0.4)
	_free_pads = MeshKit.multi(level, MeshKit.box(Vector3(City.PAD - 0.2, 0.06, City.PAD - 0.2)), _free_pad_mat, xfs)
	_free_pads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blink = 0.0


## The big upgrade window for a structure: next-level picture, stat bars, time and price.
func _open_upgrade(cell: Array) -> void:
	var s := GameState.structure_at(cell)
	var type: String = s["type"]
	var lvl := int(s["level"])
	var extra := ""
	if type == "hq":
		var unlocks := _hq_unlocks(lvl)
		if unlocks != "":
			extra = I18n.t("Upgrading unlocks: %s") % unlocks
	var confirm := func() -> void:
		hud.hide_modal()
		_do_upgrade(cell)
	var content := ShopUI.upgrade_window(I18n.t("Upgrade %s to Lv %d?") % [Catalog.display_name(type), lvl + 1], type, lvl + 1,
		_upgrade_rows(type, lvl), extra, HomeHud.clock(Catalog.build_seconds(type, lvl + 1)),
		Catalog.upgrade_cost(type, lvl), "coin", GameState.upgrade_block_reason(cell), confirm)
	hud.show_modal(content, Vector2(940, 540))


## Rows for the upgrade window: [icon, label, now, next, best], health first, then what the
## structure does.
func _upgrade_rows(type: String, lvl: int) -> Array:
	var nxt := mini(lvl + 1, Catalog.MAX_LEVEL)
	var top := Catalog.MAX_LEVEL
	if type == "wall":
		return [["heart", I18n.t("Health"), Catalog.wall_hp(lvl), Catalog.wall_hp(nxt), Catalog.wall_hp(top)]]
	var rows := [["heart", I18n.t("Health"), Catalog.structure_hp(type, lvl), Catalog.structure_hp(type, nxt), Catalog.structure_hp(type, top)]]
	match type:
		"hq":
			rows.append(["star", I18n.t("Max level for others"), lvl, nxt, top])
		"generator":
			rows.append(["coin", I18n.t("Coins per minute"), Catalog.generator_rate(lvl), Catalog.generator_rate(nxt), Catalog.generator_rate(top)])
			rows.append(["box", I18n.t("Holds up to"), Catalog.generator_rate(lvl) * Catalog.GENERATOR_FILL_MINUTES, Catalog.generator_rate(nxt) * Catalog.GENERATOR_FILL_MINUTES, Catalog.generator_rate(top) * Catalog.GENERATOR_FILL_MINUTES])
		"pump":
			rows.append(["fuel", I18n.t("Fuel per minute"), Catalog.pump_rate(lvl), Catalog.pump_rate(nxt), Catalog.pump_rate(top)])
			rows.append(["box", I18n.t("Holds up to"), Catalog.pump_rate(lvl) * Catalog.GENERATOR_FILL_MINUTES, Catalog.pump_rate(nxt) * Catalog.GENERATOR_FILL_MINUTES, Catalog.pump_rate(top) * Catalog.GENERATOR_FILL_MINUTES])
		"storage":
			rows.append(["coin", I18n.t("Coin cap bonus"), 700 * lvl, 700 * nxt, 700 * top])
		"tank":
			rows.append(["fuel", I18n.t("Fuel cap bonus"), 600 * lvl, 600 * nxt, 600 * top])
		"quarters":
			rows.append(["army", I18n.t("Army space"), Catalog.quarters_space(lvl), Catalog.quarters_space(nxt), Catalog.quarters_space(top)])
		"camp":
			rows.append(["clock", I18n.t("Training speed %"), 100 + 25 * (lvl - 1), 100 + 25 * (nxt - 1), 100 + 25 * (top - 1)])
		"hangar":
			rows.append(["drone", I18n.t("Drone max level"), lvl, nxt, top])
		"garage":
			rows.append(["army", I18n.t("Soldier and tank max level"), lvl, nxt, top])
		"support":
			rows.append(["plane", I18n.t("Slots"), Catalog.support_slots(lvl), Catalog.support_slots(nxt), Catalog.support_slots(top)])
	if Catalog.is_defense(type):
		var a := Catalog.defense_stats(type, lvl)
		var b := Catalog.defense_stats(type, nxt)
		var c := Catalog.defense_stats(type, top)
		for k: Array in [["dps", "boom", "Damage per second"], ["damage", "boom", "Damage per shot"], ["radius", "range", "Range"], ["splash", "range", "Blast radius"]]:
			if a.has(k[0]):
				rows.append([k[1], I18n.t(k[2]), a[k[0]], b[k[0]], c[k[0]]])
	return rows


## The info window: picture at this level, the numbers, what it is good and bad against,
## and what it is for. A built structure can be removed from here.
func _open_info(type: String, lvl: int, cell: Array) -> void:
	var rows := []
	if type == "wall":
		rows.append([I18n.t("Health"), str(int(Catalog.wall_hp(lvl)))])
	else:
		rows.append([I18n.t("Health"), str(int(Catalog.structure_hp(type, lvl)))])
		rows.append_array(_stat_lines(type, lvl))
	if Catalog.is_defense(type):
		var vs: Dictionary = Catalog.DEFENSES[type].get("vs", {})
		var names := {"soldier": I18n.t("Soldiers"), "tank": I18n.t("Tanks"), "air": I18n.t("Drones")}
		var strong := []
		var weak := []
		for k in names:
			var f := float(vs.get(k, 0.0))
			if f >= 1.0:
				strong.append(names[k])
			elif f < 0.5:
				weak.append(names[k])
		if not strong.is_empty():
			rows.append([I18n.t("Strong against"), ", ".join(strong)])
		if not weak.is_empty():
			rows.append([I18n.t("Weak against"), ", ".join(weak)])
	var buttons := []
	if not cell.is_empty() and type != "hq" and not GameState.is_busy(GameState.structure_at(cell)):
		var remove := func() -> void:
			hud.hide_modal()
			_do_remove(cell)
		buttons.append({"text": I18n.t("Remove (no refund)"), "call": remove})
	var title := "%s  (%s)" % [Catalog.display_name(type), I18n.t("Lv %d") % lvl]
	hud.show_modal(ShopUI.info_window(title, type, lvl, rows, I18n.t(Catalog.INFO[type]), buttons), Vector2(860, 500))


## Tapping a wall piece: Info, Upgrade, and upgrading every piece of its level at once.
func _select_wall(edge: Array) -> void:
	var w := GameState.wall_at(edge)
	var lvl := int(w["level"])
	open_wall = edge
	open_cell = []
	marker.visible = true
	marker.position = Walls.center(edge) + Vector3(0, 0.5, 0)
	var actions := [{"icon": "info", "label": I18n.t("Info"), "call": func() -> void: _open_wall_info(edge)}]
	if lvl < Catalog.MAX_LEVEL:
		var cost := Catalog.wall_upgrade_cost(lvl)
		actions.append({"icon": "up", "label": I18n.t("Upgrade"), "cost": HomeHud._thousands(cost), "cost_icon": "coin",
			"call": func() -> void: _open_wall_upgrade(edge)})
		var same := GameState.walls.filter(func(o: Dictionary) -> bool: return int(o["level"]) == lvl).size()
		if same > 1:
			var all := func() -> void:
				var n := GameState.upgrade_walls_at_level(lvl)
				if n > 0:
					Audio.play("build")
					hud.toast(I18n.t("%d walls upgraded") % n)
					_rebuild()
					_select_wall(edge)
			actions.append({"icon": "up", "label": I18n.t("All %d") % same, "cost": HomeHud._thousands(cost * same), "cost_icon": "coin",
				"disabled": GameState.wall_upgrade_reason(edge) != "", "call": all})
	hud.show_actions("%s  (%s)" % [Catalog.display_name("wall"), I18n.t("Lv %d") % lvl], actions)


func _open_wall_info(edge: Array) -> void:
	var lvl := int(GameState.wall_at(edge)["level"])
	var remove := func() -> void:
		hud.hide_modal()
		GameState.remove_wall(edge)
		_rebuild()
		_deselect()
	var buttons := [{"text": I18n.t("Remove (no refund)"), "call": remove}]
	hud.show_modal(ShopUI.info_window("%s  (%s)" % [Catalog.display_name("wall"), I18n.t("Lv %d") % lvl], "wall", lvl,
		[[I18n.t("Health"), str(int(Catalog.wall_hp(lvl)))]], I18n.t(Catalog.INFO["wall"]), buttons), Vector2(820, 440))


func _open_wall_upgrade(edge: Array) -> void:
	var lvl := int(GameState.wall_at(edge)["level"])
	var confirm := func() -> void:
		hud.hide_modal()
		if GameState.upgrade_wall(edge):
			Audio.play("build")
			_rebuild()
			_select_wall(edge)
	var content := ShopUI.upgrade_window(I18n.t("Upgrade %s to Lv %d?") % [Catalog.display_name("wall"), lvl + 1], "wall", lvl + 1,
		_upgrade_rows("wall", lvl), "", "", Catalog.wall_upgrade_cost(lvl), "coin", GameState.wall_upgrade_reason(edge), confirm)
	hud.show_modal(content, Vector2(900, 480))


## The Shop, on `tab` (or the last tab used).
func _open_shop(tab: String = "") -> void:
	if tab != "":
		shop_tab = tab
	if GameState.tutorial_key() == "build" and not GameState.tutorial_replay:
		shop_tab = "defenses"
	_deselect()
	hud.hide_panel()
	var buy := func(type: String) -> void:
		hud.hide_modal()
		if type == "wall":
			_start_wall_mode()
		else:
			_start_placing(type)
	var content := ShopUI.shop(shop_tab, func(t: String) -> void: _open_shop(t), buy, func(type: String) -> void: _open_info(type, 1, []))
	hud.show_modal(content, Vector2(1180, 610))


# ---------------------------------------------------------------- account

## Sign up ("signup") or sign in ("signin") with a commander name and password.
func _open_account(mode: String) -> void:
	_deselect()
	hud.hide_panel()
	open_sheet = "account"
	var content := AccountUI.window(mode, _submit_account, func(m: String) -> void: _open_account(m))
	hud.show_modal(content, Vector2(840, {"signup": 620, "signin": 560, "reset": 470}[mode]), not Cloud.signed_in(), true)


func _submit_account(data: Dictionary, mode: String, window: Control) -> void:
	AccountUI.set_busy(window)
	var why: String
	if mode == "signup":
		why = await Cloud.sign_up(data["name"], data["password"], data["email"], int(data["year"]), int(data["month"]))
	elif mode == "reset":
		why = await Cloud.request_reset(data["login"])
		if why == "":
			AccountUI.show_error(window, I18n.t("If this email has a base, a link is on its way. Check your inbox (and spam)."))
			(window.get_meta("error") as Label).add_theme_color_override("font_color", AccountUI.GOOD)
			return
	else:
		why = await Cloud.sign_in(data["login"], data["password"])
	if not is_instance_valid(window):
		return
	if why != "":
		AccountUI.show_error(window, why)
		return
	Audio.play("star")
	if mode == "signin":
		# The base from the cloud replaced this one: draw it again.
		get_tree().reload_current_scene()
		return
	hud.hide_modal()
	hud.toast(I18n.t("Base saved, Commander %s!") % Cloud.commander)
	_refresh_header()
	get_tree().create_timer(1.2).timeout.connect(func() -> void: _open_missions("starter"))


## Settings > account: who is signed in and Log out, or the sign-up window.
func _open_account_settings() -> void:
	if not Cloud.signed_in():
		_open_account("signup")
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	HomeHud.make_label(box, I18n.t("Signed in as %s") % Cloud.commander, 28, GOLD)
	_wrap(HomeHud.make_label(box, I18n.t("Your base is saved in the cloud. Log in with this name and password on any device."), 21, SOFT))
	HomeHud.make_button(box, I18n.t("Log out"), 24, 72).pressed.connect(func() -> void:
		Cloud.sign_out()
		hud.hide_panel()
		hud.toast(I18n.t("Logged out"))
		_open_account("signup"))
	var delete := HomeHud.make_button(box, I18n.t("Delete account"), 20, 56)
	delete.add_theme_color_override("font_color", BAD)
	delete.pressed.connect(_confirm_delete_account)
	hud.show_content(I18n.t("Account"), box)


## Deleting the account asks once more: the base in the cloud and on this device is gone for good.
func _confirm_delete_account() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var q := HomeHud.ink(box, I18n.t("Delete the account and the base for good? This cannot be undone."), 26)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var yes := HomeHud.make_button(row, I18n.t("Delete for good"), 22, 64)
	yes.add_theme_color_override("font_color", BAD)
	HomeHud.make_button(row, I18n.t("Keep my base"), 22, 64).pressed.connect(func() -> void: hud.hide_modal())
	yes.pressed.connect(func() -> void:
		yes.disabled = true
		var why: String = await Cloud.delete_account()
		if why != "":
			hud.toast(why)
			yes.disabled = false
			return
		hud.hide_modal()
		get_tree().reload_current_scene())
	hud.hide_panel()
	hud.show_modal(box, Vector2(720, 300))


# ---------------------------------------------------------------- profile

## The commander's profile: name, Command Tower level, campaign stars, battle record, what has
## been built, and every unit at its level.
func _open_profile() -> void:
	_deselect()
	hud.hide_panel()
	open_sheet = "profile"
	hud.show_modal(ProfileUI.window(func() -> void:
		hud.hide_modal()
		_open_account_settings()), Vector2(1120, 600))


# ---------------------------------------------------------------- missions

## The Missions window on `tab` (the last one used, or Starter until those are all done).
func _open_missions(tab: String = "") -> void:
	if tab != "":
		missions_tab = tab
	elif missions_tab == "":
		missions_tab = "daily" if GameState.starter_done() else "starter"
	_deselect()
	hud.hide_panel()
	open_sheet = "missions"
	var content := MissionsUI.window(missions_tab, func(t: String) -> void: _open_missions(t), _claim_mission, _go_mission)
	hud.show_modal(content, Vector2(1120, 620))


func _claim_mission(kind: String, id: Variant) -> void:
	var before := [GameState.coins, GameState.fuel, GameState.gems]
	var ok := false
	match kind:
		"starter":
			ok = GameState.claim_starter(int(id))
		"daily":
			ok = GameState.claim_daily(str(id))
		"login":
			ok = GameState.claim_login()
	if not ok:
		return
	Audio.play("star")
	var parts := []
	for i in 3:
		var got: int = [GameState.coins, GameState.fuel, GameState.gems][i] - int(before[i])
		if got > 0:
			parts.append([I18n.t("+%d coins"), I18n.t("+%d fuel"), I18n.t("+%d gems")][i] % got)
	if not parts.is_empty():
		hud.toast("  ".join(parts))
	_refresh_header()
	_open_missions()


## "Go" on a mission: closes the window and opens the place where it gets done.
func _go_mission(check: Array) -> void:
	hud.hide_modal()
	match str(check[0]):
		"hq":
			_open_cell(_cell_of("hq"))
		"level":
			var cell := _cell_of(check[1])
			if cell.is_empty():
				_open_shop(_shop_tab_of(check[1]))
			else:
				_open_cell(cell)
		"count":
			_open_shop(_shop_tab_of(check[1]))
		"walls":
			_open_shop("walls")
		"unit":
			_open_lab(Catalog.unit_lab(check[1]))
		"mission", "stars":
			get_tree().change_scene_to_file("res://scenes/syndicate/map.tscn")
		"stat":
			var key: String = check[1]
			if key.begins_with("train"):
				_open_army()
			elif key in ["raid_win", "win", "three_stars"]:
				_open_attack_choice()
			elif key == "build":
				_open_shop()
			elif key == "upgrade":
				hud.toast(I18n.t("Tap a building, then Upgrade"))
			else:
				hud.toast(I18n.t("Tap the coins and drops over your generators and pumps"))


## The cell of the highest-level structure of `type`, or [].
func _cell_of(type: String) -> Array:
	var best := {}
	for s in GameState.structures:
		if s["type"] == type and (best.is_empty() or int(s["level"]) > int(best["level"])):
			best = s
	return best.get("cell", [])


static func _shop_tab_of(type: String) -> String:
	for tab in Catalog.SHOP_TABS:
		if Catalog.SHOP_TABS[tab].has(type):
			return tab
	return ""


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


func _start_placing(type: String) -> void:
	placing = type
	GameState.tutorial_event("place_" + type)
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
	var music := HomeHud.make_button(grid, I18n.t("Music on") if GameState.music_on else I18n.t("Music off"), 24, 80)
	music.pressed.connect(func() -> void:
		GameState.set_music(not GameState.music_on)
		Audio.refresh_music()
		music.text = I18n.t("Music on") if GameState.music_on else I18n.t("Music off"))
	HomeHud.make_button(grid, I18n.t("Practice on my base"), 24, 80).pressed.connect(func() -> void: _go_raid("self"))
	var account := I18n.t("Account: %s") % Cloud.commander if Cloud.signed_in() else I18n.t("Save my base")
	HomeHud.make_button(grid, account, 24, 80).pressed.connect(_open_account_settings)
	HomeHud.make_button(grid, I18n.t("Replay tutorial"), 24, 80).pressed.connect(func() -> void:
		hud.hide_panel()
		GameState.replay_tutorial()
		Tutorial.attach(self))
	if GameState.dev_tools_available():
		var dev := HomeHud.make_button(grid, I18n.t("DEV: free ON") if GameState.infinite_coins else I18n.t("DEV: free OFF"), 24, 80)
		dev.add_theme_color_override("font_color", GOOD if GameState.infinite_coins else SOFT)
		dev.pressed.connect(_toggle_infinite)
	hud.show_content(I18n.t("Settings"), box)


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

## The Army window (Shop style): space, the training queue and a picture card per unit with
## its price; "!" opens what the unit does. Opens from the Army button, the Training Camp and
## the Quarters.
func _open_army() -> void:
	open_cell = []
	open_sheet = "army"
	marker.visible = false
	_deselect()
	hud.hide_panel()
	var train := func(type: String) -> void:
		if GameState.train(type):
			Audio.play("click")
			_refresh_header()
			_open_army()
			GameState.tutorial_event("train")
		else:
			hud.toast(GameState.train_block_reason(type))
	var cancel := func(type: String) -> void:
		GameState.cancel_training(type)
		_refresh_header()
		_open_army()
	var speedup := func() -> void:
		if GameState.speed_up_training():
			Audio.play("build")
			_refresh_header()
			_open_army()
	army_box = ShopUI.army(train, cancel, _open_unit_info, speedup)
	hud.show_modal(army_box, Vector2(1180, 480))


## What a unit does and its numbers at its current level.
func _open_unit_info(type: String) -> void:
	var lvl := int(GameState.units.get(type, 1))
	var st := Catalog.unit_stats(type, lvl)
	var def := Catalog.unit_def(type)
	var rows := []
	if Catalog.is_ground(type) and int(def.get("squad", 1)) > 1:
		rows.append([I18n.t("Per card"), I18n.t("%d soldiers") % int(def["squad"])])
	rows.append([I18n.t("Health"), str(int(st["health"]))])
	rows.append([I18n.t("Damage per second"), str(int(st["dps"]))])
	rows.append([I18n.t("Speed"), str(snappedf(float(st["speed"]), 0.1))])
	if st.has("range"):
		rows.append([I18n.t("Range"), str(snappedf(float(st["range"]), 0.1))])
	rows.append([I18n.t("Army space"), str(int(def["housing"]))])
	var targets := {"any": I18n.t("Whatever is closest"), "loot": I18n.t("Generators, silos and the Command Tower"),
		"defense": I18n.t("Defenses first"), "fence": I18n.t("Walls, then buildings")}
	rows.append([I18n.t("Targets"), targets.get(def.get("prefers", "any"), "")])
	var back := {"text": I18n.t("Back"), "call": _open_army}
	var title := Catalog.display_name(type) + "  ·  " + I18n.t("Lv %d") % lvl
	hud.show_modal(ShopUI.info_window(title, type, lvl, rows, I18n.t(def["role"]), [back]), Vector2(900, 520))


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
		GameState.tutorial_event("built_" + type)
		hud.toast(I18n.t("%s built") % Catalog.display_name(type))
		_rebuild()
		_open_cell(cell)


func _do_upgrade(cell: Array) -> void:
	if GameState.upgrade(cell):
		Audio.play("build")
		if GameState.structure_at(cell)["type"] == "hq":
			GameState.tutorial_event("upgrade_hq")
		hud.toast(I18n.t("Upgrade started"))
		_rebuild()
		_open_cell(cell)


func _do_speed_up(cell: Array) -> void:
	if GameState.speed_up(cell):
		Audio.play("build")
		hud.toast(I18n.t("Done!"))
		_rebuild()
		_open_cell(cell)
		GameState.tutorial_event("speed_up")


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
		_deselect()


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


## Attack opens a choice: the Syndicate campaign map, or a raid on the next enemy base.
func _open_attack_choice() -> void:
	_deselect()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var target := Bases.enemy(GameState.enemy_index, GameState.hq_level())
	var to_map := func() -> void:
		hud.hide_modal()
		get_tree().change_scene_to_file("res://scenes/syndicate/map.tscn")
	var to_raid := func() -> void:
		hud.hide_modal()
		_go_raid("enemy")
	var choices := [
		["syndicate", I18n.t("Iron Fang campaign"), I18n.t("Stars %d / %d") % [GameState.syndicate_total_stars(), Syndicate.COUNT * 3], to_map],
		["swords", I18n.t("Raid a base"), target["name"], to_raid],
	]
	for c: Array in choices:
		var b := Button.new()
		b.text = "%s\n%s" % [c[1], c[2]]
		b.icon = Icons.tex(c[0], 160)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(300, 260)
		if c[0] == "syndicate":
			Tutorial.tag(b, "attack_syndicate")
		b.add_theme_font_size_override("font_size", 24)
		HomeHud._style_button(b, Color(0.32, 0.22, 0.45) if c[0] == "syndicate" else Color(0.82, 0.32, 0.2), 16, Color.WHITE, 4)
		b.pressed.connect(func() -> void: Audio.play("click", -6.0))
		b.pressed.connect(c[3])
		row.add_child(b)
	hud.show_modal(row, Vector2(720, 330))


func _go_raid(target: String) -> void:
	if GameState.army_used() <= 0:
		hud.toast(I18n.t("Train an army first"))
		_open_army()
		return
	GameState.raid_target = target
	get_tree().change_scene_to_file(RAID_SCENE)
