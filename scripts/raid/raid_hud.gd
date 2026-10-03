class_name RaidHud
extends CanvasLayer
## Battle UI (landscape): timer and destruction at the top, drone cards for deploying at the bottom,
## floating health bars over damaged structures and drones, and the result panel.

signal unit_selected(type: String)
signal end_pressed
signal retry_pressed
signal home_pressed

var _title: Label
var _timer: Label
var _progress: Label
var _loot: Label
var _status: Label
var _cards: HBoxContainer
var _card_buttons := {}
var _end: Button
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
	bottom.offset_top = -120.0
	bottom.offset_bottom = -20.0
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	_cards = HBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 10)
	bottom.add_child(_cards)
	_end = HomeHud.make_button(bottom, I18n.t("End"), 26, 120)
	_end.size_flags_horizontal = Control.SIZE_SHRINK_END
	_end.custom_minimum_size.x = 120
	_end.pressed.connect(func() -> void: end_pressed.emit())

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
	HomeHud.make_button(buttons, I18n.t("Retry"), 30, 88).pressed.connect(func() -> void: retry_pressed.emit())
	HomeHud.make_button(buttons, I18n.t("Home"), 30, 88).pressed.connect(func() -> void: home_pressed.emit())
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


func set_loot(coins: int, fuel: int) -> void:
	_loot.text = I18n.t("Loot %d coins · %d fuel") % [coins, fuel]


## One card per drone type with how many are left to deploy. `names` maps type -> label.
func set_army(army: Dictionary, names: Dictionary, selected: String) -> void:
	for child in _cards.get_children():
		child.queue_free()
	_card_buttons.clear()
	for type in army:
		var b := HomeHud.make_button(_cards, "", 20, 96)
		b.custom_minimum_size.x = 140
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.toggle_mode = true
		b.pressed.connect(func() -> void: unit_selected.emit(type))
		_card_buttons[type] = b
	update_army(army, names, selected)


func update_army(army: Dictionary, names: Dictionary, selected: String) -> void:
	for type in _card_buttons:
		var b: Button = _card_buttons[type]
		var left := int(army.get(type, 0))
		b.text = "%s\nx%d" % [names[type], left]
		b.disabled = left <= 0
		b.set_pressed_no_signal(type == selected and left > 0)


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
func show_result(stars: int, percent: int, gained: Dictionary, practice: bool) -> void:
	_result_title.text = I18n.t("Battle over")
	_result_stars.text = I18n.t("Stars %d / 3   ·   %d%%") % [stars, percent]
	if practice:
		_result_info.text = I18n.t("Practice run on your own base.\nNo coins at stake.")
	else:
		_result_info.text = I18n.t("Loot banked: %d coins, %d fuel") % [int(gained["coins"]), int(gained["fuel"])]
	_result.visible = true
	_cards.visible = false
	_end.visible = false


func blocks(pos: Vector2) -> bool:
	for c: Control in [_cards, _end, _result]:
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
