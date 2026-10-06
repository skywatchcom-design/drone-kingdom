class_name CoinBubble
extends Node3D
## A small spinning gold coin (or fuel drop) over a generator or pump when there is something
## to collect; the amount shows in the toast when it is tapped. Kept small so it marks the
## building without covering it.

## Below this much waiting, nothing shows yet.
const SHOW_FROM := 10

var cell: Array = []
## Set before adding to the tree: a fuel drop instead of a coin.
var fuel := false
var _coin: Node3D
var _base_y := 0.0
var _t := randf() * 3.0


func _ready() -> void:
	_base_y = position.y
	_coin = Node3D.new()
	_coin.scale = Vector3.ONE * 0.4
	add_child(_coin)
	var tint := Color(0.95, 0.35, 0.55) if fuel else Color(1.0, 0.78, 0.15)
	if fuel:
		# A drop: a ball with a cone on top.
		MeshKit.add(_coin, MeshKit.sphere(1.2, 20), MeshKit.mat(tint, 0.15, 0.3))
		MeshKit.add(_coin, MeshKit.cyl(0.0, 1.05, 1.5, 20), MeshKit.mat(tint, 0.15, 0.3), Vector3(0, 1.15, 0))
	else:
		var face := MeshKit.add(_coin, MeshKit.cyl(1.5, 1.5, 0.3, 28), MeshKit.mat(tint, 0.25, 0.9))
		face.rotation.x = PI / 2.0
		var rim := MeshKit.add(_coin, MeshKit.cyl(1.05, 1.05, 0.34, 28), MeshKit.mat(tint.darkened(0.2), 0.3, 0.9))
		rim.rotation.x = PI / 2.0


func set_amount(amount: int) -> void:
	visible = amount >= SHOW_FROM


func _process(delta: float) -> void:
	_t += delta
	_coin.rotation.y = _t * 1.8
	position.y = _base_y + sin(_t * 2.2) * 0.15


## Little pop when collected.
func pop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.08)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
	tween.tween_callback(func() -> void:
		scale = Vector3.ONE
		visible = false)
