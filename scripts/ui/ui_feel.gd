class_name UiFeel
extends CanvasLayer
## How the UI answers a touch (UI plan, owner 16.10.2026, sketch SQhYwaeWJpKTv5HjygjboU, "feel"):
## every button in the game sinks a little while pressed and springs back, with a short buzz;
## a new screen fades in from black instead of popping. Installed once by GameState, it hooks
## buttons as they enter the tree, so no screen has to do anything.

const PRESS_SCALE := 0.94

var _fade: ColorRect
var _scene_id := 0


static func install(tree: SceneTree) -> void:
	var feel := UiFeel.new()
	feel.layer = 120
	tree.root.add_child.call_deferred(feel)


func _ready() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.04, 0.03)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		b.button_down.connect(_press.bind(b, true))
		b.button_up.connect(_press.bind(b, false))


func _press(b: BaseButton, down: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size / 2.0
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * (PRESS_SCALE if down else 1.0), 0.07 if down else 0.16)
	if down:
		Audio.buzz(8)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var id := scene.get_instance_id() if scene != null else 0
	if id != _scene_id:
		_scene_id = id
		if MeshKit.palette == "mil" and not Fx.calm:
			_fade.modulate.a = 1.0
			var tw := _fade.create_tween()
			tw.tween_interval(0.05)
			tw.tween_property(_fade, "modulate:a", 0.0, 0.35)
