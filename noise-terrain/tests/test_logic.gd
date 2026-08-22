extends Node

# Drives the real TerrainField from scripts/terrain_field.gd.
#
# The assertion that matters most is the last one: a vertex of the built mesh
# has to sit exactly where height_at() says the ground is. Everything placed on
# terrain later — the player, trees, spawn points — trusts that function, and if
# it drifts from the mesh nothing errors, things just hover.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_the_same_seed_gives_the_same_ground()
	test_a_different_seed_gives_different_ground()
	test_heights_stay_within_the_amplitude()
	test_the_ground_is_not_flat()
	test_amplitude_scales_the_hills()
	test_normals_point_up_and_are_unit_length()
	test_flat_ground_has_no_slope()
	test_normals_lean_away_from_the_slope()
	test_regions_follow_height()
	test_the_region_thresholds()
	test_steep_ground_is_rock_whatever_its_height()
	test_counts_match_the_formula()
	test_the_mesh_matches_the_counts()
	test_the_mesh_spans_the_size_asked_for()
	test_the_mesh_agrees_with_height_at()
	test_a_degenerate_resolution()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[noise-terrain] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _arrays(mesh: ArrayMesh) -> Array:
	return mesh.surface_get_arrays(0)

# --- the height field ------------------------------------------------------

func test_the_same_seed_gives_the_same_ground() -> void:
	print("determinism")
	var a := TerrainField.new(7)
	var b := TerrainField.new(7)
	expect(is_equal_approx(a.height_at(3.0, -4.0), b.height_at(3.0, -4.0)),
		"the same seed gives the same height at the same place")
	expect(is_equal_approx(a.height_at(3.0, -4.0), a.height_at(3.0, -4.0)),
		"and asking twice gives the same answer — the field has no hidden state")

func test_a_different_seed_gives_different_ground() -> void:
	print("seeds")
	var a := TerrainField.new(7)
	var b := TerrainField.new(8)
	var differences := 0
	for i in 20:
		if absf(a.height_at(i * 3.0, 0.0) - b.height_at(i * 3.0, 0.0)) > 0.01:
			differences += 1
	expect(differences > 15, "a different seed is a different landscape")

func test_heights_stay_within_the_amplitude() -> void:
	print("amplitude")
	var field := TerrainField.new(3)
	var worst := 0.0
	for x in 60:
		for z in 60:
			worst = maxf(worst, absf(field.height_at(x * 0.7 - 20.0, z * 0.7 - 20.0)))
	expect(worst <= field.amplitude + 0.001, "no point rises above the amplitude")
	expect(worst > field.amplitude * 0.4, "while the range is actually being used")

func test_the_ground_is_not_flat() -> void:
	print("variation")
	var field := TerrainField.new(3)
	var lowest := 999.0
	var highest := -999.0
	for i in 100:
		var h := field.height_at(i * 0.9 - 45.0, i * 0.4)
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	expect(highest - lowest > field.amplitude, "there are hills and valleys, not a plane")

func test_amplitude_scales_the_hills() -> void:
	print("scaling")
	var low := TerrainField.new(5)
	var high := TerrainField.new(5)
	high.amplitude = low.amplitude * 3.0
	expect(is_equal_approx(high.height_at(4.0, 4.0), low.height_at(4.0, 4.0) * 3.0),
		"three times the amplitude is three times the height, everywhere")

func test_normals_point_up_and_are_unit_length() -> void:
	print("normals")
	var field := TerrainField.new(2)
	var normal := field.normal_at(1.0, 1.0)
	expect(is_equal_approx(normal.length(), 1.0), "a normal is a unit vector")
	expect(normal.y > 0.0, "and points out of the ground, not into it")

func test_flat_ground_has_no_slope() -> void:
	print("slope")
	var field := TerrainField.new(2)
	field.amplitude = 0.0                  # perfectly flat
	expect(field.normal_at(0.0, 0.0).is_equal_approx(Vector3.UP),
		"flat ground has a straight-up normal")
	expect(is_zero_approx(field.slope_at(0.0, 0.0)), "and no slope at all")
	field.amplitude = 40.0                 # violently steep
	var steep := 0.0
	for i in 40:
		steep = maxf(steep, field.slope_at(i * 1.3, i * 0.7))
	expect(steep > 0.3, "a violently steep field reports steep ground")

func test_normals_lean_away_from_the_slope() -> void:
	print("normal direction")
	var flat := TerrainField.new(1)
	flat.amplitude = 0.0
	expect(flat.normal_at(0.0, 0.0).is_equal_approx(Vector3.UP), "flat ground leans nowhere")

	# Several sloped spots, not the first one that qualifies: a normal computed
	# from the height instead of from the slope agrees with the right answer
	# often enough to pass a single sample.
	var field := TerrainField.new(1)
	var step := 0.5
	var checked_x := 0
	var wrong_x := 0
	for i in 300:
		var x := i * 0.37 - 55.0
		var rise := field.height_at(x + step, 0.0) - field.height_at(x - step, 0.0)
		if absf(rise) < 0.15:
			continue
		checked_x += 1
		if (rise > 0.0) != (field.normal_at(x, 0.0, step).x < 0.0):
			wrong_x += 1
	expect(checked_x >= 8, "there are sloped places to check along X (%d)" % checked_x)
	expect(wrong_x == 0, "and the normal leans against the climb at every one of them")

	var checked_z := 0
	var wrong_z := 0
	for i in 300:
		var z := i * 0.41 - 61.0
		var rise := field.height_at(0.0, z + step) - field.height_at(0.0, z - step)
		if absf(rise) < 0.15:
			continue
		checked_z += 1
		if (rise > 0.0) != (field.normal_at(0.0, z, step).z < 0.0):
			wrong_z += 1
	# Both axes: the two slopes are computed separately, and one of them is easy
	# to leave out of a test that only ever walks along X.
	expect(checked_z >= 8, "and sloped places along Z as well (%d)" % checked_z)
	expect(wrong_z == 0, "where it leans against the climb too")

func test_regions_follow_height() -> void:
	print("regions")
	var field := TerrainField.new(2)
	field.amplitude = 0.0
	# Flat ground at height zero is above the water and sand thresholds, and is
	# not steep, so it is grass.
	expect(field.region_at(0.0, 0.0) == 2, "flat ground at sea level is grass")

func test_the_region_thresholds() -> void:
	print("thresholds")
	# Stated as numbers, because "it looked sandy" is not a check. Amplitude 10
	# puts water below -3.5, sand between -3.5 and -1, grass above.
	expect(TerrainField.region_for(-5.0, 0.0, 10.0) == 0, "well below sea level is water")
	expect(TerrainField.region_for(-2.0, 0.0, 10.0) == 1, "the shallows are sand")
	expect(TerrainField.region_for(-0.5, 0.0, 10.0) == 2, "just above them is grass")
	expect(TerrainField.region_for(6.0, 0.0, 10.0) == 2, "and so are the hilltops")
	expect(TerrainField.region_for(-3.6, 0.0, 10.0) == 0, "the water line is where it says it is")
	expect(TerrainField.region_for(-3.4, 0.0, 10.0) == 1, "with sand immediately above it")
	expect(TerrainField.region_for(6.0, 0.9, 10.0) == 3, "steep ground is rock at any height")
	expect(TerrainField.region_for(-5.0, 0.9, 10.0) == 3, "including underwater")

func test_steep_ground_is_rock_whatever_its_height() -> void:
	print("cliffs")
	var field := TerrainField.new(2)
	field.amplitude = 60.0                 # cliffs everywhere
	var rock := 0
	for i in 40:
		if field.region_at(i * 1.7 - 30.0, i * 0.9) == 3:
			rock += 1
	# Height alone would paint the low ground blue and the high ground green;
	# the slope rule is what stops grass growing on a vertical face.
	expect(rock > 20, "steep ground comes back as rock rather than by its height")

# --- the mesh --------------------------------------------------------------

func test_counts_match_the_formula() -> void:
	print("counts")
	var counts := TerrainField.counts(4)
	expect(counts["vertices"] == 25, "a 4x4 grid has 5x5 = 25 vertices")
	expect(counts["indices"] == 96, "and 16 cells x 2 triangles x 3 indices = 96")

func test_the_mesh_matches_the_counts() -> void:
	print("the built mesh")
	var field := TerrainField.new(4)
	var mesh := field.build_mesh(10.0, 4)
	var arrays := _arrays(mesh)
	expect(mesh.get_surface_count() == 1, "one surface")
	expect((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 25,
		"with the vertex count the formula predicts")
	expect((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == 96,
		"and the index count too")
	expect((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == 25,
		"and a normal per vertex, generated from the geometry")
	expect((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == 25,
		"and a colour per vertex, which is what makes it look like anything")

func test_the_mesh_spans_the_size_asked_for() -> void:
	print("extent")
	var field := TerrainField.new(4)
	var aabb := field.build_mesh(20.0, 8).get_aabb()
	expect(is_equal_approx(aabb.size.x, 20.0), "the mesh is as wide as it was asked to be")
	expect(is_equal_approx(aabb.size.z, 20.0), "in both directions")
	expect(is_equal_approx(aabb.position.x, -10.0), "and is centred on the origin")
	# Both axes. A row loop that subtracts where it should add still produces a
	# mesh 20 metres across — just not one anywhere near the middle of the world.
	expect(is_equal_approx(aabb.position.z, -10.0), "on the Z axis as well as the X")

func test_the_mesh_agrees_with_height_at() -> void:
	print("one source of truth")
	var field := TerrainField.new(11)
	var mesh := field.build_mesh(20.0, 10)
	var vertices: PackedVector3Array = _arrays(mesh)[Mesh.ARRAY_VERTEX]
	var mismatches := 0
	for vertex in vertices:
		if not is_equal_approx(vertex.y, field.height_at(vertex.x, vertex.z)):
			mismatches += 1
	# The whole reason the mesh is built by calling height_at() rather than by
	# sampling the noise a second time. Anything placed on the terrain later
	# uses this function, and a mesh that disagrees leaves everything hovering.
	expect(mismatches == 0, "every vertex sits exactly where height_at() says the ground is")

func test_a_degenerate_resolution() -> void:
	print("degenerate input")
	var field := TerrainField.new(1)
	expect(TerrainField.counts(0)["vertices"] == 4, "zero cells is floored to one")
	var mesh := field.build_mesh(10.0, 0)
	expect(mesh != null and mesh.get_surface_count() == 1,
		"and still produces a mesh rather than an empty resource")
