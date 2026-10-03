class_name CoinBubble
extends Node3D
## A spinning, bobbing gold coin above a generator (or a fuel drop above a pump) with the
## amount waiting. Tap to collect.

var cell: Array = []
## Set before adding to the tree: a fuel drop instead of a coin.
var fuel := false
var _coin: Node3D
var _label: Label3D
var _base_y := 0.0
var _t := randf() * 3.0


func _ready() -> void:
	_base_y = position.y
	_coin = Node3D.new()
	add_child(_coin)
	var tint := Color(0.95, 0.35, 0.55) if fuel else Color(1.0, 0.78, 0.15)
	if fuel:
		# A drop: a ball with a cone on top.
		MeshKit.add(_coin, MeshKit.sphere(1.2, 20), MeshKit.mat(tint, 0.15, 0.3))
		MeshKit.add(_coin, MeshKit.cyl(0.0, 1.05, 1.5, 20), MeshKit.mat(tint, 0.15, 0.3), Vector3(0, 1.15, 0))
	else:
		var face := MeshKit.add(_coin, MeshKit.cyl(1.5, 1.5, 0.3, 28), MeshKit.mat(tint, 0.25, 0.9))
		face.rotation.x = PI / 2.0
		var halo := MeshKit.add(_coin, MeshKit.cyl(1.9, 1.9, 0.12, 28), MeshKit.glow(Color(1.0, 0.9, 0.4), 0.3))
		halo.rotation.x = PI / 2.0
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 80
	_label.pixel_size = 0.03
	_label.outline_size = 20
	_label.modulate = Color(1.0, 0.7, 0.82) if fuel else Color(1.0, 0.92, 0.5)
	_label.position = Vector3(0, 2.6, 0)
	add_child(_label)


func set_amount(amount: int) -> void:
	visible = amount > 0
	_label.text = "+%d" % amount


func _process(delta: float) -> void:
	_t += delta
	_coin.rotation.y = _t * 2.5
	position.y = _base_y + sin(_t * 3.0) * 0.3


## Little pop when collected.
func pop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.08)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
	tween.tween_callback(func() -> void:
		scale = Vector3.ONE
		visible = false)
