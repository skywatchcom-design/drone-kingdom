class_name NetLauncher
extends Defense
## Fires a net where the drone is heading. A hit slows the drone to a crawl for two seconds.

var _cooldown := 1.0
var _life := 0.0
var _velocity := Vector3.ZERO
var _net: MeshInstance3D


func _build() -> void:
	MeshKit.add(self, MeshKit.box(Vector3(1.4, 0.9, 1.4)), MeshKit.mat(Color(0.25, 0.4, 0.3), 0.5, 0.4), Vector3(0, alt, 0))
	_net = MeshKit.add(self, MeshKit.sphere(0.8, 10), MeshKit.glow(Color(0.9, 0.95, 1.0), 0.45), Vector3(0, alt, 0))
	_net.visible = false


func tick(delta: float, drone: Drone) -> void:
	_cooldown -= delta
	if _life > 0.0:
		_life -= delta
		_net.global_position += _velocity * delta
		if drone != null and not drone.dead and _net.global_position.distance_to(drone.global_position) < 1.8:
			drone.hit_net()
			_life = 0.0
		if _life <= 0.0:
			_net.visible = false
		return
	if drone == null or drone.dead or _cooldown > 0.0 or not in_range(drone.global_position):
		return
	var origin := global_position + Vector3(0, alt + 0.6, 0)
	var lead := drone.global_position + drone.velocity * 0.45
	_velocity = (lead - origin).normalized() * float(stats.get("speed", 16.0))
	_net.global_position = origin
	_net.visible = true
	_life = 1.6
	_cooldown = float(stats.get("cooldown", 3.5))


func _ring_color() -> Color:
	return Color(0.95, 0.95, 1.0)
