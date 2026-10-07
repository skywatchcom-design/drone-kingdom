class_name AccountUI
extends RefCounted
## The sign-up and sign-in window (approved sketch Tnvwhfaq4KMqSS85z45tfx) in the parchment style:
## Noa asks the player to save the base with a commander name and a password (no email).
## Sign-up checks the fields as the player types; the server answer shows under the button.

const MUTED := Color(0.42, 0.4, 0.33)
const GOOD := Color(0.2, 0.5, 0.2)
const BAD := Color(0.75, 0.22, 0.14)


## `mode` is "signup" or "signin". `on_submit(name, password, mode, window)` does the work and
## calls show_error(window, text) when it fails; `on_switch(mode)` flips. There is no way to skip:
## an account is required to keep playing (owner, 7.10.2026).
static func window(mode: String, on_submit: Callable, on_switch: Callable) -> Control:
	var signup := mode == "signup"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/textures/noa/noa_smile.webp")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(96, 96)
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	HomeHud.ink(words, I18n.t("Save your base") if signup else I18n.t("Log in to your base"), 32)
	var line := HomeHud.ink(words, I18n.t("Noa: \"Great work! Now let's save your base so nobody takes it from you. No email, no phone.\"") if signup
		else I18n.t("Enter your commander name and password. The base saved in the cloud replaces the one on this device."), 18, MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var name_edit := _field(box, I18n.t("Commander name"), false)
	name_edit.max_length = 14
	var name_hint := HomeHud.ink(box, I18n.t("3–14 letters, digits or _") if signup else "", 16, MUTED)
	var pass_edit := _field(box, I18n.t("Password"), true)
	var pass_hint := HomeHud.ink(box, I18n.t("At least 6 characters") if signup else "", 16, MUTED)
	var again_edit: LineEdit = null
	var again_hint: Label = null
	if signup:
		again_edit = _field(box, I18n.t("Password again"), true)
		again_hint = HomeHud.ink(box, "", 16, MUTED)

	var error := HomeHud.ink(box, "", 18, BAD)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.set_meta("error", error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var go := Button.new()
	go.text = I18n.t("Save my base") if signup else I18n.t("Log in")
	go.custom_minimum_size = Vector2(240, 60)
	go.add_theme_font_size_override("font_size", 26)
	HomeHud._style_button(go, Color(0.25, 0.63, 0.35), 12, Color.WHITE, 3)
	row.add_child(go)
	box.set_meta("submit", go)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_link(row, I18n.t("I already have a base  ·  Log in") if signup else I18n.t("New here?  ·  Sign up")).pressed.connect(
		func() -> void: on_switch.call("signin" if signup else "signup"))

	var check := func() -> bool:
		var ok := true
		var n := name_edit.text.strip_edges()
		if signup:
			var why := Cloud.name_problem(n) if n != "" else ""
			name_hint.text = why if why != "" else (I18n.t("3–14 letters, digits or _") if n == "" else "✓")
			name_hint.add_theme_color_override("font_color", BAD if why != "" else (MUTED if n == "" else GOOD))
			ok = n != "" and why == ""
			var p := pass_edit.text
			pass_hint.text = I18n.t("Too short") if p != "" and p.length() < 6 else (I18n.t("At least 6 characters") if p == "" else "✓")
			pass_hint.add_theme_color_override("font_color", BAD if p != "" and p.length() < 6 else (MUTED if p == "" else GOOD))
			ok = ok and p.length() >= 6
			var same := again_edit.text == p
			again_hint.text = "" if again_edit.text == "" else ("✓" if same else I18n.t("The passwords don't match"))
			again_hint.add_theme_color_override("font_color", GOOD if same else BAD)
			ok = ok and same and again_edit.text != ""
		else:
			ok = n != "" and pass_edit.text != ""
		go.disabled = not ok
		return ok
	for e: LineEdit in [name_edit, pass_edit, again_edit]:
		if e != null:
			e.text_changed.connect(func(_t: String) -> void: check.call())
	check.call()
	go.pressed.connect(func() -> void:
		if check.call():
			Audio.play("click", -6.0)
			on_submit.call(name_edit.text.strip_edges(), pass_edit.text, mode, box))
	return box


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


static func _field(parent: Control, label: String, secret: bool) -> LineEdit:
	HomeHud.ink(parent, label, 20)
	var e := LineEdit.new()
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 52)
	e.add_theme_font_size_override("font_size", 24)
	e.add_theme_color_override("font_color", HomeHud.INK)
	var style := HomeHud._box(Color(1.0, 0.99, 0.95), 10, Color(0.72, 0.69, 0.6), 2)
	style.set_content_margin_all(10)
	e.add_theme_stylebox_override("normal", style)
	var focus := HomeHud._box(Color(1.0, 0.99, 0.95), 10, Color(0.95, 0.7, 0.2), 3)
	focus.set_content_margin_all(10)
	e.add_theme_stylebox_override("focus", focus)
	parent.add_child(e)
	return e


static func _link(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.2, 0.43, 0.66))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.3, 0.55))
	parent.add_child(b)
	return b
