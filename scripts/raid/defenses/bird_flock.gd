class_name BirdFlock
extends Defense
## Gulls circling above a nest. Each bump costs health and knocks the drone sideways.

var _birds: Array[Node3D] = []
var _wings: Array = []
var _cooldowns: Array[float] = []
var _t := 0.0


func _build_mast() -> void:
	MeshKit.add(self, MeshKit.cyl(1.2, 0.9, 0.5, 12), MeshKit.mat(Color(0.45, 0.33, 0.2), 0.95), Vector3(0, roof_y + 0.25, 0))


func _build() -> void:
	var feathers := MeshKit.mat(Color(0.92, 0.92, 0.9), 0.8)
	for i in int(stats.get("count", 6)):
		var bird := Node3D.new()
		add_child(bird)
		MeshKit.add(bird, MeshKit.sphere(0.28, 8), feathers)
		var left := MeshKit.add(bird, MeshKit.box(Vector3(0.9, 0.04, 0.3)), feathers, Vector3(0.5, 0, 0))
		var right := MeshKit.add(bird, MeshKit.box(Vector3(0.9, 0.04, 0.3)), feathers, Vector3(-0.5, 0, 0))
		_birds.append(bird)
		_wings.append([left, right])
		_cooldowns.append(0.0)


func tick(delta: float, drone: Drone) -> void:
	_t += delta
	var orbit := radius - 2.0
	var count := _birds.size()
	for i in count:
		var a := _t * float(stats.get("speed", 1.3)) + TAU * i / count
		var wobble := sin(_t * 2.0 + i) * 1.5
		var bird := _birds[i]
		bird.position = Vector3(cos(a) * (orbit + wobble), alt + sin(_t * 1.7 + i) * 0.8, sin(a) * (orbit + wobble))
		bird.rotation.y = -a
		var flap := sin(_t * 14.0 + i) * 0.5
		_wings[i][0].rotation.z = flap
		_wings[i][1].rotation.z = -flap
		_cooldowns[i] -= delta
		if drone == null or drone.dead or _cooldowns[i] > 0.0:
			continue
		if bird.global_position.distance_to(drone.global_position) < 1.8:
			drone.damage(float(stats.get("damage", 15.0)))
			var push := drone.global_position - bird.global_position
			push.y = 0.0
			drone.velocity += push.normalized() * 6.0
			_cooldowns[i] = 1.0


func _ring_color() -> Color:
	return Color(1.0, 0.8, 0.3)
