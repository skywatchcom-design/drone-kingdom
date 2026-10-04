extends RefCounted


func _fresh_state() -> Node:
	var gs: Node = load("res://scripts/autoload/game_state.gd").new()
	gs.persist = false
	gs.new_player()
	return gs


func test_open_ground_path_is_direct() -> bool:
	var path := Walls.find_path(Vector2i(-1, 4), Vector2i(3, 4), {}, 8.0)
	return path.size() == 4 and path[-1] == Vector2i(3, 4)


func test_route_goes_round_a_short_wall() -> bool:
	# A wall straight ahead: one step to the side is cheaper than breaking through.
	var walls := {Walls.key([2, 4, 0]): true}
	var path := Walls.find_path(Vector2i(2, 4), Vector2i(3, 4), walls, 8.0)
	var crossed := false
	var at := Vector2i(2, 4)
	for next in path:
		if walls.has(Walls.key(Walls.between(at, next))):
			crossed = true
		at = next
	return not crossed and path.size() == 3


func test_route_breaks_through_a_full_ring() -> bool:
	# The target is boxed in on all four sides: the route has to cross exactly one wall.
	var walls := {}
	for e in Walls.ring(4, 4, 4, 4):
		walls[Walls.key(e)] = true
	var path := Walls.find_path(Vector2i(-1, 4), Vector2i(4, 4), walls, 8.0)
	var crossings := 0
	var at := Vector2i(-1, 4)
	for next in path:
		if walls.has(Walls.key(Walls.between(at, next))):
			crossings += 1
		at = next
	return walls.size() == 4 and crossings == 1 and path[-1] == Vector2i(4, 4)


func test_ring_outlines_a_rectangle() -> bool:
	return Walls.ring(2, 2, 4, 3).size() == 2 * 3 + 2 * 2 and Walls.ring(2, 2, 4, 3, [0, 1]).size() == 8


func test_edge_geometry() -> bool:
	var e := [3, 4, 0]
	var c := Walls.center(e)
	var ends: Array = Walls.ends(e)
	var mid_between := (City.cell_pos([3, 4]) + City.cell_pos([4, 4])) / 2.0
	return c.is_equal_approx(mid_between) and absf((ends[0] as Vector3).distance_to(ends[1]) - City.SPACING) < 0.01 \
		and Walls.valid([-1, 0, 0]) and not Walls.valid([9, 0, 0]) and Walls.valid([0, 8, 1])


func test_segments_cross() -> bool:
	return Walls.segments_cross(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)) \
		and not Walls.segments_cross(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(2, 0, -1), Vector3(2, 0, 1))


func test_build_and_upgrade_walls() -> bool:
	var gs := _fresh_state()
	gs.coins = 1000
	var built: bool = gs.build_wall([0, 0, 0])
	var twice: bool = gs.build_wall([0, 0, 0])
	var paid: bool = gs.coins == 1000 - Catalog.WALL_COST
	var capped: String = gs.wall_upgrade_reason([0, 0, 0])
	gs.structure_at([4, 4])["level"] = 3
	gs.build_wall([1, 0, 0])
	var count: int = gs.upgrade_walls_at_level(1)
	var levels_ok: bool = int(gs.wall_at([0, 0, 0])["level"]) == 2 and int(gs.wall_at([1, 0, 0])["level"]) == 2
	var removed: bool = gs.remove_wall([0, 0, 0]) and gs.walls.size() == 1
	gs.free()
	return built and not twice and paid and capped == "Upgrade the Command Tower first" and count == 2 and levels_ok and removed


func test_wall_limit_follows_command_tower() -> bool:
	var gs := _fresh_state()
	gs.infinite_coins = true
	var n := 0
	for c in range(-1, 9):
		for r in range(0, 9):
			if gs.build_wall([c, r, 0]):
				n += 1
	var reason: String = gs.wall_block_reason()
	gs.free()
	return n == Catalog.wall_limit(1) and reason.begins_with("Wall limit reached")
