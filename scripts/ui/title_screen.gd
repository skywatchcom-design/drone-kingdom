class_name TitleScreen
extends Control
## The opening screen (owner, 16.10.2026: "the SkyWatch letters should do a cool, eye-catching
## hopping animation"). The logo is rebuilt from single letters in Black Ops One, the approved
## logo A colors (sand "Sky", gold "Watch", dark olive drop), with the drone mark above, so each
## letter can move on its own. Three styles to choose from (`-- --intro a|b|c`):
##   a "drop": letters fall in one by one and land with a squash and a bounce, then the drone
##     drops onto them.
##   b "wave": letters pop up from below, then a hop runs across the word again and again.
##   c "drone": the drone flies across low and every letter it passes hops up and lands.
## A tap (or a few seconds) goes on to the base.

const NEXT_SCENE := "res://scenes/home/home.tscn"
const WORD := "SkyWatch"
const SAND := Color(0.94, 0.88, 0.72)
const GOLD := Color(0.95, 0.71, 0.24)
const DROP := Color(0.17, 0.2, 0.1)
const BG := Color(0.094, 0.118, 0.071)
const FONT_SIZE := 150
const HOLD := 7.0
## Everything runs this much slower than the first sketch (owner: "a bit slower so the
## animation is seen").
const SLOW := 1.6

## Approved 16.10.2026: "c" (the drone wakes the letters) then the running hop of "b", slower.
var style := "c"
var letters: Array[Control] = []
var drone: Control
var tap: Label
var _font: Font
var _t := 0.0
var _done := false
var _wave_from := 99.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--intro"):
		style = args[args.find("--intro") + 1]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	_font = load("res://assets/fonts/BlackOpsOne-Regular.ttf")
	_background()
	_build_logo()
	tap = Label.new()
	tap.text = I18n.t("Tap to start")
	tap.add_theme_font_override("font", _font)
	tap.add_theme_font_size_override("font_size", 34)
	tap.add_theme_color_override("font_color", SAND)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.anchor_left = 0.0
	tap.anchor_right = 1.0
	tap.anchor_top = 0.78
	tap.modulate.a = 0.0
	add_child(tap)
	match style:
		"b":
			_play_wave()
		"c":
			_play_drone()
		_:
			_play_drop()


func _background() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# A soft lighter glow behind the logo, like the boot splash.
	var g := Gradient.new()
	g.set_color(0, Color(0.26, 0.31, 0.16))
	g.set_color(1, Color(0.26, 0.31, 0.16, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.texture = tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.anchor_left = -0.3
	glow.anchor_right = 1.3
	glow.anchor_top = 0.15
	glow.anchor_bottom = 0.75
	add_child(glow)


## One Control per letter, its pivot at the foot of the letter so squashes look grounded; each
## holds a dark drop copy behind the colored letter. The drone mark is the top of logo.png.
func _build_logo() -> void:
	var view := get_viewport_rect().size
	var widths: Array[float] = []
	var total := 0.0
	for ch in WORD:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		widths.append(w)
		total += w
	# Fit a phone-shaped column even on a wider window, centred in it.
	var room := minf(view.x, view.y * 0.5625) - 70.0
	var scale_fit := minf(1.0, room / total)
	var x := (view.x - total * scale_fit) / 2.0
	var base_y := view.y * 0.5
	for i in WORD.length():
		var holder := Control.new()
		holder.size = Vector2(widths[i], FONT_SIZE)
		holder.pivot_offset = Vector2(widths[i] / 2.0, FONT_SIZE * 0.9)
		holder.scale = Vector2.ONE * scale_fit
		# The holder shrinks around its pivot (the middle of its foot), so place that middle.
		holder.position = Vector2(x + widths[i] * scale_fit / 2.0 - widths[i] / 2.0, base_y - FONT_SIZE * 0.9)
		holder.set_meta("home", holder.position)
		add_child(holder)
		for layer in 2:
			var l := Label.new()
			l.text = WORD[i]
			l.add_theme_font_override("font", _font)
			l.add_theme_font_size_override("font_size", FONT_SIZE)
			l.add_theme_color_override("font_color", DROP if layer == 0 else (SAND if i < 3 else GOLD))
			l.position = Vector2(7, 9) if layer == 0 else Vector2.ZERO
			holder.add_child(l)
		letters.append(holder)
		x += widths[i] * scale_fit
	var art: Texture2D = load("res://assets/icon/logo.png")
	var crop := AtlasTexture.new()
	crop.atlas = art
	crop.region = Rect2(370, 0, 240, 108)
	var d := TextureRect.new()
	d.texture = crop
	d.size = Vector2(240, 108) * 0.85
	d.pivot_offset = d.size / 2.0
	d.position = Vector2((view.x - d.size.x) / 2.0, base_y - FONT_SIZE - 120)
	d.set_meta("home", d.position)
	add_child(d)
	drone = d


func _home(c: Control) -> Vector2:
	return c.get_meta("home")


# ---------------------------------------------------------------- the three styles

## a: each letter falls from above the screen, lands with a squash, bounces once and settles.
func _play_drop() -> void:
	for i in letters.size():
		var l := letters[i]
		var home := _home(l)
		var s := l.scale
		l.position = home + Vector2(0, -900)
		var tw := create_tween()
		tw.tween_interval(0.15 + i * 0.11)
		tw.tween_property(l, "position", home, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _land(i))
		tw.tween_property(l, "scale", s * Vector2(1.25, 0.72), 0.06)
		tw.tween_property(l, "scale", s * Vector2(0.9, 1.12), 0.09)
		tw.parallel().tween_property(l, "position", home + Vector2(0, -38), 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", home, 0.12).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(l, "scale", s, 0.12)
	var dh := _home(drone)
	drone.position = dh + Vector2(0, -700)
	var dt := create_tween()
	dt.tween_interval(0.15 + letters.size() * 0.11 + 0.35)
	dt.tween_property(drone, "position", dh + Vector2(0, 12), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dt.tween_property(drone, "position", dh, 0.25).set_trans(Tween.TRANS_SINE)
	dt.tween_callback(_show_tap)


## b: letters pop up from nothing in a row, then a hop keeps running across the word.
func _play_wave() -> void:
	for i in letters.size():
		var l := letters[i]
		var s := l.scale
		l.scale = Vector2.ZERO
		var tw := create_tween()
		tw.tween_interval(0.1 + i * 0.07)
		tw.tween_callback(func() -> void: Audio.play("click", -14.0, 0.0))
		tw.tween_property(l, "scale", s * 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "scale", s, 0.1)
	drone.modulate.a = 0.0
	var dt := create_tween()
	dt.tween_interval(0.8)
	dt.tween_property(drone, "modulate:a", 1.0, 0.3)
	dt.tween_callback(func() -> void:
		_wave_from = _t
		_show_tap())


## c: the drone sweeps in low from the left; each letter hops as the drone passes over it.
func _play_drone() -> void:
	for l in letters:
		l.modulate.a = 0.0
	var view := get_viewport_rect().size
	var dh := _home(drone)
	var low := _home(letters[0]).y - 150
	drone.position = Vector2(-300, low)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(drone, "position:x", view.x + 60, 1.3 * SLOW).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(drone, "position", Vector2(view.x + 60, dh.y - 200), 0.01)
	tw.tween_property(drone, "position", dh, 0.6 * SLOW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		_wave_from = _t
		_show_tap())
	_drone_pass = true


var _drone_pass := false
var _hopped := {}


func _process(delta: float) -> void:
	_t += delta
	# The drone mark bobs once it is in place.
	if drone != null and _t > 2.0:
		drone.position.y = _home(drone).y + sin(_t * 3.2) * 6.0
	if style == "c" and _drone_pass:
		var cx := drone.position.x + drone.size.x / 2.0
		for i in letters.size():
			var l := letters[i]
			if _hopped.has(i):
				continue
			if cx >= l.position.x + l.size.x * l.scale.x / 2.0:
				_hopped[i] = true
				_hop(l, 70.0, true)
	if style == "b" and _t >= _wave_from:
		# A hop runs across the word every 1.8 s.
		var k := fmod(_t - _wave_from, 1.8 * SLOW)
		for i in letters.size():
			var start := i * 0.08 * SLOW
			var p := clampf((k - start) / (0.32 * SLOW), 0.0, 1.0)
			var l := letters[i]
			l.position.y = _home(l).y - sin(p * PI) * 46.0
	if tap.modulate.a > 0.0:
		tap.modulate.a = 0.55 + 0.45 * absf(sin(_t * 2.4))
	if _t > HOLD + 2.5 and not _done and not OS.get_cmdline_user_args().has("--stay"):
		_go()


## One hop: up, a stretch, down, a squash. `appear` fades the letter in as it jumps.
func _hop(l: Control, height: float, appear: bool) -> void:
	var home := _home(l)
	var s := l.scale
	var tw := create_tween()
	if appear:
		l.position = home + Vector2(0, 40)
		tw.tween_property(l, "modulate:a", 1.0, 0.1 * SLOW)
	tw.tween_property(l, "position", home + Vector2(0, -height), 0.18 * SLOW).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "scale", s * Vector2(0.88, 1.14), 0.18 * SLOW)
	tw.tween_property(l, "position", home, 0.16 * SLOW).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "scale", s, 0.16 * SLOW)
	tw.tween_property(l, "scale", s * Vector2(1.18, 0.82), 0.05)
	tw.tween_property(l, "scale", s, 0.1).set_trans(Tween.TRANS_BACK)
	Audio.play("click", -14.0, 0.0)


func _land(i: int) -> void:
	Audio.play("thud", -10.0, 0.0)
	if i == letters.size() - 1:
		Audio.buzz(30)


func _show_tap() -> void:
	tap.modulate.a = 1.0


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_go()


func _go() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))
