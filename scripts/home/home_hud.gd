class_name HomeHud
extends CanvasLayer
## UI for the home base: resources bar, the build/upgrade sheet, and the Attack button.

signal attack_pressed
signal hangar_pressed
signal test_pressed
signal collect_pressed

var _title: Label
var _coins: Label
var _collect: Button
var _attack: Button
var _panel: PanelContainer
var _panel_title: Label
var _panel_info: Label
var _panel_grid: GridContainer
var _toast: Label
var _bottom: HBoxContainer


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 24.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_title = _label(top, 30)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	_coins = _label(row, 34)
	_coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collect = _button(row, "Collect", 26, 64)
	_collect.size_flags_horizontal = Control.SIZE_SHRINK_END
	_collect.custom_minimum_size.x = 220
	_collect.pressed.connect(func() -> void: collect_pressed.emit())

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
	_button(_bottom, "Hangar", 28, 88).pressed.connect(func() -> void: hangar_pressed.emit())
	_button(_bottom, "Test", 28, 88).pressed.connect(func() -> void: test_pressed.emit())
	_attack = _button(_bottom, "ATTACK", 32, 88)
	_attack.size_flags_stretch_ratio = 1.6
	_attack.add_theme_stylebox_override("normal", _flat(Color(0.85, 0.3, 0.2)))
	_attack.add_theme_stylebox_override("hover", _flat(Color(0.95, 0.38, 0.26)))
	_attack.add_theme_stylebox_override("pressed", _flat(Color(0.7, 0.24, 0.16)))
	_attack.pressed.connect(func() -> void: attack_pressed.emit())

	_panel = PanelContainer.new()
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16.0
	_panel.offset_right = -16.0
	_panel.offset_top = -760.0
	_panel.offset_bottom = -144.0
	_panel.add_theme_stylebox_override("panel", _flat(Color(0.08, 0.1, 0.14, 0.92)))
	root.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_panel_title = _label(head, 34)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(head, "Close", 24, 60).pressed.connect(hide_panel)
	_panel_info = _label(box, 24)
	_panel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_grid = GridContainer.new()
	_panel_grid.columns = 2
	_panel_grid.add_theme_constant_override("h_separation", 12)
	_panel_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(_panel_grid)
	_panel.visible = false

	_toast = _label(root, 34)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.2
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0


func _process(delta: float) -> void:
	_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta * 0.6)


func set_header(hq_level: int, coins: int, cap: int, pending: int, target_name: String) -> void:
	_title.text = "Your Base  ·  Command Tower Lv %d" % hq_level
	_coins.text = "Coins %d / %d" % [coins, cap]
	_collect.text = "Collect +%d" % pending
	_collect.disabled = pending <= 0
	_attack.text = "ATTACK\n%s" % target_name


## Shows the bottom sheet. Each action is {text, enabled, call: Callable}.
func show_panel(title: String, info: String, actions: Array) -> void:
	_panel_title.text = title
	_panel_info.text = info
	_panel_info.visible = info != ""
	for child in _panel_grid.get_children():
		child.queue_free()
	for action in actions:
		var b := _button(_panel_grid, action["text"], 22, 84)
		b.disabled = not action["enabled"]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var call: Callable = action["call"]
		b.pressed.connect(call)
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false


func panel_open() -> bool:
	return _panel.visible


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.6


func blocks(pos: Vector2) -> bool:
	for c: Control in [_panel, _bottom, _collect]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, font_size: int, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font_size)
	parent.add_child(b)
	return b


func _flat(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(14)
	s.set_content_margin_all(18)
	return s
