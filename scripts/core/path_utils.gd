class_name PathUtils
extends RefCounted


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Inserts points so no gap is longer than `spacing`. Keeps the original points.
static func resample(points: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if points.is_empty():
		return out
	out.append(points[0])
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var steps := maxi(1, int(ceil(a.distance_to(b) / spacing)))
		for s in range(1, steps + 1):
			out.append(a.lerp(b, float(s) / steps))
	return out


## Index of the point closest to `pos` (ignoring height), searching from `from_index` on.
static func nearest_index(points: PackedVector3Array, pos: Vector3, from_index: int = 0) -> int:
	if points.is_empty():
		return 0
	var start := clampi(from_index, 0, points.size() - 1)
	var best := start
	var best_d := INF
	for i in range(start, points.size()):
		var d := flat_distance(points[i], pos)
		if d < best_d:
			best_d = d
			best = i
	return best
