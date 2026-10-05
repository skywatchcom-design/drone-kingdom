class_name ShopUI
extends RefCounted
## The middle windows of the base screen (approved sketch 4WKjsEP2MoNrBQh5iGnwTF): the Shop
## with its tabs and picture cards, the upgrade window and the info window. Built as plain
## controls; HomeHud.show_modal() shows them on parchment over a dimmed screen.

const CARD_GREY := Color(0.85, 0.82, 0.75)
const CARD_LINE := Color(0.73, 0.69, 0.6)
const BAR_BG := Color(0.74, 0.72, 0.64)
const BAR_NOW := Color(0.85, 0.7, 0.24)
const BAR_ADD := Color(0.45, 0.78, 0.29)
const GOOD := Color(0.37, 0.68, 0.23)
const BAD := Color(0.75, 0.22, 0.14)

const TAB_NAMES := {"army": "Army", "resources": "Resources", "defenses": "Defenses", "walls": "Walls"}


## True if there is room to build one more of `type` (the Shop marks those with "!").
static func is_new(type: String) -> bool:
	if type == "wall":
		return false
	return GameState.count_of(type) < Catalog.max_count(type, GameState.hq_level())


static func new_count() -> int:
	var n := 0
	for tab in Catalog.SHOP_ORDER:
		for type in Catalog.SHOP_TABS[tab]:
			if is_new(type):
				n += 1
	return n


# ---------------------------------------------------------------- shop

## The Shop: a row of tabs, a horizontal strip of cards for the open tab, and the player's
## coins, fuel and gems along the bottom.
static func shop(tab: String, on_tab: Callable, on_buy: Callable, on_info: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	for t in Catalog.SHOP_ORDER:
		var b := Button.new()
		b.text = I18n.t(TAB_NAMES[t])
		b.custom_minimum_size = Vector2(150, 50)
		b.add_theme_font_size_override("font_size", 22)
		HomeHud._style_button(b, Color(0.4, 0.65, 0.24) if t == tab else Color(0.29, 0.32, 0.27), 10, Color(1, 1, 1, 0.6), 2)
		b.pressed.connect(func() -> void:
			Audio.play("click", -6.0)
			on_tab.call(t))
		tabs.add_child(b)
		var news := 0
		for type in Catalog.SHOP_TABS[t]:
			if is_new(type):
				news += 1
		if news > 0:
			var badge := HomeHud._corner_badge(b)
			badge.text = "!"
			badge.visible = true
	var title := HomeHud.make_label(box, I18n.t(TAB_NAMES[tab]), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	for type in Catalog.SHOP_TABS[tab]:
		row.add_child(_card(type, on_buy, on_info))
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", HomeHud._box(Color(0.38, 0.62, 0.22), 10))
	box.add_child(foot)
	var money := HBoxContainer.new()
	money.alignment = BoxContainer.ALIGNMENT_CENTER
	money.add_theme_constant_override("separation", 30)
	foot.add_child(money)
	for pair in [["coin", GameState.coins], ["fuel", GameState.fuel], ["gem", GameState.gems]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		money.add_child(r)
		HomeHud.make_label(r, "∞" if GameState.infinite_coins else HomeHud._thousands(int(pair[1])), 22)
		r.add_child(Icons.rect(pair[0], 28))
	return box


static func _card(type: String, on_buy: Callable, on_info: Callable) -> Control:
	var wall := type == "wall"
	var why := GameState.wall_block_reason() if wall else GameState.build_block_reason(type)
	var locked := not wall and Catalog.max_count(type, GameState.hq_level()) == 0
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(206, 0)
	card.add_theme_stylebox_override("panel", HomeHud._box(CARD_GREY, 12, CARD_LINE, 3))
	if locked:
		card.modulate = Color(0.75, 0.75, 0.75, 0.85)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := HomeHud.make_label(head, Catalog.display_name(type), 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	var i := Button.new()
	i.icon = Icons.tex("info", 48)
	i.expand_icon = true
	i.custom_minimum_size = Vector2(32, 32)
	i.flat = true
	i.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		on_info.call(type))
	head.add_child(i)
	var pic_holder := Control.new()
	pic_holder.custom_minimum_size = Vector2(0, 175)
	box.add_child(pic_holder)
	var pic := picture(type, 1)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic_holder.add_child(pic)
	if is_new(type) and why == "":
		var badge := HomeHud._corner_badge(pic_holder)
		badge.text = "!"
		badge.visible = true
	var line := HomeHud.ink(box, I18n.t(Catalog.SHORT[type]), 15, Color(0.3, 0.29, 0.24))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.y = 40
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 4)
	box.add_child(meta)
	meta.add_child(Icons.rect("clock", 20))
	var time_label := HomeHud.ink(meta, I18n.t("Instant") if wall else HomeHud.clock(Catalog.build_seconds(type, 1)), 16)
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var built := GameState.walls.size() if wall else GameState.count_of(type)
	var limit := Catalog.wall_limit(GameState.hq_level()) if wall else Catalog.max_count(type, GameState.hq_level())
	HomeHud.ink(meta, I18n.t("Built %d/%d") % [built, limit], 16)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 46)
	buy.add_theme_font_size_override("font_size", 20)
	if why == "":
		buy.text = HomeHud._thousands(Catalog.WALL_COST if wall else Catalog.build_cost(type))
		buy.icon = Icons.tex("coin", 48)
		buy.expand_icon = false
		buy.add_theme_constant_override("icon_max_width", 26)
		HomeHud._style_button(buy, Color(0.25, 0.29, 0.24), 8)
	else:
		buy.text = why
		buy.add_theme_font_size_override("font_size", 14)
		buy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buy.disabled = true
		HomeHud._style_button(buy, Color(0.42, 0.42, 0.4), 8)
		buy.add_theme_color_override("font_disabled_color", Color(1.0, 0.86, 0.8))
	buy.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		on_buy.call(type))
	box.add_child(buy)
	return card


# ---------------------------------------------------------------- upgrade and info

## The upgrade window: the structure at its next level on one side, and bars for each stat
## on the other (gold for now, green for what the upgrade adds). Under them what the upgrade
## unlocks, then the time, the worker and a confirm button with the price, or why it can't.
## Each row: [icon, label, now, next, max].
static func upgrade_window(title: String, type: String, next_level: int, rows: Array, extra: String,
		time_text: String, cost: int, cost_icon: String, reason: String, on_confirm: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var t := HomeHud.make_label(box, title, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 18)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(mid)
	var pic := picture(type, next_level)
	pic.custom_minimum_size = Vector2(340, 250)
	mid.add_child(pic)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(stats)
	for r: Array in rows:
		stats.add_child(_stat_bar(r[0], r[1], float(r[2]), float(r[3]), float(r[4])))
	if extra != "":
		var note := HomeHud.ink(stats, extra, 17, Color(0.36, 0.29, 0.1))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_stylebox_override("normal", HomeHud._box(Color(0.96, 0.9, 0.7), 6))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	box.add_child(foot)
	foot.add_child(Icons.rect("clock", 34))
	HomeHud.ink(foot, time_text, 22)
	if time_text != "":
		foot.add_child(Icons.rect("worker", 30))
		HomeHud.ink(foot, I18n.t("1 worker"), 20)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	if reason != "":
		var why := HomeHud.ink(foot, reason, 20, BAD)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = 260
	var go := Button.new()
	go.text = HomeHud._thousands(cost)
	go.icon = Icons.tex(cost_icon, 64)
	go.add_theme_constant_override("icon_max_width", 34)
	go.custom_minimum_size = Vector2(200, 64)
	go.add_theme_font_size_override("font_size", 28)
	go.disabled = reason != ""
	HomeHud._style_button(go, GOOD, 12, Color.WHITE, 3)
	go.pressed.connect(func() -> void: Audio.play("click", -6.0))
	go.pressed.connect(on_confirm)
	foot.add_child(go)
	return box


static func _stat_bar(icon: String, label: String, now: float, next: float, top: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(Icons.rect(icon, 34))
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 34)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("panel", HomeHud._box(BAR_BG, 8, Color(0.56, 0.53, 0.45), 2))
	row.add_child(bar)
	var top_v := maxf(top, maxf(next, 0.001))
	var add := ColorRect.new()
	add.color = BAR_ADD
	add.anchor_bottom = 1.0
	add.anchor_right = clampf(next / top_v, 0.0, 1.0)
	add.offset_top = 3
	add.offset_bottom = -3
	add.offset_left = 3
	bar.add_child(add)
	var fill := ColorRect.new()
	fill.color = BAR_NOW
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(now / top_v, 0.0, 1.0)
	fill.offset_top = 3
	fill.offset_bottom = -3
	fill.offset_left = 3
	bar.add_child(fill)
	var text := "%s: %s" % [label, _num(now)]
	if next > now + 0.001:
		text += "  +" + _num(next - now)
	var l := HomeHud.make_label(bar, text, 18)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 10
	l.offset_right = -10
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row


static func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return HomeHud._thousands(roundi(v))
	return "%.1f" % v


## The info window: the structure at its level, its numbers, what it is for, and any extra
## buttons (each {text, call}).
static func info_window(title: String, type: String, level: int, rows: Array, description: String, buttons: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var t := HomeHud.make_label(box, title, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 18)
	box.add_child(mid)
	var pic := picture(type, level)
	pic.custom_minimum_size = Vector2(300, 220)
	mid.add_child(pic)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(grid)
	for r: Array in rows:
		HomeHud.ink(grid, r[0], 20, Color(0.38, 0.37, 0.31))
		HomeHud.ink(grid, r[1], 22)
	var d := HomeHud.ink(box, description, 18, Color(0.24, 0.23, 0.19))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not buttons.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		for b: Dictionary in buttons:
			var btn := Button.new()
			btn.text = b["text"]
			btn.custom_minimum_size = Vector2(220, 52)
			btn.add_theme_font_size_override("font_size", 20)
			HomeHud._style_button(btn, Color(0.42, 0.44, 0.4), 10, Color.WHITE, 2)
			btn.pressed.connect(b["call"])
			row.add_child(btn)
	return box


# ---------------------------------------------------------------- pictures

## A picture of a structure (or wall) at a level, rendered once into a small 3D stage.
## A small 3D picture of a structure, wall or unit at `level`. Units stand alone on a
## plain background of color `bg` (the battle cards); structures stand on their pad.
static func picture(type: String, level: int, bg: Color = Color(0.45, 0.58, 0.33)) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	frame.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
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
	var unit := Catalog.GROUND.has(type) or Catalog.DRONES.has(type)
	if not unit:
		MeshKit.add(stage, MeshKit.box(Vector3(5.4, 0.12, 5.4)), MeshKit.mat(Color(0.6, 0.67, 0.48), 0.9), Vector3(0, 0.06, 0))
	var look := Vector3(0, 1.1, 0)
	var eye := Vector3(5.6, 6.4, 7.4)
	if Catalog.GROUND.has(type):
		var g := GroundUnit.new()
		g.configure(Catalog.unit_stats(type, level))
		g.showcase = true
		g.rotation.y = 0.45 if type != "armor" else -0.6
		stage.add_child(g)
		var tank := type == "armor"
		look = Vector3(0, 0.9 if tank else 1.45, 0)
		eye = Vector3(2.6, 3.0, 5.4) * (1.55 if tank else 0.75) * (0.85 + 0.05 * level)
	elif Catalog.DRONES.has(type):
		var d := Drone.new()
		d.configure(Catalog.unit_stats(type, level))
		d.showcase = true
		d.rotation.y = 0.6
		stage.add_child(d)
		look = Vector3(0, 0, 0)
		eye = Vector3(2.4, 2.6, 4.2) * (1.5 if type == "heavy" else 1.05) * (0.85 + 0.08 * level)
	elif type == "wall":
		StructureModels.wall(stage, [0, 0, 1], level).position = Vector3.ZERO
	elif Catalog.is_defense(type):
		var d := Catalog.make_defense(type)
		stage.add_child(d)
		d.setup(Catalog.defense_stats(type, level), 0.12)
		d.show_range(false)
	else:
		StructureModels.build(stage, type, level, Vector3(0, 0.12, 0))
	for label in stage.find_children("*", "Label3D", true, false):
		(label as Node3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	var far := 1.25 if type == "hq" else 1.0
	cam.look_at_from_position(eye * far, look)
	return frame
