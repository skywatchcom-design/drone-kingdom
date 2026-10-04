class_name Walls
extends RefCounted
## Walls stand on the paths between pads. An edge is [c, r, d]: d = 0 is the path between
## cell (c, r) and (c + 1, r); d = 1 is the path between (c, r) and (c, r + 1). Edges reach one
## cell past the grid on every side, so a base can be walled all the way round.
## Ground units route over a grid of cells that includes a ring of open ground outside the
## base; a standing wall makes crossing its edge expensive instead of impossible, so when there
## is no way round, the path goes through the cheapest wall and the unit attacks it.

const LO := -1
const HI := City.GRID


static func key(e: Array) -> String:
	return "%d,%d,%d" % [int(e[0]), int(e[1]), int(e[2])]


static func valid(e: Array) -> bool:
	var c := int(e[0])
	var r := int(e[1])
	if int(e[2]) == 0:
		return c >= -1 and c < City.GRID and r >= 0 and r < City.GRID
	return c >= 0 and c < City.GRID and r >= -1 and r < City.GRID


## The world point in the middle of an edge.
static func center(e: Array) -> Vector3:
	var half := (City.GRID - 1) / 2.0
	var x := float(e[0]) - half
	var z := float(e[1]) - half
	if int(e[2]) == 0:
		x += 0.5
	else:
		z += 0.5
	return Vector3(x * City.SPACING, 0.0, z * City.SPACING)


## The two ends of a wall on this edge, on the ground.
static func ends(e: Array) -> Array:
	var c := center(e)
	var along := Vector3(0, 0, 1) if int(e[2]) == 0 else Vector3(1, 0, 0)
	return [c - along * City.SPACING / 2.0, c + along * City.SPACING / 2.0]


## The edge crossed when stepping from cell `a` to the neighbouring cell `b`.
static func between(a: Vector2i, b: Vector2i) -> Array:
	if b.x != a.x:
		return [mini(a.x, b.x), a.y, 0]
	return [a.x, mini(a.y, b.y), 1]


## The cell a point is in (cells outside the base count, one ring out).
static func cell_of(p: Vector3) -> Vector2i:
	var half := (City.GRID - 1) / 2.0
	return Vector2i(clampi(roundi(p.x / City.SPACING + half), LO, HI), clampi(roundi(p.z / City.SPACING + half), LO, HI))


static func cell_center(cell: Vector2i) -> Vector3:
	return City.cell_pos([cell.x, cell.y])


## Cheapest route of cells from `from` to `to` (not including `from`). Each step costs 1,
## and crossing a standing wall (a key in `walls`) costs `wall_cost` more.
static func find_path(from: Vector2i, to: Vector2i, walls: Dictionary, wall_cost: float) -> Array[Vector2i]:
	var dist := {}
	var prev := {}
	var open: Array = [[0.0, from]]
	dist[from] = 0.0
	while not open.is_empty():
		# Small grid (11 x 11): a linear scan for the cheapest open cell is fast enough.
		var best := 0
		for i in range(1, open.size()):
			if open[i][0] < open[best][0]:
				best = i
		var item: Array = open[best]
		open.remove_at(best)
		var cell: Vector2i = item[1]
		if cell == to:
			break
		if float(item[0]) > float(dist.get(cell, INF)):
			continue
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if next.x < LO or next.x > HI or next.y < LO or next.y > HI:
				continue
			var cost := float(item[0]) + 1.0
			if walls.has(key(between(cell, next))):
				cost += wall_cost
			if cost < float(dist.get(next, INF)):
				dist[next] = cost
				prev[next] = cell
				open.append([cost, next])
	var path: Array[Vector2i] = []
	if not prev.has(to) and from != to:
		return path
	var at := to
	while at != from:
		path.push_front(at)
		at = prev[at]
	return path


## True if the ground segments p1-p2 and q1-q2 cross.
static func segments_cross(p1: Vector3, p2: Vector3, q1: Vector3, q2: Vector3) -> bool:
	var d1 := _orient(q1, q2, p1)
	var d2 := _orient(q1, q2, p2)
	var d3 := _orient(p1, p2, q1)
	var d4 := _orient(p1, p2, q2)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _orient(a: Vector3, b: Vector3, c: Vector3) -> float:
	return (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)


## Wall edges in a rectangle's outline (cells c0..c1, r0..r1), skipping the edges listed by
## index in `gaps` (counted clockwise from the top-left). Used to lay out enemy bases.
static func ring(c0: int, r0: int, c1: int, r1: int, gaps: Array = []) -> Array:
	var edges := []
	for c in range(c0, c1 + 1):
		edges.append([c, r0 - 1, 1])
	for r in range(r0, r1 + 1):
		edges.append([c1, r, 0])
	for c in range(c1, c0 - 1, -1):
		edges.append([c, r1, 1])
	for r in range(r1, r0 - 1, -1):
		edges.append([c0 - 1, r, 0])
	var out := []
	for i in edges.size():
		if i not in gaps:
			out.append(edges[i])
	return out
