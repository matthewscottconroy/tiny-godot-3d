extends Node

# Drives the real MeshBuilder from scripts/mesh_builder.gd.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_counts_match_the_formula()
	test_grid_is_a_real_mesh()
	test_grid_indices_are_the_two_triangles_of_each_cell()
	test_grid_is_centred_and_sized()
	test_grid_is_flat_without_a_height_function()
	test_height_function_is_applied()
	test_normals_are_generated()
	test_ring_closes()
	test_ring_winding()
	test_ring_has_thickness()
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

func test_grid_indices_are_the_two_triangles_of_each_cell() -> void:
	print("grid winding")
	# One subdivision is one cell and four vertices, so the whole index list
	# fits on a line: 0,1,2 then 1,3,2. Stating it outright rather than counting
	# is what catches a cell that indexes the wrong row — the failure that
	# renders as a mesh full of holes rather than as an error.
	#
	#   2---3      row = 2 (one vertex more than the subdivision count)
	#   | \ |      first  triangle: 0, 1, 2
	#   0---1      second triangle: 1, 3, 2
	var mesh := MeshBuilder.grid(2.0, 1)
	var indices: PackedInt32Array = _arrays(mesh)[Mesh.ARRAY_INDEX]
	expect(indices == PackedInt32Array([0, 1, 2, 1, 3, 2]),
		"a single cell is two triangles sharing the diagonal 1-2")

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

func test_ring_has_thickness() -> void:
	print("ring thickness")
	# Each segment adds a vertex above the mid-line and one below it. Adding
	# both on the same side leaves a ring with no height at all — every other
	# assertion here (radius, counts, closure) still holds.
	var mesh := MeshBuilder.ring(3.0, 1.0, 8)
	var verts: PackedVector3Array = _arrays(mesh)[Mesh.ARRAY_VERTEX]
	var split := true
	for i in verts.size():
		var wanted := 0.5 if i % 2 == 0 else -0.5
		if not is_equal_approx(verts[i].y, wanted):
			split = false
	expect(split, "each segment straddles the mid-line by half the thickness")
	var thin := MeshBuilder.ring(3.0, 0.2, 6)
	var thin_verts: PackedVector3Array = _arrays(thin)[Mesh.ARRAY_VERTEX]
	expect(is_equal_approx(thin_verts[0].y - thin_verts[1].y, 0.2),
		"and the gap between the two is the thickness asked for")

func test_ring_winding() -> void:
	print("ring winding")
	# Four segments, so the indices are short enough to state outright. Each
	# segment indexes its own vertex pair and the pair after it; the last one
	# wraps back to vertices 0 and 1, which is what makes it a ring rather than
	# an open strip. Asserting the shape of the triangles rather than just their
	# count is what catches an off-by-one in the wrap.
	var mesh := MeshBuilder.ring(1.0, 0.5, 4)
	var indices: PackedInt32Array = _arrays(mesh)[Mesh.ARRAY_INDEX]
	var expected := PackedInt32Array([
		0, 1, 2, 2, 1, 3,
		2, 3, 4, 4, 3, 5,
		4, 5, 6, 6, 5, 7,
		6, 7, 0, 0, 7, 1])
	expect(indices == expected, "each segment links to the next, and the last wraps to the first")
	var vertices: PackedVector3Array = _arrays(mesh)[Mesh.ARRAY_VERTEX]
	var in_range := true
	for i in indices:
		if i < 0 or i >= vertices.size():
			in_range = false
	expect(in_range, "and no index points outside the vertex array")

func test_degenerate_inputs() -> void:
	print("degenerate inputs")
	expect(MeshBuilder.grid_counts(0)["vertices"] == 4, "zero subdivisions is floored to one cell")
	var tiny := MeshBuilder.grid(1.0, 0)
	expect(tiny.get_surface_count() == 1, "and still produces a mesh")
	var thin := MeshBuilder.ring(1.0, 0.5, 1)
	expect(thin.get_surface_count() == 1, "a ring is floored to three segments rather than failing")
