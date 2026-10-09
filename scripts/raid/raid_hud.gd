class_name RaidHud
extends CanvasLayer
## Battle UI (landscape): timer and destruction at the top; End and the unit cards in one
## bottom corner, the prepared support abilities (air strike, flare) in the other;
## floating health bars over damaged structures and units, and the result panel.

signal unit_selected(type: String)
signal end_pressed
signal retry_pressed
signal home_pressed
signal ability_pressed(kind: String)

var retry_button: Button
## Whether the battle shown in the result window was won (at least one star).
var won := false

var _title: Label
var _timer: Label
var _progress: Label
var _loot: Label
var _status: Label
var _cards: HBoxContainer
var _card_buttons := {}
## Per card: the count label and the panel style.
var _card_parts := {}
var _end: Button
var _support_row: HBoxContainer
var _abilities := {}
var _bars_layer: Control
var _bars := {}
var _hit_tint: ColorRect
var _result: PanelContainer
var _result_title: Label
var _result_stars: Label
var _result_info: Label


func _ready() -> void:
	var root := HomeHud.make_root(self)

	_bars_layer = Control.new()
	_bars_layer.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_bars_layer.anchor_right = 1.0
	_bars_layer.anchor_bottom = 1.0
	_bars_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bars_layer)

	_hit_tint = ColorRect.new()
	_hit_tint.anchor_right = 1.0
	_hit_tint.anchor_bottom = 1.0
	_hit_tint.color = Color(1.0, 0.1, 0.1, 0.0)
	_hit_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hit_tint)

	var top := VBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 24.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_title = HomeHud.make_label(top, "", 28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	_timer = HomeHud.make_label(row, "1:30", 40)
	_progress = HomeHud.make_label(row, "", 28)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loot = HomeHud.make_label(row, "", 28)
	_status = HomeHud.make_label(top, "", 24)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bottom := HBoxContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 16.0
	bottom.offset_right = -16.0
	bottom.offset_top = -150.0
	bottom.offset_bottom = -20.0
	bottom.add_theme_constant_override("separation", 10)
	# Same layout in both languages: End on the left, abilities on the right.
	bottom.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.add_child(bottom)
	_end = HomeHud.make_button(bottom, I18n.t("End"), 24, 96)
	_end.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_end.size_flags_vertical = Control.SIZE_SHRINK_END
	_end.custom_minimum_size.x = 100
	_end.pressed.connect(func() -> void: end_pressed.emit())
	_cards = HBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.size_flags_vertical = Control.SIZE_SHRINK_END
	_cards.add_theme_constant_override("separation", 10)
	bottom.add_child(_cards)
	bottom.add_child(_support_panel())

	_result = PanelContainer.new()
	_result.anchor_left = 0.5
	_result.anchor_right = 0.5
	_result.anchor_top = 0.5
	_result.anchor_bottom = 0.5
	_result.offset_left = -290.0
	_result.offset_right = 290.0
	_result.offset_top = -250.0
	_result.offset_bottom = 250.0
	_result.add_theme_stylebox_override("panel", HomeHud.flat(Color(0.08, 0.1, 0.14, 0.94)))
	root.add_child(_result)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_result.add_child(box)
	_result_title = HomeHud.make_label(box, "", 46)
	_result_stars = HomeHud.make_label(box, "", 40)
	_result_info = HomeHud.make_label(box, "", 28)
	for l in [_result_title, _result_stars, _result_info]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	retry_button = HomeHud.make_button(buttons, I18n.t("Retry"), 30, 88)
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	var home := HomeHud.make_button(buttons, I18n.t("Home"), 30, 88)
	home.pressed.connect(func() -> void: home_pressed.emit())
	Tutorial.tag(home, "result_home")
	_result.visible = false


func _process(delta: float) -> void:
	_hit_tint.color.a = move_toward(_hit_tint.color.a, 0.0, delta * 1.5)


func set_title(text: String) -> void:
	_title.text = text


func set_status(text: String) -> void:
	_status.text = text


func set_timer(seconds: float) -> void:
	var s := maxi(0, int(ceil(seconds)))
	_timer.text = "%d:%02d" % [s / 60, s % 60]


func set_progress(percent: int, stars: int) -> void:
	_progress.text = I18n.t("%d%%  ·  Stars %d/3") % [percent, stars]


## Two round ability buttons, each with how many are left.
func _support_panel() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	_support_row = row
	for kind in Catalog.ABILITY_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 110)
		b.add_theme_font_size_override("font_size", 19)
		b.toggle_mode = true
		b.pressed.connect(func() -> void:
			Audio.play("click", -6.0)
			ability_pressed.emit(kind))
		row.add_child(b)
		_abilities[kind] = b
	return row


## Shows how many of each ability are left, greys out the spent ones, marks the armed one.
func set_support(counts: Dictionary, armed: String) -> void:
	for kind in _abilities:
		var b: Button = _abilities[kind]
		var left := int(counts.get(kind, 0))
		b.text = (I18n.t("Flare") if kind == "flare" else I18n.t("Air\nstrike")) + "\nx%d" % left
		b.disabled = left <= 0 and armed != kind
		b.set_pressed_no_signal(armed == kind)
		var base := Color(0.91, 0.33, 0.23) if kind == "strike" else Color(1.0, 0.48, 0.24)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var s := HomeHud.flat(base.lightened(0.15 if state == "hover" else 0.0).darkened(0.25 if state == "pressed" else 0.0) if state != "disabled" else Color(0.16, 0.17, 0.16, 0.8))
			s.set_corner_radius_all(55)
			s.border_color = Color(1, 1, 1, 0.9) if armed == kind else Color(1, 0.9, 0.85, 0.5)
			s.set_border_width_all(5 if armed == kind else 3)
			s.set_content_margin_all(4)
			b.add_theme_stylebox_override(state, s)


func set_loot(coins: int, fuel: int) -> void:
	_loot.text = I18n.t("Loot %d coins · %d fuel") % [coins, fuel]


const CARD := Vector2(104, 130)


## Clash-style unit cards (approved sketch Fy11Uvx52E8AXFytERpDZa): a picture of the unit at
## its level, how many are left in the corner, a level badge in the level color and the name
## in a strip at the bottom. The selected card lifts with a white frame; empty ones go grey.
func set_army(army: Dictionary, names: Dictionary, selected: String, levels: Dictionary = {}) -> void:
	for child in _cards.get_children():
		child.queue_free()
	_card_buttons.clear()
	_card_parts.clear()
	for type in army:
		var lvl := clampi(int(levels.get(type, 1)), 1, 5)
		var drone := Catalog.DRONES.has(type)
		var holder := Control.new()
		holder.custom_minimum_size = CARD + Vector2(0, 14)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards.add_child(holder)
		var b := Button.new()
		b.size = CARD
		b.position = Vector2(0, 14)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.clip_contents = true
		holder.add_child(b)
		var base := Color(0.3, 0.4, 0.5) if drone else Color(0.38, 0.42, 0.26)
		var style := HomeHud.flat(base)
		style.set_corner_radius_all(10)
		style.border_color = Color(1, 1, 1, 0.25)
		style.set_border_width_all(2)
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 3)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, style)
		var pic := ShopUI.picture(type, lvl, base.lightened(0.12))
		pic.position = Vector2(3, 3)
		pic.size = Vector2(CARD.x - 6, CARD.y - 30)
		b.add_child(pic)
		var count := _card_label(b, "", 22, Vector2(8, 2))
		count.add_theme_constant_override("outline_size", 6)
		count.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
		var badge := Panel.new()
		var bs := HomeHud.flat(UnitModels.LEVEL_COLORS[lvl - 1].lightened(0.25))
		bs.set_corner_radius_all(5)
		badge.add_theme_stylebox_override("panel", bs)
		badge.position = Vector2(6, CARD.y - 48)
		badge.size = Vector2(24, 20)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		var bl := _card_label(badge, str(lvl), 14, Vector2.ZERO)
		bl.size = badge.size
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		var strip := ColorRect.new()
		strip.color = Color(0.04, 0.05, 0.04, 0.75)
		strip.position = Vector2(0, CARD.y - 24)
		strip.size = Vector2(CARD.x, 24)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(strip)
		# What the unit goes for first, in the top corner (approved sketch FXGoTcv7xRzZbR5GDqE6S3).
		var aim := TextureRect.new()
		aim.texture = Icons.tex(Icons.target(type), 64)
		aim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		aim.size = Vector2(30, 30)
		aim.position = Vector2(CARD.x - 33, 3)
		aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(aim)
		var name_label := _card_label(strip, names[type], 13, Vector2.ZERO)
		name_label.size = strip.size
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		b.pressed.connect(func() -> void: unit_selected.emit(type))
		_card_buttons[type] = b
		_card_parts[type] = {"count": count, "style": style}
	update_army(army, names, selected)


func _card_label(parent: Control, text: String, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func update_army(army: Dictionary, _names: Dictionary, selected: String) -> void:
	for type in _card_buttons:
		var b: Button = _card_buttons[type]
		var parts: Dictionary = _card_parts[type]
		var left := int(army.get(type, 0))
		var on: bool = type == selected and left > 0
		(parts["count"] as Label).text = "x%d" % left
		b.disabled = left <= 0
		b.set_pressed_no_signal(on)
		b.position.y = 0.0 if on else 14.0
		b.modulate = Color(0.55, 0.55, 0.55) if left <= 0 else Color.WHITE
		var style: StyleBoxFlat = parts["style"]
		style.border_color = Color.WHITE if on else Color(1, 1, 1, 0.25)
		style.set_border_width_all(3 if on else 2)


func flash_hit() -> void:
	_hit_tint.color.a = 0.25


## Health bars that follow things on screen. Each entry: {key, pos: Vector2, ratio, friendly}.
func update_bars(entries: Array) -> void:
	var seen := {}
	for e in entries:
		var key: String = e["key"]
		seen[key] = true
		var bar: ProgressBar = _bars.get(key)
		if bar == null:
			bar = _make_bar(e["friendly"])
			_bars[key] = bar
		bar.visible = true
		bar.value = float(e["ratio"]) * 100.0
		bar.position = (e["pos"] as Vector2) - bar.size / 2.0
	for key in _bars:
		if not seen.has(key):
			(_bars[key] as ProgressBar).visible = false


## `gained` is {coins, fuel} actually banked.
func show_result(stars: int, percent: int, gained: Dictionary, practice: bool, extra: String = "") -> void:
	won = stars > 0
	_result_title.text = I18n.t("Battle over")
	_result_stars.text = I18n.t("Stars %d / 3   ·   %d%%") % [stars, percent]
	if practice:
		_result_info.text = I18n.t("Practice run on your own base.\nNo coins at stake.")
	else:
		_result_info.text = I18n.t("Loot banked: %d coins, %d fuel") % [int(gained["coins"]), int(gained["fuel"])]
	if extra != "":
		_result_info.text += "\n" + extra
	_result_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.visible = true
	_cards.visible = false
	_end.visible = false


func blocks(pos: Vector2) -> bool:
	for c: Control in [_cards, _end, _result, _support_row]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _make_bar(friendly: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size = Vector2(70, 12) if not friendly else Vector2(48, 9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.8, 1.0) if friendly else Color(0.95, 0.3, 0.25)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	_bars_layer.add_child(bar)
	return bar
