class_name RaidRules
extends RefCounted
## Pure game rules, kept free of nodes so they can be unit tested headless.


## Clash-style stars: one for half the base, one for the Command Tower, one for everything.
static func battle_stars(destroyed_ratio: float, hq_destroyed: bool) -> int:
	var stars := 0
	if destroyed_ratio >= 0.5:
		stars += 1
	if hq_destroyed:
		stars += 1
	if destroyed_ratio >= 0.999:
		stars += 1
	return stars


## Index of the structure a drone should attack: the nearest one it prefers, otherwise the
## nearest standing one, or -1 if nothing is left. Each target is a Dictionary with
## top (Vector3), is_defense (bool), loot (int) and destroyed (bool).
static func pick_target(prefers: String, from: Vector3, targets: Array) -> int:
	var best := -1
	var best_d := INF
	var fallback := -1
	var fallback_d := INF
	for i in targets.size():
		var t: Dictionary = targets[i]
		if t["destroyed"]:
			continue
		var d := PathUtils.flat_distance(from, t["top"])
		var preferred: bool = prefers == "any" \
			or (prefers == "defense" and t["is_defense"]) \
			or (prefers == "loot" and int(t["loot"]) > 0)
		if preferred and d < best_d:
			best_d = d
			best = i
		if d < fallback_d:
			fallback_d = d
			fallback = i
	return best if best >= 0 else fallback


## Body tilt for a multirotor: nose dips with speed and forward acceleration,
## and the drone banks into turns. Returns Vector2(pitch, roll) in radians.
## Forward is local +Z; yaw is the heading around +Y.
static func bank_angles(accel: Vector3, velocity: Vector3, yaw: float) -> Vector2:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var a_forward := accel.dot(forward)
	var a_right := accel.dot(right)
	var speed := Vector2(velocity.x, velocity.z).length()
	var pitch := clampf(speed * 0.03 + a_forward * 0.05, -0.35, 0.45)
	var roll := clampf(-a_right * 0.06, -0.5, 0.5)
	return Vector2(pitch, roll)

