extends Node

# Drives the real AlphaSorter from scripts/alpha_sorter.gd, then checks the real
# scene's materials.
#
# mutate-driver: skip — the scene is instantiated to read real materials, not to test main.gd
#
# Sorting bugs are the definition of "looks plausible": the wrong order is still
# a picture, and it only reveals itself when the camera moves. Every assertion
# here is about an order, which is a thing that can be stated.

var _pass := 0
var _fail := 0
var _checked := false

func _ready() -> void:
	test_depth_is_not_distance()
	test_depth_behind_the_camera_is_negative()
	test_a_degenerate_view_direction()
	test_sorting_furthest_first()
	test_sorting_follows_the_camera()
	test_sorting_is_stable_for_equal_depths()
	test_sorting_nothing()
	test_priorities_run_in_order()
	test_priorities_stay_in_range()
	test_priorities_can_be_reversed()
	test_overlapping_depth_ranges()
	test_separated_depth_ranges()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[transparency-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const EYE := Vector3(0, 0, 10)
const FORWARD := Vector3(0, 0, -1)

func test_depth_is_not_distance() -> void:
	print("depth versus distance")
	# The one off to the side is further away in a straight line and nearer
	# along the view direction. Sorting by distance therefore reorders these two
	# as the camera turns, and the picture flickers between two orderings.
	var ahead := Vector3(0, 0, 0)
	var offset := Vector3(8, 0, 2)
	expect(EYE.distance_to(offset) > EYE.distance_to(ahead), "the offset one is further away")
	expect(AlphaSorter.depth_of(offset, EYE, FORWARD) < AlphaSorter.depth_of(ahead, EYE, FORWARD),
		"and yet nearer along the view direction, which is what the renderer sorts by")

func test_depth_behind_the_camera_is_negative() -> void:
	print("behind the camera")
	expect(AlphaSorter.depth_of(Vector3(0, 0, 20), EYE, FORWARD) < 0.0,
		"something behind the camera has negative depth")
	expect(is_zero_approx(AlphaSorter.depth_of(EYE, EYE, FORWARD)),
		"and something at the camera has none")

func test_a_degenerate_view_direction() -> void:
	print("no view direction")
	expect(not is_nan(AlphaSorter.depth_of(Vector3.ONE, EYE, Vector3.ZERO)),
		"a zero view direction falls back rather than producing a NAN")

func test_sorting_furthest_first() -> void:
	print("back to front")
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -20), Vector3(0, 0, -10)]
	var order := AlphaSorter.back_to_front(points, EYE, FORWARD)
	expect(order[0] == 1, "the furthest is drawn first")
	expect(order[2] == 0, "and the nearest last, so it blends over the rest")

func test_sorting_follows_the_camera() -> void:
	print("from the other side")
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -20)]
	var behind := Vector3(0, 0, -30)
	var order := AlphaSorter.back_to_front(points, behind, Vector3(0, 0, 1))
	expect(order[0] == 0, "seen from the other side, the order reverses")

func test_sorting_is_stable_for_equal_depths() -> void:
	print("equal depths")
	var points: Array[Vector3] = [Vector3(-5, 0, 0), Vector3(5, 0, 0), Vector3(0, 3, 0)]
	var first := AlphaSorter.back_to_front(points, EYE, FORWARD)
	var second := AlphaSorter.back_to_front(points, EYE, FORWARD)
	# Three objects at exactly the same depth have no correct order, so the only
	# requirement is that the answer does not change between frames — an
	# unstable sort here is a visible flicker with nothing moving.
	expect(first == second, "the same scene sorts the same way twice")
	expect(first[0] == 0, "with ties falling back to declaration order")

func test_sorting_nothing() -> void:
	print("nothing to sort")
	var none: Array[Vector3] = []
	expect(AlphaSorter.back_to_front(none, EYE, FORWARD).is_empty(),
		"an empty scene sorts to nothing rather than erroring")

func test_priorities_run_in_order() -> void:
	print("priorities")
	var priorities := AlphaSorter.priorities(4)
	expect(priorities.size() == 4, "one priority per object")
	var ascending := true
	for i in range(1, priorities.size()):
		if priorities[i] <= priorities[i - 1]:
			ascending = false
	expect(ascending, "each drawn later than the one before it")

func test_priorities_stay_in_range() -> void:
	print("the priority range")
	# render_priority is a signed byte. A list long enough to run past it has to
	# clamp rather than wrap, or the last objects jump to the front.
	var many := AlphaSorter.priorities(400)
	var inside := true
	for value in many:
		if value < -128 or value > 127:
			inside = false
	expect(inside, "priorities stay inside the range the renderer accepts")

func test_priorities_can_be_reversed() -> void:
	print("reversed")
	var forwards := AlphaSorter.priorities(3, true)
	var backwards := AlphaSorter.priorities(3, false)
	# Stated outright: for three objects the priorities are -1, 0, 1 one way
	# round and 1, 0, -1 the other. A pair of inequalities would pass for any
	# monotonic sequence, including one offset by a whole object.
	var expected_forwards: Array[int] = [-1, 0, 1]
	var expected_backwards: Array[int] = [1, 0, -1]
	expect(forwards == expected_forwards, "first-drawn-first counts up from the lowest")
	expect(backwards == expected_backwards, "and the other way round counts back down")
	expect(AlphaSorter.priorities(0).is_empty(), "no objects is no priorities")

func test_overlapping_depth_ranges() -> void:
	print("unsortable pairs")
	# Two boxes that overlap along the view direction: one is in front along
	# part of the screen and behind along the rest. No per-object order is
	# correct, which is the case alpha scissor exists for.
	var a := AABB(Vector3(-1, 0, -2), Vector3(2, 2, 4))
	var b := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 4))
	expect(AlphaSorter.depth_ranges_overlap(a, b, EYE, FORWARD),
		"two boxes crossing in depth are reported as unsortable")

func test_separated_depth_ranges() -> void:
	print("sortable pairs")
	var near := AABB(Vector3(-1, 0, 0), Vector3(2, 2, 1))
	var far := AABB(Vector3(-1, 0, -20), Vector3(2, 2, 1))
	expect(not AlphaSorter.depth_ranges_overlap(near, far, EYE, FORWARD),
		"two boxes with separate depth ranges sort perfectly well")

# --- the real materials ----------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real panes")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var panes: Node3D = scene.get_node("Panes")
	expect(panes.get_child_count() == 5, "the scene has panes to sort")

	var transparent := 0
	var two_sided := 0
	for pane in panes.get_children():
		var material := (pane as GeometryInstance3D).material_override as StandardMaterial3D
		if material == null:
			continue
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			transparent += 1
		# A single-sided transparent quad shows nothing from behind, which looks
		# like a sorting bug and is not one.
		if material.cull_mode == BaseMaterial3D.CULL_DISABLED:
			two_sided += 1
	expect(transparent == 5, "every pane is transparent")
	expect(two_sided == 5, "and two-sided, so turning the camera does not make one vanish")

	scene.queue_free()
	_report()
