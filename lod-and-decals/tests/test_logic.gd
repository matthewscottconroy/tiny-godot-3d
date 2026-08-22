extends Node

# Drives the real LodBands from scripts/lod_bands.gd, then checks the ranges
# reached the real meshes.
#
# mutate-driver: skip — the scene is instantiated to read real visibility ranges, not to test main.gd
#
# Flicker at a band boundary is the classic LOD bug: it is a frame-by-frame
# oscillation that a screenshot cannot show and a bug report cannot describe.
# It is also, written down, an entirely ordinary thing to assert.

var _pass := 0
var _fail := 0
var _checked := false

func _ready() -> void:
	test_levels_by_distance()
	test_the_last_level_runs_to_the_horizon()
	test_hysteresis_holds_a_level_at_the_boundary()
	test_it_still_changes_when_you_go_far_enough()
	test_no_hysteresis_switches_immediately()
	test_a_camera_sitting_on_a_boundary_does_not_oscillate()
	test_ranges_line_up_with_the_bands()
	test_every_level_has_a_range()
	test_the_fade()
	test_update_intervals_grow_with_distance()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[lod-and-decals] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _bands() -> LodBands:
	var bands := LodBands.new()
	bands.distances = [10.0, 25.0, 50.0]
	bands.hysteresis = 2.0
	return bands

func test_levels_by_distance() -> void:
	print("levels")
	var bands := _bands()
	expect(bands.level_for(0.0) == 0, "right in front of the camera is the closest level")
	expect(bands.level_for(9.9) == 0, "just inside the first band is still level 0")
	expect(bands.level_for(10.1) == 1, "and just past it is level 1")
	expect(bands.level_for(40.0) == 2, "further out again is level 2")

func test_the_last_level_runs_to_the_horizon() -> void:
	print("the far level")
	var bands := _bands()
	expect(bands.level_for(1000.0) == 3, "past the last band there is one more level")
	expect(bands.range_for(3).y == 0.0,
		"whose range has no far limit — zero is what Godot reads as 'no limit'")

func test_hysteresis_holds_a_level_at_the_boundary() -> void:
	print("hysteresis")
	var bands := _bands()
	# Standing at 10.5 metres, having already been at level 0: the naive answer
	# is level 1, and taking it every frame while the camera breathes is the
	# flicker.
	expect(bands.level_for(10.5) == 1, "the naive answer changes level")
	expect(bands.stable_level_for(10.5, 0) == 0, "the stable one holds where it is")
	expect(bands.stable_level_for(9.5, 1) == 1, "in both directions")

func test_it_still_changes_when_you_go_far_enough() -> void:
	print("actually changing")
	var bands := _bands()
	expect(bands.stable_level_for(13.0, 0) == 1, "far enough past the boundary, the level changes")
	expect(bands.stable_level_for(7.0, 1) == 0, "and coming back changes it back")
	expect(bands.stable_level_for(60.0, 0) == 3, "a big jump lands on the right level, not the next one")

func test_no_hysteresis_switches_immediately() -> void:
	print("no margin")
	var bands := _bands()
	bands.hysteresis = 0.0
	expect(bands.stable_level_for(10.5, 0) == 1,
		"with no margin, the stable answer is the naive one")

func test_a_camera_sitting_on_a_boundary_does_not_oscillate() -> void:
	print("no flicker")
	var bands := _bands()
	var level := 0
	var changes := 0
	# A camera hovering either side of a boundary, as one does while standing
	# still and breathing on the analogue stick.
	for i in 200:
		var distance := 10.0 + sin(float(i) * 0.7) * 1.0
		var next := bands.stable_level_for(distance, level)
		if next != level:
			changes += 1
		level = next
	expect(changes <= 1, "a camera wobbling across a boundary changes level at most once (%d)"
		% changes)

func test_ranges_line_up_with_the_bands() -> void:
	print("ranges")
	var bands := _bands()
	expect(bands.range_for(0) == Vector2(0.0, 10.0), "the near mesh is visible from zero out")
	expect(bands.range_for(1) == Vector2(10.0, 25.0), "the next takes over exactly where it ends")
	expect(bands.range_for(2) == Vector2(25.0, 50.0), "and so on, with no gap between them")

func test_every_level_has_a_range() -> void:
	print("the whole chain")
	var bands := _bands()
	var ranges := bands.ranges()
	expect(ranges.size() == 4, "three bands make four levels")
	var contiguous := true
	for i in range(1, ranges.size()):
		if not is_equal_approx(ranges[i].x, ranges[i - 1].y):
			contiguous = false
	expect(contiguous, "and each begins where the last ended, so nothing is invisible")

func test_the_fade() -> void:
	print("fading")
	expect(is_equal_approx(LodBands.fade_alpha(5.0, 30.0, 10.0), 1.0), "close up, fully opaque")
	expect(is_zero_approx(LodBands.fade_alpha(35.0, 30.0, 10.0)), "past the end, gone")
	expect(absf(LodBands.fade_alpha(25.0, 30.0, 10.0) - 0.5) < 0.001, "and halfway through the fade, half")
	expect(is_equal_approx(LodBands.fade_alpha(1000.0, 0.0, 10.0), 1.0),
		"with no end at all, always opaque")
	expect(not is_nan(LodBands.fade_alpha(29.0, 30.0, 0.0)),
		"a fade of no length does not divide by zero")

func test_update_intervals_grow_with_distance() -> void:
	print("update rates")
	var bands := _bands()
	var near := bands.update_interval(0)
	var far := bands.update_interval(3)
	# The half of LOD nobody sees: an enemy fifty metres away does not need its
	# state machine run sixty times a second.
	expect(far > near, "distant things update less often")
	expect(is_equal_approx(near, 1.0 / 60.0), "while close ones update every frame")

# --- the real meshes -------------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real props")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var props: Node3D = scene.get_node("Props")
	expect(props.get_child_count() > 0, "the driver built its props")

	var prop := props.get_child(0) as Node3D
	expect(prop.get_child_count() == 3, "each has a mesh per level")
	var near := prop.get_child(0) as GeometryInstance3D
	var mid := prop.get_child(1) as GeometryInstance3D
	expect(is_zero_approx(near.visibility_range_begin), "the near mesh is visible from the camera out")
	expect(near.visibility_range_end > 0.0, "up to a limit")
	expect(is_equal_approx(mid.visibility_range_begin, near.visibility_range_end),
		"and the next takes over exactly where it stops")
	# Without a fade the switch is a pop, which is the thing visibility ranges
	# are supposed to be better than.
	expect(near.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
		"with a fade rather than a pop")

	var decal: Decal = scene.get_node("Decal")
	expect(decal.distance_fade_begin > 0.0, "and the decal fades with distance too")

	scene.queue_free()
	_report()
