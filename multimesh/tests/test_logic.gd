extends Node

# Drives the real ScatterField from scripts/scatter_field.gd.
#
# Nothing here is about drawing. What is checkable — and what actually goes
# wrong — is the placement (does it clump, does it stay in the field, is it the
# same every run) and the ordering the cull depends on.

var _pass := 0
var _fail := 0

func _ready() -> void:
	test_the_count_asked_for()
	test_the_field_has_a_capacity()
	test_the_same_seed_scatters_the_same_way()
	test_a_new_seed_scatters_differently()
	test_everything_lands_inside_the_field()
	test_one_instance_per_cell()
	test_instances_only_rotate_about_up()
	test_scales_stay_in_range()
	test_a_height_function_places_them_on_the_ground()
	test_sorting_puts_the_nearest_first()
	test_sorting_leaves_the_original_alone()
	test_the_cull_counts_what_is_in_range()
	test_the_cull_grows_with_the_radius()
	test_degenerate_requests()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[multimesh] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _field() -> ScatterField:
	var field := ScatterField.new(4)
	field.area = 20.0
	field.cell = 2.0                       # 10 x 10 cells
	return field

func test_the_count_asked_for() -> void:
	print("count")
	expect(_field().transforms(50).size() == 50, "asking for 50 instances gives 50")
	expect(_field().transforms(0).is_empty(), "and asking for none gives none")

func test_the_field_has_a_capacity() -> void:
	print("capacity")
	var field := _field()
	expect(field.capacity() == 100, "a 20m field of 2m cells holds 100 instances")
	expect(field.transforms(500).size() == 100,
		"asking for more than fits is capped rather than overlapping them")

func test_the_same_seed_scatters_the_same_way() -> void:
	print("determinism")
	var a := _field().transforms(30)
	var b := _field().transforms(30)
	var same := true
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			same = false
	expect(same, "the same seed places every instance identically")

func test_a_new_seed_scatters_differently() -> void:
	print("seeds")
	var a := _field().transforms(30)
	var other := _field()
	other.set_seed(99)
	var b := other.transforms(30)
	var differences := 0
	for i in a.size():
		if not a[i].origin.is_equal_approx(b[i].origin):
			differences += 1
	expect(differences > 25, "a different seed moves nearly all of them")

func test_everything_lands_inside_the_field() -> void:
	print("bounds")
	var field := _field()
	var half := field.area * 0.5
	var outside := 0
	for item in field.transforms(100):
		if absf(item.origin.x) > half or absf(item.origin.z) > half:
			outside += 1
	expect(outside == 0, "no instance escapes the area, jitter included")

func test_one_instance_per_cell() -> void:
	print("no clumping")
	var field := _field()
	var items := field.transforms(100)
	# Pure random placement piles instances on top of each other; the jittered
	# grid is what stops that. Two instances in the same cell would mean the
	# grid indexing is wrong.
	var seen := {}
	var collisions := 0
	for item in items:
		var cell := Vector2i(
			int(floor((item.origin.x + field.area * 0.5) / field.cell)),
			int(floor((item.origin.z + field.area * 0.5) / field.cell)))
		if seen.has(cell):
			collisions += 1
		seen[cell] = true
	expect(collisions == 0, "every instance is in a cell of its own")
	expect(seen.size() == 100, "and every cell is used")

func test_instances_only_rotate_about_up() -> void:
	print("orientation")
	var tilted := 0
	for item in _field().transforms(40):
		# A scaled basis has a Y column of length min_scale..max_scale, so the
		# check is on direction, not magnitude. A tree leaning off vertical
		# reads as a bug however good the scattering is.
		if item.basis.y.normalized().dot(Vector3.UP) < 0.999:
			tilted += 1
	expect(tilted == 0, "every instance stands upright, rotated only about Y")

func test_scales_stay_in_range() -> void:
	print("scale")
	var field := _field()
	field.min_scale = 0.5
	field.max_scale = 2.0
	var smallest := 99.0
	var largest := 0.0
	for item in field.transforms(100):
		var scale := item.basis.get_scale().y
		smallest = minf(smallest, scale)
		largest = maxf(largest, scale)
	expect(smallest >= 0.5 - 0.001, "nothing is smaller than min_scale")
	expect(largest <= 2.0 + 0.001, "nothing is larger than max_scale")
	expect(largest - smallest > 0.5, "and the range is actually used")

func test_a_height_function_places_them_on_the_ground() -> void:
	print("on the ground")
	var field := _field()
	var height := func(x: float, z: float) -> float:
		return x * 0.1 + z * 0.2
	var wrong := 0
	for item in field.transforms(40, height):
		if not is_equal_approx(item.origin.y, item.origin.x * 0.1 + item.origin.z * 0.2):
			wrong += 1
	expect(wrong == 0, "with a height function, every instance sits on the surface")
	var flat := _field().transforms(10)
	expect(is_zero_approx(flat[0].origin.y), "and without one they sit at y = 0")

func test_sorting_puts_the_nearest_first() -> void:
	print("sorting")
	var items: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(10, 0, 0)),
		Transform3D(Basis(), Vector3(2, 0, 0)),
		Transform3D(Basis(), Vector3(6, 0, 0)),
	]
	var sorted := ScatterField.sorted_by_distance(items, Vector3.ZERO)
	expect(is_equal_approx(sorted[0].origin.x, 2.0), "the nearest instance comes first")
	expect(is_equal_approx(sorted[2].origin.x, 10.0), "and the furthest last")
	var from_far := ScatterField.sorted_by_distance(items, Vector3(20, 0, 0))
	expect(is_equal_approx(from_far[0].origin.x, 10.0), "the order follows the viewer")

func test_sorting_leaves_the_original_alone() -> void:
	print("no surprises")
	var items: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(10, 0, 0)),
		Transform3D(Basis(), Vector3(2, 0, 0)),
	]
	ScatterField.sorted_by_distance(items, Vector3.ZERO)
	expect(is_equal_approx(items[0].origin.x, 10.0),
		"sorting returns a new list rather than reordering the caller's")

func test_the_cull_counts_what_is_in_range() -> void:
	print("culling")
	var items: Array[Transform3D] = []
	for i in 10:
		items.append(Transform3D(Basis(), Vector3(float(i), 0, 0)))
	var sorted := ScatterField.sorted_by_distance(items, Vector3.ZERO)
	# Instances sit at 0..9 metres, so a radius of 4.5 takes the first five.
	expect(ScatterField.visible_within(sorted, Vector3.ZERO, 4.5) == 5,
		"the count is how many are inside the radius")
	expect(ScatterField.visible_within(sorted, Vector3.ZERO, 100.0) == 10,
		"a radius past everything draws everything")
	expect(ScatterField.visible_within(sorted, Vector3.ZERO, 0.0) == 0,
		"and a radius of zero draws nothing")

func test_the_cull_grows_with_the_radius() -> void:
	print("radius")
	var field := _field()
	var sorted := ScatterField.sorted_by_distance(field.transforms(100), Vector3.ZERO)
	var near := ScatterField.visible_within(sorted, Vector3.ZERO, 5.0)
	var far := ScatterField.visible_within(sorted, Vector3.ZERO, 12.0)
	expect(far > near, "a larger radius draws more")
	expect(near > 0, "and a small one still draws something")

func test_degenerate_requests() -> void:
	print("degenerate input")
	var field := _field()
	expect(field.transforms(-5).is_empty(), "a negative count is no instances, not a crash")
	field.cell = 0.0
	expect(field.capacity() > 0, "a cell size of zero does not divide by zero")
