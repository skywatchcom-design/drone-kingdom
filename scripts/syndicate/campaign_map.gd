extends Control
## The Syndicate campaign map (approved sketch G1Y41QRsCwW8TVG8wyP9NB): a desert with a river,
## a dashed road through ten missions, stars over the ones played, locks on the ones not open
## yet, and Razor's fortress at the end. Tapping an open mission shows the briefing: Razor's
## taunt, the first-win reward, what defends the base, and Attack.
## Run with `-- --mission N` to open that briefing on start (screenshots).

const HOME_SCENE := "res://scenes/home/home.tscn"
const RAID_SCENE := "res://scenes/raid/raid.tscn"
## Mission spots on a 1950 x 900 map, scaled to the screen.
const SPOTS := [[820, 720], [960, 600], [900, 430], [1080, 320], [1280, 400], [1420, 580], [1600, 650], [1760, 480], [1640, 290], [1820, 170]]
const SAND := Color(0.85, 0.77, 0.56)

var _art: Control
var _brief: PanelContainer
var _toast: Label
var selected := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.hum(0.0)
	_art = Control.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_map)
	add_child(_art)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(ui)

	var open := GameState.syndicate_open()
	for i in Syndicate.COUNT:
		_add_spot(ui, i, i < open)

	var back := Button.new()
	back.text = I18n.t("Back to base")
	back.position = Vector2(20, 18)
	back.custom_minimum_size = Vector2(190, 52)
	back.add_theme_font_size_override("font_size", 22)
	HomeHud._style_button(back, HomeHud.GOLD_TOP, 10, Color.WHITE, 3)
	back.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		get_tree().change_scene_to_file(HOME_SCENE))
	ui.add_child(back)

	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", HomeHud._box(Color(0.08, 0.06, 0.12, 0.85), 10, Color(0.75, 0.55, 1.0), 2))
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -190
	title.offset_right = 190
	title.offset_top = 16
	ui.add_child(title)
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 10)
	title.add_child(trow)
	trow.add_child(Icons.rect("syndicate", 40))
	HomeHud.make_label(trow, I18n.t("Syndicate Operation"), 26)

	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 6)
	stars.anchor_left = 1.0
	stars.anchor_right = 1.0
	stars.offset_left = -170
	stars.offset_top = 22
	ui.add_child(stars)
	stars.add_child(Icons.rect("star", 30))
	HomeHud.make_label(stars, "%d / %d" % [GameState.syndicate_total_stars(), Syndicate.COUNT * 3], 24)

	_brief = PanelContainer.new()
	_brief.add_theme_stylebox_override("panel", HomeHud._box(HomeHud.PARCHMENT, 16, Color(0.11, 0.12, 0.1), 4))
	_brief.position = Vector2(26, 140)
	_brief.custom_minimum_size = Vector2(470, 0)
	_brief.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_brief)

	_toast = HomeHud.make_label(self, "", 30)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.9
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0

	selected = mini(open - 1, Syndicate.COUNT - 1)
	var args := OS.get_cmdline_user_args()
	if args.has("--mission"):
		selected = clampi(int(args[args.find("--mission") + 1]), 0, Syndicate.COUNT - 1)
	_show_brief(selected)


func _process(delta: float) -> void:
	_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta * 0.6)


func _spot(i: int) -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(SPOTS[i][0] / 1950.0 * s.x, SPOTS[i][1] / 900.0 * s.y)


## One mission on the map: a round button (number, or the emblem for the boss), stars over it
## if played, a lock if not open yet, and its name underneath.
func _add_spot(parent: Control, i: int, open: bool) -> void:
	var boss := i == Syndicate.BOSS
	var size := 92.0 if boss else 70.0
	var center := _spot(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.position = center - Vector2(size, size) / 2.0
	b.add_theme_font_size_override("font_size", 32)
	var fill := Color(0.17, 0.18, 0.2) if boss else Color(0.23, 0.24, 0.27)
	if not open:
		fill = Color(0.42, 0.41, 0.38)
	var ring := Color(0.75, 0.55, 1.0) if boss else (Color(0.95, 0.76, 0.18) if open else Color(0.3, 0.29, 0.26))
	HomeHud._style_button(b, fill, int(size / 2.0), ring, 5)
	if boss:
		b.icon = Icons.tex("syndicate", 128)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		b.text = str(i + 1)
	b.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		if open:
			_show_brief(i)
		else:
			_toast.text = I18n.t("Win the mission before it first")
			_toast.modulate.a = 1.6)
	parent.add_child(b)
	var earned := int(GameState.syndicate_stars.get(str(i), -1))
	if earned >= 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.position = center + Vector2(-48, -size / 2.0 - 32)
		parent.add_child(row)
		for k in 3:
			var star := Icons.rect("star", 32)
			if k >= earned:
				star.modulate = Color(0.3, 0.3, 0.3)
			row.add_child(star)
	if not open:
		var lock := Icons.rect("lock", 28)
		lock.position = center + Vector2(-14, size / 2.0 + 2)
		parent.add_child(lock)
	var name_label := HomeHud.make_label(parent, Syndicate.mission_name(i), 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.x = 200
	name_label.position = center + Vector2(-100, size / 2.0 + (30 if not open else 4))


## The briefing: Razor's portrait and taunt, the reward for the first win, what defends the
## base, and the Attack button.
func _show_brief(i: int) -> void:
	selected = i
	for child in _brief.get_children():
		child.queue_free()
	var m: Dictionary = Syndicate.MISSIONS[i]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	# The panel stays on the left; its content reads in the language's direction.
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL if I18n.rtl() else Control.LAYOUT_DIRECTION_LTR
	_brief.add_child(box)
	HomeHud.make_label(box, I18n.t("Mission %d: %s") % [i + 1, Syndicate.mission_name(i)], 26)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	box.add_child(who)
	who.add_child(Icons.rect("razor", 110))
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", HomeHud._box(Color.WHITE, 10))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(bubble)
	var said := VBoxContainer.new()
	bubble.add_child(said)
	var line := HomeHud.ink(said, "\"%s\"" % I18n.t(m["taunt"]), 18)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 300
	HomeHud.ink(said, I18n.t("Razor"), 15, Color(0.45, 0.3, 0.6))
	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 8)
	box.add_child(reward)
	var first := int(GameState.syndicate_stars.get(str(i), 0)) == 0
	HomeHud.ink(reward, I18n.t("First win reward:") if first else I18n.t("Reward already taken"), 18)
	if first:
		for pair in [["coins", "coin"], ["fuel", "fuel"], ["gems", "gem"]]:
			var amount := int(m["reward"].get(pair[0], 0))
			if amount > 0:
				HomeHud.ink(reward, str(amount), 20)
				reward.add_child(Icons.rect(pair[1], 24))
	var counts := {}
	for s in Syndicate.base(i)["structures"]:
		if Catalog.is_defense(s["type"]) or s["type"] == "quarters":
			counts[s["type"]] = int(counts.get(s["type"], 0)) + 1
	var parts := []
	for type in counts:
		var label := I18n.t("Robot guards") if type == "quarters" else Catalog.display_name(type)
		parts.append(label if int(counts[type]) == 1 else "%s x%d" % [label, int(counts[type])])
	var defs := HomeHud.ink(box, I18n.t("Defenses: %s") % ", ".join(parts), 17, Color(0.3, 0.29, 0.24))
	defs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	defs.custom_minimum_size.x = 430
	var attack := Button.new()
	attack.text = I18n.t("ATTACK!")
	attack.icon = Icons.tex("swords", 64)
	attack.add_theme_constant_override("icon_max_width", 34)
	attack.custom_minimum_size = Vector2(0, 60)
	attack.add_theme_font_size_override("font_size", 26)
	HomeHud._style_button(attack, Color(0.85, 0.3, 0.2), 12, Color.WHITE, 3)
	attack.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		_attack(i))
	box.add_child(attack)


func _attack(i: int) -> void:
	if GameState.army_used() <= 0:
		_toast.text = I18n.t("Train an army first")
		_toast.modulate.a = 1.6
		return
	GameState.raid_target = "syndicate"
	GameState.syndicate_mission = i
	get_tree().change_scene_to_file(RAID_SCENE)


## The desert, the river, scattered scrap, and the dashed road between the missions.
func _draw_map() -> void:
	var s := get_viewport_rect().size
	_art.draw_rect(Rect2(Vector2.ZERO, s), SAND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 60:
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
		_art.draw_arc(p + Vector2(0, 20), 26, PI * 1.15, PI * 1.85, 10, Color(0.79, 0.68, 0.45), 3.0)
	var river := PackedVector2Array()
	for x in range(0, int(s.x) + 40, 40):
		river.append(Vector2(x, s.y * 0.9 + sin(x * 0.006) * 22.0))
	river.append(Vector2(s.x, s.y))
	river.append(Vector2(0, s.y))
	_art.draw_colored_polygon(river, Color(0.36, 0.56, 0.69))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.85, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.58),
		Vector2(s.x * 0.9, s.y * 0.4), Vector2(s.x * 0.86, s.y * 0.15)]), Color(0.42, 0.35, 0.29, 0.75))
	for k in 16:
		var p := Vector2(rng.randf() * s.x * 0.8, rng.randf() * s.y * 0.8)
		_art.draw_rect(Rect2(p, Vector2(28, 12)), Color(0.54, 0.48, 0.37))
		_art.draw_rect(Rect2(p + Vector2(8, -10), Vector2(12, 10)), Color(0.43, 0.38, 0.29))
	for i in range(1, Syndicate.COUNT):
		_art.draw_dashed_line(_spot(i - 1), _spot(i), Color(0.48, 0.35, 0.22), 7.0, 18.0)
