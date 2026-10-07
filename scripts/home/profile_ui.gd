class_name ProfileUI
extends RefCounted
## The commander's profile, opened by tapping the badge or the name (owner, 7.10.2026), in the
## parchment style: the name and Command Tower level on top, the battle and building record on
## one side, and every structure kind and unit with its level on the other.

const MUTED := Color(0.42, 0.4, 0.33)
const CARD := Color(0.85, 0.82, 0.75)
const LINE := Color(0.73, 0.69, 0.6)


static func window(on_account: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(76, 76)
	badge.add_theme_stylebox_override("panel", HomeHud._box(Color(0.2, 0.42, 0.85), 14, Color(0.8, 0.88, 1.0), 3))
	head.add_child(badge)
	var lvl := HomeHud.make_label(badge, str(GameState.hq_level()), 38)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	head.add_child(words)
	HomeHud.ink(words, Cloud.commander if Cloud.signed_in() else I18n.t("Commander"), 34)
	HomeHud.ink(words, I18n.t("Command Tower Lv %d") % GameState.hq_level() + ("" if Cloud.signed_in() else "  ·  " + I18n.t("Not saved yet")), 19, MUTED)
	var acc := Button.new()
	acc.text = I18n.t("Account settings")
	acc.add_theme_font_size_override("font_size", 18)
	acc.custom_minimum_size = Vector2(0, 46)
	HomeHud._style_button(acc, Color(0.43, 0.48, 0.35), 10, Color(1, 1, 1, 0.6), 2)
	acc.pressed.connect(func() -> void: Audio.play("click", -6.0))
	acc.pressed.connect(on_account)
	head.add_child(acc)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	split.add_child(_record())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.7
	split.add_child(right)
	HomeHud.ink(right, I18n.t("Army"), 22)
	right.add_child(_grid(Catalog.UNIT_ORDER, func(t: String) -> int: return int(GameState.units.get(t, 0)), 6))
	HomeHud.ink(right, I18n.t("Buildings"), 22)
	var kinds: Array = ["hq"]
	for tab in Catalog.SHOP_ORDER:
		for t in Catalog.SHOP_TABS[tab]:
			if t != "wall" and GameState.count_of(t) > 0:
				kinds.append(t)
	right.add_child(_grid(kinds, func(t: String) -> int: return _best_level(t), 8))
	return box


## Name/number rows: campaign stars, battles, missions and the running totals.
static func _record() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(330, 0)
	card.add_theme_stylebox_override("panel", HomeHud._box(CARD, 12, LINE, 2))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	HomeHud.ink(col, I18n.t("Record"), 22)
	var s := GameState.stats
	var rows := [
		["star", I18n.t("Iron Fang stars"), "%d / %d" % [GameState.syndicate_total_stars(), Syndicate.COUNT * 3]],
		["swords", I18n.t("Battles won"), str(int(s.get("win", 0)))],
		["star", I18n.t("3-star wins"), str(int(s.get("three_stars", 0)))],
		["swords", I18n.t("Raids won"), str(int(s.get("raid_win", 0)))],
		["tasks", I18n.t("Starter missions"), "%d / %d" % [GameState.starter_claimed.size(), Missions.STARTER.size()]],
		["train", I18n.t("Units trained"), HomeHud._thousands(int(s.get("train", 0)))],
		["box", I18n.t("Buildings built"), HomeHud._thousands(int(s.get("build", 0)))],
		["up", I18n.t("Upgrades"), HomeHud._thousands(int(s.get("upgrade", 0)))],
		["coin", I18n.t("Coins collected"), HomeHud._thousands(int(s.get("coins_collected", 0)))],
	]
	for r: Array in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		var icon := Icons.rect(r[0], 24)
		if r[0] in ["swords", "tasks"]:
			icon.modulate = Color(0.25, 0.25, 0.22)
		row.add_child(icon)
		var name_label := HomeHud.ink(row, r[1], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		HomeHud.ink(row, r[2], 19)
	return card


## Small picture cards with a level strip; level 0 shows as locked.
static func _grid(types: Array, level_of: Callable, columns: int) -> Control:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for t: String in types:
		var lvl: int = level_of.call(t)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(84, 98)
		card.add_theme_stylebox_override("panel", HomeHud._box(CARD, 10, LINE, 2))
		if lvl <= 0:
			card.modulate = Color(1, 1, 1, 0.5)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76, 66)
		v.add_child(holder)
		var pic := ShopUI.picture(t, maxi(lvl, 1), Color(0.56, 0.64, 0.43))
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(pic)
		var l := HomeHud.ink(v, I18n.t("Lv %d") % lvl if lvl > 0 else I18n.t("Locked"), 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(card)
	return grid


static func _best_level(type: String) -> int:
	var best := 0
	for s in GameState.structures:
		if s["type"] == type:
			best = maxi(best, int(s["level"]))
	return best
