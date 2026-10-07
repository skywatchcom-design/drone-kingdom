class_name MissionsUI
extends RefCounted
## The Missions window (approved sketch Tnvwhfaq4KMqSS85z45tfx), in the Shop's parchment style:
## a Starter tab with the twelve starter missions by day, and a Daily tab with the day's three
## missions and the seven-day login gift. Each mission row: picture, text, progress, reward and
## a button (Claim when done, Go to head there, a lock while its day is closed).

const ROW := Color(0.85, 0.82, 0.75)
const ROW_NEXT := Color(0.95, 0.9, 0.74)
const LINE := Color(0.73, 0.69, 0.6)
const MUTED := Color(0.42, 0.4, 0.33)


## `on_claim(kind, id)` pays a reward (kind "starter", "daily" or "login"); `on_go(check)` heads
## to where a mission is done; `on_tab(tab)` reopens the window on a tab.
static func window(tab: String, on_tab: Callable, on_claim: Callable, on_go: Callable) -> Control:
	GameState.refresh_daily()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_tabs(tab, on_tab))
	if tab == "starter":
		_starter(box, on_claim, on_go)
	else:
		_daily(box, on_claim, on_go)
	return box


static func _tabs(tab: String, on_tab: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var ready := {"starter": 0, "daily": 1 if GameState.login_ready() else 0}
	for i in Missions.STARTER.size():
		if GameState.starter_state(i) == "claim":
			ready["starter"] += 1
	for key in GameState.daily["keys"]:
		if GameState.daily_state(key) == "claim":
			ready["daily"] += 1
	for t in ["starter", "daily"]:
		var b := Button.new()
		b.text = I18n.t("Starter") if t == "starter" else I18n.t("Daily")
		b.custom_minimum_size = Vector2(170, 50)
		b.add_theme_font_size_override("font_size", 22)
		HomeHud._style_button(b, Color(0.4, 0.65, 0.24) if t == tab else Color(0.29, 0.32, 0.27), 10, Color(1, 1, 1, 0.6), 2)
		b.pressed.connect(func() -> void:
			Audio.play("click", -6.0)
			on_tab.call(t))
		row.add_child(b)
		if ready[t] > 0:
			var badge := HomeHud._corner_badge(b)
			badge.text = str(ready[t])
			badge.visible = true
	return row


## Noa's face in a circle, a title and her line, and (optionally) progress on the far side.
static func _header(parent: Control, face: String, title: String, line: String, done: int = -1, total: int = 0) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	parent.add_child(head)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/textures/noa/noa_%s.webp" % face)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(64, 64)
	pic.clip_contents = true
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	HomeHud.ink(words, title, 28)
	var say := HomeHud.ink(words, line, 18, MUTED)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if done >= 0:
		var prog := VBoxContainer.new()
		prog.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(prog)
		var n := HomeHud.ink(prog, "%d / %d" % [done, total], 24)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prog.add_child(_bar(done, total, Vector2(170, 14)))


static func _starter(box: Control, on_claim: Callable, on_go: Callable) -> void:
	var done := GameState.starter_claimed.size()
	var total := Missions.STARTER.size()
	var line := I18n.t("Noa: \"A few more missions and your base will be a fortress!\"")
	if GameState.starter_done():
		line = I18n.t("Noa: \"All done, Commander! Check the daily missions every day.\"")
	_header(box, "smile", I18n.t("Starter missions"), line, done, total)
	var list := _list(box)
	var next_marked := false
	var day := 0
	for i in total:
		var m: Dictionary = Missions.STARTER[i]
		if int(m["day"]) != day:
			day = int(m["day"])
			HomeHud.ink(list, I18n.t("Day %d") % day, 18, MUTED)
		var state := GameState.starter_state(i)
		var is_next := not next_marked and state in ["open", "claim"]
		next_marked = next_marked or is_next
		var id := i
		list.add_child(_row(m, GameState.mission_progress(m["check"]), state, is_next,
			func() -> void: on_claim.call("starter", id), func() -> void: on_go.call(m["check"])))


static func _daily(box: Control, on_claim: Callable, on_go: Callable) -> void:
	var t := Time.get_time_dict_from_system()
	var since_midnight := int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"])
	var line := I18n.t("New missions in %s  ·  all three = %d gems") % [HomeHud.clock(86400 - since_midnight), Missions.DAILY_BONUS]
	_header(box, "wink", I18n.t("Daily missions"), line)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	var list := _list(split)
	list.get_parent().size_flags_stretch_ratio = 1.3
	for key: String in GameState.daily["keys"]:
		var m: Dictionary = Missions.DAILY[key]
		list.add_child(_row(m, GameState.daily_progress(key), GameState.daily_state(key), false,
			func() -> void: on_claim.call("daily", key), func() -> void: on_go.call(m["check"])))
	split.add_child(_login(on_claim))


## The seven-day login gift: taken days ticked, today's with a Claim button, day 7 the big one.
static func _login(on_claim: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var taken := int(GameState.login.get("day", 0)) % Missions.LOGIN.size()
	if not GameState.login_ready() and taken == 0 and int(GameState.login.get("day", 0)) > 0:
		taken = Missions.LOGIN.size()
	HomeHud.ink(col, I18n.t("Login gift  ·  day %d") % (mini(taken + 1, Missions.LOGIN.size()) if GameState.login_ready() else taken), 22)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for i in Missions.LOGIN.size():
		var today := GameState.login_ready() and i == taken
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(96, 104)
		card.add_theme_stylebox_override("panel", HomeHud._box(ROW_NEXT if today else ROW, 10, Color(0.95, 0.7, 0.2) if today else LINE, 3 if today else 2))
		if i < taken:
			card.modulate = Color(1, 1, 1, 0.55)
		grid.add_child(card)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var d := HomeHud.ink(v, I18n.t("Day %d") % (i + 1), 16, MUTED)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var r := _reward(Missions.LOGIN[i], 18)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(r)
		if i < taken:
			var tick := HomeHud.ink(v, "✓", 22, ShopUI.GOOD)
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif today:
			_button(I18n.t("Claim"), Color(0.25, 0.63, 0.35), v).pressed.connect(func() -> void: on_claim.call("login", ""))
	return col


static func _list(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


static func _row(m: Dictionary, progress: Array, state: String, is_next: bool, claim: Callable, go: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HomeHud._box(ROW_NEXT if is_next else ROW, 10, Color(0.95, 0.7, 0.2) if is_next else LINE, 3 if is_next else 2))
	if state == "claimed" or state == "locked":
		card.modulate = Color(1, 1, 1, 0.6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var pic_box := Control.new()
	pic_box.custom_minimum_size = Vector2(70, 70)
	row.add_child(pic_box)
	var pic := ShopUI.picture(m["pic"][0], int(m["pic"][1]), Color(0.56, 0.64, 0.43))
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic_box.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var text := HomeHud.ink(words, I18n.t(m["text"]), 21)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if int(progress[1]) > 1 and state != "claimed":
		var p := HBoxContainer.new()
		p.add_theme_constant_override("separation", 8)
		words.add_child(p)
		p.add_child(_bar(int(progress[0]), int(progress[1]), Vector2(140, 12)))
		HomeHud.ink(p, "%s / %s" % [HomeHud._thousands(int(progress[0])), HomeHud._thousands(int(progress[1]))], 16, MUTED)
	row.add_child(_reward(m["reward"], 20))
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(110, 0)
	row.add_child(slot)
	match state:
		"claim":
			_button(I18n.t("Claim"), Color(0.25, 0.63, 0.35), slot).pressed.connect(claim)
		"open":
			_button(I18n.t("Go"), Color(0.43, 0.48, 0.35), slot).pressed.connect(go)
		"claimed":
			HomeHud.ink(slot, "✓", 30, ShopUI.GOOD)
		_:
			slot.add_child(Icons.rect("lock", 34))
	return card


static func _reward(reward: Dictionary, size: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	for k: String in ["coins", "fuel", "gems"]:
		if reward.has(k):
			r.add_child(Icons.rect({"coins": "coin", "fuel": "fuel", "gems": "gem"}[k], size + 4))
			HomeHud.ink(r, HomeHud._thousands(int(reward[k])), size)
	return r


static func _button(text: String, color: Color, parent: Control) -> Button:
	var b := Button.new()
	parent.add_child(b)
	b.text = text
	b.custom_minimum_size = Vector2(110, 46)
	b.add_theme_font_size_override("font_size", 20)
	HomeHud._style_button(b, color, 10, Color(1, 1, 1, 0.7), 2)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	return b


static func _bar(value: int, total: int, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(1, total)
	bar.value = value
	bar.custom_minimum_size = size
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := HomeHud.flat(ShopUI.BAR_BG)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(0)
	var fill := HomeHud.flat(Color(0.25, 0.63, 0.35))
	fill.set_corner_radius_all(6)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
