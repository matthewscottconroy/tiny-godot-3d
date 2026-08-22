extends Node

# Drives the real FrameFit from scripts/frame_fit.gd.
#
# Every failure mode of a group camera is a number: a centre pulled toward a
# cluster, a distance that fits the wrong axis, a zoom that never stops. None of
# them looks like an error, and all of them are stateable.

var _pass := 0
var _fail := 0

const FOV := 70.0
const WIDE := 16.0 / 9.0

func _ready() -> void:
	test_bounds_of_a_group()
	test_the_focus_is_the_middle_not_the_average()
	test_the_radius_of_a_group()
	test_one_target_needs_no_room()
	test_distance_grows_with_the_group()
	test_a_wider_lens_stands_closer()
	test_a_tall_screen_binds_on_the_horizontal()
	test_distance_of_nothing()
	test_the_first_frame_snaps()
	test_it_smooths_afterwards()
	test_no_smoothing_means_no_smoothing()
	test_smoothing_is_frame_rate_independent()
	test_the_distance_is_clamped()
	test_padding_stands_further_back()
	test_an_empty_group()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[camera-framing] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _group() -> Array[Vector3]:
	var points: Array[Vector3] = [
		Vector3(-10, 0, 0), Vector3(10, 0, 0), Vector3(0, 0, 6)]
	return points

func test_bounds_of_a_group() -> void:
	print("bounds")
	var box := FrameFit.bounds_of(_group())
	expect(box.position.is_equal_approx(Vector3(-10, 0, 0)), "the box starts at the lowest corner")
	expect(box.size.is_equal_approx(Vector3(20, 0, 6)), "and spans to the highest")

func test_the_focus_is_the_middle_not_the_average() -> void:
	print("focus")
	# Three players together and one away on his own. The average sits with the
	# group and leaves the fourth off screen — which is the player who needed
	# the camera.
	var lopsided: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(30, 0, 0)]
	var focus := FrameFit.focus_of(lopsided)
	expect(is_equal_approx(focus.x, 15.0), "the focus is the middle of the bounds")
	var average := (0.0 + 1.0 + 2.0 + 30.0) / 4.0
	expect(absf(focus.x - average) > 5.0, "which is nowhere near the average of the positions")

func test_the_radius_of_a_group() -> void:
	print("radius")
	var wide: Array[Vector3] = [Vector3(-5, 0, 0), Vector3(5, 0, 0)]
	expect(is_equal_approx(FrameFit.radius_of(wide), 5.0), "two points ten apart have a radius of five")
	var spread: Array[Vector3] = [Vector3(-5, 0, -5), Vector3(5, 0, 5)]
	expect(FrameFit.radius_of(spread) > 5.0, "and spreading them on both axes needs more room")

func test_one_target_needs_no_room() -> void:
	print("one target")
	var single: Array[Vector3] = [Vector3(3, 0, 4)]
	expect(is_zero_approx(FrameFit.radius_of(single)), "one target has no radius to fit")
	expect(FrameFit.focus_of(single).is_equal_approx(Vector3(3, 0, 4)), "and the focus is simply it")

func test_distance_grows_with_the_group() -> void:
	print("fitting")
	var near := FrameFit.distance_for(5.0, FOV, WIDE)
	var far := FrameFit.distance_for(10.0, FOV, WIDE)
	expect(far > near, "a bigger group needs more room")
	expect(absf(far - near * 2.0) < 0.001, "in proportion — twice the radius is twice the distance")

func test_a_wider_lens_stands_closer() -> void:
	print("field of view")
	var narrow := FrameFit.distance_for(5.0, 40.0, WIDE)
	var wide := FrameFit.distance_for(5.0, 100.0, WIDE)
	expect(wide < narrow, "a wider lens fits the same group from closer in")

func test_a_tall_screen_binds_on_the_horizontal() -> void:
	print("aspect")
	# Godot's fov is the vertical angle. On a wide screen the horizontal one is
	# larger, so the vertical binds and the aspect changes nothing. On a tall
	# screen it is the other way round.
	var on_wide := FrameFit.distance_for(5.0, FOV, WIDE)
	var on_square := FrameFit.distance_for(5.0, FOV, 1.0)
	expect(is_equal_approx(on_wide, on_square),
		"at 1:1 and wider, the vertical angle is what binds")
	var on_tall := FrameFit.distance_for(5.0, FOV, 0.5)
	expect(on_tall > on_wide, "on a screen taller than it is wide, the camera has to back further off")

func test_distance_of_nothing() -> void:
	print("no radius")
	expect(is_zero_approx(FrameFit.distance_for(0.0, FOV, WIDE)),
		"a group with no size needs no distance")
	expect(not is_nan(FrameFit.distance_for(5.0, 0.0, WIDE)),
		"and a nonsensical field of view is clamped rather than dividing by zero")

func test_the_first_frame_snaps() -> void:
	print("the first frame")
	var fit := FrameFit.new()
	var result := fit.update(_group(), FOV, WIDE, 1.0 / 60.0)
	# Easing in from wherever the camera was left is a swoop at the start of
	# every level that nobody asked for.
	expect(result["focus"].is_equal_approx(FrameFit.focus_of(_group())),
		"the first update snaps to the group rather than easing toward it")

func test_it_smooths_afterwards() -> void:
	print("smoothing")
	var fit := FrameFit.new()
	fit.update(_group(), FOV, WIDE, 1.0 / 60.0)
	var moved: Array[Vector3] = [Vector3(50, 0, 0), Vector3(60, 0, 0)]
	var result := fit.update(moved, FOV, WIDE, 1.0 / 60.0)
	var target := FrameFit.focus_of(moved)
	expect(result["focus"].x > 0.0, "the camera moves toward the new focus")
	expect(result["focus"].x < target.x, "without arriving in one frame")

func test_no_smoothing_means_no_smoothing() -> void:
	print("smoothing off")
	var fit := FrameFit.new()
	fit.smoothing = 0.0
	fit.update(_group(), FOV, WIDE, 0.016)
	var moved: Array[Vector3] = [Vector3(40, 0, 0), Vector3(44, 0, 0)]
	var result := fit.update(moved, FOV, WIDE, 0.016)
	# "No smoothing" has to mean arriving now. Reading it as "never move" gives
	# a camera that silently stops following, which is a far worse default.
	expect(result["focus"].is_equal_approx(FrameFit.focus_of(moved)),
		"a smoothing of zero arrives immediately rather than freezing")

func test_smoothing_is_frame_rate_independent() -> void:
	print("frame rate")
	var one := FrameFit.new()
	var two := FrameFit.new()
	one.update(_group(), FOV, WIDE, 0.016)
	two.update(_group(), FOV, WIDE, 0.016)
	var moved: Array[Vector3] = [Vector3(40, 0, 0), Vector3(44, 0, 0)]
	var whole := one.update(moved, FOV, WIDE, 0.1)
	two.update(moved, FOV, WIDE, 0.05)
	var halves := two.update(moved, FOV, WIDE, 0.05)
	expect(absf(whole["focus"].x - halves["focus"].x) < 0.001,
		"two half-steps land where one whole step does")

func test_the_distance_is_clamped() -> void:
	print("limits")
	var fit := FrameFit.new()
	fit.min_distance = 5.0
	fit.max_distance = 20.0
	var tiny: Array[Vector3] = [Vector3.ZERO, Vector3(0.1, 0, 0)]
	expect(is_equal_approx(fit.snap(tiny, FOV, WIDE)["distance"], 5.0),
		"a group standing together does not put the camera in their pockets")
	var enormous: Array[Vector3] = [Vector3(-500, 0, 0), Vector3(500, 0, 0)]
	expect(is_equal_approx(fit.snap(enormous, FOV, WIDE)["distance"], 20.0),
		"and one player falling down a hole does not put it into orbit")

func test_padding_stands_further_back() -> void:
	print("padding")
	var tight := FrameFit.new()
	tight.padding = 0.0
	var roomy := FrameFit.new()
	roomy.padding = 0.5
	expect(roomy.snap(_group(), FOV, WIDE)["distance"]
		> tight.snap(_group(), FOV, WIDE)["distance"],
		"padding leaves room around the group rather than framing it exactly")

func test_an_empty_group() -> void:
	print("nobody left")
	var fit := FrameFit.new()
	var none: Array[Vector3] = []
	var result := fit.snap(none, FOV, WIDE)
	expect(result["focus"] == Vector3.ZERO, "an empty group focuses on the origin rather than erroring")
	expect(result["distance"] >= fit.min_distance, "and keeps a sane distance")
