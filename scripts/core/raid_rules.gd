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


## Outward direction of the fence side that `p` (a point on the fence line) sits on.
static func fence_normal(p: Vector3) -> Vector3:
	if absf(p.x) >= absf(p.z):
		return Vector3(signf(p.x), 0, 0)
	return Vector3(0, 0, signf(p.z))


static func _inside(p: Vector3, yard: float) -> bool:
	return absf(p.x) < yard and absf(p.z) < yard


## True if walking straight from `a` to `b` would cross into the fenced yard.
static func crosses_yard(a: Vector3, b: Vector3, yard: float) -> bool:
	for i in range(1, 12):
		if _inside(a.lerp(b, i / 12.0), yard):
			return true
	return false


## Next point a ground unit walks to on its way to `goal`. The fence can only be crossed at
## an opening (the gate or a breach, each a point on the fence line): the unit walks to the
## opening's outer side, then through it. Outside the fence it goes around the corners
## instead of walking into the fence.
static func ground_waypoint(from: Vector3, goal: Vector3, yard: float, openings: Array) -> Vector3:
	var inside_from := _inside(from, yard)
	if inside_from == _inside(goal, yard) or openings.is_empty():
		return goal
	var best: Vector3 = openings[0]
	var best_cost := INF
	for o: Vector3 in openings:
		var cost := PathUtils.flat_distance(from, o) + PathUtils.flat_distance(o, goal)
		if cost < best_cost:
			best_cost = cost
			best = o
	var n := fence_normal(best)
	var outer := best + n * 2.0
	var inner := best - n * 2.0
	if PathUtils.flat_distance(from, best) < 2.6:
		return outer if inside_from else inner
	if inside_from:
		return inner
	if not crosses_yard(from, outer, yard):
		return outer
	# Go around: the corner (just outside the fence) that leads to the opening fastest.
	var corner_best := outer
	var corner_cost := INF
	var c := yard + 3.0
	for corner: Vector3 in [Vector3(c, 0, c), Vector3(-c, 0, c), Vector3(c, 0, -c), Vector3(-c, 0, -c)]:
		if crosses_yard(from, corner, yard) or PathUtils.flat_distance(from, corner) < 0.8:
			continue
		var cost := PathUtils.flat_distance(from, corner) + PathUtils.flat_distance(corner, outer)
		if cost < corner_cost:
			corner_cost = cost
			corner_best = corner
	return corner_best
