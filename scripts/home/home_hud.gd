class_name HomeHud
extends CanvasLayer
## UI for the home base in Clash style (approved sketch 4WKjsEP2MoNrBQh5iGnwTF), laid out the
## same in Hebrew and English: commander badge top left, free workers top middle, compact
## coins / fuel / gems top right; Attack and Army bottom left, Settings and the Shop bottom right.
## Tapping a building shows its name over a row of round actions (Info, Upgrade, and its own
## action). The Shop, upgrade and info windows open in the middle over a dimmed screen; other
## sheets (army, labs, support, settings) open as a card at the bottom middle.
## Also hosts the small UI helpers the raid screen reuses.

signal attack_pressed
signal army_pressed
signal build_pressed
signal settings_pressed
signal workers_pressed
signal gems_pressed
signal mode_done
signal actions_closed
signal missions_pressed
signal profile_pressed

const COIN := Color(0.96, 0.77, 0.26)
const FUEL := Color(0.93, 0.35, 0.55)
const GEM := Color(0.31, 0.86, 0.58)
const DARK := Color(0.06, 0.07, 0.06, 0.78)
const PARCHMENT := Color(0.914, 0.894, 0.831)
const INK := Color(0.17, 0.16, 0.13)
const GOLD_TOP := Color(0.94, 0.7, 0.21)
## HUD direction A "military clean" (approved 16.10.2026, sketch H2WYiqcnCPrV8Wo1yEMSiE): dark olive
## plates with a thin sand line and almost square corners, a deep red-brown Attack, an olive Shop,
## muted resource colors. On while the military palette is on.
const PLATE := Color(0.086, 0.1, 0.07, 0.86)
const SAND_LINE := Color(0.85, 0.77, 0.54, 0.45)
const OLIVE := Color(0.24, 0.29, 0.17)
const ATTACK_RED := Color(0.43, 0.165, 0.12)


static func mil() -> bool:
	return MeshKit.palette == "mil"

var _badge: Label
var _rank: Label
var _workers: Button
var _bars := {}
var _attack: Button
var _left: HBoxContainer
var _dock: HBoxContainer
var _shop_badge: Label
var _missions: Button
var _commander: Label
var _player: Control
var _missions_badge: Label
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _toast: Label
## A banner under the top bar for building modes (walls), with a Done button.
var _mode: PanelContainer
var _mode_label: Label
## The tapped building's name over its round action buttons.
var _actions: VBoxContainer
## The middle window: a dimmed screen with a parchment window over it.
var _dim: ColorRect
var _modal: Control
var _modal_close: Button
var _modal_sheet: PanelContainer
## A locked window has no close button and ignores taps outside it (sign-up is required).
var _modal_locked := false
var _modal_body: MarginContainer
## Portrait + military look: windows open as a sheet from the bottom (plan sketch
## SQhYwaeWJpKTv5HjygjboU, the owner's pick: "full" for long lists such as the Shop and the Army,
## "half" for one building's upgrade or info so the base stays in view). "" = the centred window.
var _sheet_mode := ""
var _grab: Control
var _parchment: StyleBox
var _sheet_drag := 0.0


func _ready() -> void:
	var root := make_root(self)
	# Corner widgets live in a left-to-right layer so the layout is the same in both languages.
	var corners := Control.new()
	corners.layout_direction = Control.LAYOUT_DIRECTION_LTR
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corners)

	# Commander badge and Command Tower level, top left.
	var player := HBoxContainer.new()
	player.add_theme_constant_override("separation", 10)
	# Tapping the badge or the name opens the commander's profile.
	player.mouse_filter = Control.MOUSE_FILTER_STOP
	player.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and not e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and not e.pressed):
			Audio.play("click", -6.0)
			profile_pressed.emit())
	_player = player
	# The badge, with the Missions button under it.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(corners, column, false)
	column.add_child(player)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(60, 60)
	var badge_style := _box(OLIVE, 4, Color(0.73, 0.65, 0.43), 2) if mil() else _box(Color(0.2, 0.42, 0.85), 12, Color(0.8, 0.88, 1.0), 3)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(badge)
	_badge = make_label(badge, "1", 30)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(names)
	_commander = make_label(names, I18n.t("Commander"), 24)
	_rank = make_label(names, "", 17, Color(0.88, 0.92, 0.88))
	_missions = _small_button(column, "tasks", I18n.t("Missions"))
	_missions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_button(_missions, PLATE if mil() else Color(0.2, 0.42, 0.75), 12, Color(1, 1, 1, 0.8), 3)
	_missions.pressed.connect(func() -> void: missions_pressed.emit())
	_missions_badge = _corner_badge(_missions)
	Tutorial.tag(_missions, "missions_button")

	# Free workers, top middle.
	_workers = Button.new()
	_workers.add_theme_font_size_override("font_size", 20)
	_workers.icon = Icons.tex("worker", 64)
	_workers.expand_icon = false
	_workers.add_theme_constant_override("icon_max_width", 30)
	_style_button(_workers, PLATE if mil() else DARK, 10, Color(1, 1, 1, 0.25))
	_workers.anchor_left = 0.5
	_workers.anchor_right = 0.5
	_workers.offset_left = -75
	_workers.offset_right = 75
	_workers.offset_top = 18
	_workers.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		workers_pressed.emit())
	corners.add_child(_workers)

	# Coins, fuel and gems, top right.
	var res := VBoxContainer.new()
	res.add_theme_constant_override("separation", 14)
	res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(corners, res, true)
	for key in ["coins", "fuel", "gems"]:
		_bars[key] = _resource_bar(res, key)

	# Attack and Army, bottom left.
	_left = HBoxContainer.new()
	_left.add_theme_constant_override("separation", 10)
	_left.alignment = BoxContainer.ALIGNMENT_END
	_pin(corners, _left, false, true)
	_attack = _big_button(_left, "swords", I18n.t("ATTACK!"))
	_attack.pressed.connect(func() -> void: attack_pressed.emit())
	Tutorial.tag(_attack, "attack_button")
	_small_button(_left, "army", I18n.t("Army")).pressed.connect(func() -> void: army_pressed.emit())

	# Settings and the Shop, bottom right.
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 10)
	_pin(corners, _dock, true, true)
	_small_button(_dock, "gear", I18n.t("Settings")).pressed.connect(func() -> void: settings_pressed.emit())
	var shop := _big_button(_dock, "cart", I18n.t("Shop"))
	Tutorial.tag(shop, "shop_button")
	shop.pressed.connect(func() -> void: build_pressed.emit())
	_shop_badge = _corner_badge(shop)

	# The tapped building's actions, bottom middle.
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	_actions.anchor_left = 0.5
	_actions.anchor_right = 0.5
	_actions.anchor_top = 1.0
	_actions.anchor_bottom = 1.0
	_actions.offset_bottom = -18
	_actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_actions.visible = false
	root.add_child(_actions)

	# Bottom-middle card for sheets.
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

	_mode = PanelContainer.new()
	_mode.anchor_left = 0.5
	_mode.anchor_right = 0.5
	_mode.offset_left = -330
	_mode.offset_right = 330
	_mode.offset_top = 86
	_mode.add_theme_stylebox_override("panel", flat(Color(0.06, 0.08, 0.06, 0.9)))
	root.add_child(_mode)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 14)
	_mode.add_child(mode_row)
	_mode_label = make_label(mode_row, "", 22)
	_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var done := make_button(mode_row, I18n.t("Done"), 24, 64)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.custom_minimum_size.x = 130
	done.pressed.connect(func() -> void: mode_done.emit())
	_mode.visible = false

	# The middle window over a dimmed screen.
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not _modal_locked:
			hide_modal())
	root.add_child(_dim)
	_modal = Control.new()
	# The close button sits top right in both languages; the content keeps the language's direction.
	_modal.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.visible = false
	root.add_child(_modal)
	var sheet := PanelContainer.new()
	_modal_sheet = sheet
	sheet.add_theme_stylebox_override("panel", _box(PARCHMENT, 16, Color(0.11, 0.12, 0.1), 4))
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(sheet)
	_modal_body = MarginContainer.new()
	_modal_body.layout_direction = Control.LAYOUT_DIRECTION_RTL if I18n.rtl() else Control.LAYOUT_DIRECTION_LTR
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_modal_body.add_theme_constant_override(side, 16)
	sheet.add_child(_modal_body)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(54, 54)
	x.add_theme_font_size_override("font_size", 26)
	_style_button(x, Color(0.85, 0.26, 0.16), 10, Color.WHITE, 3)
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -34
	x.offset_right = 20
	x.offset_top = -20
	x.offset_bottom = 34
	x.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		hide_modal())
	_modal.add_child(x)
	_modal_close = x
	_parchment = sheet.get_theme_stylebox("panel")
	# The sheet's handle: a short bar on top; dragging it (or the top strip) down closes the sheet.
	_grab = Control.new()
	_grab.anchor_right = 1.0
	_grab.offset_bottom = 46
	_grab.visible = false
	_grab.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(_grab)
	var bar := Panel.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_left = -44
	bar.offset_right = 44
	bar.offset_top = 14
	bar.offset_bottom = 22
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SAND, 0.55), 4))
	_grab.add_child(bar)
	_grab.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and e.pressed:
			_sheet_drag = 0.0
		elif e is InputEventScreenDrag:
			_sheet_drag += (e as InputEventScreenDrag).relative.y
			if _sheet_drag > 70.0 and not _modal_locked:
				hide_modal())
	_modal.move_child(x, -1)

	_toast = make_label(root, "", 34)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.24
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	if UiTheme.on():
		# A small plate under the top bar instead of big text in the middle of the base.
		_toast.add_theme_font_size_override("font_size", 24)
		_toast.add_theme_constant_override("outline_size", 0)
		var tsb := UiTheme.box(UiTheme.PLATE, UiTheme.RADIUS, Color(UiTheme.OK, 0.7), 1)
		tsb.set_content_margin_all(10)
		_toast.add_theme_stylebox_override("normal", tsb)
		_toast.anchor_left = 0.14
		_toast.anchor_right = 0.86
		_toast.anchor_top = 0.2
		_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Places a control in a screen corner (same in both languages), anchored there and growing
## inward to fit its content.
func _pin(root: Control, c: Control, right: bool, bottom: bool = false) -> void:
	const MARGIN := 20.0
	root.add_child(c)
	var on_right := right
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


static func _box(color: Color, radius: int, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(6)
	return s


## Gives a button the same flat look in every state (lighter on hover, darker when pressed),
## with a drop shadow underneath.
static func _style_button(b: Button, color: Color, radius: int, border: Color = Color(0, 0, 0, 0), width: int = 2) -> void:
	if mil():
		radius = mini(radius, 6)
		width = mini(width, 2)
		if border.a > 0.0:
			border = SAND_LINE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color
		if state == "hover":
			c = color.lightened(0.1)
		elif state == "pressed":
			c = color.darkened(0.15)
		elif state == "disabled":
			c = color.lerp(Color(0.4, 0.4, 0.4), 0.7)
		var s := _box(c, radius, border, width)
		s.shadow_color = Color(0, 0, 0, 0.4 if not mil() else 0.3)
		s.shadow_offset = Vector2(0, 4 if not mil() else 2)
		s.shadow_size = 1
		if state == "focus":
			s.draw_center = false
			s.shadow_size = 0
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 7 if not mil() else 3)


## A big square corner button (Attack, Shop): gold, an icon over a word.
func _big_button(parent: Control, icon: String, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = Icons.tex(icon, 128)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.custom_minimum_size = Vector2(132, 132)
	b.add_theme_font_size_override("font_size", 24)
	_style_button(b, (ATTACK_RED if icon == "swords" else OLIVE) if mil() else GOLD_TOP, 16, Color(1, 1, 1, 0.9), 4)
	if mil():
		b.custom_minimum_size = Vector2(150, 104)
		b.add_theme_constant_override("icon_max_width", 52)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	parent.add_child(b)
	return b


## A small square corner button (Army, Settings).
func _small_button(parent: Control, icon: String, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = Icons.tex(icon, 64)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.custom_minimum_size = Vector2(74, 74)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.add_theme_font_size_override("font_size", 14)
	_style_button(b, PLATE if mil() else Color(0.3, 0.35, 0.29), 12, Color(1, 1, 1, 0.6), 3)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	parent.add_child(b)
	return b


## A small red number badge in a button's top corner. Hidden while empty.
static func _corner_badge(parent: Control) -> Label:
	var l := make_label(parent, "", 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", _box(Color(0.85, 0.25, 0.17), 14, Color.WHITE, 2))
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.offset_left = -22
	l.offset_right = 10
	l.offset_top = -10
	l.offset_bottom = 22
	l.visible = false
	return l


## A compact resource bar: the amount over a fill toward the cap, the icon on the right, and
## the cap in small print above.
func _resource_bar(parent: Control, key: String) -> Dictionary:
	var color: Color = {"coins": COIN, "fuel": FUEL, "gems": GEM}[key]
	if mil():
		color = {"coins": Color(0.79, 0.64, 0.15), "fuel": Color(0.66, 0.28, 0.25), "gems": Color(0.25, 0.62, 0.48)}[key]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(240 if key != "gems" else 160, 36)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_right = -22
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _box(PLATE, 4, SAND_LINE, 1) if mil() else _box(DARK, 8, Color(1, 1, 1, 0.2), 2))
	bar.add_theme_stylebox_override("fill", _box(Color(color, (0.75 if mil() else 0.55) if key != "gems" else 0.0), 3 if mil() else 6))
	holder.add_child(bar)
	var value := make_label(holder, "", 22)
	value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value.offset_right = -52
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cap := make_label(holder, "", 12, Color(0.92, 0.94, 0.9))
	cap.position = Vector2(6, -16)
	var icon := Icons.rect({"coins": "coin", "fuel": "fuel", "gems": "gem"}[key], 48)
	icon.anchor_left = 1.0
	icon.anchor_right = 1.0
	icon.offset_left = -48
	icon.offset_right = 0
	icon.offset_top = -6
	icon.offset_bottom = 42
	holder.add_child(icon)
	if key == "gems":
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 30)
		plus.position = Vector2(-36, 3)
		plus.add_theme_font_size_override("font_size", 22)
		_style_button(plus, Color(0.25, 0.62, 0.48) if mil() else GEM, 6, Color.WHITE, 2)
		plus.pressed.connect(func() -> void: gems_pressed.emit())
		holder.add_child(plus)
	return {"bar": bar, "value": value, "cap": cap}


func _process(delta: float) -> void:
	_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta * 0.6)


func set_header(hq_level: int, target_name: String, infinite: bool = false) -> void:
	_badge.text = str(hq_level)
	_rank.text = I18n.t("Command Tower Lv %d") % hq_level
	_workers.text = "%d/%d" % [GameState.free_workers(), GameState.workers]
	_attack.tooltip_text = target_name
	_set_bar("coins", GameState.coins, GameState.coin_cap(), infinite)
	_set_bar("fuel", GameState.fuel, GameState.fuel_cap(), infinite)
	_set_bar("gems", GameState.gems, 0, infinite)


## How many new things the Shop has (structures there is room to build); 0 hides the badge.
## The name under the badge: the signed-in commander, or just "Commander".
func set_commander(name: String) -> void:
	_commander.text = name if name != "" else I18n.t("Commander")


## The red count of rewards waiting on the Missions button; the button hides during Noa's
## tutorial.
func set_missions(count: int, shown: bool) -> void:
	_missions.visible = shown
	_missions_badge.text = str(count)
	_missions_badge.visible = count > 0


func set_shop_badge(count: int) -> void:
	_shop_badge.visible = count > 0
	_shop_badge.text = str(count)


func _set_bar(key: String, value: int, cap: int, infinite: bool) -> void:
	var b: Dictionary = _bars[key]
	var label := b["value"] as Label
	var shown: int = b.get("shown", -1)
	b["shown"] = value
	if UiTheme.on() and not infinite and shown >= 0 and value > shown:
		# Collected resources count up on the bar once the flying coins arrive.
		var tw := label.create_tween()
		tw.tween_interval(0.45)
		tw.tween_method(func(n: float) -> void: label.text = _thousands(int(n)), float(shown), float(value), 0.6)
	else:
		label.text = "∞" if infinite else _thousands(value)
	(b["cap"] as Label).text = "" if cap <= 0 or infinite else I18n.t("Max %s") % _thousands(cap)
	(b["bar"] as ProgressBar).max_value = maxi(cap, 1)
	(b["bar"] as ProgressBar).value = cap if infinite else value


## 12345 -> "12,345".
static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Time left as 0:45, 12:05 or 3:04:10.
static func clock(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


func panel_open() -> bool:
	return _panel.visible


func _corners_visible(on: bool) -> void:
	_left.visible = on
	_dock.visible = on


## Bottom-middle card with any content. The bottom corners hide while it is open.
func show_content(title: String, content: Control) -> void:
	hide_actions()
	_panel_title.text = title
	for child in _panel_body.get_children():
		child.queue_free()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_child(content)
	_panel.visible = true
	var screen := get_viewport().get_visible_rect().size
	_panel.anchor_left = 0.03 if screen.y > screen.x else 0.2
	_panel.anchor_right = 0.97 if screen.y > screen.x else 0.8
	_corners_visible(false)
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
	_corners_visible(not _actions.visible and not _mode.visible)


# ---------------------------------------------------------------- building actions

## Shows a building's name and level over a row of round actions. Each action is
## {icon, label, cost (text, optional), cost_icon (optional), call, disabled (optional)}.
func show_actions(title: String, actions: Array) -> void:
	_panel.visible = false
	for child in _actions.get_children():
		child.queue_free()
	var name_label := make_label(_actions, title, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Same order as Clash in both languages: Info first on the left.
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_actions.add_child(row)
	for a: Dictionary in actions:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var cost := HBoxContainer.new()
		cost.alignment = BoxContainer.ALIGNMENT_CENTER
		cost.add_theme_constant_override("separation", 4)
		cost.custom_minimum_size.y = 28
		col.add_child(cost)
		if a.get("cost", "") != "":
			if a.get("cost_icon", "") != "":
				cost.add_child(Icons.rect(a["cost_icon"], 24))
			make_label(cost, a["cost"], 20)
		var b := Button.new()
		b.icon = Icons.tex(a["icon"], 96)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(92, 92)
		b.disabled = a.get("disabled", false)
		_style_button(b, PLATE if mil() else Color(0.95, 0.93, 0.86), 16, Color.WHITE, 3)
		b.pressed.connect(func() -> void: Audio.play("click", -6.0))
		b.pressed.connect(a["call"])
		Tutorial.tag(b, "action_" + str(a["icon"]))
		col.add_child(b)
		var l := make_label(col, a["label"], 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions.visible = true
	_corners_visible(false)


func hide_actions() -> void:
	if _actions.visible:
		_actions.visible = false
		actions_closed.emit()
	_corners_visible(not _panel.visible and not _mode.visible)


func actions_open() -> bool:
	return _actions.visible


# ---------------------------------------------------------------- middle window

## Opens `content` in the parchment window in the middle, `size` pixels big. A `locked` window
## can only be closed by the game (hide_modal), not by the player. A `bare` window leaves out the
## parchment, for content that draws its own card.
func show_modal(content: Control, size: Vector2, locked: bool = false, bare: bool = false, kind: String = "") -> void:
	_modal_locked = locked
	var view := get_viewport().get_visible_rect().size
	_sheet_mode = ""
	if view.y > view.x and UiTheme.on() and not bare:
		_sheet_mode = kind if kind != "" else ("full" if size.x >= 1000.0 else "half")
		_open_sheet(content, locked)
		return
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal_sheet.add_theme_stylebox_override("panel", _parchment)
	_grab.visible = false
	_dim.color = Color(0, 0, 0, 0.5)
	_modal_close.offset_left = -34
	_modal_close.offset_right = 20
	_modal_close.offset_top = -20
	_modal_close.offset_bottom = 34
	_style_button(_modal_close, Color(0.85, 0.26, 0.16), 10, Color.WHITE, 3)
	# Windows were laid out for landscape. In portrait they take the screen's width and grow
	# taller, so their containers reflow; whatever still does not fit shrinks (below).
	var screen := get_viewport().get_visible_rect().size
	if screen.y > screen.x and size.x > screen.x - 24.0:
		size = Vector2(screen.x - 24.0, minf(size.y * 1.35, screen.y - 200.0))
	_modal_sheet.self_modulate.a = 0.0 if bare else 1.0
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_modal_body.add_theme_constant_override(side, 0 if bare else 16)
	_modal_close.visible = not locked
	for child in _modal_body.get_children():
		child.queue_free()
	_modal_body.add_child(content)
	_modal.offset_left = -size.x / 2.0
	_modal.offset_right = size.x / 2.0
	_modal.offset_top = -size.y / 2.0
	_modal.offset_bottom = size.y / 2.0
	# Windows were drawn for landscape; in portrait they shrink to fit the screen.
	_modal.scale = Vector2.ONE
	_dim.visible = true
	_modal.visible = true
	_fit_modal()


## A window as a sheet from the bottom: full width, a dark plate with a sand line on top, the
## handle and the close button in its top strip; "full" reaches up under the top bar, "half"
## is as tall as its content (at most about 60% of the screen). It slides up when it opens.
func _open_sheet(content: Control, locked: bool) -> void:
	var sb := UiTheme.box(UiTheme.SHEET, 0, UiTheme.SAND_LINE, 0)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.border_width_top = 1
	_modal_sheet.add_theme_stylebox_override("panel", sb)
	_modal_sheet.self_modulate.a = 1.0
	for side in ["margin_left", "margin_right", "margin_bottom"]:
		_modal_body.add_theme_constant_override(side, 18)
	_modal_body.add_theme_constant_override("margin_top", 46)
	_modal_close.visible = not locked
	_modal_close.offset_left = -70
	_modal_close.offset_right = -16
	_modal_close.offset_top = 8
	_modal_close.offset_bottom = 54
	_style_button(_modal_close, Color(0, 0, 0, 0), 6)
	_grab.visible = true
	for child in _modal_body.get_children():
		child.queue_free()
	_modal_body.add_child(content)
	UiTheme.darken_tree(content)
	var view := get_viewport().get_visible_rect().size
	_modal.anchor_left = 0.0
	_modal.anchor_right = 1.0
	_modal.anchor_bottom = 1.0
	_modal.offset_left = 0.0
	_modal.offset_right = 0.0
	_modal.offset_bottom = 0.0
	_modal.scale = Vector2.ONE
	if _sheet_mode == "full":
		_modal.anchor_top = 0.0
		_modal.offset_top = 150.0
	else:
		_modal.anchor_top = 1.0
		_modal.offset_top = -view.y * 0.5
	_dim.color = Color(0, 0, 0, 0.45 if _sheet_mode == "full" else 0.22)
	_dim.visible = true
	_modal.visible = true
	_fit_modal()


## Some windows need more room than they were given (fixed-width rows): once laid out, the
## window is centred on its real size and shrunk to fit the screen. A half sheet takes its
## content's height instead, and both slide up.
func _fit_modal() -> void:
	for i in 2:
		await get_tree().process_frame
	if not _modal.visible:
		return
	if _sheet_mode != "":
		var view := get_viewport().get_visible_rect().size
		var need := _modal_sheet.get_combined_minimum_size()
		if _sheet_mode == "half":
			_modal.offset_top = -clampf(need.y, 320.0, view.y * 0.62)
		if need.x > view.x:
			# Too wide for the screen: shrink from the bottom-left corner so it fits the width
			# and keeps its full height.
			var k := view.x / need.x
			_modal.offset_right = need.x - view.x
			if _sheet_mode == "full":
				_modal.offset_top = 150.0 - (_modal.size.y / k - _modal.size.y)
			_modal.pivot_offset = Vector2(0.0, _modal.size.y)
			_modal.scale = Vector2.ONE * k
		var top := _modal.offset_top
		var drop := view.y - (_modal.offset_top if _sheet_mode == "half" else 0.0)
		_modal.position.y += minf(drop, 400.0)
		var tw := _modal.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_modal, "offset_top", top, 0.22)
		tw.parallel().tween_property(_modal, "offset_bottom", 0.0, 0.22)
		return
	var screen := get_viewport().get_visible_rect().size
	var real := _modal.size.max(_modal_sheet.get_combined_minimum_size())
	_modal.offset_left = -real.x / 2.0
	_modal.offset_right = real.x / 2.0
	_modal.offset_top = -real.y / 2.0
	_modal.offset_bottom = real.y / 2.0
	_modal.pivot_offset = real / 2.0
	_modal.scale = Vector2.ONE * minf(1.0, minf((screen.x - 24.0) / real.x, (screen.y - 80.0) / real.y))


func hide_modal() -> void:
	_modal_locked = false
	_dim.visible = false
	_modal.visible = false


func modal_open() -> bool:
	return _modal.visible


## Coins or fuel fly from `from` (a screen point) up to their bar.
func fly(from: Vector2, key: String, amount: int) -> void:
	if not UiTheme.on() or not _bars.has(key):
		return
	var target := (_bars[key]["value"] as Label).get_global_rect()
	var to := Vector2(target.end.x + 20.0, target.get_center().y)
	for i in clampi(amount / 40 + 4, 4, 9):
		var icon := TextureRect.new()
		icon.texture = Icons.tex("coin" if key == "coins" else "fuel", 48)
		icon.size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = from + Vector2(randf_range(-26, 26), randf_range(-26, 26)) - icon.size / 2.0
		add_child(icon)
		var p0 := icon.position
		var end := to - icon.size / 2.0
		var mid := (p0 + end) / 2.0 + Vector2(randf_range(-60, 60), -90)
		var tw := icon.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_method(func(k: float) -> void: icon.position = p0.lerp(mid, k).lerp(mid.lerp(end, k), k), 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
		tw.tween_callback(icon.queue_free)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.6


## Shows the building-mode banner with `text`, or hides it when `text` is empty. The bottom
## corners hide while a mode is on.
func show_mode(text: String) -> void:
	_mode.visible = text != ""
	_mode_label.text = text
	if text != "":
		hide_actions()
	_corners_visible(text == "" and not _panel.visible and not _actions.visible)


func blocks(pos: Vector2) -> bool:
	if _dim.visible:
		return true
	for c: Control in [_mode, _panel, _left, _dock, _workers, _actions, _missions, _player, _bars["gems"]["bar"]]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


## A label in dark ink for the parchment window (no outline).
static func ink(parent: Control, text: String, size: int, color: Color = INK) -> Label:
	var l := make_label(parent, text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l


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
	if UiTheme.on():
		_style_button(b, UiTheme.CARD, 6, UiTheme.SAND_LINE, 1)
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
