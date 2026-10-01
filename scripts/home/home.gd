extends Node3D
## The player's rooftop base. Tap a roof to build or upgrade, tap a floating coin to collect
## from a generator, set up the attack army in the Hangar, then Attack (or Test your own base).
## Run with `-- --screenshot-panel` / `--screenshot-hangar` to open a sheet on start.

const RAID_SCENE := "res://scenes/raid/raid.tscn"
const VIEW_SIZE := 56.0
const TAP_SLOP := 24.0
const PICK_RADIUS := 90.0
const COIN_PICK_RADIUS := 70.0
const PAN_LIMIT := 30.0

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
	hud.set_header(GameState.hq_level(), GameState.coins, GameState.coin_cap(), target["name"])
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
			hud.toast("+%d coins" % got)
			bubble.pop()
		else:
			hud.toast("Coin silos are full. Build or upgrade a Coin Silo.")
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


# ---------------------------------------------------------------- build / upgrade sheet

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
	var hp := int(Catalog.structure_hp(type, lvl))
	match type:
		"hq":
			return "Everything else can be upgraded up to this level. Higher levels unlock more buildings. Destroying it earns attackers a star. Health %d." % hp
		"generator":
			return "Makes %d coins per minute. Tap the gold coin above it to collect. Health %d." % [int(Catalog.generator_rate(lvl)), hp]
		"storage":
			return "Raises your coin cap by %d. Attackers loot it. Health %d." % [700 * lvl, hp]
		"hangar":
			return "Holds %d space of attack drones and lets them be upgraded up to Lv %d." % [Catalog.army_capacity(lvl), lvl]
		"laser":
			var st := Catalog.defense_stats(type, lvl)
			return "Turns toward the nearest drone and burns it: %d damage per second, range %.1f m. Health %d." % [int(st["dps"]), st["radius"], hp]
		"net":
			var st := Catalog.defense_stats(type, lvl)
			return "Fires a net that slows a drone to a crawl. Range %.1f m, reload %.1f s. Health %d." % [st["radius"], st["cooldown"], hp]
		"jammer":
			var st := Catalog.defense_stats(type, lvl)
			return "Drones inside %.1f m lose their bearings, drift and slow down. Health %d." % [st["radius"], hp]
		"birds":
			var st := Catalog.defense_stats(type, lvl)
			return "%d gulls circle the nest, %d damage per bump. Health %d." % [int(st["count"]), int(st["damage"]), hp]
	return ""


# ---------------------------------------------------------------- hangar

func _open_hangar() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	var cap := GameState.army_capacity()
	var used := GameState.army_used()
	HomeHud.make_label(content, "Next attack army: %d / %d space" % [used, cap], 28, Color(1.0, 0.85, 0.35))
	var hint := HomeHud.make_label(content, "Pick how many of each drone you take into battle. Bigger drones take more space. Upgrade the Hangar for more space.", 21, Color(0.8, 0.84, 0.9))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for type in Catalog.DRONE_ORDER:
		content.add_child(_drone_card(type))
	hud.show_content("Drone Hangar", content)


func _drone_card(type: String) -> Control:
	var def: Dictionary = Catalog.DRONES[type]
	var owned: bool = GameState.drones.has(type)
	var lvl := int(GameState.drones.get(type, 1))
	var st := Catalog.drone_stats(type, lvl)
	var top := Catalog.drone_stats("heavy", Catalog.MAX_LEVEL)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HomeHud.flat(Color(1, 1, 1, 0.06) if owned else Color(1, 1, 1, 0.025)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := HomeHud.make_label(head, def["name"], 32, def["color"] if owned else Color(0.6, 0.62, 0.66))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HomeHud.make_label(head, "Lv %d" % lvl if owned else "Locked", 26, Color(0.85, 0.88, 0.92))
	var role := HomeHud.make_label(box, def["role"], 21, Color(0.8, 0.84, 0.9))
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	HomeHud.stat_bar(box, "Health %d" % int(st["health"]), st["health"], 700.0, Color(0.35, 0.85, 0.45))
	HomeHud.stat_bar(box, "Speed %.1f" % st["speed"], st["speed"], 14.0, Color(0.35, 0.75, 1.0))
	HomeHud.stat_bar(box, "Damage %d/s" % int(st["dps"]), st["dps"], float(top["dps"]), Color(1.0, 0.55, 0.3))
	HomeHud.make_label(box, "Takes %d space" % int(def["housing"]), 21, Color(0.8, 0.84, 0.9))

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
		var in_army := HomeHud.make_label(row, "In army: %d" % count, 26)
		in_army.custom_minimum_size.x = 170
		in_army.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		in_army.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		in_army.size_flags_vertical = Control.SIZE_FILL
		var plus := HomeHud.make_button(row, "+", 34, 76)
		plus.custom_minimum_size.x = 76
		plus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		plus.disabled = GameState.army_used() + int(def["housing"]) > GameState.army_capacity()
		plus.pressed.connect(func() -> void: _set_army(type, count + 1))
		var up_text := "Max level"
		if lvl < Catalog.MAX_LEVEL:
			up_text = "Upgrade  ·  %d" % Catalog.drone_upgrade_cost(type, lvl)
			if reason != "":
				up_text += "\n" + reason
		var up := HomeHud.make_button(row, up_text, 20, 76)
		up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		up.disabled = reason != ""
		up.pressed.connect(func() -> void: _do_drone(type))
	else:
		var unlock_text := "Unlock  ·  %d" % int(def["unlock"])
		if reason != "":
			unlock_text += "\n" + reason
		var unlock := HomeHud.make_button(row, unlock_text, 22, 76)
		unlock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unlock.disabled = reason != ""
		unlock.pressed.connect(func() -> void: _do_drone(type))
	return card


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


func _set_army(type: String, count: int) -> void:
	GameState.set_army_count(type, count)
	_open_hangar()


func _go_raid(target: String) -> void:
	if GameState.army_used() <= 0:
		hud.toast("Add drones to your army in the Hangar first")
		_open_hangar()
		return
	GameState.raid_target = target
	get_tree().change_scene_to_file(RAID_SCENE)
