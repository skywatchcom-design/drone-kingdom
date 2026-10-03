extends Node3D
## The player's base. Tap a pad to build or upgrade (or press Build, pick, then tap a free pad),
## tap a floating coin or fuel drop to collect, set up the attack army in the Hangar, then
## Attack. Settings holds language, sound, practice on your own base and dev tools.
## Run with `-- --screenshot-panel` / `--screenshot-hq` / `--screenshot-hangar` /
## `--screenshot-settings` to open a sheet on start.

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
## Structure type picked from the Build menu, waiting for a free pad to be tapped.
var placing := ""
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
	hud.hangar_pressed.connect(_open_hangar)
	hud.build_pressed.connect(func() -> void: _open_build([]))
	hud.settings_pressed.connect(_open_settings)
	hud.workers_pressed.connect(_open_workers)
	hud.gems_pressed.connect(func() -> void: hud.toast(I18n.t("The gem shop is coming soon")))
	GameState.finish_ready()
	_rebuild()
	var args := OS.get_cmdline_user_args()
	if args.has("--screenshot-panel"):
		_open_cell([1, 3])
	elif args.has("--screenshot-hq"):
		_open_cell([4, 4])
	elif args.has("--screenshot-hangar"):
		_open_hangar()
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
	_update_timers()
	_refresh_header()
	if not open_cell.is_empty() and GameState.is_busy(GameState.structure_at(open_cell)):
		_open_cell(open_cell)


func _refresh_header() -> void:
	var target := Bases.enemy(GameState.enemy_index, GameState.hq_level())
	hud.set_header(GameState.hq_level(), target["name"], GameState.infinite_coins)
	for bubble in coins:
		if bubble.scale.x > 0.99:
			bubble.set_amount(GameState.generator_pending(GameState.structure_at(bubble.cell)))


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
	if _try_collect(touch.position):
		return
	var cell := _pick_cell(touch.position)
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
	marker.visible = true
	marker.position = city.roof_top(cell) + Vector3(0, 0.5, 0)
	var s := GameState.structure_at(cell)
	if s.is_empty():
		hud.show_content(I18n.t("Build here"), _build_menu(cell))
	else:
		var title := "%s  ·  %s" % [Catalog.display_name(s["type"]), I18n.t("Lv %d") % int(s["level"])]
		hud.show_content(title, _structure_sheet(cell, s))


func _build_menu(cell: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for option in Catalog.BUILD_ORDER:
		var why := GameState.build_block_reason(option)
		var card := _card(why == "")
		box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		HomeHud.make_label(info, Catalog.display_name(option), 28, Color.WHITE if why == "" else Color(0.65, 0.67, 0.7))
		_wrap(HomeHud.make_label(info, I18n.t(Catalog.INFO[option]), 20, SOFT))
		if why != "":
			_wrap(HomeHud.make_label(info, why, 20, BAD))
		var b := HomeHud.make_button(row, I18n.t("Build  ·  %d\n%s") % [Catalog.build_cost(option), HomeHud.clock(Catalog.build_seconds(option, 1))], 22, 80)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size.x = 200
		b.disabled = why != ""
		_gold(b, why == "")
		b.pressed.connect(func() -> void:
			if cell.is_empty():
				_start_placing(option)
			else:
				_do_build(option, cell))
	return box


## The Build button: pick something, then tap a free pad for it.
func _open_build(cell: Array) -> void:
	open_cell = []
	marker.visible = false
	hud.show_content(I18n.t("Build"), _build_menu(cell))


func _start_placing(type: String) -> void:
	placing = type
	hud.hide_panel()
	hud.toast(I18n.t("Tap a free pad for the %s") % Catalog.display_name(type))


func _open_settings() -> void:
	open_cell = []
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
	if type == "hangar":
		HomeHud.make_button(extra, I18n.t("Open hangar"), 22, 72).pressed.connect(_open_hangar)
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
			return [[I18n.t("Army space"), str(Catalog.army_capacity(lvl))], [I18n.t("Drone max level"), str(lvl)]]
	var st := Catalog.defense_stats(type, lvl)
	var lines := [[I18n.t("Range"), I18n.t("%.1f m") % st["radius"]]]
	match type:
		"laser":
			lines.append([I18n.t("Damage per second"), str(int(st["dps"]))])
		"net":
			lines.append([I18n.t("Reload"), I18n.t("%.1f s") % st["cooldown"]])
		"birds":
			lines.append([I18n.t("Gulls"), str(int(st["count"]))])
			lines.append([I18n.t("Damage per bump"), str(int(st["damage"]))])
	return lines


## What the next Command Tower level allows that this one doesn't, e.g. "Net Launcher +1".
func _hq_unlocks(lvl: int) -> String:
	var parts := []
	for type in Catalog.LIMITS:
		var more := Catalog.max_count(type, lvl + 1) - Catalog.max_count(type, lvl)
		if more > 0:
			parts.append("%s +%d" % [Catalog.display_name(type), more])
	return ", ".join(parts)


# ---------------------------------------------------------------- hangar

func _open_hangar() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	var cap := GameState.army_capacity()
	var used := GameState.army_used()
	HomeHud.make_label(content, I18n.t("Next attack army: %d / %d space") % [used, cap], 28, GOLD)
	_wrap(HomeHud.make_label(content, I18n.t("Pick how many of each drone you take into battle. Bigger drones take more space. Upgrade the Hangar for more space."), 21, SOFT))
	for type in Catalog.DRONE_ORDER:
		content.add_child(_drone_card(type))
	hud.show_content(I18n.t("Drone Hangar"), content)


func _drone_card(type: String) -> Control:
	var def: Dictionary = Catalog.DRONES[type]
	var owned: bool = GameState.drones.has(type)
	var lvl := int(GameState.drones.get(type, 1))
	var st := Catalog.drone_stats(type, lvl)
	var top := Catalog.drone_stats("heavy", Catalog.MAX_LEVEL)

	var card := _card(owned)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_drone_preview(type, st, owned))

	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := HomeHud.make_label(head, Catalog.display_name(type), 32, def["color"] if owned else Color(0.6, 0.62, 0.66))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HomeHud.make_label(head, I18n.t("Lv %d") % lvl if owned else I18n.t("Locked"), 26, SOFT)
	_wrap(HomeHud.make_label(box, I18n.t(def["role"]), 21, SOFT))

	HomeHud.stat_bar(box, I18n.t("Health %d") % int(st["health"]), st["health"], 700.0, Color(0.35, 0.85, 0.45))
	HomeHud.stat_bar(box, I18n.t("Speed %.1f") % st["speed"], st["speed"], 14.0, Color(0.35, 0.75, 1.0))
	HomeHud.stat_bar(box, I18n.t("Damage %d/s") % int(st["dps"]), st["dps"], float(top["dps"]), Color(1.0, 0.55, 0.3))
	HomeHud.make_label(box, I18n.t("Takes %d space") % int(def["housing"]), 21, SOFT)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var reason := GameState.drone_block_reason(type)
	if owned:
		var count := int(GameState.army.get(type, 0))
		var minus := HomeHud.make_button(row, "-", 34, 76)
		minus.custom_minimum_size.x = 76
		minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		minus.disabled = count <= 0
		minus.pressed.connect(func() -> void: _set_army(type, count - 1))
		var in_army := HomeHud.make_label(row, I18n.t("In army: %d") % count, 26)
		in_army.custom_minimum_size.x = 170
		in_army.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		in_army.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		in_army.size_flags_vertical = Control.SIZE_FILL
		var plus := HomeHud.make_button(row, "+", 34, 76)
		plus.custom_minimum_size.x = 76
		plus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		plus.disabled = GameState.army_used() + int(def["housing"]) > GameState.army_capacity()
		plus.pressed.connect(func() -> void: _set_army(type, count + 1))
		var up_text := I18n.t("Max level")
		if lvl < Catalog.MAX_LEVEL:
			up_text = I18n.t("Upgrade  ·  %d fuel") % Catalog.drone_upgrade_cost(type, lvl)
		var up := HomeHud.make_button(row, up_text, 20, 76)
		up.disabled = reason != ""
		_gold(up, reason == "")
		up.pressed.connect(func() -> void: _do_drone(type))
	else:
		var unlock := HomeHud.make_button(row, I18n.t("Unlock  ·  %d fuel") % int(def["unlock"]), 22, 76)
		unlock.disabled = reason != ""
		_gold(unlock, reason == "")
		unlock.pressed.connect(func() -> void: _do_drone(type))
	if reason != "" and not (owned and lvl >= Catalog.MAX_LEVEL):
		_wrap(HomeHud.make_label(box, reason, 21, BAD))
	return card


## A small 3D stage with the drone hovering on a turntable and looping its signature move.
## Every preview uses the same camera distance, so the size difference between drones is real.
func _drone_preview(type: String, stats: Dictionary, owned: bool) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(0, 230)
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
	MeshKit.add(stage, MeshKit.cyl(3.4, 3.4, 0.05, 48), MeshKit.mat(Color(0.12, 0.14, 0.17), 0.95))
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
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


func _do_drone(type: String) -> void:
	if GameState.upgrade_drone(type):
		Audio.play("build")
		hud.toast(I18n.t("%s Lv %d") % [Catalog.display_name(type), int(GameState.drones[type])])
		_refresh_header()
		_open_hangar()


## Switches every text in the game between Hebrew and English; the scene reloads to redraw.
func _toggle_language() -> void:
	GameState.set_language("en" if I18n.rtl() else "he")
	get_tree().reload_current_scene()


func _toggle_infinite() -> void:
	GameState.set_infinite_coins(not GameState.infinite_coins)
	_refresh_header()
	_open_settings()


func _set_army(type: String, count: int) -> void:
	GameState.set_army_count(type, count)
	_open_hangar()


func _go_raid(target: String) -> void:
	if GameState.army_used() <= 0:
		hud.toast(I18n.t("Add drones to your army in the Hangar first"))
		_open_hangar()
		return
	GameState.raid_target = target
	get_tree().change_scene_to_file(RAID_SCENE)
