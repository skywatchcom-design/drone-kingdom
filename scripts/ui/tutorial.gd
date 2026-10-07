class_name Tutorial
extends CanvasLayer
## Noa's beginner tutorial (approved sketch MGyZi8x3roSUiJFQpDLzYt): twelve short steps from the
## first coins to the first Syndicate win and a Command Tower upgrade. Noa stands in a bottom
## corner with a speech bubble and speaks each line; the screen darkens around the one thing to
## tap, a bouncing arrow points at it, and every other tap is blocked.
##
## The steps, Noa's lines and the gift live in TutorialSteps.
##
## Each scene adds one with Tutorial.attach(self). A step's targets are tried in order and the
## first one on screen is used: a Control tagged with Tutorial.tag(control, key), or a rect from
## the scene's tutorial_target(key). A step ends on its "done" event (GameState.tutorial_event)
## or, without one, on a tap.

const NOA_SIZE := Vector2(250, 287)
const BUBBLE_WIDTH := 500.0
const TYPE_SPEED := 32.0
const DIM := 0.55

## The step whose line was spoken last, kept across scene changes so a line plays once.
static var _spoken := ""
## Browsers (Safari on iPad above all) keep sound off until the first tap, so on the web a
## line waits for that tap instead of playing into silence.
static var _audio_ready := not OS.has_feature("web")
var _pending_voice := ""
var _swallow_tap := false

var _root: Control
var _blocker: Blocker
var _dim: ColorRect
var _arrow: Control
var _noa: TextureRect
var _bubble: PanelContainer
var _text: Label
var _hint: Label
var _skip: Button
var _confirm: PanelContainer
var _faces := {}
var _shown := ""
var _typed := 0.0
var _voice_len := 0.0
var _time := 0.0
var _target := Rect2()
var _target_key := ""
## Dev: `-- --tutorial-bot` taps wherever Noa points and saves a picture now and then to
## tmp/bot, to check the whole tutorial without a person.
var _bot := OS.is_debug_build() and OS.get_cmdline_user_args().has("--tutorial-bot")
var _bot_wait := 2.5
static var _bot_shots := 0


## Adds the tutorial to `scene` when it is running. Safe to call in every scene.
static func attach(scene: Node) -> void:
	if GameState.tutorial >= 0:
		scene.add_child(Tutorial.new())


## Marks `control` as the target called `key`.
static func tag(control: Control, key: String) -> void:
	control.add_to_group("tut_" + key)


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.material = _hole_material()
	_root.add_child(_dim)

	_blocker = Blocker.new()
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.gui_input.connect(_on_blocker_input)
	_root.add_child(_blocker)

	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(56, 66)
	_arrow.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(16, 0), Vector2(40, 0), Vector2(40, 32), Vector2(56, 32), Vector2(28, 66), Vector2(0, 32), Vector2(16, 32)])
		_arrow.draw_colored_polygon(pts, Color(0.96, 0.71, 0.23))
		pts.append(pts[0])
		_arrow.draw_polyline(pts, Color(0.35, 0.24, 0.02), 3.0, true))
	_root.add_child(_arrow)

	for face in ["smile", "wink", "serious"]:
		_faces[face] = load("res://assets/textures/noa/noa_%s.webp" % face)
	_noa = TextureRect.new()
	_noa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_noa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_noa.size = NOA_SIZE
	_noa.pivot_offset = Vector2(NOA_SIZE.x / 2.0, NOA_SIZE.y)
	_noa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_noa)

	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := HomeHud._box(HomeHud.PARCHMENT, 18, Color(1, 1, 1, 0.9), 3)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(0, 5)
	style.shadow_size = 2
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.custom_minimum_size.x = BUBBLE_WIDTH
	_root.add_child(_bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL if I18n.rtl() else Control.LAYOUT_DIRECTION_LTR
	_bubble.add_child(box)
	HomeHud.ink(box, I18n.t("Noa"), 20, Color(0.16, 0.48, 0.42))
	_text = HomeHud.ink(box, "", 25)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BUBBLE_WIDTH - 40, 66)
	_hint = HomeHud.ink(box, I18n.t("Tap to continue"), 16, Color(0.45, 0.43, 0.36))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not I18n.rtl() else HORIZONTAL_ALIGNMENT_LEFT

	_skip = Button.new()
	_skip.text = I18n.t("Skip tutorial")
	_skip.add_theme_font_size_override("font_size", 18)
	HomeHud._style_button(_skip, Color(0, 0, 0, 0.55), 18, Color(1, 1, 1, 0.35), 2)
	_skip.anchor_left = 0.5
	_skip.anchor_right = 0.5
	_skip.offset_left = -95
	_skip.offset_right = 95
	_skip.offset_top = 74
	_skip.offset_bottom = 112
	_skip.pressed.connect(_ask_skip)
	_root.add_child(_skip)
	_confirm = _skip_dialog()
	_root.add_child(_confirm)

	GameState.tutorial_changed.connect(_on_changed)
	_on_changed()


func _step() -> Dictionary:
	return TutorialSteps.STEPS[GameState.tutorial] if GameState.tutorial >= 0 else {}


## A tap step ends with a tap: steps with no event, and every step when replaying.
func _tap_step() -> bool:
	return GameState.tutorial_replay or not _step().has("done")


func _on_changed() -> void:
	if GameState.tutorial < 0:
		Audio.stop_voice()
		queue_free()
		return
	_shown = ""


func _process(delta: float) -> void:
	_time += delta
	var step := _step()
	if step.is_empty():
		return
	if _bot:
		_bot_tick(delta)
	_target = _find_target(step)
	var free: bool = step.get("free", false) and not GameState.tutorial_replay
	# Noa waits off screen while none of the step's targets is showing (in battle, say).
	var visible_now := _target.has_area() or _tap_step()
	_root.visible = visible_now
	_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE if free or not visible_now else Control.MOUSE_FILTER_STOP
	if not visible_now:
		return
	var alt: Dictionary = step.get("alt", {}).get(_target_key, {})
	var line: String = alt.get("line", step["key"])
	if _shown != line:
		_show_line(line, alt.get("face", step["face"]))
	_layout(free)
	_animate(delta)


func _show_line(line: String, face: String) -> void:
	_shown = line
	_noa.texture = _faces[face]
	_text.text = I18n.t(TutorialSteps.LINES[line])
	_typed = 0.0
	_voice_len = 0.0
	var id := "%d:%s" % [GameState.tutorial, line]
	var path := "res://assets/audio/noa/%s_%s.ogg" % [I18n.lang, line]
	_pending_voice = ""
	_swallow_tap = false
	if _spoken != id and not _audio_ready:
		_spoken = id
		_pending_voice = path
	elif _spoken != id:
		_spoken = id
		_voice_len = Audio.say(path)
	else:
		_typed = _text.text.length()
	_text.visible_characters = int(_typed)
	_hint.visible = false


## Noa sits in the bottom corner away from the target, the bubble beside her (or at the top
## when it would cover the target), the hole and arrow on the target.
func _layout(free: bool) -> void:
	var screen := get_viewport().get_visible_rect().size
	var has := _target.has_area()
	var center := _target.get_center() if has else Vector2(-1000, -1000)
	var on_left := not has or center.x > screen.x * 0.5
	var noa_x := 150.0 if on_left else screen.x - 150.0 - NOA_SIZE.x
	var noa_rect := Rect2(Vector2(noa_x, screen.y - NOA_SIZE.y), NOA_SIZE)
	if has and noa_rect.grow(10).intersects(_target):
		on_left = not on_left
		noa_x = 150.0 if on_left else screen.x - 150.0 - NOA_SIZE.x
	_noa.position = Vector2(noa_x, screen.y - NOA_SIZE.y)
	_noa.flip_h = not on_left
	var bsize := _bubble.get_combined_minimum_size()
	var bx := noa_x + NOA_SIZE.x - 10.0 if on_left else noa_x - bsize.x + 10.0
	var by := screen.y - bsize.y - 40.0
	if has and Rect2(Vector2(bx, by), bsize).grow(12).intersects(_target):
		by = 120.0
	_bubble.position = Vector2(bx, by)
	_bubble.size = bsize

	var mat := _dim.material as ShaderMaterial
	_dim.visible = not free
	mat.set_shader_parameter("size", screen)
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("radius", maxf(_target.size.x, _target.size.y) * 0.5 + 10.0 if has else 0.0)
	_blocker.hole = _target.grow(10) if has else Rect2()
	_arrow.visible = has
	if has:
		var bob := sin(_time * 7.0) * 8.0
		_arrow.position = Vector2(center.x - _arrow.size.x / 2.0, maxf(4.0, _target.position.y - _arrow.size.y - 14.0 + bob))


## Text appears with the voice (or at a steady pace without one); Noa bobs while she talks.
func _animate(delta: float) -> void:
	var total := _text.text.length()
	if _typed < total:
		if _voice_len > 0.0 and Audio.voice_playing():
			_typed = maxf(_typed, total * clampf(Audio.voice_position() / (_voice_len * 0.9), 0.0, 1.0))
		else:
			_typed += delta * TYPE_SPEED * (3.0 if _voice_len > 0.0 else 1.0)
		_text.visible_characters = int(_typed)
	if _pending_voice != "":
		_hint.text = I18n.t("Tap to hear Noa")
		_hint.visible = true
	else:
		_hint.text = I18n.t("Tap to continue")
		_hint.visible = _tap_step() and _typed >= total
	var talking := Audio.voice_playing()
	var s := 1.0 + (0.012 * absf(sin(_time * 11.0)) if talking else 0.0)
	_noa.scale = Vector2(s, s)
	_noa.rotation = sin(_time * 5.0) * 0.012 if talking else 0.0


## The first of the step's targets on screen (its key goes to _target_key), or Rect2().
func _find_target(step: Dictionary) -> Rect2:
	var scene := get_tree().current_scene
	for key: String in step.get("targets", []):
		_target_key = key
		for node in get_tree().get_nodes_in_group("tut_" + key):
			var c := node as Control
			if c != null and c.is_visible_in_tree() and not c.is_queued_for_deletion():
				return c.get_global_rect()
		if scene != null and scene.has_method("tutorial_target"):
			var r: Rect2 = scene.tutorial_target(key)
			if r.has_area():
				return r
	_target_key = ""
	return Rect2()


## The first press anywhere unlocks sound on the web; a line waiting for it starts then, and
## that tap only starts her talking.
func _input(event: InputEvent) -> void:
	if _audio_ready or not (event is InputEventMouseButton or event is InputEventScreenTouch) or not event.pressed:
		return
	_audio_ready = true
	if _pending_voice != "":
		_swallow_tap = _tap_step()
		_typed = 0.0
		_text.visible_characters = 0
		_voice_len = Audio.say(_pending_voice)
		_pending_voice = ""


func _on_blocker_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and not event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if not tap or _confirm.visible:
		return
	if _swallow_tap:
		_swallow_tap = false
		return
	if _typed < _text.text.length():
		_typed = _text.text.length()
		_text.visible_characters = -1
		return
	if _tap_step():
		Audio.play("click", -6.0)
		GameState.tutorial_next()


func _bot_tick(delta: float) -> void:
	_bot_wait -= delta
	if _bot_wait > 0.0:
		return
	_bot_wait = 1.5
	var dir := ProjectSettings.globalize_path("res://tmp/bot")
	DirAccess.make_dir_recursive_absolute(dir)
	_bot_shots += 1
	get_viewport().get_texture().get_image().save_jpg("%s/%03d_%s.jpg" % [dir, _bot_shots, GameState.tutorial_key()], 0.8)
	var scene := get_tree().current_scene
	if not _root.visible:
		# In battle, keep sending troops so the bot wins.
		var spot: Rect2 = scene.tutorial_target("deploy_ground") if scene.has_method("tutorial_target") else Rect2()
		if spot.has_area():
			_bot_click(spot.get_center())
		return
	_bot_click(_target.get_center() if _target.has_area() else get_viewport().get_visible_rect().size * Vector2(0.5, 0.3))


func _bot_click(p: Vector2) -> void:
	var w := get_viewport().get_screen_transform() * p
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = w
		e.global_position = w
		Input.parse_input_event(e)


func _ask_skip() -> void:
	Audio.play("click", -6.0)
	_confirm.visible = true


func _skip_dialog() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HomeHud.flat(Color(0.08, 0.1, 0.12, 0.95)))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -100
	panel.offset_bottom = 100
	panel.visible = false
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var q := HomeHud.make_label(box, I18n.t("Skip the tutorial?"), 30)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	HomeHud.make_button(row, I18n.t("Skip"), 24, 64).pressed.connect(func() -> void:
		panel.visible = false
		GameState.skip_tutorial())
	HomeHud.make_button(row, I18n.t("Keep going"), 24, 64).pressed.connect(func() -> void: panel.visible = false)
	return panel


static func _hole_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec2 center = vec2(-1000.0);
uniform float radius = 0.0;
uniform float dim = %.2f;
void fragment() {
	vec2 p = UV * size;
	float d = distance(p, center);
	float a = dim * smoothstep(radius - 2.0, radius + 4.0, d);
	float ring = radius > 0.0 ? 1.0 - smoothstep(2.0, 4.0, abs(d - radius - 3.0)) : 0.0;
	float dash = step(0.0, sin(atan(p.y - center.y, p.x - center.x) * 16.0 + TIME * 3.0));
	COLOR = mix(vec4(0.0, 0.0, 0.0, a), vec4(0.96, 0.71, 0.23, 1.0), ring * dash);
}
""" % DIM
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Blocks every tap except inside the hole over the target.
class Blocker extends Control:
	var hole := Rect2()

	func _has_point(point: Vector2) -> bool:
		return not hole.has_point(point)
