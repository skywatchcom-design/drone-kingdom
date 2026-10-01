class_name HomeHud
extends CanvasLayer
## UI for the home base: coins bar, the build/upgrade sheet, the hangar, and Attack.
## Also hosts the small UI helpers the raid screen reuses.

signal attack_pressed
signal hangar_pressed
signal test_pressed

var _title: Label
var _coins: Label
var _attack: Button
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _toast: Label
var _bottom: HBoxContainer


func _ready() -> void:
	var root := make_root(self)

	var top := VBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 24.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_title = make_label(top, "", 30)
	_coins = make_label(top, "", 36)
	_coins.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	_bottom = HBoxContainer.new()
	_bottom.anchor_top = 1.0
	_bottom.anchor_right = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.offset_left = 24.0
	_bottom.offset_right = -24.0
	_bottom.offset_top = -128.0
	_bottom.offset_bottom = -36.0
	_bottom.add_theme_constant_override("separation", 12)
	root.add_child(_bottom)
	make_button(_bottom, I18n.t("Hangar"), 28, 88).pressed.connect(func() -> void: hangar_pressed.emit())
	make_button(_bottom, I18n.t("Test"), 28, 88).pressed.connect(func() -> void: test_pressed.emit())
	_attack = make_button(_bottom, "", 30, 88)
	_attack.size_flags_stretch_ratio = 1.6
	_attack.add_theme_stylebox_override("normal", flat(Color(0.85, 0.3, 0.2)))
	_attack.add_theme_stylebox_override("hover", flat(Color(0.95, 0.38, 0.26)))
	_attack.add_theme_stylebox_override("pressed", flat(Color(0.7, 0.24, 0.16)))
	_attack.pressed.connect(func() -> void: attack_pressed.emit())

	_panel = PanelContainer.new()
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16.0
	_panel.offset_right = -16.0
	_panel.offset_top = -900.0
	_panel.offset_bottom = -144.0
	_panel.add_theme_stylebox_override("panel", flat(Color(0.08, 0.1, 0.14, 0.94)))
	root.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	_panel_title = make_label(head, "", 34)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := make_button(head, I18n.t("Close"), 24, 60)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 140
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

	_toast = make_label(root, "", 36)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.18
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0


func _process(delta: float) -> void:
	_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta * 0.6)


func set_header(hq_level: int, coins: int, cap: int, target_name: String) -> void:
	_title.text = I18n.t("Your Base  ·  Command Tower Lv %d") % hq_level
	_coins.text = I18n.t("Coins %d / %d") % [coins, cap]
	_attack.text = I18n.t("ATTACK\n%s") % target_name


## Bottom sheet with an info line and a grid of buttons. Each action is {text, enabled, call}.
func show_panel(title: String, info: String, actions: Array) -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	if info != "":
		var l := make_label(content, info, 24)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for action in actions:
		var b := make_button(grid, action["text"], 22, 84)
		b.disabled = not action["enabled"]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(action["call"])
	show_content(title, content)


## Bottom sheet with any custom content (used by the hangar).
func show_content(title: String, content: Control) -> void:
	_panel_title.text = title
	for child in _panel_body.get_children():
		child.queue_free()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_child(content)
	_panel.visible = true
	_fit_panel()


## Shrinks the sheet to its content (up to most of the screen). Waits for layout first,
## because wrapped text only knows its height once it has a width.
func _fit_panel() -> void:
	for i in 2:
		await get_tree().process_frame
	var wanted := _panel_body.get_combined_minimum_size().y + 130.0
	_panel.offset_top = -144.0 - clampf(wanted, 260.0, 1000.0)


func hide_panel() -> void:
	_panel.visible = false


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.6


func blocks(pos: Vector2) -> bool:
	for c: Control in [_panel, _bottom]:
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
