class_name NetLauncher
extends Defense
## Fires a net where the nearest drone is heading. A hit slows that drone to a crawl.

var _cooldown := 1.0
var _life := 0.0
var _velocity := Vector3.ZERO
var _net: MeshInstance3D


func _build() -> void:
	MeshKit.add(self, MeshKit.box(Vector3(1.4, 0.9, 1.4)), MeshKit.mat(Color(0.25, 0.4, 0.3), 0.5, 0.4), Vector3(0, head_y, 0))
	_net = MeshKit.add(self, MeshKit.sphere(0.8, 10), MeshKit.glow(Color(0.9, 0.95, 1.0), 0.45), Vector3(0, head_y, 0))
	_net.visible = false


func tick(delta: float, drones: Array) -> void:
	_cooldown -= delta
	if _life > 0.0:
		_life -= delta
		_net.global_position += _velocity * delta
		for d: Unit in drones:
			if not d.dead and _net.global_position.distance_to(d.global_position) < 1.8:
				d.hit_net()
				_life = 0.0
				break
		if _life <= 0.0:
			_net.visible = false
		return
	var target := nearest_drone(drones)
	if target == null or _cooldown > 0.0:
		return
	var origin := head_position() + Vector3(0, 0.6, 0)
	var lead := target.global_position + target.velocity * 0.45
	_velocity = (lead - origin).normalized() * float(stats.get("speed", 16.0))
	_net.global_position = origin
	_net.visible = true
	_life = 1.6
	_cooldown = float(stats.get("cooldown", 3.5))


func _ring_color() -> Color:
	return Color(0.95, 0.95, 1.0)
