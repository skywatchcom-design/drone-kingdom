class_name AccountUI
extends RefCounted
## The sign-up, sign-in and password-reset window, in the approved "two steps" look (sketch
## Aoa9vgoFSHQ9wN4f6Vf9aQ, option B): a bright card, Noa in a circle with a speech bubble, white
## rounded fields and a big green button.
## Sign-up has two steps: 1 "who you are" (commander name, birth month and year, asked neutrally)
## and 2 "the account" (an email only from age 13, password twice, agreeing to the terms).
## Sign-in takes an email or a commander name. Fields are checked as the player types; the server
## answer shows under them. There is no way to skip: an account is required to keep playing.

const INK := Color(0.17, 0.16, 0.13)
const MUTED := Color(0.42, 0.4, 0.33)
const GOOD := Color(0.18, 0.49, 0.26)
const BAD := Color(0.75, 0.22, 0.14)
const GREEN := Color(0.25, 0.63, 0.35)
const CARD := Color(0.984, 0.969, 0.925)
const BUBBLE := Color(0.933, 0.953, 0.902)
const CHIP := Color(0.9, 0.875, 0.79)
const FIELD_LINE := Color(0.87, 0.83, 0.72)
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]


## `mode` is "signup", "signin" or "reset". `on_submit(data, mode, window)` does the work (data:
## name, email, password, year, month for sign-up; login and password otherwise) and calls
## show_error(window, text) when it fails; `on_switch(mode)` opens another mode.
static func window(mode: String, on_submit: Callable, on_switch: Callable) -> Control:
	var signup := mode == "signup"
	var card := PanelContainer.new()
	var card_style := HomeHud._box(CARD, 22, Color.WHITE, 4)
	card_style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", card_style)
	card.layout_direction = Control.LAYOUT_DIRECTION_RTL if I18n.rtl() else Control.LAYOUT_DIRECTION_LTR
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var say := _noa(box)

	var f := {}
	var steps := []
	if signup:
		var chips := _chips(box)
		var one := _step(box)
		f["name"] = _field(one, I18n.t("Commander name"), false, "Commander_Noam")
		f["name"].max_length = 14
		f["name_hint"] = _hint_label(one)
		_caption(one, I18n.t("Date of birth"))
		var birth := HBoxContainer.new()
		birth.add_theme_constant_override("separation", 10)
		one.add_child(birth)
		f["month"] = _choice(birth, I18n.t("Month"), MONTHS.map(func(m: String) -> String: return I18n.t(m)))
		var now_year := int(Time.get_date_dict_from_system()["year"])
		var years := []
		for y in range(now_year, now_year - 100, -1):
			years.append(str(y))
		f["year"] = _choice(birth, I18n.t("Year"), years)
		f["birth_hint"] = _hint_label(one)
		var two := _step(box)
		f["email_box"] = VBoxContainer.new()
		f["email_box"].add_theme_constant_override("separation", 4)
		two.add_child(f["email_box"])
		f["email"] = _field(f["email_box"], I18n.t("Email"), false, "name@example.com")
		f["email"].layout_direction = Control.LAYOUT_DIRECTION_LTR
		f["email_hint"] = _hint_label(f["email_box"])
		f["child_note"] = _note(two, I18n.t("Under 13 you don't need an email: you log in with your commander name."))
		var pw := HBoxContainer.new()
		pw.add_theme_constant_override("separation", 12)
		two.add_child(pw)
		for k: String in ["password", "again"]:
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pw.add_child(col)
			f[k] = _field(col, I18n.t("Password") if k == "password" else I18n.t("Password again"), true, "")
			f[k + "_hint"] = _hint_label(col)
		f["terms"] = _terms(two)
		steps = [one, two]
		f["chips"] = chips
	else:
		var only := _step(box)
		if mode == "reset":
			f["login"] = _field(only, I18n.t("Email"), false, "name@example.com")
			f["login"].layout_direction = Control.LAYOUT_DIRECTION_LTR
			_note(only, I18n.t("Players under 13 have no email: a parent can write to %s and we will help.") % Cloud.SUPPORT_EMAIL).add_theme_color_override("font_color", MUTED)
		else:
			f["login"] = _field(only, I18n.t("Email or commander name"), false, "")
			f["password"] = _field(only, I18n.t("Password"), true, "")
			_hint_label(only).text = I18n.t("Players under 13 log in with their commander name.")
			var forgot := _link(only, I18n.t("Forgot your password?"))
			forgot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			forgot.pressed.connect(func() -> void: on_switch.call("reset"))

	var error := HomeHud.ink(box, "", 18, BAD)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var back := _button(row, I18n.t("Back"), Color(0.925, 0.898, 0.81), MUTED, 0.0)
	back.visible = false
	var go := _button(row, "", GREEN, Color.WHITE, 1.0)
	var alt := _link(box, I18n.t("I already have a base  ·  Log in") if mode != "signin" else I18n.t("New here?  ·  Sign up"))
	alt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	alt.pressed.connect(func() -> void: on_switch.call("signup" if mode == "signin" else "signin"))

	var state := {"step": 0}
	var refresh := func() -> bool:
		var ok := false
		if signup:
			var r := _check_signup(f)
			var on_one: bool = state["step"] == 0
			steps[0].visible = on_one
			steps[1].visible = not on_one
			back.visible = not on_one
			_set_chips(f["chips"], int(state["step"]))
			say.text = I18n.t("Hi! Two quick steps and your base is saved.") if on_one else I18n.t("Great! Now a password, and we're ready.")
			go.text = I18n.t("Continue") if on_one else I18n.t("Save my base")
			ok = r["one"] if on_one else r["all"]
		elif mode == "reset":
			say.text = I18n.t("Enter the email of your base and we will send a link to choose a new password.")
			go.text = I18n.t("Send me a link")
			ok = f["login"].text.strip_edges() != ""
		else:
			say.text = I18n.t("Welcome back, Commander! The base saved in the cloud replaces the one on this device.")
			go.text = I18n.t("Log in")
			ok = f["login"].text.strip_edges() != "" and f["password"].text != ""
		go.disabled = not ok
		return ok
	for key in f:
		var c = f[key]
		if c is LineEdit:
			c.text_changed.connect(func(_t: String) -> void: refresh.call())
		elif c is OptionButton:
			c.item_selected.connect(func(_i: int) -> void: refresh.call())
		elif c is CheckBox:
			c.toggled.connect(func(_on: bool) -> void: refresh.call())
	back.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		state["step"] = 0
		error.text = ""
		refresh.call())
	go.pressed.connect(func() -> void:
		if not refresh.call():
			return
		Audio.play("click", -6.0)
		if signup and state["step"] == 0:
			state["step"] = 1
			refresh.call()
			return
		var data := {"password": f["password"].text if f.has("password") else ""}
		if signup:
			data["name"] = f["name"].text.strip_edges()
			data["email"] = f["email"].text.strip_edges() if f["email_box"].visible else ""
			data["year"] = int(f["year"].get_item_text(f["year"].selected))
			data["month"] = f["month"].selected
		else:
			data["login"] = f["login"].text.strip_edges()
		on_submit.call(data, mode, card))
	card.set_meta("error", error)
	card.set_meta("submit", go)
	card.set_meta("refresh", refresh)
	refresh.call()
	return card


## Checks every sign-up field and shows a hint under each. {one: step 1 is fine, all: all is}.
## The email shows until the birth date says the player is under 13; then a note replaces it.
static func _check_signup(f: Dictionary) -> Dictionary:
	var n: String = f["name"].text.strip_edges()
	var why := Cloud.name_problem(n) if n != "" else ""
	_hint(f["name_hint"], I18n.t("3–14 letters, digits or _") if n == "" else (why if why != "" else "✓"), why != "")
	var name_ok := n != "" and why == ""
	var born: bool = f["month"].selected > 0 and f["year"].selected > 0
	var age := Cloud.age(int(f["year"].get_item_text(f["year"].selected)), f["month"].selected) if born else -1
	_hint(f["birth_hint"], "" if born else I18n.t("Pick a month and a year"), false)
	var child := born and age < Cloud.EMAIL_AGE
	f["email_box"].visible = not child
	f["child_note"].visible = child
	var email_ok := child
	if not child:
		var e: String = f["email"].text.strip_edges()
		var bad := Cloud.email_problem(e) if e != "" else ""
		_hint(f["email_hint"], I18n.t("For password recovery only") if e == "" else (bad if bad != "" else "✓"), bad != "")
		email_ok = e != "" and bad == ""
	var p: String = f["password"].text
	_hint(f["password_hint"], I18n.t("At least 6 characters") if p == "" else (I18n.t("Too short") if p.length() < 6 else "✓"), p != "" and p.length() < 6)
	var a: String = f["again"].text
	_hint(f["again_hint"], "" if a == "" else ("✓" if a == p else I18n.t("The passwords don't match")), a != "" and a != p)
	var pass_ok := p.length() >= 6 and a == p
	return {"one": name_ok and born, "all": name_ok and born and email_ok and pass_ok and f["terms"].button_pressed}


static func _hint(label: Label, text: String, bad: bool) -> void:
	label.text = text
	label.add_theme_color_override("font_color", BAD if bad else (GOOD if text == "✓" else MUTED))


## Shows what went wrong under the fields and lets the player try again.
static func show_error(window: Control, text: String) -> void:
	(window.get_meta("refresh") as Callable).call()
	(window.get_meta("error") as Label).text = text


static func set_busy(window: Control) -> void:
	(window.get_meta("error") as Label).text = ""
	var go := window.get_meta("submit") as Button
	go.disabled = true
	go.text = I18n.t("One moment...")


# ---------------------------------------------------------------- pieces

## Noa in a circle beside her speech bubble; returns the bubble's label.
static func _noa(parent: Control) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var bubble := PanelContainer.new()
	var bs := HomeHud._box(BUBBLE, 16)
	bs.set_content_margin_all(14)
	bubble.add_theme_stylebox_override("panel", bs)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bubble)
	var say := HomeHud.ink(bubble, "", 20, Color(0.21, 0.27, 0.17))
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ring := Panel.new()
	ring.custom_minimum_size = Vector2(92, 92)
	ring.add_theme_stylebox_override("panel", HomeHud._box(Color(0.85, 0.81, 0.68), 46, Color(0.91, 0.64, 0.12), 4))
	ring.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	row.add_child(ring)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/textures/noa/noa_smile.webp")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_bottom = 30
	ring.add_child(pic)
	return say


## The "1 · Who you are" and "2 · The account" chips.
static func _chips(parent: Control) -> Array:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var chips := []
	for i in 2:
		if i == 1:
			var dash := ColorRect.new()
			dash.color = CHIP
			dash.custom_minimum_size = Vector2(48, 4)
			dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dash)
		var chip := Label.new()
		chip.text = "1 · " + I18n.t("Who you are") if i == 0 else "2 · " + I18n.t("The account")
		chip.add_theme_font_size_override("font_size", 17)
		row.add_child(chip)
		chips.append(chip)
	return chips


static func _set_chips(chips: Array, step: int) -> void:
	for i in chips.size():
		var on := i == step
		var s := HomeHud._box(GREEN if on else CHIP, 16)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		(chips[i] as Label).add_theme_stylebox_override("normal", s)
		(chips[i] as Label).add_theme_color_override("font_color", Color.WHITE if on else Color(0.48, 0.45, 0.37))


static func _step(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	return v


static func _caption(parent: Control, text: String) -> Label:
	return HomeHud.ink(parent, text, 19, INK)


static func _hint_label(parent: Control) -> Label:
	return HomeHud.ink(parent, "", 15, MUTED)


static func _note(parent: Control, text: String) -> Label:
	var l := HomeHud.ink(parent, text, 18, GOOD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var s := HomeHud._box(Color(0.906, 0.957, 0.914), 12)
	s.set_content_margin_all(10)
	l.add_theme_stylebox_override("normal", s)
	return l


static func _field(parent: Control, label: String, secret: bool, placeholder: String) -> LineEdit:
	_caption(parent, label)
	var e := LineEdit.new()
	e.secret = secret
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 52)
	e.add_theme_font_size_override("font_size", 23)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.6, 0.58, 0.5))
	e.add_theme_color_override("caret_color", GREEN)
	var normal := HomeHud._box(Color.WHITE, 14, FIELD_LINE, 2)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	e.add_theme_stylebox_override("normal", normal)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = GREEN
	focus.set_border_width_all(3)
	e.add_theme_stylebox_override("focus", focus)
	parent.add_child(e)
	return e


## A drop-down in the same white rounded look, whose first item is the empty prompt.
static func _choice(parent: Control, prompt: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	o.add_item(prompt)
	for it in items:
		o.add_item(str(it))
	o.select(0)
	o.custom_minimum_size = Vector2(0, 52)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 21)
	o.get_popup().add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		o.add_theme_color_override(c, INK)
	var normal := HomeHud._box(Color.WHITE, 14, FIELD_LINE, 2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	# Right-to-left drop-downs draw with the "_mirrored" styles, so both sets get the look.
	for st in ["normal", "hover", "pressed", "focus", "normal_mirrored", "hover_mirrored", "pressed_mirrored"]:
		var s := normal.duplicate() as StyleBoxFlat
		if not st.begins_with("normal"):
			s.border_color = GREEN
		o.add_theme_stylebox_override(st, s)
	parent.add_child(o)
	return o


## The terms checkbox with links to the terms of use and the privacy policy (in the language).
static func _terms(parent: Control) -> CheckBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var box := CheckBox.new()
	box.text = I18n.t("I have read and agree to the")
	box.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		box.add_theme_color_override(c, INK)
	row.add_child(box)
	_link(row, I18n.t("Terms of Use"), 18).pressed.connect(func() -> void: OS.shell_open(Cloud.TERMS_URL % I18n.lang))
	HomeHud.ink(row, I18n.t("and the"), 18)
	_link(row, I18n.t("Privacy Policy"), 18).pressed.connect(func() -> void: OS.shell_open(Cloud.PRIVACY_URL % I18n.lang))
	return box


## A big rounded button with a darker edge under it; `grow` 1 takes the free width.
static func _button(parent: Control, text: String, color: Color, font: Color, grow: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if grow > 0.0 else Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 25)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color
		if st == "hover":
			c = color.lightened(0.08)
		elif st == "pressed":
			c = color.darkened(0.1)
		elif st == "disabled":
			c = color.lerp(Color(0.78, 0.8, 0.74), 0.65)
		var s := HomeHud._box(c, 16)
		s.border_width_bottom = 6
		s.border_color = c.darkened(0.35)
		if st == "focus":
			s.draw_center = false
			s.border_width_bottom = 0
		b.add_theme_stylebox_override(st, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, font)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.85) if font == Color.WHITE else font)
	parent.add_child(b)
	return b


static func _link(parent: Control, text: String, size: int = 19) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.18, 0.43, 0.69))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.3, 0.55))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.3, 0.55))
	parent.add_child(b)
	return b
