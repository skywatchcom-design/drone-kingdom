class_name DefenseUI
extends RefCounted
## What happened to the base while the player was away (approved sketch NW7rzSLQsYyZ2g54BgcdTx,
## owner's pick A+C, 15.10.2026): Noa's welcome-back window, the defense log, and from each log row
## the damage map on the base itself (home._show_damage_map). A replay may come later.

const MUTED := Color(0.42, 0.4, 0.33)
const LOST := Color(0.96, 0.86, 0.83)
const HELD := Color(0.86, 0.94, 0.81)
const LINE := Color(0.73, 0.69, 0.6)


## Noa tells the player about `attacks` (newest first, as the server sends them) and what they cost
## (`lost` = {coins, fuel} actually taken off the bank).
static func welcome(attacks: Array, lost: Dictionary, on_log: Callable, on_continue: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var face := TextureRect.new()
	face.texture = load("res://assets/textures/noa/noa_serious.webp")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.custom_minimum_size = Vector2(220, 0)
	face.clip_contents = true
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	HomeHud.ink(col, I18n.t("While you were away, Commander"), 32)
	var held := 0
	var trophies := 0
	var trap_hits := 0
	for a: Dictionary in attacks:
		if int(a.get("stars", 0)) == 0:
			held += 1
		trophies += int(a.get("trophies", 0))
		for t in (a.get("report", {}) as Dictionary).get("traps", []):
			trap_hits += int(t.get("hits", 0))
	var line := I18n.t("They attacked us once.") if attacks.size() == 1 else I18n.t("They attacked us %d times.") % attacks.size()
	if held == attacks.size():
		line += " " + I18n.t("We held every time!")
	elif held > 0:
		line += " " + I18n.t("We held %d.") % held
	if trap_hits > 0:
		line += " " + I18n.t("Our traps caught %d attackers!") % trap_hits
	var say := HomeHud.ink(col, line, 22)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var taken := HBoxContainer.new()
	taken.add_theme_constant_override("separation", 8)
	col.add_child(taken)
	HomeHud.ink(taken, I18n.t("Taken:"), 22, MUTED)
	_amounts(taken, int(lost.get("coins", 0)), int(lost.get("fuel", 0)), trophies, 24)
	if Cloud.shield_left() > 0.0:
		var shield := HBoxContainer.new()
		shield.add_theme_constant_override("separation", 8)
		col.add_child(shield)
		shield.add_child(Icons.rect("shield", 26))
		HomeHud.ink(shield, I18n.t("Shield on for %s. Attacking someone ends it.") % HomeHud.clock(Cloud.shield_left()), 18, MUTED)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	_button(buttons, I18n.t("Defense log"), Color(0.95, 0.71, 0.2), Color(0.16, 0.12, 0.0)).pressed.connect(on_log)
	_button(buttons, I18n.t("Continue"), Color(0.25, 0.63, 0.35), Color.WHITE).pressed.connect(on_continue)
	return row


## The last attacks, newest first: who, when, stars, what was taken, trophies, and "View" for the
## damage map. `rows` null means there was no connection; a String is shown instead of the list.
static func log_window(rows: Variant, on_view: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(Icons.rect("shield", 40))
	HomeHud.ink(head, I18n.t("Defense log"), 30)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	if Cloud.signed_in():
		head.add_child(Icons.rect("trophy", 30))
		HomeHud.ink(head, "%d  ·  %s" % [Cloud.trophies, Pvp.league_name(Cloud.trophies)], 22)
	if Cloud.shield_left() > 0.0:
		head.add_child(Icons.rect("shield", 30))
		HomeHud.ink(head, HomeHud.clock(Cloud.shield_left()), 22, Color(0.18, 0.4, 0.8))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if rows is String:
		HomeHud.ink(list, rows, 22, MUTED)
	elif rows == null:
		HomeHud.ink(list, I18n.t("No connection. Try again in a moment."), 22, MUTED)
	elif (rows as Array).is_empty():
		var none := HomeHud.ink(list, I18n.t("Nobody has attacked your base yet. Bases from Command Tower 2 can be attacked."), 22, MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		for a: Dictionary in rows:
			list.add_child(_row(a, on_view))
	return box


static func _row(a: Dictionary, on_view: Callable) -> Control:
	var won := int(a.get("stars", 0)) > 0
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HomeHud._box(LOST if won else HELD, 10, LINE, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	HomeHud.ink(words, str(a.get("attacker_name", "?")), 24)
	var when := ago(Cloud.seconds_since(str(a.get("created_at", ""))))
	HomeHud.ink(words, "%s  ·  %s  ·  %d%%" % [when, I18n.t("They broke in") if won else I18n.t("The base held"), int(a.get("percent", 0))], 17, MUTED)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 2)
	row.add_child(stars)
	for i in 3:
		var s := Icons.rect("star", 30)
		if i >= int(a.get("stars", 0)):
			s.modulate = Color(0.3, 0.3, 0.3, 0.35)
		stars.add_child(s)
	var amounts := HBoxContainer.new()
	amounts.add_theme_constant_override("separation", 6)
	amounts.custom_minimum_size.x = 300
	row.add_child(amounts)
	_amounts(amounts, int(a.get("coins", 0)), int(a.get("fuel", 0)), int(a.get("trophies", 0)), 20)
	_button(row, I18n.t("View"), Color(0.43, 0.48, 0.35), Color.WHITE).pressed.connect(func() -> void: on_view.call(a))
	return card


## -coins, -fuel and the trophy change, each with its icon.
static func _amounts(parent: Control, coins: int, fuel: int, trophies: int, size: int) -> void:
	parent.add_child(Icons.rect("coin", size + 4))
	HomeHud.ink(parent, ("-" if coins > 0 else "") + HomeHud._thousands(coins), size)
	parent.add_child(Icons.rect("fuel", size + 4))
	HomeHud.ink(parent, ("-" if fuel > 0 else "") + HomeHud._thousands(fuel), size)
	parent.add_child(Icons.rect("trophy", size + 4))
	HomeHud.ink(parent, ("+%d" if trophies > 0 else "%d") % trophies, size, ShopUI.GOOD if trophies > 0 else (ShopUI.BAD if trophies < 0 else HomeHud.INK))


## "5 minutes ago", "3 hours ago", "2 days ago".
static func ago(seconds: float) -> String:
	if seconds < 3600.0:
		return I18n.t("%d minutes ago") % maxi(1, int(seconds / 60.0))
	if seconds < 86400.0:
		return I18n.t("%d hours ago") % int(seconds / 3600.0)
	if seconds < 2.0 * 86400.0:
		return I18n.t("Yesterday")
	return I18n.t("%d days ago") % int(seconds / 86400.0)


static func _button(parent: Control, text: String, color: Color, font: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 54)
	b.add_theme_font_size_override("font_size", 22)
	HomeHud._style_button(b, color, 12, Color(1, 1, 1, 0.7), 2)
	if font != Color.WHITE:
		# Dark words on a light button, without the usual black outline.
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(key, font)
		b.add_theme_constant_override("outline_size", 0)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	parent.add_child(b)
	return b
