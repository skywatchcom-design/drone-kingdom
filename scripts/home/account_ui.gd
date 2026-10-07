class_name AccountUI
extends RefCounted
## The sign-up and sign-in window (approved sketch Tnvwhfaq4KMqSS85z45tfx, owner 7.10.2026) in the
## parchment style. Sign-up: commander name, birth month and year (asked neutrally, nothing hints
## at an age limit), an email only from age 13, password twice, and agreeing to the terms and
## privacy policy. Sign-in: email or commander name, and password. Fields are checked as the
## player types; the server answer shows under them. There is no way to skip: an account is
## required to keep playing.

const MUTED := Color(0.42, 0.4, 0.33)
const GOOD := Color(0.2, 0.5, 0.2)
const BAD := Color(0.75, 0.22, 0.14)
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]


## `mode` is "signup" or "signin". `on_submit(data, mode, window)` does the work (data:
## name, email, password, year, month for sign-up; login, password for sign-in) and calls
## show_error(window, text) when it fails; `on_switch(mode)` flips between the two.
static func window(mode: String, on_submit: Callable, on_switch: Callable) -> Control:
	var signup := mode == "signup"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_header(box, mode)

	var f := {}
	if signup:
		var top := _columns(box)
		f["name"] = _field(top[0], I18n.t("Commander name"), false)
		f["name"].max_length = 14
		f["name_hint"] = HomeHud.ink(top[0], "", 15, MUTED)
		HomeHud.ink(top[1], I18n.t("Date of birth"), 19)
		var birth := HBoxContainer.new()
		birth.add_theme_constant_override("separation", 8)
		top[1].add_child(birth)
		f["month"] = _choice(birth, I18n.t("Month"), MONTHS.map(func(m: String) -> String: return I18n.t(m)))
		var now_year := int(Time.get_date_dict_from_system()["year"])
		var years := []
		for y in range(now_year, now_year - 100, -1):
			years.append(str(y))
		f["year"] = _choice(birth, I18n.t("Year"), years)
		f["birth_hint"] = HomeHud.ink(top[1], "", 15, MUTED)
		f["email_box"] = VBoxContainer.new()
		f["email_box"].add_theme_constant_override("separation", 2)
		box.add_child(f["email_box"])
		f["email"] = _field(f["email_box"], I18n.t("Email"), false)
		f["email"].layout_direction = Control.LAYOUT_DIRECTION_LTR
		f["email_hint"] = HomeHud.ink(f["email_box"], "", 15, MUTED)
		f["child_note"] = HomeHud.ink(box, I18n.t("Under 13 you don't need an email: you log in with your commander name."), 16, GOOD)
		f["child_note"].visible = false
		var pw := _columns(box)
		f["password"] = _field(pw[0], I18n.t("Password"), true)
		f["pass_hint"] = HomeHud.ink(pw[0], "", 15, MUTED)
		f["again"] = _field(pw[1], I18n.t("Password again"), true)
		f["again_hint"] = HomeHud.ink(pw[1], "", 15, MUTED)
		f["terms"] = _terms(box)
	elif mode == "reset":
		f["login"] = _field(box, I18n.t("Email"), false)
		f["login"].layout_direction = Control.LAYOUT_DIRECTION_LTR
		var note := HomeHud.ink(box, I18n.t("Players under 13 have no email: a parent can write to %s and we will help.") % Cloud.SUPPORT_EMAIL, 16, MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f["password"] = LineEdit.new()
	else:
		f["login"] = _field(box, I18n.t("Email or commander name"), false)
		f["password"] = _field(box, I18n.t("Password"), true)
		HomeHud.ink(box, I18n.t("Players under 13 log in with their commander name."), 15, MUTED)
		_link(box, I18n.t("Forgot your password?"), 18).pressed.connect(func() -> void: on_switch.call("reset"))

	var error := HomeHud.ink(box, "", 17, BAD)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.set_meta("error", error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var go := Button.new()
	go.text = I18n.t("Save my base") if signup else (I18n.t("Send me a link") if mode == "reset" else I18n.t("Log in"))
	go.custom_minimum_size = Vector2(240, 56)
	go.add_theme_font_size_override("font_size", 24)
	HomeHud._style_button(go, Color(0.25, 0.63, 0.35), 12, Color.WHITE, 3)
	row.add_child(go)
	box.set_meta("submit", go)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_link(row, I18n.t("I already have a base  ·  Log in") if mode != "signin" else I18n.t("New here?  ·  Sign up")).pressed.connect(
		func() -> void: on_switch.call("signup" if mode == "signin" else "signin"))

	var check := func() -> bool:
		var ok: bool = _check_signup(f) if signup else (f["login"].text.strip_edges() != "" and (mode == "reset" or f["password"].text != ""))
		go.disabled = not ok
		return ok
	for key in f:
		var c = f[key]
		if c is LineEdit:
			c.text_changed.connect(func(_t: String) -> void: check.call())
		elif c is OptionButton:
			c.item_selected.connect(func(_i: int) -> void: check.call())
		elif c is CheckBox:
			c.toggled.connect(func(_on: bool) -> void: check.call())
	check.call()
	go.pressed.connect(func() -> void:
		if not check.call():
			return
		Audio.play("click", -6.0)
		var data := {"password": f["password"].text}
		if signup:
			data["name"] = f["name"].text.strip_edges()
			data["email"] = f["email"].text.strip_edges() if f["email_box"].visible else ""
			data["year"] = int(f["year"].get_item_text(f["year"].selected))
			data["month"] = f["month"].selected
		else:
			data["login"] = f["login"].text.strip_edges()
		on_submit.call(data, mode, box))
	return box


## Checks every sign-up field, shows a hint under each, and shows the email only from 13.
static func _check_signup(f: Dictionary) -> bool:
	var ok := true
	var n: String = f["name"].text.strip_edges()
	var why := Cloud.name_problem(n) if n != "" else ""
	_hint(f["name_hint"], why if why != "" else ("" if n == "" else "✓"), why != "")
	ok = ok and n != "" and why == ""

	var born: bool = f["month"].selected > 0 and f["year"].selected > 0
	var age := Cloud.age(int(f["year"].get_item_text(f["year"].selected)), f["month"].selected) if born else -1
	_hint(f["birth_hint"], "" if born else I18n.t("Pick a month and a year"), false)
	ok = ok and born
	# The email shows until the birth date says the player is under 13; then a note replaces it.
	var child := born and age < Cloud.EMAIL_AGE
	f["email_box"].visible = not child
	f["child_note"].visible = child
	if born and not child:
		var e: String = f["email"].text.strip_edges()
		var bad := Cloud.email_problem(e) if e != "" else ""
		_hint(f["email_hint"], bad if bad != "" else (I18n.t("For password recovery only") if e == "" else "✓"), bad != "")
		ok = ok and e != "" and bad == ""

	var p: String = f["password"].text
	_hint(f["pass_hint"], I18n.t("Too short") if p != "" and p.length() < 6 else (I18n.t("At least 6 characters") if p == "" else "✓"), p != "" and p.length() < 6)
	ok = ok and p.length() >= 6
	var a: String = f["again"].text
	_hint(f["again_hint"], "" if a == "" else ("✓" if a == p else I18n.t("The passwords don't match")), a != "" and a != p)
	ok = ok and a == p and a != ""
	return ok and f["terms"].button_pressed


static func _hint(label: Label, text: String, bad: bool) -> void:
	label.text = text
	label.add_theme_color_override("font_color", BAD if bad else (GOOD if text == "✓" else MUTED))


## Shows what went wrong under the fields and lets the player try again.
static func show_error(window: Control, text: String) -> void:
	(window.get_meta("error") as Label).text = text
	var go := window.get_meta("submit") as Button
	go.disabled = false
	go.text = I18n.t("Try again")


static func set_busy(window: Control) -> void:
	(window.get_meta("error") as Label).text = ""
	var go := window.get_meta("submit") as Button
	go.disabled = true
	go.text = I18n.t("One moment...")


static func _header(box: Control, mode: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/textures/noa/noa_smile.webp")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(72, 72)
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	head.add_child(words)
	var title := {"signup": "Save your base", "signin": "Log in to your base", "reset": "Forgot your password?"}
	var say := {"signup": "Noa: \"Let's save your base so nobody takes it from you.\"",
		"signin": "The base saved in the cloud replaces the one on this device.",
		"reset": "Enter the email of your base and we will send a link to choose a new password."}
	HomeHud.ink(words, I18n.t(title[mode]), 30)
	var line := HomeHud.ink(words, I18n.t(say[mode]), 17, MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Two side-by-side columns.
static func _columns(parent: Control) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var cols := []
	for i in 2:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
		cols.append(c)
	return cols


## The terms checkbox with links to the terms of use and the privacy policy (in the language).
static func _terms(parent: Control) -> CheckBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var box := CheckBox.new()
	box.text = I18n.t("I have read and agree to the")
	box.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		box.add_theme_color_override(c, HomeHud.INK)
	row.add_child(box)
	_link(row, I18n.t("Terms of Use"), 18).pressed.connect(func() -> void: OS.shell_open(Cloud.TERMS_URL % I18n.lang))
	HomeHud.ink(row, I18n.t("and the"), 18)
	_link(row, I18n.t("Privacy Policy"), 18).pressed.connect(func() -> void: OS.shell_open(Cloud.PRIVACY_URL % I18n.lang))
	return box


static func _field(parent: Control, label: String, secret: bool) -> LineEdit:
	HomeHud.ink(parent, label, 19)
	var e := LineEdit.new()
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 46)
	e.add_theme_font_size_override("font_size", 22)
	e.add_theme_color_override("font_color", HomeHud.INK)
	var style := HomeHud._box(Color(1.0, 0.99, 0.95), 10, Color(0.72, 0.69, 0.6), 2)
	style.set_content_margin_all(8)
	e.add_theme_stylebox_override("normal", style)
	var focus := HomeHud._box(Color(1.0, 0.99, 0.95), 10, Color(0.95, 0.7, 0.2), 3)
	focus.set_content_margin_all(8)
	e.add_theme_stylebox_override("focus", focus)
	parent.add_child(e)
	return e


## A drop-down whose first item is the empty prompt.
static func _choice(parent: Control, prompt: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	o.add_item(prompt)
	for it in items:
		o.add_item(str(it))
	o.select(0)
	o.custom_minimum_size = Vector2(0, 46)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 20)
	o.get_popup().add_theme_font_size_override("font_size", 22)
	parent.add_child(o)
	return o


static func _link(parent: Control, text: String, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.2, 0.43, 0.66))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.3, 0.55))
	parent.add_child(b)
	return b
