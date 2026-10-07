class_name StoreUI
extends RefCounted
## The gem shop window (approved sketch WqAsDumRoAXDrToDiHBMDn, layout A): everything in one
## scroll on the parchment: the starter pack banner with Noa, five gem packs, cosmetics, and free
## gems. See Store for the items and rules.

const CARD := Color(0.85, 0.82, 0.75)
const LINE := Color(0.73, 0.69, 0.6)
const MUTED := Color(0.42, 0.4, 0.33)
const GREEN := Color(0.25, 0.63, 0.35)
const BLUE := Color(0.18, 0.44, 0.69)
const GREY := Color(0.64, 0.62, 0.55)
const OLIVE := Color(0.18, 0.23, 0.15)
const GOLD := Color(0.91, 0.64, 0.12)


## `on_real(product)` asks to pay real money for a pack or the starter pack; `on_gems(id)` buys a
## cosmetic with gems; `on_wear(id)` puts an owned cosmetic on or takes it off.
static func window(on_real: Callable, on_gems: Callable, on_wear: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var title := HomeHud.ink(box, I18n.t("Store"), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_starter(on_real))
	_section(list, I18n.t("Gems"), I18n.t("For speed-ups, a third worker and cosmetics"))
	var packs := HBoxContainer.new()
	packs.add_theme_constant_override("separation", 10)
	list.add_child(packs)
	for p: Dictionary in Store.PACKS:
		packs.add_child(_pack(p, on_real))
	_section(list, I18n.t("Cosmetics"), I18n.t("Changes only how it looks"))
	var looks := HBoxContainer.new()
	looks.add_theme_constant_override("separation", 10)
	list.add_child(looks)
	for id: String in Store.COSMETIC_ORDER:
		looks.add_child(_cosmetic(id, on_gems, on_wear))
	_section(list, I18n.t("Free gems"), "")
	list.add_child(_free())
	return box


## The one-time starter pack: Noa, what is inside, the old price and the price.
static func _starter(on_real: Callable) -> Control:
	var panel := PanelContainer.new()
	var style := HomeHud._box(OLIVE, 14, GOLD, 3)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var noa := TextureRect.new()
	noa.texture = load("res://assets/textures/noa/noa_wink.webp")
	noa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	noa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	noa.custom_minimum_size = Vector2(104, 120)
	row.add_child(noa)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	HomeHud.make_label(words, I18n.t("Starter pack") + "  ·  " + I18n.t("one time only"), 26, Color(1.0, 0.84, 0.42))
	HomeHud.make_label(words, I18n.t("Noa: \"Worth seven times the price. Only once!\""), 17, Color(0.82, 0.85, 0.75))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	words.add_child(chips)
	for k: Array in [["gem", Store.STARTER["gems"]], ["coin", Store.STARTER["coins"]], ["fuel", Store.STARTER["fuel"]]]:
		chips.add_child(Icons.rect(k[0], 24))
		HomeHud.make_label(chips, HomeHud._thousands(int(k[1])), 20)
	HomeHud.make_label(chips, "+ " + I18n.t("Gold Flag"), 20, Color(1.0, 0.84, 0.42))
	var buy := VBoxContainer.new()
	buy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buy)
	if GameState.starter_bought:
		_button(buy, I18n.t("Bought ✓"), GREY).disabled = true
	else:
		var was := HomeHud.make_label(buy, I18n.t("Instead of %s") % Store.price(Store.STARTER, true), 16, Color(0.75, 0.78, 0.68))
		was.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(buy, Store.price(Store.STARTER), GREEN).pressed.connect(func() -> void: on_real.call(Store.STARTER["id"]))
	return panel


static func _section(parent: Control, title: String, note: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	HomeHud.ink(row, title, 23)
	if note != "":
		var n := HomeHud.ink(row, note, 16, MUTED)
		n.size_flags_vertical = Control.SIZE_SHRINK_END


static func _card() -> Array:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := HomeHud._box(CARD, 12, LINE, 2)
	s.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	return [card, v]


## A gem pack: a pile of gems that grows with the pack, the amount, its name and the price.
static func _pack(p: Dictionary, on_real: Callable) -> Control:
	var parts := _card()
	var v: VBoxContainer = parts[1]
	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(0, 104)
	art.add_theme_stylebox_override("panel", HomeHud._box(Color(0.1, 0.27, 0.2), 10))
	v.add_child(art)
	var pile := HFlowContainer.new()
	pile.alignment = FlowContainer.ALIGNMENT_CENTER
	pile.add_theme_constant_override("h_separation", -6)
	pile.add_theme_constant_override("v_separation", -10)
	pile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.add_child(pile)
	var count := 1 + Store.PACKS.find(p) * 3
	for i in count:
		pile.add_child(Icons.rect("gem", 36 if count < 6 else 28))
	if p["ribbon"] != "":
		var r := HomeHud.make_label(art, I18n.t(p["ribbon"]), 14)
		r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		r.add_theme_stylebox_override("normal", HomeHud._box(Color(0.85, 0.28, 0.23) if p["ribbon"] == "Popular" else GOLD, 6))
	var amount := HBoxContainer.new()
	amount.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(amount)
	amount.add_child(Icons.rect("gem", 22))
	HomeHud.ink(amount, HomeHud._thousands(int(p["gems"])), 22)
	var n := HomeHud.ink(v, I18n.t(p["name"]), 15, MUTED)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(v, Store.price(p), GREEN).pressed.connect(func() -> void: on_real.call(p["id"]))
	return parts[0]


## A cosmetic: its picture, name, and Buy (gems) / Wear / Worn / why not.
static func _cosmetic(id: String, on_gems: Callable, on_wear: Callable) -> Control:
	var c: Dictionary = Store.COSMETICS[id]
	var parts := _card()
	var v: VBoxContainer = parts[1]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 116)
	v.add_child(holder)
	var pic := ColorRect.new()
	pic.color = Color(0.56, 0.64, 0.43)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pic)
	if ResourceLoader.exists(Store.picture_path(id)):
		var tex := TextureRect.new()
		tex.texture = load(Store.picture_path(id))
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.add_child(tex)
	var n := HomeHud.ink(v, I18n.t(c["name"]), 18)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if GameState.cosmetics_owned.has(id):
		var worn: bool = GameState.cosmetics_worn.get(c["slot"], "") == id
		var b := _button(v, I18n.t("Worn ✓") if worn else I18n.t("Wear"), GREY if worn else GREEN)
		b.pressed.connect(func() -> void: on_wear.call(id))
	elif int(c["gems"]) <= 0:
		_button(v, I18n.t("In the starter pack"), GREY).disabled = true
	else:
		var b := _button(v, HomeHud._thousands(int(c["gems"])), BLUE)
		b.icon = Icons.tex("gem", 48)
		b.add_theme_constant_override("icon_max_width", 22)
		b.pressed.connect(func() -> void: on_gems.call(id))
	return parts[0]


## Players under 13 are pointed to the missions; older players get short videos once an ad
## network is in.
static func _free() -> Control:
	var box := VBoxContainer.new()
	var note := HomeHud.ink(box, "", 18)
	var s := HomeHud._box(Color(0.906, 0.957, 0.914), 10)
	s.set_content_margin_all(10)
	note.add_theme_stylebox_override("normal", s)
	note.add_theme_color_override("font_color", Color(0.18, 0.42, 0.24))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Cloud.child:
		note.text = I18n.t("Free gems: the daily missions give gems every day, and day 7 of the login gift gives 50.")
	else:
		note.text = I18n.t("Free gems: the daily missions and the login gift. Short videos for %d gems (up to %d a day) are coming soon.") % [Store.VIDEO_GEMS, Store.VIDEOS_PER_DAY]
	return box


static func _button(parent: Control, text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color
		if st == "hover":
			c = color.lightened(0.08)
		elif st == "pressed":
			c = color.darkened(0.1)
		var s := HomeHud._box(c, 10)
		s.border_width_bottom = 4
		s.border_color = c.darkened(0.35)
		if st == "focus":
			s.draw_center = false
			s.border_width_bottom = 0
		b.add_theme_stylebox_override(st, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	parent.add_child(b)
	return b
