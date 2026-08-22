extends Node

# Drives the real ScreenLayout from scripts/screen_layout.gd, then checks the
# real panes really do share one world.
#
# mutate-driver: skip — the scene is instantiated to inspect real SubViewports, not to test main.gd

var _pass := 0
var _fail := 0
var _checked := false

const SIZE := Vector2i(1280, 720)

func _ready() -> void:
	test_one_player_gets_everything()
	test_two_players_split_horizontally()
	test_two_players_split_vertically()
	test_three_players()
	test_four_players()
	test_no_gaps_at_any_count()
	test_odd_sizes_leave_no_seam()
	test_coverage_rejects_bad_layouts()
	test_out_of_range_counts()
	test_aspect_ratios()
	test_matching_the_field_of_view()
	test_degenerate_aspects()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[split-screen-3d] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func test_one_player_gets_everything() -> void:
	print("one player")
	var rects := ScreenLayout.rects(1, SIZE)
	expect(rects.size() == 1, "one pane")
	expect(rects[0] == Rect2i(Vector2i.ZERO, SIZE), "covering the whole window")

func test_two_players_split_horizontally() -> void:
	print("two, stacked")
	var rects := ScreenLayout.rects(2, SIZE, ScreenLayout.Split.HORIZONTAL)
	expect(rects.size() == 2, "two panes")
	expect(rects[0].size == Vector2i(1280, 360), "the top one is full width, half height")
	expect(rects[1].position == Vector2i(0, 360), "and the second starts where the first ends")

func test_two_players_split_vertically() -> void:
	print("two, side by side")
	var rects := ScreenLayout.rects(2, SIZE, ScreenLayout.Split.VERTICAL)
	expect(rects[0].size == Vector2i(640, 720), "the left pane is half width, full height")
	expect(rects[1].position == Vector2i(640, 0), "and the right one starts at the halfway point")

func test_three_players() -> void:
	print("three")
	var rects := ScreenLayout.rects(3, SIZE)
	expect(rects.size() == 3, "three panes")
	# Two on top and one below: what everyone does and nobody likes.
	expect(rects[0].size.y == rects[1].size.y, "the top two are the same height")
	expect(rects[2].size.x == SIZE.x, "and the third spans the full width beneath them")

func test_four_players() -> void:
	print("four")
	var rects := ScreenLayout.rects(4, SIZE)
	expect(rects.size() == 4, "four panes")
	expect(rects[3].position == Vector2i(640, 360), "the last one is the bottom-right quadrant")

func test_no_gaps_at_any_count() -> void:
	print("full coverage")
	for players in [1, 2, 3, 4]:
		expect(ScreenLayout.covers(ScreenLayout.rects(players, SIZE), SIZE),
			"%d panes cover the window exactly once" % players)
	expect(ScreenLayout.covers(
		ScreenLayout.rects(2, SIZE, ScreenLayout.Split.VERTICAL), SIZE),
		"and so does a vertical split")

func test_odd_sizes_leave_no_seam() -> void:
	print("odd sizes")
	# 1081 halved twice is 1080, and the missing row is a permanent one-pixel
	# line down the middle of somebody's monitor.
	var odd := Vector2i(1281, 1081)
	for players in [2, 3, 4]:
		var rects := ScreenLayout.rects(players, odd)
		expect(ScreenLayout.covers(rects, odd),
			"%d panes still cover an odd-sized window with no seam" % players)
	var tiny := Vector2i(3, 3)
	expect(ScreenLayout.covers(ScreenLayout.rects(4, tiny), tiny),
		"even a three-pixel window is covered exactly")

func test_coverage_rejects_bad_layouts() -> void:
	print("bad layouts")
	# A checker that only ever says yes checks nothing. Both failure modes: a
	# pane hanging off the edge of the window, and two panes on top of each
	# other.
	var outside: Array[Rect2i] = [Rect2i(0, 0, SIZE.x, SIZE.y + 10)]
	expect(not ScreenLayout.covers(outside, SIZE), "a pane larger than the window is refused")
	var negative: Array[Rect2i] = [Rect2i(-5, 0, SIZE.x, SIZE.y)]
	expect(not ScreenLayout.covers(negative, SIZE), "so is one starting off the left edge")
	# Overlapping by ten rows and leaving ten bare: the areas still add up to
	# exactly the window, so only an overlap check can catch this one.
	var overlapping: Array[Rect2i] = [
		Rect2i(0, 0, SIZE.x, SIZE.y / 2),
		Rect2i(0, SIZE.y / 2 - 10, SIZE.x, SIZE.y / 2),
	]
	expect(not ScreenLayout.covers(overlapping, SIZE),
		"and two panes that overlap, even when their areas add up correctly")
	var gap: Array[Rect2i] = [Rect2i(0, 0, SIZE.x, SIZE.y / 2 - 1)]
	expect(not ScreenLayout.covers(gap, SIZE), "as is a layout that leaves part of the window bare")
	# The one an area check alone would miss: exactly the right number of
	# pixels, all of them slid ten rows off the bottom of the window.
	var shifted: Array[Rect2i] = [Rect2i(0, 10, SIZE.x, SIZE.y)]
	expect(not ScreenLayout.covers(shifted, SIZE),
		"and so is a pane of the right size hanging off the edge")

func test_out_of_range_counts() -> void:
	print("silly counts")
	expect(ScreenLayout.rects(0, SIZE).size() == 1, "zero players still gets one pane")
	expect(ScreenLayout.rects(9, SIZE).size() == 4, "and nine is capped at four")
	expect(ScreenLayout.covers(ScreenLayout.rects(-3, SIZE), SIZE),
		"a negative count is clamped rather than producing nothing")

func test_aspect_ratios() -> void:
	print("aspect")
	expect(is_equal_approx(ScreenLayout.aspect_of(Rect2i(0, 0, 1600, 900)), 16.0 / 9.0),
		"a 16:9 pane reports 16:9")
	var stacked := ScreenLayout.rects(2, SIZE)[0]
	expect(ScreenLayout.aspect_of(stacked) > 3.0, "half a 16:9 screen is a letterbox")
	expect(is_zero_approx(ScreenLayout.aspect_of(Rect2i(0, 0, 100, 0))),
		"and a pane with no height reports zero rather than dividing by it")

func test_matching_the_field_of_view() -> void:
	print("field of view")
	var base_aspect := 16.0 / 9.0
	expect(is_equal_approx(ScreenLayout.matched_fov(70.0, base_aspect, base_aspect), 70.0),
		"an unchanged aspect leaves the field of view alone")
	# A letterbox pane is *wider* than the screen was, so holding the horizontal
	# angle means a narrower vertical one.
	var letterbox := ScreenLayout.matched_fov(70.0, base_aspect, base_aspect * 2.0)
	expect(letterbox < 70.0, "a wider pane needs a narrower vertical angle")
	var tall := ScreenLayout.matched_fov(70.0, base_aspect, base_aspect * 0.5)
	expect(tall > 70.0, "and a taller one a wider vertical angle")
	expect(tall < 179.0 and letterbox > 1.0, "both staying inside what a camera accepts")

func test_degenerate_aspects() -> void:
	print("degenerate aspect")
	expect(is_equal_approx(ScreenLayout.matched_fov(70.0, 0.0, 1.5), 70.0),
		"a zero base aspect leaves the field of view alone rather than dividing by zero")
	expect(is_equal_approx(ScreenLayout.matched_fov(70.0, 1.5, 0.0), 70.0),
		"and so does a zero pane aspect")

# --- the real panes --------------------------------------------------------

func _process(_delta: float) -> void:
	if _checked:
		return
	_checked = true
	print("the real panes")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var panes: Control = scene.get_node("UI/Panes")
	expect(panes.get_child_count() == 2, "the driver built one pane per player")

	var world: World3D = scene.get_viewport().world_3d
	var shared := 0
	var cameras := 0
	for container in panes.get_children():
		for child in container.get_children():
			var view := child as SubViewport
			if view == null:
				continue
			# The line the whole demo exists for: a SubViewport makes its own
			# empty World3D unless told otherwise, and a pane looking into an
			# empty world renders black with no error to search for.
			if view.world_3d == world:
				shared += 1
			for node in view.get_children():
				if node is Camera3D and (node as Camera3D).current:
					cameras += 1
	expect(shared == 2, "and pointed every one of them at the same World3D")
	expect(cameras == 2, "each with a current camera of its own")

	scene.queue_free()
	_report()
