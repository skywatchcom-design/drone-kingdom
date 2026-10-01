extends RefCounted


func test_resample_fills_long_gaps() -> bool:
	var out := PathUtils.resample(PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)]), 2.0)
	if out.size() != 6:
		return false
	for i in range(1, out.size()):
		if out[i - 1].distance_to(out[i]) > 2.0001:
			return false
	return out[out.size() - 1].is_equal_approx(Vector3(10, 0, 0))


func test_resample_keeps_short_paths() -> bool:
	var out := PathUtils.resample(PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)]), 2.0)
	return out.size() == 2


func test_resample_empty() -> bool:
	return PathUtils.resample(PackedVector3Array(), 2.0).is_empty()


func test_nearest_index_ignores_height() -> bool:
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(10, 0, 0)])
	return PathUtils.nearest_index(pts, Vector3(5.4, 30, 0)) == 1


func test_nearest_index_searches_forward_only() -> bool:
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(10, 0, 0)])
	return PathUtils.nearest_index(pts, Vector3(0, 0, 0), 1) == 1
