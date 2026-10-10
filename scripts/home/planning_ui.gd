class_name PlanningUI
extends RefCounted
## The Planning HQ window (approved sketch 3ybncHdm6sxxuWetMYLJBg, direction B "orders"): saved plan
## slots on top, then one sentence per force, "Tanks: attack [Defenses]". Tapping the marked word
## cycles it through Catalog.PLAN_TARGETS.

const ROW := Color(0.85, 0.82, 0.75)
const LINE := Color(0.73, 0.69, 0.6)
const MUTED := Color(0.42, 0.4, 0.33)
const TARGET := Color(1.0, 0.93, 0.7)
const GREEN := Color(0.4, 0.65, 0.24)
const GREY := Color(0.29, 0.32, 0.27)

## Border color of each order, the same colors as the target badges.
const ORDER_COLORS := {"auto": Color(0.6, 0.66, 0.72), "defense": Color(0.95, 0.3, 0.25),
	"loot": Color(1.0, 0.75, 0.15), "hq": Color(0.3, 0.6, 0.95)}


## `on_slot(i)` opens another plan, `on_cycle(type)` moves a force's order on, `on_rename(i, text)`
## names the open plan.
static func window(slot: int, on_slot: Callable, on_cycle: Callable, on_rename: Callable) -> Control:
	var lvl := GameState.level_of("planning")
	var slots := Catalog.planning_slots(lvl)
	slot = clampi(slot, 0, maxi(slots - 1, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_header(box, lvl, slots)
	box.add_child(_slot_row(slot, slots, on_slot))
	box.add_child(_name_row(slot, on_rename))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)
	var orders := GameState.plan_orders(slot)
	for type: String in Catalog.PLAN_UNITS:
		list.add_child(_order_row(type, str(orders[type]), on_cycle))
	var note := HomeHud.ink(box, I18n.t("A plan applies to every base. The battle uses the plan you opened last."), 18, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return box


static func _header(box: Control, lvl: int, slots: int) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	var pic := ShopUI.picture("planning", lvl)
	pic.custom_minimum_size = Vector2(60, 60)
	pic.clip_contents = true
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	HomeHud.ink(words, "%s  ·  %s" % [Catalog.display_name("planning"), I18n.t("Lv %d") % lvl], 28)
	HomeHud.ink(words, I18n.t("Give each force its order. Higher levels open more plans."), 18, MUTED)
	var count := HomeHud.ink(head, I18n.t("Plans %d") % slots, 22)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _slot_row(slot: int, slots: int, on_slot: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in slots:
		var b := Button.new()
		b.text = GameState.plan_name(i) if GameState.plan_name(i) != "" else I18n.t("Plan %d") % (i + 1)
		b.custom_minimum_size = Vector2(150, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		HomeHud._style_button(b, GREEN if i == slot else GREY, 10, Color(1, 1, 1, 0.6), 2)
		var index := i
		b.pressed.connect(func() -> void:
			Audio.play("click", -6.0)
			on_slot.call(index))
		row.add_child(b)
	return row


static func _name_row(slot: int, on_rename: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	HomeHud.ink(row, I18n.t("Name"), 20, MUTED)
	var edit := LineEdit.new()
	edit.text = GameState.plan_name(slot)
	edit.placeholder_text = I18n.t("Plan %d") % (slot + 1)
	edit.max_length = 14
	edit.custom_minimum_size = Vector2(260, 44)
	edit.add_theme_font_size_override("font_size", 22)
	edit.text_submitted.connect(func(text: String) -> void: on_rename.call(slot, text))
	edit.focus_exited.connect(func() -> void: on_rename.call(slot, edit.text))
	row.add_child(edit)
	return row


## One order: the force's picture, its name, "attacks" and the order word on a button.
static func _order_row(type: String, order: String, on_cycle: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HomeHud._box(ROW, 10, ORDER_COLORS[order], 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var owned := int(GameState.units.get(type, 0)) > 0
	var pic := ShopUI.picture(type, int(GameState.units.get(type, 1)), Color(0.24, 0.29, 0.38))
	pic.custom_minimum_size = Vector2(52, 52)
	pic.clip_contents = true
	row.add_child(pic)
	var name_label := HomeHud.ink(row, Catalog.display_name(type), 26)
	name_label.custom_minimum_size = Vector2(190, 0)
	HomeHud.ink(row, I18n.t("attacks"), 24, MUTED)
	var b := Button.new()
	b.text = Catalog.plan_target_name(order)
	b.custom_minimum_size = Vector2(230, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
	HomeHud._style_button(b, ORDER_COLORS[order].darkened(0.25), 10, TARGET, 3)
	b.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		on_cycle.call(type))
	row.add_child(b)
	if not owned:
		card.modulate = Color(1, 1, 1, 0.55)
	return card
