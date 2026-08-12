extends Node

# Drives the real MeshBuilder from scripts/mesh_builder.gd.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_counts_match_the_formula()
	test_grid_is_a_real_mesh()
	test_grid_is_centred_and_sized()
	test_grid_is_flat_without_a_height_function()
	test_height_function_is_applied()
	test_normals_are_generated()
	test_ring_closes()
	test_degenerate_inputs()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[procedural-mesh] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _arrays(mesh: ArrayMesh) -> Array:
	return mesh.surface_get_arrays(0)

func test_counts_match_the_formula() -> void:
	print("vertex and index counts")
	var counts := MeshBuilder.grid_counts(4)
	expect(counts["vertices"] == 25, "a 4x4 grid has 5x5 = 25 vertices")
	expect(counts["indices"] == 96, "and 16 cells x 2 triangles x 3 indices = 96")

func test_grid_is_a_real_mesh() -> void:
	print("the grid commits to an ArrayMesh")
	var mesh := MeshBuilder.grid(10.0, 4)
	expect(mesh != null, "a mesh is produced")
	expect(mesh.get_surface_count() == 1, "with one surface")
	var arrays := _arrays(mesh)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	expect(verts.size() == 25, "the vertex count matches the formula")
	expect(indices.size() == 96, "so does the index count")
	# Every index must address a real vertex, or the mesh renders as garbage.
	var in_range := true
	for i in indices:
		if i < 0 or i >= verts.size():
			in_range = false
	expect(in_range, "every index points at a vertex that exists")

func test_grid_is_centred_and_sized() -> void:
	print("extent")
	var mesh := MeshBuilder.grid(10.0, 4)
	var verts: PackedVector3Array = _arrays(mesh)[Mesh.ARRAY_VERTEX]
	var min_x := INF
	var max_x := -INF
	for v in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	expect(is_equal_approx(min_x, -5.0), "the grid starts at -size/2")
	expect(is_equal_approx(max_x, 5.0), "and ends at +size/2")

func test_grid_is_flat_without_a_height_function() -> void:
	print("flat by default")
	var verts: PackedVector3Array = _arrays(MeshBuilder.grid(4.0, 3))[Mesh.ARRAY_VERTEX]
	var flat := true
	for v in verts:
		if not is_zero_approx(v.y):
			flat = false
	expect(flat, "with no height callable every vertex sits on y = 0")

func test_height_function_is_applied() -> void:
	print("height callable")
	var mesh := MeshBuilder.grid(4.0, 3, func(x: float, z: float) -> float: return x + z)
	var verts: PackedVector3Array = _arrays(mesh)[Mesh.ARRAY_VERTEX]
	var matched := true
	for v in verts:
		if not is_equal_approx(v.y, v.x + v.z):
			matched = false
	expect(matched, "every vertex takes its height from the callable")

func test_normals_are_generated() -> void:
	print("normals")
	var arrays := _arrays(MeshBuilder.grid(4.0, 2))
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	expect(normals.size() > 0, "normals are present — without them nothing lights")
	var all_up := true
	for n in normals:
		if not is_equal_approx(n.dot(Vector3.UP), 1.0):
			all_up = false
	# Winding order decides this. If the triangles were wound the other way the
	# normals would point down and the surface would be invisible from above.
	expect(all_up, "a flat grid's normals point up, so it faces the sky")

func test_ring_closes() -> void:
	print("ring")
	var mesh := MeshBuilder.ring(3.0, 1.0, 8)
	var arrays := _arrays(mesh)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	expect(verts.size() == 16, "8 segments produce 8 top and 8 bottom vertices")
	expect(indices.size() == 8 * 6, "and two triangles per segment")
	# The last segment must wrap to the first, or the ring has a gap.
	var used: Dictionary = {}
	for i in indices:
		used[i] = true
	expect(used.size() == verts.size(), "every vertex is used — the ring closes")

	var radii_ok := true
	for v in verts:
		if not is_equal_approx(Vector2(v.x, v.z).length(), 3.0):
			radii_ok = false
	expect(radii_ok, "every vertex sits on the radius")

func test_degenerate_inputs() -> void:
	print("degenerate inputs")
	expect(MeshBuilder.grid_counts(0)["vertices"] == 4, "zero subdivisions is floored to one cell")
	var tiny := MeshBuilder.grid(1.0, 0)
	expect(tiny.get_surface_count() == 1, "and still produces a mesh")
	var thin := MeshBuilder.ring(1.0, 0.5, 1)
	expect(thin.get_surface_count() == 1, "a ring is floored to three segments rather than failing")
