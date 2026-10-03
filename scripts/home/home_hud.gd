class_name HomeHud
extends CanvasLayer
## UI for the home base, held sideways (approved sketch, layout B): the player badge and
## Command Tower level in one top corner, free workers in the middle, coins / fuel / gems in
## the other corner; a round Attack button in one bottom corner and Army / Build / Settings
## in the other. Info sheets open as a card at the bottom middle, over the bottom buttons.
## Hebrew mirrors everything. Also hosts the small UI helpers the raid screen reuses.

signal attack_pressed
signal army_pressed
signal build_pressed
signal settings_pressed
signal workers_pressed
signal gems_pressed

const COIN := Color(0.95, 0.79, 0.3)
const FUEL := Color(0.93, 0.35, 0.55)
const GEM := Color(0.37, 0.88, 0.65)
const DARK := Color(0.04, 0.06, 0.04, 0.75)

var _badge: Label
var _rank: Label
var _workers: Button
var _bars := {}
var _attack: Button
var _dock: HBoxContainer
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _toast: Label


func _ready() -> void:
	var root := make_root(self)
	# Corner widgets live in a left-to-right layer and are mirrored by hand for Hebrew,
	# because Godot's automatic RTL mirroring does not flip anchored offsets.
	var corners := Control.new()
	corners.layout_direction = Control.LAYOUT_DIRECTION_LTR
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corners)
	var dir := Control.LAYOUT_DIRECTION_RTL if I18n.rtl() else Control.LAYOUT_DIRECTION_LTR

	# Player badge and Command Tower level.
	var player := HBoxContainer.new()
	player.position = Vector2(28, 22)
	player.add_theme_constant_override("separation", 12)
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.layout_direction = dir
	_pin(corners, player, false)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(62, 62)
	var badge_style := flat(Color(0.18, 0.43, 0.88))
	badge_style.border_color = Color.WHITE
	badge_style.set_border_width_all(3)
	badge_style.set_content_margin_all(0)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(badge)
	_badge = make_label(badge, "1", 30)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(names)
	make_label(names, I18n.t("Commander"), 26)
	_rank = make_label(names, "", 20, Color(0.85, 0.9, 0.85))

	# Free workers, top middle.
	_workers = Button.new()
	_workers.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed"]:
		var s := flat(DARK if state != "hover" else Color(0.1, 0.13, 0.1, 0.85))
		s.set_corner_radius_all(24)
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		_workers.add_theme_stylebox_override(state, s)
	_workers.anchor_left = 0.5
	_workers.anchor_right = 0.5
	_workers.offset_left = -150
	_workers.offset_right = 150
	_workers.offset_top = 22
	_workers.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		workers_pressed.emit())
	root.add_child(_workers)

	# Coins, fuel and gems, top corner.
	var res := VBoxContainer.new()
	res.add_theme_constant_override("separation", 8)
	res.custom_minimum_size.x = 300
	res.layout_direction = dir
	_pin(corners, res, true)
	for key in ["coins", "fuel", "gems"]:
		_bars[key] = _resource_bar(res, key)

	# Round Attack button, bottom corner.
	_attack = Button.new()
	_attack.custom_minimum_size = Vector2(170, 170)
	_attack.add_theme_font_size_override("font_size", 30)
	_attack.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_attack.add_theme_constant_override("outline_size", 8)
	for state in ["normal", "hover", "pressed"]:
		var s := flat({"normal": Color(0.85, 0.28, 0.17), "hover": Color(0.93, 0.36, 0.23), "pressed": Color(0.7, 0.2, 0.12)}[state])
		s.set_corner_radius_all(85)
		s.border_color = Color(1.0, 0.85, 0.78)
		s.set_border_width_all(4)
		s.shadow_color = Color(0.42, 0.11, 0.06)
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 7)
		_attack.add_theme_stylebox_override(state, s)
	_attack.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		attack_pressed.emit())
	_pin(corners, _attack, false, true)

	# Army / Build / Settings, other bottom corner.
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 12)
	_dock.layout_direction = dir
	_pin(corners, _dock, true, true)
	_dock_button(I18n.t("Army"), false).pressed.connect(func() -> void: army_pressed.emit())
	_dock_button(I18n.t("Build"), true).pressed.connect(func() -> void: build_pressed.emit())
	_dock_button(I18n.t("Settings"), false).pressed.connect(func() -> void: settings_pressed.emit())

	# Info card, bottom middle.
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -18.0
	_panel.offset_top = -400.0
	_panel.add_theme_stylebox_override("panel", flat(Color(0.06, 0.08, 0.06, 0.95)))
	root.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	_panel_title = make_label(head, "", 32)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := make_button(head, I18n.t("Close"), 22, 52)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 120
	close.pressed.connect(hide_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_panel_body)
	_panel.visible = false

	_toast = make_label(root, "", 34)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.24
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0


## Places a control in a screen corner: the start or end side (mirrored in Hebrew), top or
## bottom. It is anchored to the corner and grows inward to fit its content.
func _pin(root: Control, c: Control, end_side: bool, bottom: bool = false) -> void:
	const MARGIN := 24.0
	root.add_child(c)
	var on_right := end_side != I18n.rtl()
	# Godot mirrors the anchors of a control that is itself right-to-left; undo that.
	if c.is_layout_rtl():
		on_right = not on_right
	c.anchor_left = 1.0 if on_right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	var x := -MARGIN if on_right else MARGIN
	var y := -MARGIN if bottom else MARGIN
	c.offset_left = x
	c.offset_right = x
	c.offset_top = y
	c.offset_bottom = y
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if on_right else Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END


func _resource_bar(parent: Control, key: String) -> Dictionary:
	var color: Color = {"coins": COIN, "fuel": FUEL, "gems": GEM}[key]
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 44)
	var bg := flat(DARK)
	bg.set_corner_radius_all(22)
	bg.border_color = Color(1, 1, 1, 0.14)
	bg.set_border_width_all(1)
	var fill := flat(Color(color, 0.38 if key != "gems" else 0.0))
	fill.set_corner_radius_all(20)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -14
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot := flat(color)
	dot.set_corner_radius_all(18)
	dot.border_color = Color(0, 0, 0, 0.35)
	dot.set_border_width_all(2)
	icon.add_theme_stylebox_override("panel", dot)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var value := make_label(row, "", 26)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_FILL
	var cap := make_label(row, "", 18, Color(0.85, 0.88, 0.85))
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.size_flags_vertical = Control.SIZE_FILL
	if key == "gems":
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 34)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.add_theme_font_size_override("font_size", 24)
		plus.add_theme_color_override("font_color", Color(0.02, 0.24, 0.15))
		var ps := flat(GEM)
		ps.set_corner_radius_all(8)
		ps.set_content_margin_all(0)
		plus.add_theme_stylebox_override("normal", ps)
		plus.add_theme_stylebox_override("hover", ps)
		plus.add_theme_stylebox_override("pressed", ps)
		plus.pressed.connect(func() -> void: gems_pressed.emit())
		row.add_child(plus)
	return {"bar": bar, "value": value, "cap": cap}


func _dock_button(text: String, gold: bool) -> Button:
	var b := make_button(_dock, text, 22, 96)
	b.custom_minimum_size.x = 104
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if gold:
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, flat({"normal": Color(0.9, 0.69, 0.16), "hover": Color(0.96, 0.76, 0.24), "pressed": Color(0.78, 0.56, 0.08)}[state]))
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color(0.17, 0.11, 0.0))
	else:
		for state in ["normal", "hover", "pressed"]:
			var s := flat({"normal": Color(0.07, 0.09, 0.07, 0.86), "hover": Color(0.12, 0.15, 0.12, 0.9), "pressed": Color(0.04, 0.05, 0.04, 0.9)}[state])
			s.border_color = Color(1, 1, 1, 0.2)
			s.set_border_width_all(2)
			b.add_theme_stylebox_override(state, s)
	return b


func _process(delta: float) -> void:
	_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta * 0.6)


func set_header(hq_level: int, target_name: String, infinite: bool = false) -> void:
	_badge.text = str(hq_level)
	_rank.text = I18n.t("Command Tower Lv %d") % hq_level
	_workers.text = I18n.t("Free workers %d/%d") % [GameState.free_workers(), GameState.workers]
	_attack.text = I18n.t("ATTACK!\n%s") % target_name
	_set_bar("coins", GameState.coins, GameState.coin_cap(), infinite)
	_set_bar("fuel", GameState.fuel, GameState.fuel_cap(), infinite)
	_set_bar("gems", GameState.gems, 0, infinite)


func _set_bar(key: String, value: int, cap: int, infinite: bool) -> void:
	var b: Dictionary = _bars[key]
	(b["value"] as Label).text = "∞" if infinite else str(value)
	(b["cap"] as Label).text = "" if cap <= 0 or infinite else "/ %d" % cap
	(b["bar"] as ProgressBar).max_value = maxi(cap, 1)
	(b["bar"] as ProgressBar).value = cap if infinite else value


## Time left as 0:45, 12:05 or 3:04:10.
static func clock(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


func panel_open() -> bool:
	return _panel.visible


## Bottom-middle card with any content. The bottom buttons hide while it is open.
func show_content(title: String, content: Control) -> void:
	_panel_title.text = title
	for child in _panel_body.get_children():
		child.queue_free()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_child(content)
	_panel.visible = true
	_attack.visible = false
	_dock.visible = false
	_fit_panel()


## Shrinks the card to its content, up to the space under the top bar. Waits for layout
## first, because wrapped text only knows its height once it has a width.
func _fit_panel() -> void:
	for i in 2:
		await get_tree().process_frame
	var room := get_viewport().get_visible_rect().size.y - 190.0
	var wanted := _panel_body.get_combined_minimum_size().y + 110.0
	_panel.offset_top = _panel.offset_bottom - clampf(wanted, 220.0, room)


func hide_panel() -> void:
	_panel.visible = false
	_attack.visible = true
	_dock.visible = true


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.6


func blocks(pos: Vector2) -> bool:
	for c: Control in [_panel, _attack, _dock, _workers, _bars["gems"]["bar"]]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


# ---------------------------------------------------------------- shared UI helpers

## Full-screen root control that ignores clicks, laid out right-to-left in Hebrew.
static func make_root(layer: CanvasLayer) -> Control:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if I18n.rtl() else Control.LAYOUT_DIRECTION_LTR
	layer.add_child(root)
	return root


static func make_label(parent: Control, text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func make_button(parent: Control, text: String, font_size: int, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	parent.add_child(b)
	return b


static func flat(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(14)
	s.set_content_margin_all(18)
	return s


static func stat_bar(parent: Control, label: String, value: float, max_value: float, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := make_label(row, label, 22, Color(0.8, 0.84, 0.9))
	l.custom_minimum_size.x = 210
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = max_value
	bar.value = value
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
