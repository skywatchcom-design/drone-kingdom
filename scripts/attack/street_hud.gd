class_name StreetHud
extends MergeHud
## HUD for StreetRaid: the target's name, its tower's health, how much is destroyed and the
## loot it is worth so far on top; a card per unit type the player brought (picture at its
## level, how many are left), a speed toggle and an End button at the bottom; the result card
## with stars, loot and the way home.

var _counts := {}
var _loot_label: Label
var _title: Label


func _top(root: Control) -> void:
	super._top(root)
	# The title shows the target instead of the game's name.
	for c in root.get_children():
		for l in c.get_children():
			if l is Label and (l as Label).text == "BASE WARS":
				_title = l
	if _title != null:
		_title.text = str((game as StreetRaid).base.get("name", ""))
		_title.add_theme_font_size_override("font_size", 34)
	_loot_label = _coins


func _bottom(root: Control) -> void:
	var g := game as StreetRaid
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -230
	panel.add_theme_stylebox_override("panel", _style(Color(0.11, 0.13, 0.09, 0.94), 0))
	root.add_child(panel)
	var types: Array = []
	for type in Catalog.UNIT_ORDER:
		if g.army.has(type):
			types.append(type)
	var n := maxi(types.size(), 1)
	var w := minf(180.0, (720.0 - 32.0 - 8.0 * (n - 1)) / n)
	var x := (720.0 - (w * n + 8.0 * (n - 1))) / 2.0
	for type: String in types:
		var card := Panel.new()
		card.position = Vector2(x, 70)
		card.size = Vector2(w, 148)
		card.add_theme_stylebox_override("panel", _style(Color(0.17, 0.2, 0.14), 16, SAND))
		panel.add_child(card)
		var lvl: int = g.unit_levels.get(type, 1)
		var crop := AtlasTexture.new()
		crop.atlas = load("res://assets/textures/pictures/%s_%d.webp" % [type, lvl])
		crop.region = Rect2(16, 16, 224, 224)
		var pic := TextureRect.new()
		pic.texture = crop
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		pic.position = Vector2(4, 4)
		pic.size = Vector2(w - 8, 108)
		var count := _label("", 26, Color.WHITE)
		count.position = Vector2(8, 2)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(count)
		_counts[type] = count
		var badge := _label(str(lvl), 18, Color.WHITE)
		badge.position = Vector2(w - 26, 4)
		badge.add_theme_color_override("font_color", UnitModels.LEVEL_COLORS[lvl - 1].lightened(0.3))
		card.add_child(badge)
		var tag := Panel.new()
		tag.position = Vector2(4, 112)
		tag.size = Vector2(w - 8, 32)
		tag.add_theme_stylebox_override("panel", _style(GO, 10))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tag)
		var name := _label(Catalog.display_name(type), 16 if w < 130 else 19, Color.WHITE)
		name.size = tag.size
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		tag.add_child(name)
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventScreenTouch and e.pressed:
				g.send(type))
		_cards[type] = card
		x += w + 8.0
	_speed = _small(panel, "x2", Vector2(560, 12))
	_speed.toggle_mode = true
	_speed.toggled.connect(func(on: bool) -> void:
		Engine.time_scale = 2.0 if on else 1.0
		Audio.play("click", -8.0))
	var end := _small(panel, I18n.t("End"), Vector2(24, 12))
	end.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		g._finish(false))


func _small(parent: Control, text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(136, 48)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(Color(0.17, 0.2, 0.14), 14, SAND))
	b.add_theme_stylebox_override("hover", _style(Color(0.22, 0.26, 0.18), 14, SAND))
	b.add_theme_stylebox_override("pressed", _style(GOLD, 14, SAND))
	parent.add_child(b)
	return b


func refresh() -> void:
	if game == null or _hp_fill == null:
		return
	var g := game as StreetRaid
	var k := clampf(g.hq_hp / g.hq_max, 0.0, 1.0)
	_hp_fill.size.x = maxf(34.0, 664.0 * k)
	_hp_fill.visible = k > 0.0
	_hp_fill.add_theme_stylebox_override("panel", _style(Color(0.83, 0.33, 0.25), 17))
	_hp_text.text = I18n.t("Command Tower %d%%") % int(round(k * 100.0))
	_wave.text = I18n.t("Destroyed %d%%") % int(round(g.destroyed_ratio() * 100.0))
	_coins.text = str(int(round(g._loot_total.x * g.destroyed_ratio())))
	for type in _counts:
		var n: int = int(g.army.get(type, 0))
		(_counts[type] as Label).text = "x%d" % n
		(_cards[type] as Control).modulate = Color.WHITE if n > 0 else Color(0.5, 0.5, 0.5)


func _process(_delta: float) -> void:
	pass


func show_result(stars: int, percent: int, gained: Dictionary, extra: String) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var card := PanelContainer.new()
	card.position = Vector2(60, 340)
	card.custom_minimum_size = Vector2(600, 520)
	card.add_theme_stylebox_override("panel", _style(Color(0.13, 0.16, 0.11), 28, SAND))
	shade.add_child(card)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	var won := stars > 0
	var title := _label(I18n.t("Base taken!") if stars >= 2 else (I18n.t("Victory!") if won else I18n.t("Attack failed")), 50, GOLD if won else Color(0.95, 0.4, 0.32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var star_row := _label("★".repeat(stars) + "☆".repeat(3 - stars), 64, GOLD)
	star_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(star_row)
	var pct := _label(I18n.t("Destroyed %d%%") % percent, 30, Color.WHITE)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pct)
	var loot := HBoxContainer.new()
	loot.alignment = BoxContainer.ALIGNMENT_CENTER
	loot.add_theme_constant_override("separation", 10)
	col.add_child(loot)
	loot.add_child(_icon(Icons.tex("coin")))
	loot.add_child(_label("+%d" % int(gained.get("coins", 0)), 30, GOLD))
	loot.add_child(_icon(Icons.tex("fuel")))
	loot.add_child(_label("+%d" % int(gained.get("fuel", 0)), 30, Color(0.95, 0.5, 0.7)))
	if extra != "":
		var x := _label(extra, 22, Color(0.85, 0.85, 0.8))
		x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		x.custom_minimum_size.x = 540
		col.add_child(x)
	var home := Button.new()
	home.text = I18n.t("Back to base")
	home.custom_minimum_size = Vector2(320, 76)
	home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home.add_theme_font_size_override("font_size", 32)
	home.add_theme_stylebox_override("normal", _style(GO, 38))
	home.add_theme_stylebox_override("hover", _style(GO.lightened(0.1), 38))
	home.add_theme_stylebox_override("pressed", _style(GO.darkened(0.2), 38))
	home.pressed.connect(func() -> void: (game as StreetRaid).go_home())
	col.add_child(home)
