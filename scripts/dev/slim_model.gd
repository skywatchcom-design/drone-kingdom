extends SceneTree
## Dev tool: turns a heavy AI-generated GLB (TRELLIS.2) into a light mesh for phones.
## Godot's importer already builds simplified LODs; this keeps the one closest to the target
## triangle count, drops unused vertices, re-centers it with its feet at y = 0, scales it to
## `height` and saves it as a .res (no material: game code adds one from the albedo texture).
##   godot --headless --path . -s scripts/dev/slim_model.gd -- in.glb out.res target_tris height


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var src: String = a[0]
	var dst: String = a[1]
	var target := int(a[2]) if a.size() > 2 else 6000
	var height := float(a[3]) if a.size() > 3 else 1.0
	var scene: PackedScene = load(src)
	var inst := scene.instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	# Let Godot's mesh optimizer build simplified levels; repeat on the result until the
	# triangle count gets near the target (seams stop a single pass early).
	for round in 6:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(25.0, 60.0, [])
		var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for l in im.get_surface_lod_count(0):
			var idx := im.get_surface_lod_indices(0, l)
			if absi(idx.size() / 3 - target) < absi(best.size() / 3 - target):
				best = idx
		var before := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		arrays = _compact(arrays, best)
		print("round ", round, ": ", before, " -> ", best.size() / 3)
		if best.size() / 3 <= target * 1.2 or best.size() / 3 >= before:
			break
	# Still too heavy: merge vertices that share a small grid cell and a texture area (so
	# texture seams stay apart), then drop collapsed triangles.
	var cells := float(a[4]) if a.size() > 4 else 70.0
	while (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 > target * 1.3 and cells > 12.0:
		arrays = _cluster(arrays, cells)
		print("cluster ", cells, " -> ", (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
		cells *= 0.85
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var out := arrays
	# Feet on the ground, centered, scaled to the wanted height.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var k := height / maxf(0.001, hi.y - lo.y)
	var shift := Vector3(-(lo.x + hi.x) / 2.0, -lo.y, -(lo.z + hi.z) / 2.0)
	for i in verts.size():
		verts[i] = (verts[i] + shift) * k
	out[Mesh.ARRAY_VERTEX] = verts
	var indices: PackedInt32Array = out[Mesh.ARRAY_INDEX]
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	# The material is built in game code from the albedo texture saved next to the mesh, so
	# the mesh does not depend on the source GLB.
	var err := ResourceSaver.save(am, dst)
	print("saved ", dst, " tris ", indices.size() / 3, " verts ", verts.size(), " err ", err)
	quit()


## Arrays holding only the vertices `idx` uses, re-indexed.
func _compact(arrays: Array, idx: PackedInt32Array) -> Array:
	var remap := {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_t = arrays[Mesh.ARRAY_TANGENT]
	var has_t: bool = src_t != null and (src_t as PackedFloat32Array).size() > 0
	var indices := PackedInt32Array()
	for i in idx:
		if not remap.has(i):
			remap[i] = verts.size()
			verts.append(src_v[i])
			normals.append(src_n[i])
			uvs.append(src_uv[i])
			if has_t:
				for k in 4:
					tangents.append((src_t as PackedFloat32Array)[i * 4 + k])
		indices.append(remap[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	if has_t:
		out[Mesh.ARRAY_TANGENT] = tangents
	out[Mesh.ARRAY_INDEX] = indices
	return out



func _cluster(arrays: Array, cells: float) -> Array:
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in src_v:
		lo = lo.min(v)
		hi = hi.max(v)
	var cell := (hi.y - lo.y) / cells
	var uv_cells := cells * 0.6
	var key_of := {}
	var sum_v := []
	var sum_n := []
	var sum_uv := []
	var count := []
	var map := PackedInt32Array()
	map.resize(src_v.size())
	for i in src_v.size():
		var c := ((src_v[i] - lo) / cell).floor()
		var u := (src_uv[i] * uv_cells).floor()
		var key := "%d,%d,%d,%d,%d" % [c.x, c.y, c.z, u.x, u.y]
		var id: int = key_of.get(key, -1)
		if id < 0:
			id = sum_v.size()
			key_of[key] = id
			sum_v.append(Vector3.ZERO)
			sum_n.append(Vector3.ZERO)
			sum_uv.append(Vector2.ZERO)
			count.append(0)
		sum_v[id] += src_v[i]
		sum_n[id] += src_n[i]
		sum_uv[id] += src_uv[i]
		count[id] += 1
		map[i] = id
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for id in sum_v.size():
		verts.append(sum_v[id] / count[id])
		normals.append((sum_n[id] as Vector3).normalized())
		uvs.append(sum_uv[id] / count[id])
	var indices := PackedInt32Array()
	var seen := {}
	for t in range(0, src_i.size(), 3):
		var a0 := map[src_i[t]]
		var a1 := map[src_i[t + 1]]
		var a2 := map[src_i[t + 2]]
		if a0 == a1 or a1 == a2 or a0 == a2:
			continue
		var tri := Vector3i(a0, a1, a2)
		if seen.has(tri):
			continue
		seen[tri] = true
		indices.append(a0)
		indices.append(a1)
		indices.append(a2)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = indices
	return out
