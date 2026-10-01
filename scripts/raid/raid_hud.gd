class_name RaidHud
extends CanvasLayer
## On-screen UI for a raid, built in code so the prototype has no scene files to keep in sync.

signal launch_pressed
signal clear_pressed
signal retry_pressed
signal home_pressed

var _title: Label
var _health: ProgressBar
var _loot: Label
var _status: Label
var _launch: Button
var _clear: Button
var _manual_tint: ColorRect
var _hit_tint: ColorRect
var _result: PanelContainer
var _result_title: Label
var _result_stars: Label
var _result_loot: Label


func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_manual_tint = _tint(root, Color(1.0, 0.55, 0.1, 0.0))
	_hit_tint = _tint(root, Color(1.0, 0.1, 0.1, 0.0))

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
	_health = ProgressBar.new()
	_health.custom_minimum_size = Vector2(0, 28)
	_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health.show_percentage = false
	_health.max_value = 100.0
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health.add_theme_stylebox_override("background", _bar_style(Color(0, 0, 0, 0.45)))
	_health.add_theme_stylebox_override("fill", _bar_style(Color(0.3, 0.85, 0.45)))
	row.add_child(_health)
	_loot = _label(row, 28)
	_status = _label(top, 26)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bottom := HBoxContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 24.0
	bottom.offset_right = -24.0
	bottom.offset_top = -128.0
	bottom.offset_bottom = -36.0
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)
	_clear = _button(bottom, "Clear")
	_clear.pressed.connect(func() -> void: clear_pressed.emit())
	_launch = _button(bottom, "Launch")
	_launch.pressed.connect(func() -> void: launch_pressed.emit())

	_result = PanelContainer.new()
	_result.anchor_left = 0.5
	_result.anchor_right = 0.5
	_result.anchor_top = 0.5
	_result.anchor_bottom = 0.5
	_result.offset_left = -280.0
	_result.offset_right = 280.0
	_result.offset_top = -230.0
	_result.offset_bottom = 230.0
	root.add_child(_result)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_result.add_child(box)
	_result_title = _label(box, 46)
	_result_stars = _label(box, 40)
	_result_loot = _label(box, 28)
	for l in [_result_title, _result_stars, _result_loot]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_button(buttons, "Retry").pressed.connect(func() -> void: retry_pressed.emit())
	_button(buttons, "Home").pressed.connect(func() -> void: home_pressed.emit())
	_result.visible = false


func _process(delta: float) -> void:
	_hit_tint.color.a = move_toward(_hit_tint.color.a, 0.0, delta * 1.5)


func set_title(text: String) -> void:
	_title.text = text


func set_status(text: String) -> void:
	_status.text = text


func set_health(value: float) -> void:
	_health.value = value
	var fill := _health.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color(0.3, 0.85, 0.45) if value > 50.0 else (Color(1.0, 0.75, 0.2) if value > 25.0 else Color(1.0, 0.3, 0.25))


func _bar_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	return s


func set_loot(amount: int) -> void:
	_loot.text = "Loot %d" % amount


func set_plan_buttons(shown: bool, can_launch: bool) -> void:
	_clear.visible = shown
	_launch.visible = shown
	_launch.disabled = not can_launch


## True when a touch at `pos` lands on a visible button or the result panel,
## so the world should ignore it.
func blocks(pos: Vector2) -> bool:
	for c: Control in [_clear, _launch, _result]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func set_manual(on: bool, jammed: bool) -> void:
	_manual_tint.color = Color(0.6, 0.2, 1.0, 0.16) if jammed else Color(1.0, 0.55, 0.1, 0.12 if on else 0.0)
	if not on:
		_manual_tint.color.a = 0.0


func flash_hit() -> void:
	_hit_tint.color.a = 0.35


func show_result(success: bool, stars: int, banked: int, total: int, practice: bool) -> void:
	_result_title.text = "Raid complete" if success else "Drone down"
	_result_stars.text = "Stars: %d / 3" % stars
	if practice:
		_result_loot.text = "Practice run on your own base.\nNo coins at stake."
	else:
		_result_loot.text = "Coins banked: %d\nTotal coins: %d" % [banked, total]
	_result.visible = true
	set_plan_buttons(false, false)


func hide_result() -> void:
	_result.visible = false


func _tint(parent: Control, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 32)
	parent.add_child(b)
	return b
