class_name MergeHud
extends CanvasLayer
## Base Wars HUD, portrait: the tower's health, wave, coins and gems on top; the start button,
## speed toggle and the three tower cards (drag them onto the board) at the bottom; health bars
## over enemies and floating "+5" / "LEVEL UP!" drawn on an overlay; the win / lose card.

const SAND := Color(0.85, 0.77, 0.54)
const GOLD := Color(0.91, 0.71, 0.17)
const GO := Color(0.31, 0.68, 0.29)
const DARK := Color(0.1, 0.12, 0.09, 0.88)
const NAMES := {"mg": "MG Nest", "mortar": "Mortar", "aa": "AA Battery"}

var game: MergeGame
var _hp_fill: Panel
var _hp_text: Label
var _wave: Label
var _coins: Label
var _start: Button
var _speed: Button
var _cards := {}
var _overlay: Control
var _floats: Array = []
var _banner: Label


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	root.add_child(_overlay)
	_top(root)
	_bottom(root)
	_banner = _label("", 44, Color.WHITE)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-300, 190)
	_banner.size = Vector2(600, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	root.add_child(_banner)


func _style(color: Color, radius: int = 18, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.set_border_width_all(3)
		s.border_color = border
	return s


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _pill(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", _style(DARK, int(size.y / 2.0)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _top(root: Control) -> void:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 170)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var title := _label("BASE WARS", 40, SAND)
	title.position = Vector2(0, 16)
	title.size = Vector2(720, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var hp := _pill(bar, Vector2(24, 76), Vector2(672, 42))
	_hp_fill = Panel.new()
	_hp_fill.position = Vector2(4, 4)
	_hp_fill.size = Vector2(664, 34)
	_hp_fill.add_theme_stylebox_override("panel", _style(GO, 17))
	hp.add_child(_hp_fill)
	_hp_text = _label("", 24, Color.WHITE)
	_hp_text.size = Vector2(672, 42)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp.add_child(_hp_text)
	var wave := _pill(bar, Vector2(24, 128), Vector2(200, 44))
	_wave = _label("", 24, Color.WHITE)
	_wave.size = wave.size
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave.add_child(_wave)
	var money := _pill(bar, Vector2(436, 128), Vector2(260, 44))
	var row := HBoxContainer.new()
	row.size = money.size
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	money.add_child(row)
	row.add_child(_icon(Icons.tex("coin")))
	_coins = _label("", 26, GOLD)
	row.add_child(_coins)
	row.add_child(_icon(Icons.tex("gem")))
	row.add_child(_label("120", 24, Color(0.6, 0.95, 0.75)))


func _icon(tex: Texture2D) -> Control:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(30, 30)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r


func _bottom(root: Control) -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -250
	panel.add_theme_stylebox_override("panel", _style(Color(0.11, 0.13, 0.09, 0.94), 0))
	root.add_child(panel)
	var x := 24.0
	for type in MergeGame.TOWER_ORDER:
		var card := Panel.new()
		card.position = Vector2(x, 26)
		card.size = Vector2(180, 200)
		card.add_theme_stylebox_override("panel", _style(Color(0.17, 0.2, 0.14), 18, SAND))
		panel.add_child(card)
		# The baked pictures sit low in their square; show the part with the model.
		var crop := AtlasTexture.new()
		crop.atlas = load("res://assets/textures/pictures/%s_1.webp" % type)
		crop.region = Rect2(0, 70, 256, 186)
		var pic := TextureRect.new()
		pic.texture = crop
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		pic.position = Vector2(12, 10)
		pic.size = Vector2(156, 130)
		var price := Panel.new()
		price.position = Vector2(10, 146)
		price.size = Vector2(160, 44)
		price.add_theme_stylebox_override("panel", _style(GOLD, 12))
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(price)
		var name := _label("%s · %d" % [I18n.t(NAMES[type]), MergeGame.TOWERS[type]["cost"]], 20, Color(0.1, 0.1, 0.06))
		name.add_theme_constant_override("outline_size", 0)
		name.size = price.size
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.add_child(name)
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventScreenTouch and e.pressed:
				game.begin_new(type, card.get_global_transform_with_canvas() * e.position))
		_cards[type] = card
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
	_start = Button.new()
	_start.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_start.position = Vector2(210, 1280 - 340)
	_start.size = Vector2(300, 74)
	_start.add_theme_font_size_override("font_size", 32)
	_start.add_theme_stylebox_override("normal", _style(GO, 37, Color(0.75, 0.94, 0.66)))
	_start.add_theme_stylebox_override("hover", _style(GO.lightened(0.1), 37, Color(0.75, 0.94, 0.66)))
	_start.add_theme_stylebox_override("pressed", _style(GO.darkened(0.2), 37, Color(0.75, 0.94, 0.66)))
	_start.pressed.connect(func() -> void: game.start_wave())
	root.add_child(_start)


func refresh() -> void:
	if game == null or _hp_fill == null:
		return
	var k := clampf(game.hq_hp / MergeGame.HQ_HP, 0.0, 1.0)
	_hp_fill.size.x = maxf(34.0, 664.0 * k)
	_hp_fill.visible = k > 0.0
	_hp_fill.add_theme_stylebox_override("panel", _style(GO if k > 0.4 else Color(0.83, 0.33, 0.25), 17))
	_hp_text.text = I18n.t("Command Tower %d%%") % int(round(k * 100.0))
	_wave.text = I18n.t("Wave %d/%d") % [maxi(1, game.wave), MergeGame.WAVES]
	_coins.text = str(game.coins)
	for type in _cards:
		(_cards[type] as Control).modulate = Color.WHITE if game.coins >= MergeGame.TOWERS[type]["cost"] else Color(0.55, 0.55, 0.55)
	_start.visible = game.state in [MergeGame.State.READY, MergeGame.State.BREAK]
	_start.text = I18n.t("Wave %d ▶") % (game.wave + 1)


func _process(_delta: float) -> void:
	if game != null and game.state == MergeGame.State.BREAK:
		_start.text = I18n.t("Wave %d in %d") % [game.wave + 1, ceili(game._break)]


func banner(text: String) -> void:
	_banner.text = text
	var tw := _banner.create_tween()
	_banner.modulate.a = 0.0
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


func float_text(world: Vector3, text: String, color: Color, big: bool) -> void:
	_floats.append({"pos": world, "text": text, "color": color, "big": big, "born": Time.get_ticks_msec()})


func queue_redraw_overlay() -> void:
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	for f: Dictionary in game.foes:
		if f.get("gone", false) or not is_instance_valid(f["node"]):
			continue
		var node: Node3D = f["node"]
		var top := node.position + Vector3(0, 13.0 if f["air"] else (10.0 if f["kind"] == "boss" else 8.5), 0)
		if game.cam.is_position_behind(top):
			continue
		var p := game.cam.unproject_position(top)
		var w := 56.0 if f["kind"] == "boss" else 34.0
		_overlay.draw_rect(Rect2(p.x - w / 2.0 - 2.0, p.y - 2.0, w + 4.0, 10.0), Color(0, 0, 0, 0.7))
		_overlay.draw_rect(Rect2(p.x - w / 2.0, p.y, w * clampf(f["hp"] / f["max"], 0.0, 1.0), 6.0), Color(0.9, 0.3, 0.24))
	var now := Time.get_ticks_msec()
	var keep: Array = []
	for f: Dictionary in _floats:
		var age := (now - int(f["born"])) / 1000.0
		var life := 1.3 if f["big"] else 0.8
		if age > life:
			continue
		keep.append(f)
		var p := game.cam.unproject_position(f["pos"]) + Vector2(0, -50.0 * age)
		var size := 40 if f["big"] else 26
		var c: Color = f["color"]
		c.a = 1.0 - pow(age / life, 2.0)
		var wdt := font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_overlay.draw_string_outline(font, p - Vector2(wdt / 2.0, 0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0, 0, 0, c.a * 0.7))
		_overlay.draw_string(font, p - Vector2(wdt / 2.0, 0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	_floats = keep


func show_end(won: bool, stars: int) -> void:
	_start.visible = false
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
	var title := _label(I18n.t("Victory!") if won else I18n.t("Base destroyed"), 54, GOLD if won else Color(0.95, 0.4, 0.32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var star_row := _label("★".repeat(stars) + "☆".repeat(3 - stars), 64, GOLD)
	star_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(star_row)
	var line := _label(I18n.t("+850 coins · +50 gems") if won else I18n.t("Fell in wave %d of %d") % [game.wave, MergeGame.WAVES], 28, Color.WHITE)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	var again := Button.new()
	again.text = I18n.t("Next stage") if won else I18n.t("Try again")
	again.custom_minimum_size = Vector2(300, 76)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.add_theme_font_size_override("font_size", 32)
	again.add_theme_stylebox_override("normal", _style(GO, 38))
	again.add_theme_stylebox_override("hover", _style(GO.lightened(0.1), 38))
	again.add_theme_stylebox_override("pressed", _style(GO.darkened(0.2), 38))
	again.pressed.connect(func() -> void: game.restart())
	col.add_child(again)
