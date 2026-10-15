class_name AttackHud
extends MergeHud
## HUD for the "reverse Bloons" attack sketch: the enemy Command Tower's health and how much of
## the base is destroyed on top, loot instead of coins, and unit cards (with how many are left)
## to tap at the bottom.

const UNIT_PICS := {"soldier": "infantry", "tank": "armor", "drone": "courier"}
const UNIT_NAMES := {"soldier": "Soldiers", "tank": "Tanks", "drone": "Drones"}

var _counts := {}


func _bottom(root: Control) -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -250
	panel.add_theme_stylebox_override("panel", _style(Color(0.11, 0.13, 0.09, 0.94), 0))
	root.add_child(panel)
	var x := 24.0
	for kind: String in AttackGame.SEND_ORDER:
		var card := Panel.new()
		card.position = Vector2(x, 26)
		card.size = Vector2(180, 200)
		card.add_theme_stylebox_override("panel", _style(Color(0.17, 0.2, 0.14), 18, SAND))
		panel.add_child(card)
		var crop := AtlasTexture.new()
		crop.atlas = load("res://assets/textures/pictures/%s_2.webp" % UNIT_PICS[kind])
		crop.region = Rect2(20, 20, 216, 216)
		var pic := TextureRect.new()
		pic.texture = crop
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		pic.position = Vector2(12, 8)
		pic.size = Vector2(156, 134)
		var count := _label("", 30, Color.WHITE)
		count.position = Vector2(12, 4)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(count)
		_counts[kind] = count
		var tag := Panel.new()
		tag.position = Vector2(10, 146)
		tag.size = Vector2(160, 44)
		tag.add_theme_stylebox_override("panel", _style(GO, 12))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tag)
		var name := _label(I18n.t(UNIT_NAMES[kind]), 22, Color.WHITE)
		name.size = tag.size
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_child(name)
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventScreenTouch and e.pressed:
				(game as AttackGame).send(kind))
		_cards[kind] = card
		x += 196.0
	_speed = Button.new()
	_speed.text = "x2"
	_speed.position = Vector2(612, 26)
	_speed.size = Vector2(88, 200)
	_speed.add_theme_font_size_override("font_size", 30)
	_speed.add_theme_stylebox_override("normal", _style(Color(0.17, 0.2, 0.14), 18, SAND))
	_speed.add_theme_stylebox_override("hover", _style(Color(0.17, 0.2, 0.14), 18, SAND))
	_speed.add_theme_stylebox_override("pressed", _style(GOLD, 18, SAND))
	_speed.toggle_mode = true
	_speed.toggled.connect(func(on: bool) -> void:
		Engine.time_scale = 2.0 if on else 1.0
		Audio.play("click", -8.0))
	panel.add_child(_speed)


func refresh() -> void:
	if game == null or _hp_fill == null:
		return
	var g := game as AttackGame
	var k := clampf(g.hq_hp / AttackGame.ENEMY_HQ, 0.0, 1.0)
	_hp_fill.size.x = maxf(34.0, 664.0 * k)
	_hp_fill.visible = k > 0.0
	_hp_fill.add_theme_stylebox_override("panel", _style(Color(0.83, 0.33, 0.25), 17))
	_hp_text.text = I18n.t("Iron Fang tower %d%%") % int(round(k * 100.0))
	_wave.text = I18n.t("Destroyed %d%%") % int(round((1.0 - k) * 100.0))
	_coins.text = str(g.loot)
	for kind in _counts:
		var n: int = g.army.get(kind, 0)
		(_counts[kind] as Label).text = "x%d" % n
		(_cards[kind] as Control).modulate = Color.WHITE if n > 0 else Color(0.5, 0.5, 0.5)


func _process(_delta: float) -> void:
	pass


func show_end(won: bool, stars: int) -> void:
	var g := game as AttackGame
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var card := Panel.new()
	card.position = Vector2(80, 380)
	card.size = Vector2(560, 470)
	card.add_theme_stylebox_override("panel", _style(Color(0.13, 0.16, 0.11), 28, SAND))
	shade.add_child(card)
	var col := VBoxContainer.new()
	col.position = Vector2(0, 34)
	col.size = Vector2(560, 400)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var title := _label(I18n.t("Base taken!") if won else I18n.t("Attack failed"), 54, GOLD if won else Color(0.95, 0.4, 0.32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var star_row := _label("★".repeat(stars) + "☆".repeat(3 - stars), 64, GOLD)
	star_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(star_row)
	var line := _label(I18n.t("Loot: %d coins") % g.loot, 30, Color.WHITE)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	var again := Button.new()
	again.text = I18n.t("Try again")
	again.custom_minimum_size = Vector2(300, 76)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.add_theme_font_size_override("font_size", 32)
	again.add_theme_stylebox_override("normal", _style(GO, 38))
	again.add_theme_stylebox_override("hover", _style(GO.lightened(0.1), 38))
	again.add_theme_stylebox_override("pressed", _style(GO.darkened(0.2), 38))
	again.pressed.connect(func() -> void: game.restart())
	col.add_child(again)
