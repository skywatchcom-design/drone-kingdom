extends Node3D
## The player's rooftop base. Tap a roof to build or upgrade, tap a floating coin to collect
## from a generator, set up the attack army in the Hangar, then Attack (or Test your own base).
## Run with `-- --screenshot-panel` / `--screenshot-hq` / `--screenshot-hangar` to open a sheet on start.

const RAID_SCENE := "res://scenes/raid/raid.tscn"
const VIEW_SIZE := 56.0
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
var marker: MeshInstance3D
var press_pos := Vector2.ZERO
var header_timer := 0.0
var focus := Vector3(0, 10, 0)


func _ready() -> void:
	Engine.time_scale = 1.0
	cam = WorldSetup.create(self, VIEW_SIZE)
	hud = HomeHud.new()
	add_child(hud)
	hud.attack_pressed.connect(func() -> void: _go_raid("enemy"))
	hud.test_pressed.connect(func() -> void: _go_raid("self"))
	hud.hangar_pressed.connect(_open_hangar)
	hud.language_pressed.connect(_toggle_language)
	hud.dev_coins_pressed.connect(_toggle_infinite)
	hud.set_dev(GameState.dev_tools_available(), GameState.infinite_coins)
	_rebuild()
	var args := OS.get_cmdline_user_args()
	if args.has("--screenshot-panel"):
		_open_cell([1, 3])
	elif args.has("--screenshot-hq"):
		_open_cell([3, 3])
	elif args.has("--screenshot-hangar"):
		_open_hangar()


func _rebuild() -> void:
	if level != null:
		level.queue_free()
	level = Node3D.new()
	add_child(level)
	defenses.clear()
	coins.clear()
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
		defense.setup(Catalog.defense_stats(type, lvl), city.roof_y(s["cell"]))
		defenses.append(defense)
		return
	StructureModels.build(level, type, lvl, city.roof_top(s["cell"]))
	if type == "generator":
		var bubble := CoinBubble.new()
		bubble.cell = s["cell"]
		bubble.position = city.roof_top(s["cell"]) + Vector3(0, 4.2, 0)
		level.add_child(bubble)
		coins.append(bubble)


func _process(delta: float) -> void:
	for defense in defenses:
		defense.tick(delta, [])
	header_timer -= delta
	if header_timer <= 0.0:
		header_timer = 1.0
		_refresh_header()


func _refresh_header() -> void:
	var target := Bases.enemy(GameState.enemy_index, GameState.hq_level())
	hud.set_header(GameState.hq_level(), GameState.coins, GameState.coin_cap(), target["name"], GameState.infinite_coins)
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
	if cell.is_empty():
		hud.hide_panel()
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
			hud.toast(I18n.t("+%d coins") % got)
			bubble.pop()
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


# ---------------------------------------------------------------- build menu

func _open_cell(cell: Array) -> void:
	marker.visible = true
	marker.position = city.roof_top(cell) + Vector3(0, 0.5, 0)
	var s := GameState.structure_at(cell)
	if s.is_empty():
		hud.show_content(I18n.t("Empty roof"), _build_menu(cell))
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
		var b := HomeHud.make_button(row, I18n.t("Build  ·  %d") % Catalog.build_cost(option), 22, 80)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size.x = 200
		b.disabled = why != ""
		_gold(b, why == "")
		b.pressed.connect(func() -> void: _do_build(option, cell))
	return box


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
	if maxed:
		HomeHud.make_label(box, I18n.t("Max level reached"), 26, GOLD)
	else:
		var up := HomeHud.make_button(box, I18n.t("Upgrade to Lv %d  ·  %d coins") % [lvl + 1, Catalog.upgrade_cost(type, lvl)], 28, 100)
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
	if type != "hq":
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
			up_text = I18n.t("Upgrade  ·  %d") % Catalog.drone_upgrade_cost(type, lvl)
		var up := HomeHud.make_button(row, up_text, 20, 76)
		up.disabled = reason != ""
		_gold(up, reason == "")
		up.pressed.connect(func() -> void: _do_drone(type))
	else:
		var unlock := HomeHud.make_button(row, I18n.t("Unlock  ·  %d") % int(def["unlock"]), 22, 76)
		unlock.disabled = reason != ""
		_gold(unlock, reason == "")
		unlock.pressed.connect(func() -> void: _do_drone(type))
	if reason != "" and not (owned and lvl >= Catalog.MAX_LEVEL):
		_wrap(HomeHud.make_label(box, reason, 21, BAD))
	return card


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
		hud.toast(I18n.t("%s built") % Catalog.display_name(type))
		_rebuild()
		_open_cell(cell)


func _do_upgrade(cell: Array) -> void:
	if GameState.upgrade(cell):
		hud.toast(I18n.t("Upgraded"))
		_rebuild()
		_open_cell(cell)


func _do_remove(cell: Array) -> void:
	if GameState.remove(cell):
		_rebuild()
		hud.hide_panel()


func _do_drone(type: String) -> void:
	if GameState.upgrade_drone(type):
		hud.toast(I18n.t("%s Lv %d") % [Catalog.display_name(type), int(GameState.drones[type])])
		_refresh_header()
		_open_hangar()


## Switches every text in the game between Hebrew and English; the scene reloads to redraw.
func _toggle_language() -> void:
	GameState.set_language("en" if I18n.rtl() else "he")
	get_tree().reload_current_scene()


func _toggle_infinite() -> void:
	GameState.set_infinite_coins(not GameState.infinite_coins)
	hud.set_dev(GameState.dev_tools_available(), GameState.infinite_coins)
	_refresh_header()
	hud.hide_panel()


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
